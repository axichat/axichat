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
          final Duration offset = seededTask.endDate!
              .difference(seededTask.scheduledTime!);
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
        final DateTime newEnd = seededTask.scheduledTime!.add(const Duration(hours: 2));
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
              updated.endDate == seededTask.scheduledTime!.add(const Duration(hours: 2));
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
        final DateTime shifted = seededTask.scheduledTime!.add(const Duration(minutes: 45));
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
