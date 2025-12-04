import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/view/calendar_task_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'calendar_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCalendarFallbackValues);

  testWidgets('task search filters results when query text changes',
      (tester) async {
    final CalendarState initialState = CalendarTestData.weekView();
    final MockCalendarBloc bloc = MockCalendarBloc();
    when(() => bloc.state).thenReturn(initialState);
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ShadButton(
                  key: const ValueKey('open-search'),
                  onPressed: () => showCalendarTaskSearch(
                    context: context,
                    bloc: bloc,
                  ),
                  child: const Text('Open Search'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-search')));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Sync'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'agenda');
    await tester.pumpAndSettle();

    expect(find.text('Draft Agenda'), findsOneWidget);
    expect(find.text('Weekly Sync'), findsNothing);
  });
}
