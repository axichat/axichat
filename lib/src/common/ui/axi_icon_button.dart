// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

const double _defaultIconScale = 0.6;
const double _ghostIconScale = 0.85;

class AxiIconButton extends StatelessWidget {
  static const double kDefaultSize = 36.0;
  static const double kTapTargetSize = 48.0;

  const AxiIconButton({
    super.key,
    required this.iconData,
    this.icon,
    this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.semanticLabel,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.borderWidth,
    this.usePrimary = false,
    this.ghost = false,
  });

  const AxiIconButton.ghost({
    super.key,
    required this.iconData,
    this.icon,
    this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.semanticLabel,
    this.color,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.usePrimary = false,
  })  : backgroundColor = null,
        borderColor = null,
        borderWidth = null,
        ghost = true;

  final IconData iconData;
  final Widget? icon;
  final void Function()? onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final String? semanticLabel;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? iconSize;
  final double? buttonSize;
  final double? tapTargetSize;
  final double? cornerRadius;
  final double? borderWidth;
  final bool usePrimary;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final env = EnvScope.maybeOf(context);
    final isDesktop = env?.isDesktopPlatform ?? false;
    final bool isGhost = ghost;
    final Color resolvedForeground =
        color ?? (usePrimary ? colors.primary : colors.foreground);
    final Color resolvedBorder =
        borderColor ?? (isGhost ? Colors.transparent : colors.border);
    final Color resolvedBackground =
        backgroundColor ?? (isGhost ? colors.secondary : colors.card);
    final bool enabled = onPressed != null || onLongPress != null;
    final double fallbackIconSize =
        context.iconTheme.size ?? kDefaultSize * _defaultIconScale;
    final double resolvedIconSize = iconSize ??
        (isGhost ? fallbackIconSize * _ghostIconScale : fallbackIconSize);
    final double resolvedButtonSize = buttonSize ?? kDefaultSize;
    final double resolvedTapTargetSize = tapTargetSize ?? kTapTargetSize;
    final double resolvedCornerRadius = cornerRadius ?? 18;
    final double resolvedBorderWidth = borderWidth ?? (isGhost ? 0 : 1.0);
    final paintShape = SquircleBorder(
      cornerRadius: resolvedCornerRadius,
      side: BorderSide(
        color: resolvedBorder,
        width: resolvedBorderWidth,
      ),
    );
    final Widget baseIcon = icon ??
        Icon(
          iconData,
          size: resolvedIconSize,
          color: resolvedForeground,
        );
    final Widget iconWidget = icon == null
        ? baseIcon
        : IconTheme.merge(
            data: IconThemeData(size: resolvedIconSize),
            child: baseIcon,
          );

    Widget tappable = SizedBox(
      width: resolvedTapTargetSize,
      height: resolvedTapTargetSize,
      child: Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: resolvedBackground,
            shape: paintShape,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: paintShape,
            clipBehavior: Clip.antiAlias,
            child: InkResponse(
              onTap: onPressed,
              onLongPress: onLongPress,
              containedInkWell: true,
              highlightShape: BoxShape.rectangle,
              customBorder: paintShape,
              splashFactory:
                  isDesktop ? NoSplash.splashFactory : InkRipple.splashFactory,
              splashColor: !enabled || isDesktop
                  ? Colors.transparent
                  : colors.primary.withValues(alpha: 0.18),
              hoverColor: enabled
                  ? colors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: SizedBox(
                width: resolvedButtonSize,
                height: resolvedButtonSize,
                child: Center(child: iconWidget),
              ),
            ),
          ),
        ),
      ),
    ).withTapBounce(enabled: enabled);

    if (tooltip != null) {
      tappable = AxiTooltip(
        builder: (context) => Text(
          tooltip!,
          style: context.textTheme.muted,
        ),
        child: tappable,
      );
    }

    final withCursor = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: tappable,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? tooltip,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: withCursor,
    );
  }
}
