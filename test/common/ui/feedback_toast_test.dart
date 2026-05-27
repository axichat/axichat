// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('compact one-line toast keeps bottom breathing room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _FeedbackToastTestApp(child: FeedbackToast.success(message: 'Sent')),
    );

    final toastRect = tester.getRect(find.byType(Dismissible));
    final textRect = tester.getRect(find.text('Sent'));
    expect(tester.takeException(), isNull);
    expect(toastRect.bottom - textRect.bottom, greaterThan(axiSpacing.s));
  });

  testWidgets('compact calendar warning toast does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _FeedbackToastTestApp(
        child: FeedbackToast.warning(
          title: 'Calendar sync',
          message:
              'Calendar history sync incomplete. Axichat will retry automatically.',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

class _FeedbackToastTestApp extends StatelessWidget {
  const _FeedbackToastTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[
          axiBorders,
          axiRadii,
          axiSpacing,
          axiSizing,
          axiMotion,
        ],
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
