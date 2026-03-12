import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

void main() {
  test(
    'sync timestamp recording stays monotonic within one clock tick',
    () async {
      final storage = _InMemoryStorage();
      HydratedBloc.storage = storage;
      final fixedNow = DateTime(2026, 3, 12, 10, 30);
      final bloc = _TestCalendarBloc(storage: storage, now: () => fixedNow);
      final emittedStates = <CalendarState>[];
      final subscription = bloc.stream.listen(emittedStates.add);
      addTearDown(() async {
        await subscription.cancel();
        await bloc.close();
      });

      bloc.add(const CalendarEvent.syncTimestampRecorded());
      await pumpEventQueue();
      bloc.add(const CalendarEvent.syncTimestampRecorded());
      await pumpEventQueue();

      expect(emittedStates, hasLength(2));
      expect(emittedStates.first.lastSyncTime, fixedNow);
      expect(
        emittedStates.last.lastSyncTime,
        fixedNow.add(const Duration(microseconds: 1)),
      );
    },
  );
}

class _TestCalendarBloc extends BaseCalendarBloc {
  _TestCalendarBloc({
    required super.storage,
    required DateTime Function() super.now,
  }) : super(storagePrefix: 'test-calendar');

  @override
  Future<void> onTaskAdded(CalendarTask task) async {}

  @override
  Future<void> onTaskUpdated(CalendarTask task) async {}

  @override
  Future<void> onTaskDeleted(CalendarTask task) async {}

  @override
  Future<void> onTaskCompleted(CalendarTask task) async {}

  @override
  Future<void> onDayEventAdded(DayEvent event) async {}

  @override
  Future<void> onDayEventUpdated(DayEvent event) async {}

  @override
  Future<void> onDayEventDeleted(DayEvent event) async {}

  @override
  void logError(String message, Object error) {}
}

class _InMemoryStorage implements Storage {
  final Map<String, dynamic> _store = <String, dynamic>{};

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}
}
