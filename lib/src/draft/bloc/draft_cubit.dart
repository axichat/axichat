// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'package:axichat/src/calendar/interop/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/draft_forwarded_content.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
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

final class DraftSendOutcome {
  DraftSendOutcome._({
    required this.status,
    required this.failureType,
    Set<ComposerRecipientKey> incompleteRecipients = const {},
    Map<ComposerRecipientKey, SendRecipientOutcome> recipientOutcomes =
        const {},
    Map<ComposerRecipientKey, FanOutRecipientState>
        latestEmailRecipientStatuses =
        const {},
    this.resendMayDuplicate = false,
  }) : incompleteRecipients = Set.unmodifiable(incompleteRecipients),
       recipientOutcomes = Map.unmodifiable(recipientOutcomes),
       latestEmailRecipientStatuses = Map.unmodifiable(
         latestEmailRecipientStatuses,
       );

  factory DraftSendOutcome.completed({
    Map<ComposerRecipientKey, SendRecipientOutcome> recipientOutcomes =
        const {},
    Map<ComposerRecipientKey, FanOutRecipientState>
        latestEmailRecipientStatuses =
        const {},
  }) => DraftSendOutcome._(
    status: ComposerSendOutcomeStatus.completed,
    failureType: null,
    recipientOutcomes: recipientOutcomes,
    latestEmailRecipientStatuses: latestEmailRecipientStatuses,
  );

  factory DraftSendOutcome.blocked({
    required DraftSendFailureType failureType,
    Map<ComposerRecipientKey, SendRecipientOutcome> recipientOutcomes =
        const {},
    Map<ComposerRecipientKey, FanOutRecipientState>
        latestEmailRecipientStatuses =
        const {},
  }) => DraftSendOutcome._(
    status: ComposerSendOutcomeStatus.blocked,
    failureType: failureType,
    recipientOutcomes: recipientOutcomes,
    latestEmailRecipientStatuses: latestEmailRecipientStatuses,
  );

  factory DraftSendOutcome.incomplete({
    required DraftSendFailureType failureType,
    required Set<ComposerRecipientKey> incompleteRecipients,
    Map<ComposerRecipientKey, SendRecipientOutcome> recipientOutcomes =
        const {},
    Map<ComposerRecipientKey, FanOutRecipientState>
        latestEmailRecipientStatuses =
        const {},
    bool resendMayDuplicate = false,
  }) => DraftSendOutcome._(
    status: ComposerSendOutcomeStatus.incomplete,
    failureType: failureType,
    incompleteRecipients: incompleteRecipients,
    recipientOutcomes: recipientOutcomes,
    latestEmailRecipientStatuses: latestEmailRecipientStatuses,
    resendMayDuplicate: resendMayDuplicate,
  );

  final ComposerSendOutcomeStatus status;
  final DraftSendFailureType? failureType;
  final Set<ComposerRecipientKey> incompleteRecipients;
  final Map<ComposerRecipientKey, SendRecipientOutcome> recipientOutcomes;
  final Map<ComposerRecipientKey, FanOutRecipientState>
  latestEmailRecipientStatuses;
  final bool resendMayDuplicate;

  bool get succeeded => status == ComposerSendOutcomeStatus.completed;
  bool get blocked => status == ComposerSendOutcomeStatus.blocked;
  bool get incomplete => status == ComposerSendOutcomeStatus.incomplete;
}

final class _DraftEmailSendResult {
  const _DraftEmailSendResult({
    required this.completedRecipientKeys,
    required this.latestRecipientStatuses,
  });

  final Set<ComposerRecipientKey> completedRecipientKeys;
  final Map<ComposerRecipientKey, FanOutRecipientState> latestRecipientStatuses;

  bool get hasFailures => latestRecipientStatuses.values.any(
    (status) => status == FanOutRecipientState.failed,
  );
}

final class _DraftXmppSendResult {
  const _DraftXmppSendResult({
    required this.completedRecipientKeys,
    required this.hasFailures,
  });

  final Set<ComposerRecipientKey> completedRecipientKeys;
  final bool hasFailures;
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
  final Set<String> _sendingOwnerIds = <String>{};
  DraftSearchSnapshot _searchSnapshot = const DraftSearchSnapshot(
    query: '',
    filterAttachmentsOnly: false,
    sortOrder: DraftSortOrder.newestFirst,
  );

  late final StreamSubscription<List<Draft>> _draftsSubscription;

  Set<String> get _sendingOwnerSnapshot =>
      Set<String>.unmodifiable(_sendingOwnerIds);

  bool isSendOwnerActive(String ownerId) => _sendingOwnerIds.contains(ownerId);

