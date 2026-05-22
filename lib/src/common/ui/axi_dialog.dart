// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/axi_adaptive_sheet.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/axi_modal_scaffold.dart';
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
    final EdgeInsets dialogInsets = EdgeInsets.symmetric(
      horizontal: context.spacing.l,
      vertical: context.spacing.l,
    );
    final bool hasHeader = title != null || description != null;
    final Widget header = hasHeader
        ? AxiDialogHeader(
            title: title ?? const SizedBox.shrink(),
            subtitle: description,
            onClose: () => closeSheetWithKeyboardDismiss(
              context,
              () => Navigator.of(context).pop(),
            ),
          )
        : const SizedBox.shrink();
    final Widget? footer = actions.isEmpty
        ? null
        : AxiDialogActions(children: actions);
    final Widget scaffold = child == null
        ? AxiDialogScaffold(
            header: header,
            body: const SizedBox.shrink(),
            footer: footer,
          )
        : AxiDialogScaffold.sections(
            header: header,
            footer: footer,
            scrollPhysics: scrollable == false
                ? const NeverScrollableScrollPhysics()
                : null,
            sections: [AxiModalSection.compact(child: child!)],
          );
    return Dialog(
      insetPadding: dialogInsets,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: ConstrainedBox(
        constraints:
            constraints ??
            BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
        child: AxiModalSurface(padding: EdgeInsets.zero, child: scaffold),
      ),
    );
  }
}
