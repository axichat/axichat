import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'dart:io';

import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/view/calendar_month_view.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'calendar_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory:
          Directory.systemTemp.createTempSync('calendar_day_event_tests'),
    );
    registerCalendarFallbackValues();
  });

  testWidgets('Month view renders overflow pill and taps edit callback',
      (tester) async {
    final DateTime anchor = DateTime(2024, 1, 15);
    final List<DayEvent> events = <DayEvent>[
      DayEvent.create(title: 'Birthday', startDate: anchor),
      DayEvent.create(title: 'Holiday', startDate: anchor),
      DayEvent.create(title: 'Anniversary', startDate: anchor),
      DayEvent.create(title: 'Trip', startDate: anchor),
    ];

    CalendarModel model = CalendarModel.empty();
    for (final DayEvent event in events) {
      model = model.addDayEvent(event);
    }

    bool tappedEdit = false;
    final CalendarState state = CalendarState(
      model: model,
      selectedDate: anchor,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 900,
              height: 800,
              child: CalendarMonthView(
                state: state,
                onDateSelected: (_) {},
                onCreateEvent: (_) {},
                onEditEvent: (_) => tappedEdit = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Birthday'), findsOneWidget);
    expect(find.text('Holiday'), findsOneWidget);
    expect(find.text('+1 more'), findsOneWidget);

    await tester.tap(find.text('Birthday'));
    await tester.pump();

    expect(tappedEdit, isTrue);
  });

  testWidgets('Week headers show badge counts for day events', (tester) async {
    final DateTime selected = DateTime(2024, 1, 15); // Monday
    final DayEvent first = DayEvent.create(
      title: 'All Hands',
      startDate: selected,
    );
    final DayEvent second = DayEvent.create(
      title: 'Product Review',
      startDate: selected,
    );

    CalendarModel model =
        CalendarModel.empty().addDayEvent(first).addDayEvent(second);

    final CalendarState state = CalendarState(
      model: model,
      selectedDate: selected,
      selectedDayIndex: 0,
      viewMode: CalendarView.week,
    );

    final CalendarWidgetHarness harness = await CalendarWidgetHarness.pump(
      tester: tester,
      state: state,
      size: const Size(1400, 900),
    );
    await tester.pumpAndSettle();

    final Finder badgeFinder = find.byWidgetPredicate((Widget widget) {
      if (widget is Container && widget.child is Text) {
        final BoxDecoration? decoration = widget.decoration as BoxDecoration?;
        final Text text = widget.child! as Text;
        return decoration?.color == calendarPrimaryColor &&
            text.data == '2' &&
            harness.gridFinder.evaluate().isNotEmpty;
      }
      return false;
    });

    expect(badgeFinder, findsOneWidget);
  });

  testWidgets('Day view renders bullet strip with day-level events',
      (tester) async {
    final DateTime selected = DateTime(2024, 2, 2);
    final DayEvent event = DayEvent.create(
      title: 'Conference',
      startDate: selected,
    );

    final CalendarState state = CalendarState(
      model: CalendarModel.empty().addDayEvent(event),
      selectedDate: selected,
      selectedDayIndex: 0,
      viewMode: CalendarView.day,
    );

    await CalendarWidgetHarness.pump(
      tester: tester,
      state: state,
      size: const Size(1280, 860),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day events'), findsOneWidget);
    expect(find.text('Conference'), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}
