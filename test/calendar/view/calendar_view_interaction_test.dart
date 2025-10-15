import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/quick_add_modal.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:flutter/material.dart';
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
  });

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
