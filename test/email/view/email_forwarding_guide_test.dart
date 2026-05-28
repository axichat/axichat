import 'dart:async';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/foreground_runtime_controller.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  late ForegroundTaskBridge originalForegroundTaskBridge;

  setUp(() {
    originalForegroundTaskBridge = foregroundTaskBridge;
    foregroundTaskBridge = _RunningForegroundTaskBridge();
    withForeground = true;
    foregroundServiceActive.value = true;
  });

  tearDown(() {
    foregroundTaskBridge = originalForegroundTaskBridge;
    withForeground = false;
    foregroundServiceActive.value = false;
  });

  testWidgets('connect existing email guide omits notification request', (
    tester,
  ) async {
    await _pumpEmailForwardingApp(
      tester,
      child: const EmailForwardingGuideContent(
        forwardingAddress: 'user@example.com',
      ),
    );

    expect(find.byType(NotificationRequest), findsNothing);
    expect(find.text('Mute email notifications'), findsNothing);
    expect(find.text('Link existing email'), findsOneWidget);
  });

  testWidgets('signup welcome uses background messaging setting', (
    tester,
  ) async {
    await _pumpEmailForwardingApp(
      tester,
      child: EmailForwardingWelcomeContent(
        onForegroundActivationStarted: () {},
        onForegroundActivationFinished: () {},
        onForegroundActivated: () async {},
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NotificationRequest), findsOneWidget);
    expect(find.text('Mute email notifications'), findsNothing);
    expect(find.text('Background notifications'), findsOneWidget);
    expect(find.text('Strongly recommended'), findsOneWidget);
  });

  testWidgets('signup background messaging setting updates SettingsCubit', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    await _pumpEmailForwardingApp(
      tester,
      settingsCubit: settingsCubit,
      child: EmailForwardingWelcomeContent(
        onForegroundActivationStarted: () {},
        onForegroundActivationFinished: () {},
        onForegroundActivated: () async {},
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(ShadSwitch));
    await tester.pump();

    verify(
      () => settingsCubit.toggleBackgroundMessaging(
        true,
        accountJid: 'user@example.com',
      ),
    ).called(1);
  });

  testWidgets('background messaging switch is disabled while starting', (
    tester,
  ) async {
    final foregroundStart = Completer<void>();
    final settingsCubit = _settingsCubit();
    final emailService = _emailService();
    when(
      () => emailService.setForegroundKeepalive(true),
    ).thenAnswer((_) => foregroundStart.future);
    await _pumpEmailForwardingApp(
      tester,
      settingsCubit: settingsCubit,
      emailService: emailService,
      child: EmailForwardingWelcomeContent(
        onForegroundActivationStarted: () {},
        onForegroundActivationFinished: () {},
        onForegroundActivated: () async {},
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.widget<ShadSwitch>(find.byType(ShadSwitch)).value, isFalse);

    await tester.tap(find.byType(ShadSwitch));
    await tester.pump();

    final pendingSwitch = tester.widget<ShadSwitch>(find.byType(ShadSwitch));
    expect(pendingSwitch.value, isTrue);
    expect(pendingSwitch.onChanged, isNull);
    verifyNever(
      () => settingsCubit.toggleBackgroundMessaging(
        any(),
        accountJid: any(named: 'accountJid'),
      ),
    );

    foregroundStart.complete();
    await tester.pump();

    verify(
      () => settingsCubit.toggleBackgroundMessaging(
        true,
        accountJid: 'user@example.com',
      ),
    ).called(1);
  });

  testWidgets('signup welcome gate ignores the persisted guide-seen setting', (
    tester,
  ) async {
    await _pumpEmailForwardingApp(
      tester,
      settingsCubit: _settingsCubit(
        state: const SettingsState(emailForwardingGuideSeen: true),
      ),
      authenticationCubit: _authenticationCubit(
        state: const AuthenticationCompleteFromSignup(),
      ),
      child: const EmailForwardingWelcomeGate(child: SizedBox.shrink()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to Axichat'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.text('Background notifications'), findsOneWidget);
  });

  testWidgets('signup welcome gate skips normal login completions', (
    tester,
  ) async {
    await _pumpEmailForwardingApp(
      tester,
      authenticationCubit: _authenticationCubit(
        state: const AuthenticationComplete(),
      ),
      child: const EmailForwardingWelcomeGate(child: SizedBox.shrink()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to Axichat'), findsNothing);
  });

  testWidgets('signup welcome gate skips smtp-disabled signups', (
    tester,
  ) async {
    await _pumpEmailForwardingApp(
      tester,
      settingsCubit: _settingsCubit(
        state: const SettingsState(
          endpointConfig: EndpointConfig(smtpEnabled: false),
        ),
      ),
      authenticationCubit: _authenticationCubit(
        state: const AuthenticationCompleteFromSignup(),
      ),
      child: const EmailForwardingWelcomeGate(child: SizedBox.shrink()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to Axichat'), findsNothing);
  });
}

Future<void> _pumpEmailForwardingApp(
  WidgetTester tester, {
  required Widget child,
  _MockSettingsCubit? settingsCubit,
  _MockAuthenticationCubit? authenticationCubit,
  _MockNotificationService? notificationService,
  _MockXmppService? xmppService,
  _MockEmailService? emailService,
}) {
  final cubit = settingsCubit ?? _settingsCubit();
  final authCubit =
      authenticationCubit ??
      _authenticationCubit(state: const AuthenticationNone());
  final notifications = notificationService ?? _notificationService();
  final xmpp = xmppService ?? _xmppService();
  final email = emailService ?? _emailService();
  final foregroundRuntimeController = ForegroundRuntimeController(
    capability: const _TestCapability(),
    notificationService: notifications,
    xmppService: xmpp,
    emailService: email,
  );

  return tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<Capability>.value(value: const _TestCapability()),
        RepositoryProvider<NotificationService>.value(value: notifications),
        RepositoryProvider<XmppService>.value(value: xmpp),
        RepositoryProvider<EmailService>.value(value: email),
        RepositoryProvider<ForegroundRuntimeController>.value(
          value: foregroundRuntimeController,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: cubit),
          BlocProvider<AuthenticationCubit>.value(value: authCubit),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            platform: TargetPlatform.android,
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF0F172A),
            brightness: Brightness.light,
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
          locale: const Locale('en'),
          home: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
}

_MockSettingsCubit _settingsCubit({
  SettingsState state = const SettingsState(),
}) {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(state);
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  when(
    () => settingsCubit.toggleBackgroundMessaging(
      any(),
      accountJid: any(named: 'accountJid'),
    ),
  ).thenAnswer((_) async {});
  return settingsCubit;
}

_MockEmailService _emailService() {
  final emailService = _MockEmailService();
  when(
    () => emailService.setForegroundKeepalive(any()),
  ).thenAnswer((_) async {});
  return emailService;
}

_MockNotificationService _notificationService() {
  final notificationService = _MockNotificationService();
  when(
    notificationService.hasAllNotificationPermissions,
  ).thenAnswer((_) async => true);
  when(
    notificationService.requestAllNotificationPermissions,
  ).thenAnswer((_) async => true);
  return notificationService;
}

_MockXmppService _xmppService() {
  final xmppService = _MockXmppService();
  when(xmppService.ensureForegroundSocketIfActive).thenAnswer((_) async {});
  when(() => xmppService.connected).thenReturn(true);
  when(() => xmppService.hasConnectionSettings).thenReturn(true);
  when(() => xmppService.usingForegroundSocket).thenReturn(true);
  when(() => xmppService.myJid).thenReturn('user@example.com');
  return xmppService;
}

_MockAuthenticationCubit _authenticationCubit({
  required AuthenticationState state,
}) {
  final authenticationCubit = _MockAuthenticationCubit();
  when(() => authenticationCubit.state).thenReturn(state);
  when(
    () => authenticationCubit.stream,
  ).thenAnswer((_) => const Stream<AuthenticationState>.empty());
  when(
    () => authenticationCubit.releaseSignupPostLoginWorkHold(),
  ).thenAnswer((_) async {});
  return authenticationCubit;
}

class _TestCapability extends Capability {
  const _TestCapability();

  @override
  bool get canForegroundService => true;
}

class _RunningForegroundTaskBridge implements ForegroundTaskBridge {
  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {}

  @override
  Future<bool> isRunning() async => true;

  @override
  Future<void> release(String clientId) async {}

  @override
  void registerListener(
    String clientId,
    ForegroundTaskMessageHandler handler,
  ) {}

  @override
  Future<void> send(List<Object> parts) async {}

  @override
  void unregisterListener(String clientId) {}
}

class _MockAuthenticationCubit extends Mock implements AuthenticationCubit {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockEmailService extends Mock implements EmailService {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockXmppService extends Mock implements XmppService {}
