import 'dart:async';

import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/view/xmpp_operation_overlay.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:axichat/src/xmpp_activity/bloc/xmpp_activity_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const Duration _calendarDelay = Duration(seconds: 3);
const Duration _animationDuration = Duration(milliseconds: 300);

void main() {
  testWidgets('calendar sync display delay resets before first entry', (
    tester,
  ) async {
    final driver = await _pumpOverlay(tester);
    final operation = _calendarOperation(triggerRevision: 1);

    driver.emitOperations([operation]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Syncing calendar...'), findsNothing);

    driver.emitOperations([operation.copyWith(triggerRevision: 2)]);
    await tester.pump();
    await tester.pump(_calendarDelay - const Duration(milliseconds: 1));

    expect(find.text('Syncing calendar...'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Syncing calendar...'), findsOneWidget);
  });

  testWidgets('completed delayed calendar sync survives source cleanup', (
    tester,
  ) async {
    final driver = await _pumpOverlay(
      tester,
      animationDuration: _animationDuration,
    );
    final operation = _calendarOperation(triggerRevision: 1);

    driver.emitOperations([operation]);
    await tester.pump();
    driver.emitOperations([
      operation.copyWith(status: XmppOperationStatus.success),
    ]);
    await tester.pump();
    driver.emitOperations([]);
    await tester.pump();

    await tester.pump(_calendarDelay);

    expect(find.text('Syncing calendar...'), findsOneWidget);
    expect(find.text('Calendar synced'), findsNothing);

    await tester.pump(
      _double(_animationDuration) - const Duration(milliseconds: 1),
    );

    expect(find.text('Syncing calendar...'), findsOneWidget);
    expect(find.text('Calendar synced'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Calendar synced'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(_animationDuration);
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Syncing calendar...'), findsNothing);
    expect(find.text('Calendar synced'), findsNothing);
  });

  testWidgets('failed delayed calendar sync before display surfaces promptly', (
    tester,
  ) async {
    final driver = await _pumpOverlay(tester);
    final operation = _calendarOperation(triggerRevision: 1);

    driver.emitOperations([operation]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Syncing calendar...'), findsNothing);
    expect(find.text('Calendar sync failed'), findsNothing);

    driver.emitOperations([
      operation.copyWith(status: XmppOperationStatus.failure),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Calendar sync failed'), findsOneWidget);
    expect(find.text('Syncing calendar...'), findsNothing);

    await tester.pump(_calendarDelay);

    expect(find.text('Calendar sync failed'), findsNothing);
    expect(find.text('Syncing calendar...'), findsNothing);
  });

  testWidgets('long delayed calendar sync waits for real final status', (
    tester,
  ) async {
    final driver = await _pumpOverlay(
      tester,
      animationDuration: _animationDuration,
    );
    final operation = _calendarOperation(triggerRevision: 1);

    driver.emitOperations([operation]);
    await tester.pump();
    await tester.pump(_calendarDelay);

    expect(find.text('Syncing calendar...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Syncing calendar...'), findsOneWidget);
    expect(find.text('Calendar synced'), findsNothing);

    driver.emitOperations([
      operation.copyWith(status: XmppOperationStatus.success),
    ]);
    await tester.pump();

    expect(find.text('Calendar synced'), findsOneWidget);
  });

  testWidgets('revealed delayed calendar completion survives retained sync', (
    tester,
  ) async {
    final driver = await _pumpOverlay(
      tester,
      animationDuration: _animationDuration,
    );
    final operation = _calendarOperation(triggerRevision: 1);
    final success = operation.copyWith(status: XmppOperationStatus.success);

    driver.emitOperations([operation]);
    await tester.pump();
    await tester.pump(_calendarDelay);

    driver.emitOperations([success]);
    await tester.pump();
    await tester.pump(_double(_animationDuration));

    expect(find.text('Calendar synced'), findsOneWidget);
    expect(find.text('Syncing calendar...'), findsNothing);

    driver.emitOperations([success]);
    await tester.pump();

    expect(find.text('Calendar synced'), findsOneWidget);
    expect(find.text('Syncing calendar...'), findsNothing);
  });

  testWidgets('delayed calendar final status waits remaining spinner minimum', (
    tester,
  ) async {
    final driver = await _pumpOverlay(
      tester,
      animationDuration: _animationDuration,
    );
    final operation = _calendarOperation(triggerRevision: 1);

    driver.emitOperations([operation]);
    await tester.pump();
    await tester.pump(_calendarDelay);
    await tester.pump(_animationDuration);

    driver.emitOperations([
      operation.copyWith(status: XmppOperationStatus.success),
    ]);
    await tester.pump();

    expect(find.text('Syncing calendar...'), findsOneWidget);
    expect(find.text('Calendar synced'), findsNothing);

    await tester.pump(_animationDuration - const Duration(milliseconds: 1));

    expect(find.text('Syncing calendar...'), findsOneWidget);
    expect(find.text('Calendar synced'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Calendar synced'), findsOneWidget);
  });

  testWidgets('missing delayed in-progress calendar toast is removed', (
    tester,
  ) async {
    final driver = await _pumpOverlay(tester);
    final operation = _calendarOperation(triggerRevision: 1);

    driver.emitOperations([operation]);
    await tester.pump();
    await tester.pump(_calendarDelay);

    expect(find.text('Syncing calendar...'), findsOneWidget);

    driver.emitOperations([]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Syncing calendar...'), findsNothing);
  });

  testWidgets('visible delayed calendar completion ignores later trigger', (
    tester,
  ) async {
    final driver = await _pumpOverlay(tester);
    final first = _calendarOperation(id: 'calendar-1', triggerRevision: 1);
    final second = _calendarOperation(id: 'calendar-2', triggerRevision: 1);
    final firstSuccess = first.copyWith(status: XmppOperationStatus.success);

    driver.emitOperations([first]);
    await tester.pump();
    await tester.pump(_calendarDelay);

    expect(find.text('Syncing calendar...'), findsOneWidget);

    driver.emitOperations([firstSuccess]);
    await tester.pump();
    expect(find.text('Calendar synced'), findsOneWidget);
    expect(find.text('Syncing calendar...'), findsNothing);

    driver.emitOperations([firstSuccess, second]);
    await tester.pump();

    expect(find.text('Calendar synced'), findsOneWidget);
    expect(find.text('Syncing calendar...'), findsNothing);
  });

  testWidgets('follow-up delayed calendar operation waits for entry exit', (
    tester,
  ) async {
    final driver = await _pumpOverlay(tester);
    final first = _calendarOperation(id: 'calendar-1', triggerRevision: 1);
    final second = _calendarOperation(id: 'calendar-2', triggerRevision: 1);
    final firstSuccess = first.copyWith(status: XmppOperationStatus.success);

    driver.emitOperations([first]);
    await tester.pump();
    await tester.pump(_calendarDelay);

    driver.emitOperations([firstSuccess]);
    await tester.pump();
    driver.emitOperations([firstSuccess, second]);
    await tester.pump();

    expect(find.text('Calendar synced'), findsOneWidget);
    expect(find.text('Syncing calendar...'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    driver.emitOperations([second]);
    await tester.pump();
    await tester.pump(
      _calendarDelay -
          const Duration(seconds: 1) -
          const Duration(milliseconds: 1),
    );

    expect(find.text('Calendar synced'), findsNothing);
    expect(find.text('Syncing calendar...'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Syncing calendar...'), findsOneWidget);
  });

  testWidgets(
    'completed follow-up calendar operation redisplays after debounce',
    (tester) async {
      final driver = await _pumpOverlay(tester);
      final first = _calendarOperation(id: 'calendar-1', triggerRevision: 1);
      final second = _calendarOperation(id: 'calendar-2', triggerRevision: 1);
      final firstSuccess = first.copyWith(status: XmppOperationStatus.success);
      final secondSuccess = second.copyWith(
        status: XmppOperationStatus.success,
      );

      driver.emitOperations([first]);
      await tester.pump();
      await tester.pump(_calendarDelay);

      driver.emitOperations([firstSuccess]);
      await tester.pump();
      driver.emitOperations([firstSuccess, second]);
      await tester.pump();
      driver.emitOperations([firstSuccess, secondSuccess]);
      await tester.pump();

      expect(find.text('Calendar synced'), findsOneWidget);
      expect(find.text('Syncing calendar...'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      driver.emitOperations([secondSuccess]);
      await tester.pump();
      await tester.pump(
        _calendarDelay -
            const Duration(seconds: 1) -
            const Duration(milliseconds: 1),
      );

      expect(find.text('Calendar synced'), findsNothing);
      expect(find.text('Syncing calendar...'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Calendar synced'), findsOneWidget);
      expect(find.text('Syncing calendar...'), findsNothing);
    },
  );

  testWidgets('non-delayed operation kinds still display immediately', (
    tester,
  ) async {
    final driver = await _pumpOverlay(tester);

    driver.emitOperations([
      XmppOperation(
        id: 'conversations-1',
        kind: XmppOperationKind.pubSubConversations,
        startedAt: DateTime(2026),
        triggerRevision: 1,
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Syncing chats list...'), findsOneWidget);
  });
}

XmppOperation _calendarOperation({
  String id = 'calendar-1',
  required int triggerRevision,
}) {
  return XmppOperation(
    id: id,
    kind: XmppOperationKind.pubSubCalendarSnapshot,
    startedAt: DateTime(2026),
    triggerRevision: triggerRevision,
  );
}

Duration _double(Duration duration) {
  return Duration(microseconds: duration.inMicroseconds * 2);
}

Future<_OverlayDriver> _pumpOverlay(
  WidgetTester tester, {
  Duration animationDuration = Duration.zero,
}) async {
  final xmppActivityCubit = _MockXmppActivityCubit();
  final settingsCubit = _MockSettingsCubit();
  final stateController = StreamController<XmppActivityState>.broadcast();
  var currentState = const XmppActivityState();

  when(() => xmppActivityCubit.state).thenAnswer((_) => currentState);
  when(
    () => xmppActivityCubit.stream,
  ).thenAnswer((_) => stateController.stream);
  when(() => settingsCubit.state).thenReturn(const SettingsState());
  when(
    () => settingsCubit.stream,
  ).thenAnswer((_) => const Stream<SettingsState>.empty());
  when(() => settingsCubit.animationDuration).thenReturn(animationDuration);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BlocProvider<XmppActivityCubit>.value(value: xmppActivityCubit),
          ],
          child: const Material(
            type: MaterialType.transparency,
            child: XmppOperationOverlay(
              offsetForOpenChat: false,
              displayDelayByKind: {
                XmppOperationKind.pubSubCalendarSnapshot: _calendarDelay,
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  addTearDown(() async {
    await stateController.close();
  });

  return _OverlayDriver(
    emitOperations: (operations) {
      currentState = XmppActivityState(operations: operations);
      stateController.add(currentState);
    },
  );
}

class _OverlayDriver {
  const _OverlayDriver({required this.emitOperations});

  final void Function(List<XmppOperation> operations) emitOperations;
}

class _MockXmppActivityCubit extends MockCubit<XmppActivityState>
    implements XmppActivityCubit {}

class _MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}
