import 'dart:ui';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_date_time_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('CalendarDateTimeField overlay opens and selects a day', (
    tester,
  ) async {
    DateTime? selected;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pumpWidget(
      _wrap(
        CalendarDateTimeField(
          value: DateTime(2026, 1, 15),
          placeholder: 'Pick date',
          showTimeSelectors: false,
          onChanged: (value) {
            selected = value;
          },
        ),
      ),
    );
    await mouse.moveTo(Offset.zero);
    await tester.pump();

    await tester.tap(find.textContaining('Jan'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final dayButton = tester
        .widgetList<AxiButton>(find.widgetWithText(AxiButton, '16'))
        .firstWhere((button) => button.onPressed != null);
    dayButton.onPressed?.call();
    await tester.pump();
    if (selected == null && tester.any(find.text('Done'))) {
      final doneButton = tester.widget<AxiButton>(
        find.widgetWithText(AxiButton, 'Done'),
      );
      doneButton.onPressed?.call();
      await tester.pump();
    }

    expect(selected?.day, 16);
  });

  testWidgets('CalendarDateTimeField sheet commits today when empty', (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      _wrap(
        CalendarDateTimeField(
          value: null,
          placeholder: 'Pick date',
          showTimeSelectors: false,
          onChanged: (value) {
            selected = value;
          },
        ),
      ),
    );

    await tester.tap(find.text('Pick date'));
    await tester.pump();
    expect(selected, isNull);

    final doneButton = tester.widget<AxiButton>(
      find.widgetWithText(AxiButton, 'Done'),
    );
    doneButton.onPressed?.call();
    await tester.pump();

    final today = DateTime.now();
    expect(selected?.year, today.year);
    expect(selected?.month, today.month);
    expect(selected?.day, today.day);
  });
}

Widget _wrap(Widget child) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  return BlocProvider<SettingsCubit>.value(
    value: settingsCubit,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(
          body: Center(child: SizedBox(width: 420, child: child)),
        ),
      ),
    ),
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
