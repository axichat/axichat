import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarWidget Logic Tests', () {
    group('task filtering logic', () {
      test('filters tasks for selected date correctly', () {
        final selectedDate = DateTime(2024, 1, 15);
        final task1 = CalendarTask.create(
          title: 'Task on 15th',
          scheduledTime: DateTime(2024, 1, 15, 10, 0),
        );
        final task2 = CalendarTask.create(
          title: 'Task on 16th',
          scheduledTime: DateTime(2024, 1, 16, 10, 0),
        );
        final taskWithoutDate = CalendarTask.create(
          title: 'Task without date',
        );

        final modelWithTasks = CalendarModel.empty()
            .addTask(task1)
            .addTask(task2)
            .addTask(taskWithoutDate);

        // Simulate the _getTasksForSelectedDate logic
        final selectedTasks = modelWithTasks.tasks.values.where((task) {
          if (task.scheduledTime == null) return false;
          final taskDate = task.scheduledTime!;
          return taskDate.year == selectedDate.year &&
              taskDate.month == selectedDate.month &&
              taskDate.day == selectedDate.day;
        }).toList();

        expect(selectedTasks.length, equals(1));
        expect(selectedTasks.first.title, equals('Task on 15th'));
      });

      test('sorts tasks by scheduled time', () {
        final selectedDate = DateTime(2024, 1, 15);
        final task1 = CalendarTask.create(
          title: 'Morning Task',
          scheduledTime: DateTime(2024, 1, 15, 9, 0),
        );
        final task2 = CalendarTask.create(
          title: 'Afternoon Task',
          scheduledTime: DateTime(2024, 1, 15, 14, 0),
        );
        final task3 = CalendarTask.create(
          title: 'Evening Task',
          scheduledTime: DateTime(2024, 1, 15, 18, 0),
        );

        final modelWithTasks = CalendarModel.empty()
            .addTask(task2) // Add in random order
            .addTask(task3)
            .addTask(task1);

        // Simulate the sorting logic from _getTasksForSelectedDate
        final tasks = modelWithTasks.tasks.values.where((task) {
          if (task.scheduledTime == null) return false;
          final taskDate = task.scheduledTime!;
          return taskDate.year == selectedDate.year &&
              taskDate.month == selectedDate.month &&
              taskDate.day == selectedDate.day;
        }).toList();

        tasks.sort((a, b) {
          if (a.scheduledTime == null && b.scheduledTime == null) return 0;
          if (a.scheduledTime == null) return 1;
          if (b.scheduledTime == null) return -1;
          return a.scheduledTime!.compareTo(b.scheduledTime!);
        });

        expect(tasks.length, equals(3));
        expect(tasks[0].title, equals('Morning Task'));
        expect(tasks[1].title, equals('Afternoon Task'));
        expect(tasks[2].title, equals('Evening Task'));
      });

      test('handles empty task list', () {
        final selectedDate = DateTime(2024, 1, 15);
        final emptyModel = CalendarModel.empty();

        final tasks = emptyModel.tasks.values.where((task) {
          if (task.scheduledTime == null) return false;
          final taskDate = task.scheduledTime!;
          return taskDate.year == selectedDate.year &&
              taskDate.month == selectedDate.month &&
              taskDate.day == selectedDate.day;
        }).toList();

        expect(tasks, isEmpty);
      });
    });

    group('date navigation logic', () {
      test('calculates next date correctly', () {
        final currentDate = DateTime(2024, 1, 15);
        final nextDate = currentDate.add(const Duration(days: 1));

        expect(nextDate, equals(DateTime(2024, 1, 16)));
      });

      test('calculates previous date correctly', () {
        final currentDate = DateTime(2024, 1, 15);
        final prevDate = currentDate.add(const Duration(days: -1));

        expect(prevDate, equals(DateTime(2024, 1, 14)));
      });

      test('handles month boundary navigation', () {
        final lastDayOfMonth = DateTime(2024, 1, 31);
        final nextDate = lastDayOfMonth.add(const Duration(days: 1));

        expect(nextDate, equals(DateTime(2024, 2, 1)));
      });
    });

    group('responsive layout logic', () {
      test('mobile breakpoint detection', () {
        // Simulate ResponsiveHelper.isMobile logic
        bool isMobile(double width) => width < 600.0;

        expect(isMobile(400), isTrue);
        expect(isMobile(550), isTrue);
        expect(isMobile(600), isFalse);
        expect(isMobile(800), isFalse);
      });

      test('tablet breakpoint detection', () {
        // Simulate ResponsiveHelper.isTablet logic
        bool isTablet(double width) => width >= 600.0 && width < 1200.0;

        expect(isTablet(400), isFalse);
        expect(isTablet(600), isTrue);
        expect(isTablet(800), isTrue);
        expect(isTablet(1199), isTrue);
        expect(isTablet(1200), isFalse);
      });

      test('desktop breakpoint detection', () {
        // Simulate ResponsiveHelper.isDesktop logic
        bool isDesktop(double width) => width >= 1200.0;

        expect(isDesktop(400), isFalse);
        expect(isDesktop(800), isFalse);
        expect(isDesktop(1199), isFalse);
        expect(isDesktop(1200), isTrue);
        expect(isDesktop(1400), isTrue);
      });
    });
  });
}
