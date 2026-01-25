// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _defaultBounceScale = 0.98;
const double _splashAlpha = 0.18;
const int _pressDurationNumerator = 4;
const int _pressDurationDenominator = 15;
const int _releaseDurationNumerator = 3;
const int _releaseDurationDenominator = 5;

enum AxiButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  link,
  destructive;

  ShadButtonTheme themeFor(ShadThemeData theme) {
    return switch (this) {
      AxiButtonVariant.primary => theme.primaryButtonTheme,
      AxiButtonVariant.secondary => theme.secondaryButtonTheme,
      AxiButtonVariant.outline => theme.outlineButtonTheme,
      AxiButtonVariant.ghost => theme.ghostButtonTheme,
      AxiButtonVariant.link => theme.linkButtonTheme,
      AxiButtonVariant.destructive => theme.destructiveButtonTheme,
    };
  }

  Color fallbackBackground(ShadColorScheme colors) {
    return switch (this) {
      AxiButtonVariant.primary => colors.primary,
      AxiButtonVariant.secondary => colors.secondary,
      AxiButtonVariant.outline => colors.card,
      AxiButtonVariant.ghost => Colors.transparent,
      AxiButtonVariant.link => Colors.transparent,
      AxiButtonVariant.destructive => colors.destructive,
    };
  }

  Color fallbackForeground(ShadColorScheme colors) {
    return switch (this) {
      AxiButtonVariant.primary => colors.primaryForeground,
      AxiButtonVariant.secondary => colors.secondaryForeground,
      AxiButtonVariant.outline => colors.foreground,
      AxiButtonVariant.ghost => colors.foreground,
      AxiButtonVariant.link => colors.primary,
      AxiButtonVariant.destructive => colors.destructiveForeground,
    };
  }

  Color backgroundColor({
    required ShadButtonTheme theme,
    required ShadColorScheme colors,
    required bool hovered,
    required bool pressed,
  }) {
    if (pressed) {
      return theme.pressedBackgroundColor ??
          theme.hoverBackgroundColor ??
          theme.backgroundColor ??
          fallbackBackground(colors);
    }
    if (hovered) {
      return theme.hoverBackgroundColor ??
          theme.backgroundColor ??
          fallbackBackground(colors);
    }
    return theme.backgroundColor ?? fallbackBackground(colors);
  }

  Color foregroundColor({
    required ShadButtonTheme theme,
    required ShadColorScheme colors,
    required bool hovered,
    required bool pressed,
  }) {
    if (pressed) {
      return theme.pressedForegroundColor ??
          theme.hoverForegroundColor ??
          theme.foregroundColor ??
          fallbackForeground(colors);
    }
    if (hovered) {
      return theme.hoverForegroundColor ??
          theme.foregroundColor ??
          fallbackForeground(colors);
    }
    return theme.foregroundColor ?? fallbackForeground(colors);
  }

  Color borderColor(ShadColorScheme colors) {
    if (this != AxiButtonVariant.outline) {
      return Colors.transparent;
    }
    return colors.border;
  }

  TextDecoration? textDecoration() {
    if (this == AxiButtonVariant.link) {
      return TextDecoration.underline;
    }
    return null;
  }
}

enum AxiButtonSize {
  sm,
  regular,
  lg;

  EdgeInsets padding(AxiSpacing spacing) {
    return switch (this) {
      AxiButtonSize.sm => EdgeInsets.symmetric(
          horizontal: spacing.s,
          vertical: spacing.xs,
        ),
      AxiButtonSize.regular => EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.s,
        ),
      AxiButtonSize.lg => EdgeInsets.symmetric(
          horizontal: spacing.l,
          vertical: spacing.m,
        ),
    };
  }

  double minHeight(AxiSpacing spacing) {
    return switch (this) {
      AxiButtonSize.sm => spacing.l,
      AxiButtonSize.regular => spacing.l,
      AxiButtonSize.lg => spacing.xl,
    };
  }

  double gap(AxiSpacing spacing) {
    return switch (this) {
      AxiButtonSize.sm => spacing.xs,
      AxiButtonSize.regular => spacing.s,
      AxiButtonSize.lg => spacing.m,
    };
  }
}

class AxiButton extends StatefulWidget {
  const AxiButton({
    super.key,
    required this.variant,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.loadingIndicator,
    this.semanticLabel,
  });

