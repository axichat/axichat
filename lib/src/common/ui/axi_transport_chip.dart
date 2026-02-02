// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiTransportChip extends StatelessWidget {
  const AxiTransportChip({
    super.key,
    required this.transport,
    this.compact = false,
    this.label,
  });

  final MessageTransport transport;
  final bool compact;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final radii = context.radii;
    final isEmail = transport.isEmail;
    final background = isEmail ? colors.destructive : colors.primary;
    final foreground =
        isEmail ? colors.destructiveForeground : colors.primaryForeground;
    final borderColor = colors.background;

    final padding = compact
        ? EdgeInsets.symmetric(
            horizontal: spacing.xs,
            vertical: spacing.xxs,
          )
        : EdgeInsets.symmetric(
            horizontal: spacing.s,
            vertical: spacing.xs,
          );
    final borderRadius = compact ? radii.squircleSm : radii.squircle;
    final borderWidth = context.borderSide.width;
    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: background,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
      child: Text(
        label ?? transport.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: context.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class AxiCompatibilityBadge extends StatelessWidget {
  const AxiCompatibilityBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final size =
        compact ? sizing.iconButtonIconSize : sizing.iconButtonIconSize + 4;
    final iconSize =
        compact ? sizing.menuItemIconSize : sizing.menuItemIconSize + 4;
    final borderWidth = context.borderSide.width;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary,
        border: Border.all(color: colors.background, width: borderWidth),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          LucideIcons.check,
          size: iconSize,
          color: colors.primaryForeground,
        ),
      ),
    );
  }
}
