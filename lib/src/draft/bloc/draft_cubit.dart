// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/draft/models/draft_save_result.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_bundle.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'draft_state.dart';

enum DraftSortOrder {
  newestFirst,
  oldestFirst;

  bool get isNewestFirst => this == DraftSortOrder.newestFirst;
}

class DraftSearchSnapshot extends Equatable {
  const DraftSearchSnapshot({
    required this.query,
    required this.filterAttachmentsOnly,
    required this.sortOrder,
  });

  final String query;
  final bool filterAttachmentsOnly;
  final DraftSortOrder sortOrder;

  @override
  List<Object?> get props => [query, filterAttachmentsOnly, sortOrder];
}

enum DraftSendFailureType { noRecipients, noContent, sendFailed }

class DraftSendValidationException implements Exception {
  const DraftSendValidationException(this.type);

  final DraftSendFailureType type;
}

class DraftXmppTarget extends Equatable {
  const DraftXmppTarget({
    required this.jid,
    required this.encryptionProtocol,
    required this.chatType,
  });

  final String jid;
  final EncryptionProtocol encryptionProtocol;
  final ChatType chatType;

  @override
  List<Object?> get props => [jid, encryptionProtocol, chatType];
}

class DraftCubit extends Cubit<DraftState> with BlocCache<DraftState> {
  static const String itemsCacheKey = 'items';
  static const String visibleItemsCacheKey = 'visibleItems';
  static const int _emailAttachmentBundleMinimumCount = 2;

  DraftCubit({
    required MessageService messageService,
    EmailService? emailService,
  }) : _messageService = messageService,
       _emailService = emailService,
       super(const DraftsAvailable(items: null, visibleItems: null)) {
    _draftsSubscription = _messageService.draftsStream().listen((items) {
      _items = items;
      emit(_stateForItems(items));
    });
  }

  final MessageService _messageService;
  EmailService? _emailService;
  List<Draft>? _items;
  DraftSearchSnapshot _searchSnapshot = const DraftSearchSnapshot(
    query: '',
    filterAttachmentsOnly: false,
    sortOrder: DraftSortOrder.newestFirst,
  );

  late final StreamSubscription<List<Draft>> _draftsSubscription;

  void updateEmailService(EmailService? emailService) {
    _emailService = emailService;
  }

  @override
  void onChange(Change<DraftState> change) {
    super.onChange(change);
    final current = change.currentState;
    if (current is DraftsAvailable) {
      cache[itemsCacheKey] = current.items;
      cache[visibleItemsCacheKey] = current.visibleItems;
      _items = current.items;
    }
  }

  @override
  Future<void> close() async {
    await _draftsSubscription.cancel();
    return super.close();
  }

  void updateSearchSnapshot(DraftSearchSnapshot snapshot) {
    if (_searchSnapshot == snapshot) {
      return;
    }
    _searchSnapshot = snapshot;
    final items = _items;
    if (items == null) return;
    emit(_stateForItems(items));
  }

  Future<List<EmailAttachment>> loadDraftAttachments(
    List<String> metadataIds,
  ) async {
    if (metadataIds.isEmpty) return const [];
    return _messageService.loadDraftAttachments(metadataIds);
  }

  Future<EmailAttachment> optimizeAttachment(EmailAttachment attachment) async {
    return EmailAttachmentOptimizer.optimize(attachment);
  }

  Future<void> deleteDraftAttachmentMetadata(String metadataId) async {
    await _messageService.deleteFileMetadata(metadataId);
  }

