import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/view/sidebar/task_sidebar.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../calendar_test_utils.dart';

void main() {
  setUpAll(registerCalendarFallbackValues);

  testWidgets('TaskSidebar popovers open without context errors', (
    tester,
  ) async {
    final state = CalendarTestData.weekView();
    await tester.pumpWidget(
      _wrap(state: state, child: const TaskSidebar<CalendarBloc>()),
    );
    await tester.pumpAndSettle();

    final actionButton = find.byTooltip('Actions');
    if (actionButton.evaluate().isNotEmpty) {
      await tester.tap(actionButton.first);
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
  });
}

Widget _wrap({required CalendarState state, required Widget child}) {
  final settingsCubit = _settingsCubit();
  final bloc = MockCalendarBloc();
  when(() => bloc.state).thenReturn(state);
  when(
    () => bloc.stream,
  ).thenAnswer((_) => const Stream<CalendarState>.empty());
  when(() => bloc.add(any<CalendarEvent>())).thenReturn(null);
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CalendarBloc>.value(value: bloc),
          BlocProvider<BaseCalendarBloc>.value(value: bloc),
        ],
        child: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: Scaffold(
            body: SizedBox(width: 420, height: 860, child: child),
          ),
        ),
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
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
