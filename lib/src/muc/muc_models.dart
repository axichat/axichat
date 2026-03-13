// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

enum MucStatusCode {
  selfPresence('110'),
  nickChange('303'),
  roomCreated('201'),
  nickAssigned('210'),
  configurationChanged('104'),
  banned('301'),
  kicked('307'),
  removedByAffiliationChange('321'),
  removedByMembersOnlyChange('322'),
  roomShutdown('332');

  const MucStatusCode(this.code);

  final String code;
}

enum MucJoinErrorCondition {
  registrationRequired('registration-required'),
  forbidden('forbidden'),
  notAuthorized('not-authorized'),
  itemNotFound('item-not-found'),
  serviceUnavailable('service-unavailable'),
  other('');

  const MucJoinErrorCondition(this.xmlValue);

  final String xmlValue;

  bool get blocksAutoRejoin => switch (this) {
    MucJoinErrorCondition.registrationRequired ||
    MucJoinErrorCondition.forbidden ||
    MucJoinErrorCondition.notAuthorized ||
    MucJoinErrorCondition.itemNotFound => true,
    _ => false,
  };

  static MucJoinErrorCondition? fromString(String? value) => switch (value) {
    'registration-required' => registrationRequired,
    'forbidden' => forbidden,
    'not-authorized' => notAuthorized,
    'item-not-found' => itemNotFound,
    'service-unavailable' => serviceUnavailable,
    null || '' => null,
    _ => other,
  };
}

enum OccupantAffiliation {
  owner,
  admin,
  member,
  outcast,
  none;

  bool get isOwner => this == owner;

  bool get isAdmin => this == admin;

  bool get isMember => this == member;

  bool get isOutcast => this == outcast;

  bool get isNone => this == none;

  bool get canManagePins => isOwner || isAdmin || isMember;

  int get authorityRank => switch (this) {
    OccupantAffiliation.owner => 3,
    OccupantAffiliation.admin => 2,
    OccupantAffiliation.member => 1,
    OccupantAffiliation.none => 0,
    OccupantAffiliation.outcast => -1,
  };

  String get xmlValue => switch (this) {
    OccupantAffiliation.owner => 'owner',
    OccupantAffiliation.admin => 'admin',
    OccupantAffiliation.member => 'member',
    OccupantAffiliation.outcast => 'outcast',
    OccupantAffiliation.none => 'none',
  };

  static OccupantAffiliation fromString(String? value) => switch (value) {
    'owner' => owner,
    'admin' => admin,
    'member' => member,
    'outcast' => outcast,
    _ => none,
  };
}

enum OccupantRole {
  moderator,
  participant,
  visitor,
  none;

  bool get isModerator => this == moderator;

  bool get isParticipant => this == participant;

  bool get isVisitor => this == visitor;

  bool get isNone => this == none;

  String get xmlValue => switch (this) {
    OccupantRole.moderator => 'moderator',
    OccupantRole.participant => 'participant',
    OccupantRole.visitor => 'visitor',
    OccupantRole.none => 'none',
  };

  static OccupantRole fromString(String? value) => switch (value) {
    'moderator' => moderator,
    'participant' => participant,
    'visitor' => visitor,
    _ => none,
  };
}

class Occupant {
  Occupant({
    required this.occupantId,
    required this.nick,
    this.realJid,
    this.affiliation = OccupantAffiliation.none,
    this.role = OccupantRole.none,
    this.chatType = ChatType.groupChat,
    this.isPresent = true,
  });

  final String occupantId;
  final String nick;
  final String? realJid;
  final OccupantAffiliation affiliation;
  final OccupantRole role;
  final ChatType chatType;
  final bool isPresent;

  bool get isModerator => role.isModerator;
  bool get isOffline => !isPresent;
  bool get hasRealJid => realJid?.trim().isNotEmpty == true;
  bool get hasResolvedMembershipState => !affiliation.isNone || !role.isNone;
  String get normalizedNick => nick.trim().toLowerCase();
  String get avatarKey {
    final resolvedRealJid = realJid?.trim();
    if (resolvedRealJid == null || resolvedRealJid.isEmpty) {
      return nick;
    }
    return bareAddress(resolvedRealJid) ?? resolvedRealJid;
  }

