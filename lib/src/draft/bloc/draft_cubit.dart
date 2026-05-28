// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'package:axichat/src/calendar/interop/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/draft_forwarded_content.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/models/fan_out_recipient_status.dart';
import 'package:axichat/src/email/models/fan_out_send_report.dart';
import 'package:axichat/src/email/service/attachment_bundle.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

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

enum DraftSendTransport { xmpp, email }

final class DraftSendOutcome {
  DraftSendOutcome._({
    required this.failureType,
    Set<DraftSendTransport> completedTransports = const {},
    Set<String> completedEmailRecipientKeys = const {},
    Map<String, FanOutRecipientState> latestEmailRecipientStatuses = const {},
  }) : completedTransports = Set.unmodifiable(completedTransports),
       completedEmailRecipientKeys = Set.unmodifiable(
         completedEmailRecipientKeys,
       ),
       latestEmailRecipientStatuses = Map.unmodifiable(
         latestEmailRecipientStatuses,
       );

  factory DraftSendOutcome.success({
    Set<DraftSendTransport> completedTransports = const {},
    Set<String> completedEmailRecipientKeys = const {},
    Map<String, FanOutRecipientState> latestEmailRecipientStatuses = const {},
  }) => DraftSendOutcome._(
    failureType: null,
    completedTransports: completedTransports,
    completedEmailRecipientKeys: completedEmailRecipientKeys,
    latestEmailRecipientStatuses: latestEmailRecipientStatuses,
  );

  factory DraftSendOutcome.failure({
    required DraftSendFailureType failureType,
    Set<DraftSendTransport> completedTransports = const {},
    Set<String> completedEmailRecipientKeys = const {},
    Map<String, FanOutRecipientState> latestEmailRecipientStatuses = const {},
  }) => DraftSendOutcome._(
    failureType: failureType,
    completedTransports: completedTransports,
    completedEmailRecipientKeys: completedEmailRecipientKeys,
    latestEmailRecipientStatuses: latestEmailRecipientStatuses,
  );

  final DraftSendFailureType? failureType;
  final Set<DraftSendTransport> completedTransports;
  final Set<String> completedEmailRecipientKeys;
  final Map<String, FanOutRecipientState> latestEmailRecipientStatuses;

  bool get succeeded => failureType == null;
}

final class _DraftEmailSendResult {
  const _DraftEmailSendResult({
    required this.completedRecipientKeys,
    required this.latestRecipientStatuses,
  });

  final Set<String> completedRecipientKeys;
  final Map<String, FanOutRecipientState> latestRecipientStatuses;

  bool get hasFailures => latestRecipientStatuses.values.any(
    (status) => status == FanOutRecipientState.failed,
  );
}

sealed class DraftSendValidationException implements Exception {
  const DraftSendValidationException();

  @override
  String toString() => runtimeType.toString();
}

final class DraftSendNoRecipientsException
    extends DraftSendValidationException {
  const DraftSendNoRecipientsException();
}

final class DraftSendNoContentException extends DraftSendValidationException {
  const DraftSendNoContentException();
}

final class DraftSendFailedException extends DraftSendValidationException {
  const DraftSendFailedException();
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
  static const String _calendarTaskIcsAttachmentMimeType = 'text/calendar';

