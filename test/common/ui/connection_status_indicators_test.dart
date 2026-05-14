// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('syncing transport chips do not show progress indicators', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _ConnectionStatusTestApp(
        child: ConnectionStatusIndicators(
          xmppState: ConnectionState.connecting,
          emailState: EmailSyncState.recovering('Syncing'),
          emailEnabled: true,
        ),
      ),
    );

    expect(find.byType(AxiProgressIndicator), findsNothing);
  });

  testWidgets('connecting banner shows progress after status text', (
    tester,
  ) async {
    final settingsCubit = _mockSettingsCubit();
    final xmppStates = StreamController<ConnectionState>.broadcast();
    final xmppService = _MockXmppService();
    when(
      () => xmppService.connectionState,
    ).thenReturn(ConnectionState.connecting);
    when(
      () => xmppService.connectivityStream,
    ).thenAnswer((_) => xmppStates.stream);
    when(() => xmppService.demoOfflineMode).thenReturn(false);
    final connectivityCubit = ConnectivityCubit(
      xmppBase: xmppService,
      emailEnabled: true,
    );
    addTearDown(connectivityCubit.close);
    addTearDown(xmppStates.close);

    await tester.pumpWidget(
      _ConnectionStatusTestApp(
        settingsCubit: settingsCubit,
        connectivityCubit: connectivityCubit,
        child: const ConnectivityIndicator(),
      ),
    );
    await tester.pump();

    final progress = find.byType(AxiProgressIndicator);
    final cloudIcon = find.byIcon(LucideIcons.cloudCog);
    final statusText = find.text(
      lookupAppLocalizations(const Locale('en')).connectivityStatusConnecting,
    );

    expect(progress, findsOneWidget);
    expect(cloudIcon, findsOneWidget);
    expect(statusText, findsOneWidget);

    const spacing = axiSpacing;
    expect(
      tester.getCenter(cloudIcon).dx,
      lessThan(tester.getTopLeft(statusText).dx),
    );
    expect(
      tester.getTopLeft(progress).dx,
      greaterThan(tester.getTopRight(statusText).dx),
    );
    expect(
      tester.getTopLeft(progress).dx - tester.getTopRight(statusText).dx,
      closeTo(spacing.m, spacing.xs),
    );
  });
}

SettingsCubit _mockSettingsCubit() {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  return settingsCubit;
}

class _ConnectionStatusTestApp extends StatelessWidget {
  const _ConnectionStatusTestApp({
    required this.child,
    this.settingsCubit,
    this.connectivityCubit,
  });

  final Widget child;
  final SettingsCubit? settingsCubit;
  final ConnectivityCubit? connectivityCubit;

  @override
  Widget build(BuildContext context) {
    Widget body = ShadTheme(
      data: ShadThemeData(
        colorScheme: const ShadSlateColorScheme.light(),
        brightness: Brightness.light,
      ),
      child: Scaffold(body: Center(child: child)),
    );
    if (connectivityCubit case final cubit?) {
      body = BlocProvider<ConnectivityCubit>.value(value: cubit, child: body);
    }
    if (settingsCubit case final cubit?) {
      body = BlocProvider<SettingsCubit>.value(value: cubit, child: body);
    }
    return MaterialApp(
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[
          axiBorders,
          axiRadii,
          axiSpacing,
          axiSizing,
          axiMotion,
        ],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: body,
    );
  }
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockXmppService extends Mock implements XmppService {}
