// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/authentication/view/endpoint_config_sheet.dart';
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
  test(
    'Endpoint signup policy requires custom server without debug allowance',
    () {
      expect(
        const EndpointConfig().requiresCustomSignupEndpoint(
          allowDefaultEndpoint: false,
        ),
        isTrue,
      );
      expect(
        const EndpointConfig(
          domain: 'selfhosted.example',
        ).requiresCustomSignupEndpoint(allowDefaultEndpoint: false),
        isFalse,
      );
    },
  );

  testWidgets('Login endpoint suffix keeps default axi.im label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        child: EndpointSuffix(server: EndpointConfig.defaultDomain),
      ),
    );

    expect(find.text('@axi.im'), findsOneWidget);
    expect(find.text('Choose server'), findsNothing);
  });

  testWidgets('Signup endpoint suffix keeps default axi.im label in debug', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        child: SignupEndpointSuffix(config: EndpointConfig()),
      ),
    );

    expect(find.text('@axi.im'), findsOneWidget);
    expect(find.text('Choose server'), findsNothing);
  });

  testWidgets('Signup endpoint suffix shows selected custom endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        child: SignupEndpointSuffix(
          config: EndpointConfig(domain: 'selfhosted.example'),
        ),
      ),
    );

    expect(find.text('@selfhosted.example'), findsOneWidget);
  });

  testWidgets('Endpoint config sheet leaves default domain empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(child: EndpointConfigSheet(compact: false)),
    );

    expect(_textFormFieldAt(tester, 0).controller?.text, isEmpty);
  });

  testWidgets('Endpoint config sheet preloads custom domain', (tester) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        settingsState: SettingsState(
          endpointConfig: EndpointConfig(domain: 'selfhosted.example'),
        ),
        child: EndpointConfigSheet(compact: false),
      ),
    );

    expect(_textFormFieldAt(tester, 0).controller?.text, 'selfhosted.example');
  });
}

AxiTextFormField _textFormFieldAt(WidgetTester tester, int index) {
  return tester
      .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
      .elementAt(index);
}

class _EndpointSuffixTestApp extends StatelessWidget {
  const _EndpointSuffixTestApp({
    this.settingsState = const SettingsState(),
    required this.child,
  });

  final SettingsState settingsState;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settingsCubit = MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(settingsState);
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
    return BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
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
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }
}
