import 'package:axichat/src/calendar/bloc/calendar_state.dart';
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
  });
}
