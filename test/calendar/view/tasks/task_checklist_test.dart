// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/tasks/task_checklist.dart';
import 'package:axichat/src/calendar/view/tasks/task_checklist_controller.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../mocks.dart';

void main() {
  testWidgets('checklist rows keep a normal gap below the progress bar', (
    tester,
  ) async {
    final controller = TaskChecklistController(
      initialItems: const <TaskChecklistItem>[
        TaskChecklistItem(id: 'one', label: 'First item', isCompleted: false),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _TaskChecklistTestApp(child: TaskChecklist(controller: controller)),
    );

    final Rect progressRect = tester.getRect(
      find.byType(TaskChecklistProgressBar),
    );
    final Rect firstInputRect = tester.getRect(find.byType(AxiTextInput).first);

    expect(firstInputRect.top - progressRect.bottom, greaterThanOrEqualTo(8));
  });
}

class _TaskChecklistTestApp extends StatelessWidget {
  const _TaskChecklistTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settingsCubit = MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(const SettingsState());
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => settingsCubit.animationDuration).thenReturn(Duration.zero);

    return BlocProvider<SettingsCubit>.value(
      value: settingsCubit,
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [
            axiBorders,
            axiRadii,
            axiSpacing,
            axiSizing,
            axiMotion,
          ],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: SizedBox(
                    width: context.sizing.dialogMaxWidth,
                    child: child,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
