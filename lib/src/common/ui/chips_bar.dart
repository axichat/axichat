// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

const double chipsBarHeight = 36.0;
const Duration chipsBarAnimationDuration = Duration(milliseconds: 360);
const double chipsBarHeaderFontSize = 12.0;
const double chipsBarHeaderLetterSpacing = 0.4;
const double chipsBarHeaderBadgeRadius = 8.0;
const double chipsBarHeaderBadgeFontSize = 11.0;
const double chipsBarHeaderBorderRadius = 12.0;
const double chipsBarLightOverlayOpacity = 0.07;
const double chipsBarDarkOverlayOpacity = 0.06;
const EdgeInsets chipsBarBadgePadding =
    EdgeInsets.symmetric(horizontal: 6, vertical: 2);
const EdgeInsets chipsBarCountBadgePadding =
    EdgeInsets.symmetric(horizontal: 10, vertical: 4);
const double chipsBarCountBadgeRadius = 12.0;
const double chipsBarCountBadgeFontSize = 12.0;
const double chipsBarCountBadgeLetterSpacing = 0.4;

TextStyle chipsBarHeaderTextStyle(BuildContext context) {
  final TextStyle? base = Theme.of(context).textTheme.labelSmall;
  return (base ?? const TextStyle()).copyWith(
    fontSize: chipsBarHeaderFontSize,
    fontWeight: FontWeight.w600,
    color:
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
    letterSpacing: chipsBarHeaderLetterSpacing,
  );
}

Color chipsBarBackground(ColorScheme colors) {
  final overlay = colors.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: chipsBarDarkOverlayOpacity)
      : colors.primary.withValues(alpha: chipsBarLightOverlayOpacity);
  return Color.alphaBlend(overlay, colors.surfaceContainerHigh);
}

class ChipsBarSurface extends StatelessWidget {
  const ChipsBarSurface({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding,
    this.borderSide,
    this.duration = chipsBarAnimationDuration,
    this.curve = Curves.easeInOutCubic,
    this.includeTopBorder = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderSide? borderSide;
  final Duration duration;
  final Curve curve;
  final bool includeTopBorder;

  @override
  Widget build(BuildContext context) {
    final Color resolvedBackground =
        backgroundColor ?? chipsBarBackground(Theme.of(context).colorScheme);
    final BorderSide resolvedBorder =
        borderSide ?? BorderSide(color: Theme.of(context).colorScheme.outline);
    final Border? border =
        includeTopBorder ? Border(top: resolvedBorder) : null;
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedBackground,
        border: border,
      ),
      child: child,
    );
  }
}

class ChipsBarCountBadge extends StatelessWidget {
  const ChipsBarCountBadge({
    super.key,
    required this.count,
    required this.expanded,
    required this.colors,
    this.duration = chipsBarAnimationDuration,
  });

  final int count;
  final bool expanded;
  final ColorScheme colors;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final background =
        expanded ? colors.primary : colors.primary.withValues(alpha: 0.09);
    final foreground = expanded ? colors.onPrimary : colors.primary;
    return AnimatedContainer(
      duration: duration,
      padding: chipsBarCountBadgePadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(chipsBarCountBadgeRadius),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: chipsBarCountBadgeFontSize,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: chipsBarCountBadgeLetterSpacing,
        ),
      ),
    );
  }
}
