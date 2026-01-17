// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const double _defaultIconScale = 0.6;
const double _ghostIconScale = 0.85;

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
  });

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
  })  : backgroundColor = null,
        borderColor = null,
        borderWidth = null,
        ghost = true;

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
  final bool ghost;

  @override
  State<AxiIconButton> createState() => _AxiIconButtonState();
}

class _AxiIconButtonState extends State<AxiIconButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    if (!mounted) return;
    setState(() {
      _pressed = value;
    });
  }

  bool _shouldHandleTapKind(PointerDeviceKind? kind) {
    if (kind == null) {
      return true;
    }
    if (kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus) {
      return true;
    }
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.trackpad;
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_shouldHandleTapKind(details.kind)) {
      return;
    }
    _setPressed(true);
  }

  void _handleTapUp(TapUpDetails details) => _setPressed(false);

  void _handleTapCancel() => _setPressed(false);

  void _handleLongPressUp() => _setPressed(false);

  @override
  void didUpdateWidget(covariant AxiIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && widget.onLongPress == null) {
      _setPressed(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final env = EnvScope.maybeOf(context);
    final isDesktop = env?.isDesktopPlatform ?? false;
    final bool isGhost = widget.ghost;
    final Color resolvedForeground = widget.color ??
        (widget.usePrimary ? colors.primary : colors.foreground);
    final Color resolvedBorder =
        widget.borderColor ?? (isGhost ? Colors.transparent : colors.border);
    final Color resolvedBackground =
        widget.backgroundColor ?? (isGhost ? colors.secondary : colors.card);
    final bool enabled = widget.onPressed != null || widget.onLongPress != null;
    final double fallbackIconSize = context.iconTheme.size ??
        AxiIconButton.kDefaultSize * _defaultIconScale;
    final double resolvedIconSize = widget.iconSize ??
        (isGhost ? fallbackIconSize * _ghostIconScale : fallbackIconSize);
    final double resolvedButtonSize =
        widget.buttonSize ?? AxiIconButton.kDefaultSize;
    final double resolvedTapTargetSize =
        widget.tapTargetSize ?? AxiIconButton.kTapTargetSize;
    final double resolvedCornerRadius = widget.cornerRadius ?? 18;
    final double resolvedBorderWidth =
        widget.borderWidth ?? (isGhost ? 0 : 1.0);
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
              onTapDown: enabled ? _handleTapDown : null,
              onTapUp: enabled ? _handleTapUp : null,
              onTapCancel: enabled ? _handleTapCancel : null,
              onLongPressUp: enabled ? _handleLongPressUp : null,
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
      const double pressScale = 0.96;
      const Duration pressDuration = Duration(milliseconds: 80);
      const Duration releaseDuration = Duration(milliseconds: 180);
      const Curve pressCurve = Curves.easeOutCubic;
      const Curve releaseCurve = Curves.easeOutBack;
      final double targetScale = _pressed ? pressScale : 1.0;
      final Duration duration = _pressed ? pressDuration : releaseDuration;
      final Curve curve = _pressed ? pressCurve : releaseCurve;
      tappable = AnimatedScale(
        scale: targetScale,
        duration: duration,
        curve: curve,
        alignment: Alignment.center,
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
