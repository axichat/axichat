// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

import 'package:axichat/src/calendar/view/tasks/calendar_date_time_field.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../mocks.dart';

void main() {
  testWidgets('system back closes deadline dropdown before popping route', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    addTearDown(() async {
      await mouse.removePointer();
    });

    await tester.pumpWidget(const _DeadlineBackTestApp());

    await tester.tap(find.byKey(const Key('open-deadline-page')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deadline-page')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deadline-page')), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });
}

class _DeadlineBackTestApp extends StatelessWidget {
  const _DeadlineBackTestApp();

  @override
  Widget build(BuildContext context) {
    final settingsCubit = MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(const SettingsState());
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
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
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open-deadline-page'),
                    onPressed: () {
                      final ShadThemeData shadTheme = ShadTheme.of(context);
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => ShadTheme(
                            data: shadTheme,
                            child: const _DeadlinePage(),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DeadlinePage extends StatefulWidget {
  const _DeadlinePage();

  @override
  State<_DeadlinePage> createState() => _DeadlinePageState();
}

class _DeadlinePageState extends State<_DeadlinePage> {
  DateTime? _value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('deadline-page'),
      body: Center(
        child: CalendarDateTimeField(
          value: _value,
          onChanged: (value) => setState(() => _value = value),
          showTimeSelectors: true,
        ),
      ),
    );
  }
}
