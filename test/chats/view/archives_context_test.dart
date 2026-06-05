import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/archives_screen.dart';
import 'package:axichat/src/common/request_status.dart';
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
  testWidgets('ArchivesRoute survives opener disposal', (tester) async {
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
                builder: (_) => ArchivesScreen(locate: locate),
              ),
            );
          },
          child: const Text('Open archives'),
        ),
      ),
    );

    await tester.tap(find.text('Open archives'));
    showOpener.value = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _RouteHarness extends StatelessWidget {
  _RouteHarness({required this.showOpener, required this.childBuilder})
    : settingsCubit = _settingsCubit(),
      profileCubit = _profileCubit(),
      chatsCubit = _chatsCubit();

  final ValueNotifier<bool> showOpener;
  final WidgetBuilder childBuilder;
  final SettingsCubit settingsCubit;
  final ProfileCubit profileCubit;
  final ChatsCubit chatsCubit;

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
          BlocProvider<ProfileCubit>.value(value: profileCubit),
          BlocProvider<ChatsCubit>.value(value: chatsCubit),
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

ChatsCubit _chatsCubit() {
  final cubit = _MockChatsCubit();
  when(() => cubit.state).thenReturn(
    const ChatsState(
      openCalendar: false,
      items: [],
      creationStatus: RequestStatus.none,
    ),
  );
  when(() => cubit.stream).thenAnswer((_) => const Stream<ChatsState>.empty());
  return cubit;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockChatsCubit extends Mock implements ChatsCubit {}