  Future<bool> sendDraft({
    required int? id,
    required List<DraftXmppTarget> xmppTargets,
    required List<FanOutTarget> emailTargets,
    required String body,
    required bool shareTokenSignatureEnabled,
    String? subject,
    List<EmailAttachment> attachments = const [],
  }) async {
    emit(DraftSending(items: _items, visibleItems: _visibleItems));
    try {
      if (emailTargets.isNotEmpty) {
        await _sendEmailDraft(
          targets: emailTargets,
          body: body,
          subject: subject,
          attachments: attachments,
          shareTokenSignatureEnabled: shareTokenSignatureEnabled,
        );
      }
      if (xmppTargets.isNotEmpty) {
        await _sendXmppDraft(
          targets: xmppTargets,
          body: body,
          attachments: attachments,
        );
      }
    } on DraftSendValidationException catch (error) {
      emit(
        DraftFailure(error.type, items: _items, visibleItems: _visibleItems),
      );
      return false;
    } on FanOutValidationException {
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
        ),
      );
      return false;
    } on XmppMessageException catch (_) {
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
        ),
      );
      return false;
    } on Exception catch (_) {
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
        ),
      );
      return false;
    }
    if (id != null) {
      await deleteDraft(id: id);
    }
    emit(DraftSendComplete(items: _items, visibleItems: _visibleItems));
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
        visibleItems: _visibleItems,
        autoSaved: autoSave,
      ),
    );
    return result;
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
    final recipient = await _singleEmailRecipient(jids);
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
    final recipient = await _singleEmailRecipient(draft.jids);
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
    return _messageService.database;
  }

  bool get _shouldUseCoreDraftFallback {
    final emailService = _emailService;
    if (emailService == null) return false;
    return emailService.isSmtpOnly;
  }

  Future<String?> _singleEmailRecipient(List<String> jids) async {
    const int coreDraftRecipientLimit = 1;
    final normalizedRecipients = <String>{};
    for (final jid in jids) {
      final normalized = normalizeEmailAddress(jid);
      if (normalized.isEmpty) {
        continue;
      }
      normalizedRecipients.add(normalized);
    }
    if (normalizedRecipients.length != coreDraftRecipientLimit) {
      return null;
    }
    final recipient = normalizedRecipients.first;
    final db = await _loadDatabase();
    final existing = await db.getChat(recipient);
    if (existing == null || !existing.defaultTransport.isEmail) {
      return null;
    }
    return recipient;
  }

  Future<void> _sendEmailDraft({
    required List<FanOutTarget> targets,
    required String body,
    String? subject,
    required List<EmailAttachment> attachments,
    required bool shareTokenSignatureEnabled,
  }) async {
    final emailService = _emailService;
    if (emailService == null) {
      throw StateError('EmailService unavailable for email draft send.');
    }
    if (targets.isEmpty) {
      throw const DraftSendValidationException(
        DraftSendFailureType.noRecipients,
      );
    }
    final trimmedBody = body.trim();
    final hasSubject = subject?.trim().isNotEmpty == true;
    final hasAttachments = attachments.isNotEmpty;
    if (!hasSubject && trimmedBody.isEmpty && attachments.isEmpty) {
      throw const DraftSendValidationException(DraftSendFailureType.noContent);
    }
    final htmlBody = trimmedBody.isNotEmpty
        ? HtmlContentCodec.fromPlainText(trimmedBody)
        : null;
    final includeSignatureToken =
        shareTokenSignatureEnabled &&
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
      _throwIfFanOutFailed(report);
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
          _throwIfFanOutFailed(report);
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
    required List<DraftXmppTarget> targets,
    required String body,
    required List<EmailAttachment> attachments,
  }) async {
    final trimmedBody = body.trim();
    final hasBody = trimmedBody.isNotEmpty;
    final hasAttachments = attachments.isNotEmpty;
    if (!hasBody && !hasAttachments) {
      throw const DraftSendValidationException(DraftSendFailureType.noContent);
    }
    if (targets.isEmpty) {
      throw const DraftSendValidationException(
        DraftSendFailureType.noRecipients,
      );
    }
    final attachmentGroupId = hasAttachments && attachments.length > 1
        ? uuid.v4()
        : null;
    final uploads = List<XmppAttachmentUpload?>.filled(
      attachments.length,
      null,
    );

    Future<void> sendToTarget(
      DraftXmppTarget target, {
      required bool updateUploads,
    }) async {
      final jid = target.jid;
      final encryption = target.encryptionProtocol;
      final chatType = target.chatType;
      if (hasBody && !hasAttachments) {
        await _messageService.sendMessage(
          jid: jid,
          text: trimmedBody,
          encryptionProtocol: encryption,
          chatType: chatType,
        );
        return;
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
        if (updateUploads) {
          uploads[index] = resolvedUpload;
        }
      }
    }

    if (!hasAttachments) {
      await Future.wait(
        targets.map((target) => sendToTarget(target, updateUploads: false)),
      );
      return;
    }

    final firstTarget = targets.first;
    await sendToTarget(firstTarget, updateUploads: true);
    final remaining = targets.skip(1).toList();
    if (remaining.isEmpty) return;
    await Future.wait(
      remaining.map((target) => sendToTarget(target, updateUploads: false)),
    );
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

  void _throwIfFanOutFailed(FanOutSendReport report) {
    if (!report.hasFailures) {
      return;
    }
    throw const DraftSendValidationException(DraftSendFailureType.sendFailed);
  }

  List<Draft> _computeVisibleItems(List<Draft> items) {
    final snapshot = _searchSnapshot;
    var visibleItems = List<Draft>.from(items);
    if (snapshot.filterAttachmentsOnly) {
      visibleItems = visibleItems
          .where((draft) => draft.attachmentMetadataIds.isNotEmpty)
          .toList();
    }
    final query = snapshot.query;
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      visibleItems = visibleItems.where((draft) {
        final recipients = draft.jids.join(', ').toLowerCase();
        return recipients.contains(lower) ||
            (draft.body?.toLowerCase().contains(lower) ?? false) ||
            (draft.subject?.toLowerCase().contains(lower) ?? false);
      }).toList();
    }
    visibleItems.sort(
      (a, b) => snapshot.sortOrder.isNewestFirst
          ? b.id.compareTo(a.id)
          : a.id.compareTo(b.id),
    );
    return visibleItems;
  }

  List<Draft>? get _visibleItems {
    final items = _items;
    if (items == null) return null;
    return _computeVisibleItems(items);
  }

  DraftsAvailable _stateForItems(List<Draft> items) {
    return DraftsAvailable(
      items: items,
      visibleItems: _computeVisibleItems(items),
    );
  }
}
