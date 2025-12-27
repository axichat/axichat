import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
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

  testWidgets('task search filters results by category', (tester) async {
    const String categoryName = 'Ops';
    const String categoryQuery = 'category:ops';
    const String taskWithCategoryTitle = 'Weekly Sync';
    const String taskWithoutCategoryTitle = 'Design Review';
    final CalendarState baseState = CalendarTestData.weekView();
    final CalendarTask baseTask = baseState.model.tasks['task-weekly-sync']!;
    final CalendarTask updatedTask = baseTask.copyWith(
      icsMeta: const CalendarIcsMeta(categories: <String>[categoryName]),
    );
    final Map<String, CalendarTask> updatedTasks =
        Map<String, CalendarTask>.from(baseState.model.tasks)
          ..[baseTask.id] = updatedTask;
    final CalendarModel updatedModel = baseState.model.copyWith(
      tasks: updatedTasks,
    );
    final CalendarState initialState = baseState.copyWith(
      model: updatedModel,
    );
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

    await tester.enterText(find.byType(TextField).first, categoryQuery);
    await tester.pumpAndSettle();

    expect(find.text(taskWithCategoryTitle), findsOneWidget);
    expect(find.text(taskWithoutCategoryTitle), findsNothing);
  });
}
