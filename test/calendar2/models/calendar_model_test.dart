import 'package:axichat/src/calendar2/models/calendar_model.dart';
import 'package:axichat/src/calendar2/models/calendar_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarModel.empty', () {
    test('creates model with normalized selectedDate', () {
      final selected = DateTime(2024, 4, 18, 15, 30);
      final model = CalendarModel.empty(selectedDate: selected);

      expect(model.selectedDate, DateTime(2024, 4, 18));
      expect(model.version, 1);
      expect(model.tasks, isEmpty);
    });
  });

  group('CalendarModel task operations', () {
    test('addTask stores sanitized task and updates lastUpdated', () {
      final model = CalendarModel.empty();
      final task = CalendarTask.create(title: ' Demo ');

      final updated = model.addTask(task);

      expect(updated.tasks.length, 1);
      final storedTask = updated.tasks.values.first;
      expect(storedTask.title, 'Demo');
      expect(updated.lastUpdated.isAfter(model.lastUpdated), isTrue);
    });

    test('updateTask retains createdAt and updates fields', () {
      final initial = CalendarModel.empty();
      final task = CalendarTask.create(title: 'Original');
      final withTask = initial.addTask(task);

      final updatedTask = task.copyWith(title: 'Updated', urgent: true);
      final updatedModel = withTask.updateTask(updatedTask);

      final stored = updatedModel.tasks[task.id]!;
      expect(stored.title, 'Updated');
      expect(stored.urgent, isTrue);
      expect(stored.createdAt, task.createdAt);
      expect(stored.updatedAt.isAfter(task.updatedAt), isTrue);
    });

    test('deleteTask removes task', () {
      final initial = CalendarModel.empty();
      final task = CalendarTask.create(title: 'Disposable');
      final withTask = initial.addTask(task);

      final result = withTask.deleteTask(task.id);

      expect(result.tasks, isEmpty);
    });
  });

  group('CalendarModel ranges', () {
    test('tasksForSelectedWeek includes spanning tasks', () {
      final selected = DateTime(2024, 1, 3); // Wednesday
      final model = CalendarModel.empty(selectedDate: selected);
      final spanningTask = CalendarTask.create(
        title: 'Conference',
        scheduledStart: DateTime(2024, 1, 2, 9),
        endDate: DateTime(2024, 1, 4, 18),
      );
      final outsideTask = CalendarTask.create(
        title: 'Later',
        scheduledStart: DateTime(2024, 1, 10, 10),
      );

      final populated = model.addTask(spanningTask).addTask(outsideTask);

      expect(populated.tasksForSelectedWeek.length, 1);
      expect(populated.tasksForSelectedWeek.first.title, 'Conference');
    });

    test('tasksForSelectedDay matches by calendar day', () {
      final selected = DateTime(2024, 6, 5);
      final model = CalendarModel.empty(selectedDate: selected);
      final task = CalendarTask.create(
        title: 'Workshop',
        scheduledStart: DateTime(2024, 6, 5, 10),
        duration: const Duration(hours: 2),
      );
      final otherDay = CalendarTask.create(
        title: 'Different day',
        scheduledStart: DateTime(2024, 6, 6, 10),
      );

      final populated = model.addTask(task).addTask(otherDay);

      expect(populated.tasksForSelectedDay.length, 1);
      expect(populated.tasksForSelectedDay.first.title, 'Workshop');
    });
  });
}
