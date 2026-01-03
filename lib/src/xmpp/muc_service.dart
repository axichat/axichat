// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const _mucUserXmlns = 'http://jabber.org/protocol/muc#user';
const _mucAdminXmlns = 'http://jabber.org/protocol/muc#admin';
const _mucOwnerXmlns = 'http://jabber.org/protocol/muc#owner';
const _mucJoinXmlns = 'http://jabber.org/protocol/muc';
const _occupantIdXmlns = 'urn:xmpp:occupant-id:0';
const _directInviteXmlns = 'jabber:x:conference';
const _directInviteTag = 'x';
const _directInviteRoomAttr = 'jid';
const _directInviteReasonAttr = 'reason';
const _directInvitePasswordAttr = 'password';
const _directInviteContinueAttr = 'continue';
const _axiInviteXmlns = 'urn:axichat:invite:1';
const _axiInviteTag = 'invite';
const _axiInviteRevokeTag = 'invite-revoke';
const _axiInviteTokenAttr = 'token';
const _axiInviteRoomAttr = 'room';
const _axiInviteRoomNameAttr = 'room_name';
const _axiInviteInviterAttr = 'inviter';
const _axiInviteInviteeAttr = 'invitee';
const _axiInviteReasonAttr = 'reason';
const _axiInvitePasswordAttr = 'password';
const _mucDiscoFeature = 'http://jabber.org/protocol/muc';
const _discoInfoXmlns = 'http://jabber.org/protocol/disco#info';
const _dataFormXmlns = 'jabber:x:data';
const _dataFormTag = 'x';
const _fieldTag = 'field';
const _valueTag = 'value';
const _varAttr = 'var';
const _formTypeFieldVar = 'FORM_TYPE';
const _mucRoomInfoFormType = 'http://jabber.org/protocol/muc#roominfo';
const _mucRoomConfigFormType = 'http://jabber.org/protocol/muc#roomconfig';
const _avatarFieldToken = 'avatar';
const _avatarHashToken = 'hash';
const _dataUriPrefix = 'data:';
const _dataUriBase64Delimiter = ';base64,';
const _roomAvatarDecodeFailedLog = 'Room avatar decode failed.';
const _roomAvatarStoreFailedLog = 'Room avatar store failed.';
const _iqTypeAttr = 'type';
const _iqTypeGet = 'get';
const _iqTypeSet = 'set';
const _iqTypeResult = 'result';
const _queryTag = 'query';
const _itemTag = 'item';
const _jidAttr = 'jid';
const _nickAttr = 'nick';
const _affiliationAttr = 'affiliation';
const _roleAttr = 'role';
const _reasonTag = 'reason';
const _subjectTag = 'subject';
const _messageTypeGroupchat = 'groupchat';
const _messageTypeNormal = 'normal';
const _mucServiceHostStorageKeyName = 'muc_service_host';
final _mucServiceHostStorageKey =
    XmppStateStore.registerKey(_mucServiceHostStorageKeyName);

extension _MoxAffiliationConversion on mox.Affiliation {
  OccupantAffiliation get toOccupantAffiliation => switch (this) {
        mox.Affiliation.owner => OccupantAffiliation.owner,
        mox.Affiliation.admin => OccupantAffiliation.admin,
        mox.Affiliation.member => OccupantAffiliation.member,
        mox.Affiliation.outcast => OccupantAffiliation.outcast,
        mox.Affiliation.none => OccupantAffiliation.none,
      };
}

extension _MoxRoleConversion on mox.Role {
  OccupantRole get toOccupantRole => switch (this) {
        mox.Role.moderator => OccupantRole.moderator,
        mox.Role.participant => OccupantRole.participant,
        mox.Role.visitor => OccupantRole.visitor,
        mox.Role.none => OccupantRole.none,
      };
}

final class MucSubjectChangedEvent extends mox.XmppEvent {
  MucSubjectChangedEvent({
    required this.roomJid,
    required this.subject,
  });

  final String roomJid;
  final String? subject;
}

final class MucAffiliationEntry {
  const MucAffiliationEntry({
    required this.affiliation,
    this.jid,
    this.nick,
    this.role,
    this.reason,
  });

  final OccupantAffiliation affiliation;
  final String? jid;
  final String? nick;
  final OccupantRole? role;
  final String? reason;
}

final class _RoomAvatarPayload {
  const _RoomAvatarPayload({
    this.data,
    this.hash,
  });

  final String? data;
  final String? hash;
}

