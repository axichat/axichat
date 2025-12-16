part of 'package:axichat/src/xmpp/xmpp_service.dart';

final class MucPresenceMirrorEvent extends mox.XmppEvent {
  MucPresenceMirrorEvent({
    required this.roomJid,
    required this.occupantId,
    required this.nick,
    required this.isSelfPresence,
    required this.isPresent,
    required this.isNickChange,
    this.realJid,
    this.affiliation,
    this.role,
    this.newNick,
  });

  final String roomJid;
  final String occupantId;
  final String nick;
  final bool isSelfPresence;
  final bool isPresent;
  final bool isNickChange;
  final String? realJid;
  final String? affiliation;
  final String? role;
  final String? newNick;
}

final class MucPresenceMirrorManager extends mox.XmppManagerBase {
  MucPresenceMirrorManager() : super(_mucPresenceMirrorManagerId);

  static const String _mucPresenceMirrorManagerId = 'axi_muc_presence_mirror';

  static final int _handlerPriority =
      mox.PresenceManager.presenceHandlerPriority + 2;

  static const String _selfPresenceStatusCode = '110';
  static const String _nickChangeStatusCode = '303';

  @override
  Future<bool> isSupported() async => true;

  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: 'presence',
          tagName: 'x',
          tagXmlns: _mucUserXmlns,
          priority: _handlerPriority,
          callback: _onPresence,
        ),
      ];

  Future<mox.StanzaHandlerData> _onPresence(
    mox.Stanza presence,
    mox.StanzaHandlerData state,
  ) async {
    final fromAttr = presence.from;
    if (fromAttr == null || fromAttr.isEmpty) return state;
    final fromJid = mox.JID.fromString(fromAttr);
    final nick = fromJid.resource;
    if (nick.isEmpty) return state;

    final mucUser = presence.firstTag('x', xmlns: _mucUserXmlns);
    final item = mucUser?.firstTag('item');
    if (mucUser == null || item == null) return state;

    final roomBare = fromJid.toBare().toString();
    final affiliation = item.attributes['affiliation'];
    final role = item.attributes['role'];
    final realJid = item.attributes['jid'];
    final newNick = item.attributes['nick'];

    final statuses = mucUser
        .findTags('status')
        .map((status) => status.attributes['code'])
        .whereType<String>()
        .toSet();

    final isSelfPresence = statuses.contains(_selfPresenceStatusCode);
    final isNickChange = statuses.contains(_nickChangeStatusCode) &&
        newNick is String &&
        newNick.trim().isNotEmpty;
    final isUnavailable = presence.type == Presence.unavailable.name;
    final isRoleNone = role == 'none';
    final isLeft = isUnavailable && !isNickChange && isRoleNone;

    String? occupantId;
    final occupantNode =
        presence.firstTag('occupant-id', xmlns: _occupantIdXmlns);
    final occupantRaw = occupantNode?.attributes['id'];
    if (occupantRaw is String && occupantRaw.isNotEmpty) {
      occupantId = occupantRaw;
    } else {
      occupantId = fromJid.toString();
    }

    getAttributes().sendEvent(
      MucPresenceMirrorEvent(
        roomJid: roomBare,
        occupantId: occupantId,
        nick: nick,
        isSelfPresence: isSelfPresence,
        isPresent: !isLeft,
        isNickChange: isNickChange,
        realJid: realJid is String ? realJid : null,
        affiliation: affiliation is String ? affiliation : null,
        role: role is String ? role : null,
        newNick: isNickChange ? (newNick).trim() : null,
      ),
    );

    return state;
  }
}
