// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiAttentionShake extends StatefulWidget {
  const AxiAttentionShake({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  static const double _activeScale = 1.3;
  static const double _angleMultiplier = 4.0;
  static const double _speedFactor = 0.5882352941176471;

  @override
  State<AxiAttentionShake> createState() => _AxiAttentionShakeState();
}

class _AxiAttentionShakeState extends State<AxiAttentionShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            (baseAnimationDuration.inMilliseconds *
                    AxiAttentionShake._speedFactor)
                .round(),
      ),
    );
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AxiAttentionShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) {
      return;
    }
    if (widget.enabled) {
      _controller.repeat();
      return;
    }
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    final double maxAngle =
        (context.spacing.xxs / context.sizing.iconButtonSize) *
        AxiAttentionShake._angleMultiplier;
    return AnimatedScale(
      alignment: Alignment.center,
      curve: Curves.easeOutBack,
      duration: _controller.duration ?? baseAnimationDuration,
      scale: AxiAttentionShake._activeScale,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final phase = _controller.value * math.pi * 2;
          final angle = math.sin(phase) * maxAngle;
          return Transform.rotate(angle: angle, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
