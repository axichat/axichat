// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

part 'calendar_acl.freezed.dart';
part 'calendar_acl.g.dart';

const int _calendarChatRoleTypeId = 77;
const int _calendarChatRoleVisitorField = 0;
const int _calendarChatRoleParticipantField = 1;
const int _calendarChatRoleModeratorField = 2;
const int _calendarChatRoleNoneField = 3;

const int _calendarChatAclTypeId = 78;
const int _calendarChatAclReadField = 0;
const int _calendarChatAclWriteField = 1;
const int _calendarChatAclManageField = 2;
const int _calendarChatAclDeleteField = 3;

const String _calendarChatRoleVisitorValue = 'visitor';
const String _calendarChatRoleParticipantValue = 'participant';
const String _calendarChatRoleModeratorValue = 'moderator';
const String _calendarChatRoleNoneValue = 'none';
const String _calendarChatRoleVisitorLabel = 'Visitor';
const String _calendarChatRoleParticipantLabel = 'Participant';
const String _calendarChatRoleModeratorLabel = 'Moderator';
const String _calendarChatRoleNoneLabel = 'None';
const int _calendarChatRoleRankNone = 0;
const int _calendarChatRoleRankVisitor = 1;
const int _calendarChatRoleRankParticipant = 2;
const int _calendarChatRoleRankModerator = 3;

const Map<CalendarChatRole, int> _calendarChatRoleRank =
    <CalendarChatRole, int>{
      CalendarChatRole.none: _calendarChatRoleRankNone,
      CalendarChatRole.visitor: _calendarChatRoleRankVisitor,
      CalendarChatRole.participant: _calendarChatRoleRankParticipant,
      CalendarChatRole.moderator: _calendarChatRoleRankModerator,
    };

const CalendarChatAcl _calendarAclForDirectChat = CalendarChatAcl(
  read: CalendarChatRole.participant,
  write: CalendarChatRole.participant,
  manage: CalendarChatRole.participant,
  delete: CalendarChatRole.participant,
);

const CalendarChatAcl _calendarAclForGroupChat = CalendarChatAcl(
  read: CalendarChatRole.visitor,
  write: CalendarChatRole.participant,
  manage: CalendarChatRole.moderator,
  delete: CalendarChatRole.moderator,
);

@HiveType(typeId: _calendarChatRoleTypeId)
enum CalendarChatRole {
  @HiveField(_calendarChatRoleVisitorField)
  visitor,
  @HiveField(_calendarChatRoleParticipantField)
  participant,
  @HiveField(_calendarChatRoleModeratorField)
  moderator,
  @HiveField(_calendarChatRoleNoneField)
  none;

  bool get isVisitor => this == CalendarChatRole.visitor;
  bool get isParticipant => this == CalendarChatRole.participant;
  bool get isModerator => this == CalendarChatRole.moderator;
  bool get isNone => this == CalendarChatRole.none;

  String get mucValue => switch (this) {
    CalendarChatRole.visitor => _calendarChatRoleVisitorValue,
    CalendarChatRole.participant => _calendarChatRoleParticipantValue,
    CalendarChatRole.moderator => _calendarChatRoleModeratorValue,
    CalendarChatRole.none => _calendarChatRoleNoneValue,
  };

  static CalendarChatRole fromMucValue(String? value) => switch (value) {
    _calendarChatRoleVisitorValue => CalendarChatRole.visitor,
    _calendarChatRoleParticipantValue => CalendarChatRole.participant,
    _calendarChatRoleModeratorValue => CalendarChatRole.moderator,
    _ => CalendarChatRole.none,
  };

  int get rank => _calendarChatRoleRank[this]!;

  bool allows(CalendarChatRole required) => rank >= required.rank;
}

extension CalendarChatRoleLabelX on CalendarChatRole {
  String get label => switch (this) {
    CalendarChatRole.visitor => _calendarChatRoleVisitorLabel,
    CalendarChatRole.participant => _calendarChatRoleParticipantLabel,
    CalendarChatRole.moderator => _calendarChatRoleModeratorLabel,
    CalendarChatRole.none => _calendarChatRoleNoneLabel,
  };
}

extension ChatTypeCalendarAclX on ChatType {
  CalendarChatAcl get calendarDefaultAcl => switch (this) {
    ChatType.groupChat => _calendarAclForGroupChat,
    ChatType.chat => _calendarAclForDirectChat,
    ChatType.note => _calendarAclForDirectChat,
  };
}

extension OccupantRoleCalendarChatRoleX on OccupantRole {
  CalendarChatRole get calendarChatRole => switch (this) {
    OccupantRole.moderator => CalendarChatRole.moderator,
    OccupantRole.participant => CalendarChatRole.participant,
    OccupantRole.visitor => CalendarChatRole.visitor,
    OccupantRole.none => CalendarChatRole.none,
  };
}

@freezed
@HiveType(typeId: _calendarChatAclTypeId)
abstract class CalendarChatAcl with _$CalendarChatAcl {
  const factory CalendarChatAcl({
    @HiveField(_calendarChatAclReadField) required CalendarChatRole read,
    @HiveField(_calendarChatAclWriteField) required CalendarChatRole write,
    @HiveField(_calendarChatAclManageField) required CalendarChatRole manage,
    @HiveField(_calendarChatAclDeleteField) required CalendarChatRole delete,
  }) = _CalendarChatAcl;

  factory CalendarChatAcl.fromJson(Map<String, dynamic> json) =>
      _$CalendarChatAclFromJson(json);
}
