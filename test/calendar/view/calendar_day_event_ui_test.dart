import 'dart:io';

import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/view/calendar_grid.dart';
import 'package:axichat/src/calendar/view/calendar_month_view.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'calendar_test_utils.dart';

const Size _monthViewSize = Size(900, 800);

class CalendarMonthViewHarness extends StatelessWidget {
  const CalendarMonthViewHarness({
    super.key,
    required this.state,
    required this.onDateSelected,
    required this.onCreateEvent,
    required this.onEditEvent,
    this.size = _monthViewSize,
  });

  final CalendarState state;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onCreateEvent;
  final ValueChanged<DayEvent> onEditEvent;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F172A),
        brightness: Brightness.light,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: ShadTheme(
              data: ShadThemeData(
                colorScheme: const ShadSlateColorScheme.light(),
                brightness: Brightness.light,
              ),
              child: CalendarMonthView(
                state: state,
                onDateSelected: onDateSelected,
                onCreateEvent: onCreateEvent,
                onEditEvent: onEditEvent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
      CalendarMonthViewHarness(
        state: state,
        onDateSelected: (_) {},
        onCreateEvent: (_) {},
        onEditEvent: (_) => tappedEdit = true,
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

    await CalendarWidgetHarness.pump(
      tester: tester,
      state: state,
      size: const Size(1400, 900),
    );
    await tester.pumpAndSettle();

    final Finder badgeFinder = find.descendant(
      of: find.byType(DayEventBadge),
      matching: find.text('2'),
    );

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
    expect(find.text('Conference', findRichText: true), findsOneWidget);
  });
}
