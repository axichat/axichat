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
  static const List<ConvItem> _emptyConversationIndexSnapshot = <ConvItem>[];
  static const List<Chat> _emptyChatList = <Chat>[];
  final Map<String, _TypingParticipantsSession> _typingParticipantSessions = {};
  final Map<String, int> _openChatUnreadBoundarySeedByJid = {};
  Future<List<ConvItem>>? _conversationIndexLoginSync;
  List<Chat>? _cachedChatList;
  bool? _lastMarkerResponsive;

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
    Message? insertedMessage;
    try {
      final db = await database;
      final existingMessage = await db.getMessageByStanzaID(welcomeStanzaId);
      final existingChat = await db.getChat(_signupWelcomeChatJid);
      if (existingMessage == null) {
        if (existingChat != null) {
          if (existingChat.title != title ||
              existingChat.contactDisplayName != title ||
              existingChat.contactJid != _signupWelcomeChatJid) {
            await db.updateChat(
              existingChat.copyWith(
                title: title,
                contactDisplayName: title,
                contactJid: _signupWelcomeChatJid,
              ),
            );
          }
        } else if (!allowInsert) {
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
            contactDisplayName: title,
            contactJid: _signupWelcomeChatJid,
          ),
        );
        return;
      }
      if (existingChat.title != title ||
          existingChat.contactDisplayName != title ||
          existingChat.contactJid != _signupWelcomeChatJid) {
        await db.updateChat(
          existingChat.copyWith(
            title: title,
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

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _conversationIndexBootstrapOperationName,
        priority: 0,
        lane: 'conversationIndex',
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _conversationIndexBootstrapOperationName,
        run: () async {
          await syncConversationIndexSnapshot();
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
      });
  }

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    ConversationIndexManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    conversationIndexNotifyFeature,
  ];

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
        return _emptyConversationIndexSnapshot;
      }

      final manager = _connection.getManager<ConversationIndexManager>();
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

  Stream<List<Chat>> chatsStream({
    int start = _chatPreloadStart,
    int end = _defaultChatPreloadLimit,
  }) =>
      createPaginatedStream<Chat, XmppDatabase>(
        watchFunction: (db) async =>
            db.watchChats(start: start, end: end).map(sortChats),
        getFunction: (db) async =>
            sortChats(await db.getChats(start: start, end: end)),
      ).map((items) {
        _cacheSortedChatList(chats: items, limit: end);
        return items;
      });

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
    final sorted = sortChats(chats);
    return _cacheSortedChatList(chats: sorted, limit: limit);
  }

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
        watchFunction: (db) async => db.watchRecipientAddressSuggestions(
          limit: _recipientAddressSuggestionLimit,
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
      if (a.favorited == b.favorited) {
        return b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp);
      }
      return (!a.favorited).toSign;
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

  Future<void> openChat(String jid) async {
    final unreadBeforeOpen = await _dbOpReturning<XmppDatabase, int?>((
      db,
    ) async {
      final existing = await db.getChat(jid);
      return existing?.unreadCount;
    });
    stageOpenChatUnreadBoundarySeed(
      jid: jid,
      unreadCount: unreadBeforeOpen ?? 0,
    );
    final closed = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.openChat(jid),
    );
    if (closed != null) {
      await sendChatState(jid: closed.jid, state: mox.ChatState.inactive);
    }
    await sendChatState(jid: jid, state: mox.ChatState.active);
  }

  Future<void> closeChat() async {
    await _dbOp<XmppDatabase>((db) async {
      final closed = await db.closeChat();
      if (closed == null) return;
      await sendChatState(jid: closed.jid, state: mox.ChatState.inactive);
    });
  }

  Future<void> toggleChatMuted({
    required String jid,
    required bool muted,
  }) async {
    await _dbOp<XmppDatabase>((db) => db.markChatMuted(jid: jid, muted: muted));
    await _syncConversationIndexMeta(jid: jid);
  }

  Future<void> setChatNotificationPreviewSetting({
    required String jid,
    required NotificationPreviewSetting? setting,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.setChatNotificationPreviewSetting(jid: jid, setting: setting),
    );
  }

  Future<void> toggleChatShareSignature({
    required String jid,
    required bool? enabled,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.setChatShareSignature(jid: jid, enabled: enabled),
    );
  }

  Future<void> toggleChatAttachmentAutoDownload({
    required String jid,
    required bool enabled,
  }) async {
    final value = enabled
        ? AttachmentAutoDownload.allowed
        : AttachmentAutoDownload.blocked;
    await _dbOp<XmppDatabase>(
      (db) => db.setChatAttachmentAutoDownload(jid: jid, value: value),
    );
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

  Future<void> toggleChatMarkerResponsive({
    required String jid,
    required bool responsive,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatMarkerResponsive(jid: jid, responsive: responsive),
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
    await applyConversationIndexItems(items);
    if (snapshot.isComplete) {
      await _reconcileConversationIndexRemovals(items);
    }
  }

  Future<void> _reconcileConversationIndexRemovals(List<ConvItem> items) async {
    final knownPeers = items
        .map((item) => item.peerBare.toBare().toString())
        .toSet();
    final selfJid = myJid;
    await _dbOp<XmppDatabase>((db) async {
      final chats = await db.getChats(
        start: _conversationIndexSnapshotStart,
        end: _conversationIndexSnapshotEnd,
      );
      for (final chat in chats) {
        if (chat.type != ChatType.chat) continue;
        if (!chat.defaultTransport.isXmpp) continue;
        final normalized = _normalizeBareChatJid(chat.jid);
        if (normalized == null || normalized.isEmpty) continue;
        if (normalized == selfJid) continue;
        if (_isConversationIndexLocalOnlyChatJid(normalized)) continue;
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
    if (jid.isEmpty) return;
    if (_isConversationIndexLocalOnlyChatJid(jid)) return;

    final manager = _connection.getManager<ConversationIndexManager>();
    if (manager == null) return;

    final chat = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(jid),
    );
    if (chat == null || chat.type != ChatType.chat) return;
    if (!chat.transport.isXmpp) return;

    final peer = mox.JID.fromString(jid).toBare();
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
