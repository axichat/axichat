part of 'package:chat/src/xmpp/xmpp_service.dart';

mixin PresenceService on XmppBase {
  final presenceStorageKey = XmppStateStore.registerKey('my_presence');
  final statusStorageKey = XmppStateStore.registerKey('my_status');

  Presence get presence =>
      _stateStore.value?.read(key: presenceStorageKey) as Presence? ??
      Presence.chat;
  String? get status =>
      _stateStore.value?.read(key: statusStorageKey) as String?;

  Stream<Presence>? get presenceStream =>
      _stateStore.value?.watch<Presence>(key: presenceStorageKey);
  Stream<String?>? get statusStream =>
      _stateStore.value?.watch<String?>(key: statusStorageKey);

  final _log = Logger('PresenceService');

  Future<void> sendPresence({
    required Presence? presence,
    required String? status,
  }) async {
    await _connection
        .getManager<XmppPresenceManager>()
        ?.sendPresence(presence: presence, status: status);
  }

  Future<void> receivePresence(
    String jid,
    Presence presence,
    String? status,
  ) async {
    if (jid == user!.jid.toString()) {
      _log.info('Saving profile presence: $presence and status: $status...');
      await owner._dbOp<XmppStateStore>((ss) async {
        await ss.writeAll(data: {
          presenceStorageKey: presence,
          statusStorageKey: status,
        });
      });
    } else {
      _log.info('Saving ${jid.toString()} presence: $presence '
          'and status: $status...');
      await owner._dbOp<XmppDatabase>((db) async {
        if (await db.rosterAccessor.selectOne(jid.toString())
            case final item?) {
          await db.rosterAccessor.updateOne(
            item.copyWith(
              presence: presence,
              status: status,
            ),
          );
        }
      });
    }
  }
}

class XmppPresenceManager extends mox.PresenceManager {
  XmppPresenceManager({required this.owner}) : super();

  final _log = Logger('XmppPresenceManager');

  final XmppService owner;

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
            if (stanza.type == 'subscribe' || stanza.type == 'subscribed') {
              getAttributes().sendEvent(
                mox.SubscriptionRequestReceivedEvent(from: jid),
              );
            } else if (stanza.type?.contains('unsubscribe') ?? false) {
              _log.info('Deleting invite from ${jid.toString()}');
              await owner._dbOp<XmppDatabase>((db) async {
                await db.invitesAccessor.deleteOne(jid.toString());
              });
            }

            _log.info('Incoming presence from: ${jid.toString()}...');

            final show = stanza.children.singleWhere(
              (e) => e.tag == 'show',
              orElse: () => mox.XMLNode(tag: 'show', text: 'chat'),
            );

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
              Presence.fromString(show.text),
              status.text,
            );

            state.done = true;

            return state;
          },
        ),
      ];

  Future<void> sendPresence({Presence? presence, String? status}) async {
    final stanza = mox.Stanza.presence(
      children: [
        if (presence != null) mox.XMLNode(tag: 'show', text: presence.name),
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
