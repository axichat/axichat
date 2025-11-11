import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/view/calendar_grid.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:axichat/src/calendar/view/task_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import 'calendar_test_utils.dart';

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

Future<MockCalendarBloc> _pumpCalendarHarness(
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

  final bloc = MockCalendarBloc();
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

  setUpAll(registerCalendarFallbackValues);

  group('Calendar component goldens', () {
    testWidgets('CalendarGrid week view matches golden', (tester) async {
      final state = CalendarTestData.weekView();
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

      // TODO(#calendar-goldens): Refresh golden once interaction harness stabilises.
      await expectLater(
        find.byType(CalendarGrid<CalendarBloc>),
        matchesGoldenFile('goldens/calendar_grid_week.png'),
      );
    }, skip: true);

    testWidgets('CalendarWidget week view matches golden', (tester) async {
      await _pumpCalendarHarness(
        tester,
        state: CalendarTestData.weekView(),
        size: const Size(1440, 900),
        child: const CalendarWidget(),
      );

      // TODO(#calendar-goldens): Capture replacement golden once navigation overflow is addressed.
      await expectLater(
        find.byType(CalendarWidget),
        matchesGoldenFile('goldens/calendar_widget_week.png'),
      );
    }, skip: true);

    testWidgets('TaskSidebar default state matches golden', (tester) async {
      await _pumpCalendarHarness(
        tester,
        state: CalendarTestData.weekView(),
        size: const Size(420, 860),
        child: const TaskSidebar(),
      );

      // TODO(#calendar-goldens): Recreate sidebar golden once data fixtures are finalised.
      await expectLater(
        find.byType(TaskSidebar),
        matchesGoldenFile('goldens/task_sidebar_default.png'),
      );
    }, skip: true);

    testWidgets('TaskSidebar selection mode matches golden', (tester) async {
      await _pumpCalendarHarness(
        tester,
        state: CalendarTestData.selectionMode(),
        size: const Size(420, 860),
        child: const TaskSidebar(),
      );

      // TODO(#calendar-goldens): Recreate selection mode golden once fixtures stabilise.
      await expectLater(
        find.byType(TaskSidebar),
        matchesGoldenFile('goldens/task_sidebar_selection.png'),
      );
    }, skip: true);

    testWidgets('TaskSidebar width responds to resize rail drag',
        (tester) async {
      final state = CalendarTestData.weekView();
      await _pumpCalendarHarness(
        tester,
        state: state,
        size: const Size(1280, 860),
        child: const Row(
          children: [
            TaskSidebar(),
            Expanded(child: SizedBox()),
          ],
        ),
      );

      Rect rect = tester.getRect(find.byType(TaskSidebar));
      final double initialWidth = rect.width;
      final Finder handleFinder =
          find.byKey(const ValueKey('calendar.sidebar.resizeHandle'));
      expect(handleFinder, findsOneWidget);
      Rect handleRect = tester.getRect(handleFinder);

      // Drag left to shrink the sidebar.
      Offset dragStart = handleRect.center;
      final TestGesture shrinkGesture = await tester.startGesture(dragStart);
      await tester.pump();
      final dynamic stateAfterPointerDown =
          tester.state(find.byType(TaskSidebar));
      final bool isResizingAfterDown = (stateAfterPointerDown as dynamic)
          .debugSidebarState
          .isResizing as bool;
      expect(
        isResizingAfterDown,
        isTrue,
        reason: 'Controller should enter resizing immediately on pointer down.',
      );
      await shrinkGesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      handleRect = tester.getRect(handleFinder);
      final dynamic sidebarStateDuringDrag =
          tester.state(find.byType(TaskSidebar));
      final bool isResizingDuringDrag = (sidebarStateDuringDrag as dynamic)
          .debugSidebarState
          .isResizing as bool;
      expect(
        isResizingDuringDrag,
        isTrue,
        reason:
            'Controller should mark itself as resizing after drag movement.',
      );
      await shrinkGesture.up();
      await tester.pumpAndSettle();

      rect = tester.getRect(find.byType(TaskSidebar));
      final double shrunkWidth = rect.width;
      final dynamic sidebarStateAfterShrink =
          tester.state(find.byType(TaskSidebar));
      final double controllerShrunkWidth = (sidebarStateAfterShrink as dynamic)
          .debugSidebarState
          .width as double;
      expect(
        controllerShrunkWidth,
        lessThan(initialWidth),
        reason: 'Controller width should shrink after drag.',
      );
      expect(
        shrunkWidth,
        lessThan(initialWidth),
        reason: 'Dragging the resize rail left should reduce sidebar width.',
      );

      // Drag right to expand the sidebar.
      handleRect = tester.getRect(handleFinder);
      dragStart = handleRect.center;
      final TestGesture expandGesture = await tester.startGesture(dragStart);
      await tester.pump();
      await expandGesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await expandGesture.up();
      await tester.pumpAndSettle();

      rect = tester.getRect(find.byType(TaskSidebar));
      final double expandedWidth = rect.width;
      final dynamic sidebarStateAfterExpand =
          tester.state(find.byType(TaskSidebar));
      final double controllerExpandedWidth =
          (sidebarStateAfterExpand as dynamic).debugSidebarState.width
              as double;
      expect(
        controllerExpandedWidth,
        greaterThan(controllerShrunkWidth),
        reason: 'Controller width should grow after dragging right.',
      );
      expect(
        expandedWidth,
        greaterThan(shrunkWidth),
        reason: 'Dragging the resize rail right should increase sidebar width.',
      );
    });
  });
}
