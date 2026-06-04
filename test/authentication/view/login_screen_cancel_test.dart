// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/login_screen.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/startup/auth_bootstrap.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const EndpointConfig());
  });

  testWidgets(
    'pre-network cancel stays hidden when network phase starts fast',
    (tester) async {
      final auth = _AuthenticationDriver();
      addTearDown(auth.close);

      await tester.pumpLoginScreen(auth);

      auth.emit(
        const AuthenticationLogInInProgress(
          phase: AuthenticationLoginPhase.preNetwork,
        ),
      );
      await tester.pump();
      auth.emit(const AuthenticationLogInInProgress());
      await tester.pump();
      await tester.pump(axiMotion.authLoginCancelRevealDelay);
      await tester.pump();

      expect(find.byKey(_loginCancelButtonKey), findsNothing);
    },
  );

  testWidgets('pre-network cancel appears when cancelable state persists', (
    tester,
  ) async {
    final auth = _AuthenticationDriver();
    addTearDown(auth.close);

    await tester.pumpLoginScreen(auth);

    auth.emit(
      const AuthenticationLogInInProgress(
        phase: AuthenticationLoginPhase.preNetwork,
      ),
    );
    await tester.pump();
    await tester.pump(axiMotion.authLoginCancelRevealDelay);
    await tester.pump();

    expect(find.byKey(_loginCancelButtonKey), findsOneWidget);
  });

  testWidgets('visible pre-network cancel calls cancelLogin without throwing', (
    tester,
  ) async {
    final auth = _AuthenticationDriver();
    addTearDown(auth.close);

    await tester.pumpLoginScreen(auth);
    auth.emit(
      const AuthenticationLogInInProgress(
        phase: AuthenticationLoginPhase.preNetwork,
      ),
    );
    await tester.pump();
    await tester.pump(axiMotion.authLoginCancelRevealDelay);
    await tester.pump();

    await tester.tap(find.byKey(_loginCancelButtonKey));
    await tester.pump();

    verify(() => auth.cubit.cancelLogin()).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network login phase never shows cancel', (tester) async {
    final auth = _AuthenticationDriver();
    addTearDown(auth.close);

    await tester.pumpLoginScreen(auth);

    auth.emit(const AuthenticationLogInInProgress());
    await tester.pump();
    await tester.pump(axiMotion.authLoginCancelRevealDelay);
    await tester.pump();

    expect(find.byKey(_loginCancelButtonKey), findsNothing);
  });

  testWidgets('visible pre-network cancel hides when network phase starts', (
    tester,
  ) async {
    final auth = _AuthenticationDriver();
    addTearDown(auth.close);

    await tester.pumpLoginScreen(auth);

    auth.emit(
      const AuthenticationLogInInProgress(
        phase: AuthenticationLoginPhase.preNetwork,
      ),
    );
    await tester.pump();
    await tester.pump(axiMotion.authLoginCancelRevealDelay);
    await tester.pump();

    expect(find.byKey(_loginCancelButtonKey), findsOneWidget);

    auth.emit(const AuthenticationLogInInProgress());
    await tester.pump();

    expect(find.byKey(_loginCancelButtonKey), findsNothing);
  });
}

const _loginCancelButtonKey = ValueKey('login-cancel-button');

extension on WidgetTester {
  Future<void> pumpLoginScreen(_AuthenticationDriver auth) async {
    await pumpWidget(
      _LoginScreenHarness(
        authenticationCubit: auth.cubit,
        settingsCubit: _settingsCubit(),
        credentialStore: MockCredentialStore(),
      ),
    );
  }
}

class _LoginScreenHarness extends StatelessWidget {
  const _LoginScreenHarness({
    required this.authenticationCubit,
    required this.settingsCubit,
    required this.credentialStore,
  });

  final AuthenticationCubit authenticationCubit;
  final SettingsCubit settingsCubit;
  final CredentialStore credentialStore;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.build(
      shadColor: ShadColor.blue,
      brightness: Brightness.light,
      platform: defaultTargetPlatform,
    );
    return ShadApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthBootstrap>.value(
            value: const AuthBootstrap(hasStoredLoginCredentials: false),
          ),
          RepositoryProvider<CredentialStore>.value(value: credentialStore),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BlocProvider<AuthenticationCubit>.value(value: authenticationCubit),
          ],
          child: const LoginScreen(),
        ),
      ),
    );
  }
}

class _AuthenticationDriver {
  _AuthenticationDriver() {
    when(() => cubit.state).thenAnswer((_) => _state);
    when(() => cubit.stream).thenAnswer((_) => _controller.stream);
    when(cubit.beginPendingLogoutRecovery).thenAnswer((_) {});
    when(cubit.loadRememberMeChoice).thenAnswer((_) async => true);
    when(
      () => cubit.fetchCaptchaSrcWithRetry(config: any(named: 'config')),
    ).thenAnswer((_) async => '');
    when(cubit.cancelLogin).thenAnswer((_) async {});
  }

  final _MockAuthenticationCubit cubit = _MockAuthenticationCubit();
  final StreamController<AuthenticationState> _controller =
      StreamController<AuthenticationState>.broadcast();
  AuthenticationState _state = const AuthenticationNone();

  void emit(AuthenticationState state) {
    _state = state;
    _controller.add(state);
  }

  Future<void> close() async {
    await _controller.close();
  }
}

MockSettingsCubit _settingsCubit() {
  final settingsCubit = MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(baseAnimationDuration);
  when(() => settingsCubit.authCompletionDuration).thenReturn(Duration.zero);
  return settingsCubit;
}

class _MockAuthenticationCubit extends Mock implements AuthenticationCubit {}
