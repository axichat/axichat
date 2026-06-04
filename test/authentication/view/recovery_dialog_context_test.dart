import 'dart:async';

import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/authentication/view/recovery_dialog.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('showAccountRecoveryDialog survives opener disposal', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        showOpener: showOpener,
        childBuilder: (context) => AxiButton.primary(
          onPressed: () {
            unawaited(showAccountRecoveryDialog(context));
          },
          child: const Text('Open account recovery'),
        ),
      ),
    );

    await tester.tap(find.text('Open account recovery'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    showOpener.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery username field uses fixed axi.im suffix', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        showOpener: showOpener,
        childBuilder: (context) => AxiButton.primary(
          onPressed: () {
            unawaited(
              showAccountRecoveryDialog(
                context,
                initialUsername: 'alice@axi.im',
              ),
            );
          },
          child: const Text('Open account recovery'),
        ),
      ),
    );

    await tester.tap(find.text('Open account recovery'));
    await tester.pumpAndSettle();

    expect(find.text('Choose recovery method'), findsOneWidget);
    expect(find.text('@axi.im'), findsOneWidget);
    final field = tester.widget<AxiTextFormField>(
      find.byKey(const ValueKey('recovery-username-field')),
    );
    expect(field.controller?.text, 'alice');
  });

  testWidgets('recovery authenticator code uses OTP input', (tester) async {
    final settingsCubit = _settingsCubit();
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        showOpener: showOpener,
        childBuilder: (context) => AxiButton.primary(
          onPressed: () {
            unawaited(
              showAccountRecoveryDialog(
                context,
                initialUsername: 'alice@axi.im',
              ),
            );
          },
          child: const Text('Open account recovery'),
        ),
      ),
    );

    await tester.tap(find.text('Open account recovery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authenticator code'));
    await tester.pumpAndSettle();

    expect(find.byType(AxiOtpFormField), findsOneWidget);
    expect(find.byType(ShadInputOTP), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(ShadInputOTP),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );
    expect(find.byType(ShadInputOTPSlot), findsNWidgets(6));
  });

  testWidgets('recovery email verify sends challenge and code', (tester) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.startRecoveryEmailReset(
        accountJid: 'alice@axi.im',
        recoveryEmail: 'recovery@example.com',
      ),
    ).thenAnswer(
      (_) async =>
          const provisioning.RecoveryEmailChallenge(challenge: 'challenge-id'),
    );
    when(
      () => settingsCubit.verifyRecoveryEmailReset(
        accountJid: 'alice@axi.im',
        challenge: 'challenge-id',
        code: '123456',
      ),
    ).thenAnswer(
      (_) async =>
          const provisioning.RecoveryResetToken(resetToken: 'reset-token'),
    );
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        showOpener: showOpener,
        childBuilder: (context) => AxiButton.primary(
          onPressed: () {
            unawaited(
              showAccountRecoveryDialog(
                context,
                initialUsername: 'alice@axi.im',
              ),
            );
          },
          child: const Text('Open account recovery'),
        ),
      ),
    );

    await tester.tap(find.text('Open account recovery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email code'));
    await tester.pumpAndSettle();
    tester
            .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
            .last
            .controller
            ?.text =
        'recovery@example.com';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(ShadInput).first, '123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    verify(
      () => settingsCubit.verifyRecoveryEmailReset(
        accountJid: 'alice@axi.im',
        challenge: 'challenge-id',
        code: '123456',
      ),
    ).called(1);
  });
}

class _RecoveryHarness extends StatelessWidget {
  const _RecoveryHarness({
    required this.settingsCubit,
    required this.showOpener,
    required this.childBuilder,
  });

  final SettingsCubit settingsCubit;
  final ValueNotifier<bool> showOpener;
  final WidgetBuilder childBuilder;

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
      home: BlocProvider<SettingsCubit>.value(
        value: settingsCubit,
        child: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: showOpener,
              builder: (context, visible, child) {
                if (!visible) {
                  return const SizedBox.shrink();
                }
                return Builder(builder: childBuilder);
              },
            ),
          ),
        ),
      ),
    );
  }
}

SettingsCubit _settingsCubit() {
  final cubit = _MockSettingsCubit();
  when(() => cubit.state).thenReturn(const SettingsState());
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => cubit.animationDuration).thenReturn(Duration.zero);
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
