// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
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
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.semanticLabel,
    this.focusNode,
    this.foregroundColor,
    this.backgroundColor,
  });

  const AxiListButton.destructive({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.semanticLabel,
    this.focusNode,
    this.foregroundColor,
    this.backgroundColor,
  }) : variant = AxiButtonVariant.destructive;

  final Widget child;
  final AxiButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool loading;
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
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      builder: (context, states, _) {
        final bool enabled =
            widget.onPressed != null || widget.onLongPress != null;
        final bool hovered = states.contains(WidgetState.hovered);
        final bool pressed = states.contains(WidgetState.pressed);
        final ShadButtonTheme buttonTheme =
            widget.variant.themeFor(ShadTheme.of(context));
        final Color background = widget.backgroundColor ??
            widget.variant.backgroundColor(
              theme: buttonTheme,
              colors: context.colorScheme,
              hovered: hovered,
              pressed: pressed,
            );
        final Color foreground = widget.foregroundColor ??
            widget.variant.foregroundColor(
              theme: buttonTheme,
              colors: context.colorScheme,
              hovered: hovered,
              pressed: pressed,
            );
        final Color borderColor =
            widget.variant.borderColor(context.colorScheme);
        final shape = RoundedSuperellipseBorder(
          borderRadius: context.radius,
          side: BorderSide(
            color: widget.variant == AxiButtonVariant.outline
                ? (ShadTheme.of(context).decoration.border?.top?.color ??
                    borderColor)
                : Colors.transparent,
            width: widget.variant == AxiButtonVariant.outline
                ? (ShadTheme.of(context).decoration.border?.top?.width ?? 0)
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
          child: InkResponse(
            focusNode: widget.focusNode,
            canRequestFocus: enabled,
            onTap: widget.onPressed,
            onLongPress: widget.onLongPress,
            onHighlightChanged: enabled
                ? (value) {
                    _updateState(WidgetState.pressed, value);
                    _bounceController.setPressed(value);
                  }
                : null,
            onHover: enabled
                ? (value) => _updateState(WidgetState.hovered, value)
                : null,
            onTapCancel: enabled
                ? () {
                    _updateState(WidgetState.pressed, false);
                    _bounceController.setPressed(false);
                  }
                : null,
            containedInkWell: true,
            highlightShape: BoxShape.rectangle,
            customBorder: shape,
            splashFactory:
                (EnvScope.maybeOf(context)?.isDesktopPlatform ?? false)
                    ? NoSplash.splashFactory
                    : InkRipple.splashFactory,
            splashColor: enabled
                ? context.colorScheme.primary
                    .withValues(alpha: context.motion.tapSplashAlpha)
                : Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: enabled
                ? context.colorScheme.primary
                    .withValues(alpha: context.motion.tapFocusAlpha)
                : Colors.transparent,
            child: content,
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
          label: widget.semanticLabel,
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          child: MouseRegion(
            cursor:
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: button,
          ),
        );
      },
    );
  }
}
