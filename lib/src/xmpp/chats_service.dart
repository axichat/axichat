part of 'package:axichat/src/xmpp/xmpp_service.dart';

List<Chat> sortChats(List<Chat> chats) => chats.toList()
  ..sort((a, b) {
    if (a.favourited == b.favourited) return 0;
    if (a.favourited) return 1;
    return -1;
  })
  ..sort(
    (a, b) => b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp),
  );

mixin ChatsService on XmppBase {
  Stream<List<Chat>> chatsStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppDatabase, Stream<List<Chat>>>(
          (db) async => db
              .watchChats(start: start, end: end)
              .startWith(sortChats(await db.getChats(start: start, end: end))),
        ),
      ));

  Stream<Chat?> chatStream(String jid) =>
      StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppDatabase, Stream<Chat?>>((db) => db.watchChat(jid)),
      ));

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
    final closed = await _dbOpReturning<XmppDatabase, Chat?>((db) async {
      return await db.openChat(jid);
    });
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

  Future<void> toggleChatFavourited({
    required String jid,
    required bool favourited,
  }) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.markChatFavourited(jid: jid, favourited: favourited);
    });
  }

  Future<void> toggleChatMuted({
    required String jid,
    required bool muted,
  }) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.markChatMuted(jid: jid, muted: muted);
    });
  }

  Future<void> setChatEncryption({
    required String jid,
    required EncryptionProtocol protocol,
  }) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.updateChatEncryption(chatJid: jid, protocol: protocol);
    });
  }

  Future<void> deleteChat({required String jid}) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.removeChat(jid);
    });
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
