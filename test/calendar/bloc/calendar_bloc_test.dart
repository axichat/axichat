import 'dart:async';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockCalendarBox extends Mock implements Box<CalendarModel> {}

class MockCalendarSyncManager extends Mock implements CalendarSyncManager {}

void main() {
  group('CalendarBloc', () {
    late CalendarBloc calendarBloc;
    late MockCalendarBox mockCalendarBox;
    late MockCalendarSyncManager mockSyncManager;
    final testTime = DateTime(2024, 1, 15, 10, 30);

    setUpAll(() {
      // Register fallback values for mocktail
      registerFallbackValue(CalendarModel.empty());
      registerFallbackValue(CalendarTask.create(
        title: 'test',
      ));
    });

    setUp(() {
      mockCalendarBox = MockCalendarBox();
      mockSyncManager = MockCalendarSyncManager();

      // Default mock behavior for calendar box
      when(() => mockCalendarBox.get('calendar')).thenReturn(null);
      when(() => mockCalendarBox.put('calendar', any()))
          .thenAnswer((_) async {});
      when(() => mockCalendarBox.watch())
          .thenAnswer((_) => const Stream.empty());

      // Default mock behavior for sync manager
      when(() => mockSyncManager.sendTaskUpdate(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockSyncManager.requestFullSync()).thenAnswer((_) async {});
      when(() => mockSyncManager.pushFullSync()).thenAnswer((_) async {});

      calendarBloc = CalendarBloc(
        calendarBox: mockCalendarBox,
        syncManager: mockSyncManager,
      );
    });

    tearDown(() {
      calendarBloc.close();
    });

    test('initial state is correct', () {
      expect(calendarBloc.state.model.tasks, isEmpty);
      expect(calendarBloc.state.viewMode, equals(CalendarView.week));
      expect(calendarBloc.state.isSyncing, isFalse);
      expect(calendarBloc.state.dueReminders, isNull);
      expect(calendarBloc.state.nextTask, isNull);
    });

    blocTest<CalendarBloc, CalendarState>(
      'CalendarStarted loads empty model when box is empty',
      build: () {
        when(() => mockCalendarBox.get('calendar')).thenReturn(null);
        return CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        );
      },
      act: (bloc) => bloc.add(const CalendarEvent.started()),
      expect: () => [
        predicate<CalendarState>((state) {
          return state.model.tasks.isEmpty &&
              state.dueReminders != null &&
              state.dueReminders!.isEmpty;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'CalendarStarted loads existing model from box',
      build: () {
        final existingModel = CalendarModel.empty().addTask(
          CalendarTask.create(
            title: 'Existing Task',
          ),
        );
        when(() => mockCalendarBox.get('calendar')).thenReturn(existingModel);
        return CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        );
      },
      act: (bloc) => bloc.add(const CalendarEvent.started()),
      expect: () => [
        predicate<CalendarState>((state) {
          return state.model.tasks.length == 1 &&
              state.model.tasks.values.first.title == 'Existing Task';
        }),
      ],
    );

    group('task operations', () {
      blocTest<CalendarBloc, CalendarState>(
        'CalendarTaskAdded creates and saves new task',
        build: () => CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        ),
        act: (bloc) => bloc.add(const CalendarEvent.taskAdded(
          title: 'New Task',
          description: 'Task description',
          scheduledTime: null,
          duration: null,
        )),
        verify: (bloc) {
          verify(() => mockCalendarBox.put('calendar', any(
                that: predicate<CalendarModel>((model) {
                  return model.tasks.length == 1 &&
                      model.tasks.values.first.title == 'New Task' &&
                      model.tasks.values.first.description ==
                          'Task description' &&
                      true;
                }),
              ))).called(1);
        },
      );

      blocTest<CalendarBloc, CalendarState>(
        'CalendarTaskAdded creates task with scheduled time and duration',
        build: () => CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        ),
        act: (bloc) => bloc.add(CalendarEvent.taskAdded(
          title: 'Scheduled Task',
          scheduledTime: testTime,
          duration: const Duration(hours: 1),
        )),
        verify: (bloc) {
          verify(() => mockCalendarBox.put('calendar', any(
                that: predicate<CalendarModel>((model) {
                  final task = model.tasks.values.first;
                  return task.title == 'Scheduled Task' &&
                      task.scheduledTime == testTime &&
                      task.duration == const Duration(hours: 1);
                }),
              ))).called(1);
        },
      );

      blocTest<CalendarBloc, CalendarState>(
        'CalendarTaskUpdated updates existing task',
        build: () {
          final initialModel = CalendarModel.empty().addTask(
            CalendarTask.create(
              title: 'Original Task',
            ),
          );
          when(() => mockCalendarBox.get('calendar')).thenReturn(initialModel);
          return CalendarBloc(
            calendarBox: mockCalendarBox,
            syncManager: mockSyncManager,
          );
        },
        seed: () {
          final task = CalendarTask.create(
            title: 'Original Task',
          );
          final model = CalendarModel.empty().addTask(task);
          return CalendarState.initial().copyWith(model: model);
        },
        act: (bloc) {
          final existingTask = bloc.state.model.tasks.values.first;
          final updatedTask = existingTask.copyWith(title: 'Updated Task');
          bloc.add(CalendarEvent.taskUpdated(task: updatedTask));
        },
        verify: (bloc) {
          verify(() => mockCalendarBox.put('calendar', any(
                that: predicate<CalendarModel>((model) {
                  return model.tasks.values.first.title == 'Updated Task';
                }),
              ))).called(1);
        },
      );

      blocTest<CalendarBloc, CalendarState>(
        'CalendarTaskDeleted removes task',
        build: () => CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        ),
        seed: () {
          final task = CalendarTask.create(
            title: 'Task to Delete',
          );
          final model = CalendarModel.empty().addTask(task);
          return CalendarState.initial().copyWith(model: model);
        },
        act: (bloc) {
          final taskId = bloc.state.model.tasks.keys.first;
          bloc.add(CalendarEvent.taskDeleted(taskId: taskId));
        },
        verify: (bloc) {
          verify(() => mockCalendarBox.put('calendar', any(
                that: predicate<CalendarModel>((model) {
                  return model.tasks.isEmpty;
                }),
              ))).called(1);
        },
      );

      blocTest<CalendarBloc, CalendarState>(
        'CalendarTaskCompleted toggles completion status',
        build: () => CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        ),
        seed: () {
          final task = CalendarTask.create(
            title: 'Task to Complete',
          );
          final model = CalendarModel.empty().addTask(task);
          return CalendarState.initial().copyWith(model: model);
        },
        act: (bloc) {
          final taskId = bloc.state.model.tasks.keys.first;
          bloc.add(
              CalendarEvent.taskCompleted(taskId: taskId, completed: true));
        },
        verify: (bloc) {
          verify(() => mockCalendarBox.put('calendar', any(
                that: predicate<CalendarModel>((model) {
                  return model.tasks.values.first.isCompleted == true;
                }),
              ))).called(1);
        },
      );

      blocTest<CalendarBloc, CalendarState>(
        'CalendarTaskCompleted does nothing for non-existent task',
        build: () => CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        ),
        act: (bloc) => bloc.add(const CalendarEvent.taskCompleted(
          taskId: 'non-existent-id',
          completed: true,
        )),
        verify: (bloc) {
          verifyNever(() => mockCalendarBox.put('calendar', any()));
        },
      );
    });

    group('view and date operations', () {
      blocTest<CalendarBloc, CalendarState>(
        'CalendarViewChanged updates view mode',
        build: () => CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        ),
        act: (bloc) =>
            bloc.add(const CalendarEvent.viewChanged(view: CalendarView.day)),
        expect: () => [
          predicate<CalendarState>(
              (state) => state.viewMode == CalendarView.day),
        ],
      );

      blocTest<CalendarBloc, CalendarState>(
        'CalendarDateSelected updates selected date',
        build: () => CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        ),
        act: (bloc) => bloc.add(CalendarEvent.dateSelected(date: testTime)),
        expect: () => [
          predicate<CalendarState>((state) => state.selectedDate == testTime),
        ],
      );
    });

    group('data changed handling', () {
      blocTest<CalendarBloc, CalendarState>(
        'CalendarDataChanged reloads model and updates computed fields',
        build: () {
          final now = DateTime.now();
          final overdueTasks = CalendarTask.create(
            title: 'Overdue Task',
            scheduledTime: now.subtract(const Duration(hours: 1)),
          );
          final upcomingTask = CalendarTask.create(
            title: 'Upcoming Task',
            scheduledTime: now.add(const Duration(hours: 3)),
          );

          final modelWithTasks =
              CalendarModel.empty().addTask(overdueTasks).addTask(upcomingTask);

          when(() => mockCalendarBox.get('calendar'))
              .thenReturn(modelWithTasks);
          return CalendarBloc(
            calendarBox: mockCalendarBox,
            syncManager: mockSyncManager,
          );
        },
        act: (bloc) => bloc.add(const CalendarEvent.dataChanged()),
        expect: () => [
          predicate<CalendarState>((state) {
            return state.model.tasks.length == 2 &&
                state.dueReminders != null &&
                state.dueReminders!.length == 1 && // Only overdue task
                state.nextTask != null &&
                state.nextTask!.title == 'Upcoming Task';
          }),
        ],
      );
    });

    group('due reminders logic', () {
      blocTest<CalendarBloc, CalendarState>(
        'correctly identifies overdue and due soon tasks',
        build: () {
          final now = DateTime.now();
          final overdue = CalendarTask.create(
            title: 'Overdue',
            scheduledTime: now.subtract(const Duration(hours: 1)),
          );
          final dueSoon = CalendarTask.create(
            title: 'Due Soon',
            scheduledTime: now.add(const Duration(hours: 1)),
          );
          final dueWayLater = CalendarTask.create(
            title: 'Due Way Later',
            scheduledTime: now.add(const Duration(hours: 5)),
          );
          final completed = CalendarTask.create(
            title: 'Completed Overdue',
            scheduledTime: now.subtract(const Duration(hours: 2)),
          ).copyWith(isCompleted: true);

          final model = CalendarModel.empty()
              .addTask(overdue)
              .addTask(dueSoon)
              .addTask(dueWayLater)
              .addTask(completed);

          when(() => mockCalendarBox.get('calendar')).thenReturn(model);
          return CalendarBloc(
            calendarBox: mockCalendarBox,
            syncManager: mockSyncManager,
          );
        },
        act: (bloc) => bloc.add(const CalendarEvent.started()),
        expect: () => [
          predicate<CalendarState>((state) {
            return state.dueReminders != null &&
                state.dueReminders!.length ==
                    2 && // overdue + due soon, not completed or way later
                state.dueReminders!.any((task) => task.title == 'Overdue') &&
                state.dueReminders!.any((task) => task.title == 'Due Soon');
          }),
        ],
      );
    });

    group('next task logic', () {
      blocTest<CalendarBloc, CalendarState>(
        'finds next upcoming incomplete task',
        build: () {
          final now = DateTime.now();
          final completed = CalendarTask.create(
            title: 'Completed Future',
            scheduledTime: now.add(const Duration(hours: 1)),
          ).copyWith(isCompleted: true);

          final nextTask = CalendarTask.create(
            title: 'Next Task',
            scheduledTime: now.add(const Duration(hours: 2)),
          );

          final laterTask = CalendarTask.create(
            title: 'Later Task',
            scheduledTime: now.add(const Duration(hours: 3)),
          );

          final model = CalendarModel.empty()
              .addTask(completed)
              .addTask(laterTask)
              .addTask(nextTask);

          when(() => mockCalendarBox.get('calendar')).thenReturn(model);
          return CalendarBloc(
            calendarBox: mockCalendarBox,
            syncManager: mockSyncManager,
          );
        },
        act: (bloc) => bloc.add(const CalendarEvent.started()),
        expect: () => [
          predicate<CalendarState>((state) {
            return state.nextTask != null &&
                state.nextTask!.title == 'Next Task';
          }),
        ],
      );

      blocTest<CalendarBloc, CalendarState>(
        'returns null when no upcoming tasks',
        build: () {
          final now = DateTime.now();
          final pastTask = CalendarTask.create(
            title: 'Past Task',
            scheduledTime: now.subtract(const Duration(hours: 1)),
          );

          final model = CalendarModel.empty().addTask(pastTask);

          when(() => mockCalendarBox.get('calendar')).thenReturn(model);
          return CalendarBloc(
            calendarBox: mockCalendarBox,
            syncManager: mockSyncManager,
          );
        },
        act: (bloc) => bloc.add(const CalendarEvent.started()),
        expect: () => [
          predicate<CalendarState>((state) => state.nextTask == null),
        ],
      );
    });

    group('box subscription', () {
      test('listens to box changes and triggers data changed event', () async {
        final streamController = StreamController<BoxEvent>();
        when(() => mockCalendarBox.watch())
            .thenAnswer((_) => streamController.stream);

        final bloc = CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        );

        // Simulate box change
        streamController.add(BoxEvent('calendar', null, false));

        // Allow async processing
        await Future.delayed(Duration.zero);

        verify(() => mockCalendarBox.get('calendar'))
            .called(greaterThanOrEqualTo(1));

        await bloc.close();
        await streamController.close();
      });

      test('cancels box subscription on close', () async {
        final streamController = StreamController<BoxEvent>();
        when(() => mockCalendarBox.watch())
            .thenAnswer((_) => streamController.stream);

        final bloc = CalendarBloc(
          calendarBox: mockCalendarBox,
          syncManager: mockSyncManager,
        );

        expect(streamController.hasListener, isTrue);

        await bloc.close();

        // Stream should be cancelled
        expect(streamController.hasListener, isFalse);

        await streamController.close();
      });
    });
  });
}
