import 'dart:async';

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
  testWidgets('confirm survives opener disposal and returns decision', (
    tester,
  ) async {
    final settingsCubit = _settingsCubit();
    final showOpener = ValueNotifier<bool>(true);
    final result = Completer<bool?>();
    addTearDown(showOpener.dispose);

    await tester.pumpWidget(
      _DialogHarness(
        settingsCubit: settingsCubit,
        showOpener: showOpener,
        childBuilder: (context) => AxiButton.primary(
          onPressed: () {
            unawaited(
              confirm(
                context,
                title: 'Confirm action',
                message: 'Continue?',
                confirmLabel: 'Continue',
                cancelLabel: 'Cancel',
                destructiveConfirm: false,
              ).then(result.complete),
            );
          },
          child: const Text('Open confirm'),
        ),
      ),
    );

    await tester.tap(find.text('Open confirm'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    showOpener.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await result.future, isTrue);
  });
}

class _DialogHarness extends StatelessWidget {
  const _DialogHarness({
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
