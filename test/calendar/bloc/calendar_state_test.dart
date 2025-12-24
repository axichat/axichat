import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarState.tasksInRange', () {
    test(
      'includes recurring overrides even when moved outside original day',
      () {
        final baseStart = DateTime(2024, 1, 1, 9);
        final overrideKey = baseStart.microsecondsSinceEpoch.toString();
        final movedStart = DateTime(2024, 1, 3, 10);

        final task = CalendarTask(
          id: 'task-1',
          title: 'Daily',
          scheduledTime: baseStart,
          duration: const Duration(hours: 1),
          createdAt: baseStart,
          modifiedAt: baseStart,
          recurrence:
              const RecurrenceRule(frequency: RecurrenceFrequency.daily),
          occurrenceOverrides: {
            overrideKey: TaskOccurrenceOverride(scheduledTime: movedStart),
          },
        );

        final model = CalendarModel.empty().addTask(task);
        final state = CalendarState(
          model: model,
          selectedDate: DateTime(2024, 1, 3),
        );

        final tasks = state.tasksForDate(DateTime(2024, 1, 3));

        expect(
          tasks.any(
            (occurrence) =>
                occurrence.id.contains(task.id) &&
                occurrence.scheduledTime == movedStart,
          ),
          isTrue,
        );
      },
    );

    test('honors rDates and exDates without duplicates', () {
      const int recurrenceCount = 3;
      final DateTime baseStart = DateTime(2024, 1, 1, 9);
      final DateTime excludedStart = DateTime(2024, 1, 2, 9);
      final DateTime extraStart = DateTime(2024, 1, 5, 9);
      final CalendarDateTime excludedDate =
          CalendarDateTime(value: excludedStart);
      final CalendarDateTime extraDate = CalendarDateTime(value: extraStart);
      final RecurrenceRule recurrence = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        count: recurrenceCount,
        rDates: <CalendarDateTime>[extraDate],
        exDates: <CalendarDateTime>[excludedDate],
      );
      final CalendarTask task = CalendarTask(
        id: 'task-1',
        title: 'Daily',
        scheduledTime: baseStart,
        duration: const Duration(hours: 1),
        createdAt: baseStart,
        modifiedAt: baseStart,
        recurrence: recurrence,
      );

      final CalendarModel model = CalendarModel.empty().addTask(task);
      final CalendarState state = CalendarState(
        model: model,
        selectedDate: baseStart,
      );

      final List<CalendarTask> excludedDayTasks =
          state.tasksForDate(excludedStart);
      expect(excludedDayTasks, isEmpty);

      final List<CalendarTask> extraDayTasks = state.tasksForDate(extraStart);
      expect(extraDayTasks, hasLength(1));
      expect(extraDayTasks.first.scheduledTime, equals(extraStart));
    });
  });

  group('CalendarState bucket getters', () {
    test('separates scheduled, unscheduled, and reminder tasks', () {
      const String scheduledTaskId = 'task-scheduled';
      const String unscheduledTaskId = 'task-unscheduled';
      const String reminderTaskId = 'task-reminder';
      const String scheduledTitle = 'Scheduled Task';
      const String unscheduledTitle = 'Unscheduled Task';
      const String reminderTitle = 'Reminder Task';
      final DateTime baseTime = DateTime(2024, 2, 2, 9);
      const Duration scheduledDuration = Duration(hours: 1);
      const Duration reminderDelta = Duration(days: 2);

      final CalendarTask scheduledTask = CalendarTask(
        id: scheduledTaskId,
        title: scheduledTitle,
        scheduledTime: baseTime,
        duration: scheduledDuration,
        createdAt: baseTime,
        modifiedAt: baseTime,
      );
      final CalendarTask unscheduledTask = CalendarTask(
        id: unscheduledTaskId,
        title: unscheduledTitle,
        createdAt: baseTime,
        modifiedAt: baseTime,
      );
      final CalendarTask reminderTask = CalendarTask(
        id: reminderTaskId,
        title: reminderTitle,
        deadline: baseTime.add(reminderDelta),
        createdAt: baseTime,
        modifiedAt: baseTime,
      );

      final CalendarModel model = CalendarModel.empty()
          .addTask(scheduledTask)
          .addTask(unscheduledTask)
          .addTask(reminderTask);
      final CalendarState state = CalendarState(
        model: model,
        selectedDate: baseTime,
      );

      expect(state.scheduledTasks, hasLength(1));
      expect(state.scheduledTasks.first.id, equals(scheduledTaskId));
      expect(state.unscheduledTasks, hasLength(1));
      expect(state.unscheduledTasks.first.id, equals(unscheduledTaskId));
      expect(state.reminderTasks, hasLength(1));
      expect(state.reminderTasks.first.id, equals(reminderTaskId));
    });
  });
}
