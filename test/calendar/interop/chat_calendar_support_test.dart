import 'package:axichat/src/calendar/interop/chat_calendar_support.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _lastChangeTimestamp = DateTime(2024, 1, 1);
const String _axiJid = 'user@axi.im';
const String _emailJid = 'user@example.com';
const String _roomJid = 'room@conference.axi.im';
const String _occupantId = 'me';
const String _occupantNick = 'Me';

Chat createChat({ChatType type = ChatType.chat, String jid = _axiJid}) {
  return Chat(
    jid: jid,
    title: jid,
    type: type,
    lastChangeTimestamp: _lastChangeTimestamp,
  );
}

RoomState createRoomState({
  required OccupantAffiliation affiliation,
  OccupantRole role = OccupantRole.participant,
}) {
  final occupant = Occupant(
    occupantId: _occupantId,
    nick: _occupantNick,
    affiliation: affiliation,
    role: role,
  );
  return RoomState(
    roomJid: _roomJid,
    occupants: <String, Occupant>{_occupantId: occupant},
    myOccupantJid: _occupantId,
  );
}

void main() {
  group('CalendarChatSupport', () {
    test('allows direct XMPP chats', () {
      const policy = CalendarChatSupport();
      final decision = policy.decisionForChat(chat: createChat());

      expect(decision.canWrite, isTrue);
    });

    test('blocks email-only chats', () {
      const policy = CalendarChatSupport();
      final decision = policy.decisionForChat(chat: createChat(jid: _emailJid));

      expect(decision.canWrite, isFalse);
    });

    test('allows group members', () {
      const policy = CalendarChatSupport();
      final decision = policy.decisionForChat(
        chat: createChat(type: ChatType.groupChat, jid: _roomJid),
        roomState: createRoomState(affiliation: OccupantAffiliation.member),
      );

      expect(decision.canWrite, isTrue);
    });

    test('blocks group visitors', () {
      const policy = CalendarChatSupport();
      final decision = policy.decisionForChat(
        chat: createChat(type: ChatType.groupChat, jid: _roomJid),
        roomState: createRoomState(
          affiliation: OccupantAffiliation.none,
          role: OccupantRole.visitor,
        ),
      );

      expect(decision.canWrite, isFalse);
    });
  });
}
