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
  final resolvedConfirmLabel =
      confirmLabel.isEmpty ? context.l10n.commonContinue : confirmLabel;
  final resolvedCancelLabel =
      cancelLabel.isEmpty ? context.l10n.commonCancel : cancelLabel;
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
        constraints:
            BoxConstraints(maxWidth: dialogContext.sizing.dialogMaxWidth),
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
