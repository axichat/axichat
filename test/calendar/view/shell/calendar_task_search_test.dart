import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_search.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_task_list_tile.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../calendar_test_utils.dart';

Widget _buildSearchTestApp({required Widget child}) {
  final SettingsCubit settingsCubit = _settingsCubit();
  return BlocProvider<SettingsCubit>(
    create: (_) => settingsCubit,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: child,
      ),
    ),
  );
}

SettingsCubit _settingsCubit() {
  final cubit = _MockSettingsCubit();
  when(() => cubit.state).thenReturn(const SettingsState());
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => cubit.animationDuration).thenReturn(Duration.zero);
  when(() => cubit.close()).thenAnswer((_) async {});
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCalendarFallbackValues);

  testWidgets('task search passes result metadata outside trailing', (
    tester,
  ) async {
    final CalendarState initialState = CalendarTestData.weekView();
    final MockCalendarBloc bloc = MockCalendarBloc();
    when(() => bloc.state).thenReturn(initialState);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    var scheduledTaskSawMetadata = false;
    var scheduledTaskSawTrailing = false;

    await tester.pumpWidget(
      _buildSearchTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ShadButton(
                key: const ValueKey('open-search'),
                onPressed: () => showCalendarTaskSearch(
                  context: context,
                  bloc: bloc,
                  taskTileBuilder:
                      (
                        CalendarTask task, {
                        Widget? metadata,
                        Widget? trailing,
                        bool requiresLongPress = false,
                        VoidCallback? onTap,
                        VoidCallback? onDragStart,
                        bool allowContextMenu = false,
                      }) {
                        if (task.id == 'task-weekly-sync') {
                          scheduledTaskSawMetadata = metadata != null;
                          scheduledTaskSawTrailing = trailing != null;
                        }
                        return Text(task.title);
                      },
                ),
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-search')));
    await tester.pumpAndSettle();

    expect(scheduledTaskSawMetadata, isTrue);
    expect(scheduledTaskSawTrailing, isFalse);
  });

  testWidgets('task list tile places metadata below title row', (tester) async {
    final CalendarTask task = CalendarTestData.scheduled(
      'layout-task',
      'Prepare the exceptionally long calendar task title',
      CalendarTestData.baseDate,
    );

    await tester.pumpWidget(
      _buildSearchTestApp(
        child: Material(
          child: SizedBox(
            width: 240,
            child: CalendarTaskListTile(
              task: task,
              metadata: const Text('Search metadata'),
              trailing: const Icon(Icons.schedule),
            ),
          ),
        ),
      ),
    );

    final Finder title = find.text(task.title);
    final Finder metadata = find.text('Search metadata');

    expect(title, findsOneWidget);
    expect(metadata, findsOneWidget);
    expect(
      tester.getTopLeft(metadata).dy,
      greaterThan(tester.getBottomLeft(title).dy),
    );
  });

  testWidgets('task search filters results when query text changes', (
    tester,
  ) async {
    final CalendarState initialState = CalendarTestData.weekView();
    final MockCalendarBloc bloc = MockCalendarBloc();
    when(() => bloc.state).thenReturn(initialState);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _buildSearchTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ShadButton(
                key: const ValueKey('open-search'),
                onPressed: () =>
                    showCalendarTaskSearch(context: context, bloc: bloc),
                child: const Text('Open Search'),
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

    await tester.tap(
      find.text(
        'title:, desc:, location:, category:work, priority:urgent, status:done',
      ),
      warnIfMissed: false,
    );
    tester.testTextInput.enterText('agenda');
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
    final CalendarState initialState = baseState.copyWith(model: updatedModel);
    final MockCalendarBloc bloc = MockCalendarBloc();
    when(() => bloc.state).thenReturn(initialState);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<CalendarState>.empty());
    when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _buildSearchTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ShadButton(
                key: const ValueKey('open-search'),
                onPressed: () =>
                    showCalendarTaskSearch(context: context, bloc: bloc),
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-search')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(
        'title:, desc:, location:, category:work, priority:urgent, status:done',
      ),
      warnIfMissed: false,
    );
    tester.testTextInput.enterText(categoryQuery);
    await tester.pumpAndSettle();

    expect(find.text(taskWithCategoryTitle), findsOneWidget);
    expect(find.text(taskWithoutCategoryTitle), findsNothing);
  });
}
