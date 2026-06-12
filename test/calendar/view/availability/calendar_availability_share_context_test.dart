import 'dart:async';

import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/view/availability/calendar_availability_share_sheet.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('showCalendarAvailabilityShareSheet survives opener disposal', (
    tester,
  ) async {
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _AvailabilityShareHarness(
        showOpener: showOpener,
        childBuilder: (context) => ElevatedButton(
          onPressed: () {
            unawaited(
              showCalendarAvailabilityShareSheet(
                context: context,
                source: const CalendarAvailabilityShareSource.personal(),
                model: CalendarModel(
                  tasks: const {},
                  lastModified: DateTime(2026),
                  checksum: 'checksum',
                ),
                ownerJid: 'me@axi.im',
              ),
            );
          },
          child: const Text('Open availability share'),
        ),
      ),
    );

    await tester.tap(find.text('Open availability share'));
    showOpener.value = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _AvailabilityShareHarness extends StatelessWidget {
  _AvailabilityShareHarness({
    required this.showOpener,
    required this.childBuilder,
  }) : settingsCubit = _settingsCubit(),
       profileCubit = _profileCubit(),
       rosterCubit = _rosterCubit(),
       chatsCubit = _chatsCubit();

  final ValueNotifier<bool> showOpener;
  final WidgetBuilder childBuilder;
  final SettingsCubit settingsCubit;
  final ProfileCubit profileCubit;
  final RosterCubit rosterCubit;
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
          BlocProvider<RosterCubit>.value(value: rosterCubit),
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

RosterCubit _rosterCubit() {
  final cubit = _MockRosterCubit();
  when(() => cubit.state).thenReturn(const RosterState());
  when(() => cubit.stream).thenAnswer((_) => const Stream<RosterState>.empty());
  when(() => cubit[RosterCubit.itemsCacheKey]).thenReturn(null);
  return cubit;
}

ChatsCubit _chatsCubit() {
  final cubit = _MockChatsCubit();
  when(() => cubit.state).thenReturn(
    ChatsState(
      openCalendar: false,
      items: [_chat()],
      creationStatus: RequestStatus.none,
    ),
  );
  when(cubit.allChats).thenAnswer((_) async => [_chat()]);
  when(() => cubit.stream).thenAnswer((_) => const Stream<ChatsState>.empty());
  when(() => cubit.selfJid).thenReturn('me@axi.im');
  return cubit;
}

Chat _chat() {
  return Chat(
    jid: 'alpha@axi.im',
    title: 'Alpha',
    type: ChatType.chat,
    lastChangeTimestamp: DateTime(2026),
  );
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockProfileCubit extends Mock implements ProfileCubit {}

class _MockRosterCubit extends Mock implements RosterCubit {}

class _MockChatsCubit extends Mock implements ChatsCubit {}
