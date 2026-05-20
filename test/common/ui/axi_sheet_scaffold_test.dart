// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('zero-padding sheet safe area stays inside the sheet surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
    });

    await tester.pumpWidget(
      const _AxiSheetScaffoldTestApp(
        child: _AdaptiveSheetOpenButton(
          bottomSafeAreaBehavior: AxiSheetBottomSafeAreaBehavior.insideSurface,
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final Rect surfaceRect = tester.getRect(find.byType(AxiModalSurface).last);
    final Rect contentRect = tester.getRect(
      find.byKey(const ValueKey<String>('adaptiveSheetContent')),
    );

    expect(surfaceRect.bottom, 844);
    expect(contentRect.bottom, 820);
  });

  testWidgets('zero-padding sheet can opt out of bottom safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
    });

    await tester.pumpWidget(
      const _AxiSheetScaffoldTestApp(
        child: _AdaptiveSheetOpenButton(
          bottomSafeAreaBehavior: AxiSheetBottomSafeAreaBehavior.none,
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final Rect surfaceRect = tester.getRect(find.byType(AxiModalSurface).last);
    final Rect contentRect = tester.getRect(
      find.byKey(const ValueKey<String>('adaptiveSheetContent')),
    );

    expect(surfaceRect.bottom, 844);
    expect(contentRect.bottom, 844);
  });

  testWidgets(
    'scroll body section dividers span the sheet surface while content stays padded',
    (tester) async {
      await tester.pumpWidget(const _AxiSheetScaffoldTestApp());

      final Rect surfaceRect = tester.getRect(
        find.byKey(const ValueKey<String>('sheetSurface')),
      );
      final Rect contentRect = tester.getRect(
        find.byKey(const ValueKey<String>('paddedBodyContent')),
      );
      final Rect dividerRect = tester.getRect(
        find.byKey(const ValueKey<String>('edgeDivider')),
      );

      expect(dividerRect.left, surfaceRect.left);
      expect(dividerRect.right, surfaceRect.right);
      expect(contentRect.left, greaterThan(surfaceRect.left));
      expect(contentRect.right, lessThan(surfaceRect.right));
    },
  );

  testWidgets('body item wrapper keeps custom scroll dividers edge-to-edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _AxiSheetScaffoldTestApp(child: _AxiSheetCustomScrollHarness()),
    );

    final Rect surfaceRect = tester.getRect(
      find.byKey(const ValueKey<String>('customSurface')),
    );
    final Rect contentRect = tester.getRect(
      find.byKey(const ValueKey<String>('customPaddedBodyContent')),
    );
    final Rect dividerRect = tester.getRect(
      find.byKey(const ValueKey<String>('customEdgeDivider')),
    );

    expect(dividerRect.left, surfaceRect.left);
    expect(dividerRect.right, surfaceRect.right);
    expect(contentRect.left, greaterThan(surfaceRect.left));
    expect(contentRect.right, lessThan(surfaceRect.right));
  });

  testWidgets('scroll viewport ends at the footer divider', (tester) async {
    await tester.pumpWidget(
      const _AxiSheetScaffoldTestApp(child: _AxiSheetFooterGapHarness()),
    );

    final Rect listRect = tester.getRect(find.byType(ListView));
    final Rect footerRect = tester.getRect(
      find.byKey(const ValueKey<String>('footerActions')),
    );

    expect((footerRect.top - listRect.bottom).abs(), lessThan(0.1));
  });

  testWidgets(
    'footer sheets keep body content padded above the footer divider',
    (tester) async {
      await tester.pumpWidget(
        const _AxiSheetScaffoldTestApp(child: _AxiSheetFooterGapHarness()),
      );

      final Rect contentRect = tester.getRect(
        find.byKey(const ValueKey<String>('footerBodyContent')),
      );
      final Rect footerRect = tester.getRect(
        find.byKey(const ValueKey<String>('footerActions')),
      );

      expect(footerRect.top - contentRect.bottom, greaterThanOrEqualTo(15));
    },
  );

  testWidgets('sections insert edge-to-edge dividers between padded content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _AxiSheetScaffoldTestApp(child: _AxiSheetSectionsHarness()),
    );

    final Rect surfaceRect = tester.getRect(
      find.byKey(const ValueKey<String>('sectionsSurface')),
    );
    final Rect firstRect = tester.getRect(
      find.byKey(const ValueKey<String>('sectionsFirstContent')),
    );
    final Rect secondRect = tester.getRect(
      find.byKey(const ValueKey<String>('sectionsSecondContent')),
    );
    final Rect dividerRect = tester.getRect(
      find.byType(AxiSheetSectionDivider).first,
    );

    expect(dividerRect.left, surfaceRect.left);
    expect(dividerRect.right, surfaceRect.right);
    expect(firstRect.left, greaterThan(surfaceRect.left));
    expect(secondRect.left, greaterThan(surfaceRect.left));
    expect(dividerRect.height, axiBorders.width);
  });

  testWidgets('edge section can opt out of chips-only spacing', (tester) async {
    await tester.pumpWidget(
      const _AxiSheetScaffoldTestApp(child: _AxiSheetChipsOnlyHarness()),
    );

    final dividerFinder = find.descendant(
      of: find.byKey(const ValueKey<String>('chipsOnlySurface')),
      matching: find.byType(AxiModalEdgeDivider),
    );
    final Rect headerDividerRect = tester.getRect(dividerFinder.first);
    final Rect footerRect = tester.getRect(
      find.byKey(const ValueKey<String>('chipsOnlyFooter')),
    );
    final Rect contentRect = tester.getRect(
      find.byKey(const ValueKey<String>('chipsOnlyContent')),
    );

    expect((contentRect.top - headerDividerRect.bottom).abs(), lessThan(0.1));
    expect((footerRect.top - contentRect.bottom).abs(), lessThan(0.1));
  });
}

