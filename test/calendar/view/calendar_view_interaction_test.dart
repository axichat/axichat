import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/quick_add_modal.dart';

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

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
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

    expect(find.descendant(of: harness.gridFinder, matching: find.text('MON 15')),
        findsOneWidget);
    expect(find.descendant(of: harness.gridFinder, matching: find.text('TUE 16')),
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

    expect(find.text('30m'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('30m'), findsNothing);
  });
}
