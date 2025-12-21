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
    required this.statusCodes,
    this.reason,
    this.newNick,
  });

  final String roomJid;
  final String occupantJid;
  final String nick;
  final String affiliation;
  final String role;
  final bool isAvailable;
  final bool isNickChange;
  final Set<String> statusCodes;
  final String? reason;
  final String? newNick;
}

final class MucJoinBootstrapManager extends mox.XmppManagerBase {
  MucJoinBootstrapManager() : super(_mucJoinBootstrapManagerId);

  static const String _mucJoinBootstrapManagerId = 'axi_muc_join_bootstrap';

  static final int _handlerPriority =
      mox.PresenceManager.presenceHandlerPriority + 2;

  static const int _outgoingHandlerPriority = 120;
  static const String _presenceTag = 'presence';
  static const String _passwordTag = 'password';

  @override
  Future<bool> isSupported() async => true;

  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: _presenceTag,
          tagName: 'x',
          tagXmlns: _mucUserXmlns,
          priority: _handlerPriority,
          callback: _onPresence,
        ),
      ];

  @override
  List<mox.StanzaHandler> getOutgoingPreStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: _presenceTag,
          priority: _outgoingHandlerPriority,
          callback: _onOutgoingPresence,
        ),
      ];

  final Map<String, String> _roomPasswords = {};

  void rememberPassword({
    required String roomJid,
    required String password,
  }) {
    final normalizedRoom = _normalizeRoomKey(roomJid);
    if (normalizedRoom == null || password.trim().isEmpty) return;
    _roomPasswords[normalizedRoom] = password.trim();
  }

  void forgetPassword(String roomJid) {
    final normalizedRoom = _normalizeRoomKey(roomJid);
    if (normalizedRoom == null) return;
    _roomPasswords.remove(normalizedRoom);
  }

  String? passwordForRoom(String roomJid) {
    final normalizedRoom = _normalizeRoomKey(roomJid);
    if (normalizedRoom == null) return null;
    return _roomPasswords[normalizedRoom];
  }

  String? _normalizeRoomKey(String roomJid) {
    final trimmed = roomJid.trim();
    if (trimmed.isEmpty) return null;
    try {
      return mox.JID.fromString(trimmed).toBare().toString();
    } on Exception {
      return null;
    }
  }

  Future<mox.StanzaHandlerData> _onOutgoingPresence(
    mox.Stanza presence,
    mox.StanzaHandlerData state,
  ) async {
    if (presence.type == 'unavailable') return state;
    final mucJoin = presence.firstTag('x', xmlns: _mucJoinXmlns);
    if (mucJoin == null) return state;

    final toAttr = presence.attributes['to']?.toString().trim();
    if (toAttr == null || toAttr.isEmpty) return state;

    final normalizedRoom = _normalizeRoomKey(toAttr);
    if (normalizedRoom == null) return state;

    final password = _roomPasswords[normalizedRoom];
    if (password == null || password.isEmpty) return state;
    if (mucJoin.firstTag(_passwordTag) != null) return state;

    mucJoin.addChild(mox.XMLNode(tag: _passwordTag, text: password));
    return state;
  }

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
    if (!statuses.contains(mucStatusSelfPresence)) return state;

    final roomBare = fromJid.toBare();
    final roomJid = roomBare.toString();
    final isUnavailable = presence.type == 'unavailable';
    final newNickAttr = item.attributes['nick'];
    final newNick = newNickAttr is String ? newNickAttr.trim() : null;
    final isNickChange =
        statuses.contains(mucStatusNickChange) && newNick?.isNotEmpty == true;
    final affiliationAttr = item.attributes['affiliation'];
    final roleAttr = item.attributes['role'];
    final affiliation = affiliationAttr is String ? affiliationAttr : 'none';
    final role = roleAttr is String ? roleAttr : 'none';
    final reason = item.firstTag('reason')?.innerText().trim();

    if (!isUnavailable) {
      final mucManager =
          getAttributes().getManagerById<MUCManager>(mox.mucManager);
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
        statusCodes: statuses,
        reason: reason?.isNotEmpty == true ? reason : null,
        newNick: isNickChange ? newNick : null,
      ),
    );

    return state;
  }
}