  bool matchesOccupantId(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return false;
    }
    return occupantId == trimmedValue ||
        sameFullAddress(occupantId, trimmedValue);
  }

  bool matchesNick(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return false;
    }
    return normalizedNick == trimmedValue.toLowerCase();
  }

  bool matchesRealJid(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty || !hasRealJid) {
      return false;
    }
    return sameBareAddress(realJid, trimmedValue);
  }

  Occupant copyWith({
    String? occupantId,
    String? nick,
    String? realJid,
    OccupantAffiliation? affiliation,
    OccupantRole? role,
    ChatType? chatType,
    bool? isPresent,
  }) => Occupant(
    occupantId: occupantId ?? this.occupantId,
    nick: nick ?? this.nick,
    realJid: realJid ?? this.realJid,
    affiliation: affiliation ?? this.affiliation,
    role: role ?? this.role,
    chatType: chatType ?? this.chatType,
    isPresent: isPresent ?? this.isPresent,
  );
}

class RoomState {
  RoomState({
    required this.roomJid,
    Map<String, Occupant>? occupants,
    this.myOccupantJid,
    Set<String>? selfPresenceStatusCodes,
    this.selfPresenceReason,
    this.joinErrorCondition,
    this.joinErrorText,
    this.isDestroyed = false,
    this.destroyedAlternateRoomJid,
    this.postJoinRefreshPending = false,
  }) : occupants = Map.unmodifiable(
         Map<String, Occupant>.of(occupants ?? <String, Occupant>{}),
       ),
       selfPresenceStatusCodes = Set.unmodifiable(
         Set<String>.of(selfPresenceStatusCodes ?? const <String>{}),
       );

  final String roomJid;
  final Map<String, Occupant> occupants;
  final String? myOccupantJid;
  final Set<String> selfPresenceStatusCodes;
  final String? selfPresenceReason;
  final MucJoinErrorCondition? joinErrorCondition;
  final String? joinErrorText;
  final bool isDestroyed;
  final String? destroyedAlternateRoomJid;
  final bool postJoinRefreshPending;
  late final _RoomOccupantGroups _occupantGroups = _buildOccupantGroups();
  late final _RoomOccupantDirectory _occupantDirectory = _RoomOccupantDirectory(
    roomJid: roomJid,
    occupants: occupants,
  );

  OccupantAffiliation get myAffiliation =>
      occupants[myOccupantJid]?.affiliation ?? OccupantAffiliation.none;

  OccupantRole get myRole {
    final role = occupants[myOccupantJid]?.role;
    return role ?? OccupantRole.none;
  }

  List<Occupant> get owners => _occupantGroups.owners;

  List<Occupant> get admins => _occupantGroups.admins;

  List<Occupant> get moderators => _occupantGroups.moderators;

  List<Occupant> get members => _occupantGroups.members;

  List<Occupant> get participants => _occupantGroups.participants;

  List<Occupant> get visitors => _occupantGroups.visitors;

  Occupant? get selfOccupant {
    final occupantJid = myOccupantJid;
    if (occupantJid == null || occupantJid.isEmpty) {
      return null;
    }
    return occupants[occupantJid];
  }

  String? get selfNick => selfOccupant?.nick;

  String? get selfRealJid {
    final resolvedRealJid = selfOccupant?.realJid?.trim();
    if (resolvedRealJid == null || resolvedRealJid.isEmpty) {
      return null;
    }
    return resolvedRealJid;
  }

  bool get roomCreated =>
      selfPresenceStatusCodes.contains(MucStatusCode.roomCreated.code);

  bool get nickAssigned =>
      selfPresenceStatusCodes.contains(MucStatusCode.nickAssigned.code);

  bool get wasKicked =>
      selfPresenceStatusCodes.contains(MucStatusCode.kicked.code);

  bool get wasBanned =>
      selfPresenceStatusCodes.contains(MucStatusCode.banned.code);

  bool get removedByAffiliationChange => selfPresenceStatusCodes.contains(
    MucStatusCode.removedByAffiliationChange.code,
  );

