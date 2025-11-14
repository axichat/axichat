import 'dart:async';

import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/draft/models/draft_save_result.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'draft_state.dart';

class DraftCubit extends Cubit<DraftState> with BlocCache<DraftState> {
  DraftCubit({
    required MessageService messageService,
    EmailService? emailService,
  })  : _messageService = messageService,
        _emailService = emailService,
        super(const DraftsAvailable(items: null)) {
    _draftsSubscription = _messageService
        .draftsStream()
        .listen((items) => emit(DraftsAvailable(items: items)));
  }

  final MessageService _messageService;
  final EmailService? _emailService;

  late final StreamSubscription<List<Draft>> _draftsSubscription;

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
    return super.close();
  }

  Future<bool> sendDraft({
    required int? id,
    required List<String> xmppJids,
    required List<FanOutTarget> emailTargets,
    required String body,
    MessageTransport transport = MessageTransport.xmpp,
    List<EmailAttachment> attachments = const [],
  }) async {
    emit(DraftSending());
    try {
      if (transport == MessageTransport.email) {
        await _sendEmailDraft(
          targets: emailTargets,
          body: body,
          attachments: attachments,
        );
      } else {
        await _sendXmppDraft(
          jids: xmppJids,
          body: body,
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
    List<EmailAttachment> attachments = const [],
  }) async {
    final result = await _messageService.saveDraft(
      id: id,
      jids: jids,
      body: body,
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
    if (trimmedBody.isEmpty && attachments.isEmpty) {
      throw const FanOutValidationException('Message cannot be empty.');
    }
    if (trimmedBody.isNotEmpty) {
      final report = await emailService.fanOutSend(
        targets: targets,
        body: trimmedBody,
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
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw const FanOutValidationException('Message cannot be empty.');
    }
    if (jids.isEmpty) {
      throw const FanOutValidationException('Select at least one recipient.');
    }
    for (final jid in jids) {
      await _messageService.sendMessage(jid: jid, text: trimmedBody);
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
