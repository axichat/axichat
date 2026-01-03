// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

const Curve _fadePageCurve = Curves.easeInOutCubic;

class AxiFadePageRoute<T> extends PageRouteBuilder<T> {
  AxiFadePageRoute({
    required WidgetBuilder builder,
    required Duration duration,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final CurvedAnimation curved = CurvedAnimation(
              parent: animation,
              curve: _fadePageCurve,
              reverseCurve: _fadePageCurve,
            );
            return FadeTransition(
              opacity: curved,
              child: child,
            );
          },
        );
}
