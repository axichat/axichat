// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/view/sidebar/critical_path_panel.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('membership controls reserve no empty critical-path row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _CriticalPathWidgetTestApp(
        child: CriticalPathMembershipControls(
          addButton: Text('Add to critical path'),
          paths: <CalendarCriticalPath>[],
        ),
      ),
    );

    expect(find.text('Add to critical path'), findsOneWidget);
    expect(find.byType(CriticalPathMembershipList), findsNothing);
  });
}

class _CriticalPathWidgetTestApp extends StatelessWidget {
  const _CriticalPathWidgetTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        extensions: [axiBorders, axiRadii, axiSpacing, axiSizing, axiMotion],
      ),
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }
}
