import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:test/test.dart';

final DateTime _lastChangeTimestamp = DateTime(2024, 1, 1);
final DateTime _taskStart = DateTime(2024, 1, 2, 9);
final DateTime _availabilityStart = DateTime(2024, 1, 3, 10);
final DateTime _availabilityEnd = DateTime(2024, 1, 3, 11);
const Duration _taskDuration = Duration(hours: 1);
const Duration _reminderOffset = Duration(minutes: 30);
const String _axiJid = 'user@axi.im';
const String _roomJid = 'room@conference.axi.im';
const String _occupantId = 'me';
const String _occupantNick = 'Me';
const String _availabilityOwner = 'owner@axi.im';
const String _taskTitle = 'Team sync';
const String _taskDescription = 'Agenda';
const String _taskLocation = 'Room A';
const String _checklistId = 'check-1';
const String _checklistLabel = 'Prep';
const String _redactedTaskTitle = 'Private task';

Chat createChat({
  ChatType type = ChatType.chat,
  String jid = _axiJid,
}) {
  return Chat(
    jid: jid,
    title: jid,
    type: type,
    lastChangeTimestamp: _lastChangeTimestamp,
  );
}

RoomState createRoomState(OccupantRole role) {
  final occupant = Occupant(
    occupantId: _occupantId,
    nick: _occupantNick,
    role: role,
  );
  return RoomState(
    roomJid: _roomJid,
    occupants: <String, Occupant>{_occupantId: occupant},
    myOccupantId: _occupantId,
  );
}

CalendarTask createTask() {
  return CalendarTask.create(
    title: _taskTitle,
    description: _taskDescription,
    scheduledTime: _taskStart,
    duration: _taskDuration,
    location: _taskLocation,
    reminders: const ReminderPreferences(
      enabled: true,
      startOffsets: <Duration>[_reminderOffset],
      deadlineOffsets: <Duration>[],
    ),
    checklist: const <TaskChecklistItem>[
      TaskChecklistItem(id: _checklistId, label: _checklistLabel),
    ],
  );
}

CalendarAvailabilityOverlay createAvailabilityOverlay() {
  return CalendarAvailabilityOverlay(
    owner: _availabilityOwner,
    rangeStart: CalendarDateTime(value: _availabilityStart),
    rangeEnd: CalendarDateTime(value: _availabilityEnd),
    isRedacted: false,
  );
}

void main() {
  group('CalendarFragmentPolicy', () {
    test('uses full visibility for direct chats', () {
      const policy = CalendarFragmentPolicy();
      final decision = policy.decisionForChat(chat: createChat());

      expect(decision.canWrite, isTrue);
      expect(decision.visibility, CalendarFragmentVisibility.full);
    });

    test('redacts visibility for group participants', () {
      const policy = CalendarFragmentPolicy();
      final decision = policy.decisionForChat(
        chat: createChat(type: ChatType.groupChat),
        roomState: createRoomState(OccupantRole.participant),
      );

      expect(decision.canWrite, isTrue);
      expect(decision.visibility, CalendarFragmentVisibility.redacted);
    });

    test('redacts task details when visibility is redacted', () {
      const policy = CalendarFragmentPolicy();
      final fragment = CalendarFragment.task(task: createTask());
      final redacted = policy.redactFragment(
        fragment,
        CalendarFragmentVisibility.redacted,
      );
      final CalendarTaskFragment redactedTaskFragment =
          redacted as CalendarTaskFragment;

      expect(redactedTaskFragment.task.title, equals(_redactedTaskTitle));
      expect(redactedTaskFragment.task.description, isNull);
      expect(redactedTaskFragment.task.location, isNull);
      expect(redactedTaskFragment.task.recurrence, isNull);
      expect(redactedTaskFragment.task.reminders?.isEnabled, isFalse);
      expect(redactedTaskFragment.task.checklist, isEmpty);
      expect(redactedTaskFragment.task.icsMeta, isNull);
    });

    test('marks overlays as redacted when visibility is redacted', () {
      const policy = CalendarFragmentPolicy();
      final overlay = createAvailabilityOverlay();
      final redacted = policy.redactOverlay(
        overlay,
        CalendarFragmentVisibility.redacted,
      );

      expect(redacted.isRedacted, isTrue);
    });
  });
}
