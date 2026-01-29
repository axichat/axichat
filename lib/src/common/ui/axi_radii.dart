// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

class AxiRadii extends ThemeExtension<AxiRadii> {
  const AxiRadii({
    required this.squircle,
    required this.squircleSm,
  });

  final double squircle;
  final double squircleSm;

  @override
  AxiRadii copyWith({double? squircle, double? squircleSm}) {
    return AxiRadii(
      squircle: squircle ?? this.squircle,
      squircleSm: squircleSm ?? this.squircleSm,
    );
  }

  @override
  AxiRadii lerp(AxiRadii? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

const double axiSquircleRadius = 12;
const BorderRadius axiBorderRadius =
    BorderRadius.all(Radius.circular(axiSquircleRadius));

const AxiRadii axiRadii = AxiRadii(
  squircle: axiSquircleRadius,
  squircleSm: 8,
);
