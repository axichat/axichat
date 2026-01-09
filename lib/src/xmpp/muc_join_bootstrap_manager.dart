// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

final class MucSelfPresenceEvent extends mox.XmppEvent {
  MucSelfPresenceEvent({
    required this.roomJid,
    required this.occupantJid,
    required this.nick,
    required this.affiliation,
    required this.role,
    required this.isAvailable,
    required this.isError,
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
  final bool isError;
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
  static const String _presenceTypeUnavailable = 'unavailable';
  static const String _presenceTypeError = 'error';

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
  final Map<String, String> _roomNicknames = {};

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

  void rememberNickname({
    required String roomJid,
    required String nickname,
  }) {
    final normalizedRoom = _normalizeRoomKey(roomJid);
    final normalizedNick = nickname.trim();
    if (normalizedRoom == null || normalizedNick.isEmpty) return;
    _roomNicknames[normalizedRoom] = normalizedNick;
  }

  void forgetNickname(String roomJid) {
    final normalizedRoom = _normalizeRoomKey(roomJid);
    if (normalizedRoom == null) return;
    _roomNicknames.remove(normalizedRoom);
  }

  String? passwordForRoom(String roomJid) {
    final normalizedRoom = _normalizeRoomKey(roomJid);
    if (normalizedRoom == null) return null;
    return _roomPasswords[normalizedRoom];
  }

  String? _nickForRoom(String roomJid) {
    final normalizedRoom = _normalizeRoomKey(roomJid);
    if (normalizedRoom == null) return null;
    return _roomNicknames[normalizedRoom];
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
    if (presence.type == _presenceTypeUnavailable) return state;
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
    final String? presenceType = presence.type;
    final bool isErrorPresence = presenceType == _presenceTypeError;
    final nick = fromJid.resource;
    if (nick.isEmpty && !isErrorPresence) return state;

    final mucUser = presence.firstTag('x', xmlns: _mucUserXmlns);
    final item = mucUser?.firstTag('item');
    if (mucUser == null || item == null) {
      if (!isErrorPresence) return state;
      final roomJid = fromJid.toBare().toString();
      final String? resolvedNick = _resolveSelfPresenceNick(
        roomJid: roomJid,
        stanzaNick: nick,
      );
      if (resolvedNick == null) return state;
      final Set<String> statuses = mucUser
              ?.findTags('status')
              .map((status) => status.attributes['code'])
              .whereType<String>()
              .toSet() ??
          const <String>{};
      if (!_isSelfPresenceForError(
        presence: presence,
        roomJid: roomJid,
        nick: resolvedNick,
        statusCodes: statuses,
      )) {
        return state;
      }
      final occupantJid =
          nick.isNotEmpty ? fromJid.toString() : '$roomJid/$resolvedNick';
      getAttributes().sendEvent(
        MucSelfPresenceEvent(
          roomJid: roomJid,
          occupantJid: occupantJid,
          nick: resolvedNick,
          affiliation: OccupantAffiliation.none.xmlValue,
          role: OccupantRole.none.xmlValue,
          isAvailable: false,
          isError: true,
          isNickChange: false,
          statusCodes: statuses,
          reason: null,
          newNick: null,
        ),
      );
      return state;
    }

    final statuses = mucUser
        .findTags('status')
        .map((status) => status.attributes['code'])
        .whereType<String>()
        .toSet();
    final roomBare = fromJid.toBare();
    final roomJid = roomBare.toString();
    final itemJid = item.attributes['jid'];
    final ownBareJid = getAttributes().getFullJID().toBare().toString();
    final isSelfByJid = itemJid is String && itemJid.isNotEmpty
        ? _matchesBareJid(itemJid, ownBareJid)
        : false;
    final isSelfPresence = statuses.contains(mucStatusSelfPresence) ||
        statuses.contains(mucStatusNickAssigned) ||
        isSelfByJid;
    if (!isSelfPresence) return state;
    final resolvedStatuses = statuses.contains(mucStatusSelfPresence)
        ? statuses
        : <String>{
            ...statuses,
            ..._selfPresenceFallbackStatusCodes,
          };
    final bool isError = presenceType == _presenceTypeError;
    final bool isUnavailable = presenceType == _presenceTypeUnavailable;
    final bool isAvailable = !isUnavailable && !isError;
    final newNickAttr = item.attributes['nick'];
    final newNick = newNickAttr is String ? newNickAttr.trim() : null;
    final isNickChange =
        statuses.contains(mucStatusNickChange) && newNick?.isNotEmpty == true;
    final affiliationAttr = item.attributes['affiliation'];
    final roleAttr = item.attributes['role'];
    final affiliation = affiliationAttr is String ? affiliationAttr : 'none';
    final role = roleAttr is String ? roleAttr : 'none';
    final reason = item.firstTag('reason')?.innerText().trim();

    if (isAvailable) {
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
        isAvailable: isAvailable,
        isError: isError,
        isNickChange: isNickChange,
        statusCodes: resolvedStatuses,
        reason: reason?.isNotEmpty == true ? reason : null,
        newNick: isNickChange ? newNick : null,
      ),
    );

    return state;
  }

  bool _matchesBareJid(String left, String right) {
    final normalizedLeft = _normalizeRoomKey(left);
    final normalizedRight = _normalizeRoomKey(right);
    if (normalizedLeft == null || normalizedRight == null) return false;
    return normalizedLeft == normalizedRight;
  }

  String? _resolveSelfPresenceNick({
    required String roomJid,
    required String stanzaNick,
  }) {
    if (stanzaNick.isNotEmpty) return stanzaNick;
    final storedNick = _nickForRoom(roomJid);
    if (storedNick == null || storedNick.isEmpty) return null;
    return storedNick;
  }

  bool _isSelfPresenceForError({
    required mox.Stanza presence,
    required String roomJid,
    required String nick,
    required Set<String> statusCodes,
  }) {
    if (statusCodes.contains(mucStatusSelfPresence) ||
        statusCodes.contains(mucStatusNickAssigned)) {
      return true;
    }
    final String? toAttr = presence.to;
    final String ownBareJid = getAttributes().getFullJID().toBare().toString();
    if (toAttr != null && toAttr.isNotEmpty) {
      if (_matchesBareJid(toAttr, ownBareJid)) return true;
    }
    final storedNick = _nickForRoom(roomJid);
    if (storedNick == null || storedNick.isEmpty) return false;
    return storedNick.toLowerCase() == nick.toLowerCase();
  }
}
