// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AxiIconButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive;
}

class AxiIconButton extends StatefulWidget {
  static const double kDefaultSize = 32;
  static const double kTapTargetSize = 48;

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
        resolvedIconSize = iconSize,
        resolvedButtonSize = buttonSize,
        resolvedTapTargetSize = tapTargetSize,
        resolvedCornerRadius = cornerRadius,
        resolvedBorderWidth = borderWidth;

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
  })  : resolvedIconSize = iconSize,
        resolvedButtonSize = buttonSize,
        resolvedTapTargetSize = tapTargetSize,
        resolvedCornerRadius = cornerRadius,
        resolvedBorderWidth = borderWidth;

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
        resolvedIconSize = iconSize,
        resolvedButtonSize = buttonSize,
        resolvedTapTargetSize = tapTargetSize,
        resolvedCornerRadius = cornerRadius,
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
        resolvedIconSize = iconSize,
        resolvedButtonSize = buttonSize,
        resolvedTapTargetSize = tapTargetSize,
        resolvedCornerRadius = cornerRadius,
        resolvedBorderWidth = null;

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
        resolvedIconSize = iconSize,
        resolvedButtonSize = buttonSize,
        resolvedTapTargetSize = tapTargetSize,
        resolvedCornerRadius = cornerRadius,
        resolvedBorderWidth = borderWidth;

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
        resolvedIconSize = iconSize,
        resolvedButtonSize = buttonSize,
        resolvedTapTargetSize = tapTargetSize,
        resolvedCornerRadius = cornerRadius,
        resolvedBorderWidth = borderWidth;

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
  final double? resolvedIconSize;
  final double? resolvedButtonSize;
  final double? resolvedTapTargetSize;
  final double? resolvedCornerRadius;
  final double? resolvedBorderWidth;

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
    final env = EnvScope.maybeOf(context);
    final isDesktop = env?.isDesktopPlatform ?? false;
    final Color fallbackForeground = widget.usePrimary
        ? context.colorScheme.primary
        : switch (widget.variant) {
            AxiIconButtonVariant.destructive => context.colorScheme.destructive,
            _ => context.colorScheme.foreground,
          };
    final Color resolvedForeground = widget.color ?? fallbackForeground;
    final Color resolvedBorder = widget.borderColor ??
        (widget.variant == AxiIconButtonVariant.ghost
            ? Colors.transparent
            : ShadTheme.of(context).decoration.border?.top?.color ??
                context.colorScheme.border);
    final Color resolvedBackground = widget.backgroundColor ??
        switch (widget.variant) {
          AxiIconButtonVariant.outline => Colors.transparent,
          AxiIconButtonVariant.ghost => context.colorScheme.secondary,
          _ => context.colorScheme.card,
        };
    final bool enabled = widget.onPressed != null || widget.onLongPress != null;
    final double resolvedIconSize =
        widget.resolvedIconSize ?? context.sizing.iconButtonIconSize;
    final double resolvedButtonSize =
        widget.resolvedButtonSize ?? context.sizing.iconButtonSize;
    final double resolvedTapTargetSize =
        widget.resolvedTapTargetSize ?? context.sizing.iconButtonTapTarget;
    final double resolvedBorderWidth = widget.resolvedBorderWidth ??
        (widget.variant == AxiIconButtonVariant.outline
            ? (ShadTheme.of(context).decoration.border?.top?.width ?? 0)
            : 0);
    final paintShape = RoundedSuperellipseBorder(
      borderRadius: widget.resolvedCornerRadius == null
          ? context.radius
          : BorderRadius.circular(widget.resolvedCornerRadius!),
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
              onHighlightChanged: enabled ? _bounceController.setPressed : null,
              onTapCancel: enabled ? _bounceController.handleTapCancel : null,
              containedInkWell: true,
              highlightShape: BoxShape.rectangle,
              customBorder: paintShape,
              splashFactory:
                  isDesktop ? NoSplash.splashFactory : InkRipple.splashFactory,
              splashColor: !enabled || isDesktop
                  ? Colors.transparent
                  : context.colorScheme.primary
                      .withValues(alpha: context.motion.tapSplashAlpha),
              hoverColor: enabled
                  ? context.colorScheme.primary
                      .withValues(alpha: context.motion.tapHoverAlpha)
                  : Colors.transparent,
              highlightColor: Colors.transparent,
              focusColor: enabled
                  ? context.colorScheme.primary
                      .withValues(alpha: context.motion.tapFocusAlpha)
                  : Colors.transparent,
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
      final double compactSizeThreshold = context.sizing.iconButtonSize;
      final Duration pressDuration = Duration(
        milliseconds: (animationDuration.inMilliseconds *
                context.motion.iconButtonPressDurationFactor)
            .round(),
      );
      final Duration releaseDuration = Duration(
        milliseconds: (animationDuration.inMilliseconds *
                context.motion.iconButtonReleaseDurationFactor)
            .round(),
      );
      tappable = AxiTapBounce(
        controller: _bounceController,
        enabled: animationDuration != Duration.zero,
        scale: resolvedButtonSize < compactSizeThreshold
            ? context.motion.iconButtonCompactBounceScale
            : context.motion.iconButtonBounceScale,
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
