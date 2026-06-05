import 'package:axichat/src/avatar/view/avatar_editor_screen.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('AvatarEditorRoute survives opener disposal', (tester) async {
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _RouteHarness(
        showOpener: showOpener,
        childBuilder: (context) => ElevatedButton(
          onPressed: () {
            final locate = context.read;
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => AvatarEditorScreen(locate: locate),
              ),
            );
          },
          child: const Text('Open avatar editor'),
        ),
      ),
    );

    await tester.tap(find.text('Open avatar editor'));
    showOpener.value = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _RouteHarness extends StatelessWidget {
  _RouteHarness({required this.showOpener, required this.childBuilder})
    : settingsCubit = _settingsCubit(),
      profileCubit = _profileCubit(),
      xmppService = _xmppService();

  final ValueNotifier<bool> showOpener;
  final WidgetBuilder childBuilder;
  final SettingsCubit settingsCubit;
  final ProfileCubit profileCubit;
  final XmppService xmppService;

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
        providers: [RepositoryProvider<XmppService>.value(value: xmppService)],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BlocProvider<ProfileCubit>.value(value: profileCubit),
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

XmppService _xmppService() {
  final service = _MockXmppService();
  when(() => service.cachedSelfAvatar).thenReturn(null);
  when(() => service.getOwnAvatar()).thenAnswer((_) async => null);
  return service;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockXmppService extends Mock implements XmppService {}
