import 'package:axichat/src/chats/view/archived_chat_screen.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('ArchivedChatRoute survives opener disposal', (tester) async {
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
                builder: (_) =>
                    ArchivedChatScreen(locate: locate, jid: 'alpha@axi.im'),
              ),
            );
          },
          child: const Text('Open archived chat'),
        ),
      ),
    );

    await tester.tap(find.text('Open archived chat'));
    showOpener.value = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _RouteHarness extends StatelessWidget {
  _RouteHarness({required this.showOpener, required this.childBuilder})
    : settingsCubit = _settingsCubit(),
      xmppService = _MockXmppService();

  final ValueNotifier<bool> showOpener;
  final WidgetBuilder childBuilder;
  final SettingsCubit settingsCubit;
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
      home: RepositoryProvider<XmppService>.value(
        value: xmppService,
        child: BlocProvider<SettingsCubit>.value(
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

class _MockXmppService extends Mock implements XmppService {}
