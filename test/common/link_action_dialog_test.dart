import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/common/ui/app_theme.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/app_localizations_en.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart' show ShadColor;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const String _warningUrl = 'https://example.com/\u202etxt';
const String _openButtonLabel = 'Open';
const String _copyButtonLabel = 'Copy';
const String _cancelButtonLabel = 'Cancel';

class LinkDialogHarness extends StatelessWidget {
  const LinkDialogHarness({
    super.key,
    required this.message,
    required this.title,
  });

  final String message;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.build(
      shadColor: ShadColor.blue,
      brightness: Brightness.light,
    );
    return ShadApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: ShadButton(
            onPressed: () => showLinkActionDialog(
              context,
              title: title,
              message: message,
              openLabel: _openButtonLabel,
              copyLabel: _copyButtonLabel,
              cancelLabel: _cancelButtonLabel,
            ),
            child: const Text('Show'),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('shows warning content in link dialog', (tester) async {
    final l10n = AppLocalizationsEn();
    final report = assessLinkSafety(
      raw: _warningUrl,
      kind: LinkSafetyKind.message,
    );
    expect(report, isNotNull);
    final hostLabel = formatLinkSchemeHostLabel(report!);
    final baseMessage = l10n.chatOpenLinkWarningMessage(
      report.displayUri,
      hostLabel,
    );
    final warningBlock = formatLinkWarningText(report.warnings);
    final message = '$baseMessage$warningBlock';

    await tester.pumpWidget(
      LinkDialogHarness(
        title: l10n.chatOpenLinkTitle,
        message: message,
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.chatOpenLinkTitle), findsOneWidget);
    expect(find.text(_openButtonLabel), findsOneWidget);
    expect(
        find.textContaining(l10n.chatOpenLinkWarningMessage(
          report.displayUri,
          hostLabel,
        )),
        findsOneWidget);
    expect(find.textContaining('Warnings:'), findsOneWidget);
  });
}
