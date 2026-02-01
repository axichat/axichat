// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

class AxiBorders extends ThemeExtension<AxiBorders> {
  const AxiBorders({
    required this.width,
    required this.widthStrong,
  });

  final double width;
  final double widthStrong;

  @override
  AxiBorders copyWith({double? width, double? widthStrong}) {
    return AxiBorders(
      width: width ?? this.width,
      widthStrong: widthStrong ?? this.widthStrong,
    );
  }

  @override
  AxiBorders lerp(AxiBorders? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

const AxiBorders axiBorders = AxiBorders(width: 1, widthStrong: 2);
