import 'dart:async';

import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/view/account_recovery_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('settings page loads recovery status with current password', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.recoveryStatus(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).thenAnswer(
      (_) async => const provisioning.RecoveryStatus(
        recoveryEmailConfigured: true,
        maskedRecoveryEmail: 'a***@example.com',
        totpConfigured: false,
      ),
    );
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        profileCubit: _profileCubit(jid: 'alpha@axi.im'),
        showOpener: showOpener,
        childBuilder: (_) => const AccountRecoverySettingsPage(),
      ),
    );

    final field = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    field.controller?.text = 'current-password';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    verify(
      () => settingsCubit.recoveryStatus(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).called(1);
    expect(find.text('a***@example.com'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    verify(
      () => settingsCubit.recoveryStatus(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).called(1);
    expect(find.text('Old password'), findsNothing);
  });

  testWidgets('wrong recovery settings password keeps entered value', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.recoveryStatus(
        accountJid: 'alpha@axi.im',
        password: 'wrong-password',
      ),
    ).thenThrow(
      const provisioning.EmailProvisioningApiRejectedException(
        code: provisioning.EmailProvisioningApiErrorCode.authFailed,
        statusCode: 401,
        isRecoverable: true,
      ),
    );
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        profileCubit: _profileCubit(jid: 'alpha@axi.im'),
        showOpener: showOpener,
        childBuilder: (_) => const AccountRecoverySettingsPage(),
      ),
    );

    final passwordField = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    passwordField.controller?.text = 'wrong-password';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final submittedField = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    expect(submittedField.controller?.text, 'wrong-password');
    const message = 'Incorrect password. Please try again.';
    expect(find.text(message), findsOneWidget);
    _expectDestructiveText(tester, message);
    _expectAbove(tester, find.text(message), find.byType(AxiTextFormField));
  });

  testWidgets('configured recovery email edit dialog can remove method', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.recoveryStatus(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).thenAnswer(
      (_) async => const provisioning.RecoveryStatus(
        recoveryEmailConfigured: true,
        recoveryEmail: 'recovery@example.com',
        maskedRecoveryEmail: 'r***@example.com',
        totpConfigured: false,
      ),
    );
    when(
      () => settingsCubit.removeRecoveryEmail(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).thenAnswer((_) async {});
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        profileCubit: _profileCubit(jid: 'alpha@axi.im'),
        showOpener: showOpener,
        childBuilder: (_) => const AccountRecoverySettingsPage(),
      ),
    );

    final passwordField = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    passwordField.controller?.text = 'current-password';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recovery email'));
    await tester.pumpAndSettle();

    final field = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    expect(field.controller?.text, 'recovery@example.com');

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    verify(
      () => settingsCubit.removeRecoveryEmail(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).called(1);
  });

  testWidgets('recovery email add dialog ignores stale current email', (
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
              showRecoveryEmailSetupDialog(
                context,
                accountJid: 'alpha@axi.im',
                currentPassword: 'current-password',
                currentRecoveryEmail: 'stale@example.com',
              ),
            );
          },
          child: const Text('Open recovery email'),
        ),
      ),
    );

    await tester.tap(find.text('Open recovery email'));
    await tester.pumpAndSettle();

    final field = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('configured authenticator edit dialog can remove method', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.recoveryStatus(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).thenAnswer(
      (_) async => const provisioning.RecoveryStatus(
        recoveryEmailConfigured: false,
        totpConfigured: true,
      ),
    );
    when(
      () => settingsCubit.removeRecoveryTotp(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).thenAnswer((_) async {});
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        profileCubit: _profileCubit(jid: 'alpha@axi.im'),
        showOpener: showOpener,
        childBuilder: (_) => const AccountRecoverySettingsPage(),
      ),
    );

    final passwordField = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    passwordField.controller?.text = 'current-password';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    expect(find.text('Create new'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    verify(
      () => settingsCubit.removeRecoveryTotp(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).called(1);
  });

  testWidgets('configured authenticator replacement continues after secret', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.recoveryStatus(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).thenAnswer(
      (_) async => const provisioning.RecoveryStatus(
        recoveryEmailConfigured: false,
        totpConfigured: true,
      ),
    );
    when(
      () => settingsCubit.startRecoveryTotpSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).thenAnswer(
      (_) async => const provisioning.RecoveryTotpSetup(
        otpauthUri: 'otpauth://totp/Axichat:alpha@axi.im?secret=ABC123',
        secret: 'ABC123',
        challenge: 'challenge-id',
      ),
    );
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RecoveryHarness(
        settingsCubit: settingsCubit,
        profileCubit: _profileCubit(jid: 'alpha@axi.im'),
        showOpener: showOpener,
        childBuilder: (_) => const AccountRecoverySettingsPage(),
      ),
    );

    final passwordField = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    passwordField.controller?.text = 'current-password';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new'));
    await tester.pumpAndSettle();

    expect(find.text('Create new'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(AxiOtpFormField), findsOneWidget);
  });

  testWidgets('showRecoveryEmailSetupDialog survives opener disposal', (
    tester,
  ) async {
    await _pumpRecoverySetupDialog(
      tester,
      openLabel: 'Open recovery email',
      open: (context) =>
          showRecoveryEmailSetupDialog(context, accountJid: 'alpha@axi.im'),
    );
  });

  testWidgets('showRecoveryTotpSetupDialog survives opener disposal', (
    tester,
  ) async {
    await _pumpRecoverySetupDialog(
      tester,
      openLabel: 'Open recovery totp',
      open: (context) =>
          showRecoveryTotpSetupDialog(context, accountJid: 'alpha@axi.im'),
    );
  });

  testWidgets('recovery setup dialogs can use a settings-session password', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.startRecoveryEmailSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
        recoveryEmail: 'recovery@example.com',
      ),
    ).thenAnswer(
      (_) async =>
          const provisioning.RecoveryEmailChallenge(challenge: 'challenge-id'),
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
              showRecoveryEmailSetupDialog(
                context,
                accountJid: 'alpha@axi.im',
                currentPassword: 'current-password',
              ),
            );
          },
          child: const Text('Open recovery email'),
        ),
      ),
    );

    await tester.tap(find.text('Open recovery email'));
    await tester.pumpAndSettle();

    expect(find.text('Old password'), findsNothing);
    final field = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    field.controller?.text = 'recovery@example.com';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    verify(
      () => settingsCubit.startRecoveryEmailSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
        recoveryEmail: 'recovery@example.com',
      ),
    ).called(1);
  });

  testWidgets('recovery email setup code step can go back and change email', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.startRecoveryEmailSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
        recoveryEmail: 'first@example.com',
      ),
    ).thenAnswer(
      (_) async =>
          const provisioning.RecoveryEmailChallenge(challenge: 'first-id'),
    );
    when(
      () => settingsCubit.startRecoveryEmailSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
        recoveryEmail: 'second@example.com',
      ),
    ).thenAnswer(
      (_) async =>
          const provisioning.RecoveryEmailChallenge(challenge: 'second-id'),
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
              showRecoveryEmailSetupDialog(
                context,
                accountJid: 'alpha@axi.im',
                currentPassword: 'current-password',
              ),
            );
          },
          child: const Text('Open recovery email'),
        ),
      ),
    );

    await tester.tap(find.text('Open recovery email'));
    await tester.pumpAndSettle();
    final emailField = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    emailField.controller?.text = 'first@example.com';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    final updatedEmailField = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    expect(updatedEmailField.controller?.text, 'first@example.com');
    updatedEmailField.controller?.text = 'second@example.com';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    verify(
      () => settingsCubit.startRecoveryEmailSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
        recoveryEmail: 'second@example.com',
      ),
    ).called(1);
  });

  testWidgets('recovery email setup maps unavailable service error', (
    tester,
  ) async {
    await _expectRecoveryEmailSetupError(
      tester,
      error: const provisioning.EmailProvisioningApiUnavailableException(
        statusCode: 503,
      ),
      message: 'Service unavailable',
    );
  });

  testWidgets('recovery email setup maps xmpp dependency error', (
    tester,
  ) async {
    await _expectRecoveryEmailSetupError(
      tester,
      error: const provisioning.EmailProvisioningApiRejectedException(
        code: provisioning.EmailProvisioningApiErrorCode.xmppServiceUnavailable,
        statusCode: 503,
        isRecoverable: true,
      ),
      message: 'Service unavailable',
    );
  });

  testWidgets('TOTP setup confirmation uses OTP input', (tester) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.startRecoveryTotpSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
      ),
    ).thenAnswer(
      (_) async => const provisioning.RecoveryTotpSetup(
        otpauthUri: 'otpauth://totp/Axichat:alpha@axi.im?secret=ABC123',
        secret: 'ABC123',
        challenge: 'challenge-id',
      ),
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
              showRecoveryTotpSetupDialog(
                context,
                accountJid: 'alpha@axi.im',
                currentPassword: 'current-password',
              ),
            );
          },
          child: const Text('Open recovery totp'),
        ),
      ),
    );

    await tester.tap(find.text('Open recovery totp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
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

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(AxiOtpFormField), findsNothing);
    expect(
      find.text(
        'Generate an authenticator secret for this account, then enter the 6-digit code from your app.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('recovery email setup confirmation sends OTP input', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    when(
      () => settingsCubit.startRecoveryEmailSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
        recoveryEmail: 'recovery@example.com',
      ),
    ).thenAnswer(
      (_) async =>
          const provisioning.RecoveryEmailChallenge(challenge: 'challenge-id'),
    );
    when(
      () => settingsCubit.confirmRecoveryEmailSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
        challenge: 'challenge-id',
        code: '123456',
      ),
    ).thenThrow(
      const provisioning.EmailProvisioningApiRejectedException(
        code: provisioning.EmailProvisioningApiErrorCode.invalidCode,
        statusCode: 401,
        isRecoverable: true,
      ),
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
              showRecoveryEmailSetupDialog(
                context,
                accountJid: 'alpha@axi.im',
                currentPassword: 'current-password',
              ),
            );
          },
          child: const Text('Open recovery email'),
        ),
      ),
    );

    await tester.tap(find.text('Open recovery email'));
    await tester.pumpAndSettle();
    final field = tester
        .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
        .single;
    field.controller?.text = 'recovery@example.com';
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(ShadInput).first, '123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    verify(
      () => settingsCubit.confirmRecoveryEmailSetup(
        accountJid: 'alpha@axi.im',
        password: 'current-password',
        challenge: 'challenge-id',
        code: '123456',
      ),
    ).called(1);
    const message = 'The code is not valid.';
    expect(find.text(message), findsOneWidget);
    _expectDestructiveText(tester, message);
    _expectAbove(tester, find.text(message), find.byType(ShadInputOTP));
  });
}