  bool beginSendPreparation(String ownerId) {
    if (_sendingOwnerIds.contains(ownerId)) {
      return false;
    }
    _sendingOwnerIds.add(ownerId);
    emit(
      DraftSending(
        items: _items,
        visibleItems: _visibleItems,
        sendingOwnerIds: _sendingOwnerSnapshot,
        ownerId: ownerId,
        preparing: true,
      ),
    );
    return true;
  }

  void cancelSendPreparation(String ownerId) {
    if (!_sendingOwnerIds.remove(ownerId)) {
      return;
    }
    emit(_currentLifecycleState());
  }

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
    required List<XmppRecipientIntent> xmppTargets,
    required List<EmailRecipientIntent> emailTargets,
    required String body,
    required bool shareTokenSignatureEnabled,
    String? ownerId,
    String? subject,
    DraftQuoteTarget? quoteTarget,
    List<Attachment> attachments = const [],
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    List<DraftForwardedBlock> forwardedBlocks = const <DraftForwardedBlock>[],
  }) async {
    final submittedRecipientKeys = <ComposerRecipientKey>{
      ...xmppTargets.map((target) => target.recipientKey),
      ...emailTargets.map((target) => target.recipientKey),
    };
    final sendProgress = ComposerSendProgress(submittedRecipientKeys);
    final safeFailedOnlyRetry = _isSafeDraftFailedOnlyRetry(
      xmppTargets: xmppTargets,
      emailTargets: emailTargets,
      attachments: attachments,
      calendarTaskIcsMessage: calendarTaskIcsMessage,
    );
    final latestEmailRecipientStatuses =
        <ComposerRecipientKey, FanOutRecipientState>{};
    var xmppAttempted = false;
    var emailAttempted = false;

    void markOwnerNotSending() {
      if (ownerId != null) {
        _sendingOwnerIds.remove(ownerId);
      }
    }

    DraftSendOutcome blockedOrIncomplete(DraftSendFailureType failureType) {
      if (xmppAttempted) {
        sendProgress.markMissingAs(
          xmppTargets.map((target) => target.recipientKey),
          SendRecipientOutcome.failed,
        );
      }
      if (emailAttempted) {
        sendProgress.markMissingAs(
          emailTargets.map((target) => target.recipientKey),
          SendRecipientOutcome.failed,
        );
      }
      final incompleteRecipients = sendProgress.incompleteKeys;
      final recipientOutcomes = sendProgress.outcomes;
      if (failureType == DraftSendFailureType.sendFailed ||
          sendProgress.completedKeys.isNotEmpty) {
        return DraftSendOutcome.incomplete(
          failureType: failureType,
          incompleteRecipients: incompleteRecipients,
          recipientOutcomes: recipientOutcomes,
          latestEmailRecipientStatuses: latestEmailRecipientStatuses,
          resendMayDuplicate:
              failureType == DraftSendFailureType.sendFailed &&
              !safeFailedOnlyRetry &&
              incompleteRecipients.isNotEmpty,
        );
      }
      return DraftSendOutcome.blocked(
        failureType: failureType,
        recipientOutcomes: recipientOutcomes,
        latestEmailRecipientStatuses: latestEmailRecipientStatuses,
      );
    }

    if (emailTargets.isEmpty && xmppTargets.isEmpty) {
      markOwnerNotSending();
      emit(
        DraftFailure(
          DraftSendFailureType.noRecipients,
          items: _items,
          visibleItems: _visibleItems,
          sendingOwnerIds: _sendingOwnerSnapshot,
          ownerId: ownerId,
        ),
      );
      return blockedOrIncomplete(DraftSendFailureType.noRecipients);
    }
    final assembled = DraftForwardedContent.compose(
      introText: body,
      forwardedBlocks: forwardedBlocks,
    );
    final hasSubject = subject?.trim().isNotEmpty == true;
    final hasBody = assembled.plainText.trim().isNotEmpty;
    if (!hasSubject &&
        !hasBody &&
        attachments.isEmpty &&
        calendarTaskIcsMessage == null) {
      markOwnerNotSending();
      emit(
        DraftFailure(
          DraftSendFailureType.noContent,
          items: _items,
          visibleItems: _visibleItems,
          sendingOwnerIds: _sendingOwnerSnapshot,
          ownerId: ownerId,
        ),
      );
      return blockedOrIncomplete(DraftSendFailureType.noContent);
    }

    if (ownerId != null) {
      _sendingOwnerIds.add(ownerId);
    }
    emit(
      DraftSending(
        items: _items,
        visibleItems: _visibleItems,
        sendingOwnerIds: _sendingOwnerSnapshot,
        ownerId: ownerId,
      ),
    );

    var sendAttemptHandled = false;
    try {
      if (xmppTargets.isNotEmpty) {
        xmppAttempted = true;
        final xmppResult = await _sendXmppDraft(
          targets: xmppTargets,
          body: body,
          subject: subject,
          quoteTarget: quoteTarget,
          attachments: attachments,
          calendarTaskIcsMessage: calendarTaskIcsMessage,
          forwardedBlocks: forwardedBlocks,
        );
        sendProgress.markCompletedAll(xmppResult.completedRecipientKeys);
        if (xmppResult.hasFailures) {
          throw const DraftSendFailedException();
        }
      }
      if (emailTargets.isNotEmpty) {
        emailAttempted = true;
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
        latestEmailRecipientStatuses.addAll(
          emailResult.latestRecipientStatuses,
        );
        for (final target in emailTargets) {
          if (emailResult.completedRecipientKeys.contains(
            target.recipientKey,
          )) {
            sendProgress.markCompleted(target.recipientKey);
          } else if (latestEmailRecipientStatuses[target.recipientKey] ==
              FanOutRecipientState.failed) {
            sendProgress.markFailed(target.recipientKey);
          }
        }
        if (emailResult.hasFailures) {
          throw const DraftSendFailedException();
        }
      }
      sendAttemptHandled = true;
    } on DraftSendValidationException catch (error) {
      sendAttemptHandled = true;
      markOwnerNotSending();
      emit(
        DraftFailure(
          _failureTypeFor(error),
          items: _items,
          visibleItems: _visibleItems,
          sendingOwnerIds: _sendingOwnerSnapshot,
          ownerId: ownerId,
        ),
      );
      return blockedOrIncomplete(_failureTypeFor(error));
    } on FanOutValidationException {
      sendAttemptHandled = true;
      markOwnerNotSending();
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
          sendingOwnerIds: _sendingOwnerSnapshot,
          ownerId: ownerId,
        ),
      );
      return blockedOrIncomplete(DraftSendFailureType.sendFailed);
    } on EmailAttachmentBundleException {
      sendAttemptHandled = true;
      markOwnerNotSending();
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
          sendingOwnerIds: _sendingOwnerSnapshot,
          ownerId: ownerId,
        ),
      );
      return blockedOrIncomplete(DraftSendFailureType.sendFailed);
    } on EmailProvisioningException {
      sendAttemptHandled = true;
      markOwnerNotSending();
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
          sendingOwnerIds: _sendingOwnerSnapshot,
          ownerId: ownerId,
        ),
      );
      return blockedOrIncomplete(DraftSendFailureType.sendFailed);
    } on EmailServiceException {
      sendAttemptHandled = true;
      markOwnerNotSending();
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
          sendingOwnerIds: _sendingOwnerSnapshot,
          ownerId: ownerId,
        ),
      );
      return blockedOrIncomplete(DraftSendFailureType.sendFailed);
    } on XmppMessageException catch (_) {
      sendAttemptHandled = true;
      markOwnerNotSending();
      emit(
        DraftFailure(
          DraftSendFailureType.sendFailed,
          items: _items,
          visibleItems: _visibleItems,
          sendingOwnerIds: _sendingOwnerSnapshot,
          ownerId: ownerId,
        ),
      );
      return blockedOrIncomplete(DraftSendFailureType.sendFailed);
    } finally {
      if (!sendAttemptHandled) {
        markOwnerNotSending();
        emit(_currentLifecycleState());
      }
    }
    if (id != null) {
      try {
        await deleteDraft(id: id);
      } on Exception {
        // Best-effort after a successful send; do not turn success into failure.
      }
    }
    markOwnerNotSending();
    emit(
      DraftSendComplete(
        items: _items,
        visibleItems: _visibleItems,
        sendingOwnerIds: _sendingOwnerSnapshot,
        ownerId: ownerId,
      ),
    );
    return DraftSendOutcome.completed(
      recipientOutcomes: sendProgress.outcomes,
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
    bool autosaveEnabled = false,
  }) async {
    final draft = await _messageService.saveDraft(
      id: id,
      jids: jids,
      body: body,
      subject: subject,
      quotingStanzaId: quoteTarget?.stanzaId,
      quotingReferenceKind: null,
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
        sendingOwnerIds: _sendingOwnerSnapshot,
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

  bool _isSafeDraftFailedOnlyRetry({
    required List<XmppRecipientIntent> xmppTargets,
    required List<EmailRecipientIntent> emailTargets,
    required List<Attachment> attachments,
    required CalendarTaskIcsMessage? calendarTaskIcsMessage,
  }) {
    if (calendarTaskIcsMessage != null) {
      return false;
    }
    if (xmppTargets.isNotEmpty && emailTargets.isNotEmpty) {
      return false;
    }
    if (emailTargets.isNotEmpty) {
      return attachments.isEmpty ||
          attachments.length == 1 ||
          attachments.length >= _emailAttachmentBundleMinimumCount;
    }
    if (xmppTargets.isNotEmpty) {
      return attachments.isEmpty || attachments.length == 1;
    }
    return false;
  }

  Future<_DraftEmailSendResult> _sendEmailDraft({
    required List<EmailRecipientIntent> targets,
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
    final hasAttachments =
        attachments.isNotEmpty || calendarTaskAttachment != null;
    final htmlBody = assembled.htmlBody;
    final includeSignatureToken =
        shareTokenSignatureEnabled &&
        targets.every((target) => target.shareSignatureEnabled);
    final shareId = ShareTokenCodec.generateShareId();
    var activeTargets = targets.toList(growable: false);
    final completedRecipientKeys = <ComposerRecipientKey>{};
    final latestRecipientStatuses =
        <ComposerRecipientKey, FanOutRecipientState>{};

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
      final statuses = report.statusesByTargetKey(activeTargets);
      for (final target in activeTargets) {
        final status =
            statuses[target.recipientKey] ?? FanOutRecipientState.failed;
        latestRecipientStatuses[target.recipientKey] = status;
      }
      activeTargets = activeTargets
          .where(
            (target) =>
                statuses[target.recipientKey] == FanOutRecipientState.sent,
          )
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
      completedRecipientKeys.add(target.recipientKey);
    }
    return _DraftEmailSendResult(
      completedRecipientKeys: completedRecipientKeys,
      latestRecipientStatuses: latestRecipientStatuses,
    );
  }

  Future<_DraftXmppSendResult> _sendXmppDraft({
    required List<XmppRecipientIntent> targets,
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
    final groupQuotedStanzaId = attachmentGroupId == null || hasCalendarTask
        ? null
        : quoteTarget?.stanzaId;
    final uploads = List<XmppAttachmentUpload?>.filled(
      attachments.length,
      null,
    );

    Future<void> sendToTarget(
      XmppRecipientIntent target, {
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
          quotedStanzaId: quoteTarget?.stanzaId,
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
        final quotedStanzaId = !hasCalendarTask && index == 0
            ? quoteTarget?.stanzaId
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
          quotedStanzaId: quotedStanzaId,
          groupQuotedStanzaId: groupQuotedStanzaId,
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

    final completedRecipientKeys = <ComposerRecipientKey>{};
    var hasFailures = false;

    Future<bool> trySendToTarget(
      XmppRecipientIntent target, {
      required bool updateUploads,
    }) async {
      try {
        await sendToTarget(target, updateUploads: updateUploads);
        completedRecipientKeys.add(target.recipientKey);
        return true;
      } on XmppMessageException {
        hasFailures = true;
        return false;
      }
    }

    if (!hasAttachments) {
      await Future.wait(
        targets.map((target) => trySendToTarget(target, updateUploads: false)),
      );
      return _DraftXmppSendResult(
        completedRecipientKeys: completedRecipientKeys,
        hasFailures: hasFailures,
      );
    }

    final pendingTargets = targets.toList();
    var uploadsReady = false;
    while (pendingTargets.isNotEmpty && !uploadsReady) {
      final target = pendingTargets.removeAt(0);
      uploadsReady = await trySendToTarget(target, updateUploads: true);
    }
    if (pendingTargets.isNotEmpty) {
      await Future.wait(
        pendingTargets.map(
          (target) => trySendToTarget(target, updateUploads: false),
        ),
      );
    }
    return _DraftXmppSendResult(
      completedRecipientKeys: completedRecipientKeys,
      hasFailures: hasFailures,
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

  Future<Attachment> _buildCalendarTaskEmailAttachment(
    CalendarTaskIcsMessage message,
  ) async {
    const transferService = CalendarTransferService();
    final file = await transferService.exportTaskIcs(task: message.task);
    CalendarTransferService.scheduleCleanup(file);
    return Attachment(
      path: file.path,
      fileName: p.basename(file.path),
      sizeBytes: await File(file.path).length(),
      mimeType: _calendarTaskIcsAttachmentMimeType,
    );
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

  DraftsAvailable _currentAvailableState() {
    return DraftsAvailable(
      items: _items,
      visibleItems: _visibleItems,
      sendingOwnerIds: _sendingOwnerSnapshot,
    );
  }

  DraftState _currentLifecycleState() {
    if (_sendingOwnerIds.isEmpty) {
      return _currentAvailableState();
    }
    return DraftSending(
      items: _items,
      visibleItems: _visibleItems,
      sendingOwnerIds: _sendingOwnerSnapshot,
      ownerId: null,
      preparing: true,
    );
  }

  DraftsAvailable _stateForItems(List<Draft> items) {
    return DraftsAvailable(
      items: items,
      visibleItems: _computeVisibleItems(items),
      sendingOwnerIds: _sendingOwnerSnapshot,
    );
  }
}
