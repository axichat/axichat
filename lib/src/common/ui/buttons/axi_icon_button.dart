// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/ui/buttons/axi_button_haptics.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AxiIconButtonVariant { primary, secondary, outline, ghost, destructive }

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
    this.hoverColor,
    this.pressedColor,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.borderColor,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.borderWidth,
    this.loading = false,
    this.selected = false,
  }) : variant = AxiIconButtonVariant.primary,
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
    this.hoverColor,
    this.pressedColor,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.borderColor,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.borderWidth,
    this.loading = false,
    this.selected = false,
  }) : resolvedIconSize = iconSize,
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
    this.hoverColor,
    this.pressedColor,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.borderColor,
    this.loading = false,
    this.selected = false,
  }) : variant = AxiIconButtonVariant.ghost,
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
    this.hoverColor,
    this.pressedColor,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.loading = false,
    this.selected = false,
  }) : variant = AxiIconButtonVariant.outline,
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
    this.hoverColor,
    this.pressedColor,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.borderWidth,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.borderColor,
    this.loading = false,
    this.selected = false,
  }) : variant = AxiIconButtonVariant.secondary,
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
    this.hoverColor,
    this.pressedColor,
    this.iconSize,
    this.buttonSize,
    this.tapTargetSize,
    this.cornerRadius,
    this.borderWidth,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.borderColor,
    this.loading = false,
    this.selected = false,
  }) : variant = AxiIconButtonVariant.destructive,
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
  final Color? hoverColor;
  final Color? pressedColor;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color? pressedBackgroundColor;
  final Color? borderColor;
  final double? iconSize;
  final double? buttonSize;
  final double? tapTargetSize;
  final double? cornerRadius;
  final double? borderWidth;
  final bool loading;
  final bool selected;
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
        final Color fallbackForeground = widget.selected
            ? context.colorScheme.primary
            : switch (widget.variant) {
                AxiIconButtonVariant.destructive =>
                  context.colorScheme.destructive,
                _ => context.colorScheme.foreground,
              };
        final Color baseForeground = widget.color ?? fallbackForeground;
        final Color baseBorder =
            widget.borderColor ??
            (widget.variant == AxiIconButtonVariant.ghost
                ? Colors.transparent
                : context.borderSide.color);
        final Color baseBackground =
            widget.backgroundColor ??
            switch (widget.variant) {
              AxiIconButtonVariant.outline => Colors.transparent,
              AxiIconButtonVariant.ghost => context.colorScheme.secondary,
              _ => context.colorScheme.card,
            };
        final bool isSelected = widget.selected;
        final Color selectedTint = context.colorScheme.primary.withValues(
          alpha: context.motion.tapHoverAlpha,
        );
        final Color resolvedBorder = (isSelected && widget.borderColor == null)
            ? (widget.variant == AxiIconButtonVariant.ghost
                  ? Colors.transparent
                  : context.colorScheme.primary)
            : baseBorder;
        final Color resolvedBackground =
            (isSelected && widget.backgroundColor == null)
            ? Color.alphaBlend(selectedTint, baseBackground)
            : baseBackground;
        final bool enabled =
            (widget.onPressed != null || widget.onLongPress != null) &&
            !widget.loading;
        final VoidCallback? onTap = enabled
            ? withSelectionHaptic(widget.onPressed)
            : null;
        final VoidCallback? handleLongPress = enabled
            ? withSelectionHaptic(widget.onLongPress)
            : null;
        final VoidCallback? onLongPress = handleLongPress == null
            ? null
            : () {
                _updateState(WidgetState.pressed, false);
                _bounceController.setPressed(false);
                handleLongPress();
              };
        final bool hovered = states.contains(WidgetState.hovered);
        final bool focused = states.contains(WidgetState.focused);
        final bool pressed = states.contains(WidgetState.pressed);
        final bool emphasized = hovered || focused;
        final double resolvedIconSize =
            widget.resolvedIconSize ?? context.sizing.iconButtonIconSize;
        final double resolvedButtonSize =
            widget.resolvedButtonSize ?? context.sizing.iconButtonSize;
        final double resolvedTapTargetSize =
            widget.resolvedTapTargetSize ?? context.sizing.iconButtonTapTarget;
        final double resolvedBorderWidth =
            widget.resolvedBorderWidth ??
            (widget.variant == AxiIconButtonVariant.outline
                ? context.borderSide.width
                : 0);
        final double iconSize = resolvedIconSize;
        final double buttonSize = resolvedButtonSize;
        final double tapTargetSize = resolvedTapTargetSize;
        final paintShape = SquircleBorder(
          borderRadius: widget.resolvedCornerRadius == null
              ? BorderRadius.circular(context.radii.squircle)
              : BorderRadius.circular(widget.resolvedCornerRadius!),
          side: BorderSide(color: resolvedBorder, width: resolvedBorderWidth),
        );
        final Color resolvedForeground = pressed
            ? (widget.pressedColor ?? widget.hoverColor ?? baseForeground)
            : (emphasized
                  ? (widget.hoverColor ?? baseForeground)
                  : baseForeground);
        final Widget iconWidget = widget.loading
            ? AxiProgressIndicator(color: resolvedForeground)
            : (widget.icon == null
                  ? Icon(
                      widget.iconData,
                      size: iconSize,
                      color: resolvedForeground,
                    )
                  : IconTheme.merge(
                      data: IconThemeData(size: iconSize),
                      child: widget.icon!,
                    ));
        Color background = emphasized && widget.hoverBackgroundColor != null
            ? widget.hoverBackgroundColor!
            : resolvedBackground;
        if (pressed) {
          background =
              widget.pressedBackgroundColor ??
              Color.alphaBlend(
                context.colorScheme.primary.withValues(
                  alpha: context.motion.tapSplashAlpha,
                ),
                background,
              );
        }

        Widget tappable = SizedBox(
          width: tapTargetSize,
          height: tapTargetSize,
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
                  cursor: enabled
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  behavior: HitTestBehavior.opaque,
                  hoverStrategies: ShadTheme.of(context).hoverStrategies,
                  onHoverChange: enabled
                      ? (value) => _updateState(WidgetState.hovered, value)
                      : null,
                  onTap: onTap,
                  onLongPress: onLongPress,
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
                    width: buttonSize,
                    height: buttonSize,
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
            milliseconds:
                (animationDuration.inMilliseconds *
                        context.motion.iconButtonPressDurationFactor)
                    .round(),
          );
          final Duration releaseDuration = Duration(
            milliseconds:
                (animationDuration.inMilliseconds *
                        context.motion.iconButtonReleaseDurationFactor)
                    .round(),
          );
          tappable = AxiTapBounce(
            controller: _bounceController,
            enabled: animationDuration != Duration.zero,
            scale: buttonSize < compactSizeThreshold
                ? context.motion.iconButtonCompactBounceScale
                : context.motion.iconButtonBounceScale,
            hoverScale: context.motion.iconButtonHoverScale,
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
          selected: widget.selected,
          label: widget.semanticLabel ?? widget.tooltip,
          onTap: onTap,
          onLongPress: onLongPress,
          child: tappable,
        );
      },
    );
  }
}
