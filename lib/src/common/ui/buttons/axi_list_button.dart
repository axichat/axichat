// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiListButton extends StatefulWidget {
  const AxiListButton({
    super.key,
    required this.child,
    this.variant = AxiButtonVariant.ghost,
    this.leading,
    this.trailing,
    this.collapsed = false,
    this.collapsedIconData,
    this.collapsedIcon,
    this.collapsedTooltip,
    this.collapsedSemanticLabel,
    this.collapsedForegroundColor,
    this.collapsedBackgroundColor,
    this.collapsedButtonSize,
    this.collapsedTapTargetSize,
    this.collapsedCornerRadius,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.selected = false,
    this.semanticLabel,
    this.focusNode,
    this.foregroundColor,
    this.backgroundColor,
  }) : assert(
          !collapsed || collapsedIconData != null || collapsedIcon != null,
          'Collapsed list buttons require an icon.',
        );

  const AxiListButton.destructive({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
    this.collapsed = false,
    this.collapsedIconData,
    this.collapsedIcon,
    this.collapsedTooltip,
    this.collapsedSemanticLabel,
    this.collapsedForegroundColor,
    this.collapsedBackgroundColor,
    this.collapsedButtonSize,
    this.collapsedTapTargetSize,
    this.collapsedCornerRadius,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.selected = false,
    this.semanticLabel,
    this.focusNode,
    this.foregroundColor,
    this.backgroundColor,
  })  : variant = AxiButtonVariant.destructive,
        assert(
          !collapsed || collapsedIconData != null || collapsedIcon != null,
          'Collapsed list buttons require an icon.',
        );

  final Widget child;
  final AxiButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool collapsed;
  final IconData? collapsedIconData;
  final Widget? collapsedIcon;
  final String? collapsedTooltip;
  final String? collapsedSemanticLabel;
  final Color? collapsedForegroundColor;
  final Color? collapsedBackgroundColor;
  final double? collapsedButtonSize;
  final double? collapsedTapTargetSize;
  final double? collapsedCornerRadius;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool loading;
  final bool selected;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  State<AxiListButton> createState() => _AxiListButtonState();
}

class _AxiListButtonState extends State<AxiListButton> {
  final AxiTapBounceController _bounceController = AxiTapBounceController();
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
    final IconData collapsedIconData = widget.collapsedIconData!;
    final collapsedButton = AxiIconButton.ghost(
      iconData: collapsedIconData,
      icon: widget.collapsedIcon,
      tooltip: widget.collapsedTooltip ?? widget.semanticLabel,
      semanticLabel: widget.collapsedSemanticLabel ?? widget.semanticLabel,
      onPressed: widget.onPressed,
      onLongPress: widget.onLongPress,
      color: widget.collapsedForegroundColor,
      backgroundColor: widget.collapsedBackgroundColor,
      buttonSize: widget.collapsedButtonSize,
      tapTargetSize: widget.collapsedTapTargetSize,
      cornerRadius: widget.collapsedCornerRadius,
    );
    final expandedButton = ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      builder: (context, states, _) {
        final bool enabled =
            widget.onPressed != null || widget.onLongPress != null;
        final bool hovered = states.contains(WidgetState.hovered);
        final bool pressed = states.contains(WidgetState.pressed);
        final bool focused = states.contains(WidgetState.focused);
        final bool hoverOrFocus = hovered || focused || widget.selected;
        final ShadButtonTheme buttonTheme =
            widget.variant.themeFor(ShadTheme.of(context));
        final Color background = widget.backgroundColor ??
            widget.variant.backgroundColor(
              theme: buttonTheme,
              colors: context.colorScheme,
              hovered: hoverOrFocus,
              pressed: pressed,
            );
        final Color foreground = widget.foregroundColor ??
            widget.variant.foregroundColor(
              theme: buttonTheme,
              colors: context.colorScheme,
              hovered: hoverOrFocus,
              pressed: pressed,
            );
        final shape = RoundedSuperellipseBorder(
          borderRadius: context.radius,
          side: BorderSide(
            color: widget.variant == AxiButtonVariant.outline
                ? context.borderSide.color
                : Colors.transparent,
            width: widget.variant == AxiButtonVariant.outline
                ? context.borderSide.width
                : 0,
          ),
        );
        final textStyle = context.textTheme.small.copyWith(
          color: foreground,
          decoration: widget.variant.textDecoration(),
          decorationColor: foreground,
        );
        final bool replacesLeading = widget.leading != null && widget.loading;

        Widget content = ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: context.sizing.listButtonHeight,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.leading == null)
                  ButtonSpinnerSlot(
                    isVisible: widget.loading,
                    spinner: AxiProgressIndicator(color: foreground),
                    slotSize: context.sizing.progressIndicatorSize,
                    gap: context.spacing.s,
                    duration: animationDuration,
                  ),
                if (widget.leading != null)
                  replacesLeading
                      ? AxiProgressIndicator(color: foreground)
                      : widget.leading!,
                if (widget.leading != null) SizedBox(width: context.spacing.s),
                Expanded(child: widget.child),
                if (widget.trailing != null)
                  Padding(
                    padding: EdgeInsets.only(left: context.spacing.s),
                    child: widget.trailing,
                  ),
              ],
            ),
          ),
        );

        content = IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: DefaultTextStyle(
            style: textStyle,
            textAlign: TextAlign.start,
            child: content,
          ),
        );

        Widget button = Material(
          color: background,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: ShadFocusable(
            focusNode: widget.focusNode,
            canRequestFocus: enabled,
            onFocusChange: enabled
                ? (value) => _updateState(WidgetState.focused, value)
                : null,
            builder: (context, focused, child) =>
                child ?? const SizedBox.shrink(),
            child: ShadGestureDetector(
              cursor: enabled
                  ? (buttonTheme.cursor ?? SystemMouseCursors.click)
                  : MouseCursor.defer,
              hoverStrategies: buttonTheme.hoverStrategies ??
                  ShadTheme.of(context).hoverStrategies,
              longPressDuration: buttonTheme.longPressDuration,
              onHoverChange: enabled
                  ? (value) => _updateState(WidgetState.hovered, value)
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
              child: content,
            ),
          ),
        );

        if (enabled) {
          button = AxiTapBounce(
            controller: _bounceController,
            enabled: animationDuration != Duration.zero,
            scale: context.motion.buttonBounceScale,
            pressDuration: Duration(
              milliseconds: (animationDuration.inMilliseconds *
                      context.motion.buttonPressDurationFactor)
                  .round(),
            ),
            releaseDuration: Duration(
              milliseconds: (animationDuration.inMilliseconds *
                      context.motion.buttonReleaseDurationFactor)
                  .round(),
            ),
            child: button,
          );
        }

        button = Opacity(
          opacity: enabled ? 1 : ShadTheme.of(context).disabledOpacity,
          child: button,
        );

        return Semantics(
          button: true,
          enabled: enabled,
          selected: widget.selected,
          label: widget.semanticLabel,
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          child: button,
        );
      },
    );
    const collapsedKey = ValueKey('axi_list_button_collapsed');
    const expandedKey = ValueKey('axi_list_button_expanded');
    const axisAlignment = 1.0;
    return AnimatedSwitcher(
      duration: animationDuration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, _) =>
          currentChild ?? const SizedBox.shrink(),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axis: Axis.horizontal,
        axisAlignment: axisAlignment,
        child: child,
      ),
      child: widget.collapsed
          ? SizedBox(key: collapsedKey, child: collapsedButton)
          : SizedBox(key: expandedKey, child: expandedButton),
    );
  }
}
