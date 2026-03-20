// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/buttons/axi_button_haptics.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiPlainHeaderButton extends StatefulWidget {
  const AxiPlainHeaderButton({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.onFocusChange,
    this.onHoverChange,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onHoverChange;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color? pressedBackgroundColor;
  final String? semanticLabel;

  @override
  State<AxiPlainHeaderButton> createState() => _AxiPlainHeaderButtonState();
}

class _AxiPlainHeaderButtonState extends State<AxiPlainHeaderButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHoverChange?.call(value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final enabled = widget.onPressed != null || widget.onLongPress != null;
    final VoidCallback? onTap = enabled
        ? withSelectionHaptic(widget.onPressed)
        : null;
    final VoidCallback? handleLongPress = enabled
        ? withSelectionHaptic(widget.onLongPress)
        : null;
    final VoidCallback? onLongPress = handleLongPress == null
        ? null
        : () {
            _setPressed(false);
            handleLongPress();
          };
    final baseBackground = widget.backgroundColor ?? Colors.transparent;
    final hoverBackground =
        widget.hoverBackgroundColor ??
        Color.alphaBlend(
          context.colorScheme.primary.withValues(
            alpha: context.motion.tapHoverAlpha,
          ),
          baseBackground,
        );
    final pressedBackground =
        widget.pressedBackgroundColor ??
        Color.alphaBlend(
          context.colorScheme.primary.withValues(
            alpha: context.motion.tapSplashAlpha,
          ),
          hoverBackground,
        );
    final Color resolvedBackground = _pressed
        ? pressedBackground
        : (_hovered ? hoverBackground : baseBackground);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeInOutCubic,
        color: resolvedBackground,
        child: ShadFocusable(
          canRequestFocus: enabled,
          onFocusChange: widget.onFocusChange,
          builder: (context, _, child) => child ?? const SizedBox.shrink(),
          child: ShadGestureDetector(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            hoverStrategies: ShadTheme.of(context).hoverStrategies,
            behavior: HitTestBehavior.opaque,
            onHoverChange: enabled ? _setHovered : null,
            onTap: onTap,
            onLongPress: onLongPress,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: enabled ? () => _setPressed(false) : null,
            onLongPressStart: enabled ? (_) => _setPressed(true) : null,
            onLongPressEnd: enabled ? (_) => _setPressed(false) : null,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
