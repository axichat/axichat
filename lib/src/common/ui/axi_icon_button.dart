// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _defaultIconScale = 0.6;

class AxiIconButton extends StatefulWidget {
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
    this.outline = false,
  }) : resolvedIconSize =
            iconSize ?? AxiIconButton.kDefaultSize * _defaultIconScale;

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
  })  : resolvedIconSize =
            iconSize ?? AxiIconButton.kDefaultSize * _defaultIconScale,
        borderWidth = null,
        ghost = true,
        outline = false;

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
  })  : resolvedIconSize =
            iconSize ?? AxiIconButton.kDefaultSize * _defaultIconScale,
        backgroundColor = null,
        borderColor = null,
        borderWidth = null,
        ghost = false,
        outline = true;

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
  final double resolvedIconSize;
  final double? buttonSize;
  final double? tapTargetSize;
  final double? cornerRadius;
  final double? borderWidth;
  final bool usePrimary;
  final bool ghost;
  final bool outline;

  @override
  State<AxiIconButton> createState() => _AxiIconButtonState();
}

class _AxiIconButtonState extends State<AxiIconButton> {
  @override
  Widget build(BuildContext context) {
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final colors = context.colorScheme;
    final env = EnvScope.maybeOf(context);
    final isDesktop = env?.isDesktopPlatform ?? false;
    final bool isGhost = widget.ghost;
    final bool isOutline = widget.outline;
    final Color resolvedForeground = widget.color ??
        (widget.usePrimary ? colors.primary : colors.foreground);
    final Color resolvedBorder = widget.borderColor ??
        (isOutline
            ? colors.border
            : (isGhost ? Colors.transparent : colors.border));
    final Color resolvedBackground = widget.backgroundColor ??
        (isOutline
            ? Colors.transparent
            : (isGhost ? colors.secondary : colors.card));
    final bool enabled = widget.onPressed != null || widget.onLongPress != null;
    final double resolvedIconSize = widget.resolvedIconSize;
    final double resolvedButtonSize =
        widget.buttonSize ?? AxiIconButton.kDefaultSize;
    final double resolvedTapTargetSize =
        widget.tapTargetSize ?? AxiIconButton.kTapTargetSize;
    final double resolvedCornerRadius = widget.cornerRadius ?? 18;
    final double resolvedBorderWidth =
        widget.borderWidth ?? (isOutline ? 1.0 : (isGhost ? 0 : 1.0));
    final paintShape = SquircleBorder(
      cornerRadius: resolvedCornerRadius,
      side: BorderSide(color: resolvedBorder, width: resolvedBorderWidth),
    );
    final Widget baseIcon = widget.icon ??
        Icon(
          widget.iconData,
          size: resolvedIconSize,
          color: resolvedForeground,
        );
    final Widget iconWidget = widget.icon == null
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
              onTap: widget.onPressed,
              onLongPress: widget.onLongPress,
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
        enabled: animationDuration != Duration.zero,
        scale: resolvedButtonSize < compactSizeThreshold
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
