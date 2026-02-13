// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/axi_popover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('system back closes popover before popping route',
      (tester) async {
    await tester.pumpWidget(const _AxiPopoverBackTestApp());

    await tester.tap(find.byKey(const Key('open-popover-route')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('popover-route')), findsOneWidget);

    await tester.tap(find.byKey(const Key('popover-trigger')));
    await tester.pumpAndSettle();

    expect(find.text('Popover content'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('popover-route')), findsOneWidget);
    expect(find.text('Popover content'), findsNothing);
  });
}

class _AxiPopoverBackTestApp extends StatelessWidget {
  const _AxiPopoverBackTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadSlateColorScheme.light(),
          brightness: Brightness.light,
        ),
        child: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-popover-route'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const _PopoverRoutePage(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PopoverRoutePage extends StatefulWidget {
  const _PopoverRoutePage();

  @override
  State<_PopoverRoutePage> createState() => _PopoverRoutePageState();
}

class _PopoverRoutePageState extends State<_PopoverRoutePage> {
  late final ShadPopoverController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShadPopoverController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('popover-route'),
      body: Center(
        child: AxiPopover(
          controller: _controller,
          popover: (_) => const Text('Popover content'),
          child: ElevatedButton(
            key: const Key('popover-trigger'),
            onPressed: _controller.toggle,
            child: const Text('Toggle'),
          ),
        ),
      ),
    );
  }
}