Future<void> _expectRecoveryEmailSetupError(
  WidgetTester tester, {
  required Object error,
  required String message,
}) async {
  final settingsCubit = _settingsCubit();
  when(
    () => settingsCubit.startRecoveryEmailSetup(
      accountJid: 'alpha@axi.im',
      password: 'current-password',
      recoveryEmail: 'recovery@example.com',
    ),
  ).thenThrow(error);
  final showOpener = ValueNotifier<bool>(true);
  addTearDown(showOpener.dispose);

  await tester.pumpWidget(
    _RecoveryHarness(
      settingsCubit: settingsCubit,
      showOpener: showOpener,
      childBuilder: (context) => AxiButton.primary(
        onPressed: () {
          unawaited(
            showRecoveryEmailSetupDialog(
              context,
              accountJid: 'alpha@axi.im',
              currentPassword: 'current-password',
            ),
          );
        },
        child: const Text('Open recovery email'),
      ),
    ),
  );

  await tester.tap(find.text('Open recovery email'));
  await tester.pumpAndSettle();
  final field = tester
      .widgetList<AxiTextFormField>(find.byType(AxiTextFormField))
      .single;
  field.controller?.text = 'recovery@example.com';
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  expect(find.text(message), findsOneWidget);
  _expectDestructiveText(tester, message);
  _expectAbove(tester, find.text(message), find.byType(AxiTextFormField));
  expect(
    find.text('Unable to reach the email server. Please try again.'),
    findsNothing,
  );
}

