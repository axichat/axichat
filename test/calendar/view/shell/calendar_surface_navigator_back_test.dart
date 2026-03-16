// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/view/shell/calendar_widget.dart';
import 'package:axichat/src/common/ui/axi_fade_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
