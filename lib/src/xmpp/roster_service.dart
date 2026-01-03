// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin RosterService on XmppBase, BaseStreamService, MessageService, MucService {
  Stream<List<RosterItem>> rosterStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      createPaginatedStream<RosterItem, XmppDatabase>(
        watchFunction: (db) async => db.watchRoster(start: start, end: end),
        getFunction: (db) => db.getRoster(),
      );

  Stream<List<Invite>> invitesStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      createPaginatedStream<Invite, XmppDatabase>(
        watchFunction: (db) async => db.watchInvites(start: start, end: end),
        getFunction: (db) => db.getInvites(start: start, end: end),
      );

  final _rosterLog = Logger('RosterService');

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (event.resumed) return;
        _rosterLog.info('Fetching roster...');
        unawaited(requestRoster());
      })
      ..registerHandler<mox.SubscriptionRequestReceivedEvent>((event) async {
        final requester = event.from.toBare().toString();
        _rosterLog.info('Subscription request received');
        await _dbOp<XmppDatabase>(
          (db) async {
            final item = await db.getRosterItem(requester);
            if (item != null) {
              _rosterLog.info('Accepting subscription request...');
              try {
                await _acceptSubscriptionRequest(item);
              } on XmppRosterException catch (error, stackTrace) {
                _rosterLog.severe(
                  'Failed to auto-accept subscription request',
                  error,
                  stackTrace,
                );
              }
              return;
            }
            await db.saveInvite(Invite(
              jid: requester,
              title: event.from.local,
            ));
          },
        );
      });
  }

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      mox.RosterManager(XmppRosterStateManager(owner: this)),
    ]);

  Future<void> requestRoster() async {
    final result = await _connection.requestRoster();
    if (result == null || !result.isType<mox.RosterRequestResult>()) {
      return;
    }

    final rosterResult = result.get<mox.RosterRequestResult>();
    final items = rosterResult.items.map(RosterItem.fromMox).toList();

    await _dbOp<XmppDatabase>(
      (db) => db.saveRosterItems(items),
      awaitDatabase: true,
    );
    if (this is AvatarService) {
      (this as AvatarService)
          .scheduleAvatarRefresh(items.map((item) => item.jid));
    }
    await _publishConversationIndexForRoster(items);

    final version = rosterResult.ver;
    if (version != null && version.isNotEmpty) {
      await _dbOp<XmppStateStore>(
        (ss) => ss.write(
          key: XmppRosterStateManager.versionStateKey,
          value: version,
        ),
        awaitDatabase: true,
      );
    }
  }

  Future<void> _publishConversationIndexForRoster(
    Iterable<RosterItem> items,
  ) async {
    final uniqueJids = <String>{};
    for (final item in items) {
      final jid = item.jid.trim();
      if (jid.isEmpty) continue;
      if (!uniqueJids.add(jid)) continue;
      await _ensureConversationIndexEntryForContact(jid);
    }
  }

  Future<void> addToRoster({required String jid, String? title}) async {
    _rosterLog.info('Requesting to add roster entry...');
    if (!await _connection.addToRoster(jid, title: title)) {
      throw XmppRosterException();
    }

    _rosterLog.info('Requesting roster subscription...');
    final preApproved = await _connection.preApproveSubscription(jid);
    if (!preApproved) {
      final requested = await _connection.requestSubscription(jid);
      if (!requested) {
        _rosterLog.severe('Failed to request roster subscription.');
        throw XmppRosterException();
      }
    }
    if (this is AvatarService) {
      (this as AvatarService).scheduleAvatarRefresh([jid]);
    }
    await _ensureConversationIndexEntryForContact(jid);
  }

  Future<void> _ensureConversationIndexEntryForContact(String jid) async {
    final normalized = jid.trim();
    if (normalized.isEmpty) return;
    final createdAt = DateTime.timestamp();
    final existing = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(normalized),
    );
    if (existing == null) {
      await _dbOp<XmppDatabase>(
        (db) => db.createChat(
          Chat.fromJid(normalized).copyWith(
            lastChangeTimestamp: createdAt,
          ),
        ),
      );
    }
    await _upsertConversationIndexForPeer(
      peerJid: normalized,
      lastTimestamp: existing?.lastChangeTimestamp ?? createdAt,
      lastId: null,
    );
  }

  Future<void> removeFromRoster({required String jid}) async {
    _rosterLog.info('Requesting to remove roster entry...');
    switch (await _connection.removeFromRoster(jid)) {
      case mox.RosterRemovalResult.okay:
        return;
      case mox.RosterRemovalResult.itemNotFound:
        await _dbOp<XmppDatabase>(
          (db) => db.removeRosterItem(jid),
        );
      case mox.RosterRemovalResult.error:
        throw XmppRosterException();
    }
  }

  //To simplify the end user experience, allow either bidirectional presence
  // subscription or none at all.
  Future<void> _acceptSubscriptionRequest(RosterItem item) async {
    try {
      final accepted = await _connection.acceptSubscriptionRequest(item.jid);
      if (!accepted) {
        throw XmppRosterException();
      }

      await _dbOp<XmppDatabase>((db) async {
        final subscription = switch (item.subscription) {
          Subscription.both => Subscription.both,
          Subscription.to => Subscription.both,
          Subscription.from => Subscription.from,
          Subscription.none => Subscription.from,
        };

        await db.updateRosterSubscription(
          jid: item.jid,
          subscription: subscription,
        );
        await db.updateRosterAsk(jid: item.jid, ask: null);
        await db.deleteInvite(item.jid);
      });

      final requested = await _connection.requestSubscription(item.jid);
      if (!requested) {
        _rosterLog.warning(
          'Subscription request failed; roster remains ${item.subscription.name}.',
        );
        return;
      }

      await _dbOp<XmppDatabase>(
        (db) => db.updateRosterAsk(jid: item.jid, ask: Ask.subscribe),
      );
    } catch (error, stackTrace) {
      _rosterLog.severe(
        'Failed to accept subscription request.',
        error,
        stackTrace,
      );
      throw XmppRosterException();
    }
  }

  Future<void> rejectSubscriptionRequest(String jid) async {
    _rosterLog.info('Requesting to reject subscription...');
    try {
      final rejected = await _connection.rejectSubscriptionRequest(jid);

      if (rejected) {
        await _dbOp<XmppDatabase>(
          (db) => db.deleteInvite(jid),
        );
        return;
      }

      throw XmppRosterException();
    } catch (error, stackTrace) {
      _rosterLog.severe(
        'Failed to reject subscription.',
        error,
        stackTrace,
      );
      throw XmppRosterException();
    }
  }
}

