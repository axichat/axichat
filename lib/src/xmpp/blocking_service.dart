part of 'package:chat/src/xmpp/xmpp_service.dart';

mixin BlockingService on XmppBase {
  Stream<List<BlocklistData>>? get blocklistStream =>
      _database.value?.watchBlocklist();

  Future<void> requestBlocklist() async {
    if (_connection.getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      await _dbOp<XmppDatabase>((db) async {
        await db.deleteBlocklist();
        for (final blocked in await bm.getBlocklist()) {
          await db.insertBlocklistData(blocked);
        }
      });
    }
  }

  Future<void> block({required String jid}) async {
    if (_connection.getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      if (!await bm.block([jid])) throw XmppBlocklistException();
    }
  }

  Future<void> unblock({required String jid}) async {
    if (_connection.getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      if (!await bm.unblock([jid])) throw XmppBlocklistException();
    }
  }

  Future<void> unblockAll() async {
    if (_connection.getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      if (!await bm.unblockAll()) throw XmppBlocklistException();
    }
  }
}
