import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_screen.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('ProfileRoute survives opener disposal', (tester) async {
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RouteHarness(
        showOpener: showOpener,
        childBuilder: (context) => ElevatedButton(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            );
          },
          child: const Text('Open profile'),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    showOpener.value = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _RouteHarness extends StatelessWidget {
  _RouteHarness({required this.showOpener, required this.childBuilder})
    : settingsCubit = _settingsCubit(),
      profileCubit = _profileCubit(),
      connectivityCubit = _connectivityCubit(),
      authenticationCubit = _authenticationCubit(),
      capability = _MockCapability(),
      xmppService = _MockXmppService(),
      emailService = _MockEmailService();

  final ValueNotifier<bool> showOpener;
  final WidgetBuilder childBuilder;
  final SettingsCubit settingsCubit;
  final ProfileCubit profileCubit;
  final ConnectivityCubit connectivityCubit;
  final AuthenticationCubit authenticationCubit;
  final Capability capability;
  final XmppService xmppService;
  final EmailService emailService;

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
          RepositoryProvider<Capability>.value(value: capability),
          RepositoryProvider<XmppService>.value(value: xmppService),
          RepositoryProvider<EmailService>.value(value: emailService),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BlocProvider<ProfileCubit>.value(value: profileCubit),
            BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
            BlocProvider<AuthenticationCubit>.value(value: authenticationCubit),
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

ProfileCubit _profileCubit() {
  final cubit = _MockProfileCubit();
  when(
    () => cubit.state,
  ).thenReturn(const ProfileState(jid: '', resource: '', username: ''));
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<ProfileState>.empty());
  return cubit;
}

ConnectivityCubit _connectivityCubit() {
  final cubit = _MockConnectivityCubit();
  when(() => cubit.state).thenReturn(
    const ConnectivityNotConnected(
      emailState: EmailSyncState.ready(),
      emailEnabled: false,
      demoOffline: false,
    ),
  );
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<ConnectivityState>.empty());
  return cubit;
}

AuthenticationCubit _authenticationCubit() {
  final cubit = _MockAuthenticationCubit();
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<AuthenticationState>.empty());
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockConnectivityCubit extends Mock implements ConnectivityCubit {}

class _MockAuthenticationCubit extends Mock implements AuthenticationCubit {}

class _MockCapability extends Mock implements Capability {}

class _MockXmppService extends Mock implements XmppService {}

class _MockEmailService extends Mock implements EmailService {}
