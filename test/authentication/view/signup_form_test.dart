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
  testWidgets('Signup first step allows default server in debug', (
    tester,
  ) async {
    await tester.pumpSignupForm(const EndpointConfig());

    tester.enterUsername('validusername');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('@axi.im'), findsNothing);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('Signup first step advances after choosing a custom server', (
    tester,
  ) async {
    await tester.pumpSignupForm(
      const EndpointConfig(domain: 'selfhosted.example'),
    );

    tester.enterUsername('validusername');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('@selfhosted.example'), findsNothing);
    expect(find.text('Back'), findsOneWidget);
  });
}

extension on WidgetTester {
  void enterUsername(String username) {
    widgetList<AxiTextFormField>(
      find.byType(AxiTextFormField),
    ).first.controller?.text = username;
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
      authenticationCubit.fetchCaptchaSrcWithRetry,
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
  return settingsCubit;
}

class _MockAuthenticationCubit extends Mock implements AuthenticationCubit {}
