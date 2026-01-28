// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

/// Consistent squircle shape that matches [RoundedSuperellipseBorder].
class SquircleBorder extends RoundedSuperellipseBorder {
  SquircleBorder({
    super.side = BorderSide.none,
    double cornerRadius = 16.0,
    BorderRadius? borderRadius,
  }) : super(
          borderRadius:
              borderRadius ?? BorderRadius.all(Radius.circular(cornerRadius)),
        );
}
