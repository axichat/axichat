// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AxiInputDialog extends StatelessWidget {
  const AxiInputDialog({
    super.key,
    required this.title,
    required this.content,
    this.callback,
    this.callbackText,
    this.loading = false,
    this.canPop = true,
    this.showCloseButton = true,
    this.actions = const [],
    this.maxWidth,
  });

  final Widget title;
  final Widget content;
  final void Function()? callback;
  final String? callbackText;
  final bool loading;
  final bool canPop;
  final bool showCloseButton;
  final List<Widget> actions;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedCallbackText = callbackText ?? context.l10n.commonContinue;
    final EdgeInsets dialogInsets = EdgeInsets.symmetric(
      horizontal: context.spacing.l,
      vertical: context.spacing.l,
    );
    final EdgeInsets headerPadding = EdgeInsets.fromLTRB(
      context.spacing.m,
      context.spacing.m,
      context.spacing.s,
      context.spacing.s,
    );
    final EdgeInsets bodyPadding = EdgeInsets.only(
      left: context.spacing.m,
      right: context.spacing.m,
      bottom: context.spacing.m,
    );
    final EdgeInsets actionsPadding = EdgeInsets.only(
      left: context.spacing.m,
      right: context.spacing.m,
      bottom: context.spacing.m,
    );
    final actionButtons = <Widget>[
      AxiButton.outline(
        onPressed: canPop
            ? () => closeSheetWithKeyboardDismiss(context, () => context.pop())
            : null,
        child: Text(context.l10n.commonCancel),
      ),
      ...actions,
      AxiButton.primary(
        onPressed: loading ? null : callback,
        loading: loading,
        child: Text(resolvedCallbackText),
      ),
    ];
    final resolvedMaxWidth = maxWidth ?? context.sizing.dialogMaxWidth;
    final dialogChild = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
      child: AxiModalSurface(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AxiSheetHeader(
              title: title,
              onClose: () =>
                  closeSheetWithKeyboardDismiss(context, () => context.pop()),
              showCloseButton: showCloseButton,
              padding: headerPadding,
            ),
            Padding(padding: bodyPadding, child: content),
            Padding(
              padding: actionsPadding,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: context.spacing.s,
                runSpacing: context.spacing.s,
                children: actionButtons,
              ),
            ),
          ],
        ),
      ),
    );
    return PopScope(
      canPop: canPop,
      child: Dialog(
        insetPadding: dialogInsets,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: dialogChild,
      ),
    );
  }
}
