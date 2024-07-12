part of 'xmpp_service.dart';

mixin ChatsService on XmppBase {
  Stream<List<Chat>>? get chatsStream =>
      _database.value?.chatsAccessor.watchAll();
  Stream<List<Message>>? chatStream(String jid) =>
      _database.value?.messagesAccessor.watchChat(jid);

  Future<void> openChat(String jid) async {
    await _dbOp<XmppDatabase>((db) async {
      if (await db.chatsAccessor.selectOne(jid) case final chat?) {
        await db.chatsAccessor.closeOpen();
        await db.chatsAccessor
            .updateOne(chat.copyWith(open: true, unreadCount: 0));
      }
    });
  }
}
