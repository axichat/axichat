import 'dart:async';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/calendar_grid.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MockCalendarBloc extends MockBloc<CalendarEvent, CalendarState>
    implements CalendarBloc {}

bool _calendarFallbacksRegistered = false;

void registerCalendarFallbackValues() {
  if (_calendarFallbacksRegistered) {
    return;
  }
  _calendarFallbacksRegistered = true;
  registerFallbackValue(const CalendarEvent.started());
  registerFallbackValue(CalendarState.initial());
}

class CalendarTestData {
  static final DateTime baseDate = DateTime(2024, 1, 15, 9);
  static final DateTime creationStamp = DateTime(2024, 1, 1, 8);

  static CalendarTask scheduled(
    String id,
    String title,
    DateTime start, {
    Duration duration = const Duration(minutes: 60),
    TaskPriority priority = TaskPriority.none,
    String? location,
  }) {
    return CalendarTask(
      id: id,
      title: title,
      description: null,
      scheduledTime: start,
      duration: duration,
      isCompleted: false,
      createdAt: creationStamp,
      modifiedAt: creationStamp,
      location: location,
      deadline: null,
      priority: priority == TaskPriority.none ? null : priority,
      startHour: start.hour + start.minute / 60,
      endDate: null,
      recurrence: null,
      occurrenceOverrides: const {},
    );
  }

  static CalendarTask recurring(
    String id,
    String title,
    DateTime start,
    RecurrenceRule recurrence, {
    Duration duration = const Duration(minutes: 45),
  }) {
    return CalendarTask(
      id: id,
      title: title,
      description: null,
      scheduledTime: start,
      duration: duration,
      isCompleted: false,
      createdAt: creationStamp,
      modifiedAt: creationStamp,
      location: 'Studio 2',
      deadline: null,
      priority: TaskPriority.important,
      startHour: start.hour + start.minute / 60,
      endDate: null,
      recurrence: recurrence,
      occurrenceOverrides: const {},
    );
  }

  static CalendarTask unscheduled(String id, String title) {
    return CalendarTask(
      id: id,
      title: title,
      description: 'Prep list and resources',
      scheduledTime: null,
      duration: const Duration(minutes: 45),
      isCompleted: false,
      createdAt: creationStamp,
      modifiedAt: creationStamp,
      location: null,
      deadline: DateTime(2024, 1, 20, 12),
      priority: TaskPriority.urgent,
      startHour: null,
      endDate: null,
      recurrence: null,
      occurrenceOverrides: const {},
    );
  }

  static CalendarModel buildModel() {
    final recurrence = RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      interval: 1,
      count: 5,
      byWeekdays: const [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ],
    );

    final tasks = <String, CalendarTask>{
      'task-weekly-sync': scheduled(
        'task-weekly-sync',
        'Weekly Sync',
        DateTime(2024, 1, 15, 9),
        duration: const Duration(minutes: 90),
        priority: TaskPriority.important,
      ),
      'task-design-review': scheduled(
        'task-design-review',
        'Design Review',
        DateTime(2024, 1, 15, 13),
        duration: const Duration(minutes: 90),
      ),
      'task-overlap-a': scheduled(
        'task-overlap-a',
        'Pairing Session',
        DateTime(2024, 1, 16, 10),
        duration: const Duration(minutes: 60),
      ),
      'task-overlap-b': scheduled(
        'task-overlap-b',
        'Architecture Review',
        DateTime(2024, 1, 16, 10, 30),
        duration: const Duration(minutes: 75),
        priority: TaskPriority.important,
      ),
      'task-recurring-standup': recurring(
        'task-recurring-standup',
        'Recurring Standup',
        DateTime(2024, 1, 15, 9, 30),
        recurrence,
      ),
      'task-unscheduled': unscheduled('task-unscheduled', 'Prep Meeting Notes'),
      'task-unscheduled-2': unscheduled('task-unscheduled-2', 'Draft Agenda'),
    };

