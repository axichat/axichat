// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('AxiTooltip survives rebuilds while hovered', (tester) async {
    final size = ValueNotifier<double>(40);
    addTearDown(size.dispose);

    await tester.pumpWidget(
      _TooltipTestApp(
        child: ValueListenableBuilder<double>(
          valueListenable: size,
          builder: (context, currentSize, child) {
            return Center(
              child: AxiTooltip(
                builder: (_) => const Text('Tooltip'),
                child: SizedBox.square(
                  key: const ValueKey<String>('tooltip-target'),
                  dimension: currentSize,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            );
          },
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey<String>('tooltip-target'))),
    );
    await tester.pump();

    size.value = 64;
    await tester.pump();
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _TooltipTestApp extends StatelessWidget {
  const _TooltipTestApp({required this.child});

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
        child: Scaffold(body: child),
      ),
    );
  }
}
