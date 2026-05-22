// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/app_localizations_en.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart' show ShadColor;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('invalid links use snackbar feedback', (tester) async {
    final l10n = AppLocalizationsEn();

    await tester.pumpWidget(
      const _AxiLinkTestApp(
        child: AxiLink(text: 'Blocked link', link: 'javascript:alert(1)'),
      ),
    );

    tester.widget<AxiLinkDetector>(find.byType(AxiLinkDetector)).onTap!();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(l10n.chatInvalidLink('javascript:alert(1)')),
      findsOneWidget,
    );
  });
}

class _AxiLinkTestApp extends StatelessWidget {
  const _AxiLinkTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      theme: AppTheme.build(
        shadColor: ShadColor.blue,
        brightness: Brightness.light,
        platform: defaultTargetPlatform,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ScaffoldMessenger(
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }
}
