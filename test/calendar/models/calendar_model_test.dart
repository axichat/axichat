import 'dart:convert';

import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarModel', () {
    final testTime = DateTime(2024, 1, 15, 10, 30);
    late CalendarTask testTask1;
    late CalendarTask testTask2;

    setUp(() {
      testTask1 = CalendarTask(
        id: 'task-1',
        title: 'First Task',
        description: 'First task description',
        createdAt: testTime,
        modifiedAt: testTime,
      );

      testTask2 = CalendarTask(
        id: 'task-2',
        title: 'Second Task',
        scheduledTime: testTime.add(const Duration(hours: 1)),
        duration: const Duration(minutes: 30),
        createdAt: testTime,
        modifiedAt: testTime,
      );
    });

    group('factory CalendarModel.empty', () {
      test('creates empty model with correct defaults', () {
        final model = CalendarModel.empty();

        expect(model.tasks, isEmpty);
        expect(model.lastModified, isNotNull);
        expect(model.checksum, isNotEmpty);
      });

      test('generates valid checksum for empty model', () {
        final model = CalendarModel.empty();
        final calculatedChecksum = model.calculateChecksum();

        expect(model.checksum, equals(calculatedChecksum));
      });
    });

    group('checksum calculation', () {
      test('produces consistent checksum for identical models', () {
        // Create a base model with fixed timestamp
        final baseModel = CalendarModel(
          lastModified: testTime,
          checksum: '',
        );

        final model1 = baseModel.addTask(testTask1);
        // Create identical model by copying from the first
        final model2 = model1.copyWith();

        expect(model1.checksum, equals(model2.checksum));
      });

      test('produces different checksums for different data', () {
        final baseModel = CalendarModel(
          lastModified: testTime,
          checksum: '',
        );

        final model1 = baseModel.addTask(testTask1);
        final model2 = baseModel.addTask(testTask2);

        expect(model1.checksum, isNot(equals(model2.checksum)));
      });

      test('checksum changes when tasks change', () {
        final emptyModel = CalendarModel.empty();
        final modelWithTask = emptyModel.addTask(testTask1);

        expect(emptyModel.checksum, isNot(equals(modelWithTask.checksum)));
      });

      test('task order does not affect checksum with same timestamp', () {
        // Create two models with the same tasks added in different order
        final fixedTime = DateTime(2024, 1, 15, 12, 0);
        final tasks = {testTask1.id: testTask1, testTask2.id: testTask2};

        final model1 = CalendarModel(
          lastModified: fixedTime,
          checksum: '',
          tasks: tasks,
        );

        final model2 = CalendarModel(
          lastModified: fixedTime,
          checksum: '',
          tasks: tasks,
        );

        expect(model1.calculateChecksum(), equals(model2.calculateChecksum()));
      });
    });

    group('task operations', () {
      late CalendarModel baseModel;

      setUp(() {
        baseModel = CalendarModel.empty();
      });

      group('addTask', () {
        test('adds task to empty model', () {
          final updated = baseModel.addTask(testTask1);

          expect(updated.tasks, hasLength(1));
          expect(updated.tasks['task-1'], equals(testTask1));
          expect(updated.lastModified, isNot(equals(baseModel.lastModified)));
          expect(updated.checksum, isNot(equals(baseModel.checksum)));
        });

        test('adds multiple tasks', () {
          final updated = baseModel.addTask(testTask1).addTask(testTask2);

          expect(updated.tasks, hasLength(2));
          expect(updated.tasks['task-1'], equals(testTask1));
          expect(updated.tasks['task-2'], equals(testTask2));
        });

        test('overwrites existing task with same ID', () {
          final initialModel = baseModel.addTask(testTask1);
          final updatedTask = testTask1.copyWith(title: 'Updated Task');
          final finalModel = initialModel.addTask(updatedTask);

          expect(finalModel.tasks, hasLength(1));
          expect(finalModel.tasks['task-1']?.title, equals('Updated Task'));
          expect(finalModel.lastModified,
              isNot(equals(initialModel.lastModified)));
        });

        test('preserves immutability', () {
          final updated = baseModel.addTask(testTask1);

          expect(baseModel.tasks, isEmpty);
          expect(updated.tasks, hasLength(1));
        });
      });

      group('updateTask', () {
        late CalendarModel modelWithTask;

        setUp(() {
          modelWithTask = baseModel.addTask(testTask1);
        });

        test('updates existing task', () {
          final updatedTask = testTask1.copyWith(title: 'Updated Title');
          final result = modelWithTask.updateTask(updatedTask);

          expect(result.tasks['task-1']?.title, equals('Updated Title'));
          expect(
              result.lastModified, isNot(equals(modelWithTask.lastModified)));
          expect(result.checksum, isNot(equals(modelWithTask.checksum)));
        });

        test('returns unchanged model for non-existent task', () {
          final nonExistentTask = CalendarTask(
            id: 'non-existent',
            title: 'Does not exist',
            createdAt: testTime,
            modifiedAt: testTime,
          );

          final result = modelWithTask.updateTask(nonExistentTask);

          expect(result, equals(modelWithTask));
          expect(result.tasks, hasLength(1));
        });
      });

      group('deleteTask', () {
        late CalendarModel modelWithTasks;

        setUp(() {
          modelWithTasks = baseModel.addTask(testTask1).addTask(testTask2);
        });

        test('deletes existing task', () {
          final result = modelWithTasks.deleteTask('task-1');

          expect(result.tasks, hasLength(1));
          expect(result.tasks, isNot(contains('task-1')));
          expect(result.tasks, contains('task-2'));
          expect(
              result.lastModified, isNot(equals(modelWithTasks.lastModified)));
          expect(result.checksum, isNot(equals(modelWithTasks.checksum)));
        });

        test('returns unchanged model for non-existent task', () {
          final result = modelWithTasks.deleteTask('non-existent');

          expect(result, equals(modelWithTasks));
          expect(result.tasks, hasLength(2));
        });

        test('can delete all tasks', () {
          final result =
              modelWithTasks.deleteTask('task-1').deleteTask('task-2');

          expect(result.tasks, isEmpty);
          expect(
              result.lastModified, isNot(equals(modelWithTasks.lastModified)));
        });

        test('preserves immutability', () {
          final result = modelWithTasks.deleteTask('task-1');

          expect(modelWithTasks.tasks, hasLength(2));
          expect(result.tasks, hasLength(1));
        });
      });
    });

    group('day event operations', () {
      late CalendarModel baseModel;
      late DayEvent birthday;

      setUp(() {
        baseModel = CalendarModel.empty();
        birthday = DayEvent.create(
          title: 'Birthday',
          startDate: DateTime(2024, 5, 5),
          reminders: ReminderPreferences.defaults(),
        );
      });

      test('addDayEvent stores event and updates checksum', () {
        final CalendarModel updated = baseModel.addDayEvent(birthday);

        expect(updated.dayEvents, contains(birthday.id));
        expect(
          updated.dayEvents[birthday.id]?.effectiveReminders.isEnabled,
          isTrue,
        );
        expect(updated.checksum, isNot(equals(baseModel.checksum)));
      });

      test('updateDayEvent replaces existing entry', () {
        final CalendarModel withEvent = baseModel.addDayEvent(birthday);
        final DayEvent revised = birthday.normalizedCopy(
          title: 'Updated birthday',
          endDate: birthday.startDate.add(const Duration(days: 1)),
          reminders: const ReminderPreferences(
            startOffsets: <Duration>[Duration(hours: 2)],
          ),
        );

        final CalendarModel updated = withEvent.updateDayEvent(revised);

        expect(updated.dayEvents[birthday.id]?.title, 'Updated birthday');
        expect(
          updated.dayEvents[birthday.id]?.normalizedEnd
              .isAfter(updated.dayEvents[birthday.id]!.normalizedStart),
          isTrue,
        );
        expect(
          updated.dayEvents[birthday.id]?.effectiveReminders.startOffsets,
          contains(const Duration(hours: 2)),
        );
      });

      test('deleteDayEvent removes event', () {
        final CalendarModel withEvent = baseModel.addDayEvent(birthday);
        final CalendarModel updated = withEvent.deleteDayEvent(birthday.id);

        expect(updated.dayEvents, isEmpty);
        expect(updated.checksum, isNot(equals(withEvent.checksum)));
      });

      test('replaceDayEvents merges without dropping tasks', () {
        final CalendarModel withTask =
            baseModel.addTask(testTask1).addDayEvent(birthday);
        final DayEvent holiday = DayEvent.create(
          title: 'Holiday',
          startDate: DateTime(2024, 5, 20),
        );

        final CalendarModel merged = withTask.replaceDayEvents(
          {holiday.id: holiday},
        );

        expect(merged.dayEvents, hasLength(2));
        expect(merged.tasks, contains(testTask1.id));
      });
    });

    group('JSON serialization', () {
      late CalendarModel model;

      setUp(() {
        model = CalendarModel.empty().addTask(testTask1).addTask(testTask2);
      });

      test('toJson produces valid JSON', () {
        final json = model.toJson();

        expect(json['tasks'], isA<Map>());
        expect(json['last_modified'], isNotNull);
        expect(json['checksum'], isNotEmpty);
      });

      test('fromJson reconstructs model correctly', () {
        // Proper JSON round-trip through string encoding/decoding
        final jsonString = jsonEncode(model.toJson());
        final parsedJson = jsonDecode(jsonString) as Map<String, dynamic>;
        final reconstructed = CalendarModel.fromJson(parsedJson);

        expect(reconstructed.tasks, hasLength(2));
        expect(reconstructed.checksum, equals(model.checksum));
        expect(reconstructed.lastModified.millisecondsSinceEpoch,
            equals(model.lastModified.millisecondsSinceEpoch));

        // Verify tasks are correctly reconstructed
        expect(reconstructed.tasks.keys, containsAll(['task-1', 'task-2']));
        expect(reconstructed.tasks['task-1']?.title, equals('First Task'));
        expect(reconstructed.tasks['task-2']?.title, equals('Second Task'));
      });

      test('roundtrip serialization maintains data integrity', () {
        final jsonString = jsonEncode(model.toJson());
        final parsedJson = jsonDecode(jsonString) as Map<String, dynamic>;
        final reconstructed = CalendarModel.fromJson(parsedJson);

        expect(reconstructed.tasks.keys, equals(model.tasks.keys));
        expect(reconstructed.checksum, equals(model.checksum));

        // Verify tasks are preserved
        for (final taskId in model.tasks.keys) {
          expect(reconstructed.tasks[taskId], equals(model.tasks[taskId]));
        }
      });

      test('handles empty model serialization', () {
        final emptyModel = CalendarModel.empty();
        final json = emptyModel.toJson();
        final reconstructed = CalendarModel.fromJson(json);

        expect(reconstructed.tasks, isEmpty);
        expect(reconstructed.checksum, equals(emptyModel.checksum));
      });
    });

    group('equality', () {
      test('models with same data are equal', () {
        // Create models with identical timestamps to ensure equality
        final fixedTime = DateTime(2024, 1, 15, 12, 0);
        final baseModel = CalendarModel(
          lastModified: fixedTime,
          checksum: 'test-checksum',
        );

        final model1 = baseModel.copyWith(tasks: {testTask1.id: testTask1});
        final model2 = baseModel.copyWith(tasks: {testTask1.id: testTask1});

        expect(model1, equals(model2));
        expect(model1.hashCode, equals(model2.hashCode));
      });

      test('models with different tasks are not equal', () {
        final fixedTime = DateTime(2024, 1, 15, 12, 0);
        final baseModel1 = CalendarModel(
          lastModified: fixedTime,
          checksum: 'checksum1',
          tasks: {testTask1.id: testTask1},
        );
        final baseModel2 = CalendarModel(
          lastModified: fixedTime,
          checksum: 'checksum2',
          tasks: {testTask2.id: testTask2},
        );

        expect(baseModel1, isNot(equals(baseModel2)));
      });
    });

    group('conflict resolution scenarios', () {
      test('adding same task overwrites existing', () {
        final model = CalendarModel.empty();
        final task1 = testTask1.copyWith(title: 'Original');
        final task2 = testTask1.copyWith(title: 'Updated');

        final result = model.addTask(task1).addTask(task2);

        expect(result.tasks, hasLength(1));
        expect(result.tasks[testTask1.id]?.title, equals('Updated'));
      });

      test('model operations are atomic', () {
        final originalModel = CalendarModel.empty().addTask(testTask1);
        final updatedTask = testTask1.copyWith(title: 'Updated');

        final result = originalModel.updateTask(updatedTask);

        // Original model should be unchanged
        expect(
            originalModel.tasks[testTask1.id]?.title, equals(testTask1.title));
        // Result should have updated task
        expect(result.tasks[testTask1.id]?.title, equals('Updated'));
      });
    });
  });
}
