import 'dart:io';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/calendar_grid.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/calendar_drag_payload.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_render_surface.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'calendar_test_utils.dart';

class _MockCalendarBloc extends Mock implements CalendarBloc {}

class _GridHarness extends StatelessWidget {
  const _GridHarness({required this.child, required this.state});

  final Widget child;
  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final bloc = _MockCalendarBloc();
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.add(any())).thenReturn(null);

    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>.value(value: bloc),
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 900)),
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final storageDir = Directory.systemTemp.createTempSync(
      'calendar_grid_render_tests',
    );
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(storageDir.path),
    );
    registerCalendarFallbackValues();
  });

  testWidgets('CalendarGrid renders time column labels', (tester) async {
    final state = CalendarTestData.weekView();
    await tester.pumpWidget(
      _GridHarness(
        state: state,
        child: CalendarGrid<CalendarBloc>(
          state: state,
          onDateSelected: (_) {},
          onViewChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CalendarRenderSurface), findsOneWidget);
  });

  testWidgets('CalendarGrid preserves explicit day view on desktop', (
    tester,
  ) async {
    final state = CalendarTestData.dayView();
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final List<CalendarView> requestedViews = [];
    await tester.pumpWidget(
      _GridHarness(
        state: state,
        child: CalendarGrid<CalendarBloc>(
          state: state,
          onDateSelected: (_) {},
          onViewChanged: (view) => requestedViews.add(view),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(requestedViews, isEmpty);
  });

  testWidgets('CalendarGrid empty slot tap is handled at the widget layer', (
    tester,
  ) async {
    final state = CalendarTestData.weekView();
    DateTime? tappedSlot;

    await tester.pumpWidget(
      _GridHarness(
        state: state,
        child: CalendarGrid<CalendarBloc>(
          state: state,
          onDateSelected: (_) {},
          onViewChanged: (_) {},
          onEmptySlotTapped: (slot, _) => tappedSlot = slot,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final RenderCalendarSurface renderSurface = tester
        .renderObject<RenderCalendarSurface>(
          find.byType(CalendarRenderSurface),
        );
    final metrics = renderSurface.metrics!;
    final Offset localPosition = Offset(
      renderSurface.layoutTheme.timeColumnWidth + 40,
      metrics.slotHeight * 12.5,
    );
    final DateTime expectedSlot = renderSurface.slotForOffset(localPosition)!;

    await tester.tapAt(renderSurface.localToGlobal(localPosition));
    await tester.pump();

    expect(tappedSlot, expectedSlot);
  });

  testWidgets(
    'CalendarGrid empty surface scroll gesture does not trigger tap',
    (tester) async {
      final state = CalendarTestData.weekView();
      DateTime? tappedSlot;

      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
            onEmptySlotTapped: (slot, _) => tappedSlot = slot,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final metrics = renderSurface.metrics!;
      final Offset start = renderSurface.localToGlobal(
        Offset(
          renderSurface.layoutTheme.timeColumnWidth + 40,
          metrics.slotHeight * 14.5,
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, -160));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tappedSlot, isNull);
    },
  );

  testWidgets(
    'CalendarGrid ignores task-originated taps for empty slot quick add',
    (tester) async {
      final state = CalendarTestData.weekView();
      DateTime? tappedSlot;

      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
            onEmptySlotTapped: (slot, _) => tappedSlot = slot,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final Rect taskBounds = renderSurface.globalRectForTask(
        'task-design-review',
      )!;

      await tester.tapAt(taskBounds.center);
      await tester.pump();

      expect(tappedSlot, isNull);
    },
  );

  testWidgets(
    'CalendarRenderSurface can refresh an active drag preview from the left edge without a new pointer move',
    (tester) async {
      final state = CalendarTestData.weekView();
      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final Finder surfaceFinder = find.byType(CalendarRenderSurface);
      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(surfaceFinder);
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;
      final Offset surfaceOrigin = renderSurface.localToGlobal(Offset.zero);

      interactionController.beginExternalDrag(
        task: task,
        snapshot: task.copyWith(),
        pointerOffset: Offset(taskRect.width / 2, taskRect.height / 2),
        feedbackSize: taskRect.size,
        globalPosition: taskRect.topLeft,
      );

      final bool dispatched = renderSurface.dispatchActiveDragUpdate(
        Offset(surfaceOrigin.dx + 1, taskRect.center.dy + 120),
      );
      await tester.pump();

      expect(dispatched, isTrue);
      expect(interactionController.preview.value, isNotNull);

      interactionController.endDrag();
    },
  );

  testWidgets(
    'CalendarRenderSurface can refresh drag preview without marking drag moved',
    (tester) async {
      final state = CalendarTestData.weekView();
      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final Finder surfaceFinder = find.byType(CalendarRenderSurface);
      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(surfaceFinder);
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;
      final Offset surfaceOrigin = renderSurface.localToGlobal(Offset.zero);

      interactionController.beginExternalDrag(
        task: task,
        snapshot: task.copyWith(),
        pointerOffset: Offset(taskRect.width / 2, taskRect.height / 2),
        feedbackSize: taskRect.size,
        globalPosition: taskRect.topLeft,
      );

      final bool dispatched = renderSurface.dispatchActiveDragUpdate(
        Offset(surfaceOrigin.dx + 1, taskRect.center.dy + 120),
        markDragMoved: false,
      );
      await tester.pump();

      expect(dispatched, isTrue);
      expect(interactionController.preview.value, isNotNull);
      expect(interactionController.dragHasMoved, isFalse);

      interactionController.endDrag();
    },
  );

  testWidgets(
    'CalendarGrid forwards drag preview notifier updates to the render surface',
    (tester) async {
      final state = CalendarTestData.weekView();
      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final DragPreview preview = DragPreview(
        start: DateTime(2024, 1, 15, 14),
        duration: const Duration(hours: 1),
      );

      interactionController.updatePreview(preview.start, preview.duration);
      await tester.pump();

      expect(renderSurface.dragPreview, preview);
    },
  );

  testWidgets(
    'CalendarRenderSurface ignores stale task-surface payload updates during an active grid drag',
    (tester) async {
      final state = CalendarTestData.weekView();
      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;

      interactionController.beginDrag(
        task: task,
        snapshot: task.copyWith(),
        bounds: taskRect,
        pointerNormalized: 0.5,
        pointerGlobalX: taskRect.center.dx,
        originSlot: task.scheduledTime,
      );

      final Offset livePointer = taskRect.center + const Offset(0, 160);
      final bool dispatched = renderSurface.dispatchActiveDragUpdate(
        livePointer,
      );
      await tester.pump();

      expect(dispatched, isTrue);
      final DragPreview? previewBefore = interactionController.preview.value;
      expect(previewBefore, isNotNull);

      renderSurface.handleDragPayloadUpdate(
        CalendarDragPayload(
          task: task,
          snapshot: task.copyWith(),
          source: CalendarDragPayloadSource.taskSurface,
          sourceBounds: taskRect,
          pointerNormalizedX: 0.5,
          pointerOffsetY: taskRect.height / 2,
          originSlot: task.scheduledTime,
          pickupScheduledTime: task.scheduledTime,
        ),
        taskRect.topLeft,
      );
      await tester.pump();

      expect(interactionController.preview.value, previewBefore);
      expect(
        interactionController.activeInteractionSession?.source,
        CalendarInteractionSource.taskSurface,
      );

      interactionController.endDrag();
    },
  );

  testWidgets(
    'CalendarRenderSurface keeps the pickup anchor fixed during active grid drag preview updates',
    (tester) async {
      final CalendarState state = CalendarTestData.weekView();
      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;

      interactionController.beginDrag(
        task: task,
        snapshot: task.copyWith(),
        bounds: taskRect,
        pointerNormalized: 0.5,
        pointerGlobalX: taskRect.center.dx,
        originSlot: task.scheduledTime,
      );
      await tester.pump();

      final double? initialAnchor =
          interactionController.dragPointerOffsetFromTop;
      expect(initialAnchor, isNotNull);

      final bool firstDispatch = renderSurface.dispatchActiveDragUpdate(
        taskRect.center + const Offset(0, 96),
      );
      final bool secondDispatch = renderSurface.dispatchActiveDragUpdate(
        taskRect.center + const Offset(0, -32),
      );
      await tester.pump();

      expect(firstDispatch, isTrue);
      expect(secondDispatch, isTrue);
      expect(interactionController.dragPointerOffsetFromTop, initialAnchor);

      interactionController.endDrag();
    },
  );

  testWidgets(
    'CalendarRenderSurface keeps occupied-cell preview aligned with the pointer-based preview',
    (tester) async {
      final CalendarState state = CalendarTestData.weekView();
      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;
      final Offset occupiedPoint = renderSurface
          .globalRectForTask('task-design-review')!
          .center;

      interactionController.beginDrag(
        task: task,
        snapshot: task.copyWith(),
        bounds: taskRect,
        pointerNormalized: 0.5,
        pointerGlobalX: taskRect.center.dx,
        originSlot: task.scheduledTime,
      );

      interactionController.updateDragPointerGlobalPosition(occupiedPoint);
      final DragPreview? expected = renderSurface.previewForGlobalPosition(
        occupiedPoint,
      );
      final bool dispatched = renderSurface.dispatchActiveDragUpdate(
        occupiedPoint,
      );
      await tester.pump();

      expect(dispatched, isTrue);
      expect(interactionController.preview.value, isNotNull);
      expect(interactionController.preview.value!.start, expected?.start);
      expect(interactionController.preview.value!.duration, expected?.duration);

      interactionController.endDrag();
    },
  );

  testWidgets(
    'CalendarGrid forwards task-surface drag session updates from the interaction session',
    (tester) async {
      final state = CalendarTestData.weekView();
      int startedCount = 0;
      int endedCount = 0;
      final List<Offset> positions = <Offset>[];

      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
            onDragSessionStarted: () => startedCount += 1,
            onDragGlobalPositionChanged: positions.add,
            onDragSessionEnded: () => endedCount += 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;

      interactionController.beginDrag(
        task: task,
        snapshot: task.copyWith(),
        bounds: taskRect,
        pointerNormalized: 0.5,
        pointerGlobalX: taskRect.center.dx,
        originSlot: task.scheduledTime,
      );
      await tester.pump();

      expect(startedCount, 1);
      expect(positions, isNotEmpty);
      expect(positions.last, taskRect.center);

      final Offset movedPosition = taskRect.center + const Offset(0, 96);
      interactionController.updateDragPointerGlobalPosition(movedPosition);
      await tester.pump();

      expect(startedCount, 1);
      expect(positions.last, movedPosition);

      interactionController.endDrag();
      await tester.pump();

      expect(endedCount, 1);
    },
  );

  testWidgets(
    'CalendarGrid ignores external drag sessions for drag shell callbacks',
    (tester) async {
      final state = CalendarTestData.weekView();
      int startedCount = 0;
      int endedCount = 0;
      final List<Offset> positions = <Offset>[];

      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
            onDragSessionStarted: () => startedCount += 1,
            onDragGlobalPositionChanged: positions.add,
            onDragSessionEnded: () => endedCount += 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;

      interactionController.beginExternalDrag(
        task: task,
        snapshot: task.copyWith(),
        pointerOffset: Offset(taskRect.width / 2, taskRect.height / 2),
        feedbackSize: taskRect.size,
        globalPosition: taskRect.topLeft,
      );
      await tester.pump();

      interactionController.updateDragPointerGlobalPosition(
        taskRect.center + const Offset(0, 96),
      );
      await tester.pump();

      interactionController.endDrag();
      await tester.pump();

      expect(startedCount, 0);
      expect(positions, isEmpty);
      expect(endedCount, 0);
    },
  );

  testWidgets(
    'CalendarGrid ends an active task-surface drag when an external payload consumes it',
    (tester) async {
      final CalendarState state = CalendarTestData.weekView();
      final ValueNotifier<int> completionRevision = ValueNotifier<int>(0);
      int endedCount = 0;

      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
            onDragSessionEnded: () => endedCount += 1,
            dragCompletionRevision: completionRevision,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;

      interactionController.beginDrag(
        task: task,
        snapshot: task.copyWith(),
        bounds: taskRect,
        pointerNormalized: 0.5,
        pointerGlobalX: taskRect.center.dx,
        originSlot: task.scheduledTime,
      );
      await tester.pump();

      expect(interactionController.draggingTaskId, task.id);

      completionRevision.value += 1;
      await tester.pump();

      expect(interactionController.draggingTaskId, isNull);
      expect(interactionController.preview.value, isNull);
      expect(interactionController.activeInteractionSession, isNull);
      expect(endedCount, 1);
    },
  );

  testWidgets(
    'CalendarGrid neutralizes edge intent and clears preview while a non-grid drag region is active',
    (tester) async {
      final CalendarState state = CalendarTestData.weekView();
      final ValueNotifier<bool> nonGridHover = ValueNotifier<bool>(false);

      await tester.pumpWidget(
        _GridHarness(
          state: state,
          child: CalendarGrid<CalendarBloc>(
            state: state,
            onDateSelected: (_) {},
            onViewChanged: (_) {},
            nonGridDragRegionHoverNotifier: nonGridHover,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderCalendarSurface renderSurface = tester
          .renderObject<RenderCalendarSurface>(
            find.byType(CalendarRenderSurface),
          );
      final TaskInteractionController interactionController =
          renderSurface.interactionController!;
      final CalendarTask task = state.model.tasks['task-weekly-sync']!;
      final Rect taskRect = renderSurface.globalRectForTask(task.id)!;

      interactionController.beginDrag(
        task: task,
        snapshot: task.copyWith(),
        bounds: taskRect,
        pointerNormalized: 0.5,
        pointerGlobalX: taskRect.center.dx,
        originSlot: task.scheduledTime,
      );
      renderSurface.dispatchActiveDragUpdate(
        taskRect.center + const Offset(0, 96),
      );
      interactionController.updateInteractionEdgeIntent(
        verticalIntent: CalendarInteractionVerticalIntent.down,
        horizontalIntent: CalendarInteractionHorizontalIntent.backward,
      );
      await tester.pump();

      expect(interactionController.preview.value, isNotNull);
      expect(
        interactionController.activeInteractionSession?.horizontalIntent,
        CalendarInteractionHorizontalIntent.backward,
      );

      nonGridHover.value = true;
      await tester.pump();

      expect(interactionController.preview.value, isNull);
      expect(
        interactionController.activeInteractionSession?.verticalIntent,
        CalendarInteractionVerticalIntent.neutral,
      );
      expect(
        interactionController.activeInteractionSession?.horizontalIntent,
        CalendarInteractionHorizontalIntent.neutral,
      );

      interactionController.endDrag();
      nonGridHover.dispose();
    },
  );
}