  bool get removedByMembersOnlyChange => selfPresenceStatusCodes.contains(
    MucStatusCode.removedByMembersOnlyChange.code,
  );

  bool get roomDestroyed => isDestroyed;

  bool get roomShutdown =>
      selfPresenceStatusCodes.contains(MucStatusCode.roomShutdown.code);

  bool isRoomNickOccupantId(String occupantId) =>
      _occupantDirectory.isRoomNickOccupantId(occupantId);

  Occupant? occupantForRealJid(
    String realJid, {
    bool excludeRoomNickOccupantIds = false,
  }) => _occupantDirectory.occupantForRealJid(
    realJid,
    excludeRoomNickOccupantIds: excludeRoomNickOccupantIds,
  );

  Occupant? occupantForNick(
    String nick, {
    bool preferPresent = false,
    bool preferRealJid = false,
    bool roomNickOccupantOnly = false,
  }) => _occupantDirectory.occupantForNick(
    nick,
    preferPresent: preferPresent,
    preferRealJid: preferRealJid,
    roomNickOccupantOnly: roomNickOccupantOnly,
  );

  Occupant? occupantForSenderJid(
    String senderJid, {
    bool preferRealJid = false,
  }) => _occupantDirectory.occupantForSenderJid(
    senderJid,
    preferRealJid: preferRealJid,
  );

  String? canonicalOccupantId(String occupantId) =>
      _occupantDirectory.canonicalOccupantId(occupantId);

  String? occupantIdForAffiliation({String? realJid, String? nick}) =>
      _occupantDirectory.occupantIdForAffiliation(realJid: realJid, nick: nick);

  String syntheticOccupantIdForAffiliationJid(String jid) {
    final normalizedJid = bareAddress(jid) ?? jid.trim();
    return '$roomJid/~$normalizedJid';
  }

  String fallbackNickForAffiliationJid(String jid) =>
      bareAddress(jid) ?? jid.trim();

  _RoomOccupantGroups _buildOccupantGroups() {
    final owners = <Occupant>[];
    final admins = <Occupant>[];
    final moderators = <Occupant>[];
    final members = <Occupant>[];
    final participants = <Occupant>[];
    final visitors = <Occupant>[];

    for (final occupant in occupants.values) {
      if (occupant.affiliation.isOutcast) continue;
      if (!occupant.hasResolvedMembershipState) continue;
      if (occupant.affiliation.isOwner) {
        owners.add(occupant);
      } else if (occupant.affiliation.isAdmin) {
        admins.add(occupant);
      } else if (occupant.role.isModerator) {
        moderators.add(occupant);
      } else if (occupant.affiliation.isMember) {
        members.add(occupant);
      } else if (occupant.role.isParticipant) {
        participants.add(occupant);
      } else if (occupant.affiliation.isNone) {
        visitors.add(occupant);
      }
    }

    _sortByNick(owners);
    _sortByNick(admins);
    _sortByNick(moderators);
    _sortByNick(members);
    _sortByNick(participants);
    _sortByNick(visitors);

    return _RoomOccupantGroups(
      owners: owners,
      admins: admins,
      moderators: moderators,
      members: members,
      participants: participants,
      visitors: visitors,
    );
  }

  void _sortByNick(List<Occupant> items) {
    items.sort((a, b) => a.nick.toLowerCase().compareTo(b.nick.toLowerCase()));
  }

  RoomState copyWith({
    Map<String, Occupant>? occupants,
    String? myOccupantJid,
    Set<String>? selfPresenceStatusCodes,
    String? selfPresenceReason,
    MucJoinErrorCondition? joinErrorCondition,
    String? joinErrorText,
    bool? isDestroyed,
    String? destroyedAlternateRoomJid,
    bool? postJoinRefreshPending,
  }) => RoomState(
    roomJid: roomJid,
    occupants: occupants ?? this.occupants,
    myOccupantJid: myOccupantJid ?? this.myOccupantJid,
    selfPresenceStatusCodes:
        selfPresenceStatusCodes ?? this.selfPresenceStatusCodes,
    selfPresenceReason: selfPresenceReason ?? this.selfPresenceReason,
    joinErrorCondition: joinErrorCondition ?? this.joinErrorCondition,
    joinErrorText: joinErrorText ?? this.joinErrorText,
    isDestroyed: isDestroyed ?? this.isDestroyed,
    destroyedAlternateRoomJid:
        destroyedAlternateRoomJid ?? this.destroyedAlternateRoomJid,
    postJoinRefreshPending:
        postJoinRefreshPending ?? this.postJoinRefreshPending,
  );
}

