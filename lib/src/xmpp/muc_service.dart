part of 'package:axichat/src/xmpp/xmpp_service.dart';

const _mucUserXmlns = 'http://jabber.org/protocol/muc#user';
const _mucAdminXmlns = 'http://jabber.org/protocol/muc#admin';
const _occupantIdXmlns = 'urn:xmpp:occupant-id:0';

mixin MucService on XmppBase, BaseStreamService {
  final _mucLog = Logger('MucService');
  final _roomStates = <String, RoomState>{};
  final _roomStreams = <String, StreamController<RoomState>>{};
  final _roomNicknames = <String, String>{};
  final _leftRooms = <String>{};
  final _createdRooms = <String>{};
  final _seededDummyRooms = <String>{};
  String? _mucServiceHost;

  String get mucServiceHost =>
      _mucServiceHost ?? 'conference.${_myJid?.domain ?? 'example.com'}';

  void setMucServiceHost(String? host) {
    _mucServiceHost = host;
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

  RoomState? roomStateFor(String roomJid) => _roomStates[_roomKey(roomJid)];

  bool hasLeftRoom(String roomJid) => _leftRooms.contains(_roomKey(roomJid));

  void _markRoomJoined(String roomJid) {
    _leftRooms.remove(_roomKey(roomJid));
  }

  void _markRoomLeft(String roomJid) {
    final key = _roomKey(roomJid);
    _leftRooms.add(key);
    final room = RoomState(
      roomJid: key,
      occupants: const {},
      myOccupantId: null,
    );
    _roomStates[key] = room;
    _roomStreams[key]?.add(room);
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
    _createdRooms.add(_roomKey(roomJid));

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
    return roomJid;
  }

  Future<void> joinRoom({
    required String roomJid,
    required String nickname,
    int maxHistoryStanzas = 0,
  }) async {
    _markRoomJoined(roomJid);
    _roomNicknames[_roomKey(roomJid)] = nickname;
    if (_connection.getManager<mox.MUCManager>() case final manager?) {
      if (manager is MUCManager) {
        await manager.joinRoomWithStrings(
          jid: roomJid,
          nickname: nickname,
          maxHistoryStanzas: maxHistoryStanzas,
        );
        return;
      }
      await manager.joinRoom(
        mox.JID.fromString(roomJid),
        nickname,
        maxHistoryStanzas: maxHistoryStanzas,
      );
      return;
    }
    throw XmppMessageException();
  }

  Future<void> ensureJoined({
    required String roomJid,
    String? nickname,
    int maxHistoryStanzas = 0,
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
    );
    await _applyLocalNickname(roomJid: roomJid, nickname: resolvedNick);
  }

  Future<void> inviteUserToRoom({
    required String roomJid,
    required String inviteeJid,
    String? reason,
  }) async {
    await _sendInviteNotice(
      roomJid: roomJid,
      inviteeJid: inviteeJid,
      reason: reason,
    );
    if (_connection.getManager<mox.MUCManager>() case final manager?) {
      if (manager is MUCManager) {
        await manager.sendMediatedInvite(
          roomJid: roomJid,
          inviteeJid: inviteeJid,
          reason: reason,
        );
        _mucLog.info('Sent mediated invite for $inviteeJid to $roomJid');
        return;
      }
    }
    throw XmppMessageException();
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

  Future<void> leaveRoom(String roomJid) async {
    if (_connection.getManager<mox.MUCManager>() case final manager?) {
      await manager.leaveRoom(mox.JID.fromString(roomJid));
      _markRoomLeft(roomJid);
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
  }

  Future<void> acceptRoomInvite({
    required String roomJid,
    required String? roomName,
    String? nickname,
  }) async {
    final existingRoom = roomStateFor(roomJid);
    if (existingRoom?.myOccupantId != null) {
      return;
    }
    final existing = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(roomJid),
    );
    final title = roomName?.trim().isNotEmpty == true
        ? roomName!.trim()
        : existing?.title ?? mox.JID.fromString(roomJid).local;
    if (existing == null) {
      await _dbOp<XmppDatabase>(
        (db) => db.createChat(
          Chat(
            jid: roomJid,
            title: title,
            type: ChatType.groupChat,
            myNickname: nickname ?? _nickForRoom(null),
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        ),
      );
    }
    await joinRoom(
      roomJid: roomJid,
      nickname: nickname ?? _nickForRoom(null),
      maxHistoryStanzas: 0,
    );
  }

  void trackOccupantsFromMessages(String roomJid, Iterable<Message> messages) {
    final key = _roomKey(roomJid);
    if (_leftRooms.contains(key)) return;
    final selfOccupantId = _roomStates[key]?.myOccupantId;
    final preferredSelfNick = _roomNicknames[key];
    for (final message in messages) {
      final nick = _nickFromSender(message.senderJid) ??
          _nickFromSender(message.occupantID ?? '');
      if (nick == null) continue;
      final occupantId = _resolveOccupantId(
        occupantId: message.occupantID,
        roomJid: roomJid,
        nick: nick,
      );
      if (occupantId == null) continue;
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
    final occupantId = _resolveOccupantId(
      occupantId: message.occupantID,
      roomJid: message.chatJid,
      nick: nick,
    );
    if (occupantId == null) return;
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
    if (_connection.getManager<mox.MUCManager>() case final manager?) {
      if (manager is MUCManager) {
        await manager.sendAdminIq(roomJid: roomJid, items: items);
        return;
      }
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
    final jid = mox.JID.fromString(sender);
    final resource = jid.resource;
    if (resource.isEmpty) return null;
    if (jid.toBare().toString() == jid.toString()) return null;
    return resource;
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
    final isSelf =
        resolvedRealJid != null ? _isSelfRealJid(resolvedRealJid) : false;
    var resolvedAffiliation = affiliation ?? current?.affiliation;
    if ((resolvedAffiliation == null || resolvedAffiliation.isNone) && isSelf) {
      resolvedAffiliation = OccupantAffiliation.member;
    }
    if ((resolvedAffiliation == null || resolvedAffiliation.isNone) &&
        _createdRooms.contains(key) &&
        (existing.myOccupantId == occupantId || isNickMatch)) {
      resolvedAffiliation = OccupantAffiliation.owner;
    }
    final next = (current ??
            Occupant(
              occupantId: occupantId,
              nick: nick,
              isPresent: isPresent ?? true,
            ))
        .copyWith(
      nick: nick,
      realJid: resolvedRealJid,
      affiliation: resolvedAffiliation ?? OccupantAffiliation.none,
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

  String? _resolveOccupantId({
    required String? occupantId,
    required String roomJid,
    required String nick,
  }) {
    if (occupantId != null && occupantId.isNotEmpty) {
      return occupantId;
    }
    if (nick.isEmpty) return null;
    return '$roomJid/$nick';
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
  }) async {
    final myBare = _myJid?.toBare().toString();
    if (myBare == null) throw XmppMessageException();
    final chat =
        await _dbOpReturning<XmppDatabase, Chat?>((db) => db.getChat(roomJid));
    final roomName = chat?.title;
    final token = generateRandomString(length: 10);
    final payload = <String, dynamic>{
      'roomJid': roomJid,
      'token': token,
      'inviter': myBare,
      'invitee': inviteeJid,
      if (reason?.isNotEmpty == true) 'reason': reason,
      if (roomName?.isNotEmpty == true) 'roomName': roomName,
    };
    final marker = 'axc-invite:${jsonEncode(payload)}';
    final displayLine = roomName?.isNotEmpty == true
        ? 'Join $roomName ($roomJid)'
        : 'Join $roomJid';
    final body = reason?.isNotEmpty == true
        ? '$displayLine\n$reason\n$marker'
        : '$displayLine\n$marker';
    final message = Message(
      stanzaID: _connection.generateId(),
      senderJid: myBare,
      chatJid: inviteeJid,
      body: body,
      timestamp: DateTime.timestamp(),
      pseudoMessageType: PseudoMessageType.mucInvite,
      pseudoMessageData: payload,
    );
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessage(message, chatType: ChatType.chat),
    );
    final stanza = mox.MessageEvent(
      mox.JID.fromString(myBare),
      mox.JID.fromString(inviteeJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageBodyData(body),
        mox.MessageIdData(message.stanzaID),
        const mox.MarkableData(true),
        mox.ChatState.active,
      ]),
      id: message.stanzaID,
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
    final payload = <String, dynamic>{
      'roomJid': roomJid,
      'token': token,
      'inviter': myBare,
      'invitee': inviteeJid,
      'revoked': true,
    };
    final marker = 'axc-invite-revoke:${jsonEncode(payload)}';
    final body = 'Invite revoked for $roomJid\n$marker';
    final message = Message(
      stanzaID: _connection.generateId(),
      senderJid: myBare,
      chatJid: inviteeJid,
      body: body,
      timestamp: DateTime.timestamp(),
      pseudoMessageType: PseudoMessageType.mucInviteRevocation,
      pseudoMessageData: payload,
    );
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessage(message, chatType: ChatType.chat),
    );
    final stanza = mox.MessageEvent(
      mox.JID.fromString(myBare),
      mox.JID.fromString(inviteeJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageBodyData(body),
        mox.MessageIdData(message.stanzaID),
        const mox.MarkableData(true),
        mox.ChatState.active,
      ]),
      id: message.stanzaID,
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
    final occupantId = _resolveOccupantId(
      occupantId: myOccupantId != null && myOccupantId.startsWith('$key/')
          ? null
          : myOccupantId,
      roomJid: roomJid,
      nick: nickname,
    );
    _upsertOccupant(
      roomJid: roomJid,
      occupantId: occupantId ?? '$key/$nickname',
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
