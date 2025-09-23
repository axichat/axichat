import 'dart:async';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _InMemoryStorage implements Storage {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async => _store.clear();

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;
}

class _MockCalendarSyncManager extends Mock implements CalendarSyncManager {}

void main() {
  group('CalendarBloc', () {
    late _InMemoryStorage storage;
    late _MockCalendarSyncManager syncManager;
    late CalendarBloc bloc;
    late CalendarStorageRegistry registry;

    setUpAll(() {
      registerFallbackValue(
        CalendarTask.create(title: 'fallback'),
      );
    });

    setUp(() {
      storage = _InMemoryStorage();
      registry = CalendarStorageRegistry(fallback: storage);
      registry.registerPrefix(authStoragePrefix, storage);
      HydratedBloc.storage = registry;
      syncManager = _MockCalendarSyncManager();

      when(() => syncManager.sendTaskUpdate(any(), any()))
          .thenAnswer((_) async {});
      when(() => syncManager.requestFullSync()).thenAnswer((_) async {});
      when(() => syncManager.pushFullSync()).thenAnswer((_) async {});

      bloc = CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is CalendarState.initial()', () {
      expect(bloc.state.viewMode, CalendarView.week);
      expect(bloc.state.model.tasks, isEmpty);
    });

    blocTest<CalendarBloc, CalendarState>(
      'started computes helper fields for empty model',
      build: () => bloc,
      act: (bloc) => bloc.add(const CalendarEvent.started()),
      expect: () => [
        predicate<CalendarState>((state) {
          return state.dueReminders != null &&
              state.dueReminders!.isEmpty &&
              state.nextTask == null;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskAdded inserts task and triggers sync',
      build: () => bloc,
      act: (bloc) => bloc.add(const CalendarEvent.taskAdded(
        title: 'New Task',
        description: 'details',
        duration: Duration(hours: 1),
      )),
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'add')).called(1);
      },
      expect: () => [
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', false),
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', true),
        predicate<CalendarState>((state) {
          return state.model.tasks.values
              .any((task) => task.title == 'New Task');
        }),
      ],
    );

    late CalendarTask seededTask;

    blocTest<CalendarBloc, CalendarState>(
      'taskUpdated replaces existing task and syncs',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(title: 'Original');
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        bloc.add(CalendarEvent.taskUpdated(
          task: seededTask.copyWith(title: 'Updated'),
        ));
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
      },
      expect: () => [
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', false),
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', true),
        predicate<CalendarState>((state) {
          final tasks = state.model.tasks;
          return tasks.isNotEmpty && tasks.values.first.title == 'Updated';
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskDeleted removes task and syncs',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(title: 'Delete me');
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        bloc.add(CalendarEvent.taskDeleted(taskId: seededTask.id));
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'delete')).called(1);
      },
      expect: () => [
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', false),
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', true),
        predicate<CalendarState>((state) => state.model.tasks.isEmpty),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskCompleted toggles completion and syncs',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(title: 'Complete me');
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        bloc.add(CalendarEvent.taskCompleted(
          taskId: seededTask.id,
          completed: true,
        ));
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
      },
      expect: () => [
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', false),
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', true),
        predicate<CalendarState>((state) {
          final tasks = state.model.tasks;
          return tasks.isNotEmpty && tasks.values.first.isCompleted;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'selectionPriorityChanged updates tasks and enables undo history',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(title: 'Reprioritize me');
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(
          model: model,
          isSelectionMode: true,
          selectedTaskIds: {seededTask.id},
        );
      },
      act: (bloc) {
        bloc.add(
          const CalendarEvent.selectionPriorityChanged(
            priority: TaskPriority.important,
          ),
        );
      },
      expect: () => [
        isA<CalendarState>()
            .having((state) => state.canUndo, 'canUndo', true)
            .having((state) => state.isSelectionMode, 'isSelectionMode', true),
        predicate<CalendarState>((state) {
          final task = state.model.tasks[seededTask.id]!;
          return task.isImportant &&
              state.canUndo &&
              !state.canRedo &&
              state.isSelectionMode &&
              state.selectedTaskIds.contains(seededTask.id);
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'undo/redo navigates history after priority change',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(title: 'History task');
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) async {
        bloc.add(
          CalendarEvent.taskUpdated(
            task: seededTask.copyWith(priority: TaskPriority.urgent),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CalendarEvent.undoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CalendarEvent.redoRequested());
      },
      expect: () => [
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', false),
        isA<CalendarState>()
            .having((state) => state.isLoading, 'isLoading', true)
            .having((state) => state.canUndo, 'canUndo', true),
        predicate<CalendarState>((state) {
          final task = state.model.tasks[seededTask.id]!;
          return task.isUrgent && state.canUndo && !state.canRedo;
        }),
        predicate<CalendarState>((state) {
          final task = state.model.tasks[seededTask.id]!;
          return !task.isUrgent && state.canRedo && !state.canUndo;
        }),
        predicate<CalendarState>((state) {
          final task = state.model.tasks[seededTask.id]!;
          return task.isUrgent && state.canUndo && !state.canRedo;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'remoteModelApplied replaces local model',
      build: () => bloc,
      act: (bloc) {
        final remote = CalendarModel.empty().addTask(
          CalendarTask.create(title: 'Remote task'),
        );
        bloc.add(CalendarEvent.remoteModelApplied(model: remote));
      },
      expect: () => [
        predicate<CalendarState>((state) {
          return state.model.tasks.values.first.title == 'Remote task';
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskOccurrenceUpdated stores overrides on base task',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(
          title: 'Repeating',
          scheduledTime: DateTime(2024, 1, 1, 9),
          duration: const Duration(hours: 1),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            byWeekdays: [DateTime.tuesday],
          ),
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final occurrenceStart = DateTime(2024, 1, 2, 9);
        final occurrenceKey = occurrenceStart.microsecondsSinceEpoch.toString();
        final occurrenceId = '${seededTask.id}::$occurrenceKey';

        bloc.add(
          CalendarEvent.taskOccurrenceUpdated(
            taskId: seededTask.id,
            occurrenceId: occurrenceId,
            scheduledTime: DateTime(2024, 1, 2, 11),
            duration: const Duration(hours: 2),
          ),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
      },
      expect: () => [
        isA<CalendarState>()
            .having((state) => state.canUndo, 'canUndo', true)
            .having((state) =>
                state.model.tasks[seededTask.id]?.occurrenceOverrides.isEmpty ??
                    true, 'overridesEmpty', true),
        predicate<CalendarState>((state) {
          final task = state.model.tasks[seededTask.id]!;
          final occurrenceStart = DateTime(2024, 1, 2, 9);
          final key = occurrenceStart.microsecondsSinceEpoch.toString();
          final override = task.occurrenceOverrides[key];
          return override != null &&
              override.scheduledTime == DateTime(2024, 1, 2, 11) &&
              override.duration == const Duration(hours: 2);
        }),
      ],
    );
  });
}
