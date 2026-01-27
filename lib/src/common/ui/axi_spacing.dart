// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

class AxiSpacing extends ThemeExtension<AxiSpacing> {
  const AxiSpacing({
    required this.xxs,
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.xxl,
  });

  final double xxs;
  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;

  @override
  AxiSpacing copyWith({
    double? xxs,
    double? xs,
    double? s,
    double? m,
    double? l,
    double? xl,
    double? xxl,
  }) {
    return AxiSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      s: s ?? this.s,
      m: m ?? this.m,
      l: l ?? this.l,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AxiSpacing lerp(AxiSpacing? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

const AxiSpacing axiSpacing = AxiSpacing(
  xxs: 2,
  xs: 4,
  s: 8,
  m: 16,
  l: 32,
  xl: 64,
  xxl: 128,
);

const double axiSpaceXxs = 2;
const double axiSpaceXs = 4;
const double axiSpaceS = 8;
const double axiSpaceM = 16;
const double axiSpaceL = 32;
const double axiSpaceXl = 64;
const double axiSpaceXxl = 128;

const double axiSquircleRadius = 12;
const BorderRadius axiBorderRadius =
    BorderRadius.all(Radius.circular(axiSquircleRadius));

const double axiIconSize = axiSpaceM;
const double axiIconSizeSm = axiSpaceS;
