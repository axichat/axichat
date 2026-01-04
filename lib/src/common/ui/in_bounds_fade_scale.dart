// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:animations/animations.dart';
import 'package:axichat/src/common/ui/settings_cubit_lookup.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _fadeScaleAnimationStart = 0.0;
const double _fadeScaleAnimationEnd = 1.0;
const Duration _fallbackFadeScaleDuration = Duration(milliseconds: 300);

class InBoundsFadeScale extends StatelessWidget {
  const InBoundsFadeScale({
    super.key,
    required this.child,
    this.duration,
  });

  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final SettingsCubit? settingsCubit = maybeSettingsCubit(context);
    final Duration resolvedDuration = duration ??
        (settingsCubit == null
            ? _fallbackFadeScaleDuration
            : context.select<SettingsCubit, Duration>(
                (cubit) => cubit.animationDuration,
              ));
    return _FadeScaleTransitionPlayer(
      duration: resolvedDuration,
      child: child,
    );
  }
}

class InBoundsFadeScaleChild extends StatelessWidget {
  const InBoundsFadeScaleChild({
    super.key,
    required this.child,
    this.duration,
  });

  final Widget? child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final Widget resolvedChild = child ?? const SizedBox.shrink();
    return InBoundsFadeScale(
      duration: duration,
      child: resolvedChild,
    );
  }
}

class _FadeScaleTransitionPlayer extends StatefulWidget {
  const _FadeScaleTransitionPlayer({
    required this.duration,
    required this.child,
  });

  final Duration duration;
  final Widget child;

  @override
  State<_FadeScaleTransitionPlayer> createState() =>
      _FadeScaleTransitionPlayerState();
}

class _FadeScaleTransitionPlayerState extends State<_FadeScaleTransitionPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant _FadeScaleTransitionPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (widget.duration == Duration.zero) {
      _controller.value = _fadeScaleAnimationEnd;
      return;
    }
    _controller
      ..value = _fadeScaleAnimationStart
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeScaleTransition(
      animation: _controller,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
