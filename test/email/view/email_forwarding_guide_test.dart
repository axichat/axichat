import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
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

  testWidgets('signup welcome uses email notification setting', (tester) async {
    await _pumpEmailForwardingApp(
      tester,
      child: const EmailForwardingWelcomeContent(),
    );

    expect(find.byType(NotificationRequest), findsNothing);
    expect(find.text('Mute email notifications'), findsOneWidget);
    expect(
      find.text('Stop receiving email message notifications on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('signup email notification setting updates SettingsCubit', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    await _pumpEmailForwardingApp(
      tester,
      settingsCubit: settingsCubit,
      child: const EmailForwardingWelcomeContent(),
    );

    await tester.tap(find.byType(ShadSwitch));
    await tester.pump();

    verify(() => settingsCubit.toggleEmailNotificationsMuted(true)).called(1);
  });
}

Future<void> _pumpEmailForwardingApp(
  WidgetTester tester, {
  required Widget child,
  _MockSettingsCubit? settingsCubit,
}) {
  final cubit = settingsCubit ?? _settingsCubit();

  return tester.pumpWidget(
    BlocProvider<SettingsCubit>.value(
      value: cubit,
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
  );
}

_MockSettingsCubit _settingsCubit() {
  final settingsCubit = _MockSettingsCubit();
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);
  when(
    () => settingsCubit.toggleEmailNotificationsMuted(any()),
  ).thenAnswer((_) async {});
  return settingsCubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
