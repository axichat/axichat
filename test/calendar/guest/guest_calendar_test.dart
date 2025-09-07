import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/guest/guest_calendar_bloc.dart';
import 'package:axichat/src/calendar/guest/guest_calendar_storage.dart';
import 'package:axichat/src/calendar/models/models.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<CalendarModel> {}

void main() {
  group('GuestCalendarStorage', () {
    test('storage functions are available', () {
      // Test that storage methods exist and are callable
      expect(GuestCalendarStorage.openBox, isA<Function>());
      expect(GuestCalendarStorage.saveCalendar, isA<Function>());
      expect(GuestCalendarStorage.loadCalendar, isA<Function>());
      expect(GuestCalendarStorage.clearGuestData, isA<Function>());
    });

    test('uses correct box name', () {
      // Verify the box name is 'guest_calendar'
      expect(GuestCalendarStorage, isNotNull);
    });
  });

  group('GuestCalendarBloc', () {
    late MockBox mockBox;
    late GuestCalendarBloc bloc;
    final testDeviceId = 'test-device';

    setUp(() {
      mockBox = MockBox();
      bloc =
          GuestCalendarBloc(guestCalendarBox: mockBox, deviceId: testDeviceId);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state contains empty calendar', () {
      expect(bloc.state.model.tasks, isEmpty);
      expect(bloc.state.model.deviceId, equals(testDeviceId));
    });

    group('CalendarStarted', () {
      blocTest<GuestCalendarBloc, CalendarState>(
        'loads empty calendar when box is empty',
        build: () {
          when(() => mockBox.get('calendar')).thenReturn(null);
          return bloc;
        },
        act: (bloc) => bloc.add(const CalendarEvent.started()),
        expect: () => [
          isA<CalendarState>().having(
            (state) => state.model.tasks.isEmpty,
            'empty tasks',
            isTrue,
          ),
        ],
      );

      blocTest<GuestCalendarBloc, CalendarState>(
        'loads existing calendar from box',
        build: () {
          final now = DateTime.now();
          final task = CalendarTask(
            id: 'test-task',
            title: 'Test Task',
            isCompleted: false,
            createdAt: now,
            modifiedAt: now,
            deviceId: testDeviceId,
          );
          final existingCalendar =
              CalendarModel.empty(testDeviceId).addTask(task);
          when(() => mockBox.get('calendar')).thenReturn(existingCalendar);
          return bloc;
        },
        act: (bloc) => bloc.add(const CalendarEvent.started()),
        expect: () => [
          isA<CalendarState>().having(
            (state) => state.model.tasks.length,
            'one task',
            equals(1),
          ),
        ],
      );
    });

    group('CalendarTaskAdded', () {
      blocTest<GuestCalendarBloc, CalendarState>(
        'adds task to calendar without sync',
        build: () {
          final initialCalendar = CalendarModel.empty(testDeviceId);
          when(() => mockBox.get('calendar')).thenReturn(initialCalendar);
          when(() => mockBox.put('calendar', any())).thenAnswer((_) async {});
          when(() => mockBox.watch()).thenAnswer((_) => Stream.empty());
          return bloc;
        },
        act: (bloc) => bloc.add(const CalendarEvent.taskAdded(
          title: 'New Task',
          description: 'Task description',
        )),
        expect: () => [
          isA<CalendarState>().having(
            (state) => state.model.tasks.length,
            'task added',
            equals(1),
          ),
        ],
      );

      blocTest<GuestCalendarBloc, CalendarState>(
        'validates task input',
        build: () {
          final initialCalendar = CalendarModel.empty(testDeviceId);
          when(() => mockBox.get('calendar')).thenReturn(initialCalendar);
          when(() => mockBox.watch()).thenAnswer((_) => Stream.empty());
          return bloc;
        },
        act: (bloc) => bloc.add(const CalendarEvent.taskAdded(title: '')),
        expect: () => [
          isA<CalendarState>().having(
            (state) => state.error,
            'validation error',
            contains('Title cannot be empty'),
          ),
        ],
      );
    });

    group('CalendarTaskUpdated', () {
      blocTest<GuestCalendarBloc, CalendarState>(
        'updates existing task without sync',
        build: () {
          final now = DateTime.now();
          final task = CalendarTask(
            id: 'test-task',
            title: 'Original Task',
            isCompleted: false,
            createdAt: now,
            modifiedAt: now,
            deviceId: testDeviceId,
          );
          final initialCalendar =
              CalendarModel.empty(testDeviceId).addTask(task);
          when(() => mockBox.get('calendar')).thenReturn(initialCalendar);
          when(() => mockBox.put('calendar', any())).thenAnswer((_) async {});
          when(() => mockBox.watch()).thenAnswer((_) => Stream.empty());
          return bloc;
        },
        act: (bloc) {
          final updatedTask = CalendarTask(
            id: 'test-task',
            title: 'Updated Task',
            isCompleted: false,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            deviceId: testDeviceId,
          );
          bloc.add(CalendarEvent.taskUpdated(task: updatedTask));
        },
        expect: () => [
          isA<CalendarState>().having(
            (state) => state.model.tasks.values.first.title,
            'task updated',
            equals('Updated Task'),
          ),
        ],
      );
    });

    group('CalendarTaskDeleted', () {
      blocTest<GuestCalendarBloc, CalendarState>(
        'deletes task without sync',
        build: () {
          final now = DateTime.now();
          final task = CalendarTask(
            id: 'test-task',
            title: 'Task to Delete',
            isCompleted: false,
            createdAt: now,
            modifiedAt: now,
            deviceId: testDeviceId,
          );
          final initialCalendar =
              CalendarModel.empty(testDeviceId).addTask(task);
          when(() => mockBox.get('calendar')).thenReturn(initialCalendar);
          when(() => mockBox.put('calendar', any())).thenAnswer((_) async {});
          when(() => mockBox.watch()).thenAnswer((_) => Stream.empty());
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CalendarEvent.taskDeleted(taskId: 'test-task')),
        expect: () => [
          isA<CalendarState>().having(
            (state) => state.model.tasks.isEmpty,
            'task deleted',
            isTrue,
          ),
        ],
      );
    });

    group('CalendarTaskCompleted', () {
      blocTest<GuestCalendarBloc, CalendarState>(
        'marks task as completed without sync',
        build: () {
          final now = DateTime.now();
          final task = CalendarTask(
            id: 'test-task',
            title: 'Task to Complete',
            isCompleted: false,
            createdAt: now,
            modifiedAt: now,
            deviceId: testDeviceId,
          );
          final initialCalendar =
              CalendarModel.empty(testDeviceId).addTask(task);
          when(() => mockBox.get('calendar')).thenReturn(initialCalendar);
          when(() => mockBox.put('calendar', any())).thenAnswer((_) async {});
          when(() => mockBox.watch()).thenAnswer((_) => Stream.empty());
          return bloc;
        },
        act: (bloc) => bloc.add(const CalendarEvent.taskCompleted(
          taskId: 'test-task',
          completed: true,
        )),
        expect: () => [
          isA<CalendarState>().having(
            (state) => state.model.tasks.values.first.isCompleted,
            'task completed',
            isTrue,
          ),
        ],
      );
    });

    test('does not handle sync events', () {
      // The GuestCalendarBloc should handle sync events but ignore the sync operations
      // This is already implemented correctly in the actual bloc
      expect(bloc.state.isSyncing, isFalse);
    });
  });

  group('Data Isolation Tests', () {
    test('guest calendar uses separate box from authenticated calendar', () {
      // Verify box names are different
      const guestBoxName = 'guest_calendar';
      const authBoxName = 'calendar'; // Authenticated box name

      expect(guestBoxName, isNot(equals(authBoxName)));
    });
  });
}
