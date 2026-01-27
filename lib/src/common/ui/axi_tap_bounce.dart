// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum _TapBouncePressState { idle, pressed }

class AxiTapBounce extends StatefulWidget {
  const AxiTapBounce({
    super.key,
    required this.child,
    this.controller,
    this.scale = 0.96,
    this.enabled = true,
    this.pressDuration = const Duration(milliseconds: 80),
    this.releaseDuration = const Duration(milliseconds: 180),
    this.pressCurve = Curves.easeOutCubic,
    this.releaseCurve = Curves.easeOutBack,
  });

  final Widget child;
  final AxiTapBounceController? controller;
  final double scale;
  final bool enabled;
  final Duration pressDuration;
  final Duration releaseDuration;
  final Curve pressCurve;
  final Curve releaseCurve;

  @override
  State<AxiTapBounce> createState() => _AxiTapBounceState();
}

class _AxiTapBounceState extends State<AxiTapBounce> {
  static final Set<PointerDeviceKind> _tapBouncePointerKinds =
      <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
  _TapBouncePressState _pressState = _TapBouncePressState.idle;

  void _setPressed(bool value) {
    final nextState =
        value ? _TapBouncePressState.pressed : _TapBouncePressState.idle;
    if (_pressState == nextState) return;
    if (!mounted) return;
    setState(() {
      _pressState = nextState;
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
        _pressState == _TapBouncePressState.pressed ? widget.scale : 1.0;
    final duration = _pressState == _TapBouncePressState.pressed
        ? widget.pressDuration
        : widget.releaseDuration;
    final curve = _pressState == _TapBouncePressState.pressed
        ? widget.pressCurve
        : widget.releaseCurve;
    final animationChild = AnimatedScale(
      scale: targetScale,
      duration: duration,
      curve: curve,
      alignment: Alignment.center,
      child: widget.child,
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
      return animationChild;
    }
    return Listener(
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
      child: animationChild,
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
}

extension AxiTapBounceExtension on Widget {
  Widget withTapBounce({bool enabled = true}) =>
      AxiTapBounce(enabled: enabled, child: this);
}
