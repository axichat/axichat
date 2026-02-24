// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/services.dart';

VoidCallback? withSelectionHaptic(VoidCallback? callback) {
  if (callback == null) {
    return null;
  }
  return () {
    HapticFeedback.selectionClick();
    callback();
  };
}
