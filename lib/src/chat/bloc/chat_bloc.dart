// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:async/async.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_eligibility.dart';
import 'package:axichat/src/calendar/interop/chat_calendar_support.dart';
import 'package:axichat/src/calendar/interop/calendar_snapshot_metadata.dart';
import 'package:axichat/src/calendar/interop/calendar_transfer_service.dart';
import 'package:axichat/src/chat/models/chat_message.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/models/pinned_message_item.dart';
import 'package:axichat/src/chat/models/rfc_email_group.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/attachment_import_source.dart';
import 'package:axichat/src/common/composer_attachment_staging.dart';
import 'package:axichat/src/common/event_transform.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/demo/demo_chats.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/service/attachment_bundle.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/models/fan_out_send_report.dart';
import 'package:axichat/src/email/models/share_context.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/notification_payload.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:path/path.dart' as p;
import 'package:stream_transform/stream_transform.dart';

part 'chat_bloc.freezed.dart';

part 'chat_event.dart';

part 'chat_state.dart';

const int _emailAttachmentBundleMinimumCount = 2;
const _calendarTaskIcsAttachmentMimeType = 'text/calendar';
const _calendarTaskIcsAttachmentSendFailureLogMessage =
    'Failed to send calendar task attachment';
const _sendSignatureSeparator = '::';
const _sendSignatureSubjectTag = '::subject:';
const _sendSignatureAttachmentTag = '::attachments:';
const _sendSignatureCalendarTaskTag = '::calendar_task:';
const _sendSignatureQuoteTag = '::quote:';
const _sendSignatureListSeparator = ',';
const _sendSignatureAttachmentFieldSeparator = '|';
const _emptySignatureValue = '';
const int _deltaMessageIdUnset = 0;
const _bundledAttachmentSendFailureLogMessage =
    'Failed to send bundled email attachment';

const _pinSyncFailedLogMessage = 'Failed to sync pinned messages.';
const _roomAvatarUpdateFailedLogMessage = 'Failed to update room avatar.';
const _roomAffiliationRefreshFailedLogMessage =
    'Failed to refresh room affiliations.';
const _mamLoadFailedLogMessage = 'Failed to load older MAM page.';
const _mamCatchUpFailedLogMessage = 'Failed to catch up via MAM.';
const _viewFilterLoadFailedLogMessage = 'Failed to load view filter.';
const _mamHydrateFailedLogMessage = 'Failed to hydrate MAM for chat.';
const _mucMembershipFailedLogMessage = 'Failed to ensure membership.';
const _roomStateWarmFailedLogMessage = 'Failed to warm room state.';
const _contactRenameFailedLogMessage = 'Failed to rename contact.';
const _sendEmailMessageFailedLogMessage = 'Failed to send email message.';
const _sendMessageFailedLogMessage = 'Failed to send message.';
const _messageReactionFailedLogMessage = 'Failed to react to message.';
const _messageResendFailedLogMessage = 'Failed to resend message.';
const _emailResendFailedLogMessage = 'Failed to resend email message.';
const _attachmentSendFailedLogMessage = 'Failed to send attachment.';
const _xmppAttachmentSendFailedLogMessage = 'Failed to send XMPP attachment.';
const _xmppDraftSaveFailedLogMessage = 'Failed to save XMPP draft.';
const int _pinnedMessagesFetchPageLimit = 4;
const _emptyPinnedMessageItems = <PinnedMessageItem>[];
const _emptyPinnedAttachmentIds = <String>[];
const _emptyShareReplies = <String, List<Chat>>{};

EventTransformer<ChatMessageResendRequested> _dedupeConcurrentResendRequests() {
  final activeStanzaIds = <String>{};
  return (events, mapper) => events
      .where((event) {
        final stanzaId = event.message.stanzaID.trim();
        if (stanzaId.isEmpty) {
          return true;
        }
        if (activeStanzaIds.contains(stanzaId)) {
          return false;
        }
        activeStanzaIds.add(stanzaId);
        return true;
      })
      .concurrentAsyncExpand((event) async* {
        final stanzaId = event.message.stanzaID.trim();
        try {
          yield* mapper(event);
        } finally {
          if (stanzaId.isNotEmpty) {
            activeStanzaIds.remove(stanzaId);
          }
        }
      });
}

EventTransformer<ChatMessageSent> _dedupeConcurrentChatMessageSends() {
  var sendInFlight = false;
  return (events, mapper) => events
      .where((event) {
        if (!sendInFlight) {
          sendInFlight = true;
          return true;
        }
        final completer = event.completer;
        if (completer != null && !completer.isCompleted) {
          completer.complete(
            ChatSendOutcome.blocked(
              message: ChatMessageKey.chatComposerSendFailed,
              pendingAttachments: List<PendingAttachment>.from(
                event.pendingAttachments,
              ),
            ),
          );
        }
        return false;
      })
      .concurrentAsyncExpand((event) async* {
        try {
          yield* mapper(event);
        } finally {
          sendInFlight = false;
        }
      });
}

class FanOutDraft extends Equatable {
  const FanOutDraft({
    this.body,
    this.attachment,
    required this.shareId,
    this.subject,
    this.quotedStanzaId,
  });

  final String? body;
  final Attachment? attachment;
  final String shareId;
  final String? subject;
  final String? quotedStanzaId;

  @override
  List<Object?> get props => [
    body,
    attachment,
    shareId,
    subject,
    quotedStanzaId,
  ];
}

final class _ChatXmppSendResult {
  const _ChatXmppSendResult({
    required this.completedRecipientKeys,
    required this.hasFailures,
    this.submittedAttachments = const <PendingAttachment>[],
  });

  final Set<ComposerRecipientKey> completedRecipientKeys;
  final bool hasFailures;
  final List<PendingAttachment> submittedAttachments;
}

final class _ChatEmailSendUnitResult {
  const _ChatEmailSendUnitResult({
    required this.succeeded,
    this.recipientStatuses =
        const <ComposerRecipientKey, FanOutRecipientState>{},
  });

  final bool succeeded;
  final Map<ComposerRecipientKey, FanOutRecipientState> recipientStatuses;
}

final class _EmailQuotedTextHydrationResult {
  const _EmailQuotedTextHydrationResult({
    required this.message,
    required this.deltaMessageId,
    required this.stopwatch,
    required this.result,
    this.quotedText,
    this.unavailable = false,
  });

  final Message message;
  final int deltaMessageId;
  final Stopwatch stopwatch;
  final String result;
  final String? quotedText;
  final bool unavailable;
}

enum ChatToastVariant { info, warning, destructive }

enum ChatToastAction { restoreDraft }

class ChatToast extends Equatable {
  const ChatToast({
    this.title,
    this.message,
    this.messageText,
    this.messageActionLabel,
    this.messageTargetLabel,
    this.variant = ChatToastVariant.info,
    this.action,
    this.actionDraftId,
  });

  final String? title;
  final ChatMessageKey? message;
  final String? messageText;
  final String? messageActionLabel;
  final String? messageTargetLabel;
  final ChatToastVariant variant;
  final ChatToastAction? action;
  final int? actionDraftId;

  bool get isDestructive => variant == ChatToastVariant.destructive;

  @override
  List<Object?> get props => [
    title,
    message,
    messageText,
    messageActionLabel,
    messageTargetLabel,
    variant,
    action,
    actionDraftId,
  ];
}

class ChatSettingsSnapshot extends Equatable {
  const ChatSettingsSnapshot({
    required this.language,
    required this.chatReadReceipts,
    required this.emailReadReceipts,
    required this.shareTokenSignatureEnabled,
    required this.autoDownloadImages,
    required this.autoDownloadVideos,
    required this.autoDownloadDocuments,
    required this.autoDownloadArchives,
  });

  final AppLanguage language;
  final bool chatReadReceipts;
  final bool emailReadReceipts;
  final bool shareTokenSignatureEnabled;
  final bool autoDownloadImages;
  final bool autoDownloadVideos;
  final bool autoDownloadDocuments;
  final bool autoDownloadArchives;

  ChatSettingsSnapshot copyWith({
    AppLanguage? language,
    bool? chatReadReceipts,
    bool? emailReadReceipts,
    bool? shareTokenSignatureEnabled,
    bool? autoDownloadImages,
    bool? autoDownloadVideos,
    bool? autoDownloadDocuments,
    bool? autoDownloadArchives,
  }) => ChatSettingsSnapshot(
    language: language ?? this.language,
    chatReadReceipts: chatReadReceipts ?? this.chatReadReceipts,
    emailReadReceipts: emailReadReceipts ?? this.emailReadReceipts,
    shareTokenSignatureEnabled:
        shareTokenSignatureEnabled ?? this.shareTokenSignatureEnabled,
    autoDownloadImages: autoDownloadImages ?? this.autoDownloadImages,
    autoDownloadVideos: autoDownloadVideos ?? this.autoDownloadVideos,
    autoDownloadDocuments: autoDownloadDocuments ?? this.autoDownloadDocuments,
    autoDownloadArchives: autoDownloadArchives ?? this.autoDownloadArchives,
  );

  @override
  List<Object?> get props => [
    language,
    chatReadReceipts,
    emailReadReceipts,
    shareTokenSignatureEnabled,
    autoDownloadImages,
    autoDownloadVideos,
    autoDownloadDocuments,
    autoDownloadArchives,
  ];
}

const String _availabilitySendFailureLog =
    'Failed to send availability message';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  static final Set<String> _seededDemoPendingAttachmentJids = <String>{};
  static const unreadDividerScrollTargetMessageId = '__unread_divider__';
  static const Duration _emailContentProfileTraceSlowThreshold = Duration(
    milliseconds: 50,
  );

  static List<Message> _messagesNewestFirst(Iterable<Message> messages) {
    final indexedMessages = <({int index, Message message})>[];
    var index = 0;
    for (final message in messages) {
      indexedMessages.add((index: index, message: message));
      index += 1;
    }
    if (indexedMessages.length < 2) {
      return [
        for (final indexedMessage in indexedMessages) indexedMessage.message,
      ];
    }
    indexedMessages.sort((a, b) {
      final aTimestamp = a.message.timestamp;
      final bTimestamp = b.message.timestamp;
      if (aTimestamp == null && bTimestamp == null) {
        return a.index.compareTo(b.index);
      }
      if (aTimestamp == null) {
        return 1;
      }
      if (bTimestamp == null) {
        return -1;
      }
      final timestampOrder = bTimestamp.compareTo(aTimestamp);
      if (timestampOrder != 0) {
        return timestampOrder;
      }
      final aDeltaMsgId = a.message.deltaMsgId;
      final bDeltaMsgId = b.message.deltaMsgId;
      final deltaRankOrder = (bDeltaMsgId == null ? 0 : 1).compareTo(
        aDeltaMsgId == null ? 0 : 1,
      );
      if (deltaRankOrder != 0) {
        return deltaRankOrder;
      }
      if (aDeltaMsgId != null && bDeltaMsgId != null) {
        final deltaOrder = bDeltaMsgId.compareTo(aDeltaMsgId);
        if (deltaOrder != 0) {
          return deltaOrder;
        }
      }
      return a.index.compareTo(b.index);
    });
    return [
      for (final indexedMessage in indexedMessages) indexedMessage.message,
    ];
  }

  ChatBloc({
    required this.jid,
    required MessageService messageService,
    required ChatsService chatsService,
    required NotificationService notificationService,
    required MucService mucService,
    required ChatSettingsSnapshot settings,
    Duration initialLoadDelay = Duration.zero,
    EmailService? emailService,
    OmemoService? omemoService,
  }) : _messageService = messageService,
       _chatsService = chatsService,
       _notificationService = notificationService,
       _emailService = emailService,
       _omemoService =
           omemoService ??
           (messageService is OmemoService
               ? messageService as OmemoService
               : null),
       _mucService = mucService,
       _chatArchiveSessionId = messageService.createChatArchiveSession(),
       _settingsSnapshot = settings,
       super(
         ChatState(
           items: const [],
           emailServiceAvailable: emailService != null,
           emailSelfJid: emailService?.selfSenderJid,
         ),
       ) {
    on<_ChatUpdated>(_onChatUpdated, transformer: restartable());
    on<_ChatStarted>(_onChatStarted);
    on<_ChatMessagesUpdated>(
      _onChatMessagesUpdated,
      transformer: restartable(),
    );
    on<_ChatMessagePageEnrichmentRequested>(
      _onChatMessagePageEnrichmentRequested,
      transformer: restartable(),
    );
    on<_ChatPresentationHydrationRequested>(
      _onChatPresentationHydrationRequested,
      transformer: sequential(),
    );
    on<_ChatEmailContentPreparationUpdated>(
      _onChatEmailContentPreparationUpdated,
    );
    on<_ChatEmailOriginalContentUpdated>(_onChatEmailOriginalContentUpdated);
    on<_ChatEmailFullMessageDownloaded>(_onChatEmailFullMessageDownloaded);
    on<ChatRenderedMessagesHydrationRequested>(
      _onChatRenderedMessagesHydrationRequested,
    );
    on<ChatUnreadDividerScrollCompleted>(_onChatUnreadDividerScrollCompleted);
    on<ChatUnreadDividerScrollAbandoned>(_onChatUnreadDividerScrollAbandoned);
    on<_PinnedMessagesUpdated>(
      _onPinnedMessagesUpdated,
      transformer: restartable(),
    );
    on<_PinnedMessagesLoadFailed>(_onPinnedMessagesLoadFailed);
    on<_FileMetadataBatchUpdated>(_onFileMetadataBatchUpdated);
    on<ChatPinnedMessagesOpened>(
      _onChatPinnedMessagesOpened,
      transformer: sequential(),
    );
    on<ChatPinnedMessagesRetryRequested>(
      _onChatPinnedMessagesRetryRequested,
      transformer: sequential(),
    );
    on<ChatPinnedMessageNoticeHidden>(_onChatPinnedMessageNoticeHidden);
    on<ChatPinnedMessageSelected>(_onChatPinnedMessageSelected);
    on<ChatImportantMessageSelected>(_onChatImportantMessageSelected);
    on<_RoomStateUpdated>(_onRoomStateUpdated, transformer: restartable());
    on<_RoomRosterUpdated>(_onRoomRosterUpdated);
    on<_RoomChatsUpdated>(_onRoomChatsUpdated);
    on<_RoomSelfAvatarUpdated>(_onRoomSelfAvatarUpdated);
    on<_EmailSyncStateChanged>(_onEmailSyncStateChanged);
    on<_XmppConnectionStateChanged>(_onXmppConnectionStateChanged);
    on<ChatMessageFocused>(_onChatMessageFocused);
    on<ChatReadThresholdChanged>(_onChatReadThresholdChanged);
    on<ChatEmailHeadersRequested>(_onChatEmailHeadersRequested);
    on<_ChatEmailOriginalContentRequested>(
      _onChatEmailOriginalContentRequested,
      transformer: sequential(),
    );
    on<ChatEmailQuotedTextRequested>(_onChatEmailQuotedTextRequested);
    on<_ChatEmailQuotedTextBatchRequested>(
      _onChatEmailQuotedTextBatchRequested,
      transformer: sequential(),
    );
    on<ChatTypingStarted>(_onChatTypingStarted);
    on<_ChatTypingStopped>(_onChatTypingStopped);
    on<_TypingParticipantsUpdated>(_onTypingParticipantsUpdated);
    on<ChatSettingsUpdated>(_onChatSettingsUpdated);
    on<ChatEmailServiceUpdated>(_onChatEmailServiceUpdated);
    on<_ChatSavedTransportOverrideUpdated>(
      _onChatSavedTransportOverrideUpdated,
    );
    on<ChatMessageSent>(
      _onChatMessageSent,
      transformer: _dedupeConcurrentChatMessageSends(),
    );
    on<ChatAvailabilityMessageSent>(_onChatAvailabilityMessageSent);
    on<ChatMuted>(_onChatMuted);
    on<ChatNotificationPreviewSettingChanged>(
      _onChatNotificationPreviewSettingChanged,
    );
    on<ChatNotificationBehaviorChanged>(_onChatNotificationBehaviorChanged);
    on<ChatLoadEarlier>(_onChatLoadEarlier, transformer: droppable());
    on<ChatShareSignatureToggled>(_onChatShareSignatureToggled);
    on<ChatAttachmentAutoDownloadToggled>(_onChatAttachmentAutoDownloadToggled);
    on<ChatAttachmentAutoDownloadRequested>(
      _onChatAttachmentAutoDownloadRequested,
    );
    on<ChatResponsivityChanged>(_onChatResponsivityChanged);
    on<ChatTypingIndicatorsChanged>(_onChatTypingIndicatorsChanged);
    on<ChatEmailRemoteImagesChanged>(_onChatEmailRemoteImagesChanged);
    on<ChatEmailReadReceiptsChanged>(_onChatEmailReadReceiptsChanged);
    on<ChatEmailSendConfirmationChanged>(_onChatEmailSendConfirmationChanged);
    on<ChatEmailComposerWatermarkChanged>(_onChatEmailComposerWatermarkChanged);
    on<ChatSavedTransportOverrideChanged>(
      _onChatSavedTransportOverrideChanged,
      transformer: sequential(),
    );
    on<ChatSettingSyncRetried>(
      _onChatSettingSyncRetried,
      transformer: sequential(),
    );
    on<ChatEncryptionChanged>(_onChatEncryptionChanged);
    on<ChatEncryptionRepaired>(_onChatEncryptionRepaired);
    on<ChatCapabilitiesRequested>(_onChatCapabilitiesRequested);
    on<ChatAlertHidden>(_onChatAlertHidden);
    on<ChatSpamStatusRequested>(_onChatSpamStatusRequested);
    on<ChatContactAddRequested>(_onChatContactAddRequested);
    on<ChatRecipientEmailChatRequested>(_onChatRecipientEmailChatRequested);
    on<ChatMessagePinRequested>(
      _onChatMessagePinRequested,
      transformer: sequential(),
    );
    on<ChatMessageCollectionMembershipChanged>(
      _onChatMessageCollectionMembershipChanged,
      transformer: sequential(),
    );
    on<ChatMessageReactionToggled>(_onChatMessageReactionToggled);
    on<ChatMessageForwardRequested>(_onChatMessageForwardRequested);
    on<ChatForwardDraftConsumed>(_onChatForwardDraftConsumed);
    on<ChatMessageResendRequested>(
      _onChatMessageResendRequested,
      transformer: _dedupeConcurrentResendRequests(),
    );
    on<ChatInviteRequested>(_onChatInviteRequested);
    on<ChatModerationActionRequested>(_onChatModerationActionRequested);
    on<ChatMessageEditRequested>(_onChatMessageEditRequested);
    on<ChatComposerErrorCleared>(_onChatComposerErrorCleared);
    on<_HttpUploadSupportUpdated>(_onHttpUploadSupportUpdated);
    on<ChatAttachmentPicked>(_onChatAttachmentPicked);
    on<ChatPendingAttachmentMetadataDiscarded>(
      _onChatPendingAttachmentMetadataDiscarded,
    );
    on<ChatAttachmentRetryRequested>(_onChatAttachmentRetryRequested);
    on<ChatDemoPendingAttachmentsRequested>(
      _onChatDemoPendingAttachmentsRequested,
    );
    on<ChatViewFilterChanged>(_onChatViewFilterChanged);
    on<ChatFanOutRetryRequested>(_onFanOutRetryRequested);
    on<ChatSubjectChanged>(
      _onChatSubjectChanged,
      transformer: blocDebounce(const Duration(milliseconds: 200)),
    );
    on<ChatInviteRevocationRequested>(_onInviteRevocationRequested);
    on<ChatInviteJoinRequested>(_onInviteJoinRequested);
    on<ChatLeaveRoomRequested>(_onLeaveRoomRequested);
    on<ChatDestroyRoomRequested>(_onDestroyRoomRequested);
    on<ChatNicknameChangeRequested>(_onNicknameChangeRequested);
    on<ChatRoomMembersOpened>(_onChatRoomMembersOpened);
    on<ChatRoomAvatarChangeRequested>(
      _onRoomAvatarChangeRequested,
      transformer: sequential(),
    );
    on<ChatContactRenameRequested>(_onContactRenameRequested);
    if (jid != null) {
      final chatLookupJid = _chatLookupJid;
      if (chatLookupJid == null) return;
      final threadKey =
          _notificationPayloadCodec.encodeChatJid(chatLookupJid) ??
          chatLookupJid.trim();
      if (threadKey.isNotEmpty) {
        _notificationService.dismissMessageNotification(threadKey: threadKey);
      }
      _chatSubscription = _chatsService.chatStream(chatLookupJid).listen((
        chat,
      ) {
        if (chat == null) {
          return;
        }
        add(_ChatUpdated(chat));
      });
      _transportPreferenceSubscription = _chatsService
          .watchChatTransportPreference(chatLookupJid)
          .listen(
            (transport) => add(_ChatSavedTransportOverrideUpdated(transport)),
          );
      if (initialLoadDelay == Duration.zero) {
        add(const _ChatStarted());
      } else {
        unawaited(_startChatAfterDelay(initialLoadDelay));
      }
    }
    _emailSyncSubscription = _emailService?.syncStateStream.listen(
      (syncState) => add(_EmailSyncStateChanged(syncState)),
    );
    final initialSyncState = _emailService?.syncState;
    if (initialSyncState != null) {
      add(_EmailSyncStateChanged(initialSyncState));
    }
    final initialContentPreparationSnapshot =
        _emailService?.contentPreparationSnapshot;
    if (initialContentPreparationSnapshot != null) {
      _emailContentPreparationSnapshot = initialContentPreparationSnapshot;
      add(
        _ChatEmailContentPreparationUpdated(initialContentPreparationSnapshot),
      );
    }
    _emailContentPreparationSubscription = _emailService
        ?.contentPreparationStream
        .listen(
          (snapshot) => add(_ChatEmailContentPreparationUpdated(snapshot)),
        );
    final initialOriginalContentSnapshot =
        _emailService?.originalContentSnapshot;
    if (initialOriginalContentSnapshot != null) {
      _emailOriginalContentSnapshot = initialOriginalContentSnapshot;
      add(_ChatEmailOriginalContentUpdated(initialOriginalContentSnapshot));
    }
    _emailOriginalContentSubscription = _emailService?.originalContentStream
        .listen((snapshot) => add(_ChatEmailOriginalContentUpdated(snapshot)));
    _httpUploadSupportSubscription = _messageService.httpUploadSupportStream
        .listen((support) => add(_HttpUploadSupportUpdated(support.supported)));
    add(_HttpUploadSupportUpdated(_messageService.httpUploadSupport.supported));
    if (messageService case final XmppService xmppService) {
      _xmppService = xmppService;
      add(_XmppConnectionStateChanged(xmppService.connectionState));
      _connectivitySubscription = xmppService.connectivityStream.listen(
        (connectionState) => add(_XmppConnectionStateChanged(connectionState)),
      );
    }
    _lifecycleListener = AppLifecycleListener(
      onResume: () async {
        await _handleLifecycleResumed();
      },
      onShow: () async {
        await _handleLifecycleShown();
      },
    );
  }

  Future<void> _startChatAfterDelay(Duration delay) async {
    await Future<void>.delayed(delay);
    if (_isClosing) {
      return;
    }
    add(const _ChatStarted());
  }

  static const messageBatchSize = 50;
  static const int _emailMessageBatchSize = 15;
  static const int _emailHydrationResultChunkSize = 4;
  static const int _emptyMessageCount = 0;
  static const CalendarChatSupport _calendarFragmentPolicy =
      CalendarChatSupport();
  static const NotificationPayloadCodec _notificationPayloadCodec =
      NotificationPayloadCodec();

  bool get _forceAllWithContactViewFilter {
    return _isEmailChat;
  }

  final String? jid;
  late final String? _chatLookupJid = normalizeAddress(jid);
  final MessageService _messageService;
  XmppService? _xmppService;
  final ChatsService _chatsService;
  final NotificationService _notificationService;
  EmailService? _emailService;
  final OmemoService? _omemoService;
  final MucService _mucService;
  ChatSettingsSnapshot _settingsSnapshot;

  final Logger _log = Logger('ChatBloc');
  var _composerHydrationSeed = 0;
  String? _lastEmailSendSignature;
  String? _lastXmppSendSignature;
  List<Message>? _preChatInitialMessages;
  Set<String> _readThresholdMessageIds = const <String>{};
  ({
    String chatJid,
    Set<String> thresholdIds,
    bool allowSend,
    bool syncEmailSeen,
    bool deferForUnreadBootstrap,
  })?
  _pendingReadStateSyncRequest;
  Future<void> _readStateSyncQueue = Future<void>.value();

  late final StreamSubscription<Chat?> _chatSubscription;
  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<List<PinnedMessageAggregate>>? _pinnedSubscription;
  String? _pinnedMessagesSourceKey;
  String? _lastSeenPinnedMessageSourceKey;
  DateTime? _lastSeenPinnedMessageAt;
  StreamSubscription<RoomState>? _roomSubscription;
  StreamSubscription<List<RosterItem>>? _roomRosterSubscription;
  StreamSubscription<List<Chat>>? _roomChatsSubscription;
  StreamSubscription<Avatar?>? _roomSelfAvatarSubscription;
  StreamSubscription<List<String>>? _typingParticipantsSubscription;
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;
  StreamSubscription<EmailContentPreparationSnapshot>?
  _emailContentPreparationSubscription;
  StreamSubscription<EmailOriginalContentSnapshot>?
  _emailOriginalContentSubscription;
  StreamSubscription<ConnectionState>? _connectivitySubscription;
  StreamSubscription<HttpUploadSupport>? _httpUploadSupportSubscription;
  StreamSubscription<MessageTransport?>? _transportPreferenceSubscription;
  StreamSubscription<Map<String, FileMetadataData?>>? _fileMetadataSubscription;
  Set<String> _trackedFileMetadataIds = const <String>{};
  var _fileMetadataRetryAttempts = _emptyMessageCount;
  var _fileMetadataSubscriptionCancelling = false;
  var _chatStarted = false;
  var _initialChatSideEffectsStarted = false;
  var _isClosing = false;
  String? _retainedMucRoomJid;
  AppLifecycleListener? _lifecycleListener;
  var _currentMessageLimit = messageBatchSize;
  ChatMessageKey? _emailSyncComposerMessage;
  final Set<String> _autoDownloadAttemptedMetadataIds = <String>{};
  final Set<String> _shareContextAttemptedStanzaIds = <String>{};
  final Set<String> _prefetchedPeerAvatarJids = <String>{};
  final Set<int> _queuedEmailQuotedTextDeltaIds = <int>{};
  EmailContentPreparationSnapshot _emailContentPreparationSnapshot =
      EmailContentPreparationSnapshot.empty;
  EmailOriginalContentSnapshot _emailOriginalContentSnapshot =
      EmailOriginalContentSnapshot.empty;
  Map<EmailContentJobKey, Message> _pendingUnreadDividerEmailContentMessages =
      const <EmailContentJobKey, Message>{};
  Future<void> _autoDownloadQueue = Future<void>.value();
  int _messageSubscriptionGeneration = 0;
  List<RosterItem> _roomRosterItems = const <RosterItem>[];
  Map<String, String>? _roomChatsAvatarSnapshot;
  String? _roomSelfAvatarPath;
  String? _unreadBoundaryStanzaId;
  bool _needsUnreadBootstrap = false;
  int? _pendingUnreadBoundaryCount;
  int? _unreadBootstrapRefreshLimit;
  bool _sessionUnreadBoundaryResolved = false;
  bool _unreadBoundaryScrollRequested = false;
  String? _pendingScrollTargetMessageId;
  final String _chatArchiveSessionId;

  RestartableTimer? _typingTimer;

  bool get encryptionAvailable => _omemoService != null;

  bool get _isEmailChat => state.chat?.defaultTransport.isEmail ?? false;

  int _timelineBatchSizeForChat(Chat chat) =>
      chat.isEmailBacked ? _emailMessageBatchSize : messageBatchSize;

  String? _bareJid(String? jid) {
    return bareAddress(jid);
  }

  Future<void> _handleLifecycleResumed() async {
    await _syncEmailChatNoticeForActiveChat();
    await _queueReadStateSync(allowSend: true);
  }

  Future<void> _handleLifecycleShown() async {
    await _queueReadStateSync(allowSend: true, syncEmailSeen: false);
  }

  Future<void> _syncEmailChatNoticeForActiveChat() async {
    final chat = state.chat;
    final emailService = _emailService;
    if (!_chatStarted ||
        chat == null ||
        emailService == null ||
        !emailService.hasInMemoryReconnectContext ||
        _mustDeferAutomaticReadStateSync ||
        !_hasPendingEmailReadState(chat, state.items) ||
        kEnableDemoChats && _messageService.demoOfflineMode) {
      return;
    }
    final stopwatch = Stopwatch()..start();
    final result = await emailService.syncChatNoticeState(chat);
    SafeLogging.profileTrace(
      'chat.emailNoticeReadState',
      'end',
      fields: <String, Object?>{
        'chatHash': SafeLogging.profileFingerprint(chat.jid.trim()),
        'status': result.status.name,
        'requested': result.coreNoticeRequested,
        'accepted': result.coreNoticeAccepted,
        'noticeRequestCount': result.noticeRequestCount,
        'noticeAcceptedCount': result.noticeAcceptedCount,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
  }

  Future<void> _onChatReadThresholdChanged(
    ChatReadThresholdChanged event,
    Emitter<ChatState> _,
  ) async {
    final nextIds = event.messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (nextIds.length == _readThresholdMessageIds.length &&
        nextIds.containsAll(_readThresholdMessageIds)) {
      return;
    }
    _readThresholdMessageIds = nextIds;
    await _queueReadStateSync(
      allowSend:
          SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed,
      deferForUnreadBootstrap: false,
    );
  }

  Future<void> _queueReadStateSync({
    required bool allowSend,
    bool syncEmailSeen = true,
    bool deferForUnreadBootstrap = true,
  }) {
    final chat = state.chat;
    if (chat == null) {
      return Future<void>.value();
    }
    final previousRequest = _pendingReadStateSyncRequest;
    final shouldDeferForUnreadBootstrap =
        deferForUnreadBootstrap &&
        (previousRequest == null ||
            previousRequest.chatJid != chat.jid ||
            previousRequest.deferForUnreadBootstrap);
    _pendingReadStateSyncRequest = (
      chatJid: chat.jid,
      thresholdIds: Set<String>.unmodifiable(_readThresholdMessageIds),
      allowSend: allowSend,
      syncEmailSeen: syncEmailSeen,
      deferForUnreadBootstrap: shouldDeferForUnreadBootstrap,
    );
    final nextQueue = _readStateSyncQueue.then(
      (_) => _drainReadStateSyncQueue(),
    );
    _readStateSyncQueue = nextQueue.onError<Exception>((_, _) {});
    return nextQueue;
  }

  Future<void> _drainReadStateSyncQueue() async {
    while (true) {
      final request = _pendingReadStateSyncRequest;
      if (request == null) {
        return;
      }
      _pendingReadStateSyncRequest = null;
      await _syncReadStateForCurrentChat(
        chatJid: request.chatJid,
        thresholdIds: request.thresholdIds,
        allowSend: request.allowSend,
        syncEmailSeen: request.syncEmailSeen,
        deferForUnreadBootstrap: request.deferForUnreadBootstrap,
      );
    }
  }

  Future<void> _syncReadStateForCurrentChat({
    required String chatJid,
    required Set<String> thresholdIds,
    required bool allowSend,
    bool syncEmailSeen = true,
    bool deferForUnreadBootstrap = true,
  }) async {
    final chat = state.chat;
    if (!_chatStarted ||
        chat == null ||
        chat.jid != chatJid ||
        deferForUnreadBootstrap && _mustDeferAutomaticReadStateSync) {
      return;
    }
    await _syncReadStateForActiveChat(
      chat: chat,
      items: state.items,
      thresholdIds: thresholdIds,
      allowSend: allowSend,
      syncEmailSeen: syncEmailSeen,
    );
  }

  Future<void> _syncReadStateForActiveChat({
    required Chat chat,
    required List<Message> items,
    required Set<String> thresholdIds,
    required bool allowSend,
    required bool syncEmailSeen,
  }) async {
    final stopwatch = Stopwatch()..start();
    var result = 'completed';
    var scopedCount = 0;
    var unreadCount = 0;
    var thresholdVisibleCount = 0;
    var thresholdUnreadCount = 0;
    var xmppVisibleCount = 0;
    var xmppUpdatedRows = 0;
    var xmppMarkerStatus = XmppReadMarkerSyncStatus.notRequested.name;
    var emailUnreadCount = 0;
    var localEmailDisplayedCandidateCount = 0;
    var seenCandidateCount = 0;
    var seenRequested = false;
    var seenSkippedReason = 'none';
    var seenSyncStatus = 'notRequested';
    try {
      final thresholdMessageIds = thresholdIds;
      final scopedItems = items
          .where((message) => message.chatJid == chat.jid)
          .toList(growable: false);
      scopedCount = scopedItems.length;
      final unreadCandidates = scopedItems
          .where(_isUnreadCandidate)
          .toList(growable: false);
      unreadCount = unreadCandidates.length;
      final thresholdVisibleItems = scopedItems
          .where((message) => thresholdMessageIds.contains(message.stanzaID))
          .toList(growable: false);
      final thresholdOrderByMessageId = <String, int>{};
      var thresholdOrder = 0;
      for (final messageId in thresholdMessageIds) {
        thresholdOrderByMessageId[messageId] = thresholdOrder;
        thresholdOrder += 1;
      }
      thresholdVisibleCount = thresholdVisibleItems.length;
      final thresholdVisibleUnreadCandidates = unreadCandidates
          .where((message) => thresholdMessageIds.contains(message.stanzaID))
          .toList(growable: false);
      thresholdUnreadCount = thresholdVisibleUnreadCandidates.length;
      final xmppVisibleCandidates = chat.defaultTransport.isEmail
          ? const <Message>[]
          : (thresholdVisibleUnreadCandidates
                .where((message) => !message.isEmailBacked)
                .toList(growable: false)
              ..sort(
                (left, right) => _compareMessagesByThresholdOrder(
                  left,
                  right,
                  thresholdOrderByMessageId,
                ),
              ));
      final shouldSendChatReadReceipts =
          chat.markerResponsive ?? _settingsSnapshot.chatReadReceipts;
      if (_xmppAllowedForChat(chat) && xmppVisibleCandidates.isNotEmpty) {
        xmppVisibleCount = xmppVisibleCandidates.length;
        final xmppResult = await _messageService
            .markVisibleXmppMessagesDisplayed(
              messages: xmppVisibleCandidates,
              chatJid: chat.jid,
              chatType: chat.type,
              markerPolicy: _xmppDisplayedMarkerPolicy(
                chat: chat,
                allowSend: allowSend,
                sendReadReceipts: shouldSendChatReadReceipts,
              ),
              myOccupantJid: state.roomState?.myOccupantJid,
            );
        xmppUpdatedRows = xmppResult.updatedRows;
        xmppMarkerStatus = xmppResult.markerStatus.name;
      }
      final emailUnreadCandidates = unreadCandidates
          .where((message) => message.isEmailBacked)
          .toList(growable: false);
      emailUnreadCount = emailUnreadCandidates.length;
      final localEmailDisplayedCandidates =
          await _emailCandidatesWithRfcSiblings(
            thresholdVisibleItems
                .where((message) => message.isEmailBacked)
                .where(_isUnreadCandidate)
                .toList(growable: false),
          );
      localEmailDisplayedCandidateCount = localEmailDisplayedCandidates.length;
      final remoteEmailSeenCandidates = await _emailCandidatesWithRfcSiblings(
        thresholdVisibleItems
            .where((message) => message.isEmailBacked)
            .where(_countsTowardUnread)
            .toList(growable: false),
        includeAlreadyDisplayed: true,
      );
      final seenCandidates = _emailSeenCandidatesWithDeltaIds(
        remoteEmailSeenCandidates,
      );
      seenCandidateCount = seenCandidates.length;
      Future<void> markLocalEmailDisplayedCandidates() {
        return _messageService.markMessagesDisplayedLocally(
          messages: localEmailDisplayedCandidates,
          chatJid: chat.jid,
          selfJid: selfJid,
          emailSelfJid: state.emailSelfJid,
        );
      }

      if (localEmailDisplayedCandidates.isNotEmpty) {
        await markLocalEmailDisplayedCandidates();
      }

      if (!allowSend) {
        result = 'localOnly';
        return;
      }
      if (!syncEmailSeen) {
        result = 'emailSeenSkipped';
        return;
      }
      final emailService = _emailService;
      if (emailService == null) {
        result = 'noEmailService';
        return;
      }
      if (kEnableDemoChats && _messageService.demoOfflineMode) {
        result = 'demoOffline';
        return;
      }
      if (!emailService.hasInMemoryReconnectContext) {
        seenSkippedReason = 'noReconnectContext';
        result = 'noReconnectContextLocalDisplayed';
        return;
      }
      seenRequested = true;
      final seenResult = await emailService.syncSeenMessages(
        seenCandidates,
        sendReadReceipts:
            chat.emailReadReceiptsEnabled ??
            _settingsSnapshot.emailReadReceipts,
        chatJidScope: chat.jid,
      );
      seenSyncStatus = seenResult.status.name;
      if (seenCandidates.isEmpty) {
        result = 'storedSeenDebtDrain';
      }
    } finally {
      SafeLogging.profileTrace(
        'chat.readStateSync',
        'end',
        fields: <String, Object?>{
          'chatHash': SafeLogging.profileFingerprint(chat.jid.trim()),
          'allowSend': allowSend,
          'result': result,
          'scopedCount': scopedCount,
          'unreadCount': unreadCount,
          'thresholdVisibleCount': thresholdVisibleCount,
          'thresholdUnreadCount': thresholdUnreadCount,
          'xmppVisibleCount': xmppVisibleCount,
          'xmppUpdatedRows': xmppUpdatedRows,
          'xmppMarkerStatus': xmppMarkerStatus,
          'emailUnreadCount': emailUnreadCount,
          'localEmailDisplayedCandidateCount':
              localEmailDisplayedCandidateCount,
          'seenCandidateCount': seenCandidateCount,
          'seenCandidateSource': 'thresholdVisible',
          'seenSkippedReason': seenSkippedReason,
          'seenSyncStatus': seenSyncStatus,
          'seenRequested': seenRequested,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    }
  }

  bool _hasPendingEmailReadState(Chat chat, Iterable<Message> messages) {
    if (messages.any(
      (message) => message.isEmailBacked && _isUnreadCandidate(message),
    )) {
      return true;
    }
    if (chat.defaultTransport.isEmail &&
        chat.unreadCount > _emptyMessageCount) {
      return true;
    }
    return false;
  }

  int _compareMessagesByThresholdOrder(
    Message left,
    Message right,
    Map<String, int> thresholdOrderByMessageId,
  ) {
    final leftOrder = thresholdOrderByMessageId[left.stanzaID];
    final rightOrder = thresholdOrderByMessageId[right.stanzaID];
    if (leftOrder != null && rightOrder != null) {
      final compared = leftOrder.compareTo(rightOrder);
      if (compared != 0) return compared;
    } else if (leftOrder == null && rightOrder != null) {
      return 1;
    } else if (leftOrder != null) {
      return -1;
    }
    return left.stanzaID.compareTo(right.stanzaID);
  }

  Future<List<Message>> _emailCandidatesWithRfcSiblings(
    List<Message> messages, {
    bool includeAlreadyDisplayed = false,
  }) async {
    if (messages.isEmpty) {
      return const <Message>[];
    }
    final candidatesByStanzaId = <String, Message>{};
    for (final message in messages) {
      candidatesByStanzaId[message.stanzaID] = message;
      if (message.emailRfcGroupKey == null) {
        continue;
      }
      final siblings = await _messageService.loadEmailMessagesByRfcGroup(
        message,
      );
      for (final sibling in siblings) {
        if (sibling.emailRfcGroupKey != message.emailRfcGroupKey) {
          continue;
        }
        if (includeAlreadyDisplayed
            ? !_countsTowardUnread(sibling)
            : !_isUnreadCandidate(sibling)) {
          continue;
        }
        candidatesByStanzaId[sibling.stanzaID] = sibling;
      }
    }
    return candidatesByStanzaId.values.toList(growable: false);
  }

  List<Message> _emailSeenCandidatesWithDeltaIds(Iterable<Message> messages) {
    final candidatesByDeltaId = <int, Message>{};
    for (final message in messages) {
      final deltaId = message.deltaMsgId;
      if (deltaId == null || deltaId <= 0 || !_countsTowardUnread(message)) {
        continue;
      }
      candidatesByDeltaId.putIfAbsent(deltaId, () => message);
    }
    return candidatesByDeltaId.values.toList(growable: false);
  }

  bool get _mustDeferAutomaticReadStateSync =>
      _needsUnreadBootstrap ||
      _unreadBootstrapRefreshLimit != null ||
      state.initialUnreadBootstrapStatus.isLoading ||
      state.scrollTargetMessageId == unreadDividerScrollTargetMessageId;

  bool _xmppAllowedForChat(Chat chat) {
    if (chat.defaultTransport.isEmail || chat.isAxichatWelcomeThread) {
      return false;
    }
    final candidate = chat.remoteJid.isNotEmpty ? chat.remoteJid : chat.jid;
    return candidate.trim().isNotEmpty;
  }

  XmppDisplayedMarkerPolicy _xmppDisplayedMarkerPolicy({
    required Chat chat,
    required bool allowSend,
    required bool sendReadReceipts,
  }) {
    if (chat.type == ChatType.groupChat || !sendReadReceipts) {
      return XmppDisplayedMarkerPolicy.localOnly;
    }
    return allowSend
        ? XmppDisplayedMarkerPolicy.sendOrQueue
        : XmppDisplayedMarkerPolicy.defer;
  }

  bool _canPageXmppHistory(Chat chat) {
    if (!_xmppAllowedForChat(chat) || chat.isAxiImServerAnnouncementThread) {
      return false;
    }
    return true;
  }

  bool _isLocalOnlyXmppTarget({required String? jid, Contact? target}) {
    return isAxichatWelcomeThreadJid(jid) ||
        target?.chat?.isAxichatWelcomeThread == true;
  }

  ChatHistoryPaginationSourceState _xmppPaginationStateFor(
    Chat? chat, {
    ConnectionState? connectionState,
    ChatHistoryPaginationSourceState? previous,
    bool reset = false,
  }) {
    if (chat == null || !_canPageXmppHistory(chat)) {
      return ChatHistoryPaginationSourceState.unavailable;
    }
    final xmppService = _xmppService;
    if (xmppService != null &&
        (connectionState ?? state.xmppConnectionState) !=
            ConnectionState.connected) {
      return ChatHistoryPaginationSourceState.temporarilyUnavailable;
    }
    if (!reset && previous == ChatHistoryPaginationSourceState.exhausted) {
      return ChatHistoryPaginationSourceState.exhausted;
    }
    return ChatHistoryPaginationSourceState.available;
  }

  int _messageProbeLimit(int visibleLimit) => visibleLimit + 1;

  Future<void> sendCalendarSyncMessage({
    required String jid,
    required CalendarSyncOutbound outbound,
    required ChatType chatType,
  }) async {
    if (isAxichatWelcomeThreadJid(jid) ||
        state.chat?.isAxichatWelcomeThread == true) {
      return;
    }
    final xmppService = _xmppService;
    if (xmppService == null) return;
    await xmppService.sendCalendarSyncMessage(
      jid: jid,
      outbound: outbound,
      chatType: chatType,
    );
  }

  Future<CalendarSnapshotUploadResult> uploadCalendarSnapshot(File file) async {
    if (state.chat?.isAxichatWelcomeThread == true) {
      final snapshot = await CalendarSnapshotCodec.decodeFile(file);
      if (snapshot == null) {
        throw XmppMessageException();
      }
      return CalendarSnapshotUploadResult(
        url: Uri.file(file.path).toString(),
        checksum: snapshot.checksum,
        version: snapshot.version,
      );
    }
    final xmppService = _xmppService;
    if (xmppService == null) {
      throw XmppMessageException();
    }
    return xmppService.uploadCalendarSnapshot(file);
  }

  Message resolveReplyTargetForMessage(Message message) {
    final group = _rfcEmailActionGroupFor(message);
    return _replyTargetForRfcEmailGroup(message: message, group: group);
  }

  Future<Message> resolveReplyTargetForMessageAsync(Message message) async {
    final group = await _loadRfcEmailActionGroupFor(message);
    return _replyTargetForRfcEmailGroup(message: message, group: group);
  }

  Message _replyTargetForRfcEmailGroup({
    required Message message,
    required RfcEmailGroup? group,
  }) {
    if (group == null) {
      return message;
    }
    final body = _rfcEmailGroupPlainBody(group);
    final htmlBody = _singleRfcEmailGroupHtmlBody(group);
    return group.quoteTarget.copyWith(
      body: body.isEmpty ? group.quoteTarget.body : body,
      htmlBody: htmlBody ?? group.quoteTarget.htmlBody,
      fileMetadataID: null,
    );
  }

  Future<void> _prefetchPeerAvatar(Chat chat) async {
    if (chat.type == ChatType.groupChat) return;
    if (!_xmppAllowedForChat(chat)) return;
    final xmppService = _xmppService;
    if (xmppService == null) return;
    final peerJid = chat.remoteJid.isNotEmpty ? chat.remoteJid : chat.jid;
    final peerKey = normalizedBareAddressValue(peerJid);
    if (peerKey == null || !_prefetchedPeerAvatarJids.add(peerKey)) {
      return;
    }
    try {
      await xmppService.prefetchAvatarForJid(peerJid);
    } on Exception {
      _prefetchedPeerAvatarJids.remove(peerKey);
      rethrow;
    }
  }

  Future<int> _archivedMessageCount(Chat chat) {
    return _messageService.countLocalMessages(
      jid: chat.remoteJid,
      filter: state.viewFilter,
      includePseudoMessages: false,
    );
  }

  String _nextPendingAttachmentId() => uuid.v4();

  String? _oldestLoadedXmppStanzaId() {
    for (final message in state.items.reversed) {
      if (message.isEmailBacked) {
        continue;
      }
      final stanzaId = message.stanzaID.trim();
      if (stanzaId.isNotEmpty) {
        return stanzaId;
      }
    }
    return null;
  }

  Future<MamPageResult?> _loadEarlierFromMam() async {
    final chat = state.chat;
    if (chat == null) return null;
    try {
      return await _messageService.loadEarlierFromMamForChatSession(
        sessionId: _chatArchiveSessionId,
        chat: chat,
        fallbackBeforeId: _oldestLoadedXmppStanzaId(),
        filter: state.viewFilter,
        pageSize: messageBatchSize,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamLoadFailedLogMessage, error, stackTrace);
      return const MamPageResult(complete: false);
    }
  }

  Future<Message?> _ensureEmailMessageAvailableLocally({
    required Chat chat,
    required String messageId,
  }) => _messageService.loadMessageByReferenceId(messageId, chatJid: chat.jid);

  bool _containsMessageId(Iterable<Message> messages, String messageId) {
    for (final message in messages) {
      if (_messageMatchesId(message, messageId)) {
        return true;
      }
    }
    return false;
  }

  Message? _messageForId(Iterable<Message> messages, String messageId) {
    for (final message in messages) {
      if (_messageMatchesId(message, messageId)) {
        return message;
      }
    }
    return null;
  }

  bool _messageMatchesId(Message message, String messageId) {
    final normalized = messageId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return message.referenceIds.contains(normalized);
  }

  void _indexMessageByReference(Map<String, Message> target, Message message) {
    for (final referenceId in message.referenceIds) {
      target[referenceId] = message;
    }
  }

  String? _storedReplyId(Message message) {
    final value = message.storedReplyId;
    if (value == null || isLegacyWireMessageReferenceValue(value)) {
      return null;
    }
    return value;
  }

  ({String? stanzaId, String? originId, String? mucStanzaId})
  _replyIdsForDraft({required Message quotedMessage, required Chat? chat}) {
    if (chat?.type == ChatType.groupChat) {
      return (
        stanzaId: null,
        originId: null,
        mucStanzaId: quotedMessage.trimmedMucStanzaId,
      );
    }
    final originId = quotedMessage.trimmedOriginId;
    if (originId != null) {
      return (stanzaId: null, originId: originId, mucStanzaId: null);
    }
    return (
      stanzaId: quotedMessage.trimmedStanzaId,
      originId: null,
      mucStanzaId: null,
    );
  }

  void _emitScrollTargetRequest(Emitter<ChatState> emit, String messageId) {
    emit(
      state.copyWith(
        scrollTargetMessageId: messageId,
        scrollTargetRequestId: state.scrollTargetRequestId + 1,
      ),
    );
  }

  Future<Message?> _ensurePinnedMessageAvailableLocally({
    required Chat chat,
    required String messageId,
  }) async {
    var target = await _messageService.loadMessageByReferenceId(
      messageId,
      chatJid: chat.jid,
    );
    if (target != null) {
      await _refreshPinnedMessagesFromDatabase(chat);
      return target;
    }
    if (chat.isEmailBacked) {
      target = await _ensureEmailMessageAvailableLocally(
        chat: chat,
        messageId: messageId,
      );
      if (target != null) {
        await _refreshPinnedMessagesFromDatabase(chat);
        return target;
      }
      if (chat.defaultTransport.isEmail) {
        return null;
      }
    }
    if (!_xmppAllowedForChat(chat)) {
      return null;
    }
    try {
      target = await _messageService
          .ensureMessageAvailableFromMamForChatSession(
            sessionId: _chatArchiveSessionId,
            chat: chat,
            messageId: messageId,
            filter: state.viewFilter,
            visibleWindowEmpty: state.items.isEmpty,
            fallbackBeforeId: _oldestLoadedXmppStanzaId(),
            pageSize: messageBatchSize,
          );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamHydrateFailedLogMessage, error, stackTrace);
    }
    if (target != null) {
      await _refreshPinnedMessagesFromDatabase(chat);
    }
    return target;
  }

  Future<Message?> _ensureImportantMessageAvailableLocally({
    required Chat chat,
    required String messageId,
  }) async {
    var target = await _messageService.loadMessageByReferenceId(
      messageId,
      chatJid: chat.jid,
    );
    if (target != null) {
      return target;
    }
    if (chat.isEmailBacked) {
      target = await _ensureEmailMessageAvailableLocally(
        chat: chat,
        messageId: messageId,
      );
      if (target != null) {
        return target;
      }
      if (chat.defaultTransport.isEmail) {
        return null;
      }
    }
    if (!_xmppAllowedForChat(chat)) {
      return null;
    }
    try {
      return await _messageService.ensureMessageAvailableFromMamForChatSession(
        sessionId: _chatArchiveSessionId,
        chat: chat,
        messageId: messageId,
        filter: state.viewFilter,
        visibleWindowEmpty: state.items.isEmpty,
        fallbackBeforeId: _oldestLoadedXmppStanzaId(),
        pageSize: messageBatchSize,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamHydrateFailedLogMessage, error, stackTrace);
    }
    return null;
  }

  Future<void> _subscribeThroughMessage({
    required Chat chat,
    required Message target,
    int? maxLimit,
  }) async {
    final timestamp = target.timestamp;
    if (timestamp == null) {
      return;
    }
    final throughCount = await _messageService.countChatMessagesThrough(
      chat.jid,
      throughTimestamp: timestamp,
      throughStanzaId: target.stanzaID,
      throughDeltaMsgId: target.deltaMsgId,
      filter: state.viewFilter,
    );
    var desiredLimit = throughCount > _currentMessageLimit
        ? throughCount
        : _currentMessageLimit;
    if (maxLimit != null && desiredLimit > maxLimit) {
      desiredLimit = maxLimit;
    }
    await _subscribeToMessages(limit: desiredLimit, filter: state.viewFilter);
  }

  Future<void> _ensureUnreadWindowLoaded({
    required Chat chat,
    required int desiredWindow,
    required int unreadTargetCount,
  }) async {
    if (unreadTargetCount <= _emptyMessageCount) {
      return;
    }
    if (chat.defaultTransport.isEmail || !_xmppAllowedForChat(chat)) {
      return;
    }
    try {
      await _messageService.ensureArchiveWindowFromMamForChatSession(
        sessionId: _chatArchiveSessionId,
        chat: chat,
        desiredWindow: desiredWindow,
        filter: state.viewFilter,
        visibleWindowEmpty: state.items.isEmpty,
        fallbackBeforeId: _oldestLoadedXmppStanzaId(),
        pageSize: messageBatchSize,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamHydrateFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _catchUpFromMam() async {
    final chat = state.chat;
    if (chat == null) return;
    try {
      await _messageService.catchUpChatFromMamOnConnectForSession(
        sessionId: _chatArchiveSessionId,
        chat: chat,
        filter: state.viewFilter,
        pageSize: messageBatchSize,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamCatchUpFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _initializeViewFilter(Emitter<ChatState> emit) async {
    if (jid == null) return;
    if (_forceAllWithContactViewFilter) return;
    try {
      final filter = await _chatsService.loadChatViewFilter(jid!);
      const forcedFilter = MessageTimelineFilter.allWithContact;
      final effectiveFilter = _forceAllWithContactViewFilter
          ? forcedFilter
          : filter;
      await _applyViewFilter(
        effectiveFilter,
        emit: emit,
        persist: false,
        chatJid: jid!,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_viewFilterLoadFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _initializeSavedTransportOverride(
    Emitter<ChatState> emit,
  ) async {
    final chatLookupJid = _chatLookupJid;
    if (chatLookupJid == null) {
      return;
    }
    final preference = await _chatsService.loadChatTransportPreference(
      chatLookupJid,
    );
    if (state.savedTransportOverride != null ||
        state.savedTransportOverrideStatus.isLoading) {
      return;
    }
    emit(
      state.copyWith(
        savedTransportOverride: preference.isExplicit
            ? preference.transport
            : null,
      ),
    );
  }

  Future<void> _applyViewFilter(
    MessageTimelineFilter filter, {
    required Emitter<ChatState> emit,
    required String chatJid,
    required bool persist,
  }) async {
    if (state.viewFilter == filter) {
      return;
    }
    final chat = state.chat;
    emit(
      state.copyWith(
        viewFilter: filter,
        hasMoreLocalMessages: false,
        xmppHistoryPaginationState: _xmppPaginationStateFor(chat, reset: true),
      ),
    );
    final resetChat = chat?.jid == chatJid ? chat : null;
    _messageService.resetChatArchiveSession(
      sessionId: _chatArchiveSessionId,
      chat: resetChat,
    );
    await _subscribeToMessages(limit: _currentMessageLimit, filter: filter);
    if (persist && !_forceAllWithContactViewFilter) {
      await _chatsService.saveChatViewFilter(jid: chatJid, filter: filter);
    }
  }

  Future<void> _onChatStarted(
    _ChatStarted event,
    Emitter<ChatState> emit,
  ) async {
    if (_chatStarted || _isClosing || jid == null) {
      return;
    }
    _chatStarted = true;
    await _initializeViewFilter(emit);
    if (_isClosing || emit.isDone) return;
    await _initializeSavedTransportOverride(emit);
    if (_isClosing || emit.isDone) return;
    final chat = state.chat;
    if (chat == null) {
      return;
    }
    final nextViewFilter = chat.defaultTransport.isEmail
        ? MessageTimelineFilter.allWithContact
        : state.viewFilter;
    await _runStartedChatSideEffects(
      chat,
      emit,
      firstChatSideEffects: true,
      typingContextChanged: true,
      pinnedContextChanged: true,
      showXmppCapabilities: _xmppAllowedForChat(chat),
      nextViewFilter: nextViewFilter,
    );
  }

  void _assertOwnsChat(Chat chat) {
    final chatLookupJid = _chatLookupJid;
    if (chatLookupJid == null || !sameBareAddress(chatLookupJid, chat.jid)) {
      throw StateError(
        'ChatBloc for $jid received chat update for ${chat.jid}',
      );
    }
  }

  Future<void> _hydrateLatestFromMam(Chat chat) async {
    try {
      await _messageService.hydrateLatestFromMamForChatSessionIfNeeded(
        sessionId: _chatArchiveSessionId,
        chat: chat,
        desiredWindow: _currentMessageLimit,
        filter: state.viewFilter,
        visibleWindowEmpty: state.items.isEmpty,
        pageSize: messageBatchSize,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamHydrateFailedLogMessage, error, stackTrace);
    }
  }

  DateTime get _staleUnackedSendAgainCutoff => DateTime.timestamp().subtract(
    XmppStreamManagementManager.ackTimeoutDuration,
  );

  bool _isSelfMessageForSendAgain(Message message, Chat chat) {
    if (message.isFromAccount(_chatsService.myJid)) {
      return true;
    }
    if (chat.type == ChatType.groupChat) {
      final roomState = state.roomState ?? _mucService.roomStateFor(chat.jid);
      if (roomState != null) {
        return roomState.isSelfOccupantId(message.senderJid);
      }
      final selfNick = chat.myNickname?.trim();
      final senderNick = addressResourcePart(message.senderJid)?.trim();
      return selfNick != null &&
          selfNick.isNotEmpty &&
          senderNick != null &&
          senderNick == selfNick;
    }
    return false;
  }

  bool _canMutatePinForMessage({
    required Message message,
    required Chat chat,
    required RoomState? roomState,
  }) {
    if (chat.defaultTransport.isEmail || message.isEmailBacked) {
      return false;
    }
    if (chat.type != ChatType.groupChat) {
      return true;
    }
    if (roomState == null ||
        roomState.myRole.isVisitor ||
        roomState.myRole.isNone) {
      return false;
    }
    if (roomState.myRole.canManagePins ||
        roomState.myAffiliation.canManagePins) {
      return true;
    }
    return roomState.myRole.isParticipant || roomState.myAffiliation.isMember;
  }

  List<Message> _staleUnackedSendAgainCandidatesForMessages(
    Chat chat,
    Iterable<Message> messages,
  ) {
    final candidates = <Message>[];
    for (final message in messages) {
      if (message.isStaleUnackedXmppSendAgainCandidate(
        isSelf: _isSelfMessageForSendAgain(message, chat),
        isEmailChat: chat.defaultTransport.isEmail,
        staleBefore: _staleUnackedSendAgainCutoff,
      )) {
        candidates.add(message);
      }
    }
    return List<Message>.unmodifiable(candidates);
  }

  List<Message> _staleUnackedSendAgainCandidates(Chat chat) {
    return _staleUnackedSendAgainCandidatesForMessages(chat, state.items);
  }

  Future<void> _verifyStaleUnackedMessagesFromMam(Chat chat) async {
    if (!_xmppAllowedForChat(chat)) {
      return;
    }
    final candidates = _staleUnackedSendAgainCandidates(chat);
    if (candidates.isEmpty) {
      return;
    }
    try {
      await _messageService.verifyUnackedMessagesFromMamForChat(
        chat: chat,
        candidates: candidates,
        pageSize: messageBatchSize,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamHydrateFailedLogMessage, error, stackTrace);
    }
  }

  Future<List<Message>> _verifyAndRefreshInitialStaleUnackedMessages({
    required Chat chat,
    required List<Message> messages,
  }) async {
    if (!_xmppAllowedForChat(chat)) {
      return messages;
    }
    final candidates = _staleUnackedSendAgainCandidatesForMessages(
      chat,
      messages,
    );
    if (candidates.isEmpty) {
      return messages;
    }
    try {
      await _messageService.verifyUnackedMessagesFromMamForChat(
        chat: chat,
        candidates: candidates,
        pageSize: messageBatchSize,
      );
      final refreshed = await _messageService.loadMessagesByReferenceIds(
        candidates.map((message) => message.stanzaID),
        chatJid: chat.jid,
      );
      if (refreshed.isEmpty) {
        return messages;
      }
      final refreshedById = <String, Message>{};
      for (final message in refreshed) {
        refreshedById[message.stanzaID] = message;
      }
      return [
        for (final message in messages)
          refreshedById[message.stanzaID] ?? message,
      ];
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamHydrateFailedLogMessage, error, stackTrace);
      return messages;
    }
  }

  Future<void> _publishVerifiedInitialMessagesForChat(
    Chat chat,
    Emitter<ChatState> emit,
  ) async {
    if (state.messagesLoaded) {
      return;
    }
    final initialMessages = state.items.isNotEmpty
        ? state.items
        : _preChatInitialMessages;
    if (initialMessages == null) {
      return;
    }
    if (initialMessages.isEmpty) {
      _preChatInitialMessages = null;
      if (emit.isDone) return;
      emit(state.copyWith(messagesLoaded: true));
      return;
    }
    final verifiedItems = await _verifyAndRefreshInitialStaleUnackedMessages(
      chat: chat,
      messages: initialMessages,
    );
    if (emit.isDone) return;
    _preChatInitialMessages = null;
    emit(
      state.copyWith(
        items: _messagesNewestFirst(verifiedItems),
        messagesLoaded: true,
      ),
    );
  }

  Future<void> _ensureMucMembership(Chat chat) async {
    if (chat.type != ChatType.groupChat) return;
    if (!_xmppAllowedForChat(chat)) return;
    try {
      await _mucService.ensureJoined(
        roomJid: chat.jid,
        nickname: chat.myNickname,
        maxHistoryStanzas: 0,
        allowRejoin: true,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mucMembershipFailedLogMessage, error, stackTrace);
    }
  }

  void _retainMucPresence(Chat chat) {
    if (chat.type != ChatType.groupChat) {
      _releaseRetainedMucPresence();
      return;
    }
    if (!_xmppAllowedForChat(chat)) return;
    final retained = _retainedMucRoomJid;
    if (retained != null && sameBareAddress(retained, chat.jid)) return;
    _releaseRetainedMucPresence();
    _mucService.retainRoomPresence(chat.jid);
    _retainedMucRoomJid = chat.jid;
  }

  void _releaseRetainedMucPresence() {
    final retained = _retainedMucRoomJid;
    if (retained == null) return;
    _retainedMucRoomJid = null;
    _mucService.releaseRoomPresence(retained);
  }

  Future<void> _onChatRoomMembersOpened(
    ChatRoomMembersOpened event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null || chat.type != ChatType.groupChat) return;
    final chatJid = _bareJid(chat.jid);
    if (chatJid == null) return;
    RoomState roomState =
        _mucService.roomStateFor(chat.jid) ??
        _mucService.roomStateForOrEmpty(chat.jid);
    if (_bareJid(state.chat?.jid) != chatJid) return;
    if (emit.isDone) return;
    emit(
      state.copyWith(
        roomState: roomState,
        roomMemberSections: _buildRoomMemberSections(roomState),
      ),
    );
    try {
      roomState = await _mucService.prepareRoomMemberState(roomJid: chat.jid);
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_roomStateWarmFailedLogMessage, error, stackTrace);
    }
    if (_bareJid(state.chat?.jid) != chatJid) return;
    if (emit.isDone) return;
    emit(
      state.copyWith(
        roomState: roomState,
        roomMemberSections: _buildRoomMemberSections(roomState),
      ),
    );
    if (emit.isDone) return;
    await _ensureMucMembership(chat);
    if (_bareJid(state.chat?.jid) != chatJid) return;
    if (emit.isDone) return;
    final latestRoomState = _mucService.roomStateFor(chat.jid) ?? roomState;
    emit(
      state.copyWith(
        roomState: latestRoomState,
        roomMemberSections: _buildRoomMemberSections(latestRoomState),
      ),
    );
    if (emit.isDone) return;
    await _refreshRoomAffiliations(chat: chat, roomState: latestRoomState);
  }

  Future<void> _refreshRoomAffiliations({
    required Chat chat,
    required RoomState roomState,
  }) async {
    if (!roomState.hasSelfPresence) return;
    final roomJid = _bareJid(chat.jid);
    if (roomJid == null || roomJid.isEmpty) return;
    final affiliation = roomState.myAffiliation;
    Future<void> refreshIfAllowed(
      OccupantAffiliation queriedAffiliation,
      Future<void> Function() refresh,
    ) async {
      if (!affiliation.canAuthoritativelyRefreshAffiliation(
        queriedAffiliation,
      )) {
        return;
      }
      try {
        await refresh();
      } on Exception catch (error, stackTrace) {
        _log.safeFine(
          _roomAffiliationRefreshFailedLogMessage,
          error,
          stackTrace,
        );
      }
    }

    await refreshIfAllowed(
      OccupantAffiliation.member,
      () => _mucService.fetchRoomMembers(roomJid: roomJid),
    );
    await refreshIfAllowed(
      OccupantAffiliation.owner,
      () => _mucService.fetchRoomOwners(roomJid: roomJid),
    );
    await refreshIfAllowed(
      OccupantAffiliation.admin,
      () => _mucService.fetchRoomAdmins(roomJid: roomJid),
    );
  }

  Future<void> _subscribeToMessages({
    required int limit,
    required MessageTimelineFilter filter,
    bool forceXmppFallback = false,
    int? generationOverride,
  }) async {
    final targetJid = state.chat?.jid ?? _chatLookupJid ?? jid;
    if (targetJid == null ||
        generationOverride != null &&
            generationOverride != _messageSubscriptionGeneration) {
      return;
    }
    final previousSubscription = _messageSubscription;
    _messageSubscription = null;
    await _detachAndCancelSubscription(previousSubscription);
    if (isClosed ||
        generationOverride != null &&
            generationOverride != _messageSubscriptionGeneration) {
      return;
    }
    _currentMessageLimit = limit;
    final generation =
        generationOverride ?? (_messageSubscriptionGeneration += 1);
    final chat = state.chat;
    final emailService = _emailService;
    final useEmailService =
        !forceXmppFallback && chat?.defaultTransport.isEmail == true;
    final queryLimit = _messageProbeLimit(limit);
    if (useEmailService && emailService != null) {
      _messageSubscription = emailService
          .messageStreamForChat(targetJid, end: queryLimit, filter: filter)
          .listen(
            (items) => add(_ChatMessagesUpdated(items, generation)),
            onError: (Object error, StackTrace stackTrace) async {
              _log.fine('Email message stream failed', error, stackTrace);
              await _subscribeToMessages(
                limit: limit,
                filter: filter,
                forceXmppFallback: true,
                generationOverride: generation,
              );
            },
          );
      return;
    }
    _messageSubscription = _messageService
        .messageStreamForChat(targetJid, end: queryLimit, filter: filter)
        .listen((items) => add(_ChatMessagesUpdated(items, generation)));
  }

  String? _resolvePinnedMessagesChatJid(Chat chat) {
    if (chat.defaultTransport.isEmail) {
      return null;
    }
    return normalizedBareAddressValue(chat.remoteJid);
  }

  Future<void> _subscribeToPinnedMessages(Chat chat) async {
    if (_isClosing || isClosed) {
      return;
    }
    final sourceKey = _resolvePinnedMessagesChatJid(chat);
    if (_pinnedMessagesSourceKey != sourceKey) {
      _clearLastSeenPinnedMessageCache();
    }
    if (sourceKey != null &&
        _pinnedMessagesSourceKey == sourceKey &&
        _pinnedSubscription != null) {
      return;
    }
    _pinnedMessagesSourceKey = sourceKey;
    final previousSubscription = _pinnedSubscription;
    _pinnedSubscription = null;
    await _detachAndCancelSubscription(previousSubscription);
    if (_isClosing || isClosed) return;
    if (sourceKey == null) {
      _pinnedSubscription = null;
      add(
        const _PinnedMessagesUpdated(
          sourceKey: null,
          items: <PinnedMessageAggregate>[],
        ),
      );
      return;
    }
    late final StreamSubscription<List<PinnedMessageAggregate>> subscription;
    subscription = _messageService
        .pinnedMessagesStream(sourceKey)
        .listen(
          (items) =>
              add(_PinnedMessagesUpdated(sourceKey: sourceKey, items: items)),
          onError: (Object error, StackTrace stackTrace) {
            _log.safeFine('Pinned messages stream failed.', error, stackTrace);
            add(_PinnedMessagesLoadFailed(sourceKey));
          },
          onDone: () {
            _log.safeFine('Pinned messages stream closed.');
            if (identical(_pinnedSubscription, subscription)) {
              _pinnedSubscription = null;
            }
          },
        );
    _pinnedSubscription = subscription;
    unawaited(_syncPinnedMessagesForChat(chat));
  }

  Future<void> _subscribeToTypingParticipants(Chat chat) async {
    if (!_xmppAllowedForChat(chat)) {
      final previousSubscription = _typingParticipantsSubscription;
      _typingParticipantsSubscription = null;
      await _detachAndCancelSubscription(previousSubscription);
      _typingParticipantsSubscription = null;
      return;
    }
    final previousSubscription = _typingParticipantsSubscription;
    _typingParticipantsSubscription = null;
    await _detachAndCancelSubscription(previousSubscription);
    if (isClosed) return;
    _typingParticipantsSubscription = _chatsService
        .typingParticipantsStream(chat.jid)
        .listen(
          (participants) => add(_TypingParticipantsUpdated(participants)),
        );
  }

  Future<void> _syncPinnedMessagesForChat(Chat chat) async {
    final chatJid = _resolvePinnedMessagesChatJid(chat);
    if (chatJid == null) {
      return;
    }
    if (chat.isAxichatWelcomeThread) {
      return;
    }
    try {
      await _messageService.syncPinnedMessagesForChat(chatJid);
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_pinSyncFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _detachAndCancelSubscription<T>(
    StreamSubscription<T>? subscription,
  ) async {
    if (subscription == null) {
      return;
    }
    subscription
      ..onData(null)
      ..onError(null)
      ..onDone(null);
    await subscription.cancel();
  }

  @override
  Future<void> close() async {
    _isClosing = true;
    _clearVisibleEmailContentMessagesForCurrentChat();
    _restageUnresolvedUnreadBoundarySeed();
    _releaseRetainedMucPresence();
    await _detachAndCancelSubscription(_chatSubscription);
    final messageSubscription = _messageSubscription;
    _messageSubscription = null;
    await _detachAndCancelSubscription(messageSubscription);
    final pinnedSubscription = _pinnedSubscription;
    _pinnedSubscription = null;
    await _detachAndCancelSubscription(pinnedSubscription);
    final roomSubscription = _roomSubscription;
    _roomSubscription = null;
    await _detachAndCancelSubscription(roomSubscription);
    final roomRosterSubscription = _roomRosterSubscription;
    _roomRosterSubscription = null;
    await _detachAndCancelSubscription(roomRosterSubscription);
    final roomChatsSubscription = _roomChatsSubscription;
    _roomChatsSubscription = null;
    await _detachAndCancelSubscription(roomChatsSubscription);
    final roomSelfAvatarSubscription = _roomSelfAvatarSubscription;
    _roomSelfAvatarSubscription = null;
    await _detachAndCancelSubscription(roomSelfAvatarSubscription);
    final typingParticipantsSubscription = _typingParticipantsSubscription;
    _typingParticipantsSubscription = null;
    await _detachAndCancelSubscription(typingParticipantsSubscription);
    final emailSyncSubscription = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await _detachAndCancelSubscription(emailSyncSubscription);
    final emailContentPreparationSubscription =
        _emailContentPreparationSubscription;
    _emailContentPreparationSubscription = null;
    await _detachAndCancelSubscription(emailContentPreparationSubscription);
    final emailOriginalContentSubscription = _emailOriginalContentSubscription;
    _emailOriginalContentSubscription = null;
    await _detachAndCancelSubscription(emailOriginalContentSubscription);
    final connectivitySubscription = _connectivitySubscription;
    _connectivitySubscription = null;
    await _detachAndCancelSubscription(connectivitySubscription);
    final httpUploadSupportSubscription = _httpUploadSupportSubscription;
    _httpUploadSupportSubscription = null;
    await _detachAndCancelSubscription(httpUploadSupportSubscription);
    final transportPreferenceSubscription = _transportPreferenceSubscription;
    _transportPreferenceSubscription = null;
    await _detachAndCancelSubscription(transportPreferenceSubscription);
    final metadataSubscription = _fileMetadataSubscription;
    _fileMetadataSubscription = null;
    _trackedFileMetadataIds = const <String>{};
    _fileMetadataRetryAttempts = _emptyMessageCount;
    _fileMetadataSubscriptionCancelling = true;
    try {
      await metadataSubscription?.cancel();
    } finally {
      _fileMetadataSubscriptionCancelling = false;
    }
    _typingTimer?.cancel();
    _typingTimer = null;
    _autoDownloadAttemptedMetadataIds.clear();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _messageService.disposeChatArchiveSession(_chatArchiveSessionId);
    return super.close();
  }

  void _restageUnresolvedUnreadBoundarySeed() {
    final pendingUnreadBoundaryCount = _pendingUnreadBoundaryCount;
    final chatJid = state.chat?.jid ?? _chatLookupJid;
    if (pendingUnreadBoundaryCount == null ||
        pendingUnreadBoundaryCount <= _emptyMessageCount ||
        _sessionUnreadBoundaryResolved ||
        chatJid == null ||
        chatJid.isEmpty) {
      return;
    }
    _chatsService.stageOpenChatUnreadBoundarySeed(
      jid: chatJid,
      unreadCount: pendingUnreadBoundaryCount,
    );
  }

  Future<void> _onChatUpdated(
    _ChatUpdated event,
    Emitter<ChatState> emit,
  ) async {
    if (_isClosing || isClosed) {
      return;
    }
    _assertOwnsChat(event.chat);
    final chatWasUninitialized = state.chat == null;
    if (chatWasUninitialized || state.chat?.jid != event.chat.jid) {
      if (!chatWasUninitialized) {
        _clearVisibleEmailContentMessagesForCurrentChat();
      }
      _clearPendingUnreadDividerEmailContentMessages();
      _readThresholdMessageIds = const <String>{};
      _pendingReadStateSyncRequest = null;
      _unreadBoundaryStanzaId = null;
    }
    final transportChanged =
        state.chat?.defaultTransport != event.chat.defaultTransport;
    final initialChatSideEffectsStarting =
        _chatStarted && !_initialChatSideEffectsStarted;
    final paginationContextChanged =
        chatWasUninitialized ||
        state.chat?.jid != event.chat.jid ||
        transportChanged ||
        state.chat?.isEmailBacked != event.chat.isEmailBacked;
    final previousPinnedSourceKey = state.chat == null
        ? null
        : _resolvePinnedMessagesChatJid(state.chat!);
    final nextPinnedSourceKey = _resolvePinnedMessagesChatJid(event.chat);
    final typingContextChanged =
        chatWasUninitialized ||
        transportChanged ||
        initialChatSideEffectsStarting;
    final pinnedSourceChanged =
        (_pinnedMessagesSourceKey ?? previousPinnedSourceKey) !=
        nextPinnedSourceKey;
    final pinnedContextChanged =
        chatWasUninitialized ||
        pinnedSourceChanged ||
        (nextPinnedSourceKey != null && _pinnedSubscription == null) ||
        initialChatSideEffectsStarting;
    final resetPinnedMessages =
        !chatWasUninitialized && previousPinnedSourceKey != nextPinnedSourceKey;
    final capabilitiesShouldReset = chatWasUninitialized || transportChanged;
    final showXmppCapabilities = _xmppAllowedForChat(event.chat);
    final typingShouldClear =
        typingContextChanged || !_xmppAllowedForChat(event.chat);
    const forcedViewFilter = MessageTimelineFilter.allWithContact;
    final nextViewFilter = event.chat.defaultTransport.isEmail
        ? forcedViewFilter
        : state.viewFilter;
    final nextRoomState = event.chat.type == ChatType.groupChat
        ? state.roomState ?? _mucService.roomStateForOrEmpty(event.chat.jid)
        : null;
    final nextRoomMemberSections = nextRoomState == null
        ? const <RoomMemberSection>[]
        : state.roomState == null
        ? _buildRoomMemberSections(nextRoomState)
        : state.roomMemberSections;
    final unreadCount = event.chat.unreadCount;
    final stagedUnreadCount = _initialChatSideEffectsStarted
        ? _chatsService.consumeOpenChatUnreadBoundarySeed(event.chat.jid)
        : _chatsService.peekOpenChatUnreadBoundarySeed(event.chat.jid);
    final seededUnreadCount =
        _pendingUnreadBoundaryCount ??
        (stagedUnreadCount != null && stagedUnreadCount > _emptyMessageCount
            ? stagedUnreadCount
            : chatWasUninitialized && unreadCount > _emptyMessageCount
            ? unreadCount
            : null);
    if (resetPinnedMessages) {
      _clearLastSeenPinnedMessageCache();
    }
    emit(
      _withEmailContentPreparationProjection(
        state.copyWith(
          chat: event.chat,
          showAlert: event.chat.alert != null && state.chat?.alert == null,
          roomState: nextRoomState,
          roomMemberSections: nextRoomState == null
              ? const <RoomMemberSection>[]
              : nextRoomMemberSections,
          xmppCapabilities: capabilitiesShouldReset || !showXmppCapabilities
              ? null
              : state.xmppCapabilities,
          typingParticipants: typingShouldClear
              ? const []
              : state.typingParticipants,
          typing: event.chat.defaultTransport.isEmail ? false : state.typing,
          viewFilter: nextViewFilter,
          hasMoreLocalMessages: paginationContextChanged
              ? false
              : state.hasMoreLocalMessages,
          xmppHistoryPaginationState: _xmppPaginationStateFor(
            event.chat,
            previous: state.xmppHistoryPaginationState,
            reset: paginationContextChanged,
          ),
          pinnedMessages: resetPinnedMessages
              ? const <PinnedMessageItem>[]
              : state.pinnedMessages,
          pinnedMessagesStatus: resetPinnedMessages
              ? ChatPinnedMessagesStatus.idle
              : state.pinnedMessagesStatus,
          latestPinnedMessageNotice: resetPinnedMessages
              ? null
              : state.latestPinnedMessageNotice,
          lastSeenPinnedMessageAt: resetPinnedMessages
              ? null
              : state.lastSeenPinnedMessageAt,
          unreadBoundaryStanzaId: state.unreadBoundaryStanzaId,
          initialUnreadBootstrapStatus:
              seededUnreadCount != null &&
                  seededUnreadCount > _emptyMessageCount
              ? ChatInitialUnreadBootstrapStatus.loading
              : paginationContextChanged
              ? ChatInitialUnreadBootstrapStatus.idle
              : state.initialUnreadBootstrapStatus,
        ),
      ),
    );
    if (chatWasUninitialized) {
      _needsUnreadBootstrap =
          seededUnreadCount != null && seededUnreadCount > _emptyMessageCount;
      _pendingUnreadBoundaryCount = seededUnreadCount;
    } else {
      if (_pendingUnreadBoundaryCount == null &&
          stagedUnreadCount != null &&
          stagedUnreadCount > _emptyMessageCount) {
        _pendingUnreadBoundaryCount = stagedUnreadCount;
        _needsUnreadBootstrap = true;
      }
    }
    if (!_chatStarted) {
      return;
    }
    await _runStartedChatSideEffects(
      event.chat,
      emit,
      firstChatSideEffects:
          chatWasUninitialized || initialChatSideEffectsStarting,
      typingContextChanged: typingContextChanged,
      pinnedContextChanged: pinnedContextChanged,
      showXmppCapabilities: showXmppCapabilities,
      nextViewFilter: nextViewFilter,
    );
  }

  Future<void> _runStartedChatSideEffects(
    Chat chat,
    Emitter<ChatState> emit, {
    required bool firstChatSideEffects,
    required bool typingContextChanged,
    required bool pinnedContextChanged,
    required bool showXmppCapabilities,
    required MessageTimelineFilter nextViewFilter,
  }) async {
    final runFirstChatSideEffects =
        firstChatSideEffects && !_initialChatSideEffectsStarted;
    _retainMucPresence(chat);
    if (runFirstChatSideEffects) {
      _messageService.resetChatArchiveSession(
        sessionId: _chatArchiveSessionId,
        chat: chat,
      );
    }
    final roomSubscription = _roomSubscription;
    _roomSubscription = null;
    await _detachAndCancelSubscription(roomSubscription);
    final roomRosterSubscription = _roomRosterSubscription;
    _roomRosterSubscription = null;
    await _detachAndCancelSubscription(roomRosterSubscription);
    final roomChatsSubscription = _roomChatsSubscription;
    _roomChatsSubscription = null;
    await _detachAndCancelSubscription(roomChatsSubscription);
    final roomSelfAvatarSubscription = _roomSelfAvatarSubscription;
    _roomSelfAvatarSubscription = null;
    await _detachAndCancelSubscription(roomSelfAvatarSubscription);
    if (_isClosing || emit.isDone) return;
    if (chat.type == ChatType.groupChat) {
      _subscribeRoomMemberSources();
    } else {
      _roomRosterItems = const <RosterItem>[];
      _roomChatsAvatarSnapshot = null;
      _roomSelfAvatarPath = null;
    }
    if (runFirstChatSideEffects) {
      await _subscribeToMessages(
        limit: _timelineBatchSizeForChat(chat),
        filter: nextViewFilter,
      );
      _chatsService.consumeOpenChatUnreadBoundarySeed(chat.jid);
      _initialChatSideEffectsStarted = true;
      if (_isClosing || emit.isDone) return;
      await _prefetchPeerAvatar(chat);
      if (_isClosing || emit.isDone) return;
    }
    final pendingUnreadBoundaryCount = _pendingUnreadBoundaryCount;
    if (pendingUnreadBoundaryCount != null &&
        pendingUnreadBoundaryCount > _emptyMessageCount) {
      await _resolveUnreadBoundaryStanzaId(
        chat,
        unreadCount: pendingUnreadBoundaryCount,
      );
      if (_isClosing || emit.isDone) return;
    }
    if (state.items.isNotEmpty) {
      final rawBoundary = _resolveStickyUnreadBoundaryStanzaId(
        chat: chat,
        messages: state.items,
        storedBoundaryStanzaId: _unreadBoundaryStanzaId,
        previousBoundaryStanzaId: _sessionUnreadBoundaryResolved
            ? state.unreadBoundaryStanzaId
            : null,
        pendingUnreadBoundaryCount: _pendingUnreadBoundaryCount,
      );
      final boundary = _resolveVisibleUnreadBoundaryStanzaId(
        boundaryStanzaId: rawBoundary,
        messages: state.items,
        groupLeaderByMessageId: state.attachmentGroupLeaderByMessageId,
        attachmentsByMessageId: state.attachmentMetadataIdsByMessageId,
        emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
      );
      _continueUnreadBootstrapIfNeeded(
        rawBoundaryStanzaId: rawBoundary,
        visibleBoundaryStanzaId: boundary,
      );
      final nextInitialUnreadBootstrapStatus =
          _nextInitialUnreadBootstrapStatus(
            rawBoundaryStanzaId: rawBoundary,
            visibleBoundaryStanzaId: boundary,
          );
      if (boundary != state.unreadBoundaryStanzaId) {
        final shouldRequestUnreadScroll =
            boundary != null && !_unreadBoundaryScrollRequested;
        if (shouldRequestUnreadScroll) {
          _unreadBoundaryScrollRequested = true;
          _retainPendingUnreadDividerEmailContentMessages(
            _unreadDividerEmailContentMessages(
              messages: state.items,
              unreadBoundaryStanzaId: boundary,
              groupLeaderByMessageId: state.attachmentGroupLeaderByMessageId,
              attachmentsByMessageId: state.attachmentMetadataIdsByMessageId,
              emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
            ),
          );
          _requestPendingUnreadDividerEmailContentPreparation();
        }
        emit(
          _withEmailContentPreparationProjection(
            state.copyWith(
              unreadBoundaryStanzaId: boundary,
              scrollTargetMessageId: shouldRequestUnreadScroll
                  ? unreadDividerScrollTargetMessageId
                  : state.scrollTargetMessageId,
              scrollTargetRequestId: shouldRequestUnreadScroll
                  ? state.scrollTargetRequestId + 1
                  : state.scrollTargetRequestId,
              initialUnreadBootstrapStatus: nextInitialUnreadBootstrapStatus,
            ),
          ),
        );
      } else if (nextInitialUnreadBootstrapStatus !=
          state.initialUnreadBootstrapStatus) {
        emit(
          state.copyWith(
            initialUnreadBootstrapStatus: nextInitialUnreadBootstrapStatus,
          ),
        );
      }
      if (boundary != null) {
        _needsUnreadBootstrap = false;
        _pendingUnreadBoundaryCount = null;
        _sessionUnreadBoundaryResolved = true;
      }
    }
    if (typingContextChanged) {
      await _subscribeToTypingParticipants(chat);
      if (_isClosing || emit.isDone) return;
    }
    if (pinnedContextChanged) {
      await _subscribeToPinnedMessages(chat);
      if (_isClosing || emit.isDone) return;
    }
    if (_canPageXmppHistory(chat)) {
      await _hydrateLatestFromMam(chat);
      if (_isClosing || emit.isDone) return;
      if (state.messagesLoaded) {
        await _verifyStaleUnackedMessagesFromMam(chat);
        if (_isClosing || emit.isDone) return;
      } else {
        await _publishVerifiedInitialMessagesForChat(chat, emit);
        if (_isClosing || emit.isDone) return;
      }
    }
    if (showXmppCapabilities) {
      final capabilities = await _resolvePeerCapabilities(chat);
      if (_isClosing || emit.isDone) return;
      if (capabilities != null) {
        emit(state.copyWith(xmppCapabilities: capabilities));
      }
    }
    if (_isClosing || emit.isDone) return;
    if (chat.type == ChatType.groupChat) {
      final shouldPrimeRoomState =
          runFirstChatSideEffects || state.roomState == null;
      if (shouldPrimeRoomState) {
        await _primeRoomState(chat, emit);
        if (_isClosing || emit.isDone) return;
      }
      await _ensureMucMembership(chat);
      if (_isClosing || emit.isDone) return;
      if (runFirstChatSideEffects) {
        await _mucService.refreshRoomAvatar(chat.jid);
      }
      if (_isClosing || emit.isDone) return;
      _roomSubscription = _mucService.roomStateStream(chat.jid).listen((room) {
        add(_RoomStateUpdated(room));
      });
      if (_isClosing || emit.isDone) {
        final roomSubscription = _roomSubscription;
        _roomSubscription = null;
        await _detachAndCancelSubscription(roomSubscription);
        return;
      }
    }
    if (runFirstChatSideEffects) {
      await _syncEmailChatNoticeForActiveChat();
    }
  }

  Future<void> _onChatCapabilitiesRequested(
    ChatCapabilitiesRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null || !_xmppAllowedForChat(chat)) {
      emit(state.copyWith(xmppCapabilities: null));
      return;
    }
    final capabilities = await _resolvePeerCapabilities(
      chat,
      forceRefresh: event.forceRefresh,
    );
    if (capabilities == null) {
      return;
    }
    emit(state.copyWith(xmppCapabilities: capabilities));
  }

  Future<XmppPeerCapabilities?> _resolvePeerCapabilities(
    Chat chat, {
    bool forceRefresh = false,
  }) async {
    if (!_xmppAllowedForChat(chat)) {
      return null;
    }
    final peerJid = chat.remoteJid.isNotEmpty ? chat.remoteJid : chat.jid;
    if (peerJid.trim().isEmpty) {
      return null;
    }
    try {
      return await _messageService.resolvePeerCapabilities(
        jid: peerJid,
        forceRefresh: forceRefresh,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine('Failed to resolve peer capabilities', error, stackTrace);
      return null;
    }
  }

  Future<void> _onRoomStateUpdated(
    _RoomStateUpdated event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = _bareJid(state.chat?.jid);
    if (chatJid == null) return;
    if (chatJid != _bareJid(event.roomState.roomJid)) return;
    final nextRoomSections = _buildRoomMemberSections(event.roomState);
    emit(
      state.copyWith(
        roomState: event.roomState,
        roomMemberSections: nextRoomSections,
      ),
    );
  }

  void _onRoomRosterUpdated(_RoomRosterUpdated event, Emitter<ChatState> emit) {
    _roomRosterItems = event.items;
    _refreshRoomMemberSections(emit);
  }

  void _onRoomChatsUpdated(_RoomChatsUpdated event, Emitter<ChatState> emit) {
    _refreshRoomMemberSections(emit);
  }

  void _onRoomSelfAvatarUpdated(
    _RoomSelfAvatarUpdated event,
    Emitter<ChatState> emit,
  ) {
    _roomSelfAvatarPath = event.avatar?.path;
    _refreshRoomMemberSections(emit);
  }

  void _subscribeRoomMemberSources() {
    final xmppService = _xmppService;
    if (xmppService == null) return;
    _roomChatsAvatarSnapshot = null;
    _roomRosterSubscription = xmppService.rosterStream().listen((items) {
      add(_RoomRosterUpdated(items));
    });
    _roomChatsSubscription = _chatsService.allChatsStream().listen((items) {
      final avatarPaths = _chatAvatarPathsByBareJid(items);
      if (mapEquals(avatarPaths, _roomChatsAvatarSnapshot)) {
        return;
      }
      _roomChatsAvatarSnapshot = avatarPaths;
      add(const _RoomChatsUpdated());
    });
    _roomSelfAvatarSubscription = xmppService.selfAvatarStream.listen(
      (avatar) => add(_RoomSelfAvatarUpdated(avatar)),
    );
    final cachedSelfAvatar = xmppService.cachedSelfAvatar;
    if (cachedSelfAvatar != null) {
      add(_RoomSelfAvatarUpdated(cachedSelfAvatar));
    }
  }

  void _refreshRoomMemberSections(Emitter<ChatState> emit) {
    final roomState = state.roomState;
    if (roomState == null) return;
    emit(
      state.copyWith(roomMemberSections: _buildRoomMemberSections(roomState)),
    );
  }

  List<RoomMemberSection> _buildRoomMemberSections(RoomState roomState) {
    final avatarPathsByBareJid = _buildAvatarPathsByBareJid();
    final selfAvatarPath = _trimmedAvatarPath(
      _roomSelfAvatarPath ?? _xmppService?.cachedSelfAvatar?.path,
    );
    final seen = <String>{};
    final membersByKind = <RoomMemberSectionKind, List<RoomMemberEntry>>{
      RoomMemberSectionKind.owners: <RoomMemberEntry>[],
      RoomMemberSectionKind.admins: <RoomMemberEntry>[],
      RoomMemberSectionKind.moderators: <RoomMemberEntry>[],
      RoomMemberSectionKind.members: <RoomMemberEntry>[],
      RoomMemberSectionKind.participants: <RoomMemberEntry>[],
      RoomMemberSectionKind.visitors: <RoomMemberEntry>[],
    };

    for (final occupant in roomState.occupants.values) {
      if (!seen.add(occupant.occupantId)) continue;
      if (!occupant.hasResolvedMembershipState) continue;
      if (!occupant.isPresent && roomState.isPendingInvitee(occupant)) {
        continue;
      }
      final kind = occupant.memberSectionKind;
      membersByKind[kind]!.add(
        RoomMemberEntry(
          occupant: occupant,
          actions: roomState.moderationActionsFor(occupant),
          avatarPath: _avatarPathForOccupant(
            occupant: occupant,
            roomState: roomState,
            avatarPathsByBareJid: avatarPathsByBareJid,
            selfAvatarPath: selfAvatarPath,
          ),
          directChatJid: roomState.directChatJidForOccupant(occupant),
        ),
      );
    }

    for (final entries in membersByKind.values) {
      entries.sort(
        (a, b) =>
            a.occupant.normalizedNick.compareTo(b.occupant.normalizedNick),
      );
    }

    final sections = <RoomMemberSection>[];
    void addSection(RoomMemberSectionKind kind) {
      final members = membersByKind[kind];
      if (members == null || members.isEmpty) return;
      sections.add(RoomMemberSection(kind: kind, members: members));
    }

    addSection(RoomMemberSectionKind.owners);
    addSection(RoomMemberSectionKind.admins);
    addSection(RoomMemberSectionKind.moderators);
    addSection(RoomMemberSectionKind.members);
    addSection(RoomMemberSectionKind.participants);
    addSection(RoomMemberSectionKind.visitors);
    return sections;
  }

  String? _avatarPathForOccupant({
    required Occupant occupant,
    required RoomState roomState,
    required Map<String, String> avatarPathsByBareJid,
    required String? selfAvatarPath,
  }) {
    if (roomState.isSelfOccupant(occupant)) {
      return selfAvatarPath;
    }
    final bareJid = occupant.normalizedBareRealJid;
    if (bareJid == null) return null;
    return avatarPathsByBareJid[bareJid];
  }

  Map<String, String> _buildAvatarPathsByBareJid() {
    final avatarPaths = <String, String>{};
    for (final item in _roomRosterItems) {
      final jid = _normalizedBareJid(item.jid);
      if (jid == null) continue;
      final path = _trimmedAvatarPath(item.avatarPath);
      if (path == null) continue;
      avatarPaths[jid] = path;
    }
    for (final entry in (_roomChatsAvatarSnapshot ?? const {}).entries) {
      avatarPaths.putIfAbsent(entry.key, () => entry.value);
    }
    return avatarPaths;
  }

  Map<String, String> _chatAvatarPathsByBareJid(List<Chat> chats) {
    final avatarPaths = <String, String>{};
    for (final chat in chats) {
      final jid = _normalizedBareJid(chat.remoteJid);
      if (jid == null) continue;
      final path = _trimmedAvatarPath(
        chat.avatarPath ?? chat.contactAvatarPath,
      );
      if (path == null) continue;
      avatarPaths[jid] = path;
    }
    return avatarPaths;
  }

  String? _normalizedBareJid(String? jid) {
    final bareJid = _bareJid(jid);
    if (bareJid == null || bareJid.isEmpty) return null;
    return bareJid.trim().toLowerCase();
  }

  String? _trimmedAvatarPath(String? path) {
    final trimmed = path?.trim();
    return trimmed?.isNotEmpty == true ? trimmed : null;
  }

  Future<void> _primeRoomState(Chat chat, Emitter<ChatState> emit) async {
    if (chat.type == ChatType.groupChat) {
      await _mucService.seedDummyRoomData(chat.jid);
    }
    final cachedRoom = _mucService.roomStateFor(chat.jid);
    if (cachedRoom != null) {
      await _onRoomStateUpdated(_RoomStateUpdated(cachedRoom), emit);
    }
    try {
      final warmed = await _mucService.prepareRoomMemberState(
        roomJid: chat.jid,
      );
      if (_bareJid(state.chat?.jid) != _bareJid(chat.jid)) return;
      await _onRoomStateUpdated(_RoomStateUpdated(warmed), emit);
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_roomStateWarmFailedLogMessage, error, stackTrace);
    }
  }

  Future<List<PendingAttachment>> _demoPendingAttachmentsForChat({
    required Chat chat,
    required Set<String> existingFileNames,
  }) async {
    if (!kEnableDemoChats) return const <PendingAttachment>[];
    final chatJid = _bareJid(chat.jid);
    if (chatJid == null || chatJid != DemoChats.groupJid) {
      return const <PendingAttachment>[];
    }
    if (_seededDemoPendingAttachmentJids.contains(chatJid)) {
      return const <PendingAttachment>[];
    }
    _seededDemoPendingAttachmentJids.add(chatJid);
    final service = _messageService;
    if (service is! XmppService) {
      return const <PendingAttachment>[];
    }
    final pendingToAdd = <PendingAttachment>[];
    final demoAssets = <DemoAttachmentAsset>[
      ...DemoChats.composerAttachments,
      DemoChats.gmailDocAttachment,
      DemoChats.gmailDocAttachment2,
    ];
    for (final asset in demoAssets) {
      if (existingFileNames.contains(asset.fileName)) {
        continue;
      }
      final materialized = await service.materializeDemoAsset(
        assetPath: asset.assetPath,
        fileName: asset.fileName,
      );
      if (materialized == null) {
        continue;
      }
      pendingToAdd.add(
        PendingAttachment(
          id: 'demo-pending-${asset.fileName}',
          attachment: Attachment(
            path: materialized.path,
            fileName: asset.fileName,
            sizeBytes: materialized.sizeBytes,
            mimeType: asset.mimeType,
            width: materialized.width,
            height: materialized.height,
          ),
        ),
      );
      existingFileNames.add(asset.fileName);
    }
    return pendingToAdd;
  }

  Future<void> _onChatMessagesUpdated(
    _ChatMessagesUpdated event,
    Emitter<ChatState> emit,
  ) async {
    if (event.generation != _messageSubscriptionGeneration) {
      return;
    }
    final stopwatch = Stopwatch()..start();
    var result = 'completed';
    var filteredCount = 0;
    var missingQuoteCount = 0;
    var metadataCount = 0;
    var emittedState = false;
    var hydrationQueued = false;
    void traceEnd() {
      SafeLogging.profileTrace(
        'chat.messagesUpdated',
        'end',
        fields: <String, Object?>{
          'chatHash': state.chat == null
              ? null
              : SafeLogging.profileFingerprint(state.chat!.jid.trim()),
          'result': result,
          'inputCount': event.items.length,
          'filteredCount': filteredCount,
          'missingQuoteCount': missingQuoteCount,
          'metadataCount': metadataCount,
          'emittedState': emittedState,
          'hydrationQueued': hydrationQueued,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    }

    final readStateWasDeferred = _mustDeferAutomaticReadStateSync;
    SafeLogging.profileTrace(
      'chat.messagesUpdated',
      'start',
      fields: <String, Object?>{
        'chatHash': state.chat == null
            ? null
            : SafeLogging.profileFingerprint(state.chat!.jid.trim()),
        'inputCount': event.items.length,
        'emailBacked': _emailBackedMessageCount(event.items),
        'undisplayed': _undisplayedMessageCount(event.items),
      },
    );
    _unreadBootstrapRefreshLimit = null;
    final chat = state.chat;
    final shouldVerifyInitialStaleUnacked =
        chat != null && !state.messagesLoaded;
    final shouldAwaitPageEnrichment =
        shouldVerifyInitialStaleUnacked || event.awaitPageEnrichment;
    final pendingUnreadBoundaryCount = _pendingUnreadBoundaryCount;
    var prepared = await _prepareVisibleChatMessagePage(
      sourceItems: event.items,
      chat: chat,
      verifyInitialStaleUnacked: false,
      loadAttachmentEnrichment: false,
    );
    var filteredItems = prepared.items;
    var hasMoreLocalMessages = prepared.hasMoreLocalMessages;
    var preparedSourceCount = prepared.sourceCount;
    filteredCount = filteredItems.length;
    if (chat == null) {
      _preChatInitialMessages = filteredItems;
    } else {
      _preChatInitialMessages = null;
    }
    if (emit.isDone) {
      result = 'emitDoneAfterPrepare';
      traceEnd();
      return;
    }
    if (event.generation != _messageSubscriptionGeneration) {
      result = 'staleGenerationAfterPrepare';
      traceEnd();
      return;
    }
    if (chat == null) {
      _preChatInitialMessages = filteredItems;
    } else {
      _preChatInitialMessages = null;
    }
    if (emit.isDone) {
      result = 'emitDoneAfterStaleRefresh';
      traceEnd();
      return;
    }
    if (event.generation != _messageSubscriptionGeneration) {
      result = 'staleGenerationAfterStaleRefresh';
      traceEnd();
      return;
    }
    final referencedQuotes = <String, Message>{};
    final knownMessageIds = <String>{...state.quotedMessagesById.keys};
    for (final message in filteredItems) {
      _indexMessageByReference(referencedQuotes, message);
    }
    knownMessageIds.addAll(referencedQuotes.keys);
    final missingQuoteIds = _quotedReferenceIdsForMessages(
      filteredItems,
    ).where((id) => !knownMessageIds.contains(id)).toSet();
    missingQuoteCount = missingQuoteIds.length;
    final updatedQuotedMessages = <String, Message>{
      ...state.quotedMessagesById,
      ...referencedQuotes,
    };
    final storedBoundaryStanzaId = _unreadBoundaryStanzaId;
    final rawUnreadBoundary = _resolveStickyUnreadBoundaryStanzaId(
      chat: state.chat,
      messages: filteredItems,
      storedBoundaryStanzaId: storedBoundaryStanzaId,
      previousBoundaryStanzaId: _sessionUnreadBoundaryResolved
          ? state.unreadBoundaryStanzaId
          : null,
      pendingUnreadBoundaryCount: _pendingUnreadBoundaryCount,
    );
    final unreadBoundary = _resolveVisibleUnreadBoundaryStanzaId(
      boundaryStanzaId: rawUnreadBoundary,
      messages: filteredItems,
      groupLeaderByMessageId: prepared.groupLeaderByMessageId,
      attachmentsByMessageId: prepared.attachmentsByMessageId,
      emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
    );
    _continueUnreadBootstrapIfNeeded(
      rawBoundaryStanzaId: rawUnreadBoundary,
      visibleBoundaryStanzaId: unreadBoundary,
    );
    final nextInitialUnreadBootstrapStatus = _nextInitialUnreadBootstrapStatus(
      rawBoundaryStanzaId: rawUnreadBoundary,
      visibleBoundaryStanzaId: unreadBoundary,
    );
    if (unreadBoundary != null) {
      _needsUnreadBootstrap = false;
      _pendingUnreadBoundaryCount = null;
      _sessionUnreadBoundaryResolved = true;
    }
    final shouldRequestUnreadScroll =
        unreadBoundary != null && !_unreadBoundaryScrollRequested;
    if (shouldRequestUnreadScroll) {
      _unreadBoundaryScrollRequested = true;
    }
    final nextMetadataIds = _metadataIdsForState(
      messages: filteredItems,
      attachmentsByMessageId: prepared.attachmentsByMessageId,
      pinnedMessages: state.pinnedMessages,
    );
    metadataCount = nextMetadataIds.length;
    if (emit.isDone) {
      result = 'emitDoneBeforeState';
      traceEnd();
      return;
    }
    final nextFileMetadataById = _pruneFileMetadataById(
      metadataIds: nextMetadataIds,
      existing: state.fileMetadataById,
    );
    final pendingScrollTargetMessageId = _pendingScrollTargetMessageId;
    final shouldEmitScrollTarget =
        pendingScrollTargetMessageId != null &&
        _containsMessageId(filteredItems, pendingScrollTargetMessageId);
    if (shouldEmitScrollTarget) {
      _pendingScrollTargetMessageId = null;
    }
    final nextScrollTargetMessageId = shouldEmitScrollTarget
        ? pendingScrollTargetMessageId
        : state.scrollTargetMessageId;
    if (shouldRequestUnreadScroll) {
      _retainPendingUnreadDividerEmailContentMessages(
        _unreadDividerEmailContentMessages(
          messages: filteredItems,
          unreadBoundaryStanzaId: unreadBoundary,
          groupLeaderByMessageId: prepared.groupLeaderByMessageId,
          attachmentsByMessageId: prepared.attachmentsByMessageId,
          emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
        ),
      );
      _requestPendingUnreadDividerEmailContentPreparation();
    }
    emit(
      _withEmailContentPreparationProjection(
        state.copyWith(
          items: filteredItems,
          messagesLoaded:
              chat != null &&
              (state.messagesLoaded || !shouldAwaitPageEnrichment),
          hasMoreLocalMessages: hasMoreLocalMessages,
          attachmentMetadataIdsByMessageId: prepared.attachmentsByMessageId,
          attachmentGroupLeaderByMessageId: prepared.groupLeaderByMessageId,
          fileMetadataById: nextFileMetadataById,
          quotedMessagesById: updatedQuotedMessages,
          unreadBoundaryStanzaId: unreadBoundary,
          scrollTargetMessageId: shouldRequestUnreadScroll
              ? unreadDividerScrollTargetMessageId
              : nextScrollTargetMessageId,
          scrollTargetRequestId:
              shouldRequestUnreadScroll || shouldEmitScrollTarget
              ? state.scrollTargetRequestId + 1
              : state.scrollTargetRequestId,
          initialUnreadBootstrapStatus: nextInitialUnreadBootstrapStatus,
        ),
      ),
    );
    emittedState = true;
    if (chat == null) {
      result = 'noChat';
      traceEnd();
      return;
    }
    if (emit.isDone) {
      result = 'emitDoneAfterState';
      traceEnd();
      return;
    }
    if (shouldAwaitPageEnrichment) {
      hydrationQueued = await _applyChatMessagePageEnrichment(
        sourceItems: event.items,
        generation: event.generation,
        chatJid: chat.jid,
        limit: _currentMessageLimit,
        filter: state.viewFilter,
        verifyInitialStaleUnacked: shouldVerifyInitialStaleUnacked,
        pendingUnreadBoundaryCount: pendingUnreadBoundaryCount,
        emit: emit,
      );
      if (!emit.isDone &&
          event.awaitPageEnrichment &&
          state.loadEarlierStatus.isLoading) {
        emit(state.copyWith(loadEarlierStatus: RequestStatus.success));
      }
    } else {
      add(
        _ChatMessagePageEnrichmentRequested(
          sourceItems: event.items,
          generation: event.generation,
          chatJid: chat.jid,
          limit: _currentMessageLimit,
          filter: state.viewFilter,
          verifyInitialStaleUnacked: shouldVerifyInitialStaleUnacked,
          pendingUnreadBoundaryCount: pendingUnreadBoundaryCount,
        ),
      );
      _requestPresentationHydrationForMessages(
        filteredItems,
        missingQuoteIds: missingQuoteIds,
        metadataIds: nextMetadataIds,
        syncFileMetadata: true,
      );
      hydrationQueued = true;
    }
    await _maybeBootstrapUnreadWindow(
      chat: chat,
      filteredOutCount: preparedSourceCount - filteredItems.length,
      pseudoCount: filteredItems
          .where((message) => message.pseudoMessageType != null)
          .length,
      emit: emit,
    );
    if (readStateWasDeferred && !_mustDeferAutomaticReadStateSync) {
      await _syncEmailChatNoticeForActiveChat();
    }
    if (emit.isDone) {
      result = 'emitDoneAfterBootstrap';
      traceEnd();
      return;
    }
    traceEnd();
  }

  Future<void> _onChatMessagePageEnrichmentRequested(
    _ChatMessagePageEnrichmentRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _applyChatMessagePageEnrichment(
      sourceItems: event.sourceItems,
      generation: event.generation,
      chatJid: event.chatJid,
      limit: event.limit,
      filter: event.filter,
      verifyInitialStaleUnacked: event.verifyInitialStaleUnacked,
      pendingUnreadBoundaryCount: event.pendingUnreadBoundaryCount,
      emit: emit,
    );
  }

  Future<bool> _applyChatMessagePageEnrichment({
    required List<Message> sourceItems,
    required int generation,
    required String chatJid,
    required int limit,
    required MessageTimelineFilter filter,
    required bool verifyInitialStaleUnacked,
    required int? pendingUnreadBoundaryCount,
    required Emitter<ChatState> emit,
  }) async {
    bool staleRequest() {
      return generation != _messageSubscriptionGeneration ||
          _currentMessageLimit != limit ||
          state.chat?.jid != chatJid ||
          state.viewFilter != filter;
    }

    if (staleRequest()) {
      return false;
    }
    final chat = state.chat;
    if (chat == null) {
      return false;
    }
    final prepared = await _prepareVisibleChatMessagePage(
      sourceItems: sourceItems,
      chat: chat,
      verifyInitialStaleUnacked: verifyInitialStaleUnacked,
      loadAttachmentEnrichment: true,
    );
    if (emit.isDone || staleRequest()) {
      return false;
    }
    final filteredItems = prepared.items;
    final referencedQuotes = <String, Message>{};
    final knownMessageIds = <String>{...state.quotedMessagesById.keys};
    for (final message in filteredItems) {
      _indexMessageByReference(referencedQuotes, message);
    }
    knownMessageIds.addAll(referencedQuotes.keys);
    final missingQuoteIds = _quotedReferenceIdsForMessages(
      filteredItems,
    ).where((id) => !knownMessageIds.contains(id)).toSet();
    final updatedQuotedMessages = <String, Message>{
      ...state.quotedMessagesById,
      ...referencedQuotes,
    };
    final enrichmentPendingUnreadBoundaryCount = pendingUnreadBoundaryCount;
    final rawUnreadBoundary = _resolveStickyUnreadBoundaryStanzaId(
      chat: state.chat,
      messages: filteredItems,
      storedBoundaryStanzaId: _unreadBoundaryStanzaId,
      previousBoundaryStanzaId:
          enrichmentPendingUnreadBoundaryCount == null &&
              _sessionUnreadBoundaryResolved
          ? state.unreadBoundaryStanzaId
          : null,
      pendingUnreadBoundaryCount:
          enrichmentPendingUnreadBoundaryCount ?? _pendingUnreadBoundaryCount,
    );
    final unreadBoundary = _resolveVisibleUnreadBoundaryStanzaId(
      boundaryStanzaId: rawUnreadBoundary,
      messages: filteredItems,
      groupLeaderByMessageId: prepared.groupLeaderByMessageId,
      attachmentsByMessageId: prepared.attachmentsByMessageId,
      emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
    );
    _continueUnreadBootstrapIfNeeded(
      rawBoundaryStanzaId: rawUnreadBoundary,
      visibleBoundaryStanzaId: unreadBoundary,
    );
    final nextInitialUnreadBootstrapStatus = _nextInitialUnreadBootstrapStatus(
      rawBoundaryStanzaId: rawUnreadBoundary,
      visibleBoundaryStanzaId: unreadBoundary,
    );
    if (unreadBoundary != null) {
      _needsUnreadBootstrap = false;
      _pendingUnreadBoundaryCount = null;
      _sessionUnreadBoundaryResolved = true;
    }
    final shouldRequestUnreadScroll =
        unreadBoundary != null && !_unreadBoundaryScrollRequested;
    if (shouldRequestUnreadScroll) {
      _unreadBoundaryScrollRequested = true;
    }
    final nextMetadataIds = _metadataIdsForState(
      messages: filteredItems,
      attachmentsByMessageId: prepared.attachmentsByMessageId,
      pinnedMessages: state.pinnedMessages,
    );
    final nextFileMetadataById = _pruneFileMetadataById(
      metadataIds: nextMetadataIds,
      existing: state.fileMetadataById,
    );
    final pendingScrollTargetMessageId = _pendingScrollTargetMessageId;
    final shouldEmitScrollTarget =
        pendingScrollTargetMessageId != null &&
        _containsMessageId(filteredItems, pendingScrollTargetMessageId);
    if (shouldEmitScrollTarget) {
      _pendingScrollTargetMessageId = null;
    }
    final nextScrollTargetMessageId = shouldEmitScrollTarget
        ? pendingScrollTargetMessageId
        : state.scrollTargetMessageId;
    if (shouldRequestUnreadScroll) {
      _retainPendingUnreadDividerEmailContentMessages(
        _unreadDividerEmailContentMessages(
          messages: filteredItems,
          unreadBoundaryStanzaId: unreadBoundary,
          groupLeaderByMessageId: prepared.groupLeaderByMessageId,
          attachmentsByMessageId: prepared.attachmentsByMessageId,
          emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
        ),
      );
      _requestPendingUnreadDividerEmailContentPreparation();
    }
    emit(
      _withEmailContentPreparationProjection(
        state.copyWith(
          items: filteredItems,
          messagesLoaded: true,
          hasMoreLocalMessages: prepared.hasMoreLocalMessages,
          attachmentMetadataIdsByMessageId: prepared.attachmentsByMessageId,
          attachmentGroupLeaderByMessageId: prepared.groupLeaderByMessageId,
          fileMetadataById: nextFileMetadataById,
          quotedMessagesById: updatedQuotedMessages,
          unreadBoundaryStanzaId: unreadBoundary,
          scrollTargetMessageId: shouldRequestUnreadScroll
              ? unreadDividerScrollTargetMessageId
              : nextScrollTargetMessageId,
          scrollTargetRequestId:
              shouldRequestUnreadScroll || shouldEmitScrollTarget
              ? state.scrollTargetRequestId + 1
              : state.scrollTargetRequestId,
          initialUnreadBootstrapStatus: nextInitialUnreadBootstrapStatus,
        ),
      ),
    );
    if (emit.isDone || staleRequest()) {
      return true;
    }
    _requestPresentationHydrationForMessages(
      filteredItems,
      missingQuoteIds: missingQuoteIds,
      metadataIds: nextMetadataIds,
      syncFileMetadata: true,
    );
    return true;
  }

  bool _reportVisibleEmailContentMessages(Iterable<Message> messages) {
    final emailService = _emailService;
    if (emailService == null) {
      return false;
    }
    final chatJid = state.chat?.jid ?? _chatLookupJid;
    if (chatJid == null || chatJid.trim().isEmpty) {
      return false;
    }
    final messagesByKey = <EmailContentJobKey, Message>{};
    void addMessage(Message message) {
      if (!_messageBelongsToCurrentChat(message)) {
        return;
      }
      if (!_messageNeedsVisibleEmailContentPreparation(message)) {
        return;
      }
      final key = _emailContentJobKey(message);
      if (key != null) {
        messagesByKey[key] = message;
      }
    }

    for (final message in messages) {
      addMessage(message);
    }
    final visibleMessages = messagesByKey.values.toList(growable: false);
    emailService.reportVisibleEmailContentMessages(
      chatJid: chatJid,
      messages: visibleMessages,
    );
    return visibleMessages.isNotEmpty;
  }

  bool _messageNeedsVisibleEmailContentPreparation(Message message) {
    if (!message.isEmailBacked || message.rfc822BodyContentUnavailable) {
      return false;
    }
    if (!_messageHasProjectedAttachments(message)) {
      return true;
    }
    final hasReadableText =
        message.body?.trim().isNotEmpty == true ||
        message.subject?.trim().isNotEmpty == true;
    if (hasReadableText) {
      return true;
    }
    if (HtmlContentCodec.normalizeHtml(message.htmlBody) != null) {
      return true;
    }
    return false;
  }

  bool _messageHasProjectedAttachments(Message message) {
    final attachmentIds =
        state.attachmentMetadataIdsByMessageId[_messageKey(message)];
    if (attachmentIds?.any((id) => id.trim().isNotEmpty) == true) {
      return true;
    }
    final fallbackId = message.fileMetadataID?.trim();
    return fallbackId != null && fallbackId.isNotEmpty;
  }

  void _refreshEmailContentPreparationSnapshot() {
    final snapshot = _emailService?.contentPreparationSnapshot;
    if (snapshot != null) {
      _emailContentPreparationSnapshot = snapshot;
    }
  }

  void _continueUnreadBootstrapIfNeeded({
    required String? rawBoundaryStanzaId,
    required String? visibleBoundaryStanzaId,
  }) {
    if (visibleBoundaryStanzaId != null ||
        state.initialUnreadBootstrapStatus ==
            ChatInitialUnreadBootstrapStatus.exhausted) {
      return;
    }
    final pendingCount = _pendingUnreadBoundaryCount;
    if ((pendingCount != null && pendingCount > _emptyMessageCount) ||
        rawBoundaryStanzaId?.trim().isNotEmpty == true) {
      _needsUnreadBootstrap = true;
    }
  }

  ChatInitialUnreadBootstrapStatus _nextInitialUnreadBootstrapStatus({
    required String? rawBoundaryStanzaId,
    required String? visibleBoundaryStanzaId,
  }) {
    if (visibleBoundaryStanzaId != null) {
      return ChatInitialUnreadBootstrapStatus.ready;
    }
    if (state.initialUnreadBootstrapStatus ==
        ChatInitialUnreadBootstrapStatus.exhausted) {
      return ChatInitialUnreadBootstrapStatus.exhausted;
    }
    final pendingCount = _pendingUnreadBoundaryCount;
    if (_needsUnreadBootstrap ||
        (pendingCount != null && pendingCount > _emptyMessageCount) ||
        rawBoundaryStanzaId?.trim().isNotEmpty == true) {
      return ChatInitialUnreadBootstrapStatus.loading;
    }
    return state.initialUnreadBootstrapStatus;
  }

  void _emitInitialUnreadBootstrapStatus(
    ChatInitialUnreadBootstrapStatus status,
    Emitter<ChatState> emit,
  ) {
    final shouldClearUnreadDividerScroll =
        status == ChatInitialUnreadBootstrapStatus.exhausted &&
        state.scrollTargetMessageId == unreadDividerScrollTargetMessageId;
    if (emit.isDone ||
        (state.initialUnreadBootstrapStatus == status &&
            !shouldClearUnreadDividerScroll)) {
      return;
    }
    emit(
      state.copyWith(
        initialUnreadBootstrapStatus: status,
        scrollTargetMessageId: shouldClearUnreadDividerScroll
            ? null
            : state.scrollTargetMessageId,
      ),
    );
  }

  void _clearVisibleEmailContentMessagesForCurrentChat() {
    final chatJid = state.chat?.jid ?? _chatLookupJid;
    if (chatJid == null || chatJid.trim().isEmpty) {
      return;
    }
    _emailService?.clearVisibleEmailContentMessages(chatJid);
  }

  void _retainPendingUnreadDividerEmailContentMessages(
    Iterable<Message> messages,
  ) {
    final retained = <EmailContentJobKey, Message>{};
    for (final message in messages) {
      if (!_messageBelongsToCurrentChat(message)) {
        continue;
      }
      if (!_messageNeedsVisibleEmailContentPreparation(message)) {
        continue;
      }
      final key = _emailContentJobKey(message);
      if (key != null) {
        retained[key] = message;
      }
    }
    _pendingUnreadDividerEmailContentMessages =
        Map<EmailContentJobKey, Message>.unmodifiable(retained);
  }

  void _clearPendingUnreadDividerEmailContentMessages() {
    if (_pendingUnreadDividerEmailContentMessages.isEmpty) {
      return;
    }
    _pendingUnreadDividerEmailContentMessages =
        const <EmailContentJobKey, Message>{};
  }

  void _requestPendingUnreadDividerEmailContentPreparation() {
    final emailService = _emailService;
    if (emailService == null ||
        _pendingUnreadDividerEmailContentMessages.isEmpty) {
      return;
    }
    for (final message in _pendingUnreadDividerEmailContentMessages.values) {
      unawaited(
        emailService
            .requestEmailContentPreparation(
              message,
              priority: EmailContentPreparationPriority.manual,
            )
            .catchError((Object error, StackTrace stackTrace) {
              _log.fine(
                'Initial unread email content preparation failed.',
                error,
                stackTrace,
              );
              return false;
            }),
      );
    }
    _refreshEmailContentPreparationSnapshot();
  }

  List<Message> _unreadDividerEmailContentMessages({
    required List<Message> messages,
    required String? unreadBoundaryStanzaId,
    required Map<String, String> groupLeaderByMessageId,
    required Map<String, List<String>> attachmentsByMessageId,
    required Map<int, String> emailFullHtmlByDeltaId,
  }) {
    if (unreadBoundaryStanzaId == null) {
      return const <Message>[];
    }
    int? boundaryIndex;
    for (var index = 0; index < messages.length; index += 1) {
      if (messages[index].stanzaID == unreadBoundaryStanzaId) {
        boundaryIndex = index;
        break;
      }
    }
    if (boundaryIndex == null) {
      return const <Message>[];
    }
    final rfcEmailGroupsByStanzaId = buildRfcEmailGroupsByMessageStanzaId(
      messages: messages,
      attachmentsForMessage: (message) =>
          attachmentsByMessageId[_messageKey(message)] ?? const <String>[],
      bodyTextForMessage: (message) => rfcEmailBodyText(
        message: message,
        resolvedHtmlBody: resolvedEmailHtmlBodyForMessage(
          message: message,
          emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
          deriveHtmlIfMissing: false,
        ),
        deriveHtmlIfMissing: false,
      ),
      isAuthoritativeBody: (message) => message.hasRfc822BodyContent,
      requireMeaningfulBody: false,
    );
    final byStanzaId = <String, Message>{};
    final groupLeaderIds = <String>{};
    final rfcGroupLeaderStanzaIds = <String>{};
    void addTrackedMessage(Message message) {
      byStanzaId[message.stanzaID] = message;
      final leaderId = groupLeaderByMessageId[_messageKey(message)];
      if (leaderId != null) {
        groupLeaderIds.add(leaderId);
      }
      final group = rfcEmailGroupsByStanzaId[message.stanzaID];
      final groupLeaderStanzaId = group?.leader.stanzaID.trim();
      if (groupLeaderStanzaId != null && groupLeaderStanzaId.isNotEmpty) {
        rfcGroupLeaderStanzaIds.add(groupLeaderStanzaId);
      }
    }

    for (var index = 0; index <= boundaryIndex; index += 1) {
      addTrackedMessage(messages[index]);
    }
    if (groupLeaderIds.isNotEmpty || rfcGroupLeaderStanzaIds.isNotEmpty) {
      for (final message in messages) {
        final leaderId = groupLeaderByMessageId[_messageKey(message)];
        final group = rfcEmailGroupsByStanzaId[message.stanzaID];
        final groupLeaderStanzaId = group?.leader.stanzaID.trim();
        if ((leaderId != null && groupLeaderIds.contains(leaderId)) ||
            (groupLeaderStanzaId != null &&
                rfcGroupLeaderStanzaIds.contains(groupLeaderStanzaId))) {
          addTrackedMessage(message);
        }
      }
    }
    return byStanzaId.values
        .where((message) => _emailContentJobKey(message) != null)
        .toList(growable: false);
  }

  ChatState _withEmailContentPreparationProjection(ChatState base) {
    final originalProjected = _withEmailOriginalContentProjection(base);
    final loading = _emailFullMessageLoadingForState(base);
    if (setEquals(loading, originalProjected.emailFullMessageLoading) &&
        originalProjected.emailContentPreparationRevision ==
            _emailContentPreparationSnapshot.revision) {
      return originalProjected;
    }
    return originalProjected.copyWith(
      emailFullMessageLoading: loading,
      emailContentPreparationRevision:
          _emailContentPreparationSnapshot.revision,
    );
  }

  ChatState _withEmailOriginalContentProjection(ChatState base) {
    final keysByDeltaId = <int, EmailContentJobKey>{};
    for (final message in _emailContentMessagesForState(base)) {
      final deltaMessageId = message.deltaMsgId;
      final key = _emailContentJobKey(message);
      if (deltaMessageId != null && key != null) {
        keysByDeltaId[deltaMessageId] = key;
      }
    }
    if (keysByDeltaId.isEmpty) {
      if (base.emailFullHtmlByDeltaId.isEmpty &&
          base.emailFullHtmlLoading.isEmpty &&
          base.emailFullHtmlUnavailable.isEmpty) {
        return base;
      }
      return base.copyWith(
        emailFullHtmlByDeltaId: const <int, String>{},
        emailFullHtmlLoading: const <int>{},
        emailFullHtmlUnavailable: const <int>{},
      );
    }
    final htmlByDeltaId = <int, String>{};
    final loading = <int>{};
    final unavailable = <int>{};
    for (final entry in keysByDeltaId.entries) {
      final key = entry.value;
      final html = _emailOriginalContentSnapshot.htmlByKey[key];
      if (html != null) {
        htmlByDeltaId[entry.key] = html;
      }
      if (_emailOriginalContentSnapshot.loadingKeys.contains(key)) {
        loading.add(entry.key);
      }
      if (_emailOriginalContentSnapshot.unavailableKeys.contains(key)) {
        unavailable.add(entry.key);
      }
    }
    if (mapEquals(htmlByDeltaId, base.emailFullHtmlByDeltaId) &&
        setEquals(loading, base.emailFullHtmlLoading) &&
        setEquals(unavailable, base.emailFullHtmlUnavailable)) {
      return base;
    }
    return base.copyWith(
      emailFullHtmlByDeltaId: Map<int, String>.unmodifiable(htmlByDeltaId),
      emailFullHtmlLoading: Set<int>.unmodifiable(loading),
      emailFullHtmlUnavailable: Set<int>.unmodifiable(unavailable),
    );
  }

  Set<int> _emailFullMessageLoadingForState(ChatState base) {
    final activeKeys =
        _emailContentPreparationSnapshot.activeLoadingIndicatorKeys;
    if (activeKeys.isEmpty) {
      return const <int>{};
    }
    final loading = <int>{};
    for (final message in _emailContentMessagesForState(base)) {
      final key = _emailContentJobKey(message);
      final deltaMessageId = message.deltaMsgId;
      if (key != null && deltaMessageId != null && activeKeys.contains(key)) {
        loading.add(deltaMessageId);
      }
    }
    return Set<int>.unmodifiable(loading);
  }

  Iterable<Message> _emailContentMessagesForState(ChatState base) sync* {
    yield* base.items;
    final focused = base.focused;
    if (focused != null) {
      yield focused;
    }
    for (final item in base.pinnedMessages) {
      final message = item.message;
      if (message != null) {
        yield message;
      }
    }
  }

  EmailContentJobKey? _emailContentJobKey(Message message) {
    final deltaMessageId = message.deltaMsgId;
    if (!message.isEmailBacked ||
        deltaMessageId == null ||
        deltaMessageId <= _deltaMessageIdUnset) {
      return null;
    }
    return EmailContentJobKey(
      deltaAccountId: message.deltaAccountId,
      deltaChatId: message.deltaChatId ?? 0,
      deltaMsgId: deltaMessageId,
    );
  }

  Future<
    ({
      List<Message> items,
      int sourceCount,
      bool hasMoreLocalMessages,
      Map<String, List<String>> attachmentsByMessageId,
      Map<String, String> groupLeaderByMessageId,
    })
  >
  _prepareVisibleChatMessagePage({
    required List<Message> sourceItems,
    required Chat? chat,
    required bool verifyInitialStaleUnacked,
    required bool loadAttachmentEnrichment,
  }) async {
    final attachmentMaps = loadAttachmentEnrichment
        ? await _loadAttachmentMaps(sourceItems)
        : _directAttachmentMaps(sourceItems);
    final filtered = loadAttachmentEnrichment
        ? await _filterInternalMessages(
            messages: sourceItems,
            attachmentsByMessageId: attachmentMaps.attachmentsByMessageId,
            groupLeaderByMessageId: attachmentMaps.groupLeaderByMessageId,
          )
        : _filterBodyInternalMessages(
            messages: sourceItems,
            attachmentsByMessageId: attachmentMaps.attachmentsByMessageId,
            groupLeaderByMessageId: attachmentMaps.groupLeaderByMessageId,
          );
    var filteredItems = _messagesWithAttachmentGroupQuoteFallback(
      messages: filtered.messages,
      groupQuotedReferenceByMessageId:
          attachmentMaps.groupQuotedReferenceByMessageId,
    );
    filteredItems = _messagesNewestFirst(filteredItems);
    final hasMoreLocalMessages =
        sourceItems.length > _currentMessageLimit ||
        filteredItems.length > _currentMessageLimit;
    if (filteredItems.length > _currentMessageLimit) {
      filteredItems = filteredItems
          .take(_currentMessageLimit)
          .toList(growable: false);
    }
    if (chat != null && verifyInitialStaleUnacked) {
      filteredItems = await _verifyAndRefreshInitialStaleUnackedMessages(
        chat: chat,
        messages: filteredItems,
      );
      filteredItems = _messagesWithAttachmentGroupQuoteFallback(
        messages: filteredItems,
        groupQuotedReferenceByMessageId:
            attachmentMaps.groupQuotedReferenceByMessageId,
      );
      filteredItems = _messagesNewestFirst(filteredItems);
    }
    return (
      items: filteredItems,
      sourceCount: sourceItems.length,
      hasMoreLocalMessages: hasMoreLocalMessages,
      attachmentsByMessageId: filtered.attachmentsByMessageId,
      groupLeaderByMessageId: filtered.groupLeaderByMessageId,
    );
  }

  int _emailBackedMessageCount(Iterable<Message> messages) {
    var count = 0;
    for (final message in messages) {
      if (message.isEmailBacked) {
        count += 1;
      }
    }
    return count;
  }

  int _undisplayedMessageCount(Iterable<Message> messages) {
    var count = 0;
    for (final message in messages) {
      if (!message.displayed) {
        count += 1;
      }
    }
    return count;
  }

  Set<String> _quotedReferenceIdsForMessages(Iterable<Message> messages) {
    final ids = <String>{};
    for (final message in messages) {
      final quotedId = message.storedReplyId;
      if (quotedId == null || quotedId.isEmpty) {
        continue;
      }
      ids.add(quotedId);
    }
    return ids;
  }

  Set<String> _messageReferenceIdsForMessages(Iterable<Message> messages) {
    final ids = <String>{};
    for (final message in messages) {
      for (final referenceId in message.referenceIds) {
        final normalized = referenceId.trim();
        if (normalized.isNotEmpty) {
          ids.add(normalized);
        }
      }
    }
    return ids;
  }

  Set<int> _deltaMessageIdsForMessages(Iterable<Message> messages) {
    final ids = <int>{};
    for (final message in messages) {
      final deltaMessageId = message.deltaMsgId;
      if (deltaMessageId != null && deltaMessageId > _deltaMessageIdUnset) {
        ids.add(deltaMessageId);
      }
    }
    return ids;
  }

  bool _messageBelongsToCurrentChat(Message message) {
    final chatJid = state.chat?.jid ?? _chatLookupJid;
    if (chatJid == null || chatJid.trim().isEmpty) {
      return false;
    }
    return sameBareAddress(message.chatJid, chatJid);
  }

  void _requestPresentationHydrationForMessages(
    Iterable<Message> messages, {
    Set<String> missingQuoteIds = const <String>{},
    Set<String> metadataIds = const <String>{},
    bool hydrateEmailContent = false,
    bool allowOffWindowEmailContentHydration = false,
    bool syncFileMetadata = false,
  }) {
    final renderedMessages = messages
        .where(_messageBelongsToCurrentChat)
        .toList(growable: false);
    if (renderedMessages.isEmpty &&
        missingQuoteIds.isEmpty &&
        metadataIds.isEmpty &&
        !syncFileMetadata) {
      return;
    }
    final messageReferenceIds = Set<String>.unmodifiable(
      _messageReferenceIdsForMessages(renderedMessages),
    );
    final deltaMessageIds = Set<int>.unmodifiable(
      _deltaMessageIdsForMessages(renderedMessages),
    );
    SafeLogging.profileTrace(
      'chat.presentationHydration',
      'queued',
      fields: <String, Object?>{
        'chatHash': state.chat == null
            ? null
            : SafeLogging.profileFingerprint(state.chat!.jid.trim()),
        'renderedCount': renderedMessages.length,
        'referenceCount': messageReferenceIds.length,
        'deltaCount': deltaMessageIds.length,
        'missingQuoteCount': missingQuoteIds.length,
        'metadataCount': metadataIds.length,
        'hydrateEmailContent': hydrateEmailContent,
        'allowOffWindow': allowOffWindowEmailContentHydration,
        'syncFileMetadata': syncFileMetadata,
      },
    );
    add(
      _ChatPresentationHydrationRequested(
        messageReferenceIds: messageReferenceIds,
        deltaMessageIds: deltaMessageIds,
        missingQuoteIds: Set<String>.unmodifiable(missingQuoteIds),
        metadataIds: Set<String>.unmodifiable(metadataIds),
        renderedMessages: renderedMessages,
        hydrateEmailContent: hydrateEmailContent,
        allowOffWindowEmailContentHydration:
            allowOffWindowEmailContentHydration,
        syncFileMetadata: syncFileMetadata,
      ),
    );
  }

  Future<void> _onChatEmailContentPreparationUpdated(
    _ChatEmailContentPreparationUpdated event,
    Emitter<ChatState> emit,
  ) async {
    final previousBodyKeys =
        _emailContentPreparationSnapshot.activeBodyHydrationKeys;
    final completedBodyKeys = previousBodyKeys.difference(
      event.snapshot.activeBodyHydrationKeys,
    );
    if (completedBodyKeys.isNotEmpty) {
      await _refreshVisibleAttachmentProjection(emit);
      if (emit.isDone) {
        return;
      }
    }
    _emailContentPreparationSnapshot = event.snapshot;
    emit(_withEmailContentPreparationProjection(state));
  }

  void _onChatEmailOriginalContentUpdated(
    _ChatEmailOriginalContentUpdated event,
    Emitter<ChatState> emit,
  ) {
    _emailOriginalContentSnapshot = event.snapshot;
    emit(_withEmailContentPreparationProjection(state));
  }

  Future<void> _onChatEmailFullMessageDownloaded(
    _ChatEmailFullMessageDownloaded event,
    Emitter<ChatState> emit,
  ) async {
    if (event.stanzaId.trim().isEmpty) {
      return;
    }
    await _refreshVisibleAttachmentProjection(emit);
  }

  void _onChatRenderedMessagesHydrationRequested(
    ChatRenderedMessagesHydrationRequested event,
    Emitter<ChatState> _,
  ) {
    final messages = _messagesForRenderedEmailContentHydration(event.messages);
    SafeLogging.profileTrace(
      'chat.renderedHydration',
      'requested',
      fields: <String, Object?>{
        'chatHash': state.chat == null
            ? null
            : SafeLogging.profileFingerprint(state.chat!.jid.trim()),
        'renderedCount': event.messages.length,
        'expandedCount': messages.length,
        'allowOffWindow': event.allowOffWindowEmailContentHydration,
      },
    );
    final emailContentReported = _reportVisibleEmailContentMessages(messages);
    final emailQuotedTextQueued = _maybeRequestVisibleEmailQuotedText(
      messages,
      allowOffWindow: event.allowOffWindowEmailContentHydration,
    );
    SafeLogging.profileTrace(
      'chat.renderedHydration',
      'end',
      fields: <String, Object?>{
        'chatHash': state.chat == null
            ? null
            : SafeLogging.profileFingerprint(state.chat!.jid.trim()),
        'messageCount': messages.length,
        'emailContentReported': emailContentReported,
        'emailQuotedTextQueued': emailQuotedTextQueued,
        'allowOffWindow': event.allowOffWindowEmailContentHydration,
      },
    );
  }

  Future<void> _onChatUnreadDividerScrollCompleted(
    ChatUnreadDividerScrollCompleted event,
    Emitter<ChatState> emit,
  ) async {
    if (event.requestId != state.scrollTargetRequestId ||
        state.scrollTargetMessageId != unreadDividerScrollTargetMessageId) {
      return;
    }
    _clearPendingUnreadDividerEmailContentMessages();
    emit(
      state.copyWith(
        scrollTargetMessageId: null,
        initialUnreadBootstrapStatus: ChatInitialUnreadBootstrapStatus.idle,
      ),
    );
    await _syncEmailChatNoticeForActiveChat();
  }

  Future<void> _onChatUnreadDividerScrollAbandoned(
    ChatUnreadDividerScrollAbandoned event,
    Emitter<ChatState> emit,
  ) async {
    if (event.requestId != state.scrollTargetRequestId ||
        state.scrollTargetMessageId != unreadDividerScrollTargetMessageId) {
      return;
    }
    _clearPendingUnreadDividerEmailContentMessages();
    emit(
      state.copyWith(
        scrollTargetMessageId: null,
        initialUnreadBootstrapStatus: ChatInitialUnreadBootstrapStatus.idle,
      ),
    );
    await _syncEmailChatNoticeForActiveChat();
  }

  List<Message> _messagesForRenderedEmailContentHydration(
    List<Message> renderedMessages,
  ) {
    return renderedMessages
        .where(_messageBelongsToCurrentChat)
        .toList(growable: false);
  }

  List<Message> _messagesForPresentationHydration(
    _ChatPresentationHydrationRequested event,
  ) {
    final messages = <Message>[];
    void addMessage(Message? message) {
      if (message == null) {
        return;
      }
      if (!_messageBelongsToCurrentChat(message)) {
        return;
      }
      if (_messageMatchesPresentationHydration(message, event) &&
          !messages.contains(message)) {
        messages.add(message);
      }
    }

    for (final message in state.items) {
      addMessage(message);
    }
    addMessage(state.focused);
    for (final item in state.pinnedMessages) {
      addMessage(item.message);
    }
    for (final message in event.renderedMessages) {
      addMessage(message);
    }
    return messages;
  }

  bool _messageMatchesPresentationHydration(
    Message message,
    _ChatPresentationHydrationRequested event,
  ) {
    final deltaMessageId = message.deltaMsgId;
    if (deltaMessageId != null &&
        event.deltaMessageIds.contains(deltaMessageId)) {
      return true;
    }
    for (final referenceId in message.referenceIds) {
      if (event.messageReferenceIds.contains(referenceId.trim())) {
        return true;
      }
    }
    return false;
  }

  Future<void> _onChatPresentationHydrationRequested(
    _ChatPresentationHydrationRequested event,
    Emitter<ChatState> emit,
  ) async {
    final stopwatch = Stopwatch()..start();
    var result = 'completed';
    var messageCount = 0;
    var missingQuoteCount = 0;
    var loadedQuoteCount = 0;
    var metadataCount = 0;
    var emailContentReported = false;
    var emailQuotedTextQueued = 0;
    var shareHydrated = false;
    try {
      var messages = _messagesForPresentationHydration(event);
      messageCount = messages.length;

      final currentQuoteIds = _quotedReferenceIdsForMessages(messages);
      final missingQuoteIds = event.missingQuoteIds
          .where(
            (id) =>
                currentQuoteIds.contains(id) &&
                !state.quotedMessagesById.containsKey(id),
          )
          .toSet();
      missingQuoteCount = missingQuoteIds.length;
      if (missingQuoteIds.isNotEmpty) {
        final loadedQuotes = await _messageService.loadMessagesByReferenceIds(
          missingQuoteIds,
          chatJid: state.chat?.jid,
        );
        loadedQuoteCount = loadedQuotes.length;
        if (emit.isDone) {
          result = 'emitDoneAfterQuotes';
          return;
        }
        messages = _messagesForPresentationHydration(event);
        messageCount = messages.length;
        final refreshedQuoteIds = _quotedReferenceIdsForMessages(messages);
        final updatedQuotedMessages = <String, Message>{
          ...state.quotedMessagesById,
        };
        var changed = false;
        for (final message in loadedQuotes) {
          if (!message.referenceIds.any(refreshedQuoteIds.contains)) {
            continue;
          }
          for (final referenceId in message.referenceIds) {
            if (updatedQuotedMessages[referenceId] != message) {
              updatedQuotedMessages[referenceId] = message;
              changed = true;
            }
          }
        }
        if (changed) {
          emit(state.copyWith(quotedMessagesById: updatedQuotedMessages));
        }
      }

      if (emit.isDone) {
        result = 'emitDoneBeforeMetadata';
        return;
      }
      if (event.syncFileMetadata) {
        final currentMetadataIds = _metadataIdsForState(
          messages: state.items,
          attachmentsByMessageId: state.attachmentMetadataIdsByMessageId,
          pinnedMessages: state.pinnedMessages,
        );
        final metadataIds = event.metadataIds
            .where(currentMetadataIds.contains)
            .toSet();
        metadataCount = metadataIds.length;
        await _syncFileMetadataSubscriptions(metadataIds);
        if (emit.isDone) {
          result = 'emitDoneAfterMetadata';
          return;
        }
      }

      messages = _messagesForPresentationHydration(event);
      messageCount = messages.length;
      if (messages.isEmpty) {
        result = 'noMessages';
        return;
      }
      if (event.hydrateEmailContent) {
        emailContentReported = _reportVisibleEmailContentMessages(messages);
        emailQuotedTextQueued = _maybeRequestVisibleEmailQuotedText(
          messages,
          allowOffWindow: event.allowOffWindowEmailContentHydration,
        );
      }

      if (messages.any((message) => message.deltaMsgId != null)) {
        await _hydrateShareContexts(messages, emit);
        shareHydrated = true;
        if (emit.isDone) {
          result = 'emitDoneAfterShareContexts';
          return;
        }
        await _hydrateShareReplies(
          _messagesForPresentationHydration(event),
          emit,
        );
        if (emit.isDone) {
          result = 'emitDoneAfterShareReplies';
          return;
        }
      }

      _queueAutoDownloadAttachments(
        messages: _messagesForPresentationHydration(event),
        attachmentsByMessageId: state.attachmentMetadataIdsByMessageId,
      );
    } finally {
      SafeLogging.profileTrace(
        'chat.presentationHydration',
        'end',
        fields: <String, Object?>{
          'chatHash': state.chat == null
              ? null
              : SafeLogging.profileFingerprint(state.chat!.jid.trim()),
          'result': result,
          'messageCount': messageCount,
          'missingQuoteCount': missingQuoteCount,
          'loadedQuoteCount': loadedQuoteCount,
          'metadataCount': metadataCount,
          'hydrateEmailContent': event.hydrateEmailContent,
          'emailContentReported': emailContentReported,
          'emailQuotedTextQueued': emailQuotedTextQueued,
          'shareHydrated': shareHydrated,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    }
  }

  String? _resolveStickyUnreadBoundaryStanzaId({
    required Chat? chat,
    required List<Message> messages,
    required String? storedBoundaryStanzaId,
    required String? previousBoundaryStanzaId,
    required int? pendingUnreadBoundaryCount,
  }) {
    final previousBoundary = previousBoundaryStanzaId?.trim();
    if (previousBoundary != null && previousBoundary.isNotEmpty) {
      return previousBoundary;
    }
    final pendingCount = pendingUnreadBoundaryCount;
    if (pendingCount == null || pendingCount <= _emptyMessageCount) {
      return null;
    }
    final storedBoundary = storedBoundaryStanzaId?.trim();
    if (storedBoundary != null && storedBoundary.isNotEmpty) {
      return storedBoundary;
    }
    final countBoundary = _resolveUnreadBoundaryFromCount(
      messages: messages,
      unreadCount: pendingCount,
    );
    if (countBoundary != null && countBoundary.isNotEmpty) {
      return countBoundary;
    }
    return null;
  }

  String? _resolveUnreadBoundaryFromCount({
    required List<Message> messages,
    required int unreadCount,
  }) {
    if (unreadCount <= _emptyMessageCount) {
      return null;
    }
    var remaining = unreadCount;
    for (final message in messages) {
      if (!_isUnreadCandidate(message)) {
        continue;
      }
      remaining -= 1;
      if (remaining <= 0) {
        final stanzaId = message.stanzaID.trim();
        return stanzaId.isEmpty ? null : stanzaId;
      }
    }
    return null;
  }

  String? _resolveVisibleUnreadBoundaryStanzaId({
    required String? boundaryStanzaId,
    required List<Message> messages,
    required Map<String, String> groupLeaderByMessageId,
    required Map<String, List<String>> attachmentsByMessageId,
    required Map<int, String> emailFullHtmlByDeltaId,
  }) {
    final boundary = boundaryStanzaId?.trim();
    if (boundary == null || boundary.isEmpty) {
      return null;
    }
    Message? boundaryMessage;
    for (final message in messages) {
      if (message.stanzaID == boundary) {
        boundaryMessage = message;
        break;
      }
    }
    if (boundaryMessage == null) {
      return null;
    }
    final rfcEmailGroup = buildRfcEmailGroupsByMessageStanzaId(
      messages: messages,
      attachmentsForMessage: (message) =>
          attachmentsByMessageId[_messageKey(message)] ?? const <String>[],
      bodyTextForMessage: (message) => rfcEmailBodyText(
        message: message,
        resolvedHtmlBody: resolvedEmailHtmlBodyForMessage(
          message: message,
          emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
          deriveHtmlIfMissing: false,
        ),
        deriveHtmlIfMissing: false,
      ),
      isAuthoritativeBody: (message) => message.hasRfc822BodyContent,
      requireMeaningfulBody: false,
    )[boundary];
    final rfcEmailLeaderStanzaId = rfcEmailGroup?.leader.stanzaID.trim();
    if (rfcEmailLeaderStanzaId != null && rfcEmailLeaderStanzaId.isNotEmpty) {
      return rfcEmailLeaderStanzaId;
    }
    final boundaryMessageId = _messageKey(boundaryMessage);
    final leaderId = groupLeaderByMessageId[boundaryMessageId];
    if (leaderId == null || leaderId == boundaryMessageId) {
      return boundary;
    }
    for (final message in messages) {
      if (_messageKey(message) != leaderId) {
        continue;
      }
      final leaderBoundary = message.stanzaID.trim();
      if (leaderBoundary.isEmpty) {
        return boundary;
      }
      return leaderBoundary;
    }
    return boundary;
  }

  bool _countsTowardUnread(Message message) {
    final chat = state.chat;
    if (chat == null) {
      return message.hasUnreadContent;
    }
    return message.countsTowardUnread(
      selfJid: _selfJidForUnread(message),
      isGroupChat: chat.type == ChatType.groupChat,
      myOccupantJid: state.roomState?.myOccupantJid,
    );
  }

  bool _isUnreadCandidate(Message message) =>
      !message.displayed && _countsTowardUnread(message);

  String? _selfJidForUnread(Message message) {
    final chat = state.chat;
    if (message.isEmailBacked || chat?.defaultTransport.isEmail == true) {
      return state.emailSelfJid;
    }
    return _chatsService.myJid;
  }

  Future<String?> _resolveUnreadBoundaryStanzaId(
    Chat? chat, {
    int? unreadCount,
  }) async {
    if (chat == null) {
      return null;
    }
    final targetUnreadCount = unreadCount ?? chat.unreadCount;
    if (targetUnreadCount <= _emptyMessageCount) {
      _unreadBoundaryStanzaId = null;
      return null;
    }
    if (chat.defaultTransport.isEmail) {
      final oldestEmailUnread = await _emailService
          ?.loadOldestUnreadEmailBackedMessageForChat(
            chat,
            selfJid: selfJid,
            emailSelfJid: state.emailSelfJid,
            unreadCount: targetUnreadCount,
            filter: state.viewFilter,
          );
      final oldestEmailStanzaId = oldestEmailUnread?.stanzaID.trim();
      _unreadBoundaryStanzaId =
          oldestEmailStanzaId == null || oldestEmailStanzaId.isEmpty
          ? null
          : oldestEmailStanzaId;
      return _unreadBoundaryStanzaId;
    }
    final oldestUnread = await _messageService.loadOldestUnreadMessageForChat(
      chat,
      selfJid: selfJid,
      emailSelfJid: state.emailSelfJid,
      myOccupantJid: state.roomState?.myOccupantJid,
      filter: state.viewFilter,
    );
    final oldestStanzaId = oldestUnread?.stanzaID.trim();
    _unreadBoundaryStanzaId = oldestStanzaId == null || oldestStanzaId.isEmpty
        ? null
        : oldestStanzaId;
    return _unreadBoundaryStanzaId;
  }

  Future<void> _maybeBootstrapUnreadWindow({
    required Chat chat,
    required int filteredOutCount,
    required int pseudoCount,
    required Emitter<ChatState> emit,
  }) async {
    if (!_needsUnreadBootstrap) {
      return;
    }
    final unreadTargetCount = _pendingUnreadBoundaryCount ?? chat.unreadCount;
    if (unreadTargetCount <= _emptyMessageCount) {
      _needsUnreadBootstrap = false;
      _emitInitialUnreadBootstrapStatus(
        ChatInitialUnreadBootstrapStatus.idle,
        emit,
      );
      return;
    }
    _needsUnreadBootstrap = false;
    _emitInitialUnreadBootstrapStatus(
      ChatInitialUnreadBootstrapStatus.loading,
      emit,
    );
    final desiredWindow = unreadTargetCount + filteredOutCount + pseudoCount;
    final batchSize = _timelineBatchSizeForChat(chat);
    final unboundedDesiredLimit = desiredWindow > batchSize
        ? desiredWindow
        : batchSize;
    final desiredLimit = unboundedDesiredLimit;
    final storedBoundaryStanzaId = _unreadBoundaryStanzaId;
    Message? boundaryMessage;
    if (storedBoundaryStanzaId != null) {
      boundaryMessage = await _ensureImportantMessageAvailableLocally(
        chat: chat,
        messageId: storedBoundaryStanzaId,
      );
    }
    if (chat.defaultTransport.isEmail) {
      final boundary = await _emailService
          ?.loadOldestUnreadEmailBackedMessageForChat(
            chat,
            selfJid: selfJid,
            emailSelfJid: state.emailSelfJid,
            unreadCount: unreadTargetCount,
            filter: state.viewFilter,
          );
      final boundaryStanzaId = boundary?.stanzaID.trim();
      if (boundary != null &&
          boundaryStanzaId != null &&
          boundaryStanzaId.isNotEmpty) {
        _unreadBoundaryStanzaId = boundaryStanzaId;
        await _subscribeThroughMessage(chat: chat, target: boundary);
        return;
      }
      _pendingUnreadBoundaryCount = null;
      _clearPendingUnreadDividerEmailContentMessages();
      _emitInitialUnreadBootstrapStatus(
        ChatInitialUnreadBootstrapStatus.exhausted,
        emit,
      );
      return;
    }
    if (_xmppAllowedForChat(chat)) {
      await _ensureUnreadWindowLoaded(
        chat: chat,
        desiredWindow: desiredLimit,
        unreadTargetCount: unreadTargetCount,
      );
    }
    if (storedBoundaryStanzaId != null) {
      boundaryMessage ??= await _ensureImportantMessageAvailableLocally(
        chat: chat,
        messageId: storedBoundaryStanzaId,
      );
      if (boundaryMessage != null) {
        await _subscribeThroughMessage(chat: chat, target: boundaryMessage);
        return;
      }
    }
    if (desiredLimit != _currentMessageLimit) {
      _unreadBootstrapRefreshLimit = desiredLimit;
      await _subscribeToMessages(limit: desiredLimit, filter: state.viewFilter);
      return;
    }
    _pendingUnreadBoundaryCount = null;
    _clearPendingUnreadDividerEmailContentMessages();
    _emitInitialUnreadBootstrapStatus(
      ChatInitialUnreadBootstrapStatus.exhausted,
      emit,
    );
  }

  Future<void> _onPinnedMessagesUpdated(
    _PinnedMessagesUpdated event,
    Emitter<ChatState> emit,
  ) async {
    if (!_isCurrentPinnedMessagesSource(event.sourceKey)) {
      return;
    }
    try {
      await _applyPinnedMessagesUpdated(
        sourceKey: event.sourceKey,
        entries: event.items,
        emit: emit,
      );
    } on XmppException catch (error, stackTrace) {
      _log.safeFine('Failed to apply pinned messages.', error, stackTrace);
      if (!_isCurrentPinnedMessagesSource(event.sourceKey)) {
        return;
      }
      _emitPinnedMessagesLoadFailureIfRelevant(emit);
    }
  }

  void _onPinnedMessagesLoadFailed(
    _PinnedMessagesLoadFailed event,
    Emitter<ChatState> emit,
  ) {
    if (!_isCurrentPinnedMessagesSource(event.sourceKey)) {
      return;
    }
    _emitPinnedMessagesLoadFailureIfRelevant(emit);
  }

  void _emitPinnedMessagesLoadFailureIfRelevant(Emitter<ChatState> emit) {
    if (state.pinnedMessagesStatus.hasSnapshot) {
      return;
    }
    if (!state.pinnedMessagesStatus.showsPanelLoading) {
      return;
    }
    emit(
      state.copyWith(pinnedMessagesStatus: ChatPinnedMessagesStatus.failure),
    );
  }

  bool _isCurrentPinnedMessagesSource(String? sourceKey) {
    return sourceKey == _pinnedMessagesSourceKey;
  }

  Future<void> _applyPinnedMessagesUpdated({
    required String? sourceKey,
    required List<PinnedMessageAggregate> entries,
    required Emitter<ChatState> emit,
  }) async {
    var pinnedItems = _emptyPinnedMessageItems;
    if (entries.isNotEmpty) {
      final orderedIds = <String>{};
      for (final entry in entries) {
        final messageId = entry.messageReferenceId.trim();
        if (messageId.isEmpty) {
          continue;
        }
        orderedIds.add(messageId);
      }
      if (orderedIds.isNotEmpty) {
        final messages = await _messageService.loadMessagesByReferenceIds(
          orderedIds,
          chatJid: state.chat?.jid,
        );
        if (!_isCurrentPinnedMessagesSource(sourceKey)) return;
        final messageByReference = <String, Message>{};
        for (final message in state.items) {
          _indexMessageByReference(messageByReference, message);
        }
        for (final message in messages) {
          _indexMessageByReference(messageByReference, message);
        }
        final attachmentMaps = await _loadAttachmentMaps(messages);
        if (!_isCurrentPinnedMessagesSource(sourceKey)) return;
        pinnedItems = <PinnedMessageItem>[];
        for (final entry in entries) {
          final messageId = entry.messageReferenceId.trim();
          if (messageId.isEmpty) {
            continue;
          }
          final message = messageByReference[messageId];
          final attachmentIds = message == null
              ? _emptyPinnedAttachmentIds
              : attachmentMaps.attachmentsByMessageId[_messageKey(message)] ??
                    _emptyPinnedAttachmentIds;
          pinnedItems.add(
            PinnedMessageItem(
              messageStanzaId: messageId,
              chatJid: entry.chatJid,
              pinnedAt: entry.pinnedAt,
              pinCount: entry.pinCount,
              pinnedBySelf: entry.pinnedBySelf,
              message: message,
              attachmentMetadataIds: attachmentIds,
            ),
          );
        }
      }
    }
    final nextMetadataIds = _metadataIdsForState(
      messages: state.items,
      attachmentsByMessageId: state.attachmentMetadataIdsByMessageId,
      pinnedMessages: pinnedItems,
    );
    await _syncFileMetadataSubscriptions(nextMetadataIds);
    if (!_isCurrentPinnedMessagesSource(sourceKey)) return;
    var lastSeenPinnedMessageAt = await _loadLastSeenPinnedMessageAt(sourceKey);
    if (!_isCurrentPinnedMessagesSource(sourceKey)) return;
    final latestPinnedMessageNotice = _latestPinnedMessageNoticeForEntries(
      entries,
    );
    if ((state.pinnedMessagesStatus.showsPanelLoading ||
            state.pinnedMessagesStatus.isHydrating) &&
        latestPinnedMessageNotice != null) {
      lastSeenPinnedMessageAt = await _markPinnedMessageNoticeSeen(
        latest: latestPinnedMessageNotice,
        seenAt: lastSeenPinnedMessageAt,
        sourceKey: sourceKey,
      );
      if (!_isCurrentPinnedMessagesSource(sourceKey)) return;
    }
    final nextState = state.copyWith(
      pinnedMessages: pinnedItems,
      pinnedMessagesStatus: ChatPinnedMessagesStatus.loaded,
      latestPinnedMessageNotice: latestPinnedMessageNotice,
      lastSeenPinnedMessageAt: lastSeenPinnedMessageAt,
      fileMetadataById: _pruneFileMetadataById(
        metadataIds: nextMetadataIds,
        existing: state.fileMetadataById,
      ),
    );
    emit(nextState);
    _requestPresentationHydrationForMessages(
      pinnedItems.map((item) => item.message).whereType<Message>(),
      hydrateEmailContent: true,
      allowOffWindowEmailContentHydration: true,
    );
  }

  void _onFileMetadataBatchUpdated(
    _FileMetadataBatchUpdated event,
    Emitter<ChatState> emit,
  ) {
    _fileMetadataRetryAttempts = _emptyMessageCount;
    final nextMetadataById = _pruneFileMetadataById(
      metadataIds: _trackedFileMetadataIds,
      existing: event.metadataById,
    );
    if (nextMetadataById.length == state.fileMetadataById.length &&
        nextMetadataById.entries.every(
          (entry) => state.fileMetadataById[entry.key] == entry.value,
        )) {
      return;
    }
    emit(state.copyWith(fileMetadataById: nextMetadataById));
  }

  Future<void> _refreshVisibleAttachmentProjection(
    Emitter<ChatState> emit,
  ) async {
    if (state.items.isEmpty) {
      return;
    }
    final attachmentMaps = await _loadAttachmentMaps(state.items);
    if (emit.isDone) {
      return;
    }
    final nextMetadataIds = _metadataIdsForState(
      messages: state.items,
      attachmentsByMessageId: attachmentMaps.attachmentsByMessageId,
      pinnedMessages: state.pinnedMessages,
    );
    await _syncFileMetadataSubscriptions(nextMetadataIds);
    if (emit.isDone) {
      return;
    }
    final metadataIdsToLoad = <String>{
      for (final id in nextMetadataIds)
        if (state.fileMetadataById[id] == null) id,
    };
    final loadedMetadata = metadataIdsToLoad.isEmpty
        ? const <FileMetadataData>[]
        : await _messageService.loadFileMetadataByIds(metadataIdsToLoad);
    if (emit.isDone) {
      return;
    }
    final loadedMetadataById = <String, FileMetadataData>{
      for (final metadata in loadedMetadata) metadata.id: metadata,
    };
    final nextFileMetadataById = _pruneFileMetadataById(
      metadataIds: nextMetadataIds,
      existing: <String, FileMetadataData?>{
        ...state.fileMetadataById,
        ...loadedMetadataById,
      },
    );
    if (_stringListMapEquals(
          state.attachmentMetadataIdsByMessageId,
          attachmentMaps.attachmentsByMessageId,
        ) &&
        mapEquals(
          state.attachmentGroupLeaderByMessageId,
          attachmentMaps.groupLeaderByMessageId,
        ) &&
        mapEquals(state.fileMetadataById, nextFileMetadataById)) {
      return;
    }
    emit(
      _withEmailContentPreparationProjection(
        state.copyWith(
          attachmentMetadataIdsByMessageId:
              attachmentMaps.attachmentsByMessageId,
          attachmentGroupLeaderByMessageId:
              attachmentMaps.groupLeaderByMessageId,
          fileMetadataById: nextFileMetadataById,
        ),
      ),
    );
    _reportVisibleEmailContentMessages(state.items);
  }

  Set<String> _metadataIdsForState({
    required List<Message> messages,
    required Map<String, List<String>> attachmentsByMessageId,
    required List<PinnedMessageItem> pinnedMessages,
  }) {
    final metadataIds = <String>{};
    for (final attachmentIds in attachmentsByMessageId.values) {
      for (final id in attachmentIds) {
        final trimmed = id.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        metadataIds.add(trimmed);
      }
    }
    for (final message in messages) {
      final metadataId = message.fileMetadataID?.trim();
      if (metadataId == null || metadataId.isEmpty) {
        continue;
      }
      metadataIds.add(metadataId);
    }
    for (final item in pinnedMessages) {
      for (final id in item.attachmentMetadataIds) {
        final trimmed = id.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        metadataIds.add(trimmed);
      }
    }
    return metadataIds;
  }

  Map<String, FileMetadataData?> _pruneFileMetadataById({
    required Set<String> metadataIds,
    required Map<String, FileMetadataData?> existing,
  }) {
    if (metadataIds.isEmpty || existing.isEmpty) {
      return const <String, FileMetadataData?>{};
    }
    final nextMetadataById = <String, FileMetadataData?>{};
    for (final id in metadataIds) {
      if (!existing.containsKey(id)) {
        continue;
      }
      nextMetadataById[id] = existing[id];
    }
    return nextMetadataById;
  }

  bool _stringListMapEquals(
    Map<String, List<String>> left,
    Map<String, List<String>> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      final rightValue = right[entry.key];
      if (rightValue == null || !listEquals(entry.value, rightValue)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _syncFileMetadataSubscriptions(Set<String> metadataIds) async {
    if (isClosed) return;
    final normalizedIds = <String>{
      for (final id in metadataIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
    final sameIds =
        normalizedIds.length == _trackedFileMetadataIds.length &&
        normalizedIds.containsAll(_trackedFileMetadataIds);
    if (sameIds && _fileMetadataSubscription != null) return;
    if (!sameIds) {
      _fileMetadataRetryAttempts = _emptyMessageCount;
    }
    _trackedFileMetadataIds = normalizedIds;
    final previous = _fileMetadataSubscription;
    _fileMetadataSubscription = null;
    if (previous != null) {
      _fileMetadataSubscriptionCancelling = true;
      try {
        await _detachAndCancelSubscription(previous);
      } finally {
        _fileMetadataSubscriptionCancelling = false;
      }
    }
    if (isClosed) return;
    if (normalizedIds.isEmpty) return;
    _fileMetadataSubscription = _messageService
        .fileMetadataByIdsStream(normalizedIds)
        .listen(
          (metadataById) =>
              add(_FileMetadataBatchUpdated(metadataById: metadataById)),
          onError: (Object error, StackTrace stackTrace) {
            _fileMetadataSubscription = null;
            _retryFileMetadataSubscription();
          },
          onDone: () {
            _fileMetadataSubscription = null;
            _retryFileMetadataSubscription();
          },
        );
  }

  void _retryFileMetadataSubscription() {
    if (isClosed ||
        _fileMetadataSubscriptionCancelling ||
        _trackedFileMetadataIds.isEmpty) {
      return;
    }
    if (_fileMetadataRetryAttempts >= 3) {
      return;
    }
    _fileMetadataRetryAttempts += 1;
    unawaited(_syncFileMetadataSubscriptions(_trackedFileMetadataIds));
  }

  Future<void> _onChatPinnedMessagesOpened(
    ChatPinnedMessagesOpened event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null) {
      return;
    }
    switch (state.pinnedMessagesStatus) {
      case ChatPinnedMessagesStatus.idle:
        emit(
          state.copyWith(
            pinnedMessagesStatus: ChatPinnedMessagesStatus.loading,
          ),
        );
        await _refreshPinnedMessagesFromDatabase(chat);
      case ChatPinnedMessagesStatus.loaded:
        await _hydratePinnedMessagesIfNeeded(chat, emit);
      case ChatPinnedMessagesStatus.loading:
      case ChatPinnedMessagesStatus.hydrating:
        await _markLatestPinnedMessageNoticeSeen(emit);
        return;
      case ChatPinnedMessagesStatus.failure:
        return;
    }
    await _markLatestPinnedMessageNoticeSeen(emit);
  }

  Future<void> _onChatPinnedMessagesRetryRequested(
    ChatPinnedMessagesRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null || !state.pinnedMessagesStatus.canRetry) {
      return;
    }
    emit(
      state.copyWith(pinnedMessagesStatus: ChatPinnedMessagesStatus.loading),
    );
    await _refreshPinnedMessagesFromDatabase(chat);
  }

  Future<void> _onChatPinnedMessageNoticeHidden(
    ChatPinnedMessageNoticeHidden event,
    Emitter<ChatState> emit,
  ) async {
    final latest = state.latestPinnedMessageNotice;
    final seenAt = state.lastSeenPinnedMessageAt;
    if (latest == null ||
        (seenAt != null && !latest.pinnedAt.isAfter(seenAt))) {
      return;
    }
    final sourceKey = _pinnedMessagesSourceKey;
    final markedAt = await _markPinnedMessageNoticeSeen(
      latest: latest,
      seenAt: seenAt,
      sourceKey: sourceKey,
    );
    if (sourceKey != _pinnedMessagesSourceKey) {
      return;
    }
    emit(state.copyWith(lastSeenPinnedMessageAt: markedAt));
  }

  Future<void> _markLatestPinnedMessageNoticeSeen(
    Emitter<ChatState> emit,
  ) async {
    final latest = state.latestPinnedMessageNotice;
    if (latest == null) {
      return;
    }
    final sourceKey = _pinnedMessagesSourceKey;
    final markedAt = await _markPinnedMessageNoticeSeen(
      latest: latest,
      seenAt: state.lastSeenPinnedMessageAt,
      sourceKey: sourceKey,
    );
    if (sourceKey != _pinnedMessagesSourceKey) {
      return;
    }
    emit(state.copyWith(lastSeenPinnedMessageAt: markedAt));
  }

  Future<DateTime?> _markPinnedMessageNoticeSeen({
    required ChatPinnedMessageNotice latest,
    required DateTime? seenAt,
    required String? sourceKey,
  }) async {
    if (seenAt != null && !latest.pinnedAt.isAfter(seenAt)) {
      return seenAt;
    }
    _lastSeenPinnedMessageSourceKey = sourceKey;
    _lastSeenPinnedMessageAt = latest.pinnedAt;
    try {
      await _messageService.saveLastSeenPinnedMessageAt(
        chatJid: latest.chatJid,
        seenAt: latest.pinnedAt,
      );
    } on XmppException catch (error, stackTrace) {
      _log.safeFine(
        'Failed to save latest seen pinned message timestamp.',
        error,
        stackTrace,
      );
    }
    return latest.pinnedAt;
  }

  Future<void> _hydratePinnedMessagesIfNeeded(
    Chat chat,
    Emitter<ChatState> emit,
  ) async {
    final sourceKey = _pinnedMessagesSourceKey;
    final missing = _missingPinnedMessageIds(state.pinnedMessages);
    if (missing.isEmpty) {
      return;
    }
    emit(
      state.copyWith(pinnedMessagesStatus: ChatPinnedMessagesStatus.hydrating),
    );
    if (chat.defaultTransport.isEmail) {
      await _pruneResolvedPinnedMessages(missing);
      await _refreshPinnedMessagesFromDatabase(chat);
    } else {
      await _hydratePinnedMessagesFromMam(chat, missing);
    }
    if (!_isCurrentPinnedMessagesSource(sourceKey)) {
      return;
    }
    emit(state.copyWith(pinnedMessagesStatus: ChatPinnedMessagesStatus.loaded));
  }

  Future<DateTime?> _loadLastSeenPinnedMessageAt(String? sourceKey) async {
    if (sourceKey == null) {
      return null;
    }
    if (_lastSeenPinnedMessageSourceKey == sourceKey) {
      return _lastSeenPinnedMessageAt;
    }
    try {
      final seenAt = await _messageService.loadLastSeenPinnedMessageAt(
        sourceKey,
      );
      _lastSeenPinnedMessageSourceKey = sourceKey;
      _lastSeenPinnedMessageAt = seenAt;
      return seenAt;
    } on XmppException catch (error, stackTrace) {
      _log.safeFine(
        'Failed to load latest seen pinned message timestamp.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  void _clearLastSeenPinnedMessageCache() {
    _lastSeenPinnedMessageSourceKey = null;
    _lastSeenPinnedMessageAt = null;
  }

  ChatPinnedMessageNotice? _latestPinnedMessageNoticeForEntries(
    List<PinnedMessageAggregate> entries,
  ) {
    final currentNotices = _pinnedMessageNoticesForEntries(entries);
    if (currentNotices.isEmpty) {
      return null;
    }
    return _latestPinnedMessageNotice(currentNotices);
  }

  Set<ChatPinnedMessageNotice> _pinnedMessageNoticesForEntries(
    List<PinnedMessageAggregate> entries,
  ) {
    if (entries.isEmpty) {
      return const <ChatPinnedMessageNotice>{};
    }
    final notices = <ChatPinnedMessageNotice>{};
    for (final entry in entries) {
      if (entry.pinnedBySelf) {
        continue;
      }
      final messageId = entry.messageReferenceId.trim();
      final chatJid = entry.chatJid.trim();
      if (messageId.isEmpty || chatJid.isEmpty) {
        continue;
      }
      notices.add(
        ChatPinnedMessageNotice(
          messageStanzaId: messageId,
          chatJid: chatJid,
          pinnedAt: entry.pinnedAt,
        ),
      );
    }
    return Set<ChatPinnedMessageNotice>.unmodifiable(notices);
  }

  ChatPinnedMessageNotice _latestPinnedMessageNotice(
    Set<ChatPinnedMessageNotice> notices,
  ) {
    ChatPinnedMessageNotice? latest;
    for (final notice in notices) {
      final current = latest;
      if (current == null) {
        latest = notice;
        continue;
      }
      if (notice.isAfter(current)) {
        latest = notice;
      }
    }
    return latest!;
  }

  Future<void> _onChatPinnedMessageSelected(
    ChatPinnedMessageSelected event,
    Emitter<ChatState> emit,
  ) async {
    final messageId = event.messageStanzaId.trim();
    if (messageId.isEmpty) {
      return;
    }
    final chat = state.chat;
    if (chat == null) {
      return;
    }
    final currentMessage = _messageForId(state.items, messageId);
    if (currentMessage != null) {
      _pendingScrollTargetMessageId = null;
      _emitScrollTargetRequest(emit, currentMessage.stanzaID);
      return;
    }
    if (!_forceAllWithContactViewFilter &&
        state.viewFilter == MessageTimelineFilter.directOnly) {
      await _applyViewFilter(
        MessageTimelineFilter.allWithContact,
        emit: emit,
        persist: false,
        chatJid: chat.jid,
      );
    }
    final target = await _ensurePinnedMessageAvailableLocally(
      chat: chat,
      messageId: messageId,
    );
    if (target == null || target.timestamp == null) {
      _pendingScrollTargetMessageId = null;
      return;
    }
    _pendingScrollTargetMessageId = target.stanzaID;
    await _subscribeThroughMessage(chat: chat, target: target);
    if (_containsMessageId(state.items, target.stanzaID)) {
      _pendingScrollTargetMessageId = null;
      _emitScrollTargetRequest(emit, target.stanzaID);
    }
  }

  Future<void> _onChatImportantMessageSelected(
    ChatImportantMessageSelected event,
    Emitter<ChatState> emit,
  ) async {
    final messageId = event.messageReferenceId.trim();
    if (messageId.isEmpty) {
      return;
    }
    final chat = state.chat;
    if (chat == null) {
      return;
    }
    final currentMessage = _messageForId(state.items, messageId);
    if (currentMessage != null) {
      _pendingScrollTargetMessageId = null;
      _emitScrollTargetRequest(emit, currentMessage.stanzaID);
      return;
    }
    if (!_forceAllWithContactViewFilter &&
        state.viewFilter == MessageTimelineFilter.directOnly) {
      await _applyViewFilter(
        MessageTimelineFilter.allWithContact,
        emit: emit,
        persist: false,
        chatJid: chat.jid,
      );
    }
    final target = await _ensureImportantMessageAvailableLocally(
      chat: chat,
      messageId: messageId,
    );
    if (target == null || target.timestamp == null) {
      _pendingScrollTargetMessageId = null;
      return;
    }
    _pendingScrollTargetMessageId = target.stanzaID;
    await _subscribeThroughMessage(chat: chat, target: target);
    if (_containsMessageId(state.items, target.stanzaID)) {
      _pendingScrollTargetMessageId = null;
      _emitScrollTargetRequest(emit, target.stanzaID);
    }
  }

  Set<String> _missingPinnedMessageIds(List<PinnedMessageItem> items) {
    final missing = <String>{};
    for (final item in items) {
      if (item.message != null) {
        continue;
      }
      final stanzaId = item.messageStanzaId.trim();
      if (stanzaId.isEmpty) {
        continue;
      }
      missing.add(stanzaId);
    }
    return missing;
  }

  bool _isPinnedMessageInChat({
    required Chat chat,
    required String messageReferenceId,
  }) {
    final sourceKey = _resolvePinnedMessagesChatJid(chat);
    if (sourceKey == null) {
      return false;
    }
    final messageId = messageReferenceId.trim();
    if (messageId.isEmpty) {
      return false;
    }
    for (final item in state.pinnedMessages) {
      if (item.messageStanzaId.trim() != messageId) {
        continue;
      }
      if (sameNormalizedAddressValue(item.chatJid, sourceKey)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _hydratePinnedMessagesFromMam(
    Chat chat,
    Set<String> missingStanzaIds,
  ) async {
    if (!_xmppAllowedForChat(chat)) {
      return;
    }
    if (state.items.isEmpty) {
      await _hydrateLatestFromMam(chat);
      missingStanzaIds = await _pruneResolvedPinnedMessages(missingStanzaIds);
      await _refreshPinnedMessagesFromDatabase(chat);
    }
    for (
      var attempt = 0;
      attempt < _pinnedMessagesFetchPageLimit && missingStanzaIds.isNotEmpty;
      attempt += 1
    ) {
      final previousCount = await _archivedMessageCount(chat);
      await _loadEarlierFromMam();
      missingStanzaIds = await _pruneResolvedPinnedMessages(missingStanzaIds);
      await _refreshPinnedMessagesFromDatabase(chat);
      final nextCount = await _archivedMessageCount(chat);
      if (nextCount <= previousCount) {
        break;
      }
    }
  }

  Future<Set<String>> _pruneResolvedPinnedMessages(
    Set<String> missingStanzaIds,
  ) async {
    if (missingStanzaIds.isEmpty) {
      return missingStanzaIds;
    }
    final resolvedMessages = await _messageService.loadMessagesByReferenceIds(
      missingStanzaIds,
      chatJid: state.chat?.jid,
    );
    if (resolvedMessages.isEmpty) {
      return missingStanzaIds;
    }
    final resolvedIds = <String>{};
    for (final message in resolvedMessages) {
      resolvedIds.addAll(message.referenceIds);
    }
    missingStanzaIds.removeAll(resolvedIds);
    return missingStanzaIds;
  }

  Future<void> _refreshPinnedMessagesFromDatabase(Chat chat) async {
    final sourceKey = _resolvePinnedMessagesChatJid(chat);
    _pinnedMessagesSourceKey ??= sourceKey;
    if (!_isCurrentPinnedMessagesSource(sourceKey)) {
      return;
    }
    if (sourceKey == null) {
      add(
        const _PinnedMessagesUpdated(
          sourceKey: null,
          items: <PinnedMessageAggregate>[],
        ),
      );
      return;
    }
    try {
      final entries = await _messageService.loadPinnedMessages(sourceKey);
      add(_PinnedMessagesUpdated(sourceKey: sourceKey, items: entries));
    } on XmppException catch (error, stackTrace) {
      _log.safeFine('Failed to load pinned messages.', error, stackTrace);
      add(_PinnedMessagesLoadFailed(sourceKey));
    }
  }

  Future<void> _onChatInviteRequested(
    ChatInviteRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    if (chat.type != ChatType.groupChat) {
      return;
    }
    final roomState = event.roomState;
    if (roomState == null) {
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatMembersLoading,
            variant: ChatToastVariant.warning,
          ),
          toastId: state.toastId + 1,
        ),
      );
      return;
    }
    final canInvite =
        roomState.myAffiliation.isOwner ||
        roomState.myAffiliation.isAdmin ||
        roomState.myRole.isModerator;
    if (!canInvite) {
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatInvitePermissionDenied,
            variant: ChatToastVariant.warning,
          ),
          toastId: state.toastId + 1,
        ),
      );
      return;
    }
    final myDomain = _chatsService.myJid;
    if (myDomain == null) return;
    String? inviteeDomain;
    String? inviteeBare;
    try {
      final jid = mox.JID.fromString(event.jid);
      inviteeDomain = jid.domain;
      inviteeBare = jid.toBare().toString();
    } catch (_) {
      inviteeDomain = null;
    }
    if (inviteeDomain == null ||
        inviteeDomain != mox.JID.fromString(myDomain).domain) {
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatInviteDomainRestricted,
            variant: ChatToastVariant.warning,
          ),
          toastId: state.toastId + 1,
        ),
      );
      return;
    }
    final inviteeBareLower = inviteeBare?.toLowerCase();
    if (inviteeBareLower != null) {
      final alreadyMember = roomState.occupants.values.any(
        (occupant) =>
            occupant.realJid != null &&
            mox.JID
                    .fromString(occupant.realJid!)
                    .toBare()
                    .toString()
                    .toLowerCase() ==
                inviteeBareLower,
      );
      if (alreadyMember) {
        emit(
          state.copyWith(
            toast: const ChatToast(
              message: ChatMessageKey.chatInviteAlreadyMember,
            ),
            toastId: state.toastId + 1,
          ),
        );
        return;
      }
    }
    try {
      await _mucService.inviteUserToRoom(
        roomJid: chat.jid,
        inviteeJid: inviteeBare ?? event.jid,
        reason: event.reason,
      );
      emit(
        state.copyWith(
          toast: const ChatToast(message: ChatMessageKey.chatInviteSent),
          toastId: state.toastId + 1,
        ),
      );
    } catch (error, stackTrace) {
      _log.fine('Failed to send room invite', error, stackTrace);
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatInviteSendFailed,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
    }
  }

  Future<void> _onInviteRevocationRequested(
    ChatInviteRevocationRequested event,
    Emitter<ChatState> emit,
  ) async {
    final data = event.message.pseudoMessageData ?? const {};
    final roomJid = data['roomJid'] as String?;
    final invitee = data['invitee'] as String? ?? event.inviteeJidFallback;
    final token = data['token'] as String?;
    if (roomJid == null || invitee == null || token == null) {
      return;
    }
    try {
      await _mucService.revokeInvite(
        roomJid: roomJid,
        inviteeJid: invitee,
        token: token,
      );
      emit(
        state.copyWith(
          toast: const ChatToast(message: ChatMessageKey.chatInviteRevoked),
          toastId: state.toastId + 1,
        ),
      );
    } catch (error, stackTrace) {
      _log.warning('Failed to revoke invite $token', error, stackTrace);
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatInviteRevokeFailed,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
    }
  }

  Future<void> _onInviteJoinRequested(
    ChatInviteJoinRequested event,
    Emitter<ChatState> emit,
  ) async {
    final data = event.message.pseudoMessageData ?? const {};
    final roomJid = data['roomJid'] as String?;
    final roomName = data['roomName'] as String?;
    final invitee = data['invitee'] as String?;
    final inviter = data['inviter'] as String?;
    final token = data['token'] as String?;
    final password = data['password'] as String?;
    if (roomJid == null) return;
    if (invitee != null &&
        _chatsService.myJid != null &&
        !sameBareAddress(invitee, _chatsService.myJid)) {
      return;
    }
    try {
      await _mucService.acceptRoomInvite(
        roomJid: roomJid,
        roomName: roomName,
        inviteToken: token,
        inviterJid: inviter,
        inviteeJid: invitee,
        password: password,
      );
      emit(
        state.copyWith(
          toast: const ChatToast(message: ChatMessageKey.chatInviteJoinSuccess),
          toastId: state.toastId + 1,
        ),
      );
    } catch (error, stackTrace) {
      _log.warning('Failed to join invited room', error, stackTrace);
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatInviteJoinFailed,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
    }
  }

  Future<void> _onLeaveRoomRequested(
    ChatLeaveRoomRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    final completer = event.completer;
    if (chatJid.isEmpty || event.chatType != ChatType.groupChat) {
      if (completer != null && !completer.isCompleted) {
        completer.completeError(XmppMessageException());
      }
      return;
    }
    try {
      await _mucService.leaveRoom(chatJid);
      emit(
        state.copyWith(
          roomState: _mucService.roomStateFor(chatJid) ?? state.roomState,
          roomMemberSections: const [],
        ),
      );
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to leave room $chatJid', error, stackTrace);
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatLeaveRoomFailed,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
      if (completer != null && !completer.isCompleted) {
        completer.completeError(XmppMessageException());
      }
    }
  }

  Future<void> _onDestroyRoomRequested(
    ChatDestroyRoomRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    final completer = event.completer;
    if (chatJid.isEmpty || event.chatType != ChatType.groupChat) {
      if (completer != null && !completer.isCompleted) {
        completer.completeError(XmppMessageException());
      }
      return;
    }
    try {
      await _mucService.destroyRoom(roomJid: chatJid);
      emit(
        state.copyWith(
          roomState: _mucService.roomStateFor(chatJid) ?? state.roomState,
          roomMemberSections: const [],
        ),
      );
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to destroy room $chatJid', error, stackTrace);
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatDestroyRoomFailed,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
      if (completer != null && !completer.isCompleted) {
        completer.completeError(XmppMessageException());
      }
    }
  }

  Future<void> _onNicknameChangeRequested(
    ChatNicknameChangeRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty || event.chatType != ChatType.groupChat) return;
    final trimmed = event.nickname.trim();
    if (trimmed.isEmpty) return;
    try {
      await _mucService.changeNickname(roomJid: chatJid, nickname: trimmed);
      emit(
        state.copyWith(
          chat: state.chat?.copyWith(myNickname: trimmed),
          roomState: _mucService.roomStateFor(chatJid) ?? state.roomState,
          toast: const ChatToast(message: ChatMessageKey.chatNicknameUpdated),
          toastId: state.toastId + 1,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.safeWarning(
        'Failed to change nickname for $chatJid',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatNicknameUpdateFailed,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
    }
  }

  Future<void> _onRoomAvatarChangeRequested(
    ChatRoomAvatarChangeRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    if (chat.type != ChatType.groupChat) return;
    final roomState = event.roomState;
    final canEdit = roomState.canEditAvatar;
    if (!canEdit) {
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatRoomAvatarPermissionDenied,
            variant: ChatToastVariant.warning,
          ),
          toastId: state.toastId + 1,
        ),
      );
      return;
    }
    if (event.avatar.bytes.isEmpty) return;
    if (state.roomAvatarUpdateStatus.isLoading) return;
    emit(state.copyWith(roomAvatarUpdateStatus: RequestStatus.loading));
    try {
      final updated = await _mucService.updateRoomAvatar(
        roomJid: chat.jid,
        avatar: event.avatar,
      );
      if (!updated) {
        emit(
          state.copyWith(
            roomAvatarUpdateStatus: RequestStatus.none,
            toast: const ChatToast(
              message: ChatMessageKey.chatRoomAvatarUpdateFailed,
              variant: ChatToastVariant.destructive,
            ),
            toastId: state.toastId + 1,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          roomAvatarUpdateStatus: RequestStatus.none,
          toast: const ChatToast(message: ChatMessageKey.chatRoomAvatarUpdated),
          toastId: state.toastId + 1,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.safeWarning(_roomAvatarUpdateFailedLogMessage, error, stackTrace);
      emit(
        state.copyWith(
          roomAvatarUpdateStatus: RequestStatus.none,
          toast: const ChatToast(
            message: ChatMessageKey.chatRoomAvatarUpdateFailed,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
    }
  }

  Future<void> _onContactRenameRequested(
    ChatContactRenameRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    if (chat.type != ChatType.chat) return;
    final trimmed = event.displayName.trim();
    final alias = trimmed.isEmpty ? null : trimmed;
    try {
      await _chatsService.renameChatContact(
        jid: chat.jid,
        displayName: trimmed,
      );
      emit(
        state.copyWith(
          chat: chat.copyWith(contactDisplayName: alias),
          toast: ChatToast(messageText: event.successMessage),
          toastId: state.toastId + 1,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.safeWarning(_contactRenameFailedLogMessage, error, stackTrace);
      emit(
        state.copyWith(
          toast: ChatToast(
            messageText: event.failureMessage,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
    }
  }

  Future<void> _onChatModerationActionRequested(
    ChatModerationActionRequested event,
    Emitter<ChatState> emit,
  ) async {
    final completer = event.completer;
    final chat = event.chat;
    if (chat.type != ChatType.groupChat || event.roomState == null) {
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      return;
    }
    final occupant = event.roomState!.occupants[event.occupantId];
    if (occupant == null) {
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      return;
    }
    try {
      switch (event.action) {
        case MucModerationAction.kick:
          await _mucService.kickOccupant(
            roomJid: chat.jid,
            nick: occupant.nick,
            reason: event.reason,
          );
          break;
        case MucModerationAction.ban:
          final realJid = occupant.realJid;
          if (realJid == null || realJid.isEmpty) {
            throw XmppMessageException();
          }
          await _mucService.banOccupant(
            roomJid: chat.jid,
            jid: realJid,
            reason: event.reason,
          );
          break;
        case MucModerationAction.member:
        case MucModerationAction.admin:
        case MucModerationAction.owner:
          final realJid = occupant.realJid;
          if (realJid == null || realJid.isEmpty) {
            throw XmppMessageException();
          }
          final nextAffiliation = switch (event.action) {
            MucModerationAction.owner => OccupantAffiliation.owner,
            MucModerationAction.admin => OccupantAffiliation.admin,
            MucModerationAction.member => OccupantAffiliation.member,
            _ => OccupantAffiliation.none,
          };
          await _mucService.changeAffiliation(
            roomJid: chat.jid,
            jid: realJid,
            affiliation: nextAffiliation,
          );
          break;
        case MucModerationAction.moderator:
        case MucModerationAction.participant:
          final nextRole = event.action == MucModerationAction.moderator
              ? OccupantRole.moderator
              : OccupantRole.participant;
          await _mucService.changeRole(
            roomJid: chat.jid,
            nick: occupant.nick,
            role: nextRole,
          );
          break;
      }
      emit(
        state.copyWith(
          toast: ChatToast(
            message: ChatMessageKey.chatModerationRequested,
            messageActionLabel: event.actionLabel,
            messageTargetLabel: occupant.nick,
          ),
          toastId: state.toastId + 1,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Moderation action ${event.action.name} failed for ${occupant.nick}',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: ChatMessageKey.chatModerationFailed,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
    } finally {
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  void _onEmailSyncStateChanged(
    _EmailSyncStateChanged event,
    Emitter<ChatState> emit,
  ) {
    _applyEmailSyncState(event.state, emit);
  }

  void _applyEmailSyncState(EmailSyncState nextState, Emitter<ChatState> emit) {
    if (!_isEmailChat && !state.usesSavedEmailTransportOverride) {
      if (state.emailSyncState != nextState) {
        emit(state.copyWith(emailSyncState: nextState));
      }
      return;
    }
    var composerError = state.composerError;
    if (!nextState.requiresAttention) {
      if (composerError != null && composerError == _emailSyncComposerMessage) {
        composerError = null;
      }
      _emailSyncComposerMessage = null;
    } else {
      const message = ChatMessageKey.messageErrorServiceUnavailable;
      _emailSyncComposerMessage = message;
      composerError = message;
    }
    emit(
      state.copyWith(emailSyncState: nextState, composerError: composerError),
    );
  }

  Future<void> _onXmppConnectionStateChanged(
    _XmppConnectionStateChanged event,
    Emitter<ChatState> emit,
  ) async {
    if (_isClosing || isClosed) {
      return;
    }
    final stateChanged = state.xmppConnectionState != event.state;
    final nextXmppPaginationState = _xmppPaginationStateFor(
      state.chat,
      connectionState: event.state,
      previous: state.xmppHistoryPaginationState,
      reset:
          state.xmppConnectionState != ConnectionState.connected &&
          event.state == ConnectionState.connected,
    );
    if (stateChanged ||
        state.xmppHistoryPaginationState != nextXmppPaginationState) {
      emit(
        state.copyWith(
          xmppConnectionState: event.state,
          xmppHistoryPaginationState: nextXmppPaginationState,
        ),
      );
    }
    if (_isClosing || isClosed) {
      return;
    }
    final chat = state.chat;
    if (!_chatStarted ||
        event.state != ConnectionState.connected ||
        chat == null) {
      return;
    }
    if (chat.type == ChatType.groupChat) {
      await _ensureMucMembership(chat);
      if (_isClosing || isClosed) {
        return;
      }
    }
    if (_canPageXmppHistory(chat)) {
      await _catchUpFromMam();
      if (_isClosing || isClosed) {
        return;
      }
      await _verifyStaleUnackedMessagesFromMam(chat);
      if (_isClosing || isClosed) {
        return;
      }
    }
    await _syncPinnedMessagesForChat(chat);
  }

  void _onHttpUploadSupportUpdated(
    _HttpUploadSupportUpdated event,
    Emitter<ChatState> emit,
  ) {
    if (state.supportsHttpFileUpload == event.supported) return;
    emit(state.copyWith(supportsHttpFileUpload: event.supported));
  }

  Future<void> _onChatSettingsUpdated(
    ChatSettingsUpdated event,
    Emitter<ChatState> emit,
  ) async {
    _settingsSnapshot = event.settings;
    _queueAutoDownloadAttachments(
      messages: state.items,
      attachmentsByMessageId: state.attachmentMetadataIdsByMessageId,
    );
  }

  void _onChatSavedTransportOverrideUpdated(
    _ChatSavedTransportOverrideUpdated event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(savedTransportOverride: event.transport));
  }

  Future<void> _onChatMessageFocused(
    ChatMessageFocused event,
    Emitter<ChatState> emit,
  ) async {
    final messageId = event.messageID;
    if (messageId == null) {
      emit(state.copyWith(focused: null));
      return;
    }
    var target = state.items.where((e) => e.stanzaID == messageId).firstOrNull;
    if (target == null) {
      final fetched = await _messageService.loadMessageByStanzaId(messageId);
      if (fetched != null) {
        final updatedItems = _messagesNewestFirst([
          ...state.items.where((msg) => msg.stanzaID != fetched.stanzaID),
          fetched,
        ]);
        emit(state.copyWith(items: updatedItems, focused: fetched));
        _reportVisibleEmailContentMessages([fetched]);
        _requestEmailOriginalContent(fetched);
        _maybeRequestEmailQuotedText(fetched);
        return;
      }
    }
    emit(state.copyWith(focused: target));
    if (target != null) {
      _reportVisibleEmailContentMessages([target]);
    }
    _requestEmailOriginalContent(target);
    _maybeRequestEmailQuotedText(target);
  }

  Future<void> _onChatEmailHeadersRequested(
    ChatEmailHeadersRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    final deltaMessageId = message.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return;
    }
    if (state.emailRawHeadersByDeltaId.containsKey(deltaMessageId)) {
      return;
    }
    if (state.emailRawHeadersLoading.contains(deltaMessageId)) {
      return;
    }
    final loading = Set<int>.from(state.emailRawHeadersLoading)
      ..add(deltaMessageId);
    final unavailable = Set<int>.from(state.emailRawHeadersUnavailable)
      ..remove(deltaMessageId);
    emit(
      state.copyWith(
        emailRawHeadersLoading: loading,
        emailRawHeadersUnavailable: unavailable,
      ),
    );
    final emailService = _emailService;
    if (emailService == null) {
      final updatedLoading = Set<int>.from(state.emailRawHeadersLoading)
        ..remove(deltaMessageId);
      final unavailable = Set<int>.from(state.emailRawHeadersUnavailable)
        ..add(deltaMessageId);
      emit(
        state.copyWith(
          emailRawHeadersLoading: updatedLoading,
          emailRawHeadersUnavailable: unavailable,
        ),
      );
      return;
    }
    String? headers;
    try {
      headers = await emailService.getMessageRawHeadersForMessage(message);
    } catch (_) {
      headers = null;
    }
    final updatedLoading = Set<int>.from(state.emailRawHeadersLoading)
      ..remove(deltaMessageId);
    if (headers == null || headers.trim().isEmpty) {
      final unavailable = Set<int>.from(state.emailRawHeadersUnavailable)
        ..add(deltaMessageId);
      emit(
        state.copyWith(
          emailRawHeadersLoading: updatedLoading,
          emailRawHeadersUnavailable: unavailable,
        ),
      );
      return;
    }
    final updatedHeaders = Map<int, String>.from(state.emailRawHeadersByDeltaId)
      ..[deltaMessageId] = headers;
    emit(
      state.copyWith(
        emailRawHeadersLoading: updatedLoading,
        emailRawHeadersByDeltaId: updatedHeaders,
      ),
    );
  }

  void _onChatEmailOriginalContentRequested(
    _ChatEmailOriginalContentRequested event,
    Emitter<ChatState> _,
  ) {
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    final requestedDeltaIds = <int>{};
    for (final message in event.messages) {
      final deltaMessageId = message.deltaMsgId;
      if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
        continue;
      }
      if (!_isEmailDeltaMessageRelevant(
        deltaMessageId,
        offWindowMessage: event.allowOffWindow ? message : null,
      )) {
        continue;
      }
      if (state.emailFullHtmlByDeltaId.containsKey(deltaMessageId) ||
          state.emailFullHtmlLoading.contains(deltaMessageId) ||
          state.emailFullHtmlUnavailable.contains(deltaMessageId) ||
          !requestedDeltaIds.add(deltaMessageId)) {
        continue;
      }
      unawaited(emailService.requestEmailOriginalContentPreparation(message));
    }
  }

  Future<void> _onChatEmailQuotedTextRequested(
    ChatEmailQuotedTextRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _hydrateEmailQuotedTextBatch(
      [event.message],
      allowOffWindow: event.allowOffWindow,
      emit: emit,
    );
  }

  Future<void> _onChatEmailQuotedTextBatchRequested(
    _ChatEmailQuotedTextBatchRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _hydrateEmailQuotedTextBatch(
      event.messages,
      allowOffWindow: event.allowOffWindow,
      emit: emit,
    );
  }

  Future<void> _hydrateEmailQuotedTextBatch(
    Iterable<Message> messages, {
    required bool allowOffWindow,
    required Emitter<ChatState> emit,
  }) async {
    final emailService = _emailService;
    final entries =
        <({Message message, int deltaMessageId, Stopwatch stopwatch})>[];
    final entryDeltaIds = <int>{};
    for (final message in messages) {
      final stopwatch = Stopwatch()..start();
      final deltaMessageId = message.deltaMsgId;
      if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
        _traceEmailQuotedTextEnd(
          deltaMessageId: deltaMessageId,
          result: 'invalidDeltaMessageId',
          allowOffWindow: allowOffWindow,
          stopwatch: stopwatch,
        );
        continue;
      }
      if (!_isEmailDeltaMessageRelevant(
        deltaMessageId,
        offWindowMessage: allowOffWindow ? message : null,
      )) {
        _traceEmailQuotedTextEnd(
          deltaMessageId: deltaMessageId,
          result: 'notRelevant',
          allowOffWindow: allowOffWindow,
          stopwatch: stopwatch,
        );
        continue;
      }
      if (state.emailQuotedTextByDeltaId.containsKey(deltaMessageId)) {
        _traceEmailQuotedTextEnd(
          deltaMessageId: deltaMessageId,
          result: 'cached',
          allowOffWindow: allowOffWindow,
          stopwatch: stopwatch,
        );
        continue;
      }
      if (state.emailQuotedTextLoading.contains(deltaMessageId) ||
          !entryDeltaIds.add(deltaMessageId)) {
        _traceEmailQuotedTextEnd(
          deltaMessageId: deltaMessageId,
          result: 'alreadyLoading',
          allowOffWindow: allowOffWindow,
          stopwatch: stopwatch,
        );
        continue;
      }
      entries.add((
        message: message,
        deltaMessageId: deltaMessageId,
        stopwatch: stopwatch,
      ));
    }
    if (entries.isEmpty) {
      return;
    }
    final loading = Set<int>.from(state.emailQuotedTextLoading);
    final unavailable = Set<int>.from(state.emailQuotedTextUnavailable);
    for (final entry in entries) {
      loading.add(entry.deltaMessageId);
      unavailable.remove(entry.deltaMessageId);
    }
    emit(
      state.copyWith(
        emailQuotedTextLoading: loading,
        emailQuotedTextUnavailable: unavailable,
      ),
    );
    final acceptedDeltaIds = {
      for (final entry in entries) entry.deltaMessageId,
    };
    final pendingCleanupDeltaIds = Set<int>.from(acceptedDeltaIds);
    try {
      var nextEntryIndex = 0;
      var nextToken = 0;
      final active =
          <
            int,
            Future<({int token, _EmailQuotedTextHydrationResult result})>
          >{};

      void startNextEntry() {
        final entry = entries[nextEntryIndex];
        final token = nextToken;
        nextEntryIndex += 1;
        nextToken += 1;
        active[token] = _loadEmailQuotedText(
          message: entry.message,
          deltaMessageId: entry.deltaMessageId,
          stopwatch: entry.stopwatch,
          allowOffWindow: allowOffWindow,
          emailService: emailService,
        ).then((result) => (token: token, result: result));
      }

      void fillActiveQueue() {
        while (nextEntryIndex < entries.length &&
            active.length < _emailHydrationResultChunkSize) {
          startNextEntry();
        }
      }

      fillActiveQueue();
      while (active.isNotEmpty) {
        final completed = await Future.any(active.values);
        active.remove(completed.token);
        final result = completed.result;
        _emitEmailQuotedTextHydrationResults([result], emit);
        _traceEmailQuotedTextEnd(
          deltaMessageId: result.deltaMessageId,
          result: result.result,
          allowOffWindow: allowOffWindow,
          stopwatch: result.stopwatch,
        );
        pendingCleanupDeltaIds.remove(result.deltaMessageId);
        fillActiveQueue();
      }
    } finally {
      _queuedEmailQuotedTextDeltaIds.removeAll(acceptedDeltaIds);
      if (!emit.isDone && pendingCleanupDeltaIds.isNotEmpty) {
        final updatedLoading = Set<int>.from(state.emailQuotedTextLoading)
          ..removeAll(pendingCleanupDeltaIds);
        if (updatedLoading.length != state.emailQuotedTextLoading.length) {
          emit(state.copyWith(emailQuotedTextLoading: updatedLoading));
        }
      }
    }
  }

  void _emitEmailQuotedTextHydrationResults(
    List<_EmailQuotedTextHydrationResult> results,
    Emitter<ChatState> emit,
  ) {
    if (emit.isDone) {
      return;
    }
    final updatedLoading = Set<int>.from(state.emailQuotedTextLoading);
    final updatedUnavailable = Set<int>.from(state.emailQuotedTextUnavailable);
    final updatedQuotedText = Map<int, String>.from(
      state.emailQuotedTextByDeltaId,
    );
    for (final result in results) {
      updatedLoading.remove(result.deltaMessageId);
      final quotedText = result.quotedText;
      if (quotedText != null) {
        updatedQuotedText[result.deltaMessageId] = quotedText;
        updatedUnavailable.remove(result.deltaMessageId);
      } else if (result.unavailable) {
        updatedUnavailable.add(result.deltaMessageId);
      }
    }
    emit(
      state.copyWith(
        emailQuotedTextLoading: updatedLoading,
        emailQuotedTextUnavailable: updatedUnavailable,
        emailQuotedTextByDeltaId: updatedQuotedText,
      ),
    );
  }

  Future<_EmailQuotedTextHydrationResult> _loadEmailQuotedText({
    required Message message,
    required int deltaMessageId,
    required Stopwatch stopwatch,
    required bool allowOffWindow,
    required EmailService? emailService,
  }) async {
    if (emailService == null) {
      return _EmailQuotedTextHydrationResult(
        message: message,
        deltaMessageId: deltaMessageId,
        stopwatch: stopwatch,
        result: 'noEmailService',
        unavailable: true,
      );
    }
    String? quotedText;
    try {
      quotedText = (await emailService.getQuotedMessage(message))?.text?.trim();
    } on Exception {
      quotedText = null;
    }
    final sanitizedQuotedText = ChatSubjectCodec.previewBodyText(
      quotedText,
    ).trim();
    if (!_isEmailDeltaMessageRelevant(
      deltaMessageId,
      offWindowMessage: allowOffWindow ? message : null,
    )) {
      return _EmailQuotedTextHydrationResult(
        message: message,
        deltaMessageId: deltaMessageId,
        stopwatch: stopwatch,
        result: 'notRelevantAfterLoad',
      );
    }
    if (sanitizedQuotedText.isEmpty) {
      return _EmailQuotedTextHydrationResult(
        message: message,
        deltaMessageId: deltaMessageId,
        stopwatch: stopwatch,
        result: 'unavailable',
        unavailable: true,
      );
    }
    return _EmailQuotedTextHydrationResult(
      message: message,
      deltaMessageId: deltaMessageId,
      stopwatch: stopwatch,
      result: 'stored',
      quotedText: sanitizedQuotedText,
    );
  }

  void _traceEmailQuotedTextEnd({
    required int? deltaMessageId,
    required String result,
    required bool allowOffWindow,
    required Stopwatch stopwatch,
  }) {
    if (deltaMessageId != null) {
      _queuedEmailQuotedTextDeltaIds.remove(deltaMessageId);
    }
    final elapsedMs = stopwatch.elapsedMilliseconds;
    if (elapsedMs < _emailContentProfileTraceSlowThreshold.inMilliseconds &&
        (result == 'alreadyLoading' ||
            result == 'cached' ||
            result == 'notRelevant' ||
            result == 'notRelevantAfterLoad' ||
            result == 'stored')) {
      return;
    }
    SafeLogging.profileTrace(
      'chat.emailQuotedText',
      'end',
      fields: <String, Object?>{
        'deltaMessageId': deltaMessageId,
        'result': result,
        'allowOffWindow': allowOffWindow,
        'cached': deltaMessageId == null
            ? false
            : state.emailQuotedTextByDeltaId.containsKey(deltaMessageId),
        'loading': deltaMessageId == null
            ? false
            : state.emailQuotedTextLoading.contains(deltaMessageId),
        'unavailable': deltaMessageId == null
            ? false
            : state.emailQuotedTextUnavailable.contains(deltaMessageId),
        'elapsedMs': elapsedMs,
      },
    );
  }

  Message? _emailOriginalContentRequestMessage(Message? message) {
    final deltaMessageId = message?.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return null;
    }
    if (state.emailFullHtmlByDeltaId.containsKey(deltaMessageId)) {
      return null;
    }
    if (state.emailFullHtmlLoading.contains(deltaMessageId)) {
      return null;
    }
    if (state.emailFullHtmlUnavailable.contains(deltaMessageId)) {
      return null;
    }
    return message;
  }

  bool _requestEmailOriginalContent(
    Message? message, {
    bool allowOffWindow = false,
  }) {
    final requestMessage = _emailOriginalContentRequestMessage(message);
    if (requestMessage == null) {
      return false;
    }
    add(
      _ChatEmailOriginalContentRequested([
        requestMessage,
      ], allowOffWindow: allowOffWindow),
    );
    return true;
  }

  bool _isEmailDeltaMessageRelevant(
    int deltaMessageId, {
    Message? offWindowMessage,
  }) {
    for (final message in state.items) {
      if (message.deltaMsgId == deltaMessageId) {
        return true;
      }
    }
    if (state.focused?.deltaMsgId == deltaMessageId) {
      return true;
    }
    for (final message in state.pinnedMessages) {
      if (message.message?.deltaMsgId == deltaMessageId) {
        return true;
      }
    }
    final renderedMessage = offWindowMessage;
    if (renderedMessage != null &&
        renderedMessage.deltaMsgId == deltaMessageId &&
        _messageBelongsToCurrentChat(renderedMessage)) {
      return true;
    }
    return false;
  }

  Message? _queueEmailQuotedText(Message? message) {
    if (_emailService == null) {
      return null;
    }
    final deltaMessageId = message?.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return null;
    }
    final htmlBody = message?.htmlBody?.trim();
    if (htmlBody != null && htmlBody.isNotEmpty) {
      return null;
    }
    if (state.emailQuotedTextByDeltaId.containsKey(deltaMessageId)) {
      return null;
    }
    if (state.emailQuotedTextLoading.contains(deltaMessageId)) {
      return null;
    }
    if (_queuedEmailQuotedTextDeltaIds.contains(deltaMessageId)) {
      return null;
    }
    if (state.emailQuotedTextUnavailable.contains(deltaMessageId)) {
      return null;
    }
    _queuedEmailQuotedTextDeltaIds.add(deltaMessageId);
    return message;
  }

  bool _maybeRequestEmailQuotedText(
    Message? message, {
    bool allowOffWindow = false,
  }) {
    final queued = _queueEmailQuotedText(message);
    if (queued == null) {
      return false;
    }
    add(
      _ChatEmailQuotedTextBatchRequested([
        queued,
      ], allowOffWindow: allowOffWindow),
    );
    return true;
  }

  int _maybeRequestVisibleEmailQuotedText(
    List<Message> messages, {
    bool allowOffWindow = false,
  }) {
    final queuedMessages = <Message>[];
    for (final message in messages) {
      final queued = _queueEmailQuotedText(message);
      if (queued != null) {
        queuedMessages.add(queued);
      }
    }
    if (queuedMessages.isNotEmpty) {
      add(
        _ChatEmailQuotedTextBatchRequested(
          queuedMessages,
          allowOffWindow: allowOffWindow,
        ),
      );
      SafeLogging.profileTrace(
        'chat.emailQuotedTextQueue',
        'end',
        fields: <String, Object?>{
          'chatHash': state.chat == null
              ? null
              : SafeLogging.profileFingerprint(state.chat!.jid.trim()),
          'messageCount': messages.length,
          'queued': queuedMessages.length,
          'allowOffWindow': allowOffWindow,
        },
      );
    }
    return queuedMessages.length;
  }

  Future<void> _onChatTypingStarted(
    ChatTypingStarted event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    if (!_xmppAllowedForChat(chat)) {
      return;
    }
    if (_typingTimer case final timer?) {
      if (timer.isActive) {
        timer.reset();
      }
      return;
    } else {
      _typingTimer = RestartableTimer(
        const Duration(seconds: 3),
        () => add(_ChatTypingStopped(chat: chat)),
      );
    }
    await _chatsService.sendTyping(jid: chat.jid, typing: true);
    emit(state.copyWith(typing: true));
  }

  void _onChatTypingStopped(_ChatTypingStopped event, Emitter<ChatState> emit) {
    _stopTyping(chat: event.chat);
    emit(state.copyWith(typing: false));
  }

  void _onTypingParticipantsUpdated(
    _TypingParticipantsUpdated event,
    Emitter<ChatState> emit,
  ) {
    if (_isEmailChat) {
      return;
    }
    emit(state.copyWith(typingParticipants: event.participants));
  }

  void _completeChatMessageSent(
    ChatMessageSent event, {
    required ChatSendOutcome outcome,
  }) {
    final completer = event.completer;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(outcome);
  }

  Future<void> _deleteReleasedComposerStagedAttachments({
    required Iterable<PendingAttachment> submitted,
    required Iterable<PendingAttachment> retained,
  }) async {
    final retainedStagedPaths = retained
        .map((pending) => pending.stagedAttachment?.path)
        .whereType<String>()
        .toSet();
    for (final pending in submitted) {
      final staged = pending.stagedAttachment;
      if (staged == null || retainedStagedPaths.contains(staged.path)) {
        continue;
      }
      try {
        await deleteComposerStagedAttachment(staged);
      } on Exception catch (error, stackTrace) {
        _log.safeWarning(
          'Failed to delete released composer attachment staging file',
          error,
          stackTrace,
        );
      }
    }
  }

  Future<List<PendingAttachment>> _reconcileCommittedPendingAttachments(
    Iterable<PendingAttachment> pendingAttachments,
  ) async {
    final pendingList = pendingAttachments.toList(growable: false);
    if (pendingList.isEmpty) {
      return const <PendingAttachment>[];
    }
    final indexes = <int>[];
    final metadataIds = <String>[];
    for (var index = 0; index < pendingList.length; index += 1) {
      final pending = pendingList[index];
      if (pending.stagedAttachment == null) {
        continue;
      }
      final metadataId = pending.attachment.metadataId?.trim();
      if (metadataId == null || metadataId.isEmpty) {
        continue;
      }
      indexes.add(index);
      metadataIds.add(metadataId);
    }
    if (metadataIds.isEmpty) {
      return pendingList;
    }
    final attachments = await _messageService.loadDraftAttachments(metadataIds);
    final attachmentByMetadataId = {
      for (final attachment in attachments)
        if (attachment.metadataId?.trim().isNotEmpty == true)
          attachment.metadataId!.trim(): attachment,
    };
    if (attachmentByMetadataId.isEmpty) {
      return pendingList;
    }
    final updated = List<PendingAttachment>.from(pendingList);
    for (var index = 0; index < metadataIds.length; index += 1) {
      final attachment = attachmentByMetadataId[metadataIds[index]];
      if (attachment == null) {
        continue;
      }
      final pendingIndex = indexes[index];
      final pending = pendingList[pendingIndex];
      updated[pendingIndex] = pending.copyWith(
        attachment: attachment,
        clearStagedAttachment: true,
      );
    }
    return updated;
  }

  Future<void> _onChatMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    _stopTyping(chat: event.chat);
    emit(state.copyWith(typing: false));
    if (state.composerSendStatus.isLoading) {
      _completeChatMessageSent(
        event,
        outcome: ChatSendOutcome.blocked(
          message: ChatMessageKey.chatComposerSendFailed,
          pendingAttachments: List<PendingAttachment>.from(
            event.pendingAttachments,
          ),
        ),
      );
      return;
    }
    final chat = event.chat;
    if (chat.isAxiImServerAnnouncementThread) {
      _completeChatMessageSent(
        event,
        outcome: ChatSendOutcome.blocked(
          message: ChatMessageKey.chatComposerSendFailed,
          pendingAttachments: List<PendingAttachment>.from(
            event.pendingAttachments,
          ),
        ),
      );
      return;
    }
    final subject = event.subject;
    final quotedDraft = event.quotedDraft;
    final settings = event.settings;
    final attachments = List<PendingAttachment>.from(event.pendingAttachments);
    if (event.recipients.isEmpty) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerSelectRecipient,
        ),
      );
      _completeChatMessageSent(
        event,
        outcome: ChatSendOutcome.blocked(
          message: ChatMessageKey.chatComposerSelectRecipient,
          pendingAttachments: attachments,
        ),
      );
      return;
    }
    final storedStanzaIds = <String>{};
    final trimmedText = event.text.trim();
    final CalendarTask? requestedTask = event.calendarTaskIcs;
    final String? taskSharePreview = _calendarTaskSharePreview(
      requestedTask,
      event.calendarTaskShareText,
    );
    final bool taskReadOnly = event.calendarTaskIcsReadOnly;
    final queuedAttachments = attachments
        .where(
          (attachment) =>
              attachment.status == PendingAttachmentStatus.queued &&
              !attachment.isPreparing,
        )
        .toList(growable: false);
    var xmppDraftAttachments = queuedAttachments;
    final hasQueuedAttachments = queuedAttachments.isNotEmpty;
    final bool hasCalendarTaskIcs = requestedTask != null;
    final hasSubject = subject?.trim().isNotEmpty == true;
    final hasBody = trimmedText.isNotEmpty;
    final emailBody = hasBody ? trimmedText : (hasSubject ? '' : null);
    final emailBodyTrimmed = emailBody?.trim();
    final syntheticEmailReply = _emailService?.syntheticEmailReplyEnvelope(
      body: trimmedText,
      subject: subject,
      quotedDraft: quotedDraft,
    );
    if (trimmedText.isEmpty &&
        !hasQueuedAttachments &&
        !hasSubject &&
        !hasCalendarTaskIcs) {
      emit(
        state.copyWith(composerError: ChatMessageKey.chatComposerEmptyMessage),
      );
      _completeChatMessageSent(
        event,
        outcome: ChatSendOutcome.blocked(
          message: ChatMessageKey.chatComposerEmptyMessage,
          pendingAttachments: attachments,
        ),
      );
      return;
    }
    final forceEmail = _shouldForceEmailForSend(
      chat: chat,
      oneShotTransportOverride: event.oneShotTransportOverride,
    );
    final split = _splitRecipientsForSend(
      chat: chat,
      recipients: event.recipients,
      forceEmail: forceEmail,
    );
    final isLocalOnlyChat = chat.isAxichatWelcomeThread;
    final emailRecipients = split.emailRecipients;
    final xmppRecipients = split.xmppRecipients;
    final sendsXmppTaskEnvelope =
        requestedTask != null &&
        xmppRecipients.isNotEmpty &&
        xmppRecipients.every(
          (recipient) => _canSendCalendarTaskEnvelopeToRecipient(
            recipient,
            roomState: event.roomState,
          ),
        );
    final sendsXmppTaskAttachment =
        requestedTask != null &&
        xmppRecipients.isNotEmpty &&
        !sendsXmppTaskEnvelope;
    final CalendarTask? taskForXmpp = sendsXmppTaskEnvelope
        ? requestedTask
        : null;
    final rawAttachmentsViaEmail =
        (hasQueuedAttachments || hasCalendarTaskIcs) &&
        emailRecipients.isNotEmpty;
    final rawAttachmentsViaXmpp =
        (hasQueuedAttachments || sendsXmppTaskAttachment) &&
        xmppRecipients.isNotEmpty;
    final rawRequiresEmail =
        emailRecipients.isNotEmpty || rawAttachmentsViaEmail;
    final rawRequiresXmpp = xmppRecipients.isNotEmpty || rawAttachmentsViaXmpp;
    final xmppBody = _composeXmppBody(body: trimmedText, subject: subject);
    final hasXmppBody = xmppBody.isNotEmpty;
    final CalendarTaskIcsMessage? emailCalendarTaskMessage =
        requestedTask == null
        ? null
        : CalendarTaskIcsMessage(task: requestedTask, readOnly: taskReadOnly);
    final CalendarTaskIcsMessage? xmppCalendarTaskMessage =
        requestedTask == null
        ? null
        : CalendarTaskIcsMessage(task: requestedTask, readOnly: taskReadOnly);
    final String? soleRecipientId = xmppRecipients.length == 1
        ? xmppRecipients.first.recipientId
        : null;
    final CalendarTask? fanOutTask = soleRecipientId == chat.jid
        ? taskForXmpp
        : null;
    final quoteId = quotedDraft == null ? null : _messageKey(quotedDraft);
    final emailSignature = rawRequiresEmail
        ? _sendSignature(
            recipients: emailRecipients
                .map((recipient) => recipient.target.key)
                .toList(),
            body: emailBody ?? '',
            subject: subject,
            pendingAttachments: rawAttachmentsViaEmail
                ? queuedAttachments
                : const <PendingAttachment>[],
            calendarTaskIcsMessage: emailCalendarTaskMessage,
            quoteId: quoteId,
          )
        : null;
    final xmppSignature = rawRequiresXmpp
        ? _sendSignature(
            recipients: xmppRecipients
                .map((recipient) => recipient.target.key)
                .toList(),
            body: xmppBody,
            subject: subject,
            pendingAttachments: rawAttachmentsViaXmpp
                ? queuedAttachments
                : const <PendingAttachment>[],
            calendarTaskIcsMessage: xmppCalendarTaskMessage,
            quoteId: quoteId,
          )
        : null;
    final emailAlreadySent =
        emailSignature != null && _lastEmailSendSignature == emailSignature;
    final xmppAlreadySent =
        xmppSignature != null && _lastXmppSendSignature == xmppSignature;
    final attachmentsViaEmail = rawAttachmentsViaEmail && !emailAlreadySent;
    final attachmentsViaXmpp = rawAttachmentsViaXmpp && !xmppAlreadySent;
    final requiresEmail = rawRequiresEmail && !emailAlreadySent;
    final requiresXmpp = rawRequiresXmpp && !xmppAlreadySent;
    final shouldAttemptXmppFanOut =
        !xmppAlreadySent &&
        !rawAttachmentsViaXmpp &&
        xmppRecipients.isNotEmpty &&
        (hasXmppBody || fanOutTask != null);
    final shouldAttemptXmppDirect =
        !xmppAlreadySent &&
        !rawAttachmentsViaXmpp &&
        !requiresEmail &&
        xmppRecipients.isEmpty &&
        (hasXmppBody || taskForXmpp != null);
    final shouldAttemptXmppCalendarTaskAfterAttachments =
        !xmppAlreadySent &&
        rawAttachmentsViaXmpp &&
        xmppRecipients.isNotEmpty &&
        taskForXmpp != null;
    final hasQueuedEmailAttachments = queuedAttachments.isNotEmpty;
    final shouldSendCalendarTaskAttachment = hasCalendarTaskIcs;
    final shouldBundleEmailAttachments =
        attachmentsViaEmail && queuedAttachments.length > 1;
    final shouldSendEmailText = emailBody != null && !attachmentsViaEmail;
    final emailSendUnitCount =
        (shouldSendEmailText ? 1 : 0) +
        (attachmentsViaEmail && hasQueuedEmailAttachments
            ? (shouldBundleEmailAttachments ? 1 : queuedAttachments.length)
            : 0) +
        (attachmentsViaEmail && shouldSendCalendarTaskAttachment ? 1 : 0);
    final xmppSendUnitCount =
        (attachmentsViaXmpp
            ? (sendsXmppTaskAttachment ? 1 : 0) + queuedAttachments.length
            : 0) +
        ((shouldAttemptXmppFanOut ||
                shouldAttemptXmppDirect ||
                shouldAttemptXmppCalendarTaskAfterAttachments)
            ? 1
            : 0);
    final safeFailedOnlyRetry =
        !hasCalendarTaskIcs &&
        !(requiresEmail && requiresXmpp) &&
        ((requiresEmail && !requiresXmpp && emailSendUnitCount == 1) ||
            (requiresXmpp && !requiresEmail && xmppSendUnitCount == 1));
    final service = _emailService;
    if (requiresEmail && service == null) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerEmailUnavailable,
        ),
      );
      _completeChatMessageSent(
        event,
        outcome: ChatSendOutcome.blocked(
          message: ChatMessageKey.chatComposerEmailUnavailable,
          pendingAttachments: attachments,
        ),
      );
      return;
    }
    final allXmppRecipientsLocalOnly =
        xmppRecipients.isNotEmpty &&
        xmppRecipients.every(
          (recipient) => _isLocalOnlyXmppTarget(
            jid: _resolvedXmppRecipientJid(recipient),
            target: recipient.target,
          ),
        );
    if (attachmentsViaXmpp &&
        !event.supportsHttpFileUpload &&
        !(isLocalOnlyChat || allXmppRecipientsLocalOnly)) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerFileUploadUnavailable,
        ),
      );
      _completeChatMessageSent(
        event,
        outcome: ChatSendOutcome.blocked(
          message: ChatMessageKey.chatComposerFileUploadUnavailable,
          pendingAttachments: attachments,
        ),
      );
      return;
    }
    final invalidEmailRecipients = requiresEmail
        ? emailRecipients.where((recipient) {
            return !_recipientSupportsEmailSend(
              recipient: recipient,
              forceEmail: forceEmail,
            );
          })
        : const <ComposerRecipient>[];
    if (requiresEmail && emailRecipients.isEmpty) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerSelectRecipient,
        ),
      );
      _completeChatMessageSent(
        event,
        outcome: ChatSendOutcome.blocked(
          message: ChatMessageKey.chatComposerSelectRecipient,
          pendingAttachments: attachments,
        ),
      );
      return;
    }
    if (requiresEmail && invalidEmailRecipients.isNotEmpty) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerEmailRecipientUnavailable,
        ),
      );
      _completeChatMessageSent(
        event,
        outcome: ChatSendOutcome.blocked(
          message: ChatMessageKey.chatComposerEmailRecipientUnavailable,
          pendingAttachments: attachments,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        composerError: null,
        composerSendStatus: RequestStatus.loading,
      ),
    );
    var emailSendSucceeded = emailAlreadySent;
    var xmppSendSucceeded = xmppAlreadySent;
    var xmppAttempted = xmppAlreadySent || !requiresXmpp;
    final sendProgress = ComposerSendProgress(
      event.recipients.map((recipient) => recipient.recipientKey),
    );
    final xmppCompletedRecipientKeys = <ComposerRecipientKey>{};
    String? generatedXmppTaskAttachmentId;
    Future<void> saveXmppFanOutDraftForFailures(
      _ChatXmppSendResult result,
    ) async {
      if (!result.hasFailures || storedStanzaIds.isNotEmpty) {
        return;
      }
      final failedRecipients = xmppRecipients
          .where(
            (recipient) =>
                !result.completedRecipientKeys.contains(recipient.recipientKey),
          )
          .toList(growable: false);
      if (failedRecipients.isEmpty) {
        return;
      }
      await _saveXmppDraft(
        chat: chat,
        recipients: failedRecipients,
        body: trimmedText,
        attachments: xmppDraftAttachments,
        subject: subject,
        quotedDraft: quotedDraft,
        calendarTaskIcsMessage: xmppCalendarTaskMessage,
        emit: emit,
      );
    }

    try {
      if (chat.type == ChatType.groupChat) {
        await _ensureMucMembership(chat);
      }
      if (requiresEmail) {
        final EmailService emailService = service!;
        var emailTextSent = false;
        var emailAttachmentsSent = !attachmentsViaEmail;
        Attachment? bundledEmailAttachment;
        if (shouldBundleEmailAttachments) {
          _markPendingAttachmentsPreparingInList(
            attachments,
            queuedAttachments,
            preparing: true,
          );
          try {
            bundledEmailAttachment = await _bundlePendingAttachments(
              attachments: queuedAttachments,
              caption: emailBodyTrimmed?.isNotEmpty == true ? emailBody : null,
            );
          } on EmailAttachmentBundleException catch (error, stackTrace) {
            _log.warning(
              'Failed to bundle email attachments',
              error,
              stackTrace,
            );
            emit(
              state.copyWith(
                composerError:
                    ChatMessageKey.chatComposerAttachmentBundleFailed,
              ),
            );
            return;
          } finally {
            _markPendingAttachmentsPreparingInList(
              attachments,
              queuedAttachments,
              preparing: false,
            );
          }
        }
        if (shouldSendEmailText) {
          final shouldFanOut = _shouldFanOut(emailRecipients, chat);
          final effectiveEmailSubject = shouldFanOut
              ? (syntheticEmailReply?.subject ?? subject)
              : subject;
          final effectiveEmailBody = shouldFanOut
              ? (syntheticEmailReply?.body ?? emailBody)
              : emailBody;
          final effectiveEmailHtmlBody = shouldFanOut
              ? syntheticEmailReply?.htmlBody
              : null;
          if (shouldFanOut) {
            final unitRecipients = _emailRecipientsForNextSendUnit(
              recipients: emailRecipients,
              progress: sendProgress,
            );
            if (unitRecipients.isEmpty) {
              return;
            }
            final result = await _sendFanOut(
              recipients: unitRecipients,
              text: effectiveEmailBody,
              htmlBody: effectiveEmailHtmlBody,
              subject: effectiveEmailSubject,
              quotedStanzaId: syntheticEmailReply?.quotedStanzaId,
              chat: chat,
              settings: settings,
              emit: emit,
            );
            _applyEmailSendUnitResult(
              progress: sendProgress,
              recipients: unitRecipients,
              result: result,
            );
            if (!result.succeeded) {
              return;
            }
          } else {
            if (quotedDraft != null) {
              await emailService.sendReply(
                chat: chat,
                body: trimmedText,
                quotedMessage: quotedDraft,
                subject: subject,
              );
            } else {
              await emailService.sendMessage(
                chat: chat,
                body: emailBody,
                subject: subject,
              );
            }
            _messageService.notifyDemoOutboundTextMessage(
              chatJid: chat.jid,
              body: trimmedText,
            );
            if (kEnableDemoChats && trimmedText.isNotEmpty) {
              await _messageService.updateDemoChatSummary(
                chatJid: chat.jid,
                lastMessage: trimmedText,
              );
            }
          }
          emailTextSent = true;
        }
        if (attachmentsViaEmail) {
          final captionForAttachments = emailBodyTrimmed?.isNotEmpty == true
              ? emailBody
              : null;
          final calendarTaskCaption = captionForAttachments ?? taskSharePreview;
          var queuedAttachmentsSent = !hasQueuedEmailAttachments;
          if (hasQueuedEmailAttachments) {
            final attachmentsSent = shouldBundleEmailAttachments
                ? await _sendBundledEmailAttachments(
                    attachments: queuedAttachments,
                    pendingAttachments: attachments,
                    bundledAttachment: bundledEmailAttachment!,
                    chat: chat,
                    service: emailService,
                    recipients: emailRecipients,
                    emit: emit,
                    subject: subject,
                    quotedDraft: quotedDraft,
                    settings: settings,
                    retainOnSuccess: attachmentsViaXmpp,
                    captionForBundle: captionForAttachments,
                    progress: sendProgress,
                    hasFollowingEmailUnits: shouldSendCalendarTaskAttachment,
                  )
                : await _sendQueuedAttachments(
                    attachments: queuedAttachments,
                    pendingAttachments: attachments,
                    chat: chat,
                    service: emailService,
                    recipients: emailRecipients,
                    emit: emit,
                    subject: subject,
                    quotedDraft: quotedDraft,
                    settings: settings,
                    retainOnSuccess: attachmentsViaXmpp,
                    captionForFirstAttachment: captionForAttachments,
                    progress: sendProgress,
                    hasFollowingEmailUnits: shouldSendCalendarTaskAttachment,
                  );
            if (!attachmentsSent) {
              return;
            }
            queuedAttachmentsSent = true;
          }
          var calendarTaskSent = !shouldSendCalendarTaskAttachment;
          if (shouldSendCalendarTaskAttachment) {
            final unitRecipients = _emailRecipientsForNextSendUnit(
              recipients: emailRecipients,
              progress: sendProgress,
            );
            if (unitRecipients.isEmpty) {
              return;
            }
            final result = await _sendCalendarTaskEmailAttachment(
              task: requestedTask,
              taskReadOnly: taskReadOnly,
              chat: chat,
              service: emailService,
              recipients: unitRecipients,
              emit: emit,
              subject: subject,
              quotedDraft: quotedDraft,
              settings: settings,
              caption: calendarTaskCaption,
            );
            _applyEmailSendUnitResult(
              progress: sendProgress,
              recipients: unitRecipients,
              result: result,
            );
            if (!result.succeeded) {
              return;
            }
            calendarTaskSent = true;
          }
          emailAttachmentsSent = queuedAttachmentsSent && calendarTaskSent;
          if (emailAttachmentsSent &&
              (hasQueuedEmailAttachments || shouldSendCalendarTaskAttachment)) {
            _messageService.notifyDemoOutboundAttachmentMessage(
              chatJid: chat.jid,
            );
            if (kEnableDemoChats) {
              final String? caption =
                  calendarTaskCaption?.trim().isNotEmpty == true
                  ? calendarTaskCaption
                  : captionForAttachments;
              final String preview = caption?.trim().isNotEmpty == true
                  ? caption!.trim()
                  : event.attachmentFallbackLabel;
              await _messageService.updateDemoChatSummary(
                chatJid: chat.jid,
                lastMessage: preview,
              );
            }
          }
        }
        emailSendSucceeded =
            (!shouldSendEmailText || emailTextSent) && emailAttachmentsSent;
        if (emailSendSucceeded && emailSignature != null) {
          _lastEmailSendSignature = emailSignature;
        }
      }
      var xmppAttachmentsSent = !attachmentsViaXmpp;
      var xmppBodySent =
          !(shouldAttemptXmppFanOut ||
              shouldAttemptXmppDirect ||
              shouldAttemptXmppCalendarTaskAfterAttachments);
      var xmppCalendarTaskSent = false;
      var postAttachmentXmppRecipients = xmppRecipients;
      if (requiresXmpp) {
        xmppAttempted = true;
      }
      if (attachmentsViaXmpp) {
        final attachmentsForXmpp = <PendingAttachment>[];
        if (sendsXmppTaskAttachment) {
          final calendarTaskAttachment = await _buildCalendarTaskIcsAttachment(
            requestedTask,
          );
          generatedXmppTaskAttachmentId =
              'calendar-task-${requestedTask.id}-${DateTime.timestamp().microsecondsSinceEpoch}';
          final resolvedCalendarTaskAttachment = taskSharePreview == null
              ? calendarTaskAttachment
              : calendarTaskAttachment.copyWith(caption: taskSharePreview);
          attachmentsForXmpp.add(
            PendingAttachment(
              id: generatedXmppTaskAttachmentId,
              attachment: resolvedCalendarTaskAttachment,
            ),
          );
        }
        attachmentsForXmpp.addAll(queuedAttachments);
        final result = await _sendXmppAttachments(
          attachments: attachmentsForXmpp,
          pendingAttachments: attachments,
          chat: chat,
          recipients: xmppRecipients,
          emit: emit,
          supportsHttpFileUpload: event.supportsHttpFileUpload,
          subject: subject,
          quotedDraft: shouldAttemptXmppCalendarTaskAfterAttachments
              ? null
              : quotedDraft,
          draftQuotedDraft: shouldAttemptXmppCalendarTaskAfterAttachments
              ? quotedDraft
              : null,
          draftBody: shouldAttemptXmppCalendarTaskAfterAttachments
              ? xmppBody
              : _emptySignatureValue,
          draftCalendarTaskIcsMessage:
              shouldAttemptXmppCalendarTaskAfterAttachments
              ? xmppCalendarTaskMessage
              : null,
          caption: !shouldAttemptXmppCalendarTaskAfterAttachments
              ? (hasXmppBody ? xmppBody : taskSharePreview)
              : null,
          onLocalMessageStored: storedStanzaIds.add,
        );
        final generatedAttachmentId = generatedXmppTaskAttachmentId;
        xmppDraftAttachments = result.submittedAttachments
            .where((pending) => pending.id != generatedAttachmentId)
            .toList(growable: false);
        xmppCompletedRecipientKeys.addAll(result.completedRecipientKeys);
        if (shouldAttemptXmppCalendarTaskAfterAttachments) {
          postAttachmentXmppRecipients = xmppRecipients
              .where(
                (recipient) => result.completedRecipientKeys.contains(
                  recipient.recipientKey,
                ),
              )
              .toList(growable: false);
          if (postAttachmentXmppRecipients.isEmpty) {
            return;
          }
        } else if (result.hasFailures) {
          return;
        }
        xmppAttachmentsSent = !result.hasFailures;
        if (result.completedRecipientKeys.isNotEmpty) {
          _messageService.notifyDemoOutboundAttachmentMessage(
            chatJid: chat.jid,
          );
        }
      }
      if (shouldAttemptXmppFanOut) {
        final result = await _sendXmppFanOut(
          recipients: xmppRecipients,
          body: xmppBody,
          calendarTaskIcs: fanOutTask,
          calendarTaskIcsReadOnly: taskReadOnly,
          quotedDraft: quotedDraft,
          onLocalMessageStored: storedStanzaIds.add,
        );
        xmppCompletedRecipientKeys.addAll(result.completedRecipientKeys);
        xmppBodySent = !result.hasFailures;
        if (fanOutTask != null) {
          xmppCalendarTaskSent = !result.hasFailures;
        }
        if (result.hasFailures) {
          emit(
            state.copyWith(
              composerError: ChatMessageKey.chatComposerSendFailed,
            ),
          );
          await saveXmppFanOutDraftForFailures(result);
        }
      } else if (shouldAttemptXmppDirect) {
        final sameChatQuote =
            quotedDraft != null && quotedDraft.chatJid == chat.jid
            ? quotedDraft
            : null;
        if (isLocalOnlyChat) {
          await _messageService.sendLocalOnlyMessage(
            jid: chat.jid,
            text: xmppBody,
            encryptionProtocol: chat.encryptionProtocol,
            quotedMessage: sameChatQuote,
            calendarTaskIcs: taskForXmpp,
            calendarTaskIcsReadOnly: taskReadOnly,
            chatType: chat.type,
            onLocalMessageStored: storedStanzaIds.add,
          );
        } else {
          await _messageService.sendMessage(
            jid: chat.jid,
            text: xmppBody,
            encryptionProtocol: chat.encryptionProtocol,
            quotedMessage: sameChatQuote,
            calendarTaskIcs: taskForXmpp,
            calendarTaskIcsReadOnly: taskReadOnly,
            chatType: chat.type,
            onLocalMessageStored: storedStanzaIds.add,
          );
        }
        xmppBodySent = true;
        if (taskForXmpp != null) {
          xmppCalendarTaskSent = true;
        }
      }
      if (shouldAttemptXmppCalendarTaskAfterAttachments) {
        final result = await _sendXmppFanOut(
          recipients: postAttachmentXmppRecipients,
          body: xmppBody,
          calendarTaskIcs: taskForXmpp,
          calendarTaskIcsReadOnly: taskReadOnly,
          quotedDraft: quotedDraft,
          onLocalMessageStored: storedStanzaIds.add,
        );
        xmppCompletedRecipientKeys.addAll(result.completedRecipientKeys);
        xmppBodySent = !result.hasFailures;
        xmppCalendarTaskSent = !result.hasFailures;
        if (result.hasFailures) {
          emit(
            state.copyWith(
              composerError: ChatMessageKey.chatComposerSendFailed,
            ),
          );
          await saveXmppFanOutDraftForFailures(result);
        }
      }
      if (xmppCalendarTaskSent) {
        _messageService.notifyDemoOutboundAttachmentMessage(chatJid: chat.jid);
        if (kEnableDemoChats) {
          final preview = taskSharePreview ?? event.attachmentFallbackLabel;
          await _messageService.updateDemoChatSummary(
            chatJid: chat.jid,
            lastMessage: preview,
          );
        }
      }
      xmppSendSucceeded = xmppAttachmentsSent && xmppBodySent;
      if (xmppSendSucceeded && xmppSignature != null) {
        _lastXmppSendSignature = xmppSignature;
      }
    } on DeltaChatException catch (error, stackTrace) {
      _log.safeWarning(_sendEmailMessageFailedLogMessage, error, stackTrace);
      if (requiresEmail) {
        final mappedError = DeltaErrorMapper.resolve(error.message);
        emit(
          state.copyWith(
            composerError: _chatMessageKeyForMessageError(mappedError),
          ),
        );
      }
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.safeWarning(_sendEmailMessageFailedLogMessage, error, stackTrace);
      if (requiresEmail) {
        emit(
          state.copyWith(
            composerError: ChatMessageKey.chatComposerEmailUnavailable,
          ),
        );
      }
    } on EmailServiceException catch (error, stackTrace) {
      _log.safeWarning(_sendEmailMessageFailedLogMessage, error, stackTrace);
      if (requiresEmail) {
        emit(
          state.copyWith(composerError: ChatMessageKey.chatComposerSendFailed),
        );
      }
    } on XmppMessageException catch (error, stackTrace) {
      _log.safeWarning(_sendMessageFailedLogMessage, error, stackTrace);
      if (storedStanzaIds.isEmpty) {
        await _saveXmppDraft(
          chat: chat,
          recipients: xmppRecipients,
          body: trimmedText,
          attachments: xmppDraftAttachments,
          subject: subject,
          quotedDraft: quotedDraft,
          calendarTaskIcsMessage: xmppCalendarTaskMessage,
          emit: emit,
        );
      }
    } finally {
      final shouldClearComposer =
          (!requiresEmail || emailSendSucceeded) &&
          (!requiresXmpp || xmppSendSucceeded);
      if (shouldClearComposer) {
        _lastEmailSendSignature = null;
        _lastXmppSendSignature = null;
      }
      if (shouldClearComposer && queuedAttachments.isNotEmpty) {
        _removePendingAttachmentsByIdsFromList(
          attachments,
          queuedAttachments.map((pending) => pending.id),
        );
      }
      final taskAttachmentId = generatedXmppTaskAttachmentId;
      if (taskAttachmentId != null) {
        _removePendingAttachmentFromList(attachments, taskAttachmentId);
      }
      if (requiresEmail) {
        if (emailSendSucceeded) {
          sendProgress.markCompletedAll(
            emailRecipients.map((recipient) => recipient.recipientKey),
          );
        } else {
          sendProgress.markMissingAs(
            emailRecipients.map((recipient) => recipient.recipientKey),
            SendRecipientOutcome.failed,
          );
        }
      }
      if (requiresXmpp) {
        sendProgress.markCompletedAll(xmppCompletedRecipientKeys);
        if (xmppSendSucceeded) {
          sendProgress.markCompletedAll(
            xmppRecipients.map((recipient) => recipient.recipientKey),
          );
        } else {
          sendProgress.markMissingAs(
            xmppRecipients.map((recipient) => recipient.recipientKey),
            xmppAttempted
                ? SendRecipientOutcome.failed
                : SendRecipientOutcome.notAttempted,
          );
        }
      }
      final composerError = state.composerError;
      final incompleteRecipients = sendProgress.incompleteRecipientsFor(
        event.recipients,
      );
      final retainsCompletedPinnedRecipient = _wouldHideIncludedPinnedRecipient(
        submittedRecipients: event.recipients,
        nextRecipients: incompleteRecipients,
      );
      final outcomeRecipients = retainsCompletedPinnedRecipient
          ? _includeIncludedPinnedRecipients(
              submittedRecipients: event.recipients,
              recipients: incompleteRecipients,
            )
          : incompleteRecipients;
      final resendMayDuplicate = _retryMayDuplicateDeliveredUnits(
        safeFailedOnlyRetry: safeFailedOnlyRetry,
        requiresEmail: requiresEmail,
        requiresXmpp: requiresXmpp,
        emailSendSucceeded: emailSendSucceeded,
        xmppSendSucceeded: xmppSendSucceeded,
        emailSendUnitCount: emailSendUnitCount,
        xmppSendUnitCount: xmppSendUnitCount,
        retainsCompletedPinnedRecipient: retainsCompletedPinnedRecipient,
      );
      final outcomeMessage = resendMayDuplicate
          ? ChatMessageKey.chatComposerPartialSendWarning
          : composerError ?? ChatMessageKey.chatComposerSendFailed;
      if (state.composerSendStatus.isLoading) {
        emit(
          state.copyWith(
            composerSendStatus: RequestStatus.none,
            composerError: shouldClearComposer ? null : outcomeMessage,
          ),
        );
      }
      final outcomePendingAttachments =
          await _reconcileCommittedPendingAttachments(attachments);
      final outcome = shouldClearComposer
          ? ChatSendOutcome.completed(
              pendingAttachments: outcomePendingAttachments,
            )
          : ChatSendOutcome.incomplete(
              recipients: outcomeRecipients,
              pendingAttachments: outcomePendingAttachments,
              recipientOutcomes: sendProgress.outcomes,
              resendMayDuplicate: resendMayDuplicate,
              message: outcomeMessage,
            );
      await _deleteReleasedComposerStagedAttachments(
        submitted: event.pendingAttachments,
        retained: outcome.pendingAttachments,
      );
      _completeChatMessageSent(event, outcome: outcome);
      if (shouldClearComposer && (state.emailSubject?.isNotEmpty ?? false)) {
        _clearEmailSubject(emit);
      }
    }
  }

  Future<void> _onChatAvailabilityMessageSent(
    ChatAvailabilityMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    _stopTyping(chat: event.chat);
    emit(state.copyWith(typing: false));
    final chat = event.chat;
    if (chat.defaultTransport.isEmail || chat.isAxiImServerAnnouncementThread) {
      return;
    }
    if (chat.isAxichatWelcomeThread) {
      try {
        await _messageService.sendLocalOnlyAvailabilityMessage(
          jid: chat.jid,
          message: event.message,
          chatType: chat.type,
        );
      } catch (error, stackTrace) {
        _log.warning(_availabilitySendFailureLog, error, stackTrace);
      }
      return;
    }
    if (chat.type == ChatType.groupChat) {
      await _ensureMucMembership(chat);
    }
    try {
      await _messageService.sendAvailabilityMessage(
        jid: chat.jid,
        message: event.message,
        chatType: chat.type,
      );
    } catch (error, stackTrace) {
      _log.warning(_availabilitySendFailureLog, error, stackTrace);
    }
  }

  Future<void> _onChatMuted(ChatMuted event, Emitter<ChatState> emit) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _chatsService.toggleChatMuted(jid: chatJid, muted: event.muted);
  }

  Future<void> _runChatSettingMutation({
    required Emitter<ChatState> emit,
    required ChatSettingId settingId,
    required Chat Function(Chat chat) updateLocalChat,
    required Future<bool> Function() mutation,
  }) async {
    if (state.isChatSettingLoading(settingId)) return;
    final currentChat = state.chat;
    emit(
      state
          .markChatSettingLoading(settingId)
          .copyWith(
            chat: currentChat == null ? null : updateLocalChat(currentChat),
          ),
    );
    final publishedSnapshot = state.chat?.chatSettingsSyncJson;
    final published = await mutation();
    final next = state.clearChatSettingLoading(settingId);
    final confirmed =
        published &&
            publishedSnapshot != null &&
            mapEquals(next.chat?.chatSettingsSyncJson, publishedSnapshot)
        ? next.chat?.markChatSettingsSyncConfirmed()
        : next.chat;
    emit(
      published
          ? next.copyWith(chat: confirmed)
          : _attachToast(
              next,
              const ChatToast(
                message: ChatMessageKey.settingsSyncFailure,
                variant: ChatToastVariant.destructive,
              ),
            ),
    );
  }

  Future<void> _onChatSettingSyncRetried(
    ChatSettingSyncRetried event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null) {
      return;
    }
    if (state.isChatSettingLoading(event.settingId)) return;
    emit(state.markChatSettingLoading(event.settingId));
    final publishedSnapshot = state.chat?.chatSettingsSyncJson;
    final published = await _chatsService.retryChatSettingsSync(chat.jid);
    final next = state.clearChatSettingLoading(event.settingId);
    final confirmed =
        published &&
            publishedSnapshot != null &&
            mapEquals(next.chat?.chatSettingsSyncJson, publishedSnapshot)
        ? next.chat?.markChatSettingsSyncConfirmed()
        : next.chat;
    emit(
      published
          ? next.copyWith(chat: confirmed)
          : _attachToast(
              next,
              const ChatToast(
                message: ChatMessageKey.settingsSyncFailure,
                variant: ChatToastVariant.destructive,
              ),
            ),
    );
  }

  Future<void> _onChatNotificationPreviewSettingChanged(
    ChatNotificationPreviewSettingChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.notificationPreview,
      updateLocalChat: (chat) =>
          chat.copyWith(notificationPreviewSetting: event.setting),
      mutation: () => _chatsService.setChatNotificationPreviewSetting(
        jid: chat.jid,
        setting: event.setting,
      ),
    );
  }

  Future<void> _onChatNotificationBehaviorChanged(
    ChatNotificationBehaviorChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.notificationBehavior,
      updateLocalChat: (chat) => chat.copyWith(
        notificationBehavior: event.behavior,
        muted: event.behavior == ChatNotificationBehavior.muted,
      ),
      mutation: () => _chatsService.setChatNotificationBehavior(
        jid: chat.jid,
        behavior: event.behavior,
      ),
    );
  }

  Future<void> _onChatEmailServiceUpdated(
    ChatEmailServiceUpdated event,
    Emitter<ChatState> emit,
  ) async {
    final emailService = event.emailService;
    if (identical(_emailService, emailService)) {
      return;
    }
    final emailSub = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await _detachAndCancelSubscription(emailSub);
    final contentPreparationSub = _emailContentPreparationSubscription;
    _emailContentPreparationSubscription = null;
    await _detachAndCancelSubscription(contentPreparationSub);
    final originalContentSub = _emailOriginalContentSubscription;
    _emailOriginalContentSubscription = null;
    await _detachAndCancelSubscription(originalContentSub);
    if (emit.isDone) return;
    _clearPendingUnreadDividerEmailContentMessages();
    _clearVisibleEmailContentMessagesForCurrentChat();
    _emailService = emailService;
    _emailContentPreparationSnapshot =
        emailService?.contentPreparationSnapshot ??
        EmailContentPreparationSnapshot.empty;
    _emailOriginalContentSnapshot =
        emailService?.originalContentSnapshot ??
        EmailOriginalContentSnapshot.empty;
    final shouldResetEmailAvailability = emailService != null;
    emit(
      _withEmailContentPreparationProjection(
        state.copyWith(
          emailServiceAvailable: emailService != null,
          emailSelfJid: emailService?.selfSenderJid,
          emailRawHeadersUnavailable: shouldResetEmailAvailability
              ? const <int>{}
              : state.emailRawHeadersUnavailable,
          emailFullHtmlUnavailable: shouldResetEmailAvailability
              ? const <int>{}
              : state.emailFullHtmlUnavailable,
          emailQuotedTextUnavailable: shouldResetEmailAvailability
              ? const <int>{}
              : state.emailQuotedTextUnavailable,
        ),
      ),
    );
    if (emailService != null) {
      _emailSyncSubscription = emailService.syncStateStream.listen(
        (syncState) => add(_EmailSyncStateChanged(syncState)),
      );
      _emailContentPreparationSubscription = emailService
          .contentPreparationStream
          .listen(
            (snapshot) => add(_ChatEmailContentPreparationUpdated(snapshot)),
          );
      _emailOriginalContentSubscription = emailService.originalContentStream
          .listen(
            (snapshot) => add(_ChatEmailOriginalContentUpdated(snapshot)),
          );
      _applyEmailSyncState(emailService.syncState, emit);
      _requestEmailOriginalContent(state.focused);
      _maybeRequestEmailQuotedText(state.focused);
      _requestPresentationHydrationForMessages(
        state.pinnedMessages.map((item) => item.message).whereType<Message>(),
        hydrateEmailContent: true,
        allowOffWindowEmailContentHydration: true,
      );
    } else {
      _applyEmailSyncState(const EmailSyncState.ready(), emit);
    }
    final chat = state.chat;
    if (chat == null) {
      return;
    }
    await _subscribeToMessages(
      limit: _currentMessageLimit,
      filter: state.viewFilter,
    );
    await _subscribeToPinnedMessages(chat);
  }

  Future<void> _onChatShareSignatureToggled(
    ChatShareSignatureToggled event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.shareSignature,
      updateLocalChat: (chat) =>
          chat.copyWith(shareSignatureEnabled: event.enabled),
      mutation: () => _chatsService.toggleChatShareSignature(
        jid: chat.jid,
        enabled: event.enabled,
      ),
    );
  }

  Future<void> _onChatAttachmentAutoDownloadToggled(
    ChatAttachmentAutoDownloadToggled event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.attachmentAutoDownload,
      updateLocalChat: (chat) =>
          chat.copyWith(attachmentAutoDownload: event.value),
      mutation: () => _chatsService.toggleChatAttachmentAutoDownload(
        jid: chat.jid,
        value: event.value,
      ),
    );
    if (event.value == AttachmentAutoDownload.allowed) {
      _queueAutoDownloadAttachments(
        messages: state.items,
        attachmentsByMessageId: state.attachmentMetadataIdsByMessageId,
      );
    }
  }

  Future<void> _onChatAttachmentAutoDownloadRequested(
    ChatAttachmentAutoDownloadRequested event,
    Emitter<ChatState> emit,
  ) async {
    final stanzaId = event.stanzaId.trim();
    if (stanzaId.isEmpty) return;
    final message = state.items
        .where((item) => item.stanzaID == stanzaId)
        .firstOrNull;
    if (message == null) return;
    final key = _messageKey(message);
    final attachmentIds = state.attachmentMetadataIdsByMessageId[key];
    if (attachmentIds == null || attachmentIds.isEmpty) return;
    _queueAutoDownloadAttachments(
      messages: [message],
      attachmentsByMessageId: {key: attachmentIds},
      force: true,
    );
  }

  Future<void> _onChatResponsivityChanged(
    ChatResponsivityChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.readReceipts,
      updateLocalChat: (chat) =>
          chat.copyWith(markerResponsive: event.responsive),
      mutation: () => _chatsService.toggleChatMarkerResponsive(
        jid: chatJid,
        responsive: event.responsive,
      ),
    );
  }

  Future<void> _onChatTypingIndicatorsChanged(
    ChatTypingIndicatorsChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.typingIndicators,
      updateLocalChat: (chat) =>
          chat.copyWith(typingIndicatorsEnabled: event.enabled),
      mutation: () => _chatsService.setChatTypingIndicators(
        jid: chatJid,
        enabled: event.enabled,
      ),
    );
  }

  Future<void> _onChatEmailRemoteImagesChanged(
    ChatEmailRemoteImagesChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.emailImageAutoload,
      updateLocalChat: (chat) =>
          chat.copyWith(emailRemoteImagesEnabled: event.enabled),
      mutation: () => _chatsService.setChatEmailRemoteImages(
        jid: chatJid,
        enabled: event.enabled,
      ),
    );
  }

  Future<void> _onChatEmailReadReceiptsChanged(
    ChatEmailReadReceiptsChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.emailReadReceipts,
      updateLocalChat: (chat) =>
          chat.copyWith(emailReadReceiptsEnabled: event.enabled),
      mutation: () => _chatsService.setChatEmailReadReceipts(
        jid: chatJid,
        enabled: event.enabled,
      ),
    );
  }

  Future<void> _onChatEmailSendConfirmationChanged(
    ChatEmailSendConfirmationChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.emailSendConfirmation,
      updateLocalChat: (chat) =>
          chat.copyWith(emailSendConfirmationEnabled: event.enabled),
      mutation: () => _chatsService.setChatEmailSendConfirmation(
        jid: chatJid,
        enabled: event.enabled,
      ),
    );
  }

  Future<void> _onChatEmailComposerWatermarkChanged(
    ChatEmailComposerWatermarkChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _runChatSettingMutation(
      emit: emit,
      settingId: ChatSettingId.emailComposerWatermark,
      updateLocalChat: (chat) =>
          chat.copyWith(emailComposerWatermarkEnabled: event.enabled),
      mutation: () => _chatsService.setChatEmailComposerWatermark(
        jid: chatJid,
        enabled: event.enabled,
      ),
    );
  }

  Future<void> _onChatSavedTransportOverrideChanged(
    ChatSavedTransportOverrideChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null ||
        !sameBareAddress(chat.jid, event.chatJid) ||
        !state.canOfferEmailOutboundOverride) {
      return;
    }
    if (state.savedTransportOverrideStatus.isLoading) return;
    emit(state.copyWith(savedTransportOverrideStatus: RequestStatus.loading));
    final transport = event.transport;
    try {
      if (transport == null || transport == chat.defaultTransport) {
        await _chatsService.clearChatTransportPreference(jid: chat.jid);
        emit(
          state.copyWith(
            savedTransportOverride: null,
            savedTransportOverrideStatus: RequestStatus.none,
          ),
        );
        return;
      }
      await _chatsService.saveChatTransportPreference(
        jid: chat.jid,
        transport: transport,
      );
      emit(
        state.copyWith(
          savedTransportOverride: transport,
          savedTransportOverrideStatus: RequestStatus.none,
        ),
      );
    } on XmppAbortedException {
      emit(state.copyWith(savedTransportOverrideStatus: RequestStatus.none));
    }
  }

  Future<void> _onChatEncryptionChanged(
    ChatEncryptionChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _chatsService.setChatEncryption(
      jid: chatJid,
      protocol: event.protocol,
    );
  }

  Future<void> _onChatEncryptionRepaired(
    ChatEncryptionRepaired event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    await _omemoService?.recreateSessions(jid: chatJid);
  }

  Future<void> _onChatLoadEarlier(
    ChatLoadEarlier event,
    Emitter<ChatState> emit,
  ) async {
    if (state.loadEarlierStatus.isLoading) {
      return;
    }
    emit(state.copyWith(loadEarlierStatus: RequestStatus.loading));
    final status = await _enqueueLoadEarlier(emit);
    if (emit.isDone || !state.loadEarlierStatus.isLoading) {
      return;
    }
    emit(state.copyWith(loadEarlierStatus: status));
  }

  Future<RequestStatus> _enqueueLoadEarlier(Emitter<ChatState> emit) async {
    try {
      final chat = state.chat;
      if (chat == null) {
        return RequestStatus.success;
      }
      final chatJid = chat.jid;
      final hadMoreLocalMessages = state.hasMoreLocalMessages;
      final nextLimit = _currentMessageLimit + _timelineBatchSizeForChat(chat);
      _currentMessageLimit = nextLimit;
      _messageSubscriptionGeneration += 1;
      final generation = _messageSubscriptionGeneration;
      final loadedLocalWindow = await _loadLocalMessagesForCurrentWindow(
        chat: chat,
        generation: generation,
        limit: nextLimit,
        awaitPageEnrichment: hadMoreLocalMessages,
        emit: emit,
      );
      if (!loadedLocalWindow) {
        return RequestStatus.success;
      }
      unawaited(
        fireAndForget(
          () => _subscribeToMessages(
            limit: nextLimit,
            filter: state.viewFilter,
            generationOverride: generation,
          ),
          operationName: 'rebind load earlier message stream',
          loggerName: 'ChatBloc',
        ),
      );
      if (state.chat?.jid != chatJid) {
        return RequestStatus.success;
      }
      if (hadMoreLocalMessages) {
        return RequestStatus.success;
      }
      final canPageXmpp = _canPageXmppHistory(chat);
      if (!canPageXmpp) {
        return RequestStatus.success;
      }
      if (!state.xmppHistoryPaginationState.canAttempt) {
        return RequestStatus.success;
      }
      emit(
        state.copyWith(
          xmppHistoryPaginationState: ChatHistoryPaginationSourceState.loading,
        ),
      );
      final mamResult = await _loadEarlierFromMam();
      if (state.chat?.jid != chatJid) {
        return RequestStatus.success;
      }
      emit(
        state.copyWith(
          xmppHistoryPaginationState: mamResult == null || mamResult.complete
              ? ChatHistoryPaginationSourceState.exhausted
              : _xmppPaginationStateFor(chat),
        ),
      );
      return RequestStatus.success;
    } on Exception catch (error, stackTrace) {
      _log.safeFine('Failed to load earlier', error, stackTrace);
      return RequestStatus.failure;
    }
  }

  Future<bool> _loadLocalMessagesForCurrentWindow({
    required Chat chat,
    required int generation,
    required int limit,
    required bool awaitPageEnrichment,
    required Emitter<ChatState> emit,
  }) async {
    final items = await _messageService.loadChatMessagesPage(
      chat.jid,
      start: 0,
      end: _messageProbeLimit(limit),
      filter: state.viewFilter,
    );
    if (state.chat?.jid != chat.jid ||
        generation != _messageSubscriptionGeneration) {
      return false;
    }
    await _onChatMessagesUpdated(
      _ChatMessagesUpdated(
        items,
        generation,
        awaitPageEnrichment: awaitPageEnrichment,
      ),
      emit,
    );
    return true;
  }

  Future<void> _onChatAlertHidden(
    ChatAlertHidden event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    emit(state.copyWith(showAlert: false));
    if (event.forever) {
      await _chatsService.clearChatAlert(jid: chatJid);
    }
  }

  Future<void> _onChatSpamStatusRequested(
    ChatSpamStatusRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    final xmppService = _xmppService;
    if (xmppService == null) return;
    final spamTargetJid = chat.antiAbuseTargetAddress;
    if (spamTargetJid.isEmpty) {
      return;
    }
    try {
      await xmppService.setSpamStatus(
        jid: spamTargetJid,
        spam: event.sendToSpam,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeWarning('Failed to update spam status', error, stackTrace);
      emit(
        _attachToast(
          state,
          ChatToast(
            messageText: event.failureMessage,
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
      return;
    }
    emit(_attachToast(state, ChatToast(messageText: event.successMessage)));
  }

  Future<void> _onChatContactAddRequested(
    ChatContactAddRequested event,
    Emitter<ChatState> emit,
  ) async {
    final acceptedCompleter = event.acceptedCompleter;
    final chat = event.chat;
    final remoteJid = chat.remoteJid.trim();
    if (remoteJid.isEmpty) {
      acceptedCompleter?.complete(false);
      return;
    }
    final rosterTitle = chat.contactDisplayName?.trim().isNotEmpty == true
        ? chat.contactDisplayName!.trim()
        : chat.title;
    try {
      if (chat.defaultTransport.isEmail) {
        final emailService = _emailService;
        if (emailService == null) {
          acceptedCompleter?.complete(false);
          return;
        }
        await emailService.ensureChatForAddress(
          address: remoteJid,
          displayName: rosterTitle,
        );
      } else {
        final xmppService = _xmppService;
        if (xmppService == null) {
          acceptedCompleter?.complete(false);
          return;
        }
        await xmppService.addToRoster(
          jid: remoteJid,
          title: rosterTitle.isNotEmpty ? rosterTitle : null,
        );
      }
    } on EmailServiceException catch (error, stackTrace) {
      _log.safeWarning('Failed to add contact', error, stackTrace);
      emit(
        _attachToast(
          state,
          ChatToast(
            messageText: event.failureMessage,
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
      acceptedCompleter?.complete(false);
      return;
    } on Exception catch (error, stackTrace) {
      _log.safeWarning('Failed to add contact', error, stackTrace);
      emit(
        _attachToast(
          state,
          ChatToast(
            messageText: event.failureMessage,
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
      acceptedCompleter?.complete(false);
      return;
    }

    acceptedCompleter?.complete(true);
  }

  Future<void> _onChatRecipientEmailChatRequested(
    ChatRecipientEmailChatRequested event,
    Emitter<ChatState> emit,
  ) async {
    final emailService = _emailService;
    if (emailService == null) {
      emit(
        _attachToast(
          state,
          ChatToast(
            messageText: event.failureMessage,
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
      return;
    }
    try {
      final ensured = await emailService.ensureChatForEmailChat(
        event.recipient,
      );
      emit(
        state.copyWith(
          openChatJid: ensured.jid,
          openChatRequestId: state.openChatRequestId + 1,
        ),
      );
    } on EmailServiceException catch (error, stackTrace) {
      _log.safeWarning('Failed to create email chat', error, stackTrace);
      emit(
        _attachToast(
          state,
          ChatToast(
            messageText: event.failureMessage,
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.safeWarning('Failed to create email chat', error, stackTrace);
      emit(
        _attachToast(
          state,
          ChatToast(
            messageText: event.failureMessage,
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
    }
  }

  Future<void> _onChatMessagePinRequested(
    ChatMessagePinRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    final isEmailBacked =
        chat.defaultTransport.isEmail || event.message.isEmailBacked;
    if (isEmailBacked) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: ChatMessageKey.chatPinMessageUnavailable,
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
    final pinReference = event.message.pinId(
      isGroupChat: chat.type == ChatType.groupChat,
    );
    if (pinReference == null) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: ChatMessageKey.chatPinMessageUnavailable,
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
    if (chat.type == ChatType.groupChat) {
      final roomState = event.roomState;
      if (roomState == null) {
        emit(
          _attachToast(
            state,
            const ChatToast(
              message: ChatMessageKey.chatMembersLoading,
              variant: ChatToastVariant.warning,
            ),
          ),
        );
        return;
      }
      if (roomState.myRole.isVisitor || roomState.myRole.isNone) {
        emit(
          _attachToast(
            state,
            const ChatToast(
              message: ChatMessageKey.chatPinPermissionDenied,
              variant: ChatToastVariant.warning,
            ),
          ),
        );
        return;
      }
    }
    if (!_canMutatePinForMessage(
      message: event.message,
      chat: chat,
      roomState: event.roomState,
    )) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: ChatMessageKey.chatPinPermissionDenied,
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
    if (event.pin &&
        _isPinnedMessageInChat(chat: chat, messageReferenceId: pinReference)) {
      emit(
        _attachToast(
          state,
          const ChatToast(message: ChatMessageKey.chatMessageAlreadyPinned),
        ),
      );
      return;
    }
    final successMessage = event.pin
        ? ChatMessageKey.chatMessagePinned
        : ChatMessageKey.chatMessageUnpinned;
    try {
      if (event.pin) {
        await _messageService.pinMessage(
          chatJid: chat.remoteJid,
          message: event.message,
        );
      } else {
        await _messageService.unpinMessage(
          chatJid: chat.remoteJid,
          message: event.message,
        );
      }
      emit(_attachToast(state, ChatToast(message: successMessage)));
    } on XmppPinPermissionException catch (error, stackTrace) {
      _log.safeFine('Rejected unauthorized XMPP pin.', error, stackTrace);
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: ChatMessageKey.chatPinPermissionDenied,
            variant: ChatToastVariant.warning,
          ),
        ),
      );
    } on XmppPinAlreadyPinnedException catch (error, stackTrace) {
      _log.safeFine('Rejected duplicate XMPP pin.', error, stackTrace);
      emit(
        _attachToast(
          state,
          const ChatToast(message: ChatMessageKey.chatMessageAlreadyPinned),
        ),
      );
    } on XmppException catch (error, stackTrace) {
      _log.safeFine('Failed to update XMPP pin.', error, stackTrace);
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: ChatMessageKey.chatPinMessageUnavailable,
            variant: ChatToastVariant.warning,
          ),
        ),
      );
    }
  }

  Future<void> _onChatMessageCollectionMembershipChanged(
    ChatMessageCollectionMembershipChanged event,
    Emitter<ChatState> emit,
  ) async {
    final collectionId = event.collectionId.trim();
    final messageReference = event.message.collectionReference(
      isGroupChat: event.chat.type == ChatType.groupChat,
    );
    final messageReferenceId = messageReference == null
        ? ''
        : messageReference.value.trim();
    if (event.message.awaitsMucReference(
          isGroupChat: event.chat.type == ChatType.groupChat,
          isEmailBacked:
              event.chat.defaultTransport.isEmail ||
              event.message.isEmailBacked,
        ) ||
        collectionId.isEmpty ||
        event.chat.jid.trim().isEmpty ||
        messageReferenceId.isEmpty) {
      emit(
        state.copyWith(
          collectionActionState: ChatCollectionActionFailure(
            collectionId: collectionId,
            messageReferenceId: messageReferenceId,
            active: event.active,
            reason: ChatCollectionActionFailureReason.unsupported,
          ),
        ),
      );
      return;
    }
    final collectionActionState = state.collectionActionState;
    if (collectionActionState is ChatCollectionActionLoading &&
        collectionActionState.collectionId == collectionId &&
        collectionActionState.messageReferenceId == messageReferenceId &&
        collectionActionState.active == event.active) {
      return;
    }
    emit(
      state.copyWith(
        collectionActionState: ChatCollectionActionLoading(
          collectionId: collectionId,
          messageReferenceId: messageReferenceId,
          active: event.active,
        ),
      ),
    );
    try {
      final changed = await _messageService.setMessageCollectionMembership(
        collectionId: collectionId,
        chat: event.chat,
        message: event.message,
        active: event.active,
      );
      if (!changed) {
        emit(
          state.copyWith(
            collectionActionState: ChatCollectionActionFailure(
              collectionId: collectionId,
              messageReferenceId: messageReferenceId,
              active: event.active,
              reason: ChatCollectionActionFailureReason.updateFailed,
            ),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          collectionActionState: ChatCollectionActionSuccess(
            collectionId: collectionId,
            messageReferenceId: messageReferenceId,
            active: event.active,
          ),
        ),
      );
    } on XmppMessageException {
      emit(
        state.copyWith(
          collectionActionState: ChatCollectionActionFailure(
            collectionId: collectionId,
            messageReferenceId: messageReferenceId,
            active: event.active,
            reason: ChatCollectionActionFailureReason.updateFailed,
          ),
        ),
      );
    }
  }

  Future<void> _onChatMessageReactionToggled(
    ChatMessageReactionToggled event,
    Emitter<ChatState> emit,
  ) async {
    var success = false;
    try {
      final chat = state.chat;
      if (chat == null ||
          !event.message.canSendXmppReaction(
            chatDefaultTransport: chat.defaultTransport,
          )) {
        return;
      }
      if (event.message.awaitsMucReference(
        isGroupChat: chat.type == ChatType.groupChat,
        isEmailBacked:
            chat.defaultTransport.isEmail || event.message.isEmailBacked,
      )) {
        return;
      }
      success = chat.isAxichatWelcomeThread
          ? await _messageService.reactToMessageLocally(
              stanzaID: event.message.stanzaID,
              emoji: event.emoji,
            )
          : await _messageService.reactToMessage(
              stanzaID: event.message.stanzaID,
              emoji: event.emoji,
            );
    } on Exception catch (error, stackTrace) {
      _log.fine(_messageReactionFailedLogMessage, error, stackTrace);
    } finally {
      event.completer?.complete(success);
    }
  }

  Future<void> _onChatMessageForwardRequested(
    ChatMessageForwardRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    if (message.pseudoMessageType != null) {
      emit(
        _attachToast(
          state,
          const ChatToast(message: ChatMessageKey.chatForwardInviteForbidden),
        ),
      );
      return;
    }

    final rfcEmailGroup = await _loadRfcEmailActionGroupFor(message);
    final sourceMessage = rfcEmailGroup?.leader ?? message;
    final content = rfcEmailGroup == null
        ? _forwardDraftContent(message)
        : _forwardDraftContentForRfcEmailGroup(rfcEmailGroup);
    final attachmentMetadataIds = rfcEmailGroup == null
        ? await _attachmentMetadataIdsForForwardDraft(message)
        : await _attachmentMetadataIdsForRfcEmailForwardDraft(rfcEmailGroup);
    emit(
      state.copyWith(
        pendingForwardDraft: ChatForwardDraft(
          sources: [
            ChatForwardDraftSource(
              sourceMessageId: sourceMessage.stanzaID,
              senderJid: sourceMessage.senderJid,
              resolvedSenderLabel:
                  sourceMessage.resolveForwardedOriginalSenderLabel() ??
                  sourceMessage.senderJid,
              timestamp: sourceMessage.timestamp,
              originalSubject: content.subject,
              originalPlainTextBody: content.body,
              originalHtmlBody: content.htmlBody,
              attachmentMetadataIds: attachmentMetadataIds,
              quotedContext: _forwardedQuoteContext(sourceMessage),
            ),
          ],
        ),
      ),
    );
  }

  RfcEmailGroup? _rfcEmailActionGroupFor(Message message) {
    return _rfcEmailActionGroupForMessages(
      message: message,
      messages: state.items,
    );
  }

  Future<RfcEmailGroup?> _loadRfcEmailActionGroupFor(Message message) async {
    if (message.emailRfcGroupKey == null) {
      return null;
    }
    final messagesByStanzaId = <String, Message>{};
    for (final candidate in state.items) {
      if (candidate.emailRfcGroupKey == message.emailRfcGroupKey) {
        messagesByStanzaId[candidate.stanzaID] = candidate;
      }
    }
    final loadedMessages = await _messageService.loadEmailMessagesByRfcGroup(
      message,
    );
    for (final candidate in loadedMessages) {
      if (candidate.emailRfcGroupKey == message.emailRfcGroupKey) {
        messagesByStanzaId[candidate.stanzaID] = candidate;
      }
    }
    return _rfcEmailActionGroupForMessages(
      message: message,
      messages: messagesByStanzaId.values,
    );
  }

  RfcEmailGroup? _rfcEmailActionGroupForMessages({
    required Message message,
    required Iterable<Message> messages,
  }) {
    final groupsByStanzaId = buildRfcEmailGroupsByMessageStanzaId(
      messages: messages.toList(growable: false),
      attachmentsForMessage: _stateAttachmentMetadataIdsForMessage,
      bodyTextForMessage: _rfcEmailMessagePlainBody,
      isAuthoritativeBody: (message) => message.hasRfc822BodyContent,
      requireMeaningfulBody: false,
    );
    return groupsByStanzaId[message.stanzaID];
  }

  List<String> _stateAttachmentMetadataIdsForMessage(Message message) {
    final stateIds =
        state.attachmentMetadataIdsByMessageId[_messageKey(message)];
    if (stateIds != null && stateIds.isNotEmpty) {
      return _trimmedUniqueMetadataIds(stateIds);
    }
    final fallbackId = message.fileMetadataID?.trim();
    if (fallbackId == null || fallbackId.isEmpty) {
      return const <String>[];
    }
    return [fallbackId];
  }

  String? _resolvedEmailHtmlBodyForMessage(Message message) {
    return resolvedEmailHtmlBodyForMessage(
      message: message,
      emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
      deriveHtmlIfMissing: false,
    );
  }

  String _rfcEmailMessagePlainBody(Message message) => rfcEmailBodyText(
    message: message,
    resolvedHtmlBody: _resolvedEmailHtmlBodyForMessage(message),
    deriveHtmlIfMissing: false,
  );

  String _rfcEmailGroupPlainBody(RfcEmailGroup group) {
    return group.bodySources
        .map(_rfcEmailMessagePlainBody)
        .map((body) => body.trim())
        .where((body) => body.isNotEmpty)
        .join('\n\n');
  }

  String? _singleRfcEmailGroupHtmlBody(RfcEmailGroup group) {
    final htmlBodies = group.bodySources
        .map(_resolvedEmailHtmlBodyForMessage)
        .map(HtmlContentCodec.normalizeHtml)
        .whereType<String>()
        .toList(growable: false);
    if (htmlBodies.length != 1) {
      return null;
    }
    return htmlBodies.single;
  }

  ({String? subject, String body, String? htmlBody})
  _forwardDraftContentForRfcEmailGroup(RfcEmailGroup group) {
    final leaderContent = _forwardDraftContent(group.leader);
    return (
      subject: leaderContent.subject,
      body: _rfcEmailGroupPlainBody(group),
      htmlBody: _singleRfcEmailGroupHtmlBody(group),
    );
  }

  Future<List<String>> _attachmentMetadataIdsForRfcEmailForwardDraft(
    RfcEmailGroup group,
  ) async {
    final metadataIds = <String>[];
    for (final message in group.messages) {
      metadataIds.addAll(await _attachmentMetadataIdsForForwardDraft(message));
    }
    return _trimmedUniqueMetadataIds(metadataIds);
  }

  DraftForwardedQuoteContext? _forwardedQuoteContext(Message message) {
    final quotedReference = message.storedReplyId;
    if (quotedReference == null || quotedReference.isEmpty) {
      return null;
    }
    final quotedMessage = state.quotedMessagesById[quotedReference];
    if (quotedMessage == null) {
      return null;
    }
    final plainText = quotedMessage.isEmailBacked
        ? ChatSubjectCodec.previewEmailText(
            body: quotedMessage.body,
            subject: quotedMessage.subject,
          )
        : ChatSubjectCodec.previewText(
            body: quotedMessage.body,
            subject: quotedMessage.subject,
          );
    final normalizedPlainText = plainText?.trim();
    if (normalizedPlainText == null || normalizedPlainText.isEmpty) {
      return null;
    }
    final senderLabel = _forwardedQuoteSenderLabel(quotedMessage);
    if (senderLabel.isEmpty) {
      return null;
    }
    return DraftForwardedQuoteContext(
      senderLabel: senderLabel,
      plainText: normalizedPlainText,
    );
  }

  String _forwardedQuoteSenderLabel(Message quotedMessage) {
    if (state.chat?.type == ChatType.groupChat) {
      final nick = state.roomState?.senderNick(quotedMessage.senderJid);
      if (nick != null && nick.trim().isNotEmpty) {
        return nick.trim();
      }
    }
    return quotedMessage.senderJid.trim();
  }

  void _onChatForwardDraftConsumed(
    ChatForwardDraftConsumed event,
    Emitter<ChatState> emit,
  ) {
    if (state.pendingForwardDraft == null) return;
    emit(state.copyWith(pendingForwardDraft: null));
  }

  ({String? subject, String body, String? htmlBody}) _forwardDraftContent(
    Message message,
  ) {
    final isEmailMessage =
        message.deltaChatId != null || message.deltaMsgId != null;
    final display = isEmailMessage
        ? ChatSubjectCodec.splitEmailBody(
            body: message.body,
            subject: message.subject,
          )
        : ChatSubjectCodec.splitDisplayBody(
            body: message.body,
            subject: message.subject,
          );
    final renderedText = display.body.trim();
    final originalSubject = display.subject?.trim();
    var originalBody = renderedText;
    if (isEmailMessage &&
        message.hasRfc822BodyContent &&
        HtmlContentCodec.looksLikeCssBodyText(originalBody)) {
      originalBody = rfcEmailBodyText(
        message: message,
        resolvedHtmlBody: _resolvedEmailHtmlBodyForMessage(message),
      );
    }
    if (originalBody.isEmpty) {
      final normalizedHtml = HtmlContentCodec.normalizeHtml(
        _resolvedEmailHtmlBodyForMessage(message),
      );
      if (normalizedHtml != null) {
        originalBody = emailHtmlVisibleBodyText(normalizedHtml);
        if (originalSubject != null && originalSubject.isNotEmpty) {
          originalBody = ChatSubjectCodec.stripRepeatedSubject(
            body: originalBody,
            subject: originalSubject,
          ).trim();
        }
      }
    }
    final htmlBody = HtmlContentCodec.normalizeHtml(
      _resolvedEmailHtmlBodyForMessage(message),
    );
    final htmlDerivation = htmlBody == null
        ? null
        : HtmlContentCodec.emailDerivations(htmlBody);
    final shouldForwardHtml =
        isEmailMessage &&
        htmlDerivation != null &&
        HtmlContentCodec.shouldRenderRichEmailHtml(
          normalizedHtmlBody: htmlBody,
          normalizedHtmlText: htmlDerivation.visibleBodyText,
          renderedText: renderedText,
          derivation: htmlDerivation,
        );
    return (
      subject: originalSubject == null || originalSubject.isEmpty
          ? null
          : originalSubject,
      body: originalBody,
      htmlBody: shouldForwardHtml ? htmlBody : null,
    );
  }

  Future<List<String>> _attachmentMetadataIdsForForwardDraft(
    Message message,
  ) async {
    final stateIds =
        state.attachmentMetadataIdsByMessageId[_messageKey(message)];
    if (stateIds != null && stateIds.isNotEmpty) {
      return _trimmedUniqueMetadataIds(stateIds);
    }
    final metadataIds = <String>[];
    final messageId = message.id;
    if (messageId != null && messageId.isNotEmpty) {
      var attachments = await _messageService.loadMessageAttachments(messageId);
      if (attachments.isNotEmpty) {
        final transportGroupId = attachments.first.transportGroupId?.trim();
        if (transportGroupId != null && transportGroupId.isNotEmpty) {
          attachments = await _messageService.loadMessageAttachmentsForGroup(
            transportGroupId,
          );
        }
        final ordered = List<MessageAttachmentData>.from(attachments)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        for (final attachment in ordered) {
          metadataIds.add(attachment.fileMetadataId);
        }
      }
    }
    if (metadataIds.isEmpty) {
      final fallbackId = message.fileMetadataID;
      if (fallbackId != null && fallbackId.isNotEmpty) {
        metadataIds.add(fallbackId);
      }
    }
    return _trimmedUniqueMetadataIds(metadataIds);
  }

  List<String> _trimmedUniqueMetadataIds(Iterable<String> ids) {
    final uniqueIds = <String>{};
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      uniqueIds.add(trimmed);
    }
    return uniqueIds.toList(growable: false);
  }

  Future<void> _onChatMessageResendRequested(
    ChatMessageResendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    final chatType = event.chatType;
    final resendMessageId = message.stanzaID.trim();
    if (state.isMessageResendLoading(resendMessageId)) return;
    final pseudoMessageType = message.pseudoMessageType;
    final isEmailMessage = message.deltaChatId != null;
    final isLocalOnlyChat = isAxichatWelcomeThreadJid(message.chatJid);
    final shouldMarkManualSendAgain = message
        .isStaleUnackedXmppSendAgainCandidate(
          isSelf: state.chat == null
              ? false
              : _isSelfMessageForSendAgain(message, state.chat!),
          isEmailChat: state.chat?.defaultTransport.isEmail == true,
          staleBefore: _staleUnackedSendAgainCutoff,
        );
    String? manualSendAgainStanzaId;
    void captureManualSendAgainStanzaId(String stanzaId) {
      final normalizedStanzaId = stanzaId.trim();
      if (manualSendAgainStanzaId == null && normalizedStanzaId.isNotEmpty) {
        manualSendAgainStanzaId = normalizedStanzaId;
      }
    }

    var resendCompleted = false;
    var manualSendAgainMarked = false;

    Future<void> performResend() async {
      if (isEmailMessage) {
        resendCompleted = await _resendEmailMessage(message, emit);
        return;
      }
      if (pseudoMessageType?.isInvite == true) {
        await _mucService.resendInvitePseudoMessage(
          message,
          onLocalMessageStored: shouldMarkManualSendAgain
              ? captureManualSendAgainStanzaId
              : null,
        );
        resendCompleted = true;
        return;
      }
      final attachments = await _attachmentsForMessage(message);
      if (attachments.isNotEmpty) {
        final storedQuotedStanzaId = _storedReplyId(message);
        Message? quoted;
        if (storedQuotedStanzaId != null) {
          quoted = await _messageService.loadMessageByReferenceId(
            storedQuotedStanzaId,
            chatJid: message.chatJid,
          );
        }
        final caption = message.plainText.trim();
        final htmlCaption = message.normalizedHtmlBody;
        final attachmentGroupId = attachments.length > 1 ? uuid.v4() : null;
        final resolvedQuotedStanzaId = quoted == null
            ? storedQuotedStanzaId
            : quoted.replyId(isGroupChat: chatType == ChatType.groupChat);
        final groupQuotedStanzaId =
            attachmentGroupId == null || resolvedQuotedStanzaId == null
            ? null
            : resolvedQuotedStanzaId;
        for (var index = 0; index < attachments.length; index += 1) {
          final attachment = attachments[index];
          final shouldApplyCaption = caption.isNotEmpty && index == 0;
          final resolvedAttachment = shouldApplyCaption
              ? attachment.copyWith(caption: caption)
              : attachment;
          if (isLocalOnlyChat) {
            await _messageService.sendLocalOnlyAttachment(
              jid: message.chatJid,
              attachment: resolvedAttachment,
              encryptionProtocol: message.encryptionProtocol,
              quotedMessage: index == 0 ? quoted : null,
              quotedStanzaId: index == 0 ? resolvedQuotedStanzaId : null,
              groupQuotedStanzaId: groupQuotedStanzaId,
              chatType: chatType,
              htmlCaption: shouldApplyCaption ? htmlCaption : null,
              forwarded: message.isForwarded,
              forwardedFromJid: message.forwardedFromJid,
              forwardedOriginalSenderLabel:
                  message.forwardedOriginalSenderLabel,
              transportGroupId: attachmentGroupId,
              attachmentOrder: index,
              onLocalMessageStored: shouldMarkManualSendAgain
                  ? captureManualSendAgainStanzaId
                  : null,
            );
          } else {
            await _messageService.sendAttachment(
              jid: message.chatJid,
              attachment: resolvedAttachment,
              encryptionProtocol: message.encryptionProtocol,
              quotedMessage: index == 0 ? quoted : null,
              quotedStanzaId: index == 0 ? resolvedQuotedStanzaId : null,
              groupQuotedStanzaId: groupQuotedStanzaId,
              chatType: chatType,
              htmlCaption: shouldApplyCaption ? htmlCaption : null,
              forwarded: message.isForwarded,
              forwardedFromJid: message.forwardedFromJid,
              forwardedOriginalSenderLabel:
                  message.forwardedOriginalSenderLabel,
              transportGroupId: attachmentGroupId,
              attachmentOrder: index,
              onLocalMessageStored: shouldMarkManualSendAgain
                  ? captureManualSendAgainStanzaId
                  : null,
            );
          }
        }
        resendCompleted = true;
        return;
      }
      final hasBody =
          message.plainText.isNotEmpty || message.normalizedHtmlBody != null;
      if (!hasBody) return;
      if (isLocalOnlyChat) {
        final CalendarFragment? fragment = message.calendarFragment;
        final CalendarTask? taskIcs = message.calendarTaskIcs;
        final bool taskIcsReadOnly = message.calendarTaskIcsReadOnly;
        final CalendarAvailabilityMessage? availabilityMessage =
            message.calendarAvailabilityMessage;
        Message? quoted;
        final storedReplyId = _storedReplyId(message);
        if (storedReplyId != null) {
          quoted = await _messageService.loadMessageByReferenceId(
            storedReplyId,
            chatJid: message.chatJid,
          );
        }
        await _messageService.sendLocalOnlyMessage(
          jid: message.chatJid,
          text: message.plainText,
          htmlBody: message.normalizedHtmlBody,
          encryptionProtocol: message.encryptionProtocol,
          quotedMessage: quoted,
          calendarFragment: fragment,
          calendarTaskIcs: taskIcs,
          calendarTaskIcsReadOnly: taskIcsReadOnly,
          calendarAvailabilityMessage: availabilityMessage,
          forwarded: message.isForwarded,
          forwardedFromJid: message.forwardedFromJid,
          forwardedOriginalSenderLabel: message.forwardedOriginalSenderLabel,
          chatType: chatType,
          onLocalMessageStored: shouldMarkManualSendAgain
              ? captureManualSendAgainStanzaId
              : null,
        );
        resendCompleted = true;
      } else {
        if (shouldMarkManualSendAgain) {
          resendCompleted = await _messageService.resendMessage(
            message.stanzaID,
            chatType: chatType,
            onLocalMessageStored: captureManualSendAgainStanzaId,
          );
        } else {
          resendCompleted = await _messageService.resendMessage(
            message.stanzaID,
            chatType: chatType,
          );
        }
      }
    }

    try {
      if (resendMessageId.isNotEmpty) {
        emit(state.markMessageResendLoading(resendMessageId));
      }
      await performResend();
    } on Exception catch (error, stackTrace) {
      _log.warning(_messageResendFailedLogMessage, error, stackTrace);
    } finally {
      if (shouldMarkManualSendAgain && resendCompleted) {
        final sendAgainStanzaId = manualSendAgainStanzaId;
        if (sendAgainStanzaId != null) {
          try {
            await _messageService.markMessageManualSendAgain(
              stanzaID: message.stanzaID,
              sendAgainStanzaID: sendAgainStanzaId,
            );
            manualSendAgainMarked = true;
          } on Exception catch (error, stackTrace) {
            _log.warning(_messageResendFailedLogMessage, error, stackTrace);
          }
        }
      }
      if (resendMessageId.isNotEmpty) {
        emit(state.clearMessageResendLoading(resendMessageId));
      }
      if (resendCompleted &&
          (!shouldMarkManualSendAgain || manualSendAgainMarked)) {
        emit(
          _attachToast(
            state,
            const ChatToast(message: ChatMessageKey.chatMessageSentAgain),
          ),
        );
      }
    }
  }

  Future<void> _onChatMessageEditRequested(
    ChatMessageEditRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    if (message.deltaChatId != null) {
      final attachments = await _rehydrateEmailDraft(message, emit);
      event.attachmentsCompleter?.complete(attachments);
    } else {
      final attachments = await _rehydrateXmppDraft(message, emit);
      event.attachmentsCompleter?.complete(attachments);
    }
  }

  void _onChatComposerErrorCleared(
    ChatComposerErrorCleared event,
    Emitter<ChatState> emit,
  ) {
    if (state.composerError == null) return;
    emit(state.copyWith(composerError: null));
  }

  Future<void> _onChatAttachmentPicked(
    ChatAttachmentPicked event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    if (event.recipients.isEmpty) {
      event.completer.complete(null);
      return;
    }
    final forceEmail = _shouldForceEmailForSend(chat: chat);
    final split = _splitRecipientsForSend(
      chat: chat,
      recipients: event.recipients,
      forceEmail: forceEmail,
    );
    final requiresXmpp = split.xmppRecipients.isNotEmpty;
    final canPickAttachmentForEmailOverride =
        state.canOfferEmailOutboundOverride &&
        chat.supportsAxiEmailOutboundOverride;
    final shouldUseEmail =
        forceEmail ||
        _shouldSendAttachmentsViaEmail(
          chat: chat,
          recipients: event.recipients,
        );
    final service = _emailService;
    if (shouldUseEmail && service == null) {
      event.completer.complete(null);
      return;
    }
    if (shouldUseEmail &&
        !_hasEmailTarget(
          chat: chat,
          recipients: event.recipients,
          forceEmail: forceEmail,
        )) {
      const message =
          ChatMessageKey.chatComposerEmailAttachmentRecipientRequired;
      emit(
        _attachToast(
          state.copyWith(composerError: message),
          ChatToast(message: message, variant: ChatToastVariant.warning),
        ),
      );
      event.completer.complete(null);
      return;
    }
    final pendingId = event.pendingId;
    final uploadLimitBytes = requiresXmpp && !canPickAttachmentForEmailOverride
        ? _messageService.httpUploadSupport.maxFileSizeBytes
        : null;
    final ComposerAttachmentStage staged;
    try {
      staged = await stageComposerAttachment(
        source: event.source,
        sessionId: event.composerSessionId,
        fallbackId: pendingId,
        maxSizeBytes: uploadLimitBytes,
      );
    } on ComposerAttachmentTooLargeException {
      var sizeBytes = 0;
      try {
        sizeBytes = await event.source.loadSizeBytes();
      } on AttachmentImportException {
        sizeBytes = 0;
      } on FileSystemException {
        sizeBytes = 0;
      }
      const message = ChatMessageKey.messageErrorFileUploadFailure;
      final pending = PendingAttachment(
        id: pendingId,
        attachment: Attachment(
          path: event.source.path,
          fileName: event.source.fileName,
          sizeBytes: sizeBytes,
          mimeType: event.source.mimeType,
        ),
        status: PendingAttachmentStatus.failed,
        errorMessage: message,
      );
      emit(state.copyWith(composerError: message));
      event.completer.complete(pending);
      return;
    } on ComposerAttachmentStagingException catch (error, stackTrace) {
      _log.fine('Failed to stage attachment', error, stackTrace);
      const message = ChatMessageKey.messageErrorFileUploadFailure;
      emit(state.copyWith(composerError: message));
      event.completer.complete(null);
      return;
    }
    var pending = PendingAttachment(
      id: pendingId,
      attachment: staged.attachment.copyWith(metadataId: pendingId),
      stagedAttachment: staged.staged,
    );
    event.completer.complete(pending.copyWith(isPreparing: false));
  }

  Future<void> _onChatPendingAttachmentMetadataDiscarded(
    ChatPendingAttachmentMetadataDiscarded event,
    Emitter<ChatState> emit,
  ) async {
    final metadataId = event.metadataId.trim();
    if (metadataId.isEmpty) {
      return;
    }
    try {
      await _messageService.deleteFileMetadata(metadataId);
    } on XmppException catch (error, stackTrace) {
      _log.safeWarning(
        'Failed to discard pending attachment metadata',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _onChatDemoPendingAttachmentsRequested(
    ChatDemoPendingAttachmentsRequested event,
    Emitter<ChatState> emit,
  ) async {
    final attachments = await _demoPendingAttachmentsForChat(
      chat: event.chat,
      existingFileNames: {...event.existingFileNames},
    );
    event.completer.complete(attachments);
  }

  Future<void> _onChatAttachmentRetryRequested(
    ChatAttachmentRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final pending = event.attachment;
    final chat = event.chat;
    if (pending.status != PendingAttachmentStatus.failed) {
      event.completer.complete(pending);
      return;
    }
    if (event.recipients.isEmpty) {
      event.completer.complete(pending);
      return;
    }
    final forceEmail = _shouldForceEmailForSend(chat: chat);
    final split = _splitRecipientsForSend(
      chat: chat,
      recipients: event.recipients,
      forceEmail: forceEmail,
    );
    final emailRecipients = split.emailRecipients;
    final xmppRecipients = split.xmppRecipients;
    final requiresEmail = emailRecipients.isNotEmpty;
    final requiresXmpp = xmppRecipients.isNotEmpty;
    if (requiresEmail && state.emailSyncState.requiresAttention) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: ChatMessageKey.chatEmailOfflineRetryMessage,
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      event.completer.complete(pending);
      return;
    }
    final service = _emailService;
    if (requiresEmail && service == null) {
      event.completer.complete(pending);
      return;
    }
    final pendingAttachments = <PendingAttachment>[
      pending.copyWith(
        status: PendingAttachmentStatus.queued,
        clearErrorMessage: true,
      ),
    ];
    final updated = pendingAttachments.single;
    Future<void> completeWithCurrentPendingAttachments() async {
      final reconciled = await _reconcileCommittedPendingAttachments(
        pendingAttachments,
      );
      await _deleteReleasedComposerStagedAttachments(
        submitted: [pending],
        retained: reconciled,
      );
      if (!event.completer.isCompleted) {
        event.completer.complete(reconciled.isEmpty ? null : reconciled.single);
      }
    }

    if (requiresEmail) {
      final EmailService emailService = service!;
      final emailResult = await _sendEmailAttachment(
        pending: updated,
        pendingAttachments: pendingAttachments,
        chat: chat,
        service: emailService,
        recipients: emailRecipients,
        emit: emit,
        subject: event.subject,
        quotedDraft: event.quotedDraft,
        settings: event.settings,
        retainOnSuccess: requiresXmpp,
      );
      if (!emailResult.succeeded || !requiresXmpp) {
        await completeWithCurrentPendingAttachments();
        return;
      }
    }
    if (!requiresXmpp) {
      await completeWithCurrentPendingAttachments();
      return;
    }
    final _ChatXmppSendResult result;
    try {
      result = await _sendXmppAttachments(
        attachments: [updated],
        pendingAttachments: pendingAttachments,
        chat: chat,
        recipients: xmppRecipients,
        emit: emit,
        supportsHttpFileUpload: event.supportsHttpFileUpload,
        subject: event.subject,
        quotedDraft: event.quotedDraft,
      );
    } on XmppMessageException catch (error, stackTrace) {
      final message = _xmppAttachmentFailureMessage(error);
      _markPendingAttachmentFailedInList(
        pendingAttachments,
        updated.id,
        message: message,
      );
      emit(state.copyWith(composerError: message));
      if (_shouldLogXmppAttachmentFailure(error)) {
        _log.safeWarning(
          _xmppAttachmentSendFailedLogMessage,
          error,
          stackTrace,
        );
      }
      await completeWithCurrentPendingAttachments();
      return;
    }
    await completeWithCurrentPendingAttachments();
    if (result.hasFailures) {
      return;
    }
  }

  Future<void> _onChatViewFilterChanged(
    ChatViewFilterChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    _clearPendingUnreadDividerEmailContentMessages();
    const forcedFilter = MessageTimelineFilter.allWithContact;
    final effectiveFilter = _forceAllWithContactViewFilter
        ? forcedFilter
        : event.filter;
    await _applyViewFilter(
      effectiveFilter,
      emit: emit,
      persist: event.persist,
      chatJid: chatJid,
    );
  }

  Future<void> _onFanOutRetryRequested(
    ChatFanOutRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (state.emailSyncState.requiresAttention) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: ChatMessageKey.chatEmailOfflineRetryMessage,
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
    final draft = event.draft;
    if (event.recipients.isEmpty) return;
    await _sendFanOut(
      recipients: event.recipients,
      text: draft.body,
      attachment: draft.attachment,
      shareId: draft.shareId,
      subject: draft.subject,
      quotedStanzaId: draft.quotedStanzaId,
      chat: event.chat,
      settings: event.settings,
      emit: emit,
    );
  }

  void _onChatSubjectChanged(
    ChatSubjectChanged event,
    Emitter<ChatState> emit,
  ) {
    if (state.emailSubject == event.subject) {
      return;
    }
    emit(
      state.copyWith(
        emailSubject: event.subject,
        emailSubjectAutofilled: false,
        emailSubjectAutofillEligible: false,
      ),
    );
  }

  Future<void> _stopTyping({required Chat chat}) async {
    _typingTimer?.cancel();
    _typingTimer = null;
    if (_xmppAllowedForChat(chat)) {
      await _chatsService.sendTyping(jid: chat.jid, typing: false);
    }
  }

  List<ComposerRecipient> _emailRecipientsForNextSendUnit({
    required List<ComposerRecipient> recipients,
    required ComposerSendProgress progress,
  }) {
    final outcomes = progress.outcomes;
    final hasAttemptedEmailUnit = recipients.any(
      (recipient) =>
          outcomes[recipient.recipientKey] != SendRecipientOutcome.notAttempted,
    );
    if (!hasAttemptedEmailUnit) {
      return recipients;
    }
    return recipients
        .where(
          (recipient) =>
              outcomes[recipient.recipientKey] ==
              SendRecipientOutcome.completed,
        )
        .toList(growable: false);
  }

  void _applyEmailSendUnitResult({
    required ComposerSendProgress progress,
    required List<ComposerRecipient> recipients,
    required _ChatEmailSendUnitResult result,
  }) {
    if (result.recipientStatuses.isEmpty) {
      if (result.succeeded) {
        progress.markCompletedAll(
          recipients.map((recipient) => recipient.recipientKey),
        );
      } else {
        progress.markFailedAll(
          recipients.map((recipient) => recipient.recipientKey),
        );
      }
      return;
    }
    for (final recipient in recipients) {
      final status = result.recipientStatuses[recipient.recipientKey];
      if (status == FanOutRecipientState.sent) {
        progress.markCompleted(recipient.recipientKey);
      } else {
        progress.markFailed(recipient.recipientKey);
      }
    }
  }

  Future<_ChatEmailSendUnitResult> _sendEmailAttachment({
    required PendingAttachment pending,
    required List<PendingAttachment> pendingAttachments,
    required Chat chat,
    required EmailService service,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
    required String? subject,
    required Message? quotedDraft,
    required ChatSettingsSnapshot settings,
    bool retainOnSuccess = false,
    String? htmlCaption,
  }) async {
    var current = pending;
    if (current.status != PendingAttachmentStatus.uploading) {
      current = current.copyWith(
        status: PendingAttachmentStatus.uploading,
        clearErrorMessage: true,
      );
      _replacePendingAttachmentInList(pendingAttachments, current);
    }
    var captionText = current.attachment.caption?.trim() ?? '';
    if (captionText.isEmpty && htmlCaption?.trim().isNotEmpty == true) {
      captionText = HtmlContentCodec.toPlainText(htmlCaption!);
    }
    if (_shouldFanOut(recipients, chat)) {
      final syntheticAttachmentReply = service.syntheticEmailReplyEnvelope(
        body: captionText,
        subject: subject,
        quotedDraft: quotedDraft,
      );
      final effectiveSubject = syntheticAttachmentReply?.subject ?? subject;
      final effectiveHtmlCaption =
          syntheticAttachmentReply?.htmlBody ?? htmlCaption;
      final effectiveAttachment = syntheticAttachmentReply == null
          ? current.attachment
          : current.attachment.copyWith(
              caption: syntheticAttachmentReply.body.isEmpty
                  ? null
                  : syntheticAttachmentReply.body,
            );
      final result = await _sendFanOut(
        recipients: recipients,
        attachment: effectiveAttachment,
        htmlCaption: effectiveHtmlCaption,
        subject: effectiveSubject,
        quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
        chat: chat,
        settings: settings,
        emit: emit,
      );
      if (result.succeeded) {
        _handlePendingAttachmentSuccessInList(
          pendingAttachments,
          current,
          retainOnSuccess: retainOnSuccess,
        );
        return result;
      } else {
        _markPendingAttachmentFailedInList(
          pendingAttachments,
          current.id,
          message:
              state.composerError ?? ChatMessageKey.chatAttachmentSendFailed,
        );
      }
      return result;
    }
    try {
      await service.sendAttachment(
        chat: chat,
        attachment: current.attachment,
        subject: subject,
        htmlCaption: htmlCaption,
        quotedDraft: quotedDraft,
      );
      _handlePendingAttachmentSuccessInList(
        pendingAttachments,
        current,
        retainOnSuccess: retainOnSuccess,
      );
      return const _ChatEmailSendUnitResult(succeeded: true);
    } on DeltaChatException catch (error, stackTrace) {
      _log.safeWarning(_attachmentSendFailedLogMessage, error, stackTrace);
      final mappedError = DeltaErrorMapper.resolve(error.message);
      final readableMessage = _chatMessageKeyForMessageError(mappedError);
      _markPendingAttachmentFailedInList(
        pendingAttachments,
        current.id,
        message: readableMessage,
      );
      emit(state.copyWith(composerError: readableMessage));
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.safeWarning(_attachmentSendFailedLogMessage, error, stackTrace);
      _markPendingAttachmentFailedInList(
        pendingAttachments,
        current.id,
        message: ChatMessageKey.chatComposerEmailUnavailable,
      );
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerEmailUnavailable,
        ),
      );
    } on EmailServiceException catch (error, stackTrace) {
      _log.safeWarning(_attachmentSendFailedLogMessage, error, stackTrace);
      _markPendingAttachmentFailedInList(
        pendingAttachments,
        current.id,
        message: ChatMessageKey.chatAttachmentSendFailed,
      );
      emit(
        state.copyWith(composerError: ChatMessageKey.chatAttachmentSendFailed),
      );
    }
    return const _ChatEmailSendUnitResult(succeeded: false);
  }

  Future<Attachment> _buildCalendarTaskIcsAttachment(CalendarTask task) async {
    const CalendarTransferService transferService = CalendarTransferService();
    final File file = await transferService.exportTaskIcs(task: task);
    CalendarTransferService.scheduleCleanup(file);
    final int sizeBytes = await file.length();
    final String fileName = p.basename(file.path);
    return Attachment(
      path: file.path,
      fileName: fileName,
      sizeBytes: sizeBytes,
      mimeType: _calendarTaskIcsAttachmentMimeType,
    );
  }

  Future<_ChatEmailSendUnitResult> _sendCalendarTaskEmailAttachment({
    required CalendarTask task,
    required bool taskReadOnly,
    required Chat chat,
    required EmailService service,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
    required String? subject,
    required Message? quotedDraft,
    required ChatSettingsSnapshot settings,
    String? caption,
    String? htmlCaption,
  }) async {
    if (kEnableDemoChats && _messageService.demoOfflineMode) {
      final sent = await _sendDemoCalendarTaskShare(
        task: task,
        taskReadOnly: taskReadOnly,
        chat: chat,
        recipients: recipients,
        caption: caption,
      );
      if (!sent) {
        emit(
          state.copyWith(
            composerError: ChatMessageKey.calendarTaskShareSendFailed,
          ),
        );
        return const _ChatEmailSendUnitResult(succeeded: false);
      }
      return const _ChatEmailSendUnitResult(succeeded: true);
    }
    final Attachment attachment = await _buildCalendarTaskIcsAttachment(task);
    if (_shouldFanOut(recipients, chat)) {
      final syntheticAttachmentReply = service.syntheticEmailReplyEnvelope(
        body: caption ?? '',
        subject: subject,
        quotedDraft: quotedDraft,
      );
      final Attachment resolvedAttachment = syntheticAttachmentReply == null
          ? (caption == null
                ? attachment
                : attachment.copyWith(caption: caption))
          : attachment.copyWith(
              caption: syntheticAttachmentReply.body.isEmpty
                  ? null
                  : syntheticAttachmentReply.body,
            );
      final effectiveSubject = syntheticAttachmentReply?.subject ?? subject;
      final effectiveHtmlCaption =
          syntheticAttachmentReply?.htmlBody ?? htmlCaption;
      final result = await _sendFanOut(
        recipients: recipients,
        attachment: resolvedAttachment,
        htmlCaption: effectiveHtmlCaption,
        subject: effectiveSubject,
        quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
        chat: chat,
        settings: settings,
        emit: emit,
      );
      if (!result.succeeded) {
        return result;
      }
      return result;
    }
    try {
      await service.sendAttachment(
        chat: chat,
        attachment: caption == null
            ? attachment
            : attachment.copyWith(caption: caption),
        subject: subject,
        htmlCaption: htmlCaption,
        quotedDraft: quotedDraft,
      );
      return const _ChatEmailSendUnitResult(succeeded: true);
    } on DeltaChatException catch (error, stackTrace) {
      _log.warning(
        _calendarTaskIcsAttachmentSendFailureLogMessage,
        error,
        stackTrace,
      );
      final mappedError = DeltaErrorMapper.resolve(error.message);
      final readableMessage = _chatMessageKeyForMessageError(mappedError);
      emit(state.copyWith(composerError: readableMessage));
      return const _ChatEmailSendUnitResult(succeeded: false);
    }
  }

  Future<bool> _sendDemoCalendarTaskShare({
    required CalendarTask task,
    required bool taskReadOnly,
    required Chat chat,
    required List<ComposerRecipient> recipients,
    String? caption,
  }) async {
    final resolvedCaption = caption?.trim() ?? '';
    final processed = <String>{};
    for (final recipient in recipients) {
      final targetJid = recipient.recipientId;
      if (targetJid == null || targetJid.isEmpty) {
        continue;
      }
      if (!processed.add(targetJid)) {
        continue;
      }
      await _messageService.sendMessage(
        jid: targetJid,
        text: resolvedCaption,
        encryptionProtocol: recipient.target.hasBackingChat
            ? recipient.target.encryptionProtocol
            : chat.encryptionProtocol,
        calendarTaskIcs: task,
        calendarTaskIcsReadOnly: taskReadOnly,
        chatType: recipient.target.hasBackingChat
            ? recipient.target.chatType
            : chat.type,
      );
    }
    return processed.isNotEmpty;
  }

  Future<Attachment> _bundlePendingAttachments({
    required List<PendingAttachment> attachments,
    required String? caption,
  }) async {
    return EmailAttachmentBundler.bundle(
      attachments: attachments.map((pending) => pending.attachment),
      caption: caption,
    );
  }

  Future<List<Attachment>> _bundleEmailAttachmentList({
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

  Future<bool> _sendQueuedAttachments({
    required Iterable<PendingAttachment> attachments,
    required List<PendingAttachment> pendingAttachments,
    required Chat chat,
    required EmailService service,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
    required String? subject,
    required Message? quotedDraft,
    required ChatSettingsSnapshot settings,
    bool retainOnSuccess = false,
    String? captionForFirstAttachment,
    String? htmlCaptionForFirstAttachment,
    ComposerSendProgress? progress,
    bool hasFollowingEmailUnits = false,
  }) async {
    final orderedAttachments = attachments.toList(growable: false);
    for (var index = 0; index < orderedAttachments.length; index += 1) {
      final unitRecipients = progress == null
          ? recipients
          : _emailRecipientsForNextSendUnit(
              recipients: recipients,
              progress: progress,
            );
      if (unitRecipients.isEmpty) {
        return false;
      }
      final attachment = orderedAttachments[index];
      final shouldApplyCaption =
          captionForFirstAttachment != null && index == 0;
      final shouldApplyHtmlCaption =
          htmlCaptionForFirstAttachment != null && index == 0;
      final pendingWithCaption = shouldApplyCaption
          ? attachment.copyWith(
              attachment: attachment.attachment.copyWith(
                caption: captionForFirstAttachment,
              ),
            )
          : attachment;
      final result = await _sendEmailAttachment(
        pending: pendingWithCaption,
        pendingAttachments: pendingAttachments,
        chat: chat,
        service: service,
        recipients: unitRecipients,
        emit: emit,
        subject: subject,
        quotedDraft: quotedDraft,
        settings: settings,
        retainOnSuccess: retainOnSuccess,
        htmlCaption: shouldApplyHtmlCaption
            ? htmlCaptionForFirstAttachment
            : null,
      );
      if (progress != null) {
        _applyEmailSendUnitResult(
          progress: progress,
          recipients: unitRecipients,
          result: result,
        );
      }
      if (!result.succeeded) {
        if (progress != null &&
            (hasFollowingEmailUnits || index < orderedAttachments.length - 1)) {
          progress.markNotAttemptedAll(
            _emailRecipientsForNextSendUnit(
              recipients: recipients,
              progress: progress,
            ).map((recipient) => recipient.recipientKey),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<bool> _sendBundledEmailAttachments({
    required List<PendingAttachment> attachments,
    required List<PendingAttachment> pendingAttachments,
    required Attachment bundledAttachment,
    required Chat chat,
    required EmailService service,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
    required String? subject,
    required Message? quotedDraft,
    required ChatSettingsSnapshot settings,
    bool retainOnSuccess = false,
    String? captionForBundle,
    String? htmlCaptionForBundle,
    ComposerSendProgress? progress,
    bool hasFollowingEmailUnits = false,
  }) async {
    if (attachments.isEmpty) return true;
    _markPendingAttachmentsUploadingInList(pendingAttachments, attachments);
    try {
      if (_shouldFanOut(recipients, chat)) {
        final unitRecipients = progress == null
            ? recipients
            : _emailRecipientsForNextSendUnit(
                recipients: recipients,
                progress: progress,
              );
        if (unitRecipients.isEmpty) {
          return false;
        }
        final syntheticAttachmentReply = service.syntheticEmailReplyEnvelope(
          body: captionForBundle ?? '',
          subject: subject,
          quotedDraft: quotedDraft,
        );
        final resolvedAttachment = syntheticAttachmentReply == null
            ? (captionForBundle == null
                  ? bundledAttachment
                  : bundledAttachment.copyWith(caption: captionForBundle))
            : bundledAttachment.copyWith(
                caption: syntheticAttachmentReply.body.isEmpty
                    ? null
                    : syntheticAttachmentReply.body,
              );
        final effectiveSubject = syntheticAttachmentReply?.subject ?? subject;
        final effectiveHtmlCaption =
            syntheticAttachmentReply?.htmlBody ?? htmlCaptionForBundle;
        final result = await _sendFanOut(
          recipients: unitRecipients,
          attachment: resolvedAttachment,
          htmlCaption: effectiveHtmlCaption,
          subject: effectiveSubject,
          quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
          chat: chat,
          settings: settings,
          emit: emit,
        );
        if (progress != null) {
          _applyEmailSendUnitResult(
            progress: progress,
            recipients: unitRecipients,
            result: result,
          );
        }
        if (result.succeeded) {
          _handleBundledAttachmentSuccessInList(
            pendingAttachments,
            attachments,
            retainOnSuccess: retainOnSuccess,
          );
          return true;
        }
        if (progress != null && hasFollowingEmailUnits) {
          progress.markNotAttemptedAll(
            _emailRecipientsForNextSendUnit(
              recipients: recipients,
              progress: progress,
            ).map((recipient) => recipient.recipientKey),
          );
        }
        _markPendingAttachmentsFailedInList(
          pendingAttachments,
          attachments,
          message:
              state.composerError ?? ChatMessageKey.chatAttachmentSendFailed,
        );
        return false;
      }
      try {
        await service.sendAttachment(
          chat: chat,
          attachment: captionForBundle == null
              ? bundledAttachment
              : bundledAttachment.copyWith(caption: captionForBundle),
          subject: subject,
          htmlCaption: htmlCaptionForBundle,
          quotedDraft: quotedDraft,
        );
        _handleBundledAttachmentSuccessInList(
          pendingAttachments,
          attachments,
          retainOnSuccess: retainOnSuccess,
        );
        return true;
      } on DeltaChatException catch (error, stackTrace) {
        _log.warning(
          _bundledAttachmentSendFailureLogMessage,
          error,
          stackTrace,
        );
        final mappedError = DeltaErrorMapper.resolve(error.message);
        final readableMessage = _chatMessageKeyForMessageError(mappedError);
        _markPendingAttachmentsFailedInList(
          pendingAttachments,
          attachments,
          message: readableMessage,
        );
        emit(state.copyWith(composerError: readableMessage));
      } on EmailProvisioningException catch (error, stackTrace) {
        _log.warning(
          _bundledAttachmentSendFailureLogMessage,
          error,
          stackTrace,
        );
        _markPendingAttachmentsFailedInList(
          pendingAttachments,
          attachments,
          message: ChatMessageKey.chatComposerEmailUnavailable,
        );
        emit(
          state.copyWith(
            composerError: ChatMessageKey.chatComposerEmailUnavailable,
          ),
        );
      } on EmailServiceException catch (error, stackTrace) {
        _log.warning(
          _bundledAttachmentSendFailureLogMessage,
          error,
          stackTrace,
        );
        _markPendingAttachmentsFailedInList(
          pendingAttachments,
          attachments,
          message: ChatMessageKey.chatAttachmentSendFailed,
        );
        emit(
          state.copyWith(
            composerError: ChatMessageKey.chatAttachmentSendFailed,
          ),
        );
      }
    } finally {
      EmailAttachmentBundler.scheduleCleanup(bundledAttachment);
    }
    return false;
  }

  void _handlePendingAttachmentSuccessInList(
    List<PendingAttachment> pendingAttachments,
    PendingAttachment pending, {
    required bool retainOnSuccess,
  }) {
    if (retainOnSuccess) {
      _replacePendingAttachmentInList(
        pendingAttachments,
        pending.copyWith(
          status: PendingAttachmentStatus.queued,
          clearErrorMessage: true,
        ),
      );
      return;
    }
    _removePendingAttachmentFromList(pendingAttachments, pending.id);
  }

  String? _calendarTaskSharePreview(CalendarTask? task, String? shareText) {
    final trimmedShareText = shareText?.trim();
    if (trimmedShareText != null && trimmedShareText.isNotEmpty) {
      return trimmedShareText;
    }
    final title = task?.title.trim();
    if (title == null || title.isEmpty) {
      return null;
    }
    return title;
  }

  Future<List<PendingAttachment>> _commitPendingAttachmentsForXmppFanOut({
    required List<PendingAttachment> attachments,
    required List<PendingAttachment> pendingAttachments,
  }) async {
    final committedAttachments = await _messageService
        .commitComposerAttachmentsForSend(
          attachments
              .map((pending) => pending.attachment)
              .toList(growable: false),
        );
    if (committedAttachments.length != attachments.length) {
      throw XmppMessageException();
    }
    final committedPendingAttachments = <PendingAttachment>[];
    for (var index = 0; index < attachments.length; index += 1) {
      final committed = attachments[index].copyWith(
        attachment: committedAttachments[index],
        clearStagedAttachment: true,
      );
      committedPendingAttachments.add(committed);
      _replacePendingAttachmentInList(pendingAttachments, committed);
    }
    return committedPendingAttachments;
  }

  Future<_ChatXmppSendResult> _sendXmppAttachments({
    required Iterable<PendingAttachment> attachments,
    required List<PendingAttachment> pendingAttachments,
    required Chat chat,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
    required bool supportsHttpFileUpload,
    required String? subject,
    Message? quotedDraft,
    Message? draftQuotedDraft,
    String draftBody = _emptySignatureValue,
    CalendarTaskIcsMessage? draftCalendarTaskIcsMessage,
    String? caption,
    String? htmlCaption,
    void Function(String stanzaId)? onLocalMessageStored,
  }) async {
    if (!supportsHttpFileUpload && !chat.isAxichatWelcomeThread) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerFileUploadUnavailable,
        ),
      );
      return const _ChatXmppSendResult(
        completedRecipientKeys: <ComposerRecipientKey>{},
        hasFailures: true,
      );
    }
    var orderedAttachments = attachments.toList(growable: false);
    if (orderedAttachments.isEmpty) {
      return const _ChatXmppSendResult(
        completedRecipientKeys: <ComposerRecipientKey>{},
        hasFailures: false,
      );
    }
    final shouldGroupAttachments = orderedAttachments.length > 1;
    final targets = <String, Contact>{};
    final recipientsByJid = <String, List<ComposerRecipient>>{};
    if (recipients.isEmpty) {
      targets[chat.jid] = Contact.chat(
        chat: chat,
        shareSignatureEnabled:
            chat.shareSignatureEnabled ??
            _settingsSnapshot.shareTokenSignatureEnabled,
      );
      recipientsByJid[chat.jid] = const <ComposerRecipient>[];
    } else {
      for (final recipient in recipients) {
        final targetJid = _resolvedXmppRecipientJid(recipient);
        if (targetJid == null) {
          continue;
        }
        targets.putIfAbsent(targetJid, () => recipient.target);
        (recipientsByJid[targetJid] ??= []).add(recipient);
      }
      if (targets.isEmpty) {
        emit(
          state.copyWith(
            composerError: ChatMessageKey.chatComposerSelectRecipient,
          ),
        );
        return const _ChatXmppSendResult(
          completedRecipientKeys: <ComposerRecipientKey>{},
          hasFailures: true,
        );
      }
    }
    if (targets.length > 1) {
      try {
        orderedAttachments = await _commitPendingAttachmentsForXmppFanOut(
          attachments: orderedAttachments,
          pendingAttachments: pendingAttachments,
        );
      } on XmppMessageException catch (error, stackTrace) {
        final message = _xmppAttachmentFailureMessage(error);
        _markPendingAttachmentsFailedInList(
          pendingAttachments,
          orderedAttachments,
          message: message,
        );
        emit(state.copyWith(composerError: message));
        if (_shouldLogXmppAttachmentFailure(error)) {
          _log.safeWarning(
            _xmppAttachmentSendFailedLogMessage,
            error,
            stackTrace,
          );
        }
        return const _ChatXmppSendResult(
          completedRecipientKeys: <ComposerRecipientKey>{},
          hasFailures: true,
        );
      }
    }
    final attachmentGroupIds = <String, String?>{};
    if (shouldGroupAttachments) {
      for (final entry in targets.entries) {
        attachmentGroupIds[entry.key] = uuid.v4();
      }
    }
    Future<void> saveFailedAttachmentDraft({
      required String? storedStanzaId,
      required PendingAttachment attachment,
      required Set<String> failedTargetJids,
    }) async {
      if (storedStanzaId != null) {
        return;
      }
      final failedRecipients = failedTargetJids
          .expand((jid) => recipientsByJid[jid] ?? const <ComposerRecipient>[])
          .toList(growable: false);
      await _saveXmppDraft(
        chat: chat,
        recipients: failedRecipients.isEmpty ? recipients : failedRecipients,
        body: draftBody,
        attachments: [attachment],
        subject: subject,
        quotedDraft: draftQuotedDraft ?? quotedDraft,
        calendarTaskIcsMessage: draftCalendarTaskIcsMessage,
        emit: emit,
      );
    }

    final successfulAttachmentCounts = <String, int>{
      for (final targetJid in targets.keys) targetJid: 0,
    };
    final failedTargetJids = <String>{};
    var hasFailures = false;
    for (var index = 0; index < orderedAttachments.length; index += 1) {
      var current = orderedAttachments[index];
      String? storedStanzaId;
      final shouldApplyCaption = caption?.isNotEmpty == true && index == 0;
      final updatedAttachment = shouldApplyCaption
          ? current.attachment.copyWith(caption: caption)
          : current.attachment;
      current = current.copyWith(
        attachment: updatedAttachment,
        status: PendingAttachmentStatus.uploading,
        clearErrorMessage: true,
      );
      _replacePendingAttachmentInList(pendingAttachments, current);
      XmppAttachmentUpload? localUpload;
      XmppAttachmentUpload? networkUpload;
      ChatMessageKey? failureMessage;
      var targetFailedThisAttachment = false;
      for (final entry in targets.entries) {
        final targetJid = entry.key;
        if (failedTargetJids.contains(targetJid)) {
          continue;
        }
        final target = entry.value;
        final targetIsLocalOnly = _isLocalOnlyXmppTarget(
          jid: targetJid,
          target: target,
        );
        final quotedStanzaId =
            quotedDraft != null && quotedDraft.chatJid == targetJid
            ? quotedDraft.replyId(
                isGroupChat: target.chatType == ChatType.groupChat,
              )
            : null;
        final quote = quotedStanzaId != null && index == 0 ? quotedDraft : null;
        final groupId = attachmentGroupIds[targetJid];
        final groupQuotedStanzaId = groupId == null ? null : quotedStanzaId;
        try {
          if (targetIsLocalOnly) {
            localUpload = await _messageService.sendLocalOnlyAttachment(
              jid: targetJid,
              attachment: current.attachment,
              encryptionProtocol: target.encryptionProtocol,
              chatType: target.chatType,
              quotedMessage: quote,
              groupQuotedStanzaId: groupQuotedStanzaId,
              htmlCaption: shouldApplyCaption ? htmlCaption : null,
              transportGroupId: groupId,
              attachmentOrder: index,
              upload: localUpload,
              onLocalMessageStored: (stanzaId) {
                storedStanzaId = stanzaId;
                onLocalMessageStored?.call(stanzaId);
              },
            );
          } else {
            networkUpload = await _messageService.sendAttachment(
              jid: targetJid,
              attachment: current.attachment,
              encryptionProtocol: target.encryptionProtocol,
              chatType: target.chatType,
              quotedMessage: quote,
              groupQuotedStanzaId: groupQuotedStanzaId,
              htmlCaption: shouldApplyCaption ? htmlCaption : null,
              transportGroupId: groupId,
              attachmentOrder: index,
              upload: networkUpload,
              onLocalMessageStored: (stanzaId) {
                storedStanzaId = stanzaId;
                onLocalMessageStored?.call(stanzaId);
              },
            );
          }
          successfulAttachmentCounts[targetJid] =
              (successfulAttachmentCounts[targetJid] ?? 0) + 1;
        } on XmppMessageException catch (error, stackTrace) {
          failedTargetJids.add(targetJid);
          hasFailures = true;
          targetFailedThisAttachment = true;
          failureMessage ??= _xmppAttachmentFailureMessage(error);
          if (_shouldLogXmppAttachmentFailure(error)) {
            _log.safeWarning(
              _xmppAttachmentSendFailedLogMessage,
              error,
              stackTrace,
            );
          }
        }
      }
      if (targetFailedThisAttachment) {
        final message =
            failureMessage ?? ChatMessageKey.chatAttachmentSendFailed;
        _markPendingAttachmentFailedInList(
          pendingAttachments,
          current.id,
          message: message,
        );
        emit(state.copyWith(composerError: message));
        await saveFailedAttachmentDraft(
          storedStanzaId: storedStanzaId,
          attachment: current,
          failedTargetJids: failedTargetJids,
        );
      } else if (failedTargetJids.isEmpty) {
        _removePendingAttachmentFromList(pendingAttachments, current.id);
      } else {
        _replacePendingAttachmentInList(
          pendingAttachments,
          current.copyWith(
            status: PendingAttachmentStatus.queued,
            clearErrorMessage: true,
          ),
        );
      }
      if (failedTargetJids.length == targets.length) {
        break;
      }
    }
    final completedRecipientKeys = <ComposerRecipientKey>{};
    for (final entry in successfulAttachmentCounts.entries) {
      if (entry.value != orderedAttachments.length) {
        continue;
      }
      completedRecipientKeys.addAll(
        (recipientsByJid[entry.key] ?? const <ComposerRecipient>[]).map(
          (recipient) => recipient.recipientKey,
        ),
      );
    }
    return _ChatXmppSendResult(
      completedRecipientKeys: completedRecipientKeys,
      hasFailures: hasFailures,
      submittedAttachments: orderedAttachments,
    );
  }

  ChatMessageKey _xmppAttachmentFailureMessage(Exception error) {
    if (error is XmppUploadUnavailableException ||
        error is XmppUploadNotSupportedException) {
      return ChatMessageKey.chatComposerFileUploadUnavailable;
    }
    if (error is XmppFileTooBigException ||
        error is XmppUploadMisconfiguredException) {
      return ChatMessageKey.messageErrorFileUploadFailure;
    }
    return ChatMessageKey.chatAttachmentSendFailed;
  }

  bool _shouldLogXmppAttachmentFailure(Exception error) =>
      error is! XmppFileTooBigException &&
      error is! XmppUploadUnavailableException &&
      error is! XmppUploadNotSupportedException &&
      error is! XmppUploadMisconfiguredException &&
      error is! XmppMessageException;

  List<String> _draftRecipientJids({
    required Chat chat,
    required List<ComposerRecipient> recipients,
  }) => recipients.recipientIds(fallbackJid: chat.jid);

  String _draftSignature({
    required List<String> recipients,
    required String body,
    required String? subject,
    required List<PendingAttachment> pendingAttachments,
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
  }) {
    final sortedRecipients = List<String>.from(recipients)..sort();
    final buffer =
        StringBuffer(sortedRecipients.join(_sendSignatureListSeparator))
          ..write(_sendSignatureSeparator)
          ..write(body)
          ..write(_sendSignatureSubjectTag)
          ..write(subject ?? _emptySignatureValue);
    if (pendingAttachments.isNotEmpty) {
      final attachmentKeys =
          pendingAttachments
              .map(_pendingAttachmentSignatureKey)
              .where((key) => key.isNotEmpty)
              .toList()
            ..sort();
      buffer
        ..write(_sendSignatureAttachmentTag)
        ..write(attachmentKeys.join(_sendSignatureListSeparator));
    }
    if (calendarTaskIcsMessage != null) {
      buffer
        ..write(_sendSignatureCalendarTaskTag)
        ..write(calendarTaskIcsMessage.toJson().toString());
    }
    return buffer.toString();
  }

  String _pendingAttachmentSignatureKey(PendingAttachment pending) {
    final attachment = pending.attachment;
    final path = attachment.path;
    if (path.isEmpty) return _emptySignatureValue;
    return (StringBuffer(path)
          ..write(_sendSignatureAttachmentFieldSeparator)
          ..write(attachment.fileName)
          ..write(_sendSignatureAttachmentFieldSeparator)
          ..write(attachment.sizeBytes)
          ..write(_sendSignatureAttachmentFieldSeparator)
          ..write(attachment.mimeType ?? _emptySignatureValue)
          ..write(_sendSignatureAttachmentFieldSeparator)
          ..write(attachment.metadataId ?? _emptySignatureValue)
          ..write(_sendSignatureAttachmentFieldSeparator)
          ..write(pending.id))
        .toString();
  }

  String _sendSignature({
    required List<String> recipients,
    required String body,
    required String? subject,
    required List<PendingAttachment> pendingAttachments,
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    required String? quoteId,
  }) {
    final signature = _draftSignature(
      recipients: recipients,
      body: body,
      subject: subject,
      pendingAttachments: pendingAttachments,
      calendarTaskIcsMessage: calendarTaskIcsMessage,
    );
    final resolvedQuoteId = quoteId?.trim();
    if (resolvedQuoteId == null || resolvedQuoteId.isEmpty) {
      return signature;
    }
    return (StringBuffer(signature)
          ..write(_sendSignatureQuoteTag)
          ..write(resolvedQuoteId))
        .toString();
  }

  String _messageKey(Message message) => message.id ?? message.stanzaID;

  Future<bool> _isChatBlockedForAutoDownload(Chat chat) async {
    if (chat.spam) return true;
    if (chat.defaultTransport.isEmail) {
      final emailService = _emailService;
      if (emailService != null) {
        final address =
            normalizedAddressValue(chat.emailAddress ?? chat.jid) ?? '';
        if (address.isNotEmpty &&
            await emailService.blocking.isBlocked(address)) {
          return true;
        }
      }
    }
    final xmppService = _xmppService;
    if (xmppService == null) return false;
    return xmppService.isJidBlocked(chat.jid);
  }

  Future<bool> _hasLocalAttachmentFile(FileMetadataData metadata) async {
    final path = metadata.path?.trim();
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }

  Future<bool> _needsAttachmentDownload(FileMetadataData metadata) async {
    if (await _hasLocalAttachmentFile(metadata)) {
      return false;
    }
    final urls = metadata.sourceUrls;
    return urls != null && urls.isNotEmpty;
  }

  void _queueAutoDownloadAttachments({
    required List<Message> messages,
    required Map<String, List<String>> attachmentsByMessageId,
    bool force = false,
  }) {
    _autoDownloadQueue = _autoDownloadQueue.then((_) async {
      try {
        await _maybeAutoDownloadAttachments(
          messages: messages,
          attachmentsByMessageId: attachmentsByMessageId,
          force: force,
        );
      } on Exception catch (error, stackTrace) {
        _log.warning('Auto-download queue failed.', error, stackTrace);
      }
    });
  }

  Future<void> _maybeAutoDownloadAttachments({
    required List<Message> messages,
    required Map<String, List<String>> attachmentsByMessageId,
    bool force = false,
  }) async {
    if (messages.isEmpty || attachmentsByMessageId.isEmpty) return;
    final chat = state.chat;
    if (chat == null) return;
    final isChatBlocked = await _isChatBlockedForAutoDownload(chat);
    if (!force && isChatBlocked) return;

    final messageKeys = <String, List<String>>{};
    final metadataIds = <String>{};
    for (final message in messages) {
      final key = _messageKey(message);
      final ids = attachmentsByMessageId[key];
      if (ids == null || ids.isEmpty) continue;
      messageKeys[key] = ids;
      metadataIds.addAll(ids);
    }
    if (metadataIds.isEmpty) return;
    final metadataList = await _messageService.loadFileMetadataByIds(
      metadataIds,
    );
    final metadataById = <String, FileMetadataData>{
      for (final metadata in metadataList) metadata.id: metadata,
    };
    final downloads = <({String metadataId, String stanzaId})>[];

    for (final message in messages) {
      final key = _messageKey(message);
      final ids = messageKeys[key];
      if (ids == null || ids.isEmpty) continue;

      if (chat.defaultTransport.isEmail || message.isEmailBacked) {
        continue;
      }

      for (final metadataId in ids) {
        final metadata = metadataById[metadataId];
        if (metadata == null) continue;
        if (!force &&
            (_autoDownloadAttemptedMetadataIds.contains(metadataId) ||
                !allowsAttachmentAutoDownload(
                  chat: chat,
                  metadata: metadata,
                  imagesEnabled: _settingsSnapshot.autoDownloadImages,
                  videosEnabled: _settingsSnapshot.autoDownloadVideos,
                  documentsEnabled: _settingsSnapshot.autoDownloadDocuments,
                  archivesEnabled: _settingsSnapshot.autoDownloadArchives,
                  chatBlocked: isChatBlocked,
                  requireKnownSize: false,
                  maxBytes: maxAttachmentAutoDownloadBytes,
                ))) {
          continue;
        }
        if (force && metadata.isHighRiskForAutoDownload) {
          continue;
        }
        if (force &&
            metadata.sizeBytes != null &&
            metadata.sizeBytes! > maxAttachmentAutoDownloadBytes) {
          continue;
        }
        final needsDownload = await _needsAttachmentDownload(metadata);
        if (!needsDownload) continue;
        if (!force) {
          _autoDownloadAttemptedMetadataIds.add(metadataId);
        }
        downloads.add((metadataId: metadataId, stanzaId: message.stanzaID));
      }
    }

    for (final download in downloads) {
      try {
        await downloadInboundAttachment(
          metadataId: download.metadataId,
          stanzaId: download.stanzaId,
          maxBytesOverride: maxAttachmentAutoDownloadBytes,
        );
      } on XmppException catch (error, stackTrace) {
        _log.warning('Auto-download attachment failed.', error, stackTrace);
      }
    }
  }

  Future<bool> downloadFullEmailMessage(Message message) async {
    final emailService = _emailService;
    if (emailService == null) return false;
    final downloaded = await emailService.requestEmailContentPreparation(
      message,
      priority: EmailContentPreparationPriority.manual,
    );
    if (downloaded) {
      add(_ChatEmailFullMessageDownloaded(message.stanzaID));
    }
    return downloaded;
  }

  Future<bool> downloadInboundAttachment({
    required String metadataId,
    required String stanzaId,
    int? maxBytesOverride,
  }) async {
    final xmppService = _xmppService;
    if (xmppService == null) return false;
    final downloadedPath = await xmppService.downloadInboundAttachment(
      metadataId: metadataId,
      stanzaId: stanzaId,
      maxBytesOverride: maxBytesOverride,
    );
    return downloadedPath?.trim().isNotEmpty == true;
  }

  Future<FileMetadataData?> reloadFileMetadata(String metadataId) async {
    return _messageService.loadFileMetadata(metadataId);
  }

  String? get selfJid => _chatsService.myJid;

  List<String> _orderedUniqueAttachmentIds(
    Iterable<MessageAttachmentData> attachments,
  ) {
    final orderedIds = <String>{};
    for (final attachment in attachments) {
      final id = attachment.fileMetadataId;
      if (id.isEmpty) {
        continue;
      }
      orderedIds.add(id);
    }
    return orderedIds.toList(growable: false);
  }

  ({
    Map<String, List<String>> attachmentsByMessageId,
    Map<String, String> groupLeaderByMessageId,
    Map<String, String> groupQuotedReferenceByMessageId,
  })
  _directAttachmentMaps(List<Message> messages) {
    if (messages.isEmpty) {
      return (
        attachmentsByMessageId: const <String, List<String>>{},
        groupLeaderByMessageId: const <String, String>{},
        groupQuotedReferenceByMessageId: const <String, String>{},
      );
    }
    final attachmentByMessageId = <String, List<String>>{};
    for (final message in messages) {
      final fallback = message.fileMetadataID?.trim();
      if (fallback == null || fallback.isEmpty) {
        continue;
      }
      attachmentByMessageId[_messageKey(message)] = [fallback];
    }
    return (
      attachmentsByMessageId: attachmentByMessageId,
      groupLeaderByMessageId: const <String, String>{},
      groupQuotedReferenceByMessageId: const <String, String>{},
    );
  }

  Future<
    ({
      Map<String, List<String>> attachmentsByMessageId,
      Map<String, String> groupLeaderByMessageId,
      Map<String, String> groupQuotedReferenceByMessageId,
    })
  >
  _loadAttachmentMaps(List<Message> messages) async {
    if (messages.isEmpty) {
      return (
        attachmentsByMessageId: const <String, List<String>>{},
        groupLeaderByMessageId: const <String, String>{},
        groupQuotedReferenceByMessageId: const <String, String>{},
      );
    }
    final messageIds = <String>[];
    final messageById = <String, Message>{};
    final messageIndex = <String, int>{};
    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      final id = message.id;
      if (id == null || id.isEmpty) continue;
      messageIds.add(id);
      messageById[id] = message;
      messageIndex[id] = index;
    }
    final attachmentByMessageId = <String, List<String>>{};
    final groupLeaderByMessageId = <String, String>{};
    final groupQuotedReferenceByMessageId = <String, String>{};
    if (messageIds.isNotEmpty) {
      final attachments = await _messageService
          .loadMessageAttachmentsForMessages(messageIds);
      for (final entry in attachments.entries) {
        final sorted = entry.value.whereType<MessageAttachmentData>().toList(
          growable: false,
        )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        attachmentByMessageId[entry.key] = _orderedUniqueAttachmentIds(sorted);
      }

      final grouped = <String, List<MessageAttachmentData>>{};
      for (final entry in attachments.entries) {
        for (final attachment
            in entry.value.whereType<MessageAttachmentData>()) {
          final groupId = attachment.transportGroupId;
          if (groupId == null || groupId.isEmpty) continue;
          grouped.putIfAbsent(groupId, () => []).add(attachment);
        }
      }

      for (final entry in grouped.entries) {
        final groupEntries = entry.value;
        if (groupEntries.isEmpty) continue;
        final messageIdsInGroup = groupEntries
            .map((attachment) => attachment.messageId)
            .toSet();
        final leaderId = _selectGroupLeader(
          attachments: groupEntries,
          messageById: messageById,
          messageIndex: messageIndex,
        );
        if (leaderId == null) continue;
        final groupQuotedReference = _attachmentGroupQuotedReference(
          attachments: groupEntries,
          messageById: messageById,
        );
        if (groupQuotedReference != null) {
          groupQuotedReferenceByMessageId[leaderId] = groupQuotedReference;
        }
        for (final messageId in messageIdsInGroup) {
          groupLeaderByMessageId[messageId] = leaderId;
          if (messageId != leaderId) {
            attachmentByMessageId.remove(messageId);
          }
        }
        final orderedGroup = List<MessageAttachmentData>.from(groupEntries)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        attachmentByMessageId[leaderId] = _orderedUniqueAttachmentIds(
          orderedGroup,
        );
      }
    }

    for (final message in messages) {
      final key = _messageKey(message);
      final leaderId = groupLeaderByMessageId[key];
      if (leaderId != null && leaderId != key) continue;
      if (attachmentByMessageId.containsKey(key)) continue;
      final fallback = message.fileMetadataID;
      if (fallback != null && fallback.isNotEmpty) {
        attachmentByMessageId[key] = [fallback];
      }
    }
    return (
      attachmentsByMessageId: attachmentByMessageId,
      groupLeaderByMessageId: groupLeaderByMessageId,
      groupQuotedReferenceByMessageId: groupQuotedReferenceByMessageId,
    );
  }

  bool _isCalendarSyncEnvelope(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return false;
    }
    return CalendarSyncMessage.looksLikeEnvelope(trimmed);
  }

  ({
    List<Message> messages,
    Map<String, List<String>> attachmentsByMessageId,
    Map<String, String> groupLeaderByMessageId,
  })
  _filterBodyInternalMessages({
    required List<Message> messages,
    required Map<String, List<String>> attachmentsByMessageId,
    required Map<String, String> groupLeaderByMessageId,
  }) {
    if (messages.isEmpty) {
      return (
        messages: messages,
        attachmentsByMessageId: attachmentsByMessageId,
        groupLeaderByMessageId: groupLeaderByMessageId,
      );
    }
    final retainedMessages = <Message>[];
    var filtered = false;
    for (final message in messages) {
      if (_isCalendarSyncEnvelope(message.body)) {
        filtered = true;
        continue;
      }
      retainedMessages.add(message);
    }
    if (!filtered) {
      return (
        messages: messages,
        attachmentsByMessageId: attachmentsByMessageId,
        groupLeaderByMessageId: groupLeaderByMessageId,
      );
    }
    final retainedKeys = retainedMessages.map(_messageKey).toSet();
    return (
      messages: retainedMessages,
      attachmentsByMessageId: <String, List<String>>{
        for (final entry in attachmentsByMessageId.entries)
          if (retainedKeys.contains(entry.key)) entry.key: entry.value,
      },
      groupLeaderByMessageId: const <String, String>{},
    );
  }

  Future<Set<String>> _snapshotMetadataIdsFor(
    Map<String, List<String>> attachmentsByMessageId,
  ) async {
    if (attachmentsByMessageId.isEmpty) {
      return const <String>{};
    }
    final allIds = <String>{};
    for (final entry in attachmentsByMessageId.values) {
      allIds.addAll(entry);
    }
    if (allIds.isEmpty) {
      return const <String>{};
    }
    final metadataRows = await _messageService.loadFileMetadataByIds(allIds);
    final snapshotIds = <String>{};
    for (final metadata in metadataRows) {
      if (metadata.isCalendarSnapshot) {
        snapshotIds.add(metadata.id);
      }
    }
    return snapshotIds;
  }

  Future<
    ({
      List<Message> messages,
      Map<String, List<String>> attachmentsByMessageId,
      Map<String, String> groupLeaderByMessageId,
    })
  >
  _filterInternalMessages({
    required List<Message> messages,
    required Map<String, List<String>> attachmentsByMessageId,
    required Map<String, String> groupLeaderByMessageId,
  }) async {
    if (messages.isEmpty) {
      return (
        messages: messages,
        attachmentsByMessageId: attachmentsByMessageId,
        groupLeaderByMessageId: groupLeaderByMessageId,
      );
    }
    final snapshotIds = await _snapshotMetadataIdsFor(attachmentsByMessageId);
    final blockedKeys = <String>{};
    for (final entry in attachmentsByMessageId.entries) {
      if (entry.value.any(snapshotIds.contains)) {
        blockedKeys.add(entry.key);
      }
    }
    final filteredMessages = <Message>[];
    for (final message in messages) {
      final key = _messageKey(message);
      if (_isCalendarSyncEnvelope(message.body)) {
        blockedKeys.add(key);
      }
    }
    if (blockedKeys.isNotEmpty) {
      for (final entry in groupLeaderByMessageId.entries) {
        if (blockedKeys.contains(entry.value)) {
          blockedKeys.add(entry.key);
        }
      }
    }
    for (final message in messages) {
      final key = _messageKey(message);
      if (blockedKeys.contains(key)) {
        continue;
      }
      filteredMessages.add(message);
    }
    if (blockedKeys.isEmpty) {
      return (
        messages: messages,
        attachmentsByMessageId: attachmentsByMessageId,
        groupLeaderByMessageId: groupLeaderByMessageId,
      );
    }
    if (filteredMessages.length == messages.length) {
      return (
        messages: messages,
        attachmentsByMessageId: attachmentsByMessageId,
        groupLeaderByMessageId: groupLeaderByMessageId,
      );
    }
    final retainedKeys = filteredMessages.map(_messageKey).toSet();
    final filteredAttachments = <String, List<String>>{};
    for (final entry in attachmentsByMessageId.entries) {
      if (retainedKeys.contains(entry.key)) {
        filteredAttachments[entry.key] = entry.value;
      }
    }
    final filteredLeaders = <String, String>{};
    for (final entry in groupLeaderByMessageId.entries) {
      if (!retainedKeys.contains(entry.key)) {
        continue;
      }
      final leaderId = entry.value;
      if (!retainedKeys.contains(leaderId)) {
        continue;
      }
      filteredLeaders[entry.key] = leaderId;
    }
    return (
      messages: filteredMessages,
      attachmentsByMessageId: filteredAttachments,
      groupLeaderByMessageId: filteredLeaders,
    );
  }

  String? _selectGroupLeader({
    required Iterable<MessageAttachmentData> attachments,
    required Map<String, Message> messageById,
    required Map<String, int> messageIndex,
  }) {
    final candidates = attachments
        .where((attachment) => messageById.containsKey(attachment.messageId))
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    int compareCandidates(
      MessageAttachmentData left,
      MessageAttachmentData right,
    ) {
      final sortOrder = left.sortOrder.compareTo(right.sortOrder);
      if (sortOrder != 0) {
        return sortOrder;
      }
      final leftIndex = messageIndex[left.messageId] ?? 0;
      final rightIndex = messageIndex[right.messageId] ?? 0;
      return leftIndex.compareTo(rightIndex);
    }

    final ordered = List<MessageAttachmentData>.from(candidates)
      ..sort(compareCandidates);
    final withContent = ordered
        .where((attachment) {
          final message = messageById[attachment.messageId];
          return message != null && _hasRealAttachmentGroupContent(message);
        })
        .toList(growable: false);
    final prioritized = withContent.isNotEmpty ? withContent : ordered;
    return prioritized.first.messageId;
  }

  bool _hasRealAttachmentGroupContent(Message message) {
    final display = ChatSubjectCodec.splitDisplayBody(
      body: message.body,
      subject: message.subject,
    );
    return display.subject?.trim().isNotEmpty == true ||
        display.body.trim().isNotEmpty ||
        message.normalizedHtmlBody?.trim().isNotEmpty == true;
  }

  String? _attachmentGroupQuotedReference({
    required Iterable<MessageAttachmentData> attachments,
    required Map<String, Message> messageById,
  }) {
    for (final attachment in attachments) {
      final value = attachment.groupQuotedReference?.trim();
      if (value != null &&
          value.isNotEmpty &&
          !isLegacyWireMessageReferenceValue(value)) {
        return value;
      }
    }
    for (final attachment in attachments) {
      final message = messageById[attachment.messageId];
      final value = message?.storedReplyId;
      if (value != null &&
          value.isNotEmpty &&
          !isLegacyWireMessageReferenceValue(value)) {
        return value;
      }
    }
    return null;
  }

  List<Message> _messagesWithAttachmentGroupQuoteFallback({
    required List<Message> messages,
    required Map<String, String> groupQuotedReferenceByMessageId,
  }) {
    if (messages.isEmpty || groupQuotedReferenceByMessageId.isEmpty) {
      return messages;
    }
    var changed = false;
    final updated = messages
        .map((message) {
          if (message.storedReplyId?.trim().isNotEmpty == true) {
            return message;
          }
          final messageId = message.id;
          if (messageId == null || messageId.isEmpty) {
            return message;
          }
          final reference = groupQuotedReferenceByMessageId[messageId];
          if (reference == null) {
            return message;
          }
          changed = true;
          return message.copyWith(replyStanzaId: reference);
        })
        .toList(growable: false);
    return changed ? updated : messages;
  }

  ChatState _attachToast(ChatState base, ChatToast toast) =>
      base.copyWith(toast: toast, toastId: base.toastId + 1);

  void _clearEmailSubject(Emitter<ChatState> emit) {
    if (state.emailSubject?.isEmpty ?? true) {
      return;
    }
    emit(
      state.copyWith(
        emailSubject: '',
        emailSubjectAutofillEligible: true,
        emailSubjectAutofilled: false,
      ),
    );
  }

  ({
    List<ComposerRecipient> emailRecipients,
    List<ComposerRecipient> xmppRecipients,
  })
  _splitRecipientsForSend({
    required Chat chat,
    required List<ComposerRecipient> recipients,
    required bool forceEmail,
  }) {
    if (forceEmail || _isEmailCapableChat(chat)) {
      return (
        emailRecipients: recipients.toList(growable: false),
        xmppRecipients: const <ComposerRecipient>[],
      );
    }
    return (
      emailRecipients: recipients.emailRecipients,
      xmppRecipients: recipients.xmppRecipients,
    );
  }

  List<ComposerRecipient> _includeIncludedPinnedRecipients({
    required List<ComposerRecipient> submittedRecipients,
    required List<ComposerRecipient> recipients,
  }) {
    final keys = recipients.map((recipient) => recipient.recipientKey).toSet();
    final next = List<ComposerRecipient>.from(recipients);
    for (final recipient in submittedRecipients) {
      if (!recipient.included || !recipient.isPinned) {
        continue;
      }
      if (keys.add(recipient.recipientKey)) {
        next.insert(0, recipient);
      }
    }
    return next;
  }

  bool _wouldHideIncludedPinnedRecipient({
    required List<ComposerRecipient> submittedRecipients,
    required List<ComposerRecipient> nextRecipients,
  }) {
    final nextKeys = nextRecipients
        .map((recipient) => recipient.recipientKey)
        .toSet();
    return submittedRecipients.any(
      (recipient) =>
          recipient.included &&
          recipient.isPinned &&
          !nextKeys.contains(recipient.recipientKey),
    );
  }

  bool _retryMayDuplicateDeliveredUnits({
    required bool safeFailedOnlyRetry,
    required bool requiresEmail,
    required bool requiresXmpp,
    required bool emailSendSucceeded,
    required bool xmppSendSucceeded,
    required int emailSendUnitCount,
    required int xmppSendUnitCount,
    required bool retainsCompletedPinnedRecipient,
  }) {
    if (retainsCompletedPinnedRecipient) {
      return true;
    }
    if (safeFailedOnlyRetry) {
      return false;
    }
    if (requiresEmail && !emailSendSucceeded && emailSendUnitCount > 1) {
      return true;
    }
    if (requiresXmpp && !xmppSendSucceeded && xmppSendUnitCount > 1) {
      return true;
    }
    return false;
  }

  bool _shouldForceEmailForSend({
    required Chat chat,
    MessageTransport? oneShotTransportOverride,
  }) {
    if (!state.canOfferEmailOutboundOverride) {
      return false;
    }
    return state
        .activeTransportForSend(chat, oneShotOverride: oneShotTransportOverride)
        .isEmail;
  }

  bool _recipientSupportsEmailSend({
    required ComposerRecipient recipient,
    required bool forceEmail,
  }) {
    if (recipient.target.supportsEmail) {
      return true;
    }
    final targetChat = recipient.target.chat;
    return forceEmail &&
        targetChat != null &&
        targetChat.supportsEmailOutboundOverrideForDomain(
          addressDomainPart(state.emailSelfJid),
        );
  }

  String? _resolvedXmppRecipientJid(ComposerRecipient recipient) {
    return switch (recipient.intent) {
      XmppRecipientIntent(:final jid) => jid,
      _ => null,
    };
  }

  bool _hasEmailTarget({
    required Chat chat,
    required List<ComposerRecipient> recipients,
    bool forceEmail = false,
  }) {
    if (forceEmail &&
        chat.supportsEmailOutboundOverrideForDomain(
          addressDomainPart(state.emailSelfJid),
        )) {
      return true;
    }
    if (_isEmailCapableChat(chat)) {
      return true;
    }
    return recipients.hasEmailRecipients;
  }

  bool _shouldSendAttachmentsViaEmail({
    required Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (chat.defaultTransport.isEmail) {
      return true;
    }
    return recipients.hasEmailRecipients;
  }

  bool _isEmailCapableChat(Chat chat) {
    return chat.defaultTransport.isEmail;
  }

  bool _shouldFanOut(List<ComposerRecipient> recipients, Chat chat) =>
      recipients.shouldFanOut(chat);

  ChatMessageKey _chatMessageKeyForMessageError(
    MessageError error,
  ) => switch (error) {
    MessageError.serviceUnavailable =>
      ChatMessageKey.messageErrorServiceUnavailable,
    MessageError.serverNotFound => ChatMessageKey.messageErrorServerNotFound,
    MessageError.serverTimeout => ChatMessageKey.messageErrorServerTimeout,
    MessageError.unknown => ChatMessageKey.messageErrorUnknown,
    MessageError.notEncryptedForDevice =>
      ChatMessageKey.messageErrorNotEncryptedForDevice,
    MessageError.malformedKey => ChatMessageKey.messageErrorMalformedKey,
    MessageError.unknownSPK => ChatMessageKey.messageErrorUnknownSignedPrekey,
    MessageError.noDeviceSession => ChatMessageKey.messageErrorNoDeviceSession,
    MessageError.skippingTooManyKeys =>
      ChatMessageKey.messageErrorSkippingTooManyKeys,
    MessageError.invalidHMAC => ChatMessageKey.messageErrorInvalidHmac,
    MessageError.malformedCiphertext =>
      ChatMessageKey.messageErrorMalformedCiphertext,
    MessageError.noKeyMaterial => ChatMessageKey.messageErrorNoKeyMaterial,
    MessageError.noDecryptionKey => ChatMessageKey.messageErrorNoDecryptionKey,
    MessageError.invalidKEX => ChatMessageKey.messageErrorInvalidKex,
    MessageError.unknownOmemoError => ChatMessageKey.messageErrorUnknownOmemo,
    MessageError.invalidAffixElements =>
      ChatMessageKey.messageErrorInvalidAffixElements,
    MessageError.emptyDeviceList => ChatMessageKey.messageErrorEmptyDeviceList,
    MessageError.omemoUnsupported =>
      ChatMessageKey.messageErrorOmemoUnsupported,
    MessageError.encryptionFailure =>
      ChatMessageKey.messageErrorEncryptionFailure,
    MessageError.invalidEnvelope => ChatMessageKey.messageErrorInvalidEnvelope,
    MessageError.fileDownloadFailure =>
      ChatMessageKey.messageErrorFileDownloadFailure,
    MessageError.fileUploadFailure =>
      ChatMessageKey.messageErrorFileUploadFailure,
    MessageError.fileDecryptionFailure =>
      ChatMessageKey.messageErrorFileDecryptionFailure,
    MessageError.fileEncryptionFailure =>
      ChatMessageKey.messageErrorFileEncryptionFailure,
    MessageError.plaintextFileInOmemo =>
      ChatMessageKey.messageErrorPlaintextFileInOmemo,
    MessageError.emailSendFailure =>
      ChatMessageKey.messageErrorEmailSendFailure,
    MessageError.emailAttachmentTooLarge =>
      ChatMessageKey.messageErrorEmailAttachmentTooLarge,
    MessageError.emailRecipientRejected =>
      ChatMessageKey.messageErrorEmailRecipientRejected,
    MessageError.emailAuthenticationFailed =>
      ChatMessageKey.messageErrorEmailAuthenticationFailed,
    MessageError.emailBounced => ChatMessageKey.messageErrorEmailBounced,
    MessageError.emailThrottled => ChatMessageKey.messageErrorEmailThrottled,
    _ => ChatMessageKey.messageErrorUnknown,
  };

  ChatMessageKey _chatMessageKeyForFanOutFailure(
    FanOutValidationException error,
  ) => switch (error) {
    FanOutNoRecipientsException() => ChatMessageKey.fanOutErrorNoRecipients,
    FanOutResolveFailedException() => ChatMessageKey.fanOutErrorResolveFailed,
    FanOutTooManyRecipientsException() =>
      ChatMessageKey.fanOutErrorTooManyRecipients,
    FanOutEmptyMessageException() => ChatMessageKey.fanOutErrorEmptyMessage,
    FanOutInvalidShareTokenException() =>
      ChatMessageKey.fanOutErrorInvalidShareToken,
  };

  ChatMessageKey _chatMessageKeyForFanOutReportFailure(
    FanOutSendReport report,
  ) {
    final failures = report.statuses.where((status) => status.isFailure);
    if (failures.isNotEmpty &&
        failures.every(
          (status) => status.error is FanOutResolveFailedException,
        )) {
      return ChatMessageKey.fanOutErrorResolveFailed;
    }
    return ChatMessageKey.chatComposerSendFailed;
  }

  String _composeXmppBody({required String body, required String? subject}) =>
      ChatSubjectCodec.composeXmppBody(body: body, subject: subject);

  String? get _calendarEnvelopeAccountJid =>
      _xmppService?.myJid ?? _chatsService.myJid;

  bool _canSendCalendarTaskEnvelopeToRecipient(
    ComposerRecipient recipient, {
    required RoomState? roomState,
  }) {
    final targetJid = _resolvedXmppRecipientJid(recipient);
    if (targetJid == null) {
      return false;
    }
    final targetChat = recipient.target.chat;
    if (targetChat != null) {
      final decision = _calendarFragmentPolicy.decisionForChat(
        chat: targetChat,
        roomState: _calendarEnvelopeRoomStateFor(
          chat: targetChat,
          roomState: roomState,
        ),
        accountJid: _calendarEnvelopeAccountJid,
      );
      return decision.canWrite;
    }
    return isCalendarSyncTargetAllowed(
      accountJid: _calendarEnvelopeAccountJid,
      targetJid: targetJid,
    );
  }

  RoomState? _calendarEnvelopeRoomStateFor({
    required Chat chat,
    required RoomState? roomState,
  }) {
    if (chat.type != ChatType.groupChat) {
      return roomState;
    }
    final chatJid = _bareJid(chat.jid);
    if (chatJid == null) {
      return null;
    }
    final eventRoomJid = _bareJid(roomState?.roomJid);
    if (eventRoomJid == chatJid) {
      return roomState;
    }
    return _mucService.roomStateFor(chat.jid);
  }

  Future<_ChatXmppSendResult> _sendXmppFanOut({
    required List<ComposerRecipient> recipients,
    required String body,
    CalendarTask? calendarTaskIcs,
    bool calendarTaskIcsReadOnly = CalendarTaskIcsMessage.defaultReadOnly,
    required Message? quotedDraft,
    void Function(String stanzaId)? onLocalMessageStored,
  }) async {
    final recipientsByJid = <String, List<ComposerRecipient>>{};
    for (final recipient in recipients) {
      final targetJid = _resolvedXmppRecipientJid(recipient);
      if (targetJid == null) {
        continue;
      }
      (recipientsByJid[targetJid] ??= []).add(recipient);
    }
    if (recipients.isNotEmpty && recipientsByJid.isEmpty) {
      return const _ChatXmppSendResult(
        completedRecipientKeys: <ComposerRecipientKey>{},
        hasFailures: true,
      );
    }
    final completedRecipientKeys = <ComposerRecipientKey>{};
    var hasFailures = false;
    for (final entry in recipientsByJid.entries) {
      final targetJid = entry.key;
      final recipient = entry.value.first;
      final quote = quotedDraft != null && quotedDraft.chatJid == targetJid
          ? quotedDraft
          : null;
      try {
        if (_isLocalOnlyXmppTarget(jid: targetJid, target: recipient.target)) {
          await _messageService.sendLocalOnlyMessage(
            jid: targetJid,
            text: body,
            encryptionProtocol: recipient.target.encryptionProtocol,
            quotedMessage: quote,
            calendarTaskIcs: calendarTaskIcs,
            calendarTaskIcsReadOnly: calendarTaskIcsReadOnly,
            chatType: recipient.target.chatType,
            onLocalMessageStored: onLocalMessageStored,
          );
        } else {
          await _messageService.sendMessage(
            jid: targetJid,
            text: body,
            encryptionProtocol: recipient.target.encryptionProtocol,
            quotedMessage: quote,
            calendarTaskIcs: calendarTaskIcs,
            calendarTaskIcsReadOnly: calendarTaskIcsReadOnly,
            chatType: recipient.target.chatType,
            onLocalMessageStored: onLocalMessageStored,
          );
        }
        completedRecipientKeys.addAll(
          entry.value.map((recipient) => recipient.recipientKey),
        );
      } on XmppMessageException catch (error, stackTrace) {
        hasFailures = true;
        _log.safeWarning(_sendMessageFailedLogMessage, error, stackTrace);
      }
    }
    return _ChatXmppSendResult(
      completedRecipientKeys: completedRecipientKeys,
      hasFailures: hasFailures,
    );
  }

  Future<_ChatEmailSendUnitResult> _sendFanOut({
    required List<ComposerRecipient> recipients,
    String? text,
    String? htmlBody,
    Attachment? attachment,
    String? htmlCaption,
    String? shareId,
    String? subject,
    String? quotedStanzaId,
    required Chat chat,
    required ChatSettingsSnapshot settings,
    required Emitter<ChatState> emit,
  }) async {
    final service = _emailService;
    if (service == null || recipients.isEmpty) {
      return const _ChatEmailSendUnitResult(succeeded: false);
    }
    final targets = <EmailRecipientIntent>[];
    for (final recipient in recipients) {
      final intent = recipient.forcedEmailIntent(
        emailDomain: addressDomainPart(state.emailSelfJid),
      );
      if (intent == null) {
        emit(
          state.copyWith(
            composerError: ChatMessageKey.chatComposerEmailRecipientUnavailable,
          ),
        );
        return const _ChatEmailSendUnitResult(succeeded: false);
      }
      targets.add(intent);
    }
    final chatShareSignatureEnabled =
        chat.shareSignatureEnabled ?? settings.shareTokenSignatureEnabled;
    final useSignatureToken =
        chatShareSignatureEnabled &&
        targets.every((target) => target.shareSignatureEnabled);
    final effectiveShareId = shareId ?? ShareTokenCodec.generateShareId();
    try {
      final report = await service.fanOutSend(
        targets: targets,
        body: text,
        htmlBody: htmlBody,
        attachment: attachment,
        htmlCaption: htmlCaption,
        shareId: effectiveShareId,
        subject: subject,
        quotedStanzaId: quotedStanzaId,
        useSubjectToken: useSignatureToken,
        tokenAsSignature: useSignatureToken,
      );
      final reports =
          LinkedHashMap<String, FanOutSendReport>.from(state.fanOutReports)
            ..remove(report.shareId)
            ..[report.shareId] = report;
      final drafts = LinkedHashMap<String, FanOutDraft>.from(state.fanOutDrafts)
        ..remove(report.shareId)
        ..[report.shareId] = FanOutDraft(
          body: text,
          attachment: attachment,
          shareId: report.shareId,
          subject: subject,
          quotedStanzaId: quotedStanzaId,
        );
      emit(
        state.copyWith(
          fanOutReports: reports,
          fanOutDrafts: drafts,
          composerError: report.hasFailures
              ? _chatMessageKeyForFanOutReportFailure(report)
              : null,
        ),
      );
      return _ChatEmailSendUnitResult(
        succeeded: !report.hasFailures,
        recipientStatuses: report.statusesByTargetKey(targets),
      );
    } on FanOutValidationException catch (error) {
      final key = _chatMessageKeyForFanOutFailure(error);
      emit(state.copyWith(composerError: key));
      return const _ChatEmailSendUnitResult(succeeded: false);
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.warning('Failed to send fan-out message', error, stackTrace);
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerEmailUnavailable,
        ),
      );
      return const _ChatEmailSendUnitResult(succeeded: false);
    } on EmailServiceException catch (error, stackTrace) {
      _log.warning('Failed to send fan-out message', error, stackTrace);
      emit(
        state.copyWith(composerError: ChatMessageKey.chatComposerSendFailed),
      );
      return const _ChatEmailSendUnitResult(succeeded: false);
    }
  }

  Future<List<PendingAttachment>> _rehydrateEmailDraft(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    final service = _emailService;
    if (chat == null || service == null) {
      return const <PendingAttachment>[];
    }
    ShareContext? shareContext = state.shareContexts[message.stanzaID];
    final nextHydrationId = ++_composerHydrationSeed;
    final nextSubject = (shareContext?.subject ?? message.subject)?.trim();
    emit(
      state.copyWith(
        composerHydrationId: nextHydrationId,
        composerHydrationText: message.plainText,
        composerHydrationCalendarTaskIcsMessage: message.calendarTaskIcsMessage,
        composerError: message.error.isNotNone
            ? _chatMessageKeyForMessageError(message.error)
            : state.composerError,
        emailSubject: nextSubject?.isNotEmpty == true ? nextSubject : '',
        emailSubjectAutofillEligible: false,
        emailSubjectAutofilled: false,
      ),
    );
    shareContext ??= await service.shareContextForMessage(message);
    final updatedSubject = (shareContext?.subject ?? message.subject)?.trim();
    if (updatedSubject != (state.emailSubject ?? '')) {
      emit(
        state.copyWith(
          emailSubject: updatedSubject?.isNotEmpty == true
              ? updatedSubject
              : '',
          emailSubjectAutofillEligible: false,
          emailSubjectAutofilled: false,
        ),
      );
    }
    final attachments = await _attachmentsForMessage(message);
    if (attachments.isEmpty) {
      return const <PendingAttachment>[];
    }
    final pendingAttachments = <PendingAttachment>[];
    for (final attachment in attachments) {
      pendingAttachments.add(
        PendingAttachment(
          id: _nextPendingAttachmentId(),
          attachment: attachment,
        ),
      );
    }
    return pendingAttachments;
  }

  void _replacePendingAttachmentInList(
    List<PendingAttachment> attachments,
    PendingAttachment replacement,
  ) {
    final index = attachments.indexWhere(
      (pending) => pending.id == replacement.id,
    );
    if (index == -1) {
      attachments.add(replacement);
      return;
    }
    attachments[index] = replacement;
  }

  void _removePendingAttachmentFromList(
    List<PendingAttachment> attachments,
    String attachmentId,
  ) {
    attachments.removeWhere((pending) => pending.id == attachmentId);
  }

  void _removePendingAttachmentsByIdsFromList(
    List<PendingAttachment> attachments,
    Iterable<String> attachmentIds,
  ) {
    final ids = attachmentIds.toSet();
    if (ids.isEmpty) return;
    attachments.removeWhere((pending) => ids.contains(pending.id));
  }

  void _markPendingAttachmentFailedInList(
    List<PendingAttachment> attachments,
    String attachmentId, {
    ChatMessageKey? message,
  }) {
    final index = attachments.indexWhere(
      (pending) => pending.id == attachmentId,
    );
    if (index == -1) {
      return;
    }
    attachments[index] = attachments[index].copyWith(
      status: PendingAttachmentStatus.failed,
      errorMessage: message ?? ChatMessageKey.chatAttachmentSendFailed,
    );
  }

  void _markPendingAttachmentsFailedInList(
    List<PendingAttachment> pendingAttachments,
    Iterable<PendingAttachment> attachments, {
    ChatMessageKey? message,
  }) {
    final ids = attachments.map((attachment) => attachment.id).toSet();
    if (ids.isEmpty) return;
    final resolvedMessage = message ?? ChatMessageKey.chatAttachmentSendFailed;
    for (var index = 0; index < pendingAttachments.length; index += 1) {
      final pending = pendingAttachments[index];
      if (!ids.contains(pending.id)) {
        continue;
      }
      pendingAttachments[index] = pending.copyWith(
        status: PendingAttachmentStatus.failed,
        errorMessage: resolvedMessage,
      );
    }
  }

  void _markPendingAttachmentsUploadingInList(
    List<PendingAttachment> pendingAttachments,
    Iterable<PendingAttachment> attachments,
  ) {
    final ids = attachments.map((attachment) => attachment.id).toSet();
    if (ids.isEmpty) return;
    for (var index = 0; index < pendingAttachments.length; index += 1) {
      final pending = pendingAttachments[index];
      if (!ids.contains(pending.id)) {
        continue;
      }
      final shouldClearError = pending.errorMessage != null;
      if (pending.status == PendingAttachmentStatus.uploading &&
          !shouldClearError) {
        continue;
      }
      pendingAttachments[index] = pending.copyWith(
        status: PendingAttachmentStatus.uploading,
        clearErrorMessage: true,
      );
    }
  }

  void _markPendingAttachmentsPreparingInList(
    List<PendingAttachment> pendingAttachments,
    Iterable<PendingAttachment> attachments, {
    required bool preparing,
  }) {
    final ids = attachments.map((attachment) => attachment.id).toSet();
    if (ids.isEmpty) return;
    for (var index = 0; index < pendingAttachments.length; index += 1) {
      final pending = pendingAttachments[index];
      if (!ids.contains(pending.id) || pending.isPreparing == preparing) {
        continue;
      }
      pendingAttachments[index] = pending.copyWith(isPreparing: preparing);
    }
  }

  void _queuePendingAttachmentsInList(
    List<PendingAttachment> pendingAttachments,
    Iterable<PendingAttachment> attachments,
  ) {
    final ids = attachments.map((attachment) => attachment.id).toSet();
    if (ids.isEmpty) return;
    for (var index = 0; index < pendingAttachments.length; index += 1) {
      final pending = pendingAttachments[index];
      if (!ids.contains(pending.id)) {
        continue;
      }
      final shouldClearError = pending.errorMessage != null;
      if (pending.status == PendingAttachmentStatus.queued &&
          !shouldClearError) {
        continue;
      }
      pendingAttachments[index] = pending.copyWith(
        status: PendingAttachmentStatus.queued,
        clearErrorMessage: true,
      );
    }
  }

  void _handleBundledAttachmentSuccessInList(
    List<PendingAttachment> pendingAttachments,
    Iterable<PendingAttachment> attachments, {
    required bool retainOnSuccess,
  }) {
    if (retainOnSuccess) {
      _queuePendingAttachmentsInList(pendingAttachments, attachments);
      return;
    }
    _removePendingAttachmentsByIdsFromList(
      pendingAttachments,
      attachments.map((attachment) => attachment.id),
    );
  }

  Future<List<PendingAttachment>> _rehydrateXmppDraft(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final nextHydrationId = ++_composerHydrationSeed;
    emit(
      state.copyWith(
        composerHydrationId: nextHydrationId,
        composerHydrationText: message.plainText,
        composerHydrationCalendarTaskIcsMessage: message.calendarTaskIcsMessage,
        composerError: message.error.isNotNone
            ? _chatMessageKeyForMessageError(message.error)
            : state.composerError,
      ),
    );
    final attachments = await _attachmentsForMessage(message);
    if (attachments.isEmpty) {
      return const <PendingAttachment>[];
    }
    final pendingAttachments = <PendingAttachment>[];
    for (final attachment in attachments) {
      pendingAttachments.add(
        PendingAttachment(
          id: _nextPendingAttachmentId(),
          attachment: attachment,
        ),
      );
    }
    return pendingAttachments;
  }

  Future<void> _saveXmppDraft({
    required Chat chat,
    required List<ComposerRecipient> recipients,
    required String body,
    required Iterable<PendingAttachment> attachments,
    required String? subject,
    required Message? quotedDraft,
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    required Emitter<ChatState> emit,
  }) async {
    final hasAttachments = attachments.isNotEmpty;
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty &&
        !hasAttachments &&
        calendarTaskIcsMessage == null) {
      return;
    }
    final resolvedRecipients = _draftRecipientJids(
      chat: chat,
      recipients: recipients,
    );
    if (resolvedRecipients.isEmpty) return;
    final attachmentPayload = attachments
        .map((pending) => pending.attachment)
        .toList();
    final quoteIds = quotedDraft == null
        ? (
            stanzaId: null as String?,
            originId: null as String?,
            mucStanzaId: null as String?,
          )
        : _replyIdsForDraft(quotedMessage: quotedDraft, chat: chat);
    try {
      await _messageService.saveDraft(
        id: null,
        jids: resolvedRecipients,
        body: trimmedBody,
        subject: subject,
        quotingStanzaId: quoteIds.stanzaId,
        quotingOriginId: quoteIds.originId,
        quotingMucStanzaId: quoteIds.mucStanzaId,
        attachments: attachmentPayload,
        calendarTaskIcsMessage: calendarTaskIcsMessage,
      );
      emit(
        _attachToast(
          state,
          const ChatToast(message: ChatMessageKey.chatDraftSaved),
        ),
      );
    } catch (error, stackTrace) {
      _log.safeFine(_xmppDraftSaveFailedLogMessage, error, stackTrace);
    }
  }

  Future<List<Attachment>> _attachmentsForMessage(Message message) async {
    final messageId = message.id;
    final metadataIds = <String>[];
    if (messageId != null && messageId.isNotEmpty) {
      var attachments = await _messageService.loadMessageAttachments(messageId);
      if (attachments.isNotEmpty) {
        final transportGroupId = attachments.first.transportGroupId?.trim();
        if (transportGroupId != null && transportGroupId.isNotEmpty) {
          attachments = await _messageService.loadMessageAttachmentsForGroup(
            transportGroupId,
          );
        }
        final ordered = List<MessageAttachmentData>.from(attachments)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        for (final attachment in ordered) {
          metadataIds.add(attachment.fileMetadataId);
        }
      }
    }
    if (metadataIds.isEmpty) {
      final fallbackId = message.fileMetadataID;
      if (fallbackId != null && fallbackId.isNotEmpty) {
        metadataIds.add(fallbackId);
      }
    }
    return _attachmentsFromMetadataIds(metadataIds);
  }

  Future<List<Attachment>> _attachmentsFromMetadataIds(
    Iterable<String> metadataIds,
  ) async {
    final orderedIds = LinkedHashSet<String>.from(metadataIds);
    if (orderedIds.isEmpty) return const [];
    final resolved = <Attachment>[];
    for (final metadataId in orderedIds) {
      final metadata = await _messageService.loadFileMetadata(metadataId);
      final path = metadata?.path;
      if (metadata == null || path == null || path.isEmpty) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      final size = metadata.sizeBytes ?? await file.length();
      resolved.add(
        Attachment(
          path: path,
          fileName: metadata.filename,
          sizeBytes: size,
          mimeType: metadata.mimeType,
          width: metadata.width,
          height: metadata.height,
          metadataId: metadata.id,
        ),
      );
    }
    return resolved;
  }

  Future<void> _hydrateShareContexts(
    List<Message> messages,
    Emitter<ChatState> emit,
  ) async {
    final emailService = _emailService;
    if (emailService == null) return;
    final pending = <String, ShareContext>{};
    for (final message in messages) {
      if (message.deltaMsgId == null) continue;
      if (state.shareContexts.containsKey(message.stanzaID)) {
        continue;
      }
      if (_shareContextAttemptedStanzaIds.contains(message.stanzaID)) {
        continue;
      }
      final context = await emailService.shareContextForMessage(message);
      if (emit.isDone) {
        return;
      }
      if (!_messageBelongsToCurrentChat(message)) {
        continue;
      }
      _shareContextAttemptedStanzaIds.add(message.stanzaID);
      if (context != null) {
        pending[message.stanzaID] = context;
      }
    }
    if (pending.isEmpty) return;
    final contexts = Map<String, ShareContext>.from(state.shareContexts)
      ..addAll(pending);
    if (emit.isDone) return;
    emit(state.copyWith(shareContexts: contexts));
  }

  Future<void> _hydrateShareReplies(
    List<Message> messages,
    Emitter<ChatState> emit,
  ) async {
    final contexts = state.shareContexts;
    if (contexts.isEmpty) return;
    final shareContextsById = <String, ShareContext>{};
    final shareBuckets = <String, List<String>>{};
    for (final entry in contexts.entries) {
      shareContextsById.putIfAbsent(entry.value.shareId, () => entry.value);
    }
    for (final message in messages) {
      final shareId = contexts[message.stanzaID]?.shareId;
      if (shareId == null) continue;
      final bucket = shareBuckets.putIfAbsent(shareId, () => <String>[]);
      bucket.add(message.stanzaID);
    }
    if (shareBuckets.isEmpty) return;
    final myBare = _bareJid(_chatsService.myJid);
    final currentChatJid = jid;
    final replies = Map<String, List<Chat>>.from(state.shareReplies);
    for (final entry in shareBuckets.entries) {
      final shareId = entry.key;
      final shareContext = shareContextsById[shareId];
      if (shareContext == null) continue;
      final shareMessages = await _messageService.loadMessagesForShare(shareId);
      if (emit.isDone) return;
      final responders = <String>{};
      for (final shareMessage in shareMessages) {
        final senderBare = _bareJid(shareMessage.senderJid);
        if (senderBare != null && senderBare == myBare) continue;
        if (currentChatJid != null && shareMessage.chatJid == currentChatJid) {
          continue;
        }
        responders.add(shareMessage.chatJid);
      }
      final participants = shareContext.participants
          .where((participant) => responders.contains(participant.jid))
          .toList(growable: false);
      for (final stanzaId in entry.value) {
        if (participants.isEmpty) {
          replies.remove(stanzaId);
        } else {
          replies[stanzaId] = participants;
        }
      }
    }
    if (emit.isDone) return;
    emit(state.copyWith(shareReplies: replies));
  }

  Future<bool> _resendEmailMessage(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    final service = _emailService;
    if (chat == null || service == null) return false;
    final resolvedBody = message.plainText.trim();
    final normalizedHtml = message.normalizedHtmlBody;
    final hasBody = resolvedBody.isNotEmpty;
    final attachments = await _attachmentsForMessage(message);
    final hasAttachment = attachments.isNotEmpty;
    if (!hasBody && !hasAttachment) {
      return false;
    }
    ShareContext? shareContext = state.shareContexts[message.stanzaID];
    shareContext ??= await service.shareContextForMessage(message);
    try {
      final resent = await service.resendMessages([message]);
      if (resent) {
        return true;
      }
      if (hasAttachment) {
        final caption = hasBody ? resolvedBody : null;
        final bool shouldBundle =
            attachments.length >= _emailAttachmentBundleMinimumCount;
        final bundled = await _bundleEmailAttachmentList(
          attachments: attachments,
          caption: caption,
        );
        if (bundled.isEmpty) {
          return false;
        }
        try {
          for (var index = 0; index < bundled.length; index += 1) {
            final attachment = bundled[index];
            final captionedAttachment = index == 0 && caption != null
                ? attachment.copyWith(caption: caption)
                : attachment;
            await service.sendAttachment(
              chat: chat,
              attachment: captionedAttachment,
              subject: shareContext?.subject,
              htmlCaption: index == 0 ? normalizedHtml : null,
              forwarded: message.isForwarded,
              forwardedFromJid: message.forwardedFromJid,
              forwardedOriginalSenderLabel:
                  message.forwardedOriginalSenderLabel,
            );
          }
        } finally {
          if (shouldBundle && bundled.isNotEmpty) {
            EmailAttachmentBundler.scheduleCleanup(bundled.first);
          }
        }
        return true;
      }
      if (hasBody) {
        await service.sendMessage(
          chat: chat,
          body: resolvedBody,
          subject: shareContext?.subject,
          htmlBody: normalizedHtml,
          forwarded: message.isForwarded,
          forwardedFromJid: message.forwardedFromJid,
          forwardedOriginalSenderLabel: message.forwardedOriginalSenderLabel,
        );
        return true;
      }
    } on DeltaChatException catch (error, stackTrace) {
      _log.warning(_emailResendFailedLogMessage, error, stackTrace);
      final mappedError = DeltaErrorMapper.resolve(error.message);
      emit(
        _attachToast(
          state.copyWith(
            composerError: _chatMessageKeyForMessageError(mappedError),
          ),
          ChatToast(
            message: ChatMessageKey.chatEmailResendFailedDetails,
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(_emailResendFailedLogMessage, error, stackTrace);
    }
    return false;
  }
}
