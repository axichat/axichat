part of 'package:chat/src/xmpp/xmpp_service.dart';

mixin RosterService on XmppBase {
  Stream<List<RosterItem>>? get rosterStream => _database.value?.watchRoster();
  Stream<List<Invite>>? get invitesStream => _database.value?.watchInvites();

  Future<void> addToRoster({required String jid, String? title}) async {
    if (_connection.getRosterManager() case final rm?) {
      Logger('XmppService').info('Adding $jid to roster...');
      if (!await rm.addToRoster(jid, title ?? mox.JID.fromString(jid).local)) {
        throw XmppRosterException();
      }
    }

    if (_connection.getPresenceManager() case final pm?) {
      Logger('XmppService').info('Requesting subscription to $jid...');
      final to = mox.JID.fromString(jid);
      if (!await pm.preApproveSubscription(to)) {
        await pm.requestSubscription(to);
      }
    }
  }

  Future<void> removeFromRoster({required String jid}) async {
    if (_connection.getRosterManager() case final rm?) {
      if (await rm.removeFromRoster(jid) != mox.RosterRemovalResult.okay) {
        throw XmppRosterException();
      }
    }
  }

  Future<void> _acceptSubscriptionRequest(RosterItem item) async {
    _connection.getPresenceManager()
      ?..acceptSubscriptionRequest(mox.JID.fromString(item.jid))
      ..requestSubscription(mox.JID.fromString(item.jid));
    _database.value
        ?.updateRosterItem(item.copyWith(subscription: Subscription.both));
  }

  Future<void> rejectSubscriptionRequest(Invite item) async {
    try {
      await _connection
          .getPresenceManager()
          ?.rejectSubscriptionRequest(mox.JID.fromString(item.jid));
    } catch (e) {
      throw XmppRosterException();
    }
    _database.value?.deleteInvite(item.jid);
  }
}

class XmppRosterStateManager extends mox.BaseRosterStateManager {
  XmppRosterStateManager({required this.owner}) : super();

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
        await db.deleteRosterItem(jid);
        await db.deleteChat(jid);
      }

      final myJid = owner.user!.jid.toString();
      for (final item in added) {
        await db.insertChat(Chat(
          jid: item.jid,
          myJid: myJid,
          myNickname: owner.user!.username,
          title: item.name ?? mox.JID.fromString(item.jid).local,
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
        ));
        await db.insertOrUpdateRosterItem(RosterItem.fromMox(
          myJid: myJid,
          item: item,
        ));
        await db.deleteInvite(item.jid);
      }

      for (final item in modified) {
        await db.updateRosterItem(RosterItem.fromMox(
          myJid: myJid,
          item: item,
        ));
      }
    });

    if (version != null) {
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

    final rosterItems = <mox.XmppRosterItem>[];
    await owner._dbOp<XmppDatabase>((db) async {
      for (final item in (await db.selectRoster())) {
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
