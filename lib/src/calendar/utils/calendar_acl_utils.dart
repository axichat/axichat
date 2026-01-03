// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

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

extension ChatTypeCalendarAclX on ChatType {
  CalendarChatAcl get calendarDefaultAcl => switch (this) {
        ChatType.groupChat => _calendarAclForGroupChat,
        ChatType.chat => _calendarAclForDirectChat,
        ChatType.note => _calendarAclForDirectChat,
      };
}

extension CalendarChatRoleAccessX on CalendarChatRole {
  int get rank => _calendarChatRoleRank[this]!;

  bool allows(CalendarChatRole required) => rank >= required.rank;
}

extension OccupantRoleCalendarChatRoleX on OccupantRole {
  CalendarChatRole get calendarChatRole => switch (this) {
        OccupantRole.moderator => CalendarChatRole.moderator,
        OccupantRole.participant => CalendarChatRole.participant,
        OccupantRole.visitor => CalendarChatRole.visitor,
        OccupantRole.none => CalendarChatRole.none,
      };
}
