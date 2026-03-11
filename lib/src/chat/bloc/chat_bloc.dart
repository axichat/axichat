// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:async/async.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/calendar_snapshot_metadata.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/chat/models/chat_message.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/models/pinned_message_item.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/event_transform.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/demo/demo_chats.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_bundle.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/synthetic_forward_html.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/notification_payload.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:equatable/equatable.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:path/path.dart' as p;

part 'chat_bloc.freezed.dart';
part 'chat_event.dart';
part 'chat_state.dart';

const int _emailAttachmentBundleMinimumCount = 2;
const _calendarTaskIcsAttachmentMimeType = 'text/calendar';
const _calendarTaskIcsAttachmentSendFailureLogMessage =
    'Failed to send calendar task attachment';
const _attachmentMimeTypeResolutionLogMessage =
    'Failed to resolve attachment mime type';
const _sendSignatureSeparator = '::';
const _sendSignatureSubjectTag = '::subject:';
const _sendSignatureAttachmentTag = '::attachments:';
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
const _emailContactLookupFailedLogMessage =
    'Failed to resolve known email contact.';
const _sendEmailMessageFailedLogMessage = 'Failed to send email message.';
const _sendMessageFailedLogMessage = 'Failed to send message.';
const _messageReactionFailedLogMessage = 'Failed to react to message.';
const _messageForwardFailedLogMessage = 'Failed to forward message.';
const _messageResendFailedLogMessage = 'Failed to resend message.';
const _emailResendFailedLogMessage = 'Failed to resend email message.';
const _attachmentSendFailedLogMessage = 'Failed to send attachment.';
const _xmppAttachmentSendFailedLogMessage = 'Failed to send XMPP attachment.';
const _xmppDraftSaveFailedLogMessage = 'Failed to save XMPP draft.';
const int _pinnedMessagesFetchPageLimit = 4;
const _emptyPinnedMessageItems = <PinnedMessageItem>[];
const _emptyPinnedAttachmentIds = <String>[];
const _emptyShareReplies = <String, List<Chat>>{};

class ComposerRecipient extends Equatable {
  const ComposerRecipient({
    required this.target,
    this.included = true,
    this.pinned = false,
  });

  final FanOutTarget target;
  final bool included;
  final bool pinned;

  String get key => target.key;

  ComposerRecipient copyWith({
    FanOutTarget? target,
    bool? included,
    bool? pinned,
  }) => ComposerRecipient(
    target: target ?? this.target,
    included: included ?? this.included,
    pinned: pinned ?? this.pinned,
  );

  @override
  List<Object?> get props => [target, included, pinned];
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
  final EmailAttachment? attachment;
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

  AttachmentAutoDownload get defaultChatAttachmentAutoDownload =>
      autoDownloadImages ||
          autoDownloadVideos ||
          autoDownloadDocuments ||
          autoDownloadArchives
      ? AttachmentAutoDownload.allowed
      : AttachmentAutoDownload.blocked;

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

enum MamPageDirection { before, after }

const String _availabilitySendFailureLog =
    'Failed to send availability message';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  static final Set<String> _seededDemoPendingAttachmentJids = <String>{};

  ChatBloc({
    required this.jid,
    required MessageService messageService,
    required ChatsService chatsService,
    required NotificationService notificationService,
    required MucService mucService,
    required ChatSettingsSnapshot settings,
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
       _settingsSnapshot = settings,
       super(
         ChatState(
           items: const [],
           emailServiceAvailable: emailService != null,
           emailSelfJid: emailService?.selfSenderJid,
         ),
       ) {
    on<_ChatUpdated>(_onChatUpdated);
    on<_ChatStarted>(_onChatStarted);
    on<_ChatMessagesUpdated>(_onChatMessagesUpdated);
    on<_PinnedMessagesUpdated>(_onPinnedMessagesUpdated);
    on<_FileMetadataBatchUpdated>(_onFileMetadataBatchUpdated);
    on<ChatPinnedMessagesOpened>(_onChatPinnedMessagesOpened);
    on<ChatPinnedMessageSelected>(_onChatPinnedMessageSelected);
    on<_RoomStateUpdated>(_onRoomStateUpdated);
    on<_RoomRosterUpdated>(_onRoomRosterUpdated);
    on<_RoomChatsUpdated>(_onRoomChatsUpdated);
    on<_RoomSelfAvatarUpdated>(_onRoomSelfAvatarUpdated);
    on<_EmailSyncStateChanged>(_onEmailSyncStateChanged);
    on<_EmailContactKnownChanged>(_onEmailContactKnownChanged);
    on<_XmppConnectionStateChanged>(_onXmppConnectionStateChanged);
    on<ChatMessageFocused>(_onChatMessageFocused);
    on<ChatEmailHeadersRequested>(_onChatEmailHeadersRequested);
    on<ChatEmailDebugDumpRequested>(_onChatEmailDebugDumpRequested);
    on<ChatEmailFullHtmlRequested>(_onChatEmailFullHtmlRequested);
    on<ChatEmailQuotedTextRequested>(_onChatEmailQuotedTextRequested);
    on<ChatTypingStarted>(_onChatTypingStarted);
    on<_ChatTypingStopped>(_onChatTypingStopped);
    on<_TypingParticipantsUpdated>(_onTypingParticipantsUpdated);
    on<ChatSettingsUpdated>(_onChatSettingsUpdated);
    on<ChatEmailServiceUpdated>(_onChatEmailServiceUpdated);
    on<ChatMessageSent>(
      _onChatMessageSent,
      transformer: blocThrottle(downTime),
    );
    on<ChatAvailabilityMessageSent>(_onChatAvailabilityMessageSent);
    on<ChatMuted>(_onChatMuted);
    on<ChatNotificationPreviewSettingChanged>(
      _onChatNotificationPreviewSettingChanged,
    );
    on<ChatLoadEarlier>(_onChatLoadEarlier);
    on<ChatShareSignatureToggled>(_onChatShareSignatureToggled);
    on<ChatAttachmentAutoDownloadToggled>(_onChatAttachmentAutoDownloadToggled);
    on<ChatAttachmentAutoDownloadRequested>(
      _onChatAttachmentAutoDownloadRequested,
    );
    on<ChatResponsivityChanged>(_onChatResponsivityChanged);
    on<ChatEncryptionChanged>(_onChatEncryptionChanged);
    on<ChatEncryptionRepaired>(_onChatEncryptionRepaired);
    on<ChatCapabilitiesRequested>(_onChatCapabilitiesRequested);
    on<ChatAlertHidden>(_onChatAlertHidden);
    on<ChatSpamStatusRequested>(_onChatSpamStatusRequested);
    on<ChatContactAddRequested>(_onChatContactAddRequested);
    on<ChatRecipientEmailChatRequested>(_onChatRecipientEmailChatRequested);
    on<ChatQuoteRequested>(_onChatQuoteRequested);
    on<ChatQuoteCleared>(_onChatQuoteCleared);
    on<ChatMessagePinRequested>(_onChatMessagePinRequested);
    on<ChatMessageReactionToggled>(_onChatMessageReactionToggled);
    on<ChatMessageForwardRequested>(_onChatMessageForwardRequested);
    on<ChatMessageResendRequested>(_onChatMessageResendRequested);
    on<ChatInviteRequested>(_onChatInviteRequested);
    on<ChatModerationActionRequested>(_onChatModerationActionRequested);
    on<ChatMessageEditRequested>(_onChatMessageEditRequested);
    on<ChatComposerErrorCleared>(_onChatComposerErrorCleared);
    on<_HttpUploadSupportUpdated>(_onHttpUploadSupportUpdated);
    on<ChatAttachmentPicked>(_onChatAttachmentPicked);
    on<ChatAttachmentRetryRequested>(_onChatAttachmentRetryRequested);
    on<ChatPendingAttachmentRemoved>(_onChatPendingAttachmentRemoved);
    on<ChatViewFilterChanged>(_onChatViewFilterChanged);
    on<ChatFanOutRetryRequested>(_onFanOutRetryRequested);
    on<ChatSubjectChanged>(
      _onChatSubjectChanged,
      transformer: blocDebounce(const Duration(milliseconds: 200)),
    );
    on<ChatInviteRevocationRequested>(_onInviteRevocationRequested);
    on<ChatInviteJoinRequested>(_onInviteJoinRequested);
    on<ChatLeaveRoomRequested>(_onLeaveRoomRequested);
    on<ChatNicknameChangeRequested>(_onNicknameChangeRequested);
    on<ChatRoomMembersOpened>(_onChatRoomMembersOpened);
    on<ChatRoomAvatarChangeRequested>(_onRoomAvatarChangeRequested);
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
      add(const _ChatStarted());
    }
    _emailSyncSubscription = _emailService?.syncStateStream.listen(
      (syncState) => add(_EmailSyncStateChanged(syncState)),
    );
    final initialSyncState = _emailService?.syncState;
    if (initialSyncState != null) {
      add(_EmailSyncStateChanged(initialSyncState));
    }
    if (messageService case final XmppService xmppService) {
      _xmppService = xmppService;
      add(_XmppConnectionStateChanged(xmppService.connectionState));
      _connectivitySubscription = xmppService.connectivityStream.listen(
        (connectionState) => add(_XmppConnectionStateChanged(connectionState)),
      );
      _httpUploadSupportSubscription = xmppService.httpUploadSupportStream
          .listen(
            (support) => add(_HttpUploadSupportUpdated(support.supported)),
          );
      add(_HttpUploadSupportUpdated(xmppService.httpUploadSupport.supported));
    }
    _lifecycleListener = AppLifecycleListener(
      onResume: () async {
        await _handleLifecycleResumed();
      },
      onShow: () async {
        await _handleLifecycleResumed();
      },
    );
  }

  static const messageBatchSize = 50;
  static const int _emptyMessageCount = 0;
  static const CalendarFragmentPolicy _calendarFragmentPolicy =
      CalendarFragmentPolicy();
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
  var _pendingAttachmentSeed = 0;
  var _composerHydrationSeed = 0;
  String? _lastEmailSendSignature;
  String? _lastXmppSendSignature;

  late final StreamSubscription<Chat?> _chatSubscription;
  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<List<PinnedMessageEntry>>? _pinnedSubscription;
  StreamSubscription<RoomState>? _roomSubscription;
  StreamSubscription<List<RosterItem>>? _roomRosterSubscription;
  StreamSubscription<List<Chat>>? _roomChatsSubscription;
  StreamSubscription<StoredAvatar?>? _roomSelfAvatarSubscription;
  StreamSubscription<List<String>>? _typingParticipantsSubscription;
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;
  StreamSubscription<bool>? _emailContactKnownSubscription;
  StreamSubscription<ConnectionState>? _connectivitySubscription;
  StreamSubscription<HttpUploadSupport>? _httpUploadSupportSubscription;
  StreamSubscription<Map<String, FileMetadataData?>>? _fileMetadataSubscription;
  Set<String> _trackedFileMetadataIds = const <String>{};
  var _fileMetadataRetryAttempts = _emptyMessageCount;
  var _fileMetadataSubscriptionCancelling = false;
  AppLifecycleListener? _lifecycleListener;
  var _currentMessageLimit = messageBatchSize;
  ChatMessageKey? _emailSyncComposerMessage;
  String? _mamBeforeId;
  int? _mamTotalCount;
  bool _mamComplete = false;
  bool _mamLoading = false;
  bool _mamCatchingUp = false;
  bool _mamCatchUpCompleted = false;
  bool _emailHistoryLoading = false;
  bool _pinHydrationInFlight = false;
  final Set<String> _roomAffiliationRefreshAttempts = <String>{};
  final Set<String> _autoDownloadAttemptedMetadataIds = <String>{};
  final Set<String> _autoDownloadAttemptedEmailMessages = <String>{};
  final Set<String> _shareContextAttemptedStanzaIds = <String>{};
  Future<void> _autoDownloadQueue = Future<void>.value();
  Completer<void>? _mamLoadingCompleter;
  List<RosterItem> _roomRosterItems = const <RosterItem>[];
  List<Chat> _roomChats = const <Chat>[];
  String? _roomSelfAvatarPath;
  String? _lastReadMarkerStanzaId;
  String? _lastNoticedEmailMessageId;
  int? _lastNoticedEmailCandidateCount;
  String? _lastSeenEmailSyncKey;
  int? _emailUnreadBoundaryDeltaId;
  int? _emailUnreadBoundaryUnreadCount;
  String? _lastOccupantTrackedStanzaId;
  bool _needsUnreadBootstrap = false;
  int? _pendingUnreadBoundaryCount;
  Future<void> _loadEarlierQueue = Future<void>.value();
  String? _pendingScrollTargetMessageId;

  RestartableTimer? _typingTimer;

  bool get encryptionAvailable => _omemoService != null;
  bool get _isEmailChat => state.chat?.defaultTransport.isEmail ?? false;
  String? _bareJid(String? jid) {
    return bareAddress(jid);
  }

  MessageTransport? _transportForRecipient(ComposerRecipient recipient) {
    final chat = recipient.target.chat;
    if (chat != null) {
      return chat.defaultTransport;
    }
    return recipient.target.transport;
  }

  Future<void> _markEmailMessagesDisplayedLocally(
    List<Message> messages,
  ) async {
    if (messages.isEmpty) return;
    if (_messageService case final XmppBase xmppBase) {
      final db = await xmppBase.database;
      final stanzaIds = messages
          .map((message) => message.stanzaID)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (stanzaIds.isEmpty) return;
      final chatJid = state.chat?.jid;
      if (chatJid == null || chatJid.isEmpty) return;
      if (db is XmppDrift) {
        await db.batch((batch) {
          batch.update(
            db.messages,
            const MessagesCompanion(displayed: Value(true)),
            where: (tbl) =>
                tbl.chatJid.equals(chatJid) &
                (tbl.stanzaID.isIn(stanzaIds) | tbl.originID.isIn(stanzaIds)),
          );
        });
        return;
      }
      for (final id in stanzaIds) {
        await db.markMessageDisplayed(id, chatJid: chatJid);
      }
    }
  }

  Future<void> _handleLifecycleResumed() async {
    final chat = state.chat;
    if (chat == null) return;
    await _syncReadStateForActiveChat(
      chat: chat,
      items: state.items,
      allowSend: true,
    );
  }

  Future<void> _syncReadStateForActiveChat({
    required Chat chat,
    required List<Message> items,
    required bool allowSend,
  }) async {
    if (!allowSend) {
      return;
    }
    final scopedItems = items
        .where((message) => message.chatJid == chat.jid)
        .toList(growable: false);
    final selfBare = _bareJid(_chatsService.myJid);
    final shouldSendChatReadReceipts =
        chat.markerResponsive ?? _settingsSnapshot.chatReadReceipts;
    if (shouldSendChatReadReceipts &&
        _xmppAllowedForChat(chat) &&
        chat.type != ChatType.groupChat) {
      Message? latestUnread;
      for (var i = scopedItems.length - 1; i >= 0; i--) {
        final item = scopedItems[i];
        if (item.displayed) continue;
        if (_bareJid(item.senderJid) == selfBare) continue;
        if (item.body?.isNotEmpty != true) continue;
        latestUnread = item;
        break;
      }
      final latestId = latestUnread?.stanzaID;
      if (latestId != null && latestId != _lastReadMarkerStanzaId) {
        await _messageService.sendReadMarker(chat.jid, latestId);
        _lastReadMarkerStanzaId = latestId;
      }
    }
    final emailService = _emailService;
    if (emailService == null || !chat.defaultTransport.isEmail) {
      return;
    }
    final seenCandidates = scopedItems
        .where((message) => message.deltaMsgId != null)
        .where((message) => !message.displayed)
        .where((message) => _bareJid(message.senderJid) != selfBare)
        .toList(growable: false);
    if (kEnableDemoChats && _messageService.demoOfflineMode) {
      if (seenCandidates.isNotEmpty) {
        await _markEmailMessagesDisplayedLocally(seenCandidates);
      }
      return;
    }
    if (!emailService.hasInMemoryReconnectContext) {
      return;
    }
    final latestSeenCandidateId = seenCandidates.isNotEmpty
        ? seenCandidates.last.stanzaID
        : null;
    if (seenCandidates.isNotEmpty) {
      final shouldNotify =
          _lastNoticedEmailCandidateCount != seenCandidates.length ||
          _lastNoticedEmailMessageId != latestSeenCandidateId;
      if (shouldNotify) {
        final noticed = await emailService.markNoticedChat(chat);
        if (noticed) {
          _lastNoticedEmailCandidateCount = seenCandidates.length;
          _lastNoticedEmailMessageId = latestSeenCandidateId;
        }
      }
    }
    if (seenCandidates.isEmpty) {
      _lastSeenEmailSyncKey = null;
      return;
    }
    final shouldSendEmailReadReceipts = _settingsSnapshot.emailReadReceipts;
    final seenSyncKey = [
      if (shouldSendEmailReadReceipts) 'seen' else 'displayed',
      ...seenCandidates.map(
        (message) => message.deltaMsgId?.toString() ?? message.stanzaID.trim(),
      ),
    ].join('|');
    if (seenSyncKey == _lastSeenEmailSyncKey) {
      return;
    }
    if (shouldSendEmailReadReceipts) {
      final markedSeen = await emailService.markSeenMessages(seenCandidates);
      if (markedSeen) {
        _lastSeenEmailSyncKey = seenSyncKey;
      }
    } else {
      await _markEmailMessagesDisplayedLocally(seenCandidates);
      _lastSeenEmailSyncKey = seenSyncKey;
    }
  }

  bool _xmppAllowedForChat(Chat chat) {
    if (chat.isEmailBacked) return false;
    final candidate = chat.remoteJid.isNotEmpty ? chat.remoteJid : chat.jid;
    return candidate.trim().isNotEmpty;
  }

  Future<bool> _canPageMam(Chat chat) async {
    if (!_xmppAllowedForChat(chat)) return false;
    if (state.xmppConnectionState != ConnectionState.connected) return false;
    return _messageService.resolveMamSupport();
  }

  bool _canPageEmailHistory(Chat chat) {
    if (!chat.defaultTransport.isEmail) return false;
    final status = state.emailSyncState.status;
    return status == EmailSyncStatus.ready ||
        status == EmailSyncStatus.recovering;
  }

  Future<void> sendCalendarSyncMessage({
    required String jid,
    required CalendarSyncOutbound outbound,
    required ChatType chatType,
  }) async {
    final xmppService = _xmppService;
    if (xmppService == null) return;
    await xmppService.sendCalendarSyncMessage(
      jid: jid,
      outbound: outbound,
      chatType: chatType,
    );
  }

  Future<CalendarSnapshotUploadResult> uploadCalendarSnapshot(File file) async {
    final xmppService = _xmppService;
    if (xmppService == null) {
      throw XmppMessageException();
    }
    return xmppService.uploadCalendarSnapshot(file);
  }

  bool _shouldSkipInitialMamSync(Chat chat) {
    if (chat.type != ChatType.chat) return false;
    final xmppService = _xmppService;
    if (xmppService == null) return false;
    return xmppService.hasGlobalMamSyncForCurrentSession;
  }

  Future<void> _prefetchPeerAvatar(Chat chat) async {
    if (chat.type == ChatType.groupChat) return;
    if (!_xmppAllowedForChat(chat)) return;
    final xmppService = _xmppService;
    if (xmppService == null) return;
    if (xmppService.connectionState != ConnectionState.connected) return;
    final peerJid = chat.remoteJid.isNotEmpty ? chat.remoteJid : chat.jid;
    await xmppService.prefetchAvatarForJid(peerJid);
  }

  Future<int> _archivedMessageCount(Chat chat) {
    return _messageService.countLocalMessages(
      jid: chat.remoteJid,
      filter: state.viewFilter,
      includePseudoMessages: false,
    );
  }

  String _nextPendingAttachmentId() => 'pending-${_pendingAttachmentSeed++}';

  void _beginMamLoad() {
    _mamLoading = true;
    _mamLoadingCompleter = Completer<void>();
  }

  void _finishMamLoad() {
    _mamLoading = false;
    _mamLoadingCompleter?.complete();
    _mamLoadingCompleter = null;
  }

  Future<void> _loadEarlierFromMam({required int desiredWindow}) async {
    final chat = state.chat;
    if (chat == null || _mamLoading || _mamComplete) return;
    if (!await _canPageMam(chat)) return;
    final beforeId =
        _mamBeforeId ??
        (state.items.isEmpty ? null : state.items.last.stanzaID);
    if (beforeId == null) return;
    _beginMamLoad();
    try {
      final result = await _messageService.fetchBeforeFromArchive(
        jid: chat.remoteJid,
        before: beforeId,
        pageSize: messageBatchSize,
        isMuc: chat.type == ChatType.groupChat,
      );
      await _updateMamStateFromResult(
        chat,
        result,
        direction: MamPageDirection.before,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamLoadFailedLogMessage, error, stackTrace);
    }
    _finishMamLoad();
  }

  Future<void> _loadEarlierFromEmail({required int desiredWindow}) async {
    if (_emailHistoryLoading) {
      return;
    }
    final chat = state.chat;
    final emailService = _emailService;
    if (chat == null || emailService == null) {
      return;
    }
    if (!_canPageEmailHistory(chat)) {
      return;
    }
    final items = state.items;
    if (items.isEmpty) {
      return;
    }
    final oldest = items.reversed.firstWhere(
      (message) => message.deltaMsgId != null,
      orElse: () => items.last,
    );
    _emailHistoryLoading = true;
    try {
      await emailService.backfillChatHistory(
        chat: chat,
        desiredWindow: desiredWindow,
        beforeMessageId: oldest.deltaMsgId,
        beforeTimestamp: oldest.timestamp,
        filter: state.viewFilter,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to backfill email history', error, stackTrace);
    } finally {
      _emailHistoryLoading = false;
    }
  }

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

  MessageReference? _quotedMessageReference({
    required Message quotedMessage,
    required Chat? chat,
  }) => quotedMessage.outboundReference(
    isGroupChat: chat?.type == ChatType.groupChat,
    directPolicy: chat?.type == ChatType.groupChat
        ? DirectMessageReferencePolicy.currentWire
        : DirectMessageReferencePolicy.preferOriginId,
  );

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
      if (!_canPageEmailHistory(chat)) {
        return null;
      }
      while (true) {
        final previousCount = await _archivedMessageCount(chat);
        await _loadEarlierFromEmail(
          desiredWindow: previousCount + messageBatchSize,
        );
        target = await _messageService.loadMessageByReferenceId(
          messageId,
          chatJid: chat.jid,
        );
        if (target != null) {
          await _refreshPinnedMessagesFromDatabase(chat);
          return target;
        }
        final nextCount = await _archivedMessageCount(chat);
        if (nextCount <= previousCount) {
          return null;
        }
      }
    }
    if (!await _canPageMam(chat)) {
      return null;
    }
    if (_mamBeforeId == null && state.items.isEmpty) {
      await _hydrateLatestFromMam(chat);
      target = await _messageService.loadMessageByReferenceId(
        messageId,
        chatJid: chat.jid,
      );
      if (target != null) {
        await _refreshPinnedMessagesFromDatabase(chat);
        return target;
      }
    }
    while (!_mamComplete) {
      final previousCount = await _archivedMessageCount(chat);
      await _loadEarlierFromMam(
        desiredWindow: previousCount + messageBatchSize,
      );
      target = await _messageService.loadMessageByReferenceId(
        messageId,
        chatJid: chat.jid,
      );
      if (target != null) {
        await _refreshPinnedMessagesFromDatabase(chat);
        return target;
      }
      final nextCount = await _archivedMessageCount(chat);
      if (nextCount <= previousCount) {
        return null;
      }
    }
    return null;
  }

