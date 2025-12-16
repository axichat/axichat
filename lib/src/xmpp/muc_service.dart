part of 'package:axichat/src/xmpp/xmpp_service.dart';

const _mucUserXmlns = 'http://jabber.org/protocol/muc#user';
const _mucAdminXmlns = 'http://jabber.org/protocol/muc#admin';
const _occupantIdXmlns = 'urn:xmpp:occupant-id:0';
const _mucRoomsNodeId = 'urn:axichat:muc-rooms';
const _mucRoomsPayloadXmlns = 'urn:axichat:muc-rooms:1';
const _mucRoomsPayloadTag = 'room';
const _mucRoomsPayloadJidAttr = 'jid';
const _mucRoomsPayloadNickAttr = 'nick';
const _mucRoomsPayloadTitleAttr = 'title';
const _mucRoomsPayloadAutojoinAttr = 'autojoin';
const _mucRoomsPayloadEncodingAttr = 'enc';
const _mucRoomsPayloadEncodingBase64 = 'b64';
const _mucRoomsAccessModel = 'whitelist';
const _mucRoomsMaxItems = '512';
const _mucRoomsSendLastPublishedItemOnSubscribe = 'on_subscribe';
const _mucRoomsPublishModel = 'publishers';

mixin MucService on XmppBase, BaseStreamService {
  final _mucLog = Logger('MucService');
  final _roomStates = <String, RoomState>{};
  final _roomStreams = <String, StreamController<RoomState>>{};
  final _roomNicknames = <String, String>{};
  final _leftRooms = <String>{};
  final _createdRooms = <String>{};
  final _seededDummyRooms = <String>{};
  String? _mucServiceHost;
  bool _mucRoomsSyncInFlight = false;
  mox.JID? _mucRoomsPubSubHost;
  final Map<String, RegisteredStateKey> _pendingMucRoomRetractKeys = {};

  String get mucServiceHost =>
      _mucServiceHost ?? 'conference.${_myJid?.domain ?? 'example.com'}';

  void setMucServiceHost(String? host) {
    _mucServiceHost = host;
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((_) async {
        if (connectionState != ConnectionState.connected) return;
        unawaited(_ensureMucRoomsPubSubSubscription());
        unawaited(_flushPendingMucRoomListingRemovals());
      })
      ..registerHandler<mox.PubSubNotificationEvent>((event) async {
        await _handleMucRoomsPubSubNotification(event);
      })
      ..registerHandler<mox.PubSubItemsRetractedEvent>((event) async {
        await _handleMucRoomsPubSubItemsRetracted(event);
      })
      ..registerHandler<mox.PubSubNodeDeletedEvent>((event) async {
        await _handleMucRoomsPubSubReset(
          node: event.node,
          from: event.from,
        );
      })
      ..registerHandler<mox.PubSubNodePurgedEvent>((event) async {
        await _handleMucRoomsPubSubReset(
          node: event.node,
          from: event.from,
        );
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
    await _upsertMucRoomListing(
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
        _seedSelfOccupant(roomJid: roomJid, nickname: nickname);
        return;
      }
      await manager.joinRoom(
        mox.JID.fromString(roomJid),
        nickname,
        maxHistoryStanzas: maxHistoryStanzas,
      );
      _seedSelfOccupant(roomJid: roomJid, nickname: nickname);
      return;
    }
    throw XmppMessageException();
  }

  void _seedSelfOccupant({
    required String roomJid,
    required String nickname,
  }) {
    final bareRoomJid = _roomKey(roomJid);
    final occupantId = _resolveOccupantId(
      occupantId: null,
      roomJid: bareRoomJid,
      nick: nickname,
    );
    if (occupantId == null) return;
    _upsertOccupant(
      roomJid: bareRoomJid,
      occupantId: occupantId,
      nick: nickname,
      isPresent: true,
    );
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
        _mucLog.info('Sent mediated room invite.');
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
      await _queueMucRoomListingRemoval(roomJid);
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
    await _upsertMucRoomListing(
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
    final existing = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(roomJid),
    );
    final title = roomName?.trim().isNotEmpty == true
        ? roomName!.trim()
        : existing?.title ?? mox.JID.fromString(roomJid).local;
    final resolvedNickname = _nickForRoom(nickname);
    if (existing == null) {
      await _dbOp<XmppDatabase>(
        (db) => db.createChat(
          Chat(
            jid: roomJid,
            title: title,
            type: ChatType.groupChat,
            myNickname: resolvedNickname,
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        ),
      );
    }
    await joinRoom(
      roomJid: roomJid,
      nickname: resolvedNickname,
      maxHistoryStanzas: 0,
    );
    await _upsertMucRoomListing(
      roomJid: roomJid,
      title: title,
      nickname: resolvedNickname,
      autojoin: true,
    );
  }

  String? _mucRoomsSafeBareJid(String? jid) {
    if (jid == null || jid.isEmpty) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } on Exception {
      return null;
    }
  }

  Future<bool> _isMucRoomsPubSubEventFromSelf(String? from) async {
    final fromBare = _mucRoomsSafeBareJid(from);
    if (fromBare == null) return false;

    final host = await _resolveMucRoomsPubSubHost();
    if (host == null) return false;

    return fromBare == host.toString();
  }

  Future<void> _ensureMucRoomsPubSubSubscription() async {
    final pubsub = _connection.getManager<mox.PubSubManager>();
    if (pubsub == null) return;
    if (connectionState != ConnectionState.connected) return;

    final host = await _resolveMucRoomsPubSubHost();
    if (host == null) return;

    try {
      final result = await pubsub.subscribe(host, _mucRoomsNodeId);
      if (result.isType<mox.PubSubError>()) return;
    } on XmppAbortedException {
      return;
    } on Exception {
      _mucLog.fine('Failed to subscribe to room list updates.');
    }
  }

  Future<void> _handleMucRoomsPubSubNotification(
    mox.PubSubNotificationEvent event,
  ) async {
    if (event.item.node != _mucRoomsNodeId) return;
    if (connectionState != ConnectionState.connected) return;
    if (!await _isMucRoomsPubSubEventFromSelf(event.from)) return;

    final payload = event.item.payload;
    if (payload == null) {
      unawaited(syncMucRoomsFromPubSubOnLogin());
      return;
    }

    final listing = _MucRoomListing.fromXml(payload);
    if (listing == null) return;

    try {
      await database;
      if (connectionState != ConnectionState.connected) return;

      await _upsertMucChatsFromListings([listing]);

      if (!listing.autojoin) return;
      if (connectionState != ConnectionState.connected) return;

      _markRoomJoined(listing.roomJid);
      await ensureJoined(
        roomJid: listing.roomJid,
        nickname: listing.nickname,
        maxHistoryStanzas: mamLoginBackfillMessageLimit,
      );
    } on XmppAbortedException {
      return;
    } on Exception {
      _mucLog.fine('Failed to apply a room list update.');
    }
  }

  Future<void> _handleMucRoomsPubSubItemsRetracted(
    mox.PubSubItemsRetractedEvent event,
  ) async {
    if (event.node != _mucRoomsNodeId) return;
    if (event.itemIds.isEmpty) return;
    if (connectionState != ConnectionState.connected) return;
    if (!await _isMucRoomsPubSubEventFromSelf(event.from)) return;

    final knownRooms = List<String>.from(_roomStates.keys);
    for (final roomJid in knownRooms) {
      if (connectionState != ConnectionState.connected) return;
      if (hasLeftRoom(roomJid)) continue;

      final itemId = _mucRoomsItemId(roomJid);
      if (!event.itemIds.contains(itemId)) continue;

      try {
        await leaveRoom(roomJid);
      } on XmppAbortedException {
        return;
      } on Exception {
        _mucLog.fine(
          'Failed to leave one or more chat rooms after a room list update.',
        );
      }
    }
  }

  Future<void> _handleMucRoomsPubSubReset({
    required String node,
    required String from,
  }) async {
    if (node != _mucRoomsNodeId) return;
    if (connectionState != ConnectionState.connected) return;
    if (!await _isMucRoomsPubSubEventFromSelf(from)) return;

    unawaited(syncMucRoomsFromPubSubOnLogin());
  }

  Future<void> syncMucRoomsFromPubSubOnLogin() async {
    if (_mucRoomsSyncInFlight) return;
    if (connectionState != ConnectionState.connected) return;
    _mucRoomsSyncInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) return;

      await _flushPendingMucRoomListingRemovals();

      final rooms = await _fetchMucRoomListings();
      if (rooms.isEmpty) return;

      await _upsertMucChatsFromListings(rooms);

      for (final room in rooms) {
        if (!room.autojoin) continue;
        if (connectionState != ConnectionState.connected) return;
        try {
          await ensureJoined(
            roomJid: room.roomJid,
            nickname: room.nickname,
            maxHistoryStanzas: mamLoginBackfillMessageLimit,
          );
        } on XmppAbortedException {
          return;
        } on Exception {
          _mucLog.fine(
            'Failed to auto-join one or more chat rooms during login.',
          );
        }
      }
    } on XmppAbortedException {
      return;
    } finally {
      _mucRoomsSyncInFlight = false;
    }
  }

  String? _mucRoomsAccountId() {
    final myJid = _myJid;
    if (myJid == null) return null;
    final digest = sha256.convert(utf8.encode(myJid.toBare().toString())).bytes;
    return base64Url.encode(digest).replaceAll('=', '');
  }

  RegisteredStateKey _pendingMucRoomRetractKeyForAccount(String accountId) =>
      _pendingMucRoomRetractKeys.putIfAbsent(
        accountId,
        () =>
            XmppStateStore.registerKey('muc_rooms_pending_retract_$accountId'),
      );

  Future<Set<String>> _loadPendingMucRoomListingRemovals({
    required String accountId,
  }) async {
    final key = _pendingMucRoomRetractKeyForAccount(accountId);
    final stored = await _dbOpReturning<XmppStateStore, Object?>(
      (ss) => ss.read(key: key),
    );
    if (stored is List) {
      return stored.whereType<String>().toSet();
    }
    return <String>{};
  }

  Future<void> _savePendingMucRoomListingRemovals({
    required String accountId,
    required Set<String> removals,
  }) async {
    final key = _pendingMucRoomRetractKeyForAccount(accountId);
    await _dbOp<XmppStateStore>(
      (ss) => ss.write(
        key: key,
        value: removals.toList(growable: false),
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueMucRoomListingRemoval(String roomJid) async {
    final accountId = _mucRoomsAccountId();
    if (accountId == null) return;

    final itemId = _mucRoomsItemId(roomJid);
    final pending = await _loadPendingMucRoomListingRemovals(
      accountId: accountId,
    );
    if (!pending.add(itemId)) return;

    await _savePendingMucRoomListingRemovals(
      accountId: accountId,
      removals: pending,
    );

    unawaited(_flushPendingMucRoomListingRemovals());
  }

  Future<void> _flushPendingMucRoomListingRemovals() async {
    final pubsub = _connection.getManager<mox.PubSubManager>();
    if (pubsub == null) return;
    if (connectionState != ConnectionState.connected) return;

    final accountId = _mucRoomsAccountId();
    if (accountId == null) return;

    final host = await _resolveMucRoomsPubSubHost();
    if (host == null) return;

    final pending = await _loadPendingMucRoomListingRemovals(
      accountId: accountId,
    );
    if (pending.isEmpty) return;

    final remaining = <String>{};
    for (final itemId in pending) {
      if (connectionState != ConnectionState.connected) return;
      try {
        final result = await pubsub.retract(
          host,
          _mucRoomsNodeId,
          itemId,
        );
        if (result.isType<mox.PubSubError>()) {
          final error = result.get<mox.PubSubError>();
          final alreadyGone = error is mox.ItemNotFoundError ||
              error is mox.NoItemReturnedError;
          if (!alreadyGone) {
            remaining.add(itemId);
          }
        }
      } on XmppAbortedException {
        return;
      } on Exception {
        _mucLog.fine(
          'Failed to flush one or more room list removals.',
        );
        remaining.add(itemId);
      }
    }

    if (remaining.length == pending.length) return;
    await _savePendingMucRoomListingRemovals(
      accountId: accountId,
      removals: remaining,
    );
  }

  Future<void> _upsertMucChatsFromListings(
    List<_MucRoomListing> rooms,
  ) async {
    for (final room in rooms) {
      if (room.roomJid.isEmpty) continue;
      try {
        await _dbOp<XmppDatabase>(
          (db) async {
            final existing = await db.getChat(room.roomJid);
            final nickname = room.nickname ?? existing?.myNickname;
            if (existing == null) {
              final fallbackTitle = mox.JID.fromString(room.roomJid).local;
              await db.createChat(
                Chat(
                  jid: room.roomJid,
                  title: room.title ??
                      (fallbackTitle.isNotEmpty ? fallbackTitle : room.roomJid),
                  type: ChatType.groupChat,
                  myNickname: nickname ?? _nickForRoom(null),
                  lastChangeTimestamp: DateTime.timestamp(),
                  contactJid: room.roomJid,
                ),
              );
              return;
            }

            final trimmedTitle = room.title?.trim();
            final trimmedNickname = room.nickname?.trim();

            final shouldUpdateTitle = trimmedTitle != null &&
                trimmedTitle.isNotEmpty &&
                trimmedTitle != existing.title;
            final shouldUpdateNickname = trimmedNickname != null &&
                trimmedNickname.isNotEmpty &&
                trimmedNickname != existing.myNickname;
            if (!shouldUpdateTitle && !shouldUpdateNickname) return;

            await db.updateChat(
              existing.copyWith(
                title: shouldUpdateTitle ? trimmedTitle : existing.title,
                myNickname: shouldUpdateNickname
                    ? trimmedNickname
                    : existing.myNickname,
              ),
            );
          },
          awaitDatabase: true,
        );
      } on XmppAbortedException {
        return;
      } on Exception {
        _mucLog.fine(
          'Failed to upsert one or more chat rooms.',
        );
      }
    }
  }

  Future<List<_MucRoomListing>> _fetchMucRoomListings() async {
    final pubsub = _connection.getManager<mox.PubSubManager>();
    if (pubsub == null) return const [];

    final host = await _resolveMucRoomsPubSubHost();
    if (host == null) return const [];

    final primary = await _fetchMucRoomListingsFromHost(
      pubsub: pubsub,
      host: host,
    );
    if (primary.isNotEmpty) {
      return primary;
    }

    final migrated = await _migrateLegacyMucRoomListings(pubsub: pubsub);
    if (migrated.isNotEmpty) {
      return migrated;
    }

    return primary;
  }

  Future<List<_MucRoomListing>> _fetchMucRoomListingsFromHost({
    required mox.PubSubManager pubsub,
    required mox.JID host,
  }) async {
    try {
      final result = await pubsub.getItems(host, _mucRoomsNodeId);
      if (result.isType<mox.PubSubError>()) {
        final error = result.get<mox.PubSubError>();
        if (error is mox.ItemNotFoundError ||
            error is mox.NoItemReturnedError) {
          return const [];
        }
        return const [];
      }

      final items = result.get<List<mox.PubSubItem>>();
      final listings = <_MucRoomListing>[];
      for (final item in items) {
        final payload = item.payload;
        if (payload == null) continue;
        final listing = _MucRoomListing.fromXml(payload);
        if (listing == null) continue;
        listings.add(listing);
      }
      return List<_MucRoomListing>.unmodifiable(listings);
    } on XmppAbortedException {
      rethrow;
    } on Exception {
      _mucLog.fine('Failed to fetch room list.');
      return const [];
    }
  }

  Future<List<_MucRoomListing>> _migrateLegacyMucRoomListings({
    required mox.PubSubManager pubsub,
  }) async {
    try {
      if (connectionState != ConnectionState.connected) return const [];
      final myJid = _myJid;
      if (myJid == null) return const [];
      final domain = myJid.domain;
      if (domain.isEmpty) return const [];

      final bareJid = myJid.toBare().toString();
      final legacyHosts = <mox.JID>[
        mox.JID.fromString('pubsub.$domain'),
        mox.JID.fromString(domain),
      ];

      for (final legacyHost in legacyHosts) {
        if (connectionState != ConnectionState.connected) return const [];
        final affiliations =
            await pubsub.getNodeAffiliations(legacyHost, _mucRoomsNodeId);
        if (affiliations == null) continue;
        if (affiliations[bareJid] != mox.PubSubAffiliation.owner) {
          continue;
        }

        final hasOtherPublishers = affiliations.entries.any((entry) {
          final affiliation = entry.value;
          if (affiliation != mox.PubSubAffiliation.owner &&
              affiliation != mox.PubSubAffiliation.publisher) {
            return false;
          }
          return entry.key != bareJid;
        });
        if (hasOtherPublishers) continue;

        final listings = await _fetchMucRoomListingsFromHost(
          pubsub: pubsub,
          host: legacyHost,
        );
        if (listings.isEmpty) continue;

        for (final listing in listings) {
          if (connectionState != ConnectionState.connected) break;
          await _upsertMucRoomListing(
            roomJid: listing.roomJid,
            title: listing.title,
            nickname: listing.nickname,
            autojoin: listing.autojoin,
          );
        }

        return listings;
      }

      return const [];
    } on XmppAbortedException {
      rethrow;
    } on Exception {
      return const [];
    }
  }

  Future<void> _upsertMucRoomListing({
    required String roomJid,
    required String? title,
    required String? nickname,
    required bool autojoin,
  }) async {
    final pubsub = _connection.getManager<mox.PubSubManager>();
    if (pubsub == null) return;
    if (connectionState != ConnectionState.connected) return;

    final host = await _resolveMucRoomsPubSubHost();
    if (host == null) return;

    final trimmedTitle = title?.trim();
    final trimmedNickname = nickname?.trim();
    final encodedRoomJid = _encodeMucRoomsPayloadValue(roomJid);
    final payload = mox.XMLNode.xmlns(
      tag: _mucRoomsPayloadTag,
      xmlns: _mucRoomsPayloadXmlns,
      attributes: {
        _mucRoomsPayloadJidAttr: encodedRoomJid,
        _mucRoomsPayloadEncodingAttr: _mucRoomsPayloadEncodingBase64,
        if (trimmedTitle != null && trimmedTitle.isNotEmpty)
          _mucRoomsPayloadTitleAttr: _encodeMucRoomsPayloadValue(trimmedTitle),
        if (trimmedNickname != null && trimmedNickname.isNotEmpty)
          _mucRoomsPayloadNickAttr:
              _encodeMucRoomsPayloadValue(trimmedNickname),
        _mucRoomsPayloadAutojoinAttr: autojoin.toString(),
      },
    );

    final itemId = _mucRoomsItemId(roomJid);
    const publishOptions = mox.PubSubPublishOptions(
      accessModel: _mucRoomsAccessModel,
      maxItems: _mucRoomsMaxItems,
      persistItems: true,
    );
    final createConfig = mox.NodeConfig(
      accessModel: mox.AccessModel.whitelist,
      publishModel: _mucRoomsPublishModel,
      deliverNotifications: true,
      maxItems: _mucRoomsMaxItems,
      notifyRetract: true,
      persistItems: true,
      deliverPayloads: true,
      sendLastPublishedItem: _mucRoomsSendLastPublishedItemOnSubscribe,
    );

    try {
      final result = await pubsub.publish(
        host,
        _mucRoomsNodeId,
        payload,
        id: itemId,
        options: publishOptions,
        autoCreate: true,
        createNodeConfig: createConfig,
      );
      if (result.isType<mox.PubSubError>()) {
        _mucLog.fine('Failed to publish room list update.');
      }
    } on XmppAbortedException {
      rethrow;
    } on Exception {
      _mucLog.fine('Failed to publish room list update.');
    }

    unawaited(_ensureMucRoomsPubSubSubscription());
  }

  Future<mox.JID?> _resolveMucRoomsPubSubHost() async {
    final cached = _mucRoomsPubSubHost;
    if (cached != null) return cached;

    final myJid = _myJid;
    if (myJid == null) return null;
    final host = myJid.toBare();
    _mucRoomsPubSubHost = host;
    return host;
  }

  String _mucRoomsItemId(String roomJid) {
    final digest = sha256.convert(utf8.encode(roomJid)).bytes;
    return base64Url.encode(digest).replaceAll('=', '');
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
    final displayLine =
        roomName?.isNotEmpty == true ? 'Join $roomName' : 'Join room';
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

String _encodeMucRoomsPayloadValue(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

String? _decodeMucRoomsPayloadValue(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  final padded = normalized.padRight(
    normalized.length + ((4 - normalized.length % 4) % 4),
    '=',
  );
  try {
    return utf8.decode(base64Url.decode(padded));
  } on FormatException {
    return null;
  }
}

class _MucRoomListing {
  const _MucRoomListing({
    required this.roomJid,
    required this.autojoin,
    this.nickname,
    this.title,
  });

  final String roomJid;
  final bool autojoin;
  final String? nickname;
  final String? title;

  static _MucRoomListing? fromXml(mox.XMLNode node) {
    if (node.tag != _mucRoomsPayloadTag) return null;
    final xmlns = node.attributes['xmlns']?.toString();
    if (xmlns != _mucRoomsPayloadXmlns) return null;

    final encoding =
        node.attributes[_mucRoomsPayloadEncodingAttr]?.toString().trim();
    final usesBase64 = encoding == _mucRoomsPayloadEncodingBase64;

    final rawJidValue =
        node.attributes[_mucRoomsPayloadJidAttr]?.toString().trim();
    if (rawJidValue == null || rawJidValue.isEmpty) return null;

    final decodedRoomJid =
        usesBase64 ? _decodeMucRoomsPayloadValue(rawJidValue) : rawJidValue;
    if (decodedRoomJid == null || decodedRoomJid.isEmpty) return null;
    if (!decodedRoomJid.contains('@')) return null;
    try {
      mox.JID.fromString(decodedRoomJid);
    } on Exception {
      return null;
    }

    final rawNicknameValue =
        node.attributes[_mucRoomsPayloadNickAttr]?.toString().trim();
    final rawTitleValue =
        node.attributes[_mucRoomsPayloadTitleAttr]?.toString().trim();
    final rawAutojoin =
        node.attributes[_mucRoomsPayloadAutojoinAttr]?.toString().trim();

    final decodedNickname = rawNicknameValue == null
        ? null
        : usesBase64
            ? _decodeMucRoomsPayloadValue(rawNicknameValue)
            : rawNicknameValue;
    final decodedTitle = rawTitleValue == null
        ? null
        : usesBase64
            ? _decodeMucRoomsPayloadValue(rawTitleValue)
            : rawTitleValue;

    return _MucRoomListing(
      roomJid: decodedRoomJid,
      nickname: decodedNickname?.isNotEmpty == true ? decodedNickname : null,
      title: decodedTitle?.isNotEmpty == true ? decodedTitle : null,
      autojoin: _parseBool(rawAutojoin, defaultValue: true),
    );
  }

  static bool _parseBool(String? value, {required bool defaultValue}) {
    final normalized = value?.toLowerCase();
    return switch (normalized) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => defaultValue,
    };
  }
}
