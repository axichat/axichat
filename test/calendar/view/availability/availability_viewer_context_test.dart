import 'dart:async';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/view/availability/availability_viewer.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('showCalendarAvailabilityShareViewer survives opener disposal', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    final calendarBloc = _calendarBloc();
    final showOpener = ValueNotifier<bool>(true);
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _AvailabilityViewerHarness(
        settingsCubit: settingsCubit,
        calendarBloc: calendarBloc,
        showOpener: showOpener,
        childBuilder: (context) => ElevatedButton(
          onPressed: () {
            final locate = context.read;
            unawaited(
              showCalendarAvailabilityShareViewer(
                context: context,
                share: _share(),
                enableChatCalendar: false,
                locate: locate,
              ),
            );
          },
          child: const Text('Open availability viewer'),
        ),
      ),
    );

    await tester.tap(find.text('Open availability viewer'));
    showOpener.value = false;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _AvailabilityViewerHarness extends StatelessWidget {
  const _AvailabilityViewerHarness({
    required this.settingsCubit,
    required this.calendarBloc,
    required this.showOpener,
    required this.childBuilder,
  });

  final SettingsCubit settingsCubit;
  final CalendarBloc calendarBloc;
  final ValueNotifier<bool> showOpener;
  final WidgetBuilder childBuilder;

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
      home: BlocProvider<SettingsCubit>.value(
        value: settingsCubit,
        child: BlocProvider<CalendarBloc>.value(
          value: calendarBloc,
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

CalendarAvailabilityShare _share() {
  return CalendarAvailabilityShare(
    id: 'share-1',
    overlay: CalendarAvailabilityOverlay(
      owner: 'me@axi.im',
      rangeStart: CalendarDateTime(value: DateTime(2026)),
      rangeEnd: CalendarDateTime(value: DateTime(2026, 1, 2)),
      intervals: const [],
    ),
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

CalendarBloc _calendarBloc() {
  final bloc = _MockCalendarBloc();
  when(() => bloc.state).thenReturn(CalendarState.initial());
  when(
    () => bloc.stream,
  ).thenAnswer((_) => const Stream<CalendarState>.empty());
  return bloc;
}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockCalendarBloc extends MockBloc<CalendarEvent, CalendarState>
    implements CalendarBloc {}
