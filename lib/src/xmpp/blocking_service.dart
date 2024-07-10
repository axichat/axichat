part of 'package:chat/src/xmpp/xmpp_service.dart';

mixin BlockingService on XmppBase {
  Stream<List<BlocklistData>>? get blocklistStream =>
      _database.value?.blocklistAccessor.watchAll();

  final _log = Logger('BlockingService');

  Future<void> requestBlocklist() async {
    if (_connection.getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      await _dbOp<XmppDatabase>((db) async {
        await db.blocklistAccessor.deleteAll();
        for (final blocked in await bm.getBlocklist()) {
          await db.blocklistAccessor.insertOne(BlocklistData(jid: blocked));
        }
      });
    }
  }

  Future<void> block({required String jid}) async {
    if (_connection.getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      _log.info('Requesting to block $jid...');
      if (!await bm.block([jid])) throw XmppBlocklistException();
    }
  }

  Future<void> unblock({required String jid}) async {
    if (_connection.getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      _log.info('Requesting to unblock $jid...');
      if (!await bm.unblock([jid])) throw XmppBlocklistException();
    }
  }

  Future<void> unblockAll() async {
    if (_connection.getManager<mox.BlockingManager>() case final bm?) {
      if (!await bm.isSupported()) throw XmppBlockUnsupportedException();
      _log.info('Requesting to unblock all...');
      if (!await bm.unblockAll()) throw XmppBlocklistException();
    }
  }
}
