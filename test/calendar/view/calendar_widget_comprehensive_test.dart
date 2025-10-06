import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/calendar_grid.dart';
import 'package:axichat/src/calendar/view/task_sidebar.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _MockCalendarBloc extends MockBloc<CalendarEvent, CalendarState>
    implements CalendarBloc {}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.bloc,
    required this.child,
    required this.size,
  });

  final CalendarBloc bloc;
  final Widget child;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQueryData(
      size: size,
      devicePixelRatio: 1.0,
      textScaler: const TextScaler.linear(1.0),
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

    return MaterialApp(
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
              child: Material(
                type: MaterialType.transparency,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarTestData {
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
      daySpan: 1,
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
      daySpan: 1,
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
      daySpan: 1,
      priority: TaskPriority.urgent,
      startHour: null,
      endDate: null,
      recurrence: null,
      occurrenceOverrides: const {},
    );
  }

  static CalendarModel buildModel() {
    final monday = baseDate;
    final tuesday = DateTime(2024, 1, 16, 13);
    final wednesday = DateTime(2024, 1, 17, 11, 30);
    final thursday = DateTime(2024, 1, 18, 18);
    const recurrence = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      interval: 1,
      byWeekdays: [DateTime.monday, DateTime.wednesday],
    );

    final tasks = <String, CalendarTask>{
      'task-weekly-sync': scheduled(
        'task-weekly-sync',
        'Weekly Sync',
        monday,
        duration: const Duration(minutes: 45),
        priority: TaskPriority.important,
        location: 'All Hands',
      ),
      'task-client-review': scheduled(
        'task-client-review',
        'Client Review',
        tuesday,
        duration: const Duration(minutes: 75),
        priority: TaskPriority.urgent,
        location: 'Zoom',
      ),
      'task-design-handoff': scheduled(
        'task-design-handoff',
        'Design Handoff',
        wednesday,
        duration: const Duration(minutes: 30),
      ),
      'task-evening-retro': scheduled(
        'task-evening-retro',
        'Retro Session',
        thursday,
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
        isSelectionMode: true,
        selectedTaskIds: {
          'task-overlap-a',
          'task-overlap-b',
        },
      );
}

Future<_MockCalendarBloc> _pumpCalendarHarness(
  WidgetTester tester, {
  required CalendarState state,
  required Widget child,
  Size size = const Size(1280, 860),
}) async {
  final binding = tester.binding;
  await binding.setSurfaceSize(size);
  addTearDown(() => binding.setSurfaceSize(null));

  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetDevicePixelRatio());

  final bloc = _MockCalendarBloc();
  when(() => bloc.state).thenReturn(state);
  when(() => bloc.stream)
      .thenAnswer((_) => const Stream<CalendarState>.empty());
  when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
  when(() => bloc.close()).thenAnswer((_) async {});

  await tester.pumpWidget(
    _TestApp(
      bloc: bloc,
      size: size,
      child: child,
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(bloc.close);
  return bloc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const CalendarEvent.started());
    registerFallbackValue(CalendarState.initial());
  });

  group('Calendar component goldens', () {
    testWidgets('CalendarGrid week view matches golden', (tester) async {
      final state = _CalendarTestData.weekView();
      await _pumpCalendarHarness(
        tester,
        state: state,
        size: const Size(1280, 860),
        child: CalendarGrid<CalendarBloc>(
          state: state,
          onDateSelected: (_) {},
          onViewChanged: (_) {},
        ),
      );

      await expectLater(
        find.byType(CalendarGrid<CalendarBloc>),
        matchesGoldenFile('goldens/calendar_grid_week.png'),
      );
    });

    testWidgets('CalendarGrid day view matches golden', (tester) async {
      final state = _CalendarTestData.dayView();
      await _pumpCalendarHarness(
        tester,
        state: state,
        size: const Size(1280, 860),
        child: CalendarGrid<CalendarBloc>(
          state: state,
          onDateSelected: (_) {},
          onViewChanged: (_) {},
        ),
      );

      await expectLater(
        find.byType(CalendarGrid<CalendarBloc>),
        matchesGoldenFile('goldens/calendar_grid_day.png'),
      );
    });

    testWidgets('TaskSidebar default state matches golden', (tester) async {
      await _pumpCalendarHarness(
        tester,
        state: _CalendarTestData.weekView(),
        size: const Size(420, 860),
        child: const TaskSidebar(),
      );

      await expectLater(
        find.byType(TaskSidebar),
        matchesGoldenFile('goldens/task_sidebar_default.png'),
      );
    });

    testWidgets('TaskSidebar selection mode matches golden', (tester) async {
      await _pumpCalendarHarness(
        tester,
        state: _CalendarTestData.selectionMode(),
        size: const Size(420, 860),
        child: const TaskSidebar(),
      );

      await expectLater(
        find.byType(TaskSidebar),
        matchesGoldenFile('goldens/task_sidebar_selection.png'),
      );
    });
  });
}
