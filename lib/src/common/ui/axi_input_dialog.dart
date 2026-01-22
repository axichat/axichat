// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _inputDialogSpinnerDimension = 16.0;
const double _inputDialogSpinnerPadding = 1.0;
const double _inputDialogSpinnerSlotSize =
    _inputDialogSpinnerDimension + (_inputDialogSpinnerPadding * 2);
const double _inputDialogSpinnerGap = 8.0;
const Duration _inputDialogLoadingAnimation = Duration(milliseconds: 200);

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
    const loadingSemanticsLabel = 'Loading';
    final spinner = AxiProgressIndicator(
      dimension: _inputDialogSpinnerDimension,
      color: context.colorScheme.primaryForeground,
      semanticsLabel: loadingSemanticsLabel,
    );
    final spinnerSlot = ButtonSpinnerSlot(
      isVisible: loading,
      spinner: spinner,
      slotSize: _inputDialogSpinnerSlotSize,
      gap: _inputDialogSpinnerGap,
      duration: _inputDialogLoadingAnimation,
    );
    const double headerTopPadding = 16.0;
    const double headerHorizontalPadding = 20.0;
    const double headerRightPadding = 12.0;
    const double headerBottomPadding = 12.0;
    const double bodyHorizontalPadding = 20.0;
    const double bodyBottomPadding = 16.0;
    const double actionsHorizontalPadding = 20.0;
    const double actionsBottomPadding = 20.0;
    const double actionSpacing = 8.0;
    const EdgeInsets dialogInsets = EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 24,
    );
    const EdgeInsets headerPadding = EdgeInsets.fromLTRB(
      headerHorizontalPadding,
      headerTopPadding,
      headerRightPadding,
      headerBottomPadding,
    );
    const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(
      bodyHorizontalPadding,
      0,
      bodyHorizontalPadding,
      bodyBottomPadding,
    );
    const EdgeInsets actionsPadding = EdgeInsets.fromLTRB(
      actionsHorizontalPadding,
      0,
      actionsHorizontalPadding,
      actionsBottomPadding,
    );
    final actionButtons = <Widget>[
      ShadButton.outline(
        onPressed: () => context.pop(),
        child: Text(context.l10n.commonCancel),
      ).withTapBounce(),
      ...actions,
      ShadButton(
        enabled: callback != null && !loading,
        onPressed: loading ? null : callback,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [spinnerSlot, Text(resolvedCallbackText)],
        ),
      ).withTapBounce(enabled: callback != null && !loading),
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
                spacing: actionSpacing,
                runSpacing: actionSpacing,
                children: actionButtons,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
