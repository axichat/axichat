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
  testWidgets('AxiMore opens a scroll-controlled bottom sheet on mobile', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_AxiMoreTestApp(observer: observer));

    await tester.tap(find.byType(AxiIconButton));
    await tester.pumpAndSettle();

    expect(observer.lastPushed, isA<ModalBottomSheetRoute<void>>());
    expect(
      (observer.lastPushed! as ModalBottomSheetRoute<void>).isScrollControlled,
      isTrue,
    );
    expect(find.text('Chat settings'), findsOneWidget);
  });
}

class _AxiMoreTestApp extends StatelessWidget {
  const _AxiMoreTestApp({required this.observer});

  final NavigatorObserver observer;

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
        navigatorObservers: [observer],
        theme: ThemeData(
          platform: TargetPlatform.android,
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
              child: AxiMore(
                tooltip: 'More options',
                actions: const [
                  AxiMenuAction(label: 'Action 1', icon: Icons.looks_one),
                  AxiMenuAction(label: 'Action 2', icon: Icons.looks_two),
                  AxiMenuAction(label: 'Action 3', icon: Icons.looks_3),
                  AxiMenuAction(label: 'Action 4', icon: Icons.looks_4),
                  AxiMenuAction(label: 'Action 5', icon: Icons.looks_5),
                  AxiMenuAction(label: 'Action 6', icon: Icons.looks_6),
                  AxiMenuAction(label: 'Action 7', icon: Icons.image),
                  AxiMenuAction(label: 'Chat settings', icon: Icons.settings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
