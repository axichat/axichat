// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiInputDialog extends StatelessWidget {
  const AxiInputDialog({
    super.key,
    required this.title,
    required this.content,
    this.callback,
    this.callbackText,
    this.loading = false,
    this.actions = const [],
  });

  final Widget title;
  final Widget content;
  final void Function()? callback;
  final String? callbackText;
  final bool loading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final resolvedCallbackText = callbackText ?? context.l10n.commonContinue;
    final loadingSemanticsLabel = context.l10n.accessibilityLoadingLabel;
    final spacing = context.spacing;
    final spinner = AxiProgressIndicator(
      dimension: spacing.s,
      color: context.colorScheme.primaryForeground,
      semanticsLabel: loadingSemanticsLabel,
    );
    final EdgeInsets dialogInsets = EdgeInsets.symmetric(
      horizontal: spacing.l,
      vertical: spacing.l,
    );
    final EdgeInsets headerPadding = EdgeInsets.fromLTRB(
      spacing.m,
      spacing.m,
      spacing.s,
      spacing.s,
    );
    final EdgeInsets bodyPadding = EdgeInsets.fromLTRB(
      spacing.m,
      0,
      spacing.m,
      spacing.m,
    );
    final EdgeInsets actionsPadding = EdgeInsets.fromLTRB(
      spacing.m,
      0,
      spacing.m,
      spacing.m,
    );
    final actionButtons = <Widget>[
      AxiButton.outline(
        onPressed: () => context.pop(),
        child: Text(context.l10n.commonCancel),
      ),
      ...actions,
      AxiButton(
        onPressed: loading ? null : callback,
        loading: loading,
        loadingIndicator: spinner,
        child: Text(resolvedCallbackText),
      ),
    ];
    return Dialog(
      insetPadding: dialogInsets,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: AxiModalSurface(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AxiSheetHeader(
              title: title,
              onClose: () => context.pop(),
              padding: headerPadding,
            ),
            Padding(padding: bodyPadding, child: content),
            Padding(
              padding: actionsPadding,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: spacing.s,
                runSpacing: spacing.s,
                children: actionButtons,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
