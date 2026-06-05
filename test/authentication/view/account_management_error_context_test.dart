import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/change_password_form.dart';
import 'package:axichat/src/authentication/view/unregister_form.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('change password error is destructive above current password', (
    tester,
  ) async {
    await _pumpAuthForm(
      tester,
      authenticationCubit: _authenticationCubit(
        state: const AuthenticationPasswordChangeFailure(
          AuthKeyMessage(AuthMessageKey.passwordIncorrect),
        ),
      ),
      child: const ChangePasswordForm(),
    );

    const message = 'Incorrect password. Please try again.';
    expect(find.text(message), findsOneWidget);
    _expectDestructiveText(tester, message);
    _expectAbove(tester, find.text(message), find.text('Old password'));
  });

  testWidgets('delete account error is destructive above password', (
    tester,
  ) async {
    await _pumpAuthForm(
      tester,
      authenticationCubit: _authenticationCubit(
        state: const AuthenticationUnregisterFailure(
          AuthKeyMessage(AuthMessageKey.passwordIncorrect),
        ),
      ),
      child: const UnregisterForm(),
    );

    const message = 'Incorrect password. Please try again.';
    expect(find.text(message), findsOneWidget);
    _expectDestructiveText(tester, message);
    _expectAbove(tester, find.text(message), find.text('Password'));
  });
}

Future<void> _pumpAuthForm(
  WidgetTester tester, {
  required AuthenticationCubit authenticationCubit,
  required Widget child,
}) async {
  final theme = AppTheme.build(
    shadColor: ShadColor.blue,
    brightness: Brightness.light,
    platform: defaultTargetPlatform,
  );
  await tester.pumpWidget(
    ShadApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthenticationCubit>.value(value: authenticationCubit),
          BlocProvider<ProfileCubit>.value(value: _profileCubit()),
          BlocProvider<SettingsCubit>.value(value: _settingsCubit()),
        ],
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
}

AuthenticationCubit _authenticationCubit({
  required AuthenticationState state,
  bool passwordWasSkipped = false,
}) {
  final cubit = _MockAuthenticationCubit();
  when(() => cubit.state).thenReturn(state);
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<AuthenticationState>.empty());
  when(() => cubit.passwordWasSkipped).thenReturn(passwordWasSkipped);
  return cubit;
}

ProfileCubit _profileCubit() {
  final cubit = _MockProfileCubit();
  when(() => cubit.state).thenReturn(
    const ProfileState(jid: 'alpha@axi.im', resource: '', username: 'alpha'),
  );
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<ProfileState>.empty());
  return cubit;
}

SettingsCubit _settingsCubit() {
  final cubit = _MockSettingsCubit();
  when(() => cubit.state).thenReturn(
    const SettingsState(
      endpointConfig: EndpointConfig(domain: EndpointConfig.axiImDomain),
    ),
  );
  when(() => cubit.animationDuration).thenReturn(Duration.zero);
  when(
    () => cubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  return cubit;
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

class _MockAuthenticationCubit extends Mock implements AuthenticationCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}