  Future<void> _subscribeThroughMessage({
    required Chat chat,
    required Message target,
  }) async {
    final timestamp = target.timestamp;
    if (timestamp == null) {
      return;
    }
    final db = await _messageService.database;
    final throughCount = await db.countChatMessagesThrough(
      chat.jid,
      throughTimestamp: timestamp,
      throughStanzaId: target.stanzaID,
      throughDeltaMsgId: target.deltaMsgId,
      filter: state.viewFilter,
    );
    final desiredLimit = throughCount > _currentMessageLimit
        ? throughCount
        : _currentMessageLimit;
    await _subscribeToMessages(limit: desiredLimit, filter: state.viewFilter);
  }

  Future<void> _ensureUnreadWindowLoaded({
    required Chat chat,
    required int desiredWindow,
    required int unreadTargetCount,
    int? emailBoundaryDeltaId,
  }) async {
    if (unreadTargetCount <= _emptyMessageCount) {
      return;
    }
    var localCount = await _archivedMessageCount(chat);
    if (chat.defaultTransport.isEmail) {
      Message? boundaryMessage;
      if (emailBoundaryDeltaId != null) {
        boundaryMessage = await _loadEmailMessageByDeltaId(
          chat: chat,
          deltaMessageId: emailBoundaryDeltaId,
        );
      }
      if (!_canPageEmailHistory(chat)) {
        return;
      }
      var shouldAttemptNetwork = true;
      while (localCount < desiredWindow ||
          shouldAttemptNetwork ||
          (emailBoundaryDeltaId != null && boundaryMessage == null)) {
        shouldAttemptNetwork = false;
        await _loadEarlierFromEmail(desiredWindow: desiredWindow);
        final refreshed = await _archivedMessageCount(chat);
        if (emailBoundaryDeltaId != null) {
          boundaryMessage = await _loadEmailMessageByDeltaId(
            chat: chat,
            deltaMessageId: emailBoundaryDeltaId,
          );
        }
        if (refreshed <= localCount) {
          if (emailBoundaryDeltaId == null || boundaryMessage == null) {
            break;
          }
          continue;
        }
        localCount = refreshed;
      }
      return;
    }
    if (!await _canPageMam(chat)) {
      return;
    }
    if (_mamBeforeId == null && state.items.isEmpty) {
      await _hydrateLatestFromMam(chat);
      localCount = await _archivedMessageCount(chat);
    }
    var shouldAttemptNetwork = true;
    while ((localCount < desiredWindow || shouldAttemptNetwork) &&
        !_mamComplete) {
      shouldAttemptNetwork = false;
      await _loadEarlierFromMam(desiredWindow: desiredWindow);
      final refreshed = await _archivedMessageCount(chat);
      if (refreshed <= localCount) {
        break;
      }
      localCount = refreshed;
    }
  }

