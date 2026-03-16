// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

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

enum RoomMemberSectionKind {
  owners,
  admins,
  moderators,
  members,
  participants,
  visitors,
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
  String? get bareRealJid {
    final resolvedRealJid = realJid?.trim();
    if (resolvedRealJid == null || resolvedRealJid.isEmpty) {
      return null;
    }
    return bareAddress(resolvedRealJid) ?? resolvedRealJid;
  }

  String? get normalizedBareRealJid {
    final resolvedRealJid = realJid?.trim();
    if (resolvedRealJid == null || resolvedRealJid.isEmpty) {
      return null;
    }
    final normalized = normalizedAddressKey(resolvedRealJid);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String get avatarKey {
    final resolvedRealJid = bareRealJid;
    if (resolvedRealJid == null) {
      return nick;
    }
    return resolvedRealJid;
  }

  RoomMemberSectionKind get memberSectionKind {
    if (affiliation.isOwner) {
      return RoomMemberSectionKind.owners;
    }
    if (affiliation.isAdmin) {
      return RoomMemberSectionKind.admins;
    }
    if (role.isModerator) {
      return RoomMemberSectionKind.moderators;
    }
    if (affiliation.isMember) {
      return RoomMemberSectionKind.members;
    }
    if (role.isParticipant) {
      return RoomMemberSectionKind.participants;
    }
    return RoomMemberSectionKind.visitors;
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

  bool canBeKickedBy({
    required OccupantAffiliation actorAffiliation,
    required OccupantRole actorRole,
  }) {
    if (!isPresent) {
      return false;
    }
    if (!actorRole.isModerator &&
        !actorAffiliation.isAdmin &&
        !actorAffiliation.isOwner) {
      return false;
    }
    if (actorAffiliation.authorityRank < affiliation.authorityRank) {
      return false;
    }
    if (role.isModerator) {
      return actorAffiliation.isAdmin || actorAffiliation.isOwner;
    }
    return role.isParticipant || role.isVisitor;
  }

  bool canBeBannedBy({required OccupantAffiliation actorAffiliation}) {
    if (normalizedBareRealJid == null) return false;
    if (actorAffiliation.isOwner) return true;
    if (actorAffiliation.isAdmin) {
      return affiliation.isMember || affiliation.isNone;
    }
    return false;
  }

  bool canChangeAffiliationTo({
    required OccupantAffiliation actorAffiliation,
    required OccupantAffiliation nextAffiliation,
  }) {
    if (normalizedBareRealJid == null) return false;
    if (affiliation == nextAffiliation) return false;
    if (actorAffiliation.isOwner) {
      return true;
    }
    if (!actorAffiliation.isAdmin) {
      return false;
    }
    return nextAffiliation.isMember && affiliation.isNone;
  }

  bool canBeGrantedModeratorBy({
    required OccupantAffiliation actorAffiliation,
  }) {
    if (!isPresent) {
      return false;
    }
    if (!actorAffiliation.isOwner && !actorAffiliation.isAdmin) {
      return false;
    }
    if (role.isModerator) {
      return false;
    }
    return affiliation.isMember || affiliation.isNone;
  }

  bool canBeRevokedModeratorBy({
    required OccupantAffiliation actorAffiliation,
  }) {
    if (!isPresent) {
      return false;
    }
    if (!actorAffiliation.isOwner && !actorAffiliation.isAdmin) {
      return false;
    }
    if (!role.isModerator) {
      return false;
    }
    return affiliation.isMember || affiliation.isNone;
  }

  String? nextRealJid(String? realJid, {Occupant? fallback}) =>
      realJid ?? (isPresent ? this.realJid : null) ?? fallback?.realJid;

  OccupantAffiliation nextAffiliation(
    OccupantAffiliation? affiliation, {
    Occupant? fallback,
  }) {
    final nextAffiliation = affiliation ?? this.affiliation;
    if (!nextAffiliation.isNone) {
      return nextAffiliation;
    }
    return fallback?.affiliation ?? OccupantAffiliation.none;
  }

  OccupantRole nextRole(OccupantRole? role, {Occupant? fallback}) {
    final nextRole = role ?? this.role;
    if (!nextRole.isNone) {
      return nextRole;
    }
    return fallback?.role ?? OccupantRole.none;
  }

  bool nextPresence(bool? isPresent) => isPresent ?? this.isPresent;

  Occupant withUnavailable() {
    if (!isPresent) {
      return this;
    }
    return copyWith(isPresent: false);
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
