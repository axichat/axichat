import 'dart:convert';

import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarTask', () {
    final testTime = DateTime(2024, 1, 15, 10, 30);

    group('factory CalendarTask.create', () {
      test('creates task with required fields', () {
        final task = CalendarTask.create(
          title: 'Test Task',
        );

        expect(task.title, equals('Test Task'));
        expect(task.id, isNotEmpty);
        expect(task.isCompleted, isFalse);
        expect(task.createdAt, isNotNull);
        expect(task.modifiedAt, equals(task.createdAt));
        expect(task.description, isNull);
        expect(task.scheduledTime, isNull);
        expect(task.duration, isNull);
      });

      test('creates task with all optional fields', () {
        const duration = Duration(hours: 1, minutes: 30);
        final task = CalendarTask.create(
          title: 'Meeting',
          description: 'Team standup',
          scheduledTime: testTime,
          duration: duration,
        );

        expect(task.title, equals('Meeting'));
        expect(task.description, equals('Team standup'));
        expect(task.scheduledTime, equals(testTime));
        expect(task.duration, equals(duration));
      });

      test('generates unique IDs for different tasks', () {
        final task1 = CalendarTask.create(title: 'Task 1');
        final task2 = CalendarTask.create(title: 'Task 2');

        expect(task1.id, isNot(equals(task2.id)));
      });
    });

    group('JSON serialization', () {
      late CalendarTask task;

      setUp(() {
        task = CalendarTask(
          id: 'test-id-123',
          title: 'Test Task',
          description: 'Task description',
          scheduledTime: testTime,
          duration: const Duration(hours: 2),
          isCompleted: true,
          createdAt: testTime,
          modifiedAt: testTime.add(const Duration(minutes: 5)),
        );
      });

      test('toJson produces valid JSON', () {
        final json = task.toJson();

        expect(json['id'], equals('test-id-123'));
        expect(json['title'], equals('Test Task'));
        expect(json['description'], equals('Task description'));
        expect(json['is_completed'], isTrue);
        expect(json['scheduled_time'], isNotNull);
        expect(json['duration'], equals(7200000000)); // 2 hours in microseconds
      });

      test('includes reminder preferences in serialization', () {
        final CalendarTask withReminders = task.copyWith(
          reminders: const ReminderPreferences(
            enabled: true,
            startOffsets: <Duration>[Duration(hours: 1)],
            deadlineOffsets: <Duration>[Duration(hours: 4)],
          ),
        );

        final Map<String, dynamic> json = withReminders.toJson();
        final CalendarTask restored = CalendarTask.fromJson(json);

        expect(restored.reminders?.enabled, isTrue);
        expect(
          restored.effectiveReminders.startOffsets,
          contains(const Duration(hours: 1)),
        );
        expect(
          restored.effectiveReminders.deadlineOffsets,
          contains(const Duration(hours: 4)),
        );
      });

      test('fromJson reconstructs task correctly', () {
        final json = task.toJson();
        final reconstructed = CalendarTask.fromJson(json);

        expect(reconstructed, equals(task));
      });

      test('handles null values correctly', () {
        final taskWithNulls = CalendarTask(
          id: 'test-id',
          title: 'Simple Task',
          createdAt: testTime,
          modifiedAt: testTime,
        );

        final json = taskWithNulls.toJson();
        final reconstructed = CalendarTask.fromJson(json);

        expect(reconstructed.description, isNull);
        expect(reconstructed.scheduledTime, isNull);
        expect(reconstructed.duration, isNull);
        expect(reconstructed.isCompleted, isFalse);
      });

      test('roundtrip serialization maintains data integrity', () {
        final jsonString = jsonEncode(task.toJson());
        final parsedJson = jsonDecode(jsonString) as Map<String, dynamic>;
        final reconstructed = CalendarTask.fromJson(parsedJson);

        expect(reconstructed.id, equals(task.id));
        expect(reconstructed.title, equals(task.title));
        expect(reconstructed.description, equals(task.description));
        expect(reconstructed.isCompleted, equals(task.isCompleted));
        expect(reconstructed.scheduledTime, equals(task.scheduledTime));
        expect(reconstructed.duration, equals(task.duration));
      });
    });

    group('copyWith', () {
      late CalendarTask originalTask;

      setUp(() {
        originalTask = CalendarTask.create(
          title: 'Original Task',
          description: 'Original description',
        );
      });

      test('creates copy with updated title', () {
        final updated = originalTask.copyWith(title: 'Updated Task');

        expect(updated.title, equals('Updated Task'));
        expect(updated.id, equals(originalTask.id));
        expect(updated.description, equals(originalTask.description));
      });

      test('creates copy with completion status changed', () {
        final completed = originalTask.copyWith(isCompleted: true);

        expect(completed.isCompleted, isTrue);
        expect(completed.id, equals(originalTask.id));
        expect(completed.title, equals(originalTask.title));
      });

      test('creates copy with null values', () {
        final taskWithSchedule = originalTask.copyWith(
          scheduledTime: testTime,
          description: 'Has schedule',
        );

        final clearedSchedule = taskWithSchedule.copyWith(
          scheduledTime: null,
          description: null,
        );

        expect(clearedSchedule.scheduledTime, isNull);
        expect(clearedSchedule.description, isNull);
        expect(clearedSchedule.title, equals(originalTask.title));
      });
    });

    group('validation', () {
      test('accepts valid task data', () {
        expect(
          () => CalendarTask(
            id: 'valid-id',
            title: 'Valid Title',
            createdAt: testTime,
            modifiedAt: testTime,
          ),
          returnsNormally,
        );
      });

      test('accepts empty title', () {
        // Note: Based on the model, empty titles are technically allowed
        // but should be validated at the BLoC/UI layer
        expect(
          () => CalendarTask(
            id: 'test-id',
            title: '',
            createdAt: testTime,
            modifiedAt: testTime,
          ),
          returnsNormally,
        );
      });
    });

    group('occurrencesWithin', () {
      test('generates weekly occurrences only for selected weekdays', () {
        final task = CalendarTask.create(
          title: 'Class',
          scheduledTime: DateTime(2024, 1, 3, 9), // Wednesday
          duration: const Duration(hours: 1),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            byWeekdays: [DateTime.wednesday, DateTime.friday],
          ),
        );

        final occurrences = task.occurrencesWithin(
          DateTime(2024, 1, 1),
          DateTime(2024, 1, 12),
        );

        final weekdays = occurrences
            .map((occurrence) => occurrence.scheduledTime!.weekday)
            .toList();

        expect(weekdays, equals([DateTime.friday, DateTime.wednesday]));
        expect(
          weekdays.every((weekday) => weekday != DateTime.thursday),
          isTrue,
        );
      });

      test('expands yearly rules with month and weekday filters', () {
        const String title = 'Yearly review';
        const int baseYear = 2024;
        const int baseMonth = 2;
        const int baseDay = 12;
        const int baseHour = 9;
        const int taskDurationHours = 1;
        const Duration taskDuration = Duration(hours: taskDurationHours);
        const int rangeStartDay = 1;
        const int rangeEndDay = 28;
        const int rangeEndHour = 23;
        const int rangeEndMinute = 59;
        const int rangeEndSecond = 59;
        const int firstExpectedDay = 19;
        const int secondExpectedDay = 26;
        const RecurrenceRule recurrence = RecurrenceRule(
          frequency: RecurrenceFrequency.yearly,
          byMonths: <int>[baseMonth],
          byDays: <RecurrenceWeekday>[
            RecurrenceWeekday(weekday: CalendarWeekday.monday),
          ],
        );

        final DateTime baseStart = DateTime(
          baseYear,
          baseMonth,
          baseDay,
          baseHour,
        );
        final DateTime rangeStart = DateTime(
          baseYear,
          baseMonth,
          rangeStartDay,
        );
        final DateTime rangeEnd = DateTime(
          baseYear,
          baseMonth,
          rangeEndDay,
          rangeEndHour,
          rangeEndMinute,
          rangeEndSecond,
        );
        final CalendarTask task = CalendarTask.create(
          title: title,
          scheduledTime: baseStart,
          duration: taskDuration,
          recurrence: recurrence,
        );

        final occurrences = task.occurrencesWithin(rangeStart, rangeEnd);
        final List<DateTime?> occurrenceTimes =
            occurrences.map((occurrence) => occurrence.scheduledTime).toList();

        final DateTime firstExpected = DateTime(
          baseYear,
          baseMonth,
          firstExpectedDay,
          baseHour,
        );
        final DateTime secondExpected = DateTime(
          baseYear,
          baseMonth,
          secondExpectedDay,
          baseHour,
        );

        expect(occurrenceTimes, equals([firstExpected, secondExpected]));
      });

      test('expands yearly rules with weekday positions', () {
        const String title = 'First Tuesday';
        const int baseYear = 2024;
        const int baseMonth = 4;
        const int baseDay = 2;
        const int baseHour = 8;
        const int taskDurationHours = 1;
        const Duration taskDuration = Duration(hours: taskDurationHours);
        const int rangeYear = 2025;
        const int rangeMonth = baseMonth;
        const int rangeStartDay = 1;
        const int rangeEndDay = 30;
        const int rangeEndHour = 23;
        const int rangeEndMinute = 59;
        const int rangeEndSecond = 59;
        const int firstPosition = 1;
        const RecurrenceRule recurrence = RecurrenceRule(
          frequency: RecurrenceFrequency.yearly,
          byMonths: <int>[baseMonth],
          byDays: <RecurrenceWeekday>[
            RecurrenceWeekday(
              weekday: CalendarWeekday.tuesday,
              position: firstPosition,
            ),
          ],
        );

        final DateTime baseStart = DateTime(
          baseYear,
          baseMonth,
          baseDay,
          baseHour,
        );
        final DateTime rangeStart = DateTime(
          rangeYear,
          rangeMonth,
          rangeStartDay,
        );
        final DateTime rangeEnd = DateTime(
          rangeYear,
          rangeMonth,
          rangeEndDay,
          rangeEndHour,
          rangeEndMinute,
          rangeEndSecond,
        );
        final CalendarTask task = CalendarTask.create(
          title: title,
          scheduledTime: baseStart,
          duration: taskDuration,
          recurrence: recurrence,
        );

        final occurrences = task.occurrencesWithin(rangeStart, rangeEnd);
        const int expectedOccurrences = 1;

        expect(occurrences, hasLength(expectedOccurrences));
        expect(
          occurrences.first.scheduledTime,
          DateTime(rangeYear, rangeMonth, rangeStartDay, baseHour),
        );
      });

      test('honors yearly count limits before the range start', () {
        const String title = 'New year';
        const int baseYear = 2020;
        const int baseMonth = 1;
        const int baseDay = 1;
        const int baseHour = 9;
        const int taskDurationHours = 1;
        const Duration taskDuration = Duration(hours: taskDurationHours);
        const int occurrenceCount = 2;
        const int rangeStartYear = baseYear + 2;
        const int rangeEndYear = baseYear + 3;
        const RecurrenceRule recurrence = RecurrenceRule(
          frequency: RecurrenceFrequency.yearly,
          count: occurrenceCount,
          byMonths: <int>[baseMonth],
          byMonthDays: <int>[baseDay],
        );

        final DateTime baseStart = DateTime(
          baseYear,
          baseMonth,
          baseDay,
          baseHour,
        );
        final DateTime rangeStart = DateTime(
          rangeStartYear,
          baseMonth,
          baseDay,
        );
        final DateTime rangeEnd = DateTime(
          rangeEndYear,
          baseMonth,
          baseDay,
        );
        final CalendarTask task = CalendarTask.create(
          title: title,
          scheduledTime: baseStart,
          duration: taskDuration,
          recurrence: recurrence,
        );

        final occurrences = task.occurrencesWithin(rangeStart, rangeEnd);

        expect(occurrences, isEmpty);
      });

      test('applies overrides for individual occurrences', () {
        final baseTask = CalendarTask.create(
          title: 'Shift',
          scheduledTime: DateTime(2024, 1, 1, 9), // Monday
          duration: const Duration(hours: 1),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            byWeekdays: [DateTime.tuesday],
          ),
        );

        final originalOccurrence = DateTime(2024, 1, 2, 9);
        final overrideKey =
            originalOccurrence.microsecondsSinceEpoch.toString();
        final withOverride = baseTask.copyWith(
          occurrenceOverrides: {
            overrideKey: TaskOccurrenceOverride(
              scheduledTime: DateTime(2024, 1, 3, 11),
              duration: const Duration(hours: 2),
            ),
          },
        );

        final occurrences = withOverride.occurrencesWithin(
          DateTime(2024, 1, 1),
          DateTime(2024, 1, 5),
        );

        expect(occurrences, hasLength(1));
        final occurrence = occurrences.first;
        expect(occurrence.scheduledTime, DateTime(2024, 1, 3, 11));
        expect(occurrence.duration, const Duration(hours: 2));
      });

      test('omits cancelled occurrences', () {
        final baseTask = CalendarTask.create(
          title: 'Gym',
          scheduledTime: DateTime(2024, 1, 1, 7),
          duration: const Duration(hours: 1),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            byWeekdays: [DateTime.tuesday],
          ),
        );

        final originalOccurrence = DateTime(2024, 1, 2, 7);
        final overrideKey =
            originalOccurrence.microsecondsSinceEpoch.toString();
        final cancelled = baseTask.copyWith(
          occurrenceOverrides: {
            overrideKey: const TaskOccurrenceOverride(isCancelled: true),
          },
        );

        final occurrences = cancelled.occurrencesWithin(
          DateTime(2024, 1, 1),
          DateTime(2024, 1, 3),
        );

        expect(occurrences, isEmpty);
      });

      test(
        'includes shifted future occurrences when range override moves series earlier',
        () {
          const int baseYear = 2024;
          const int baseMonth = 3;
          const int baseDay = 20;
          const int overrideDay = 1;
          const int expectedDay = 8;
          const int baseHour = 9;
          const int baseMinute = 0;
          const int baseSecond = 0;
          const int rangeStartDay = 1;
          const int rangeEndDay = 10;
          const int rangeStartHour = 0;
          const int rangeStartMinute = 0;
          const int rangeStartSecond = 0;
          const int rangeEndHour = 23;
          const int rangeEndMinute = 59;
          const int rangeEndSecond = 59;
          const bool isAllDay = false;
          const bool isFloating = false;
          const Duration baseDuration = Duration(hours: 1);
          const RecurrenceRule weeklyRule = RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
          );
          const String taskTitle = 'Shifted series';

          final DateTime seriesStart = DateTime(
            baseYear,
            baseMonth,
            baseDay,
            baseHour,
            baseMinute,
            baseSecond,
          );
          final DateTime overrideStart = DateTime(
            baseYear,
            baseMonth,
            overrideDay,
            baseHour,
            baseMinute,
            baseSecond,
          );
          final DateTime rangeStart = DateTime(
            baseYear,
            baseMonth,
            rangeStartDay,
            rangeStartHour,
            rangeStartMinute,
            rangeStartSecond,
          );
          final DateTime rangeEnd = DateTime(
            baseYear,
            baseMonth,
            rangeEndDay,
            rangeEndHour,
            rangeEndMinute,
            rangeEndSecond,
          );
          final DateTime expectedOccurrence = DateTime(
            baseYear,
            baseMonth,
            expectedDay,
            baseHour,
            baseMinute,
            baseSecond,
          );
          final CalendarDateTime recurrenceId = CalendarDateTime(
            value: seriesStart,
            tzid: null,
            isAllDay: isAllDay,
            isFloating: isFloating,
          );
          final TaskOccurrenceOverride rangeOverride = TaskOccurrenceOverride(
            scheduledTime: overrideStart,
            recurrenceId: recurrenceId,
            range: RecurrenceRange.thisAndFuture,
          );
          final String overrideKey =
              seriesStart.microsecondsSinceEpoch.toString();
          final CalendarTask task = CalendarTask.create(
            title: taskTitle,
            scheduledTime: seriesStart,
            duration: baseDuration,
            recurrence: weeklyRule,
          ).copyWith(
            occurrenceOverrides: <String, TaskOccurrenceOverride>{
              overrideKey: rangeOverride,
            },
          );

          final occurrences = task.occurrencesWithin(rangeStart, rangeEnd);

          expect(occurrences, hasLength(1));
          expect(occurrences.first.scheduledTime, expectedOccurrence);
        },
      );
    });

    group('equality', () {
      test('tasks with same data are equal', () {
        final task1 = CalendarTask(
          id: 'same-id',
          title: 'Same Task',
          createdAt: testTime,
          modifiedAt: testTime,
        );

        final task2 = CalendarTask(
          id: 'same-id',
          title: 'Same Task',
          createdAt: testTime,
          modifiedAt: testTime,
        );

        expect(task1, equals(task2));
        expect(task1.hashCode, equals(task2.hashCode));
      });

      test('tasks with different IDs are not equal', () {
        final task1 = CalendarTask.create(title: 'Task');
        final task2 = CalendarTask.create(title: 'Task');

        expect(task1, isNot(equals(task2)));
      });
    });
  });

  group('occurrence helpers', () {
    final baseStart = DateTime(2024, 3, 10, 14);

    test('split standalone task is not treated as occurrence', () {
      final parent = CalendarTask(
        id: 'standalone-task',
        title: 'Parent',
        scheduledTime: baseStart,
        duration: const Duration(hours: 1),
        isCompleted: false,
        createdAt: baseStart,
        modifiedAt: baseStart,
      );

      final split = parent.copyWith(
        id: '${parent.id}::split',
        scheduledTime: baseStart.add(const Duration(minutes: 30)),
        recurrence: null,
      );

      expect(split.isOccurrence, isFalse);
      expect(split.isSeries, isFalse);
    });

    test('generated recurring instance is treated as occurrence', () {
      final recurring = CalendarTask(
        id: 'series',
        title: 'Recurring',
        scheduledTime: baseStart,
        duration: const Duration(hours: 1),
        isCompleted: false,
        createdAt: baseStart,
        modifiedAt: baseStart,
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
        ),
      );

      final occurrences = recurring.occurrencesWithin(
        baseStart,
        baseStart.add(const Duration(days: 14)),
      );

      expect(occurrences, isNotEmpty);
      final instance = occurrences.first;
      expect(instance.isOccurrence, isTrue);
      expect(instance.isSeries, isTrue);
    });
  });

  group('splitTimeForFraction', () {
    test('falls back to default window when duration missing', () {
      final start = DateTime(2024, 6, 2, 8);
      final task = CalendarTask(
        id: 'fallback-split',
        title: 'Meeting',
        scheduledTime: start,
        duration: null,
        isCompleted: false,
        createdAt: start,
        modifiedAt: start,
      );

      final DateTime? split = task.splitTimeForFraction(
        fraction: 0.5,
        minutesPerStep: 15,
      );

      expect(
        split,
        equals(start.add(const Duration(minutes: 30))),
      );
    });
  });
}
