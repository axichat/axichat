import 'dart:async';

import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/draft/models/draft_save_result.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'draft_state.dart';

class DraftCubit extends Cubit<DraftState> with BlocCache<DraftState> {
  DraftCubit({
    required MessageService messageService,
    EmailService? emailService,
    required SettingsCubit settingsCubit,
  })  : _messageService = messageService,
        _settingsCubit = settingsCubit,
        _settingsState = settingsCubit.state,
        _emailService = emailService,
        super(const DraftsAvailable(items: null)) {
    _draftsSubscription = _messageService
        .draftsStream()
        .listen((items) => emit(DraftsAvailable(items: items)));
    _settingsSubscription = _settingsCubit.stream.listen((state) {
      _settingsState = state;
    });
  }

  final MessageService _messageService;
  final EmailService? _emailService;
  final SettingsCubit _settingsCubit;
  SettingsState _settingsState;

  late final StreamSubscription<List<Draft>> _draftsSubscription;
  StreamSubscription<SettingsState>? _settingsSubscription;

  @override
  void onChange(Change<DraftState> change) {
    super.onChange(change);
    final current = change.currentState;
    if (current is DraftsAvailable) {
      cache['items'] = current.items;
    }
  }

  @override
  Future<void> close() async {
    await _draftsSubscription.cancel();
    await _settingsSubscription?.cancel();
    return super.close();
  }

  Future<bool> sendDraft({
    required int? id,
    required List<String> xmppJids,
    required List<FanOutTarget> emailTargets,
    required String body,
    String? subject,
    List<EmailAttachment> attachments = const [],
  }) async {
    emit(DraftSending());
    try {
      if (emailTargets.isNotEmpty) {
        await _sendEmailDraft(
          targets: emailTargets,
          body: body,
          subject: subject,
          attachments: attachments,
        );
      }
      if (xmppJids.isNotEmpty) {
        await _sendXmppDraft(
          jids: xmppJids,
          body: body,
          attachments: attachments,
        );
      }
    } on FanOutValidationException catch (error) {
      emit(DraftFailure(error.message));
      return false;
    } on XmppMessageException catch (_) {
      emit(const DraftFailure(
          'Failed to send message. Ensure recipient address exists.'));
      return false;
    } on Exception catch (_) {
      emit(const DraftFailure(
          'Failed to send email. Ensure recipient address exists.'));
      return false;
    }
    if (id != null) {
      await deleteDraft(id: id);
    }
    emit(DraftSendComplete());
    return true;
  }

  Future<DraftSaveResult> saveDraft({
    required int? id,
    required List<String> jids,
    required String body,
    String? subject,
    List<EmailAttachment> attachments = const [],
  }) async {
    final result = await _messageService.saveDraft(
      id: id,
      jids: jids,
      body: body,
      subject: subject,
      attachments: attachments,
    );
    emit(DraftSaveComplete());
    return result;
  }

  Future<void> deleteDraft({required int id}) async {
    await _messageService.deleteDraft(id: id);
  }

  Future<void> _sendEmailDraft({
    required List<FanOutTarget> targets,
    required String body,
    String? subject,
    required List<EmailAttachment> attachments,
  }) async {
    final emailService = _emailService;
    if (emailService == null) {
      throw StateError('EmailService unavailable for email draft send.');
    }
    if (targets.isEmpty) {
      throw const FanOutValidationException('Select at least one recipient.');
    }
    final trimmedBody = body.trim();
    final hasSubject = subject?.trim().isNotEmpty == true;
    if (!hasSubject && trimmedBody.isEmpty && attachments.isEmpty) {
      throw const FanOutValidationException('Message cannot be empty.');
    }
    final includeSignatureToken = _settingsState.shareTokenSignatureEnabled &&
        targets.every((target) => target.shareSignatureEnabled);
    final shareId = ShareTokenCodec.generateShareId();
    if (trimmedBody.isNotEmpty || hasSubject) {
      final report = await emailService.fanOutSend(
        targets: targets,
        body: trimmedBody,
        subject: subject,
        shareId: shareId,
        useSubjectToken: includeSignatureToken,
        tokenAsSignature: includeSignatureToken,
      );
      _throwIfFanOutFailed(
        report,
        failureContext: 'Message',
      );
    }
    for (final attachment in attachments) {
      final report = await emailService.fanOutSend(
        targets: targets,
        attachment: attachment,
        subject: subject,
        shareId: shareId,
        useSubjectToken: includeSignatureToken,
        tokenAsSignature: includeSignatureToken,
      );
      _throwIfFanOutFailed(
        report,
        failureContext: attachment.fileName,
      );
    }
  }

  Future<void> _sendXmppDraft({
    required List<String> jids,
    required String body,
    required List<EmailAttachment> attachments,
  }) async {
    final trimmedBody = body.trim();
    final hasBody = trimmedBody.isNotEmpty;
    final hasAttachments = attachments.isNotEmpty;
    if (!hasBody && !hasAttachments) {
      throw const FanOutValidationException('Message cannot be empty.');
    }
    if (jids.isEmpty) {
      throw const FanOutValidationException('Select at least one recipient.');
    }
    final db = await _messageService.database;
    for (final jid in jids) {
      final chat = await db.getChat(jid);
      final encryption = chat?.encryptionProtocol ?? EncryptionProtocol.omemo;
      final chatType = chat?.type ?? ChatType.chat;
      if (hasBody) {
        await _messageService.sendMessage(
          jid: jid,
          text: trimmedBody,
          encryptionProtocol: encryption,
          chatType: chatType,
        );
      }
      for (final attachment in attachments) {
        await _messageService.sendAttachment(
          jid: jid,
          attachment: attachment,
          encryptionProtocol: encryption,
          chatType: chatType,
        );
      }
    }
  }

  void _throwIfFanOutFailed(
    FanOutSendReport report, {
    required String failureContext,
  }) {
    if (!report.hasFailures) {
      return;
    }
    final failedRecipients = report.statuses
        .where((status) => status.state == FanOutRecipientState.failed)
        .map((status) => status.chat.contactDisplayName?.isNotEmpty == true
            ? status.chat.contactDisplayName!
            : status.chat.jid)
        .toList();
    final recipientList = failedRecipients.join(', ');
    final message = failedRecipients.length == 1
        ? '$failureContext failed to send to $recipientList.'
        : '$failureContext failed to send to $recipientList.';
    throw FanOutValidationException(message);
  }
}