class XmppRosterStateManager extends mox.BaseRosterStateManager {
  XmppRosterStateManager({required this.owner}) : super();

  final _log = Logger('XmppRosterStateManager');

  final XmppBase owner;

  static const keyPrefix = 'roster_state';
  static final versionStateKey =
      XmppStateStore.registerKey('${keyPrefix}_last_version');

  @override
  Future<void> commitRoster(
    String? version,
    List<String> removed,
    List<mox.XmppRosterItem> modified,
    List<mox.XmppRosterItem> added,
  ) async {
    final updatedJids = <String>{};
    await owner._dbOp<XmppDatabase>(
      (db) async {
        for (final jid in removed) {
          await db.removeRosterItem(jid);
        }

        for (final item in added) {
          await db.saveRosterItem(RosterItem.fromMox(item));
          updatedJids.add(item.jid);
        }

        for (final item in modified) {
          await db.updateRosterItem(RosterItem.fromMox(item));
          updatedJids.add(item.jid);
        }
      },
      awaitDatabase: true,
    );
    if (owner is AvatarService && updatedJids.isNotEmpty) {
      (owner as AvatarService).scheduleAvatarRefresh(updatedJids);
    }

    if (version != null) {
      _log.info('Saving roster version: $version...');
      await owner._dbOp<XmppStateStore>(
        (ss) => ss.write(key: versionStateKey, value: version),
        awaitDatabase: true,
      );
    }
  }

  @override
  Future<mox.RosterCacheLoadResult> loadRosterCache() async {
    String? version;
    version = await owner._dbOpReturning<XmppStateStore, String?>(
      (ss) => ss.read(key: versionStateKey) as String?,
    );
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
