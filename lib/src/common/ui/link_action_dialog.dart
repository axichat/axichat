// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum LinkAction {
  open,
  copy,
}

Future<LinkAction?> showLinkActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String openLabel,
  required String copyLabel,
  required String cancelLabel,
}) {
  return showShadDialog<LinkAction>(
    context: context,
    builder: (dialogContext) {
      final pop = Navigator.of(dialogContext).pop;
      return ShadDialog(
        title: Text(
          title,
          style: context.modalHeaderTextStyle,
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => pop(null),
            child: Text(cancelLabel),
          ).withTapBounce(),
          ShadButton.secondary(
            onPressed: () => pop(LinkAction.copy),
            child: Text(copyLabel),
          ).withTapBounce(),
          ShadButton(
            onPressed: () => pop(LinkAction.open),
            child: Text(openLabel),
          ).withTapBounce(),
        ],
        child: SelectableText(
          message,
          style: context.textTheme.small,
          textAlign: TextAlign.start,
        ),
      );
    },
  );
}
