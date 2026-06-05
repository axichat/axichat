import 'dart:async';

import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/view/chat/chat_task_card.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_completion_checkbox.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../calendar_test_utils.dart';

void main() {
  setUpAll(registerCalendarFallbackValues);

  testWidgets('BaseTaskTile popover opens without context errors', (
    tester,
  ) async {
    final state = CalendarTestData.weekView();
    final bloc = _chatCalendarBloc(state);
    await tester.pumpWidget(
      _wrap(
        bloc: bloc,
        child: ChatCalendarTaskTile(
          task: state.model.tasks['task-weekly-sync']!,
          shareFragment: false,
          onTap: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Actions'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('completion waits for linked task hook before dispatch', (
    tester,
  ) async {
    final state = CalendarTestData.weekView();
    final bloc = _chatCalendarBloc(state);
    final hookStarted = Completer<void>();
    final releaseHook = Completer<void>();

    await tester.pumpWidget(
      _wrap(
        bloc: bloc,
        child: ChatCalendarTaskTile(
          task: state.model.tasks['task-weekly-sync']!,
          shareFragment: false,
          onBeforeToggleCompletion: (task) async {
            hookStarted.complete();
            await releaseHook.future;
          },
        ),
      ),
    );

    await tester.tap(find.byType(CalendarCompletionCheckbox));
    await tester.pump();
    await hookStarted.future;

    verifyNever(() => bloc.add(any<CalendarEvent>()));

    releaseHook.complete();
    await tester.pump();

    verify(
      () => bloc.add(
        any(
          that: isA<CalendarTaskCompleted>().having(
            (event) => event.completed,
            'completed',
            true,
          ),
        ),
      ),
    ).called(1);
  });
}

Widget _wrap({required ChatCalendarBloc bloc, required Widget child}) {
  final settingsCubit = _settingsCubit();
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: BlocProvider<ChatCalendarBloc>.value(
        value: bloc,
        child: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: Scaffold(body: SizedBox(width: 420, child: child)),
        ),
      ),
    ),
  );
}

ChatCalendarBloc _chatCalendarBloc(CalendarState state) {
  final bloc = _MockChatCalendarBloc();
  when(() => bloc.state).thenReturn(state);
  when(
    () => bloc.stream,
  ).thenAnswer((_) => const Stream<CalendarState>.empty());
  when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
  return bloc;
}

SettingsCubit _settingsCubit() {
  final cubit = _MockSettingsCubit();
  when(() => cubit.state).thenReturn(const SettingsState());
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => cubit.animationDuration).thenReturn(Duration.zero);
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockChatCalendarBloc extends MockBloc<CalendarEvent, CalendarState>
    implements ChatCalendarBloc {}
