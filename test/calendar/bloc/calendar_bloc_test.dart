import 'dart:async';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
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
    late String undoBaseTaskId;
    late String undoOccurrenceId;

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
      'undoRequested restores selection state after batch edit',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final DateTime start = DateTime(2024, 5, 1, 11);
        final CalendarTask recurring = CalendarTask(
          id: 'undo-series',
          title: 'Recurring base',
          description: null,
          scheduledTime: start,
          duration: const Duration(hours: 1),
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
          location: 'Desk',
          deadline: null,
          priority: null,
          startHour: start.hour + (start.minute / 60.0),
          endDate: null,
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
          ),
          occurrenceOverrides: const {},
        );
        undoBaseTaskId = recurring.id;
        final DateTime secondOccurrence = start.add(const Duration(days: 1));
        undoOccurrenceId =
            '${recurring.id}::${secondOccurrence.microsecondsSinceEpoch}';
        final model = CalendarModel.empty().addTask(recurring);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) async {
        bloc
          ..add(CalendarEvent.selectionModeEntered(taskId: undoBaseTaskId))
          ..add(CalendarEvent.selectionToggled(taskId: undoOccurrenceId));
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const CalendarEvent.selectionTitleChanged(title: 'Updated title'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CalendarEvent.undoRequested());
      },
      expect: () => [
        predicate<CalendarState>(
          (state) =>
              state.isSelectionMode &&
              state.selectedTaskIds.length == 1 &&
              state.selectedTaskIds.contains(undoBaseTaskId),
        ),
        predicate<CalendarState>(
          (state) =>
              state.isSelectionMode &&
              state.selectedTaskIds.length == 2 &&
              state.selectedTaskIds.containsAll(
                {undoBaseTaskId, undoOccurrenceId},
              ),
        ),
        predicate<CalendarState>((state) {
          final CalendarTask base = state.model.tasks[undoBaseTaskId]!;
          final Map<String, TaskOccurrenceOverride> overrides =
              base.occurrenceOverrides;
          final String key = undoOccurrenceId.split('::').last;
          final TaskOccurrenceOverride? override = overrides[key];
          return state.isSelectionMode &&
              state.selectedTaskIds.containsAll(
                {undoBaseTaskId, undoOccurrenceId},
              ) &&
              override?.title == 'Updated title';
        }),
        predicate<CalendarState>((state) {
          final CalendarTask base = state.model.tasks[undoBaseTaskId]!;
          return state.isSelectionMode &&
              state.selectedTaskIds.containsAll(
                {undoBaseTaskId, undoOccurrenceId},
              ) &&
              base.occurrenceOverrides.isEmpty &&
              base.title == 'Recurring base';
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'selectionToggled retains existing recurring selections when adding another occurrence',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final DateTime start = DateTime(2024, 1, 8, 9);
        final CalendarTask recurring = CalendarTask(
          id: 'recurring-task',
          title: 'Standup',
          description: null,
          scheduledTime: start,
          duration: const Duration(minutes: 30),
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
          location: null,
          deadline: null,
          priority: null,
          startHour: start.hour + (start.minute / 60.0),
          endDate: null,
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            interval: 1,
          ),
          occurrenceOverrides: const {},
        );
        final model = CalendarModel.empty().addTask(recurring);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final baseTask = bloc.state.model.tasks['recurring-task']!;
        final secondOccurrenceStart = baseTask.scheduledTime!.add(
          const Duration(days: 1),
        );
        final thirdOccurrenceStart = baseTask.scheduledTime!.add(
          const Duration(days: 2),
        );

        final secondOccurrenceId =
            '${baseTask.id}::${secondOccurrenceStart.microsecondsSinceEpoch}';
        final thirdOccurrenceId =
            '${baseTask.id}::${thirdOccurrenceStart.microsecondsSinceEpoch}';

        bloc
          ..add(CalendarEvent.selectionModeEntered(taskId: baseTask.id))
          ..add(CalendarEvent.selectionToggled(taskId: secondOccurrenceId))
          ..add(CalendarEvent.selectionToggled(taskId: thirdOccurrenceId));
      },
      expect: () => [
        predicate<CalendarState>(
          (state) =>
              state.isSelectionMode &&
              state.selectedTaskIds.length == 1 &&
              state.selectedTaskIds.contains('recurring-task'),
        ),
        predicate<CalendarState>(
          (state) =>
              state.isSelectionMode &&
              state.selectedTaskIds.length == 2 &&
              state.selectedTaskIds.contains('recurring-task') &&
              state.selectedTaskIds.any(
                (id) => id.startsWith('recurring-task::'),
              ),
        ),
        predicate<CalendarState>(
          (state) =>
              state.isSelectionMode &&
              state.selectedTaskIds.length == 3 &&
              state.selectedTaskIds.contains('recurring-task') &&
              state.selectedTaskIds
                      .where((id) => id.startsWith('recurring-task::'))
                      .length ==
                  2,
        ),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'selectionTitleChanged applies overrides for recurring occurrences only',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final DateTime start = DateTime(2024, 3, 10, 10);
        final CalendarTask recurring = CalendarTask(
          id: 'series-task',
          title: 'Daily Sync',
          description: 'Discuss blockers',
          scheduledTime: start,
          duration: const Duration(minutes: 30),
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
          location: 'Room 1',
          deadline: null,
          priority: null,
          startHour: start.hour + (start.minute / 60.0),
          endDate: null,
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            interval: 1,
          ),
          occurrenceOverrides: const {},
        );
        final DateTime secondOccurrenceStart =
            start.add(const Duration(days: 1));
        final String occurrenceId =
            '${recurring.id}::${secondOccurrenceStart.microsecondsSinceEpoch}';
        final model = CalendarModel.empty().addTask(recurring);
        return CalendarState.initial().copyWith(
          model: model,
          isSelectionMode: true,
          selectedTaskIds: {occurrenceId},
        );
      },
      act: (bloc) => bloc.add(
        const CalendarEvent.selectionTitleChanged(title: 'Updated Sync'),
      ),
      expect: () => [
        predicate<CalendarState>((state) {
          final CalendarTask base = state.model.tasks['series-task']!;
          final overrides = base.occurrenceOverrides;
          final DateTime start = base.scheduledTime!;
          final String occurrenceKey = start
              .add(const Duration(days: 1))
              .microsecondsSinceEpoch
              .toString();
          final TaskOccurrenceOverride? override = overrides[occurrenceKey];
          return base.title == 'Daily Sync' &&
              override != null &&
              override.title == 'Updated Sync';
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
        isA<CalendarState>().having(
          (state) => state.isLoading,
          'isLoading',
          true,
        ),
        predicate<CalendarState>((state) {
          return state.model.tasks.values
              .any((task) => task.title == 'New Task');
        }),
      ],
    );

    late CalendarTask seededTask;
    late CalendarTask selectionTaskA;
    late CalendarTask selectionTaskB;
    late String occurrenceId;

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
        isA<CalendarState>().having(
          (state) => state.isLoading,
          'isLoading',
          true,
        ),
        predicate<CalendarState>((state) {
          final tasks = state.model.tasks;
          return tasks.isNotEmpty && tasks.values.first.title == 'Updated';
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'quickTaskAdded creates task from text input',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      act: (bloc) {
        bloc.add(const CalendarEvent.quickTaskAdded(text: 'Draft report'));
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'add')).called(1);
      },
      expect: () => [
        isA<CalendarState>().having(
          (state) => state.isLoading,
          'isLoading',
          true,
        ),
        predicate<CalendarState>((state) {
          return state.model.tasks.isNotEmpty &&
              state.model.tasks.values.first.title.isNotEmpty &&
              !state.isLoading;
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
        isA<CalendarState>().having(
          (state) => state.isLoading,
          'isLoading',
          true,
        ),
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
        isA<CalendarState>().having(
          (state) => state.isLoading,
          'isLoading',
          true,
        ),
        predicate<CalendarState>((state) {
          final tasks = state.model.tasks;
          return tasks.isNotEmpty && tasks.values.first.isCompleted;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskDropped repositions task and preserves duration',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final start = DateTime(2024, 2, 3, 9, 15);
        seededTask = CalendarTask(
          id: 'drop-task',
          title: 'Move me',
          description: null,
          scheduledTime: start,
          duration: const Duration(hours: 2),
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
          location: null,
          deadline: null,
          priority: null,
          startHour: start.hour + (start.minute / 60.0),
          endDate: start.add(const Duration(hours: 2)),
          recurrence: null,
          occurrenceOverrides: const {},
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime newStart = seededTask.scheduledTime!
            .add(const Duration(days: 1, hours: 1, minutes: 30));
        bloc.add(
          CalendarEvent.taskDropped(
            taskId: seededTask.id,
            time: newStart,
          ),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final updated = state.model.tasks[seededTask.id]!;
          final DateTime newStart = seededTask.scheduledTime!
              .add(const Duration(days: 1, hours: 1, minutes: 30));
          final Duration duration = seededTask.duration!;
          final double expectedStartHour =
              newStart.hour + (newStart.minute / 60.0);
          return updated.scheduledTime == newStart &&
              updated.duration == duration &&
              updated.endDate == newStart.add(duration) &&
              updated.startHour != null &&
              (updated.startHour! - expectedStartHour).abs() < 1e-6;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskRepeated clones template for copy/paste',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(
          title: 'Template',
          scheduledTime: DateTime(2024, 1, 1, 8),
          duration: const Duration(hours: 1),
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime newStart =
            seededTask.scheduledTime!.add(const Duration(hours: 2));
        bloc.add(
          CalendarEvent.taskRepeated(
            template: seededTask,
            scheduledTime: newStart,
          ),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'add')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final tasks = state.model.tasks.values;
          final clones = tasks.where((task) => task.id != seededTask.id);
          return clones.length == 1 &&
              clones.first.scheduledTime ==
                  seededTask.scheduledTime!.add(
                    const Duration(hours: 2),
                  );
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'commitTaskInteraction schedules unscheduled task',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(title: 'Unschedule me');
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime newStart = DateTime(2024, 1, 1, 9);
        bloc.commitTaskInteraction(
          seededTask.normalizedForInteraction(newStart),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final updated = state.model.tasks[seededTask.id];
          return updated?.scheduledTime == DateTime(2024, 1, 1, 9) &&
              updated?.duration?.inMinutes == 60;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'commitTaskInteraction resizes scheduled task when duration changes',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(
          title: 'Resize me',
          scheduledTime: DateTime(2024, 1, 1, 8),
          duration: const Duration(hours: 1),
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime newStart = seededTask.scheduledTime!.add(
          const Duration(hours: 1),
        );
        final CalendarTask normalized = seededTask.withScheduled(
          scheduledTime: newStart,
          duration: const Duration(hours: 2),
        );
        bloc.commitTaskInteraction(normalized);
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final updated = state.model.tasks[seededTask.id];
          return updated?.scheduledTime ==
                  seededTask.scheduledTime!.add(
                    const Duration(hours: 1),
                  ) &&
              updated?.duration?.inHours == 2;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'commitTaskInteraction updates occurrence overrides',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(
          title: 'Recurring task',
          scheduledTime: DateTime(2024, 1, 1, 9),
          duration: const Duration(hours: 1),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
          ),
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime occurrenceStart =
            seededTask.scheduledTime!.add(const Duration(days: 1));
        final String occurrenceId =
            '${seededTask.id}::${occurrenceStart.microsecondsSinceEpoch}';
        final CalendarTask occurrence = seededTask.copyWith(
          id: occurrenceId,
          scheduledTime: occurrenceStart,
        );
        final DateTime newStart = occurrenceStart.add(const Duration(hours: 1));
        final CalendarTask normalized =
            occurrence.normalizedForInteraction(newStart);
        bloc.commitTaskInteraction(normalized);
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final CalendarTask? base = state.model.tasks[seededTask.id];
          if (base == null) {
            return false;
          }
          final DateTime occurrenceStart =
              seededTask.scheduledTime!.add(const Duration(days: 1));
          final String occurrenceKey = occurrenceKeyFrom(
                  '${seededTask.id}::${occurrenceStart.microsecondsSinceEpoch}') ??
              '';
          final TaskOccurrenceOverride? override =
              base.occurrenceOverrides[occurrenceKey];
          if (override == null) {
            return false;
          }
          return override.scheduledTime ==
                  occurrenceStart.add(const Duration(hours: 1)) &&
              override.duration?.inHours == 1;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'selectionTimeShifted moves selected tasks forward',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        selectionTaskA = CalendarTask.create(
          title: 'A',
          scheduledTime: DateTime(2024, 1, 1, 8),
          duration: const Duration(hours: 1),
        );
        selectionTaskB = CalendarTask.create(
          title: 'B',
          scheduledTime: DateTime(2024, 1, 1, 10),
          duration: const Duration(hours: 1),
        );
        var model = CalendarModel.empty();
        model = model.addTask(selectionTaskA);
        model = model.addTask(selectionTaskB);
        return CalendarState.initial().copyWith(
          model: model,
          isSelectionMode: true,
          selectedTaskIds: {selectionTaskA.id, selectionTaskB.id},
        );
      },
      act: (bloc) {
        bloc.add(
          const CalendarEvent.selectionTimeShifted(
            startDelta: Duration(hours: 1),
          ),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(2);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final updatedA = state.model.tasks[selectionTaskA.id];
          final updatedB = state.model.tasks[selectionTaskB.id];
          return updatedA?.scheduledTime ==
                  selectionTaskA.scheduledTime!.add(const Duration(hours: 1)) &&
              updatedB?.scheduledTime ==
                  selectionTaskB.scheduledTime!.add(const Duration(hours: 1));
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'selectionModeEntered selects only requested recurring base task',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(
          title: 'Recurring base',
          scheduledTime: DateTime(2024, 1, 1, 8),
          duration: const Duration(hours: 1),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
          ),
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        bloc.add(
          CalendarEvent.selectionModeEntered(taskId: seededTask.id),
        );
      },
      expect: () => [
        predicate<CalendarState>((state) {
          return state.isSelectionMode &&
              state.selectedTaskIds.length == 1 &&
              state.selectedTaskIds.contains(seededTask.id);
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'selectionToggled adds only the chosen occurrence',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        seededTask = CalendarTask.create(
          title: 'Recurring task',
          scheduledTime: DateTime(2024, 1, 1, 9),
          duration: const Duration(hours: 1),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
          ),
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime occurrenceStart =
            seededTask.scheduledTime!.add(const Duration(days: 1));
        occurrenceId =
            '${seededTask.id}::${occurrenceStart.microsecondsSinceEpoch}';
        bloc
          ..add(
            CalendarEvent.selectionModeEntered(taskId: seededTask.id),
          )
          ..add(
            CalendarEvent.selectionToggled(taskId: occurrenceId),
          );
      },
      expect: () => [
        predicate<CalendarState>(
          (state) =>
              state.isSelectionMode &&
              state.selectedTaskIds.length == 1 &&
              state.selectedTaskIds.contains(seededTask.id),
        ),
        predicate<CalendarState>(
          (state) =>
              state.isSelectionMode &&
              state.selectedTaskIds.length == 2 &&
              state.selectedTaskIds.contains(seededTask.id) &&
              state.selectedTaskIds.contains(occurrenceId),
        ),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskDropped schedules unscheduled task',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final created = DateTime(2024, 6, 1, 8);
        seededTask = CalendarTask(
          id: 'unscheduled-task',
          title: 'Inbox item',
          description: null,
          scheduledTime: null,
          duration: const Duration(minutes: 45),
          isCompleted: false,
          createdAt: created,
          modifiedAt: created,
          location: null,
          deadline: null,
          priority: null,
          startHour: null,
          endDate: null,
          recurrence: null,
          occurrenceOverrides: const {},
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime target = DateTime(2024, 6, 12, 10, 15);
        bloc.add(
          CalendarEvent.taskDropped(
            taskId: seededTask.id,
            time: target,
          ),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final scheduled = state.model.tasks[seededTask.id]!;
          final double expectedHour = scheduled.scheduledTime!.hour +
              (scheduled.scheduledTime!.minute / 60.0);
          return scheduled.scheduledTime == DateTime(2024, 6, 12, 10, 15) &&
              scheduled.duration == const Duration(minutes: 45) &&
              scheduled.startHour != null &&
              (scheduled.startHour! - expectedHour).abs() < 1e-6;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskSplit divides task without explicit duration using fallback window',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final start = DateTime(2024, 4, 12, 9, 0);
        seededTask = CalendarTask(
          id: 'split-base-task',
          title: 'Split target',
          description: null,
          scheduledTime: start,
          duration: null,
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
          location: null,
          deadline: null,
          priority: null,
          startHour: start.hour + (start.minute / 60.0),
          endDate: null,
          recurrence: null,
          occurrenceOverrides: const {},
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime splitTime =
            seededTask.scheduledTime!.add(const Duration(minutes: 30));
        bloc.add(
          CalendarEvent.taskSplit(
            target: seededTask,
            splitTime: splitTime,
          ),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
        verify(() => syncManager.sendTaskUpdate(any(), 'add')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final CalendarTask base = state.model.tasks['split-base-task']!;
          final List<CalendarTask> additions = state.model.tasks.values
              .where((task) => task.id != 'split-base-task')
              .toList();
          if (additions.length != 1) {
            return false;
          }
          final CalendarTask clone = additions.first;
          final DateTime splitMoment =
              seededTask.scheduledTime!.add(const Duration(minutes: 30));
          return base.duration == const Duration(minutes: 30) &&
              clone.duration == const Duration(minutes: 30) &&
              clone.scheduledTime == splitMoment &&
              clone.recurrence == null;
        }),
      ],
    );

    late CalendarTask splitOccurrence;
    late DateTime splitMoment;

    blocTest<CalendarBloc, CalendarState>(
      'taskSplit on recurring occurrence stores override and follow-up segment',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final start = DateTime(2024, 5, 1, 14, 0);
        seededTask = CalendarTask(
          id: 'series-task',
          title: 'Series',
          description: null,
          scheduledTime: start,
          duration: const Duration(hours: 2),
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
          location: null,
          deadline: null,
          priority: null,
          startHour: start.hour + (start.minute / 60.0),
          endDate: null,
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
          ),
          occurrenceOverrides: const {},
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime rangeStart =
            seededTask.scheduledTime!.add(const Duration(days: 1));
        final DateTime rangeEnd = rangeStart.add(const Duration(hours: 4));
        final List<CalendarTask> occurrences =
            seededTask.occurrencesWithin(rangeStart, rangeEnd);
        splitOccurrence = occurrences.first;
        splitMoment =
            splitOccurrence.scheduledTime!.add(const Duration(hours: 1));

        bloc.add(
          CalendarEvent.taskSplit(
            target: splitOccurrence,
            splitTime: splitMoment,
          ),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'update')).called(1);
        verify(() => syncManager.sendTaskUpdate(any(), 'add')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final CalendarTask base = state.model.tasks['series-task']!;
          final String overrideKey = occurrenceKeyFrom(splitOccurrence.id)!;
          final TaskOccurrenceOverride? override =
              base.occurrenceOverrides[overrideKey];
          if (override == null) {
            return false;
          }
          final Iterable<CalendarTask> extras = state.model.tasks.values
              .where((task) => task.id != 'series-task');
          if (extras.length != 1) {
            return false;
          }
          final CalendarTask clone = extras.first;
          final DateTime expectedLeftEnd =
              override.scheduledTime!.add(const Duration(hours: 1));
          final DateTime expectedRightEnd =
              clone.scheduledTime!.add(const Duration(hours: 1));
          return override.duration == const Duration(hours: 1) &&
              clone.duration == const Duration(hours: 1) &&
              clone.scheduledTime == splitMoment &&
              clone.recurrence == null &&
              (override.endDate == null ||
                  override.endDate == expectedLeftEnd) &&
              (clone.endDate == null || clone.endDate == expectedRightEnd);
        }),
      ],
    );

    late DateTime pasteStart;

    blocTest<CalendarBloc, CalendarState>(
      'taskRepeated maintains duration window when pasted to new slot',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final start = DateTime(2024, 6, 10, 9);
        seededTask = CalendarTask(
          id: 'multi-day-task',
          title: 'Multi Day',
          description: null,
          scheduledTime: start,
          duration: null,
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
          location: null,
          deadline: null,
          priority: null,
          startHour: start.hour + (start.minute / 60.0),
          endDate: start.add(const Duration(days: 2)),
          recurrence: null,
          occurrenceOverrides: const {},
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        pasteStart =
            seededTask.scheduledTime!.add(const Duration(days: 5, hours: 2));
        bloc.add(
          CalendarEvent.taskRepeated(
            template: seededTask,
            scheduledTime: pasteStart,
          ),
        );
      },
      verify: (_) {
        verify(() => syncManager.sendTaskUpdate(any(), 'add')).called(1);
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final Iterable<CalendarTask> extras = state.model.tasks.values
              .where((task) => task.id != 'multi-day-task');
          if (extras.length != 1) {
            return false;
          }
          final CalendarTask clone = extras.first;
          final DateTime pasteStart =
              seededTask.scheduledTime!.add(const Duration(days: 5, hours: 2));
          final Duration offset =
              seededTask.endDate!.difference(seededTask.scheduledTime!);
          final DateTime expectedEnd = pasteStart.add(offset);
          return clone.scheduledTime == pasteStart &&
              clone.duration == offset &&
              clone.endDate == expectedEnd;
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskResized updates end date when duration changes',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final start = DateTime(2024, 7, 2, 11, 0);
        seededTask = CalendarTask(
          id: 'resize-target',
          title: 'Resize me',
          scheduledTime: start,
          duration: const Duration(hours: 1),
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime newEnd =
            seededTask.scheduledTime!.add(const Duration(hours: 2));
        bloc.add(
          CalendarEvent.taskResized(
            taskId: seededTask.id,
            scheduledTime: seededTask.scheduledTime,
            duration: const Duration(hours: 2),
            endDate: newEnd,
          ),
        );
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final updated = state.model.tasks[seededTask.id]!;
          return updated.duration == const Duration(hours: 2) &&
              updated.endDate ==
                  seededTask.scheduledTime!.add(const Duration(hours: 2));
        }),
      ],
    );

    blocTest<CalendarBloc, CalendarState>(
      'taskResized recomputes end when only start changes',
      build: () => CalendarBloc(
        syncManagerBuilder: (_) => syncManager,
        storage: storage,
      ),
      seed: () {
        final start = DateTime(2024, 7, 2, 11, 0);
        seededTask = CalendarTask(
          id: 'resize-move',
          title: 'Move & keep span',
          scheduledTime: start,
          duration: const Duration(hours: 1, minutes: 30),
          isCompleted: false,
          createdAt: start,
          modifiedAt: start,
        );
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final DateTime shifted =
            seededTask.scheduledTime!.add(const Duration(minutes: 45));
        bloc.add(
          CalendarEvent.taskResized(
            taskId: seededTask.id,
            scheduledTime: shifted,
          ),
        );
      },
      expect: () => [
        predicate<CalendarState>((state) {
          final updated = state.model.tasks[seededTask.id]!;
          return updated.scheduledTime ==
                  seededTask.scheduledTime!.add(const Duration(minutes: 45)) &&
              updated.duration == seededTask.duration &&
              updated.endDate ==
                  seededTask.scheduledTime!
                      .add(const Duration(minutes: 45))
                      .add(seededTask.duration!);
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
