// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('AxiSelect options use readable text and spaced checkmark', (
    tester,
  ) async {
    await tester.pumpWidget(const _AxiSelectTestApp());

    await tester.tap(find.text('One').first);
    await tester.pumpAndSettle();

    final selectedOption = find.byWidgetPredicate(
      (widget) => widget is ShadOption<String> && widget.value == 'one',
    );
    final normalOption = find.byWidgetPredicate(
      (widget) => widget is ShadOption<String> && widget.value == 'two',
    );
    final selectedTextStyle = tester.widget<DefaultTextStyle>(
      find.descendant(
        of: selectedOption,
        matching: find.byType(DefaultTextStyle),
      ),
    );
    final normalTextStyle = tester.widget<DefaultTextStyle>(
      find.descendant(
        of: normalOption,
        matching: find.byType(DefaultTextStyle),
      ),
    );
    final selectedIconPadding = tester
        .widgetList<Padding>(
          find.descendant(of: selectedOption, matching: find.byType(Padding)),
        )
        .where(
          (padding) =>
              padding.padding ==
              EdgeInsetsDirectional.only(start: axiSpacing.m),
        );

    const colors = ShadSlateColorScheme.light();
    expect(selectedTextStyle.style.color, colors.accentForeground);
    expect(normalTextStyle.style.color, colors.foreground);
    expect(selectedIconPadding, isNotEmpty);
  });
}

class _AxiSelectTestApp extends StatelessWidget {
  const _AxiSelectTestApp();

  @override
  Widget build(BuildContext context) {
    final settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(const SettingsState());
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
    return BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: MaterialApp(
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
            body: Center(
              child: AxiSelect<String>(
                initialValue: 'one',
                selectedOptionBuilder: (_, value) =>
                    Text(value == 'two' ? 'Two' : 'One'),
                options: const [
                  ShadOption(value: 'one', child: Text('One')),
                  ShadOption(value: 'two', child: Text('Two')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
