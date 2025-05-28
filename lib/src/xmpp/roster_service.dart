part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin RosterService on XmppBase {
  Stream<List<RosterItem>> rosterStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppDatabase, Stream<List<RosterItem>>>(
          (db) async => db
              .watchRoster(start: start, end: end)
              .startWith(await db.getRoster()),
        ),
      ));

  Stream<List<Invite>> invitesStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppDatabase, Stream<List<Invite>>>(
          (db) async => db
              .watchInvites(start: start, end: end)
              .startWith(await db.getInvites(start: start, end: end)),
        ),
      ));

  final _log = Logger('RosterService');

  @override
  EventManager<mox.XmppEvent> get _eventManager => super._eventManager
    ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
      if (event.resumed) return;
      _log.info('Fetching roster...');
      await requestRoster();
    })
    ..registerHandler<mox.SubscriptionRequestReceivedEvent>((event) async {
      final requester = event.from.toBare().toString().toLowerCase();
      _log.info('Subscription request received from $requester');
      await _dbOp<XmppDatabase>((db) async {
        final item = await db.getRosterItem(requester);
        if (item != null) {
          _log.info('Accepting subscription request from $requester...');
          try {
            await _acceptSubscriptionRequest(item);
          } on XmppRosterException catch (_) {}
          return;
        }
        await db.saveInvite(Invite(
          jid: requester,
          title: event.from.local,
        ));
      });
    });

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      mox.RosterManager(XmppRosterStateManager(owner: this)),
    ]);

  Future<void> requestRoster() async {
    if (await _connection.requestRoster() case final result?) {
      if (result.isType<mox.RosterRequestResult>()) {
        final items = result
            .get<mox.RosterRequestResult>()
            .items
            .map((e) => RosterItem.fromMox(e))
            .toList();
        await _dbOp<XmppDatabase>((db) async {
          await db.saveRosterItems(items);
        });
      }
    }
  }

  Future<void> addToRoster({required String jid, String? title}) async {
    _log.info('Requesting to add $jid to roster...');
    if (!await _connection.addToRoster(jid, title: title)) {
      throw XmppRosterException();
    }

    _log.info('Requesting subscription to $jid...');
    if (!await _connection.preApproveSubscription(jid)) {
      if (await _connection.requestSubscription(jid)) return;
      _log.severe('Failed to request subscription to $jid.');
      throw XmppRosterException();
    }
  }

  Future<void> removeFromRoster({required String jid}) async {
    _log.info('Requesting to remove $jid from roster...');
    switch (await _connection.removeFromRoster(jid)) {
      case mox.RosterRemovalResult.okay:
        return;
      case mox.RosterRemovalResult.itemNotFound:
        await _dbOp<XmppDatabase>((db) async {
          await db.removeRosterItem(jid);
        });
      case mox.RosterRemovalResult.error:
        throw XmppRosterException();
    }
  }

  //To simplify the end user experience, allow either bidirectional presence
  // subscription or none at all.
  Future<void> _acceptSubscriptionRequest(RosterItem item) async {
    final accepted = await _connection.acceptSubscriptionRequest(item.jid);
    final requested = await _connection.requestSubscription(item.jid);

    if (accepted && requested) return;

    _log.severe('Failed to accept subscription to ${item.jid}.', e);
    throw XmppRosterException();
  }

  Future<void> rejectSubscriptionRequest(String jid) async {
    _log.info('Requesting to reject subscription from $jid...');
    final rejected = await _connection.rejectSubscriptionRequest(jid);

    if (rejected) {
      await _dbOp<XmppDatabase>((db) async {
        await db.deleteInvite(jid);
      });
      return;
    }

    _log.severe('Failed to reject subscription from $jid.', e);
    throw XmppRosterException();
  }
}

class XmppRosterStateManager extends mox.BaseRosterStateManager {
  XmppRosterStateManager({required this.owner}) : super();

  final _log = Logger('XmppRosterStateManager');

  final XmppBase owner;

  static const keyPrefix = 'roster_state';
  final rosterVersionKey =
      XmppStateStore.registerKey('${keyPrefix}_last_version');

  @override
  Future<void> commitRoster(
    String? version,
    List<String> removed,
    List<mox.XmppRosterItem> modified,
    List<mox.XmppRosterItem> added,
  ) async {
    await owner._dbOp<XmppDatabase>((db) async {
      for (final jid in removed) {
        await db.removeRosterItem(jid);
      }

      for (final item in added) {
        await db.saveRosterItem(RosterItem.fromMox(item));
      }

      for (final item in modified) {
        await db.updateRosterItem(RosterItem.fromMox(item));
      }
    });

    if (version != null) {
      _log.info('Saving roster version: $version...');
      await owner._dbOp<XmppStateStore>((ss) async {
        await ss.write(key: rosterVersionKey, value: version);
      });
    }
  }

  @override
  Future<mox.RosterCacheLoadResult> loadRosterCache() async {
    String? version;
    await owner._dbOp<XmppStateStore>((ss) {
      version = ss.read(key: rosterVersionKey) as String?;
    });
    _log.info('Loaded roster version: $version.');

    final rosterItems =
        await owner._dbOpReturning<XmppDatabase, List<mox.XmppRosterItem>>(
      (db) async => (await db.getRoster())
          .map(
            (item) => mox.XmppRosterItem(
              jid: item.jid,
              name: item.title,
              subscription: item.subscription.name,
              ask: item.ask?.name,
              groups: item.groups,
            ),
          )
          .toList(),
    );
    return mox.RosterCacheLoadResult(version, rosterItems);
  }
}
