import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/home/view/home_screen.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveHomeSecondaryPane', () {
    const welcomeJid = 'axichat@welcome.axichat.invalid';
    final welcomeChat = Chat.fromJid(welcomeJid);

    test('uses the explicit open chat when openJid is present', () {
      final pane = resolveHomeSecondaryPane(
        openJid: 'room@axi.im',
        navPlacement: NavPlacement.rail,
        items: [welcomeChat],
      );

      expect(pane.kind, HomeSecondaryPaneKind.openChat);
      expect(pane.jid, 'room@axi.im');
      expect(pane.hasChatPane, isTrue);
      expect(pane.syncWithOpenChatRoute, isTrue);
      expect(pane.scopeKey, 'open:room@axi.im');
    });

    test('uses the welcome fallback on wide layouts with no explicit chat', () {
      final pane = resolveHomeSecondaryPane(
        openJid: null,
        navPlacement: NavPlacement.rail,
        items: [welcomeChat],
      );

      expect(pane.kind, HomeSecondaryPaneKind.welcomeFallback);
      expect(pane.jid, welcomeJid);
      expect(pane.hasChatPane, isTrue);
      expect(pane.syncWithOpenChatRoute, isFalse);
      expect(pane.scopeKey, 'welcome:$welcomeJid');
    });

    test('returns no pane on bottom layouts without an explicit chat', () {
      final pane = resolveHomeSecondaryPane(
        openJid: null,
        navPlacement: NavPlacement.bottom,
        items: [welcomeChat],
      );

      expect(pane.kind, HomeSecondaryPaneKind.none);
      expect(pane.jid, isNull);
      expect(pane.hasChatPane, isFalse);
      expect(pane.syncWithOpenChatRoute, isFalse);
    });

    test('returns no pane when no welcome fallback is available', () {
      final pane = resolveHomeSecondaryPane(
        openJid: null,
        navPlacement: NavPlacement.rail,
        items: [Chat.fromJid('friend@axi.im')],
      );

      expect(pane.kind, HomeSecondaryPaneKind.none);
      expect(pane.jid, isNull);
      expect(pane.hasChatPane, isFalse);
    });

    test('gives explicit open and fallback panes different subtree keys', () {
      const jid = welcomeJid;
      final explicitPane = HomeSecondaryPane.openChat(jid);
      final fallbackPane = HomeSecondaryPane.welcomeFallback(jid);

      expect(explicitPane.scopeKey, 'open:$jid');
      expect(fallbackPane.scopeKey, 'welcome:$jid');
      expect(explicitPane.scopeKey, isNot(fallbackPane.scopeKey));
    });

    testWidgets(
      'different pane identities remount the keyed subtree even for the same jid',
      (tester) async {
        var initCount = 0;
        var disposeCount = 0;

        Widget buildHost(HomeSecondaryPane pane) {
          return MaterialApp(
            home: KeyedSubtree(
              key: ValueKey(pane.scopeKey),
              child: _PaneProbe(
                onInit: () => initCount += 1,
                onDispose: () => disposeCount += 1,
              ),
            ),
          );
        }

        await tester.pumpWidget(
          buildHost(HomeSecondaryPane.openChat(welcomeJid)),
        );
        expect(initCount, 1);
        expect(disposeCount, 0);

        await tester.pumpWidget(
          buildHost(HomeSecondaryPane.welcomeFallback(welcomeJid)),
        );
        expect(initCount, 2);
        expect(disposeCount, 1);
      },
    );
  });
}

class _PaneProbe extends StatefulWidget {
  const _PaneProbe({required this.onInit, required this.onDispose});

  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_PaneProbe> createState() => _PaneProbeState();
}

class _PaneProbeState extends State<_PaneProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
