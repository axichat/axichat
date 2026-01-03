// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';

class OperationProgressController {
  OperationProgressController({required TickerProvider vsync})
      : _controller = AnimationController(
          vsync: vsync,
          lowerBound: 0,
          upperBound: 1,
        );

  static const double _maxDuringOperation = 0.8;
  static const Duration _defaultRamp = Duration(seconds: 5);
  final AnimationController _controller;
  bool _active = false;

  Animation<double> get animation => _controller.view;

  bool get isActive => _active;

  void start() {
    _active = true;
    _controller
      ..stop()
      ..value = 0;
    _controller.animateTo(
      _maxDuringOperation,
      duration: _defaultRamp,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> reach(
    double target, {
    Duration duration = const Duration(milliseconds: 450),
  }) {
    if (!_active) return Future.value();
    final clamped = target.clamp(0.0, _maxDuringOperation);
    if (clamped <= _controller.value) return Future.value();
    return _controller.animateTo(
      clamped,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> complete({
    Duration duration = const Duration(milliseconds: 600),
  }) async {
    if (!_active) {
      final seededValue = _controller.value < _maxDuringOperation
          ? _maxDuringOperation
          : _controller.value;
      _controller
        ..stop()
        ..value = seededValue;
      _active = true;
    }
    await _controller.animateTo(
      1.0,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
    _active = false;
  }

  Future<void> fail() async {
    if (!_active) {
      reset();
      return;
    }
    await _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
    );
    _active = false;
  }

  void reset() {
    _controller
      ..stop()
      ..value = 0;
    _active = false;
  }

  void dispose() {
    _controller.dispose();
  }
}

class OperationProgressBar extends StatelessWidget {
  const OperationProgressBar({
    super.key,
    required this.animation,
    required this.visible,
    required this.label,
  });

  final Animation<double> animation;
  final bool visible;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: !visible
          ? const SizedBox.shrink()
          : AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final percent = (animation.value * 100).clamp(0, 100).round();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: textTheme.muted,
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: label,
                      value: '$percent percent complete',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: animation.value.clamp(0.0, 1.0),
                            backgroundColor:
                                colors.muted.withValues(alpha: 0.24),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
