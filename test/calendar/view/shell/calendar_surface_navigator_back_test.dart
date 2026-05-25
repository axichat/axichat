// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/guest/guest_calendar_bloc.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/calendar/view/shell/guest_calendar_widget.dart';
import 'package:axichat/src/calendar/view/shell/calendar_widget.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MockGuestCalendarBloc extends MockBloc<CalendarEvent, CalendarState>
    implements GuestCalendarBloc {}

void main() {
  setUpAll(() {
    HydratedBloc.storage = _InMemoryStorage();
    registerFallbackValue(const CalendarEvent.started());
  });

  testWidgets(
    'system back does not force-pop nested route when top route blocks pop',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final modalAnchorKey = GlobalKey();
      var blockedBackInvocations = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSurfaceNavigator(
            navigatorKey: navigatorKey,
            modalAnchorKey: modalAnchorKey,
            child: const SizedBox.shrink(),
          ),
        ),
      );

      final navigator = navigatorKey.currentState!;
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                blockedBackInvocations += 1;
              }
            },
            child: const Scaffold(body: SizedBox(key: Key('guarded-route'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guarded-route')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guarded-route')), findsOneWidget);
      expect(blockedBackInvocations, 1);
    },
  );

  testWidgets(
    'calendar sheet stays bound to calendar surface across tab switches',
    (tester) async {
      await tester.pumpWidget(const _CalendarSheetBindingHarness());

      await tester.tap(find.byKey(const Key('open-calendar-sheet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar-sheet')), findsOneWidget);

      await tester.tap(find.byKey(const Key('show-home-page')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-page')), findsOneWidget);
      expect(find.byKey(const Key('calendar-sheet')), findsNothing);

      await tester.tap(find.byKey(const Key('show-calendar-page')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar-sheet')), findsOneWidget);
    },
  );

  testWidgets('guest calendar bare system back returns to login', (
    tester,
  ) async {
    await _pumpGuestCalendarBackHarness(tester);

    expect(find.byType(GuestCalendarWidget), findsOneWidget);
    expect(find.byKey(_loginScreenKey), findsNothing);

    await tester.binding.handlePopRoute();
    await _pumpGuestCalendarBackFrame(tester);

    expect(find.byKey(_loginScreenKey), findsOneWidget);
  });

  testWidgets('guest calendar keeps framework back handling active', (
    tester,
  ) async {
    final frameworkHandlesBack = ValueNotifier<bool?>(null);
    addTearDown(frameworkHandlesBack.dispose);

    await _pumpGuestCalendarBackHarness(
      tester,
      frameworkHandlesBack: frameworkHandlesBack,
    );

    expect(frameworkHandlesBack.value, isTrue);
  });

  testWidgets(
    'guest calendar system back unfocuses sidebar input before login',
    (tester) async {
      await _pumpGuestCalendarBackHarness(tester);

      await tester.tap(find.text('Try guest calendar'));
      await _pumpGuestCalendarBackFrame(tester);

      await tester.tapAt(tester.getCenter(find.textContaining('Quick task')));
      await _pumpGuestCalendarBackFrame(tester);

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'sidebarTitleInput',
      );

      await tester.binding.handlePopRoute();
      await _pumpGuestCalendarBackFrame(tester);

      expect(find.byType(GuestCalendarWidget), findsOneWidget);
      expect(find.byKey(_loginScreenKey), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('sidebarTitleInput'),
      );

      await tester.binding.handlePopRoute();
      await _pumpGuestCalendarBackFrame(tester);

      expect(find.byKey(_loginScreenKey), findsOneWidget);
    },
  );
}

const Key _loginScreenKey = Key('login-screen');

Future<void> _pumpGuestCalendarBackFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _CalendarSheetBindingHarness extends StatefulWidget {
  const _CalendarSheetBindingHarness();

  @override
  State<_CalendarSheetBindingHarness> createState() =>
      _CalendarSheetBindingHarnessState();
}

class _CalendarSheetBindingHarnessState
    extends State<_CalendarSheetBindingHarness> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey _modalAnchorKey = GlobalKey(
    debugLabel: 'calendar-sheet-binding-anchor',
  );
  int _selectedIndex = 1;

  BuildContext get _modalContext =>
      _modalAnchorKey.currentContext ??
      _navigatorKey.currentState?.overlay?.context ??
      _navigatorKey.currentContext ??
      context;

  Future<void> _openSheet() {
    return showModalBottomSheet<void>(
      context: _modalContext,
      isScrollControlled: true,
      builder: (context) {
        return const SizedBox(key: Key('calendar-sheet'), height: 120);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('show-home-page'),
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                  child: const Text('Home'),
                ),
                TextButton(
                  key: const Key('show-calendar-page'),
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  child: const Text('Calendar'),
                ),
              ],
            ),
            Expanded(
              child: AxiFadeIndexedStack(
                index: _selectedIndex,
                duration: Duration.zero,
                overlapChildren: false,
                children: [
                  const ColoredBox(
                    color: Colors.white,
                    child: SizedBox.expand(key: Key('home-page')),
                  ),
                  CalendarSurfaceNavigator(
                    navigatorKey: _navigatorKey,
                    modalAnchorKey: _modalAnchorKey,
                    child: Center(
                      child: TextButton(
                        key: const Key('open-calendar-sheet'),
                        onPressed: _openSheet,
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pumpGuestCalendarBackHarness(
  WidgetTester tester, {
  ValueNotifier<bool?>? frameworkHandlesBack,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final guestCalendarBloc = MockGuestCalendarBloc();
  when(() => guestCalendarBloc.state).thenReturn(CalendarState.initial());
  when(
    () => guestCalendarBloc.stream,
  ).thenAnswer((_) => const Stream<CalendarState>.empty());
  when(() => guestCalendarBloc.add(any<CalendarEvent>())).thenReturn(null);
  when(() => guestCalendarBloc.close()).thenAnswer((_) async {});
  final settingsCubit = SettingsCubit();
  final calendarDragController = CalendarTaskOffGridDragController();
  final router = GoRouter(
    initialLocation: '/guest-calendar',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(
          body: SizedBox.expand(
            child: Center(child: Text('login screen', key: _loginScreenKey)),
          ),
        ),
      ),
      GoRoute(
        path: '/guest-calendar',
        builder: (context, state) => const GuestCalendarWidget(),
      ),
    ],
  );
  addTearDown(() async {
    router.dispose();
    calendarDragController.dispose();
    await settingsCubit.close();
    await guestCalendarBloc.close();
  });

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BlocProvider<GuestCalendarBloc>.value(value: guestCalendarBloc),
        BlocProvider<BaseCalendarBloc>.value(value: guestCalendarBloc),
      ],
      child: ChangeNotifierProvider<CalendarTaskOffGridDragController>.value(
        value: calendarDragController,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
          onNavigationNotification: (notification) {
            frameworkHandlesBack?.value = notification.canHandlePop;
            return true;
          },
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context).copyWith(
              padding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              textScaler: const TextScaler.linear(0.7),
            );
            return MediaQuery(
              data: mediaQuery,
              child: ShadTheme(
                data: ShadThemeData(
                  colorScheme: const ShadSlateColorScheme.light(),
                  brightness: Brightness.light,
                ),
                child: EnvScope(child: child ?? const SizedBox.shrink()),
              ),
            );
          },
        ),
      ),
    ),
  );
  await _pumpGuestCalendarBackFrame(tester);
}

class _InMemoryStorage implements Storage {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async => _store.clear();

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }
}
