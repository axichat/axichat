// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const _mucAdminXmlns = 'http://jabber.org/protocol/muc#admin';
const _mucOwnerXmlns = 'http://jabber.org/protocol/muc#owner';
const _mucDiscoFeature = 'http://jabber.org/protocol/muc';
const _mucMembersOnlyFeature = 'muc_membersonly';
const _discoInfoXmlns = 'http://jabber.org/protocol/disco#info';
const _dataFormXmlns = 'jabber:x:data';
const _dataFormTag = 'x';
const _dataFormTypeAttr = 'type';
const _dataFormTypeSubmit = 'submit';
const _dataFormFieldTypeHidden = 'hidden';
const _fieldTag = 'field';
const _valueTag = 'value';
const _varAttr = 'var';
const _errorTag = 'error';
const _formTypeFieldVar = 'FORM_TYPE';
const _mucRoomInfoFormType = 'http://jabber.org/protocol/muc#roominfo';
const _mucRoomConfigFormType = 'http://jabber.org/protocol/muc#roomconfig';
const _avatarFieldToken = 'avatar';
const _avatarHashToken = 'hash';
const _avatarSha1Token = 'sha1';
const _avatarMimeToken = 'mime';
const _avatarTypeToken = 'type';
const _dataUriPrefix = 'data:';
const _dataUriBase64Delimiter = ';base64,';
const _vCardTempXmlns = mox.vCardTempXmlns;
const _vCardTag = 'vCard';
const _vCardPhotoTag = 'PHOTO';
const _vCardBinvalTag = 'BINVAL';
const _vCardTypeTag = 'TYPE';
const _mucJoinRequestedLog = 'MUC join requested.';
const _mucJoinPollHasSelfPresenceLog = 'MUC join already has self presence.';
const _mucJoinSelfPresenceEventLog = 'MUC self presence event.';
const _mucJoinOwnDataIgnoredLog =
    'MUC own data ignored; missing self presence.';
const _mucJoinCompletedLog = 'MUC join completed.';
const _mucJoinTimeoutLog = 'Timed out waiting for room join to complete.';
const _mucJoinLogSeparator = ' ';
const _mucJoinAttemptIdLabel = 'attempt=';
const _mucJoinHasSelfPresenceLabel = 'has_self_presence=';
const _mucJoinJoinCompleterActiveLabel = 'join_completer_active=';
const _mucJoinInFlightLabel = 'join_in_flight=';
const _mucJoinManagerPresenceLabel = 'manager_presence=';
const _mucJoinUsedFallbackLabel = 'used_fallback_status=';
const _mucJoinIsErrorLabel = 'is_error=';
const _mucJoinIsAvailableLabel = 'is_available=';
const _mucJoinIsNickChangeLabel = 'is_nick_change=';
const _mucJoinStatusCountLabel = 'status_count=';
const _mucJoinHasSelfStatusLabel = 'has_self_status=';
const _mucJoinErrorLabel = 'error=';
const _mucJoinManagerJoinTimeoutLog =
    'moxxmpp joinRoom still pending; proceeding via self-presence.';
final XmppOperationEvent _mucCreateStartEvent = XmppOperationEvent(
  kind: XmppOperationKind.mucCreate,
  stage: XmppOperationStage.start,
);
final XmppOperationEvent _mucCreateSuccessEvent = XmppOperationEvent(
  kind: XmppOperationKind.mucCreate,
  stage: XmppOperationStage.end,
);
final XmppOperationEvent _mucCreateFailureEvent = XmppOperationEvent(
  kind: XmppOperationKind.mucCreate,
  stage: XmppOperationStage.end,
  isSuccess: false,
);
final XmppOperationEvent _mucJoinStartEvent = XmppOperationEvent(
  kind: XmppOperationKind.mucJoin,
  stage: XmppOperationStage.start,
);
XmppOperationEvent _mucJoinEndEvent({required bool isSuccess}) =>
    XmppOperationEvent(
      kind: XmppOperationKind.mucJoin,
      stage: XmppOperationStage.end,
      isSuccess: isSuccess,
    );
const _roomAvatarFieldMissingLog =
    'Room configuration form missing avatar field.';
const _roomConfigSubmitFailedLog = 'Room configuration update rejected.';
const _roomConfigSubmitTimeoutLog = 'Room configuration update timed out.';
const _instantRoomConfigFailedLog = 'Instant room configuration failed.';
const _roomAvatarDecodeFailedLog = 'Room avatar decode failed.';
const _roomAvatarStoreFailedLog = 'Room avatar store failed.';
const _roomAvatarUpdateFailedLog = 'Failed to update room avatar.';
const _roomAvatarVCardSubmitFailedLog = 'Room vCard avatar update rejected.';
const _mucCreateRoomOperationName = 'MucService.createRoom';
const _mucUpsertBookmarkOperationName = 'MucService.upsertBookmarkForRoom';
const _mucPostJoinRefreshOperationName = 'MucService.refreshJoinedRoom';
const _mucResumeRecoveryOperationName = 'MucService.recoverAfterResume';
const _mucServiceDiscoveryBootstrapOperationName =
    'MucService.discoverServiceHostOnNegotiations';
const _mucBookmarksBootstrapOperationName =
    'MucService.syncBookmarksOnNegotiations';
const _mucRoomAvatarBootstrapOperationName =
    'MucService.refreshRoomAvatarsOnNegotiations';
const _mucAutojoinBootstrapOperationName =
    'MucService.autojoinBookmarkedRoomsOnNegotiations';
const _mucCreateRoomBookmarkTimeoutLog =
    'Bookmark upsert still running for newly created room.';
const _mucCreateConflictLog =
    'Rejected room create because the room already exists.';
const _mucRoomPrimaryViewSyncFailedLog =
    'Failed to sync calendar room primary view.';
const _mucBookmarkBaselineUnavailableLog =
    'Bookmark baseline unavailable; skipping metadata-only bookmark upsert.';
const _mucCreateRollbackFailedLog =
    'Failed to leave room after rejected create attempt.';
const _roomAffiliationQueryTimeoutLog = 'Room affiliation query timed out.';
const bool _mucAvatarSupportEnabled = true;
const bool _mucSendAllowRejoin = true;
const int _roomAvatarVerificationAttempts = 3;
const Duration _roomAvatarVerificationDelay = Duration(milliseconds: 350);
const Set<String> _emptyStatusCodes = <String>{};
const bool _preserveOccupantsDefault = false;
const bool _preserveOccupantsOnMucError = true;
const bool _preserveOccupantsOnJoinTimeout = true;
const _roomPrimaryViewBookmarkXmlns = 'urn:axichat:bookmark:room:0';
const _roomPrimaryViewBookmarkTag = 'room';
const _roomPrimaryViewBookmarkAttr = 'primary-view';
const _iqTypeAttr = 'type';
const _iqTypeGet = 'get';
const _iqTypeSet = 'set';
const _iqTypeResult = 'result';
const _queryTag = 'query';
const _itemTag = 'item';
const _destroyTag = 'destroy';
const _jidAttr = 'jid';
const _nickAttr = 'nick';
const _affiliationAttr = 'affiliation';
const _roleAttr = 'role';
const _reasonTag = 'reason';
const _subjectTag = 'subject';
const _messageTypeChat = 'chat';
const _messageTypeGroupchat = 'groupchat';
const _messageTypeNormal = 'normal';
const _mucServiceHostStorageKeyName = 'muc_service_host';
const _axiMucServiceHost = 'conference.axi.im';
const _mucPrejoinRoomsStorageKeyName = 'muc_prejoin_rooms';
const _mucRoomMemberSnapshotStorageKeyPrefix = 'muc_room_member_snapshot:';
const _mucPrejoinRoomJidKey = 'room_jid';
const _mucPrejoinRoomNickKey = 'nickname';
const _mucRoomMemberOccupantIdKey = 'occupant_id';
const _mucRoomMemberNickKey = 'nick';
const _mucRoomMemberRealJidKey = 'real_jid';
const _mucRoomMemberAffiliationKey = 'affiliation';
const _mucRoomMemberRoleKey = 'role';
final _mucServiceHostStorageKey = XmppStateStore.registerKey(
  _mucServiceHostStorageKeyName,
);
final _mucPrejoinRoomsStorageKey = XmppStateStore.registerKey(
  _mucPrejoinRoomsStorageKeyName,
);

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
  MucSubjectChangedEvent({required this.roomJid, required this.subject});

  final String roomJid;
  final String? subject;
}

final class MucArchiveSyncRequestedEvent extends mox.XmppEvent {
  MucArchiveSyncRequestedEvent({required this.roomJid});

  final String roomJid;
}

final class _PendingOwnData {
  const _PendingOwnData({
    required this.nick,
    required this.affiliation,
    required this.role,
  });

  final String nick;
  final mox.Affiliation affiliation;
  final mox.Role role;
}

final class _MucRoomSession {
  String? nickname;
  _PendingOwnData? pendingOwnData;
  bool hasLeft = false;
  bool explicitlyLeft = false;
  bool needsJoin = false;
  int joinInFlightCount = 0;
  Completer<void>? joinCompleter;
  int? joinAttemptId;
  bool tracksJoinOperation = false;
  Completer<void>? instantRoomConfigCompleter;
  Completer<void>? postJoinRefreshCompleter;
  Completer<void>? repairCompleter;
  bool instantRoomConfigured = false;
  bool instantRoomPending = false;
  bool seededDummyRoom = false;

  int ensureJoinAttemptId(int nextId) => joinAttemptId ??= nextId;

  void clearJoinAttemptId() {
    joinAttemptId = null;
  }

  Completer<void> ensureJoinCompleter() => joinCompleter ??= Completer<void>();

  Completer<void>? takeJoinCompleter() {
    final completer = joinCompleter;
    joinCompleter = null;
    return completer;
  }

  _PendingOwnData? takePendingOwnData() {
    final pending = pendingOwnData;
    pendingOwnData = null;
    return pending;
  }

  bool consumeTrackedJoinOperation() {
    final tracked = tracksJoinOperation;
    tracksJoinOperation = false;
    return tracked;
  }

  void incrementJoinInFlight() {
    joinInFlightCount++;
  }

  void decrementJoinInFlight() {
    if (joinInFlightCount > 0) {
      joinInFlightCount--;
    }
  }

  bool get joinInFlight => joinInFlightCount > 0;
}

final class MucPrejoinRoom {
  const MucPrejoinRoom({required this.roomJid, required this.nickname});

  final String roomJid;
  final String nickname;

  Map<String, String> toJson() => {
    _mucPrejoinRoomJidKey: roomJid,
    _mucPrejoinRoomNickKey: nickname,
  };

  static MucPrejoinRoom? fromJson(Object? value) {
    if (value is! Map) return null;
    final roomJid = value[_mucPrejoinRoomJidKey];
    final nickname = value[_mucPrejoinRoomNickKey];
    if (roomJid is! String || nickname is! String) return null;
    final trimmedRoom = roomJid.trim();
    final trimmedNickname = nickname.trim();
    if (trimmedRoom.isEmpty || trimmedNickname.isEmpty) return null;
    return MucPrejoinRoom(roomJid: trimmedRoom, nickname: trimmedNickname);
  }
}

const List<MucPrejoinRoom> _emptyMucPrejoinRooms = <MucPrejoinRoom>[];

final class _PersistedRoomMember {
  const _PersistedRoomMember({
    required this.nick,
    required this.affiliation,
    required this.role,
    this.occupantId,
    this.realJid,
  });

  final String nick;
  final String? occupantId;
  final String? realJid;
  final OccupantAffiliation affiliation;
  final OccupantRole role;

  Map<String, Object> toJson() {
    final json = <String, Object>{
      _mucRoomMemberNickKey: nick,
      _mucRoomMemberAffiliationKey: affiliation.xmlValue,
      _mucRoomMemberRoleKey: role.xmlValue,
    };
    final resolvedOccupantId = occupantId?.trim();
    if (resolvedOccupantId != null && resolvedOccupantId.isNotEmpty) {
      json[_mucRoomMemberOccupantIdKey] = resolvedOccupantId;
    }
    final jid = realJid;
    if (jid != null) {
      json[_mucRoomMemberRealJidKey] = jid;
    }
    return json;
  }

  static _PersistedRoomMember? fromJson(Object? value) {
    if (value is! Map) return null;
    final rawOccupantId = value[_mucRoomMemberOccupantIdKey];
    final rawNick = value[_mucRoomMemberNickKey];
    final rawRealJid = value[_mucRoomMemberRealJidKey];
    final rawAffiliation = value[_mucRoomMemberAffiliationKey];
    final rawRole = value[_mucRoomMemberRoleKey];
    if (rawNick is! String || rawAffiliation is! String || rawRole is! String) {
      return null;
    }
    final occupantId = rawOccupantId is String ? rawOccupantId.trim() : null;
    final nick = rawNick.trim();
    final realJid = rawRealJid is String ? rawRealJid.trim() : null;
    if ((occupantId == null || occupantId.isEmpty) &&
        nick.isEmpty &&
        (realJid == null || realJid.isEmpty)) {
      return null;
    }
    return _PersistedRoomMember(
      nick: nick,
      occupantId: occupantId?.isEmpty == true ? null : occupantId,
      realJid: realJid?.isEmpty == true ? null : realJid,
      affiliation: OccupantAffiliation.fromString(rawAffiliation),
      role: OccupantRole.fromString(rawRole),
    );
  }
}

final class _RoomAvatarPayload {
  const _RoomAvatarPayload({this.data, this.hash});

  final String? data;
  final String? hash;
}

