// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math';

import 'package:flutter/material.dart';

Color generateAvatarBackground(Random random) {
  final hue = random.nextDouble() * 360.0;
  final saturation = 0.72 + random.nextDouble() * 0.28;
  final lightness = 0.48 + random.nextDouble() * 0.20;
  return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
}
