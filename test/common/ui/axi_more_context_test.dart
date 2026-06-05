import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('AxiMore sheet survives opener disposal and runs action', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settingsCubit = _settingsCubit();
    final showOpener = ValueNotifier<bool>(true);
    var actionCount = 0;
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _SheetHarness(
        settingsCubit: settingsCubit,
        showOpener: showOpener,
        childBuilder: (context) => AxiMore(
          tooltip: 'More options',
          actions: [
            AxiMenuAction(
              label: 'Run action',
              onPressed: () {
                actionCount += 1;
              },
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    showOpener.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Run action'));
    await tester.pumpAndSettle();

    expect(actionCount, 1);
  });
}

class _SheetHarness extends StatelessWidget {
  const _SheetHarness({
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
      platform: TargetPlatform.android,
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
