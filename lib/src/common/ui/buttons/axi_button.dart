// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/buttons/axi_hover_band.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

  double minHeight(AxiSizing sizing) {
    return switch (this) {
      AxiButtonSize.sm => sizing.buttonHeightSm,
      AxiButtonSize.regular => sizing.buttonHeightRegular,
      AxiButtonSize.lg => sizing.buttonHeightLg,
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

enum AxiButtonWidth {
  fit,
  expand;
}

class AxiButton extends StatefulWidget {
  const AxiButton({
    super.key,
    required this.variant,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.widthBehavior = AxiButtonWidth.fit,
    this.width,
    this.semanticLabel,
  });

  const AxiButton.primary({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.widthBehavior = AxiButtonWidth.fit,
    this.width,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.primary;

  const AxiButton.secondary({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.widthBehavior = AxiButtonWidth.fit,
    this.width,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.secondary;

  const AxiButton.outline({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.widthBehavior = AxiButtonWidth.fit,
    this.width,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.outline;

  const AxiButton.ghost({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.widthBehavior = AxiButtonWidth.fit,
    this.width,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.ghost;

  const AxiButton.link({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.widthBehavior = AxiButtonWidth.fit,
    this.width,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.link;

  const AxiButton.destructive({
    super.key,
    this.size = AxiButtonSize.regular,
    this.child,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.widthBehavior = AxiButtonWidth.fit,
    this.width,
    this.semanticLabel,
  }) : variant = AxiButtonVariant.destructive;

  final AxiButtonVariant variant;
  final AxiButtonSize size;
  final Widget? child;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool loading;
  final AxiButtonWidth widthBehavior;
  final double? width;
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
        final bool enabled =
            widget.onPressed != null || widget.onLongPress != null;
        final bool hovered = states.contains(WidgetState.hovered);
        final bool pressed = states.contains(WidgetState.pressed);
        final bool focused = states.contains(WidgetState.focused);
        final bool hoverOrFocus = hovered || focused || widget.selected;
        final ShadButtonTheme buttonTheme =
            widget.variant.themeFor(ShadTheme.of(context));
        final Color background = widget.variant.backgroundColor(
          theme: buttonTheme,
          colors: context.colorScheme,
          hovered: hoverOrFocus,
          pressed: pressed,
        );
        final Color foreground = widget.variant.foregroundColor(
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
        final double hoverBandHeightFactor =
            context.motion.hoverBandHeightFactor;
        final double hoverBandIntensity = context.motion.hoverBandIntensity;
        const double minAlpha = 0.0;
        const double maxAlpha = 1.0;
        final double hoverAlpha =
            (context.motion.tapHoverAlpha * hoverBandIntensity)
                .clamp(minAlpha, maxAlpha)
                .toDouble();
        final Color hoverTintColor =
            context.colorScheme.primary.withValues(alpha: hoverAlpha);

        final bool replacesLeading = widget.leading != null && widget.loading;

        final List<Widget> rowChildren = <Widget>[
          if (widget.leading == null)
            ButtonSpinnerSlot(
              isVisible: widget.loading,
              spinner: AxiProgressIndicator(color: foreground),
              slotSize: context.sizing.progressIndicatorSize,
              gap: widget.size.gap(context.spacing),
              duration: animationDuration,
            ),
          if (widget.leading != null)
            replacesLeading
                ? AxiProgressIndicator(color: foreground)
                : widget.leading!,
          if (widget.leading != null && widget.child != null)
            SizedBox(width: widget.size.gap(context.spacing)),
          if (widget.child != null) widget.child!,
          if (widget.trailing != null && widget.child != null)
            SizedBox(width: widget.size.gap(context.spacing)),
          if (widget.trailing != null) widget.trailing!,
        ];

        Widget content = ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: widget.size.minHeight(context.sizing),
          ),
          child: Padding(
            padding: widget.size.padding(context.spacing),
            child: Row(
              mainAxisSize: widget.widthBehavior == AxiButtonWidth.expand ||
                      widget.width != null
                  ? MainAxisSize.max
                  : MainAxisSize.min,
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
        if (hoverOrFocus) {
          final Widget hoverTintLayer = Positioned.fill(
            child: IgnorePointer(
              child: AxiHoverBand(
                shape: shape,
                color: hoverTintColor,
                heightFactor: hoverBandHeightFactor,
              ),
            ),
          );
          content = Stack(
            alignment: Alignment.center,
            children: <Widget>[hoverTintLayer, content],
          );
        }

        if (widget.width != null) {
          content = SizedBox(width: widget.width, child: content);
        }

        Widget button = Material(
          color: background,
          shape: shape,
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

        if (widget.widthBehavior == AxiButtonWidth.fit &&
            widget.width == null) {
          button = UnconstrainedBox(
            constrainedAxis: Axis.vertical,
            alignment: Alignment.centerLeft,
            child: button,
          );
        }

        if (enabled) {
          final Duration pressDuration = Duration(
            milliseconds: (animationDuration.inMilliseconds *
                    context.motion.buttonPressDurationFactor)
                .round(),
          );
          final Duration releaseDuration = Duration(
            milliseconds: (animationDuration.inMilliseconds *
                    context.motion.buttonReleaseDurationFactor)
                .round(),
          );
          button = AxiTapBounce(
            controller: _bounceController,
            enabled: animationDuration != Duration.zero,
            scale: widget.size == AxiButtonSize.sm
                ? context.motion.buttonCompactBounceScale
                : context.motion.buttonBounceScale,
            pressDuration: pressDuration,
            releaseDuration: releaseDuration,
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
  }
}
