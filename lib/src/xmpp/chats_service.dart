part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin ChatsService on XmppBase, BaseStreamService {
  static final _transportKeys = <String, RegisteredStateKey>{};

  RegisteredStateKey _transportKeyFor(String jid) => _transportKeys.putIfAbsent(
        jid,
        () => XmppStateStore.registerKey('chat_transport_$jid'),
      );

  MessageTransport _transportFrom(Object? raw) {
    if (raw is String) {
      return MessageTransport.values.firstWhere(
        (transport) => transport.name == raw,
        orElse: () => MessageTransport.xmpp,
      );
    }
    return MessageTransport.xmpp;
  }

  Future<MessageTransport> loadChatTransportPreference(String jid) async {
    try {
      return await _dbOpReturning<XmppStateStore, MessageTransport>(
        (store) => _transportFrom(store.read(key: _transportKeyFor(jid))),
      );
    } on XmppAbortedException {
      return MessageTransport.xmpp;
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

  Stream<MessageTransport> watchChatTransportPreference(String jid) async* {
    yield await loadChatTransportPreference(jid);
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
    await _connection.sendChatState(state: state, jid: jid);
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

  Future<void> toggleChatFavorited({
    required String jid,
    required bool favorited,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.markChatFavorited(jid: jid, favorited: favorited),
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
}

class MUCManager extends mox.MUCManager {
  Future<void> createGroupChat({
    required String jid,
    int? maxHistoryStanzas,
  }) async {
    await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.presence(
          to: jid,
          children: [
            mox.XMLNode.xmlns(
              tag: 'x',
              xmlns: mox.mucXmlns,
            ),
          ],
        ),
        awaitable: false,
      ),
    );
  }
}
