part of 'xmpp_service.dart';

mixin ChatsService on XmppBase {
  Stream<List<Chat>>? get chatsStream =>
      _database.value?.chatsAccessor.watchAll();
  Stream<List<Message>>? messageStream(String jid) =>
      _database.value?.messagesAccessor.watchChat(jid);
  Stream<Chat>? chatStream(String jid) =>
      _database.value?.chatsAccessor.watchOne(jid);

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
    await _dbOp<XmppDatabase>((db) async {
      if (await db.chatsAccessor.selectOne(jid) case final chat?) {
        final closed = (await db.chatsAccessor.closeOpen()).first;
        await sendChatState(jid: closed.jid, state: mox.ChatState.gone);
        await db.chatsAccessor.updateOne(chat.copyWith(
          open: true,
          unreadCount: 0,
          chatState: mox.ChatState.active,
        ));
        await sendChatState(jid: jid, state: mox.ChatState.active);
      }
    });
  }
}
