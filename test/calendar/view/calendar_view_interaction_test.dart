import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/quick_add_modal.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_geometry.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_surface.dart';
import 'package:axichat/src/calendar/view/resizable_task_widget.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'calendar_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerCalendarFallbackValues);

  testWidgets('QuickAddModal submits scheduled task with prefilled time',
      (tester) async {
    final slotTime = DateTime(2024, 1, 15, 10, 30);
    CalendarTask? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: QuickAddModal(
            prefilledDateTime: slotTime,
            onTaskAdded: (task) => submitted = task,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Task name *',
    );
    await tester.enterText(titleField, 'Modal Submit Test');
    await tester.pump();

    await tester.tap(find.widgetWithText(ShadButton, 'Add Task'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.title, 'Modal Submit Test');
    expect(submitted!.scheduledTime, slotTime);
  }, skip: true);

  testWidgets('CalendarWidget week view renders day headers', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: CalendarTestData.weekView(),
      size: const Size(1600, 900),
    );

    expect(
        find.descendant(of: harness.gridFinder, matching: find.text('MON 15')),
        findsOneWidget);
    expect(
        find.descendant(of: harness.gridFinder, matching: find.text('TUE 16')),
        findsOneWidget);
  });

  testWidgets('selection sidebar exit button clears selection', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: CalendarTestData.selectionMode(),
      size: const Size(1600, 900),
    );

    expect(find.text('Clear Selection'), findsOneWidget);

    final clearedState = CalendarTestData.selectionMode().copyWith(
      isSelectionMode: false,
      selectedTaskIds: <String>{},
    );
    await harness.pumpState(clearedState);

    expect(find.text('Clear Selection'), findsNothing);
  });

  testWidgets('zoom controls update label after zoomIn call', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: CalendarTestData.weekView(),
      size: const Size(1600, 900),
    );

    final dynamic gridState = tester.state(harness.gridFinder);
    gridState.zoomIn();
    await tester.pump();

    expect(find.text('Comfort'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Comfort'), findsOneWidget);
  });

  testWidgets('selection sidebar summary updates with bloc state',
      (tester) async {
    final initialState = CalendarTestData.selectionMode();

    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: initialState,
      size: const Size(1600, 900),
    );

    expect(find.text('2 tasks selected'), findsOneWidget);

    final nextState = initialState.copyWith(
      selectedTaskIds: {'task-overlap-a'},
    );

    await harness.pumpState(nextState);
    expect(find.text('1 task selected'), findsOneWidget);
  });

  testWidgets('selection batch apply button dispatches title change',
      (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: CalendarTestData.selectionMode(),
      size: const Size(1600, 900),
    );

    final applyFinder = find.widgetWithText(ShadButton, 'Apply changes');
    expect(applyFinder, findsOneWidget);

    var applyButton = tester.widget<ShadButton>(applyFinder);
    expect(applyButton.onPressed, isNull);

    final titleField = find.byWidgetPredicate((widget) {
      return widget is TextField &&
          widget.decoration?.hintText == 'Set title for selected tasks';
    });

    await tester.enterText(titleField, 'Batch Title');
    await tester.pump();

    applyButton = tester.widget<ShadButton>(applyFinder);
    expect(applyButton.onPressed, isNotNull);

    await tester.tap(applyFinder);
    await tester.pump();

    verify(
      () => harness.bloc.add(
        const CalendarEvent.selectionTitleChanged(title: 'Batch Title'),
      ),
    ).called(1);

    final updatedTasks = Map<String, CalendarTask>.from(
      harness.currentState.model.tasks,
    );
    for (final id in harness.currentState.selectedTaskIds) {
      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = updatedTasks[baseId];
      if (baseTask == null) {
        continue;
      }

      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (occurrenceKey == null || occurrenceKey.isEmpty) {
        updatedTasks[baseId] = baseTask.copyWith(
          title: 'Batch Title',
          modifiedAt: baseTask.modifiedAt.add(const Duration(minutes: 1)),
        );
        continue;
      }

      final overrides = {
        ...baseTask.occurrenceOverrides,
      };
      final TaskOccurrenceOverride existing =
          overrides[occurrenceKey] ?? const TaskOccurrenceOverride();
      overrides[occurrenceKey] = existing.copyWith(title: 'Batch Title');

      updatedTasks[baseId] = baseTask.copyWith(
        occurrenceOverrides: overrides,
        modifiedAt: baseTask.modifiedAt.add(const Duration(minutes: 1)),
      );
    }

    final updatedState = harness.currentState.copyWith(
      model: harness.currentState.model.copyWith(tasks: updatedTasks),
    );

    await harness.pumpState(updatedState);

    final textField = tester.widget<TextField>(titleField);
    expect(textField.controller?.text, 'Batch Title');

    applyButton = tester.widget<ShadButton>(applyFinder);
    expect(applyButton.onPressed, isNull);
  });

  testWidgets('right-click opens task context menu', (tester) async {
    final taskFinder = await _pumpContextMenuSurface(tester);
    final menuFinder = find.text('Copy Task');
    expect(taskFinder, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(taskFinder),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pump();
    expect(menuFinder, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(menuFinder, findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(menuFinder, findsNothing);
  });

  testWidgets('right-click repeatedly opens task context menu', (tester) async {
    final taskFinder = await _pumpContextMenuSurface(tester);
    final menuFinder = find.text('Copy Task');
    expect(taskFinder, findsOneWidget);

    for (var attempt = 0; attempt < 5; attempt++) {
      final gesture = await tester.startGesture(
        tester.getCenter(taskFinder),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      expect(
        menuFinder,
        findsNothing,
        reason: 'menu unexpectedly visible before release on attempt $attempt',
      );
      await gesture.up();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(
        menuFinder,
        findsOneWidget,
        reason: 'context menu did not open on attempt $attempt',
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(
        menuFinder,
        findsNothing,
        reason: 'context menu did not close after attempt $attempt',
      );
    }
  });

  testWidgets('task context menu opens across vertical positions',
      (tester) async {
    final taskFinder = await _pumpContextMenuSurface(tester);
    final menuFinder = find.text('Copy Task');
    final Rect taskRect = tester.getRect(taskFinder);

    Future<void> expectMenuAt(Offset point, String label) async {
      final TestGesture gesture = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(
        menuFinder,
        findsOneWidget,
        reason:
            'Context menu should appear after right-clicking the $label region.',
      );

      final Rect menuRect = tester.getRect(menuFinder.first);
      expect(
        (menuRect.center.dy - point.dy).abs(),
        lessThan(180),
        reason:
            'Menu should anchor near the $label click point vertically (dy=${point.dy}).',
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(
        menuFinder,
        findsNothing,
        reason: 'Context menu should close after tapping outside.',
      );
    }

    await expectMenuAt(
      Offset(taskRect.center.dx, taskRect.top + 6),
      'top',
    );
    await expectMenuAt(
      taskRect.center,
      'center',
    );
    await expectMenuAt(
      Offset(taskRect.center.dx, taskRect.bottom - 6),
      'bottom',
    );
  });

  testWidgets(
    'context menu opens for top and bottom tasks inside nested navigators',
    (tester) async {
      final finders = await _pumpNestedContextMenuSurfaces(tester);
      final Finder topTaskFinder = finders['top']!;
      final Finder bottomTaskFinder = finders['bottom']!;
      final Finder menuFinder = find.text('Copy Task');

      Future<double> openMenu(Finder finder) async {
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(finder),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        await _pumpUntilMenuVisible(tester, menuFinder);
        final Rect menuRect = tester.getRect(menuFinder.first);
        return menuRect.top;
      }

      final double topMenuOffset = await openMenu(topTaskFinder);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle(const Duration(milliseconds: 150));

      final double bottomMenuOffset = await openMenu(bottomTaskFinder);
      expect(
        bottomMenuOffset,
        greaterThan(topMenuOffset),
        reason:
            'Bottom task anchor should appear lower than the top task anchor.',
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle(const Duration(milliseconds: 150));
    },
  );

  testWidgets(
    'context menu remains open while hovering into menu items',
    (tester) async {
      final finders = await _pumpNestedContextMenuSurfaces(tester);
      final Finder topTaskFinder = finders['top']!;
      final Finder menuFinder = find.text('Copy Task');

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(topTaskFinder),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await _pumpUntilMenuVisible(tester, menuFinder);

      final Rect menuRect = tester.getRect(menuFinder.first);
      final TestPointer hoverPointer = TestPointer(
        21,
        PointerDeviceKind.mouse,
      );
      await tester.sendEventToBinding(
        hoverPointer.hover(menuRect.topLeft - const Offset(48, 48)),
      );
      await tester.pump();
      await tester.sendEventToBinding(
        hoverPointer.hover(menuRect.center),
      );
      await tester.pump();

      expect(
        menuFinder,
        findsOneWidget,
        reason: 'Menu should remain visible while hovering over entries.',
      );

      await tester.sendEventToBinding(hoverPointer.removePointer());
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle(const Duration(milliseconds: 150));
      expect(menuFinder, findsNothing);
    },
  );

  testWidgets('log calendar grid geometry', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      size: const Size(1600, 900),
    );

    final double bodyTop = harness.gridBodyTop();
    debugPrint('Calendar grid body top: $bodyTop');

    final Offset morningSlot =
        harness.slotPosition(0, const Duration(hours: 9));
    final Offset eveningSlot =
        harness.slotPosition(0, const Duration(hours: 15));
    debugPrint('Slot 9am center: $morningSlot');
    debugPrint('Slot 8pm center: $eveningSlot');
  }, skip: true);

  testWidgets('debug find calendar task widgets', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      size: const Size(1600, 900),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    final Finder weeklyFinder =
        find.byKey(const ValueKey('calendar-task-task-weekly-sync'));
    final Finder designFinder =
        find.byKey(const ValueKey('calendar-task-task-design-review'));

    debugPrint('Weekly Sync widgets: ${weeklyFinder.evaluate().length}');
    debugPrint('Design Review widgets: ${designFinder.evaluate().length}');

    final taskTitles = find.descendant(
      of: harness.gridFinder,
      matching: find.byType(Text),
    );
    debugPrint('Total text widgets in grid: ${taskTitles.evaluate().length}');
  }, skip: true);

  testWidgets('log hit test stack for calendar slots', (tester) async {
    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      size: const Size(1600, 900),
    );

    final Rect gridRect = tester.getRect(harness.gridFinder);
    final Offset sampleTop = Offset(
      gridRect.left + gridRect.width / 2,
      gridRect.top + 12,
    );
    final Offset sampleBottom = Offset(
      gridRect.left + gridRect.width / 2,
      gridRect.bottom - 12,
    );

    final HitTestResult topResult = HitTestResult();
    tester.binding.hitTest(topResult, sampleTop);
    debugPrint('Hit test entries near grid top:');
    for (final entry in topResult.path) {
      debugPrint('  ${entry.target.runtimeType}');
    }

    final HitTestResult bottomResult = HitTestResult();
    tester.binding.hitTest(bottomResult, sampleBottom);
    debugPrint('Hit test entries near grid bottom:');
    for (final entry in bottomResult.path) {
      debugPrint('  ${entry.target.runtimeType}');
    }
  }, skip: true);

  testWidgets('selection batch editors preload shared field values',
      (tester) async {
    final base = CalendarTestData.baseState();
    final sourceTask = base.model.tasks['task-design-review']!;
    final updatedTask = sourceTask.copyWith(
      description: 'Review the sprint backlog',
      location: 'Room 12',
    );
    final updatedModel = base.model.copyWith(
      tasks: {
        ...base.model.tasks,
        updatedTask.id: updatedTask,
      },
    );
    final selectionState = base.copyWith(
      model: updatedModel,
      isSelectionMode: true,
      selectedTaskIds: {updatedTask.id},
    );

    await CalendarWidgetHarness.pump(
      tester: tester,
      state: selectionState,
      size: const Size(1600, 900),
    );

    final titleField = find.byWidgetPredicate((widget) {
      return widget is TextField &&
          widget.decoration?.hintText == 'Set title for selected tasks';
    });
    final descriptionField = find.byWidgetPredicate((widget) {
      return widget is TextField &&
          widget.decoration?.hintText ==
              'Set description (leave blank to clear)';
    });
    final locationField = find.byWidgetPredicate((widget) {
      return widget is TextField &&
          widget.decoration?.hintText == 'Set location (leave blank to clear)';
    });

    expect(
      tester.widget<TextField>(titleField).controller?.text,
      updatedTask.title,
    );
    expect(
      tester.widget<TextField>(descriptionField).controller?.text,
      'Review the sprint backlog',
    );
    expect(
      tester.widget<TextField>(locationField).controller?.text,
      'Room 12',
    );
  });

  testWidgets('selection list retains recurring occurrences when updated',
      (tester) async {
    final base = CalendarTestData.baseState();
    final recurring = base.model.tasks['task-recurring-standup']!;
    final rangeStart = base.weekStart;
    final rangeEnd = rangeStart.add(const Duration(days: 7));
    final occurrences =
        recurring.occurrencesWithin(rangeStart, rangeEnd).take(3).toList();
    final Set<String> firstTwoIds = {
      occurrences[0].id,
      occurrences[1].id,
    };

    final initialState = base.copyWith(
      isSelectionMode: true,
      selectedTaskIds: firstTwoIds,
    );

    final harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: initialState,
      size: const Size(1600, 900),
    );

    expect(find.byTooltip('Remove from selection'), findsNWidgets(2));

    final Set<String> updatedIds = {...firstTwoIds, occurrences[2].id};
    final updatedState = initialState.copyWith(selectedTaskIds: updatedIds);
    await harness.pumpState(updatedState);

    expect(find.byTooltip('Remove from selection'), findsNWidgets(3));
    expect(harness.currentState.selectedTaskIds, updatedIds);
  });
}

Future<Finder> _pumpContextMenuSurface(WidgetTester tester) async {
  final task = CalendarTestData.scheduled(
    'task-context-menu',
    'Context Menu Task',
    DateTime(2024, 1, 15, 10),
  );
  final interactionController = TaskInteractionController();
  final bindings = _buildTestBindings(
    controller: interactionController,
    groupId: const ValueKey('test-task-menu'),
    builderFactory: (controller) => (context, request) => [
          ShadContextMenuItem(
            onPressed: () => controller.hide(),
            child: const Text('Copy Task'),
          ),
        ],
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 240,
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 40,
                    width: 240,
                    height: 120,
                    child: CalendarTaskSurface(
                      key: const ValueKey('surface-task-context-menu'),
                      task: task,
                      isDayView: true,
                      bindings: bindings,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return find.byKey(const ValueKey('task-context-menu'));
}

CalendarTaskTileCallbacks _testTileCallbacks() => CalendarTaskTileCallbacks(
      onResizePreview: (_) {},
      onResizeEnd: (_) {},
      onResizePointerMove: (_) {},
      onDragStarted: (_, __) {},
      onDragUpdate: (_) {},
      onDragEnded: (_) {},
      onDragPointerDown: (_) {},
      onEnterSelectionMode: () {},
      onToggleSelection: () {},
      onTap: (_, __) {},
    );

CalendarTaskEntryBindings _buildTestBindings({
  required TaskInteractionController controller,
  required ValueKey<String> groupId,
  required CalendarTaskContextMenuBuilderFactory builderFactory,
  Rect geometryRect = const Rect.fromLTWH(0, 0, 240, 60),
}) {
  final geometry = CalendarTaskGeometry(
    rect: geometryRect,
    narrowedWidth: geometryRect.width * 0.8,
    splitWidthFactor: geometryRect.width == 0
        ? 0
        : (geometryRect.width * 0.8) / geometryRect.width,
  );
  return CalendarTaskEntryBindings(
    isSelectionMode: false,
    isSelected: false,
    isPopoverOpen: false,
    dragTargetKey: GlobalKey(),
    splitPreviewAnimationDuration: Duration.zero,
    contextMenuGroupId: groupId,
    contextMenuBuilderFactory: builderFactory,
    interactionController: controller,
    dragFeedbackHint: controller.feedbackHint,
    callbacks: _testTileCallbacks(),
    geometryProvider: (_) => geometry,
    addGeometryListener: (_) {},
    removeGeometryListener: (_) {},
    stepHeight: 15,
    minutesPerStep: 15,
    hourHeight: 60,
  );
}

Future<Map<String, Finder>> _pumpNestedContextMenuSurfaces(
  WidgetTester tester,
) async {
  final ValueKey<String> groupId = const ValueKey('test-task-menu');
  final builderFactory = (ShadPopoverController controller) =>
      (BuildContext context, TaskContextMenuRequest request) => [
            ShadContextMenuItem(
              onPressed: () => controller.hide(),
              child: const Text('Copy Task'),
            ),
          ];

  final TaskInteractionController topController = TaskInteractionController();
  final TaskInteractionController bottomController =
      TaskInteractionController();

  final CalendarTask topTask = CalendarTestData.scheduled(
    'task-top-context',
    'Top Context Task',
    DateTime(2024, 1, 15, 9),
  );
  final CalendarTask bottomTask = CalendarTestData.scheduled(
    'task-bottom-context',
    'Bottom Context Task',
    DateTime(2024, 1, 15, 20),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => Scaffold(
                body: ShadTheme(
                  data: ShadThemeData(
                    colorScheme: const ShadSlateColorScheme.light(),
                    brightness: Brightness.light,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 360,
                      height: 680,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 40,
                            top: 24,
                            width: 240,
                            height: 140,
                            child: CalendarTaskSurface(
                              key: ValueKey('surface-${topTask.id}'),
                              task: topTask,
                              isDayView: true,
                              bindings: _buildTestBindings(
                                controller: topController,
                                groupId: groupId,
                                builderFactory: builderFactory,
                                geometryRect:
                                    const Rect.fromLTWH(40, 24, 240, 140),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 40,
                            top: 420,
                            width: 240,
                            height: 140,
                            child: CalendarTaskSurface(
                              key: ValueKey('surface-${bottomTask.id}'),
                              task: bottomTask,
                              isDayView: true,
                              bindings: _buildTestBindings(
                                controller: bottomController,
                                groupId: groupId,
                                builderFactory: builderFactory,
                                geometryRect:
                                    const Rect.fromLTWH(40, 420, 240, 140),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return {
    'top': find.byKey(ValueKey(topTask.id)),
    'bottom': find.byKey(ValueKey(bottomTask.id)),
  };
}

Future<void> _pumpUntilMenuVisible(
  WidgetTester tester,
  Finder menuFinder,
) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (tester.any(menuFinder)) {
      return;
    }
  }
  expect(
    menuFinder,
    findsOneWidget,
    reason: 'Context menu should appear after secondary tap.',
  );
}