mixin MucService on XmppBase, BaseStreamService, AvatarService, MessageService {
  final _mucLog = Logger('MucService');
  static const Duration _mucJoinTimeout = Duration(seconds: 15);
  static const Duration _mucJoinManagerTimeout = Duration(seconds: 15);
  static const Duration _roomConfigSubmitTimeout = Duration(seconds: 15);
  static const Duration _roomActionTimeout = Duration(seconds: 15);
  static const Duration _roomQueryTimeout = Duration(seconds: 15);
  static const Duration _mucCreateRoomBookmarkTimeout = Duration(seconds: 15);
  static const int _mucJoinSelfPresencePollIntervalMs = 200;
  static const Duration _mucJoinSelfPresencePollInterval = Duration(
    milliseconds: _mucJoinSelfPresencePollIntervalMs,
  );
  static const int _defaultMucJoinHistoryStanzas = 50;
  static const int _roomMemberSnapshotLimit = 256;
  static const int _mucSnapshotStart = 0;
  static const int _mucSnapshotEnd = 0;
  static const List<MucBookmark> _emptyMucSnapshot = <MucBookmark>[];
  final _roomStates = <String, RoomState>{};
  final _roomStreams = <String, StreamController<RoomState>>{};
  final _roomSubjects = <String, String?>{};
  final _roomSubjectStreams = <String, StreamController<String?>>{};
  final _roomSessions = <String, _MucRoomSession>{};
  static const int _mucJoinAttemptIdStart = 1;
  int _nextMucJoinAttemptId = _mucJoinAttemptIdStart;
  String? _mucServiceHost;
  Future<List<MucBookmark>>? _mucBookmarksSync;
  List<MucBookmark> _latestBootstrapBookmarks = <MucBookmark>[];
  final Set<String> _mucMamUnsupportedRooms = {};
  final Map<String, String> _outboundGroupchatStanzaRooms = <String, String>{};

  Future<CapabilityDecision> _decideMucSupport({String? jid}) async {
    final candidate = jid?.trim();
    final resolved = candidate?.isNotEmpty == true
        ? candidate!
        : mucServiceHost;
    final probeJid = _mucCapabilityProbeJid(resolved);
    if (probeJid == null) {
      return const CapabilityDecision(CapabilityDecisionKind.unknown);
    }
    return decideFeatureSupport(
      jid: probeJid,
      feature: _mucDiscoFeature,
      featureLabel: 'MUC',
    );
  }

  String? _mucCapabilityProbeJid(String? jid) {
    final trimmed = jid?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      final parsed = mox.JID.fromString(trimmed);
      if (parsed.local.isNotEmpty || parsed.resource.isNotEmpty) {
        return parsed.domain;
      }
      return parsed.toBare().toString();
    } on Exception {
      return trimmed;
    }
  }

  _MucRoomSession? _roomSessionForKey(String roomKey) => _roomSessions[roomKey];

  _MucRoomSession _ensureRoomSessionForKey(String roomKey) =>
      _roomSessions.putIfAbsent(roomKey, _MucRoomSession.new);

  String? _roomNicknameForKey(String roomKey) =>
      _roomSessionForKey(roomKey)?.nickname;

  void _setRoomNicknameForKey(String roomKey, String? nickname) {
    final trimmedNickname = nickname?.trim();
    if (trimmedNickname == null || trimmedNickname.isEmpty) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.nickname = null;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).nickname = trimmedNickname;
  }

  void _setPendingOwnDataForKey(String roomKey, _PendingOwnData pending) {
    _ensureRoomSessionForKey(roomKey).pendingOwnData = pending;
  }

  _PendingOwnData? _takePendingOwnDataForKey(String roomKey) =>
      _roomSessionForKey(roomKey)?.takePendingOwnData();

  void _clearPendingOwnDataForKey(String roomKey) {
    final session = _roomSessionForKey(roomKey);
    if (session != null) {
      session.pendingOwnData = null;
    }
  }

  bool _roomHasLeft(String roomKey) =>
      _roomSessionForKey(roomKey)?.hasLeft == true;

  void _setRoomHasLeft(String roomKey, bool hasLeft) {
    if (!hasLeft) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.hasLeft = false;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).hasLeft = true;
  }

  bool _roomExplicitlyLeft(String roomKey) =>
      _roomSessionForKey(roomKey)?.explicitlyLeft == true;

  void _setRoomExplicitlyLeft(String roomKey, bool explicitlyLeft) {
    if (!explicitlyLeft) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.explicitlyLeft = false;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).explicitlyLeft = true;
  }

  bool _roomNeedsJoin(String roomJid) =>
      _roomSessionForKey(_roomKey(roomJid))?.needsJoin == true;

  void _setRoomNeedsJoin(String roomKey, bool needsJoin) {
    if (!needsJoin) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.needsJoin = false;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).needsJoin = true;
  }

  bool _mucJoinInFlight(String roomKey) =>
      _roomSessionForKey(roomKey)?.joinInFlight == true;

  void _incrementMucJoinInFlight(String roomKey) {
    _ensureRoomSessionForKey(roomKey).incrementJoinInFlight();
  }

  void _decrementMucJoinInFlight(String roomKey) {
    final session = _roomSessionForKey(roomKey);
    if (session == null) {
      return;
    }
    session.decrementJoinInFlight();
  }

  Completer<void> _ensureJoinCompleterForKey(String roomKey) =>
      _ensureRoomSessionForKey(roomKey).ensureJoinCompleter();

  Completer<void>? _joinCompleterForKey(String roomKey) =>
      _roomSessionForKey(roomKey)?.joinCompleter;

  Completer<void>? _takeJoinCompleterForKey(String roomKey) =>
      _roomSessionForKey(roomKey)?.takeJoinCompleter();

  int _ensureJoinAttemptIdForKey(String roomKey) {
    final existing = _roomSessionForKey(roomKey)?.joinAttemptId;
    if (existing != null) return existing;
    final nextId = _nextMucJoinAttemptId;
    _nextMucJoinAttemptId++;
    return _ensureRoomSessionForKey(roomKey).ensureJoinAttemptId(nextId);
  }

  int? _joinAttemptIdForKey(String roomKey) =>
      _roomSessionForKey(roomKey)?.joinAttemptId;

  void _clearJoinAttemptId(String roomKey) {
    _roomSessionForKey(roomKey)?.clearJoinAttemptId();
  }

  void _setJoinOperationTracked(String roomKey, bool tracked) {
    if (!tracked) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.tracksJoinOperation = false;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).tracksJoinOperation = true;
  }

  bool _consumeJoinOperationTracked(String roomKey) =>
      _roomSessionForKey(roomKey)?.consumeTrackedJoinOperation() ?? false;

  bool _instantRoomConfigured(String roomKey) =>
      _roomSessionForKey(roomKey)?.instantRoomConfigured == true;

  void _setInstantRoomConfigured(String roomKey, bool configured) {
    if (!configured) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.instantRoomConfigured = false;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).instantRoomConfigured = true;
  }

  bool _instantRoomPending(String roomKey) =>
      _roomSessionForKey(roomKey)?.instantRoomPending == true;

  void _setInstantRoomPending(String roomKey, bool pending) {
    if (!pending) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.instantRoomPending = false;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).instantRoomPending = true;
  }

  Completer<void>? _instantRoomConfigCompleterForKey(String roomKey) =>
      _roomSessionForKey(roomKey)?.instantRoomConfigCompleter;

  void _setInstantRoomConfigCompleterForKey(
    String roomKey,
    Completer<void>? completer,
  ) {
    if (completer == null) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.instantRoomConfigCompleter = null;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).instantRoomConfigCompleter = completer;
  }

  Completer<void>? _postJoinRefreshCompleterForKey(String roomKey) =>
      _roomSessionForKey(roomKey)?.postJoinRefreshCompleter;

  void _setPostJoinRefreshCompleterForKey(
    String roomKey,
    Completer<void>? completer,
  ) {
    if (completer == null) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.postJoinRefreshCompleter = null;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).postJoinRefreshCompleter = completer;
  }

  Completer<void>? _repairCompleterForKey(String roomKey) =>
      _roomSessionForKey(roomKey)?.repairCompleter;

  void _setRepairCompleterForKey(String roomKey, Completer<void>? completer) {
    if (completer == null) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.repairCompleter = null;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).repairCompleter = completer;
  }

  bool _seededDummyRoom(String roomKey) =>
      _roomSessionForKey(roomKey)?.seededDummyRoom == true;

  void _setSeededDummyRoom(String roomKey, bool seeded) {
    if (!seeded) {
      final session = _roomSessionForKey(roomKey);
      if (session != null) {
        session.seededDummyRoom = false;
      }
      return;
    }
    _ensureRoomSessionForKey(roomKey).seededDummyRoom = true;
  }

  void _markRoomJoined(String roomJid) {
    final key = _roomKey(roomJid);
    _setRoomHasLeft(key, false);
    _setRoomExplicitlyLeft(key, false);
  }

  void _markRoomNeedsJoin(String roomJid) {
    _setRoomNeedsJoin(_roomKey(roomJid), true);
  }

  void _clearRoomNeedsJoin(String roomJid) {
    _setRoomNeedsJoin(_roomKey(roomJid), false);
  }

  Future<bool> _ensureMucSupported({String? jid}) async {
    final decision = await _decideMucSupport(jid: jid);
    return decision.isAllowed;
  }

  @override
  Future<void> _reset() async {
    for (final controller in _roomStreams.values.toList(growable: false)) {
      await controller.close();
    }
    _roomStreams.clear();
    for (final controller in _roomSubjectStreams.values.toList(
      growable: false,
    )) {
      await controller.close();
    }
    _roomSubjectStreams.clear();
    _mucBookmarksSync = null;
    _mucMamUnsupportedRooms.clear();
    _outboundGroupchatStanzaRooms.clear();
    await super._reset();
  }

  String get mucServiceHost => _mucServiceHost ?? _defaultMucServiceHost;

  String get _defaultMucServiceHost =>
      'conference.${_myJid?.domain ?? 'example.com'}';

  Set<String> get _supportedMucServiceHosts {
    return {_defaultMucServiceHost.toLowerCase(), _axiMucServiceHost};
  }

  String? _normalizeSupportedMucServiceHost(String? host) {
    final trimmed = host?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    try {
      final parsed = mox.JID.fromString(trimmed);
      final candidate = parsed.domain.trim().toLowerCase();
      if (candidate.isEmpty) {
        return null;
      }
      return _supportedMucServiceHosts.contains(candidate) ? candidate : null;
    } on Exception {
      final candidate = trimmed.toLowerCase();
      if (candidate.isEmpty) {
        return null;
      }
      return _supportedMucServiceHosts.contains(candidate) ? candidate : null;
    }
  }

  bool _isRoomAvatarJid(mox.JID jid) {
    final bareJid = jid.toBare().toString();
    if (bareJid.isEmpty) {
      return false;
    }
    if (roomStateFor(bareJid) != null) {
      return true;
    }
    try {
      return _supportedMucServiceHosts.contains(
        jid.toBare().domain.trim().toLowerCase(),
      );
    } on Exception {
      return false;
    }
  }

  bool _isMucChatJid(String jid) {
    try {
      return _supportedMucServiceHosts.contains(
        mox.JID.fromString(jid).domain.trim().toLowerCase(),
      );
    } on Exception {
      return false;
    }
  }

  String _chatStateMessageType(String jid) {
    if (!_isMucChatJid(jid)) return _messageTypeChat;
    try {
      final parsed = mox.JID.fromString(jid);
      return parsed.resource.isEmpty ? _messageTypeGroupchat : _messageTypeChat;
    } on Exception {
      return _messageTypeChat;
    }
  }

  bool _canQueryMucArchive(String jid) {
    final trimmed = jid.trim();
    if (trimmed.isEmpty) return false;
    late final String bareRoom;
    try {
      bareRoom = mox.JID.fromString(trimmed).toBare().toString();
    } on Exception {
      return false;
    }
    if (_mucMamUnsupportedRooms.contains(bareRoom)) return false;
    if (hasLeftRoom(bareRoom)) return false;
    final roomState = roomStateFor(bareRoom);
    if (roomState == null) return false;
    if (roomState.myOccupantJid == null) return false;
    if (!roomState.hasSelfPresence) return false;
    return true;
  }

  @override
  ChatType _resolvedChatTypeForPeer({required String chatJid, Chat? chat}) {
    if (chat?.type == ChatType.groupChat || _isMucChatJid(chatJid)) {
      return ChatType.groupChat;
    }
    return super._resolvedChatTypeForPeer(chatJid: chatJid, chat: chat);
  }

  @override
  Future<void> _prepareOutboundChatSend({
    required String chatJid,
    required ChatType chatType,
  }) async {
    if (chatType != ChatType.groupChat) {
      await super._prepareOutboundChatSend(
        chatJid: chatJid,
        chatType: chatType,
      );
      return;
    }
    await _ensureMucJoinForSend(roomJid: chatJid);
  }

  @override
  String _outboundSenderJidForChat({
    required String chatJid,
    required String accountJid,
    required ChatType chatType,
  }) {
    if (chatType != ChatType.groupChat) {
      return super._outboundSenderJidForChat(
        chatJid: chatJid,
        accountJid: accountJid,
        chatType: chatType,
      );
    }
    return _outboundMucActorIdentity(
      roomJid: chatJid,
      accountJid: accountJid,
    ).senderJid;
  }

  @override
  Future<void> _sendResolvedChatState({
    required String jid,
    required mox.ChatState state,
    required ChatType chatType,
  }) async {
    if (chatType != ChatType.groupChat) {
      await super._sendResolvedChatState(
        jid: jid,
        state: state,
        chatType: chatType,
      );
      return;
    }
    final messageType = _chatStateMessageType(jid);
    if (messageType != _messageTypeGroupchat) {
      await super._sendResolvedChatState(
        jid: jid,
        state: state,
        chatType: chatType,
      );
      return;
    }
    final roomJid = _normalizeBareJid(jid);
    if (roomJid == null) {
      return;
    }
    final hasPresence = await _hasMucPresenceForSend(roomJid: roomJid);
    if (!hasPresence) {
      return;
    }
    final messageManager = _connection.getManager<mox.MessageManager>();
    if (messageManager == null) {
      return;
    }
    late final mox.JID to;
    try {
      to = mox.JID.fromString(roomJid).toBare();
    } on Exception {
      return;
    }
    await messageManager.sendMessage(
      to,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        state,
        const mox.MessageBodyData(_chatStatePlaceholderBody),
        const mox.MessageProcessingHintData(_chatStateProcessingHints),
      ]),
      type: messageType,
    );
  }

  @override
  void _scheduleArchiveSyncAfterJoin({
    required String chatJid,
    required ChatType chatType,
  }) {
    if (chatType != ChatType.groupChat) {
      super._scheduleArchiveSyncAfterJoin(chatJid: chatJid, chatType: chatType);
      return;
    }
    fireAndForget(() async {
      await _awaitMucJoinCompleterIfActive(chatJid);
      await _syncMucArchiveAfterJoin(chatJid);
    }, operationName: 'MucService.syncMucArchiveAfterJoin');
  }

  Future<void> _syncMucArchiveAfterJoin(String roomJid) async {
    final normalizedRoom = _roomKey(roomJid);
    if (_mucJoinMamSyncRooms.contains(normalizedRoom)) return;
    _mucJoinMamSyncRooms.add(normalizedRoom);
    var started = false;
    var success = false;
    try {
      if (!await resolveMamSupport()) return;
      if (!_canQueryMucArchive(normalizedRoom)) return;
      started = true;
      emitXmppOperation(_mamMucStartEvent);
      final localCount = await countLocalMessages(
        jid: normalizedRoom,
        includePseudoMessages: false,
      );
      final archiveCursor = await loadArchiveCursorTimestamp(normalizedRoom);
      final shouldBackfillLatest = localCount == 0 || archiveCursor == null;

      if (shouldBackfillLatest) {
        await fetchLatestFromArchive(
          jid: normalizedRoom,
          pageSize: mamLoginBackfillMessageLimit,
          isMuc: true,
        );
        success = true;
        return;
      }

      await _catchUpChatFromArchive(
        jid: normalizedRoom,
        since: archiveCursor,
        isMuc: true,
      );
      success = true;
    } on XmppAbortedException {
      return;
    } finally {
      _mucJoinMamSyncRooms.remove(normalizedRoom);
      if (started) {
        emitXmppOperation(success ? _mamMucSuccessEvent : _mamMucFailureEvent);
      }
    }
  }

  @override
  Future<bool> _canFetchArchiveForChat({
    required String chatJid,
    required ChatType chatType,
  }) async {
    if (chatType != ChatType.groupChat) {
      return await super._canFetchArchiveForChat(
        chatJid: chatJid,
        chatType: chatType,
      );
    }
    return _canQueryMucArchive(chatJid);
  }

  bool _isBareMucRoomJidForCapabilities(String jid) {
    final normalizedRoom = _normalizeMucRoomJidCandidate(jid);
    if (normalizedRoom == null) return false;
    try {
      final parsed = mox.JID.fromString(jid);
      if (parsed.resource.isNotEmpty) return false;
    } on Exception {
      return false;
    }
    return _isMucChatJid(normalizedRoom) ||
        roomStateFor(normalizedRoom) != null;
  }

  CalendarFragmentShareDecision calendarFragmentDecisionForChat(Chat chat) {
    return const CalendarChatSupport().decisionForChat(
      chat: chat,
      roomState: roomStateFor(chat.jid),
    );
  }

  CalendarChatRole? _calendarSyncSenderRole(
    mox.MessageEvent event, {
    required String chatJid,
    required ChatType chatType,
  }) {
    if (chatType != ChatType.groupChat) {
      return CalendarChatRole.participant;
    }
    final RoomState? roomState = roomStateFor(chatJid);
    if (roomState == null) {
      return null;
    }
    final Occupant? occupant = _calendarSyncOccupantForSender(
      event,
      roomState: roomState,
    );
    if (occupant == null) {
      return null;
    }
    return occupant.role.calendarChatRole;
  }

  @override
  bool _isInboundMessageMutationAuthorized(mox.MessageEvent event) {
    if (event.type != _messageTypeGroupchat) {
      return super._isInboundMessageMutationAuthorized(event);
    }
    return _isGroupChatMutationAuthorized(event);
  }

  @override
  bool _isInboundPinMutationAuthorized(mox.MessageEvent event) {
    if (event.type != _messageTypeGroupchat) {
      return super._isInboundPinMutationAuthorized(event);
    }
    return _isGroupChatPinMutationAuthorized(event);
  }

  @override
  bool _isSelfMutationEvent(mox.MessageEvent event) {
    if (event.type != _messageTypeGroupchat) {
      return super._isSelfMutationEvent(event);
    }
    return _isSelfPinMutation(event);
  }

  @override
  bool _isSelfArchivedMessageEvent({
    required mox.MessageEvent event,
    required ChatType chatType,
  }) {
    if (chatType != ChatType.groupChat) {
      return super._isSelfArchivedMessageEvent(
        event: event,
        chatType: chatType,
      );
    }
    return _isSelfArchivedGroupChatMessageEvent(event);
  }

  @override
  ({String senderJid, bool identityVerified})
  _resolveInboundReactionSenderIdentity({
    required String senderJid,
    required String chatJid,
    required bool isGroupChat,
  }) {
    if (!isGroupChat) {
      return super._resolveInboundReactionSenderIdentity(
        senderJid: senderJid,
        chatJid: chatJid,
        isGroupChat: isGroupChat,
      );
    }
    return _resolveReactionSenderIdentity(
      senderJid: senderJid,
      chatJid: chatJid,
      isGroupChat: isGroupChat,
    );
  }

  @override
  Set<String> _assumedCapabilityFeatures(String jid) {
    final features = <String>{...super._assumedCapabilityFeatures(jid)};
    if (_isBareMucRoomJidForCapabilities(jid)) {
      features.add(mox.messageReactionsXmlns);
    }
    return features;
  }

  @override
  void _updateUnsupportedArchiveChats(Set<String> chatJids) {
    _mucMamUnsupportedRooms
      ..clear()
      ..addAll(chatJids);
  }

  @override
  CalendarChatRole? _resolvedCalendarSyncSenderRole(
    mox.MessageEvent event, {
    required String chatJid,
    required ChatType chatType,
  }) {
    return _calendarSyncSenderRole(event, chatJid: chatJid, chatType: chatType);
  }

  @override
  Future<Map<String, mox.PubSubAffiliation>?> _pinGroupAffiliations(
    Chat chat,
  ) async {
    final affiliations = _basePinAffiliations();
    if (affiliations == null) {
      return null;
    }
    final roomJid = chat.jid.trim();
    if (roomJid.isEmpty) {
      return null;
    }
    try {
      final members = await fetchRoomMembers(roomJid: roomJid);
      final admins = await fetchRoomAdmins(roomJid: roomJid);
      final owners = await fetchRoomOwners(roomJid: roomJid);
      final entries = <MucAffiliationEntry>[...members, ...admins, ...owners];
      var added = 0;
      for (final entry in entries) {
        final jid = entry.jid?.trim();
        if (jid == null || jid.isEmpty) {
          continue;
        }
        if (affiliations.containsKey(jid)) {
          continue;
        }
        affiliations[jid] = _pinAffiliationPublisher;
        added += 1;
      }
      if (added == 0) {
        return null;
      }
      return affiliations;
    } on Exception {
      return null;
    }
  }

  Occupant? _calendarSyncOccupantForSender(
    mox.MessageEvent event, {
    required RoomState roomState,
  }) {
    return _mucOccupantForSender(event, roomState: roomState);
  }

  Occupant? _mucOccupantForSender(
    mox.MessageEvent event, {
    required RoomState roomState,
  }) {
    return roomState.occupantForSenderJid(event.from.toString());
  }

  bool _isGroupChatMutationAuthorized(mox.MessageEvent event) {
    if (event.type != _messageTypeGroupchat) {
      return true;
    }
    if (event.isFromMAM) {
      return true;
    }
    final roomJid = event.from.toBare().toString();
    if (hasLeftRoom(roomJid)) {
      return false;
    }
    final RoomState? roomState = roomStateFor(roomJid);
    if (roomState == null) {
      return false;
    }
    final Occupant? occupant = _mucOccupantForSender(
      event,
      roomState: roomState,
    );
    return occupant?.isPresent ?? false;
  }

  bool _isGroupChatPinMutationAuthorized(mox.MessageEvent event) {
    if (!_isGroupChatMutationAuthorized(event)) {
      return false;
    }
    if (event.type != _messageTypeGroupchat || event.isFromMAM) {
      return true;
    }
    final roomJid = event.from.toBare().toString();
    final roomState = roomStateFor(roomJid);
    if (roomState == null) {
      return false;
    }
    final occupant = _mucOccupantForSender(event, roomState: roomState);
    return occupant?.affiliation.canManagePins ?? false;
  }

  bool _isSelfPinMutation(mox.MessageEvent event) {
    final accountJid = myJid;
    if (accountJid == null) {
      return false;
    }
    if (event.type != _messageTypeGroupchat) {
      return sameNormalizedAddressValue(
        event.from.toBare().toString(),
        accountJid,
      );
    }
    final roomJid = event.from.toBare().toString();
    final roomState = roomStateFor(roomJid);
    if (roomState == null) {
      return false;
    }
    if (roomState.isSelfOccupantId(event.from.toString())) {
      return true;
    }
    final occupant = _mucOccupantForSender(event, roomState: roomState);
    final realJid = occupant?.realJid?.trim();
    if (realJid == null || realJid.isEmpty) {
      return false;
    }
    return sameNormalizedAddressValue(realJid, accountJid);
  }

  bool _isSelfArchivedGroupChatMessageEvent(mox.MessageEvent event) {
    if (event.type != _messageTypeGroupchat) {
      return false;
    }
    if (_isSelfPinMutation(event)) {
      return true;
    }
    final accountJid = myJid;
    if (accountJid == null) {
      return false;
    }
    final roomJid = event.from.toBare().toString();
    final roomState = roomStateFor(roomJid);
    if (roomState == null) {
      return false;
    }
    final occupant = _mucOccupantForSender(event, roomState: roomState);
    final realJid = occupant?.realJid?.trim();
    if (realJid != null && realJid.isNotEmpty) {
      return sameNormalizedAddressValue(realJid, accountJid);
    }
    return false;
  }

  ({String senderJid, bool identityVerified}) _resolveReactionSenderIdentity({
    required String senderJid,
    required String chatJid,
    required bool isGroupChat,
  }) {
    final accountJid = myJid;
    if (!isGroupChat) {
      return (
        senderJid: bareAddress(senderJid) ?? senderJid,
        identityVerified: true,
      );
    }
    final normalizedChatJid = bareAddress(chatJid) ?? chatJid;
    if (accountJid != null &&
        sameNormalizedAddressValue(senderJid, accountJid)) {
      return (senderJid: accountJid, identityVerified: true);
    }
    final roomState = roomStateFor(normalizedChatJid);
    if (roomState != null) {
      final myOccupantJid = roomState.myOccupantJid?.trim();
      if (accountJid != null &&
          myOccupantJid != null &&
          myOccupantJid.isNotEmpty &&
          senderJid == myOccupantJid) {
        return (senderJid: accountJid, identityVerified: true);
      }
      final occupant = roomState.occupantForSenderJid(
        senderJid,
        preferRealJid: true,
      );
      final realJid = occupant?.realJid?.trim();
      if (realJid != null && realJid.isNotEmpty) {
        if (accountJid != null &&
            sameNormalizedAddressValue(realJid, accountJid)) {
          return (senderJid: accountJid, identityVerified: true);
        }
        return (
          senderJid: bareAddress(realJid) ?? realJid,
          identityVerified: true,
        );
      }
      if (occupant != null) {
        return (senderJid: occupant.occupantId, identityVerified: false);
      }
    }
    if (senderJid.startsWith('$normalizedChatJid/')) {
      return (senderJid: senderJid, identityVerified: false);
    }
    return (
      senderJid: bareAddress(senderJid) ?? senderJid,
      identityVerified: false,
    );
  }

  bool _matchesStanzaErrorType(String? errorType, String expected) {
    if (errorType == null) return true;
    return errorType == expected;
  }

  bool _shouldAttemptMucRepair(StanzaErrorConditionData? conditionData) {
    if (conditionData == null) return false;
    final String condition = conditionData.condition;
    final String? errorType = conditionData.type;
    if (condition == _errorConditionNotAcceptable &&
        _matchesStanzaErrorType(errorType, _errorTypeModify)) {
      return true;
    }
    if (condition == _errorConditionResourceConstraint &&
        _matchesStanzaErrorType(errorType, _errorTypeWait)) {
      return true;
    }
    if (condition == _errorConditionServiceUnavailable &&
        _matchesStanzaErrorType(errorType, _errorTypeCancel)) {
      return true;
    }
    return false;
  }

  bool _shouldAttemptMucRepairForRoom({
    required String roomJid,
    required StanzaErrorConditionData? conditionData,
  }) {
    if (!_shouldAttemptMucRepair(conditionData)) return false;
    late final String key;
    try {
      key = _roomKey(roomJid);
    } on Exception {
      return false;
    }
    final RoomState? room = _roomStates[key];
    if (room == null) return false;
    if (room.wasBanned ||
        room.wasKicked ||
        room.roomShutdown ||
        room.blocksAutoRejoin) {
      return false;
    }

    final String condition = conditionData?.condition ?? '';
    final String? errorType = conditionData?.type;
    if (condition == _errorConditionNotAcceptable &&
        _matchesStanzaErrorType(errorType, _errorTypeModify)) {
      return true;
    }

    final bool pendingConfig = _instantRoomPending(key);
    if (pendingConfig) return true;
    if (room.roomCreated) return true;
    return room.hasSelfPresence != true;
  }

  String? _resolveGroupChatRoomJid({
    required mox.MessageEvent event,
    required String? summaryChatJid,
  }) {
    final String? normalizedSummaryJid = _normalizeMucRoomJidCandidate(
      summaryChatJid,
    );
    if (normalizedSummaryJid != null) return normalizedSummaryJid;
    final String? fromBare = _normalizeMucRoomJidCandidate(
      event.from.toBare().toString(),
    );
    final String? toBare = _normalizeMucRoomJidCandidate(
      event.to.toBare().toString(),
    );
    final String? ownBare = normalizedBareAddressValue(
      _myJid?.toBare().toString(),
    );
    if (ownBare == null || ownBare.isEmpty) {
      return fromBare ?? toBare;
    }
    if (fromBare != null && fromBare != ownBare) return fromBare;
    if (toBare != null && toBare != ownBare) return toBare;
    return null;
  }

  String? _resolveGroupChatRoomJidFromEvent(mox.MessageEvent event) {
    final String? fromBare = _normalizeMucRoomJidCandidate(
      event.from.toBare().toString(),
    );
    final String? toBare = _normalizeMucRoomJidCandidate(
      event.to.toBare().toString(),
    );
    final String? ownBare = normalizedBareAddressValue(
      _myJid?.toBare().toString(),
    );
    if (ownBare == null || ownBare.isEmpty) {
      return fromBare ?? toBare;
    }
    if (fromBare != null && fromBare != ownBare) return fromBare;
    if (toBare != null && toBare != ownBare) return toBare;
    return null;
  }

  Future<String?> _resolveGroupChatRoomJidFromDb(String stanzaId) async {
    final trimmed = stanzaId.trim();
    if (trimmed.isEmpty) return null;
    try {
      final message = await _dbOpReturning<XmppDatabase, Message?>(
        (db) => db.getMessageByStanzaID(trimmed),
      );
      if (message == null) return null;
      return _normalizeMucRoomJidCandidate(message.chatJid);
    } on XmppAbortedException {
      return null;
    }
  }

  bool _shouldClearMucPresenceForError(
    StanzaErrorConditionData? conditionData,
  ) {
    if (conditionData == null) return false;
    final condition = conditionData.condition;
    final errorType = conditionData.type;
    if (condition == _errorConditionNotAcceptable &&
        _matchesStanzaErrorType(errorType, _errorTypeModify)) {
      return true;
    }
    return condition == _errorConditionServiceUnavailable &&
        _matchesStanzaErrorType(errorType, _errorTypeCancel);
  }

  void _trackOutboundGroupchatStanza({
    required String stanzaId,
    required String roomJid,
  }) {
    final trimmedId = stanzaId.trim();
    if (trimmedId.isEmpty) return;
    final normalizedRoom = _normalizeMucRoomJidCandidate(roomJid);
    if (normalizedRoom == null) return;
    _outboundGroupchatStanzaRooms[trimmedId] = normalizedRoom;
    _trimOutboundGroupchatStanzas();
  }

  String? _takeOutboundGroupchatRoomJid(String stanzaId) {
    final trimmedId = stanzaId.trim();
    if (trimmedId.isEmpty) return null;
    return _outboundGroupchatStanzaRooms.remove(trimmedId);
  }

  void _trimOutboundGroupchatStanzas() {
    if (_outboundGroupchatStanzaRooms.length <= _outboundSummaryLimit) {
      return;
    }
    final oldestKey = _outboundGroupchatStanzaRooms.keys.first;
    _outboundGroupchatStanzaRooms.remove(oldestKey);
  }

  Future<void> _handleOutboundMessageError(
    OutboundMessageErrorEvent event,
  ) async {
    final summaryIsGroupChat = event.summaryChatType == ChatType.groupChat;
    final mappedRoomJid = _takeOutboundGroupchatRoomJid(event.stanzaId);
    if (!summaryIsGroupChat && mappedRoomJid == null) {
      return;
    }
    await _maybeRepairMucRoomAfterMessageError(
      event: event.stanzaEvent,
      stanzaId: event.stanzaId,
      summaryIsGroupChat: summaryIsGroupChat,
      summaryChatJid: event.summaryChatJid,
      mappedRoomJid: mappedRoomJid,
      shouldPersistError: event.shouldPersistError,
      errorCondition: event.errorCondition,
    );
  }

  Future<void> _maybeRepairMucRoomAfterMessageError({
    required mox.MessageEvent event,
    required String stanzaId,
    required bool summaryIsGroupChat,
    required String? summaryChatJid,
    required String? mappedRoomJid,
    required bool shouldPersistError,
    required StanzaErrorConditionData? errorCondition,
  }) async {
    String? roomJid = summaryIsGroupChat
        ? _resolveGroupChatRoomJid(event: event, summaryChatJid: summaryChatJid)
        : _resolveGroupChatRoomJidFromEvent(event);
    roomJid ??= mappedRoomJid;
    roomJid ??= await _resolveGroupChatRoomJidFromDb(stanzaId);
    if (roomJid == null || !_isMucChatJid(roomJid)) {
      return;
    }
    if (!_shouldAttemptMucRepairForRoom(
      roomJid: roomJid,
      conditionData: errorCondition,
    )) {
      return;
    }
    final resolvedRoomJid = roomJid;
    _markRoomNeedsJoin(resolvedRoomJid);
    if (shouldPersistError && _shouldClearMucPresenceForError(errorCondition)) {
      await _markRoomLeft(
        resolvedRoomJid,
        statusCodes: _emptyStatusCodes,
        preserveOccupants: _preserveOccupantsOnMucError,
      );
    }
    unawaited(_ensureRoomRepairTask(resolvedRoomJid));
  }

  @override
  List<mox.XmppManagerBase> get featureManagers => <mox.XmppManagerBase>[
    ...super.featureManagers,
    RoomAwareUserAvatarManager(shouldSkipJid: _isRoomAvatarJid),
    RoomAwareVCardManager(isRoomJid: _isRoomAvatarJid),
  ];

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    BookmarksManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    bookmarksNotifyFeature,
  ];

  Future<void> setMucServiceHost(String? host) async {
    final trimmed = host?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _mucServiceHost = null;
      await _persistMucServiceHost(null);
      return;
    }
    final normalized = _normalizeSupportedMucServiceHost(trimmed);
    if (normalized == null) {
      return;
    }
    if (_mucServiceHost == normalized) return;
    _mucServiceHost = normalized;
    await _persistMucServiceHost(normalized);
  }

  void _restoreMucServiceHost(String? host) {
    final normalized = _normalizeSupportedMucServiceHost(host);
    if (normalized == null) return;
    _mucServiceHost = normalized;
  }

  Future<void> _persistMucServiceHost(String? host) async {
    final normalized = host?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _dbOp<XmppStateStore>(
        (ss) => ss.delete(key: _mucServiceHostStorageKey),
        awaitDatabase: true,
      );
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) => ss.write(key: _mucServiceHostStorageKey, value: normalized),
      awaitDatabase: true,
    );
  }

  Future<void> _prepareMucRoomsFromStateStore() async {
    final manager = _connection.getManager<MUCManager>();
    if (manager == null) return;
    final rooms = await _loadMucPrejoinRooms();
    if (rooms.isEmpty) return;
    final joins = <mox.MUCRoomJoin>[];
    for (final room in rooms) {
      final roomJid = _normalizeBareJid(room.roomJid);
      if (roomJid == null || roomJid.isEmpty) continue;
      final nickname = room.nickname.trim();
      if (nickname.isEmpty) continue;
      final jid = mox.JID.fromString(roomJid).toBare();
      joins.add((jid, nickname));
      _setRoomNicknameForKey(_roomKey(roomJid), nickname);
    }
    if (joins.isEmpty) return;
    await manager.prepareRoomList(joins);
  }

  Future<List<MucPrejoinRoom>> _loadMucPrejoinRooms() async {
    final stored = await _dbOpReturning<XmppStateStore, Object?>(
      (ss) => ss.read(key: _mucPrejoinRoomsStorageKey),
    );
    if (stored is! List) return _emptyMucPrejoinRooms;
    final roomsByJid = <String, MucPrejoinRoom>{};
    for (final entry in stored) {
      final room = MucPrejoinRoom.fromJson(entry);
      if (room == null) continue;
      final normalizedRoom = _normalizeBareJid(room.roomJid);
      if (normalizedRoom == null || normalizedRoom.isEmpty) continue;
      final nickname = room.nickname.trim();
      if (nickname.isEmpty) continue;
      roomsByJid[normalizedRoom] = MucPrejoinRoom(
        roomJid: normalizedRoom,
        nickname: nickname,
      );
    }
    if (roomsByJid.isEmpty) return _emptyMucPrejoinRooms;
    return List<MucPrejoinRoom>.unmodifiable(roomsByJid.values);
  }

  Future<void> _persistMucPrejoinRooms(List<MucPrejoinRoom> rooms) async {
    if (rooms.isEmpty) {
      await _dbOp<XmppStateStore>(
        (ss) async => ss.delete(key: _mucPrejoinRoomsStorageKey),
        awaitDatabase: true,
      );
      return;
    }
    final uniqueByRoom = <String, MucPrejoinRoom>{};
    for (final room in rooms) {
      final normalizedRoom = _normalizeBareJid(room.roomJid);
      if (normalizedRoom == null || normalizedRoom.isEmpty) continue;
      final nickname = room.nickname.trim();
      if (nickname.isEmpty) continue;
      uniqueByRoom[normalizedRoom] = MucPrejoinRoom(
        roomJid: normalizedRoom,
        nickname: nickname,
      );
    }
    final payload = uniqueByRoom.values
        .map((room) => room.toJson())
        .toList(growable: false);
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(key: _mucPrejoinRoomsStorageKey, value: payload),
      awaitDatabase: true,
    );
  }

  Future<void> _persistMucPrejoinRoomsFromBookmarks(
    List<MucBookmark> bookmarks,
  ) async {
    final rooms = await _collectMucPrejoinRoomsFromBookmarks(bookmarks);
    await _persistMucPrejoinRooms(rooms);
  }

  Future<List<MucPrejoinRoom>> _collectMucPrejoinRoomsFromBookmarks(
    List<MucBookmark> bookmarks,
  ) async {
    if (bookmarks.isEmpty) return _emptyMucPrejoinRooms;
    final roomsByJid = <String, MucPrejoinRoom>{};
    for (final bookmark in bookmarks) {
      if (!bookmark.autojoin) continue;
      final roomJid = bookmark.roomBare.toBare().toString();
      final normalizedRoom = _normalizeBareJid(roomJid);
      if (normalizedRoom == null || normalizedRoom.isEmpty) continue;
      final nickname = (await _resolveMucPrejoinNickname(bookmark)).trim();
      if (nickname.isEmpty) continue;
      roomsByJid[normalizedRoom] = MucPrejoinRoom(
        roomJid: normalizedRoom,
        nickname: nickname,
      );
    }
    if (roomsByJid.isEmpty) return _emptyMucPrejoinRooms;
    return List<MucPrejoinRoom>.unmodifiable(roomsByJid.values);
  }

  RegisteredStateKey _roomMemberSnapshotStorageKey(String roomJid) =>
      XmppStateStore.registerKey(
        '$_mucRoomMemberSnapshotStorageKeyPrefix${_roomKey(roomJid)}',
      );

  Iterable<_PersistedRoomMember> _snapshotMembersForRoom(RoomState room) sync* {
    final seen = <String>{};
    for (final occupant in room.occupants.values) {
      if (occupant.affiliation.isOutcast) continue;
      final trimmedNick = occupant.nick.trim();
      final trimmedOccupantId = occupant.occupantId.trim();
      final trimmedRealJid = occupant.realJid?.trim();
      if (!occupant.hasResolvedMembershipState &&
          !(trimmedRealJid?.isNotEmpty == true)) {
        continue;
      }
      final dedupeKey = trimmedRealJid?.isNotEmpty == true
          ? 'jid:${_normalizeBareJid(trimmedRealJid!)}'
          : trimmedOccupantId.isNotEmpty
          ? 'occupant:$trimmedOccupantId'
          : 'nick:${trimmedNick.toLowerCase()}';
      if (!seen.add(dedupeKey)) continue;
      yield _PersistedRoomMember(
        nick: trimmedNick,
        occupantId: trimmedOccupantId.isEmpty ? null : trimmedOccupantId,
        realJid: trimmedRealJid?.isNotEmpty == true ? trimmedRealJid : null,
        affiliation: occupant.affiliation,
        role: occupant.role,
      );
      if (seen.length >= _roomMemberSnapshotLimit) {
        return;
      }
    }
  }

  Future<void> _persistRoomMemberSnapshot(RoomState room) async {
    final snapshot = _snapshotMembersForRoom(room).toList(growable: false);
    if (snapshot.isEmpty) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) => ss.write(
        key: _roomMemberSnapshotStorageKey(room.roomJid),
        value: snapshot.map((entry) => entry.toJson()).toList(growable: false),
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _clearPersistedRoomMemberSnapshot(String roomJid) async {
    await _dbOp<XmppStateStore>(
      (ss) => ss.delete(key: _roomMemberSnapshotStorageKey(roomJid)),
      awaitDatabase: true,
    );
  }

  Future<List<_PersistedRoomMember>> _loadPersistedRoomMemberSnapshot(
    String roomJid,
  ) async {
    final stored = await _dbOpReturning<XmppStateStore, Object?>(
      (ss) => ss.read(key: _roomMemberSnapshotStorageKey(roomJid)),
    );
    if (stored is! List) {
      return const <_PersistedRoomMember>[];
    }
    final members = <_PersistedRoomMember>[];
    for (final value in stored) {
      final entry = _PersistedRoomMember.fromJson(value);
      if (entry == null) continue;
      members.add(entry);
      if (members.length >= _roomMemberSnapshotLimit) {
        break;
      }
    }
    return List<_PersistedRoomMember>.unmodifiable(members);
  }

  Future<void> _restorePersistedRoomMembers(String roomJid) async {
    final roomKey = _roomKey(roomJid);
    final emptyRoom = RoomState(roomJid: roomKey, occupants: const {});
    for (final member in await _loadPersistedRoomMemberSnapshot(roomJid)) {
      final nick = member.nick.trim();
      final persistedOccupantId = member.occupantId?.trim();
      final realJid = member.realJid?.trim();
      final occupantId = persistedOccupantId?.isNotEmpty == true
          ? persistedOccupantId
          : nick.isNotEmpty
          ? '$roomKey/$nick'
          : realJid == null || realJid.isEmpty
          ? null
          : emptyRoom.syntheticOccupantIdForAffiliationJid(realJid);
      if (occupantId == null || occupantId.isEmpty) {
        continue;
      }
      _upsertOccupant(
        roomJid: roomJid,
        occupantId: occupantId,
        nick: nick.isNotEmpty
            ? nick
            : emptyRoom.fallbackNickForAffiliationJid(realJid!),
        realJid: realJid,
        affiliation: member.affiliation,
        role: member.role,
        isPresent: false,
      );
    }
  }

  void _publishRoomState({
    required String roomKey,
    required RoomState room,
    bool persistSnapshot = true,
  }) {
    _roomStates[roomKey] = room;
    _roomStreams[roomKey]?.add(room);
    if (!persistSnapshot) {
      return;
    }
    fireAndForget(
      () => _persistRoomMemberSnapshot(room),
      operationName: 'MucService.persistRoomMemberSnapshot',
    );
  }

  Future<String> _resolveMucPrejoinNickname(MucBookmark bookmark) async {
    final trimmedBookmarkNick = bookmark.nick?.trim();
    if (trimmedBookmarkNick?.isNotEmpty == true) {
      return trimmedBookmarkNick!;
    }
    final roomJid = bookmark.roomBare.toBare().toString();
    final cachedNickname = _roomNicknameForKey(roomJid);
    if (cachedNickname?.isNotEmpty == true) {
      return cachedNickname!;
    }
    if (isDatabaseReady) {
      final storedNickname = await _dbOpReturning<XmppDatabase, String?>(
        (db) async => (await db.getChat(roomJid))?.myNickname,
      );
      final trimmedStored = storedNickname?.trim();
      if (trimmedStored?.isNotEmpty == true) {
        return trimmedStored!;
      }
    }
    return _nickForRoom(null);
  }

  Future<void> _updateMucPrejoinRoomsForBookmark(MucBookmark bookmark) async {
    final roomJid = _normalizeBareJid(bookmark.roomBare.toString());
    if (roomJid == null || roomJid.isEmpty) return;
    final existing = await _loadMucPrejoinRooms();
    if (existing.isEmpty && !bookmark.autojoin) return;
    final roomsByJid = <String, MucPrejoinRoom>{};
    for (final room in existing) {
      final normalizedRoom = _normalizeBareJid(room.roomJid);
      if (normalizedRoom == null || normalizedRoom.isEmpty) continue;
      roomsByJid[normalizedRoom] = room;
    }
    if (!bookmark.autojoin) {
      if (!roomsByJid.containsKey(roomJid)) return;
      roomsByJid.remove(roomJid);
      await _persistMucPrejoinRooms(roomsByJid.values.toList(growable: false));
      return;
    }
    final nickname = (await _resolveMucPrejoinNickname(bookmark)).trim();
    if (nickname.isEmpty) return;
    roomsByJid[roomJid] = MucPrejoinRoom(roomJid: roomJid, nickname: nickname);
    await _persistMucPrejoinRooms(roomsByJid.values.toList(growable: false));
  }

  Future<void> _removeMucPrejoinRoom(mox.JID roomBare) async {
    final roomJid = _normalizeBareJid(roomBare.toString());
    if (roomJid == null || roomJid.isEmpty) return;
    final existing = await _loadMucPrejoinRooms();
    if (existing.isEmpty) return;
    final updated = existing
        .where((room) => !_sameBareJid(room.roomJid, roomJid))
        .toList(growable: false);
    if (updated.length == existing.length) return;
    await _persistMucPrejoinRooms(updated);
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _mucServiceDiscoveryBootstrapOperationName,
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
        },
        operationName: _mucServiceDiscoveryBootstrapOperationName,
        run: () async {
          await discoverMucServiceHost();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _mucBookmarksBootstrapOperationName,
        priority: 0,
        lane: 'mucBookmarks',
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _mucBookmarksBootstrapOperationName,
        run: () async {
          await syncMucBookmarksSnapshot();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _mucRoomAvatarBootstrapOperationName,
        priority: 1,
        lane: 'mucBookmarks',
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _mucRoomAvatarBootstrapOperationName,
        run: () async {
          await _refreshRoomAvatarsFromLatestBookmarks();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _mucAutojoinBootstrapOperationName,
        priority: 1,
        lane: 'mucBookmarks',
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
        },
        operationName: _mucAutojoinBootstrapOperationName,
        run: () async {
          await _autojoinLatestBookmarkedRooms();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _mucResumeRecoveryOperationName,
        priority: 2,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.resumedNegotiation,
        },
        operationName: _mucResumeRecoveryOperationName,
        run: () async {
          await _recoverRoomsAfterResume();
        },
      ),
    );
    manager
      ..registerHandler<mox.ConnectionStateChangedEvent>((event) async {
        if (event.state == ConnectionState.connected) return;
        await _clearSelfPresenceOnDisconnect();
      })
      ..registerHandler<MucSelfPresenceEvent>((event) async {
        await _handleSelfPresence(event);
      })
      ..registerHandler<mox.MessageEvent>((event) async {
        _handleInboundOccupantUpsert(event);
      })
      ..registerHandler<OutboundGroupchatStanzaEvent>((event) async {
        _trackOutboundGroupchatStanza(
          stanzaId: event.stanzaId,
          roomJid: event.roomJid,
        );
      })
      ..registerHandler<OutboundGroupchatStanzaRejectedEvent>((event) async {
        _takeOutboundGroupchatRoomJid(event.stanzaId);
      })
      ..registerHandler<OutboundMessageErrorEvent>((event) async {
        await _handleOutboundMessageError(event);
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
      ..registerHandler<RoomVCardAvatarUpdatedEvent>((event) async {
        final bareJid = _normalizeBareJid(event.jid.toBare().toString());
        if (bareJid == null || bareJid.isEmpty) return;
        if (!_isRoomAvatarJid(event.jid)) {
          return;
        }
        if (event.hash.isEmpty) {
          await _clearAvatarForJid(
            bareJid,
            reason: AvatarService._avatarClearReasonVcardEmpty,
          );
          return;
        }
        await _refreshRoomAvatar(bareJid, expectedHash: event.hash);
      })
      ..registerHandler<mox.OwnDataChangedEvent>((event) async {
        await _handleOwnDataChanged(
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
        try {
          await applyMucBookmarks([event.bookmark]);
        } finally {
          await _updateMucPrejoinRoomsForBookmark(event.bookmark);
        }
      })
      ..registerHandler<MucBookmarkRetractedEvent>((event) async {
        try {
          await _applyBookmarkRetraction(event.roomBare);
        } finally {
          await _removeMucPrejoinRoom(event.roomBare);
        }
      });
  }

  Stream<RoomState> roomStateStream(String roomJid) {
    final key = _roomKey(roomJid);
    late final StreamController<RoomState> controller;
    controller = _roomStreams.putIfAbsent(
      key,
      () => StreamController<RoomState>.broadcast(
        onListen: () {
          final current = _roomStates[key];
          if (current != null) {
            controller.add(current);
          }
        },
      ),
    );
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

  RoomState roomStateForOrEmpty(String roomJid) =>
      roomStateFor(roomJid) ?? RoomState(roomJid: _roomKey(roomJid));

  String? roomSubjectFor(String roomJid) => _roomSubjects[_roomKey(roomJid)];

  bool hasLeftRoom(String roomJid) => _roomHasLeft(_roomKey(roomJid));

  Future<mox.RoomState?> _mucManagerRoomState(String roomJid) async {
    final manager = _connection.getManager<MUCManager>();
    if (manager == null) return null;
    late final mox.JID roomBare;
    try {
      roomBare = mox.JID.fromString(roomJid).toBare();
    } on Exception {
      return null;
    }
    return manager.getRoomState(roomBare);
  }

  Future<void> _setMucManagerJoinedState({
    required String roomJid,
    required bool joined,
  }) async {
    final managerState = await _mucManagerRoomState(roomJid);
    if (managerState == null) return;
    managerState.joined = joined;
  }

  Future<bool> _hasMucPresenceForSend({required String roomJid}) async {
    late final String normalizedRoom;
    try {
      normalizedRoom = _roomKey(roomJid);
    } on Exception {
      return false;
    }
    final roomState = roomStateFor(normalizedRoom);
    if (roomState == null) return false;
    if (_instantRoomPending(normalizedRoom)) {
      return false;
    }
    if (roomState.roomCreated) {
      return false;
    }
    if (_roomNeedsJoin(normalizedRoom)) return false;
    if (!roomState.isReadyForMessaging) return false;
    final managerState = await _mucManagerRoomState(normalizedRoom);
    if (managerState == null) {
      return false;
    }
    if (managerState.joined != true) {
      return false;
    }
    final selfNick = roomState.selfNick?.trim();
    if (selfNick?.isNotEmpty == true && managerState.nick?.trim() != selfNick) {
      return false;
    }
    return true;
  }

  MucActorIdentity _outboundMucActorIdentity({
    required String roomJid,
    required String accountJid,
  }) {
    final normalizedRoomJid = _roomKey(roomJid);
    final roomState = roomStateFor(normalizedRoomJid);
    final occupantJid = roomState?.myOccupantJid?.trim();
    final occupant = roomState?.selfOccupant;
    final occupantNick = occupant?.nick.trim();
    final rememberedNick = _roomNicknameForKey(normalizedRoomJid)?.trim();
    final resolvedNick = occupantNick?.isNotEmpty == true
        ? occupantNick
        : rememberedNick;
    if (occupantJid != null &&
        occupantJid.isNotEmpty &&
        roomState?.isRoomNickOccupantId(occupantJid) == true) {
      return MucActorIdentity.room(occupantJid: occupantJid);
    }
    if (resolvedNick == null || resolvedNick.isEmpty) {
      return MucActorIdentity.direct(senderJid: accountJid);
    }
    return MucActorIdentity.room(
      occupantJid: '$normalizedRoomJid/$resolvedNick',
    );
  }

  Future<void> _ensureMucJoinForSend({required String roomJid}) async {
    late final String normalizedRoom;
    try {
      normalizedRoom = _roomKey(roomJid);
    } on Exception {
      throw XmppMessageException();
    }
    final manager = _connection.getManager<MUCManager>();
    if (manager == null) {
      throw XmppMessageException();
    }
    await _logMucSendDiagnostics(roomJid: normalizedRoom, phase: 'pre-check');
    if (await _hasMucPresenceForSend(roomJid: normalizedRoom)) {
      await _awaitInstantRoomConfigurationIfNeeded(normalizedRoom);
      return;
    }

    try {
      await ensureJoined(
        roomJid: normalizedRoom,
        allowRejoin: _mucSendAllowRejoin,
      );
    } on Exception {
      // Join failures are surfaced by the follow-up presence check.
    }
    await _awaitMucJoinCompleterIfActive(normalizedRoom);

    await _logMucSendDiagnostics(roomJid: normalizedRoom, phase: 'post-join');
    if (await _hasMucPresenceForSend(roomJid: normalizedRoom)) {
      await _awaitInstantRoomConfigurationIfNeeded(normalizedRoom);
      return;
    }

    throw XmppMessageException();
  }

  Future<void> _awaitMucJoinCompleterIfActive(String roomJid) async {
    final String normalizedRoom = _roomKey(roomJid);
    final joinCompleter = _joinCompleterForKey(normalizedRoom);
    if (joinCompleter == null || joinCompleter.isCompleted) return;
    try {
      await joinCompleter.future.timeout(_mucJoinTimeout);
    } on TimeoutException {
      // Join timeouts are handled by the join attempt that owns the completer.
    } on Exception {
      // Join failures are surfaced by the follow-up presence check.
    }
  }

  Future<void> _logMucSendDiagnostics({
    required String roomJid,
    required String phase,
  }) async {
    if (!kDebugMode) {
      return;
    }
    late final String normalizedRoom;
    try {
      normalizedRoom = _roomKey(roomJid);
    } on Exception {
      _mucLog.fine('MUC send diagnostics ($phase): invalid room JID.');
      return;
    }
    final roomState = roomStateFor(normalizedRoom);
    final managerState = await _mucManagerRoomState(normalizedRoom);
    final managerJoined = managerState?.joined == true;
    final managerNick = managerState?.nick?.trim();
    final managerNickPresent = managerNick?.isNotEmpty == true;
    final pendingConfig = _instantRoomPending(normalizedRoom);
    final roomCreated = roomState?.roomCreated == true;
    final needsJoin = _roomNeedsJoin(normalizedRoom);
    final hasSelfPresence = roomState?.hasSelfPresence == true;
    final hasSelfStatus =
        roomState?.selfPresenceStatusCodes.contains(
          MucStatusCode.selfPresence.code,
        ) ==
        true;
    final myOccupantJid = roomState?.myOccupantJid;
    final myOccupantJidPresent = myOccupantJid?.trim().isNotEmpty == true;
    final expectedOccupantJidMatches =
        managerNickPresent &&
        myOccupantJidPresent &&
        myOccupantJid == '$normalizedRoom/$managerNick';
    final selfOccupantPresent =
        myOccupantJidPresent && roomState?.selfOccupant?.isPresent == true;
    final hasPresenceForSend = await _hasMucPresenceForSend(
      roomJid: normalizedRoom,
    );
    final occupantCount = roomState?.occupants.length ?? 0;
    final statusCount = roomState?.selfPresenceStatusCodes.length ?? 0;
    final socketWrapper = _connection.socketWrapper;
    final socketType = socketWrapper.runtimeType;
    final resource = _connection.hasConnectionSettings
        ? _connection.connectionSettings.jid.resource.trim()
        : null;
    final resourcePresent = resource?.isNotEmpty == true;
    final connectionId = identityHashCode(_connection);
    _mucLog.fine(
      'MUC send diagnostics ($phase): '
      'conn=$connectionId '
      'socket=$socketType '
      'resource=$resourcePresent '
      'pendingConfig=$pendingConfig '
      'roomCreated=$roomCreated '
      'needsJoin=$needsJoin '
      'managerState=${managerState != null} '
      'managerJoined=$managerJoined '
      'managerNick=$managerNickPresent '
      'roomState=${roomState != null} '
      'selfPresence=$hasSelfPresence '
      'selfStatus=$hasSelfStatus '
      'occupantJid=$myOccupantJidPresent '
      'occupantJidMatch=$expectedOccupantJidMatches '
      'occupantPresent=$selfOccupantPresent '
      'presenceForSend=$hasPresenceForSend '
      'occupants=$occupantCount '
      'statusCodes=$statusCount',
    );
  }

  void _logJoinEvent({
    required String message,
    int? attemptId,
    bool? hasSelfPresence,
    bool? joinCompleterActive,
    bool? joinInFlight,
    bool? managerPresence,
    bool? usedFallbackStatusCodes,
    bool? isErrorPresence,
    bool? isAvailablePresence,
    bool? isNickChange,
    int? statusCount,
    bool? hasSelfStatus,
    bool? error,
  }) {
    final parts = <String>[message];
    if (attemptId != null) {
      parts.add(_mucJoinAttemptIdLabel + attemptId.toString());
    }
    if (hasSelfPresence != null) {
      parts.add(_mucJoinHasSelfPresenceLabel + hasSelfPresence.toString());
    }
    if (joinCompleterActive != null) {
      parts.add(
        _mucJoinJoinCompleterActiveLabel + joinCompleterActive.toString(),
      );
    }
    if (joinInFlight != null) {
      parts.add(_mucJoinInFlightLabel + joinInFlight.toString());
    }
    if (managerPresence != null) {
      parts.add(_mucJoinManagerPresenceLabel + managerPresence.toString());
    }
    if (usedFallbackStatusCodes != null) {
      parts.add(_mucJoinUsedFallbackLabel + usedFallbackStatusCodes.toString());
    }
    if (isErrorPresence != null) {
      parts.add(_mucJoinIsErrorLabel + isErrorPresence.toString());
    }
    if (isAvailablePresence != null) {
      parts.add(_mucJoinIsAvailableLabel + isAvailablePresence.toString());
    }
    if (isNickChange != null) {
      parts.add(_mucJoinIsNickChangeLabel + isNickChange.toString());
    }
    if (statusCount != null) {
      parts.add(_mucJoinStatusCountLabel + statusCount.toString());
    }
    if (hasSelfStatus != null) {
      parts.add(_mucJoinHasSelfStatusLabel + hasSelfStatus.toString());
    }
    if (error != null) {
      parts.add(_mucJoinErrorLabel + error.toString());
    }
    _mucLog.fine(parts.join(_mucJoinLogSeparator));
  }

  void _seedRoomSelfOccupantJid({
    required String roomJid,
    required String nickname,
  }) {
    final normalizedRoom = _roomKey(roomJid);
    final trimmedNickname = nickname.trim();
    if (trimmedNickname.isEmpty) {
      return;
    }
    const resourceSeparator = '/';
    final occupantJid = '$normalizedRoom$resourceSeparator$trimmedNickname';
    final existing =
        _roomStates[normalizedRoom] ??
        RoomState(roomJid: normalizedRoom, occupants: const {});
    if (existing.isSelfOccupantId(occupantJid)) {
      return;
    }
    final updated = existing.withSelfOccupantId(occupantJid);
    _publishRoomState(roomKey: normalizedRoom, room: updated);
  }

  void _prepareRoomStateForFreshJoin(String roomJid) {
    final key = _roomKey(roomJid);
    final existing = _roomStates[key];
    if (existing == null) return;
    final updated = existing
        .withSelfOccupantUnavailable()
        .withoutPresenceAndJoinState();
    if (identical(updated, existing)) return;
    _publishRoomState(roomKey: key, room: updated);
  }

  Future<void> _clearSelfPresenceOnDisconnect() async {
    await _invalidateSelfPresence(markNeedsJoin: false);
  }

  Future<void> _invalidateSelfPresence({required bool markNeedsJoin}) async {
    if (_roomStates.isEmpty) return;
    if (!markNeedsJoin) {
      for (final session in _roomSessions.values) {
        session.needsJoin = false;
      }
    }
    for (final session in _roomSessions.values) {
      session.pendingOwnData = null;
      session.postJoinRefreshCompleter = null;
    }
    for (final entry in _roomStates.entries.toList(growable: false)) {
      final key = entry.key;
      final room = entry.value;
      await _setMucManagerJoinedState(roomJid: key, joined: false);
      if (markNeedsJoin && !_roomHasLeft(key) && !_roomExplicitlyLeft(key)) {
        _setRoomNeedsJoin(key, true);
      }
      final cleared = room
          .withSelfOccupantUnavailable()
          .withoutPresenceAndJoinState();
      if (identical(cleared, room)) {
        continue;
      }
      _publishRoomState(roomKey: key, room: cleared);
    }
  }

  Future<void> _recoverRoomsAfterResume() async {
    final rooms = await _loadMucPrejoinRooms();
    if (rooms.isEmpty) return;
    for (final room in rooms) {
      final roomJid = _normalizeBareJid(room.roomJid);
      if (roomJid == null || roomJid.isEmpty) continue;
      final key = _roomKey(roomJid);
      if (_roomHasLeft(key) || _roomExplicitlyLeft(key)) {
        continue;
      }
      final nickname = room.nickname.trim();
      if (nickname.isEmpty) continue;
      try {
        await ensureJoined(
          roomJid: roomJid,
          nickname: nickname,
          maxHistoryStanzas: 0,
          password: _passwordForRoom(roomJid),
          allowRejoin: true,
        );
      } on XmppAbortedException {
        return;
      } on Exception {
        _mucLog.fine('Failed to rejoin one or more rooms after stream resume.');
      }
    }
  }

  void _completeJoinAttempt(
    String roomJid, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final key = _roomKey(roomJid);
    final attemptId = _joinAttemptIdForKey(key);
    final shouldEmitOperation = _consumeJoinOperationTracked(key);
    if (attemptId != null) {
      if (shouldEmitOperation) {
        emitXmppOperation(_mucJoinEndEvent(isSuccess: error == null));
      }
      _logJoinEvent(
        message: _mucJoinCompletedLog,
        attemptId: attemptId,
        hasSelfPresence: _roomStates[key]?.hasSelfPresence == true,
        error: error != null,
      );
      _clearJoinAttemptId(key);
    }
    final completer = _takeJoinCompleterForKey(key);
    if (completer == null || completer.isCompleted) return;
    if (error != null) {
      completer.completeError(error, stackTrace);
      return;
    }
    completer.complete();
  }

  Future<void> _ensureRoomRepairTask(String roomJid) async {
    final normalizedRoom = _roomKey(roomJid);
    final existingCompleter = _repairCompleterForKey(normalizedRoom);
    if (existingCompleter != null && !existingCompleter.isCompleted) {
      return existingCompleter.future;
    }
    final completer = Completer<void>();
    _setRepairCompleterForKey(normalizedRoom, completer);
    unawaited(
      _runRoomRepairTask(roomJid: normalizedRoom, completer: completer),
    );
    return completer.future;
  }

  Future<void> _runRoomRepairTask({
    required String roomJid,
    required Completer<void> completer,
  }) async {
    try {
      await ensureJoined(
        roomJid: roomJid,
        allowRejoin: true,
        forceRejoin: true,
      );
    } on Exception {
      // Join failures are already reflected in message errors.
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_repairCompleterForKey(roomJid), completer)) {
        _setRepairCompleterForKey(roomJid, null);
      }
    }
  }

  Future<void> _runJoinRoomRequest({
    required String roomJid,
    required MUCManager manager,
    required String nickname,
    required int maxHistoryStanzas,
    required int joinAttemptId,
  }) async {
    try {
      final roomBare = mox.JID.fromString(roomJid).toBare();
      final result = await manager
          .joinRoom(roomBare, nickname, maxHistoryStanzas: maxHistoryStanzas)
          .timeout(
            _mucJoinManagerTimeout,
            onTimeout: () {
              _logJoinEvent(
                message: _mucJoinManagerJoinTimeoutLog,
                attemptId: joinAttemptId,
              );
              return const moxlib.Result<bool, mox.MUCError>(true);
            },
          );
      if (result.isType<mox.MUCError>()) {
        _completeJoinAttempt(roomJid, error: XmppMessageException());
      }
    } on Exception catch (error, stackTrace) {
      _completeJoinAttempt(roomJid, error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _pollForSelfPresenceFromMucManager(String roomJid) async {
    final normalizedRoom = _roomKey(roomJid);
    final activeCompleter = _joinCompleterForKey(normalizedRoom);
    if (activeCompleter == null || activeCompleter.isCompleted) return;
    final attemptId = _joinAttemptIdForKey(normalizedRoom);
    final deadline = DateTime.timestamp().add(_mucJoinTimeout);
    while (DateTime.timestamp().isBefore(deadline)) {
      final currentCompleter = _joinCompleterForKey(normalizedRoom);
      if (currentCompleter == null || currentCompleter.isCompleted) return;
      final existing = roomStateFor(normalizedRoom);
      if (existing?.isReadyForMessaging == true) {
        _logJoinEvent(
          message: _mucJoinPollHasSelfPresenceLog,
          attemptId: attemptId,
          hasSelfPresence: existing?.hasSelfPresence == true,
        );
        _completeJoinAttempt(normalizedRoom);
        return;
      }
      await Future<void>.delayed(_mucJoinSelfPresencePollInterval);
    }
  }

  Future<void> _markRoomLeft(
    String roomJid, {
    Set<String>? statusCodes,
    String? reason,
    MucJoinErrorCondition? joinErrorCondition,
    String? joinErrorText,
    bool isDestroyed = false,
    String? destroyedAlternateRoomJid,
    bool preserveOccupants = _preserveOccupantsDefault,
  }) async {
    final key = _roomKey(roomJid);
    _setRoomHasLeft(key, true);
    _setInstantRoomPending(key, false);
    if (!preserveOccupants) {
      _setRoomNeedsJoin(key, false);
    }
    final normalizedReason = _normalizeSubject(reason);
    final existing = _roomStates[key];
    var room = existing ?? RoomState(roomJid: key, occupants: const {});
    room = preserveOccupants
        ? room.withSelfOccupantUnavailable()
        : room.withoutOccupants();
    room = room
        .withoutPresenceAndJoinState()
        .withSelfPresence(
          statusCodes: statusCodes ?? _emptyStatusCodes,
          reason: normalizedReason,
        )
        .withJoinFailure(condition: joinErrorCondition, text: joinErrorText)
        .withDestroyedState(
          destroyed: isDestroyed,
          alternateRoomJid: destroyedAlternateRoomJid,
        );
    _publishRoomState(roomKey: key, room: room, persistSnapshot: !isDestroyed);
    _clearPendingOwnDataForKey(key);
    _setPostJoinRefreshCompleterForKey(key, null);
    if (isDestroyed) {
      await _clearPersistedRoomMemberSnapshot(key);
    }
    await _setMucManagerJoinedState(roomJid: key, joined: false);
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
    manager.rememberPassword(roomJid: roomJid, password: normalizedPassword);
  }

  void _rememberRoomNickname({
    required String roomJid,
    required String nickname,
  }) {
    final normalizedNick = nickname.trim();
    if (normalizedNick.isEmpty) return;
    final manager = _connection.getManager<MucJoinBootstrapManager>();
    if (manager == null) return;
    manager.rememberNickname(roomJid: roomJid, nickname: normalizedNick);
  }

  void _forgetRoomPassword({required String roomJid}) {
    final manager = _connection.getManager<MucJoinBootstrapManager>();
    if (manager == null) return;
    manager.forgetPassword(roomJid);
  }

  void _forgetRoomNickname({required String roomJid}) {
    final manager = _connection.getManager<MucJoinBootstrapManager>();
    if (manager == null) return;
    manager.forgetNickname(roomJid);
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
    final updated = existing.withSelfPresence(
      statusCodes: statusCodes,
      reason: normalizedReason,
    );
    _publishRoomState(roomKey: key, room: updated);
  }

  void _clearRoomJoinFailure(String roomJid) {
    final key = _roomKey(roomJid);
    final existing = _roomStates[key];
    if (existing == null) {
      return;
    }
    final updated = existing.withoutJoinFailure();
    if (identical(updated, existing)) return;
    _publishRoomState(roomKey: key, room: updated);
  }

  void _clearSelfPresenceStatusCode({
    required String roomJid,
    required String statusCode,
  }) {
    final key = _roomKey(roomJid);
    final existing = _roomStates[key];
    if (existing == null) {
      return;
    }
    final updated = existing.withoutSelfPresenceStatusCode(statusCode);
    if (identical(updated, existing)) return;
    _publishRoomState(roomKey: key, room: updated);
  }

  void _setRoomPostJoinRefreshPending({
    required String roomJid,
    required bool pending,
  }) {
    final key = _roomKey(roomJid);
    final existing = _roomStates[key];
    if (existing == null) {
      if (!pending) {
        return;
      }
      final created = RoomState(
        roomJid: key,
        occupants: const {},
        postJoinRefreshPending: true,
      );
      _publishRoomState(roomKey: key, room: created);
      return;
    }
    final updated = existing.withPostJoinRefreshPending(pending);
    if (identical(updated, existing)) return;
    _publishRoomState(roomKey: key, room: updated);
  }

  Future<RoomState> warmRoomFromHistory({
    required String roomJid,
    int limit = 200,
  }) async {
    final key = _roomKey(roomJid);
    if (_roomHasLeft(key)) {
      return _roomStates[key] ?? RoomState(roomJid: key, occupants: const {});
    }
    await _restorePersistedRoomMembers(roomJid);
    return roomStateFor(roomJid) ??
        RoomState(roomJid: _roomKey(roomJid), occupants: const {});
  }

  Future<String> createRoom({
    required String name,
    String? nickname,
    AvatarUploadPayload? avatar,
    ChatPrimaryView primaryView = ChatPrimaryView.chat,
    int maxHistoryStanzas = 0,
  }) async {
    if (!await _ensureMucSupported(jid: mucServiceHost)) {
      throw XmppMessageException();
    }
    emitXmppOperation(_mucCreateStartEvent);
    final slug = _slugify(name);
    final roomJid = '$slug@$mucServiceHost';
    final key = _roomKey(roomJid);
    final nick = _nickForRoom(nickname);
    final title = name.trim().isEmpty ? slug : name.trim();
    final previousRoomState = _roomStates[key];
    final previousSubject = _roomSubjects[key];
    final previousNickname = _roomNicknameForKey(key);
    final previousPassword = _passwordForRoom(key);
    final hadSelfPresenceBeforeCreate =
        previousRoomState?.hasSelfPresence == true;
    final hadLeftBeforeCreate = _roomHasLeft(key);
    final hadExplicitLeaveBeforeCreate = _roomExplicitlyLeft(key);
    final neededJoinBeforeCreate = _roomNeedsJoin(key);
    final hadInstantRoomConfiguredBeforeCreate = _instantRoomConfigured(key);
    final hadInstantRoomPendingBeforeCreate = _instantRoomPending(key);
    var success = false;
    try {
      _mucLog.fine('MUC create start. room=$roomJid');
      await joinRoom(
        roomJid: roomJid,
        nickname: nick,
        maxHistoryStanzas: maxHistoryStanzas,
        clearExplicitLeave: true,
        emitOperation: false,
      );
      if (!_roomWasCreatedDuringCreateAttempt(
        roomJid: key,
        hadInstantRoomConfiguredBeforeCreate:
            hadInstantRoomConfiguredBeforeCreate,
        hadInstantRoomPendingBeforeCreate: hadInstantRoomPendingBeforeCreate,
      )) {
        _mucLog.warning(_mucCreateConflictLog);
        await _restoreRejectedCreateAttempt(
          roomJid: key,
          previousRoomState: previousRoomState,
          previousSubject: previousSubject,
          previousNickname: previousNickname,
          previousPassword: previousPassword,
          hadSelfPresenceBeforeCreate: hadSelfPresenceBeforeCreate,
          hadLeftBeforeCreate: hadLeftBeforeCreate,
          hadExplicitLeaveBeforeCreate: hadExplicitLeaveBeforeCreate,
          neededJoinBeforeCreate: neededJoinBeforeCreate,
          hadInstantRoomConfiguredBeforeCreate:
              hadInstantRoomConfiguredBeforeCreate,
          hadInstantRoomPendingBeforeCreate: hadInstantRoomPendingBeforeCreate,
        );
        throw XmppMucCreateConflictException();
      }
      _mucLog.fine('MUC create joined. room=$roomJid');
      await _dbOp<XmppDatabase>(
        (db) => db.createChat(
          Chat(
            jid: roomJid,
            title: title,
            type: ChatType.groupChat,
            primaryView: primaryView,
            myNickname: nick,
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        ),
        awaitDatabase: true,
      );
      _mucLog.fine('MUC create persisted. room=$roomJid');
      if (avatar != null) {
        final resolvedHash = _resolveRoomAvatarHash(avatar);
        await _storeRoomAvatarLocally(
          roomJid: roomJid,
          bytes: avatar.bytes,
          hash: resolvedHash,
        );
      }
      fireAndForget(() async {
        final slowTimer = Timer(
          _mucCreateRoomBookmarkTimeout,
          () => _mucLog.fine(_mucCreateRoomBookmarkTimeoutLog),
        );
        try {
          await _upsertBookmarkForRoom(
            roomJid: roomJid,
            title: title,
            nickname: nick,
            autojoin: true,
            primaryView: primaryView,
          );
        } finally {
          slowTimer.cancel();
        }
      }, operationName: _mucUpsertBookmarkOperationName);
      if (primaryView.isCalendar) {
        try {
          await _sendRoomPrimaryViewSync(
            roomJid: roomJid,
            primaryView: primaryView,
          );
        } on XmppAbortedException {
          // Ignore aborts during shutdown; local persistence already succeeded.
        } on XmppMessageException {
          _mucLog.fine(_mucRoomPrimaryViewSyncFailedLog);
        }
      }
      if (avatar != null) {
        fireAndForget(
          () => _publishCreatedRoomAvatar(roomJid: roomJid, avatar: avatar),
          operationName: _mucCreateRoomOperationName,
        );
      }
      success = true;
      return roomJid;
    } finally {
      emitXmppOperation(
        success ? _mucCreateSuccessEvent : _mucCreateFailureEvent,
      );
    }
  }

  bool _roomWasCreatedDuringCreateAttempt({
    required String roomJid,
    required bool hadInstantRoomConfiguredBeforeCreate,
    required bool hadInstantRoomPendingBeforeCreate,
  }) {
    final key = _roomKey(roomJid);
    if (roomStateFor(key)?.roomCreated == true) {
      return true;
    }
    if (!hadInstantRoomPendingBeforeCreate && _instantRoomPending(key)) {
      return true;
    }
    if (!hadInstantRoomConfiguredBeforeCreate && _instantRoomConfigured(key)) {
      return true;
    }
    return false;
  }

  Future<void> _restoreRejectedCreateAttempt({
    required String roomJid,
    required RoomState? previousRoomState,
    required String? previousSubject,
    required String? previousNickname,
    required String? previousPassword,
    required bool hadSelfPresenceBeforeCreate,
    required bool hadLeftBeforeCreate,
    required bool hadExplicitLeaveBeforeCreate,
    required bool neededJoinBeforeCreate,
    required bool hadInstantRoomConfiguredBeforeCreate,
    required bool hadInstantRoomPendingBeforeCreate,
  }) async {
    final key = _roomKey(roomJid);
    if (!hadSelfPresenceBeforeCreate) {
      if (_connection.getManager<MUCManager>() case final manager?) {
        try {
          await manager.leaveRoom(mox.JID.fromString(key));
        } on Exception catch (error, stackTrace) {
          _mucLog.fine(_mucCreateRollbackFailedLog, error, stackTrace);
        }
      }
      await _setMucManagerJoinedState(roomJid: key, joined: false);
      await _markRoomLeft(key, statusCodes: _emptyStatusCodes);
    }

    if (previousRoomState == null) {
      _roomStates.remove(key);
    } else {
      _publishRoomState(roomKey: key, room: previousRoomState);
    }

    if (previousSubject == null) {
      _roomSubjects.remove(key);
    } else {
      _roomSubjects[key] = previousSubject;
      _roomSubjectStreams[key]?.add(previousSubject);
    }

    if (previousNickname == null) {
      _setRoomNicknameForKey(key, null);
      _forgetRoomNickname(roomJid: key);
    } else {
      _setRoomNicknameForKey(key, previousNickname);
      _rememberRoomNickname(roomJid: key, nickname: previousNickname);
    }

    if (previousPassword == null) {
      _forgetRoomPassword(roomJid: key);
    } else {
      _rememberRoomPassword(roomJid: key, password: previousPassword);
    }

    if (hadLeftBeforeCreate) {
      _setRoomHasLeft(key, true);
    } else {
      _setRoomHasLeft(key, false);
    }

    if (hadExplicitLeaveBeforeCreate) {
      _setRoomExplicitlyLeft(key, true);
    } else {
      _setRoomExplicitlyLeft(key, false);
    }

    if (neededJoinBeforeCreate) {
      _setRoomNeedsJoin(key, true);
    } else {
      _setRoomNeedsJoin(key, false);
    }

    if (hadInstantRoomConfiguredBeforeCreate) {
      _setInstantRoomConfigured(key, true);
    } else {
      _setInstantRoomConfigured(key, false);
    }

    if (hadInstantRoomPendingBeforeCreate) {
      _setInstantRoomPending(key, true);
    } else {
      _setInstantRoomPending(key, false);
    }
  }

  Future<void> joinRoom({
    required String roomJid,
    required String nickname,
    int? maxHistoryStanzas,
    String? password,
    bool clearExplicitLeave = false,
    bool emitOperation = true,
  }) async {
    if (!await _ensureMucSupported(jid: roomJid)) {
      throw XmppMessageException();
    }
    final normalizedRoom = _roomKey(roomJid);
    final joinCompleter = _ensureJoinCompleterForKey(normalizedRoom);
    final existingAttemptId = _joinAttemptIdForKey(normalizedRoom);
    final joinAttemptId =
        existingAttemptId ?? _ensureJoinAttemptIdForKey(normalizedRoom);
    if (existingAttemptId == null && emitOperation) {
      _setJoinOperationTracked(normalizedRoom, true);
      emitXmppOperation(_mucJoinStartEvent);
    }
    _incrementMucJoinInFlight(normalizedRoom);
    final hasSelfPresence =
        _roomStates[normalizedRoom]?.hasSelfPresence == true;
    final joinCompleterActive = !joinCompleter.isCompleted;
    final joinInFlight = _mucJoinInFlight(normalizedRoom);
    Future<void> pollFuture = Future<void>.value();
    Future<void> joinRequestFuture = Future<void>.value();
    _logJoinEvent(
      message: _mucJoinRequestedLog,
      attemptId: joinAttemptId,
      hasSelfPresence: hasSelfPresence,
      joinCompleterActive: joinCompleterActive,
      joinInFlight: joinInFlight,
    );
    try {
      if (clearExplicitLeave) {
        _setRoomExplicitlyLeft(normalizedRoom, false);
      }
      _markRoomJoined(normalizedRoom);
      _clearRoomJoinFailure(normalizedRoom);
      _setRoomNicknameForKey(normalizedRoom, nickname);
      _rememberRoomNickname(roomJid: normalizedRoom, nickname: nickname);
      _seedRoomSelfOccupantJid(roomJid: normalizedRoom, nickname: nickname);
      _prepareRoomStateForFreshJoin(normalizedRoom);
      _rememberRoomPassword(roomJid: normalizedRoom, password: password);
      final manager = _connection.getManager<MUCManager>();
      if (manager == null) throw XmppMessageException();
      await _setMucManagerJoinedState(roomJid: normalizedRoom, joined: false);

      final resolvedHistoryStanzas =
          maxHistoryStanzas ?? _defaultMucJoinHistoryStanzas;
      joinRequestFuture = _runJoinRoomRequest(
        roomJid: normalizedRoom,
        manager: manager,
        nickname: nickname,
        maxHistoryStanzas: resolvedHistoryStanzas,
        joinAttemptId: joinAttemptId,
      );
      pollFuture = _pollForSelfPresenceFromMucManager(normalizedRoom);
      await joinCompleter.future.timeout(_mucJoinTimeout);
      await joinRequestFuture;
      await pollFuture;
      _scheduleRoomPostJoinRefresh(normalizedRoom);
    } on TimeoutException {
      _takeJoinCompleterForKey(normalizedRoom);
      final roomState = _roomStates[normalizedRoom];
      final hasSelfPresence = roomState?.hasSelfPresence == true;
      if (roomState?.isReadyForMessaging != true) {
        _logJoinEvent(
          message: _mucJoinTimeoutLog,
          attemptId: _joinAttemptIdForKey(normalizedRoom),
          hasSelfPresence: hasSelfPresence,
        );
        _completeJoinAttempt(normalizedRoom, error: XmppMessageException());
        _markRoomNeedsJoin(normalizedRoom);
        await _markRoomLeft(
          normalizedRoom,
          statusCodes: _emptyStatusCodes,
          preserveOccupants: _preserveOccupantsOnJoinTimeout,
        );
      } else {
        _completeJoinAttempt(normalizedRoom);
      }
      await joinRequestFuture;
      await pollFuture;
    } on Exception catch (error, stackTrace) {
      _completeJoinAttempt(
        normalizedRoom,
        error: error,
        stackTrace: stackTrace,
      );
      await joinRequestFuture;
      await pollFuture;
    } finally {
      _decrementMucJoinInFlight(normalizedRoom);
    }
  }

  Future<void> ensureJoined({
    required String roomJid,
    String? nickname,
    int? maxHistoryStanzas,
    String? password,
    bool allowRejoin = false,
    bool forceRejoin = false,
  }) async {
    final key = _roomKey(roomJid);
    if (_roomExplicitlyLeft(key) && !forceRejoin) return;
    if (_roomHasLeft(key) && !allowRejoin && !forceRejoin) return;
    final room = _roomStates[key];
    if (room?.hasTerminalExit == true) {
      return;
    }
    final hasPresenceForSend = await _hasMucPresenceForSend(roomJid: key);
    if (hasPresenceForSend && !forceRejoin) {
      await _awaitInstantRoomConfigurationIfNeeded(key);
      return;
    }
    if (forceRejoin) {
      _setRoomExplicitlyLeft(key, false);
      _setRoomHasLeft(key, false);
    }
    if (_mucJoinInFlight(key)) {
      final joinCompleter = _joinCompleterForKey(key);
      if (joinCompleter != null && !joinCompleter.isCompleted) {
        try {
          await joinCompleter.future.timeout(_mucJoinTimeout);
        } on TimeoutException {
          // Join timeouts are handled by the join attempt that owns the completer.
        }
      }
      await _awaitInstantRoomConfigurationIfNeeded(key);
      return;
    }
    final preferredNick = nickname?.trim();
    final rememberedNick = preferredNick?.isNotEmpty == true
        ? preferredNick!
        : _roomNicknameForKey(key);
    final resolvedNick = rememberedNick?.isNotEmpty == true
        ? rememberedNick!
        : _nickForRoom(null);
    _incrementMucJoinInFlight(key);
    try {
      await joinRoom(
        roomJid: roomJid,
        nickname: resolvedNick,
        maxHistoryStanzas: maxHistoryStanzas,
        password: password,
      );
      await _awaitInstantRoomConfigurationIfNeeded(key);
    } finally {
      _decrementMucJoinInFlight(key);
    }
  }

  Future<void> inviteUserToRoom({
    required String roomJid,
    required String inviteeJid,
    String? reason,
    String? password,
  }) async {
    final normalizedRoom = _roomKey(roomJid);
    final normalizedInvitee = _roomKey(inviteeJid);
    if (!await _ensureMucSupported(jid: normalizedRoom)) {
      throw XmppMessageException();
    }
    final roomState = roomStateFor(normalizedRoom);
    final canManageMembership =
        roomState?.myAffiliation.isOwner == true ||
        roomState?.myAffiliation.isAdmin == true;
    if (canManageMembership || await _roomRequiresMembership(normalizedRoom)) {
      await changeAffiliation(
        roomJid: normalizedRoom,
        jid: normalizedInvitee,
        affiliation: OccupantAffiliation.member,
      );
      await _ensureRoomMembershipGranted(
        roomJid: normalizedRoom,
        inviteeJid: normalizedInvitee,
      );
    }
    await _sendInviteNotice(
      roomJid: normalizedRoom,
      inviteeJid: normalizedInvitee,
      reason: reason,
      password: password,
    );
  }

  Future<void> _ensureRoomMembershipGranted({
    required String roomJid,
    required String inviteeJid,
  }) async {
    final deadline = DateTime.timestamp().add(_roomQueryTimeout);
    var retryDelay = const Duration(milliseconds: 250);
    while (true) {
      final members = await fetchRoomMembers(roomJid: roomJid);
      final hasMembership = members.any(
        (entry) =>
            entry.affiliation == OccupantAffiliation.member &&
            entry.jid != null &&
            _sameBareJid(entry.jid!, inviteeJid),
      );
      if (hasMembership) {
        return;
      }
      final remaining = deadline.difference(DateTime.timestamp());
      if (remaining <= Duration.zero) {
        break;
      }
      final delay = retryDelay < remaining ? retryDelay : remaining;
      await Future<void>.delayed(delay);
      if (retryDelay < const Duration(seconds: 2)) {
        retryDelay = Duration(milliseconds: retryDelay.inMilliseconds * 2);
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
          attributes: {'nick': nick, 'role': OccupantRole.none.xmlValue},
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
    final normalizedRoom = _roomKey(roomJid);
    final normalizedJid = _roomKey(jid);
    await _sendAdminItems(
      roomJid: normalizedRoom,
      items: [
        mox.XMLNode(
          tag: 'item',
          attributes: {
            'jid': normalizedJid,
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
          attributes: {'nick': nick, 'role': role.xmlValue},
        ),
      ],
    );
  }

  Future<List<MucAffiliationEntry>> fetchRoomMembers({
    required String roomJid,
  }) => fetchRoomAffiliations(
    roomJid: roomJid,
    affiliation: OccupantAffiliation.member,
  );

  Future<List<MucAffiliationEntry>> fetchRoomAdmins({
    required String roomJid,
  }) => fetchRoomAffiliations(
    roomJid: roomJid,
    affiliation: OccupantAffiliation.admin,
  );

  Future<List<MucAffiliationEntry>> fetchRoomOwners({
    required String roomJid,
  }) => fetchRoomAffiliations(
    roomJid: roomJid,
    affiliation: OccupantAffiliation.owner,
  );

  Future<List<MucAffiliationEntry>> fetchRoomOutcasts({
    required String roomJid,
  }) => fetchRoomAffiliations(
    roomJid: roomJid,
    affiliation: OccupantAffiliation.outcast,
  );

  Future<List<MucAffiliationEntry>> fetchRoomAffiliations({
    required String roomJid,
    required OccupantAffiliation affiliation,
  }) async {
    if (!await _ensureMucSupported(jid: roomJid)) {
      return const [];
    }
    final normalizedRoom = _roomKey(roomJid);
    final queryXmlns = _mucAdminXmlns;
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
    final mox.XMLNode? result;
    try {
      result = await _connection
          .sendStanza(mox.StanzaDetails(request, shouldEncrypt: false))
          .timeout(_roomQueryTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _mucLog.fine(_roomAffiliationQueryTimeoutLog, error, stackTrace);
      throw XmppMessageException();
    }
    if (result == null) return const [];
    if (result.attributes[_iqTypeAttr]?.toString() != _iqTypeResult) {
      return const [];
    }
    final query = result.firstTag(_queryTag, xmlns: queryXmlns);
    if (query == null) return const [];
    final entries = query
        .findTags(_itemTag)
        .map((item) {
          final jid = _normalizeBareJid(_readItemAttr(item, _jidAttr));
          final nick = _readItemAttr(item, _nickAttr);
          final roleAttr = _readItemAttr(item, _roleAttr);
          final itemAffiliation =
              _readItemAttr(item, _affiliationAttr) ?? affiliation.xmlValue;
          final resolvedAffiliation = OccupantAffiliation.fromString(
            itemAffiliation,
          );
          final resolvedRole = roleAttr == null
              ? null
              : OccupantRole.fromString(roleAttr);
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
        })
        .toList(growable: false);
    _applyAffiliationEntries(
      roomJid: normalizedRoom,
      queriedAffiliation: affiliation,
      entries: entries,
    );
    return List<MucAffiliationEntry>.unmodifiable(entries);
  }

  Future<void> leaveRoom(String roomJid) async {
    if (_connection.getManager<MUCManager>() case final manager?) {
      await manager
          .leaveRoom(mox.JID.fromString(roomJid))
          .timeout(_roomActionTimeout);
      _forgetRoomNickname(roomJid: roomJid);
      _forgetRoomPassword(roomJid: roomJid);
      _setRoomExplicitlyLeft(_roomKey(roomJid), true);
      await _markRoomLeft(roomJid, statusCodes: const <String>{});
      await _removeBookmarkForRoom(roomJid: roomJid);
      await _archiveRoomChat(roomJid: roomJid);
      return;
    }
    throw XmppMessageException();
  }

  Future<void> destroyRoom({required String roomJid, String? reason}) async {
    final normalizedRoom = _roomKey(roomJid);
    final normalizedReason = _normalizeSubject(reason);
    if (_connection.getManager<MUCManager>() case final manager?) {
      await manager
          .sendOwnerIq(
            roomJid: normalizedRoom,
            children: [
              mox.XMLNode(
                tag: _destroyTag,
                children: [
                  if (normalizedReason != null)
                    mox.XMLNode(tag: _reasonTag, text: normalizedReason),
                ],
              ),
            ],
          )
          .timeout(_roomActionTimeout);
      _forgetRoomNickname(roomJid: normalizedRoom);
      _forgetRoomPassword(roomJid: normalizedRoom);
      _setRoomExplicitlyLeft(normalizedRoom, true);
      await _markRoomLeft(
        normalizedRoom,
        statusCodes: _emptyStatusCodes,
        reason: normalizedReason,
        isDestroyed: true,
      );
      await _removeBookmarkForRoom(roomJid: normalizedRoom);
      await _archiveRoomChat(roomJid: normalizedRoom);
      return;
    }
    throw XmppMessageException();
  }

  Future<void> changeNickname({
    required String roomJid,
    required String nickname,
  }) async {
    final trimmed = nickname.trim();
    _setRoomNicknameForKey(_roomKey(roomJid), trimmed);
    _rememberRoomNickname(roomJid: roomJid, nickname: trimmed);
    await _applyLocalNickname(roomJid: roomJid, nickname: trimmed);
    await joinRoom(
      roomJid: roomJid,
      nickname: trimmed,
      maxHistoryStanzas: 0,
      clearExplicitLeave: true,
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
    if (existingRoom?.isReadyForMessaging == true &&
        !_roomNeedsJoin(roomJid) &&
        !hasLeftRoom(roomJid)) {
      return;
    }
    final title = await _resolveRoomTitle(
      roomJid: roomJid,
      providedTitle: roomName,
    );
    final emptyTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
    final resolvedNickname = _nickForRoom(nickname);
    final resolvedPassword = _normalizePassword(password);
    _rememberRoomPassword(roomJid: roomJid, password: resolvedPassword);
    await joinRoom(
      roomJid: roomJid,
      nickname: resolvedNickname,
      maxHistoryStanzas: _defaultMucJoinHistoryStanzas,
      password: resolvedPassword,
      clearExplicitLeave: true,
    );
    if (roomStateFor(roomJid)?.roomCreated == true) {
      try {
        await destroyRoom(roomJid: roomJid);
      } on Exception {
        await leaveRoom(roomJid);
      }
      throw XmppMessageException();
    }
    await _dbOp<XmppDatabase>((db) async {
      final existing = await db.getChat(roomJid);
      if (existing == null) {
        await db.createChat(
          Chat(
            jid: roomJid,
            title: title,
            type: ChatType.groupChat,
            myNickname: resolvedNickname,
            lastChangeTimestamp: emptyTimestamp,
            contactJid: roomJid,
          ),
        );
        return;
      }
      if (existing.type != ChatType.groupChat ||
          existing.title != title ||
          existing.myNickname != resolvedNickname ||
          existing.contactJid != roomJid ||
          existing.archived) {
        await db.updateChat(
          existing.copyWith(
            type: ChatType.groupChat,
            title: title,
            myNickname: resolvedNickname,
            contactJid: roomJid,
            archived: false,
          ),
        );
      }
    });
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
    if (mucManager != null) {
      try {
        final result = await mucManager.queryRoomInformation(
          mox.JID.fromString(roomJid),
        );
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
          final normalizedHost = _normalizeSupportedMucServiceHost(
            item.jid.toString(),
          );
          if (normalizedHost == null) {
            continue;
          }
          final infoResult = await discoManager.discoInfoQuery(item.jid);
          if (infoResult.isType<mox.DiscoInfo>()) {
            final info = infoResult.get<mox.DiscoInfo>();
            if (info.features.contains(_mucDiscoFeature)) {
              await setMucServiceHost(normalizedHost);
              return;
            }
          }
        }
      }

      final domainInfo = await discoManager.discoInfoQuery(domainJid);
      if (domainInfo.isType<mox.DiscoInfo>()) {
        final info = domainInfo.get<mox.DiscoInfo>();
        if (info.features.contains(_mucDiscoFeature)) {
          await setMucServiceHost(_defaultMucServiceHost);
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
    if (!await _ensureMucSupported(jid: resolvedService)) {
      return const [];
    }
    try {
      final result = await discoManager.discoItemsQuery(
        mox.JID.fromString(resolvedService),
      );
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
      final result = await manager.queryRoomInformation(
        mox.JID.fromString(roomJid),
      );
      if (result.isType<mox.MUCError>()) {
        return null;
      }
      return result.get<mox.RoomInformation>();
    } on Exception {
      return null;
    }
  }

  Future<bool> _roomRequiresMembership(String roomJid) async {
    final info = await fetchRoomInformation(roomJid);
    if (info == null) return false;
    return info.features.contains(_mucMembersOnlyFeature);
  }

  Future<mox.XMLNode?> _fetchRoomInfoForm(String roomJid) async {
    final stanza = mox.Stanza.iq(
      type: _iqTypeGet,
      to: roomJid,
      children: [mox.XMLNode.xmlns(tag: _queryTag, xmlns: _discoInfoXmlns)],
    );
    final mox.XMLNode? result;
    try {
      result = await _connection
          .sendStanza(mox.StanzaDetails(stanza, shouldEncrypt: false))
          .timeout(_roomQueryTimeout);
    } on TimeoutException {
      return null;
    }
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
      children: [mox.XMLNode.xmlns(tag: _queryTag, xmlns: _mucOwnerXmlns)],
    );
    final mox.XMLNode? result;
    try {
      result = await _connection
          .sendStanza(mox.StanzaDetails(stanza, shouldEncrypt: false))
          .timeout(_roomQueryTimeout);
    } on TimeoutException {
      return null;
    }
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
    mox.XMLNode? result;
    try {
      result = await _connection
          .sendStanza(mox.StanzaDetails(stanza, shouldEncrypt: false))
          .timeout(_roomConfigSubmitTimeout);
    } on TimeoutException {
      _mucLog.fine(_roomConfigSubmitTimeoutLog);
      return false;
    } on Exception {
      return false;
    }
    if (result == null) return false;
    final type = result.attributes[_iqTypeAttr]?.toString();
    if (type == _iqTypeResult) return true;
    _logRoomConfigurationError(result);
    return false;
  }

  Future<bool> updateRoomAvatar({
    required String roomJid,
    required AvatarUploadPayload avatar,
  }) async {
    if (!_mucAvatarSupportEnabled) return false;
    final normalizedRoomJid = _roomKey(roomJid);
    final resolvedHash = _resolveRoomAvatarHash(avatar);
    final encodedAvatar = _base64EncodeAvatarPublishPayload(avatar.bytes);
    final trimmedMimeType = avatar.mimeType.trim();
    final dataUriAvatar = _buildRoomAvatarDataUri(
      mimeType: trimmedMimeType,
      encodedAvatar: encodedAvatar,
    );
    final avatarCandidates = <String>[?dataUriAvatar, encodedAvatar];
    var configUpdated = false;
    final configForm = await fetchRoomConfigurationForm(normalizedRoomJid);
    if (configForm != null) {
      for (final avatarValue in avatarCandidates) {
        final updatedForm = _updateRoomAvatarForm(
          form: configForm,
          avatarValue: avatarValue,
          avatarHash: resolvedHash,
          avatarMimeType: trimmedMimeType.isEmpty ? null : trimmedMimeType,
        );
        if (updatedForm == null) {
          _mucLog.fine(_roomAvatarFieldMissingLog);
          break;
        }
        configUpdated = await submitRoomConfiguration(
          roomJid: normalizedRoomJid,
          form: updatedForm,
        );
        if (configUpdated) {
          break;
        }
      }
    }
    final vcardUpdated = await _updateRoomAvatarViaVCard(
      roomJid: normalizedRoomJid,
      encodedAvatar: encodedAvatar,
      mimeType: trimmedMimeType,
    );
    final updated = configUpdated || vcardUpdated;
    if (!updated) {
      return false;
    }
    final verified = await _verifyRoomAvatarUpdate(
      roomJid: normalizedRoomJid,
      expectedHash: resolvedHash,
      allowVCard: true,
    );
    if (!verified) {
      return false;
    }
    await _storeRoomAvatarLocally(
      roomJid: normalizedRoomJid,
      bytes: avatar.bytes,
      hash: resolvedHash,
    );
    return true;
  }

  Future<bool> _verifyRoomAvatarUpdate({
    required String roomJid,
    required String expectedHash,
    bool allowVCard = false,
  }) async {
    for (
      var attempt = 0;
      attempt < _roomAvatarVerificationAttempts;
      attempt++
    ) {
      final payload = await _fetchRoomAvatarPayload(roomJid);
      final payloadHash = payload.hash?.trim();
      if (payloadHash?.isNotEmpty == true) {
        if (payloadHash == expectedHash) {
          return true;
        }
      } else {
        final data = payload.data;
        if (data?.isNotEmpty == true) {
          final decoded = _decodeRoomAvatarData(data!);
          if (decoded != null) {
            final decodedHash = sha1.convert(decoded).toString();
            if (decodedHash == expectedHash) {
              return true;
            }
          }
        }
      }
      if (allowVCard) {
        final verified = await _verifyRoomAvatarVCard(
          roomJid: roomJid,
          expectedHash: expectedHash,
        );
        if (verified) {
          return true;
        }
      }
      if (attempt < _roomAvatarVerificationAttempts - 1) {
        await Future<void>.delayed(_roomAvatarVerificationDelay);
      }
    }
    return false;
  }

  Future<bool> _verifyRoomAvatarVCard({
    required String roomJid,
    required String expectedHash,
  }) async {
    final bytes = await _fetchRoomVCardAvatarBytes(roomJid);
    if (bytes == null || bytes.isEmpty) return false;
    final hash = sha1.convert(bytes).toString();
    return hash == expectedHash;
  }

  Future<Uint8List?> _fetchRoomVCardAvatarBytes(String roomJid) async {
    final stanza = mox.Stanza.iq(
      type: _iqTypeGet,
      to: roomJid,
      children: [mox.XMLNode.xmlns(tag: _vCardTag, xmlns: _vCardTempXmlns)],
    );
    final result = await _connection.sendStanza(
      mox.StanzaDetails(stanza, shouldEncrypt: false),
    );
    if (result == null) return null;
    if (result.attributes[_iqTypeAttr]?.toString() != _iqTypeResult) {
      return null;
    }
    final vcard = result.firstTag(_vCardTag, xmlns: _vCardTempXmlns);
    final binval = vcard
        ?.firstTag(_vCardPhotoTag)
        ?.firstTag(_vCardBinvalTag)
        ?.innerText();
    final normalized = _normalizeRoomAvatarValue(binval);
    if (normalized == null) return null;
    return _decodeRoomAvatarData(normalized);
  }

  Future<bool> _updateRoomAvatarViaVCard({
    required String roomJid,
    required String encodedAvatar,
    required String mimeType,
  }) async {
    final trimmedMimeType = mimeType.trim();
    final photoChildren = <mox.XMLNode>[
      mox.XMLNode(tag: _vCardBinvalTag, text: encodedAvatar),
    ];
    if (trimmedMimeType.isNotEmpty) {
      photoChildren.add(mox.XMLNode(tag: _vCardTypeTag, text: trimmedMimeType));
    }
    final stanza = mox.Stanza.iq(
      type: _iqTypeSet,
      to: roomJid,
      children: [
        mox.XMLNode.xmlns(
          tag: _vCardTag,
          xmlns: _vCardTempXmlns,
          children: [mox.XMLNode(tag: _vCardPhotoTag, children: photoChildren)],
        ),
      ],
    );
    final result = await _connection.sendStanza(
      mox.StanzaDetails(stanza, shouldEncrypt: false),
    );
    if (result == null) return false;
    final type = result.attributes[_iqTypeAttr]?.toString();
    if (type == _iqTypeResult) return true;
    _mucLog.fine(_roomAvatarVCardSubmitFailedLog);
    return false;
  }

  Future<bool> _storeRoomAvatarLocally({
    required String roomJid,
    required Uint8List bytes,
    required String hash,
  }) async {
    if (bytes.isEmpty) return false;
    await storeAvatarBytesForJid(
      jid: _roomKey(roomJid),
      bytes: bytes,
      hash: hash,
    );
    return true;
  }

  String _resolveRoomAvatarHash(AvatarUploadPayload avatar) {
    final trimmed = avatar.hash.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return sha1.convert(avatar.bytes).toString();
  }

  mox.XMLNode? _updateRoomAvatarForm({
    required mox.XMLNode form,
    required String avatarValue,
    required String avatarHash,
    String? avatarMimeType,
  }) {
    final resolvedMimeType = avatarMimeType?.trim();
    var hasAvatarField = false;
    final updatedChildren = <mox.XMLNode>[];
    for (final child in form.children) {
      if (child.tag != _fieldTag) {
        updatedChildren.add(child);
        continue;
      }
      final varName = _fieldVarName(child);
      if (varName == null) {
        updatedChildren.add(child);
        continue;
      }
      final lowerVar = varName.toLowerCase();
      if (!lowerVar.contains(_avatarFieldToken)) {
        updatedChildren.add(child);
        continue;
      }
      if (_isAvatarHashField(lowerVar)) {
        hasAvatarField = true;
        updatedChildren.add(_replaceFieldValues(child, [avatarHash]));
        continue;
      }
      if (_isAvatarMimeField(lowerVar)) {
        hasAvatarField = true;
        if (resolvedMimeType == null || resolvedMimeType.isEmpty) {
          updatedChildren.add(child);
          continue;
        }
        updatedChildren.add(_replaceFieldValues(child, [resolvedMimeType]));
        continue;
      }
      hasAvatarField = true;
      updatedChildren.add(_replaceFieldValues(child, [avatarValue]));
    }
    if (!hasAvatarField) return null;
    final updatedAttributes = _stringAttributes(form.attributes)
      ..[_dataFormTypeAttr] = _dataFormTypeSubmit;
    return mox.XMLNode(
      tag: form.tag,
      attributes: updatedAttributes,
      children: updatedChildren,
    );
  }

  Map<String, String> _stringAttributes(Map<String, dynamic> attributes) {
    return attributes.map((key, value) => MapEntry(key, value.toString()));
  }

  void _logRoomConfigurationError(mox.XMLNode stanza) {
    final error = stanza.firstTag(_errorTag);
    final condition = error?.firstTagByXmlns(mox.fullStanzaXmlns)?.tag;
    final trimmedCondition = condition?.trim();
    if (trimmedCondition == null || trimmedCondition.isEmpty) {
      _mucLog.fine(_roomConfigSubmitFailedLog);
      return;
    }
    _mucLog.fine('$_roomConfigSubmitFailedLog $trimmedCondition');
  }

  mox.XMLNode _createInstantRoomConfigurationForm() {
    final formAttributes = <String, String>{}
      ..[_dataFormTypeAttr] = _dataFormTypeSubmit;
    final fieldAttributes = <String, String>{}
      ..[_varAttr] = _formTypeFieldVar
      ..[_dataFormTypeAttr] = _dataFormFieldTypeHidden;
    final field = mox.XMLNode(
      tag: _fieldTag,
      attributes: fieldAttributes,
      children: [mox.XMLNode(tag: _valueTag, text: _mucRoomConfigFormType)],
    );
    return mox.XMLNode.xmlns(
      tag: _dataFormTag,
      xmlns: _dataFormXmlns,
      attributes: formAttributes,
      children: [field],
    );
  }

  bool _shouldAttemptInstantRoomConfiguration(String roomJid) {
    final key = _roomKey(roomJid);
    if (_instantRoomPending(key)) return true;
    final room = _roomStates[key];
    return room?.roomCreated == true;
  }

  Future<void> _ensureInstantRoomConfiguration({
    required String roomJid,
  }) async {
    final key = _roomKey(roomJid);
    if (_instantRoomConfigured(key)) return;
    final existingCompleter = _instantRoomConfigCompleterForKey(key);
    if (existingCompleter != null) {
      return existingCompleter.future;
    }
    final completer = Completer<void>();
    _setInstantRoomConfigCompleterForKey(key, completer);
    try {
      final form = _createInstantRoomConfigurationForm();
      final configured = await submitRoomConfiguration(
        roomJid: key,
        form: form,
      );
      if (!configured) {
        throw XmppMessageException();
      }
      _setInstantRoomConfigured(key, true);
      _setInstantRoomPending(key, false);
      _clearSelfPresenceStatusCode(
        roomJid: key,
        statusCode: MucStatusCode.roomCreated.code,
      );
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      _setInstantRoomConfigCompleterForKey(key, null);
    }
    return completer.future;
  }

  Future<void> _awaitInstantRoomConfigurationIfNeeded(String roomJid) async {
    final key = _roomKey(roomJid);
    if (!_shouldAttemptInstantRoomConfiguration(key)) return;
    try {
      await _ensureInstantRoomConfiguration(roomJid: key);
    } on Exception catch (error, stackTrace) {
      _mucLog.fine(_instantRoomConfigFailedLog, error, stackTrace);
    }
  }

  Future<void> _publishCreatedRoomAvatar({
    required String roomJid,
    required AvatarUploadPayload avatar,
  }) async {
    const maxAttempts = 3;
    const retryDelay = Duration(milliseconds: 350);

    await _awaitInstantRoomConfigurationIfNeeded(roomJid);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final updated = await updateRoomAvatar(roomJid: roomJid, avatar: avatar);
      if (updated) {
        return;
      }
      if (attempt == maxAttempts - 1) {
        _mucLog.fine(_roomAvatarUpdateFailedLog);
        return;
      }
      await Future<void>.delayed(retryDelay);
    }
  }

  Future<void> _refreshRoomAffiliations(String roomJid) async {
    await Future.wait<void>(<Future<void>>[
      _refreshRoomAffiliation(
        roomJid: roomJid,
        affiliation: OccupantAffiliation.member,
      ),
      _refreshRoomAffiliation(
        roomJid: roomJid,
        affiliation: OccupantAffiliation.owner,
      ),
      _refreshRoomAffiliation(
        roomJid: roomJid,
        affiliation: OccupantAffiliation.admin,
      ),
    ]);
  }

  Future<void> _refreshRoomAffiliation({
    required String roomJid,
    required OccupantAffiliation affiliation,
  }) async {
    try {
      switch (affiliation) {
        case OccupantAffiliation.member:
          await fetchRoomMembers(roomJid: roomJid);
        case OccupantAffiliation.owner:
          await fetchRoomOwners(roomJid: roomJid);
        case OccupantAffiliation.admin:
          await fetchRoomAdmins(roomJid: roomJid);
        case OccupantAffiliation.outcast:
        case OccupantAffiliation.none:
          return;
      }
    } on Exception catch (error, stackTrace) {
      _mucLog.fine(
        'Failed to refresh ${affiliation.xmlValue} affiliations.',
        error,
        stackTrace,
      );
    }
  }

  void _scheduleRoomPostJoinRefresh(String roomJid) {
    final key = _roomKey(roomJid);
    if (_roomHasLeft(key)) return;
    final existingCompleter = _postJoinRefreshCompleterForKey(key);
    if (existingCompleter != null) return;
    final completer = Completer<void>();
    _setPostJoinRefreshCompleterForKey(key, completer);
    _setRoomPostJoinRefreshPending(roomJid: key, pending: true);
    fireAndForget(() async {
      try {
        await _awaitInstantRoomConfigurationIfNeeded(key);
        await _refreshRoomAffiliations(key);
        await _refreshRoomAvatar(key).timeout(_roomQueryTimeout);
        completer.complete();
      } on TimeoutException {
        completer.complete();
      } on Exception catch (error, stackTrace) {
        _mucLog.fine(
          'Failed to refresh joined room metadata.',
          error,
          stackTrace,
        );
        completer.complete();
      } finally {
        _setRoomPostJoinRefreshPending(roomJid: key, pending: false);
        _setPostJoinRefreshCompleterForKey(key, null);
      }
    }, operationName: _mucPostJoinRefreshOperationName);
  }

  bool _isAvatarMimeField(String fieldName) {
    final lowerField = fieldName.toLowerCase();
    return lowerField.contains(_avatarMimeToken) ||
        lowerField.contains(_avatarTypeToken);
  }

  bool _isAvatarHashField(String lowerField) {
    return lowerField.contains(_avatarHashToken) ||
        lowerField.contains(_avatarSha1Token);
  }

  String? _buildRoomAvatarDataUri({
    required String mimeType,
    required String encodedAvatar,
  }) {
    final trimmed = mimeType.trim();
    if (trimmed.isEmpty) return null;
    return '$_dataUriPrefix$trimmed$_dataUriBase64Delimiter$encodedAvatar';
  }

  mox.XMLNode _replaceFieldValues(mox.XMLNode field, List<String> values) {
    final preservedChildren = field.children
        .where((child) => child.tag != _valueTag)
        .toList(growable: false);
    final valueNodes = values
        .map((value) => mox.XMLNode(tag: _valueTag, text: value))
        .toList(growable: false);
    return mox.XMLNode(
      tag: field.tag,
      attributes: _stringAttributes(field.attributes),
      children: [...preservedChildren, ...valueNodes],
    );
  }

  Future<void> setRoomSubject({
    required String roomJid,
    String? subject,
  }) async {
    if (!await _ensureMucSupported(jid: roomJid)) {
      return;
    }
    final resolvedSubject = subject?.trim() ?? '';
    final stanza = mox.Stanza.message(
      to: roomJid,
      type: _messageTypeGroupchat,
      children: [mox.XMLNode(tag: _subjectTag, text: resolvedSubject)],
    );
    await _connection.sendStanza(mox.StanzaDetails(stanza, awaitable: false));
  }

  Future<void> _autojoinBookmarks(List<MucBookmark> bookmarks) async {
    if (bookmarks.isEmpty) return;
    for (final bookmark in bookmarks) {
      final roomJid = bookmark.roomBare.toString();
      final password = _normalizePassword(bookmark.password);
      if (password != null) {
        _rememberRoomPassword(roomJid: roomJid, password: password);
      }
      if (!bookmark.autojoin) continue;

      final nickname = bookmark.nick?.trim();
      if (nickname?.isNotEmpty == true) {
        _setRoomNicknameForKey(_roomKey(roomJid), nickname);
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

  Future<void> _autojoinLatestBookmarkedRooms() async {
    await _autojoinBookmarks(List<MucBookmark>.from(_latestBootstrapBookmarks));
  }

  Future<void> _refreshRoomAvatarsFromLatestBookmarks() async {
    await refreshRoomAvatars(List<MucBookmark>.from(_latestBootstrapBookmarks));
  }

  Future<void> _applyMucBookmarksState(List<MucBookmark> bookmarks) async {
    if (bookmarks.isEmpty) return;
    await _upsertChatsFromBookmarks(bookmarks);
  }

  Future<void> applyMucBookmarks(List<MucBookmark> bookmarks) async {
    if (bookmarks.isEmpty) return;
    await _applyMucBookmarksState(bookmarks);
    await refreshRoomAvatars(bookmarks);
    await _autojoinBookmarks(bookmarks);
  }

  Future<void> applyMucBookmarksSnapshot(
    ({List<MucBookmark> items, bool isSuccess, bool isComplete}) snapshot,
  ) async {
    if (!snapshot.isSuccess) return;
    final bookmarks = snapshot.items;
    _latestBootstrapBookmarks = List<MucBookmark>.from(bookmarks);
    await _applyMucBookmarksState(bookmarks);
    if (snapshot.isComplete) {
      await _reconcileMucBookmarkRemovals(bookmarks);
      await _persistMucPrejoinRoomsFromBookmarks(bookmarks);
    }
  }

  Future<void> _reconcileMucBookmarkRemovals(
    List<MucBookmark> bookmarks,
  ) async {
    final knownRooms = bookmarks
        .map((bookmark) => bookmark.roomBare.toBare().toString())
        .toSet();
    final toRemove = <String>{};
    await _dbOp<XmppDatabase>((db) async {
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
    }, awaitDatabase: true);

    for (final roomBare in toRemove) {
      try {
        await _applyBookmarkRetraction(mox.JID.fromString(roomBare));
      } on Exception {
        // Ignore leave failures when applying snapshot removals.
      }
    }
  }

  Future<List<MucBookmark>> syncMucBookmarksSnapshot() async {
    final pendingSync = _mucBookmarksSync;
    if (pendingSync != null) return pendingSync;
    final task = () async {
      try {
        await database;
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
      }
    }();
    _mucBookmarksSync = task;
    return task.whenComplete(() {
      if (_mucBookmarksSync == task) {
        _mucBookmarksSync = null;
      }
    });
  }

  Future<void> refreshRoomAvatars(List<MucBookmark> bookmarks) async {
    if (!_mucAvatarSupportEnabled) return;
    if (bookmarks.isEmpty) return;

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

  Future<void> _refreshRoomAvatar(
    String roomJid, {
    String? expectedHash,
  }) async {
    if (!_mucAvatarSupportEnabled) return;
    final normalizedRoom = _roomKey(roomJid);
    try {
      if (await _roomAvatarMatchesStoredHash(normalizedRoom, expectedHash)) {
        return;
      }
      final payload = await _fetchRoomAvatarPayload(normalizedRoom);
      final payloadHash = payload.hash?.trim();
      if (await _roomAvatarMatchesStoredHash(normalizedRoom, payloadHash)) {
        return;
      }
      if (payload.data == null || payload.data!.isEmpty) {
        await _refreshRoomAvatarFromVCard(
          normalizedRoom,
          expectedHash: payloadHash?.isNotEmpty == true
              ? payloadHash
              : expectedHash,
        );
        return;
      }
      final decoded = _decodeRoomAvatarData(payload.data!);
      if (decoded == null) {
        return;
      }
      final resolvedHash = payloadHash?.isNotEmpty == true
          ? payloadHash!
          : sha1.convert(decoded).toString();
      await storeAvatarBytesForJid(
        jid: normalizedRoom,
        bytes: decoded,
        hash: resolvedHash,
      );
    } on Exception catch (error, stackTrace) {
      _mucLog.fine(_roomAvatarStoreFailedLog, error, stackTrace);
    }
  }

  Future<bool> _roomAvatarMatchesStoredHash(
    String roomJid,
    String? hash,
  ) async {
    final normalizedHash = hash?.trim();
    if (normalizedHash == null || normalizedHash.isEmpty) {
      return false;
    }
    final existingHash = await _storedAvatarHash(roomJid);
    if (existingHash == null || existingHash != normalizedHash) {
      return false;
    }
    final existingPath = await _storedAvatarPath(roomJid);
    return _hasCachedAvatarFile(existingPath);
  }

  Future<void> _refreshRoomAvatarFromVCard(
    String roomJid, {
    String? expectedHash,
  }) async {
    final normalizedRoom = _roomKey(roomJid);
    if (await _roomAvatarMatchesStoredHash(normalizedRoom, expectedHash)) {
      return;
    }
    final vcardBytes = await _fetchRoomVCardAvatarBytes(normalizedRoom);
    if (vcardBytes == null || vcardBytes.isEmpty) {
      return;
    }
    final resolvedHash = sha1.convert(vcardBytes).toString();
    await storeAvatarBytesForJid(
      jid: normalizedRoom,
      bytes: vcardBytes,
      hash: resolvedHash,
    );
  }

  Future<_RoomAvatarPayload> _fetchRoomAvatarPayload(String roomJid) async {
    final infoForm = await _fetchRoomInfoForm(roomJid);
    final infoPayload = _roomAvatarPayloadFromForm(infoForm);
    if (infoPayload.data?.isNotEmpty == true) return infoPayload;
    final roomState = roomStateFor(roomJid);
    final canQueryConfig =
        roomState?.hasSelfPresence == true && roomState!.canEditAvatar;
    if (!canQueryConfig) return infoPayload;
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
      if (_isAvatarHashField(lowerVar)) {
        final value = _normalizeRoomAvatarValue(values.first);
        if (value == null) continue;
        hash = value;
        continue;
      }
      if (_isAvatarMimeField(lowerVar)) continue;
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
      raw = normalized.substring(index + _dataUriBase64Delimiter.length);
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
    final emptyTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
    for (final bookmark in bookmarks) {
      final roomJid = bookmark.roomBare.toBare().toString();
      if (roomJid.isEmpty) continue;
      final trimmedTitle = bookmark.name?.trim();
      final title = trimmedTitle?.isNotEmpty == true
          ? trimmedTitle!
          : mox.JID.fromString(roomJid).local;
      final trimmedNick = bookmark.nick?.trim();
      final nickname = trimmedNick?.isNotEmpty == true
          ? trimmedNick!
          : _nickForRoom(null);
      final primaryView = _primaryViewFromBookmark(bookmark);

      try {
        await _dbOp<XmppDatabase>((db) async {
          final existing = await db.getChat(roomJid);
          if (existing == null) {
            await db.createChat(
              Chat(
                jid: roomJid,
                title: title.isNotEmpty ? title : roomJid,
                type: ChatType.groupChat,
                primaryView: primaryView,
                myNickname: nickname,
                lastChangeTimestamp: emptyTimestamp,
                contactJid: roomJid,
              ),
            );
            return;
          }

          final shouldUpdateTitle =
              title.isNotEmpty && existing.title.trim() != title;
          final shouldUpdateNickname =
              nickname.isNotEmpty &&
              (existing.myNickname ?? '').trim() != nickname;
          final shouldUpdateType = existing.type != ChatType.groupChat;
          final shouldUpdatePrimaryView = existing.primaryView != primaryView;
          final shouldUpdateContactJid = existing.contactJid != roomJid;

          if (!shouldUpdateTitle &&
              !shouldUpdateNickname &&
              !shouldUpdateType &&
              !shouldUpdatePrimaryView &&
              !shouldUpdateContactJid) {
            return;
          }

          await db.updateChat(
            existing.copyWith(
              type: ChatType.groupChat,
              title: shouldUpdateTitle ? title : existing.title,
              primaryView: shouldUpdatePrimaryView
                  ? primaryView
                  : existing.primaryView,
              myNickname: shouldUpdateNickname ? nickname : existing.myNickname,
              contactJid: roomJid,
            ),
          );
        }, awaitDatabase: true);
      } on XmppAbortedException {
        return;
      } on Exception {
        _mucLog.fine('Failed to update room list from bookmarks.');
      }
    }
  }

  ChatPrimaryView _primaryViewFromBookmark(MucBookmark bookmark) {
    for (final extension in bookmark.extensions) {
      if (!_isRoomPrimaryViewBookmarkExtension(extension)) {
        continue;
      }
      final primaryView = ChatPrimaryView.tryParse(
        extension.attributes[_roomPrimaryViewBookmarkAttr]?.toString(),
      );
      if (primaryView != null) {
        return primaryView;
      }
    }
    return ChatPrimaryView.chat;
  }

  bool _isRoomPrimaryViewBookmarkExtension(mox.XMLNode extension) {
    return extension.tag == _roomPrimaryViewBookmarkTag &&
        extension.attributes['xmlns']?.toString() ==
            _roomPrimaryViewBookmarkXmlns;
  }

  List<mox.XMLNode> _extensionsWithPrimaryView({
    required List<mox.XMLNode> existingExtensions,
    required ChatPrimaryView primaryView,
  }) {
    final extensions = existingExtensions
        .where((extension) => !_isRoomPrimaryViewBookmarkExtension(extension))
        .toList(growable: true);
    if (primaryView.isCalendar) {
      extensions.add(
        mox.XMLNode.xmlns(
          tag: _roomPrimaryViewBookmarkTag,
          xmlns: _roomPrimaryViewBookmarkXmlns,
          attributes: {_roomPrimaryViewBookmarkAttr: primaryView.wireValue},
        ),
      );
    }
    return List<mox.XMLNode>.unmodifiable(extensions);
  }

  Future<void> applyRoomPrimaryView({
    required String roomJid,
    required ChatPrimaryView primaryView,
  }) async {
    final normalizedRoomJid = _normalizeBareJid(roomJid);
    if (normalizedRoomJid == null || normalizedRoomJid.isEmpty) {
      return;
    }
    final defaultTitle = mox.JID.fromString(normalizedRoomJid).local;
    String? title;
    String? nickname;
    await _dbOp<XmppDatabase>((db) async {
      final existing = await db.getChat(normalizedRoomJid);
      if (existing == null) {
        await db.createChat(
          Chat(
            jid: normalizedRoomJid,
            title: defaultTitle,
            type: ChatType.groupChat,
            primaryView: primaryView,
            lastChangeTimestamp: DateTime.fromMillisecondsSinceEpoch(0),
            contactJid: normalizedRoomJid,
          ),
        );
        return;
      }
      title = existing.title;
      nickname = existing.myNickname;
      if (existing.type == ChatType.groupChat &&
          existing.primaryView == primaryView &&
          existing.contactJid == normalizedRoomJid) {
        return;
      }
      await db.updateChat(
        existing.copyWith(
          type: ChatType.groupChat,
          primaryView: primaryView,
          contactJid: normalizedRoomJid,
        ),
      );
    }, awaitDatabase: true);
    await _upsertBookmarkForRoom(
      roomJid: normalizedRoomJid,
      title: title?.trim().isNotEmpty == true ? title : null,
      nickname: nickname,
      primaryView: primaryView,
    );
  }

  Future<void> _sendRoomPrimaryViewSync({
    required String roomJid,
    required ChatPrimaryView primaryView,
  }) async {
    final message = CalendarSyncMessage.roomPrimaryViewUpdate(
      primaryView: primaryView,
    );
    final envelope = jsonEncode(<String, dynamic>{
      'calendar_sync': message.toJson(),
    });
    final selfJid = _myJid;
    if (selfJid == null) {
      throw XmppMessageException();
    }
    final sent = await _connection.sendMessage(
      mox.MessageEvent(
        selfJid,
        mox.JID.fromString(roomJid),
        false,
        mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
          mox.MessageBodyData(envelope),
          const mox.MessageProcessingHintData([
            mox.MessageProcessingHint.store,
          ]),
        ]),
        id: _connection.generateId(),
        type: 'groupchat',
      ),
    );
    if (!sent) {
      throw XmppMessageException();
    }
  }

  Future<void> _upsertBookmarkForRoom({
    required String roomJid,
    bool? autojoin,
    String? title,
    String? nickname,
    String? password,
    ChatPrimaryView? primaryView,
  }) async {
    final manager = _connection.getManager<BookmarksManager>();
    if (manager == null) {
      _mucLog.fine('Bookmark manager unavailable; skipping bookmark upsert.');
      return;
    }
    try {
      final roomBare = mox.JID.fromString(roomJid).toBare();
      final existingBookmark = await manager.bookmarkForRoom(roomBare);
      if (autojoin == null && existingBookmark == null) {
        _mucLog.fine(_mucBookmarkBaselineUnavailableLog);
        return;
      }
      final normalizedPassword = _normalizePassword(password);
      final resolvedAutojoin = autojoin ?? existingBookmark?.autojoin ?? false;
      final resolvedTitle = title?.trim().isNotEmpty == true
          ? title?.trim()
          : existingBookmark?.name;
      final resolvedNickname = nickname?.trim().isNotEmpty == true
          ? nickname?.trim()
          : existingBookmark?.nick;
      final resolvedPassword = normalizedPassword ?? existingBookmark?.password;
      final extensions = primaryView == null
          ? existingBookmark?.extensions ?? const <mox.XMLNode>[]
          : _extensionsWithPrimaryView(
              existingExtensions:
                  existingBookmark?.extensions ?? const <mox.XMLNode>[],
              primaryView: primaryView,
            );
      _mucLog.fine('Bookmark upsert start. room=$roomBare');
      await manager.upsertBookmark(
        MucBookmark(
          roomBare: roomBare,
          name: resolvedTitle,
          autojoin: resolvedAutojoin,
          nick: resolvedNickname,
          password: resolvedPassword,
          extensions: extensions,
          preserveCachedExtensions: false,
        ),
      );
      _mucLog.fine('Bookmark upsert completed. room=$roomBare');
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
    _forgetRoomNickname(roomJid: roomJid);
    _forgetRoomPassword(roomJid: roomJid);
    final key = _roomKey(roomJid);
    _setRoomExplicitlyLeft(key, true);
    if (!_roomHasLeft(key)) {
      try {
        final manager = _connection.getManager<MUCManager>();
        if (manager != null) {
          await manager.leaveRoom(mox.JID.fromString(roomJid));
        }
      } on Exception {
        // Ignore leave failures when applying bookmark updates.
      }
    }
    await _markRoomLeft(roomJid, statusCodes: const <String>{});
    await _archiveRoomChat(roomJid: roomJid);
  }

  Future<void> _handleSelfPresence(MucSelfPresenceEvent event) async {
    final roomJid = _roomKey(event.roomJid);
    _logJoinEvent(
      message: _mucJoinSelfPresenceEventLog,
      attemptId: _joinAttemptIdForKey(roomJid),
      isErrorPresence: event.isError,
      isAvailablePresence: event.isAvailable,
      isNickChange: event.isNickChange,
      statusCount: event.statusCodes.length,
      hasSelfStatus: event.statusCodes.contains(
        MucStatusCode.selfPresence.code,
      ),
    );
    if (event.shouldLeaveRoom) {
      final Set<String> statusCodes = event.isError
          ? const <String>{}
          : event.statusCodes;
      await _markRoomLeft(
        roomJid,
        statusCodes: statusCodes,
        reason: event.reason ?? event.errorText,
        joinErrorCondition: event.parsedErrorCondition,
        joinErrorText: event.errorText,
        isDestroyed: event.isRoomDestroyed,
        destroyedAlternateRoomJid: event.destroyAlternateRoomJid,
      );
      if (event.shouldArchiveRoom) {
        await _archiveRoomChat(roomJid: roomJid);
      }
      if (event.isError) {
        _completeJoinAttempt(roomJid, error: XmppMessageException());
      }
      return;
    }

    final nextNick = event.nextNick;
    if (nextNick.isEmpty) return;

    _markRoomJoined(roomJid);
    _clearRoomNeedsJoin(roomJid);
    _setRoomNicknameForKey(roomJid, nextNick);
    _rememberRoomNickname(roomJid: roomJid, nickname: nextNick);

    final managerState = await _mucManagerRoomState(roomJid);
    if (managerState != null) {
      managerState.joined = true;
      managerState.nick = nextNick;
    }

    _upsertOccupant(
      roomJid: roomJid,
      occupantId: event.nextOccupantJid,
      nick: nextNick,
      realJid: _myJid?.toBare().toString(),
      affiliation: event.occupantAffiliation,
      role: event.occupantRole,
      isPresent: true,
    );
    _applySelfPresenceStatus(
      roomJid: roomJid,
      statusCodes: event.statusCodes,
      reason: event.reason,
    );
    _applyPendingOwnData(roomJid);
    if (event.hasStatus(MucStatusCode.roomCreated)) {
      _setInstantRoomConfigured(roomJid, false);
      _setInstantRoomPending(roomJid, true);
    }
    _scheduleRoomPostJoinRefresh(roomJid);
    _completeJoinAttempt(roomJid);
    if (event.hasStatus(MucStatusCode.configurationChanged)) {
      await _refreshRoomAvatar(roomJid);
    }
    if (event.isAvailable && !event.isNickChange) {
      await _eventManager.executeHandlers(
        MucArchiveSyncRequestedEvent(roomJid: roomJid),
      );
    }

    await _dbOp<XmppDatabase>((db) async {
      final chat = await db.getChat(roomJid);
      if (chat != null && chat.myNickname != nextNick) {
        await db.updateChat(chat.copyWith(myNickname: nextNick));
      }
    }, awaitDatabase: true);
  }

  Future<void> _handleOwnDataChanged({
    required mox.JID roomJid,
    required String nick,
    required mox.Affiliation affiliation,
    required mox.Role role,
  }) async {
    final key = _roomKey(roomJid.toBare().toString());
    final roomState = _roomStates[key];
    if (roomState?.hasSelfPresence != true) {
      _setPendingOwnDataForKey(
        key,
        _PendingOwnData(nick: nick, affiliation: affiliation, role: role),
      );
      _logJoinEvent(
        message: _mucJoinOwnDataIgnoredLog,
        attemptId: _joinAttemptIdForKey(key),
      );
      return;
    }
    _applyOwnData(
      roomJid: key,
      nick: nick,
      affiliation: affiliation,
      role: role,
    );
  }

  void _applyPendingOwnData(String roomJid) {
    final key = _roomKey(roomJid);
    final pending = _takePendingOwnDataForKey(key);
    if (pending == null) return;
    _applyOwnData(
      roomJid: key,
      nick: pending.nick,
      affiliation: pending.affiliation,
      role: pending.role,
    );
  }

  void _applyOwnData({
    required String roomJid,
    required String nick,
    required mox.Affiliation affiliation,
    required mox.Role role,
  }) {
    final trimmedNick = nick.trim();
    if (trimmedNick.isEmpty) return;
    _setRoomNicknameForKey(roomJid, trimmedNick);
    _rememberRoomNickname(roomJid: roomJid, nickname: trimmedNick);
    _upsertOccupant(
      roomJid: roomJid,
      occupantId: '$roomJid/$trimmedNick',
      nick: trimmedNick,
      realJid: _myJid?.toBare().toString(),
      affiliation: affiliation.toOccupantAffiliation,
      role: role.toOccupantRole,
      isPresent: true,
    );
  }

  void _handleMemberUpsert(mox.JID roomJid, mox.RoomMember member) {
    final key = roomJid.toBare().toString();
    if (_roomHasLeft(_roomKey(key))) return;
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
    if (_roomHasLeft(_roomKey(key))) return;
    final occupantJid = '${_roomKey(key)}/$nick';
    removeOccupant(roomJid: key, occupantId: occupantJid);
  }

  void _handleMemberNickChanged(
    mox.JID roomJid,
    String oldNick,
    String newNick,
  ) {
    final key = _roomKey(roomJid.toString());
    if (_roomHasLeft(key)) return;

    final oldId = '$key/$oldNick';
    final newId = '$key/$newNick';
    final existing = _roomStates[key];
    final occupant =
        existing?.occupantForSenderJid(oldId) ??
        existing?.occupantForNick(oldNick, preferPresent: true);
    if (occupant == null) {
      _upsertOccupant(
        roomJid: key,
        occupantId: newId,
        nick: newNick,
        isPresent: true,
      );
      return;
    }

    removeOccupant(roomJid: key, occupantId: occupant.occupantId);
    final nextOccupantId =
        existing?.isRoomNickOccupantId(occupant.occupantId) == true
        ? newId
        : occupant.occupantId;
    _upsertOccupant(
      roomJid: key,
      occupantId: nextOccupantId,
      nick: newNick,
      realJid: occupant.realJid,
      affiliation: occupant.affiliation,
      role: occupant.role,
      isPresent: occupant.isPresent,
    );
  }

  void _handleInboundOccupantUpsert(mox.MessageEvent event) {
    if (event.type != _messageTypeGroupchat) {
      return;
    }
    final roomJid = _normalizeBareJid(event.from.toBare().toString());
    if (roomJid == null || roomJid.isEmpty) {
      return;
    }
    if (_roomHasLeft(_roomKey(roomJid))) {
      return;
    }
    final nick = event.from.resource.trim();
    if (nick.isEmpty) {
      return;
    }
    _upsertOccupant(roomJid: roomJid, occupantId: '$roomJid/$nick', nick: nick);
  }

  void updateOccupantFromPresence({
    required String roomJid,
    required String occupantId,
    required String nick,
    String? realJid,
    OccupantAffiliation? affiliation,
    OccupantRole? role,
    bool isPresent = true,
    bool fromPresence = false,
  }) {
    if (_roomHasLeft(_roomKey(roomJid))) return;
    final updated = _upsertOccupant(
      roomJid: roomJid,
      occupantId: occupantId,
      nick: nick,
      realJid: realJid,
      affiliation: affiliation,
      role: role,
      isPresent: isPresent,
    );
    if (!fromPresence || !isPresent) return;
    if (!updated.isSelfOccupantId(occupantId) || updated.hasSelfPresence) {
      return;
    }
    final mergedCodes = <String>{
      ...updated.selfPresenceStatusCodes,
      MucStatusCode.selfPresence.code,
    };
    _applySelfPresenceStatus(
      roomJid: roomJid,
      statusCodes: mergedCodes,
      reason: updated.selfPresenceReason,
    );
    _completeJoinAttempt(roomJid);
  }

  void removeOccupant({required String roomJid, required String occupantId}) {
    final key = _roomKey(roomJid);
    final existing = _roomStates[key];
    if (existing == null) return;
    final room = existing.withoutOccupant(occupantId);
    if (identical(room, existing)) return;
    _publishRoomState(roomKey: key, room: room);
  }

  Future<void> _sendAdminItems({
    required String roomJid,
    required List<mox.XMLNode> items,
  }) async {
    if (_connection.getManager<MUCManager>() case final manager?) {
      await manager
          .sendAdminIq(roomJid: roomJid, items: items)
          .timeout(_roomActionTimeout);
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
    return _isMucChatJid(roomBare);
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
    required OccupantAffiliation queriedAffiliation,
    required List<MucAffiliationEntry> entries,
  }) {
    final key = _roomKey(roomJid);
    if (_roomHasLeft(key)) return;
    final existing = _roomStates[key];
    if (existing == null) return;
    final room = existing.withAffiliationEntries(
      queriedAffiliation: queriedAffiliation,
      entries: entries,
      selfRealJid: _myJid?.toBare().toString(),
    );
    final myBareJid = _myJid?.toBare().toString();
    final selfRealJid = room.selfRealJid;
    final selfNick = room.selfNick;
    if (myBareJid != null &&
        selfRealJid != null &&
        selfNick != null &&
        room.myOccupantJid != existing.myOccupantJid &&
        _sameBareJid(selfRealJid, myBareJid)) {
      _setRoomNicknameForKey(key, selfNick);
    }
    _publishRoomState(roomKey: key, room: room);
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
    var resolvedOccupantId = occupantId;
    var current = updated[resolvedOccupantId];
    final normalizedRealJid = _normalizeBareJid(realJid);
    final workingRoom = existing.copyWith(occupants: updated);
    final matchedOccupant = workingRoom.matchingOccupant(
      occupantId,
      realJid: normalizedRealJid,
    );
    final matchedOccupantId = matchedOccupant?.occupantId;
    if (matchedOccupantId != null && matchedOccupantId != resolvedOccupantId) {
      current ??= matchedOccupant;
      if (workingRoom.shouldPreferMatchedOccupantId(
        resolvedOccupantId,
        matchedOccupantId,
      )) {
        resolvedOccupantId = matchedOccupantId;
      }
      updated.remove(matchedOccupantId);
    }
    final base =
        current ??
        Occupant(
          occupantId: resolvedOccupantId,
          nick: nick,
          isPresent: isPresent ?? false,
        );
    final resolvedRealJid = base.nextRealJid(
      realJid,
      fallback: matchedOccupant,
    );
    final next = base.copyWith(
      occupantId: resolvedOccupantId,
      nick: nick,
      realJid: resolvedRealJid,
      affiliation: base.nextAffiliation(affiliation, fallback: matchedOccupant),
      role: base.nextRole(role, fallback: matchedOccupant),
      isPresent: base.nextPresence(isPresent),
    );
    final isNickMatch =
        nick.toLowerCase() == (_roomNicknameForKey(key)?.toLowerCase() ?? '');
    final isKnownSelf =
        _isSelfOccupant(next) || existing.myOccupantJid == resolvedOccupantId;
    final allowNickMatch = _mucJoinInFlight(key);
    updated[resolvedOccupantId] = next;
    var room = existing.copyWith(occupants: updated);
    final shouldMarkSelf = isKnownSelf || (allowNickMatch && isNickMatch);
    if (shouldMarkSelf) {
      _setRoomNicknameForKey(key, nick);
      room = room.withSelfOccupant(
        resolvedOccupantId,
        realJid: resolvedRealJid,
      );
    }
    _publishRoomState(roomKey: key, room: room);
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

  Future<void> _archiveRoomChat({required String roomJid}) async {
    await _dbOp<XmppDatabase>((db) async {
      final chat = await db.getChat(roomJid);
      if (chat == null) {
        return;
      }
      if (!chat.archived || chat.open) {
        await db.updateChat(chat.copyWith(archived: true, open: false));
      }
    }, awaitDatabase: true);
  }

  Future<void> _sendInviteNotice({
    required String roomJid,
    required String inviteeJid,
    String? reason,
    String? password,
  }) async {
    final myBare = _myJid?.toBare().toString();
    if (myBare == null) throw XmppMessageException();
    final chat = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(roomJid),
    );
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
    final displayBody = reason?.isNotEmpty == true
        ? '$displayLine\n$reason'
        : displayLine;
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
      (db) => db.saveMessage(message, chatType: ChatType.chat, selfJid: myBare),
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
      (db) => db.saveMessage(message, chatType: ChatType.chat, selfJid: myBare),
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
    _setRoomNicknameForKey(key, nickname);
    final existing = _roomStates[key];
    final currentOccupant = existing?.selfOccupant;
    final occupantId = '$key/$nickname';
    _upsertOccupant(
      roomJid: roomJid,
      occupantId: occupantId,
      nick: nickname,
      realJid: currentOccupant?.realJid ?? _myJid?.toBare().toString(),
      affiliation: currentOccupant?.affiliation,
      role: currentOccupant?.role,
      isPresent: currentOccupant?.isPresent ?? false,
    );
    await _dbOp<XmppDatabase>((db) async {
      final chat = await db.getChat(roomJid);
      if (chat != null && chat.myNickname != nickname) {
        await db.updateChat(chat.copyWith(myNickname: nickname));
      }
    });
  }

  Future<void> seedDummyRoomData(String roomJid) async {
    final key = _roomKey(roomJid);
    if (!demoOfflineMode) return;
    if (_roomHasLeft(key)) return;
    if (_seededDummyRoom(key)) return;
    final messageCount = await _dbOpReturning<XmppDatabase, int>(
      (db) => db.countChatMessages(
        roomJid,
        filter: MessageTimelineFilter.allWithContact,
      ),
    );
    if (messageCount > 0) return;
    final rememberedNick = _roomNicknameForKey(key)?.trim();
    var resolvedNick = rememberedNick?.isNotEmpty == true
        ? rememberedNick
        : null;
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
    final idPrefix = base64Url
        .encode(utf8.encode(key))
        .replaceAll('=', '')
        .toLowerCase();
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
        timestamp: now.subtract(
          Duration(minutes: (dummyMembers.length - index) * 2),
        ),
        occupantID: occupantId,
      );
      await _dbOp<XmppDatabase>(
        (db) => db.saveMessage(message, chatType: ChatType.groupChat),
      );
    }

    _setSeededDummyRoom(key, true);
  }
}
