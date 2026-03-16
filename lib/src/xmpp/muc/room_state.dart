// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/xmpp/muc/muc_join_state.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';

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

  bool isSelfOccupantId(String? occupantId) {
    final trimmedOccupantId = occupantId?.trim();
    if (trimmedOccupantId == null || trimmedOccupantId.isEmpty) {
      return false;
    }
    final trimmedSelfOccupantId = myOccupantJid?.trim();
    if (trimmedSelfOccupantId == null || trimmedSelfOccupantId.isEmpty) {
      return false;
    }
    return trimmedSelfOccupantId == trimmedOccupantId;
  }

  bool isSelfOccupant(Occupant occupant) =>
      isSelfOccupantId(occupant.occupantId);

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

  String? resolvedSelfJid({String? fallbackJid}) {
    final trimmedFallback = fallbackJid?.trim();
    if (trimmedFallback != null && trimmedFallback.isNotEmpty) {
      return trimmedFallback;
    }
    final realJid = selfRealJid;
    if (realJid == null || realJid.isEmpty) {
      return null;
    }
    return bareAddress(realJid) ?? realJid;
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

  bool isOccupantSenderJid(String senderJid) {
    final senderBare = normalizedAddressKey(senderJid);
    final roomBare = normalizedAddressKey(roomJid);
    if (senderBare == null || roomBare == null || senderBare != roomBare) {
      return false;
    }
    final nick = addressResourcePart(senderJid)?.trim();
    return nick != null && nick.isNotEmpty;
  }

  bool shouldPreferMatchedOccupantId(
    String occupantId,
    String matchedOccupantId,
  ) {
    if (isRoomNickOccupantId(occupantId)) {
      return false;
    }
    return isRoomNickOccupantId(matchedOccupantId);
  }

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

  String? senderNick(String senderJid) {
    final occupantNick = occupantForSenderJid(
      senderJid,
      preferRealJid: true,
    )?.nick.trim();
    if (occupantNick != null && occupantNick.isNotEmpty) {
      return occupantNick;
    }
    final fallbackNick = addressResourcePart(senderJid)?.trim();
    if (fallbackNick == null || fallbackNick.isEmpty) {
      return null;
    }
    return fallbackNick;
  }

  bool senderMatchesClaimedJid({
    required String senderJid,
    required String claimedJid,
  }) {
    final trimmedClaimed = claimedJid.trim();
    if (trimmedClaimed.isEmpty) {
      return false;
    }
    if (!isOccupantSenderJid(senderJid)) {
      return sameNormalizedAddressValue(senderJid, trimmedClaimed);
    }
    final realJid = occupantForSenderJid(
      senderJid,
      preferRealJid: true,
    )?.realJid;
    if (realJid != null && realJid.trim().isNotEmpty) {
      return sameNormalizedAddressValue(realJid, trimmedClaimed);
    }
    return sameNormalizedAddressValue(senderJid, trimmedClaimed);
  }

  bool isSelfSenderJid(
    String senderJid, {
    String? selfJid,
    String? fallbackSelfNick,
  }) {
    if (isSelfOccupantId(senderJid)) {
      return true;
    }
    final resolvedSelfJid = selfRealJid ?? selfJid;
    final senderRealJid = occupantForSenderJid(
      senderJid,
      preferRealJid: true,
    )?.realJid;
    if (sameNormalizedAddressValue(senderRealJid, resolvedSelfJid)) {
      return true;
    }
    final resolvedSelfNick = (selfNick ?? fallbackSelfNick)?.trim();
    if (resolvedSelfNick == null || resolvedSelfNick.isEmpty) {
      return false;
    }
    return senderNick(senderJid) == resolvedSelfNick;
  }

  Occupant? matchingOccupant(String occupantId, {String? realJid}) {
    final trimmedRealJid = realJid?.trim();
    if (trimmedRealJid != null && trimmedRealJid.isNotEmpty) {
      final matchedByRealJid = occupantForRealJid(
        trimmedRealJid,
        excludeRoomNickOccupantIds: true,
      );
      if (matchedByRealJid != null) {
        return matchedByRealJid;
      }
    }
    final canonicalId = canonicalOccupantId(occupantId);
    if (canonicalId == null) {
      return null;
    }
    return occupants[canonicalId];
  }

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

  List<MucModerationAction> moderationActionsFor(Occupant occupant) {
    if (isSelfOccupant(occupant)) return const <MucModerationAction>[];
    final actions = <MucModerationAction>[];
    if (occupant.canBeKickedBy(
      actorAffiliation: myAffiliation,
      actorRole: myRole,
    )) {
      actions.add(MucModerationAction.kick);
    }
    if (occupant.canBeBannedBy(actorAffiliation: myAffiliation)) {
      actions.add(MucModerationAction.ban);
    }
    if (occupant.canChangeAffiliationTo(
      actorAffiliation: myAffiliation,
      nextAffiliation: OccupantAffiliation.member,
    )) {
      actions.add(MucModerationAction.member);
    }
    if (occupant.canChangeAffiliationTo(
      actorAffiliation: myAffiliation,
      nextAffiliation: OccupantAffiliation.admin,
    )) {
      actions.add(MucModerationAction.admin);
    }
    if (occupant.canChangeAffiliationTo(
      actorAffiliation: myAffiliation,
      nextAffiliation: OccupantAffiliation.owner,
    )) {
      actions.add(MucModerationAction.owner);
    }
    if (occupant.canBeGrantedModeratorBy(actorAffiliation: myAffiliation)) {
      actions.add(MucModerationAction.moderator);
    }
    if (occupant.canBeRevokedModeratorBy(actorAffiliation: myAffiliation)) {
      actions.add(MucModerationAction.participant);
    }
    return actions;
  }

  String? directChatJidForOccupant(Occupant occupant) {
    if (isSelfOccupant(occupant)) {
      return null;
    }
    final realJid = occupant.normalizedBareRealJid;
    if (realJid == null) {
      return null;
    }
    final bareRoomJid = normalizedAddressKey(roomJid) ?? roomJid.trim();
    if (realJid == bareRoomJid) {
      return null;
    }
    return realJid;
  }

  RoomState withSelfPresence({
    required Set<String> statusCodes,
    String? reason,
  }) {
    final sameStatusCodes =
        statusCodes.length == selfPresenceStatusCodes.length &&
        statusCodes.containsAll(selfPresenceStatusCodes);
    if (sameStatusCodes &&
        selfPresenceReason == reason &&
        joinErrorCondition == null &&
        joinErrorText == null) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: occupants,
      myOccupantJid: myOccupantJid,
      selfPresenceStatusCodes: statusCodes,
      selfPresenceReason: reason,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withSelfOccupantId(String? occupantId) {
    final trimmedOccupantId = occupantId?.trim();
    final nextOccupantId =
        trimmedOccupantId == null || trimmedOccupantId.isEmpty
        ? null
        : trimmedOccupantId;
    if (myOccupantJid == nextOccupantId) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: occupants,
      myOccupantJid: nextOccupantId,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: joinErrorCondition,
      joinErrorText: joinErrorText,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withSelfOccupant(String occupantId, {String? realJid}) {
    final trimmedOccupantId = occupantId.trim();
    if (trimmedOccupantId.isEmpty) {
      return this;
    }
    var room = this;
    final previousSelfOccupantId = myOccupantJid;
    final trimmedRealJid = realJid?.trim();
    if (trimmedRealJid != null && trimmedRealJid.isNotEmpty) {
      room = room.withoutOtherOccupantsForRealJid(
        keepOccupantId: trimmedOccupantId,
        realJid: trimmedRealJid,
      );
    }
    if (previousSelfOccupantId != null &&
        previousSelfOccupantId != trimmedOccupantId) {
      room = room.withoutExactOccupant(previousSelfOccupantId);
    }
    return room.withSelfOccupantId(trimmedOccupantId);
  }

  RoomState withJoinFailure({MucJoinErrorCondition? condition, String? text}) {
    if (joinErrorCondition == condition && joinErrorText == text) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: occupants,
      myOccupantJid: myOccupantJid,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: condition,
      joinErrorText: text,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withoutJoinFailure() {
    if (joinErrorCondition == null && joinErrorText == null) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: occupants,
      myOccupantJid: myOccupantJid,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withDestroyedState({
    required bool destroyed,
    String? alternateRoomJid,
  }) {
    final nextAlternateRoomJid = destroyed ? alternateRoomJid : null;
    if (isDestroyed == destroyed &&
        destroyedAlternateRoomJid == nextAlternateRoomJid) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: occupants,
      myOccupantJid: myOccupantJid,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: joinErrorCondition,
      joinErrorText: joinErrorText,
      isDestroyed: destroyed,
      destroyedAlternateRoomJid: nextAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withoutSelfPresenceStatusCode(String statusCode) {
    if (!selfPresenceStatusCodes.contains(statusCode)) {
      return this;
    }
    final updatedStatusCodes = Set<String>.of(selfPresenceStatusCodes)
      ..remove(statusCode);
    return withSelfPresence(
      statusCodes: updatedStatusCodes,
      reason: selfPresenceReason,
    );
  }

  RoomState withPostJoinRefreshPending(bool pending) {
    if (postJoinRefreshPending == pending) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: occupants,
      myOccupantJid: myOccupantJid,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: joinErrorCondition,
      joinErrorText: joinErrorText,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: pending,
    );
  }

  RoomState withAffiliationEntries({
    required OccupantAffiliation queriedAffiliation,
    required List<MucAffiliationEntry> entries,
    String? selfRealJid,
  }) {
    final updated = Map<String, Occupant>.of(occupants);
    var nextMyOccupantJid = myOccupantJid;
    final retainedOccupantIds = <String>{};
    for (final entry in entries) {
      final nick = entry.nick?.trim();
      final realJid = entry.jid;
      final workingRoom = RoomState(
        roomJid: roomJid,
        occupants: updated,
        myOccupantJid: nextMyOccupantJid,
        selfPresenceStatusCodes: selfPresenceStatusCodes,
        selfPresenceReason: selfPresenceReason,
        joinErrorCondition: joinErrorCondition,
        joinErrorText: joinErrorText,
        isDestroyed: isDestroyed,
        destroyedAlternateRoomJid: destroyedAlternateRoomJid,
        postJoinRefreshPending: postJoinRefreshPending,
      );
      final occupantId = workingRoom.occupantIdForAffiliation(
        realJid: realJid,
        nick: nick,
      );
      if (occupantId == null) {
        if ((nick == null || nick.isEmpty) &&
            (realJid == null || realJid.isEmpty)) {
          continue;
        }
        final resolvedOccupantId = realJid == null || realJid.isEmpty
            ? '$roomJid/$nick'
            : workingRoom.syntheticOccupantIdForAffiliationJid(realJid);
        final resolvedNick = (nick == null || nick.isEmpty)
            ? workingRoom.fallbackNickForAffiliationJid(realJid!)
            : nick;
        final isSelf =
            selfRealJid != null &&
            realJid != null &&
            parseJidOrThrow(realJid).toBare().toString() ==
                parseJidOrThrow(selfRealJid).toBare().toString();
        if (isSelf &&
            nextMyOccupantJid != null &&
            nextMyOccupantJid != resolvedOccupantId) {
          updated.remove(nextMyOccupantJid);
        }
        updated[resolvedOccupantId] = Occupant(
          occupantId: resolvedOccupantId,
          nick: resolvedNick,
          realJid: realJid,
          affiliation: entry.affiliation,
          role: entry.role ?? OccupantRole.none,
          isPresent: false,
        );
        if (isSelf) {
          nextMyOccupantJid = resolvedOccupantId;
        }
        retainedOccupantIds.add(resolvedOccupantId);
        continue;
      }
      final occupant = updated[occupantId];
      if (occupant == null) continue;
      updated[occupantId] = occupant.copyWith(
        nick: nick ?? occupant.nick,
        affiliation: entry.affiliation,
        role: entry.role ?? occupant.role,
        realJid: occupant.realJid ?? realJid,
      );
      retainedOccupantIds.add(occupantId);
    }
    updated.removeWhere((occupantId, occupant) {
      if (occupant.affiliation != queriedAffiliation) {
        return false;
      }
      if (occupant.isPresent) {
        return false;
      }
      final realJid = occupant.realJid;
      if (realJid == null || realJid.isEmpty) {
        return false;
      }
      return !retainedOccupantIds.contains(occupantId);
    });
    if (nextMyOccupantJid != null && !updated.containsKey(nextMyOccupantJid)) {
      nextMyOccupantJid = null;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: updated,
      myOccupantJid: nextMyOccupantJid,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: joinErrorCondition,
      joinErrorText: joinErrorText,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withSelfOccupantUnavailable() {
    final occupantJid = myOccupantJid;
    if (occupantJid == null) {
      return this;
    }
    final occupant = occupants[occupantJid];
    if (occupant == null) {
      return this;
    }
    final updatedOccupant = occupant.withUnavailable();
    if (identical(updatedOccupant, occupant)) {
      return this;
    }
    final updated = Map<String, Occupant>.of(occupants)
      ..[occupantJid] = updatedOccupant;
    return copyWith(occupants: updated);
  }

  RoomState withoutOccupants() {
    if (occupants.isEmpty && myOccupantJid == null) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: const <String, Occupant>{},
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: joinErrorCondition,
      joinErrorText: joinErrorText,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withoutOtherOccupantsForRealJid({
    required String keepOccupantId,
    required String realJid,
  }) {
    var changed = false;
    var nextMyOccupantJid = myOccupantJid;
    final updated = Map<String, Occupant>.of(occupants);
    updated.removeWhere((occupantId, occupant) {
      final occupantRealJid = occupant.realJid;
      if (occupantId == keepOccupantId ||
          occupantRealJid == null ||
          !sameBareAddress(occupantRealJid, realJid)) {
        return false;
      }
      if (occupantId == nextMyOccupantJid) {
        nextMyOccupantJid = null;
      }
      changed = true;
      return true;
    });
    if (!changed) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: updated,
      myOccupantJid: nextMyOccupantJid,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: joinErrorCondition,
      joinErrorText: joinErrorText,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withoutPresenceAndJoinState() {
    if (selfPresenceStatusCodes.isEmpty &&
        selfPresenceReason == null &&
        joinErrorCondition == null &&
        joinErrorText == null &&
        !isDestroyed &&
        destroyedAlternateRoomJid == null &&
        !postJoinRefreshPending) {
      return this;
    }
    return RoomState(
      roomJid: roomJid,
      occupants: occupants,
      myOccupantJid: myOccupantJid,
      selfPresenceStatusCodes: const <String>{},
      selfPresenceReason: null,
      isDestroyed: false,
      destroyedAlternateRoomJid: null,
      postJoinRefreshPending: false,
    );
  }

  RoomState withoutOccupant(String occupantId) {
    final resolvedOccupantId = canonicalOccupantId(occupantId);
    if (resolvedOccupantId == null) {
      return this;
    }
    final updated = Map<String, Occupant>.of(occupants)
      ..remove(resolvedOccupantId);
    return RoomState(
      roomJid: roomJid,
      occupants: updated,
      myOccupantJid: myOccupantJid == resolvedOccupantId ? null : myOccupantJid,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: joinErrorCondition,
      joinErrorText: joinErrorText,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

  RoomState withoutExactOccupant(String occupantId) {
    final trimmedOccupantId = occupantId.trim();
    if (trimmedOccupantId.isEmpty ||
        !occupants.containsKey(trimmedOccupantId)) {
      return this;
    }
    final updated = Map<String, Occupant>.of(occupants)
      ..remove(trimmedOccupantId);
    return RoomState(
      roomJid: roomJid,
      occupants: updated,
      myOccupantJid: myOccupantJid == trimmedOccupantId ? null : myOccupantJid,
      selfPresenceStatusCodes: selfPresenceStatusCodes,
      selfPresenceReason: selfPresenceReason,
      joinErrorCondition: joinErrorCondition,
      joinErrorText: joinErrorText,
      isDestroyed: isDestroyed,
      destroyedAlternateRoomJid: destroyedAlternateRoomJid,
      postJoinRefreshPending: postJoinRefreshPending,
    );
  }

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
      switch (occupant.memberSectionKind) {
        case RoomMemberSectionKind.owners:
          owners.add(occupant);
        case RoomMemberSectionKind.admins:
          admins.add(occupant);
        case RoomMemberSectionKind.moderators:
          moderators.add(occupant);
        case RoomMemberSectionKind.members:
          members.add(occupant);
        case RoomMemberSectionKind.participants:
          participants.add(occupant);
        case RoomMemberSectionKind.visitors:
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
      if (preferPresent && occupant.isPresent) {
        if (!preferRealJid || occupant.hasRealJid) {
          return occupant;
        }
        fallback ??= occupant;
        continue;
      }
      if (preferRealJid && occupant.hasRealJid) {
        return occupant;
      }
      fallback ??= occupant;
    }
    return fallback;
  }

  Occupant? occupantForSenderJid(
    String senderJid, {
    bool preferRealJid = false,
  }) {
    final occupantId = canonicalOccupantId(senderJid);
    final direct = occupantId == null ? null : occupants[occupantId];
    if (direct != null && (!preferRealJid || direct.hasRealJid)) {
      return direct;
    }
    final nick = addressResourcePart(senderJid)?.trim();
    if (nick == null || nick.isEmpty) {
      return direct;
    }
    Occupant? fallback = direct;
    for (final occupant in occupants.values) {
      if (!occupant.matchesNick(nick)) {
        continue;
      }
      if (preferRealJid && occupant.hasRealJid) {
        return occupant;
      }
      fallback ??= occupant;
    }
    return fallback;
  }

  String? canonicalOccupantId(String occupantId) {
    final trimmedOccupantId = occupantId.trim();
    if (trimmedOccupantId.isEmpty) {
      return null;
    }
    if (occupants.containsKey(trimmedOccupantId)) {
      return trimmedOccupantId;
    }
    for (final key in occupants.keys) {
      if (sameFullAddress(key, trimmedOccupantId)) {
        return key;
      }
    }
    return null;
  }

  String? occupantIdForAffiliation({String? realJid, String? nick}) {
    final trimmedRealJid = realJid?.trim();
    if (trimmedRealJid != null && trimmedRealJid.isNotEmpty) {
      final byRealJid = occupantForRealJid(trimmedRealJid);
      if (byRealJid != null) {
        return byRealJid.occupantId;
      }
    }
    final trimmedNick = nick?.trim();
    if (trimmedNick != null && trimmedNick.isNotEmpty) {
      final byNick = occupantForNick(
        trimmedNick,
        preferPresent: true,
        preferRealJid: true,
      );
      if (byNick != null) {
        return byNick.occupantId;
      }
    }
    return null;
  }
}
