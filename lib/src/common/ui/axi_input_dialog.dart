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
const Duration _inputDialogLoadingAnimation =
    Duration(milliseconds: 200);

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
    final Widget resolvedTitle = DefaultTextStyle.merge(
      style: context.modalHeaderTextStyle,
      child: title,
    );
    final resolvedCallbackText = callbackText ?? context.l10n.commonContinue;
    const loadingSemanticsLabel = 'Loading';
    final spinner = AxiProgressIndicator(
      dimension: _inputDialogSpinnerDimension,
      color: context.colorScheme.primaryForeground,
      semanticsLabel: loadingSemanticsLabel,
    );
    return ShadDialog(
      title: resolvedTitle,
      actions: [
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
            children: [
              AnimatedContainer(
                duration: _inputDialogLoadingAnimation,
                curve: Curves.easeInOut,
                width: loading ? _inputDialogSpinnerSlotSize : 0,
                height: loading ? _inputDialogSpinnerSlotSize : 0,
                child: loading ? spinner : null,
              ),
              AnimatedContainer(
                duration: _inputDialogLoadingAnimation,
                curve: Curves.easeInOut,
                width: loading ? _inputDialogSpinnerGap : 0,
              ),
              Text(resolvedCallbackText),
            ],
          ),
        ).withTapBounce(enabled: callback != null && !loading),
      ],
      child: content,
    );
  }
}
