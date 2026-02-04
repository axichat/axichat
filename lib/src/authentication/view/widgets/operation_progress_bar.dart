// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AuthProgressPhase { idle, running, completing, failing }

@immutable
class AuthProgressSnapshot {
  const AuthProgressSnapshot._(this.phase, this.label);

  const AuthProgressSnapshot.idle() : this._(AuthProgressPhase.idle, '');

  const AuthProgressSnapshot.running(String label)
      : this._(AuthProgressPhase.running, label);

  const AuthProgressSnapshot.completing(String label)
      : this._(AuthProgressPhase.completing, label);

  const AuthProgressSnapshot.failing(String label)
      : this._(AuthProgressPhase.failing, label);

  final AuthProgressPhase phase;
  final String label;

  bool get isVisible => phase != AuthProgressPhase.idle;
}

class AuthProgressController {
  AuthProgressController({required TickerProvider vsync})
      : _controller = AnimationController(
          vsync: vsync,
          lowerBound: 0,
          upperBound: 1,
        ),
        _snapshot = ValueNotifier<AuthProgressSnapshot>(
          const AuthProgressSnapshot.idle(),
        );

  static const double _maxDuringOperation = 0.8;
  final AnimationController _controller;
  final ValueNotifier<AuthProgressSnapshot> _snapshot;

  Animation<double> get animation => _controller.view;

  ValueListenable<AuthProgressSnapshot> get listenable => _snapshot;

  AuthProgressSnapshot get snapshot => _snapshot.value;

  void start({
    required String label,
    required Duration rampDuration,
  }) {
    _snapshot.value = AuthProgressSnapshot.running(label);
    _controller
      ..stop()
      ..value = 0;
    _controller.animateTo(
      _maxDuringOperation,
      duration: rampDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void continueWithLabel({
    required String label,
    required Duration rampDuration,
  }) {
    if (_snapshot.value.phase == AuthProgressPhase.idle) {
      start(label: label, rampDuration: rampDuration);
      return;
    }
    _snapshot.value = AuthProgressSnapshot.running(label);
  }

  Future<void> complete({required Duration duration}) async {
    if (_snapshot.value.phase == AuthProgressPhase.idle) {
      _snapshot.value = const AuthProgressSnapshot.completing('');
    } else {
      _snapshot.value = AuthProgressSnapshot.completing(
        _snapshot.value.label,
      );
    }
    _controller.stop();
    await _controller.animateTo(
      1.0,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> fail({required Duration duration}) async {
    if (_snapshot.value.phase == AuthProgressPhase.idle) {
      return;
    }
    _snapshot.value = AuthProgressSnapshot.failing(
      _snapshot.value.label,
    );
    _controller.stop();
    await _controller.animateTo(
      0,
      duration: duration,
      curve: Curves.easeIn,
    );
    reset();
  }

  void reset() {
    _controller
      ..stop()
      ..value = 0;
    _snapshot.value = const AuthProgressSnapshot.idle();
  }

  void dispose() {
    _controller.dispose();
    _snapshot.dispose();
  }
}

class OperationProgressBar extends StatelessWidget {
  const OperationProgressBar({
    super.key,
    required this.animation,
    required this.visible,
    required this.label,
    required this.animationDuration,
  });

  final Animation<double> animation;
  final bool visible;
  final String label;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final motion = context.motion;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final animationDuration = this.animationDuration;
    final barHeight = sizing.progressIndicatorBarHeight;
    final borderRadius = context.radius;
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
                    ShadProgress(
                      value: animation.value.clamp(0.0, 1.0),
                      minHeight: barHeight,
                      backgroundColor: colors.muted.withValues(
                        alpha: motion.tapHoverAlpha,
                      ),
                      color: colors.primary,
                      borderRadius: borderRadius,
                      innerBorderRadius: borderRadius,
                      semanticsLabel: label,
                      semanticsValue: context.l10n.commonPercentLabel(percent),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
