import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  setUp(() {
    foregroundServiceActive.value = true;
  });

  tearDown(() {
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
      child: const EmailForwardingWelcomeContent(),
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
      child: const EmailForwardingWelcomeContent(),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(ShadSwitch));
    await tester.pump();

    verify(() => settingsCubit.toggleBackgroundMessaging(true)).called(1);
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
}) {
  final cubit = settingsCubit ?? _settingsCubit();
  final authCubit =
      authenticationCubit ??
      _authenticationCubit(state: const AuthenticationNone());
  final notifications = notificationService ?? _notificationService();
  final xmpp = xmppService ?? _xmppService();

  return tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<Capability>.value(value: const _TestCapability()),
        RepositoryProvider<NotificationService>.value(value: notifications),
        RepositoryProvider<XmppService>.value(value: xmpp),
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
    () => settingsCubit.toggleBackgroundMessaging(any()),
  ).thenAnswer((_) async {});
  return settingsCubit;
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
  return authenticationCubit;
}

class _TestCapability extends Capability {
  const _TestCapability();

  @override
  bool get canForegroundService => true;
}

class _MockAuthenticationCubit extends Mock implements AuthenticationCubit {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockXmppService extends Mock implements XmppService {}
