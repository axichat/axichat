// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('reaction width includes count text', (tester) async {
    late double singleWidth;
    late double countedWidth;

    await tester.pumpWidget(
      _ReactionLayoutTestApp(
        child: Builder(
          builder: (context) {
            final mediaQuery = MediaQuery.of(context);
            singleWidth = measureReactionChipWidth(
              context: context,
              reaction: const ReactionPreview(emoji: '😂', count: 1),
              textDirection: TextDirection.ltr,
              textScaler: mediaQuery.textScaler,
            );
            countedWidth = measureReactionChipWidth(
              context: context,
              reaction: const ReactionPreview(emoji: '😂', count: 12),
              textDirection: TextDirection.ltr,
              textScaler: mediaQuery.textScaler,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(countedWidth, greaterThan(singleWidth));
  });

  testWidgets('truncated reaction layout keeps the first reaction visible', (
    tester,
  ) async {
    const reactions = <ReactionPreview>[
      ReactionPreview(emoji: '😂', count: 1),
      ReactionPreview(emoji: '🔥', count: 1),
      ReactionPreview(emoji: '👍', count: 1),
    ];
    late ({List<ReactionPreview> items, bool overflowed, double totalWidth})
    layout;

    await tester.pumpWidget(
      _ReactionLayoutTestApp(
        child: Builder(
          builder: (context) {
            final width = minimumReactionStripContentWidth(
              context: context,
              reactions: reactions,
            );
            layout = layoutReactionStrip(
              context: context,
              reactions: reactions,
              maxContentWidth: width,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      layout.items.map((reaction) => reaction.emoji).toList(),
      equals(const <String>['😂']),
    );
    expect(layout.overflowed, isTrue);
    expect(layout.totalWidth, greaterThan(0));
  });

  testWidgets('reaction layout shows all reactions when width allows', (
    tester,
  ) async {
    const reactions = <ReactionPreview>[
      ReactionPreview(emoji: '😂', count: 1),
      ReactionPreview(emoji: '🔥', count: 1),
    ];
    late ({List<ReactionPreview> items, bool overflowed, double totalWidth})
    layout;

    await tester.pumpWidget(
      _ReactionLayoutTestApp(
        child: Builder(
          builder: (context) {
            final mediaQuery = MediaQuery.of(context);
            final firstWidth = measureReactionChipWidth(
              context: context,
              reaction: reactions.first,
              textDirection: TextDirection.ltr,
              textScaler: mediaQuery.textScaler,
            );
            final secondWidth = measureReactionChipWidth(
              context: context,
              reaction: reactions.last,
              textDirection: TextDirection.ltr,
              textScaler: mediaQuery.textScaler,
            );
            layout = layoutReactionStrip(
              context: context,
              reactions: reactions,
              maxContentWidth: firstWidth + secondWidth + axiBorders.width,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      layout.items.map((reaction) => reaction.emoji).toList(),
      equals(const <String>['😂', '🔥']),
    );
    expect(layout.overflowed, isFalse);
  });

  testWidgets('reaction layout drops the ellipsis before the first chip', (
    tester,
  ) async {
    const reactions = <ReactionPreview>[
      ReactionPreview(emoji: '😂', count: 1),
      ReactionPreview(emoji: '🔥', count: 1),
    ];
    late ({List<ReactionPreview> items, bool overflowed, double totalWidth})
    layout;

    await tester.pumpWidget(
      _ReactionLayoutTestApp(
        child: Builder(
          builder: (context) {
            final mediaQuery = MediaQuery.of(context);
            final firstWidth = measureReactionChipWidth(
              context: context,
              reaction: reactions.first,
              textDirection: TextDirection.ltr,
              textScaler: mediaQuery.textScaler,
            );
            layout = layoutReactionStrip(
              context: context,
              reactions: reactions,
              maxContentWidth: firstWidth,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      layout.items.map((reaction) => reaction.emoji).toList(),
      equals(const <String>['😂']),
    );
    expect(layout.overflowed, isFalse);
  });

  test(
    'group message avatar lookup uses sender occupant data before opaque occupant ids',
    () {
      const roomJid = 'room@conference.axi.im';
      const senderOccupantId = '$roomJid/friend';
      final path = resolveMessageAvatarPath(
        message: const Message(
          stanzaID: 'm1',
          senderJid: senderOccupantId,
          chatJid: roomJid,
          occupantID: 'opaque-occupant-id',
        ),
        roomState: RoomState(
          roomJid: roomJid,
          occupants: <String, Occupant>{
            senderOccupantId: Occupant(
              occupantId: senderOccupantId,
              nick: 'friend',
              realJid: 'friend@axi.im',
            ),
          },
        ),
        rosterAvatarPathsByJid: const <String, String>{
          'friend@axi.im': '/avatars/friend.png',
        },
        chatAvatarPathsByJid: const <String, String>{},
      );

      expect(path, '/avatars/friend.png');
    },
  );

  test(
    'group message avatar lookup keeps sender bare jid fallback while room hydration catches up',
    () {
      const roomJid = 'room@conference.axi.im';
      const senderBareJid = 'friend@axi.im';
      final path = resolveMessageAvatarPath(
        message: const Message(
          stanzaID: 'm2',
          senderJid: senderBareJid,
          chatJid: roomJid,
          occupantID: 'opaque-occupant-id',
        ),
        roomState: RoomState(
          roomJid: roomJid,
          occupants: <String, Occupant>{
            '$roomJid/friend': Occupant(
              occupantId: '$roomJid/friend',
              nick: 'friend',
              isPresent: true,
            ),
          },
        ),
        rosterAvatarPathsByJid: const <String, String>{
          senderBareJid: '/avatars/friend.png',
        },
        chatAvatarPathsByJid: const <String, String>{},
      );

      expect(path, '/avatars/friend.png');
    },
  );
}

class _ReactionLayoutTestApp extends StatelessWidget {
  const _ReactionLayoutTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
