// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

/// Minimal squircle approximation built on top of [ContinuousRectangleBorder]
/// so we can keep a consistent API even on Flutter versions that do not
/// expose the framework's smooth rectangle classes yet.
class SquircleBorder extends ContinuousRectangleBorder {
  SquircleBorder({
    super.side = BorderSide.none,
    double cornerRadius = 16.0,
    BorderRadiusGeometry? borderRadius,
  }) : super(
          borderRadius:
              borderRadius ?? BorderRadius.all(Radius.circular(cornerRadius)),
        );
}
