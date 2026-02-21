// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models/chat_models.dart';

enum MucStatusCode {
  selfPresence('110'),
  nickChange('303'),
  roomCreated('201'),
  nickAssigned('210'),
  configurationChanged('104'),
  banned('301'),
  kicked('307'),
  roomShutdown('332');

  const MucStatusCode(this.code);

  final String code;
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
    this.myOccupantId,
    Set<String>? selfPresenceStatusCodes,
    this.selfPresenceReason,
  }) : occupants = Map.unmodifiable(
         Map<String, Occupant>.of(occupants ?? <String, Occupant>{}),
       ),
       selfPresenceStatusCodes = Set.unmodifiable(
         Set<String>.of(selfPresenceStatusCodes ?? const <String>{}),
       );

  final String roomJid;
  final Map<String, Occupant> occupants;
  final String? myOccupantId;
  final Set<String> selfPresenceStatusCodes;
  final String? selfPresenceReason;
  late final _RoomOccupantGroups _occupantGroups = _buildOccupantGroups();

  OccupantAffiliation get myAffiliation =>
      occupants[myOccupantId]?.affiliation ?? OccupantAffiliation.none;

  OccupantRole get myRole {
    final role = occupants[myOccupantId]?.role;
    return role ?? OccupantRole.none;
  }

  List<Occupant> get owners => _occupantGroups.owners;

  List<Occupant> get admins => _occupantGroups.admins;

  List<Occupant> get moderators => _occupantGroups.moderators;

  List<Occupant> get members => _occupantGroups.members;

  List<Occupant> get visitors => _occupantGroups.visitors;

  bool get roomCreated =>
      selfPresenceStatusCodes.contains(MucStatusCode.roomCreated.code);

  bool get nickAssigned =>
      selfPresenceStatusCodes.contains(MucStatusCode.nickAssigned.code);

  bool get wasKicked =>
      selfPresenceStatusCodes.contains(MucStatusCode.kicked.code);

  bool get wasBanned =>
      selfPresenceStatusCodes.contains(MucStatusCode.banned.code);

  bool get roomShutdown =>
      selfPresenceStatusCodes.contains(MucStatusCode.roomShutdown.code);

  _RoomOccupantGroups _buildOccupantGroups() {
    final owners = <Occupant>[];
    final admins = <Occupant>[];
    final moderators = <Occupant>[];
    final members = <Occupant>[];
    final visitors = <Occupant>[];

    for (final occupant in occupants.values) {
      if (occupant.affiliation.isOutcast) continue;
      if (occupant.affiliation.isOwner) {
        owners.add(occupant);
      } else if (occupant.affiliation.isAdmin) {
        admins.add(occupant);
      } else if (occupant.role.isModerator) {
        moderators.add(occupant);
      } else if (occupant.affiliation.isMember) {
        members.add(occupant);
      } else if (occupant.affiliation.isNone) {
        visitors.add(occupant);
      }
    }

    _sortByNick(owners);
    _sortByNick(admins);
    _sortByNick(moderators);
    _sortByNick(members);
    _sortByNick(visitors);

    return _RoomOccupantGroups(
      owners: owners,
      admins: admins,
      moderators: moderators,
      members: members,
      visitors: visitors,
    );
  }

  void _sortByNick(List<Occupant> items) {
    items.sort((a, b) => a.nick.toLowerCase().compareTo(b.nick.toLowerCase()));
  }

  RoomState copyWith({
    Map<String, Occupant>? occupants,
    String? myOccupantId,
    Set<String>? selfPresenceStatusCodes,
    String? selfPresenceReason,
  }) => RoomState(
    roomJid: roomJid,
    occupants: occupants ?? this.occupants,
    myOccupantId: myOccupantId ?? this.myOccupantId,
    selfPresenceStatusCodes:
        selfPresenceStatusCodes ?? this.selfPresenceStatusCodes,
    selfPresenceReason: selfPresenceReason ?? this.selfPresenceReason,
  );
}

extension RoomStateAvatarPermissions on RoomState {
  bool get canEditAvatar => myAffiliation.isOwner || myAffiliation.isAdmin;
}

extension RoomStatePresence on RoomState {
  bool get hasSelfPresence =>
      selfPresenceStatusCodes.contains(MucStatusCode.selfPresence.code);
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

enum RoomMemberSectionKind { owners, admins, moderators, members, visitors }

class RoomMemberEntry {
  const RoomMemberEntry({
    required this.occupant,
    required this.actions,
    this.avatarPath,
  });

  final Occupant occupant;
  final List<MucModerationAction> actions;
  final String? avatarPath;
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
    required this.visitors,
  });

  final List<Occupant> owners;
  final List<Occupant> admins;
  final List<Occupant> moderators;
  final List<Occupant> members;
  final List<Occupant> visitors;
}
