// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

class CalendarFragmentShareDecision {
  const CalendarFragmentShareDecision({required this.canWrite});

  final bool canWrite;
}

class CalendarChatSupport {
  const CalendarChatSupport();

  CalendarFragmentShareDecision decisionForChat({
    required Chat? chat,
    RoomState? roomState,
  }) {
    if (chat == null || !chat.supportsChatCalendar) {
      return const CalendarFragmentShareDecision(canWrite: false);
    }
    if (chat.type != ChatType.groupChat) {
      return const CalendarFragmentShareDecision(canWrite: true);
    }
    if (roomState == null) {
      return const CalendarFragmentShareDecision(canWrite: false);
    }
    final CalendarChatRole role = roomState.myRole.calendarChatRole;
    final CalendarChatAcl acl = chat.type.calendarDefaultAcl;
    return CalendarFragmentShareDecision(canWrite: role.allows(acl.write));
  }
}

extension ChatCalendarSupportX on Chat {
  bool get supportsChatCalendar => defaultTransport.isXmpp;
}
