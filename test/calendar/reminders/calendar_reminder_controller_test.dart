import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockNotificationService extends Mock implements NotificationService {}

const Duration _taskLeadTwoHours = Duration(hours: 2);
const Duration _taskLeadOneHour = Duration(hours: 1);
const Duration _taskLeadThirtyMinutes = Duration(minutes: 30);
const Duration _taskLeadFifteenMinutes = Duration(minutes: 15);
const Duration _taskLeadNow = Duration.zero;

const List<Duration> _taskStartOffsets = <Duration>[
  _taskLeadTwoHours,
  _taskLeadOneHour,
  _taskLeadThirtyMinutes,
  _taskLeadFifteenMinutes,
  _taskLeadNow,
];

const List<Duration> _taskDeadlineOffsets = <Duration>[
  _taskLeadOneHour,
  _taskLeadThirtyMinutes,
  _taskLeadFifteenMinutes,
  _taskLeadNow,
];

const ReminderPreferences _taskReminderPreferences = ReminderPreferences(
  enabled: true,
  startOffsets: _taskStartOffsets,
  deadlineOffsets: _taskDeadlineOffsets,
);

const List<Duration> _dayEventOffsets = <Duration>[
  _taskLeadOneHour,
  _taskLeadThirtyMinutes,
  _taskLeadFifteenMinutes,
  _taskLeadNow,
];

const ReminderPreferences _dayEventReminderPreferences = ReminderPreferences(
  enabled: true,
  startOffsets: _dayEventOffsets,
);

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2024));
    registerFallbackValue('');
    registerFallbackValue(0);
  });

  group('CalendarReminderController', () {
    late MockNotificationService notificationService;
    late Map<int, String?> payloadById;
    late List<DateTime> scheduledTimes;

    setUp(() {
      notificationService = MockNotificationService();
      payloadById = <int, String?>{};
      scheduledTimes = <DateTime>[];

      when(() => notificationService.init()).thenAnswer((_) async {});
      when(() => notificationService.refreshTimeZone())
          .thenAnswer((_) async {});
      when(
        () => notificationService.scheduleNotification(
          id: any(named: 'id'),
          scheduledAt: any(named: 'scheduledAt'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((invocation) async {
        final int id = invocation.namedArguments[#id] as int;
        final DateTime time =
            invocation.namedArguments[#scheduledAt] as DateTime;
        final String? payload = invocation.namedArguments[#payload] as String?;
        payloadById[id] = payload;
        scheduledTimes.add(time);
      });
      when(() => notificationService.cancelNotification(any()))
          .thenAnswer((_) async {});
    });

    test('schedules start and deadline reminders for tasks', () async {
      final CalendarReminderController controller = CalendarReminderController(
        notificationService: notificationService,
        now: () => DateTime(2024, 1, 10, 8),
      );

      final CalendarTask task = CalendarTask.create(
        title: 'Planning session',
        scheduledTime: DateTime(2024, 1, 10, 12),
        duration: const Duration(hours: 1),
        deadline: DateTime(2024, 1, 11, 10),
        reminders: _taskReminderPreferences,
      );

      await controller.syncWithTasks(<CalendarTask>[task]);

      expect(scheduledTimes, hasLength(9));
      expect(
        scheduledTimes,
        containsAll(<DateTime>[
          DateTime(2024, 1, 10, 11),
          DateTime(2024, 1, 10, 11, 30),
          DateTime(2024, 1, 10, 11, 45),
          DateTime(2024, 1, 10, 12),
          DateTime(2024, 1, 10, 10),
          DateTime(2024, 1, 11, 9),
          DateTime(2024, 1, 11, 9, 30),
          DateTime(2024, 1, 11, 9, 45),
          DateTime(2024, 1, 11, 10),
        ]),
      );
    });

    test('cancels reminders when tasks are removed or completed', () async {
      final CalendarReminderController controller = CalendarReminderController(
        notificationService: notificationService,
        now: () => DateTime(2024, 5, 1, 9),
      );

      final CalendarTask meeting = CalendarTask.create(
        title: 'Team sync',
        scheduledTime: DateTime(2024, 5, 2, 12),
        reminders: _taskReminderPreferences,
      );
      final CalendarTask demo = CalendarTask.create(
        title: 'Demo',
        scheduledTime: DateTime(2024, 5, 3, 15),
        reminders: _taskReminderPreferences,
      );

      await controller.syncWithTasks(<CalendarTask>[meeting, demo]);

      final List<String?> cancelledPayloads = <String?>[];
      when(() => notificationService.cancelNotification(any()))
          .thenAnswer((invocation) async {
        final int id = invocation.positionalArguments.first as int;
        cancelledPayloads.add(payloadById[id]);
      });

      await controller.syncWithTasks(<CalendarTask>[
        meeting.copyWith(isCompleted: true),
      ]);

      expect(cancelledPayloads, contains(meeting.id));
      expect(cancelledPayloads, contains(demo.id));
    });

    test('schedules day-event reminders respecting offsets', () async {
      final CalendarReminderController controller = CalendarReminderController(
        notificationService: notificationService,
        now: () => DateTime(2024, 9, 1, 8),
      );

      final DayEvent holiday = DayEvent.create(
        title: 'Holiday',
        startDate: DateTime(2024, 9, 5),
        reminders: _dayEventReminderPreferences,
      );

      await controller.syncWithTasks(
        const <CalendarTask>[],
        dayEvents: <DayEvent>[holiday],
      );

      expect(
        scheduledTimes,
        containsAll(<DateTime>[
          DateTime(2024, 9, 4, 23),
          DateTime(2024, 9, 4, 23, 30),
          DateTime(2024, 9, 4, 23, 45),
          DateTime(2024, 9, 5, 0),
        ]),
      );
    });

    test('sync refreshes timezone data on subsequent runs', () async {
      final CalendarReminderController controller = CalendarReminderController(
        notificationService: notificationService,
        now: () => DateTime(2024, 6, 1, 8),
      );

      final CalendarTask kickoff = CalendarTask.create(
        title: 'Kickoff',
        scheduledTime: DateTime(2024, 6, 2, 9),
      );

      await controller.syncWithTasks(<CalendarTask>[kickoff]);
      await controller.syncWithTasks(<CalendarTask>[
        kickoff.copyWith(
          scheduledTime: DateTime(2024, 6, 3, 9),
        )
      ]);

      verify(() => notificationService.refreshTimeZone()).called(2);
    });
  });
}
