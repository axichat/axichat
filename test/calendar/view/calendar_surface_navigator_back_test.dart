// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'system back does not force-pop nested route when top route blocks pop',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      var blockedBackInvocations = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CalendarSurfaceNavigator(
            navigatorKey: navigatorKey,
            child: const SizedBox.shrink(),
          ),
        ),
      );

      final navigator = navigatorKey.currentState!;
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, __) {
              if (!didPop) {
                blockedBackInvocations += 1;
              }
            },
            child: const Scaffold(
              body: SizedBox(key: Key('guarded-route')),
            ),
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
}
