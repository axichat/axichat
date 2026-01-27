// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:axichat/src/common/ui/axi_spacing.dart';

class AxiRadii extends ThemeExtension<AxiRadii> {
  const AxiRadii({required this.squircle});

  final double squircle;

  @override
  AxiRadii copyWith({double? squircle}) {
    return AxiRadii(squircle: squircle ?? this.squircle);
  }

  @override
  AxiRadii lerp(AxiRadii? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

const AxiRadii axiRadii = AxiRadii(squircle: axiSquircleRadius);
