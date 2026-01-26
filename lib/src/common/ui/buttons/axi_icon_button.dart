// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
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
  static const double kDefaultSize = 40;
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
  final ValueNotifier<Set<WidgetState>> _states =
      ValueNotifier<Set<WidgetState>>(<WidgetState>{});

  void _updateState(WidgetState state, bool enabled) {
    final next = Set<WidgetState>.from(_states.value);
    if (enabled) {
      next.add(state);
    } else {
      next.remove(state);
    }
    _states.value = next;
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      builder: (context, states, _) {
        final Color fallbackForeground = widget.usePrimary
            ? context.colorScheme.primary
            : switch (widget.variant) {
                AxiIconButtonVariant.destructive =>
                  context.colorScheme.destructive,
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
        final bool enabled =
            widget.onPressed != null || widget.onLongPress != null;
        final bool hovered = states.contains(WidgetState.hovered);
        final bool pressed = states.contains(WidgetState.pressed);
        final bool focused = states.contains(WidgetState.focused);
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
        Color background = resolvedBackground;
        if (pressed) {
          background = Color.alphaBlend(
            context.colorScheme.primary
                .withValues(alpha: context.motion.tapSplashAlpha),
            background,
          );
        } else if (hovered || focused) {
          background = Color.alphaBlend(
            context.colorScheme.primary
                .withValues(alpha: context.motion.tapHoverAlpha),
            background,
          );
        }

        Widget tappable = SizedBox(
          width: resolvedTapTargetSize,
          height: resolvedTapTargetSize,
          child: Center(
            child: Material(
              color: background,
              shape: paintShape,
              clipBehavior: Clip.antiAlias,
              child: ShadFocusable(
                canRequestFocus: enabled,
                onFocusChange: enabled
                    ? (value) => _updateState(WidgetState.focused, value)
                    : null,
                builder: (context, focused, child) =>
                    child ?? const SizedBox.shrink(),
                child: ShadGestureDetector(
                  cursor:
                      enabled ? SystemMouseCursors.click : MouseCursor.defer,
                  hoverStrategies: ShadTheme.of(context).hoverStrategies,
                  onHoverChange: enabled
                      ? (value) {
                          _updateState(WidgetState.hovered, value);
                          _bounceController.setHovered(value);
                        }
                      : null,
                  onTap: enabled ? widget.onPressed : null,
                  onLongPress: enabled ? widget.onLongPress : null,
                  onTapDown: enabled
                      ? (details) {
                          _updateState(WidgetState.pressed, true);
                          _bounceController.handleTapDown(details);
                        }
                      : null,
                  onTapUp: enabled
                      ? (details) {
                          _updateState(WidgetState.pressed, false);
                          _bounceController.handleTapUp(details);
                        }
                      : null,
                  onTapCancel: enabled
                      ? () {
                          _updateState(WidgetState.pressed, false);
                          _bounceController.handleTapCancel();
                        }
                      : null,
                  onLongPressStart: enabled
                      ? (_) {
                          _updateState(WidgetState.pressed, true);
                          _bounceController.setPressed(true);
                        }
                      : null,
                  onLongPressEnd: enabled
                      ? (_) {
                          _updateState(WidgetState.pressed, false);
                          _bounceController.setPressed(false);
                        }
                      : null,
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

        return Semantics(
          button: true,
          enabled: enabled,
          label: widget.semanticLabel ?? widget.tooltip,
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          child: tappable,
        );
      },
    );
  }
}
