import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/view/widgets/critical_path_panel.dart';
import 'package:flutter_test/flutter_test.dart';

const double _progressTolerance = 0.0001;

CalendarTask _task(
  String id, {
  required bool completed,
  List<TaskChecklistItem> checklist = const [],
}) {
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
    checklist: checklist,
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

      const int totalTasks = 3;
      const int completedTasks = 1;
      const double expectedProgress = completedTasks / totalTasks;

      expect(progress.total, totalTasks);
      expect(progress.completed, completedTasks,
          reason: 'later completed tasks are gated');
      expect(progress.progressValue,
          closeTo(expectedProgress, _progressTolerance));
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

      const int totalTasks = 2;
      const int completedTasks = 2;
      const double expectedProgress = completedTasks / totalTasks;

      expect(progress.total, totalTasks);
      expect(progress.completed, completedTasks);
      expect(progress.progressValue,
          closeTo(expectedProgress, _progressTolerance));
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

      const int totalTasks = 3;
      const int completedTasks = 1;
      const double expectedProgress = completedTasks / totalTasks;

      expect(progress.total, totalTasks);
      expect(progress.completed, completedTasks);
      expect(progress.progressValue,
          closeTo(expectedProgress, _progressTolerance));
    });

    test('counts checklist progress after predecessor completes', () {
      final path = CalendarCriticalPath(
        id: 'path-4',
        name: 'Checklist Path',
        taskIds: const ['a', 'b'],
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 1, 1),
        isArchived: false,
      );
      final tasks = <String, CalendarTask>{
        'a': _task('a', completed: true),
        'b': _task(
          'b',
          completed: false,
          checklist: [
            const TaskChecklistItem(
              id: 'b1',
              label: 'b1',
              isCompleted: true,
            ),
            const TaskChecklistItem(
              id: 'b2',
              label: 'b2',
              isCompleted: false,
            ),
            const TaskChecklistItem(
              id: 'b3',
              label: 'b3',
              isCompleted: true,
            ),
          ],
        ),
      };

      final progress = computeCriticalPathProgress(path: path, tasks: tasks);

      const int totalTasks = 2;
      const int completedTasks = 1;
      const int checklistCompleted = 2;
      const int checklistTotal = 3;
      const double checklistFraction = checklistCompleted / checklistTotal;
      const double expectedProgressUnits = completedTasks + checklistFraction;
      const double expectedProgress = expectedProgressUnits / totalTasks;

      expect(progress.total, totalTasks);
      expect(progress.completed, completedTasks);
      expect(progress.progressValue,
          closeTo(expectedProgress, _progressTolerance));
    });

    test('gates checklist progress behind incomplete predecessors', () {
      final path = CalendarCriticalPath(
        id: 'path-5',
        name: 'Checklist Blocked Path',
        taskIds: const ['a', 'b'],
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 1, 1),
        isArchived: false,
      );
      final tasks = <String, CalendarTask>{
        'a': _task(
          'a',
          completed: false,
          checklist: const [],
        ),
        'b': _task(
          'b',
          completed: false,
          checklist: [
            const TaskChecklistItem(
              id: 'b1',
              label: 'b1',
              isCompleted: true,
            ),
            const TaskChecklistItem(
              id: 'b2',
              label: 'b2',
              isCompleted: true,
            ),
          ],
        ),
      };

      final progress = computeCriticalPathProgress(path: path, tasks: tasks);

      const int totalTasks = 2;
      const int completedTasks = 0;
      const double expectedProgress = completedTasks / totalTasks;

      expect(progress.total, totalTasks);
      expect(progress.completed, completedTasks);
      expect(progress.progressValue,
          closeTo(expectedProgress, _progressTolerance));
    });

    test('ignores checklist progress once parent task completes', () {
      final path = CalendarCriticalPath(
        id: 'path-6',
        name: 'Checklist Ignored Path',
        taskIds: const ['a'],
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 1, 1),
        isArchived: false,
      );
      final tasks = <String, CalendarTask>{
        'a': _task(
          'a',
          completed: true,
          checklist: [
            const TaskChecklistItem(
              id: 'a1',
              label: 'a1',
              isCompleted: false,
            ),
            const TaskChecklistItem(
              id: 'a2',
              label: 'a2',
              isCompleted: false,
            ),
          ],
        ),
      };

      final progress = computeCriticalPathProgress(path: path, tasks: tasks);

      const int totalTasks = 1;
      const int completedTasks = 1;
      const double expectedProgress = completedTasks / totalTasks;

      expect(progress.total, totalTasks);
      expect(progress.completed, completedTasks);
      expect(progress.progressValue,
          closeTo(expectedProgress, _progressTolerance));
    });
  });
}
