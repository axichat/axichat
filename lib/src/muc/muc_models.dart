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
  }) =>
      Occupant(
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
  }) : occupants = Map.unmodifiable(occupants ?? <String, Occupant>{});

  final String roomJid;
  final Map<String, Occupant> occupants;
  final String? myOccupantId;

  OccupantAffiliation get myAffiliation =>
      occupants[myOccupantId]?.affiliation ?? OccupantAffiliation.none;

  OccupantRole get myRole {
    final role = occupants[myOccupantId]?.role;
    if (role == null || role.isNone) return OccupantRole.participant;
    return role;
  }

  List<Occupant> get owners => _sortedByNick(
        occupants.values
            .where((occupant) => occupant.affiliation.isOwner)
            .toList(),
      );

  List<Occupant> get admins => _sortedByNick(
        occupants.values
            .where((occupant) => occupant.affiliation.isAdmin)
            .toList(),
      );

  List<Occupant> get moderators => _sortedByNick(
        occupants.values
            .where((occupant) => occupant.role.isModerator)
            .toList(),
      );

  List<Occupant> get members => _sortedByNick(
        occupants.values
            .where((occupant) => occupant.affiliation.isMember)
            .toList(),
      );

  List<Occupant> get visitors => _sortedByNick(
        occupants.values
            .where((occupant) => occupant.affiliation.isNone)
            .toList(),
      );

  List<Occupant> _sortedByNick(List<Occupant> items) => items
    ..sort(
      (a, b) => a.nick.toLowerCase().compareTo(b.nick.toLowerCase()),
    );

  RoomState copyWith({
    Map<String, Occupant>? occupants,
    String? myOccupantId,
  }) =>
      RoomState(
        roomJid: roomJid,
        occupants: occupants ?? this.occupants,
        myOccupantId: myOccupantId ?? this.myOccupantId,
      );
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