  Future<void> _catchUpFromMam() async {
    final chat = state.chat;
    if (chat == null) return;
    if (!await _canPageMam(chat)) return;
    final lastSeen = await _messageService.loadLastSeenTimestamp(
      chat.remoteJid,
    );
    if (lastSeen == null) return;
    if (_mamCatchingUp) return;
    if (_mamLoading && _mamLoadingCompleter != null) {
      await _mamLoadingCompleter!.future;
    }
    _mamCatchUpCompleted = false;
    _mamCatchingUp = true;
    _beginMamLoad();
    var completed = true;
    try {
      String? afterId;
      while (true) {
        final result = await _messageService.fetchSinceFromArchive(
          jid: chat.remoteJid,
          since: lastSeen,
          pageSize: messageBatchSize,
          isMuc: chat.type == ChatType.groupChat,
          after: afterId,
        );
        await _updateMamStateFromResult(
          chat,
          result,
          updateTotal: false,
          direction: MamPageDirection.after,
        );
        final nextAfter = result.lastId ?? afterId;
        if (result.complete || nextAfter == afterId || nextAfter == null) {
          break;
        }
        afterId = nextAfter;
      }
    } on Exception catch (error, stackTrace) {
      completed = false;
      _log.safeFine(_mamCatchUpFailedLogMessage, error, stackTrace);
    }
    _finishMamLoad();
    _mamCatchingUp = false;
    if (completed) {
      _mamCatchUpCompleted = true;
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
      if (state.viewFilter == effectiveFilter) {
        return;
      }
      emit(state.copyWith(viewFilter: effectiveFilter));
      await _subscribeToMessages(
        limit: _currentMessageLimit,
        filter: effectiveFilter,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_viewFilterLoadFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _onChatStarted(
    _ChatStarted event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) {
      return;
    }
    await _subscribeToMessages(
      limit: messageBatchSize,
      filter: state.viewFilter,
    );
    await _initializeViewFilter(emit);
  }

  void _resetMamCursors(bool resetContext) {
    if (!resetContext) return;
    _mamBeforeId = null;
    _mamTotalCount = null;
    _mamComplete = false;
    _mamLoading = false;
    _mamCatchingUp = false;
    _mamCatchUpCompleted = false;
    _mamLoadingCompleter?.complete();
    _mamLoadingCompleter = null;
  }

  Future<void> _hydrateLatestFromMam(Chat chat) async {
    if (!await _canPageMam(chat)) return;
    if (_mamLoading || _mamComplete || _mamBeforeId != null) return;
    final localCount = await _archivedMessageCount(chat);
    if (localCount >= _currentMessageLimit) return;
    final lastSeen = await _messageService.loadLastSeenTimestamp(
      chat.remoteJid,
    );
    final hasLocalMessages = localCount > _emptyMessageCount;
    if (lastSeen != null && hasLocalMessages) {
      if (!_mamCatchUpCompleted) {
        await _catchUpFromMam();
      }
      final refreshedCount = await _archivedMessageCount(chat);
      if (refreshedCount >= _currentMessageLimit) {
        return;
      }
    }
    _beginMamLoad();
    try {
      final result = await _messageService.fetchLatestFromArchive(
        jid: chat.remoteJid,
        pageSize: messageBatchSize,
        isMuc: chat.type == ChatType.groupChat,
      );
      await _updateMamStateFromResult(
        chat,
        result,
        direction: MamPageDirection.before,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mamHydrateFailedLogMessage, error, stackTrace);
    }
    _finishMamLoad();
  }

  Future<void> _updateMamStateFromResult(
    Chat chat,
    MamPageResult result, {
    bool updateTotal = true,
    MamPageDirection direction = MamPageDirection.before,
  }) async {
    if (direction == MamPageDirection.before) {
      _mamBeforeId = result.firstId ?? _mamBeforeId ?? result.lastId;
    } else {
      _mamBeforeId ??= result.firstId ?? result.lastId;
    }
    if (!updateTotal) {
      if (result.complete) {
        _mamComplete = true;
      }
      return;
    }

    _mamTotalCount = result.count ?? _mamTotalCount;
    if (_mamTotalCount == null) {
      _mamComplete = _mamComplete || result.complete;
      return;
    }
    final total = _mamTotalCount!;
    final localCount = await _archivedMessageCount(chat);
    _mamComplete = _mamComplete || result.complete || localCount >= total;
  }

  Future<void> _ensureMucMembership(Chat chat) async {
    if (chat.type != ChatType.groupChat) return;
    if (!_xmppAllowedForChat(chat)) return;
    if (state.xmppConnectionState != ConnectionState.connected) return;
    try {
      await _mucService.ensureJoined(
        roomJid: chat.jid,
        nickname: chat.myNickname,
        allowRejoin: true,
      );
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_mucMembershipFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _onChatRoomMembersOpened(
    ChatRoomMembersOpened event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null || chat.type != ChatType.groupChat) return;
    await _ensureMucMembership(chat);
    final roomState =
        state.roomState ??
        _mucService.roomStateFor(chat.jid) ??
        RoomState(roomJid: chat.jid);
    if (state.roomState == null) {
      emit(state.copyWith(roomState: roomState));
    }
    await _refreshRoomAffiliationsIfNeeded(chat: chat, roomState: roomState);
  }

  Future<void> _refreshRoomAffiliationsIfNeeded({
    required Chat chat,
    required RoomState roomState,
  }) async {
    if (!roomState.hasSelfPresence) return;
    if (!roomState.myAffiliation.isNone) return;
    if (state.xmppConnectionState != ConnectionState.connected) return;
    final roomJid = _bareJid(chat.jid);
    if (roomJid == null || roomJid.isEmpty) return;
    if (_roomAffiliationRefreshAttempts.contains(roomJid)) return;
    _roomAffiliationRefreshAttempts.add(roomJid);
    try {
      await _mucService.fetchRoomMembers(roomJid: roomJid);
      await _mucService.fetchRoomOwners(roomJid: roomJid);
      await _mucService.fetchRoomAdmins(roomJid: roomJid);
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_roomAffiliationRefreshFailedLogMessage, error, stackTrace);
      _roomAffiliationRefreshAttempts.remove(roomJid);
    }
  }

  Future<void> _subscribeToMessages({
    required int limit,
    required MessageTimelineFilter filter,
    bool forceXmppFallback = false,
  }) async {
    final targetJid = state.chat?.jid ?? _chatLookupJid ?? jid;
    if (targetJid == null) return;
    await _messageSubscription?.cancel();
    _currentMessageLimit = limit;
    final chat = state.chat;
    final emailService = _emailService;
    final useEmailService =
        !forceXmppFallback && chat?.defaultTransport.isEmail == true;
    if (useEmailService && emailService != null) {
      _messageSubscription = emailService
          .messageStreamForChat(targetJid, end: limit, filter: filter)
          .listen(
            (items) => add(_ChatMessagesUpdated(items)),
            onError: (Object error, StackTrace stackTrace) async {
              _log.fine('Email message stream failed', error, stackTrace);
              await _subscribeToMessages(
                limit: limit,
                filter: filter,
                forceXmppFallback: true,
              );
            },
          );
      return;
    }
    _messageSubscription = _messageService
        .messageStreamForChat(targetJid, end: limit, filter: filter)
        .listen((items) => add(_ChatMessagesUpdated(items)));
  }

  String? _resolvePinnedMessagesChatJid(Chat chat) {
    final resolvedChatJid = chat.isEmailBacked ? chat.jid : chat.remoteJid;
    final trimmedChatJid = resolvedChatJid.trim();
    if (trimmedChatJid.isEmpty) {
      return null;
    }
    return trimmedChatJid;
  }

  Future<void> _subscribeToPinnedMessages(Chat chat) async {
    final trimmedChatJid = _resolvePinnedMessagesChatJid(chat);
    await _pinnedSubscription?.cancel();
    if (trimmedChatJid == null) {
      _pinnedSubscription = null;
      return;
    }
    final emailService = _emailService;
    final useEmailService = chat.isEmailBacked;
    if (useEmailService && emailService != null) {
      _pinnedSubscription = emailService
          .pinnedMessagesStream(trimmedChatJid)
          .listen((items) => add(_PinnedMessagesUpdated(items)));
    } else {
      _pinnedSubscription = _messageService
          .pinnedMessagesStream(trimmedChatJid)
          .listen((items) => add(_PinnedMessagesUpdated(items)));
    }
    await _syncPinnedMessagesForChat(chat);
  }

  Future<void> _subscribeToTypingParticipants(Chat chat) async {
    if (!_xmppAllowedForChat(chat)) {
      await _typingParticipantsSubscription?.cancel();
      _typingParticipantsSubscription = null;
      return;
    }
    await _typingParticipantsSubscription?.cancel();
    _typingParticipantsSubscription = _chatsService
        .typingParticipantsStream(chat.jid)
        .listen(
          (participants) => add(_TypingParticipantsUpdated(participants)),
        );
  }

  Future<bool> _resolveKnownEmailContact(Chat chat) async {
    if (!chat.isEmailBacked) {
      return false;
    }
    final emailService = _emailService;
    if (emailService == null) {
      return false;
    }
    final address = normalizeEmailAddress(chat.remoteJid);
    if (address.isEmpty) {
      return false;
    }
    try {
      return await emailService.isKnownEmailContact(address);
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_emailContactLookupFailedLogMessage, error, stackTrace);
      return false;
    }
  }

  Future<void> _subscribeToKnownEmailContact(Chat chat) async {
    await _emailContactKnownSubscription?.cancel();
    _emailContactKnownSubscription = null;
    if (!chat.isEmailBacked) {
      return;
    }
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    final address = normalizeEmailAddress(chat.remoteJid);
    if (address.isEmpty) {
      return;
    }
    _emailContactKnownSubscription = emailService
        .knownEmailContactStream(address)
        .listen((known) => add(_EmailContactKnownChanged(known)));
  }

  Future<void> _syncPinnedMessagesForChat(Chat chat) async {
    final chatJid = _resolvePinnedMessagesChatJid(chat);
    if (chatJid == null) {
      return;
    }
    try {
      await _messageService.syncPinnedMessagesForChat(chatJid);
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_pinSyncFailedLogMessage, error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _chatSubscription.cancel();
    await _messageSubscription?.cancel();
    await _pinnedSubscription?.cancel();
    await _roomSubscription?.cancel();
    await _roomRosterSubscription?.cancel();
    await _roomChatsSubscription?.cancel();
    await _roomSelfAvatarSubscription?.cancel();
    await _typingParticipantsSubscription?.cancel();
    await _emailSyncSubscription?.cancel();
    await _emailContactKnownSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _httpUploadSupportSubscription?.cancel();
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
    _autoDownloadAttemptedEmailMessages.clear();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    return super.close();
  }

  Future<void> _onChatUpdated(
    _ChatUpdated event,
    Emitter<ChatState> emit,
  ) async {
    final previousChat = state.chat;
    final resetContext = previousChat?.jid != event.chat.jid;
    final typingContextChanged =
        resetContext ||
        previousChat?.defaultTransport != event.chat.defaultTransport;
    final pinnedContextChanged =
        resetContext ||
        previousChat?.defaultTransport != event.chat.defaultTransport;
    final capabilitiesShouldReset =
        resetContext ||
        previousChat?.defaultTransport != event.chat.defaultTransport;
    final knownEmailContactContextChanged =
        resetContext ||
        previousChat?.defaultTransport != event.chat.defaultTransport ||
        previousChat?.remoteJid != event.chat.remoteJid;
    final showXmppCapabilities = event.chat.defaultTransport.isXmpp;
    final typingShouldClear =
        typingContextChanged || event.chat.defaultTransport.isEmail;
    const forcedViewFilter = MessageTimelineFilter.allWithContact;
    final nextViewFilter = resetContext && event.chat.defaultTransport.isEmail
        ? forcedViewFilter
        : state.viewFilter;
    final nextEmailContactKnown = knownEmailContactContextChanged
        ? await _resolveKnownEmailContact(event.chat)
        : (event.chat.defaultTransport.isEmail
              ? state.emailContactKnown
              : false);
    final unreadCount = event.chat.unreadCount;
    final stagedUnreadCount = _chatsService.consumeOpenChatUnreadBoundarySeed(
      event.chat.jid,
    );
    emit(
      state.copyWith(
        chat: event.chat,
        showAlert: event.chat.alert != null && state.chat?.alert == null,
        fanOutReports: resetContext ? const {} : state.fanOutReports,
        fanOutDrafts: resetContext ? const {} : state.fanOutDrafts,
        shareContexts: resetContext ? const {} : state.shareContexts,
        composerError: resetContext ? null : state.composerError,
        composerHydrationText: resetContext
            ? null
            : state.composerHydrationText,
        composerHydrationId: resetContext ? 0 : state.composerHydrationId,
        composerClearId: resetContext ? 0 : state.composerClearId,
        emailSubject: resetContext ? null : state.emailSubject,
        emailSubjectAutofillEligible: resetContext
            ? true
            : state.emailSubjectAutofillEligible,
        emailSubjectAutofilled: resetContext
            ? false
            : state.emailSubjectAutofilled,
        roomState: resetContext ? null : state.roomState,
        pinnedMessages: resetContext
            ? _emptyPinnedMessageItems
            : state.pinnedMessages,
        pinnedMessagesLoaded: resetContext ? false : state.pinnedMessagesLoaded,
        pinnedMessagesHydrating: resetContext
            ? false
            : state.pinnedMessagesHydrating,
        fileMetadataById: resetContext
            ? const <String, FileMetadataData?>{}
            : state.fileMetadataById,
        unreadBoundaryStanzaId: resetContext
            ? null
            : state.unreadBoundaryStanzaId,
        xmppCapabilities: capabilitiesShouldReset || !showXmppCapabilities
            ? null
            : state.xmppCapabilities,
        emailContactKnown: nextEmailContactKnown,
        typingParticipants: typingShouldClear
            ? const []
            : state.typingParticipants,
        typing: event.chat.defaultTransport.isEmail ? false : state.typing,
        viewFilter: nextViewFilter,
      ),
    );
    _resetMamCursors(resetContext);
    if (resetContext) {
      final seededUnreadCount =
          _pendingUnreadBoundaryCount ?? stagedUnreadCount;
      _needsUnreadBootstrap =
          unreadCount > _emptyMessageCount ||
          (seededUnreadCount != null && seededUnreadCount > _emptyMessageCount);
      _pendingUnreadBoundaryCount = unreadCount > _emptyMessageCount
          ? unreadCount
          : seededUnreadCount;
    } else if (unreadCount <= _emptyMessageCount) {
      if (_pendingUnreadBoundaryCount == null &&
          stagedUnreadCount != null &&
          stagedUnreadCount > _emptyMessageCount) {
        _pendingUnreadBoundaryCount = stagedUnreadCount;
        _needsUnreadBootstrap = true;
      }
      if (_pendingUnreadBoundaryCount == null) {
        _needsUnreadBootstrap = false;
      }
    }
    if (resetContext) {
      _lastReadMarkerStanzaId = null;
      _lastNoticedEmailMessageId = null;
      _lastNoticedEmailCandidateCount = null;
      _lastSeenEmailSyncKey = null;
      _emailUnreadBoundaryDeltaId = null;
      _emailUnreadBoundaryUnreadCount = null;
      _loadEarlierQueue = Future<void>.value();
      _pendingScrollTargetMessageId = null;
      _lastOccupantTrackedStanzaId = null;
      _shareContextAttemptedStanzaIds.clear();
      _autoDownloadAttemptedMetadataIds.clear();
      _autoDownloadAttemptedEmailMessages.clear();
      await _syncFileMetadataSubscriptions(const <String>{});
      await _subscribeToMessages(
        limit: messageBatchSize,
        filter: nextViewFilter,
      );
      await _prefetchPeerAvatar(event.chat);
    }
    if (knownEmailContactContextChanged) {
      await _subscribeToKnownEmailContact(event.chat);
    }
    if (event.chat.defaultTransport.isEmail && !resetContext) {
      if (_emailUnreadBoundaryUnreadCount != unreadCount) {
        _emailUnreadBoundaryDeltaId = null;
        _emailUnreadBoundaryUnreadCount = unreadCount;
      }
    }
    if (resetContext && unreadCount > _emptyMessageCount) {
      await _resolveEmailUnreadBoundaryDeltaId(event.chat);
    }
    if (!resetContext && state.items.isNotEmpty) {
      final rawBoundary = _resolveStickyUnreadBoundaryStanzaId(
        chat: event.chat,
        messages: state.items,
        emailBoundaryDeltaId: _emailUnreadBoundaryDeltaId,
        previousBoundaryStanzaId: state.unreadBoundaryStanzaId,
        pendingUnreadBoundaryCount: _pendingUnreadBoundaryCount,
      );
      final boundary = _resolveVisibleUnreadBoundaryStanzaId(
        boundaryStanzaId: rawBoundary,
        messages: state.items,
        groupLeaderByMessageId: state.attachmentGroupLeaderByMessageId,
      );
      if (boundary != state.unreadBoundaryStanzaId) {
        emit(state.copyWith(unreadBoundaryStanzaId: boundary));
      }
      if (boundary != null) {
        _pendingUnreadBoundaryCount = null;
      }
    }
    if (typingContextChanged) {
      await _subscribeToTypingParticipants(event.chat);
    }
    if (pinnedContextChanged) {
      await _subscribeToPinnedMessages(event.chat);
    }
    if (_xmppAllowedForChat(event.chat) &&
        !_shouldSkipInitialMamSync(event.chat)) {
      await _hydrateLatestFromMam(event.chat);
    }
    if (showXmppCapabilities) {
      final capabilities = await _resolvePeerCapabilities(event.chat);
      if (capabilities != null) {
        emit(state.copyWith(xmppCapabilities: capabilities));
      }
    }
    await _roomSubscription?.cancel();
    _roomSubscription = null;
    await _roomRosterSubscription?.cancel();
    _roomRosterSubscription = null;
    await _roomChatsSubscription?.cancel();
    _roomChatsSubscription = null;
    await _roomSelfAvatarSubscription?.cancel();
    _roomSelfAvatarSubscription = null;
    _roomRosterItems = const <RosterItem>[];
    _roomChats = const <Chat>[];
    _roomSelfAvatarPath = null;
    if (event.chat.type == ChatType.groupChat) {
      _roomSubscription = _mucService.roomStateStream(event.chat.jid).listen((
        room,
      ) {
        add(_RoomStateUpdated(room));
      });
      _subscribeRoomMemberSources();
      if (resetContext || state.roomState == null) {
        await _primeRoomState(event.chat, emit);
      }
      if (!resetContext && state.items.isNotEmpty) {
        _mucService.trackOccupantsFromMessages(event.chat.jid, state.items);
      }
      await _ensureMucMembership(event.chat);
    } else {
      emit(state.copyWith(roomState: null, roomMemberSections: const []));
    }
    await _primeDemoPendingAttachment(event.chat, emit);
  }

  Future<void> _onChatCapabilitiesRequested(
    ChatCapabilitiesRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null || !chat.defaultTransport.isXmpp) {
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
    emit(
      state.copyWith(
        roomState: event.roomState,
        roomMemberSections: _buildRoomMemberSections(event.roomState),
      ),
    );
    final chat = state.chat;
    if (chat == null || chat.type != ChatType.groupChat) return;
    await _refreshRoomAffiliationsIfNeeded(
      chat: chat,
      roomState: event.roomState,
    );
  }

  void _onRoomRosterUpdated(_RoomRosterUpdated event, Emitter<ChatState> emit) {
    _roomRosterItems = event.items;
    _refreshRoomMemberSections(emit);
  }

  void _onRoomChatsUpdated(_RoomChatsUpdated event, Emitter<ChatState> emit) {
    _roomChats = event.items;
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
    _roomRosterSubscription = xmppService.rosterStream().listen((items) {
      add(_RoomRosterUpdated(items));
    });
    _roomChatsSubscription = _chatsService.chatsStream().listen((items) {
      add(_RoomChatsUpdated(items));
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
      RoomMemberSectionKind.visitors: <RoomMemberEntry>[],
    };

    for (final occupant in roomState.occupants.values) {
      if (!seen.add(occupant.occupantId)) continue;
      final kind = _memberSectionKindFor(occupant);
      membersByKind[kind]!.add(
        RoomMemberEntry(
          occupant: occupant,
          actions: _moderationActionsFor(
            occupant: occupant,
            roomState: roomState,
          ),
          avatarPath: _avatarPathForOccupant(
            occupant: occupant,
            roomState: roomState,
            avatarPathsByBareJid: avatarPathsByBareJid,
            selfAvatarPath: selfAvatarPath,
          ),
        ),
      );
    }

    for (final entries in membersByKind.values) {
      entries.sort(
        (a, b) => a.occupant.nick.toLowerCase().compareTo(
          b.occupant.nick.toLowerCase(),
        ),
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
    addSection(RoomMemberSectionKind.visitors);
    return sections;
  }

  RoomMemberSectionKind _memberSectionKindFor(Occupant occupant) {
    if (occupant.affiliation.isOwner) {
      return RoomMemberSectionKind.owners;
    }
    if (occupant.affiliation.isAdmin) {
      return RoomMemberSectionKind.admins;
    }
    if (occupant.role.isModerator) {
      return RoomMemberSectionKind.moderators;
    }
    if (occupant.affiliation.isMember) {
      return RoomMemberSectionKind.members;
    }
    return RoomMemberSectionKind.visitors;
  }

  List<MucModerationAction> _moderationActionsFor({
    required Occupant occupant,
    required RoomState roomState,
  }) {
    if (occupant.occupantId == roomState.myOccupantId) return const [];
    final myAffiliation = roomState.myAffiliation;
    final myRole = roomState.myRole;
    final isOwner = myAffiliation.isOwner;
    final isAdmin = myAffiliation.isAdmin;
    final isModerator = myRole.isModerator;
    final canSetRoles = isOwner || isAdmin || isModerator;
    final actions = <MucModerationAction>[];
    if (canSetRoles) {
      actions.add(MucModerationAction.kick);
    }
    if ((isOwner || isAdmin) && occupant.realJid?.isNotEmpty == true) {
      actions.add(MucModerationAction.ban);
    }
    if (isOwner || isAdmin) {
      if (!occupant.affiliation.isMember) {
        actions.add(MucModerationAction.member);
      }
      if (isOwner) {
        if (!occupant.affiliation.isAdmin) {
          actions.add(MucModerationAction.admin);
        }
        if (!occupant.affiliation.isOwner) {
          actions.add(MucModerationAction.owner);
        }
      }
      if (occupant.role.isModerator) {
        actions.add(MucModerationAction.participant);
      } else {
        actions.add(MucModerationAction.moderator);
      }
    }
    if (canSetRoles && !actions.contains(MucModerationAction.participant)) {
      if (occupant.role.isModerator) {
        actions.add(MucModerationAction.participant);
      }
    }
    return actions;
  }

  String? _avatarPathForOccupant({
    required Occupant occupant,
    required RoomState roomState,
    required Map<String, String> avatarPathsByBareJid,
    required String? selfAvatarPath,
  }) {
    if (occupant.occupantId == roomState.myOccupantId) {
      return selfAvatarPath;
    }
    final bareJid = _normalizedBareJid(occupant.realJid);
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
    for (final chat in _roomChats) {
      final jid = _normalizedBareJid(chat.remoteJid);
      if (jid == null) continue;
      if (avatarPaths.containsKey(jid)) continue;
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
      final warmed = await _mucService.warmRoomFromHistory(roomJid: chat.jid);
      if (_bareJid(state.chat?.jid) != _bareJid(chat.jid)) return;
      if (state.roomState != null) return;
      await _onRoomStateUpdated(_RoomStateUpdated(warmed), emit);
    } on Exception catch (error, stackTrace) {
      _log.safeFine(_roomStateWarmFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _primeDemoPendingAttachment(
    Chat chat,
    Emitter<ChatState> emit,
  ) async {
    if (!kEnableDemoChats) return;
    final chatJid = _bareJid(chat.jid);
    if (chatJid == null || chatJid != DemoChats.groupJid) return;
    if (_seededDemoPendingAttachmentJids.contains(chatJid)) return;
    _seededDemoPendingAttachmentJids.add(chatJid);
    final service = _messageService;
    if (service is! XmppService) {
      return;
    }
    final existingFileNames = state.pendingAttachments
        .map((pending) => pending.attachment.fileName)
        .toSet();
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
          attachment: EmailAttachment(
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
    if (pendingToAdd.isEmpty) return;
    emit(
      state.copyWith(
        pendingAttachments: [...state.pendingAttachments, ...pendingToAdd],
      ),
    );
  }

  Future<void> _onChatMessagesUpdated(
    _ChatMessagesUpdated event,
    Emitter<ChatState> emit,
  ) async {
    final attachmentMaps = await _loadAttachmentMaps(event.items);
    final filtered = await _filterInternalMessages(
      messages: event.items,
      attachmentsByMessageId: attachmentMaps.attachmentsByMessageId,
      groupLeaderByMessageId: attachmentMaps.groupLeaderByMessageId,
    );
    final filteredItems = filtered.messages;
    final quoteIds = filteredItems
        .map((message) => message.quoting?.trim())
        .where((id) => id?.isNotEmpty == true)
        .cast<String>()
        .toSet();
    final referencedQuotes = <String, Message>{};
    final knownMessageIds = <String>{...state.quotedMessagesById.keys};
    for (final message in filteredItems) {
      _indexMessageByReference(referencedQuotes, message);
    }
    knownMessageIds.addAll(referencedQuotes.keys);
    final missingQuoteIds = quoteIds
        .where((id) => !knownMessageIds.contains(id))
        .toList();
    final loadedQuotes = <Message>[];
    if (missingQuoteIds.isNotEmpty) {
      for (final quoteId in missingQuoteIds) {
        final message = await _messageService.loadMessageByReferenceId(
          quoteId,
          chatJid: state.chat?.jid,
        );
        if (message != null) {
          loadedQuotes.add(message);
        }
      }
    }
    final updatedQuotedMessages = <String, Message>{
      ...state.quotedMessagesById,
      ...referencedQuotes,
    };
    for (final message in loadedQuotes) {
      _indexMessageByReference(updatedQuotedMessages, message);
    }
    final emailBoundaryDeltaId = _emailUnreadBoundaryDeltaId;
    final rawUnreadBoundary = _resolveStickyUnreadBoundaryStanzaId(
      chat: state.chat,
      messages: filteredItems,
      emailBoundaryDeltaId: emailBoundaryDeltaId,
      previousBoundaryStanzaId: state.unreadBoundaryStanzaId,
      pendingUnreadBoundaryCount: _pendingUnreadBoundaryCount,
    );
    final unreadBoundary = _resolveVisibleUnreadBoundaryStanzaId(
      boundaryStanzaId: rawUnreadBoundary,
      messages: filteredItems,
      groupLeaderByMessageId: filtered.groupLeaderByMessageId,
    );
    if (unreadBoundary != null) {
      _pendingUnreadBoundaryCount = null;
    }
    final nextMetadataIds = _metadataIdsForState(
      messages: filteredItems,
      attachmentsByMessageId: filtered.attachmentsByMessageId,
      pinnedMessages: state.pinnedMessages,
    );
    await _syncFileMetadataSubscriptions(nextMetadataIds);
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
    emit(
      state.copyWith(
        items: filteredItems,
        messagesLoaded: true,
        attachmentMetadataIdsByMessageId: filtered.attachmentsByMessageId,
        attachmentGroupLeaderByMessageId: filtered.groupLeaderByMessageId,
        fileMetadataById: nextFileMetadataById,
        quotedMessagesById: updatedQuotedMessages,
        unreadBoundaryStanzaId: unreadBoundary,
        scrollTargetMessageId: shouldEmitScrollTarget
            ? pendingScrollTargetMessageId
            : state.scrollTargetMessageId,
        scrollTargetRequestId: shouldEmitScrollTarget
            ? state.scrollTargetRequestId + 1
            : state.scrollTargetRequestId,
      ),
    );
    _maybeRequestVisibleEmailFullHtml(filteredItems);
    _maybeRequestVisibleEmailQuotedText(filteredItems);
    if (state.chat?.type == ChatType.groupChat) {
      final chatJid = state.chat!.jid;
      final lastTracked = _lastOccupantTrackedStanzaId;
      var startIndex = -1;
      if (lastTracked != null) {
        for (var i = filteredItems.length - 1; i >= 0; i--) {
          if (filteredItems[i].stanzaID == lastTracked) {
            startIndex = i;
            break;
          }
        }
      }
      final newItems = startIndex == -1
          ? filteredItems
          : filteredItems.sublist(startIndex + 1);
      if (newItems.isNotEmpty) {
        _mucService.trackOccupantsFromMessages(chatJid, newItems);
      }
      if (filteredItems.isNotEmpty) {
        _lastOccupantTrackedStanzaId = filteredItems.last.stanzaID;
      }
    }
    if (state.chat?.supportsEmail == true) {
      await _hydrateShareContexts(filteredItems, emit);
      await _hydrateShareReplies(filteredItems, emit);
    }
    _queueAutoDownloadAttachments(
      messages: filteredItems,
      attachmentsByMessageId: filtered.attachmentsByMessageId,
    );

    final chat = state.chat;
    final lifecycleState = SchedulerBinding.instance.lifecycleState;
    if (chat != null) {
      await _syncReadStateForActiveChat(
        chat: chat,
        items: filteredItems,
        allowSend: lifecycleState == AppLifecycleState.resumed,
      );
    }
    await _maybeBootstrapUnreadWindow(
      chat: state.chat,
      filteredOutCount: event.items.length - filteredItems.length,
      pseudoCount: filteredItems
          .where((message) => message.pseudoMessageType != null)
          .length,
    );
  }

  String? _resolveUnreadBoundaryStanzaId({
    required Chat? chat,
    required List<Message> messages,
    int? emailBoundaryDeltaId,
  }) {
    if (chat == null) {
      return null;
    }
    if (chat.defaultTransport.isEmail && emailBoundaryDeltaId != null) {
      final boundaryMessage = _findMessageByDeltaId(
        messages,
        emailBoundaryDeltaId,
      );
      if (boundaryMessage != null && _countsTowardUnread(boundaryMessage)) {
        final stanzaId = boundaryMessage.stanzaID.trim();
        return stanzaId.isEmpty ? null : stanzaId;
      }
      return null;
    }
    final unreadCount = chat.unreadCount;
    if (unreadCount <= _emptyMessageCount) {
      return null;
    }
    var remaining = unreadCount;
    for (final message in messages) {
      if (!_countsTowardUnread(message)) {
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

  String? _resolveStickyUnreadBoundaryStanzaId({
    required Chat? chat,
    required List<Message> messages,
    required int? emailBoundaryDeltaId,
    required String? previousBoundaryStanzaId,
    required int? pendingUnreadBoundaryCount,
  }) {
    final boundary = _resolveUnreadBoundaryStanzaId(
      chat: chat,
      messages: messages,
      emailBoundaryDeltaId: emailBoundaryDeltaId,
    );
    if (boundary != null) {
      return boundary;
    }
    final previousBoundary = previousBoundaryStanzaId?.trim();
    if (previousBoundary == null || previousBoundary.isEmpty) {
      final pendingCount = pendingUnreadBoundaryCount;
      if (pendingCount == null || pendingCount <= _emptyMessageCount) {
        return null;
      }
      return _resolveUnreadBoundaryFromCount(
        messages: messages,
        unreadCount: pendingCount,
      );
    }
    for (final message in messages) {
      if (message.stanzaID == previousBoundary &&
          _countsTowardUnread(message)) {
        return previousBoundary;
      }
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
      if (!_countsTowardUnread(message)) {
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
      return boundary;
    }
    final boundaryMessageId = boundaryMessage.id;
    if (boundaryMessageId == null || boundaryMessageId.isEmpty) {
      return boundary;
    }
    final leaderId = groupLeaderByMessageId[boundaryMessageId];
    if (leaderId == null || leaderId == boundaryMessageId) {
      return boundary;
    }
    for (final message in messages) {
      if (message.id != leaderId) {
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
    final hasBody = message.body?.trim().isNotEmpty == true;
    final hasAttachment = message.fileMetadataID?.trim().isNotEmpty == true;
    final pseudoMessageType = message.pseudoMessageType;
    if (!(hasBody || hasAttachment)) {
      return false;
    }
    if (pseudoMessageType != null && !pseudoMessageType.isInvite) {
      return false;
    }
    final chat = state.chat;
    if (chat == null) {
      return true;
    }
    final selfJid = chat.defaultTransport.isEmail
        ? state.emailSelfJid
        : _chatsService.myJid;
    if (sameNormalizedAddressValue(message.senderJid, selfJid)) {
      return false;
    }
    if (chat.type == ChatType.groupChat) {
      final myOccupantId = state.roomState?.myOccupantId?.trim();
      final messageOccupantId = message.occupantID?.trim();
      if (myOccupantId != null &&
          myOccupantId.isNotEmpty &&
          messageOccupantId != null &&
          messageOccupantId.isNotEmpty &&
          messageOccupantId == myOccupantId) {
        return false;
      }
    }
    return true;
  }

  Future<int?> _resolveEmailUnreadBoundaryDeltaId(Chat? chat) async {
    if (chat == null || !chat.defaultTransport.isEmail) {
      return null;
    }
    if (chat.unreadCount <= _emptyMessageCount) {
      _emailUnreadBoundaryDeltaId = null;
      _emailUnreadBoundaryUnreadCount = null;
      return null;
    }
    if (_emailUnreadBoundaryUnreadCount == chat.unreadCount) {
      return _emailUnreadBoundaryDeltaId;
    }
    final emailService = _emailService;
    if (emailService == null) {
      return null;
    }
    final oldestDeltaId = await emailService.getOldestFreshMessageId(chat);
    _emailUnreadBoundaryDeltaId = oldestDeltaId;
    _emailUnreadBoundaryUnreadCount = chat.unreadCount;
    return oldestDeltaId;
  }

  Message? _findMessageByDeltaId(List<Message> messages, int deltaMessageId) {
    for (final message in messages) {
      if (message.deltaMsgId == deltaMessageId) {
        return message;
      }
    }
    return null;
  }

  Future<Message?> _loadEmailMessageByDeltaId({
    required Chat chat,
    required int deltaMessageId,
  }) async {
    final db = await _messageService.database;
    return db.getMessageByDeltaId(deltaMessageId, chatJid: chat.jid);
  }

  Future<void> _maybeBootstrapUnreadWindow({
    required Chat? chat,
    required int filteredOutCount,
    required int pseudoCount,
  }) async {
    if (!_needsUnreadBootstrap) {
      return;
    }
    if (chat == null) {
      _needsUnreadBootstrap = false;
      return;
    }
    final unreadTargetCount = _pendingUnreadBoundaryCount ?? chat.unreadCount;
    if (unreadTargetCount <= _emptyMessageCount) {
      _needsUnreadBootstrap = false;
      return;
    }
    _needsUnreadBootstrap = false;
    final desiredWindow = unreadTargetCount + filteredOutCount + pseudoCount;
    final desiredLimit = desiredWindow > messageBatchSize
        ? desiredWindow
        : messageBatchSize;
    final canPageNetwork = chat.defaultTransport.isEmail
        ? _canPageEmailHistory(chat)
        : await _canPageMam(chat);
    if (canPageNetwork) {
      await _ensureUnreadWindowLoaded(
        chat: chat,
        desiredWindow: desiredLimit,
        unreadTargetCount: unreadTargetCount,
        emailBoundaryDeltaId: _emailUnreadBoundaryDeltaId,
      );
    }
    if (desiredLimit != _currentMessageLimit) {
      await _subscribeToMessages(limit: desiredLimit, filter: state.viewFilter);
    }
  }

  Future<void> _onPinnedMessagesUpdated(
    _PinnedMessagesUpdated event,
    Emitter<ChatState> emit,
  ) async {
    var pinnedItems = _emptyPinnedMessageItems;
    if (event.items.isNotEmpty) {
      final orderedIds = <String>{};
      for (final entry in event.items) {
        final messageId = entry.messageStanzaId.trim();
        if (messageId.isEmpty) {
          continue;
        }
        orderedIds.add(messageId);
      }
      if (orderedIds.isNotEmpty) {
        final db = await _messageService.database;
        final messages = await db.getMessagesByReferenceIds(
          orderedIds,
          chatJid: state.chat?.jid,
        );
        final messageByReference = <String, Message>{};
        for (final message in state.items) {
          _indexMessageByReference(messageByReference, message);
        }
        for (final message in messages) {
          _indexMessageByReference(messageByReference, message);
        }
        final attachmentMaps = await _loadAttachmentMaps(messages);
        pinnedItems = <PinnedMessageItem>[];
        for (final entry in event.items) {
          final messageId = entry.messageStanzaId.trim();
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
    emit(
      state.copyWith(
        pinnedMessages: pinnedItems,
        pinnedMessagesLoaded: true,
        fileMetadataById: _pruneFileMetadataById(
          metadataIds: nextMetadataIds,
          existing: state.fileMetadataById,
        ),
      ),
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

  Future<void> _syncFileMetadataSubscriptions(Set<String> metadataIds) async {
    final normalizedIds = <String>{
      for (final id in metadataIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
    final sameIds =
        normalizedIds.length == _trackedFileMetadataIds.length &&
        normalizedIds.containsAll(_trackedFileMetadataIds);
    if (sameIds && _fileMetadataSubscription != null) {
      return;
    }
    if (!sameIds) {
      _fileMetadataRetryAttempts = _emptyMessageCount;
    }
    _trackedFileMetadataIds = normalizedIds;
    final previous = _fileMetadataSubscription;
    _fileMetadataSubscription = null;
    if (previous != null) {
      _fileMetadataSubscriptionCancelling = true;
      try {
        await previous.cancel();
      } finally {
        _fileMetadataSubscriptionCancelling = false;
      }
    }
    if (normalizedIds.isEmpty) {
      return;
    }
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
    if (_pinHydrationInFlight) {
      return;
    }
    var missing = _missingPinnedMessageIds(state.pinnedMessages);
    if (missing.isEmpty) {
      if (state.pinnedMessagesHydrating) {
        emit(state.copyWith(pinnedMessagesHydrating: false));
      }
      return;
    }
    _pinHydrationInFlight = true;
    emit(state.copyWith(pinnedMessagesHydrating: true));
    try {
      if (chat.isEmailBacked) {
        await _hydratePinnedMessagesFromEmail(chat, missing);
      } else {
        await _hydratePinnedMessagesFromMam(chat, missing);
      }
    } finally {
      _pinHydrationInFlight = false;
      emit(state.copyWith(pinnedMessagesHydrating: false));
    }
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
      emit(state.copyWith(viewFilter: MessageTimelineFilter.allWithContact));
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

  Future<void> _hydratePinnedMessagesFromMam(
    Chat chat,
    Set<String> missingStanzaIds,
  ) async {
    if (!_xmppAllowedForChat(chat)) {
      return;
    }
    if (_mamBeforeId == null && state.items.isEmpty) {
      await _hydrateLatestFromMam(chat);
      missingStanzaIds = await _pruneResolvedPinnedMessages(missingStanzaIds);
      await _refreshPinnedMessagesFromDatabase(chat);
    }
    for (
      var attempt = 0;
      attempt < _pinnedMessagesFetchPageLimit && missingStanzaIds.isNotEmpty;
      attempt += 1
    ) {
      final localCount = await _archivedMessageCount(chat);
      final desiredWindow = localCount + messageBatchSize;
      await _loadEarlierFromMam(desiredWindow: desiredWindow);
      missingStanzaIds = await _pruneResolvedPinnedMessages(missingStanzaIds);
      await _refreshPinnedMessagesFromDatabase(chat);
      if (_mamComplete) {
        break;
      }
    }
  }

  Future<void> _hydratePinnedMessagesFromEmail(
    Chat chat,
    Set<String> missingStanzaIds,
  ) async {
    for (
      var attempt = 0;
      attempt < _pinnedMessagesFetchPageLimit && missingStanzaIds.isNotEmpty;
      attempt += 1
    ) {
      final localCount = await _archivedMessageCount(chat);
      final desiredWindow = localCount + messageBatchSize;
      await _loadEarlierFromEmail(desiredWindow: desiredWindow);
      missingStanzaIds = await _pruneResolvedPinnedMessages(missingStanzaIds);
      await _refreshPinnedMessagesFromDatabase(chat);
    }
  }

  Future<Set<String>> _pruneResolvedPinnedMessages(
    Set<String> missingStanzaIds,
  ) async {
    if (missingStanzaIds.isEmpty) {
      return missingStanzaIds;
    }
    final db = await _messageService.database;
    final resolvedMessages = await db.getMessagesByReferenceIds(
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
    final pinnedChatJid = _resolvePinnedMessagesChatJid(chat);
    if (pinnedChatJid == null) {
      return;
    }
    final db = await _messageService.database;
    final entries = await db.getPinnedMessages(pinnedChatJid);
    add(_PinnedMessagesUpdated(entries));
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
    final password = data['password'] as String?;
    if (roomJid == null) return;
    if (invitee != null &&
        _chatsService.myJid != null &&
        mox.JID.fromString(invitee).toBare().toString() !=
            mox.JID.fromString(_chatsService.myJid!).toBare().toString()) {
      return;
    }
    try {
      await _mucService.acceptRoomInvite(
        roomJid: roomJid,
        roomName: roomName,
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
    if (chatJid.isEmpty || event.chatType != ChatType.groupChat) return;
    try {
      await _mucService.leaveRoom(chatJid);
      emit(state.copyWith(roomState: null));
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to leave room $chatJid', error, stackTrace);
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
    final chat = event.chat;
    if (chat.type != ChatType.groupChat || event.roomState == null) {
      return;
    }
    final occupant = event.roomState!.occupants[event.occupantId];
    if (occupant == null) return;
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
    } catch (error, stackTrace) {
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
    }
  }

  void _onEmailSyncStateChanged(
    _EmailSyncStateChanged event,
    Emitter<ChatState> emit,
  ) {
    _applyEmailSyncState(event.state, emit);
  }

  void _onEmailContactKnownChanged(
    _EmailContactKnownChanged event,
    Emitter<ChatState> emit,
  ) {
    if (state.emailContactKnown == event.known) {
      return;
    }
    emit(state.copyWith(emailContactKnown: event.known));
  }

  void _applyEmailSyncState(EmailSyncState nextState, Emitter<ChatState> emit) {
    if (!_isEmailChat) {
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
    final stateChanged = state.xmppConnectionState != event.state;
    if (stateChanged) {
      emit(state.copyWith(xmppConnectionState: event.state));
    }
    final chat = state.chat;
    if (event.state != ConnectionState.connected || chat == null) {
      return;
    }
    if (chat.type == ChatType.groupChat) {
      await _ensureMucMembership(chat);
    }
    if (!_xmppAllowedForChat(chat)) {
      return;
    }
    final streamReady = _xmppService?.lastStreamReady;
    final shouldCatchUp = streamReady?.isResumed != true;
    if (shouldCatchUp && !_shouldSkipInitialMamSync(chat)) {
      await _catchUpFromMam();
    }
    await _prefetchPeerAvatar(chat);
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
        final updatedItems = List<Message>.from(state.items)
          ..removeWhere((msg) => msg.stanzaID == fetched.stanzaID)
          ..add(fetched)
          ..sort(
            (a, b) => (b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );
        emit(state.copyWith(items: updatedItems, focused: fetched));
        _maybeRequestEmailHeaders(fetched);
        _maybeRequestEmailDebugDump(fetched);
        _maybeRequestEmailFullHtml(fetched);
        _maybeRequestEmailQuotedText(fetched);
        return;
      }
    }
    emit(state.copyWith(focused: target));
    _maybeRequestEmailHeaders(target);
    _maybeRequestEmailDebugDump(target);
    _maybeRequestEmailFullHtml(target);
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
      headers = await emailService.getMessageRawHeaders(
        deltaMessageId,
        accountId: message.deltaAccountId,
      );
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

  Future<void> _onChatEmailDebugDumpRequested(
    ChatEmailDebugDumpRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    final deltaMessageId = message.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return;
    }
    if (state.emailDebugDumpByDeltaId.containsKey(deltaMessageId)) {
      return;
    }
    if (state.emailDebugDumpLoading.contains(deltaMessageId)) {
      return;
    }
    final loading = Set<int>.from(state.emailDebugDumpLoading)
      ..add(deltaMessageId);
    final unavailable = Set<int>.from(state.emailDebugDumpUnavailable)
      ..remove(deltaMessageId);
    emit(
      state.copyWith(
        emailDebugDumpLoading: loading,
        emailDebugDumpUnavailable: unavailable,
      ),
    );
    final emailService = _emailService;
    if (emailService == null) {
      final updatedLoading = Set<int>.from(state.emailDebugDumpLoading)
        ..remove(deltaMessageId);
      final updatedUnavailable = Set<int>.from(state.emailDebugDumpUnavailable)
        ..add(deltaMessageId);
      emit(
        state.copyWith(
          emailDebugDumpLoading: updatedLoading,
          emailDebugDumpUnavailable: updatedUnavailable,
        ),
      );
      return;
    }
    String? debugDump;
    try {
      debugDump = await emailService.getMessageDebugDump(message);
    } on Exception {
      debugDump = null;
    }
    final updatedLoading = Set<int>.from(state.emailDebugDumpLoading)
      ..remove(deltaMessageId);
    if (debugDump == null || debugDump.trim().isEmpty) {
      final updatedUnavailable = Set<int>.from(state.emailDebugDumpUnavailable)
        ..add(deltaMessageId);
      emit(
        state.copyWith(
          emailDebugDumpLoading: updatedLoading,
          emailDebugDumpUnavailable: updatedUnavailable,
        ),
      );
      return;
    }
    final updatedDebugDumps = Map<int, String>.from(
      state.emailDebugDumpByDeltaId,
    )..[deltaMessageId] = debugDump;
    emit(
      state.copyWith(
        emailDebugDumpLoading: updatedLoading,
        emailDebugDumpByDeltaId: updatedDebugDumps,
      ),
    );
  }

  Future<void> _onChatEmailFullHtmlRequested(
    ChatEmailFullHtmlRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    final deltaMessageId = message.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return;
    }
    if (state.emailFullHtmlByDeltaId.containsKey(deltaMessageId)) {
      return;
    }
    if (state.emailFullHtmlLoading.contains(deltaMessageId)) {
      return;
    }
    final loading = Set<int>.from(state.emailFullHtmlLoading)
      ..add(deltaMessageId);
    final unavailable = Set<int>.from(state.emailFullHtmlUnavailable)
      ..remove(deltaMessageId);
    emit(
      state.copyWith(
        emailFullHtmlLoading: loading,
        emailFullHtmlUnavailable: unavailable,
      ),
    );
    final emailService = _emailService;
    if (emailService == null) {
      final updatedLoading = Set<int>.from(state.emailFullHtmlLoading)
        ..remove(deltaMessageId);
      final updatedUnavailable = Set<int>.from(state.emailFullHtmlUnavailable)
        ..add(deltaMessageId);
      emit(
        state.copyWith(
          emailFullHtmlLoading: updatedLoading,
          emailFullHtmlUnavailable: updatedUnavailable,
        ),
      );
      return;
    }
    String? fullHtml;
    try {
      fullHtml = await emailService.getMessageFullHtml(message);
    } on Exception {
      fullHtml = null;
    }
    final updatedLoading = Set<int>.from(state.emailFullHtmlLoading)
      ..remove(deltaMessageId);
    if (fullHtml == null || fullHtml.trim().isEmpty) {
      final updatedUnavailable = Set<int>.from(state.emailFullHtmlUnavailable)
        ..add(deltaMessageId);
      emit(
        state.copyWith(
          emailFullHtmlLoading: updatedLoading,
          emailFullHtmlUnavailable: updatedUnavailable,
        ),
      );
      return;
    }
    final updatedHtml = Map<int, String>.from(state.emailFullHtmlByDeltaId)
      ..[deltaMessageId] = fullHtml;
    emit(
      state.copyWith(
        emailFullHtmlLoading: updatedLoading,
        emailFullHtmlByDeltaId: updatedHtml,
      ),
    );
  }

  Future<void> _onChatEmailQuotedTextRequested(
    ChatEmailQuotedTextRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    final deltaMessageId = message.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return;
    }
    if (state.emailQuotedTextByDeltaId.containsKey(deltaMessageId)) {
      return;
    }
    if (state.emailQuotedTextLoading.contains(deltaMessageId)) {
      return;
    }
    final loading = Set<int>.from(state.emailQuotedTextLoading)
      ..add(deltaMessageId);
    final unavailable = Set<int>.from(state.emailQuotedTextUnavailable)
      ..remove(deltaMessageId);
    emit(
      state.copyWith(
        emailQuotedTextLoading: loading,
        emailQuotedTextUnavailable: unavailable,
      ),
    );
    final emailService = _emailService;
    if (emailService == null) {
      final updatedLoading = Set<int>.from(state.emailQuotedTextLoading)
        ..remove(deltaMessageId);
      final updatedUnavailable = Set<int>.from(state.emailQuotedTextUnavailable)
        ..add(deltaMessageId);
      emit(
        state.copyWith(
          emailQuotedTextLoading: updatedLoading,
          emailQuotedTextUnavailable: updatedUnavailable,
        ),
      );
      return;
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
    final updatedLoading = Set<int>.from(state.emailQuotedTextLoading)
      ..remove(deltaMessageId);
    if (sanitizedQuotedText.isEmpty) {
      final updatedUnavailable = Set<int>.from(state.emailQuotedTextUnavailable)
        ..add(deltaMessageId);
      emit(
        state.copyWith(
          emailQuotedTextLoading: updatedLoading,
          emailQuotedTextUnavailable: updatedUnavailable,
        ),
      );
      return;
    }
    final updatedQuotedText = Map<int, String>.from(
      state.emailQuotedTextByDeltaId,
    )..[deltaMessageId] = sanitizedQuotedText;
    emit(
      state.copyWith(
        emailQuotedTextLoading: updatedLoading,
        emailQuotedTextByDeltaId: updatedQuotedText,
      ),
    );
  }

  void _maybeRequestEmailHeaders(Message? message) {
    final deltaMessageId = message?.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return;
    }
    if (state.emailRawHeadersByDeltaId.containsKey(deltaMessageId)) {
      return;
    }
    if (state.emailRawHeadersLoading.contains(deltaMessageId)) {
      return;
    }
    add(ChatEmailHeadersRequested(message!));
  }

  void _maybeRequestEmailDebugDump(Message? message) {
    final deltaMessageId = message?.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return;
    }
    if (state.emailDebugDumpByDeltaId.containsKey(deltaMessageId)) {
      return;
    }
    if (state.emailDebugDumpLoading.contains(deltaMessageId)) {
      return;
    }
    add(ChatEmailDebugDumpRequested(message!));
  }

  void _maybeRequestEmailFullHtml(Message? message) {
    final deltaMessageId = message?.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return;
    }
    final htmlBody = message?.htmlBody?.trim();
    if (htmlBody != null && htmlBody.isNotEmpty) {
      return;
    }
    if (state.emailFullHtmlByDeltaId.containsKey(deltaMessageId)) {
      return;
    }
    if (state.emailFullHtmlLoading.contains(deltaMessageId)) {
      return;
    }
    if (state.emailFullHtmlUnavailable.contains(deltaMessageId)) {
      return;
    }
    add(ChatEmailFullHtmlRequested(message!));
  }

  void _maybeRequestVisibleEmailFullHtml(List<Message> messages) {
    for (final message in messages) {
      _maybeRequestEmailFullHtml(message);
    }
  }

  void _maybeRequestEmailQuotedText(Message? message) {
    final deltaMessageId = message?.deltaMsgId;
    if (deltaMessageId == null || deltaMessageId <= _deltaMessageIdUnset) {
      return;
    }
    final htmlBody = message?.htmlBody?.trim();
    if (htmlBody != null && htmlBody.isNotEmpty) {
      return;
    }
    if (state.emailQuotedTextByDeltaId.containsKey(deltaMessageId)) {
      return;
    }
    if (state.emailQuotedTextLoading.contains(deltaMessageId)) {
      return;
    }
    if (state.emailQuotedTextUnavailable.contains(deltaMessageId)) {
      return;
    }
    add(ChatEmailQuotedTextRequested(message!));
  }

  void _maybeRequestVisibleEmailQuotedText(List<Message> messages) {
    for (final message in messages) {
      _maybeRequestEmailQuotedText(message);
    }
  }

  Future<void> _onChatTypingStarted(
    ChatTypingStarted event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    if (chat.defaultTransport.isEmail) {
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

  Future<void> _onChatMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    _stopTyping(chat: event.chat);
    emit(state.copyWith(typing: false));
    final chat = event.chat;
    final subject = event.subject;
    final quotedDraft = event.quotedDraft;
    final settings = event.settings;
    final recipients = event.recipients
        .where((recipient) => recipient.included)
        .toList(growable: false);
    if (recipients.isEmpty) {
      return;
    }
    final storedStanzaIds = <String>{};
    final trimmedText = event.text.trim();
    final CalendarTask? requestedTask = event.calendarTaskIcs;
    final bool taskReadOnly = event.calendarTaskIcsReadOnly;
    final CalendarFragmentShareDecision fragmentDecision =
        _calendarFragmentPolicy.decisionForChat(
          chat: chat,
          roomState: event.roomState,
        );
    final CalendarTask? effectiveTaskForXmpp =
        requestedTask == null || !fragmentDecision.canWrite
        ? null
        : requestedTask;
    final CalendarTask? effectiveTaskForEmail = requestedTask;
    final attachments = List<PendingAttachment>.from(event.pendingAttachments);
    final queuedAttachments = attachments
        .where(
          (attachment) =>
              attachment.status == PendingAttachmentStatus.queued &&
              !attachment.isPreparing,
        )
        .toList();
    final hasQueuedAttachments = queuedAttachments.isNotEmpty;
    final bool hasCalendarTaskIcs = effectiveTaskForEmail != null;
    final hasSubject = subject?.trim().isNotEmpty == true;
    final hasBody = trimmedText.isNotEmpty;
    final emailBody = hasBody ? trimmedText : (hasSubject ? '' : null);
    final emailBodyTrimmed = emailBody?.trim();
    final emailHtmlBody = switch (emailBodyTrimmed) {
      final value? when value.isNotEmpty => HtmlContentCodec.fromPlainText(
        value,
      ),
      _ => null,
    };
    final syntheticEmailReply = _syntheticEmailReplyEnvelope(
      body: trimmedText,
      subject: subject,
      quotedDraft: quotedDraft,
    );
    final emailReplyHtmlBody = hasBody
        ? HtmlContentCodec.fromPlainText(trimmedText)
        : null;
    if (trimmedText.isEmpty &&
        !hasQueuedAttachments &&
        !hasSubject &&
        !hasCalendarTaskIcs) {
      emit(
        state.copyWith(composerError: ChatMessageKey.chatComposerEmptyMessage),
      );
      return;
    }
    if (state.composerError != null) {
      emit(state.copyWith(composerError: null));
    }
    if (chat.type == ChatType.groupChat) {
      await _ensureMucMembership(chat);
    }
    final split = _splitRecipientsForSend(
      recipients: recipients,
      forceEmail: false,
    );
    final emailRecipients = split.emailRecipients;
    final xmppRecipients = split.xmppRecipients;
    final rawAttachmentsViaEmail =
        (hasQueuedAttachments || hasCalendarTaskIcs) &&
        emailRecipients.isNotEmpty;
    final rawAttachmentsViaXmpp =
        hasQueuedAttachments && xmppRecipients.isNotEmpty;
    final rawRequiresEmail =
        emailRecipients.isNotEmpty || rawAttachmentsViaEmail;
    final rawRequiresXmpp = xmppRecipients.isNotEmpty || rawAttachmentsViaXmpp;
    final xmppBody = _composeXmppBody(body: trimmedText, subject: subject);
    final hasXmppBody = xmppBody.isNotEmpty;
    final CalendarTask? taskForXmpp = hasQueuedAttachments
        ? null
        : effectiveTaskForXmpp;
    final Chat? soleRecipientChat = xmppRecipients.length == 1
        ? xmppRecipients.first.target.chat
        : null;
    final CalendarTask? fanOutTask = soleRecipientChat?.jid == chat.jid
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
    final service = _emailService;
    if (requiresEmail && service == null) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerEmailUnavailable,
        ),
      );
      return;
    }
    if (attachmentsViaXmpp && !event.supportsHttpFileUpload) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerFileUploadUnavailable,
        ),
      );
      return;
    }
    final invalidEmailRecipients = requiresEmail
        ? emailRecipients.where((recipient) {
            final targetChat = recipient.target.chat;
            if (targetChat != null) {
              return !_isEmailCapableChat(targetChat);
            }
            return recipient.target.address?.isNotEmpty != true;
          })
        : const <ComposerRecipient>[];
    if (requiresEmail && emailRecipients.isEmpty) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerSelectRecipient,
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
      return;
    }
    emit(state.copyWith(composerClearId: state.composerClearId + 1));
    var emailSendSucceeded = emailAlreadySent;
    var xmppSendSucceeded = xmppAlreadySent;
    try {
      if (requiresEmail) {
        final EmailService emailService = service!;
        var emailTextSent = false;
        var emailAttachmentsSent = !attachmentsViaEmail;
        final bool hasQueuedEmailAttachments = queuedAttachments.isNotEmpty;
        final bool shouldSendCalendarTaskAttachment = hasCalendarTaskIcs;
        final shouldBundleEmailAttachments =
            attachmentsViaEmail && queuedAttachments.length > 1;
        EmailAttachment? bundledEmailAttachment;
        if (shouldBundleEmailAttachments) {
          _markPendingAttachmentsPreparing(
            queuedAttachments,
            emit,
            preparing: true,
          );
          try {
            bundledEmailAttachment = await _bundlePendingAttachments(
              attachments: queuedAttachments,
              caption: emailBodyTrimmed?.isNotEmpty == true ? emailBody : null,
            );
          } on Exception catch (error, stackTrace) {
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
            _markPendingAttachmentsPreparing(
              queuedAttachments,
              emit,
              preparing: false,
            );
          }
        }
        final shouldSendEmailText = emailBody != null && !attachmentsViaEmail;
        if (shouldSendEmailText) {
          final shouldFanOut = _shouldFanOut(emailRecipients, chat);
          final effectiveEmailSubject = shouldFanOut
              ? (syntheticEmailReply?.subject ?? subject)
              : subject;
          final effectiveEmailBody = shouldFanOut
              ? (syntheticEmailReply?.body ?? emailBody)
              : emailBody;
          final effectiveEmailHtmlBody = shouldFanOut
              ? (syntheticEmailReply?.htmlBody ?? emailHtmlBody)
              : emailHtmlBody;
          if (shouldFanOut) {
            final sent = await _sendFanOut(
              recipients: emailRecipients,
              text: effectiveEmailBody,
              htmlBody: effectiveEmailHtmlBody,
              subject: effectiveEmailSubject,
              quotedStanzaId: syntheticEmailReply?.quotedStanzaId,
              chat: chat,
              settings: settings,
              emit: emit,
            );
            if (!sent) {
              return;
            }
          } else {
            if (quotedDraft != null) {
              await emailService.sendReply(
                chat: chat,
                body: trimmedText,
                quotedMessage: quotedDraft,
                subject: subject,
                htmlBody: emailReplyHtmlBody,
              );
            } else {
              await emailService.sendMessage(
                chat: chat,
                body: emailBody,
                subject: subject,
                htmlBody: emailHtmlBody,
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
          final htmlCaptionForAttachments = captionForAttachments == null
              ? null
              : emailHtmlBody;
          final calendarTaskCaption =
              captionForAttachments ?? event.calendarTaskShareText;
          var queuedAttachmentsSent = !hasQueuedEmailAttachments;
          if (hasQueuedEmailAttachments) {
            final attachmentsSent = shouldBundleEmailAttachments
                ? await _sendBundledEmailAttachments(
                    attachments: queuedAttachments,
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
                    htmlCaptionForBundle: htmlCaptionForAttachments,
                  )
                : await _sendQueuedAttachments(
                    attachments: queuedAttachments,
                    chat: chat,
                    service: emailService,
                    recipients: emailRecipients,
                    emit: emit,
                    subject: subject,
                    quotedDraft: quotedDraft,
                    settings: settings,
                    retainOnSuccess: attachmentsViaXmpp,
                    captionForFirstAttachment: captionForAttachments,
                    htmlCaptionForFirstAttachment: htmlCaptionForAttachments,
                  );
            if (!attachmentsSent) {
              return;
            }
            queuedAttachmentsSent = true;
          }
          var calendarTaskSent = !shouldSendCalendarTaskAttachment;
          if (shouldSendCalendarTaskAttachment) {
            final sent = await _sendCalendarTaskEmailAttachment(
              task: effectiveTaskForEmail,
              taskReadOnly: taskReadOnly,
              chat: chat,
              service: emailService,
              recipients: emailRecipients,
              emit: emit,
              subject: subject,
              quotedDraft: quotedDraft,
              settings: settings,
              caption: calendarTaskCaption,
              htmlCaption: htmlCaptionForAttachments,
            );
            if (!sent) {
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
      var xmppBodySent = !(shouldAttemptXmppFanOut || shouldAttemptXmppDirect);
      var xmppCalendarTaskSent = false;
      if (attachmentsViaXmpp) {
        final sent = await _sendXmppAttachments(
          attachments: queuedAttachments,
          chat: chat,
          recipients: xmppRecipients,
          emit: emit,
          supportsHttpFileUpload: event.supportsHttpFileUpload,
          subject: subject,
          quotedDraft: quotedDraft,
          caption: hasXmppBody ? xmppBody : null,
          onLocalMessageStored: storedStanzaIds.add,
        );
        if (!sent) {
          return;
        }
        xmppAttachmentsSent = true;
        _messageService.notifyDemoOutboundAttachmentMessage(chatJid: chat.jid);
      }
      if (shouldAttemptXmppFanOut) {
        await _sendXmppFanOut(
          recipients: xmppRecipients,
          body: xmppBody,
          calendarTaskIcs: fanOutTask,
          calendarTaskIcsReadOnly: taskReadOnly,
          quotedDraft: quotedDraft,
          onLocalMessageStored: storedStanzaIds.add,
        );
        xmppBodySent = true;
        if (fanOutTask != null) {
          xmppCalendarTaskSent = true;
        }
      } else if (shouldAttemptXmppDirect) {
        final sameChatQuote =
            quotedDraft != null && quotedDraft.chatJid == chat.jid
            ? quotedDraft
            : null;
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
        xmppBodySent = true;
        if (taskForXmpp != null) {
          xmppCalendarTaskSent = true;
        }
      }
      if (xmppCalendarTaskSent) {
        _messageService.notifyDemoOutboundAttachmentMessage(chatJid: chat.jid);
        if (kEnableDemoChats) {
          final preview = event.calendarTaskShareText?.trim().isNotEmpty == true
              ? event.calendarTaskShareText!.trim()
              : event.attachmentFallbackLabel;
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
    } on XmppMessageException catch (error, stackTrace) {
      _log.safeWarning(_sendMessageFailedLogMessage, error, stackTrace);
      if (storedStanzaIds.isEmpty) {
        await _saveXmppDraft(
          chat: chat,
          recipients: xmppRecipients,
          body: trimmedText,
          attachments: queuedAttachments,
          subject: subject,
          quotedDraft: quotedDraft,
          emit: emit,
        );
      }
    } on Exception catch (error, stackTrace) {
      _log.safeWarning(_sendMessageFailedLogMessage, error, stackTrace);
      if (storedStanzaIds.isEmpty) {
        await _saveXmppDraft(
          chat: chat,
          recipients: xmppRecipients,
          body: trimmedText,
          attachments: queuedAttachments,
          subject: subject,
          quotedDraft: quotedDraft,
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
        _removePendingAttachmentsByIds(
          queuedAttachments.map((pending) => pending.id),
          emit,
        );
      }
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
    if (chat.defaultTransport.isEmail) {
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

  Future<void> _onChatNotificationPreviewSettingChanged(
    ChatNotificationPreviewSettingChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    await _chatsService.setChatNotificationPreviewSetting(
      jid: chat.jid,
      setting: event.setting,
    );
    emit(
      state.copyWith(
        chat: chat.copyWith(notificationPreviewSetting: event.setting),
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
    await emailSub?.cancel();
    _emailService = emailService;
    final shouldResetEmailAvailability = emailService != null;
    emit(
      state.copyWith(
        emailServiceAvailable: emailService != null,
        emailContactKnown: emailService == null
            ? false
            : state.emailContactKnown,
        emailSelfJid: emailService?.selfSenderJid,
        emailRawHeadersUnavailable: shouldResetEmailAvailability
            ? const <int>{}
            : state.emailRawHeadersUnavailable,
        emailDebugDumpUnavailable: shouldResetEmailAvailability
            ? const <int>{}
            : state.emailDebugDumpUnavailable,
        emailFullHtmlUnavailable: shouldResetEmailAvailability
            ? const <int>{}
            : state.emailFullHtmlUnavailable,
        emailQuotedTextUnavailable: shouldResetEmailAvailability
            ? const <int>{}
            : state.emailQuotedTextUnavailable,
      ),
    );
    if (emailService != null) {
      _emailSyncSubscription = emailService.syncStateStream.listen(
        (syncState) => add(_EmailSyncStateChanged(syncState)),
      );
      _applyEmailSyncState(emailService.syncState, emit);
      _maybeRequestVisibleEmailFullHtml(state.items);
      _maybeRequestEmailFullHtml(state.focused);
      _maybeRequestEmailQuotedText(state.focused);
    } else {
      _applyEmailSyncState(const EmailSyncState.ready(), emit);
    }
    final chat = state.chat;
    if (chat == null) {
      return;
    }
    emit(
      state.copyWith(emailContactKnown: await _resolveKnownEmailContact(chat)),
    );
    await _subscribeToKnownEmailContact(chat);
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
    await _chatsService.toggleChatShareSignature(
      jid: chat.jid,
      enabled: event.enabled,
    );
    emit(
      state.copyWith(chat: chat.copyWith(shareSignatureEnabled: event.enabled)),
    );
  }

  Future<void> _onChatAttachmentAutoDownloadToggled(
    ChatAttachmentAutoDownloadToggled event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    await _chatsService.toggleChatAttachmentAutoDownload(
      jid: chat.jid,
      enabled: event.enabled,
    );
    final value = event.enabled
        ? AttachmentAutoDownload.allowed
        : AttachmentAutoDownload.blocked;
    emit(state.copyWith(chat: chat.copyWith(attachmentAutoDownload: value)));
    if (event.enabled) {
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
    await _chatsService.toggleChatMarkerResponsive(
      jid: chatJid,
      responsive: event.responsive,
    );
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
    try {
      await _enqueueLoadEarlier();
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _enqueueLoadEarlier() {
    _loadEarlierQueue = _loadEarlierQueue.then((_) async {
      try {
        final chat = state.chat;
        if (chat == null) {
          return;
        }
        final chatJid = chat.jid;
        final nextLimit = state.items.length + messageBatchSize;
        await _subscribeToMessages(limit: nextLimit, filter: state.viewFilter);
        if (state.chat?.jid != chatJid) {
          return;
        }
        final canPageNetwork = chat.defaultTransport.isEmail
            ? _canPageEmailHistory(chat)
            : await _canPageMam(chat) && !_mamComplete;
        if (!canPageNetwork) {
          return;
        }
        if (chat.defaultTransport.isEmail) {
          await _loadEarlierFromEmail(desiredWindow: nextLimit);
          return;
        }
        await _loadEarlierFromMam(desiredWindow: nextLimit);
      } on Exception catch (error, stackTrace) {
        _log.safeFine('Failed to load earlier', error, stackTrace);
      }
    });
    return _loadEarlierQueue;
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
    final chat = event.chat;
    final remoteJid = chat.remoteJid.trim();
    if (remoteJid.isEmpty) {
      return;
    }
    final rosterTitle = chat.contactDisplayName?.trim().isNotEmpty == true
        ? chat.contactDisplayName!.trim()
        : chat.title;
    var nextState = state;
    try {
      if (chat.isEmailBacked) {
        final emailService = _emailService;
        if (emailService == null) {
          return;
        }
        await emailService.ensureChatForAddress(
          address: remoteJid,
          displayName: rosterTitle,
        );
        nextState = state.copyWith(emailContactKnown: true);
      } else {
        final xmppService = _xmppService;
        if (xmppService == null) {
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
      return;
    }
    emit(_attachToast(nextState, ChatToast(messageText: event.successMessage)));
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

  void _onChatQuoteRequested(
    ChatQuoteRequested event,
    Emitter<ChatState> emit,
  ) {
    final currentChat = state.chat;
    if (currentChat != null &&
        event.message.awaitsMucReference(
          isGroupChat: currentChat.type == ChatType.groupChat,
          isEmailBacked: currentChat.isEmailBacked,
        )) {
      return;
    }
    emit(state.copyWith(quoting: event.message));
  }

  void _onChatQuoteCleared(ChatQuoteCleared event, Emitter<ChatState> emit) {
    if (state.quoting != null) {
      emit(state.copyWith(quoting: null));
    }
  }

  Future<void> _onChatMessagePinRequested(
    ChatMessagePinRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = event.chat;
    final stanzaId = event.message.stanzaID.trim();
    if (stanzaId.isEmpty) {
      return;
    }
    final isEmailBacked = chat.isEmailBacked;
    if (event.message.awaitsMucReference(
      isGroupChat: chat.type == ChatType.groupChat,
      isEmailBacked: isEmailBacked,
    )) {
      return;
    }
    if (chat.type == ChatType.groupChat && !isEmailBacked) {
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
      if (!roomState.myAffiliation.canManagePins) {
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
    final emailService = _emailService;
    if (isEmailBacked) {
      if (emailService == null) {
        return;
      }
      if (event.pin) {
        await emailService.pinMessage(chat: chat, message: event.message);
      } else {
        await emailService.unpinMessage(chat: chat, message: event.message);
      }
      return;
    }
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
  }

  Future<void> _onChatMessageReactionToggled(
    ChatMessageReactionToggled event,
    Emitter<ChatState> emit,
  ) async {
    if (event.isEmailChat) return;
    final chat = state.chat;
    if (chat != null &&
        event.message.awaitsMucReference(
          isGroupChat: chat.type == ChatType.groupChat,
          isEmailBacked: chat.isEmailBacked,
        )) {
      return;
    }
    try {
      await _messageService.reactToMessage(
        stanzaID: event.message.stanzaID,
        emoji: event.emoji,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(_messageReactionFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _onChatMessageForwardRequested(
    ChatMessageForwardRequested event,
    Emitter<ChatState> emit,
  ) async {
    final target = event.target;
    final message = event.message;
    final isEmailTarget = _isEmailForwardTarget(target);
    final targetChat = target.chat;
    final targetJid = (targetChat?.jid ?? target.address)?.trim();
    final emailService = _emailService;
    final syntheticForward = _syntheticForwardEnvelope(message);
    final syntheticXmppText = ChatSubjectCodec.composeXmppBody(
      body: syntheticForward.body,
      subject: syntheticForward.xmppSubject,
    );
    final syntheticXmppHtml = syntheticForward.xmppHtmlBody;
    final syntheticEmailCaption = syntheticForward.body.isEmpty
        ? null
        : syntheticForward.body;
    final syntheticEmailHtml = syntheticForward.emailHtmlBody;
    void emitForwardSuccess() {
      emit(
        _attachToast(
          state,
          const ChatToast(message: ChatMessageKey.chatMessageForwarded),
        ),
      );
    }

    void emitForwardFailure() {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: ChatMessageKey.chatMessageForwardFailed,
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
    }

    try {
      Chat? resolvedEmailTarget;
      if (isEmailTarget) {
        if (emailService == null) {
          emitForwardFailure();
          return;
        }
        resolvedEmailTarget = await _resolveEmailForwardTarget(
          emailService: emailService,
          target: target,
        );
        if (resolvedEmailTarget == null) {
          emitForwardFailure();
          return;
        }
      }
      if (!isEmailTarget && (targetJid == null || targetJid.isEmpty)) {
        emitForwardFailure();
        return;
      }
      if (isEmailTarget &&
          emailService != null &&
          resolvedEmailTarget != null &&
          message.deltaMsgId != null) {
        final forwarded = await emailService.forwardMessages(
          messages: [message],
          toChat: resolvedEmailTarget,
        );
        if (forwarded) {
          emitForwardSuccess();
          return;
        }
      }
      final attachments = await _attachmentsForMessage(message);
      if (attachments.isNotEmpty) {
        if (isEmailTarget) {
          if (emailService == null || resolvedEmailTarget == null) {
            emitForwardFailure();
            return;
          }
          final bool shouldBundle =
              attachments.length >= _emailAttachmentBundleMinimumCount;
          final bundled = await _bundleEmailAttachmentList(
            attachments: attachments,
            caption: syntheticEmailCaption,
          );
          for (var index = 0; index < bundled.length; index += 1) {
            final attachment = bundled[index];
            final captionedAttachment =
                index == 0 && syntheticEmailCaption != null
                ? attachment.copyWith(caption: syntheticEmailCaption)
                : attachment;
            await emailService.sendAttachment(
              chat: resolvedEmailTarget,
              attachment: captionedAttachment,
              subject: syntheticForward.emailSubject,
              htmlCaption: index == 0 ? syntheticEmailHtml : null,
              forwarded: true,
              forwardedFromJid: message.senderJid,
            );
          }
          if (shouldBundle && bundled.isNotEmpty) {
            EmailAttachmentBundler.scheduleCleanup(bundled.first);
          }
          emitForwardSuccess();
          return;
        }
        final attachmentGroupId = attachments.length > 1 ? uuid.v4() : null;
        for (var index = 0; index < attachments.length; index += 1) {
          final attachment = attachments[index];
          final captionedAttachment = index == 0
              ? attachment.copyWith(caption: syntheticXmppText)
              : attachment;
          await _messageService.sendAttachment(
            jid: targetJid!,
            attachment: captionedAttachment,
            encryptionProtocol:
                targetChat?.encryptionProtocol ?? EncryptionProtocol.none,
            chatType: targetChat?.type ?? ChatType.chat,
            htmlCaption: index == 0 ? syntheticXmppHtml : null,
            forwarded: true,
            forwardedFromJid: message.senderJid,
            transportGroupId: attachmentGroupId,
            attachmentOrder: index,
          );
        }
        emitForwardSuccess();
        return;
      }
      if (isEmailTarget) {
        if (emailService == null || resolvedEmailTarget == null) {
          emitForwardFailure();
          return;
        }
        await emailService.sendMessage(
          chat: resolvedEmailTarget,
          body: syntheticForward.body,
          subject: syntheticForward.emailSubject,
          htmlBody: syntheticEmailHtml,
          forwarded: true,
          forwardedFromJid: message.senderJid,
        );
      } else {
        await _messageService.sendMessage(
          jid: targetJid!,
          text: syntheticXmppText,
          htmlBody: syntheticXmppHtml,
          forwarded: true,
          forwardedFromJid: message.senderJid,
          encryptionProtocol:
              targetChat?.encryptionProtocol ?? EncryptionProtocol.none,
          chatType: targetChat?.type ?? ChatType.chat,
        );
      }
      emitForwardSuccess();
    } on Exception catch (error, stackTrace) {
      _log.warning(_messageForwardFailedLogMessage, error, stackTrace);
      emitForwardFailure();
    }
  }

  bool _isEmailForwardTarget(FanOutTarget target) {
    final targetChat = target.chat;
    if (targetChat != null) {
      return _isEmailCapableChat(targetChat);
    }
    final transport =
        target.transport ?? hintTransportForAddress(target.address);
    return transport?.isEmail ?? false;
  }

  Future<Chat?> _resolveEmailForwardTarget({
    required EmailService emailService,
    required FanOutTarget target,
  }) async {
    final targetChat = target.chat;
    if (targetChat != null) {
      return emailService.ensureChatForEmailChat(targetChat);
    }
    final address = target.address?.trim();
    if (address == null || address.isEmpty) {
      return null;
    }
    return emailService.ensureChatForAddress(
      address: address,
      displayName: target.displayName,
    );
  }

  ({
    String emailSubject,
    String xmppSubject,
    String body,
    String? emailHtmlBody,
    String? xmppHtmlBody,
  })
  _syntheticForwardEnvelope(Message message) {
    final display = message.deltaChatId != null || message.deltaMsgId != null
        ? ChatSubjectCodec.splitEmailBody(
            body: message.body,
            subject: message.subject,
          )
        : ChatSubjectCodec.splitDisplayBody(
            body: message.body,
            subject: message.subject,
          );
    final originalSubject = display.subject?.trim();
    var originalBody = display.body.trim();
    if (originalBody.isEmpty) {
      final normalizedHtml = message.normalizedHtmlBody;
      if (normalizedHtml != null) {
        originalBody = HtmlContentCodec.toPlainText(normalizedHtml).trim();
        if (originalSubject != null && originalSubject.isNotEmpty) {
          originalBody = ChatSubjectCodec.stripRepeatedSubject(
            body: originalBody,
            subject: originalSubject,
          ).trim();
        }
      }
    }
    final sections = <String>[
      if (originalSubject != null && originalSubject.isNotEmpty)
        '$forwardedBodySubjectPrefix $originalSubject',
      if (originalBody.isNotEmpty) originalBody,
    ];
    final body = sections.join('\n\n');
    final senderLabel = _forwardedSenderDisplayLabel(message);
    final subjectText = syntheticForwardVisibleSubject(
      senderLabel: senderLabel,
    );
    final bodyHtml = _syntheticForwardBodyHtml(
      originalSubject: originalSubject,
      originalBody: originalBody,
      originalHtmlBody: message.normalizedHtmlBody,
    );
    final emailHtml = injectSyntheticForwardHtmlMarker(bodyHtml);
    final xmppHtml = _syntheticForwardXmppHtml(
      subjectText: subjectText,
      body: body,
      bodyHtml: bodyHtml,
    );
    return (
      emailSubject: subjectText,
      xmppSubject: markSyntheticForwardSubject(subjectText),
      body: body,
      emailHtmlBody: emailHtml,
      xmppHtmlBody: xmppHtml.isEmpty ? null : xmppHtml,
    );
  }

  String? _syntheticForwardBodyHtml({
    required String? originalSubject,
    required String originalBody,
    required String? originalHtmlBody,
  }) {
    final normalizedOriginalHtml = HtmlContentCodec.normalizeHtml(
      originalHtmlBody,
    );
    final subjectHeader = originalSubject == null || originalSubject.isEmpty
        ? null
        : HtmlContentCodec.fromPlainText(
            '$forwardedBodySubjectPrefix $originalSubject',
          );
    if (normalizedOriginalHtml != null && normalizedOriginalHtml.isNotEmpty) {
      if (subjectHeader == null) {
        return normalizedOriginalHtml;
      }
      return '$subjectHeader<br />\n<br />\n$normalizedOriginalHtml';
    }
    final sections = <String>[
      if (originalSubject != null && originalSubject.isNotEmpty)
        '$forwardedBodySubjectPrefix $originalSubject',
      if (originalBody.isNotEmpty) originalBody,
    ];
    if (sections.isEmpty) {
      return null;
    }
    return HtmlContentCodec.fromPlainText(sections.join('\n\n'));
  }

  String _syntheticForwardXmppHtml({
    required String subjectText,
    required String body,
    required String? bodyHtml,
  }) {
    final subjectHtml = HtmlContentCodec.fromPlainText(subjectText);
    if (bodyHtml != null && bodyHtml.isNotEmpty) {
      return '$subjectHtml<br />\n<br />\n$bodyHtml';
    }
    if (body.isEmpty) {
      return subjectHtml;
    }
    return HtmlContentCodec.fromPlainText('$subjectText\n\n$body');
  }

  String _forwardedSenderDisplayLabel(Message message) {
    final parsed = parseJid(message.senderJid);
    final resource = parsed?.resource.trim();
    if (resource != null && resource.isNotEmpty) {
      return resource;
    }
    final safeAddress = displaySafeAddress(message.senderJid);
    if (safeAddress != null && safeAddress.trim().isNotEmpty) {
      return safeAddress.trim();
    }
    return message.senderJid.trim();
  }

  Future<void> _onChatMessageResendRequested(
    ChatMessageResendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    final chatType = event.chatType;
    final isEmailMessage = message.deltaChatId != null;
    try {
      if (isEmailMessage) {
        await _resendEmailMessage(message, emit);
        return;
      }
      final attachments = await _attachmentsForMessage(message);
      if (attachments.isNotEmpty) {
        Message? quoted;
        if (message.quoting != null) {
          quoted = await _messageService.loadMessageByReferenceId(
            message.quoting!,
            chatJid: message.chatJid,
          );
        }
        final caption = message.plainText.trim();
        final htmlCaption = message.normalizedHtmlBody;
        final attachmentGroupId = attachments.length > 1 ? uuid.v4() : null;
        for (var index = 0; index < attachments.length; index += 1) {
          final attachment = attachments[index];
          final shouldApplyCaption = caption.isNotEmpty && index == 0;
          final resolvedAttachment = shouldApplyCaption
              ? attachment.copyWith(caption: caption)
              : attachment;
          await _messageService.sendAttachment(
            jid: message.chatJid,
            attachment: resolvedAttachment,
            encryptionProtocol: message.encryptionProtocol,
            quotedMessage: index == 0 ? quoted : null,
            chatType: chatType,
            htmlCaption: shouldApplyCaption ? htmlCaption : null,
            transportGroupId: attachmentGroupId,
            attachmentOrder: index,
          );
        }
        return;
      }
      final hasBody =
          message.plainText.isNotEmpty || message.normalizedHtmlBody != null;
      if (!hasBody) return;
      await _messageService.resendMessage(message.stanzaID, chatType: chatType);
    } on Exception catch (error, stackTrace) {
      _log.warning(_messageResendFailedLogMessage, error, stackTrace);
    }
  }

  Future<void> _onChatMessageEditRequested(
    ChatMessageEditRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    if (message.deltaChatId != null) {
      await _rehydrateEmailDraft(message, emit);
    } else {
      await _rehydrateXmppDraft(message, emit);
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
    final recipients = event.recipients
        .where((recipient) => recipient.included)
        .toList(growable: false);
    if (recipients.isEmpty) {
      return;
    }
    final split = _splitRecipientsForSend(
      recipients: recipients,
      forceEmail: false,
    );
    final requiresXmpp = split.xmppRecipients.isNotEmpty;
    final shouldUseEmail = _shouldSendAttachmentsViaEmail(
      chat: chat,
      recipients: recipients,
    );
    final service = _emailService;
    if (shouldUseEmail && service == null) return;
    if (shouldUseEmail &&
        !_hasEmailTarget(chat: chat, recipients: recipients)) {
      const message =
          ChatMessageKey.chatComposerEmailAttachmentRecipientRequired;
      emit(
        _attachToast(
          state.copyWith(composerError: message),
          ChatToast(message: message, variant: ChatToastVariant.warning),
        ),
      );
      return;
    }
    final rawCaption = event.attachment.caption?.trim();
    final caption = rawCaption?.isNotEmpty == true ? rawCaption : null;
    var preparedAttachment = event.attachment.copyWith(caption: caption);
    final pendingId = _nextPendingAttachmentId();
    final placeholder = PendingAttachment(
      id: pendingId,
      attachment: preparedAttachment,
      isPreparing: true,
    );
    emit(
      state.copyWith(
        pendingAttachments: [...state.pendingAttachments, placeholder],
        quoting: null,
      ),
    );

    if (preparedAttachment.sizeBytes <= 0) {
      try {
        final resolvedSize = await File(preparedAttachment.path).length();
        if (resolvedSize > 0) {
          preparedAttachment = preparedAttachment.copyWith(
            sizeBytes: resolvedSize,
          );
        }
      } on Exception catch (error, stackTrace) {
        _log.fine('Failed to resolve attachment size', error, stackTrace);
      }
    }
    final String? existingMimeType = preparedAttachment.mimeType?.trim();
    if (existingMimeType == null || existingMimeType.isEmpty) {
      try {
        final String? resolvedMimeType = await resolveMimeTypeFromPath(
          path: preparedAttachment.path,
          fileName: preparedAttachment.fileName,
        );
        final String? trimmedResolved = resolvedMimeType?.trim();
        if (trimmedResolved != null && trimmedResolved.isNotEmpty) {
          preparedAttachment = preparedAttachment.copyWith(
            mimeType: trimmedResolved,
          );
        }
      } on Exception catch (error, stackTrace) {
        _log.fine(_attachmentMimeTypeResolutionLogMessage, error, stackTrace);
      }
    }
    try {
      preparedAttachment = await EmailAttachmentOptimizer.optimize(
        preparedAttachment,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to optimize attachment', error, stackTrace);
    }
    final uploadLimitBytes = requiresXmpp
        ? _messageService.httpUploadSupport.maxFileSizeBytes
        : null;
    final sizeBytes = preparedAttachment.sizeBytes;
    if (uploadLimitBytes != null &&
        uploadLimitBytes > 0 &&
        sizeBytes > uploadLimitBytes) {
      const message = ChatMessageKey.messageErrorFileUploadFailure;
      _replacePendingAttachment(
        placeholder.copyWith(
          attachment: preparedAttachment,
          status: PendingAttachmentStatus.failed,
          isPreparing: false,
          errorMessage: message,
        ),
        emit,
      );
      emit(state.copyWith(composerError: message));
      return;
    }
    _replacePendingAttachment(
      placeholder.copyWith(attachment: preparedAttachment, isPreparing: false),
      emit,
    );
  }

  Future<void> _onChatAttachmentRetryRequested(
    ChatAttachmentRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final pending = _pendingAttachmentById(event.attachmentId);
    final chat = event.chat;
    if (pending == null || pending.status != PendingAttachmentStatus.failed) {
      return;
    }
    final recipients = event.recipients
        .where((recipient) => recipient.included)
        .toList(growable: false);
    if (recipients.isEmpty) {
      return;
    }
    final split = _splitRecipientsForSend(
      recipients: recipients,
      forceEmail: false,
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
      return;
    }
    final service = _emailService;
    if (requiresEmail && service == null) return;
    final updated = pending.copyWith(
      status: PendingAttachmentStatus.queued,
      clearErrorMessage: true,
    );
    _replacePendingAttachment(updated, emit);
    if (requiresEmail) {
      final EmailService emailService = service!;
      final emailSent = await _sendPendingAttachment(
        pending: updated,
        chat: chat,
        service: emailService,
        recipients: emailRecipients,
        emit: emit,
        subject: event.subject,
        quotedDraft: event.quotedDraft,
        settings: event.settings,
        retainOnSuccess: requiresXmpp,
      );
      if (!emailSent || !requiresXmpp) {
        return;
      }
    }
    final latest = _pendingAttachmentById(updated.id);
    if (latest == null ||
        latest.status == PendingAttachmentStatus.failed ||
        !requiresXmpp) {
      return;
    }
    final sent = await _sendXmppAttachments(
      attachments: [latest],
      chat: chat,
      recipients: xmppRecipients,
      emit: emit,
      supportsHttpFileUpload: event.supportsHttpFileUpload,
      subject: event.subject,
      quotedDraft: event.quotedDraft,
    );
    if (!sent) {
      return;
    }
  }

  Future<void> _onChatPendingAttachmentRemoved(
    ChatPendingAttachmentRemoved event,
    Emitter<ChatState> emit,
  ) async {
    _removePendingAttachment(event.attachmentId, emit);
  }

  Future<void> _onChatViewFilterChanged(
    ChatViewFilterChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chatJid = event.chatJid.trim();
    if (chatJid.isEmpty) return;
    const forcedFilter = MessageTimelineFilter.allWithContact;
    final effectiveFilter = _forceAllWithContactViewFilter
        ? forcedFilter
        : event.filter;
    emit(state.copyWith(viewFilter: effectiveFilter));
    _subscribeToMessages(limit: _currentMessageLimit, filter: effectiveFilter);
    if (event.persist && !_forceAllWithContactViewFilter) {
      await _chatsService.saveChatViewFilter(
        jid: chatJid,
        filter: effectiveFilter,
      );
    }
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
    final recipients = event.recipients
        .where((recipient) => recipient.included)
        .toList();
    if (recipients.isEmpty) return;
    await _sendFanOut(
      recipients: recipients,
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
    if (!chat.defaultTransport.isEmail) {
      await _chatsService.sendTyping(jid: chat.jid, typing: false);
    }
  }

  Future<bool> _sendPendingAttachment({
    required PendingAttachment pending,
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
      _replacePendingAttachment(current, emit);
    }
    var captionText = current.attachment.caption?.trim() ?? '';
    if (captionText.isEmpty && htmlCaption?.trim().isNotEmpty == true) {
      captionText = HtmlContentCodec.toPlainText(htmlCaption!);
    }
    final syntheticAttachmentReply = _syntheticEmailReplyEnvelope(
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
    if (_shouldFanOut(recipients, chat)) {
      final succeeded = await _sendFanOut(
        recipients: recipients,
        attachment: effectiveAttachment,
        htmlCaption: effectiveHtmlCaption,
        subject: effectiveSubject,
        quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
        chat: chat,
        settings: settings,
        emit: emit,
      );
      if (succeeded) {
        _handlePendingAttachmentSuccess(
          current,
          emit,
          retainOnSuccess: retainOnSuccess,
        );
        return true;
      } else {
        _markPendingAttachmentFailed(
          current.id,
          emit,
          message:
              state.composerError ?? ChatMessageKey.chatAttachmentSendFailed,
        );
      }
      return false;
    }
    try {
      await service.sendAttachment(
        chat: chat,
        attachment: effectiveAttachment,
        subject: effectiveSubject,
        htmlCaption: effectiveHtmlCaption,
        quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
      );
      _handlePendingAttachmentSuccess(
        current,
        emit,
        retainOnSuccess: retainOnSuccess,
      );
      return true;
    } on DeltaChatException catch (error, stackTrace) {
      _log.safeWarning(_attachmentSendFailedLogMessage, error, stackTrace);
      final mappedError = DeltaErrorMapper.resolve(error.message);
      final readableMessage = _chatMessageKeyForMessageError(mappedError);
      _markPendingAttachmentFailed(current.id, emit, message: readableMessage);
      emit(state.copyWith(composerError: readableMessage));
    } on Exception catch (error, stackTrace) {
      _log.safeWarning(_attachmentSendFailedLogMessage, error, stackTrace);
      _markPendingAttachmentFailed(current.id, emit);
      emit(
        state.copyWith(composerError: ChatMessageKey.chatAttachmentSendFailed),
      );
    }
    return false;
  }

  Future<EmailAttachment?> _buildCalendarTaskEmailAttachment(
    CalendarTask task,
  ) async {
    try {
      const CalendarTransferService transferService = CalendarTransferService();
      final File file = await transferService.exportTaskIcs(task: task);
      final int sizeBytes = await file.length();
      final String fileName = p.basename(file.path);
      return EmailAttachment(
        path: file.path,
        fileName: fileName,
        sizeBytes: sizeBytes,
        mimeType: _calendarTaskIcsAttachmentMimeType,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        _calendarTaskIcsAttachmentSendFailureLogMessage,
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<bool> _sendCalendarTaskEmailAttachment({
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
        return false;
      }
      return true;
    }
    final EmailAttachment? attachment = await _buildCalendarTaskEmailAttachment(
      task,
    );
    if (attachment == null) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.calendarTaskShareSendFailed,
        ),
      );
      return false;
    }
    final syntheticAttachmentReply = _syntheticEmailReplyEnvelope(
      body: caption ?? '',
      subject: subject,
      quotedDraft: quotedDraft,
    );
    final EmailAttachment resolvedAttachment = syntheticAttachmentReply == null
        ? (caption == null ? attachment : attachment.copyWith(caption: caption))
        : attachment.copyWith(
            caption: syntheticAttachmentReply.body.isEmpty
                ? null
                : syntheticAttachmentReply.body,
          );
    final effectiveSubject = syntheticAttachmentReply?.subject ?? subject;
    final effectiveHtmlCaption =
        syntheticAttachmentReply?.htmlBody ?? htmlCaption;
    if (_shouldFanOut(recipients, chat)) {
      final succeeded = await _sendFanOut(
        recipients: recipients,
        attachment: resolvedAttachment,
        htmlCaption: effectiveHtmlCaption,
        subject: effectiveSubject,
        quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
        chat: chat,
        settings: settings,
        emit: emit,
      );
      if (!succeeded) {
        return false;
      }
      return true;
    }
    try {
      await service.sendAttachment(
        chat: chat,
        attachment: resolvedAttachment,
        subject: effectiveSubject,
        htmlCaption: effectiveHtmlCaption,
        quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
      );
      return true;
    } on DeltaChatException catch (error, stackTrace) {
      _log.warning(
        _calendarTaskIcsAttachmentSendFailureLogMessage,
        error,
        stackTrace,
      );
      final mappedError = DeltaErrorMapper.resolve(error.message);
      final readableMessage = _chatMessageKeyForMessageError(mappedError);
      emit(state.copyWith(composerError: readableMessage));
      return false;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        _calendarTaskIcsAttachmentSendFailureLogMessage,
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          composerError: ChatMessageKey.calendarTaskShareSendFailed,
        ),
      );
      return false;
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
      final targetChat = recipient.target.chat;
      final targetJid = (targetChat?.jid ?? recipient.target.address)?.trim();
      if (targetJid == null || targetJid.isEmpty) {
        continue;
      }
      if (!processed.add(targetJid)) {
        continue;
      }
      await _messageService.sendMessage(
        jid: targetJid,
        text: resolvedCaption,
        encryptionProtocol:
            targetChat?.encryptionProtocol ?? chat.encryptionProtocol,
        calendarTaskIcs: task,
        calendarTaskIcsReadOnly: taskReadOnly,
        chatType: targetChat?.type ?? chat.type,
      );
    }
    return processed.isNotEmpty;
  }

  Future<EmailAttachment> _bundlePendingAttachments({
    required List<PendingAttachment> attachments,
    required String? caption,
  }) async {
    return EmailAttachmentBundler.bundle(
      attachments: attachments.map((pending) => pending.attachment),
      caption: caption,
    );
  }

  Future<List<EmailAttachment>> _bundleEmailAttachmentList({
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

  Future<bool> _sendQueuedAttachments({
    required Iterable<PendingAttachment> attachments,
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
  }) async {
    var index = 0;
    for (final attachment in attachments) {
      final latest = _pendingAttachmentById(attachment.id) ?? attachment;
      final shouldApplyCaption =
          captionForFirstAttachment != null && index == 0;
      final shouldApplyHtmlCaption =
          htmlCaptionForFirstAttachment != null && index == 0;
      final pendingWithCaption = shouldApplyCaption
          ? latest.copyWith(
              attachment: latest.attachment.copyWith(
                caption: captionForFirstAttachment,
              ),
            )
          : latest;
      final sent = await _sendPendingAttachment(
        pending: pendingWithCaption,
        chat: chat,
        service: service,
        recipients: recipients,
        emit: emit,
        subject: subject,
        quotedDraft: quotedDraft,
        settings: settings,
        retainOnSuccess: retainOnSuccess,
        htmlCaption: shouldApplyHtmlCaption
            ? htmlCaptionForFirstAttachment
            : null,
      );
      if (!sent) {
        return false;
      }
      index += 1;
    }
    return true;
  }

  Future<bool> _sendBundledEmailAttachments({
    required List<PendingAttachment> attachments,
    required EmailAttachment bundledAttachment,
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
  }) async {
    if (attachments.isEmpty) return true;
    _markPendingAttachmentsUploading(attachments, emit);
    final syntheticAttachmentReply = _syntheticEmailReplyEnvelope(
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
    try {
      if (_shouldFanOut(recipients, chat)) {
        final succeeded = await _sendFanOut(
          recipients: recipients,
          attachment: resolvedAttachment,
          htmlCaption: effectiveHtmlCaption,
          subject: effectiveSubject,
          quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
          chat: chat,
          settings: settings,
          emit: emit,
        );
        if (succeeded) {
          _handleBundledAttachmentSuccess(
            attachments,
            emit,
            retainOnSuccess: retainOnSuccess,
          );
          return true;
        }
        _markPendingAttachmentsFailed(
          attachments,
          emit,
          message:
              state.composerError ?? ChatMessageKey.chatAttachmentSendFailed,
        );
        return false;
      }
      try {
        await service.sendAttachment(
          chat: chat,
          attachment: resolvedAttachment,
          subject: effectiveSubject,
          htmlCaption: effectiveHtmlCaption,
          quotedStanzaId: syntheticAttachmentReply?.quotedStanzaId,
        );
        _handleBundledAttachmentSuccess(
          attachments,
          emit,
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
        _markPendingAttachmentsFailed(
          attachments,
          emit,
          message: readableMessage,
        );
        emit(state.copyWith(composerError: readableMessage));
      } on Exception catch (error, stackTrace) {
        _log.warning(
          _bundledAttachmentSendFailureLogMessage,
          error,
          stackTrace,
        );
        _markPendingAttachmentsFailed(attachments, emit);
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

  void _handlePendingAttachmentSuccess(
    PendingAttachment pending,
    Emitter<ChatState> emit, {
    required bool retainOnSuccess,
  }) {
    if (retainOnSuccess) {
      _replacePendingAttachment(
        pending.copyWith(
          status: PendingAttachmentStatus.queued,
          clearErrorMessage: true,
        ),
        emit,
      );
      return;
    }
    _removePendingAttachment(pending.id, emit);
  }

  Future<bool> _sendXmppAttachments({
    required Iterable<PendingAttachment> attachments,
    required Chat chat,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
    required bool supportsHttpFileUpload,
    required String? subject,
    Message? quotedDraft,
    String? caption,
    String? htmlCaption,
    void Function(String stanzaId)? onLocalMessageStored,
  }) async {
    if (!supportsHttpFileUpload) {
      emit(
        state.copyWith(
          composerError: ChatMessageKey.chatComposerFileUploadUnavailable,
        ),
      );
      return false;
    }
    final orderedAttachments = attachments.toList(growable: false);
    if (orderedAttachments.isEmpty) return true;
    final shouldGroupAttachments = orderedAttachments.length > 1;
    final targets = <String, Chat>{};
    if (recipients.isEmpty) {
      targets[chat.jid] = chat;
    } else {
      for (final recipient in recipients) {
        final targetChat = recipient.target.chat;
        if (targetChat == null) continue;
        targets[targetChat.jid] = targetChat;
      }
      if (targets.isEmpty) {
        targets[chat.jid] = chat;
      }
    }
    final attachmentGroupIds = <String, String?>{};
    if (shouldGroupAttachments) {
      for (final entry in targets.entries) {
        attachmentGroupIds[entry.key] = uuid.v4();
      }
    }
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
      _replacePendingAttachment(current, emit);
      try {
        XmppAttachmentUpload? upload;
        for (final target in targets.values) {
          final quote =
              quotedDraft != null &&
                  quotedDraft.chatJid == target.jid &&
                  index == 0
              ? quotedDraft
              : null;
          final groupId = attachmentGroupIds[target.jid];
          upload = await _messageService.sendAttachment(
            jid: target.jid,
            attachment: current.attachment,
            encryptionProtocol: target.encryptionProtocol,
            chatType: target.type,
            quotedMessage: quote,
            htmlCaption: shouldApplyCaption ? htmlCaption : null,
            transportGroupId: groupId,
            attachmentOrder: index,
            upload: upload,
            onLocalMessageStored: (stanzaId) {
              storedStanzaId = stanzaId;
              onLocalMessageStored?.call(stanzaId);
            },
          );
        }
        _removePendingAttachment(current.id, emit);
      } on XmppFileTooBigException catch (_) {
        const message = ChatMessageKey.messageErrorFileUploadFailure;
        _markPendingAttachmentFailed(current.id, emit, message: message);
        emit(state.copyWith(composerError: message));
        if (storedStanzaId == null) {
          await _saveXmppDraft(
            chat: chat,
            recipients: recipients,
            body: '',
            attachments: [current],
            subject: subject,
            quotedDraft: quotedDraft,
            emit: emit,
          );
        }
        return false;
      } on XmppUploadUnavailableException catch (_) {
        const message = ChatMessageKey.chatComposerFileUploadUnavailable;
        _markPendingAttachmentFailed(current.id, emit, message: message);
        emit(state.copyWith(composerError: message));
        if (storedStanzaId == null) {
          await _saveXmppDraft(
            chat: chat,
            recipients: recipients,
            body: '',
            attachments: [current],
            subject: subject,
            quotedDraft: quotedDraft,
            emit: emit,
          );
        }
        return false;
      } on XmppUploadNotSupportedException catch (_) {
        const message = ChatMessageKey.chatComposerFileUploadUnavailable;
        _markPendingAttachmentFailed(current.id, emit, message: message);
        emit(state.copyWith(composerError: message));
        if (storedStanzaId == null) {
          await _saveXmppDraft(
            chat: chat,
            recipients: recipients,
            body: '',
            attachments: [current],
            subject: subject,
            quotedDraft: quotedDraft,
            emit: emit,
          );
        }
        return false;
      } on XmppUploadMisconfiguredException catch (_) {
        const message = ChatMessageKey.messageErrorFileUploadFailure;
        _markPendingAttachmentFailed(current.id, emit, message: message);
        emit(state.copyWith(composerError: message));
        if (storedStanzaId == null) {
          await _saveXmppDraft(
            chat: chat,
            recipients: recipients,
            body: '',
            attachments: [current],
            subject: subject,
            quotedDraft: quotedDraft,
            emit: emit,
          );
        }
        return false;
      } on XmppMessageException catch (_) {
        const message = ChatMessageKey.chatAttachmentSendFailed;
        _markPendingAttachmentFailed(current.id, emit, message: message);
        emit(state.copyWith(composerError: message));
        if (storedStanzaId == null) {
          await _saveXmppDraft(
            chat: chat,
            recipients: recipients,
            body: '',
            attachments: [current],
            subject: subject,
            quotedDraft: quotedDraft,
            emit: emit,
          );
        }
        return false;
      } on Exception catch (error, stackTrace) {
        _log.safeWarning(
          _xmppAttachmentSendFailedLogMessage,
          error,
          stackTrace,
        );
        const message = ChatMessageKey.chatAttachmentSendFailed;
        _markPendingAttachmentFailed(current.id, emit, message: message);
        emit(state.copyWith(composerError: message));
        if (storedStanzaId == null) {
          await _saveXmppDraft(
            chat: chat,
            recipients: recipients,
            body: '',
            attachments: [current],
            subject: subject,
            quotedDraft: quotedDraft,
            emit: emit,
          );
        }
        return false;
      }
    }
    return true;
  }

  List<String> _draftRecipientJids({
    required Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (recipients.isEmpty) {
      return [chat.jid];
    }
    final resolved = <String>{};
    for (final recipient in recipients) {
      final chatJid = recipient.target.chat?.jid;
      final address = recipient.target.address;
      final value = chatJid ?? address;
      if (value != null && value.isNotEmpty) {
        resolved.add(value);
      }
    }
    return resolved.toList();
  }

  String _draftSignature({
    required List<String> recipients,
    required String body,
    required String? subject,
    required List<PendingAttachment> pendingAttachments,
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
    required String? quoteId,
  }) {
    final signature = _draftSignature(
      recipients: recipients,
      body: body,
      subject: subject,
      pendingAttachments: pendingAttachments,
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

  bool _chatAllowsAutoDownload(Chat chat) {
    final resolved =
        chat.attachmentAutoDownload ??
        _settingsSnapshot.defaultChatAttachmentAutoDownload;
    return resolved.isAllowed;
  }

  bool _metadataIsHighRisk(FileMetadataData metadata) {
    final report = buildDeclaredFileTypeReport(
      declaredMimeType: metadata.mimeType,
      fileName: metadata.filename,
      path: metadata.path,
    );
    final risk = assessFileOpenRisk(
      report: report,
      fileName: metadata.filename,
    );
    return risk.isWarning;
  }

  bool _metadataAllowsAutoDownload(FileMetadataData metadata) {
    return metadata.downloadCategory.isAutoDownloadAllowed(
      imagesEnabled: _settingsSnapshot.autoDownloadImages,
      videosEnabled: _settingsSnapshot.autoDownloadVideos,
      documentsEnabled: _settingsSnapshot.autoDownloadDocuments,
      archivesEnabled: _settingsSnapshot.autoDownloadArchives,
    );
  }

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

  Future<bool> _needsAttachmentDownload(
    FileMetadataData metadata, {
    required bool isEmailChat,
  }) async {
    if (await _hasLocalAttachmentFile(metadata)) {
      return false;
    }
    if (isEmailChat) {
      return true;
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
    if (!force && !_chatAllowsAutoDownload(chat)) return;
    if (!force && await _isChatBlockedForAutoDownload(chat)) return;

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
    final db = await _messageService.database;
    final metadataList = await db.getFileMetadataForIds(metadataIds);
    final metadataById = <String, FileMetadataData>{
      for (final metadata in metadataList) metadata.id: metadata,
    };
    final isEmailChat = chat.defaultTransport.isEmail;
    final downloads = <({String metadataId, String stanzaId})>[];
    final emailMessages = <Message>[];

    for (final message in messages) {
      final key = _messageKey(message);
      final ids = messageKeys[key];
      if (ids == null || ids.isEmpty) continue;

      if (isEmailChat) {
        final metadataList = <FileMetadataData>[];
        for (final metadataId in ids) {
          final metadata = metadataById[metadataId];
          if (metadata == null) continue;
          metadataList.add(metadata);
        }
        if (metadataList.any(_metadataIsHighRisk)) {
          continue;
        }

        var shouldDownloadEmail = false;
        for (final metadata in metadataList) {
          if (!force &&
              (_autoDownloadAttemptedMetadataIds.contains(metadata.id) ||
                  !_metadataAllowsAutoDownload(metadata))) {
            continue;
          }
          final needsDownload = await _needsAttachmentDownload(
            metadata,
            isEmailChat: true,
          );
          if (!needsDownload) continue;
          if (!force) {
            _autoDownloadAttemptedMetadataIds.add(metadata.id);
          }
          shouldDownloadEmail = true;
        }
        if (!shouldDownloadEmail) continue;
        if (!force &&
            _autoDownloadAttemptedEmailMessages.contains(message.stanzaID)) {
          continue;
        }
        if (!force) {
          _autoDownloadAttemptedEmailMessages.add(message.stanzaID);
        }
        emailMessages.add(message);
        continue;
      }

      for (final metadataId in ids) {
        final metadata = metadataById[metadataId];
        if (metadata == null) continue;
        if (_metadataIsHighRisk(metadata)) {
          continue;
        }
        if (!force &&
            (_autoDownloadAttemptedMetadataIds.contains(metadataId) ||
                !_metadataAllowsAutoDownload(metadata))) {
          continue;
        }
        final needsDownload = await _needsAttachmentDownload(
          metadata,
          isEmailChat: false,
        );
        if (!needsDownload) continue;
        if (!force) {
          _autoDownloadAttemptedMetadataIds.add(metadataId);
        }
        downloads.add((metadataId: metadataId, stanzaId: message.stanzaID));
      }
    }

    if (isEmailChat) {
      for (final message in emailMessages) {
        try {
          await downloadFullEmailMessage(message);
        } on DeltaChatException catch (error, stackTrace) {
          _log.warning(
            'Auto-download email message failed.',
            error,
            stackTrace,
          );
        }
      }
      return;
    }
    for (final download in downloads) {
      try {
        await downloadInboundAttachment(
          metadataId: download.metadataId,
          stanzaId: download.stanzaId,
        );
      } on XmppException catch (error, stackTrace) {
        _log.warning('Auto-download attachment failed.', error, stackTrace);
      }
    }
  }

  Future<void> downloadFullEmailMessage(Message message) async {
    final emailService = _emailService;
    if (emailService == null) return;
    await emailService.downloadFullMessage(message);
  }

  Future<bool> downloadInboundAttachment({
    required String metadataId,
    required String stanzaId,
  }) async {
    final xmppService = _xmppService;
    if (xmppService == null) return false;
    final downloadedPath = await xmppService.downloadInboundAttachment(
      metadataId: metadataId,
      stanzaId: stanzaId,
    );
    return downloadedPath?.trim().isNotEmpty == true;
  }

  Future<FileMetadataData?> reloadFileMetadata(String metadataId) async {
    final db = await _messageService.database;
    return db.getFileMetadata(metadataId);
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

  Future<
    ({
      Map<String, List<String>> attachmentsByMessageId,
      Map<String, String> groupLeaderByMessageId,
    })
  >
  _loadAttachmentMaps(List<Message> messages) async {
    if (messages.isEmpty) {
      return (
        attachmentsByMessageId: const <String, List<String>>{},
        groupLeaderByMessageId: const <String, String>{},
      );
    }
    final db = await _messageService.database;
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
    if (messageIds.isNotEmpty) {
      final attachments = await db.getMessageAttachmentsForMessages(messageIds);
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
          messageIds: messageIdsInGroup,
          messageById: messageById,
          messageIndex: messageIndex,
        );
        if (leaderId == null) continue;
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
      if (attachmentByMessageId.containsKey(key)) continue;
      final fallback = message.fileMetadataID;
      if (fallback != null && fallback.isNotEmpty) {
        attachmentByMessageId[key] = [fallback];
      }
    }
    return (
      attachmentsByMessageId: attachmentByMessageId,
      groupLeaderByMessageId: groupLeaderByMessageId,
    );
  }

  bool _isCalendarSyncEnvelope(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return false;
    }
    return CalendarSyncMessage.looksLikeEnvelope(trimmed);
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
    final db = await _messageService.database;
    final snapshotIds = <String>{};
    for (final metadataId in allIds) {
      final metadata = await db.getFileMetadata(metadataId);
      if (metadata == null) {
        continue;
      }
      if (metadata.isCalendarSnapshot) {
        snapshotIds.add(metadataId);
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
    required Set<String> messageIds,
    required Map<String, Message> messageById,
    required Map<String, int> messageIndex,
  }) {
    if (messageIds.isEmpty) return null;
    final candidates = messageIds
        .map((id) => messageById[id])
        .whereType<Message>()
        .toList();
    if (candidates.isEmpty) return null;
    final withBody = candidates.where((message) {
      return message.plainText.trim().isNotEmpty ||
          message.normalizedHtmlBody?.trim().isNotEmpty == true;
    }).toList();
    final prioritized = withBody.isNotEmpty ? withBody : candidates;
    prioritized.sort((a, b) {
      final indexA = messageIndex[a.id] ?? 0;
      final indexB = messageIndex[b.id] ?? 0;
      return indexA.compareTo(indexB);
    });
    return prioritized.first.id;
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

  ({String subject, String body, String? htmlBody, String quotedStanzaId})?
  _syntheticEmailReplyEnvelope({
    required String body,
    required String? subject,
    required Message? quotedDraft,
  }) {
    if (quotedDraft == null) {
      return null;
    }
    final quotedContent = ChatSubjectCodec.splitDisplayBody(
      body: quotedDraft.body,
      subject: quotedDraft.subject,
    );
    final envelope = syntheticReplyEnvelope(
      body: body,
      subject: subject,
      quotedSubject: quotedContent.subject,
      quotedBody: quotedContent.body,
      quotedSenderLabel:
          displaySafeAddress(quotedDraft.senderJid) ?? quotedDraft.senderJid,
    );
    final normalizedBody = envelope.body.trim();
    return (
      subject: envelope.subject,
      body: normalizedBody,
      htmlBody: normalizedBody.isEmpty
          ? null
          : HtmlContentCodec.fromPlainText(normalizedBody),
      quotedStanzaId: quotedDraft.stanzaID,
    );
  }

  ({
    List<ComposerRecipient> emailRecipients,
    List<ComposerRecipient> xmppRecipients,
  })
  _splitRecipientsForSend({
    required List<ComposerRecipient> recipients,
    required bool forceEmail,
  }) {
    final emailRecipients = <ComposerRecipient>[];
    final xmppRecipients = <ComposerRecipient>[];
    for (final recipient in recipients) {
      if (forceEmail) {
        emailRecipients.add(recipient);
        continue;
      }
      final transport = _transportForRecipient(recipient);
      if (transport?.isEmail ?? false) {
        emailRecipients.add(recipient);
      } else {
        xmppRecipients.add(recipient);
      }
    }
    return (emailRecipients: emailRecipients, xmppRecipients: xmppRecipients);
  }

  bool _hasEmailTarget({
    required Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (_isEmailCapableChat(chat)) {
      return true;
    }
    for (final recipient in recipients) {
      final transport = _transportForRecipient(recipient);
      if (transport?.isEmail ?? false) {
        return true;
      }
    }
    return false;
  }

  bool _shouldSendAttachmentsViaEmail({
    required Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (chat.defaultTransport.isEmail) {
      return true;
    }
    for (final recipient in recipients) {
      final transport = _transportForRecipient(recipient);
      if (transport?.isEmail ?? false) {
        return true;
      }
    }
    return false;
  }

  bool _isEmailCapableChat(Chat chat) {
    return chat.supportsEmail;
  }

  bool _shouldFanOut(List<ComposerRecipient> recipients, Chat chat) {
    if (recipients.isEmpty) return false;
    if (recipients.length == 1) {
      final targetChat = recipients.single.target.chat;
      if (targetChat != null && targetChat.jid == chat.jid) {
        return false;
      }
    }
    return true;
  }

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
    FanOutValidationFailure reason,
  ) => switch (reason) {
    FanOutValidationFailure.noRecipients =>
      ChatMessageKey.fanOutErrorNoRecipients,
    FanOutValidationFailure.resolveFailed =>
      ChatMessageKey.fanOutErrorResolveFailed,
    FanOutValidationFailure.tooManyRecipients =>
      ChatMessageKey.fanOutErrorTooManyRecipients,
    FanOutValidationFailure.emptyMessage =>
      ChatMessageKey.fanOutErrorEmptyMessage,
    FanOutValidationFailure.invalidShareToken =>
      ChatMessageKey.fanOutErrorInvalidShareToken,
  };

  String _composeXmppBody({required String body, required String? subject}) =>
      ChatSubjectCodec.composeXmppBody(body: body, subject: subject);

  Future<void> _sendXmppFanOut({
    required List<ComposerRecipient> recipients,
    required String body,
    CalendarTask? calendarTaskIcs,
    bool calendarTaskIcsReadOnly = CalendarTaskIcsMessage.defaultReadOnly,
    required Message? quotedDraft,
    void Function(String stanzaId)? onLocalMessageStored,
  }) async {
    final processed = <String>{};
    for (final recipient in recipients) {
      final targetChat = recipient.target.chat;
      final targetJid = targetChat?.jid;
      if (targetChat == null || targetJid == null) {
        continue;
      }
      if (!processed.add(targetJid)) continue;
      final quote = quotedDraft != null && quotedDraft.chatJid == targetJid
          ? quotedDraft
          : null;
      await _messageService.sendMessage(
        jid: targetJid,
        text: body,
        encryptionProtocol: targetChat.encryptionProtocol,
        quotedMessage: quote,
        calendarTaskIcs: calendarTaskIcs,
        calendarTaskIcsReadOnly: calendarTaskIcsReadOnly,
        chatType: targetChat.type,
        onLocalMessageStored: onLocalMessageStored,
      );
    }
  }

  Future<bool> _sendFanOut({
    required List<ComposerRecipient> recipients,
    String? text,
    String? htmlBody,
    EmailAttachment? attachment,
    String? htmlCaption,
    String? shareId,
    String? subject,
    String? quotedStanzaId,
    required Chat chat,
    required ChatSettingsSnapshot settings,
    required Emitter<ChatState> emit,
  }) async {
    final service = _emailService;
    if (service == null || recipients.isEmpty) return false;
    final chatShareSignatureEnabled =
        chat.shareSignatureEnabled ?? settings.shareTokenSignatureEnabled;
    final useSignatureToken =
        settings.shareTokenSignatureEnabled &&
        chatShareSignatureEnabled &&
        recipients.every((recipient) => recipient.target.shareSignatureEnabled);
    final effectiveShareId = shareId ?? ShareTokenCodec.generateShareId();
    try {
      final report = await service.fanOutSend(
        targets: recipients.map((recipient) => recipient.target).toList(),
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
          composerError: null,
        ),
      );
      return true;
    } on FanOutValidationException catch (error) {
      final key = _chatMessageKeyForFanOutFailure(error.reason);
      emit(state.copyWith(composerError: key));
      return false;
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to send fan-out message', error, stackTrace);
      emit(
        state.copyWith(composerError: ChatMessageKey.chatComposerSendFailed),
      );
      return false;
    }
    // Should be unreachable.
    // ignore: dead_code
    return false;
  }

  Future<void> _rehydrateEmailDraft(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    final service = _emailService;
    if (chat == null || service == null) return;
    ShareContext? shareContext = state.shareContexts[message.stanzaID];
    final nextHydrationId = ++_composerHydrationSeed;
    final nextSubject = (shareContext?.subject ?? message.subject)?.trim();
    emit(
      state.copyWith(
        pendingAttachments: const <PendingAttachment>[],
        composerHydrationId: nextHydrationId,
        composerHydrationText: message.plainText,
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
    if (attachments.isEmpty) return;
    final pendingAttachments = <PendingAttachment>[];
    for (final attachment in attachments) {
      pendingAttachments.add(
        PendingAttachment(
          id: _nextPendingAttachmentId(),
          attachment: attachment,
        ),
      );
    }
    emit(state.copyWith(pendingAttachments: pendingAttachments));
  }

  void _replacePendingAttachment(
    PendingAttachment replacement,
    Emitter<ChatState> emit,
  ) {
    final updated = state.pendingAttachments
        .map((pending) => pending.id == replacement.id ? replacement : pending)
        .toList();
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _removePendingAttachment(String attachmentId, Emitter<ChatState> emit) {
    final updated = state.pendingAttachments
        .where((pending) => pending.id != attachmentId)
        .toList();
    if (updated.length == state.pendingAttachments.length) return;
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _removePendingAttachmentsByIds(
    Iterable<String> attachmentIds,
    Emitter<ChatState> emit,
  ) {
    final ids = attachmentIds.toSet();
    if (ids.isEmpty) return;
    final updated = state.pendingAttachments
        .where((pending) => !ids.contains(pending.id))
        .toList();
    if (updated.length == state.pendingAttachments.length) return;
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _markPendingAttachmentFailed(
    String attachmentId,
    Emitter<ChatState> emit, {
    ChatMessageKey? message,
  }) {
    final updated = state.pendingAttachments.map((pending) {
      if (pending.id != attachmentId) return pending;
      return pending.copyWith(
        status: PendingAttachmentStatus.failed,
        errorMessage: message ?? ChatMessageKey.chatAttachmentSendFailed,
      );
    }).toList();
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _markPendingAttachmentsFailed(
    Iterable<PendingAttachment> attachments,
    Emitter<ChatState> emit, {
    ChatMessageKey? message,
  }) {
    final ids = attachments.map((attachment) => attachment.id).toSet();
    if (ids.isEmpty) return;
    final resolvedMessage = message ?? ChatMessageKey.chatAttachmentSendFailed;
    final updated = state.pendingAttachments.map((pending) {
      if (!ids.contains(pending.id)) return pending;
      return pending.copyWith(
        status: PendingAttachmentStatus.failed,
        errorMessage: resolvedMessage,
      );
    }).toList();
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _markPendingAttachmentsUploading(
    Iterable<PendingAttachment> attachments,
    Emitter<ChatState> emit,
  ) {
    final ids = attachments.map((attachment) => attachment.id).toSet();
    if (ids.isEmpty) return;
    var hasChanges = false;
    final updated = state.pendingAttachments.map((pending) {
      if (!ids.contains(pending.id)) return pending;
      final shouldClearError = pending.errorMessage != null;
      if (pending.status == PendingAttachmentStatus.uploading &&
          !shouldClearError) {
        return pending;
      }
      hasChanges = true;
      return pending.copyWith(
        status: PendingAttachmentStatus.uploading,
        clearErrorMessage: true,
      );
    }).toList();
    if (!hasChanges) return;
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _markPendingAttachmentsPreparing(
    Iterable<PendingAttachment> attachments,
    Emitter<ChatState> emit, {
    required bool preparing,
  }) {
    final ids = attachments.map((attachment) => attachment.id).toSet();
    if (ids.isEmpty) return;
    var hasChanges = false;
    final updated = state.pendingAttachments.map((pending) {
      if (!ids.contains(pending.id)) return pending;
      if (pending.isPreparing == preparing) return pending;
      hasChanges = true;
      return pending.copyWith(isPreparing: preparing);
    }).toList();
    if (!hasChanges) return;
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _queuePendingAttachments(
    Iterable<PendingAttachment> attachments,
    Emitter<ChatState> emit,
  ) {
    final ids = attachments.map((attachment) => attachment.id).toSet();
    if (ids.isEmpty) return;
    var hasChanges = false;
    final updated = state.pendingAttachments.map((pending) {
      if (!ids.contains(pending.id)) return pending;
      final shouldClearError = pending.errorMessage != null;
      if (pending.status == PendingAttachmentStatus.queued &&
          !shouldClearError) {
        return pending;
      }
      hasChanges = true;
      return pending.copyWith(
        status: PendingAttachmentStatus.queued,
        clearErrorMessage: true,
      );
    }).toList();
    if (!hasChanges) return;
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _handleBundledAttachmentSuccess(
    Iterable<PendingAttachment> attachments,
    Emitter<ChatState> emit, {
    required bool retainOnSuccess,
  }) {
    if (retainOnSuccess) {
      _queuePendingAttachments(attachments, emit);
      return;
    }
    _removePendingAttachmentsByIds(
      attachments.map((attachment) => attachment.id),
      emit,
    );
  }

  PendingAttachment? _pendingAttachmentById(String attachmentId) {
    for (final pending in state.pendingAttachments) {
      if (pending.id == attachmentId) {
        return pending;
      }
    }
    return null;
  }

  Future<void> _rehydrateXmppDraft(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final nextHydrationId = ++_composerHydrationSeed;
    emit(
      state.copyWith(
        pendingAttachments: const <PendingAttachment>[],
        composerHydrationId: nextHydrationId,
        composerHydrationText: message.plainText,
        composerError: message.error.isNotNone
            ? _chatMessageKeyForMessageError(message.error)
            : state.composerError,
      ),
    );
    final attachments = await _attachmentsForMessage(message);
    if (attachments.isEmpty) return;
    final pendingAttachments = <PendingAttachment>[];
    for (final attachment in attachments) {
      pendingAttachments.add(
        PendingAttachment(
          id: _nextPendingAttachmentId(),
          attachment: attachment,
        ),
      );
    }
    emit(state.copyWith(pendingAttachments: pendingAttachments));
  }

  Future<void> _saveXmppDraft({
    required Chat chat,
    required List<ComposerRecipient> recipients,
    required String body,
    required Iterable<PendingAttachment> attachments,
    required String? subject,
    required Message? quotedDraft,
    required Emitter<ChatState> emit,
  }) async {
    final hasAttachments = attachments.isNotEmpty;
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty && !hasAttachments) return;
    final resolvedRecipients = _draftRecipientJids(
      chat: chat,
      recipients: recipients,
    );
    if (resolvedRecipients.isEmpty) return;
    final attachmentPayload = attachments
        .map((pending) => pending.attachment)
        .toList();
    final quotedReference = quotedDraft == null
        ? null
        : _quotedMessageReference(quotedMessage: quotedDraft, chat: chat);
    try {
      await _messageService.saveDraft(
        id: null,
        jids: resolvedRecipients,
        body: trimmedBody,
        subject: subject,
        quotingStanzaId: quotedReference?.value,
        quotingReferenceKind: quotedReference?.kind,
        attachments: attachmentPayload,
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

  Future<List<EmailAttachment>> _attachmentsForMessage(Message message) async {
    final messageId = message.id;
    final db = await _messageService.database;
    final metadataIds = <String>[];
    if (messageId != null && messageId.isNotEmpty) {
      var attachments = await db.getMessageAttachments(messageId);
      if (attachments.isNotEmpty) {
        final transportGroupId = attachments.first.transportGroupId?.trim();
        if (transportGroupId != null && transportGroupId.isNotEmpty) {
          attachments = await db.getMessageAttachmentsForGroup(
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

  Future<List<EmailAttachment>> _attachmentsFromMetadataIds(
    Iterable<String> metadataIds,
  ) async {
    final db = await _messageService.database;
    final orderedIds = LinkedHashSet<String>.from(metadataIds);
    if (orderedIds.isEmpty) return const [];
    final resolved = <EmailAttachment>[];
    for (final metadataId in orderedIds) {
      final metadata = await db.getFileMetadata(metadataId);
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
        EmailAttachment(
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
      _shareContextAttemptedStanzaIds.add(message.stanzaID);
      final context = await emailService.shareContextForMessage(message);
      if (context != null) {
        pending[message.stanzaID] = context;
      }
    }
    if (pending.isEmpty) return;
    final contexts = Map<String, ShareContext>.from(state.shareContexts)
      ..addAll(pending);
    emit(state.copyWith(shareContexts: contexts));
  }

  Future<void> _hydrateShareReplies(
    List<Message> messages,
    Emitter<ChatState> emit,
  ) async {
    final database = await _messageService.database;
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
      final shareMessages = await database.getMessagesForShare(shareId);
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
    emit(state.copyWith(shareReplies: replies));
  }

  Future<void> _resendEmailMessage(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    final service = _emailService;
    if (chat == null || service == null) return;
    final resolvedBody = message.plainText.trim();
    final normalizedHtml = message.normalizedHtmlBody;
    final hasBody = resolvedBody.isNotEmpty;
    final attachments = await _attachmentsForMessage(message);
    final hasAttachment = attachments.isNotEmpty;
    if (!hasBody && !hasAttachment) {
      return;
    }
    ShareContext? shareContext = state.shareContexts[message.stanzaID];
    shareContext ??= await service.shareContextForMessage(message);
    try {
      final resent = await service.resendMessages([message]);
      if (resent) {
        return;
      }
      if (hasAttachment) {
        final caption = hasBody ? resolvedBody : null;
        final bool shouldBundle =
            attachments.length >= _emailAttachmentBundleMinimumCount;
        final bundled = await _bundleEmailAttachmentList(
          attachments: attachments,
          caption: caption,
        );
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
          );
        }
        if (shouldBundle && bundled.isNotEmpty) {
          EmailAttachmentBundler.scheduleCleanup(bundled.first);
        }
        return;
      }
      if (hasBody) {
        await service.sendMessage(
          chat: chat,
          body: resolvedBody,
          subject: shareContext?.subject,
          htmlBody: normalizedHtml,
        );
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
  }
}
