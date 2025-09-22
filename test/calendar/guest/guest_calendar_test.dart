import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/guest/guest_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
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

void main() {
  group('GuestCalendarBloc', () {
    late _InMemoryStorage storage;
    late GuestCalendarBloc bloc;
    late CalendarStorageRegistry registry;

    setUp(() {
      storage = _InMemoryStorage();
      registry = CalendarStorageRegistry(fallback: storage);
      registry.registerPrefix(guestStoragePrefix, storage);
      HydratedBloc.storage = registry;
      bloc = GuestCalendarBloc(storage: storage);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state is empty calendar', () {
      expect(bloc.state.model.tasks, isEmpty);
      expect(bloc.state.viewMode, CalendarView.week);
    });

    blocTest<GuestCalendarBloc, CalendarState>(
      'taskAdded inserts a new task',
      build: () => bloc,
      act: (bloc) =>
          bloc.add(const CalendarEvent.taskAdded(title: 'Guest task')),
      expect: () => [
        isA<CalendarState>().having(
          (state) => state.isLoading,
          'isLoading',
          true,
        ),
        predicate<CalendarState>((state) {
          return state.model.tasks.values
              .any((task) => task.title == 'Guest task');
        }),
      ],
    );

    late CalendarTask seededTask;

    blocTest<GuestCalendarBloc, CalendarState>(
      'taskUpdated replaces existing task',
      build: () {
        storage.clear();
        return GuestCalendarBloc(storage: storage);
      },
      seed: () {
        seededTask = CalendarTask.create(title: 'Original');
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        final existing = bloc.state.model.tasks.values.first;
        bloc.add(CalendarEvent.taskUpdated(
          task: existing.copyWith(title: 'Updated'),
        ));
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

    blocTest<GuestCalendarBloc, CalendarState>(
      'taskDeleted removes task',
      build: () {
        storage.clear();
        return GuestCalendarBloc(storage: storage);
      },
      seed: () {
        seededTask = CalendarTask.create(title: 'Delete');
        final model = CalendarModel.empty().addTask(seededTask);
        return CalendarState.initial().copyWith(model: model);
      },
      act: (bloc) {
        bloc.add(CalendarEvent.taskDeleted(taskId: seededTask.id));
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
  });
}
