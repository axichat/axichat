import 'dart:async';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_feedback_observer.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'calendar_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCalendarFallbackValues);

  testWidgets('suppresses added feedback for sync-driven task changes', (
    tester,
  ) async {
    final CalendarState initialState = CalendarTestData.weekView();
    final CalendarTask remoteTask = CalendarTestData.scheduled(
      'remote-sync-task',
      'Remote Sync Task',
      DateTime(2024, 1, 18, 10),
    );
    final CalendarState syncState = initialState.copyWith(
      model: initialState.model.addTask(remoteTask),
      lastSyncTime: DateTime.utc(2024, 1, 20, 12),
    );

    final MockCalendarBloc bloc = MockCalendarBloc();
    final StreamController<CalendarState> controller =
        StreamController<CalendarState>.broadcast();
    var currentState = initialState;
    when(() => bloc.state).thenAnswer((_) => currentState);
    when(() => bloc.stream).thenAnswer((_) => controller.stream);
    when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
    when(() => bloc.close()).thenAnswer((_) async {});
    addTearDown(() async {
      await controller.close();
      await bloc.close();
    });

    await tester.pumpWidget(
      _CalendarTaskFeedbackHarness(bloc: bloc, initialState: initialState),
    );

    currentState = syncState;
    controller.add(syncState);
    await tester.pumpAndSettle();

    expect(find.text('Task "Remote Sync Task" added'), findsNothing);
  });

  testWidgets(
    'sync timestamp updates do not suppress the next local task feedback',
    (tester) async {
      final CalendarState initialState = CalendarTestData.weekView();
      final CalendarState syncTimestampState = initialState.copyWith(
        lastSyncTime: DateTime.utc(2024, 1, 20, 12),
      );
      final CalendarTask localTask = CalendarTestData.scheduled(
        'local-task',
        'Local Task',
        DateTime(2024, 1, 18, 14),
      );
      final CalendarState localAddState = syncTimestampState.copyWith(
        model: syncTimestampState.model.addTask(localTask),
      );

      final MockCalendarBloc bloc = MockCalendarBloc();
      final StreamController<CalendarState> controller =
          StreamController<CalendarState>.broadcast();
      var currentState = initialState;
      when(() => bloc.state).thenAnswer((_) => currentState);
      when(() => bloc.stream).thenAnswer((_) => controller.stream);
      when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
      when(() => bloc.close()).thenAnswer((_) async {});
      addTearDown(() async {
        await controller.close();
        await bloc.close();
      });

      await tester.pumpWidget(
        _CalendarTaskFeedbackHarness(bloc: bloc, initialState: initialState),
      );

      currentState = syncTimestampState;
      controller.add(syncTimestampState);
      await tester.pumpAndSettle();

      currentState = localAddState;
      controller.add(localAddState);
      await tester.pumpAndSettle();

      expect(find.text('Task "Local Task" added'), findsOneWidget);
    },
  );
}

class _CalendarTaskFeedbackHarness extends StatelessWidget {
  const _CalendarTaskFeedbackHarness({
    required this.bloc,
    required this.initialState,
  });

  final MockCalendarBloc bloc;
  final CalendarState initialState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[
          axiBorders,
          axiRadii,
          axiSpacing,
          axiSizing,
          axiMotion,
        ],
      ),
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(
          body: BlocProvider<CalendarBloc>.value(
            value: bloc,
            child: CalendarTaskFeedbackObserver<CalendarBloc>(
              initialTasks: initialState.model.tasks,
              onEvent: (_) {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