    return CalendarModel(
      tasks: tasks,
      lastModified: DateTime(2024, 1, 19, 9),
      checksum: 'calendar-test-checksum',
    );
  }

  static CalendarState baseState() {
    final model = buildModel();
    return CalendarState(
      model: model,
      selectedDate: baseDate,
      selectedDayIndex: 0,
      viewMode: CalendarView.week,
      canUndo: false,
      canRedo: false,
      nextTask: model.tasks['task-weekly-sync'],
      dueReminders: [model.tasks['task-unscheduled']!],
    );
  }

  static CalendarState weekView() => baseState();

  static CalendarState dayView() => baseState().copyWith(
        viewMode: CalendarView.day,
        selectedDayIndex: 1,
      );

  static CalendarState selectionMode() => baseState().copyWith(
        viewMode: CalendarView.day,
        selectedDayIndex: 0,
        isSelectionMode: true,
        selectedTaskIds: {
          'task-overlap-a',
          'task-overlap-b',
        },
      );

  static String dayLabel(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final index = (date.weekday - 1) % days.length;
    final prefix = days[index];
    return '$prefix ${date.day}';
  }
}

class CalendarWidgetHarness {
  CalendarWidgetHarness._({
    required this.tester,
    required this.bloc,
    required CalendarState initialState,
    required this.size,
    required StreamController<CalendarState> stateController,
  })  : _stateController = stateController,
        _currentState = initialState,
        gridFinder = find.byWidgetPredicate(
          (widget) => widget is CalendarGrid<CalendarBloc>,
        );

  final WidgetTester tester;
  final MockCalendarBloc bloc;
  final Size size;
  final Finder gridFinder;
  final StreamController<CalendarState> _stateController;
  CalendarState _currentState;
  void Function(CalendarState)? _onStateEmitted;
  double? _minuteHeightCache;
  double? _gridBodyTopCache;

  CalendarState get currentState => _currentState;

