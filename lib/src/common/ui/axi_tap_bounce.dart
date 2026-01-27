// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const Set<PointerDeviceKind> _tapBouncePointerKinds = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

const double _hoverElevationInset = 2.0;
const double _hoverElevationBlur = 2.0;
const double _hoverElevationAlpha = 0.12;
const double _hoverElevationSpread = 0.0;

enum _TapBouncePressState { idle, pressed }

enum _TapBounceHoverState { idle, hovering }

enum _TapBounceVisualState { idle, hover, pressed }

class AxiTapBounce extends StatefulWidget {
  const AxiTapBounce({
    super.key,
    required this.child,
    this.controller,
    this.scale = 0.96,
    this.hoverShape,
    this.enabled = true,
    this.pressDuration = const Duration(milliseconds: 80),
    this.releaseDuration = const Duration(milliseconds: 180),
    this.pressCurve = Curves.easeOutCubic,
    this.releaseCurve = Curves.easeOutBack,
  });

  final Widget child;
  final AxiTapBounceController? controller;
  final double scale;
  final ShapeBorder? hoverShape;
  final bool enabled;
  final Duration pressDuration;
  final Duration releaseDuration;
  final Curve pressCurve;
  final Curve releaseCurve;

  @override
  State<AxiTapBounce> createState() => _AxiTapBounceState();
}

class _AxiTapBounceState extends State<AxiTapBounce> {
  _TapBouncePressState _pressState = _TapBouncePressState.idle;
  _TapBounceHoverState _hoverState = _TapBounceHoverState.idle;

  _TapBounceVisualState get _visualState {
    if (_pressState == _TapBouncePressState.pressed) {
      return _TapBounceVisualState.pressed;
    }
    if (_hoverState == _TapBounceHoverState.hovering) {
      return _TapBounceVisualState.hover;
    }
    return _TapBounceVisualState.idle;
  }

  void _setPressed(bool value) {
    final nextState =
        value ? _TapBouncePressState.pressed : _TapBouncePressState.idle;
    if (_pressState == nextState) return;
    if (!mounted) return;
    setState(() {
      _pressState = nextState;
    });
  }

  void _setHovered(bool value) {
    final nextState =
        value ? _TapBounceHoverState.hovering : _TapBounceHoverState.idle;
    if (_hoverState == nextState) return;
    if (!mounted) return;
    setState(() {
      _hoverState = nextState;
    });
  }

  bool _shouldHandleTapKind(PointerDeviceKind? kind) {
    if (kind == null) {
      return true;
    }
    if (_tapBouncePointerKinds.contains(kind)) {
      return true;
    }
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.trackpad;
  }

  bool _shouldHandleHoverKind(PointerDeviceKind? kind) {
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

  @override
  void didUpdateWidget(AxiTapBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _setPressed(false);
      _setHovered(false);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final targetScale =
        _visualState == _TapBounceVisualState.pressed ? widget.scale : 1.0;
    final duration = switch (_visualState) {
      _TapBounceVisualState.idle => widget.releaseDuration,
      _ => widget.pressDuration,
    };
    final curve = switch (_visualState) {
      _TapBounceVisualState.idle => widget.releaseCurve,
      _ => widget.pressCurve,
    };
    final animationChild = AnimatedScale(
      scale: targetScale,
      duration: duration,
      curve: curve,
      alignment: Alignment.center,
      child: widget.child,
    );
    final hoverShadowColor = Theme.of(context).colorScheme.shadow;
    final ShapeBorder hoverShape = widget.hoverShape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        );
    final Widget elevatedChild = _TapBounceInset(
      inset: _hoverElevationInset,
      child: TweenAnimationBuilder<double>(
        duration: duration,
        curve: curve,
        tween: Tween<double>(
          begin: 0,
          end: _hoverState == _TapBounceHoverState.hovering ? 1 : 0,
        ),
        builder: (context, t, child) {
          final hoverShadow = BoxShadow(
            color: hoverShadowColor.withValues(
              alpha: _hoverElevationAlpha * t,
            ),
            blurRadius: _hoverElevationBlur,
            spreadRadius: _hoverElevationSpread,
            offset: Offset.zero,
          );
          return DecoratedBox(
            decoration: ShapeDecoration(
              shape: hoverShape,
              shadows: <BoxShadow>[hoverShadow],
            ),
            child: child,
          );
        },
        child: animationChild,
      ),
    );
    final controller = widget.controller;
    if (controller != null) {
      controller
        .._attach(this)
        .._setFallbackHandlers(
          onDown: _handleTapDown,
          onUp: _handleTapUp,
          onCancel: _handleTapCancel,
        );
      return elevatedChild;
    }
    return MouseRegion(
      onEnter: (event) {
        if (!_shouldHandleHoverKind(event.kind)) return;
        _setHovered(true);
      },
      onExit: (event) {
        if (!_shouldHandleHoverKind(event.kind)) return;
        _setHovered(false);
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _handleTapDown(
          TapDownDetails(
            kind: event.kind,
            globalPosition: event.position,
            localPosition: event.localPosition,
          ),
        ),
        onPointerUp: (event) => _handleTapUp(
          TapUpDetails(
            kind: event.kind,
            globalPosition: event.position,
            localPosition: event.localPosition,
          ),
        ),
        onPointerCancel: (_) => _handleTapCancel(),
        child: elevatedChild,
      ),
    );
  }
}

class AxiTapBounceController {
  _AxiTapBounceState? _state;
  void Function(TapDownDetails details)? _fallbackDown;
  void Function(TapUpDetails details)? _fallbackUp;
  VoidCallback? _fallbackCancel;

  void _attach(_AxiTapBounceState state) {
    if (_state == state) return;
    _state = state;
  }

  void _detach(_AxiTapBounceState state) {
    if (_state != state) return;
    _state = null;
  }

  void _setFallbackHandlers({
    required void Function(TapDownDetails details) onDown,
    required void Function(TapUpDetails details) onUp,
    required VoidCallback onCancel,
  }) {
    _fallbackDown = onDown;
    _fallbackUp = onUp;
    _fallbackCancel = onCancel;
  }

  void handleTapDown(TapDownDetails details) =>
      (_state?._handleTapDown ?? _fallbackDown)?.call(details);

  void handleTapUp(TapUpDetails details) =>
      (_state?._handleTapUp ?? _fallbackUp)?.call(details);

  void handleTapCancel() =>
      (_state?._handleTapCancel ?? _fallbackCancel)?.call();

  void setPressed(bool value) => _state?._setPressed(value);

  void setHovered(bool value) => _state?._setHovered(value);
}

class _TapBounceInset extends StatelessWidget {
  const _TapBounceInset({required this.inset, required this.child});

  final double inset;
  final Widget child;

  double _clampInset(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0;
    }
    final double reduced = value - (inset * 2);
    return reduced < 0 ? 0 : reduced;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.isTight) {
          return child;
        }
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double innerWidth = _clampInset(width);
        final double innerHeight = _clampInset(height);
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: SizedBox(
              width: innerWidth,
              height: innerHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

extension AxiTapBounceExtension on Widget {
  Widget withTapBounce({bool enabled = true}) =>
      AxiTapBounce(enabled: enabled, child: this);
}
