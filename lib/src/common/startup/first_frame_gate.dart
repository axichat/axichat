// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Holds the first frame until the UI is ready to paint.
class FirstFrameGate {
  FirstFrameGate({this.fallbackDelay = const Duration(seconds: 1)});

  final Duration fallbackDelay;

  WidgetsBinding? _binding;
  bool _deferred = false;
  bool _released = false;
  Timer? _fallback;

  void defer(WidgetsBinding binding) {
    if (_deferred) return;
    _binding = binding;
    _deferred = true;
    binding.deferFirstFrame();
  }

  void allow() {
    if (!_deferred || _released) return;
    _released = true;
    _fallback?.cancel();
    _binding?.allowFirstFrame();
  }

  void scheduleFallback() {
    if (!_deferred || _released || _fallback != null) return;
    _fallback = Timer(fallbackDelay, allow);
  }
}

final firstFrameGate = FirstFrameGate();
