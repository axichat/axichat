// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _defaultIconScale = 0.6;

enum AxiIconButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive;
}

class AxiIconButton extends StatefulWidget {
  static const double kDefaultSize = axiSpaceL;
  static const double kTapTargetSize = axiSpaceXl;

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
  })  : variant = AxiIconButtonVariant.primary,
        resolvedIconSize = iconSize ?? kDefaultSize * _defaultIconScale,
        resolvedButtonSize = buttonSize ?? kDefaultSize,
        resolvedTapTargetSize = tapTargetSize ?? kTapTargetSize,
        resolvedCornerRadius = cornerRadius ?? axiSquircleRadius,
        resolvedBorderWidth = borderWidth ?? axiSpaceXxs;

  const AxiIconButton.raw({
    super.key,
    required this.variant,
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
  })  : resolvedIconSize = iconSize ?? kDefaultSize * _defaultIconScale,
        resolvedButtonSize = buttonSize ?? kDefaultSize,
        resolvedTapTargetSize = tapTargetSize ?? kTapTargetSize,
        resolvedCornerRadius = cornerRadius ?? axiSquircleRadius,
        resolvedBorderWidth = borderWidth ??
            (variant == AxiIconButtonVariant.outline
                ? axiSpaceXxs
                : (variant == AxiIconButtonVariant.ghost ? 0 : axiSpaceXxs));

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
    this.backgroundColor,
    this.borderColor,
  })  : variant = AxiIconButtonVariant.ghost,
        borderWidth = null,
        resolvedIconSize = iconSize ?? kDefaultSize * _defaultIconScale,
        resolvedButtonSize = buttonSize ?? kDefaultSize,
        resolvedTapTargetSize = tapTargetSize ?? kTapTargetSize,
        resolvedCornerRadius = cornerRadius ?? axiSquircleRadius,
        resolvedBorderWidth = 0;

  const AxiIconButton.outline({
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
  })  : variant = AxiIconButtonVariant.outline,
        backgroundColor = null,
        borderColor = null,
        borderWidth = null,
        resolvedIconSize = iconSize ?? kDefaultSize * _defaultIconScale,
        resolvedButtonSize = buttonSize ?? kDefaultSize,
        resolvedTapTargetSize = tapTargetSize ?? kTapTargetSize,
        resolvedCornerRadius = cornerRadius ?? axiSquircleRadius,
        resolvedBorderWidth = axiSpaceXxs;

  const AxiIconButton.secondary({
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
    this.borderWidth,
    this.usePrimary = false,
    this.backgroundColor,
    this.borderColor,
  })  : variant = AxiIconButtonVariant.secondary,
        resolvedIconSize = iconSize ?? kDefaultSize * _defaultIconScale,
        resolvedButtonSize = buttonSize ?? kDefaultSize,
        resolvedTapTargetSize = tapTargetSize ?? kTapTargetSize,
        resolvedCornerRadius = cornerRadius ?? axiSquircleRadius,
        resolvedBorderWidth = borderWidth ?? axiSpaceXxs;

  const AxiIconButton.destructive({
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
    this.borderWidth,
    this.usePrimary = false,
    this.backgroundColor,
    this.borderColor,
  })  : variant = AxiIconButtonVariant.destructive,
        resolvedIconSize = iconSize ?? kDefaultSize * _defaultIconScale,
        resolvedButtonSize = buttonSize ?? kDefaultSize,
        resolvedTapTargetSize = tapTargetSize ?? kTapTargetSize,
        resolvedCornerRadius = cornerRadius ?? axiSquircleRadius,
        resolvedBorderWidth = borderWidth ?? axiSpaceXxs;

  final AxiIconButtonVariant variant;
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
  final double resolvedIconSize;
  final double resolvedButtonSize;
  final double resolvedTapTargetSize;
  final double resolvedCornerRadius;
  final double resolvedBorderWidth;

  @override
  State<AxiIconButton> createState() => _AxiIconButtonState();
}

class _AxiIconButtonState extends State<AxiIconButton> {
  late final AxiTapBounceController _bounceController =
      AxiTapBounceController();

  @override
  Widget build(BuildContext context) {
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final colors = context.colorScheme;
    final env = EnvScope.maybeOf(context);
    final isDesktop = env?.isDesktopPlatform ?? false;
    final Color fallbackForeground = widget.usePrimary
        ? colors.primary
        : switch (widget.variant) {
            AxiIconButtonVariant.destructive => colors.destructive,
            _ => colors.foreground,
          };
    final Color resolvedForeground = widget.color ?? fallbackForeground;
    final Color resolvedBorder = widget.borderColor ??
        (widget.variant == AxiIconButtonVariant.ghost
            ? Colors.transparent
            : colors.border);
    final Color resolvedBackground = widget.backgroundColor ??
        switch (widget.variant) {
          AxiIconButtonVariant.outline => Colors.transparent,
          AxiIconButtonVariant.ghost => colors.secondary,
          _ => colors.card,
        };
    final bool enabled = widget.onPressed != null || widget.onLongPress != null;
    final paintShape = SquircleBorder(
      cornerRadius: widget.resolvedCornerRadius,
      side:
          BorderSide(color: resolvedBorder, width: widget.resolvedBorderWidth),
    );
    final Widget baseIcon = widget.icon ??
        Icon(
          widget.iconData,
          size: widget.resolvedIconSize,
          color: resolvedForeground,
        );
    final Widget iconWidget = widget.icon == null
        ? baseIcon
        : IconTheme.merge(
            data: IconThemeData(size: widget.resolvedIconSize),
            child: baseIcon,
          );

    Widget tappable = SizedBox(
      width: widget.resolvedTapTargetSize,
      height: widget.resolvedTapTargetSize,
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
              onTap: widget.onPressed,
              onLongPress: widget.onLongPress,
              onHighlightChanged: enabled ? _bounceController.setPressed : null,
              onTapCancel: enabled ? _bounceController.handleTapCancel : null,
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
                width: widget.resolvedButtonSize,
                height: widget.resolvedButtonSize,
                child: Center(child: iconWidget),
              ),
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      const double defaultBounceScale = 0.96;
      const double compactBounceScale = 0.92;
      const double compactSizeThreshold = AxiIconButton.kDefaultSize;
      const int pressDurationNumerator = 4;
      const int pressDurationDenominator = 15;
      const int releaseDurationNumerator = 3;
      const int releaseDurationDenominator = 5;
      final Duration pressDuration = Duration(
        milliseconds:
            (animationDuration.inMilliseconds * pressDurationNumerator) ~/
                pressDurationDenominator,
      );
      final Duration releaseDuration = Duration(
        milliseconds:
            (animationDuration.inMilliseconds * releaseDurationNumerator) ~/
                releaseDurationDenominator,
      );
      tappable = AxiTapBounce(
        controller: _bounceController,
        enabled: animationDuration != Duration.zero,
        scale: widget.resolvedButtonSize < compactSizeThreshold
            ? compactBounceScale
            : defaultBounceScale,
        pressDuration: pressDuration,
        releaseDuration: releaseDuration,
        child: tappable,
      );
    }

    if (widget.tooltip != null) {
      tappable = AxiTooltip(
        builder: (context) =>
            Text(widget.tooltip!, style: context.textTheme.muted),
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
      label: widget.semanticLabel ?? widget.tooltip,
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: withCursor,
    );
  }
}
