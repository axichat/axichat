// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:animations/animations.dart';
import 'package:axichat/src/common/ui/settings_cubit_lookup.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _fadeScaleEffectStart = 0.0;
const double _fadeScaleEffectEnd = 1.0;
const Curve _fadeScaleEffectCurve = Curves.linear;
const Duration _fallbackFadeScaleDuration = Duration(milliseconds: 300);

Duration resolveFadeScaleDuration(BuildContext context) {
  final SettingsCubit? settingsCubit = maybeSettingsCubit(context);
  if (settingsCubit == null) {
    return _fallbackFadeScaleDuration;
  }
  return context.select<SettingsCubit, Duration>(
    (cubit) => cubit.animationDuration,
  );
}

List<Effect<dynamic>> fadeScaleEffectsFor(BuildContext context) {
  final Duration duration = resolveFadeScaleDuration(context);
  if (duration == Duration.zero) {
    return const <Effect<dynamic>>[];
  }
  return <Effect<dynamic>>[
    FadeScaleTransitionEffect(duration: duration),
  ];
}

class FadeScaleTransitionEffect extends Effect<double> {
  const FadeScaleTransitionEffect({super.duration})
      : super(
          curve: _fadeScaleEffectCurve,
          begin: _fadeScaleEffectStart,
          end: _fadeScaleEffectEnd,
        );

  @override
  Widget build(
    BuildContext context,
    Widget child,
    AnimationController controller,
    EffectEntry entry,
  ) {
    final animation = buildAnimation(controller, entry);
    return FadeScaleTransition(
      animation: animation,
      child: child,
    );
  }
}
