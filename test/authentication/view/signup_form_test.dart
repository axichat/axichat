// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/signup_form.dart';
import 'package:axichat/src/avatar/bloc/signup_avatar_cubit.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart' hide EditableText;
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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

  testWidgets('Signup first step blocks until a custom server is selected', (
    tester,
  ) async {
    await tester.pumpSignupForm(const EndpointConfig());

    tester.enterUsername('validusername');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.textContaining('Choose a custom server'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('Signup first step advances after choosing a custom server', (
    tester,
  ) async {
    await tester.pumpSignupForm(const EndpointConfig());

    await tester.tap(find.text('Choose server'));
    await tester.pumpAndSettle();
    tester.enterEndpointDomain('selfhosted.example');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verifyNever(() => tester.authenticationCubit.updateEndpointConfig(any()));
    verifyNever(() => tester.settingsCubit.updateEndpointConfig(any()));

    tester.enterUsername('validusername');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('@selfhosted.example'), findsNothing);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets(
    'Self-hosted weak signup password advances without breach check',
    (tester) async {
      await tester.pumpSignupForm(const EndpointConfig());

      await tester.tap(find.text('Choose server'));
      await tester.pumpAndSettle();
      tester.enterEndpointDomain('selfhosted.example');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      tester.enterUsername('validusername');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final passwordInputs = tester
          .widgetList<PasswordInput>(find.byType(PasswordInput))
          .toList();
      passwordInputs[0].controller.text = 'abc';
      passwordInputs[1].controller.text = 'abc';
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      verifyNever(
        () => tester.authenticationCubit.checkPasswordBreach(
          password: any(named: 'password'),
        ),
      );
      expect(find.byType(PasswordInput), findsNothing);
    },
  );
}

extension on WidgetTester {
  _MockAuthenticationCubit get authenticationCubit =>
      element(find.byType(SignupForm)).read<AuthenticationCubit>()
          as _MockAuthenticationCubit;

  MockSettingsCubit get settingsCubit =>
      element(find.byType(SignupForm)).read<SettingsCubit>()
          as MockSettingsCubit;

  void enterUsername(String username) {
    widgetList<AxiTextFormField>(
      find.byType(AxiTextFormField),
    ).first.controller?.text = username;
  }

  void enterEndpointDomain(String domain) {
    final field = widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .singleWhere((field) {
          final placeholder = field.placeholder;
          return placeholder is Text && placeholder.data == 'Domain';
        });
    field.controller?.text = domain;
  }

  Future<void> pumpSignupForm(EndpointConfig config) async {
    final authenticationCubit = _MockAuthenticationCubit();
    when(
      () => authenticationCubit.state,
    ).thenReturn(AuthenticationNone(config: config));
    when(
      () => authenticationCubit.stream,
    ).thenAnswer((_) => const Stream<AuthenticationState>.empty());
    when(
      () => authenticationCubit.fetchCaptchaSrcWithRetry(
        config: any(named: 'config'),
      ),
    ).thenAnswer((_) async => '');
    when(
      authenticationCubit.loadRememberMeChoice,
    ).thenAnswer((_) async => true);
    await pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(
            value: _settingsCubit(config: config),
          ),
          BlocProvider<AuthenticationCubit>.value(value: authenticationCubit),
          BlocProvider(create: (_) => SignupAvatarCubit()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
            child: const Scaffold(
              body: Center(child: SignupForm(visible: false)),
            ),
          ),
        ),
      ),
    );
  }
}

MockSettingsCubit _settingsCubit({required EndpointConfig config}) {
  final settingsCubit = MockSettingsCubit();
  when(
    () => settingsCubit.state,
  ).thenReturn(SettingsState(endpointConfig: config));
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  when(
    () => settingsCubit.updateEndpointConfig(any()),
  ).thenAnswer((_) async {});
  return settingsCubit;
}

class _MockAuthenticationCubit extends Mock implements AuthenticationCubit {}
