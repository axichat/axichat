// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/axi_tap_bounce.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SelectionIndicator extends StatelessWidget {
  const SelectionIndicator({
    super.key,
    required this.visible,
    required this.selected,
    this.onPressed,
  });

  final bool visible;
  final bool selected;
  final VoidCallback? onPressed;

  static const double size = 28.0;
  static const _animationDuration = Duration(milliseconds: 150);
  static const _cornerRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final iconColor =
        selected ? colors.primaryForeground : colors.mutedForeground;
    final background =
        selected ? colors.primary : colors.card.withValues(alpha: 0.96);
    final borderColor =
        selected ? colors.primary : colors.border.withValues(alpha: 0.9);

    Widget child = DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          side: BorderSide(
            color: borderColor,
            width: context.borderSide.width,
          ),
        ),
      ),
      child: Center(
        child: Icon(
          selected ? LucideIcons.check : LucideIcons.square,
          size: selected ? 16 : 14,
          color: iconColor,
        ),
      ),
    );
    if (onPressed != null) {
      child = ShadGestureDetector(
        cursor: SystemMouseCursors.click,
        hoverStrategies: ShadTheme.of(context).hoverStrategies,
        onTap: onPressed,
        child: child,
      ).withTapBounce();
    }
    return AnimatedOpacity(
      duration: _animationDuration,
      opacity: visible ? 1 : 0,
      child: AnimatedScale(
        duration: _animationDuration,
        scale: visible ? 1 : 0.94,
        curve: Curves.easeInOut,
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }
}
