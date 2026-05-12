// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('renders recovered OTP content without details controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _EmailRecoveredContentTestApp(
        child: material.Builder(
          builder: (context) => EmailRecoveredContentView(
            items: const <EmailRecoveredContent>[
              EmailRecoveredContent(
                kind: EmailRecoveredContentKind.verificationCode,
                text: '123456',
              ),
            ],
            textStyle: context.textTheme.p,
            onLinkTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Additional email content'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('Readable'), findsNothing);
    expect(find.text('Full content'), findsNothing);
  });
}

class _EmailRecoveredContentTestApp extends material.StatelessWidget {
  const _EmailRecoveredContentTestApp({required this.child});

  final material.Widget child;

  @override
  material.Widget build(material.BuildContext context) {
    return material.MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: material.ThemeData(
        extensions: const <material.ThemeExtension<dynamic>>[
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
          brightness: material.Brightness.light,
        ),
        child: material.Scaffold(body: material.Center(child: child)),
      ),
    );
  }
}
