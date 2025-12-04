import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/view/widgets/critical_path_panel.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarTask _task(String id, {required bool completed}) {
  final DateTime now = DateTime(2024, 1, 1);
  return CalendarTask(
    id: id,
    title: id,
    description: null,
    scheduledTime: null,
    duration: null,
    isCompleted: completed,
    createdAt: now,
    modifiedAt: now,
    location: null,
    deadline: null,
    priority: null,
    startHour: null,
    endDate: null,
    recurrence: null,
    occurrenceOverrides: const {},
    reminders: ReminderPreferences.defaults(),
    checklist: const [],
  );
}

void main() {
  group('computeCriticalPathProgress', () {
    test('counts only contiguous completed prefix', () {
      final path = CalendarCriticalPath(
        id: 'path-1',
        name: 'Sample Path',
        taskIds: const ['a', 'b', 'c'],
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 1, 1),
        isArchived: false,
      );
      final tasks = <String, CalendarTask>{
        'a': _task('a', completed: true),
        'b': _task('b', completed: false),
        'c': _task('c', completed: true),
      };

      final progress = computeCriticalPathProgress(path: path, tasks: tasks);

      expect(progress.total, 3);
      expect(progress.completed, 1, reason: 'later completed tasks are gated');
    });

    test('includes later tasks after earlier blockers are done', () {
      final path = CalendarCriticalPath(
        id: 'path-2',
        name: 'Unblocked Path',
        taskIds: const ['a', 'b'],
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 1, 1),
        isArchived: false,
      );
      final tasks = <String, CalendarTask>{
        'a': _task('a', completed: true),
        'b': _task('b', completed: true),
      };

      final progress = computeCriticalPathProgress(path: path, tasks: tasks);

      expect(progress.completed, 2);
    });

    test('treats missing tasks as incomplete blockers', () {
      final path = CalendarCriticalPath(
        id: 'path-3',
        name: 'Missing Task Path',
        taskIds: const ['a', 'missing', 'b'],
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 1, 1),
        isArchived: false,
      );
      final tasks = <String, CalendarTask>{
        'a': _task('a', completed: true),
        'b': _task('b', completed: true),
      };

      final progress = computeCriticalPathProgress(path: path, tasks: tasks);

      expect(progress.completed, 1);
    });
  });
}
