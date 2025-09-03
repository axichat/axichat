part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin ChatsService on XmppBase, BaseStreamService {
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
    final db = await database;
    final closed = await db.safeGetItem<Chat>(
      getter: () => db.openChat(jid),
      itemName: 'chat to close',
    );
    if (closed != null) {
      await sendChatState(jid: closed.jid, state: mox.ChatState.inactive);
    }
    await sendChatState(jid: jid, state: mox.ChatState.active);
  }

  Future<void> closeChat() async {
    final db = await database;
    await db.executeOperation(
      operation: () async {
        final closed = await db.closeChat();
        if (closed == null) return;
        await sendChatState(jid: closed.jid, state: mox.ChatState.inactive);
      },
      operationName: 'close chat',
    );
  }

  Future<void> toggleChatMuted({
    required String jid,
    required bool muted,
  }) async {
    final db = await database;
    await db.executeOperation(
      operation: () => db.markChatMuted(jid: jid, muted: muted),
      operationName: 'toggle chat muted',
    );
  }

  Future<void> toggleChatFavorited({
    required String jid,
    required bool favorited,
  }) async {
    final db = await database;
    await db.executeOperation(
      operation: () => db.markChatFavorited(jid: jid, favorited: favorited),
      operationName: 'toggle chat favorited',
    );
  }

  Future<void> toggleChatMarkerResponsive({
    required String jid,
    required bool responsive,
  }) async {
    final db = await database;
    await db.executeOperation(
      operation: () =>
          db.markChatMarkerResponsive(jid: jid, responsive: responsive),
      operationName: 'toggle chat marker responsive',
    );
  }

  Future<void> toggleAllChatsMarkerResponsive(
      {required bool responsive}) async {
    final db = await database;
    await db.executeOperation(
      operation: () => db.markChatsMarkerResponsive(responsive: responsive),
      operationName: 'toggle all chats marker responsive',
    );
  }

  Future<void> setChatEncryption({
    required String jid,
    required EncryptionProtocol protocol,
  }) async {
    final db = await database;
    await db.executeOperation(
      operation: () =>
          db.updateChatEncryption(chatJid: jid, protocol: protocol),
      operationName: 'set chat encryption',
    );
  }

  Future<void> setChatAlert({
    required String jid,
    required String alert,
  }) async {
    final db = await database;
    await db.executeOperation(
      operation: () => db.updateChatAlert(chatJid: jid, alert: alert),
      operationName: 'set chat alert',
    );
  }

  Future<void> clearChatAlert({required String jid}) async {
    final db = await database;
    await db.executeOperation(
      operation: () => db.updateChatAlert(chatJid: jid, alert: null),
      operationName: 'clear chat alert',
    );
  }

  Future<void> deleteChat({required String jid}) async {
    final db = await database;
    await db.executeOperation(
      operation: () => db.removeChat(jid),
      operationName: 'delete chat',
    );
  }

  Future<void> deleteChatMessages({required String jid}) async {
    final db = await database;
    await db.executeOperation(
      operation: () => db.removeChatMessages(jid),
      operationName: 'delete chat messages',
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
