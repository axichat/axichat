// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

class AxiRadii extends ThemeExtension<AxiRadii> {
  const AxiRadii({
    required this.container,
    required this.squircle,
    required this.squircleSm,
    required this.pill,
  });

  final double container;
  final double squircle;
  final double squircleSm;
  final double pill;

  @override
  AxiRadii copyWith({
    double? container,
    double? squircle,
    double? squircleSm,
    double? pill,
  }) {
    return AxiRadii(
      container: container ?? this.container,
      squircle: squircle ?? this.squircle,
      squircleSm: squircleSm ?? this.squircleSm,
      pill: pill ?? this.pill,
    );
  }

  @override
  AxiRadii lerp(AxiRadii? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

const double axiContainerRadius = 8;
const double axiSquircleRadius = 12;
const BorderRadius axiBorderRadius = BorderRadius.all(
  Radius.circular(axiContainerRadius),
);

const AxiRadii axiRadii = AxiRadii(
  container: axiContainerRadius,
  squircle: axiSquircleRadius,
  squircleSm: axiContainerRadius,
  pill: 1000,
);
