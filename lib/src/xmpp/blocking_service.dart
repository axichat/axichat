part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin BlockingService on XmppBase {
  Stream<List<BlocklistData>> blocklistStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppDatabase, Stream<List<BlocklistData>>>(
          (db) async => db
              .watchBlocklist(start: start, end: end)
              .startWith(await db.getBlocklist(start: start, end: end)),
        ),
      ));

  final _log = Logger('BlockingService');

  @override
  EventManager<mox.XmppEvent> get _eventManager => super._eventManager
    ..registerHandler<mox.StreamNegotiationsDoneEvent>((_) async {
      _log.info('Fetching blocklist...');
      await requestBlocklist();
    })
    ..registerHandler<mox.BlocklistBlockPushEvent>((event) async {
      await _dbOp<XmppDatabase>((db) async {
        await db.blockJids(event.items);
      });
    })
    ..registerHandler<mox.BlocklistUnblockPushEvent>((event) async {
      await _dbOp<XmppDatabase>((db) async {
        await db.unblockJids(event.items);
      });
    })
    ..registerHandler<mox.BlocklistUnblockAllPushEvent>((_) async {
      await _dbOp<XmppDatabase>((db) async {
        await db.deleteBlocklist();
      });
    });

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      mox.BlockingManager(),
    ]);

  Future<void> requestBlocklist() async {
    if (await _connection.requestBlocklist() case final blocked?) {
      await owner._dbOp<XmppDatabase>((db) async {
        db.replaceBlocklist(blocked);
      });
    }
  }

  Future<void> block({required String jid}) async {
    _log.info('Requesting to block $jid...');
    await _connection.block(jid);
  }

  Future<void> unblock({required String jid}) async {
    _log.info('Requesting to unblock $jid...');
    await _connection.unblock(jid);
  }

  Future<void> unblockAll() async {
    _log.info('Requesting to unblock all...');
    await _connection.unblockAll();
  }
}
