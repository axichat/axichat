import 'dart:async';

import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/view/sidebar/critical_path_panel.dart';
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
    'showCriticalPathPicker survives opener disposal and creates a path',
    (tester) async {
      final settingsCubit = _settingsCubit();
      final showOpener = ValueNotifier<bool>(true);
      var createCount = 0;
      addTearDown(showOpener.dispose);

      await tester.pumpWidget(
        _CalendarSheetHarness(
          settingsCubit: settingsCubit,
          showOpener: showOpener,
          childBuilder: (context) => AxiButton.primary(
            onPressed: () {
              unawaited(
                showCriticalPathPicker(
                  context: context,
                  paths: const <CalendarCriticalPath>[],
                  stayOpen: true,
                  onCreateNewPath: (_) async {
                    createCount += 1;
                    return null;
                  },
                ),
              );
            },
            child: const Text('Open critical path picker'),
          ),
        ),
      );

      await tester.tap(find.text('Open critical path picker'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      showOpener.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('New critical path'));
      await tester.pump();

      expect(createCount, 1);
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