  const AxiButton.primary({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.loadingIndicator,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.primary;

  const AxiButton.secondary({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.loadingIndicator,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.secondary;

  const AxiButton.outline({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.loadingIndicator,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.outline;

  const AxiButton.ghost({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.loadingIndicator,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.ghost;

  const AxiButton.link({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.loadingIndicator,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.link;

  const AxiButton.destructive({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.loadingIndicator,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.destructive;

  final AxiButtonVariant variant;
  final AxiButtonSize size;
  final Widget? child;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool loading;
  final Widget? loadingIndicator;
  final String? semanticLabel;

  @override
  State<AxiButton> createState() => _AxiButtonState();
}

class _AxiButtonState extends State<AxiButton> {
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
        final theme = ShadTheme.of(context);
        final colors = context.colorScheme;
        final textTheme = context.textTheme;
        final spacing = context.spacing;
        final env = EnvScope.maybeOf(context);
        final isDesktop = env?.isDesktopPlatform ?? false;
        final bool enabled =
            widget.onPressed != null || widget.onLongPress != null;
        final bool hovered = states.contains(WidgetState.hovered);
        final bool pressed = states.contains(WidgetState.pressed);
        final ShadButtonTheme buttonTheme = widget.variant.themeFor(theme);
        final Color background = widget.variant.backgroundColor(
          theme: buttonTheme,
          colors: colors,
          hovered: hovered,
          pressed: pressed,
        );
        final Color foreground = widget.variant.foregroundColor(
          theme: buttonTheme,
          colors: colors,
          hovered: hovered,
          pressed: pressed,
        );
        final Color borderColor = widget.variant.borderColor(colors);
        final shape = SquircleBorder(
          cornerRadius: axiSquircleRadius,
          side: BorderSide(
            color: borderColor,
            width: widget.variant == AxiButtonVariant.outline ? spacing.xxs : 0,
          ),
        );
        final textStyle = textTheme.small.copyWith(
          color: foreground,
          decoration: widget.variant.textDecoration(),
          decorationColor: foreground,
        );

        final Widget loadingSpinner = widget.loadingIndicator ??
            AxiProgressIndicator(
              dimension: spacing.s,
              color: foreground,
            );
        final bool replacesLeading = widget.leading != null && widget.loading;
        final Widget? leading =
            replacesLeading ? loadingSpinner : widget.leading;

        final List<Widget> rowChildren = <Widget>[
          if (widget.leading == null)
            ButtonSpinnerSlot(
              isVisible: widget.loading,
              spinner: loadingSpinner,
              slotSize: spacing.s,
              gap: widget.size.gap(spacing),
              duration: animationDuration,
            ),
          if (leading != null) leading,
          if (leading != null && widget.child != null)
            SizedBox(width: widget.size.gap(spacing)),
          if (widget.child != null) widget.child!,
          if (widget.trailing != null && widget.child != null)
            SizedBox(width: widget.size.gap(spacing)),
          if (widget.trailing != null) widget.trailing!,
        ];

        Widget content = ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: widget.size.minHeight(spacing)),
          child: Padding(
            padding: widget.size.padding(spacing),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: rowChildren,
            ),
          ),
        );

        content = IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: DefaultTextStyle(
            style: textStyle,
            textAlign: TextAlign.center,
            child: content,
          ),
        );

        Widget button = Material(
          color: background,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkResponse(
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
                isDesktop ? NoSplash.splashFactory : InkRipple.splashFactory,
            splashColor: enabled
                ? colors.primary.withValues(alpha: _splashAlpha)
                : Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: content,
          ),
        );

        if (enabled) {
          final Duration pressDuration = Duration(
            milliseconds:
                (animationDuration.inMilliseconds * _pressDurationNumerator) ~/
                    _pressDurationDenominator,
          );
          final Duration releaseDuration = Duration(
            milliseconds: (animationDuration.inMilliseconds *
                    _releaseDurationNumerator) ~/
                _releaseDurationDenominator,
          );
          button = AxiTapBounce(
            controller: _bounceController,
            enabled: animationDuration != Duration.zero,
            scale: _defaultBounceScale,
            pressDuration: pressDuration,
            releaseDuration: releaseDuration,
            child: button,
          );
        }

        button = Opacity(
          opacity: enabled ? 1 : theme.disabledOpacity,
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
