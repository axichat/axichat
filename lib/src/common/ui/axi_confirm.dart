import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> confirm(
  BuildContext context, {
  String title = 'Confirm',
  String? message,
  String? text,
  String confirmLabel = 'Continue',
  String cancelLabel = 'Cancel',
  bool destructiveConfirm = true,
  bool barrierDismissible = true,
  TextAlign messageAlign = TextAlign.start,
}) {
  final resolvedMessage = message ?? text ?? 'Are you sure?';
  final Widget? dialogBody = resolvedMessage.isEmpty
      ? null
      : Text(
          resolvedMessage,
          style: context.textTheme.small,
          textAlign: messageAlign,
        );
  return showShadDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final pop = Navigator.of(dialogContext).pop;
      final Widget confirmButton = destructiveConfirm
          ? ShadButton.destructive(
              onPressed: () => pop(true),
              child: Text(confirmLabel),
            )
          : ShadButton(
              onPressed: () => pop(true),
              child: Text(confirmLabel),
            );
      return ShadDialog(
        title: Text(
          title,
          style: context.modalHeaderTextStyle,
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => pop(false),
            child: Text(cancelLabel),
          ).withTapBounce(),
          confirmButton.withTapBounce(),
        ],
        child: dialogBody,
      );
    },
  );
}