extension RoomStateAvatarPermissions on RoomState {
  bool get canEditAvatar => myAffiliation.isOwner || myAffiliation.isAdmin;
}

extension RoomStatePresence on RoomState {
  bool get hasSelfPresence =>
      selfPresenceStatusCodes.contains(MucStatusCode.selfPresence.code);

  bool get hasJoinError => joinErrorCondition != null || joinErrorText != null;

  bool get hasTerminalExit =>
      wasKicked ||
      wasBanned ||
      roomShutdown ||
      roomDestroyed ||
      removedByAffiliationChange ||
      removedByMembersOnlyChange;

  bool get blocksAutoRejoin => joinErrorCondition?.blocksAutoRejoin == true;

  bool get hasPresentSelfOccupant {
    final occupantJid = myOccupantJid;
    if (occupantJid == null || occupantJid.isEmpty) {
      return false;
    }
    return occupants[occupantJid]?.isPresent == true;
  }

  bool get isReadyForMessaging => hasSelfPresence && hasPresentSelfOccupant;

  bool get isBootstrapPending =>
      !hasJoinError &&
      !hasTerminalExit &&
      (!isReadyForMessaging || roomCreated || postJoinRefreshPending);
}

enum MucModerationAction {
  kick,
  ban,
  member,
  admin,
  owner,
  moderator,
  participant;

  bool get isKick => this == kick;

  bool get isBan => this == ban;

  bool get isAffiliationChange =>
      this == member || this == admin || this == owner || this == ban;

  bool get isRoleChange => this == moderator || this == participant;
}

enum RoomMemberSectionKind {
  owners,
  admins,
  moderators,
  members,
  participants,
  visitors,
}

class RoomMemberEntry {
  const RoomMemberEntry({
    required this.occupant,
    required this.actions,
    this.avatarPath,
    this.directChatJid,
  });

  final Occupant occupant;
  final List<MucModerationAction> actions;
  final String? avatarPath;
  final String? directChatJid;
}

class RoomMemberSection {
  const RoomMemberSection({required this.kind, required this.members});

  final RoomMemberSectionKind kind;
  final List<RoomMemberEntry> members;
}

class _RoomOccupantGroups {
  const _RoomOccupantGroups({
    required this.owners,
    required this.admins,
    required this.moderators,
    required this.members,
    required this.participants,
    required this.visitors,
  });

  final List<Occupant> owners;
  final List<Occupant> admins;
  final List<Occupant> moderators;
  final List<Occupant> members;
  final List<Occupant> participants;
  final List<Occupant> visitors;
}

class _RoomOccupantDirectory {
  const _RoomOccupantDirectory({
    required this.roomJid,
    required this.occupants,
  });

  final String roomJid;
  final Map<String, Occupant> occupants;

  bool isRoomNickOccupantId(String occupantId) {
    final parsed = parseJid(occupantId);
    if (parsed == null) {
      return false;
    }
    final resource = parsed.resource.trim();
    if (resource.isEmpty) {
      return false;
    }
    return parsed.toBare().toString() == roomJid;
  }

  Occupant? occupantForRealJid(
    String realJid, {
    bool excludeRoomNickOccupantIds = false,
  }) {
    final trimmedRealJid = realJid.trim();
    if (trimmedRealJid.isEmpty) {
      return null;
    }
    Occupant? fallback;
    for (final occupant in occupants.values) {
      if (excludeRoomNickOccupantIds &&
          isRoomNickOccupantId(occupant.occupantId)) {
        continue;
      }
      if (!occupant.matchesRealJid(trimmedRealJid)) {
        continue;
      }
      if (occupant.isPresent) {
        return occupant;
      }
      fallback ??= occupant;
    }
    return fallback;
  }

