// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OperationProgressController {
  OperationProgressController({
    required TickerProvider vsync,
    required Duration rampDuration,
    required Duration reachDuration,
    required Duration completeDuration,
    required Duration failDuration,
  })  : _rampDuration = rampDuration,
        _reachDuration = reachDuration,
        _completeDuration = completeDuration,
        _failDuration = failDuration,
        _controller = AnimationController(
          vsync: vsync,
          lowerBound: 0,
          upperBound: 1,
        );

  static const double _maxDuringOperation = 0.8;
  final AnimationController _controller;
  final Duration _rampDuration;
  final Duration _reachDuration;
  final Duration _completeDuration;
  final Duration _failDuration;

  Animation<double> get animation => _controller.view;

  bool get isActive =>
      _controller.isAnimating ||
      (_controller.value > 0 && _controller.value < 1);

  void start() {
    _controller
      ..stop()
      ..value = 0;
    _controller.animateTo(
      _maxDuringOperation,
      duration: _rampDuration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> reach(
    double target, {
    Duration? duration,
  }) {
    if (!isActive) return Future.value();
    final clamped = target.clamp(0.0, _maxDuringOperation);
    if (clamped <= _controller.value) return Future.value();
    return _controller.animateTo(
      clamped,
      duration: duration ?? _reachDuration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> complete({
    Duration? duration,
  }) async {
    if (!isActive) {
      final seededValue = _controller.value < _maxDuringOperation
          ? _maxDuringOperation
          : _controller.value;
      _controller
        ..stop()
        ..value = seededValue;
    }
    await _controller.animateTo(
      1.0,
      duration: duration ?? _completeDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> fail() async {
    if (!isActive) {
      reset();
      return;
    }
    await _controller.animateTo(
      0,
      duration: _failDuration,
      curve: Curves.easeIn,
    );
  }

  void reset() {
    _controller
      ..stop()
      ..value = 0;
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
    final motion = context.motion;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final barHeight = sizing.progressIndicatorStrokeWidth * 4;
    final borderRadius = BorderRadius.circular(sizing.containerRadius);
    return AnimatedSwitcher(
      duration: animationDuration,
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
                    SizedBox(height: spacing.xs),
                    Semantics(
                      label: label,
                      value: context.l10n.commonPercentLabel(percent),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: SizedBox(
                          height: barHeight,
                          child: LinearProgressIndicator(
                            value: animation.value.clamp(0.0, 1.0),
                            backgroundColor: colors.muted.withValues(
                              alpha: motion.tapHoverAlpha,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.primary,
                            ),
                            borderRadius: borderRadius,
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
