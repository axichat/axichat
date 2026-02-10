// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/squircle_border.dart';

class AxiCountBadge extends StatelessWidget {
  const AxiCountBadge({
    super.key,
    required this.count,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.diameter,
    this.cornerRadius,
  });

  final int count;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final double? diameter;
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final text = count > 99 ? '99+' : '$count';
    final resolvedDiameter = diameter ?? sizing.iconButtonIconSize;
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: resolvedDiameter,
          minHeight: resolvedDiameter,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: backgroundColor ?? colors.destructive,
            shape: SquircleBorder(
              cornerRadius: cornerRadius ?? context.radii.container,
              side: BorderSide(
                color: borderColor ?? colors.background,
                width: context.borderSide.width,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.xs,
              vertical: spacing.xxs,
            ),
            child: Center(
              child: Text(
                text,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: context.textTheme.small.copyWith(
                  color: textColor ?? colors.destructiveForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AxiBadge extends StatelessWidget {
  const AxiBadge({
    super.key,
    required this.count,
    this.offset,
    required this.child,
  });

  final int count;
  final Offset? offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final spacing = context.spacing;
    final resolvedOffset = offset ??
        Offset(
          spacing.s,
          -spacing.s,
        );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: resolvedOffset.dy,
          right: resolvedOffset.dx,
          child: AxiCountBadge(count: count),
        ),
      ],
    );
  }
}
