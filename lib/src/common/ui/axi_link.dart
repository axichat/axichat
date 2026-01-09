// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class AxiLink extends StatelessWidget {
  const AxiLink({
    super.key,
    required this.text,
    required this.link,
  });

  final String text;
  final String link;

  @override
  Widget build(BuildContext context) {
    return AxiLinkDetector(
      onTap: () => unawaited(_handleTap(context)),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.lightBlueAccent,
          decoration: TextDecoration.underline,
          decorationColor: Colors.lightBlueAccent,
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    final l10n = context.l10n;
    final report = assessLinkSafety(
      raw: link,
      kind: LinkSafetyKind.message,
    );
    if (report == null || !report.isSafe) {
      _showSnackbar(context, l10n.chatInvalidLink(link.trim()));
      return;
    }
    final hostLabel = formatLinkSchemeHostLabel(report);
    final baseMessage = report.needsWarning
        ? l10n.chatOpenLinkWarningMessage(
            report.displayUri,
            hostLabel,
          )
        : l10n.chatOpenLinkMessage(
            report.displayUri,
            hostLabel,
          );
    final warningBlock = formatLinkWarningText(report.warnings);
    final action = await showLinkActionDialog(
      context,
      title: l10n.chatOpenLinkTitle,
      message: '$baseMessage$warningBlock',
      openLabel: l10n.chatOpenLinkConfirm,
      copyLabel: l10n.chatActionCopy,
      cancelLabel: l10n.commonCancel,
    );
    if (!context.mounted) return;
    if (action == null) return;
    if (action == LinkAction.copy) {
      await Clipboard.setData(
        ClipboardData(text: report.displayUri),
      );
      return;
    }
    final launched = await launchUrl(
      report.uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showSnackbar(context, l10n.chatUnableToOpenHost(report.displayHost));
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}

class AxiLinkDetector extends StatelessWidget {
  const AxiLinkDetector({
    super.key,
    required this.onTap,
    required this.child,
  });

  final void Function()? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShadGestureDetector(
      cursor: SystemMouseCursors.click,
      hoverStrategies: mobileHoverStrategies,
      onTap: onTap,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.lightBlueAccent,
          decoration: TextDecoration.underline,
          decorationColor: Colors.lightBlueAccent,
        ),
        child: child,
      ),
    );
  }
}
