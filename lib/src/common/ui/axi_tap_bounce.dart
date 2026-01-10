// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const Set<PointerDeviceKind> _tapBouncePointerKinds = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

class AxiTapBounce extends StatefulWidget {
  const AxiTapBounce({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.enabled = true,
    this.pressDuration = const Duration(milliseconds: 80),
    this.releaseDuration = const Duration(milliseconds: 180),
    this.pressCurve = Curves.easeOutCubic,
    this.releaseCurve = Curves.easeOutBack,
  });

  final Widget child;
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
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final targetScale = _pressed ? widget.scale : 1.0;
    final duration = _pressed ? widget.pressDuration : widget.releaseDuration;
    final curve = _pressed ? widget.pressCurve : widget.releaseCurve;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: targetScale,
        duration: duration,
        curve: curve,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

extension AxiTapBounceExtension on Widget {
  Widget withTapBounce({bool enabled = true}) =>
      AxiTapBounce(enabled: enabled, child: this);
}
