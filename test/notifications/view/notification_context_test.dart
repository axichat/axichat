import 'dart:async';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:axichat/src/notifications/view/notification_dialog.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'showNotificationDialog survives opener disposal and calls notification cubit',
    (tester) async {
      final settingsCubit = _settingsCubit();
      final notificationCubit = _MockNotificationRequestCubit();
      final showOpener = ValueNotifier<bool>(true);
      final result = Completer<bool?>();
      addTearDown(showOpener.dispose);

      when(() => notificationCubit.state).thenReturn(
        const NotificationRequestState(foregroundServiceActive: false),
      );
      when(
        () => notificationCubit.stream,
      ).thenAnswer((_) => const Stream<NotificationRequestState>.empty());
      when(
        () => notificationCubit.requestPermissions(),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _NotificationHarness(
          settingsCubit: settingsCubit,
          notificationCubit: notificationCubit,
          showOpener: showOpener,
          result: result,
        ),
      );

      await tester.tap(find.text('Open notifications'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      showOpener.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final exception = tester.takeException();
      expect(exception, isNull);
      if (exception != null) {
        return;
      }

      verify(() => notificationCubit.requestPermissions()).called(1);
      expect(await result.future, isTrue);
    },
  );
}

class _NotificationHarness extends StatelessWidget {
  const _NotificationHarness({
    required this.settingsCubit,
    required this.notificationCubit,
    required this.showOpener,
    required this.result,
  });

  final SettingsCubit settingsCubit;
  final NotificationRequestCubit notificationCubit;
  final ValueNotifier<bool> showOpener;
  final Completer<bool?> result;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.build(
      shadColor: ShadColor.blue,
      brightness: Brightness.light,
      platform: defaultTargetPlatform,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return BlocProvider<SettingsCubit>.value(
              value: settingsCubit,
              child: BlocProvider<NotificationRequestCubit>.value(
                value: notificationCubit,
                child: Scaffold(
                  body: Center(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: showOpener,
                      builder: (context, visible, child) {
                        if (!visible) {
                          return const SizedBox.shrink();
                        }
                        return Builder(
                          builder: (context) => AxiButton.primary(
                            onPressed: () {
                              final locate = context.read;
                              unawaited(
                                showNotificationDialog(
                                  context,
                                  locate,
                                ).then(result.complete),
                              );
                            },
                            child: const Text('Open notifications'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
    return ShadApp.router(
      theme: theme,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

class _MockNotificationRequestCubit extends MockCubit<NotificationRequestState>
    implements NotificationRequestCubit {}
