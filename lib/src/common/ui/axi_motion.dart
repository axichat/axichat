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
    required this.iconButtonPressDurationFactor,
    required this.iconButtonReleaseDurationFactor,
    required this.tapHoverScale,
    required this.tapSplashAlpha,
    required this.tapHoverAlpha,
    required this.tapFocusAlpha,
    required this.statusBannerSlideOffset,
    required this.statusBannerSuccessDuration,
  });

  final double buttonBounceScale;
  final double buttonCompactBounceScale;
  final double buttonPressDurationFactor;
  final double buttonReleaseDurationFactor;
  final double iconButtonBounceScale;
  final double iconButtonCompactBounceScale;
  final double iconButtonPressDurationFactor;
  final double iconButtonReleaseDurationFactor;
  final double tapHoverScale;
  final double tapSplashAlpha;
  final double tapHoverAlpha;
  final double tapFocusAlpha;
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
    double? iconButtonPressDurationFactor,
    double? iconButtonReleaseDurationFactor,
    double? tapHoverScale,
    double? tapSplashAlpha,
    double? tapHoverAlpha,
    double? tapFocusAlpha,
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
      iconButtonPressDurationFactor:
          iconButtonPressDurationFactor ?? this.iconButtonPressDurationFactor,
      iconButtonReleaseDurationFactor: iconButtonReleaseDurationFactor ??
          this.iconButtonReleaseDurationFactor,
      tapHoverScale: tapHoverScale ?? this.tapHoverScale,
      tapSplashAlpha: tapSplashAlpha ?? this.tapSplashAlpha,
      tapHoverAlpha: tapHoverAlpha ?? this.tapHoverAlpha,
      tapFocusAlpha: tapFocusAlpha ?? this.tapFocusAlpha,
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
  iconButtonBounceScale: 0.9,
  iconButtonCompactBounceScale: 0.86,
  iconButtonPressDurationFactor: 4 / 15,
  iconButtonReleaseDurationFactor: 3 / 5,
  tapHoverScale: 0.985,
  tapSplashAlpha: 0.18,
  tapHoverAlpha: 0.08,
  tapFocusAlpha: 0.32,
  statusBannerSlideOffset: Offset(0.0, -(1 / 12)),
  statusBannerSuccessDuration: Duration(milliseconds: 900),
);
