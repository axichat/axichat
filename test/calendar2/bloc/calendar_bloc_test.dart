import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/calendar2/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar2/bloc/calendar_event.dart';
import 'package:axichat/src/calendar2/models/calendar_model.dart';
import 'package:axichat/src/calendar2/storage/guest_calendar_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Future<void> pumpEventQueue([int times = 20]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('calendar2_bloc_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('guest_calendar');
    await Hive.deleteBoxFromDisk('calendar');
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('adds task to model', () async {
    final storage = await buildGuestCalendarStorage();
    final bloc = CalendarBloc(storage: storage);

    bloc.add(const CalendarEvent.taskAdded(title: 'Task'));
    await pumpEventQueue();

    expect(bloc.state.model.tasks.length, 1);
    await bloc.close();
  });

  test('marks task as completed', () async {
    final storage = await buildGuestCalendarStorage();
    final bloc = CalendarBloc(storage: storage);

    bloc.add(const CalendarEvent.taskAdded(title: 'Task'));
    await pumpEventQueue();
    final taskId = bloc.state.model.tasks.values.first.id;

    bloc.add(CalendarEvent.taskCompleted(taskId: taskId, completed: true));
    await pumpEventQueue();

    expect(bloc.state.model.tasks[taskId]!.completed, isTrue);
    await bloc.close();
  });

  test('persists state across instances', () async {
    final storage = await buildGuestCalendarStorage();
    final bloc = CalendarBloc(storage: storage);

    bloc.add(const CalendarEvent.taskAdded(title: 'Persisted'));
    await pumpEventQueue();
    await bloc.close();

    final restoredStorage = await buildGuestCalendarStorage();
    final raw = restoredStorage.read('calendar_state') as String?;
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    final restoredModel = CalendarModel.fromJson(
      Map<String, dynamic>.from(decoded['model'] as Map),
    );
    expect(restoredModel.tasks.length, 1);
    final restored = CalendarBloc(storage: restoredStorage);
    await pumpEventQueue();

    expect(restored.state.model.tasks.length, 1);
    await restored.close();
  });

  test('taskDropped schedules unscheduled task with default duration',
      () async {
    final storage = await buildGuestCalendarStorage();
    final bloc = CalendarBloc(storage: storage);

    bloc.add(const CalendarEvent.taskAdded(title: 'Schedule me'));
    await pumpEventQueue();

    final taskId = bloc.state.model.tasks.values.first.id;
    final target = DateTime(2024, 9, 15, 9);

    bloc.add(CalendarEvent.taskDropped(taskId: taskId, time: target));
    await pumpEventQueue();

    final updated = bloc.state.model.tasks[taskId]!;
    expect(updated.scheduledStart, target);
    expect(updated.duration, const Duration(hours: 1));

    await bloc.close();
  });

  test('taskAdded with schedule sets duration', () async {
    final storage = await buildGuestCalendarStorage();
    final bloc = CalendarBloc(storage: storage);

    final start = DateTime(2025, 1, 10, 10);
    bloc.add(
      CalendarEvent.taskAdded(
        title: 'Standup',
        scheduledStart: start,
        duration: const Duration(minutes: 30),
      ),
    );
    await pumpEventQueue();

    final task = bloc.state.model.tasks.values.first;
    expect(task.scheduledStart, start);
    expect(task.duration, const Duration(minutes: 30));
    expect(task.completed, isFalse);
    await bloc.close();
  });
}
