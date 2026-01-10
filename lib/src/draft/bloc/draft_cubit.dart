// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/draft/models/draft_save_result.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_bundle.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'draft_state.dart';

const int _coreDraftRecipientLimit = 1;
const int _emailAttachmentBundleMinimumCount = 2;
const String _jidSeparator = '@';
const String _axiDomainPatternSource = r'@(?:[\\w-]+\\.)*axi\\.im$';
final RegExp _axiDomainPattern =
    RegExp(_axiDomainPatternSource, caseSensitive: false);

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
    _draftsSubscription = _messageService.draftsStream().listen((items) {
      _items = items;
      emit(DraftsAvailable(items: items));
    });
    _settingsSubscription = _settingsCubit.stream.listen((state) {
      _settingsState = state;
    });
  }

  final MessageService _messageService;
  final EmailService? _emailService;
  final SettingsCubit _settingsCubit;
  SettingsState _settingsState;
  List<Draft>? _items;

  late final StreamSubscription<List<Draft>> _draftsSubscription;
  StreamSubscription<SettingsState>? _settingsSubscription;

  @override
  void onChange(Change<DraftState> change) {
    super.onChange(change);
    final current = change.currentState;
    if (current is DraftsAvailable) {
      cache['items'] = current.items;
      _items = current.items;
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
    required AppLocalizations l10n,
    String? subject,
    List<EmailAttachment> attachments = const [],
  }) async {
    emit(DraftSending(items: _items));
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
      emit(
        DraftFailure(
          _mapFanOutValidationMessage(error.message, l10n),
          items: _items,
        ),
      );
      return false;
    } on XmppMessageException catch (_) {
      emit(
        DraftFailure(
          l10n.draftSendFailed,
          items: _items,
        ),
      );
      return false;
    } on Exception catch (_) {
      emit(
        DraftFailure(
          l10n.draftSendFailed,
          items: _items,
        ),
      );
      return false;
    }
    if (id != null) {
      await deleteDraft(id: id);
    }
    emit(DraftSendComplete(items: _items));
    return true;
  }

  Future<DraftSaveResult> saveDraft({
    required int? id,
    required List<String> jids,
    required String body,
    String? subject,
    List<EmailAttachment> attachments = const [],
    bool autoSave = false,
  }) async {
    final result = await _messageService.saveDraft(
      id: id,
      jids: jids,
      body: body,
      subject: subject,
      attachments: attachments,
    );
    try {
      await _mirrorDraftToCore(
        jids: jids,
        body: body,
        subject: subject,
        attachments: attachments,
      );
    } on Exception {
      // Best-effort: core draft syncing should not block local saves.
    }
    emit(
      DraftSaveComplete(
        items: _items,
        autoSaved: autoSave,
      ),
    );
    return result;
  }

  String _mapFanOutValidationMessage(
    String message,
    AppLocalizations l10n,
  ) {
    switch (message) {
      case 'Select at least one recipient.':
        return l10n.draftNoRecipients;
      case 'Message cannot be empty.':
        return l10n.draftValidationNoContent;
      case 'Unable to resolve recipients.':
        return l10n.draftNoRecipients;
      default:
        return message;
    }
  }

  Future<void> deleteDraft({required int id}) async {
    final draft = await _loadDraft(id);
    await _messageService.deleteDraft(id: id);
    try {
      await _clearCoreDraftForDraft(draft);
    } on Exception {
      // Best-effort: core draft syncing should not block local deletes.
    }
  }

  Future<Draft?> _loadDraft(int id) async {
    final db = await _loadDatabase();
    return db.getDraft(id);
  }

  Future<void> _mirrorDraftToCore({
    required List<String> jids,
    required String body,
    String? subject,
    required List<EmailAttachment> attachments,
  }) async {
    if (!_shouldUseCoreDraftFallback) return;
    final emailService = _emailService;
    if (emailService == null) return;
    final recipient = _singleEmailRecipient(jids);
    if (recipient == null) return;
    final chat = await _resolveEmailChatForDraft(
      emailService: emailService,
      address: recipient,
    );
    if (chat == null) return;
    await emailService.saveDraftToCore(
      chat: chat,
      text: body,
      subject: subject,
      attachments: attachments,
    );
  }

  Future<void> _clearCoreDraftForDraft(Draft? draft) async {
    if (!_shouldUseCoreDraftFallback) return;
    final emailService = _emailService;
    if (emailService == null || draft == null) return;
    final recipient = _singleEmailRecipient(draft.jids);
    if (recipient == null) return;
    final db = await _loadDatabase();
    final existing = await db.getChat(recipient);
    if (existing == null) return;
    final chat = await emailService.ensureChatForEmailChat(existing);
    await emailService.clearDraftFromCore(chat);
  }

  Future<Chat?> _resolveEmailChatForDraft({
    required EmailService emailService,
    required String address,
  }) async {
    final normalized = normalizeEmailAddress(address);
    final db = await _loadDatabase();
    final existing = await db.getChat(normalized);
    if (existing != null) {
      return emailService.ensureChatForEmailChat(existing);
    }
    return emailService.ensureChatForAddress(address: normalized);
  }

  Future<XmppDatabase> _loadDatabase() async {
    final xmppBase = _messageService as XmppBase;
    return xmppBase.database;
  }

  bool get _shouldUseCoreDraftFallback {
    final emailService = _emailService;
    if (emailService == null) return false;
    return emailService.isSmtpOnly;
  }

  String? _singleEmailRecipient(List<String> jids) {
    final normalizedRecipients = <String>{};
    for (final jid in jids) {
      final normalized = normalizeEmailAddress(jid);
      if (normalized.isEmpty) {
        continue;
      }
      normalizedRecipients.add(normalized);
    }
    if (normalizedRecipients.length != _coreDraftRecipientLimit) {
      return null;
    }
    final recipient = normalizedRecipients.first;
    if (!_isEmailOnlyAddress(recipient)) {
      return null;
    }
    return recipient;
  }

  bool _isEmailOnlyAddress(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (!normalized.contains(_jidSeparator)) {
      return false;
    }
    return !_axiDomainPattern.hasMatch(normalized);
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
    final hasAttachments = attachments.isNotEmpty;
    if (!hasSubject && trimmedBody.isEmpty && attachments.isEmpty) {
      throw const FanOutValidationException('Message cannot be empty.');
    }
    final htmlBody = trimmedBody.isNotEmpty
        ? HtmlContentCodec.fromPlainText(trimmedBody)
        : null;
    final includeSignatureToken = _settingsState.shareTokenSignatureEnabled &&
        targets.every((target) => target.shareSignatureEnabled);
    final shareId = ShareTokenCodec.generateShareId();
    final shouldSendBodyOnly =
        (trimmedBody.isNotEmpty || hasSubject) && !hasAttachments;
    if (shouldSendBodyOnly) {
      final report = await emailService.fanOutSend(
        targets: targets,
        body: trimmedBody,
        htmlBody: htmlBody,
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
    if (hasAttachments) {
      final caption = trimmedBody.isNotEmpty ? trimmedBody : null;
      final htmlCaption = caption == null ? null : htmlBody;
      final bool shouldBundle =
          attachments.length >= _emailAttachmentBundleMinimumCount;
      final attachmentsToSend = await _bundleEmailAttachments(
        attachments: attachments,
        caption: caption,
      );
      try {
        for (var index = 0; index < attachmentsToSend.length; index += 1) {
          final attachment = attachmentsToSend[index];
          final captionedAttachment = index == 0 && caption != null
              ? attachment.copyWith(caption: caption)
              : attachment;
          final report = await emailService.fanOutSend(
            targets: targets,
            attachment: captionedAttachment,
            htmlCaption: index == 0 ? htmlCaption : null,
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
      } finally {
        if (shouldBundle) {
          for (final attachment in attachmentsToSend) {
            EmailAttachmentBundler.scheduleCleanup(attachment);
          }
        }
      }
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
    final attachmentGroupId =
        hasAttachments && attachments.length > 1 ? uuid.v4() : null;
    final uploads =
        List<XmppAttachmentUpload?>.filled(attachments.length, null);
    for (final jid in jids) {
      final chat = await db.getChat(jid);
      final encryption = chat?.encryptionProtocol ?? EncryptionProtocol.omemo;
      final chatType = chat?.type ?? ChatType.chat;
      if (hasBody && !hasAttachments) {
        await _messageService.sendMessage(
          jid: jid,
          text: trimmedBody,
          encryptionProtocol: encryption,
          chatType: chatType,
        );
      }
      for (var index = 0; index < attachments.length; index += 1) {
        final attachment = attachments[index];
        final shouldApplyCaption = hasBody && index == 0;
        final resolvedAttachment = shouldApplyCaption
            ? attachment.copyWith(caption: trimmedBody)
            : attachment;
        final upload = uploads[index];
        final resolvedUpload = await _messageService.sendAttachment(
          jid: jid,
          attachment: resolvedAttachment,
          encryptionProtocol: encryption,
          chatType: chatType,
          transportGroupId: attachmentGroupId,
          attachmentOrder: index,
          upload: upload,
        );
        uploads[index] = resolvedUpload;
      }
    }
  }

  Future<List<EmailAttachment>> _bundleEmailAttachments({
    required List<EmailAttachment> attachments,
    required String? caption,
  }) async {
    if (attachments.length < _emailAttachmentBundleMinimumCount) {
      return attachments;
    }
    final bundled = await EmailAttachmentBundler.bundle(
      attachments: attachments,
      caption: caption,
    );
    return [bundled];
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
