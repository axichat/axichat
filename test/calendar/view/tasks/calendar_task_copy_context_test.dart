import 'dart:async';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/tasks/task_copy_sheet.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'showCalendarTaskCopySheet survives opener disposal and returns decision',
    (tester) async {
      final settingsCubit = _settingsCubit();
      final showOpener = ValueNotifier<bool>(true);
      final result = Completer<CalendarTaskCopyDecision?>();
      addTearDown(showOpener.dispose);

      await tester.pumpWidget(
        _CalendarSheetHarness(
          settingsCubit: settingsCubit,
          showOpener: showOpener,
          childBuilder: (context) => AxiButton.primary(
            onPressed: () {
              unawaited(
                showCalendarTaskCopySheet(
                  context: context,
                  task: _task(),
                  canAddToPersonal: true,
                  canAddToChat: true,
                ).then(result.complete),
              );
            },
            child: const Text('Open copy sheet'),
          ),
        ),
      );

      await tester.tap(find.text('Open copy sheet'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      showOpener.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Copy').last);
      await tester.pumpAndSettle();

      final decision = await result.future;
      expect(decision?.addToPersonal, isTrue);
      expect(decision?.addToChat, isFalse);
    },
  );
}

class _CalendarSheetHarness extends StatelessWidget {
  const _CalendarSheetHarness({
    required this.settingsCubit,
    required this.showOpener,
    required this.childBuilder,
  });

  final SettingsCubit settingsCubit;
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

CalendarTask _task() {
  return CalendarTask(
    id: 'task-1',
    title: 'Copyable task',
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

class _MockSettingsCubit extends Mock implements SettingsCubit {}
