import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/view/shell/calendar_navigation.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('CalendarNavigation overlay opens and selects a date', (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      _wrap(
        CalendarNavigation(
          state: CalendarState.initial(),
          onDateSelected: (value) {
            selected = value;
          },
          onViewChanged: (_) {},
          onErrorCleared: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('15').first, warnIfMissed: false);
    await tester.pump();

    expect(selected, isNotNull);
  });
}

Widget _wrap(Widget child) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(body: SizedBox(width: 900, child: child)),
      ),
    ),
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