  Future<void> pumpState(CalendarState newState) async {
    _currentState = newState;
    _minuteHeightCache = null;
    _gridBodyTopCache = null;
    _onStateEmitted?.call(newState);
    _stateController.add(newState);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  void _registerStateListener(void Function(CalendarState) listener) {
    _onStateEmitted = listener;
  }

  DateTime dayDateForIndex(int index) {
    final state = _currentState;
    if (state.viewMode == CalendarView.day) {
      final selected = state.selectedDate;
      return DateTime(selected.year, selected.month, selected.day);
    }
    return state.weekStart.add(Duration(days: index));
  }

  Rect taskRect(String taskId) {
    final finder = find.byKey(ValueKey(taskId));
    expect(
      finder,
      findsOneWidget,
      reason: 'Task "$taskId" should be rendered in the calendar grid.',
    );
    return tester.getRect(finder);
  }

  Future<void> rightClickTask(String taskId) async {
    final rect = taskRect(taskId);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(rect.center);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  double verticalScrollOffset() {
    final scrollableFinder = find.descendant(
      of: gridFinder,
      matching: find.byType(Scrollable),
    );
    for (final element in scrollableFinder.evaluate()) {
      final scrollableState = tester.state<ScrollableState>(
        find.byWidget(element.widget),
      );
      if (scrollableState.axisDirection == AxisDirection.down) {
        return scrollableState.position.pixels;
      }
    }
    return 0;
  }

  Offset slotPosition(int dayIndex, Duration timeOfDay) {
    final state = _currentState;
    final resolvedDayCount = state.viewMode == CalendarView.day ? 1 : 7;
    assert(
      dayIndex >= 0 && dayIndex < resolvedDayCount,
      'dayIndex $dayIndex is outside of the visible range $resolvedDayCount.',
    );

    final gridRect = tester.getRect(gridFinder);
    final dayWidth = (gridRect.width - _timeColumnWidth) / resolvedDayCount;
    final centerX =
        gridRect.left + _timeColumnWidth + dayWidth * dayIndex + dayWidth / 2;

    final minuteHeight = _resolveMinuteHeight();
    final slotHeight = minuteHeight * _minutesPerSlot;
    final bodyTop = _gridBodyTop();
    final scrollOffset = verticalScrollOffset();
    final minutesFromStart = timeOfDay.inMinutes.toDouble();
    final centerY = bodyTop -
        scrollOffset +
        minutesFromStart * minuteHeight +
        slotHeight / 2;

    return Offset(centerX, centerY);
  }

  static const double _timeColumnWidth = 80;
  static const int _minutesPerSlot = 15;

  double _resolveMinuteHeight() {
    if (_minuteHeightCache != null) {
      return _minuteHeightCache!;
    }

    final bodyTop = _gridBodyTop();
    final scheduledTasks = _currentState.model.tasks.values.where((task) {
      return task.scheduledTime != null &&
          task.duration != null &&
          task.duration!.inMinutes > 0;
    }).toList()
      ..sort((a, b) => a.duration!.inMinutes.compareTo(b.duration!.inMinutes));

    for (final task in scheduledTasks) {
      final finder = find.byKey(ValueKey(task.id));
      if (finder.evaluate().isEmpty) {
        continue;
      }
      final rect = tester.getRect(finder);
      final minutesFromStart = _minutesFromMidnight(task.scheduledTime!);
      if (minutesFromStart == 0) {
        _minuteHeightCache = rect.height / task.duration!.inMinutes;
        return _minuteHeightCache!;
      }
      final derived = (rect.top - bodyTop) / minutesFromStart;
      if (derived.isFinite && derived > 0) {
        _minuteHeightCache = derived;
        return derived;
      }
    }

    if (scheduledTasks.isNotEmpty) {
      final fallbackTask = scheduledTasks.first;
      final finder = find.byKey(ValueKey(fallbackTask.id));
      if (finder.evaluate().isNotEmpty) {
        final rect = tester.getRect(finder);
        _minuteHeightCache = rect.height / fallbackTask.duration!.inMinutes;
        return _minuteHeightCache!;
      }
    }

    _minuteHeightCache = 1;
    return 1;
  }

  double _gridBodyTop() {
    if (_gridBodyTopCache != null) {
      return _gridBodyTopCache!;
    }

    final DateTime referenceDate;
    if (_currentState.viewMode == CalendarView.day) {
      referenceDate = DateTime(
        _currentState.selectedDate.year,
        _currentState.selectedDate.month,
        _currentState.selectedDate.day,
      );
    } else {
      referenceDate = _currentState.weekStart;
    }
    final label = CalendarTestData.dayLabel(referenceDate);
    final headerTextFinder = find.descendant(
      of: gridFinder,
      matching: find.text(label),
    );
    expect(
      headerTextFinder,
      findsOneWidget,
      reason: 'Expected to locate header text "$label" in calendar grid.',
    );
    final headerInkWellFinder = find.ancestor(
      of: headerTextFinder,
      matching: find.byType(InkWell),
    );
    final rect = tester.getRect(headerInkWellFinder);
    _gridBodyTopCache = rect.bottom;
    return rect.bottom;
  }

  static int _minutesFromMidnight(DateTime timestamp) {
    return timestamp.hour * 60 + timestamp.minute;
  }

  static Future<CalendarWidgetHarness> pump({
    required WidgetTester tester,
    CalendarState? state,
    Size size = const Size(1280, 860),
  }) async {
    tester.binding.window.physicalSizeTestValue = Size(size.width, size.height);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    final resolvedState = state ?? CalendarTestData.weekView();
    final bloc = MockCalendarBloc();
    final stateController = StreamController<CalendarState>.broadcast();
    var currentState = resolvedState;

    when(() => bloc.state).thenAnswer((_) => currentState);
    when(() => bloc.stream).thenAnswer((_) => stateController.stream);
    when(() => bloc.add(any<CalendarEvent>())).thenAnswer((_) {});
    when(() => bloc.close()).thenAnswer((_) async {});

    final mediaQueryData = MediaQueryData(
      size: size,
      devicePixelRatio: 1.0,
      textScaler: const TextScaler.linear(0.7),
      padding: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      accessibleNavigation: false,
      boldText: false,
      disableAnimations: false,
      highContrast: false,
      invertColors: false,
      navigationMode: NavigationMode.traditional,
      platformBrightness: Brightness.light,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0F172A),
          brightness: Brightness.light,
        ),
        home: MediaQuery(
          data: mediaQueryData,
          child: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: SizedBox.expand(
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<CalendarBloc>.value(value: bloc),
                  BlocProvider<BaseCalendarBloc>.value(value: bloc),
                ],
                child: const CalendarWidget(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    addTearDown(bloc.close);
    addTearDown(() => stateController.close());

    final harness = CalendarWidgetHarness._(
      tester: tester,
      bloc: bloc,
      initialState: resolvedState,
      size: size,
      stateController: stateController,
    );

    harness._registerStateListener((newState) {
      currentState = newState;
    });

    return harness;
  }
}
