import 'dart:async';

import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/sidebar/calendar_critical_path_share_sheet.dart';
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
  testWidgets('showCalendarCriticalPathShareSheet survives opener disposal', (
    tester,
  ) async {
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _CalendarShareHarness(
        showOpener: showOpener,
        childBuilder: (context) => ElevatedButton(
          onPressed: () {
            unawaited(
              showCalendarCriticalPathShareSheet(
                context: context,
                path: _path(),
                tasks: [_task()],
              ),
            );
          },
          child: const Text('Open path share'),
        ),
      ),
    );

    await tester.tap(find.text('Open path share'));
    showOpener.value = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _CalendarShareHarness extends StatelessWidget {
  _CalendarShareHarness({required this.showOpener, required this.childBuilder})
    : settingsCubit = _settingsCubit(),
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

CalendarCriticalPath _path() {
  return CalendarCriticalPath(
    id: 'path-1',
    name: 'Path',
    taskIds: const ['task-1'],
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  );
}

CalendarTask _task() {
  return CalendarTask(
    id: 'task-1',
    title: 'Task to share',
    description: null,
    scheduledTime: DateTime(2026),
    duration: const Duration(minutes: 30),
    isCompleted: false,
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
    location: null,
    deadline: null,
    priority: null,
    startHour: 9,
    endDate: null,
    recurrence: null,
    occurrenceOverrides: const {},
  );
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