class _AdaptiveSheetOpenButton extends StatelessWidget {
  const _AdaptiveSheetOpenButton({required this.bottomSafeAreaBehavior});

  final AxiSheetBottomSafeAreaBehavior bottomSafeAreaBehavior;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          showAdaptiveBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            surfacePadding: EdgeInsets.zero,
            bottomSafeAreaBehavior: bottomSafeAreaBehavior,
            builder: (context) {
              return SizedBox(
                key: const ValueKey<String>('adaptiveSheetContent'),
                height: context.sizing.menuItemHeight,
              );
            },
          );
        },
        child: const Text('Open sheet'),
      ),
    );
  }
}

class _AxiSheetScaffoldTestApp extends StatelessWidget {
  const _AxiSheetScaffoldTestApp({
    this.child = const _AxiSheetScaffoldHarness(),
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [
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

class _AxiSheetScaffoldHarness extends StatelessWidget {
  const _AxiSheetScaffoldHarness();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.sizing.dialogMaxWidth,
      child: AxiModalSurface(
        key: const ValueKey<String>('sheetSurface'),
        padding: EdgeInsets.zero,
        child: AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: const Text('Divider contract'),
            onClose: () {},
            showCloseButton: false,
          ),
          bodyPadding: EdgeInsets.fromLTRB(
            context.spacing.l,
            context.spacing.s,
            context.spacing.l,
            context.spacing.s,
          ),
          children: [
            SizedBox(
              key: const ValueKey<String>('paddedBodyContent'),
              width: double.infinity,
              height: context.sizing.menuItemHeight,
              child: const Text('Padded body content'),
            ),
            const AxiSheetSectionDivider(key: ValueKey<String>('edgeDivider')),
            const Text('More padded body content'),
          ],
        ),
      ),
    );
  }
}

class _AxiSheetCustomScrollHarness extends StatelessWidget {
  const _AxiSheetCustomScrollHarness();

  @override
  Widget build(BuildContext context) {
    final EdgeInsets horizontalPadding = EdgeInsets.symmetric(
      horizontal: context.spacing.l,
    );
    return SizedBox(
      width: context.sizing.dialogMaxWidth,
      child: AxiModalSurface(
        key: const ValueKey<String>('customSurface'),
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in [
                SizedBox(
                  key: const ValueKey<String>('customPaddedBodyContent'),
                  width: double.infinity,
                  height: context.sizing.menuItemHeight,
                  child: const Text('Padded body content'),
                ),
                const AxiSheetSectionDivider(
                  key: ValueKey<String>('customEdgeDivider'),
                ),
              ])
                AxiSheetBodyItem(
                  horizontalPadding: horizontalPadding,
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AxiSheetFooterGapHarness extends StatelessWidget {
  const _AxiSheetFooterGapHarness();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.sizing.dialogMaxWidth,
      child: AxiModalSurface(
        padding: EdgeInsets.zero,
        child: AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: const Text('Footer contract'),
            onClose: () {},
            showCloseButton: false,
          ),
          bodyPadding: EdgeInsets.fromLTRB(
            context.spacing.m,
            context.spacing.s,
            context.spacing.m,
            context.spacing.m,
          ),
          footer: const AxiSheetActions(
            key: ValueKey<String>('footerActions'),
            children: [Text('Done')],
          ),
          children: [
            SizedBox(
              key: const ValueKey<String>('footerBodyContent'),
              height: context.sizing.menuItemHeight,
              child: const Text('Scrollable content'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxiSheetSectionsHarness extends StatelessWidget {
  const _AxiSheetSectionsHarness();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.sizing.dialogMaxWidth,
      child: AxiModalSurface(
        key: const ValueKey<String>('sectionsSurface'),
        padding: EdgeInsets.zero,
        child: AxiSheetScaffold.sections(
          header: AxiSheetHeader(
            title: const Text('Sections contract'),
            onClose: () {},
            showCloseButton: false,
          ),
          sections: [
            AxiSheetSection(
              child: SizedBox(
                key: const ValueKey<String>('sectionsFirstContent'),
                width: double.infinity,
                height: context.sizing.menuItemHeight,
                child: const Text('First section'),
              ),
            ),
            AxiSheetSection(
              child: SizedBox(
                key: const ValueKey<String>('sectionsSecondContent'),
                width: double.infinity,
                height: context.sizing.menuItemHeight,
                child: const Text('Second section'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxiSheetChipsOnlyHarness extends StatelessWidget {
  const _AxiSheetChipsOnlyHarness();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.sizing.dialogMaxWidth,
      child: AxiModalSurface(
        key: const ValueKey<String>('chipsOnlySurface'),
        padding: EdgeInsets.zero,
        child: AxiSheetScaffold.sections(
          header: AxiSheetHeader(
            title: const Text('Invite'),
            onClose: () {},
            showCloseButton: false,
          ),
          footer: const AxiSheetActions(
            key: ValueKey<String>('chipsOnlyFooter'),
            children: [Text('Send')],
          ),
          sections: [
            AxiSheetSection.edge(
              padding: EdgeInsets.zero,
              child: SizedBox(
                key: const ValueKey<String>('chipsOnlyContent'),
                height: context.sizing.menuItemHeight,
                child: const Text('Recipient chips bar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
