import 'dart:convert';

import 'package:axichat/src/calendar/models/calendar_task.dart';
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
}
