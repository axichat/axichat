// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

final class AttachmentApprovalDecision {
  const AttachmentApprovalDecision({
    required this.approved,
    required this.alwaysAllow,
  });

  final bool approved;
  final bool alwaysAllow;
}

class AttachmentApprovalDialog extends StatefulWidget {
  const AttachmentApprovalDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.showAutoTrustToggle,
    required this.autoTrustLabel,
    required this.autoTrustHint,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool showAutoTrustToggle;
  final String autoTrustLabel;
  final String autoTrustHint;

  @override
  State<AttachmentApprovalDialog> createState() =>
      _AttachmentApprovalDialogState();
}

class _AttachmentApprovalDialogState extends State<AttachmentApprovalDialog> {
  var _alwaysAllow = false;

  @override
  Widget build(BuildContext context) {
    final pop = Navigator.of(context).pop;
    final spacing = context.spacing;
    return ShadDialog(
      title: Text(widget.title, style: context.modalHeaderTextStyle),
      actions: [
        AxiButton(
          onPressed: () => pop(
            const AttachmentApprovalDecision(
              approved: false,
              alwaysAllow: false,
            ),
          ),
          size: AxiButtonSize.sm,
          variant: AxiButtonVariant.outline,
          child: Text(widget.cancelLabel),
        ),
        AxiButton(
          onPressed: () => pop(
            AttachmentApprovalDecision(
              approved: true,
              alwaysAllow: _alwaysAllow,
            ),
          ),
          size: AxiButtonSize.sm,
          variant: AxiButtonVariant.secondary,
          child: Text(widget.confirmLabel),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          Text(widget.message, style: context.textTheme.muted),
          if (widget.showAutoTrustToggle)
            AxiCheckboxFormField(
              initialValue: _alwaysAllow,
              inputLabel: Text(widget.autoTrustLabel),
              inputSublabel: Text(widget.autoTrustHint),
              onChanged: (value) {
                setState(() {
                  _alwaysAllow = value;
                });
              },
            ),
        ],
      ),
    );
  }
}