  DraftCubit({
    required MessageService messageService,
    EmailService? emailService,
  }) : _messageService = messageService,
       _emailService = emailService,
       super(const DraftsAvailable(items: null, visibleItems: null)) {
    _draftsSubscription = _messageService.draftsStream().listen((items) {
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
    final next = change.nextState;
    if (next is DraftsAvailable) {
      cache[itemsCacheKey] = next.items;
      cache[visibleItemsCacheKey] = next.visibleItems;
      _items = next.items;
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

  Future<List<Attachment>> loadDraftAttachments(
    List<String> metadataIds,
  ) async {
    if (metadataIds.isEmpty) return const [];
    return _messageService.loadDraftAttachments(metadataIds);
  }

  Future<Attachment> optimizeAttachment(Attachment attachment) async {
    return EmailAttachmentOptimizer.optimize(attachment);
  }

  Future<void> deleteDraftAttachmentMetadata(String metadataId) async {
    await _messageService.deleteFileMetadata(metadataId);
  }

  Future<List<String>> cloneDraftAttachmentMetadata(
    Iterable<String> sourceMetadataIds,
  ) {
    return _messageService.cloneDraftAttachmentMetadata(sourceMetadataIds);
  }

  Future<Message?> loadMessageByReferenceId(
    String messageId, {
    String? chatJid,
  }) async {
    return _messageService.loadMessageByReferenceId(
      messageId,
      chatJid: chatJid,
    );
  }

  Future<DraftSendOutcome> sendDraft({
    required int? id,
    required List<DraftXmppTarget> xmppTargets,
    required List<Contact> emailTargets,
    required String body,
    required bool shareTokenSignatureEnabled,
    String? subject,
    DraftQuoteTarget? quoteTarget,
    List<Attachment> attachments = const [],
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    List<DraftForwardedBlock> forwardedBlocks = const <DraftForwardedBlock>[],
  }) async {
    emit(DraftSending(items: _items, visibleItems: _visibleItems));
    final completedTransports = <DraftSendTransport>{};
    final completedEmailRecipientKeys = <String>{};
    final latestEmailRecipientStatuses = <String, FanOutRecipientState>{};
    try {
      if (emailTargets.isEmpty && xmppTargets.isEmpty) {
        throw const DraftSendNoRecipientsException();
      }
      if (xmppTargets.isNotEmpty) {
        await _sendXmppDraft(
          targets: xmppTargets,
          body: body,
          subject: subject,
          quoteTarget: quoteTarget,
          attachments: attachments,
          calendarTaskIcsMessage: calendarTaskIcsMessage,
          forwardedBlocks: forwardedBlocks,
        );
        completedTransports.add(DraftSendTransport.xmpp);
      }
      if (emailTargets.isNotEmpty) {
        final emailResult = await _sendEmailDraft(
          targets: emailTargets,
          body: body,
          subject: subject,
          quoteTarget: quoteTarget,
          attachments: attachments,
          calendarTaskIcsMessage: calendarTaskIcsMessage,
          forwardedBlocks: forwardedBlocks,
          shareTokenSignatureEnabled: shareTokenSignatureEnabled,
        );
        completedEmailRecipientKeys.addAll(emailResult.completedRecipientKeys);
        latestEmailRecipientStatuses.addAll(
          emailResult.latestRecipientStatuses,
        );
        if (emailResult.hasFailures) {
          throw const DraftSendFailedException();
        }
        completedTransports.add(DraftSendTransport.email);
      }
    } on DraftSendValidationException catch (error) {
      emit(
        DraftFailure(
          _failureTypeFor(error),
          items: _items,
          visibleItems: _visibleItems,
        ),
      );
      return DraftSendOutcome.failure(
        failureType: _failureTypeFor(error),
        completedTransports: completedTransports,
        completedEmailRecipientKeys: completedEmailRecipientKeys,
        latestEmailRecipientStatuses: latestEmailRecipientStatuses,
      );
    } on FanOutValidationException {
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
        ),
      );
      return DraftSendOutcome.failure(
        failureType: DraftSendFailureType.sendFailed,
        completedTransports: completedTransports,
        completedEmailRecipientKeys: completedEmailRecipientKeys,
        latestEmailRecipientStatuses: latestEmailRecipientStatuses,
      );
    } on XmppMessageException catch (_) {
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
        ),
      );
      return DraftSendOutcome.failure(
        failureType: DraftSendFailureType.sendFailed,
        completedTransports: completedTransports,
        completedEmailRecipientKeys: completedEmailRecipientKeys,
        latestEmailRecipientStatuses: latestEmailRecipientStatuses,
      );
    } on Exception catch (_) {
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
        ),
      );
      return DraftSendOutcome.failure(
        failureType: DraftSendFailureType.sendFailed,
        completedTransports: completedTransports,
        completedEmailRecipientKeys: completedEmailRecipientKeys,
        latestEmailRecipientStatuses: latestEmailRecipientStatuses,
      );
    }
    if (id != null) {
      try {
        await deleteDraft(id: id);
      } on Exception {
        // Best-effort after a successful send; do not turn success into failure.
      }
    }
    emit(DraftSendComplete(items: _items, visibleItems: _visibleItems));
    return DraftSendOutcome.success(
      completedTransports: completedTransports,
      completedEmailRecipientKeys: completedEmailRecipientKeys,
      latestEmailRecipientStatuses: latestEmailRecipientStatuses,
    );
  }

  Future<Draft> saveDraft({
    required int? id,
    required List<String> jids,
    required String body,
    String? subject,
    DraftQuoteTarget? quoteTarget,
    List<Attachment> attachments = const [],
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    List<DraftForwardedBlock> forwardedBlocks = const <DraftForwardedBlock>[],
    bool autoSave = false,
    bool autosaveEnabled = true,
  }) async {
    final draft = await _messageService.saveDraft(
      id: id,
      jids: jids,
      body: body,
      subject: subject,
      quotingStanzaId: quoteTarget?.stanzaId,
      quotingReferenceKind: quoteTarget?.referenceKind,
      attachments: attachments,
      calendarTaskIcsMessage: calendarTaskIcsMessage,
      forwardedBlocks: forwardedBlocks,
      autosaveEnabled: autosaveEnabled,
    );
    try {
      await _emailService?.mirrorDraftForFallback(
        jids: jids,
        text: DraftForwardedContent.compose(
          introText: body,
          forwardedBlocks: forwardedBlocks,
        ).plainText,
        subject: subject,
        attachments: attachments,
      );
    } on Exception {
      // Best-effort: fallback mirroring should not fail local draft saves.
    }
    emit(
      DraftSaveComplete(
        items: _items,
        visibleItems: _visibleItems,
        autoSaved: autoSave,
      ),
    );
    return draft;
  }

  Future<void> updateDraftAutosaveEnabled({
    required int id,
    required bool enabled,
  }) {
    return _messageService.updateDraftAutosaveEnabled(id: id, enabled: enabled);
  }

  Future<void> deleteDraft({required int id}) async {
    final draft = await _loadDraft(id);
    await _messageService.deleteDraft(id: id);
    try {
      await _emailService?.clearMirroredDraftForFallback(
        draft?.jids ?? const [],
      );
    } on Exception {
      // Best-effort: core draft syncing should not block local deletes.
    }
  }

  Future<Draft?> _loadDraft(int id) async {
    return _messageService.loadDraft(id);
  }

  Future<int> countDrafts() async {
    return _messageService.countDrafts();
  }

  Future<_DraftEmailSendResult> _sendEmailDraft({
    required List<Contact> targets,
    required String body,
    String? subject,
    DraftQuoteTarget? quoteTarget,
    required List<Attachment> attachments,
    required CalendarTaskIcsMessage? calendarTaskIcsMessage,
    required List<DraftForwardedBlock> forwardedBlocks,
    required bool shareTokenSignatureEnabled,
  }) async {
    final emailService = _emailService;
    if (emailService == null) {
      throw StateError('EmailService unavailable for email draft send.');
    }
    if (targets.isEmpty) {
      throw const DraftSendNoRecipientsException();
    }
    final assembled = DraftForwardedContent.compose(
      introText: body,
      forwardedBlocks: forwardedBlocks,
    );
    final trimmedBody = assembled.plainText.trim();
    final hasSubject = subject?.trim().isNotEmpty == true;
    final hasCalendarTask = calendarTaskIcsMessage != null;
    if (!hasSubject &&
        trimmedBody.isEmpty &&
        attachments.isEmpty &&
        !hasCalendarTask) {
      throw const DraftSendNoContentException();
    }
    final calendarTaskAttachment = calendarTaskIcsMessage == null
        ? null
        : await _buildCalendarTaskEmailAttachment(calendarTaskIcsMessage);
    if (hasCalendarTask && calendarTaskAttachment == null) {
      throw const DraftSendFailedException();
    }
    final hasAttachments =
        attachments.isNotEmpty || calendarTaskAttachment != null;
    final htmlBody = assembled.htmlBody;
    final includeSignatureToken =
        shareTokenSignatureEnabled &&
        targets.every((target) => target.shareSignatureEnabled);
    final shareId = ShareTokenCodec.generateShareId();
    var activeTargets = targets.toList(growable: false);
    final completedRecipientKeys = <String>{};
    final latestRecipientStatuses = <String, FanOutRecipientState>{};

    Future<void> sendEmailUnit({
      String? body,
      String? htmlBody,
      Attachment? attachment,
      String? htmlCaption,
    }) async {
      if (activeTargets.isEmpty) {
        return;
      }
      final report = await emailService.fanOutSend(
        targets: activeTargets,
        body: body,
        htmlBody: htmlBody,
        attachment: attachment,
        htmlCaption: htmlCaption,
        subject: subject,
        quotedStanzaId: quoteTarget?.stanzaId,
        shareId: shareId,
        useSubjectToken: includeSignatureToken,
        tokenAsSignature: includeSignatureToken,
      );
      final statuses = _fanOutStatusesByTargetKey(
        targets: activeTargets,
        report: report,
      );
      for (final target in activeTargets) {
        final status = statuses[target.key] ?? FanOutRecipientState.failed;
        _addEmailRecipientStatus(
          latestRecipientStatuses,
          target: target,
          status: status,
        );
      }
      activeTargets = activeTargets
          .where((target) => statuses[target.key] == FanOutRecipientState.sent)
          .toList(growable: false);
    }

    final shouldSendBodyOnly =
        (trimmedBody.isNotEmpty || hasSubject) && !hasAttachments;
    if (shouldSendBodyOnly) {
      await sendEmailUnit(body: trimmedBody, htmlBody: htmlBody);
    }
    final caption = trimmedBody.isNotEmpty ? trimmedBody : null;
    final htmlCaption = caption == null ? null : htmlBody;
    var captionAppliedToAttachment = false;
    if (attachments.isNotEmpty) {
      final bool shouldBundle =
          attachments.length >= _emailAttachmentBundleMinimumCount;
      final attachmentsToSend = await _bundleEmailAttachments(
        attachments: attachments,
        caption: caption,
      );
      try {
        for (var index = 0; index < attachmentsToSend.length; index += 1) {
          final attachment = attachmentsToSend[index];
          final shouldApplyCaption = index == 0 && caption != null;
          final captionedAttachment = shouldApplyCaption
              ? attachment.copyWith(caption: caption)
              : attachment;
          if (shouldApplyCaption) {
            captionAppliedToAttachment = true;
          }
          await sendEmailUnit(
            attachment: captionedAttachment,
            htmlCaption: shouldApplyCaption ? htmlCaption : null,
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
    if (calendarTaskAttachment != null) {
      final shouldApplyCaption = caption != null && !captionAppliedToAttachment;
      await sendEmailUnit(
        attachment: shouldApplyCaption
            ? calendarTaskAttachment.copyWith(caption: caption)
            : calendarTaskAttachment,
        htmlCaption: shouldApplyCaption ? htmlCaption : null,
      );
    }
    for (final target in activeTargets) {
      completedRecipientKeys.addAll(_emailRecipientLookupKeys(target));
    }
    return _DraftEmailSendResult(
      completedRecipientKeys: completedRecipientKeys,
      latestRecipientStatuses: latestRecipientStatuses,
    );
  }

  Future<void> _sendXmppDraft({
    required List<DraftXmppTarget> targets,
    required String body,
    String? subject,
    DraftQuoteTarget? quoteTarget,
    required List<Attachment> attachments,
    required CalendarTaskIcsMessage? calendarTaskIcsMessage,
    required List<DraftForwardedBlock> forwardedBlocks,
  }) async {
    final assembled = DraftForwardedContent.compose(
      introText: body,
      forwardedBlocks: forwardedBlocks,
    );
    final trimmedBody = ChatSubjectCodec.composeXmppBody(
      body: assembled.plainText,
      subject: subject,
    ).trim();
    final htmlBody = assembled.htmlBody;
    final hasBody = trimmedBody.isNotEmpty;
    final hasAttachments = attachments.isNotEmpty;
    final hasCalendarTask = calendarTaskIcsMessage != null;
    if (!hasBody && !hasAttachments && !hasCalendarTask) {
      throw const DraftSendNoContentException();
    }
    if (targets.isEmpty) {
      throw const DraftSendNoRecipientsException();
    }
    final attachmentGroupId = hasAttachments && attachments.length > 1
        ? uuid.v4()
        : null;
    final groupQuotedReference = attachmentGroupId == null || hasCalendarTask
        ? null
        : quoteTarget?.messageReference;
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
      if (!hasAttachments || hasCalendarTask) {
        await _messageService.sendMessage(
          jid: jid,
          text: trimmedBody,
          htmlBody: htmlBody,
          encryptionProtocol: encryption,
          quotedReference: quoteTarget?.messageReference,
          chatType: chatType,
          calendarTaskIcs: calendarTaskIcsMessage?.task,
          calendarTaskIcsReadOnly: CalendarTaskIcsMessage.defaultReadOnly,
        );
        if (!hasAttachments) {
          return;
        }
      }
      for (var index = 0; index < attachments.length; index += 1) {
        final attachment = attachments[index];
        final shouldApplyCaption = hasBody && !hasCalendarTask && index == 0;
        final quotedReference = !hasCalendarTask && index == 0
            ? quoteTarget?.messageReference
            : null;
        final resolvedAttachment = shouldApplyCaption
            ? attachment.copyWith(caption: trimmedBody)
            : attachment;
        final upload = uploads[index];
        final resolvedUpload = await _messageService.sendAttachment(
          jid: jid,
          attachment: resolvedAttachment,
          encryptionProtocol: encryption,
          chatType: chatType,
          quotedReference: quotedReference,
          groupQuotedReference: groupQuotedReference,
          htmlCaption: shouldApplyCaption ? htmlBody : null,
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

  Future<List<Attachment>> _bundleEmailAttachments({
    required List<Attachment> attachments,
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

  Future<Attachment?> _buildCalendarTaskEmailAttachment(
    CalendarTaskIcsMessage message,
  ) async {
    try {
      const transferService = CalendarTransferService();
      final file = await transferService.exportTaskIcs(task: message.task);
      CalendarTransferService.scheduleCleanup(file);
      return Attachment(
        path: file.path,
        fileName: p.basename(file.path),
        sizeBytes: await File(file.path).length(),
        mimeType: _calendarTaskIcsAttachmentMimeType,
      );
    } on Exception {
      return null;
    }
  }

  Map<String, FanOutRecipientState> _fanOutStatusesByTargetKey({
    required List<Contact> targets,
    required FanOutSendReport report,
  }) {
    final statuses = <String, FanOutRecipientState>{};
    if (report.statuses.isEmpty && !report.hasFailures) {
      for (final target in targets) {
        statuses[target.key] = FanOutRecipientState.sent;
      }
      return statuses;
    }
    for (final target in targets) {
      statuses[target.key] = _fanOutStatusForTarget(
        target: target,
        statuses: report.statuses,
      );
    }
    return statuses;
  }

  FanOutRecipientState _fanOutStatusForTarget({
    required Contact target,
    required List<FanOutRecipientStatus> statuses,
  }) {
    FanOutRecipientState? resolved;
    for (final status in statuses) {
      if (!_fanOutStatusMatchesTarget(target: target, status: status)) {
        continue;
      }
      if (status.state == FanOutRecipientState.failed) {
        return FanOutRecipientState.failed;
      }
      resolved ??= status.state;
    }
    return resolved ?? FanOutRecipientState.failed;
  }

  bool _fanOutStatusMatchesTarget({
    required Contact target,
    required FanOutRecipientStatus status,
  }) {
    final targetKeys = _emailRecipientLookupKeys(target);
    if (targetKeys.isEmpty) {
      return false;
    }
    final statusKeys = _emailChatLookupKeys(status.chat);
    for (final key in targetKeys) {
      if (statusKeys.contains(key)) {
        return true;
      }
    }
    return false;
  }

  Set<String> _emailRecipientLookupKeys(Contact target) {
    final keys = <String>{};
    _addLookupKey(keys, target.key);
    for (final key in target.statusLookupKeys) {
      _addLookupKey(keys, key);
    }
    return keys;
  }

  Set<String> _emailChatLookupKeys(Chat chat) {
    final keys = <String>{};
    _addLookupKey(keys, chat.jid);
    for (final key in chat.normalizedIdentityKeys) {
      _addLookupKey(keys, key);
    }
    return keys;
  }

  void _addEmailRecipientStatus(
    Map<String, FanOutRecipientState> statuses, {
    required Contact target,
    required FanOutRecipientState status,
  }) {
    for (final key in _emailRecipientLookupKeys(target)) {
      statuses[key] = status;
    }
  }

  void _addLookupKey(Set<String> keys, String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return;
    }
    keys.add(value);
    final normalized = normalizedAddressValue(value);
    if (normalized != null && normalized.isNotEmpty) {
      keys.add(normalized);
    }
  }

  DraftSendFailureType _failureTypeFor(DraftSendValidationException error) =>
      switch (error) {
        DraftSendNoRecipientsException() => DraftSendFailureType.noRecipients,
        DraftSendNoContentException() => DraftSendFailureType.noContent,
        DraftSendFailedException() => DraftSendFailureType.sendFailed,
      };

  List<Draft> _computeVisibleItems(List<Draft> items) {
    final snapshot = _searchSnapshot;
    var visibleItems = List<Draft>.from(items);
    if (snapshot.filterAttachmentsOnly) {
      visibleItems = visibleItems
          .where((draft) => draft.hasAttachments)
          .toList();
    }
    final query = snapshot.query;
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      visibleItems = visibleItems
          .where((draft) => draft.matchesSearchQuery(lower))
          .toList();
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
