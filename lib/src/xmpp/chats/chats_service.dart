// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

class ChatTransportPreference {
  const ChatTransportPreference({
    required this.transport,
    required this.defaultTransport,
    required this.isExplicit,
  });

  final MessageTransport transport;
  final MessageTransport defaultTransport;
  final bool isExplicit;
}

final class InboundChatStateEvent extends mox.XmppEvent {
  InboundChatStateEvent({
    required this.chatJid,
    required this.participantId,
    required this.state,
  });

  final String chatJid;
  final String participantId;
  final mox.ChatState state;
}

final _chatSettingsSyncSourceKey = XmppStateStore.registerKey(
  'chat_settings_sync_source_id',
);

enum _ChatSettingsSyncDecision { applyRemote, publishLocal, skip }

final class _TypingParticipantsSession {
  _TypingParticipantsSession({
    required Duration linger,
    required int maxCount,
    required void Function() onIdle,
  }) : _linger = linger,
       _maxCount = maxCount,
       _onIdle = onIdle;

  final Duration _linger;
  final int _maxCount;
  final void Function() _onIdle;
  final Set<String> _participants = <String>{};
  final Map<String, Timer> _expiry = <String, Timer>{};
  StreamController<List<String>>? _controller;

  Stream<List<String>> get stream =>
      (_controller ??= StreamController<List<String>>.broadcast(
        onListen: emit,
        onCancel: _onIdle,
      )).stream;

  bool get hasListener => _controller?.hasListener ?? false;

  void track({required String participantId, required mox.ChatState state}) {
    switch (state) {
      case mox.ChatState.composing:
        _participants.add(participantId);
        _expiry.remove(participantId)?.cancel();
        _expiry[participantId] = Timer(
          _linger,
          () => _expireParticipant(participantId),
        );
      default:
        final removed = _participants.remove(participantId);
        _expiry.remove(participantId)?.cancel();
        if (!removed) return;
    }
    emit();
  }

  void clear() {
    _participants.clear();
    for (final timer in _expiry.values.toList(growable: false)) {
      timer.cancel();
    }
    _expiry.clear();
    emit();
  }

  void emit() {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    final ordered = _participants.take(_maxCount + 1).toList(growable: false);
    controller.add(List<String>.unmodifiable(ordered));
  }

  void dispose() {
    for (final timer in _expiry.values.toList(growable: false)) {
      timer.cancel();
    }
    _expiry.clear();
    _participants.clear();
    _controller?.close();
    _controller = null;
  }

  void _expireParticipant(String participantId) {
    final removed = _participants.remove(participantId);
    _expiry.remove(participantId)?.cancel();
    if (!removed) return;
    emit();
  }
}

