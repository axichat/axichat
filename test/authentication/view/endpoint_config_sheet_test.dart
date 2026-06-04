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
  test('Endpoint signup policy requires selfhost for axi.im', () {
    expect(const EndpointConfig().requiresCustomSignupEndpoint, isTrue);
    expect(
      const EndpointConfig(
        domain: 'selfhosted.example',
      ).requiresCustomSignupEndpoint,
      isFalse,
    );
  });

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

  testWidgets('Signup endpoint suffix asks for a server by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _EndpointSuffixTestApp(
        child: SignupEndpointSuffix(config: null, onChanged: (_) {}),
      ),
    );

    expect(find.text('@axi.im'), findsNothing);
    expect(find.text('Choose server'), findsOneWidget);
  });

  testWidgets('Signup endpoint suffix shows selected custom endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _EndpointSuffixTestApp(
        child: SignupEndpointSuffix(
          config: const EndpointConfig(domain: 'selfhosted.example'),
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('@selfhosted.example'), findsOneWidget);
  });

  testWidgets('Signup endpoint suffix treats blank endpoint as unconfigured', (
    tester,
  ) async {
    await tester.pumpWidget(
      _EndpointSuffixTestApp(
        child: SignupEndpointSuffix(
          config: const EndpointConfig(domain: ''),
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Choose server'), findsOneWidget);
    expect(find.text('@'), findsNothing);
  });

  testWidgets('Endpoint config sheet leaves default domain empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        child: EndpointConfigSheet(
          compact: false,
          mode: EndpointConfigSheetMode.login,
        ),
      ),
    );

    expect(_textFormFieldAt(tester, 0).controller?.text, isEmpty);
  });

  testWidgets('Endpoint config sheet preloads custom domain', (tester) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        settingsState: SettingsState(
          endpointConfig: EndpointConfig(domain: 'selfhosted.example'),
        ),
        child: EndpointConfigSheet(
          compact: false,
          mode: EndpointConfigSheetMode.login,
        ),
      ),
    );

    expect(_textFormFieldAt(tester, 0).controller?.text, 'selfhosted.example');
  });

  testWidgets('Signup endpoint config sheet rejects blank domain', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        child: EndpointConfigSheet(
          compact: false,
          mode: EndpointConfigSheetMode.signup,
          initialConfig: EndpointConfig(domain: ''),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('Choose a custom server'), findsOneWidget);
  });

  testWidgets('Endpoint config sheet describes login and signup modes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        child: EndpointConfigSheet(
          compact: false,
          mode: EndpointConfigSheetMode.login,
        ),
      ),
    );

    expect(
      find.textContaining('Leave it blank to keep the current domain'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Use Reset to return to axi.im'),
      findsOneWidget,
    );
    expect(find.textContaining('axichat/selfhost'), findsOneWidget);
    expect(find.textContaining('axichat/server'), findsNothing);

    await tester.pumpWidget(
      const _EndpointSuffixTestApp(
        child: EndpointConfigSheet(
          compact: false,
          mode: EndpointConfigSheetMode.signup,
          initialConfig: EndpointConfig(domain: ''),
        ),
      ),
    );

    expect(
      find.textContaining('custom server you want to sign up on'),
      findsOneWidget,
    );
    expect(find.textContaining('Leave it blank'), findsNothing);
    expect(find.textContaining('axichat/selfhost'), findsOneWidget);
    expect(find.textContaining('axichat/server'), findsNothing);
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
