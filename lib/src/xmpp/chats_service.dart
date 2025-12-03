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

mixin ChatsService on XmppBase, BaseStreamService, MucService {
  static final _transportKeys = <String, RegisteredStateKey>{};
  static final _viewFilterKeys = <String, RegisteredStateKey>{};
  final Logger _chatLog = Logger('ChatsService');
  static const _typingParticipantLinger = Duration(seconds: 6);
  static const _typingParticipantMaxCount = 7;
  final Map<String, Set<String>> _typingParticipants = {};
  final Map<String, Map<String, Timer>> _typingParticipantExpiry = {};
  final Map<String, StreamController<List<String>>> _typingParticipantStreams =
      {};

  bool _isMucChatJid(String jid) {
    try {
      return mox.JID.fromString(jid).domain == mucServiceHost;
    } on Exception {
      return false;
    }
  }

  String _chatStateMessageType(String jid) {
    if (!_isMucChatJid(jid)) return 'chat';
    try {
      final parsed = mox.JID.fromString(jid);
      return parsed.resource.isEmpty ? 'groupchat' : 'chat';
    } on Exception {
      return 'chat';
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
      return await _dbOpReturning<XmppDatabase, MessageTransport>(
        (db) async {
          final chat = await db.getChat(jid);
          return chat?.defaultTransport ?? MessageTransport.xmpp;
        },
      );
    } on XmppAbortedException {
      return MessageTransport.xmpp;
    }
  }

  Future<ChatTransportPreference> loadChatTransportPreference(
      String jid) async {
    final defaultTransport = await _defaultTransportForChat(jid);
    try {
      return await _dbOpReturning<XmppStateStore, ChatTransportPreference>(
        (store) {
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
        },
      );
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
      (store) => store.write(
        key: _transportKeyFor(jid),
        value: transport.name,
      ),
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
      (store) => store.write(
        key: _viewFilterKeyFor(jid),
        value: filter.name,
      ),
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
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      createPaginatedStream<Chat, XmppDatabase>(
        watchFunction: (db) async =>
            db.watchChats(start: start, end: end).map(sortChats),
        getFunction: (db) async =>
            sortChats(await db.getChats(start: start, end: end)),
      );

  Stream<Chat?> chatStream(String jid) =>
      createSingleItemStream<Chat?, XmppDatabase>(
        watchFunction: (db) async => db.watchChat(jid),
      );

  Stream<List<String>> typingParticipantsStream(String jid) {
    final controller = _typingParticipantStreams.putIfAbsent(
      jid,
      () => StreamController<List<String>>.broadcast(
        onListen: () => _emitTypingParticipants(jid),
        onCancel: () => _disposeTypingParticipantsIfIdle(jid),
      ),
    );
    _typingParticipants.putIfAbsent(jid, () => <String>{});
    _typingParticipantExpiry.putIfAbsent(jid, () => <String, Timer>{});
    return controller.stream;
  }

  void clearTypingParticipants(String jid) {
    final participants = _typingParticipants[jid];
    if (participants != null) {
      participants.clear();
    }
    final timers = _typingParticipantExpiry.remove(jid);
    timers?.values.forEach((timer) => timer.cancel());
    _emitTypingParticipants(jid);
  }

  void _trackTypingParticipant({
    required String chatJid,
    required String senderJid,
    required mox.ChatState state,
  }) {
    final myBare = _myJid?.toBare().toString();
    final senderBare = _safeBareJid(senderJid);
    if (senderBare != null && senderBare == myBare) {
      return;
    }
    final participants = _typingParticipants.putIfAbsent(
      chatJid,
      () => <String>{},
    );
    final timers = _typingParticipantExpiry.putIfAbsent(
      chatJid,
      () => <String, Timer>{},
    );
    final normalizedSender = _safeParticipantId(senderJid);
    if (normalizedSender == null) return;
    switch (state) {
      case mox.ChatState.composing:
        participants.add(normalizedSender);
        timers.remove(normalizedSender)?.cancel();
        timers[normalizedSender] = Timer(
          _typingParticipantLinger,
          () => _expireTypingParticipant(chatJid, normalizedSender),
        );
      default:
        final removed = participants.remove(normalizedSender);
        timers.remove(normalizedSender)?.cancel();
        if (!removed) return;
    }
    _emitTypingParticipants(chatJid);
  }

  void _expireTypingParticipant(String chatJid, String senderJid) {
    final participants = _typingParticipants[chatJid];
    if (participants == null) return;
    final removed = participants.remove(senderJid);
    _typingParticipantExpiry[chatJid]?.remove(senderJid)?.cancel();
    if (!removed) return;
    _emitTypingParticipants(chatJid);
  }

  void _emitTypingParticipants(String jid) {
    final controller = _typingParticipantStreams[jid];
    if (controller == null || controller.isClosed) return;
    final participants = _typingParticipants[jid] ?? const <String>{};
    final ordered = participants.take(_typingParticipantMaxCount + 1).toList();
    controller.add(List<String>.unmodifiable(ordered));
  }

  void _disposeTypingParticipantsIfIdle(String jid) {
    final controller = _typingParticipantStreams[jid];
    if (controller == null) return;
    if (controller.hasListener) return;
    _typingParticipantStreams.remove(jid);
    controller.close();
    _typingParticipants.remove(jid);
    final timers = _typingParticipantExpiry.remove(jid);
    timers?.values.forEach((timer) => timer.cancel());
  }

  String? _safeBareJid(String? jid) {
    if (jid == null || jid.isEmpty) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } on Exception {
      return null;
    }
  }

  String? _safeParticipantId(String? jid) {
    if (jid == null || jid.isEmpty) return null;
    try {
      final parsed = mox.JID.fromString(jid);
      if (_isMucChatJid(parsed.toBare().toString()) &&
          parsed.resource.isNotEmpty) {
        return parsed.toString();
      }
      return parsed.toBare().toString();
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

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      mox.ChatStateManager(),
    ]);

  Future<void> sendChatState({
    required String jid,
    required mox.ChatState state,
  }) async {
    if (!_isFirstPartyJid(myJid: _myJid, jid: jid)) {
      _chatLog.fine('Skipping chat state for foreign domain: $jid');
      return;
    }
    final messageType = _chatStateMessageType(jid);
    await _connection.sendChatState(
      state: state,
      jid: jid,
      messageType: messageType,
    );
  }

  Future<void> sendTyping({
    required String jid,
    required bool typing,
  }) async {
    await sendChatState(
      state: typing ? mox.ChatState.composing : mox.ChatState.paused,
      jid: jid,
    );
  }

  Future<void> openChat(String jid) async {
    final closed = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.openChat(jid),
    );
    if (closed != null) {
      await sendChatState(jid: closed.jid, state: mox.ChatState.inactive);
    }
    await sendChatState(jid: jid, state: mox.ChatState.active);
  }

  Future<void> closeChat() async {
    await _dbOp<XmppDatabase>(
      (db) async {
        final closed = await db.closeChat();
        if (closed == null) return;
        await sendChatState(jid: closed.jid, state: mox.ChatState.inactive);
      },
    );
  }

  Future<void> toggleChatMuted({
    required String jid,
    required bool muted,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatMuted(jid: jid, muted: muted),
    );
  }

  Future<void> toggleChatShareSignature({
    required String jid,
    required bool enabled,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.setChatShareSignature(jid: jid, enabled: enabled),
    );
  }

  Future<void> toggleChatFavorited({
    required String jid,
    required bool favorited,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatFavorited(jid: jid, favorited: favorited),
    );
  }

  Future<void> toggleChatArchived({
    required String jid,
    required bool archived,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatArchived(jid: jid, archived: archived),
    );
  }

  Future<void> toggleChatHidden({
    required String jid,
    required bool hidden,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatHidden(jid: jid, hidden: hidden),
    );
  }

  Future<void> toggleChatSpam({
    required String jid,
    required bool spam,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatSpam(jid: jid, spam: spam),
    );
  }

  Future<List<Message>> loadCompleteChatHistory({
    required String jid,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    return _dbOpReturning<XmppDatabase, List<Message>>(
      (db) => db.getAllMessagesForChat(jid, filter: filter),
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

  Future<void> toggleAllChatsMarkerResponsive(
      {required bool responsive}) async {
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
    await _dbOp<XmppDatabase>(
      (db) => db.removeChat(jid),
    );
  }

  Future<void> deleteChatMessages({required String jid}) async {
    await _dbOp<XmppDatabase>(
      (db) => db.removeChatMessages(jid),
    );
  }

  Future<void> renameChatContact({
    required String jid,
    required String displayName,
  }) async {
    final trimmed = displayName.trim();
    MessageTransport? transport;
    String? rosterTitle;
    await _dbOp<XmppDatabase>(
      (db) async {
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
      },
    );
    rosterTitle ??= mox.JID.fromString(jid).local;
    if (transport?.isXmpp == true && rosterTitle != null) {
      final renamed = await _connection.addToRoster(jid, title: rosterTitle);
      if (!renamed) {
        throw XmppRosterException();
      }
    }
  }
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

  Future<void> sendMediatedInvite({
    required String roomJid,
    required String inviteeJid,
    String? reason,
  }) async {
    await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.message(
          to: roomJid,
          children: [
            mox.XMLNode.xmlns(
              tag: 'x',
              xmlns: _mucUserXmlns,
              children: [
                mox.XMLNode(
                  tag: 'invite',
                  attributes: {'to': inviteeJid},
                  children: reason?.isNotEmpty == true
                      ? [mox.XMLNode(tag: 'reason', text: reason)]
                      : const [],
                ),
              ],
            ),
          ],
        ),
        awaitable: false,
      ),
    );
  }

  Future<void> sendAdminIq({
    required String roomJid,
    required List<mox.XMLNode> items,
  }) async {
    await getAttributes().sendStanza(
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
  }
}
