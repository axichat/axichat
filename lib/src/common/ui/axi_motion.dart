// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

class AxiMotion extends ThemeExtension<AxiMotion> {
  const AxiMotion({
    required this.buttonBounceScale,
    required this.buttonCompactBounceScale,
    required this.buttonPressDurationFactor,
    required this.buttonReleaseDurationFactor,
    required this.iconButtonBounceScale,
    required this.iconButtonCompactBounceScale,
    required this.iconButtonHoverScale,
    required this.iconButtonPressDurationFactor,
    required this.iconButtonReleaseDurationFactor,
    required this.tapHoverScale,
    required this.tapSplashAlpha,
    required this.tapHoverAlpha,
    required this.tapFocusAlpha,
    required this.composerBannerSlideOffset,
    required this.composerBannerTransitionDuration,
    required this.composerBannerMinVisibilityDuration,
    required this.statusBannerSlideOffset,
    required this.statusBannerSuccessDuration,
  });

  final double buttonBounceScale;
  final double buttonCompactBounceScale;
  final double buttonPressDurationFactor;
  final double buttonReleaseDurationFactor;
  final double iconButtonBounceScale;
  final double iconButtonCompactBounceScale;
  final double iconButtonHoverScale;
  final double iconButtonPressDurationFactor;
  final double iconButtonReleaseDurationFactor;
  final double tapHoverScale;
  final double tapSplashAlpha;
  final double tapHoverAlpha;
  final double tapFocusAlpha;
  final Offset composerBannerSlideOffset;
  final Duration composerBannerTransitionDuration;
  final Duration composerBannerMinVisibilityDuration;
  final Offset statusBannerSlideOffset;
  final Duration statusBannerSuccessDuration;

  @override
  AxiMotion copyWith({
    double? buttonBounceScale,
    double? buttonCompactBounceScale,
    double? buttonPressDurationFactor,
    double? buttonReleaseDurationFactor,
    double? iconButtonBounceScale,
    double? iconButtonCompactBounceScale,
    double? iconButtonHoverScale,
    double? iconButtonPressDurationFactor,
    double? iconButtonReleaseDurationFactor,
    double? tapHoverScale,
    double? tapSplashAlpha,
    double? tapHoverAlpha,
    double? tapFocusAlpha,
    Offset? composerBannerSlideOffset,
    Duration? composerBannerTransitionDuration,
    Duration? composerBannerMinVisibilityDuration,
    Offset? statusBannerSlideOffset,
    Duration? statusBannerSuccessDuration,
  }) {
    return AxiMotion(
      buttonBounceScale: buttonBounceScale ?? this.buttonBounceScale,
      buttonCompactBounceScale:
          buttonCompactBounceScale ?? this.buttonCompactBounceScale,
      buttonPressDurationFactor:
          buttonPressDurationFactor ?? this.buttonPressDurationFactor,
      buttonReleaseDurationFactor:
          buttonReleaseDurationFactor ?? this.buttonReleaseDurationFactor,
      iconButtonBounceScale:
          iconButtonBounceScale ?? this.iconButtonBounceScale,
      iconButtonCompactBounceScale:
          iconButtonCompactBounceScale ?? this.iconButtonCompactBounceScale,
      iconButtonHoverScale: iconButtonHoverScale ?? this.iconButtonHoverScale,
      iconButtonPressDurationFactor:
          iconButtonPressDurationFactor ?? this.iconButtonPressDurationFactor,
      iconButtonReleaseDurationFactor:
          iconButtonReleaseDurationFactor ??
          this.iconButtonReleaseDurationFactor,
      tapHoverScale: tapHoverScale ?? this.tapHoverScale,
      tapSplashAlpha: tapSplashAlpha ?? this.tapSplashAlpha,
      tapHoverAlpha: tapHoverAlpha ?? this.tapHoverAlpha,
      tapFocusAlpha: tapFocusAlpha ?? this.tapFocusAlpha,
      composerBannerSlideOffset:
          composerBannerSlideOffset ?? this.composerBannerSlideOffset,
      composerBannerTransitionDuration:
          composerBannerTransitionDuration ??
          this.composerBannerTransitionDuration,
      composerBannerMinVisibilityDuration:
          composerBannerMinVisibilityDuration ??
          this.composerBannerMinVisibilityDuration,
      statusBannerSlideOffset:
          statusBannerSlideOffset ?? this.statusBannerSlideOffset,
      statusBannerSuccessDuration:
          statusBannerSuccessDuration ?? this.statusBannerSuccessDuration,
    );
  }

  @override
  AxiMotion lerp(AxiMotion? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

const AxiMotion axiMotion = AxiMotion(
  buttonBounceScale: 0.95,
  buttonCompactBounceScale: 0.93,
  buttonPressDurationFactor: 4 / 15,
  buttonReleaseDurationFactor: 3 / 5,
  iconButtonBounceScale: 0.94,
  iconButtonCompactBounceScale: 0.9,
  iconButtonHoverScale: 0.97,
  iconButtonPressDurationFactor: 4 / 15,
  iconButtonReleaseDurationFactor: 3 / 5,
  tapHoverScale: 0.985,
  tapSplashAlpha: 0.18,
  tapHoverAlpha: 0.08,
  tapFocusAlpha: 0.32,
  composerBannerSlideOffset: Offset(0.0, 0.22),
  composerBannerTransitionDuration: Duration(milliseconds: 280),
  composerBannerMinVisibilityDuration: Duration(milliseconds: 500),
  statusBannerSlideOffset: Offset(0.0, -(1 / 12)),
  statusBannerSuccessDuration: Duration(milliseconds: 900),
);
