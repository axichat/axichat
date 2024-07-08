part of '../../main.dart';

mixin PresenceService on XmppBase {
  final presenceStorageKey = RegisteredStateKey._('my_presence');
  final statusStorageKey = RegisteredStateKey._('my_status');

  Presence get presence =>
      _stateStore.value?.read(key: presenceStorageKey) as Presence? ??
      Presence.chat;
  String? get status =>
      _stateStore.value?.read(key: statusStorageKey) as String?;

  Stream<Presence>? get presenceStream =>
      _stateStore.value?.watch<Presence>(key: presenceStorageKey);
  Stream<String?>? get statusStream =>
      _stateStore.value?.watch<String?>(key: statusStorageKey);

  Future<void> sendPresence({
    required Presence? presence,
    required String? status,
  }) async {
    try {
      await _connection
          .getManager<XmppPresenceManager>()
          ?.sendPresence(presence: presence, status: status);
    } on Exception catch (e) {
      Logger('XmppService').severe('Failed to update presence:', e);
      throw XmppPresenceException();
    }
  }

  Future<void> receivePresence(
    String jid,
    Presence presence,
    String? status,
  ) async {
    if (jid == user!.jid.toString()) {
      await _dbOp<_XmppStateStore>(owner, (ss) async {
        await ss.writeAll(data: {
          presenceStorageKey: presence,
          statusStorageKey: status,
        });
      });
    } else {
      await _dbOp<_XmppDatabase>(owner, (db) async {
        if (await db.selectRosterItem(jid.toString()) case final item?) {
          db.updateRosterItem(item.copyWith(
            presence: presence,
            status: status,
          ));
        }
      });
    }
  }
}

class XmppPresenceManager extends mox.PresenceManager {
  XmppPresenceManager({required this.owner}) : super();

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
              await _dbOp<_XmppDatabase>(owner, (db) async {
                await db.deleteInvite(jid.toString());
              });
            }

            Logger('XmppService')
                .info('Incoming presence from: ${jid.toString()}...');

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

    await getAttributes().sendStanza(
      mox.StanzaDetails(
        stanza,
        addId: false,
        awaitable: false,
      ),
    );
  }

  @override
  Future<void> sendInitialPresence() async {
    Presence? presence;
    String? status;
    await _dbOp<_XmppStateStore>(owner, (ss) {
      presence = ss.read(key: owner.presenceStorageKey) as Presence?;
      status = ss.read(key: owner.statusStorageKey) as String?;
    });
    await sendPresence(presence: presence, status: status);
  }
}
