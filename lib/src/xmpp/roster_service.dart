part of 'package:chat/src/xmpp/xmpp_service.dart';

mixin RosterService on XmppBase {
  Stream<List<RosterItem>> rosterStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(
          _dbOpReturning<XmppDatabase, Stream<List<RosterItem>>>((db) async {
        return db.watchRoster(start: start, end: end);
      }));
  Stream<List<Invite>> invitesStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(
          _dbOpReturning<XmppDatabase, Stream<List<Invite>>>((db) async {
        return db.watchInvites(start: start, end: end);
      }));

  final _log = Logger('RosterService');

  Future<void> addToRoster({required String jid, String? title}) async {
    if (_connection.getRosterManager() case final rm?) {
      _log.info('Requesting to add $jid to roster...');
      if (!await rm.addToRoster(jid, title ?? mox.JID.fromString(jid).local)) {
        throw XmppRosterException();
      }
    }

    if (_connection.getPresenceManager() case final pm?) {
      _log.info('Requesting to subscribe to $jid...');
      final to = mox.JID.fromString(jid);
      if (!await pm.preApproveSubscription(to)) {
        try {
          await pm.requestSubscription(to);
        } on Exception catch (e, s) {
          _log.severe('Failed to request subscription to $jid.', e, s);
          throw XmppRosterException();
        }
      }
    }
  }

  Future<void> removeFromRoster({required String jid}) async {
    if (_connection.getRosterManager() case final rm?) {
      _log.info('Requesting to remove $jid from roster...');
      if (await rm.removeFromRoster(jid) != mox.RosterRemovalResult.okay) {
        throw XmppRosterException();
      }
    }
  }

  Future<void> _acceptSubscriptionRequest(RosterItem item) async {
    final jid = mox.JID.fromString(item.jid);
    try {
      _connection.getPresenceManager()
        ?..acceptSubscriptionRequest(jid)
        ..requestSubscription(jid);
    } on Exception catch (e) {
      _log.severe('Failed to accept subscription from $jid.', e);
      throw XmppRosterException();
    }
    await _dbOp<XmppDatabase>((db) async {
      await db.markSubscriptionBoth(item.jid);
    });
  }

  Future<void> rejectSubscriptionRequest(String jid) async {
    final from = mox.JID.fromString(jid);
    try {
      _log.info('Requesting to reject subscription from $from...');
      await _connection.getPresenceManager()?.rejectSubscriptionRequest(from);
    } on Exception catch (e) {
      _log.severe('Failed to reject subscription from $from.', e);
      throw XmppRosterException();
    }
    await _dbOp<XmppDatabase>((db) async {
      await db.deleteInvite(jid);
    });
  }
}

class XmppRosterStateManager extends mox.BaseRosterStateManager {
  XmppRosterStateManager({required this.owner}) : super();

  final _log = Logger('XmppRosterStateManager');

  final XmppService owner;

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
        await db.saveRosterItem(RosterItem.fromMox(item: item));
      }

      for (final item in modified) {
        await db.updateRosterItem(RosterItem.fromMox(item: item));
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

    final rosterItems = <mox.XmppRosterItem>[];
    await owner._dbOp<XmppDatabase>((db) async {
      for (final item in (await db.getRoster())) {
        rosterItems.add(mox.XmppRosterItem(
          jid: item.jid,
          name: item.title,
          subscription: item.subscription.name,
          ask: item.ask?.name,
          groups: item.groups,
        ));
      }
    });
    return mox.RosterCacheLoadResult(version, rosterItems);
  }
}
