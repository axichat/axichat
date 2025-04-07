part of 'package:chat/src/xmpp/xmpp_service.dart';

mixin PresenceService on XmppBase {
  final presenceStorageKey = XmppStateStore.registerKey('my_presence');
  final statusStorageKey = XmppStateStore.registerKey('my_status');

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
      StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppStateStore, Stream<Presence?>>((ss) =>
            ss.watch<Presence?>(key: presenceStorageKey) ??
            Stream.value(Presence.unknown)),
      ));

  Stream<String?> get statusStream => StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppStateStore, Stream<String?>>((ss) =>
            ss.watch<String?>(key: statusStorageKey) ?? Stream.value(null)),
      ));

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      XmppPresenceManager(owner: this),
    ]);

  Future<void> sendPresence({
    required Presence? presence,
    required String? status,
  }) async {
    await _connection.sendPresence(presence: presence, status: status);
  }

  Future<void> receivePresence(
    String jid,
    Presence presence, {
    String? status,
  }) async {
    if (jid == myJid?.toString()) return;

    await _dbOp<XmppDatabase>((db) async {
      await db.updatePresence(
        jid: jid,
        presence: presence,
        status: status,
      );
    });
  }
}

class XmppPresenceManager extends mox.PresenceManager {
  XmppPresenceManager({required this.owner}) : super();

  final _log = Logger('XmppPresenceManager');

  final PresenceService owner;

  final _attachments = <mox.PresencePreSendCallback>[];

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
            if (stanza.from == null) return state..done = true;
            final jid = mox.JID.fromString(stanza.from!).toBare();
            if (stanza.type == Ask.subscribe.name ||
                stanza.type == Ask.subscribed.name) {
              getAttributes().sendEvent(
                mox.SubscriptionRequestReceivedEvent(from: jid),
              );
            } else if (stanza.type?.contains('unsubscribe') ?? false) {
              await owner._dbOp<XmppDatabase>((db) async {
                await db.deleteInvite(jid.toString());
              });
            }

            _log.info('Incoming presence from: ${jid.toString()}...');

            String? presence;
            if (stanza.type == Presence.unavailable.name) {
              presence = Presence.unavailable.name;
            } else {
              presence = stanza.children
                  .singleWhere(
                    (e) => e.tag == 'show',
                    orElse: () => mox.XMLNode(tag: 'show', text: 'chat'),
                  )
                  .text;
            }

            // TODO: xml lang i18n
            final status = stanza.children.singleWhere(
              (e) =>
                  e.tag == 'status' &&
                  (!e.attributes.containsKey('xml:lang') ||
                      e.attributes['xml:lang'] == 'en'),
              orElse: () => mox.XMLNode(tag: 'status'),
            );

            await owner.receivePresence(
              jid.toString(),
              Presence.fromString(presence),
              status: status.text,
            );

            state.done = true;

            return state;
          },
        ),
      ];

  Future<void> sendPresence({Presence? presence, String? status}) async {
    final stanza = mox.Stanza.presence(
      type: presence != null && presence.isUnavailable
          ? Presence.unavailable.name
          : null,
      children: [
        if (presence != null && !presence.isUnavailable)
          mox.XMLNode(tag: 'show', text: presence.name),
        if (status != null) mox.XMLNode(tag: 'status', text: status),
        for (final attachment in _attachments) ...await attachment(),
      ],
    );

    _log.info('Requesting to send presence: ${presence?.name} '
        'and status: $status...');

    try {
      await getAttributes().sendStanza(
        mox.StanzaDetails(
          stanza,
          addId: false,
          awaitable: false,
        ),
      );
    } on Exception catch (e) {
      _log.severe('Failed to update presence:', e);
      throw XmppPresenceException();
    }

    _log.info('Saving profile presence: $presence and status: $status...');
    await owner._dbOp<XmppStateStore>((ss) async {
      await ss.writeAll(data: {
        owner.presenceStorageKey: presence,
        owner.statusStorageKey: status,
      });
    });
  }

  @override
  Future<void> sendInitialPresence() async {
    Presence? presence;
    String? status;
    await owner._dbOp<XmppStateStore>((ss) {
      presence = ss.read(key: owner.presenceStorageKey) as Presence?;
      status = ss.read(key: owner.statusStorageKey) as String?;
    });
    await sendPresence(presence: presence, status: status);
  }
}
