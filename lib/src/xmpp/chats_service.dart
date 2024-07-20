part of 'xmpp_service.dart';

mixin ChatsService on XmppBase {
  Stream<List<Chat>> chatsStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(
          _dbOpReturning<XmppDatabase, Stream<List<Chat>>>((db) async {
        return db.watchChats(start: start, end: end);
      }));
  Stream<List<Message>> messageStream(
    String jid, {
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(
          _dbOpReturning<XmppDatabase, Stream<List<Message>>>((db) async {
        return db.watchChatMessages(jid, start: start, end: end);
      }));
  Stream<Chat> chatStream(String jid) => StreamCompleter.fromFuture(
          _dbOpReturning<XmppDatabase, Stream<Chat>>((db) async {
        return db.watchChat(jid);
      }));

  Future<void> sendTyping({
    required String jid,
    required bool typing,
  }) async {
    await _connection.getManager<mox.ChatStateManager>()?.sendChatState(
        typing ? mox.ChatState.composing : mox.ChatState.paused, jid);
  }

  Future<void> sendChatState({
    required String jid,
    required mox.ChatState state,
  }) async {
    await _connection
        .getManager<mox.ChatStateManager>()
        ?.sendChatState(state, jid);
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
}
