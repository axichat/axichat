part of 'package:axichat/src/xmpp/xmpp_service.dart';

final _presenceStatusesKey = XmppStateStore.registerKey('presence_statuses');
final _directedPresenceTargetsKey =
    XmppStateStore.registerKey('presence_directed_targets');

mixin PresenceService on XmppBase, BaseStreamService {
  final presenceStorageKey = XmppStateStore.registerKey('my_presence');
  final statusStorageKey = XmppStateStore.registerKey('my_status');
  final Map<String, Map<String, String>> _presenceStatuses = {};

  Presence get presence {
    if (_dbOpReturning<XmppStateStore, Presence?>(
            (db) => db.read(key: presenceStorageKey) as Presence?)
        case Presence presence) {
      return presence;
    }

    return Presence.chat;
  }

  String? get status {
    if (_dbOpReturning<XmppStateStore, String?>(
            (db) => db.read(key: statusStorageKey) as String?)
        case String status) {
      return status;
    }

    return null;
  }

  Stream<Presence?> get presenceStream =>
      createSingleItemStream<Presence?, XmppStateStore>(
        watchFunction: (ss) async =>
            ss.watch<Presence?>(key: presenceStorageKey) ??
            Stream.value(Presence.unknown),
      );

  Stream<String?> get statusStream =>
      createSingleItemStream<String?, XmppStateStore>(
        watchFunction: (ss) async =>
            ss.watch<String?>(key: statusStorageKey) ?? Stream.value(null),
      );

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      XmppPresenceManager(owner: this),
    ]);

  Future<void> sendPresence({
    required Presence? presence,
    required String? status,
    String? to,
    bool trackDirected = false,
  }) async {
    await _connection.sendPresence(
      presence: presence,
      status: status,
      to: to,
      trackDirected: trackDirected,
    );
  }

  Future<void> receivePresence(
    String jid,
    Presence presence, {
    String? status,
    Map<String, String>? statuses,
  }) async {
    final resolvedStatus =
        status ?? _preferredStatus(statuses, fallback: this.status);

    if (statuses != null) {
      await _storePresenceStatuses(jid, statuses);
    }

    if (jid == myJid) {
      await _dbOp<XmppStateStore>(
        (ss) => ss.writeAll(
          data: {
            presenceStorageKey: presence,
            statusStorageKey: resolvedStatus,
          },
        ),
        awaitDatabase: true,
      );
      return;
    }

    await _dbOp<XmppDatabase>(
      (db) => db.updatePresence(
        jid: jid,
        presence: presence,
        status: resolvedStatus,
      ),
    );
  }

  String? _preferredStatus(
    Map<String, String>? statuses, {
    String? fallback,
  }) {
    if (statuses == null || statuses.isEmpty) return fallback;
    final normalized = <String, String>{};
    for (final entry in statuses.entries) {
      final trimmed = entry.value.trim();
      if (trimmed.isEmpty) continue;
      normalized[entry.key] = trimmed;
    }

    if (normalized.isEmpty) return fallback;

    final english = normalized['en'];
    if (english != null && english.isNotEmpty) return english;

    final unlabeled = normalized[''];
    if (unlabeled != null && unlabeled.isNotEmpty) return unlabeled;

    return normalized.values.first;
  }

  Future<void> _storePresenceStatuses(
    String jid,
    Map<String, String> statuses,
  ) async {
    final sanitized = <String, String>{
      for (final entry in statuses.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    };

    if (sanitized.isEmpty) {
      _presenceStatuses.remove(jid);
    } else {
      _presenceStatuses[jid] = Map.unmodifiable(sanitized);
    }

    await _dbOp<XmppStateStore>(
      (ss) async {
        final current =
            (ss.read(key: _presenceStatusesKey) as Map<Object?, Object?>?)?.map(
                  (key, value) => MapEntry(
                    key as String,
                    (value as Map).cast<String, String>(),
                  ),
                ) ??
                <String, Map<String, String>>{};

        if (sanitized.isEmpty) {
          current.remove(jid);
        } else {
          current[jid] = sanitized;
        }

        await ss.write(key: _presenceStatusesKey, value: current);
      },
      awaitDatabase: true,
    );
  }

  Future<void> _markSubscriptionApproved(String jid) async {
    await _dbOp<XmppDatabase>((db) async {
      final item = await db.getRosterItem(jid);
      if (item == null) {
        await db.deleteInvite(jid);
        return;
      }

      final updatedSubscription = switch (item.subscription) {
        Subscription.both => Subscription.both,
        Subscription.to => Subscription.to,
        Subscription.from => Subscription.both,
        Subscription.none => Subscription.to,
      };

      await db.updateRosterSubscription(
        jid: jid,
        subscription: updatedSubscription,
      );
      await db.updateRosterAsk(jid: jid, ask: null);
      await db.deleteInvite(jid);
    });
  }

  Future<void> _markSubscriptionRevoked(String jid) async {
    await _dbOp<XmppDatabase>((db) async {
      final item = await db.getRosterItem(jid);
      if (item == null) return;

      final updatedSubscription = switch (item.subscription) {
        Subscription.both => Subscription.to,
        Subscription.from => Subscription.none,
        Subscription.to => Subscription.to,
        Subscription.none => Subscription.none,
      };

      await db.updateRosterSubscription(
        jid: jid,
        subscription: updatedSubscription,
      );
      await db.updateRosterAsk(jid: jid, ask: null);
      await db.deleteInvite(jid);
    });
  }

  Future<void> _markSubscriptionAcknowledged(String jid) async {
    await _dbOp<XmppDatabase>((db) async {
      final item = await db.getRosterItem(jid);
      if (item == null) return;

      final updatedSubscription = switch (item.subscription) {
        Subscription.both => Subscription.from,
        Subscription.to => Subscription.none,
        Subscription.from => Subscription.from,
        Subscription.none => Subscription.none,
      };

      await db.updateRosterSubscription(
        jid: jid,
        subscription: updatedSubscription,
      );
      await db.updateRosterAsk(jid: jid, ask: null);
      await db.deleteInvite(jid);
    });
  }
}