mixin MucService on XmppBase, BaseStreamService {
  final _mucLog = Logger('MucService');
  static const Duration _mucJoinTimeout = Duration(seconds: 10);
  static const int _defaultMucJoinHistoryStanzas = 50;
  static const int _mucSnapshotStart = 0;
  static const int _mucSnapshotEnd = 0;
  static const List<MucBookmark> _emptyMucSnapshot = <MucBookmark>[];
  final _roomStates = <String, RoomState>{};
  final _roomStreams = <String, StreamController<RoomState>>{};
  final _roomSubjects = <String, String?>{};
  final _roomSubjectStreams = <String, StreamController<String?>>{};
  final _roomNicknames = <String, String>{};
  final _leftRooms = <String>{};
  final _seededDummyRooms = <String>{};
  String? _mucServiceHost;
  bool _mucBookmarksSyncInFlight = false;

  String get mucServiceHost =>
      _mucServiceHost ?? 'conference.${_myJid?.domain ?? 'example.com'}';

  void setMucServiceHost(String? host) {
    final normalized = host?.trim();
    if (normalized == null || normalized.isEmpty) {
      _mucServiceHost = null;
      _persistMucServiceHost(null);
      return;
    }
    if (_mucServiceHost == normalized) return;
    _mucServiceHost = normalized;
    _persistMucServiceHost(normalized);
  }

  void _restoreMucServiceHost(String? host) {
    final normalized = host?.trim();
    if (normalized == null || normalized.isEmpty) return;
    _mucServiceHost = normalized;
  }

  void _persistMucServiceHost(String? host) {
    final normalized = host?.trim();
    if (normalized == null || normalized.isEmpty) {
      unawaited(
        _dbOp<XmppStateStore>(
          (ss) => ss.delete(key: _mucServiceHostStorageKey),
          awaitDatabase: true,
        ),
      );
      return;
    }
    unawaited(
      _dbOp<XmppStateStore>(
        (ss) => ss.write(key: _mucServiceHostStorageKey, value: normalized),
        awaitDatabase: true,
      ),
    );
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<MucSelfPresenceEvent>((event) async {
        _handleSelfPresence(event);
      })
      ..registerHandler<mox.MemberJoinedEvent>((event) async {
        _handleMemberUpsert(event.roomJid, event.member);
      })
      ..registerHandler<mox.MemberChangedEvent>((event) async {
        _handleMemberUpsert(event.roomJid, event.member);
      })
      ..registerHandler<mox.MemberLeftEvent>((event) async {
        _handleMemberLeft(event.roomJid, event.nick);
      })
      ..registerHandler<mox.MemberChangedNickEvent>((event) async {
        _handleMemberNickChanged(event.roomJid, event.oldNick, event.newNick);
      })
      ..registerHandler<mox.OwnDataChangedEvent>((event) async {
        _handleOwnDataChanged(
          roomJid: event.roomJid,
          nick: event.nick,
          affiliation: event.affiliation,
          role: event.role,
        );
      })
      ..registerHandler<MucSubjectChangedEvent>((event) async {
        _updateRoomSubject(event.roomJid, event.subject);
      })
      ..registerHandler<MucBookmarkUpdatedEvent>((event) async {
        await applyMucBookmarks([event.bookmark]);
      })
      ..registerHandler<MucBookmarkRetractedEvent>((event) async {
        await _applyBookmarkRetraction(event.roomBare);
      })
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (event.resumed) return;
        if (connectionState != ConnectionState.connected) return;
        unawaited(_bootstrapMucOnLogin());
      });
  }

  Future<void> _bootstrapMucOnLogin() async {
    await discoverMucServiceHost();
    await syncMucBookmarksOnLogin();
  }

  Stream<RoomState> roomStateStream(String roomJid) {
    final key = _roomKey(roomJid);
    final controller = _roomStreams.putIfAbsent(
      key,
      () => StreamController<RoomState>.broadcast(
        onListen: () {
          final current = _roomStates[key];
          if (current != null) {
            _roomStreams[key]?.add(current);
          }
        },
      ),
    );
    final current = _roomStates[key];
    if (current != null && controller.hasListener) {
      controller.add(current);
    }
    return controller.stream;
  }

  Stream<String?> roomSubjectStream(String roomJid) {
    final key = _roomKey(roomJid);
    final controller = _roomSubjectStreams.putIfAbsent(
      key,
      () => StreamController<String?>.broadcast(
        onListen: () {
          if (_roomSubjects.containsKey(key)) {
            _roomSubjectStreams[key]?.add(_roomSubjects[key]);
          }
        },
      ),
    );
    if (controller.hasListener) {
      controller.add(_roomSubjects[key]);
    }
    return controller.stream;
  }

  RoomState? roomStateFor(String roomJid) => _roomStates[_roomKey(roomJid)];

  String? roomSubjectFor(String roomJid) => _roomSubjects[_roomKey(roomJid)];

  bool hasLeftRoom(String roomJid) => _leftRooms.contains(_roomKey(roomJid));

  void _markRoomJoined(String roomJid) {
    _leftRooms.remove(_roomKey(roomJid));
  }

  void _markRoomLeft(
    String roomJid, {
    Set<String>? statusCodes,
    String? reason,
  }) {
    final key = _roomKey(roomJid);
    _leftRooms.add(key);
    final normalizedReason = _normalizeSubject(reason);
    final room = RoomState(
      roomJid: key,
      occupants: const {},
      myOccupantId: null,
      selfPresenceStatusCodes: statusCodes ?? const <String>{},
      selfPresenceReason: normalizedReason,
    );
    _roomStates[key] = room;
    _roomStreams[key]?.add(room);
  }

  void _updateRoomSubject(String roomJid, String? subject) {
    final key = _roomKey(roomJid);
    final normalizedSubject = _normalizeSubject(subject);
    _roomSubjects[key] = normalizedSubject;
    _roomSubjectStreams[key]?.add(normalizedSubject);
  }

  String? _normalizeSubject(String? subject) {
    final trimmed = subject?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _normalizePassword(String? password) {
    final trimmed = password?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  void _rememberRoomPassword({
    required String roomJid,
    required String? password,
  }) {
    final normalizedPassword = _normalizePassword(password);
    if (normalizedPassword == null) return;
    final manager = _connection.getManager<MucJoinBootstrapManager>();
    if (manager == null) return;
    manager.rememberPassword(
      roomJid: roomJid,
      password: normalizedPassword,
    );
  }

  void _forgetRoomPassword({required String roomJid}) {
    final manager = _connection.getManager<MucJoinBootstrapManager>();
    if (manager == null) return;
    manager.forgetPassword(roomJid);
  }

  String? _passwordForRoom(String roomJid) {
    final manager = _connection.getManager<MucJoinBootstrapManager>();
    if (manager == null) return null;
    return manager.passwordForRoom(roomJid);
  }

  void _applySelfPresenceStatus({
    required String roomJid,
    required Set<String> statusCodes,
    String? reason,
  }) {
    final key = _roomKey(roomJid);
    final normalizedReason = _normalizeSubject(reason);
    final existing =
        _roomStates[key] ?? RoomState(roomJid: key, occupants: const {});
    final updated = existing.copyWith(
      selfPresenceStatusCodes: statusCodes,
      selfPresenceReason: normalizedReason,
    );
    _roomStates[key] = updated;
    _roomStreams[key]?.add(updated);
  }

  Future<RoomState> warmRoomFromHistory({
    required String roomJid,
    int limit = 200,
  }) async {
    final key = _roomKey(roomJid);
    if (_leftRooms.contains(key)) {
      return _roomStates[key] ?? RoomState(roomJid: key, occupants: const {});
    }
    final messages = await _dbOpReturning<XmppDatabase, List<Message>>(
      (db) => db.getChatMessages(
        roomJid,
        start: 0,
        end: limit,
        filter: MessageTimelineFilter.allWithContact,
      ),
    );
    trackOccupantsFromMessages(roomJid, messages);
    return roomStateFor(roomJid) ??
        RoomState(roomJid: _roomKey(roomJid), occupants: const {});
  }

  Future<String> createRoom({
    required String name,
    String? nickname,
    int maxHistoryStanzas = 0,
  }) async {
    final slug = _slugify(name);
    final roomJid = '$slug@$mucServiceHost';
    final nick = _nickForRoom(nickname);
    _roomNicknames[_roomKey(roomJid)] = nick;

    await joinRoom(
      roomJid: roomJid,
      nickname: nick,
      maxHistoryStanzas: maxHistoryStanzas,
    );
    await _dbOp<XmppDatabase>(
      (db) => db.createChat(
        Chat(
          jid: roomJid,
          title: name.trim().isEmpty ? slug : name.trim(),
          type: ChatType.groupChat,
          myNickname: nick,
          lastChangeTimestamp: DateTime.timestamp(),
          contactJid: roomJid,
        ),
      ),
    );
    await _upsertBookmarkForRoom(
      roomJid: roomJid,
      title: name.trim().isEmpty ? slug : name.trim(),
      nickname: nick,
      autojoin: true,
    );
    return roomJid;
  }

  Future<void> joinRoom({
    required String roomJid,
    required String nickname,
    int? maxHistoryStanzas,
    String? password,
  }) async {
    _markRoomJoined(roomJid);
    _roomNicknames[_roomKey(roomJid)] = nickname;
    _rememberRoomPassword(roomJid: roomJid, password: password);
    final manager = _connection.getManager<MUCManager>();
    if (manager == null) throw XmppMessageException();

    try {
      final resolvedHistoryStanzas =
          maxHistoryStanzas ?? _defaultMucJoinHistoryStanzas;
      final result = await manager
          .joinRoom(
            mox.JID.fromString(roomJid),
            nickname,
            maxHistoryStanzas: resolvedHistoryStanzas,
          )
          .timeout(_mucJoinTimeout);
      if (result.isType<mox.MUCError>()) {
        throw XmppMessageException();
      }
      unawaited(_refreshRoomAvatar(roomJid));
    } on TimeoutException {
      _mucLog.fine('Timed out waiting for room join to complete.');
    }
  }

  Future<void> ensureJoined({
    required String roomJid,
    String? nickname,
    int? maxHistoryStanzas,
    String? password,
  }) async {
    final key = _roomKey(roomJid);
    if (_leftRooms.contains(key)) return;
    final room = _roomStates[key];
    final myOccupant =
        room?.myOccupantId == null ? null : room!.occupants[room.myOccupantId!];
    if (myOccupant?.isPresent == true) {
      return;
    }
    final preferredNick = nickname?.trim();
    final rememberedNick = preferredNick?.isNotEmpty == true
        ? preferredNick!
        : _roomNicknames[key];
    final resolvedNick = rememberedNick?.isNotEmpty == true
        ? rememberedNick!
        : _nickForRoom(null);
    await joinRoom(
      roomJid: roomJid,
      nickname: resolvedNick,
      maxHistoryStanzas: maxHistoryStanzas,
      password: password,
    );
  }

  Future<void> inviteUserToRoom({
    required String roomJid,
    required String inviteeJid,
    String? reason,
    String? password,
  }) async {
    await _sendInviteNotice(
      roomJid: roomJid,
      inviteeJid: inviteeJid,
      reason: reason,
      password: password,
    );
  }

  Future<void> kickOccupant({
    required String roomJid,
    required String nick,
    String? reason,
  }) async {
    await _sendAdminItems(
      roomJid: roomJid,
      items: [
        mox.XMLNode(
          tag: 'item',
          attributes: {
            'nick': nick,
            'role': OccupantRole.none.xmlValue,
          },
          children: reason?.isNotEmpty == true
              ? [mox.XMLNode(tag: 'reason', text: reason)]
              : const [],
        ),
      ],
    );
  }

  Future<void> banOccupant({
    required String roomJid,
    required String jid,
    String? reason,
  }) async {
    await _sendAdminItems(
      roomJid: roomJid,
      items: [
        mox.XMLNode(
          tag: 'item',
          attributes: {
            'jid': jid,
            'affiliation': OccupantAffiliation.outcast.xmlValue,
          },
          children: reason?.isNotEmpty == true
              ? [mox.XMLNode(tag: 'reason', text: reason)]
              : const [],
        ),
      ],
    );
  }

  Future<void> changeAffiliation({
    required String roomJid,
    required String jid,
    required OccupantAffiliation affiliation,
  }) async {
    await _sendAdminItems(
      roomJid: roomJid,
      items: [
        mox.XMLNode(
          tag: 'item',
          attributes: {
            'jid': jid,
            'affiliation': affiliation.xmlValue,
          },
        ),
      ],
    );
  }

  Future<void> changeRole({
    required String roomJid,
    required String nick,
    required OccupantRole role,
  }) async {
    await _sendAdminItems(
      roomJid: roomJid,
      items: [
        mox.XMLNode(
          tag: 'item',
          attributes: {
            'nick': nick,
            'role': role.xmlValue,
          },
        ),
      ],
    );
  }

  Future<List<MucAffiliationEntry>> fetchRoomMembers({
    required String roomJid,
  }) =>
      fetchRoomAffiliations(
        roomJid: roomJid,
        affiliation: OccupantAffiliation.member,
      );

  Future<List<MucAffiliationEntry>> fetchRoomAdmins({
    required String roomJid,
  }) =>
      fetchRoomAffiliations(
        roomJid: roomJid,
        affiliation: OccupantAffiliation.admin,
      );

  Future<List<MucAffiliationEntry>> fetchRoomOwners({
    required String roomJid,
  }) =>
      fetchRoomAffiliations(
        roomJid: roomJid,
        affiliation: OccupantAffiliation.owner,
      );

  Future<List<MucAffiliationEntry>> fetchRoomOutcasts({
    required String roomJid,
  }) =>
      fetchRoomAffiliations(
        roomJid: roomJid,
        affiliation: OccupantAffiliation.outcast,
      );

  Future<List<MucAffiliationEntry>> fetchRoomAffiliations({
    required String roomJid,
    required OccupantAffiliation affiliation,
  }) async {
    final normalizedRoom = _roomKey(roomJid);
    final queryXmlns = affiliation.isOwner ? _mucOwnerXmlns : _mucAdminXmlns;
    final request = mox.Stanza.iq(
      type: _iqTypeGet,
      to: normalizedRoom,
      children: [
        mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: queryXmlns,
          children: [
            mox.XMLNode(
              tag: _itemTag,
              attributes: {_affiliationAttr: affiliation.xmlValue},
            ),
          ],
        ),
      ],
    );
    final result = await _connection.sendStanza(
      mox.StanzaDetails(
        request,
        shouldEncrypt: false,
      ),
    );
    if (result == null) return const [];
    if (result.attributes[_iqTypeAttr]?.toString() != _iqTypeResult) {
      return const [];
    }
    final query = result.firstTag(_queryTag, xmlns: queryXmlns);
    if (query == null) return const [];
    final entries = query.findTags(_itemTag).map((item) {
      final jid = _normalizeBareJid(_readItemAttr(item, _jidAttr));
      final nick = _readItemAttr(item, _nickAttr);
      final roleAttr = _readItemAttr(item, _roleAttr);
      final itemAffiliation =
          _readItemAttr(item, _affiliationAttr) ?? affiliation.xmlValue;
      final resolvedAffiliation =
          OccupantAffiliation.fromString(itemAffiliation);
      final resolvedRole =
          roleAttr == null ? null : OccupantRole.fromString(roleAttr);
      final reason = _normalizeSubject(
        item.firstTag(_reasonTag)?.innerText(),
      );
      return MucAffiliationEntry(
        affiliation: resolvedAffiliation,
        jid: jid,
        nick: nick,
        role: resolvedRole,
        reason: reason,
      );
    }).toList(growable: false);
    _applyAffiliationEntries(roomJid: normalizedRoom, entries: entries);
    return List<MucAffiliationEntry>.unmodifiable(entries);
  }

  Future<void> leaveRoom(String roomJid) async {
    if (_connection.getManager<MUCManager>() case final manager?) {
      await manager.leaveRoom(mox.JID.fromString(roomJid));
      _forgetRoomPassword(roomJid: roomJid);
      _markRoomLeft(roomJid, statusCodes: const <String>{});
      await _removeBookmarkForRoom(roomJid: roomJid);
      return;
    }
    throw XmppMessageException();
  }

  Future<void> changeNickname({
    required String roomJid,
    required String nickname,
  }) async {
    final trimmed = nickname.trim();
    _roomNicknames[_roomKey(roomJid)] = trimmed;
    await _applyLocalNickname(roomJid: roomJid, nickname: trimmed);
    await joinRoom(
      roomJid: roomJid,
      nickname: trimmed,
      maxHistoryStanzas: 0,
    );
    final title = await _dbOpReturning<XmppDatabase, String?>(
      (db) async => (await db.getChat(roomJid))?.title,
    );
    await _upsertBookmarkForRoom(
      roomJid: roomJid,
      title: title,
      nickname: trimmed,
      autojoin: true,
      password: _passwordForRoom(roomJid),
    );
  }

  Future<void> acceptRoomInvite({
    required String roomJid,
    required String? roomName,
    String? nickname,
    String? password,
  }) async {
    final existingRoom = roomStateFor(roomJid);
    if (existingRoom?.myOccupantId != null) {
      return;
    }
    final title = await _resolveRoomTitle(
      roomJid: roomJid,
      providedTitle: roomName,
    );
    final resolvedNickname = _nickForRoom(nickname);
    final resolvedPassword = _normalizePassword(password);
    _rememberRoomPassword(roomJid: roomJid, password: resolvedPassword);
    await _dbOp<XmppDatabase>(
      (db) async {
        final existing = await db.getChat(roomJid);
        if (existing == null) {
          await db.createChat(
            Chat(
              jid: roomJid,
              title: title,
              type: ChatType.groupChat,
              myNickname: resolvedNickname,
              lastChangeTimestamp: DateTime.timestamp(),
              contactJid: roomJid,
            ),
          );
          return;
        }
        if (existing.type != ChatType.groupChat ||
            existing.title != title ||
            existing.myNickname != resolvedNickname ||
            existing.contactJid != roomJid) {
          await db.updateChat(existing.copyWith(
            type: ChatType.groupChat,
            title: title,
            myNickname: resolvedNickname,
            contactJid: roomJid,
          ));
        }
      },
    );
    await joinRoom(
      roomJid: roomJid,
      nickname: resolvedNickname,
      maxHistoryStanzas: _defaultMucJoinHistoryStanzas,
      password: resolvedPassword,
    );
    await _upsertBookmarkForRoom(
      roomJid: roomJid,
      title: title,
      nickname: resolvedNickname,
      autojoin: true,
      password: resolvedPassword,
    );
  }

  Future<String> _resolveRoomTitle({
    required String roomJid,
    required String? providedTitle,
  }) async {
    final trimmed = providedTitle?.trim();
    if (trimmed?.isNotEmpty == true) return trimmed!;

    final existing = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(roomJid),
    );
    final existingTitle = existing?.title.trim();
    if (existingTitle?.isNotEmpty == true) return existingTitle!;

    final mucManager = _connection.getManager<MUCManager>();
    if (mucManager != null && connectionState == ConnectionState.connected) {
      try {
        final result =
            await mucManager.queryRoomInformation(mox.JID.fromString(roomJid));
        if (!result.isType<mox.MUCError>()) {
          final info = result.get<mox.RoomInformation>();
          final discovered = info.name.trim();
          if (discovered.isNotEmpty) {
            return discovered;
          }
        }
      } on Exception {
        // Ignore discovery failures; fall back to identifier.
      }
    }

    return mox.JID.fromString(roomJid).local;
  }

  Future<void> discoverMucServiceHost() async {
    if (connectionState != ConnectionState.connected) return;
    final discoManager = _connection.getManager<mox.DiscoManager>();
    if (discoManager == null) return;
    final selfJid = _myJid;
    if (selfJid == null) return;
    try {
      final domainJid = selfJid.toDomain();
      final itemsResult = await discoManager.discoItemsQuery(domainJid);
      if (!itemsResult.isType<mox.StanzaError>()) {
        final items = itemsResult.get<List<mox.DiscoItem>>();
        for (final item in items) {
          final infoResult = await discoManager.discoInfoQuery(item.jid);
          if (infoResult.isType<mox.DiscoInfo>()) {
            final info = infoResult.get<mox.DiscoInfo>();
            if (info.features.contains(_mucDiscoFeature)) {
              setMucServiceHost(item.jid.toString());
              return;
            }
          }
        }
      }

      final domainInfo = await discoManager.discoInfoQuery(domainJid);
      if (domainInfo.isType<mox.DiscoInfo>()) {
        final info = domainInfo.get<mox.DiscoInfo>();
        if (info.features.contains(_mucDiscoFeature)) {
          setMucServiceHost(domainJid.toString());
        }
      }
    } on Exception {
      return;
    }
  }

  Future<List<mox.DiscoItem>> discoverRooms({String? serviceJid}) async {
    final discoManager = _connection.getManager<mox.DiscoManager>();
    if (discoManager == null) return const [];
    final resolvedService = serviceJid?.trim().isNotEmpty == true
        ? serviceJid!.trim()
        : mucServiceHost;
    try {
      final result = await discoManager
          .discoItemsQuery(mox.JID.fromString(resolvedService));
      if (result.isType<mox.StanzaError>()) {
        return const [];
      }
      final items = result.get<List<mox.DiscoItem>>();
      return List<mox.DiscoItem>.unmodifiable(items);
    } on Exception {
      return const [];
    }
  }

  Future<mox.RoomInformation?> fetchRoomInformation(String roomJid) async {
    final manager = _connection.getManager<MUCManager>();
    if (manager == null) return null;
    try {
      final result =
          await manager.queryRoomInformation(mox.JID.fromString(roomJid));
      if (result.isType<mox.MUCError>()) {
        return null;
      }
      return result.get<mox.RoomInformation>();
    } on Exception {
      return null;
    }
  }

  Future<mox.XMLNode?> _fetchRoomInfoForm(String roomJid) async {
    final stanza = mox.Stanza.iq(
      type: _iqTypeGet,
      to: roomJid,
      children: [
        mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _discoInfoXmlns,
        ),
      ],
    );
    final result = await _connection.sendStanza(
      mox.StanzaDetails(
        stanza,
        shouldEncrypt: false,
      ),
    );
    if (result == null) return null;
    if (result.attributes[_iqTypeAttr]?.toString() != _iqTypeResult) {
      return null;
    }
    final query = result.firstTag(_queryTag, xmlns: _discoInfoXmlns);
    final form = query?.firstTag(_dataFormTag, xmlns: _dataFormXmlns);
    return form;
  }

  Future<mox.XMLNode?> fetchRoomConfigurationForm(String roomJid) async {
    final stanza = mox.Stanza.iq(
      type: _iqTypeGet,
      to: roomJid,
      children: [
        mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucOwnerXmlns,
        ),
      ],
    );
    final result = await _connection.sendStanza(
      mox.StanzaDetails(
        stanza,
        shouldEncrypt: false,
      ),
    );
    if (result == null) return null;
    if (result.attributes[_iqTypeAttr]?.toString() != _iqTypeResult) {
      return null;
    }
    final query = result.firstTag(_queryTag, xmlns: _mucOwnerXmlns);
    final form = query?.firstTag('x', xmlns: mox.dataFormsXmlns);
    return form;
  }

  Future<bool> submitRoomConfiguration({
    required String roomJid,
    required mox.XMLNode form,
  }) async {
    final stanza = mox.Stanza.iq(
      type: _iqTypeSet,
      to: roomJid,
      children: [
        mox.XMLNode.xmlns(
          tag: _queryTag,
          xmlns: _mucOwnerXmlns,
          children: [form],
        ),
      ],
    );
    final result = await _connection.sendStanza(
      mox.StanzaDetails(
        stanza,
        shouldEncrypt: false,
      ),
    );
    if (result == null) return false;
    return result.attributes[_iqTypeAttr]?.toString() == _iqTypeResult;
  }

  Future<void> setRoomSubject({
    required String roomJid,
    String? subject,
  }) async {
    final resolvedSubject = subject?.trim() ?? '';
    final stanza = mox.Stanza.message(
      to: roomJid,
      type: _messageTypeGroupchat,
      children: [
        mox.XMLNode(
          tag: _subjectTag,
          text: resolvedSubject,
        ),
      ],
    );
    await _connection.sendStanza(
      mox.StanzaDetails(
        stanza,
        awaitable: false,
      ),
    );
  }

  Future<void> applyMucBookmarks(List<MucBookmark> bookmarks) async {
    if (bookmarks.isEmpty) return;
    await _upsertChatsFromBookmarks(bookmarks);
    unawaited(refreshRoomAvatars(bookmarks));

    for (final bookmark in bookmarks) {
      final roomJid = bookmark.roomBare.toString();
      final password = _normalizePassword(bookmark.password);
      if (password != null) {
        _rememberRoomPassword(roomJid: roomJid, password: password);
      }
      if (!bookmark.autojoin) continue;
      if (connectionState != ConnectionState.connected) return;

      final nickname = bookmark.nick?.trim();
      if (nickname?.isNotEmpty == true) {
        _roomNicknames[_roomKey(roomJid)] = nickname!;
      }

      try {
        await ensureJoined(
          roomJid: roomJid,
          nickname: nickname,
          maxHistoryStanzas: _defaultMucJoinHistoryStanzas,
          password: password,
        );
      } on XmppAbortedException {
        return;
      } on Exception {
        _mucLog.fine('Failed to auto-join one or more bookmarked rooms.');
      }
    }
  }

  Future<void> applyMucBookmarksSnapshot(
    PubSubFetchResult<MucBookmark> snapshot,
  ) async {
    if (!snapshot.isSuccess) return;
    final bookmarks = snapshot.items;
    await applyMucBookmarks(bookmarks);
    if (snapshot.isComplete) {
      await _reconcileMucBookmarkRemovals(bookmarks);
    }
  }

  Future<void> _reconcileMucBookmarkRemovals(
    List<MucBookmark> bookmarks,
  ) async {
    final knownRooms = bookmarks
        .map((bookmark) => bookmark.roomBare.toBare().toString())
        .toSet();
    final toRemove = <String>{};
    await _dbOp<XmppDatabase>(
      (db) async {
        final chats = await db.getChats(
          start: _mucSnapshotStart,
          end: _mucSnapshotEnd,
        );
        for (final chat in chats) {
          if (!_isSnapshotRoomChat(chat)) continue;
          final roomBare = _normalizeBareJid(chat.jid);
          if (roomBare == null || roomBare.isEmpty) continue;
          if (knownRooms.contains(roomBare)) continue;
          toRemove.add(roomBare);
        }
      },
      awaitDatabase: true,
    );

    for (final roomBare in toRemove) {
      try {
        await _applyBookmarkRetraction(mox.JID.fromString(roomBare));
      } on Exception {
        // Ignore leave failures when applying snapshot removals.
      }
    }
  }

  Future<void> syncMucBookmarksOnLogin() async {
    await syncMucBookmarksSnapshot();
  }

  Future<List<MucBookmark>> syncMucBookmarksSnapshot() async {
    if (_mucBookmarksSyncInFlight) {
      return _emptyMucSnapshot;
    }
    if (connectionState != ConnectionState.connected) {
      return _emptyMucSnapshot;
    }
    _mucBookmarksSyncInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) {
        return _emptyMucSnapshot;
      }
      final support = await refreshPubSubSupport();
      if (!support.canUseBookmarks2) {
        return _emptyMucSnapshot;
      }
      final bookmarksManager = _connection.getManager<BookmarksManager>();
      if (bookmarksManager == null) {
        return _emptyMucSnapshot;
      }

      await bookmarksManager.ensureNode();
      await bookmarksManager.subscribe();
      final snapshot = await bookmarksManager.fetchAllWithStatus();
      await applyMucBookmarksSnapshot(snapshot);
      return snapshot.items;
    } on XmppAbortedException {
      return _emptyMucSnapshot;
    } finally {
      _mucBookmarksSyncInFlight = false;
    }
  }

  Future<void> refreshRoomAvatars(List<MucBookmark> bookmarks) async {
    if (connectionState != ConnectionState.connected) return;
    if (bookmarks.isEmpty) return;
    if (this is! AvatarService) return;

    final rooms = <String>{};
    for (final bookmark in bookmarks) {
      final roomJid = bookmark.roomBare.toBare().toString().trim();
      if (roomJid.isEmpty) continue;
      rooms.add(roomJid);
    }

    for (final roomJid in rooms) {
      await _refreshRoomAvatar(roomJid);
    }
  }

  Future<void> _refreshRoomAvatar(String roomJid) async {
    if (this is! AvatarService) return;
    final normalizedRoom = _roomKey(roomJid);
    try {
      final payload = await _fetchRoomAvatarPayload(normalizedRoom);
      if (payload.data == null || payload.data!.isEmpty) return;
      final decoded = _decodeRoomAvatarData(payload.data!);
      if (decoded == null) return;
      await (this as AvatarService).storeAvatarBytesForJid(
        jid: normalizedRoom,
        bytes: decoded,
        hash: payload.hash,
      );
    } on Exception catch (error, stackTrace) {
      _mucLog.fine(_roomAvatarStoreFailedLog, error, stackTrace);
    }
  }

  Future<_RoomAvatarPayload> _fetchRoomAvatarPayload(String roomJid) async {
    final infoForm = await _fetchRoomInfoForm(roomJid);
    final infoPayload = _roomAvatarPayloadFromForm(infoForm);
    if (infoPayload.data?.isNotEmpty == true) return infoPayload;
    final configForm = await fetchRoomConfigurationForm(roomJid);
    final configPayload = _roomAvatarPayloadFromForm(configForm);
    if (configPayload.data?.isNotEmpty == true) {
      return _RoomAvatarPayload(
        data: configPayload.data,
        hash: configPayload.hash ?? infoPayload.hash,
      );
    }
    return infoPayload;
  }

  _RoomAvatarPayload _roomAvatarPayloadFromForm(mox.XMLNode? form) {
    if (form == null) return const _RoomAvatarPayload();
    if (form.tag != _dataFormTag) return const _RoomAvatarPayload();
    if (form.attributes['xmlns']?.toString() != _dataFormXmlns) {
      return const _RoomAvatarPayload();
    }
    final fields = form.findTags(_fieldTag);
    if (fields.isEmpty) return const _RoomAvatarPayload();
    if (!_isRoomFormType(fields)) return const _RoomAvatarPayload();
    return _roomAvatarPayloadFromFields(fields);
  }

  _RoomAvatarPayload _roomAvatarPayloadFromFields(
    Iterable<mox.XMLNode> fields,
  ) {
    String? data;
    String? hash;
    for (final field in fields) {
      final varName = _fieldVarName(field);
      if (varName == null) continue;
      final values = _fieldValues(field);
      if (values.isEmpty) continue;
      final lowerVar = varName.toLowerCase();
      if (!lowerVar.contains(_avatarFieldToken)) continue;
      if (lowerVar.contains(_avatarHashToken)) {
        final value = _normalizeRoomAvatarValue(values.first);
        if (value == null) continue;
        hash = value;
        continue;
      }
      final joined = _normalizeRoomAvatarValue(values.join());
      if (joined == null) continue;
      data ??= joined;
    }
    return _RoomAvatarPayload(data: data, hash: hash);
  }

  String? _fieldVarName(mox.XMLNode field) {
    final raw = field.attributes[_varAttr]?.toString();
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _fieldValue(mox.XMLNode field) {
    final values = _fieldValues(field);
    if (values.isEmpty) return null;
    return values.first;
  }

  List<String> _fieldValues(mox.XMLNode field) {
    final values = field.findTags(_valueTag);
    if (values.isEmpty) return const [];
    return values
        .map((value) => value.innerText().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  bool _isRoomFormType(Iterable<mox.XMLNode> fields) {
    String? formType;
    for (final field in fields) {
      if (_fieldVarName(field) != _formTypeFieldVar) continue;
      formType = _normalizeRoomAvatarValue(_fieldValue(field));
      break;
    }
    if (formType == null || formType.isEmpty) return true;
    return formType == _mucRoomInfoFormType ||
        formType == _mucRoomConfigFormType;
  }

  String? _normalizeRoomAvatarValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Uint8List? _decodeRoomAvatarData(String value) {
    final normalized = _normalizeRoomAvatarValue(value);
    if (normalized == null) return null;
    var raw = normalized;
    if (normalized.startsWith(_dataUriPrefix)) {
      final index = normalized.indexOf(_dataUriBase64Delimiter);
      if (index == -1) return null;
      raw = normalized.substring(
        index + _dataUriBase64Delimiter.length,
      );
    }
    final trimmed = raw.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.isEmpty) return null;
    if (trimmed.length > AvatarService._maxAvatarBase64Length) return null;
    try {
      final bytes = base64Decode(trimmed);
      if (bytes.isEmpty) return null;
      if (bytes.length > AvatarService._maxAvatarBytes) return null;
      return bytes;
    } on FormatException {
      _mucLog.fine(_roomAvatarDecodeFailedLog);
      return null;
    }
  }

  Future<void> _upsertChatsFromBookmarks(List<MucBookmark> bookmarks) async {
    for (final bookmark in bookmarks) {
      final roomJid = bookmark.roomBare.toBare().toString();
      if (roomJid.isEmpty) continue;
      final trimmedTitle = bookmark.name?.trim();
      final title = trimmedTitle?.isNotEmpty == true
          ? trimmedTitle!
          : mox.JID.fromString(roomJid).local;
      final trimmedNick = bookmark.nick?.trim();
      final nickname =
          trimmedNick?.isNotEmpty == true ? trimmedNick! : _nickForRoom(null);

      try {
        await _dbOp<XmppDatabase>(
          (db) async {
            final existing = await db.getChat(roomJid);
            if (existing == null) {
              await db.createChat(
                Chat(
                  jid: roomJid,
                  title: title.isNotEmpty ? title : roomJid,
                  type: ChatType.groupChat,
                  myNickname: nickname,
                  lastChangeTimestamp: DateTime.timestamp(),
                  contactJid: roomJid,
                ),
              );
              return;
            }

            final shouldUpdateTitle =
                title.isNotEmpty && existing.title.trim() != title;
            final shouldUpdateNickname = nickname.isNotEmpty &&
                (existing.myNickname ?? '').trim() != nickname;
            final shouldUpdateType = existing.type != ChatType.groupChat;
            final shouldUpdateContactJid = existing.contactJid != roomJid;

            if (!shouldUpdateTitle &&
                !shouldUpdateNickname &&
                !shouldUpdateType &&
                !shouldUpdateContactJid) {
              return;
            }

            await db.updateChat(
              existing.copyWith(
                type: ChatType.groupChat,
                title: shouldUpdateTitle ? title : existing.title,
                myNickname:
                    shouldUpdateNickname ? nickname : existing.myNickname,
                contactJid: roomJid,
              ),
            );
          },
          awaitDatabase: true,
        );
      } on XmppAbortedException {
        return;
      } on Exception {
        _mucLog.fine('Failed to update room list from bookmarks.');
      }
    }
  }

  Future<void> _upsertBookmarkForRoom({
    required String roomJid,
    required bool autojoin,
    String? title,
    String? nickname,
    String? password,
  }) async {
    final manager = _connection.getManager<BookmarksManager>();
    if (manager == null) return;
    try {
      final roomBare = mox.JID.fromString(roomJid).toBare();
      final normalizedPassword = _normalizePassword(password);
      await manager.upsertBookmark(
        MucBookmark(
          roomBare: roomBare,
          name: title?.trim().isNotEmpty == true ? title?.trim() : null,
          autojoin: autojoin,
          nick: nickname?.trim().isNotEmpty == true ? nickname?.trim() : null,
          password: normalizedPassword,
        ),
      );
    } on XmppAbortedException {
      return;
    } on Exception {
      _mucLog.fine('Failed to update bookmarks.');
    }
  }

  Future<void> _removeBookmarkForRoom({required String roomJid}) async {
    final manager = _connection.getManager<BookmarksManager>();
    if (manager == null) return;
    try {
      final roomBare = mox.JID.fromString(roomJid).toBare();
      await manager.removeBookmark(roomBare);
    } on XmppAbortedException {
      return;
    } on Exception {
      _mucLog.fine('Failed to remove a room bookmark.');
    }
  }

  Future<void> _applyBookmarkRetraction(mox.JID roomBare) async {
    final roomJid = roomBare.toBare().toString();
    if (roomJid.isEmpty) return;
    _forgetRoomPassword(roomJid: roomJid);
    if (!_leftRooms.contains(_roomKey(roomJid))) {
      try {
        final manager = _connection.getManager<MUCManager>();
        if (manager != null) {
          await manager.leaveRoom(mox.JID.fromString(roomJid));
        }
      } on Exception {
        // Ignore leave failures when applying bookmark updates.
      }
    }
    _markRoomLeft(roomJid, statusCodes: const <String>{});
    await _dbOp<XmppDatabase>(
      (db) async {
        final chat = await db.getChat(roomJid);
        if (chat == null) return;
        if (!chat.archived) {
          await db.updateChat(chat.copyWith(archived: true));
        }
      },
      awaitDatabase: true,
    );
  }

  void _handleSelfPresence(MucSelfPresenceEvent event) {
    final roomJid = _roomKey(event.roomJid);
    if (!event.isAvailable && !event.isNickChange) {
      _markRoomLeft(
        roomJid,
        statusCodes: event.statusCodes,
        reason: event.reason,
      );
      return;
    }

    final nextNick = event.isNickChange && event.newNick?.isNotEmpty == true
        ? event.newNick!.trim()
        : event.nick.trim();
    if (nextNick.isEmpty) return;

    _markRoomJoined(roomJid);
    _roomNicknames[roomJid] = nextNick;

    final occupantJid = event.isNickChange && event.newNick?.isNotEmpty == true
        ? '$roomJid/$nextNick'
        : event.occupantJid;

    _upsertOccupant(
      roomJid: roomJid,
      occupantId: occupantJid,
      nick: nextNick,
      realJid: _myJid?.toBare().toString(),
      affiliation: OccupantAffiliation.fromString(event.affiliation),
      role: OccupantRole.fromString(event.role),
      isPresent: true,
    );
    _applySelfPresenceStatus(
      roomJid: roomJid,
      statusCodes: event.statusCodes,
      reason: event.reason,
    );
    if (event.statusCodes.contains(mucStatusConfigurationChanged)) {
      unawaited(_refreshRoomAvatar(roomJid));
    }

    unawaited(_dbOp<XmppDatabase>(
      (db) async {
        final chat = await db.getChat(roomJid);
        if (chat != null && chat.myNickname != nextNick) {
          await db.updateChat(chat.copyWith(myNickname: nextNick));
        }
      },
      awaitDatabase: true,
    ));
  }

  void _handleOwnDataChanged({
    required mox.JID roomJid,
    required String nick,
    required mox.Affiliation affiliation,
    required mox.Role role,
  }) {
    _handleSelfPresence(
      MucSelfPresenceEvent(
        roomJid: roomJid.toBare().toString(),
        occupantJid: roomJid.toBare().withResource(nick).toString(),
        nick: nick,
        affiliation: affiliation.value,
        role: role.value,
        isAvailable: true,
        isNickChange: false,
        statusCodes: const <String>{},
        reason: null,
      ),
    );
  }

  void _handleMemberUpsert(mox.JID roomJid, mox.RoomMember member) {
    final key = roomJid.toBare().toString();
    if (_leftRooms.contains(_roomKey(key))) return;
    final occupantJid = '${_roomKey(key)}/${member.nick}';
    _upsertOccupant(
      roomJid: key,
      occupantId: occupantJid,
      nick: member.nick,
      affiliation: member.affiliation.toOccupantAffiliation,
      role: member.role.toOccupantRole,
      isPresent: true,
    );
  }

  void _handleMemberLeft(mox.JID roomJid, String nick) {
    final key = roomJid.toBare().toString();
    if (_leftRooms.contains(_roomKey(key))) return;
    final occupantJid = '${_roomKey(key)}/$nick';
    removeOccupant(roomJid: key, occupantId: occupantJid);
  }

  void _handleMemberNickChanged(
    mox.JID roomJid,
    String oldNick,
    String newNick,
  ) {
    final key = _roomKey(roomJid.toString());
    if (_leftRooms.contains(key)) return;

    final oldId = '$key/$oldNick';
    final newId = '$key/$newNick';
    final existing = _roomStates[key];
    final occupant = existing?.occupants[oldId];
    if (occupant == null) {
      _upsertOccupant(
        roomJid: key,
        occupantId: newId,
        nick: newNick,
        isPresent: true,
      );
      return;
    }

    removeOccupant(roomJid: key, occupantId: oldId);
    _upsertOccupant(
      roomJid: key,
      occupantId: newId,
      nick: newNick,
      realJid: occupant.realJid,
      affiliation: occupant.affiliation,
      role: occupant.role,
      isPresent: occupant.isPresent,
    );
  }

  void trackOccupantsFromMessages(String roomJid, Iterable<Message> messages) {
    final key = _roomKey(roomJid);
    if (_leftRooms.contains(key)) return;
    final selfOccupantId = _roomStates[key]?.myOccupantId;
    final preferredSelfNick = _roomNicknames[key];
    for (final message in messages) {
      final nick = _nickFromSender(message.senderJid);
      if (nick == null) continue;
      final occupantId = '$key/$nick';
      final resolvedNick = selfOccupantId != null &&
              occupantId == selfOccupantId &&
              preferredSelfNick?.isNotEmpty == true
          ? preferredSelfNick!
          : nick;
      _upsertOccupant(
        roomJid: roomJid,
        occupantId: occupantId,
        nick: resolvedNick,
      );
    }
  }

  void handleMucIdentifiersFromMessage(
    mox.MessageEvent event,
    Message message,
  ) {
    if (_leftRooms.contains(_roomKey(message.chatJid))) return;
    final nick = event.from.resource;
    if (nick.isEmpty) return;
    final occupantId = '${_roomKey(message.chatJid)}/$nick';
    _upsertOccupant(
      roomJid: message.chatJid,
      occupantId: occupantId,
      nick: nick,
    );
  }

  void updateOccupantFromPresence({
    required String roomJid,
    required String occupantId,
    required String nick,
    String? realJid,
    OccupantAffiliation? affiliation,
    OccupantRole? role,
    bool isPresent = true,
  }) {
    if (_leftRooms.contains(_roomKey(roomJid))) return;
    _upsertOccupant(
      roomJid: roomJid,
      occupantId: occupantId,
      nick: nick,
      realJid: realJid,
      affiliation: affiliation,
      role: role,
      isPresent: isPresent,
    );
  }

  void removeOccupant({
    required String roomJid,
    required String occupantId,
  }) {
    final key = _roomKey(roomJid);
    final existing = _roomStates[key];
    if (existing == null) return;
    if (!existing.occupants.containsKey(occupantId)) return;
    final updated = Map<String, Occupant>.of(existing.occupants)
      ..remove(occupantId);
    final room = existing.copyWith(
      occupants: updated,
      myOccupantId:
          existing.myOccupantId == occupantId ? null : existing.myOccupantId,
    );
    _roomStates[key] = room;
    _roomStreams[key]?.add(room);
  }

  Future<void> _sendAdminItems({
    required String roomJid,
    required List<mox.XMLNode> items,
  }) async {
    if (_connection.getManager<MUCManager>() case final manager?) {
      await manager.sendAdminIq(roomJid: roomJid, items: items);
      return;
    }
    throw XmppMessageException();
  }

  String _nickForRoom(String? nickname) {
    final trimmed = nickname?.trim();
    if (trimmed?.isNotEmpty == true) return trimmed!;
    if (username?.isNotEmpty == true) return username!;
    final myLocal = _myJid?.local;
    if (myLocal != null && myLocal.isNotEmpty) return myLocal;
    return 'me-${generateRandomString(length: 5)}';
  }

  String _roomKey(String roomJid) =>
      mox.JID.fromString(roomJid).toBare().toString();

  String _slugify(String input) {
    final collapsed = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp('-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (collapsed.isNotEmpty) return collapsed;
    return 'room-${generateRandomString(length: 6)}';
  }

  String? _nickFromSender(String sender) {
    if (sender.isEmpty) return null;
    try {
      final jid = mox.JID.fromString(sender);
      final resource = jid.resource;
      if (resource.isEmpty) return null;
      if (jid.toBare().toString() == jid.toString()) return null;
      return resource;
    } on Exception {
      return null;
    }
  }

  String? _readItemAttr(mox.XMLNode item, String key) {
    final raw = item.attributes[key]?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  bool _isSnapshotRoomChat(Chat chat) {
    if (chat.type != ChatType.groupChat) return false;
    if (chat.deltaChatId != null) return false;
    final roomBare = _normalizeBareJid(chat.jid);
    if (roomBare == null || roomBare.isEmpty) return false;
    try {
      return mox.JID.fromString(roomBare).domain == mucServiceHost;
    } on Exception {
      return false;
    }
  }

  String? _normalizeBareJid(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      return mox.JID.fromString(trimmed).toBare().toString();
    } on Exception {
      return null;
    }
  }

  bool _sameBareJid(String left, String right) {
    final leftBare = _normalizeBareJid(left);
    final rightBare = _normalizeBareJid(right);
    if (leftBare == null || rightBare == null) return false;
    return leftBare == rightBare;
  }

  void _applyAffiliationEntries({
    required String roomJid,
    required List<MucAffiliationEntry> entries,
  }) {
    if (entries.isEmpty) return;
    final key = _roomKey(roomJid);
    if (_leftRooms.contains(key)) return;
    final existing = _roomStates[key];
    if (existing == null) return;
    final updated = Map<String, Occupant>.of(existing.occupants);
    for (final entry in entries) {
      final occupantId = _occupantIdForAffiliationEntry(
        roomKey: key,
        occupants: updated,
        entry: entry,
      );
      if (occupantId == null) continue;
      final occupant = updated[occupantId];
      if (occupant == null) continue;
      updated[occupantId] = occupant.copyWith(
        affiliation: entry.affiliation,
        role: entry.role ?? occupant.role,
        realJid: occupant.realJid ?? entry.jid,
      );
    }
    final room = existing.copyWith(occupants: updated);
    _roomStates[key] = room;
    _roomStreams[key]?.add(room);
  }

  String? _occupantIdForAffiliationEntry({
    required String roomKey,
    required Map<String, Occupant> occupants,
    required MucAffiliationEntry entry,
  }) {
    final nick = entry.nick?.trim();
    if (nick?.isNotEmpty == true) {
      final occupantId = '$roomKey/$nick';
      if (occupants.containsKey(occupantId)) {
        return occupantId;
      }
    }

    final jid = entry.jid;
    if (jid == null || jid.isEmpty) return null;
    for (final occupant in occupants.values) {
      final realJid = occupant.realJid;
      if (realJid == null) continue;
      if (_sameBareJid(realJid, jid)) {
        return occupant.occupantId;
      }
    }
    return null;
  }

  RoomState _upsertOccupant({
    required String roomJid,
    required String occupantId,
    required String nick,
    String? realJid,
    OccupantAffiliation? affiliation,
    OccupantRole? role,
    bool? isPresent,
  }) {
    final key = _roomKey(roomJid);
    final existing =
        _roomStates[key] ?? RoomState(roomJid: key, occupants: const {});
    final updated = Map<String, Occupant>.of(existing.occupants);
    final current = updated[occupantId];
    final isNickMatch =
        nick.toLowerCase() == (_roomNicknames[key]?.toLowerCase() ?? '');
    final resolvedRealJid = realJid ?? current?.realJid;
    final resolvedAffiliation =
        affiliation ?? current?.affiliation ?? OccupantAffiliation.none;
    final next = (current ??
            Occupant(
              occupantId: occupantId,
              nick: nick,
              isPresent: isPresent ?? true,
            ))
        .copyWith(
      nick: nick,
      realJid: resolvedRealJid,
      affiliation: resolvedAffiliation,
      role: role ?? current?.role,
      isPresent: isPresent ?? current?.isPresent ?? true,
    );
    updated[occupantId] = next;
    var myOccupantId = existing.myOccupantId;
    final shouldMarkSelf = _isSelfOccupant(next) || isNickMatch;
    if (shouldMarkSelf) {
      _roomNicknames[key] = nick;
      if (resolvedRealJid != null) {
        updated.removeWhere(
          (key, occupant) =>
              key != occupantId && occupant.realJid == resolvedRealJid,
        );
      }
      if (myOccupantId != null && myOccupantId != occupantId) {
        updated.remove(myOccupantId);
      }
      myOccupantId = occupantId;
    }
    final room = existing.copyWith(
      occupants: updated,
      myOccupantId: myOccupantId,
    );
    _roomStates[key] = room;
    _roomStreams[key]?.add(room);
    return room;
  }

  bool _isSelfOccupant(Occupant occupant) {
    if (occupant.realJid == null) return false;
    return _isSelfRealJid(occupant.realJid!);
  }

  bool _isSelfRealJid(String jid) {
    final self = _myJid?.toBare().toString();
    if (self == null) return false;
    return mox.JID.fromString(jid).toBare().toString() == self;
  }

  Future<void> _sendInviteNotice({
    required String roomJid,
    required String inviteeJid,
    String? reason,
    String? password,
  }) async {
    final myBare = _myJid?.toBare().toString();
    if (myBare == null) throw XmppMessageException();
    final chat =
        await _dbOpReturning<XmppDatabase, Chat?>((db) => db.getChat(roomJid));
    final roomName = chat?.title;
    final resolvedPassword =
        _normalizePassword(password) ?? _passwordForRoom(roomJid);
    final token = generateRandomString(length: 10);
    final payload = <String, dynamic>{
      'roomJid': roomJid,
      'token': token,
      'inviter': myBare,
      'invitee': inviteeJid,
      if (reason?.isNotEmpty == true) 'reason': reason,
      if (roomName?.isNotEmpty == true) 'roomName': roomName,
      if (resolvedPassword?.isNotEmpty == true) 'password': resolvedPassword,
    };
    const displayLine = 'You have been invited to a group chat';
    final displayBody =
        reason?.isNotEmpty == true ? '$displayLine\n$reason' : displayLine;
    final message = Message(
      stanzaID: _connection.generateId(),
      senderJid: myBare,
      chatJid: inviteeJid,
      body: displayBody,
      timestamp: DateTime.timestamp(),
      pseudoMessageType: PseudoMessageType.mucInvite,
      pseudoMessageData: payload,
    );
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessage(message, chatType: ChatType.chat),
    );
    final inviteExtensions = <mox.StanzaHandlerExtension>[
      DirectMucInviteData(
        roomJid: roomJid,
        reason: reason,
        password: resolvedPassword,
      ),
      AxiMucInvitePayload(
        roomJid: roomJid,
        token: token,
        inviter: myBare,
        invitee: inviteeJid,
        roomName: roomName,
        reason: reason,
        password: resolvedPassword,
      ),
    ];
    final stanza = mox.MessageEvent(
      mox.JID.fromString(myBare),
      mox.JID.fromString(inviteeJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageBodyData(displayBody),
        mox.MessageIdData(message.stanzaID),
        const mox.MarkableData(true),
        mox.ChatState.active,
        ...inviteExtensions,
      ]),
      id: message.stanzaID,
      type: _messageTypeNormal,
    );
    final sent = await _connection.sendMessage(stanza);
    if (!sent) throw XmppMessageException();
  }

  Future<void> revokeInvite({
    required String roomJid,
    required String inviteeJid,
    required String token,
  }) async {
    final myBare = _myJid?.toBare().toString();
    if (myBare == null) throw XmppMessageException();
    final chat = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(roomJid),
    );
    final roomName = chat?.title;
    final payload = <String, dynamic>{
      'roomJid': roomJid,
      'token': token,
      'inviter': myBare,
      'invitee': inviteeJid,
      'revoked': true,
      if (roomName?.isNotEmpty == true) 'roomName': roomName,
    };
    final displayLine = roomName?.isNotEmpty == true
        ? 'Invite revoked for $roomName'
        : 'Invite revoked';
    final displayBody = displayLine;
    final message = Message(
      stanzaID: _connection.generateId(),
      senderJid: myBare,
      chatJid: inviteeJid,
      body: displayBody,
      timestamp: DateTime.timestamp(),
      pseudoMessageType: PseudoMessageType.mucInviteRevocation,
      pseudoMessageData: payload,
    );
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessage(message, chatType: ChatType.chat),
    );
    final revokeExtensions = <mox.StanzaHandlerExtension>[
      AxiMucInvitePayload(
        roomJid: roomJid,
        token: token,
        inviter: myBare,
        invitee: inviteeJid,
        roomName: roomName,
        revoked: true,
      ),
    ];
    final stanza = mox.MessageEvent(
      mox.JID.fromString(myBare),
      mox.JID.fromString(inviteeJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageBodyData(displayBody),
        mox.MessageIdData(message.stanzaID),
        const mox.MarkableData(true),
        mox.ChatState.active,
        ...revokeExtensions,
      ]),
      id: message.stanzaID,
      type: _messageTypeNormal,
    );
    final sent = await _connection.sendMessage(stanza);
    if (!sent) throw XmppMessageException();
  }

  Future<void> _applyLocalNickname({
    required String roomJid,
    required String nickname,
  }) async {
    final key = _roomKey(roomJid);
    _roomNicknames[key] = nickname;
    final existing = _roomStates[key];
    final myOccupantId = existing?.myOccupantId;
    final currentOccupant =
        myOccupantId == null ? null : existing?.occupants[myOccupantId];
    final occupantId = '$key/$nickname';
    _upsertOccupant(
      roomJid: roomJid,
      occupantId: occupantId,
      nick: nickname,
      realJid: currentOccupant?.realJid ?? _myJid?.toBare().toString(),
      affiliation: currentOccupant?.affiliation,
      role: currentOccupant?.role,
      isPresent: currentOccupant?.isPresent ?? true,
    );
    await _dbOp<XmppDatabase>(
      (db) async {
        final chat = await db.getChat(roomJid);
        if (chat != null && chat.myNickname != nickname) {
          await db.updateChat(chat.copyWith(myNickname: nickname));
        }
      },
    );
  }

  Future<void> seedDummyRoomData(String roomJid) async {
    final key = _roomKey(roomJid);
    if (!demoOfflineMode) return;
    if (_leftRooms.contains(key)) return;
    if (_seededDummyRooms.contains(key)) return;
    final messageCount = await _dbOpReturning<XmppDatabase, int>(
      (db) => db.countChatMessages(
        roomJid,
        filter: MessageTimelineFilter.allWithContact,
      ),
    );
    if (messageCount > 0) return;
    final rememberedNick = _roomNicknames[key]?.trim();
    var resolvedNick =
        rememberedNick?.isNotEmpty == true ? rememberedNick : null;
    if (resolvedNick == null) {
      final chat = await _dbOpReturning<XmppDatabase, Chat?>(
        (db) => db.getChat(roomJid),
      );
      final storedNick = chat?.myNickname?.trim();
      if (storedNick?.isNotEmpty == true) {
        resolvedNick = storedNick;
      }
    }
    final myNick = resolvedNick ?? _nickForRoom(null);
    await _applyLocalNickname(roomJid: roomJid, nickname: myNick);

    const dummyMembers = [
      (
        id: 'sam',
        name: 'Sam',
        affiliation: OccupantAffiliation.owner,
        role: OccupantRole.participant,
        message: 'Giving the room a quick look before we roll it out.',
      ),
      (
        id: 'cora',
        name: 'Cora',
        affiliation: OccupantAffiliation.admin,
        role: OccupantRole.none,
        message: 'I can help if anything looks off in this room.',
      ),
      (
        id: 'pavel',
        name: 'Pavel',
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.moderator,
        message: 'Toggling the moderator tools—do they show up for you?',
      ),
      (
        id: 'veda',
        name: 'Veda',
        affiliation: OccupantAffiliation.none,
        role: OccupantRole.visitor,
        message: 'Passing through as a visitor to check the roster.',
      ),
    ];

    for (final member in dummyMembers) {
      final occupantId = '$key/${member.name}';
      _upsertOccupant(
        roomJid: roomJid,
        occupantId: occupantId,
        nick: member.name,
        realJid: '${member.id}@example.test',
        affiliation: member.affiliation,
        role: member.role,
        isPresent: true,
      );
    }

    final now = DateTime.timestamp();
    final idPrefix =
        base64Url.encode(utf8.encode(key)).replaceAll('=', '').toLowerCase();
    for (var index = 0; index < dummyMembers.length; index++) {
      final member = dummyMembers[index];
      final occupantId = '$key/${member.name}';
      final senderJid = '$roomJid/${member.name}';
      final stanzaID = 'dummy-$idPrefix-$index';
      final existing = await _dbOpReturning<XmppDatabase, Message?>(
        (db) => db.getMessageByStanzaID(stanzaID),
      );
      if (existing != null) continue;
      final message = Message(
        stanzaID: stanzaID,
        senderJid: senderJid,
        chatJid: roomJid,
        body: member.message,
        timestamp:
            now.subtract(Duration(minutes: (dummyMembers.length - index) * 2)),
        occupantID: occupantId,
      );
      await _dbOp<XmppDatabase>(
        (db) => db.saveMessage(message, chatType: ChatType.groupChat),
      );
    }

    _seededDummyRooms.add(key);
  }
}
