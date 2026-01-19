// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _modalCloseIconSize = 18.0;
const double _modalCloseButtonSize = 34.0;
const double _modalCloseTapTargetSize = 40.0;

class ModalCloseButton extends StatelessWidget {
  const ModalCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.iconData = LucideIcons.x,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.cornerRadius,
  });

  final VoidCallback onPressed;
  final String? tooltip;
  final IconData iconData;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: iconData,
      tooltip: tooltip ?? MaterialLocalizations.of(context).closeButtonTooltip,
      onPressed: onPressed,
      color: color,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      cornerRadius: cornerRadius,
      iconSize: _modalCloseIconSize,
      buttonSize: _modalCloseButtonSize,
      tapTargetSize: _modalCloseTapTargetSize,
    );
  }
}
