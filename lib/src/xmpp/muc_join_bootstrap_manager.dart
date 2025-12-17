part of 'package:axichat/src/xmpp/xmpp_service.dart';

final class MucSelfPresenceEvent extends mox.XmppEvent {
  MucSelfPresenceEvent({
    required this.roomJid,
    required this.occupantJid,
    required this.nick,
    required this.affiliation,
    required this.role,
    required this.isAvailable,
    required this.isNickChange,
    this.newNick,
  });

  final String roomJid;
  final String occupantJid;
  final String nick;
  final String affiliation;
  final String role;
  final bool isAvailable;
  final bool isNickChange;
  final String? newNick;
}

final class MucJoinBootstrapManager extends mox.XmppManagerBase {
  MucJoinBootstrapManager() : super(_mucJoinBootstrapManagerId);

  static const String _mucJoinBootstrapManagerId = 'axi_muc_join_bootstrap';

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

    final statuses = mucUser
        .findTags('status')
        .map((status) => status.attributes['code'])
        .whereType<String>()
        .toSet();
    if (!statuses.contains(_selfPresenceStatusCode)) return state;

    final roomBare = fromJid.toBare();
    final roomJid = roomBare.toString();
    final isUnavailable = presence.type == 'unavailable';
    final newNickAttr = item.attributes['nick'];
    final newNick = newNickAttr is String ? newNickAttr.trim() : null;
    final isNickChange =
        statuses.contains(_nickChangeStatusCode) && newNick?.isNotEmpty == true;
    final affiliationAttr = item.attributes['affiliation'];
    final roleAttr = item.attributes['role'];
    final affiliation = affiliationAttr is String ? affiliationAttr : 'none';
    final role = roleAttr is String ? roleAttr : 'none';

    if (!isUnavailable) {
      final mucManager =
          getAttributes().getManagerById<mox.MUCManager>(mox.mucManager);
      final roomState = await mucManager?.getRoomState(roomBare);
      if (roomState != null && !roomState.joined) {
        roomState.joined = true;
      }
    }

    getAttributes().sendEvent(
      MucSelfPresenceEvent(
        roomJid: roomJid,
        occupantJid: fromJid.toString(),
        nick: nick,
        affiliation: affiliation,
        role: role,
        isAvailable: !isUnavailable,
        isNickChange: isNickChange,
        newNick: isNickChange ? newNick : null,
      ),
    );

    return state;
  }
}
