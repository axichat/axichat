import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:async/async.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/common/event_transform.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/demo/demo_chats.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/scheduler.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'chat_bloc.freezed.dart';
part 'chat_event.dart';
part 'chat_state.dart';

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
  }) =>
      ComposerRecipient(
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
  });

  final String? body;
  final EmailAttachment? attachment;
  final String shareId;
  final String? subject;

  @override
  List<Object?> get props => [body, attachment, shareId, subject];
}

enum ChatToastVariant { info, warning, destructive }

class ChatToast extends Equatable {
  const ChatToast({
    required this.message,
    this.variant = ChatToastVariant.info,
  });

  final String message;
  final ChatToastVariant variant;

  bool get isDestructive => variant == ChatToastVariant.destructive;

  @override
  List<Object?> get props => [message, variant];
}

enum MamPageDirection { before, after }

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  static final Set<String> _seededDemoPendingAttachmentJids = <String>{};

  ChatBloc({
    required this.jid,
    required MessageService messageService,
    required ChatsService chatsService,
    required NotificationService notificationService,
    required MucService mucService,
    required SettingsCubit settingsCubit,
    EmailService? emailService,
    OmemoService? omemoService,
  })  : _messageService = messageService,
        _chatsService = chatsService,
        _notificationService = notificationService,
        _emailService = emailService,
        _omemoService = omemoService,
        _mucService = mucService,
        _settingsCubit = settingsCubit,
        _settingsState = settingsCubit.state,
        super(const ChatState(items: [])) {
    on<_ChatUpdated>(_onChatUpdated);
    on<_ChatMessagesUpdated>(_onChatMessagesUpdated);
    on<_RoomStateUpdated>(_onRoomStateUpdated);
    on<_EmailSyncStateChanged>(_onEmailSyncStateChanged);
    on<_XmppConnectionStateChanged>(_onXmppConnectionStateChanged);
    on<ChatMessageFocused>(_onChatMessageFocused);
    on<ChatTypingStarted>(_onChatTypingStarted);
    on<_ChatTypingStopped>(_onChatTypingStopped);
    on<_TypingParticipantsUpdated>(_onTypingParticipantsUpdated);
    on<ChatMessageSent>(
      _onChatMessageSent,
      transformer: blocThrottle(downTime),
    );
    on<ChatMuted>(_onChatMuted);
    on<ChatShareSignatureToggled>(_onChatShareSignatureToggled);
    on<ChatResponsivityChanged>(_onChatResponsivityChanged);
    on<ChatEncryptionChanged>(_onChatEncryptionChanged);
    on<ChatEncryptionRepaired>(_onChatEncryptionRepaired);
    on<ChatLoadEarlier>(_onChatLoadEarlier);
    on<ChatAlertHidden>(_onChatAlertHidden);
    on<ChatQuoteRequested>(_onChatQuoteRequested);
    on<ChatQuoteCleared>(_onChatQuoteCleared);
    on<ChatMessageReactionToggled>(_onChatMessageReactionToggled);
    on<ChatMessageForwardRequested>(_onChatMessageForwardRequested);
    on<ChatMessageResendRequested>(_onChatMessageResendRequested);
    on<ChatInviteRequested>(_onChatInviteRequested);
    on<ChatModerationActionRequested>(_onChatModerationActionRequested);
    on<ChatMessageEditRequested>(_onChatMessageEditRequested);
    on<_HttpUploadSupportUpdated>(_onHttpUploadSupportUpdated);
    on<ChatAttachmentPicked>(_onChatAttachmentPicked);
    on<ChatAttachmentRetryRequested>(_onChatAttachmentRetryRequested);
    on<ChatPendingAttachmentRemoved>(_onChatPendingAttachmentRemoved);
    on<ChatViewFilterChanged>(_onChatViewFilterChanged);
    on<ChatComposerRecipientAdded>(_onComposerRecipientAdded);
    on<ChatComposerRecipientRemoved>(_onComposerRecipientRemoved);
    on<ChatComposerRecipientToggled>(_onComposerRecipientToggled);
    on<ChatFanOutRetryRequested>(_onFanOutRetryRequested);
    on<ChatSubjectChanged>(
      _onChatSubjectChanged,
      transformer: blocDebounce(const Duration(milliseconds: 200)),
    );
    on<ChatInviteRevocationRequested>(_onInviteRevocationRequested);
    on<ChatInviteJoinRequested>(_onInviteJoinRequested);
    on<ChatLeaveRoomRequested>(_onLeaveRoomRequested);
    on<ChatNicknameChangeRequested>(_onNicknameChangeRequested);
    on<ChatContactRenameRequested>(_onContactRenameRequested);
    on<ChatEmailImagesLoaded>(_onEmailImagesLoaded);
    if (jid != null) {
      final chatLookupJid = _chatLookupJid;
      if (chatLookupJid == null) return;
      _notificationService.dismissNotifications();
      _chatSubscription = _chatsService
          .chatStream(chatLookupJid)
          .listen((chat) => chat == null ? null : add(_ChatUpdated(chat)));
      _subscribeToMessages(limit: messageBatchSize, filter: state.viewFilter);
      unawaited(_initializeViewFilter());
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
        (connectionState) {
          add(_XmppConnectionStateChanged(connectionState));
          if (connectionState == ConnectionState.connected) {
            final chat = state.chat;
            if (chat != null && _xmppAllowedForChat(chat)) {
              unawaited(_catchUpFromMam());
              unawaited(_prefetchPeerAvatar(chat));
            }
          }
        },
      );
      _httpUploadSupportSubscription =
          xmppService.httpUploadSupportStream.listen(
        (support) => add(_HttpUploadSupportUpdated(support.supported)),
      );
      add(_HttpUploadSupportUpdated(xmppService.httpUploadSupport.supported));
    }
    _settingsSubscription = _settingsCubit.stream.listen((state) {
      _settingsState = state;
    });
  }

  static const messageBatchSize = 50;
  static final RegExp _axiDomainPattern =
      RegExp(r'@(?:[\\w-]+\\.)*axi\\.im$', caseSensitive: false);
  static const CalendarFragmentPolicy _calendarFragmentPolicy =
      CalendarFragmentPolicy();
  bool _isEmailOnlyAddress(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (!normalized.contains('@')) {
      return false;
    }
    return !_axiDomainPattern.hasMatch(normalized);
  }

  bool get _forceAllWithContactViewFilter {
    return _isEmailChat;
  }

  final String? jid;
  late final String? _chatLookupJid = jid == null
      ? null
      : _isEmailOnlyAddress(jid)
          ? jid!.trim().toLowerCase()
          : jid;
  final MessageService _messageService;
  XmppService? _xmppService;
  final ChatsService _chatsService;
  final NotificationService _notificationService;
  final EmailService? _emailService;
  final OmemoService? _omemoService;
  final MucService _mucService;
  final SettingsCubit _settingsCubit;
  SettingsState _settingsState;
  final Logger _log = Logger('ChatBloc');
  var _pendingAttachmentSeed = 0;
  var _composerHydrationSeed = 0;
  String? _lastOfflineDraftSignature;

  late final StreamSubscription<Chat?> _chatSubscription;
  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<RoomState>? _roomSubscription;
  StreamSubscription<List<String>>? _typingParticipantsSubscription;
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;
  StreamSubscription<ConnectionState>? _connectivitySubscription;
  StreamSubscription<HttpUploadSupport>? _httpUploadSupportSubscription;
  StreamSubscription<SettingsState>? _settingsSubscription;
  var _currentMessageLimit = messageBatchSize;
  String? _emailSyncComposerMessage;
  String? _mamBeforeId;
  int? _mamTotalCount;
  bool _mamComplete = false;
  bool _mamLoading = false;
  bool _mamCatchingUp = false;
  bool _emailHistoryLoading = false;
  Completer<void>? _mamLoadingCompleter;

  RestartableTimer? _typingTimer;

  bool get encryptionAvailable => _omemoService != null;
  bool get _isEmailChat => state.chat?.defaultTransport.isEmail ?? false;
  String? _bareJid(String? jid) {
    if (jid == null || jid.isEmpty) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } on Exception {
      return jid;
    }
  }

  bool _isAxiDomainJid(String? value) {
    final bare = _bareJid(value);
    if (bare == null) return false;
    final normalized = bare.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _axiDomainPattern.hasMatch(normalized);
  }

  bool _xmppAllowedForChat(Chat chat) {
    if (chat.defaultTransport.isEmail) return false;
    final candidate = chat.remoteJid.isNotEmpty ? chat.remoteJid : chat.jid;
    return _isAxiDomainJid(candidate);
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
    if (_messageService.messageStorageMode.isServerOnly) {
      final visibleMessages = state.items.where(
        (message) =>
            message.pseudoMessageType == null ||
            message.pseudoMessageType!.isCalendarFragment,
      );
      return Future<int>.value(visibleMessages.length);
    }
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
    if (!_xmppAllowedForChat(chat)) return;
    final localCount = await _archivedMessageCount(chat);
    if (localCount >= desiredWindow) return;
    final beforeId = _mamBeforeId ??
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
      _log.fine(
        'Failed to load older MAM page for ${chat.jid}',
        error,
        stackTrace,
      );
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

  Future<void> _catchUpFromMam() async {
    final chat = state.chat;
    if (chat == null) return;
    if (!_xmppAllowedForChat(chat)) return;
    final lastSeen = await _messageService.loadLastSeenTimestamp(
      chat.remoteJid,
    );
    if (lastSeen == null) return;
    if (_mamCatchingUp) return;
    if (_mamLoading && _mamLoadingCompleter != null) {
      await _mamLoadingCompleter!.future;
    }
    _mamCatchingUp = true;
    _beginMamLoad();
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
      _log.fine(
        'Failed to catch up via MAM for ${chat.jid}',
        error,
        stackTrace,
      );
    }
    _finishMamLoad();
    _mamCatchingUp = false;
  }

  Future<void> _initializeViewFilter() async {
    if (jid == null) return;
    if (_forceAllWithContactViewFilter) return;
    try {
      final filter = await _chatsService.loadChatViewFilter(jid!);
      add(ChatViewFilterChanged(filter: filter, persist: false));
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to load view filter for $jid', error, stackTrace);
    }
  }

  void _resetMamCursors(bool resetContext) {
    if (!resetContext) return;
    _mamBeforeId = null;
    _mamTotalCount = null;
    _mamComplete = false;
    _mamLoading = false;
    _mamCatchingUp = false;
    _mamLoadingCompleter?.complete();
    _mamLoadingCompleter = null;
  }

  Future<void> _hydrateLatestFromMam(Chat chat) async {
    if (!_xmppAllowedForChat(chat)) return;
    if (_mamLoading || _mamComplete || _mamBeforeId != null) return;
    final localCount = await _archivedMessageCount(chat);
    if (localCount >= _currentMessageLimit) return;
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
      _log.fine(
        'Failed to hydrate MAM for chat ${chat.jid}',
        error,
        stackTrace,
      );
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
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Failed to ensure membership for ${chat.jid}',
        error,
        stackTrace,
      );
    }
  }

  void _subscribeToMessages({
    required int limit,
    required MessageTimelineFilter filter,
    bool forceXmppFallback = false,
  }) {
    final targetJid = state.chat?.jid ?? _chatLookupJid ?? jid;
    if (targetJid == null) return;
    unawaited(_messageSubscription?.cancel());
    _currentMessageLimit = limit;
    final chat = state.chat;
    final emailService = _emailService;
    final useEmailService =
        !forceXmppFallback && chat?.defaultTransport.isEmail == true;
    if (useEmailService && emailService != null) {
      _messageSubscription = emailService
          .messageStreamForChat(
        targetJid,
        end: limit,
        filter: filter,
      )
          .listen(
        (items) => add(_ChatMessagesUpdated(items)),
        onError: (Object error, StackTrace stackTrace) {
          _log.fine('Email message stream failed', error, stackTrace);
          _subscribeToMessages(
            limit: limit,
            filter: filter,
            forceXmppFallback: true,
          );
        },
      );
      return;
    }
    _messageSubscription = _messageService
        .messageStreamForChat(
          targetJid,
          end: limit,
          filter: filter,
        )
        .listen((items) => add(_ChatMessagesUpdated(items)));
  }

  void _subscribeToTypingParticipants(Chat chat) {
    if (!_xmppAllowedForChat(chat)) {
      unawaited(_typingParticipantsSubscription?.cancel());
      _typingParticipantsSubscription = null;
      return;
    }
    unawaited(_typingParticipantsSubscription?.cancel());
    _typingParticipantsSubscription = _chatsService
        .typingParticipantsStream(chat.jid)
        .listen(
            (participants) => add(_TypingParticipantsUpdated(participants)));
  }

  @override
  Future<void> close() async {
    await _chatSubscription.cancel();
    await _messageSubscription?.cancel();
    await _roomSubscription?.cancel();
    await _typingParticipantsSubscription?.cancel();
    await _emailSyncSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _httpUploadSupportSubscription?.cancel();
    await _settingsSubscription?.cancel();
    _typingTimer?.cancel();
    _typingTimer = null;
    return super.close();
  }

  Future<void> _onChatUpdated(
    _ChatUpdated event,
    Emitter<ChatState> emit,
  ) async {
    final previousChat = state.chat;
    final resetContext = previousChat?.jid != event.chat.jid;
    final typingContextChanged = resetContext ||
        previousChat?.defaultTransport != event.chat.defaultTransport;
    final typingShouldClear =
        typingContextChanged || event.chat.defaultTransport.isEmail;
    const forcedViewFilter = MessageTimelineFilter.allWithContact;
    final nextViewFilter = resetContext && event.chat.defaultTransport.isEmail
        ? forcedViewFilter
        : state.viewFilter;
    emit(state.copyWith(
      chat: event.chat,
      showAlert: event.chat.alert != null && state.chat?.alert == null,
      recipients: _syncRecipientsForChat(event.chat),
      fanOutReports: resetContext ? const {} : state.fanOutReports,
      fanOutDrafts: resetContext ? const {} : state.fanOutDrafts,
      shareContexts: resetContext ? const {} : state.shareContexts,
      composerError: resetContext ? null : state.composerError,
      composerHydrationText: resetContext ? null : state.composerHydrationText,
      composerHydrationId: resetContext ? 0 : state.composerHydrationId,
      emailSubject: resetContext ? null : state.emailSubject,
      emailSubjectHydrationText:
          resetContext ? null : state.emailSubjectHydrationText,
      emailSubjectHydrationId: resetContext ? 0 : state.emailSubjectHydrationId,
      roomState: resetContext ? null : state.roomState,
      typingParticipants:
          typingShouldClear ? const [] : state.typingParticipants,
      typing: event.chat.defaultTransport.isEmail ? false : state.typing,
      viewFilter: nextViewFilter,
    ));
    if (resetContext) {
      _subscribeToMessages(
        limit: _currentMessageLimit,
        filter: state.viewFilter,
      );
      unawaited(_prefetchPeerAvatar(event.chat));
    }
    if (typingContextChanged) {
      _subscribeToTypingParticipants(event.chat);
    }
    _resetMamCursors(resetContext);
    if (_xmppAllowedForChat(event.chat)) {
      unawaited(_hydrateLatestFromMam(event.chat));
    }
    unawaited(_roomSubscription?.cancel());
    if (event.chat.type == ChatType.groupChat) {
      _roomSubscription = _mucService
          .roomStateStream(event.chat.jid)
          .listen((room) => add(_RoomStateUpdated(room)));
      if (resetContext || state.roomState == null) {
        _primeRoomState(event.chat);
      }
      if (!resetContext && state.items.isNotEmpty) {
        _mucService.trackOccupantsFromMessages(event.chat.jid, state.items);
      }
      unawaited(_ensureMucMembership(event.chat));
    } else {
      emit(state.copyWith(roomState: null));
    }
    await _primeDemoPendingAttachment(event.chat, emit);
  }

  void _onRoomStateUpdated(
    _RoomStateUpdated event,
    Emitter<ChatState> emit,
  ) {
    final chatJid = _bareJid(state.chat?.jid);
    if (chatJid == null) return;
    if (chatJid != _bareJid(event.roomState.roomJid)) return;
    emit(state.copyWith(roomState: event.roomState));
  }

  void _primeRoomState(Chat chat) {
    if (chat.type == ChatType.groupChat) {
      unawaited(_mucService.seedDummyRoomData(chat.jid));
    }
    final cachedRoom = _mucService.roomStateFor(chat.jid);
    if (cachedRoom != null) {
      add(_RoomStateUpdated(cachedRoom));
    }
    unawaited(() async {
      try {
        final warmed = await _mucService.warmRoomFromHistory(roomJid: chat.jid);
        if (isClosed) return;
        if (_bareJid(state.chat?.jid) != _bareJid(chat.jid)) return;
        if (state.roomState != null) return;
        add(_RoomStateUpdated(warmed));
      } on Exception catch (error, stackTrace) {
        _log.fine(
          'Failed to warm room state for ${chat.jid}',
          error,
          stackTrace,
        );
      }
    }());
  }

  Future<void> _primeDemoPendingAttachment(
    Chat chat,
    Emitter<ChatState> emit,
  ) async {
    if (!kEnableDemoChats) return;
    final chatJid = _bareJid(chat.jid);
    if (chatJid == null || chatJid != DemoChats.groupJid) return;
    if (_seededDemoPendingAttachmentJids.contains(chatJid)) return;
    final service = _messageService;
    if (service is! XmppService) {
      return;
    }
    final existingFileNames = state.pendingAttachments
        .map((pending) => pending.attachment.fileName)
        .toSet();
    final pendingToAdd = <PendingAttachment>[];
    for (final asset in DemoChats.composerAttachments) {
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
    _seededDemoPendingAttachmentJids.add(chatJid);
  }

  Future<void> _onChatMessagesUpdated(
    _ChatMessagesUpdated event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(items: event.items, messagesLoaded: true));
    if (state.chat?.type == ChatType.groupChat) {
      _mucService.trackOccupantsFromMessages(state.chat!.jid, event.items);
    }
    if (state.chat?.supportsEmail == true) {
      await _hydrateShareContexts(event.items, emit);
      await _hydrateShareReplies(event.items, emit);
    }

    final chat = state.chat;
    final lifecycleState = SchedulerBinding.instance.lifecycleState;
    if (chat != null &&
        _xmppAllowedForChat(chat) &&
        chat.type != ChatType.groupChat &&
        lifecycleState == AppLifecycleState.resumed) {
      final selfBare = _bareJid(_chatsService.myJid);
      for (final item in event.items) {
        if (!item.displayed &&
            _bareJid(item.senderJid) != selfBare &&
            item.body?.isNotEmpty == true) {
          _messageService.sendReadMarker(chat.jid, item.stanzaID);
        }
      }
    }
  }

  Future<void> _onChatInviteRequested(
    ChatInviteRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null || chat.type != ChatType.groupChat) {
      return;
    }
    final roomState = state.roomState;
    if (roomState == null) {
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: 'Room members are still loading.',
            variant: ChatToastVariant.warning,
          ),
          toastId: state.toastId + 1,
        ),
      );
      return;
    }
    final canInvite = roomState.myAffiliation.isOwner ||
        roomState.myAffiliation.isAdmin ||
        roomState.myRole.isModerator;
    if (!canInvite) {
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: 'You do not have permission to invite users to this room.',
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
            message: 'Invites are limited to the default domain.',
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
            toast: const ChatToast(message: 'User is already a member'),
            toastId: state.toastId + 1,
          ),
        );
        return;
      }
    }
    try {
      await _mucService.inviteUserToRoom(
        roomJid: chat.jid,
        inviteeJid: event.jid,
        reason: event.reason,
      );
      emit(
        state.copyWith(
          toast: const ChatToast(message: 'Invite sent'),
          toastId: state.toastId + 1,
        ),
      );
    } catch (error, stackTrace) {
      _log.fine(
        'Failed to send room invite',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: 'Failed to send invite.',
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
    final invitee = data['invitee'] as String? ?? state.chat?.jid;
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
          toast: const ChatToast(message: 'Invite revoked'),
          toastId: state.toastId + 1,
        ),
      );
    } catch (error, stackTrace) {
      _log.warning('Failed to revoke invite $token', error, stackTrace);
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: 'Failed to revoke invite',
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
    final trimmedRoomName = roomName?.trim();
    const fallbackRoomName = 'group chat';
    final resolvedRoomName = trimmedRoomName?.isNotEmpty == true
        ? trimmedRoomName!
        : fallbackRoomName;
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
          toast: ChatToast(message: "Joined '$resolvedRoomName'"),
          toastId: state.toastId + 1,
        ),
      );
    } catch (error, stackTrace) {
      _log.warning('Failed to join invited room', error, stackTrace);
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: 'Could not join room',
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
    final chatJid = state.chat?.jid;
    if (chatJid == null || state.chat?.type != ChatType.groupChat) return;
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
    final chatJid = state.chat?.jid;
    if (chatJid == null || state.chat?.type != ChatType.groupChat) return;
    final trimmed = event.nickname.trim();
    if (trimmed.isEmpty) return;
    try {
      await _mucService.changeNickname(
        roomJid: chatJid,
        nickname: trimmed,
      );
      emit(
        state.copyWith(
          chat: state.chat?.copyWith(myNickname: trimmed),
          roomState: _mucService.roomStateFor(chatJid) ?? state.roomState,
          toast: const ChatToast(message: 'Nickname updated'),
          toastId: state.toastId + 1,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to change nickname for $chatJid', error, stackTrace);
      emit(
        state.copyWith(
          toast: const ChatToast(
            message: 'Could not change nickname',
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
    final chat = state.chat;
    if (chat == null || chat.type != ChatType.chat) return;
    final trimmed = event.displayName.trim();
    final alias = trimmed.isEmpty ? null : trimmed;
    try {
      await _chatsService.renameChatContact(
        jid: chat.jid,
        displayName: trimmed,
      );
      emit(
        state.copyWith(
          chat: chat.copyWith(
            contactDisplayName: alias,
          ),
          toast: ChatToast(message: event.successMessage),
          toastId: state.toastId + 1,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to rename contact ${chat.jid}', error, stackTrace);
      emit(
        state.copyWith(
          toast: ChatToast(
            message: event.failureMessage,
            variant: ChatToastVariant.destructive,
          ),
          toastId: state.toastId + 1,
        ),
      );
    }
  }

  void _onEmailImagesLoaded(
    ChatEmailImagesLoaded event,
    Emitter<ChatState> emit,
  ) {
    emit(
      state.copyWith(
        loadedImageMessageIds: {
          ...state.loadedImageMessageIds,
          event.messageId
        },
      ),
    );
  }

  Future<void> _onChatModerationActionRequested(
    ChatModerationActionRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null ||
        chat.type != ChatType.groupChat ||
        state.roomState == null) {
      return;
    }
    final occupant = state.roomState!.occupants[event.occupantId];
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
            message: 'Requested ${event.action.name} for ${occupant.nick}',
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
            message:
                'Could not complete that action. Check permissions or connectivity.',
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
    final nextState = event.state;
    if (!_isEmailChat) {
      if (state.emailSyncState != nextState) {
        emit(state.copyWith(emailSyncState: nextState));
      }
      return;
    }
    var composerError = state.composerError;
    if (nextState.status == EmailSyncStatus.ready) {
      if (composerError != null && composerError == _emailSyncComposerMessage) {
        composerError = null;
      }
      _emailSyncComposerMessage = null;
      _lastOfflineDraftSignature = null;
    } else {
      final fallback = nextState.status == EmailSyncStatus.offline
          ? 'Email is offline. Messages will be saved to Drafts until the connection returns.'
          : nextState.status == EmailSyncStatus.recovering
              ? 'Email sync is refreshing…'
              : 'Email sync failed. Please try again.';
      final message = nextState.message ?? fallback;
      _emailSyncComposerMessage = message;
      composerError = message;
    }
    emit(
      state.copyWith(
        emailSyncState: nextState,
        composerError: composerError,
      ),
    );
  }

  void _onXmppConnectionStateChanged(
    _XmppConnectionStateChanged event,
    Emitter<ChatState> emit,
  ) {
    if (state.xmppConnectionState == event.state) return;
    emit(state.copyWith(xmppConnectionState: event.state));
    final chat = state.chat;
    if (event.state == ConnectionState.connected &&
        chat?.type == ChatType.groupChat) {
      unawaited(_ensureMucMembership(chat!));
    }
  }

  void _onHttpUploadSupportUpdated(
    _HttpUploadSupportUpdated event,
    Emitter<ChatState> emit,
  ) {
    if (state.supportsHttpFileUpload == event.supported) return;
    emit(state.copyWith(supportsHttpFileUpload: event.supported));
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
        return;
      }
    }
    emit(state.copyWith(focused: target));
  }

  Future<void> _onChatTypingStarted(
      ChatTypingStarted event, Emitter<ChatState> emit) async {
    if (_isEmailChat) {
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
        () => add(const _ChatTypingStopped()),
      );
    }
    await _chatsService.sendTyping(jid: state.chat!.jid, typing: true);
    emit(state.copyWith(typing: true));
  }

  void _onChatTypingStopped(_ChatTypingStopped event, Emitter<ChatState> emit) {
    _stopTyping();
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
    _stopTyping();
    emit(state.copyWith(typing: false));
    final chat = state.chat;
    if (chat == null) return;
    final trimmedText = event.text.trim();
    final CalendarFragment? requestedFragment = event.calendarFragment;
    final CalendarFragmentShareDecision fragmentDecision =
        _calendarFragmentPolicy.decisionForChat(
      chat: chat,
      roomState: state.roomState,
    );
    final CalendarFragment? effectiveFragment =
        requestedFragment == null || !fragmentDecision.canWrite
            ? null
            : requestedFragment;
    final attachments = List<PendingAttachment>.from(state.pendingAttachments);
    final queuedAttachments = attachments
        .where((attachment) =>
            attachment.status == PendingAttachmentStatus.queued &&
            !attachment.isPreparing)
        .toList();
    final hasQueuedAttachments = queuedAttachments.isNotEmpty;
    final hasSubject = state.emailSubject?.trim().isNotEmpty == true;
    final quotedDraft = state.quoting;
    if (trimmedText.isEmpty && !hasQueuedAttachments && !hasSubject) {
      emit(
        state.copyWith(
          composerError: 'Message cannot be empty.',
        ),
      );
      return;
    }
    if (state.composerError != null) {
      emit(state.copyWith(composerError: null));
    }
    if (chat.type == ChatType.groupChat) {
      await _ensureMucMembership(chat);
    }
    final recipients = _resolveComposerRecipients(chat);
    final split = _splitRecipientsForSend(
      recipients: recipients,
      forceEmail: false,
    );
    final emailRecipients = split.emailRecipients;
    final xmppRecipients = split.xmppRecipients;
    final attachmentsViaEmail =
        hasQueuedAttachments && emailRecipients.isNotEmpty;
    final attachmentsViaXmpp =
        hasQueuedAttachments && xmppRecipients.isNotEmpty;
    final requiresEmail = emailRecipients.isNotEmpty || attachmentsViaEmail;
    final xmppBody = _composeXmppBody(
      body: trimmedText,
      subject: state.emailSubject,
    );
    final hasXmppBody = xmppBody.isNotEmpty;
    final CalendarFragment? fragmentForXmpp =
        hasQueuedAttachments ? null : effectiveFragment;
    final Chat? soleRecipientChat =
        xmppRecipients.length == 1 ? xmppRecipients.first.target.chat : null;
    final CalendarFragment? fanOutFragment =
        soleRecipientChat?.jid == chat.jid ? fragmentForXmpp : null;
    final service = _emailService;
    if (requiresEmail && service == null) {
      emit(
        state.copyWith(
          composerError: 'Email sending is unavailable for this chat.',
        ),
      );
      return;
    }
    var emailSendSucceeded = false;
    var xmppSendSucceeded = false;
    try {
      if (requiresEmail) {
        if (emailRecipients.isEmpty) {
          emit(
            state.copyWith(
              composerError: 'Select at least one recipient.',
            ),
          );
          return;
        }
        final invalidEmailRecipients = emailRecipients.where(
          (recipient) {
            final targetChat = recipient.target.chat;
            if (targetChat != null) {
              return !_isEmailCapableChat(targetChat);
            }
            return recipient.target.address?.isNotEmpty != true;
          },
        );
        if (invalidEmailRecipients.isNotEmpty) {
          emit(
            state.copyWith(
              composerError: 'Email is unavailable for one or more recipients.',
            ),
          );
          return;
        }
        final hasBody = trimmedText.isNotEmpty;
        final body = hasBody
            ? _composeEmailBody(trimmedText, quotedDraft)
            : (hasSubject ? '' : null);
        if (state.emailSyncState.requiresAttention) {
          await _handleBrokenEmailSend(
            chat: chat,
            recipients: emailRecipients,
            rawText: trimmedText,
            quotedDraft: quotedDraft,
            emit: emit,
          );
          return;
        }
        var emailAttachmentsToSend = queuedAttachments;
        if (attachmentsViaEmail && queuedAttachments.length > 1) {
          try {
            emailAttachmentsToSend = await _bundleEmailAttachments(
              attachments: queuedAttachments,
              caption: body,
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
                    'Unable to bundle attachments. Please try again.',
              ),
            );
            return;
          }
        }
        final shouldSendEmailText = body != null && !attachmentsViaEmail;
        if (shouldSendEmailText) {
          final shouldFanOut = _shouldFanOut(emailRecipients, chat);
          if (shouldFanOut) {
            final sent = await _sendFanOut(
              recipients: emailRecipients,
              text: body,
              subject: state.emailSubject,
              emit: emit,
            );
            if (!sent) {
              return;
            }
          } else {
            await service!.sendMessage(
              chat: chat,
              body: body,
              subject: state.emailSubject,
            );
          }
          emailSendSucceeded = true;
        }
        if (attachmentsViaEmail) {
          final captionForAttachments = hasBody ? body : null;
          await _sendQueuedAttachments(
            attachments: emailAttachmentsToSend,
            chat: chat,
            service: service!,
            recipients: emailRecipients,
            emit: emit,
            retainOnSuccess: attachmentsViaXmpp,
            captionForFirstAttachment: captionForAttachments,
          );
          emailSendSucceeded = true;
        }
      }
      if (attachmentsViaXmpp) {
        final sent = await _sendXmppAttachments(
          attachments: queuedAttachments,
          chat: chat,
          recipients: xmppRecipients,
          emit: emit,
          quotedDraft: quotedDraft,
          caption: hasXmppBody ? xmppBody : null,
        );
        if (!sent) {
          return;
        }
        xmppSendSucceeded = true;
      } else if (xmppRecipients.isNotEmpty && hasXmppBody) {
        await _sendXmppFanOut(
          recipients: xmppRecipients,
          body: xmppBody,
          calendarFragment: fanOutFragment,
          quotedDraft: quotedDraft,
        );
        xmppSendSucceeded = true;
      } else if (!requiresEmail && hasXmppBody) {
        final sameChatQuote =
            quotedDraft != null && quotedDraft.chatJid == chat.jid
                ? quotedDraft
                : null;
        await _messageService.sendMessage(
          jid: chat.jid,
          text: xmppBody,
          encryptionProtocol: chat.encryptionProtocol,
          quotedMessage: sameChatQuote,
          calendarFragment: fragmentForXmpp,
          chatType: chat.type,
        );
        xmppSendSucceeded = true;
      }
    } on DeltaChatException catch (error, stackTrace) {
      _log.warning(
        'Failed to send email message for chat ${chat.jid}',
        error,
        stackTrace,
      );
      if (requiresEmail) {
        final mappedError = DeltaErrorMapper.resolve(error.message);
        final nextHydrationId = ++_composerHydrationSeed;
        emit(
          state.copyWith(
            composerError: mappedError.asString,
            composerHydrationId: nextHydrationId,
            composerHydrationText: trimmedText,
          ),
        );
      }
    } on XmppMessageException catch (_) {
      await _saveXmppDraft(
        chat: chat,
        recipients: xmppRecipients,
        body: trimmedText,
        attachments: queuedAttachments,
        emit: emit,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to send message for chat ${chat.jid}',
        error,
        stackTrace,
      );
      await _saveXmppDraft(
        chat: chat,
        recipients: xmppRecipients,
        body: trimmedText,
        attachments: queuedAttachments,
        emit: emit,
      );
    } finally {
      if ((emailSendSucceeded || xmppSendSucceeded) &&
          queuedAttachments.isNotEmpty) {
        _removePendingAttachmentsByIds(
          queuedAttachments.map((pending) => pending.id),
          emit,
        );
      }
      if (state.quoting != null) {
        emit(state.copyWith(quoting: null));
      }
      if ((emailSendSucceeded || xmppSendSucceeded) &&
          (state.emailSubject?.isNotEmpty ?? false)) {
        _clearEmailSubject(emit);
      }
    }
  }

  Future<void> _onChatMuted(
    ChatMuted event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.toggleChatMuted(jid: jid!, muted: event.muted);
  }

  Future<void> _onChatShareSignatureToggled(
    ChatShareSignatureToggled event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null) return;
    await _chatsService.toggleChatShareSignature(
      jid: chat.jid,
      enabled: event.enabled,
    );
    emit(
      state.copyWith(
        chat: chat.copyWith(shareSignatureEnabled: event.enabled),
      ),
    );
  }

  Future<void> _onChatResponsivityChanged(
    ChatResponsivityChanged event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.toggleChatMarkerResponsive(
        jid: jid!, responsive: event.responsive);
  }

  Future<void> _onChatEncryptionChanged(
    ChatEncryptionChanged event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.setChatEncryption(jid: jid!, protocol: event.protocol);
  }

  Future<void> _onChatEncryptionRepaired(
    ChatEncryptionRepaired event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _omemoService?.recreateSessions(jid: jid!);
  }

  Future<void> _onChatLoadEarlier(
    ChatLoadEarlier event,
    Emitter<ChatState> emit,
  ) async {
    final nextLimit = state.items.length + messageBatchSize;
    _subscribeToMessages(limit: nextLimit, filter: state.viewFilter);
    if (_isEmailChat) {
      await _loadEarlierFromEmail(desiredWindow: nextLimit);
      return;
    }
    await _loadEarlierFromMam(desiredWindow: nextLimit);
  }

  Future<void> _onChatAlertHidden(
    ChatAlertHidden event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    emit(state.copyWith(showAlert: false));
    if (event.forever) {
      await _chatsService.clearChatAlert(jid: jid!);
    }
  }

  void _onChatQuoteRequested(
    ChatQuoteRequested event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(quoting: event.message));
  }

  void _onChatQuoteCleared(
    ChatQuoteCleared event,
    Emitter<ChatState> emit,
  ) {
    if (state.quoting != null) {
      emit(state.copyWith(quoting: null));
    }
  }

  Future<void> _onChatMessageReactionToggled(
    ChatMessageReactionToggled event,
    Emitter<ChatState> emit,
  ) async {
    if (_isEmailChat) return;
    try {
      await _messageService.reactToMessage(
        stanzaID: event.message.stanzaID,
        emoji: event.emoji,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Failed to react to message ${event.message.stanzaID}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _onChatMessageForwardRequested(
    ChatMessageForwardRequested event,
    Emitter<ChatState> emit,
  ) async {
    final target = event.target;
    final isEmailTarget = target.isEmailOnlyContact;
    final message = event.message;
    final plainText = message.plainText.trim();
    final htmlBody = message.normalizedHtmlBody;
    final attachment = await _attachmentForMessage(message);
    try {
      if (attachment != null) {
        final captionedAttachment = plainText.isNotEmpty
            ? attachment.copyWith(caption: plainText)
            : attachment;
        if (isEmailTarget) {
          final emailService = _emailService;
          if (emailService == null) return;
          await emailService.sendAttachment(
            chat: target,
            attachment: captionedAttachment,
            htmlCaption: htmlBody,
          );
          return;
        }
        await _messageService.sendAttachment(
          jid: target.jid,
          attachment: captionedAttachment,
          encryptionProtocol: target.encryptionProtocol,
          chatType: target.type,
          htmlCaption: htmlBody,
        );
        return;
      }
      if (plainText.isEmpty && htmlBody == null) return;
      if (isEmailTarget) {
        final emailService = _emailService;
        if (emailService == null) return;
        await emailService.sendMessage(
          chat: target,
          body: plainText,
          htmlBody: htmlBody,
        );
      } else {
        await _messageService.sendMessage(
          jid: target.jid,
          text: plainText,
          htmlBody: htmlBody,
          encryptionProtocol: target.encryptionProtocol,
          chatType: target.type,
        );
      }
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to forward message ${event.message.stanzaID} to ${target.jid}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _onChatMessageResendRequested(
    ChatMessageResendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    final chatType = state.chat?.type ?? ChatType.chat;
    final isEmailMessage = message.deltaChatId != null;
    try {
      if (isEmailMessage) {
        await _resendEmailMessage(message, emit);
        return;
      }
      if (message.fileMetadataID != null) {
        final attachment = await _attachmentForMessage(message);
        if (attachment != null) {
          Message? quoted;
          if (message.quoting != null) {
            quoted = await _messageService.loadMessageByStanzaId(
              message.quoting!,
            );
          }
          await _messageService.sendAttachment(
            jid: message.chatJid,
            attachment: attachment,
            encryptionProtocol: message.encryptionProtocol,
            quotedMessage: quoted,
            chatType: chatType,
          );
        }
        return;
      }
      final hasBody =
          message.plainText.isNotEmpty || message.normalizedHtmlBody != null;
      if (!hasBody) return;
      await _messageService.resendMessage(
        message.stanzaID,
        chatType: chatType,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to resend message ${message.stanzaID}',
        error,
        stackTrace,
      );
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

  Future<void> _onChatAttachmentPicked(
    ChatAttachmentPicked event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null) return;
    final recipients = _resolveComposerRecipients(chat);
    final shouldUseEmail =
        _shouldSendAttachmentsViaEmail(chat: chat, recipients: recipients);
    final service = _emailService;
    if (shouldUseEmail && service == null) return;
    if (shouldUseEmail &&
        !_hasEmailTarget(chat: chat, recipients: recipients)) {
      emit(
        _attachToast(
          state.copyWith(
            composerError: 'Add an email recipient to send attachments.',
          ),
          const ChatToast(
            message: 'Add an email recipient to send attachments.',
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
    final quotedDraft = state.quoting;
    final rawCaption = event.attachment.caption?.trim();
    final caption = rawCaption?.isNotEmpty == true
        ? _composeEmailBody(rawCaption!, quotedDraft)
        : null;
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
          preparedAttachment =
              preparedAttachment.copyWith(sizeBytes: resolvedSize);
        }
      } on Exception catch (error, stackTrace) {
        _log.fine('Failed to resolve attachment size', error, stackTrace);
      }
    }
    try {
      preparedAttachment =
          await EmailAttachmentOptimizer.optimize(preparedAttachment);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to optimize attachment', error, stackTrace);
    }
    _replacePendingAttachment(
      placeholder.copyWith(
        attachment: preparedAttachment,
        isPreparing: false,
      ),
      emit,
    );
  }

  Future<void> _onChatAttachmentRetryRequested(
    ChatAttachmentRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final pending = _pendingAttachmentById(event.attachmentId);
    final chat = state.chat;
    if (pending == null ||
        pending.status != PendingAttachmentStatus.failed ||
        chat == null) {
      return;
    }
    final recipients = _resolveComposerRecipients(chat);
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
            message: 'Email is offline. Retry once sync recovers.',
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
      await _sendPendingAttachment(
        pending: updated,
        chat: chat,
        service: service!,
        recipients: emailRecipients,
        emit: emit,
        retainOnSuccess: requiresXmpp,
      );
      if (!requiresXmpp) {
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
      quotedDraft: state.quoting,
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
    if (jid == null) return;
    const forcedFilter = MessageTimelineFilter.allWithContact;
    final effectiveFilter =
        _forceAllWithContactViewFilter ? forcedFilter : event.filter;
    emit(state.copyWith(viewFilter: effectiveFilter));
    _subscribeToMessages(limit: _currentMessageLimit, filter: effectiveFilter);
    if (event.persist && !_forceAllWithContactViewFilter) {
      await _chatsService.saveChatViewFilter(
          jid: jid!, filter: effectiveFilter);
    }
  }

  void _onComposerRecipientAdded(
    ChatComposerRecipientAdded event,
    Emitter<ChatState> emit,
  ) {
    final recipients = List<ComposerRecipient>.from(state.recipients);
    final index =
        recipients.indexWhere((recipient) => recipient.key == event.target.key);
    if (index >= 0) {
      recipients[index] = recipients[index].copyWith(
        target: event.target,
        included: true,
      );
    } else {
      recipients.add(ComposerRecipient(target: event.target));
    }
    emit(state.copyWith(recipients: recipients, composerError: null));
  }

  void _onComposerRecipientRemoved(
    ChatComposerRecipientRemoved event,
    Emitter<ChatState> emit,
  ) {
    final recipients = List<ComposerRecipient>.from(state.recipients);
    final index = recipients
        .indexWhere((recipient) => recipient.key == event.recipientKey);
    if (index == -1 || recipients[index].pinned) {
      return;
    }
    recipients.removeAt(index);
    emit(state.copyWith(recipients: recipients, composerError: null));
  }

  void _onComposerRecipientToggled(
    ChatComposerRecipientToggled event,
    Emitter<ChatState> emit,
  ) {
    final recipients = List<ComposerRecipient>.from(state.recipients);
    final index = recipients
        .indexWhere((recipient) => recipient.key == event.recipientKey);
    if (index == -1) {
      return;
    }
    final recipient = recipients[index];
    recipients[index] = recipient.copyWith(
      included: event.included ?? !recipient.included,
    );
    emit(state.copyWith(recipients: recipients, composerError: null));
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
            message: 'Email is offline. Retry once sync recovers.',
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
    final draft = state.fanOutDrafts[event.shareId];
    final report = state.fanOutReports[event.shareId];
    if (draft == null || report == null) return;
    final failedStatuses = report.statuses
        .where((status) => status.state == FanOutRecipientState.failed)
        .toList();
    if (failedStatuses.isEmpty) return;
    final recipients = <ComposerRecipient>[];
    for (final status in failedStatuses) {
      final jid = status.chat.jid;
      final existing = _recipientForChat(jid);
      if (existing != null) {
        recipients.add(existing.copyWith(included: true));
      } else {
        recipients.add(
          ComposerRecipient(target: FanOutTarget.chat(status.chat)),
        );
      }
    }
    if (recipients.isEmpty) return;
    await _sendFanOut(
      recipients: recipients,
      text: draft.body,
      attachment: draft.attachment,
      shareId: draft.shareId,
      subject: draft.subject,
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
    emit(state.copyWith(emailSubject: event.subject));
  }

  Future<void> _stopTyping() async {
    _typingTimer?.cancel();
    _typingTimer = null;
    if (!_isEmailChat) {
      await _chatsService.sendTyping(jid: state.chat!.jid, typing: false);
    }
  }

  Future<void> _sendPendingAttachment({
    required PendingAttachment pending,
    required Chat chat,
    required EmailService service,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
    bool retainOnSuccess = false,
  }) async {
    var current = pending;
    if (current.status != PendingAttachmentStatus.uploading) {
      current = current.copyWith(
        status: PendingAttachmentStatus.uploading,
        clearErrorMessage: true,
      );
      _replacePendingAttachment(current, emit);
    }
    if (_shouldFanOut(recipients, chat)) {
      final succeeded = await _sendFanOut(
        recipients: recipients,
        attachment: current.attachment,
        subject: state.emailSubject,
        emit: emit,
      );
      if (succeeded) {
        _handlePendingAttachmentSuccess(
          current,
          emit,
          retainOnSuccess: retainOnSuccess,
        );
      } else {
        _markPendingAttachmentFailed(
          current.id,
          emit,
          message: state.composerError ??
              'Unable to send attachment. Please try again.',
        );
      }
      return;
    }
    try {
      await service.sendAttachment(
        chat: chat,
        attachment: current.attachment,
        subject: state.emailSubject,
      );
      _handlePendingAttachmentSuccess(
        current,
        emit,
        retainOnSuccess: retainOnSuccess,
      );
    } on DeltaChatException catch (error, stackTrace) {
      _log.warning(
        'Failed to send attachment for chat ${chat.jid}',
        error,
        stackTrace,
      );
      final mappedError = DeltaErrorMapper.resolve(error.message);
      final readableMessage = mappedError.asString;
      _markPendingAttachmentFailed(
        current.id,
        emit,
        message: readableMessage,
      );
      emit(state.copyWith(composerError: readableMessage));
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to send attachment for chat ${chat.jid}',
        error,
        stackTrace,
      );
      _markPendingAttachmentFailed(current.id, emit);
      emit(
        state.copyWith(
          composerError: 'Unable to send attachment. Please try again.',
        ),
      );
    }
  }

  Future<List<PendingAttachment>> _bundleEmailAttachments({
    required List<PendingAttachment> attachments,
    required String? caption,
  }) async {
    if (attachments.length <= 1) return attachments;
    final bundled = await _createAttachmentBundle(
      attachments: attachments,
      caption: caption,
    );
    return [
      PendingAttachment(
        id: _nextPendingAttachmentId(),
        attachment: bundled,
        status: PendingAttachmentStatus.queued,
      ),
    ];
  }

  Future<EmailAttachment> _createAttachmentBundle({
    required List<PendingAttachment> attachments,
    required String? caption,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final bundleDir = Directory(p.join(tempDir.path, 'email_attachments'));
    if (!await bundleDir.exists()) {
      await bundleDir.create(recursive: true);
    }
    final zipName = 'attachments_${DateTime.now().microsecondsSinceEpoch}.zip';
    final zipPath = p.join(bundleDir.path, zipName);
    final archive = Archive();
    for (final pending in attachments) {
      final attachment = pending.attachment;
      final file = File(attachment.path);
      if (!await file.exists()) {
        throw FileSystemException('Attachment missing', attachment.path);
      }
      final bytes = await file.readAsBytes();
      final filename = attachment.fileName.isNotEmpty
          ? attachment.fileName
          : p.basename(attachment.path);
      archive.addFile(
        ArchiveFile(
          filename,
          bytes.length,
          bytes,
        ),
      );
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const FileSystemException('Failed to bundle attachments');
    }
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(encoded, flush: true);
    return EmailAttachment(
      path: zipFile.path,
      fileName: zipName,
      sizeBytes: encoded.length,
      mimeType: 'application/zip',
      caption: caption,
    );
  }

  Future<void> _sendQueuedAttachments({
    required Iterable<PendingAttachment> attachments,
    required Chat chat,
    required EmailService service,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
    bool retainOnSuccess = false,
    String? captionForFirstAttachment,
  }) async {
    var index = 0;
    for (final attachment in attachments) {
      final latest = _pendingAttachmentById(attachment.id) ?? attachment;
      final shouldApplyCaption =
          captionForFirstAttachment != null && index == 0;
      final pendingWithCaption = shouldApplyCaption
          ? latest.copyWith(
              attachment: latest.attachment.copyWith(
                caption: captionForFirstAttachment,
              ),
            )
          : latest;
      await _sendPendingAttachment(
        pending: pendingWithCaption,
        chat: chat,
        service: service,
        recipients: recipients,
        emit: emit,
        retainOnSuccess: retainOnSuccess,
      );
      index += 1;
    }
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
    Message? quotedDraft,
    String? caption,
  }) async {
    if (!state.supportsHttpFileUpload) {
      const message = 'File upload is not available on this server.';
      emit(state.copyWith(composerError: message));
      return false;
    }
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
    for (final attachment in attachments) {
      var current = attachment;
      final updatedAttachment = caption?.isNotEmpty == true
          ? current.attachment.copyWith(caption: caption)
          : current.attachment;
      current = current.copyWith(
        attachment: updatedAttachment,
        status: PendingAttachmentStatus.uploading,
        clearErrorMessage: true,
      );
      _replacePendingAttachment(current, emit);
      try {
        for (final target in targets.values) {
          final quote = quotedDraft != null && quotedDraft.chatJid == target.jid
              ? quotedDraft
              : null;
          await _messageService.sendAttachment(
            jid: target.jid,
            attachment: current.attachment,
            encryptionProtocol: target.encryptionProtocol,
            chatType: target.type,
            quotedMessage: quote,
          );
        }
        _removePendingAttachment(current.id, emit);
      } on XmppFileTooBigException catch (error) {
        final limit = error.maxBytes;
        final readableLimit = limit == null ? null : _formatBytes(limit);
        final message = readableLimit == null
            ? 'Attachment exceeds the server limit.'
            : 'Attachment exceeds the server limit ($readableLimit).';
        _markPendingAttachmentFailed(
          current.id,
          emit,
          message: message,
        );
        emit(state.copyWith(composerError: message));
        await _saveXmppDraft(
          chat: chat,
          recipients: recipients,
          body: '',
          attachments: [current],
          emit: emit,
        );
        return false;
      } on XmppUploadUnavailableException catch (_) {
        const message =
            'File uploads are unavailable right now. Saved to drafts.';
        _markPendingAttachmentFailed(
          current.id,
          emit,
          message: message,
        );
        emit(state.copyWith(composerError: message));
        await _saveXmppDraft(
          chat: chat,
          recipients: recipients,
          body: '',
          attachments: [current],
          emit: emit,
        );
        return false;
      } on XmppUploadNotSupportedException catch (_) {
        const message = 'File upload is not available on this server.';
        _markPendingAttachmentFailed(
          current.id,
          emit,
          message: message,
        );
        emit(state.copyWith(composerError: message));
        await _saveXmppDraft(
          chat: chat,
          recipients: recipients,
          body: '',
          attachments: [current],
          emit: emit,
        );
        return false;
      } on XmppUploadMisconfiguredException catch (_) {
        const message =
            'File upload failed because the server’s upload component is misconfigured or temporarily unavailable.';
        _markPendingAttachmentFailed(
          current.id,
          emit,
          message: message,
        );
        emit(state.copyWith(composerError: message));
        await _saveXmppDraft(
          chat: chat,
          recipients: recipients,
          body: '',
          attachments: [current],
          emit: emit,
        );
        return false;
      } on XmppMessageException catch (_) {
        const message = 'Unable to send attachment. Please try again.';
        _markPendingAttachmentFailed(
          current.id,
          emit,
          message: message,
        );
        emit(state.copyWith(composerError: message));
        await _saveXmppDraft(
          chat: chat,
          recipients: recipients,
          body: '',
          attachments: [current],
          emit: emit,
        );
        return false;
      } on Exception catch (error, stackTrace) {
        _log.warning(
          'Failed to send XMPP attachment for chat ${chat.jid}',
          error,
          stackTrace,
        );
        const message = 'Unable to send attachment. Please try again.';
        _markPendingAttachmentFailed(current.id, emit, message: message);
        emit(state.copyWith(composerError: message));
        await _saveXmppDraft(
          chat: chat,
          recipients: recipients,
          body: '',
          attachments: [current],
          emit: emit,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _handleBrokenEmailSend({
    required Chat chat,
    required List<ComposerRecipient> recipients,
    required String rawText,
    required Message? quotedDraft,
    required Emitter<ChatState> emit,
  }) async {
    final resolvedRecipients =
        _draftRecipientJids(chat: chat, recipients: recipients);
    if (resolvedRecipients.isEmpty) {
      emit(
        _attachToast(
          state.copyWith(
            composerError: 'Unable to resolve recipients for this draft.',
          ),
          const ChatToast(
            message: 'Unable to save draft while email is offline.',
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
      return;
    }
    final trimmed = rawText.trim();
    final body = trimmed.isEmpty ? '' : _composeEmailBody(trimmed, quotedDraft);
    final signature = _draftSignature(
      recipients: resolvedRecipients,
      body: body,
      subject: state.emailSubject,
      pendingAttachments: state.pendingAttachments,
    );
    final attachments =
        state.pendingAttachments.map((pending) => pending.attachment).toList();
    if (_lastOfflineDraftSignature == signature) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: 'Draft already saved while email is offline.',
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
    try {
      await _messageService.saveDraft(
        id: null,
        jids: resolvedRecipients,
        body: body,
        subject: state.emailSubject,
        attachments: attachments,
      );
      _lastOfflineDraftSignature = signature;
      emit(
        _attachToast(
          state,
          const ChatToast(
            message:
                'Saved to Drafts because email is offline. Reopen it once sync recovers.',
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to save offline email draft for chat ${chat.jid}',
        error,
        stackTrace,
      );
      emit(
        _attachToast(
          state.copyWith(
            composerError:
                'Unable to save draft while email is offline. Try again shortly.',
          ),
          const ChatToast(
            message:
                'Unable to save draft while email is offline. Try again shortly.',
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
    }
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
    final buffer = StringBuffer(sortedRecipients.join(','))
      ..write('::')
      ..write(body)
      ..write('::subject:')
      ..write(subject ?? '');
    if (pendingAttachments.isNotEmpty) {
      final attachmentKeys = pendingAttachments
          .map((pending) => pending.attachment.path)
          .where((path) => path.isNotEmpty)
          .toList()
        ..sort();
      buffer
        ..write('::attachments:')
        ..write(attachmentKeys.join(','));
    }
    return buffer.toString();
  }

  ChatState _attachToast(ChatState base, ChatToast toast) => base.copyWith(
        toast: toast,
        toastId: base.toastId + 1,
      );

  void _clearEmailSubject(Emitter<ChatState> emit) {
    if (state.emailSubject?.isEmpty ?? true) {
      return;
    }
    emit(
      state.copyWith(
        emailSubject: '',
        emailSubjectHydrationId: state.emailSubjectHydrationId + 1,
        emailSubjectHydrationText: '',
      ),
    );
  }

  String _composeEmailBody(String body, Message? quoted) {
    if (quoted?.plainText.isNotEmpty != true) {
      return body;
    }
    final quotedBody = quoted!.plainText
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');
    return '$quotedBody\n\n$body';
  }

  List<ComposerRecipient> _includedRecipients() =>
      state.recipients.where((recipient) => recipient.included).toList();

  List<ComposerRecipient> _resolveComposerRecipients(Chat chat) {
    final recipients = _includedRecipients();
    if (recipients.isNotEmpty) {
      return recipients;
    }
    return [
      ComposerRecipient(
        target: FanOutTarget.chat(chat),
        included: true,
        pinned: true,
      ),
    ];
  }

  ({
    List<ComposerRecipient> emailRecipients,
    List<ComposerRecipient> xmppRecipients
  }) _splitRecipientsForSend({
    required List<ComposerRecipient> recipients,
    required bool forceEmail,
  }) {
    final emailRecipients = <ComposerRecipient>[];
    final xmppRecipients = <ComposerRecipient>[];
    for (final recipient in recipients) {
      final targetChat = recipient.target.chat;
      if (forceEmail) {
        emailRecipients.add(recipient);
        continue;
      }
      if (targetChat == null) {
        if (_isEmailOnlyAddress(recipient.target.address)) {
          emailRecipients.add(recipient);
        } else {
          xmppRecipients.add(recipient);
        }
        continue;
      }
      if (targetChat.defaultTransport.isEmail) {
        emailRecipients.add(recipient);
      } else {
        xmppRecipients.add(recipient);
      }
    }
    return (
      emailRecipients: emailRecipients,
      xmppRecipients: xmppRecipients,
    );
  }

  bool _hasEmailTarget({
    required Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (_isEmailCapableChat(chat)) {
      return true;
    }
    for (final recipient in recipients) {
      final targetChat = recipient.target.chat;
      if (targetChat != null && _isEmailCapableChat(targetChat)) {
        return true;
      }
      if (_isEmailOnlyAddress(recipient.target.address)) {
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
      final targetChat = recipient.target.chat;
      if (targetChat != null && targetChat.defaultTransport.isEmail) {
        return true;
      }
      if (_isEmailOnlyAddress(recipient.target.address)) {
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

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    final precision = value >= 10 || index == 0 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[index]}';
  }

  String _composeXmppBody({
    required String body,
    required String? subject,
  }) =>
      ChatSubjectCodec.composeXmppBody(
        body: body,
        subject: subject,
      );

  Future<void> _sendXmppFanOut({
    required List<ComposerRecipient> recipients,
    required String body,
    CalendarFragment? calendarFragment,
    required Message? quotedDraft,
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
        calendarFragment: calendarFragment,
        chatType: targetChat.type,
      );
    }
  }

  Future<bool> _sendFanOut({
    required List<ComposerRecipient> recipients,
    String? text,
    EmailAttachment? attachment,
    String? shareId,
    String? subject,
    required Emitter<ChatState> emit,
  }) async {
    final service = _emailService;
    if (service == null || recipients.isEmpty) return false;
    final chat = state.chat;
    if (chat == null) return false;
    final useSignatureToken = _settingsState.shareTokenSignatureEnabled &&
        chat.shareSignatureEnabled &&
        recipients.every((recipient) => recipient.target.shareSignatureEnabled);
    final effectiveShareId = shareId ?? ShareTokenCodec.generateShareId();
    try {
      final report = await service.fanOutSend(
        targets: recipients.map((recipient) => recipient.target).toList(),
        body: text,
        attachment: attachment,
        shareId: effectiveShareId,
        subject: subject,
        useSubjectToken: useSignatureToken,
        tokenAsSignature: useSignatureToken,
      );
      final mergedRecipients = _mergeRecipientsWithReport(report);
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
        );
      emit(state.copyWith(
        recipients: mergedRecipients,
        fanOutReports: reports,
        fanOutDrafts: drafts,
        composerError: null,
      ));
      return true;
    } on FanOutValidationException catch (error) {
      emit(state.copyWith(composerError: error.message));
      return false;
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to send fan-out message', error, stackTrace);
      emit(
        state.copyWith(
          composerError: 'Unable to send message. Please try again.',
        ),
      );
      return false;
    }
    // Should be unreachable.
    // ignore: dead_code
    return false;
  }

  List<ComposerRecipient> _mergeRecipientsWithReport(
    FanOutSendReport report,
  ) {
    if (report.statuses.isEmpty) {
      return state.recipients;
    }
    final recipients = List<ComposerRecipient>.from(state.recipients);
    var changed = false;
    for (final status in report.statuses) {
      final jid = status.chat.jid;
      final statusAddress = status.chat.emailAddress?.trim().toLowerCase();
      final matchesIndex = recipients.indexWhere((recipient) {
        final targetChat = recipient.target.chat;
        if (targetChat != null && targetChat.jid == jid) {
          return true;
        }
        final recipientAddress = recipient.target.normalizedAddress;
        return statusAddress != null &&
            recipientAddress != null &&
            recipientAddress == statusAddress;
      });
      if (matchesIndex >= 0 &&
          recipients[matchesIndex].target.chat?.jid != jid) {
        recipients[matchesIndex] = recipients[matchesIndex].copyWith(
          target: FanOutTarget.chat(status.chat),
        );
        changed = true;
      }
    }
    return changed ? recipients : state.recipients;
  }

  Future<void> _rehydrateEmailDraft(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    final service = _emailService;
    if (chat == null || service == null) return;
    ShareContext? shareContext = state.shareContexts[message.stanzaID];
    shareContext ??= await service.shareContextForMessage(message);
    final recipients = _recipientsForHydration(
      chat: chat,
      shareContext: shareContext,
      resetRecipients: true,
    );
    final pendingAttachments = <PendingAttachment>[];
    if (message.fileMetadataID != null) {
      final attachment = await service.attachmentForMessage(message);
      if (attachment != null) {
        pendingAttachments.add(
          PendingAttachment(
            id: _nextPendingAttachmentId(),
            attachment: attachment,
          ),
        );
      }
    }
    final nextHydrationId = ++_composerHydrationSeed;
    final nextSubject = shareContext?.subject;
    final shouldHydrateSubject =
        nextSubject != null && nextSubject != state.emailSubject;
    emit(
      state.copyWith(
        recipients: recipients,
        pendingAttachments: pendingAttachments,
        composerHydrationId: nextHydrationId,
        composerHydrationText: message.plainText,
        composerError: message.error.isNotNone
            ? message.error.asString
            : state.composerError,
        emailSubject: shouldHydrateSubject ? nextSubject : state.emailSubject,
        emailSubjectHydrationId: shouldHydrateSubject
            ? state.emailSubjectHydrationId + 1
            : state.emailSubjectHydrationId,
        emailSubjectHydrationText:
            shouldHydrateSubject ? nextSubject : state.emailSubject,
      ),
    );
  }

  List<ComposerRecipient> _recipientsForHydration({
    required Chat chat,
    ShareContext? shareContext,
    bool resetRecipients = false,
  }) {
    final recipients = resetRecipients
        ? [
            ComposerRecipient(
              target: FanOutTarget.chat(chat),
              included: true,
              pinned: true,
            ),
          ]
        : _syncRecipientsForChat(chat);
    if (shareContext == null) {
      return recipients;
    }
    final updated = List<ComposerRecipient>.from(recipients);
    for (final participant in shareContext.participants) {
      final jid = participant.jid;
      if (jid == chat.jid) {
        continue;
      }
      final target = FanOutTarget.chat(participant);
      final index = updated.indexWhere((recipient) => recipient.key == jid);
      if (index >= 0) {
        updated[index] = updated[index].copyWith(
          target: target,
          included: true,
        );
      } else {
        updated.add(
          ComposerRecipient(target: target, included: true),
        );
      }
    }
    return updated;
  }

  ComposerRecipient? _recipientForChat(String jid) {
    for (final recipient in state.recipients) {
      final chat = recipient.target.chat;
      if (chat != null && chat.jid == jid) {
        return recipient;
      }
    }
    return null;
  }

  void _replacePendingAttachment(
    PendingAttachment replacement,
    Emitter<ChatState> emit,
  ) {
    final updated = state.pendingAttachments
        .map(
          (pending) => pending.id == replacement.id ? replacement : pending,
        )
        .toList();
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _removePendingAttachment(
    String attachmentId,
    Emitter<ChatState> emit,
  ) {
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
    String? message,
  }) {
    final updated = state.pendingAttachments.map((pending) {
      if (pending.id != attachmentId) return pending;
      return pending.copyWith(
        status: PendingAttachmentStatus.failed,
        errorMessage: message ?? 'Unable to send attachment. Please try again.',
      );
    }).toList();
    emit(state.copyWith(pendingAttachments: updated));
  }

  PendingAttachment? _pendingAttachmentById(String attachmentId) {
    for (final pending in state.pendingAttachments) {
      if (pending.id == attachmentId) {
        return pending;
      }
    }
    return null;
  }

  List<ComposerRecipient> _syncRecipientsForChat(Chat chat) {
    final recipients = List<ComposerRecipient>.from(state.recipients);
    final key = chat.jid;
    final index = recipients.indexWhere(
      (recipient) => recipient.pinned && recipient.target.chat?.jid == key,
    );
    if (index >= 0) {
      recipients[index] = recipients[index].copyWith(
        target: FanOutTarget.chat(chat),
        included: true,
      );
      return recipients;
    }
    recipients.insert(
      0,
      ComposerRecipient(
        target: FanOutTarget.chat(chat),
        included: true,
        pinned: true,
      ),
    );
    return recipients;
  }

  Future<void> _rehydrateXmppDraft(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final pendingAttachments = <PendingAttachment>[];
    final attachment = await _attachmentForMessage(message);
    if (attachment != null) {
      pendingAttachments.add(
        PendingAttachment(
          id: _nextPendingAttachmentId(),
          attachment: attachment,
        ),
      );
    }
    final nextHydrationId = ++_composerHydrationSeed;
    emit(
      state.copyWith(
        composerHydrationId: nextHydrationId,
        composerHydrationText: message.plainText,
        composerError: message.error.isNotNone
            ? message.error.asString
            : state.composerError,
        pendingAttachments: pendingAttachments,
      ),
    );
  }

  Future<void> _saveXmppDraft({
    required Chat chat,
    required List<ComposerRecipient> recipients,
    required String body,
    required Iterable<PendingAttachment> attachments,
    required Emitter<ChatState> emit,
  }) async {
    final hasAttachments = attachments.isNotEmpty;
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty && !hasAttachments) return;
    final resolvedRecipients =
        _draftRecipientJids(chat: chat, recipients: recipients);
    if (resolvedRecipients.isEmpty) return;
    final attachmentPayload =
        attachments.map((pending) => pending.attachment).toList();
    try {
      await _messageService.saveDraft(
        id: null,
        jids: resolvedRecipients,
        body: trimmedBody,
        subject: state.emailSubject,
        attachments: attachmentPayload,
      );
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: 'Saved to Drafts because sending failed.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      _log.fine(
        'Failed to save XMPP draft for chat ${chat.jid}',
        error,
        stackTrace,
      );
    }
  }

  Future<EmailAttachment?> _attachmentForMessage(Message message) async {
    final metadataId = message.fileMetadataID;
    if (metadataId == null) return null;
    final db = await _messageService.database;
    final metadata = await db.getFileMetadata(metadataId);
    final path = metadata?.path;
    if (metadata == null || path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final size = metadata.sizeBytes ?? await file.length();
    final caption = message.plainText.trim();
    return EmailAttachment(
      path: path,
      fileName: metadata.filename,
      sizeBytes: size,
      mimeType: metadata.mimeType,
      width: metadata.width,
      height: metadata.height,
      caption: caption.isEmpty ? null : caption,
    );
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
    final hasAttachment = message.fileMetadataID != null;
    if (!hasBody && !hasAttachment) {
      return;
    }
    ShareContext? shareContext = state.shareContexts[message.stanzaID];
    shareContext ??= await service.shareContextForMessage(message);
    try {
      if (hasAttachment) {
        final attachment = await service.attachmentForMessage(message);
        if (attachment != null) {
          final captionedAttachment =
              hasBody ? attachment.copyWith(caption: resolvedBody) : attachment;
          await service.sendAttachment(
            chat: chat,
            attachment: captionedAttachment,
            htmlCaption: normalizedHtml,
          );
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
      _log.warning(
        'Failed to resend email message ${message.stanzaID}',
        error,
        stackTrace,
      );
      final mappedError = DeltaErrorMapper.resolve(error.message);
      emit(
        _attachToast(
          state.copyWith(composerError: mappedError.asString),
          const ChatToast(
            message: 'Email resend failed. Check the error bubble for details.',
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to resend email message ${message.stanzaID}',
        error,
        stackTrace,
      );
    }
  }
}
