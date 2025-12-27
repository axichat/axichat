import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

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
