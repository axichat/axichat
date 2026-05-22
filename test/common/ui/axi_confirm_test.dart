// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('confirm can render a green title chip', (tester) async {
    await tester.pumpWidget(const _AxiConfirmTestApp());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Email encryption'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Expert warning body'), findsOneWidget);

    final chipText = tester.widget<Text>(find.text('Beta'));
    expect(chipText.style?.color, axiGreen);
  });
}

class _AxiConfirmTestApp extends StatelessWidget {
  const _AxiConfirmTestApp();

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
              child: Builder(
                builder: (context) {
                  return AxiButton.primary(
                    onPressed: () {
                      unawaited(
                        confirm(
                          context,
                          title: 'Email encryption',
                          titleChipLabel: 'Beta',
                          titleChipTone: AxiStatusChipTone.success,
                          message: 'Expert warning body',
                          confirmLabel: 'Continue',
                          cancelLabel: 'Cancel',
                          destructiveConfirm: false,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