class XmppPresenceManager extends mox.PresenceManager {
  XmppPresenceManager({required this.owner}) : super();

  final _log = Logger('XmppPresenceManager');

  final PresenceService owner;

  final _attachments = <mox.PresencePreSendCallback>[];
  final _directedRecipients = <String>{};
  var _directedLoaded = false;

  @override
  void registerPreSendCallback(mox.PresencePreSendCallback callback) {
    _attachments.add(callback);
    super.registerPreSendCallback(callback);
  }

  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: 'presence',
          priority: mox.PresenceManager.presenceHandlerPriority,
          callback: (stanza, state) async {
            if (stanza.from == null) {
              state.done = true;
              return state;
            }

            if (_handleMucPresence(stanza)) {
              state.done = true;
              return state;
            }

            final from = mox.JID.fromString(stanza.from!).toBare();
            final stanzaType = stanza.type;
            _log.info('Incoming presence from: ${from.toString()} '
                'type: ${stanzaType ?? 'available'}');

            switch (stanzaType) {
              case 'probe':
                await _respondToProbe(from);
                state.done = true;
                return state;
              case 'unsubscribe':
                await _ensureDirectedRecipientsLoaded();
                await _removeDirectedRecipient(from);
                await _acknowledgeUnsubscribe(from);
                await owner._markSubscriptionRevoked(from.toString());
                state.done = true;
                return state;
              case 'unsubscribed':
                await _ensureDirectedRecipientsLoaded();
                await _removeDirectedRecipient(from);
                await owner._markSubscriptionAcknowledged(from.toString());
                state.done = true;
                return state;
              case 'subscribe':
                getAttributes().sendEvent(
                  mox.SubscriptionRequestReceivedEvent(from: from),
                );
                state.done = true;
                return state;
              case 'subscribed':
                await owner._markSubscriptionApproved(from.toString());
                state.done = true;
                return state;
            }

            final presence = stanzaType == Presence.unavailable.name
                ? Presence.unavailable
                : Presence.fromString(
                    stanza.children
                        .firstWhere(
                          (node) => node.tag == 'show',
                          orElse: () => mox.XMLNode(
                              tag: 'show', text: Presence.chat.name),
                        )
                        .text,
                  );

            final statuses = _extractStatuses(stanza);
            await owner.receivePresence(
              from.toString(),
              presence,
              statuses: statuses.isEmpty ? null : statuses,
            );

            state.done = true;
            return state;
          },
        ),
      ];

  @override
  Future<void> sendPresence({
    int? priority,
    String? show,
    String? status,
    mox.JID? to,
    bool trackDirected = false,
  }) async {
    // Convert show string to Presence enum for backward compatibility
    final presence = show != null ? Presence.fromString(show) : null;

    await _ensureDirectedRecipientsLoaded();

    final toBare = to?.toBare().toString();
    if (trackDirected && toBare != null && _directedRecipients.add(toBare)) {
      await _persistDirectedRecipients();
    }

    Future<void> sendToTarget(mox.JID? jid) async {
      final stanza = mox.Stanza.presence(
        to: jid?.toString(),
        type: presence != null && presence.isUnavailable
            ? Presence.unavailable.name
            : null,
        children: [
          if (presence != null && !presence.isUnavailable)
            mox.XMLNode(tag: 'show', text: presence.name),
          if (status != null) mox.XMLNode(tag: 'status', text: status),
          if (priority != null)
            mox.XMLNode(tag: 'priority', text: priority.toString()),
          for (final attachment in _attachments) ...await attachment(),
        ],
      );

      _log.info(
        'Sending presence ${presence?.name ?? 'default'} '
        'status=$status to ${jid?.toString() ?? 'broadcast'}',
      );

      try {
        await getAttributes().sendStanza(
          mox.StanzaDetails(
            stanza,
            addId: false,
            awaitable: false,
          ),
        );
      } on Exception catch (error, stackTrace) {
        _log.severe('Failed to send presence stanza', error, stackTrace);
        throw XmppPresenceException();
      }
    }

    if (to == null) {
      await sendToTarget(null);
      for (final recipient in _directedRecipients) {
        await sendToTarget(mox.JID.fromString(recipient));
      }
    } else {
      await sendToTarget(to);
    }

    if (to == null) {
      _log.info('Persisting current presence: ${presence?.name}');
      await owner._dbOp<XmppStateStore>((ss) async {
        await ss.writeAll(data: {
          owner.presenceStorageKey: presence,
          owner.statusStorageKey: status,
        });
      });
    }
  }

  @override
  Future<void> sendInitialPresence({int? priority}) async {
    Presence? presence;
    String? status;
    await owner._dbOp<XmppStateStore>((ss) {
      presence = ss.read(key: owner.presenceStorageKey) as Presence?;
      status = ss.read(key: owner.statusStorageKey) as String?;
    });
    await sendPresence(show: presence?.name, status: status);
  }

  bool _handleMucPresence(mox.Stanza stanza) {
    final fromAttr = stanza.from;
    if (fromAttr == null) return false;
    final jid = mox.JID.fromString(fromAttr);
    if (jid.resource.isEmpty) return false;
    final mucUser = _findChildWithXmlns(
      stanza.children,
      xmlns: _mucUserXmlns,
      tag: 'x',
    );
    if (mucUser == null) return false;
    final occupantId = _extractMucOccupantId(stanza);
    if (occupantId == null || occupantId.isEmpty) return false;
    final item = _mucItemNode(mucUser);
    final affiliation = OccupantAffiliation.fromString(
      item?.attributes['affiliation'] as String?,
    );
    final role = OccupantRole.fromString(item?.attributes['role'] as String?);
    final realJid = item?.attributes['jid'] as String?;
    final isUnavailable = stanza.type == Presence.unavailable.name;
    if (owner is MucService) {
      final muc = owner as MucService;
      muc.updateOccupantFromPresence(
        roomJid: jid.toBare().toString(),
        occupantId: occupantId,
        nick: jid.resource,
        realJid: realJid,
        affiliation: affiliation,
        role: role,
        isPresent: !isUnavailable,
      );
    }
    return true;
  }

  Map<String, String> _extractStatuses(mox.Stanza stanza) {
    final map = <String, String>{};
    for (final child in stanza.children.where((node) => node.tag == 'status')) {
      final text = child.text?.trim();
      if (text == null || text.isEmpty) continue;
      final lang = child.attributes['xml:lang'] ?? '';
      map[lang] = text;
    }
    return map;
  }

  mox.XMLNode? _findChildWithXmlns(
    List<mox.XMLNode> nodes, {
    required String xmlns,
    String? tag,
  }) {
    for (final child in nodes) {
      if (tag != null && child.tag != tag) continue;
      if (child.attributes['xmlns'] == xmlns) return child;
    }
    return null;
  }

  mox.XMLNode? _mucItemNode(mox.XMLNode mucUser) {
    for (final child in mucUser.children) {
      if (child.tag == 'item') return child;
    }
    return null;
  }

  String? _extractMucOccupantId(mox.Stanza stanza) {
    final node = _findChildWithXmlns(
      stanza.children,
      xmlns: _occupantIdXmlns,
      tag: 'occupant-id',
    );
    final id = node?.attributes['id'];
    return id is String ? id : null;
  }

  Future<void> _acknowledgeUnsubscribe(mox.JID jid) async {
    try {
      await getAttributes().sendStanza(
        mox.StanzaDetails(
          mox.Stanza.presence(
            to: jid.toString(),
            type: 'unsubscribed',
          ),
          addId: false,
          awaitable: false,
        ),
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to acknowledge unsubscribe from ${jid.toString()}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _respondToProbe(mox.JID jid) async {
    try {
      await owner.sendPresence(
        presence: owner.presence,
        status: owner.status,
        to: jid.toString(),
        trackDirected: true,
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to respond to presence probe from ${jid.toString()}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _ensureDirectedRecipientsLoaded() async {
    if (_directedLoaded) return;
    await owner._dbOp<XmppStateStore>((ss) {
      final stored = (ss.read(key: _directedPresenceTargetsKey) as List?)
              ?.cast<String>() ??
          const <String>[];
      _directedRecipients
        ..clear()
        ..addAll(stored);
    }, awaitDatabase: true);
    _directedLoaded = true;
  }

  Future<void> _persistDirectedRecipients() async {
    if (!_directedLoaded) return;
    await owner._dbOp<XmppStateStore>(
      (ss) => ss.write(
        key: _directedPresenceTargetsKey,
        value: _directedRecipients.toList(),
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _removeDirectedRecipient(mox.JID jid) async {
    final removed = _directedRecipients.remove(jid.toBare().toString());
    if (!removed) return;
    await _persistDirectedRecipients();
  }
}