mixin ChatsService on XmppBase, BaseStreamService, MessageService {
  final _chatsLog = Logger('ChatsService');
  static final _transportKeys = <String, RegisteredStateKey>{};
  static final _viewFilterKeys = <String, RegisteredStateKey>{};
  static const _typingParticipantLinger = Duration(seconds: 6);
  static const _typingParticipantMaxCount = 7;
  static const int _conversationIndexSnapshotStart = 0;
  static const int _conversationIndexSnapshotEnd = 0;
  static const int _chatPreloadStart = 0;
  static const int _defaultChatPreloadLimit = basePageItemLimit;
  static const int _chatPreloadDisabledLimit = 0;
  static const int _openChatPreloadMessageStart = 0;
  static const int _openChatPreloadMessageLimit = 50;
  static const int _openChatPreloadMessageDisabledLimit = 0;
  static const _recipientAddressSuggestionLimit = 50000;
  static const Duration _mutedForeverDuration = Duration(days: 3650);
  static const String _signupWelcomeChatJid = 'axichat@welcome.axichat.invalid';
  static const String _conversationIndexBootstrapOperationName =
      'ChatsService.bootstrapConversationIndexOnNegotiations';
  static const String _chatSettingsBootstrapOperationName =
      'ChatsService.bootstrapChatSettingsOnNegotiations';
  static const List<ConvItem> _emptyConversationIndexSnapshot = <ConvItem>[];
  static const List<ChatSettingsSyncPayload> _emptyChatSettingsSnapshot =
      <ChatSettingsSyncPayload>[];
  static const List<Chat> _emptyChatList = <Chat>[];
  final Map<String, _TypingParticipantsSession> _typingParticipantSessions = {};
  final Map<String, int> _openChatUnreadBoundarySeedByJid = {};
  final Set<String> _pendingConversationIndexSeeds = <String>{};
  Future<List<ConvItem>>? _conversationIndexLoginSync;
  Future<List<ChatSettingsSyncPayload>>? _chatSettingsLoginSync;
  String? _chatSettingsSourceId;
  List<Chat>? _cachedChatList;
  bool? _lastMarkerResponsive;
  bool _conversationIndexSnapshotResolved = false;

  List<Chat>? get cachedChatList => _cachedChatList;

  void stageOpenChatUnreadBoundarySeed({
    required String jid,
    required int unreadCount,
  }) {
    final normalizedJid = normalizeAddress(jid);
    if (normalizedJid == null || normalizedJid.isEmpty) {
      return;
    }
    if (unreadCount <= 0) {
      _openChatUnreadBoundarySeedByJid.remove(normalizedJid);
      return;
    }
    _openChatUnreadBoundarySeedByJid[normalizedJid] = unreadCount;
  }

  int? consumeOpenChatUnreadBoundarySeed(String jid) {
    final normalizedJid = normalizeAddress(jid);
    if (normalizedJid == null || normalizedJid.isEmpty) {
      return null;
    }
    return _openChatUnreadBoundarySeedByJid.remove(normalizedJid);
  }

  Future<void> syncSignupWelcomeMessage({
    required bool allowInsert,
    required String title,
    required String body,
  }) async {
    const welcomeStanzaId = 'signup-welcome.axichat';
    final lastMessagePreview = _signupWelcomeLastMessagePreview(body);
    Message? insertedMessage;
    try {
      final db = await database;
      final existingMessage = await db.getMessageByStanzaID(welcomeStanzaId);
      var existingChat = await db.getChat(_signupWelcomeChatJid);
      if (existingMessage == null) {
        if (existingChat == null && !allowInsert) {
          return;
        }
        if (allowInsert) {
          insertedMessage = Message(
            stanzaID: welcomeStanzaId,
            senderJid: _signupWelcomeChatJid,
            chatJid: _signupWelcomeChatJid,
            body: body,
            timestamp: DateTime.timestamp(),
            acked: true,
            received: true,
            displayed: true,
          );
          await db.saveMessage(insertedMessage);
        }
      } else if (existingMessage.body != body ||
          existingMessage.htmlBody != null ||
          existingMessage.senderJid != _signupWelcomeChatJid ||
          existingMessage.chatJid != _signupWelcomeChatJid ||
          !existingMessage.displayed) {
        await db.updateMessage(
          existingMessage.copyWith(
            senderJid: _signupWelcomeChatJid,
            chatJid: _signupWelcomeChatJid,
            body: body,
            htmlBody: null,
            acked: true,
            received: true,
            displayed: true,
          ),
        );
      }
      existingChat ??= await db.getChat(_signupWelcomeChatJid);
      if (existingChat == null) {
        if (!allowInsert) {
          return;
        }
        final chatTimestamp =
            insertedMessage?.timestamp ??
            existingMessage?.timestamp ??
            DateTime.timestamp();
        await db.createChat(
          Chat(
            jid: _signupWelcomeChatJid,
            title: title,
            type: ChatType.chat,
            lastChangeTimestamp: chatTimestamp,
            lastMessage: lastMessagePreview,
            contactDisplayName: title,
            contactJid: _signupWelcomeChatJid,
          ),
        );
        return;
      }
      final shouldSyncLastMessage =
          existingMessage != null || insertedMessage != null;
      if (existingChat.title != title ||
          existingChat.contactDisplayName != title ||
          existingChat.contactJid != _signupWelcomeChatJid ||
          (shouldSyncLastMessage &&
              existingChat.lastMessage != lastMessagePreview)) {
        await db.updateChat(
          existingChat.copyWith(
            title: title,
            lastMessage: shouldSyncLastMessage
                ? lastMessagePreview
                : existingChat.lastMessage,
            contactDisplayName: title,
            contactJid: _signupWelcomeChatJid,
          ),
        );
      }
    } on Exception catch (error, stackTrace) {
      _chatsLog.warning(
        'Failed to sync signup welcome chat',
        error,
        stackTrace,
      );
    }
  }

  String _signupWelcomeLastMessagePreview(String body) {
    for (final line in body.split('\n')) {
      final preview = line.trim();
      if (preview.isNotEmpty) {
        return preview;
      }
    }
    return body.trim();
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _conversationIndexBootstrapOperationName,
        priority: 1,
        lane: 'conversationIndex',
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.resumedNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _conversationIndexBootstrapOperationName,
        run: () async {
          await syncConversationIndexSnapshot();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _chatSettingsBootstrapOperationName,
        priority: 1,
        lane: 'chatSettings',
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.resumedNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _chatSettingsBootstrapOperationName,
        run: () async {
          await syncChatSettingsSnapshot();
        },
      ),
    );
    manager
      ..registerHandler<InboundChatStateEvent>((event) async {
        _trackTypingParticipant(
          chatJid: event.chatJid,
          participantId: event.participantId,
          state: event.state,
        );
      })
      ..registerHandler<ConversationIndexItemUpdatedEvent>((event) async {
        await applyConversationIndexItems([event.item]);
      })
      ..registerHandler<ConversationIndexItemRetractedEvent>((event) async {
        await _applyConversationIndexRetraction(event.peerBare);
      })
      ..registerHandler<ChatSettingsSyncUpdatedEvent>((event) async {
        await _applyChatSettingsSyncUpdate(event.payload);
      })
      ..registerHandler<ChatSettingsSyncRetractedEvent>((event) async {
        await _handleChatSettingsSyncRetraction(event.itemId);
      });
  }

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    ConversationIndexManager(),
    ChatSettingsPubSubManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    conversationIndexNotifyFeature,
    chatSettingsNotifyFeature,
  ];

  ChatSettingsPubSubManager? get _chatSettingsManager =>
      _connection.getManager<ChatSettingsPubSubManager>();

  Future<List<ConvItem>> syncConversationIndexSnapshot() async {
    final pendingSync = _conversationIndexLoginSync;
    if (pendingSync != null) return pendingSync;
    final task = _syncConversationIndexSnapshot();
    _conversationIndexLoginSync = task;
    return task.whenComplete(() {
      if (_conversationIndexLoginSync == task) {
        _conversationIndexLoginSync = null;
      }
    });
  }

  Future<List<ConvItem>> _syncConversationIndexSnapshot() async {
    try {
      await database;
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'conversation index',
      );
      if (!decision.isAllowed) {
        _conversationIndexSnapshotResolved = true;
        _pendingConversationIndexSeeds.clear();
        return _emptyConversationIndexSnapshot;
      }

      final manager = conversationIndexManager;
      if (manager == null) {
        return _emptyConversationIndexSnapshot;
      }

      await manager.ensureNode();
      await manager.subscribe();
      final snapshot = await manager.fetchAllWithStatus();
      await applyConversationIndexSnapshot(snapshot);
      return snapshot.items;
    } on XmppAbortedException {
      return _emptyConversationIndexSnapshot;
    }
  }

  Future<List<ChatSettingsSyncPayload>> syncChatSettingsSnapshot() async {
    final pendingSync = _chatSettingsLoginSync;
    if (pendingSync != null) return pendingSync;
    final task = _syncChatSettingsSnapshot();
    _chatSettingsLoginSync = task;
    return task.whenComplete(() {
      if (_chatSettingsLoginSync == task) {
        _chatSettingsLoginSync = null;
      }
    });
  }

  Future<List<ChatSettingsSyncPayload>> _syncChatSettingsSnapshot() async {
    try {
      await database;
      final manager = await _chatSettingsManagerForSync();
      if (manager == null) {
        return _emptyChatSettingsSnapshot;
      }

      await manager.ensureNode();
      await manager.subscribe();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return _emptyChatSettingsSnapshot;
      }
      await _applyChatSettingsSyncSnapshot(snapshot.items, manager: manager);
      return snapshot.items;
    } on XmppAbortedException {
      return _emptyChatSettingsSnapshot;
    }
  }

  Future<void> _applyChatSettingsSyncSnapshot(
    List<ChatSettingsSyncPayload> items, {
    required ChatSettingsPubSubManager manager,
  }) async {
    final remoteByAddressKey = <String, ChatSettingsSyncPayload>{
      for (final item in items) item.addressKey: item,
    };
    for (final payload in items) {
      await _applyChatSettingsSyncUpdate(payload, managerOverride: manager);
    }
    final localChats = await _dbOpReturning<XmppDatabase, List<Chat>>(
      (db) => db.getChats(start: 0, end: 0),
    );
    for (final chat in localChats) {
      if (!chat.hasChatSettingsSyncPayload) {
        continue;
      }
      final addressKey = normalizedAddressKey(chat.jid);
      if (addressKey == null || addressKey.isEmpty) {
        continue;
      }
      if (remoteByAddressKey.containsKey(addressKey) &&
          chat.chatSettingsUpdatedAt != null &&
          chat.chatSettingsSourceId?.trim().isNotEmpty == true) {
        continue;
      }
      await _publishChatSettingsForChat(
        chat,
        managerOverride: manager,
        managerReady: true,
      );
    }
  }

  RegisteredStateKey _transportKeyFor(String jid) => _transportKeys.putIfAbsent(
    jid,
    () => XmppStateStore.registerKey('chat_transport_$jid'),
  );

  RegisteredStateKey _viewFilterKeyFor(String jid) =>
      _viewFilterKeys.putIfAbsent(
        jid,
        () => XmppStateStore.registerKey('chat_view_filter_$jid'),
      );

  MessageTransport? _transportFrom(Object? raw) {
    if (raw is String) {
      return MessageTransport.values.firstWhere(
        (transport) => transport.name == raw,
        orElse: () => MessageTransport.xmpp,
      );
    }
    return null;
  }

  MessageTimelineFilter _viewFilterFrom(Object? raw) {
    if (raw is String) {
      return MessageTimelineFilter.values.firstWhere(
        (filter) => filter.name == raw,
        orElse: () => MessageTimelineFilter.allWithContact,
      );
    }
    return MessageTimelineFilter.allWithContact;
  }

  Future<MessageTransport> _defaultTransportForChat(String jid) async {
    try {
      return await _dbOpReturning<XmppDatabase, MessageTransport>((db) async {
        final chat = await db.getChat(jid);
        return chat?.defaultTransport ?? MessageTransport.xmpp;
      });
    } on XmppAbortedException {
      return MessageTransport.xmpp;
    }
  }

  Future<ChatTransportPreference> loadChatTransportPreference(
    String jid,
  ) async {
    final defaultTransport = await _defaultTransportForChat(jid);
    try {
      return await _dbOpReturning<XmppStateStore, ChatTransportPreference>((
        store,
      ) {
        final stored = _transportFrom(store.read(key: _transportKeyFor(jid)));
        if (stored == null) {
          return ChatTransportPreference(
            transport: defaultTransport,
            defaultTransport: defaultTransport,
            isExplicit: false,
          );
        }
        return ChatTransportPreference(
          transport: stored,
          defaultTransport: defaultTransport,
          isExplicit: true,
        );
      });
    } on XmppAbortedException {
      return ChatTransportPreference(
        transport: defaultTransport,
        defaultTransport: defaultTransport,
        isExplicit: false,
      );
    }
  }

  Future<void> saveChatTransportPreference({
    required String jid,
    required MessageTransport transport,
  }) async {
    await _dbOp<XmppStateStore>(
      (store) => store.write(key: _transportKeyFor(jid), value: transport.name),
      awaitDatabase: true,
    );
  }

  Future<void> clearChatTransportPreference({required String jid}) async {
    await _dbOp<XmppStateStore>(
      (store) => store.delete(key: _transportKeyFor(jid)),
      awaitDatabase: true,
    );
  }

  Future<MessageTimelineFilter> loadChatViewFilter(String jid) async {
    try {
      return await _dbOpReturning<XmppStateStore, MessageTimelineFilter>(
        (store) => _viewFilterFrom(store.read(key: _viewFilterKeyFor(jid))),
      );
    } on XmppAbortedException {
      return MessageTimelineFilter.allWithContact;
    }
  }

  Future<void> saveChatViewFilter({
    required String jid,
    required MessageTimelineFilter filter,
  }) async {
    await _dbOp<XmppStateStore>(
      (store) => store.write(key: _viewFilterKeyFor(jid), value: filter.name),
      awaitDatabase: true,
    );
  }

  Stream<MessageTransport?> watchChatTransportPreference(String jid) async* {
    try {
      final store = await _dbOpReturning<XmppStateStore, XmppStateStore>(
        (store) => store,
      );
      final stream = store.watch<String?>(key: _transportKeyFor(jid));
      if (stream != null) {
        yield* stream.map(_transportFrom);
      }
    } on XmppAbortedException {
      return;
    }
  }

  Stream<List<Chat>> homeChatsStream({
    int recentLimit = _defaultChatPreloadLimit,
  }) =>
      createPaginatedStream<Chat, XmppDatabase>(
        watchFunction: (db) async =>
            db.watchHomeChats(recentLimit: recentLimit),
        getFunction: (db) => db.getHomeChats(recentLimit: recentLimit),
      ).map((items) {
        _cacheSortedChatList(chats: items, limit: recentLimit);
        return items;
      });

  Stream<List<Chat>> allChatsStream() =>
      createPaginatedStream<Chat, XmppDatabase>(
        watchFunction: (db) async => db.watchAllChats(),
        getFunction: (db) => db.getAllChats(),
      );

  Future<List<Chat>> allChats() async {
    final chats = await _dbOpReturning<XmppDatabase, List<Chat>>(
      (db) => db.getAllChats(),
    );
    return sortChats(chats);
  }

  Future<List<Chat>?> preloadChatList({
    int limit = _defaultChatPreloadLimit,
  }) async {
    if (limit <= _chatPreloadDisabledLimit) return null;
    List<Chat> chats;
    try {
      chats = await _dbOpReturning<XmppDatabase, List<Chat>>(
        (db) => db.getChats(start: _chatPreloadStart, end: limit),
      );
    } on XmppAbortedException {
      return null;
    }
    return _cacheSortedChatList(chats: chats, limit: limit);
  }

  Stream<List<Chat>> unreadChatsForFolderBadgesStream() =>
      createSingleItemStream<List<Chat>, XmppDatabase>(
        watchFunction: (db) async {
          final stream = db.watchUnreadChatsForFolderBadges();
          final initial = await db.getUnreadChatsForFolderBadges();
          return stream.startWith(initial);
        },
      );

  void clearCachedChatList() {
    _cachedChatList = null;
  }

  List<Chat> _cacheSortedChatList({
    required List<Chat> chats,
    required int limit,
  }) {
    if (chats.isEmpty) {
      _cachedChatList = _emptyChatList;
      return _emptyChatList;
    }
    final limited = chats.length > limit
        ? chats.take(limit).toList(growable: false)
        : chats;
    final frozen = List<Chat>.unmodifiable(limited);
    _cachedChatList = frozen;
    return frozen;
  }

  Stream<List<String>> recipientAddressSuggestionsStream() =>
      createSingleItemStream<List<String>, XmppDatabase>(
        watchFunction: (db) async => db
            .watchRecipientAddressSuggestions(
              limit: _recipientAddressSuggestionLimit,
            )
            .map(
              (addresses) => addresses
                  .where((address) => !_isLocalOnlyChatJid(address))
                  .toList(growable: false),
            ),
      );

  Stream<Chat?> chatStream(String jid) =>
      createSingleItemStream<Chat?, XmppDatabase>(
        watchFunction: (db) async => db.watchChat(jid),
      );

  Stream<List<String>> typingParticipantsStream(String jid) {
    return _typingSessionFor(jid, create: true)!.stream;
  }

  @override
  Future<void> _reset() async {
    for (final session in _typingParticipantSessions.values.toList(
      growable: false,
    )) {
      session.dispose();
    }
    _typingParticipantSessions.clear();
    _pendingConversationIndexSeeds.clear();
    _conversationIndexSnapshotResolved = false;
    _chatSettingsLoginSync = null;
    _chatSettingsSourceId = null;
    await super._reset();
  }

  void clearTypingParticipants(String jid) {
    _typingSessionFor(jid)?.clear();
  }

  void _trackTypingParticipant({
    required String chatJid,
    required String participantId,
    required mox.ChatState state,
  }) {
    final myBare = _myJid?.toBare().toString();
    final senderBare = _safeBareJid(participantId);
    if (senderBare != null && senderBare == myBare) {
      return;
    }
    _typingSessionFor(
      chatJid,
      create: true,
    )!.track(participantId: participantId, state: state);
  }

  void _disposeTypingParticipantsIfIdle(String jid) {
    final session = _typingSessionFor(jid);
    if (session == null || session.hasListener) return;
    _typingParticipantSessions.remove(jid);
    session.dispose();
  }

  _TypingParticipantsSession? _typingSessionFor(
    String jid, {
    bool create = false,
  }) {
    if (!create) {
      return _typingParticipantSessions[jid];
    }
    return _typingParticipantSessions.putIfAbsent(
      jid,
      () => _TypingParticipantsSession(
        linger: _typingParticipantLinger,
        maxCount: _typingParticipantMaxCount,
        onIdle: () => _disposeTypingParticipantsIfIdle(jid),
      ),
    );
  }

  String? _safeBareJid(String? jid) {
    if (jid == null || jid.isEmpty) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } on Exception {
      return null;
    }
  }

  static List<Chat> sortChats(List<Chat> chats) => chats.toList()
    ..sort((a, b) {
      return compareChatsByLastChangeTimestamp(a, b);
    });

  Future<void> sendChatState({
    required String jid,
    required mox.ChatState state,
  }) async {
    if (_isLocalOnlyChatJid(jid)) {
      return;
    }
    await _sendChatState(jid: jid, state: state);
  }

  Future<void> sendTyping({required String jid, required bool typing}) async {
    await sendChatState(
      state: typing ? mox.ChatState.composing : mox.ChatState.paused,
      jid: jid,
    );
  }

  Future<void> _sendChatStateForChat({
    required Chat? chat,
    required mox.ChatState state,
  }) async {
    if (chat == null || chat.defaultTransport.isEmail) {
      return;
    }
    final targetJid = chat.remoteJid.trim().isNotEmpty
        ? chat.remoteJid
        : chat.jid;
    await sendChatState(jid: targetJid, state: state);
  }

  Future<void> openChat(String jid) async {
    final existingBeforeOpen = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(jid),
    );
    stageOpenChatUnreadBoundarySeed(
      jid: jid,
      unreadCount: existingBeforeOpen?.unreadCount ?? 0,
    );
    final transition =
        await _dbOpReturning<XmppDatabase, ({Chat? closed, Chat? opened})>((
          db,
        ) async {
          final closed = await db.openChat(jid);
          final opened = await db.getChat(jid);
          return (closed: closed, opened: opened);
        });
    await _sendChatStateForChat(
      chat: transition.closed,
      state: mox.ChatState.inactive,
    );
    if (existingBeforeOpen == null) {
      await _seedConversationIndexForDirectChatCreation(jid);
    }
    await _sendChatStateForChat(
      chat: transition.opened,
      state: mox.ChatState.active,
    );
  }

  Future<void> closeChat() async {
    final closed = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.closeChat(),
    );
    await _sendChatStateForChat(chat: closed, state: mox.ChatState.inactive);
  }

  Future<void> toggleChatMuted({
    required String jid,
    required bool muted,
  }) async {
    await _dbOp<XmppDatabase>((db) => db.markChatMuted(jid: jid, muted: muted));
    await _syncConversationIndexMeta(jid: jid);
    scheduleForegroundNotificationSnapshotPublish();
  }

  Future<bool> setChatNotificationPreviewSetting({
    required String jid,
    required NotificationPreviewSetting? setting,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.notificationPreview,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        notificationPreviewSetting: setting,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<bool> setChatNotificationBehavior({
    required String jid,
    required ChatNotificationBehavior? behavior,
  }) async {
    final published = await _updateLocalChatSetting(
      settingId: ChatSettingId.notificationBehavior,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        notificationBehavior: behavior,
        muted: behavior == ChatNotificationBehavior.muted,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
    await _syncConversationIndexMeta(jid: jid);
    return published;
  }

  Future<bool> toggleChatShareSignature({
    required String jid,
    required bool? enabled,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.shareSignature,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        shareSignatureEnabled: enabled,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<bool> toggleChatAttachmentAutoDownload({
    required String jid,
    required AttachmentAutoDownload? value,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.attachmentAutoDownload,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        attachmentAutoDownload: value,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<bool> setChatEmailRemoteImages({
    required String jid,
    required bool? enabled,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.emailImageAutoload,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        emailRemoteImagesEnabled: enabled,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<bool> setChatTypingIndicators({
    required String jid,
    required bool? enabled,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.typingIndicators,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        typingIndicatorsEnabled: enabled,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<bool> setChatEmailReadReceipts({
    required String jid,
    required bool? enabled,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.emailReadReceipts,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        emailReadReceiptsEnabled: enabled,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<bool> setChatEmailSendConfirmation({
    required String jid,
    required bool? enabled,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.emailSendConfirmation,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        emailSendConfirmationEnabled: enabled,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<bool> setChatEmailComposerWatermark({
    required String jid,
    required bool? enabled,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.emailComposerWatermark,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        emailComposerWatermarkEnabled: enabled,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<bool> retryChatSettingsSync(String jid) async {
    try {
      final normalizedJid = jid.trim();
      if (normalizedJid.isEmpty) return false;
      final chat = await _dbOpReturning<XmppDatabase, Chat?>(
        (db) => db.getChat(normalizedJid),
      );
      if (chat == null || !chat.hasChatSettingsSyncPayload) {
        return true;
      }
      return _publishChatSettingsForChat(
        chat,
        clearedSettings: _clearedUnsyncedChatSettings(chat),
      );
    } on XmppAbortedException {
      return false;
    }
  }

  Future<({bool localApplied, bool published})> resetChatSettingOverrides(
    ChatSettingId settingId, {
    Iterable<String> chatJids = const <String>[],
  }) async {
    var localApplied = false;
    try {
      final targetJids = chatJids
          .map(normalizedAddressKey)
          .whereType<String>()
          .toSet();
      final sourceId = await _ensureChatSettingsSourceId();
      final updatedAt = DateTime.timestamp().toUtc();
      final updatedChats = await _dbOpReturning<XmppDatabase, List<Chat>>((
        db,
      ) async {
        final existing = await db.getChats(start: 0, end: 0);
        final targets = existing
            .where((chat) {
              if (targetJids.isNotEmpty) {
                final chatKey = normalizedAddressKey(chat.jid);
                if (chatKey == null || !targetJids.contains(chatKey)) {
                  return false;
                }
              }
              if (settingId == ChatSettingId.notificationBehavior) {
                return chat.effectiveNotificationBehavior != null;
              }
              return settingId.syncValueFrom(chat) != null;
            })
            .toList(growable: false);
        final updated = <Chat>[];
        for (final chat in targets) {
          final next = settingId.applySyncedValue(
            chat,
            null,
            updatedAt: updatedAt,
            sourceId: sourceId,
          );
          await db.updateChatSettingsSyncState(next);
          updated.add(next);
        }
        return updated;
      });
      localApplied = updatedChats.isNotEmpty;
      if (localApplied && _isForegroundNotificationChatSetting(settingId)) {
        scheduleForegroundNotificationSnapshotPublish();
      }
      var published = true;
      for (final chat in updatedChats) {
        final clearedSettings = _clearedUnsyncedChatSettings(chat)
          ..add(settingId);
        published =
            await _publishChatSettingsForChat(
              chat,
              clearedSettings: clearedSettings,
            ) &&
            published;
        if (settingId == ChatSettingId.notificationBehavior) {
          await _syncConversationIndexMeta(jid: chat.jid);
        }
      }
      return (localApplied: localApplied, published: published);
    } on XmppAbortedException {
      return (localApplied: localApplied, published: false);
    }
  }

  Future<bool> _updateLocalChatSetting({
    required ChatSettingId settingId,
    required String jid,
    required Chat Function(Chat chat, DateTime updatedAt, String sourceId)
    update,
  }) async {
    try {
      final normalizedJid = jid.trim();
      if (normalizedJid.isEmpty) return false;
      final sourceId = await _ensureChatSettingsSourceId();
      final updatedAt = DateTime.timestamp().toUtc();
      final updatedChat = await _dbOpReturning<XmppDatabase, Chat?>((db) async {
        final existing = await db.getChat(normalizedJid);
        if (existing == null) {
          return null;
        }
        final next = update(existing, updatedAt, sourceId);
        await db.updateChatSettingsSyncState(next);
        return next;
      });
      if (updatedChat == null) {
        return false;
      }
      final clearedSettings = _clearedUnsyncedChatSettings(updatedChat);
      if (settingId.syncValueFrom(updatedChat) == null) {
        clearedSettings.add(settingId);
      }
      final published = await _publishChatSettingsForChat(
        updatedChat,
        clearedSettings: clearedSettings,
      );
      if (_isForegroundNotificationChatSetting(settingId)) {
        scheduleForegroundNotificationSnapshotPublish();
      }
      return published;
    } on XmppAbortedException {
      return false;
    }
  }

  bool _isForegroundNotificationChatSetting(ChatSettingId settingId) {
    return settingId == ChatSettingId.notificationPreview ||
        settingId == ChatSettingId.notificationBehavior;
  }

  Future<String> _ensureChatSettingsSourceId() async {
    final existing = _chatSettingsSourceId?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    try {
      final loaded = await _dbOpReturning<XmppStateStore, String?>((store) {
        final raw = store.read(key: _chatSettingsSyncSourceKey)?.toString();
        final normalized = raw?.trim();
        return normalized?.isEmpty == false ? normalized : null;
      });
      if (loaded != null) {
        _chatSettingsSourceId = loaded;
        return loaded;
      }
    } on XmppAbortedException {
      final generated = const Uuid().v4();
      _chatSettingsSourceId = generated;
      return generated;
    }
    final generated = const Uuid().v4();
    _chatSettingsSourceId = generated;
    await _dbOp<XmppStateStore>(
      (store) => store.write(key: _chatSettingsSyncSourceKey, value: generated),
      awaitDatabase: true,
    );
    return generated;
  }

  Set<ChatSettingId> _clearedUnsyncedChatSettings(Chat chat) {
    return chat.unsyncedChatSettingIds
        .where((settingId) => settingId.syncValueFrom(chat) == null)
        .toSet();
  }

  Future<ChatSettingsPubSubManager?> _chatSettingsManagerForSync() async {
    final support = await refreshPubSubSupport();
    final decision = decidePubSubSupport(
      supported: support.canUsePepNodes,
      featureLabel: 'chat settings sync',
    );
    if (!decision.isAllowed) return null;
    return _chatSettingsManager;
  }

  Future<bool> _publishChatSettingsForChat(
    Chat chat, {
    Set<ChatSettingId> clearedSettings = const <ChatSettingId>{},
    ChatSettingsPubSubManager? managerOverride,
    bool managerReady = false,
  }) async {
    try {
      final readyChat = await _ensureChatSettingsPayloadIdentity(chat);
      final payload = ChatSettingsSyncPayload.fromChat(
        readyChat,
        clearedSettings: clearedSettings,
      );
      if (payload == null) {
        return false;
      }
      if (!_hasInitializedConnection || !_connection.hasConnectionSettings) {
        return false;
      }
      final manager = managerOverride ?? await _chatSettingsManagerForSync();
      if (manager == null) {
        return false;
      }
      if (!managerReady) {
        await manager.ensureNode();
      }
      final published = await manager.publishSettings(payload);
      if (published) {
        await _confirmChatSettingsSync(payload);
      }
      return published;
    } on XmppAbortedException {
      return false;
    }
  }

  Future<Chat> _ensureChatSettingsPayloadIdentity(Chat chat) async {
    final updatedAt = chat.chatSettingsUpdatedAt;
    final sourceId = chat.chatSettingsSourceId?.trim();
    if (updatedAt != null && sourceId != null && sourceId.isNotEmpty) {
      return chat;
    }
    if (!chat.hasChatSettingsSyncOverrides) {
      return chat;
    }
    final next = chat.copyWith(
      chatSettingsUpdatedAt: DateTime.timestamp().toUtc(),
      chatSettingsSourceId: await _ensureChatSettingsSourceId(),
    );
    await _dbOp<XmppDatabase>((db) => db.updateChatSettingsSyncState(next));
    return next;
  }

  Future<Chat?> _chatForChatSettingsAddressKey(
    XmppDatabase db,
    String addressKey,
  ) async {
    final normalizedAddress = normalizedAddressKey(addressKey);
    if (normalizedAddress == null || normalizedAddress.isEmpty) {
      return null;
    }
    final direct = await db.getChat(normalizedAddress);
    if (direct != null) {
      return direct;
    }
    for (final candidate in await db.getChats(start: 0, end: 0)) {
      final candidateAddressKey = normalizedAddressKey(candidate.jid);
      if (candidateAddressKey == normalizedAddress) {
        return candidate;
      }
    }
    return null;
  }

  Future<void> _confirmChatSettingsSync(ChatSettingsSyncPayload payload) async {
    final encoded = payload.encodedSettings;
    if (encoded == null) {
      return;
    }
    await _dbOp<XmppDatabase>((db) async {
      final existing = await _chatForChatSettingsAddressKey(
        db,
        payload.addressKey,
      );
      if (existing == null) {
        return;
      }
      await db.updateChatSettingsSyncState(
        existing.copyWith(
          chatSettingsConfirmedJson: encoded,
          chatSettingsConfirmedUpdatedAt: payload.updatedAt.toUtc(),
          chatSettingsConfirmedSourceId: payload.sourceId,
        ),
      );
    });
  }

  Future<void> _applyChatSettingsSyncUpdate(
    ChatSettingsSyncPayload payload, {
    ChatSettingsPubSubManager? managerOverride,
  }) async {
    final local = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => _chatForChatSettingsAddressKey(db, payload.addressKey),
    );
    if (local == null) {
      return;
    }
    switch (_resolveChatSettingsSyncDecision(local: local, remote: payload)) {
      case _ChatSettingsSyncDecision.applyRemote:
        await _saveRemoteChatSettingsSync(local: local, remote: payload);
        await _syncConversationIndexMeta(jid: local.jid);
        scheduleForegroundNotificationSnapshotPublish();
      case _ChatSettingsSyncDecision.publishLocal:
        await _publishChatSettingsForChat(
          local,
          managerOverride: managerOverride,
          managerReady: managerOverride != null,
        );
      case _ChatSettingsSyncDecision.skip:
        await _confirmChatSettingsSync(payload);
    }
  }

  _ChatSettingsSyncDecision _resolveChatSettingsSyncDecision({
    required Chat local,
    required ChatSettingsSyncPayload remote,
  }) {
    final remoteJson = remote.encodedSettings;
    final localJson = ChatSettingsSyncPayload.encodeSettingsData(
      local.chatSettingsSyncJson,
    );
    if (remoteJson != null && remoteJson == localJson) {
      return _ChatSettingsSyncDecision.skip;
    }
    final localUpdatedAt = local.chatSettingsUpdatedAt;
    final localSourceId = local.chatSettingsSourceId?.trim();
    if (localUpdatedAt == null ||
        localSourceId == null ||
        localSourceId.isEmpty) {
      return _ChatSettingsSyncDecision.applyRemote;
    }
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    final normalizedLocalUpdatedAt = localUpdatedAt.toUtc();
    if (remoteUpdatedAt.isAfter(normalizedLocalUpdatedAt)) {
      return _ChatSettingsSyncDecision.applyRemote;
    }
    if (remoteUpdatedAt.isBefore(normalizedLocalUpdatedAt)) {
      return _ChatSettingsSyncDecision.publishLocal;
    }
    final remoteSourceId = remote.sourceId.trim();
    if (remoteSourceId == localSourceId) {
      return _ChatSettingsSyncDecision.skip;
    }
    if (remoteSourceId.compareTo(localSourceId) > 0) {
      return _ChatSettingsSyncDecision.applyRemote;
    }
    return _ChatSettingsSyncDecision.publishLocal;
  }

  Future<void> _saveRemoteChatSettingsSync({
    required Chat local,
    required ChatSettingsSyncPayload remote,
  }) async {
    final encoded = remote.encodedSettings;
    if (encoded == null) {
      return;
    }
    final next = remote.applyToChat(local);
    await _dbOp<XmppDatabase>(
      (db) => db.updateChatSettingsSyncState(
        next.copyWith(
          chatSettingsConfirmedJson: encoded,
          chatSettingsConfirmedUpdatedAt: remote.updatedAt.toUtc(),
          chatSettingsConfirmedSourceId: remote.sourceId,
        ),
      ),
    );
  }

  Future<void> _handleChatSettingsSyncRetraction(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final chat = await _dbOpReturning<XmppDatabase, Chat?>((db) async {
      for (final candidate in await db.getChats(start: 0, end: 0)) {
        final addressKey = normalizedAddressKey(candidate.jid);
        if (addressKey == null || addressKey.isEmpty) {
          continue;
        }
        if (ChatSettingsSyncPayload.itemIdFor(addressKey: addressKey) ==
            normalized) {
          return candidate;
        }
      }
      return null;
    });
    if (chat == null || !chat.hasChatSettingsSyncPayload) {
      return;
    }
    await _publishChatSettingsForChat(chat);
  }

  Future<void> toggleChatFavorited({
    required String jid,
    required bool favorited,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatFavorited(jid: jid, favorited: favorited),
    );
    await _syncConversationIndexMeta(jid: jid);
  }

  Future<void> toggleChatArchived({
    required String jid,
    required bool archived,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatArchived(jid: jid, archived: archived),
    );
    await _syncConversationIndexMeta(jid: jid);
  }

  Future<void> toggleChatHidden({
    required String jid,
    required bool hidden,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatHidden(jid: jid, hidden: hidden),
    );
  }

  Future<void> toggleChatSpam({required String jid, required bool spam}) async {
    await _dbOp<XmppDatabase>((db) => db.markChatSpam(jid: jid, spam: spam));
  }

  Future<List<Message>> loadCompleteChatHistory({
    required String jid,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    return _dbOpReturning<XmppDatabase, List<Message>>(
      (db) => db.getAllMessagesForChat(jid, filter: filter),
    );
  }

  Future<Chat?> loadOpenChat() async {
    return _dbOpReturning<XmppDatabase, Chat?>((db) => db.getOpenChat());
  }

  Future<void> preloadChatWindow({
    required String jid,
    int messageLimit = _openChatPreloadMessageLimit,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty ||
        messageLimit <= _openChatPreloadMessageDisabledLimit) {
      return;
    }
    await _dbOpReturning<XmppDatabase, List<Message>>(
      (db) => db.getChatMessages(
        normalizedJid,
        start: _openChatPreloadMessageStart,
        end: messageLimit,
        filter: filter,
      ),
    );
    await _dbOpReturning<XmppDatabase, List<Reaction>>(
      (db) => db.getReactionsForChat(normalizedJid),
    );
  }

  Future<bool> toggleChatMarkerResponsive({
    required String jid,
    required bool? responsive,
  }) async {
    return _updateLocalChatSetting(
      settingId: ChatSettingId.readReceipts,
      jid: jid,
      update: (chat, updatedAt, sourceId) => chat.copyWith(
        markerResponsive: responsive,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: sourceId,
      ),
    );
  }

  Future<void> toggleAllChatsMarkerResponsive({
    required bool responsive,
  }) async {
    if (_lastMarkerResponsive == responsive) return;
    _lastMarkerResponsive = responsive;
    await _dbOp<XmppDatabase>(
      (db) => db.markChatsMarkerResponsive(responsive: responsive),
    );
  }

  Future<void> setChatEncryption({
    required String jid,
    required EncryptionProtocol protocol,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.updateChatEncryption(chatJid: jid, protocol: protocol),
    );
  }

  Future<void> setChatAlert({
    required String jid,
    required String alert,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.updateChatAlert(chatJid: jid, alert: alert),
    );
  }

  Future<void> clearChatAlert({required String jid}) async {
    await _dbOp<XmppDatabase>(
      (db) => db.updateChatAlert(chatJid: jid, alert: null),
    );
  }

  Future<void> deleteChat({required String jid}) async {
    await _dbOp<XmppDatabase>((db) => db.removeChat(jid));
  }

  Future<void> deleteChatMessages({required String jid}) async {
    await _dbOp<XmppDatabase>((db) => db.removeChatMessages(jid));
  }

  Future<void> renameChatContact({
    required String jid,
    required String displayName,
  }) async {
    final trimmed = displayName.trim();
    MessageTransport? transport;
    String? rosterTitle;
    await _dbOp<XmppDatabase>((db) async {
      final chat = await db.getChat(jid);
      transport = chat?.transport;
      if (chat != null) {
        rosterTitle = chat.title.trim().isNotEmpty ? chat.title : null;
        final updated = chat.copyWith(
          contactDisplayName: trimmed.isNotEmpty ? trimmed : null,
        );
        await db.updateChat(updated);
      }
      final rosterItem = await db.getRosterItem(jid);
      if (rosterItem != null) {
        rosterTitle ??= rosterItem.title;
        if (trimmed.isNotEmpty) {
          rosterTitle = trimmed;
          await db.updateRosterItem(rosterItem.copyWith(title: trimmed));
        } else if (rosterTitle != null) {
          await db.updateRosterItem(rosterItem.copyWith(title: rosterTitle!));
        }
      }
    });
    if (_isLocalOnlyChatJid(jid)) {
      return;
    }
    rosterTitle ??= addressDisplayLabel(jid) ?? mox.JID.fromString(jid).local;
    if (transport?.isXmpp == true && rosterTitle != null) {
      final renamed = await _connection.addToRoster(jid, title: rosterTitle);
      if (!renamed) {
        throw XmppRosterException();
      }
    }
  }

  Future<void> applyConversationIndexItems(List<ConvItem> items) async {
    if (items.isEmpty) return;
    final now = DateTime.timestamp();
    await _dbOp<XmppDatabase>((db) async {
      for (final item in items) {
        final peerJid = item.peerBare.toBare().toString();
        if (peerJid.isEmpty) continue;
        if (_isConversationIndexLocalOnlyChatJid(peerJid)) continue;
        final isSelfChat = peerJid == myJid;

        final archived = item.archived;
        final pinned = item.pinned;
        final muted = item.mutedUntil?.toLocal().isAfter(now) ?? false;
        final messageTimestamp = item.lastTimestamp.toUtc();
        final lastVisibleSelfMessage = isSelfChat
            ? await db.getLastMessageForChat(peerJid)
            : null;
        final lastVisibleSelfTimestamp = lastVisibleSelfMessage?.timestamp
            ?.toUtc();
        final lastChangeCandidate =
            isSelfChat &&
                lastVisibleSelfTimestamp != null &&
                messageTimestamp.isAfter(lastVisibleSelfTimestamp)
            ? lastVisibleSelfTimestamp
            : messageTimestamp;

        final existing = await db.getChat(peerJid);
        if (existing == null) {
          final isSelfChat = peerJid == myJid;
          await db.createChat(
            Chat(
              jid: peerJid,
              title: isSelfChat
                  ? 'Saved Messages'
                  : addressDisplayLabel(peerJid) ??
                        mox.JID.fromString(peerJid).local,
              type: ChatType.chat,
              lastChangeTimestamp: lastChangeCandidate,
              transport: MessageTransport.xmpp,
              muted: muted,
              favorited: pinned,
              archived: archived,
              contactJid: peerJid,
            ),
          );
          continue;
        }

        if (existing.type != ChatType.chat) continue;

        final effectiveLastChange = isSelfChat
            ? lastChangeCandidate
            : (lastChangeCandidate.isAfter(existing.lastChangeTimestamp)
                  ? lastChangeCandidate
                  : existing.lastChangeTimestamp);

        final shouldUpdateMuted = existing.muted != muted;
        final shouldUpdatePinned = existing.favorited != pinned;
        final shouldUpdateArchived = existing.archived != archived;
        final shouldUpdateTimestamp =
            effectiveLastChange != existing.lastChangeTimestamp;
        final shouldUpdateContactJid = existing.contactJid != peerJid;
        final shouldNormalizeSelfTitle =
            isSelfChat &&
            existing.contactDisplayName?.trim().isNotEmpty != true &&
            existing.title.trim() != 'Saved Messages';

        if (!shouldUpdateMuted &&
            !shouldUpdatePinned &&
            !shouldUpdateArchived &&
            !shouldUpdateTimestamp &&
            !shouldUpdateContactJid &&
            !shouldNormalizeSelfTitle) {
          continue;
        }

        if (shouldNormalizeSelfTitle) {
          await db.updateChat(
            existing.copyWith(
              title: 'Saved Messages',
              lastChangeTimestamp: effectiveLastChange,
              muted: muted,
              favorited: pinned,
              archived: archived,
              contactJid: peerJid,
            ),
          );
          if (shouldUpdateTimestamp) {
            await db.repairChatSummaryPreservingTimestamp(peerJid);
          }
          continue;
        }

        await db.updateConversationIndexChatMeta(
          jid: peerJid,
          lastChangeTimestamp: effectiveLastChange,
          muted: muted,
          favorited: pinned,
          archived: archived,
          contactJid: peerJid,
        );
        if (shouldUpdateTimestamp) {
          await db.repairChatSummaryPreservingTimestamp(peerJid);
        }
      }
    }, awaitDatabase: true);
  }

  Future<void> applyConversationIndexSnapshot(
    ({List<ConvItem> items, bool isSuccess, bool isComplete}) snapshot,
  ) async {
    if (!snapshot.isSuccess) return;
    final items = snapshot.items;
    _connection.getManager<ConversationIndexManager>()?.cacheSnapshot(
      items,
      isComplete: snapshot.isComplete,
    );
    await applyConversationIndexItems(items);
    if (snapshot.isComplete) {
      await _queueMissingLocalConversationIndexSeeds(items);
      await _reconcileConversationIndexRemovals(items);
      _conversationIndexSnapshotResolved = true;
      await _flushPendingConversationIndexSeeds();
    }
  }

  Future<void> _queueMissingLocalConversationIndexSeeds(
    List<ConvItem> items,
  ) async {
    final knownPeers = items
        .map((item) => item.peerBare.toBare().toString())
        .toSet();
    final selfJid = myJid;
    final localMissingPeers = await _dbOpReturning<XmppDatabase, Set<String>>((
      db,
    ) async {
      final chats = await db.getChats(
        start: _conversationIndexSnapshotStart,
        end: _conversationIndexSnapshotEnd,
      );
      final peers = <String>{};
      for (final chat in chats) {
        if (chat.archived) continue;
        final normalized = _conversationIndexPeerForLocalChat(
          chat,
          selfJid: selfJid,
        );
        if (normalized == null) continue;
        if (knownPeers.contains(normalized)) continue;
        peers.add(normalized);
      }
      return peers;
    });
    _pendingConversationIndexSeeds.addAll(localMissingPeers);
  }

  Future<void> _reconcileConversationIndexRemovals(List<ConvItem> items) async {
    if (items.isEmpty) {
      _chatsLog.fine(
        'Skipping conversation index removal reconciliation for an empty snapshot.',
      );
      return;
    }
    final knownPeers = items
        .map((item) => item.peerBare.toBare().toString())
        .toSet();
    knownPeers.addAll(
      _pendingConversationIndexSeeds
          .map(_normalizeBareChatJid)
          .whereType<String>(),
    );
    final selfJid = myJid;
    await _dbOp<XmppDatabase>((db) async {
      final chats = await db.getChats(
        start: _conversationIndexSnapshotStart,
        end: _conversationIndexSnapshotEnd,
      );
      for (final chat in chats) {
        final normalized = _conversationIndexPeerForLocalChat(
          chat,
          selfJid: selfJid,
        );
        if (normalized == null) continue;
        if (knownPeers.contains(normalized)) continue;
        if (chat.archived) continue;
        await db.updateConversationIndexArchived(jid: chat.jid, archived: true);
      }
    }, awaitDatabase: true);
  }

  Future<void> _applyConversationIndexRetraction(mox.JID peerBare) async {
    final peer = peerBare.toBare().toString();
    if (peer.isEmpty) return;
    if (_isConversationIndexLocalOnlyChatJid(peer)) return;
    await _dbOp<XmppDatabase>((db) async {
      final existing = await db.getChat(peer);
      if (existing == null || existing.type != ChatType.chat) return;
      if (existing.archived) return;
      await db.updateConversationIndexArchived(
        jid: existing.jid,
        archived: true,
      );
    }, awaitDatabase: true);
  }

  Future<void> _syncConversationIndexMeta({required String jid}) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty) return;
    if (_isConversationIndexLocalOnlyChatJid(normalizedJid)) return;

    final manager = await _conversationIndexManagerForSync();
    if (manager == null) return;

    final chat = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(normalizedJid),
    );
    if (chat == null || chat.type != ChatType.chat) return;
    if (!chat.transport.isXmpp) return;

    final peer = mox.JID.fromString(normalizedJid).toBare();
    final cached = manager.cachedForPeer(peer);
    final lastTimestamp =
        cached?.lastTimestamp ?? chat.lastChangeTimestamp.toUtc();
    final mutedUntil = chat.muted
        ? DateTime.timestamp().add(_mutedForeverDuration).toUtc()
        : null;

    await manager.upsert(
      ConvItem(
        peerBare: peer,
        lastTimestamp: lastTimestamp,
        lastId: cached?.lastId,
        pinned: chat.favorited,
        archived: chat.archived,
        mutedUntil: mutedUntil,
      ),
    );
  }

  @override
  Future<void> _seedConversationIndexForDirectChatCreation(String jid) async {
    await _enqueueConversationIndexSeed(jid);
  }

  Future<void> _enqueueConversationIndexSeed(String jid) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty) return;
    if (_isConversationIndexLocalOnlyChatJid(normalizedJid)) return;
    _pendingConversationIndexSeeds.add(normalizedJid);
    if (!_conversationIndexSnapshotResolved) {
      return;
    }
    if (await _publishConversationIndexSeedIfMissing(normalizedJid)) {
      _pendingConversationIndexSeeds.remove(normalizedJid);
    }
  }

  Future<void> _flushPendingConversationIndexSeeds() async {
    if (_pendingConversationIndexSeeds.isEmpty) return;
    final pending = _pendingConversationIndexSeeds.toList(growable: false);
    for (final jid in pending) {
      if (await _publishConversationIndexSeedIfMissing(jid)) {
        _pendingConversationIndexSeeds.remove(jid);
      }
    }
  }

  Future<bool> _publishConversationIndexSeedIfMissing(String jid) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty) return true;
    if (_isConversationIndexLocalOnlyChatJid(normalizedJid)) return true;
    if (!_conversationIndexSnapshotResolved) return false;

    final decision = await _conversationIndexSyncDecision();
    if (!decision.isAllowed) return true;

    final manager = conversationIndexManager;
    if (manager == null) return false;

    final chat = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(normalizedJid),
    );
    if (chat == null || chat.type != ChatType.chat) return true;
    if (!chat.transport.isXmpp) return true;

    late final mox.JID peer;
    try {
      peer = mox.JID.fromString(normalizedJid).toBare();
    } on Exception {
      return true;
    }
    if (manager.cachedForPeer(peer) != null) return true;

    final mutedUntil = chat.muted
        ? DateTime.timestamp().add(_mutedForeverDuration).toUtc()
        : null;
    return manager.upsert(
      ConvItem(
        peerBare: peer,
        lastTimestamp: chat.lastChangeTimestamp.toUtc(),
        lastId: null,
        pinned: chat.favorited,
        archived: chat.archived,
        mutedUntil: mutedUntil,
      ),
    );
  }

  Future<ConversationIndexManager?> _conversationIndexManagerForSync() async {
    final decision = await _conversationIndexSyncDecision();
    if (!decision.isAllowed) return null;
    return conversationIndexManager;
  }

  Future<CapabilityDecision> _conversationIndexSyncDecision() async {
    final support = await refreshPubSubSupport();
    return decidePubSubSupport(
      supported: support.canUsePepNodes,
      featureLabel: 'conversation index',
    );
  }

  String? _conversationIndexPeerForLocalChat(
    Chat chat, {
    required String? selfJid,
  }) {
    if (chat.type != ChatType.chat) return null;
    if (!chat.defaultTransport.isXmpp) return null;
    final normalized = _normalizeBareChatJid(chat.jid);
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized == selfJid) return null;
    if (_isConversationIndexLocalOnlyChatJid(normalized)) return null;
    return normalized;
  }

  String? _normalizeBareChatJid(String jid) {
    final trimmed = jid.trim();
    if (trimmed.isEmpty) return null;
    try {
      return mox.JID.fromString(trimmed).toBare().toString();
    } on Exception {
      return null;
    }
  }

  bool _isLocalOnlyChatJid(String jid) =>
      sameNormalizedAddressValue(jid, _signupWelcomeChatJid);

  bool _isConversationIndexLocalOnlyChatJid(String jid) =>
      _isLocalOnlyChatJid(jid);
}

class MUCManager extends mox.MUCManager {
  Future<void> joinRoomWithStrings({
    required String jid,
    required String nickname,
    int? maxHistoryStanzas,
  }) async {
    await super.joinRoom(
      mox.JID.fromString(jid),
      nickname,
      maxHistoryStanzas: maxHistoryStanzas,
    );
  }

  Future<void> sendAdminIq({
    required String roomJid,
    required List<mox.XMLNode> items,
  }) async {
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: 'set',
          to: roomJid,
          children: [
            mox.XMLNode.xmlns(
              tag: 'query',
              xmlns: _mucAdminXmlns,
              children: items,
            ),
          ],
        ),
      ),
    );
    if (result == null || result.attributes['type'] != 'result') {
      throw XmppMessageException();
    }
  }

  Future<void> sendOwnerIq({
    required String roomJid,
    required List<mox.XMLNode> children,
  }) async {
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: 'set',
          to: roomJid,
          children: [
            mox.XMLNode.xmlns(
              tag: 'query',
              xmlns: _mucOwnerXmlns,
              children: children,
            ),
          ],
        ),
      ),
    );
    if (result == null || result.attributes['type'] != 'result') {
      throw XmppMessageException();
    }
  }
}
