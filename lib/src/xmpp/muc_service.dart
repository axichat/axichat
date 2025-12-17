part of 'package:axichat/src/xmpp/xmpp_service.dart';

const _mucUserXmlns = 'http://jabber.org/protocol/muc#user';
const _mucAdminXmlns = 'http://jabber.org/protocol/muc#admin';
const _occupantIdXmlns = 'urn:xmpp:occupant-id:0';

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

mixin MucService on XmppBase, BaseStreamService {
  final _mucLog = Logger('MucService');
  static const Duration _mucJoinTimeout = Duration(seconds: 10);
  static const int _defaultMucJoinHistoryStanzas = 50;
  final _roomStates = <String, RoomState>{};
  final _roomStreams = <String, StreamController<RoomState>>{};
  final _roomNicknames = <String, String>{};
  final _leftRooms = <String>{};
  final _seededDummyRooms = <String>{};
  String? _mucServiceHost;
  bool _mucBookmarksSyncInFlight = false;

  String get mucServiceHost =>
      _mucServiceHost ?? 'conference.${_myJid?.domain ?? 'example.com'}';

  void setMucServiceHost(String? host) {
    _mucServiceHost = host;
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
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (event.resumed) return;
        if (connectionState != ConnectionState.connected) return;
        unawaited(syncMucBookmarksOnLogin());
      });
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
  }) async {
    _markRoomJoined(roomJid);
    _roomNicknames[_roomKey(roomJid)] = nickname;
    final manager = _connection.getManager<mox.MUCManager>();
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
    } on TimeoutException {
      _mucLog.fine('Timed out waiting for room join to complete.');
    }
  }

  Future<void> ensureJoined({
    required String roomJid,
    String? nickname,
    int? maxHistoryStanzas,
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
    final title = await _resolveRoomTitle(
      roomJid: roomJid,
      providedTitle: roomName,
    );
    final resolvedNickname = _nickForRoom(nickname);
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
    );
    await _upsertBookmarkForRoom(
      roomJid: roomJid,
      title: title,
      nickname: resolvedNickname,
      autojoin: true,
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

    final mucManager = _connection.getManager<mox.MUCManager>();
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

  Future<void> applyMucBookmarks(List<MucBookmark> bookmarks) async {
    if (bookmarks.isEmpty) return;
    await _upsertChatsFromBookmarks(bookmarks);

    for (final bookmark in bookmarks) {
      if (!bookmark.autojoin) continue;
      if (connectionState != ConnectionState.connected) return;

      final nickname = bookmark.nick?.trim();
      if (nickname?.isNotEmpty == true) {
        _roomNicknames[_roomKey(bookmark.roomBare.toString())] = nickname!;
      }

      try {
        await ensureJoined(
          roomJid: bookmark.roomBare.toString(),
          nickname: nickname,
          maxHistoryStanzas: _defaultMucJoinHistoryStanzas,
        );
      } on XmppAbortedException {
        return;
      } on Exception {
        _mucLog.fine('Failed to auto-join one or more bookmarked rooms.');
      }
    }
  }

  Future<void> syncMucBookmarksOnLogin() async {
    if (_mucBookmarksSyncInFlight) return;
    if (connectionState != ConnectionState.connected) return;
    _mucBookmarksSyncInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) return;
      final bookmarksManager = _connection.getManager<BookmarksManager>();
      if (bookmarksManager == null) return;

      final bookmarks = await bookmarksManager.getBookmarks();
      if (bookmarks.isEmpty) return;
      await applyMucBookmarks(bookmarks);
    } on XmppAbortedException {
      return;
    } finally {
      _mucBookmarksSyncInFlight = false;
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
  }) async {
    final manager = _connection.getManager<BookmarksManager>();
    if (manager == null) return;
    try {
      final roomBare = mox.JID.fromString(roomJid).toBare();
      await manager.upsertBookmark(
        MucBookmark(
          roomBare: roomBare,
          name: title?.trim().isNotEmpty == true ? title?.trim() : null,
          autojoin: autojoin,
          nick: nickname?.trim().isNotEmpty == true ? nickname?.trim() : null,
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

  void _handleSelfPresence(MucSelfPresenceEvent event) {
    final roomJid = _roomKey(event.roomJid);
    if (!event.isAvailable && !event.isNickChange) {
      _markRoomLeft(roomJid);
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
    const displayLine = 'You have been invited to a group chat';
    final displayBody =
        reason?.isNotEmpty == true ? '$displayLine\n$reason' : displayLine;
    final wireBody = reason?.isNotEmpty == true
        ? '$displayLine\n$reason\n$marker'
        : '$displayLine\n$marker';
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
    final stanza = mox.MessageEvent(
      mox.JID.fromString(myBare),
      mox.JID.fromString(inviteeJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageBodyData(wireBody),
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
    final marker = 'axc-invite-revoke:${jsonEncode(payload)}';
    final displayLine = roomName?.isNotEmpty == true
        ? 'Invite revoked for $roomName'
        : 'Invite revoked';
    final displayBody = displayLine;
    final wireBody = '$displayLine\n$marker';
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
    final stanza = mox.MessageEvent(
      mox.JID.fromString(myBare),
      mox.JID.fromString(inviteeJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageBodyData(wireBody),
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
