import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

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
    late Map<DateTime, List<int>> scheduledIdsByTime;
    late List<int> cancelledIds;
    late List<DateTime> scheduledTimes;

    setUp(() {
      notificationService = MockNotificationService();
      payloadById = <int, String?>{};
      scheduledIdsByTime = <DateTime, List<int>>{};
      cancelledIds = <int>[];
      scheduledTimes = <DateTime>[];

      when(() => notificationService.init()).thenAnswer((_) async {});
      when(
        () => notificationService.refreshTimeZone(),
      ).thenAnswer((_) async {});
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
        scheduledIdsByTime.putIfAbsent(time, () => <int>[]).add(id);
        scheduledTimes.add(time);
      });
      when(() => notificationService.cancelNotification(any())).thenAnswer((
        invocation,
      ) async {
        cancelledIds.add(invocation.positionalArguments.first as int);
      });
      when(
        () => notificationService.pendingNotificationRequests(),
      ).thenAnswer((_) async => const <PendingNotificationReference>[]);
      when(
        () => notificationService.hasReminderSchedulingPermission(),
      ).thenAnswer((_) async => true);
      when(
        () => notificationService.requestReminderSchedulingPermission(),
      ).thenAnswer(
        (_) async => ReminderSchedulingPermissionRequestResult.granted,
      );
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

      await controller.syncWithTasks(<CalendarTask>[
        meeting.copyWith(isCompleted: true),
      ]);

      final List<String?> cancelledPayloads = <String?>[
        for (final int id in cancelledIds) payloadById[id],
      ];
      expect(
        cancelledPayloads,
        contains('axichat-calendar-reminder-v1:task:${meeting.id}'),
      );
      expect(
        cancelledPayloads,
        contains('axichat-calendar-reminder-v1:task:${demo.id}'),
      );
    });

    test(
      'keeps future reminder ids stable after an earlier reminder fires',
      () async {
        DateTime currentNow = DateTime(2024, 1, 10, 8);
        final CalendarReminderController controller =
            CalendarReminderController(
              notificationService: notificationService,
              now: () => currentNow,
            );
        final CalendarTask task = CalendarTask.create(
          title: 'Planning session',
          scheduledTime: DateTime(2024, 1, 10, 12),
          reminders: _taskReminderPreferences,
        );

        await controller.syncWithTasks(<CalendarTask>[task]);

        final int firedId =
            scheduledIdsByTime[DateTime(2024, 1, 10, 10)]!.single;
        final int futureId =
            scheduledIdsByTime[DateTime(2024, 1, 10, 11)]!.single;
        scheduledTimes.clear();
        scheduledIdsByTime.clear();
        cancelledIds.clear();
        currentNow = DateTime(2024, 1, 10, 10, 30);

        await controller.syncWithTasks(<CalendarTask>[task]);

        expect(cancelledIds, isNot(contains(firedId)));
        expect(
          scheduledIdsByTime[DateTime(2024, 1, 10, 11)],
          contains(futureId),
        );
        expect(scheduledTimes, isNot(contains(DateTime(2024, 1, 10, 10))));
      },
    );

    test(
      'does not sweep untracked pending reminders for completed tasks',
      () async {
        final CalendarReminderController controller =
            CalendarReminderController(
              notificationService: notificationService,
              now: () => DateTime(2024, 5, 1, 9),
            );
        final CalendarTask task = CalendarTask.create(
          title: 'Team sync',
          scheduledTime: DateTime(2024, 5, 2, 12),
          reminders: _taskReminderPreferences,
        );
        when(
          () => notificationService.pendingNotificationRequests(),
        ).thenAnswer(
          (_) async => <PendingNotificationReference>[
            PendingNotificationReference(
              id: 42,
              payload: 'axichat-calendar-reminder-v1:task:${task.id}',
            ),
            const PendingNotificationReference(
              id: 99,
              payload: 'axichat-chat-v1:message',
            ),
          ],
        );

        await controller.syncWithTasks(<CalendarTask>[
          task.copyWith(isCompleted: true),
        ]);

        expect(cancelledIds, isEmpty);
        expect(cancelledIds, isNot(contains(99)));
        verifyNever(() => notificationService.pendingNotificationRequests());
      },
    );

    test(
      'does not sweep stale prefixed pending reminders for removed tasks',
      () async {
        final CalendarReminderController controller =
            CalendarReminderController(
              notificationService: notificationService,
              now: () => DateTime(2024, 5, 1, 9),
            );
        when(
          () => notificationService.pendingNotificationRequests(),
        ).thenAnswer(
          (_) async => const <PendingNotificationReference>[
            PendingNotificationReference(
              id: 42,
              payload: 'axichat-calendar-reminder-v1:task:deleted-task',
            ),
            PendingNotificationReference(
              id: 99,
              payload: 'axichat-chat-v1:message',
            ),
          ],
        );

        await controller.syncWithTasks(const <CalendarTask>[]);

        expect(cancelledIds, isEmpty);
        expect(cancelledIds, isNot(contains(99)));
        verifyNever(() => notificationService.pendingNotificationRequests());
      },
    );

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
        kickoff.copyWith(scheduledTime: DateTime(2024, 6, 3, 9)),
      ]);

      verify(() => notificationService.refreshTimeZone()).called(2);
    });

    test(
      'requests exact alarm access once when future reminders exist and permission is missing',
      () async {
        final CalendarReminderController controller =
            CalendarReminderController(
              notificationService: notificationService,
              now: () => DateTime(2024, 1, 10, 8),
            );
        final CalendarTask task = CalendarTask.create(
          title: 'Planning session',
          scheduledTime: DateTime(2024, 1, 10, 12),
          reminders: _taskReminderPreferences,
        );

        when(
          () => notificationService.hasReminderSchedulingPermission(),
        ).thenAnswer((_) async => false);
        when(
          () => notificationService.requestReminderSchedulingPermission(),
        ).thenAnswer(
          (_) async => ReminderSchedulingPermissionRequestResult.denied,
        );

        await controller.syncWithTasks(<CalendarTask>[task]);
        await controller.syncWithTasks(<CalendarTask>[task]);

        verify(
          () => notificationService.requestReminderSchedulingPermission(),
        ).called(1);
      },
    );

    test(
      'retries exact alarm access after a transient request failure',
      () async {
        final CalendarReminderController controller =
            CalendarReminderController(
              notificationService: notificationService,
              now: () => DateTime(2024, 1, 10, 8),
            );
        final CalendarTask task = CalendarTask.create(
          title: 'Planning session',
          scheduledTime: DateTime(2024, 1, 10, 12),
          reminders: _taskReminderPreferences,
        );
        var requestCount = 0;

        when(
          () => notificationService.hasReminderSchedulingPermission(),
        ).thenAnswer((_) async => false);
        when(
          () => notificationService.requestReminderSchedulingPermission(),
        ).thenAnswer((_) async {
          requestCount += 1;
          return requestCount == 1
              ? ReminderSchedulingPermissionRequestResult.failed
              : ReminderSchedulingPermissionRequestResult.denied;
        });

        await controller.syncWithTasks(<CalendarTask>[task]);
        await controller.syncWithTasks(<CalendarTask>[task]);

        verify(
          () => notificationService.requestReminderSchedulingPermission(),
        ).called(2);
      },
    );

    test(
      'recomputes reminder times after exact alarm permission flow returns',
      () async {
        DateTime currentNow = DateTime(2024, 1, 10, 8);
        final CalendarReminderController controller =
            CalendarReminderController(
              notificationService: notificationService,
              now: () => currentNow,
            );
        final CalendarTask task = CalendarTask.create(
          title: 'Planning session',
          scheduledTime: DateTime(2024, 1, 10, 12),
          reminders: _taskReminderPreferences,
        );

        when(
          () => notificationService.hasReminderSchedulingPermission(),
        ).thenAnswer((_) async => false);
        when(
          () => notificationService.requestReminderSchedulingPermission(),
        ).thenAnswer((_) async {
          currentNow = DateTime(2024, 1, 10, 11, 31);
          return ReminderSchedulingPermissionRequestResult.granted;
        });

        await controller.syncWithTasks(<CalendarTask>[task]);

        expect(
          scheduledTimes,
          containsAll(<DateTime>[
            DateTime(2024, 1, 10, 11, 45),
            DateTime(2024, 1, 10, 12),
          ]),
        );
        expect(scheduledTimes, isNot(contains(DateTime(2024, 1, 10, 10))));
        expect(scheduledTimes, isNot(contains(DateTime(2024, 1, 10, 11))));
        expect(scheduledTimes, isNot(contains(DateTime(2024, 1, 10, 11, 30))));
      },
    );
  });
}
