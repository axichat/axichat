part of 'package:chat/src/xmpp/xmpp_service.dart';

mixin RosterService on XmppBase {
  Stream<List<RosterItem>>? get rosterStream =>
      _database.value?.rosterAccessor.watchAll();
  Stream<List<Invite>>? get invitesStream =>
      _database.value?.invitesAccessor.watchAll();

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
    _database.value?.rosterAccessor
        .updateOne(item.copyWith(subscription: Subscription.both));
  }

  Future<void> rejectSubscriptionRequest(Invite item) async {
    final jid = mox.JID.fromString(item.jid);
    try {
      _log.info('Requesting to reject subscription from $jid...');
      await _connection.getPresenceManager()?.rejectSubscriptionRequest(jid);
    } on Exception catch (e) {
      _log.severe('Failed to reject subscription from $jid.', e);
      throw XmppRosterException();
    }
    _database.value?.invitesAccessor.deleteOne(item.jid);
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
        _log.info('Removing $jid from roster...');
        await db.rosterAccessor.deleteOne(jid);
        await db.chatsAccessor.deleteOne(jid);
      }

      final myJid = owner.user!.jid.toString();
      for (final item in added) {
        _log.info('Adding ${item.jid} to roster...');
        await db.chatsAccessor.insertOne(Chat(
          jid: item.jid,
          myJid: myJid,
          myNickname: owner.user!.username,
          title: item.name ?? mox.JID.fromString(item.jid).local,
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
        ));
        await db.rosterAccessor.insertOrUpdateOne(RosterItem.fromMox(
          myJid: myJid,
          item: item,
        ));
        await db.invitesAccessor.deleteOne(item.jid);
      }

      for (final item in modified) {
        _log.info('Updating ${item.jid} in roster...');
        await db.rosterAccessor.updateOne(RosterItem.fromMox(
          myJid: myJid,
          item: item,
        ));
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

    _log.info('Loading roster from database...');
    final rosterItems = <mox.XmppRosterItem>[];
    await owner._dbOp<XmppDatabase>((db) async {
      for (final item in (await db.rosterAccessor.selectAll())) {
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
