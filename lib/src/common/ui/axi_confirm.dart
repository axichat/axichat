// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> confirm(
  BuildContext context, {
  String title = '',
  String? message,
  String? text,
  String confirmLabel = '',
  String cancelLabel = '',
  bool destructiveConfirm = true,
  bool barrierDismissible = true,
  TextAlign messageAlign = TextAlign.start,
}) {
  final resolvedTitle = title.isEmpty ? context.l10n.commonConfirm : title;
  final resolvedMessage = message ?? text ?? context.l10n.commonAreYouSure;
  final resolvedConfirmLabel = confirmLabel.isEmpty
      ? context.l10n.commonContinue
      : confirmLabel;
  final resolvedCancelLabel = cancelLabel.isEmpty
      ? context.l10n.commonCancel
      : cancelLabel;
  final Widget? dialogBody = resolvedMessage.isEmpty
      ? null
      : Text(
          resolvedMessage,
          style: context.textTheme.small,
          textAlign: messageAlign,
        );
  return showFadeScaleDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final pop = Navigator.of(dialogContext).pop;
      final Widget confirmButton = destructiveConfirm
          ? AxiButton.destructive(
              onPressed: () => pop(true),
              child: Text(resolvedConfirmLabel),
            )
          : AxiButton.primary(
              onPressed: () => pop(true),
              child: Text(resolvedConfirmLabel),
            );
      return ShadDialog(
        constraints: BoxConstraints(
          maxWidth: dialogContext.sizing.dialogMaxWidth,
        ),
        title: Text(resolvedTitle, style: context.modalHeaderTextStyle),
        actions: [
          AxiButton.outline(
            onPressed: () => pop(false),
            child: Text(resolvedCancelLabel),
          ),
          confirmButton,
        ],
        child: dialogBody,
      );
    },
  );
}

final class EmailSendConfirmationDecision {
  const EmailSendConfirmationDecision({
    required this.confirmed,
    required this.dontShowAgain,
  });

  final bool confirmed;
  final bool dontShowAgain;
}

Future<EmailSendConfirmationDecision?> confirmEmailSend(
  BuildContext context, {
  required List<String> recipients,
  required String body,
}) {
  return showFadeScaleDialog<EmailSendConfirmationDecision>(
    context: context,
    builder: (dialogContext) =>
        _EmailSendConfirmationDialog(recipients: recipients, body: body),
  );
}

class _EmailSendConfirmationDialog extends StatefulWidget {
  const _EmailSendConfirmationDialog({
    required this.recipients,
    required this.body,
  });

  final List<String> recipients;
  final String body;

  @override
  State<_EmailSendConfirmationDialog> createState() =>
      _EmailSendConfirmationDialogState();
}

class _EmailSendConfirmationDialogState
    extends State<_EmailSendConfirmationDialog> {
  var _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final recipientLines = widget.recipients
        .map((recipient) => recipient.trim())
        .where((recipient) => recipient.isNotEmpty)
        .toList(growable: false);
    final recipientsText = recipientLines.join('\n');
    final bodyText = widget.body.trim().isEmpty
        ? l10n.emailSendConfirmEmptyBody
        : widget.body;
    final maxPreviewHeight = context.sizing.menuItemHeight * 5;
    final pop = Navigator.of(context).pop;
    return ShadDialog(
      constraints: BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
      title: Text(
        l10n.emailSendConfirmTitle,
        style: context.modalHeaderTextStyle,
      ),
      actions: [
        AxiButton.outline(
          onPressed: () => pop(
            const EmailSendConfirmationDecision(
              confirmed: false,
              dontShowAgain: false,
            ),
          ),
          child: Text(l10n.commonCancel),
        ),
        AxiButton.primary(
          onPressed: () => pop(
            EmailSendConfirmationDecision(
              confirmed: true,
              dontShowAgain: _dontShowAgain,
            ),
          ),
          child: Text(l10n.commonSend),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.s,
        children: [
          Text(l10n.emailSendConfirmMessage, style: context.textTheme.small),
          _EmailSendPreview(
            label: l10n.emailSendConfirmRecipientsLabel,
            value: recipientsText,
            maxHeight: maxPreviewHeight,
          ),
          _EmailSendPreview(
            label: l10n.emailSendConfirmBodyLabel,
            value: bodyText,
            maxHeight: maxPreviewHeight,
          ),
          AxiCheckboxFormField(
            initialValue: _dontShowAgain,
            inputLabel: Text(l10n.emailSendConfirmDontShowAgain),
            onChanged: (value) {
              setState(() {
                _dontShowAgain = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _EmailSendPreview extends StatelessWidget {
  const _EmailSendPreview({
    required this.label,
    required this.value,
    required this.maxHeight,
  });

  final String label;
  final String value;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs,
      children: [
        Text(
          label,
          style: context.textTheme.small.copyWith(fontWeight: FontWeight.w600),
        ),
        Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: context.colorScheme.card,
            borderRadius: BorderRadius.circular(context.radii.container),
            border: Border.all(
              color: context.borderSide.color,
              width: context.borderSide.width,
            ),
          ),
          padding: EdgeInsets.all(spacing.s),
          child: SingleChildScrollView(
            child: SelectableText(value, style: context.textTheme.small),
          ),
        ),
      ],
    );
  }
}