void _expectDestructiveText(WidgetTester tester, String message) {
  final finder = find.text(message);
  final text = tester.widget<Text>(finder);
  expect(
    text.style?.color,
    ShadTheme.of(tester.element(finder)).colorScheme.destructive,
  );
}

void _expectAbove(WidgetTester tester, Finder upper, Finder lower) {
  expect(tester.getTopLeft(upper).dy, lessThan(tester.getTopLeft(lower).dy));
}

Future<void> _pumpRecoverySetupDialog(
  WidgetTester tester, {
  required String openLabel,
  required Future<bool> Function(BuildContext context) open,
}) async {
  final settingsCubit = _settingsCubit();
  final showOpener = ValueNotifier<bool>(true);
  addTearDown(showOpener.dispose);

  await tester.pumpWidget(
    _RecoveryHarness(
      settingsCubit: settingsCubit,
      showOpener: showOpener,
      childBuilder: (context) => AxiButton.primary(
        onPressed: () {
          unawaited(open(context));
        },
        child: Text(openLabel),
      ),
    ),
  );

  await tester.tap(find.text(openLabel));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  showOpener.value = false;
  await tester.pump();
  expect(tester.takeException(), isNull);
}

class _RecoveryHarness extends StatelessWidget {
  const _RecoveryHarness({
    required this.settingsCubit,
    this.profileCubit,
    required this.showOpener,
    required this.childBuilder,
  });

  final SettingsCubit settingsCubit;
  final ProfileCubit? profileCubit;
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
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<ProfileCubit>.value(
            value: profileCubit ?? _profileCubit(),
          ),
        ],
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

ProfileCubit _profileCubit({String jid = 'alpha@axi.im'}) {
  final cubit = _MockProfileCubit();
  when(
    () => cubit.state,
  ).thenReturn(ProfileState(jid: jid, resource: '', username: 'alpha'));
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<ProfileState>.empty());
  return cubit;
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

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
