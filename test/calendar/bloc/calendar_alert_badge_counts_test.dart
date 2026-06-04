import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Calendar alert badge counts', () {
    test('does not count a task before its reminder fire time', () {
      final DateTime now = DateTime(2024, 1, 10, 9);
      final CalendarTask task = CalendarTask.create(
        title: 'Submit report',
        deadline: DateTime(2024, 1, 10, 12),
        reminders: const ReminderPreferences(
          enabled: true,
          deadlineOffsets: <Duration>[Duration(hours: 1)],
        ),
      );

      final CalendarAlertBadgeCounts counts = _modelWith(
        task,
      ).alertBadgeCounts(now);

      expect(counts.total, 0);
    });

    test('counts a task once when its reminder fire time is due', () {
      final DateTime now = DateTime(2024, 1, 10, 11);
      final CalendarTask task = CalendarTask.create(
        title: 'Submit report',
        deadline: DateTime(2024, 1, 10, 12),
        reminders: const ReminderPreferences(
          enabled: true,
          deadlineOffsets: <Duration>[Duration(hours: 1)],
        ),
      );

      final CalendarAlertBadgeCounts counts = _modelWith(
        task,
      ).alertBadgeCounts(now);

      expect(counts.unscheduled, 1);
      expect(counts.scheduled, 0);
    });

    test('counts an overdue deadline without reminder offsets', () {
      final DateTime now = DateTime(2024, 1, 10, 11);
      final CalendarTask task = CalendarTask.create(
        title: 'Submit report',
        deadline: DateTime(2024, 1, 10, 10),
      );

      final CalendarAlertBadgeCounts counts = _modelWith(
        task,
      ).alertBadgeCounts(now);

      expect(counts.unscheduled, 1);
    });

    test('does not count scheduled start time without a start reminder', () {
      final DateTime now = DateTime(2024, 1, 10, 11);
      final CalendarTask task = CalendarTask.create(
        title: 'Focus block',
        scheduledTime: DateTime(2024, 1, 10, 10),
      );

      final CalendarAlertBadgeCounts counts = _modelWith(
        task,
      ).alertBadgeCounts(now);

      expect(counts.total, 0);
    });

    test('counts a zero-offset start reminder at the start time', () {
      final DateTime now = DateTime(2024, 1, 10, 10);
      final CalendarTask task = CalendarTask.create(
        title: 'Focus block',
        scheduledTime: DateTime(2024, 1, 10, 10),
        reminders: const ReminderPreferences(
          enabled: true,
          startOffsets: <Duration>[Duration.zero],
        ),
      );

      final CalendarAlertBadgeCounts counts = _modelWith(
        task,
      ).alertBadgeCounts(now);

      expect(counts.scheduled, 1);
      expect(counts.unscheduled, 0);
    });

    test('does not count completed due tasks', () {
      final DateTime now = DateTime(2024, 1, 10, 11);
      final CalendarTask task = CalendarTask.create(
        title: 'Submit report',
        deadline: DateTime(2024, 1, 10, 10),
      ).copyWith(isCompleted: true);

      final CalendarAlertBadgeCounts counts = _modelWith(
        task,
      ).alertBadgeCounts(now);

      expect(counts.total, 0);
    });

    test('recurring occurrence completion decrements the series count', () {
      final DateTime now = DateTime(2024, 1, 4, 9);
      final CalendarTask completedSeries = CalendarTask.create(
        title: 'Daily standup',
        scheduledTime: DateTime(2024, 1, 3, 9),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          interval: 1,
        ),
        reminders: const ReminderPreferences(
          enabled: true,
          startOffsets: <Duration>[Duration.zero],
        ),
      ).copyWith(isCompleted: true);
      final CalendarTask generated = completedSeries
          .occurrencesWithin(DateTime(2024, 1, 4), DateTime(2024, 1, 4, 23))
          .single;
      final String occurrenceKey = occurrenceKeyFrom(generated.id)!;
      final CalendarTask openOccurrence = completedSeries.copyWith(
        occurrenceOverrides: <String, TaskOccurrenceOverride>{
          occurrenceKey: const TaskOccurrenceOverride(isCompleted: false),
        },
      );

      expect(_modelWith(openOccurrence).alertBadgeCounts(now).scheduled, 1);

      final CalendarTask completedOccurrence = completedSeries.copyWith(
        occurrenceOverrides: <String, TaskOccurrenceOverride>{
          occurrenceKey: const TaskOccurrenceOverride(isCompleted: true),
        },
      );

      expect(_modelWith(completedOccurrence).alertBadgeCounts(now).total, 0);
    });
  });
}

CalendarModel _modelWith(CalendarTask task) =>
    CalendarModel.empty().addTask(task);
