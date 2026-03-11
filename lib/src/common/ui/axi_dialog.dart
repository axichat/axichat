// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/modal_close_button.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiDialog extends StatelessWidget {
  const AxiDialog({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.constraints,
    this.scrollable,
    this.variant = ShadDialogVariant.primary,
  });

  final Widget? title;
  final Widget? description;
  final Widget? child;
  final List<Widget> actions;
  final BoxConstraints? constraints;
  final bool? scrollable;
  final ShadDialogVariant variant;

  @override
  Widget build(BuildContext context) {
    return ShadDialog.raw(
      variant: variant,
      title: title,
      description: description,
      actions: actions,
      constraints:
          constraints ??
          BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
      scrollable: scrollable,
      radius: context.radius,
      closeIcon: ModalCloseButton(
        onPressed: () => Navigator.of(context).pop(),
        color: ShadTheme.of(context).colorScheme.mutedForeground,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
      ),
      child: child,
    );
  }
}