  Occupant? occupantForNick(
    String nick, {
    bool preferPresent = false,
    bool preferRealJid = false,
    bool roomNickOccupantOnly = false,
  }) {
    final trimmedNick = nick.trim();
    if (trimmedNick.isEmpty) {
      return null;
    }
    Occupant? fallback;
    for (final occupant in occupants.values) {
      if (roomNickOccupantOnly && !isRoomNickOccupantId(occupant.occupantId)) {
        continue;
      }
      if (!occupant.matchesNick(trimmedNick)) {
        continue;
      }
      fallback ??= occupant;
      if (preferRealJid && occupant.hasRealJid) {
        return occupant;
      }
      if (preferPresent && occupant.isPresent) {
        return occupant;
      }
    }
    return fallback;
  }

  Occupant? occupantForSenderJid(
    String senderJid, {
    bool preferRealJid = false,
  }) {
    final trimmedSenderJid = senderJid.trim();
    if (trimmedSenderJid.isEmpty) {
      return null;
    }
    final direct = occupants[trimmedSenderJid];
    Occupant? fallback = direct;
    if (direct != null && (!preferRealJid || direct.hasRealJid)) {
      return direct;
    }
    for (final occupant in occupants.values) {
      if (occupant.occupantId == direct?.occupantId) {
        continue;
      }
      if (!occupant.matchesOccupantId(trimmedSenderJid)) {
        continue;
      }
      fallback ??= occupant;
      if (!preferRealJid || occupant.hasRealJid) {
        return occupant;
      }
    }
    final senderNick = addressResourcePart(trimmedSenderJid)?.trim();
    if (senderNick == null || senderNick.isEmpty) {
      return fallback;
    }
    return occupantForNick(
          senderNick,
          preferRealJid: preferRealJid,
          preferPresent: !preferRealJid,
        ) ??
        fallback;
  }

  String? canonicalOccupantId(String occupantId) {
    final trimmedOccupantId = occupantId.trim();
    if (trimmedOccupantId.isEmpty) {
      return null;
    }
    if (occupants.containsKey(trimmedOccupantId)) {
      return trimmedOccupantId;
    }
    if (isRoomNickOccupantId(trimmedOccupantId)) {
      for (final occupant in occupants.values) {
        if (!isRoomNickOccupantId(occupant.occupantId)) {
          continue;
        }
        if (occupant.matchesOccupantId(trimmedOccupantId)) {
          return occupant.occupantId;
        }
      }
      final nick = addressResourcePart(trimmedOccupantId)?.trim();
      if (nick == null || nick.isEmpty) {
        return null;
      }
      return occupantForNick(
        nick,
        preferPresent: true,
        roomNickOccupantOnly: true,
      )?.occupantId;
    }
    return occupantForSenderJid(trimmedOccupantId)?.occupantId;
  }

  String? occupantIdForAffiliation({String? realJid, String? nick}) {
    final trimmedRealJid = realJid?.trim();
    if (trimmedRealJid?.isNotEmpty == true) {
      final direct = occupantForRealJid(
        trimmedRealJid!,
        excludeRoomNickOccupantIds: false,
      );
      if (direct != null) {
        return direct.occupantId;
      }
      final trimmedNick = nick?.trim();
      if (trimmedNick?.isNotEmpty == true) {
        final roomNickOccupant = occupantForNick(
          trimmedNick!,
          preferPresent: true,
          roomNickOccupantOnly: true,
        );
        if (roomNickOccupant == null) {
          return null;
        }
        final occupantRealJid = roomNickOccupant.realJid?.trim();
        if (occupantRealJid != null &&
            occupantRealJid.isNotEmpty &&
            !sameBareAddress(occupantRealJid, trimmedRealJid)) {
          return null;
        }
        return roomNickOccupant.occupantId;
      }
      return null;
    }
    final trimmedNick = nick?.trim();
    if (trimmedNick?.isNotEmpty != true) {
      return null;
    }
    return canonicalOccupantId('$roomJid/$trimmedNick');
  }
}
