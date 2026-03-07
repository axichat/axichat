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
  testWidgets('large buttons do not use smaller text than regular buttons', (
    tester,
  ) async {
    await tester.pumpWidget(const _AxiButtonTestApp());

    final smFontSize = _buttonLabelFontSize(tester, const Key('button-sm'));
    final regularFontSize = _buttonLabelFontSize(
      tester,
      const Key('button-regular'),
    );
    final lgFontSize = _buttonLabelFontSize(tester, const Key('button-lg'));

    expect(smFontSize, lessThan(regularFontSize));
    expect(lgFontSize, greaterThanOrEqualTo(regularFontSize));
  });
}

double _buttonLabelFontSize(WidgetTester tester, Key buttonKey) {
  final richTextFinder = find.descendant(
    of: find.byKey(buttonKey),
    matching: find.byType(RichText),
  );
  final richText = tester.widget<RichText>(richTextFinder.first);
  return richText.text.style?.fontSize ?? 0;
}

class _AxiButtonTestApp extends StatelessWidget {
  const _AxiButtonTestApp();

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  AxiButton.primary(
                    key: Key('button-sm'),
                    size: AxiButtonSize.sm,
                    child: Text('Small'),
                  ),
                  AxiButton.primary(
                    key: Key('button-regular'),
                    child: Text('Regular'),
                  ),
                  AxiButton.primary(
                    key: Key('button-lg'),
                    size: AxiButtonSize.lg,
                    child: Text('Large'),
                  ),
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
