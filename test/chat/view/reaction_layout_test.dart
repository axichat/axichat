// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/common/ui/ui.dart';
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
}

class _ReactionLayoutTestApp extends StatelessWidget {
  const _ReactionLayoutTestApp({required this.child});

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
