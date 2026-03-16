// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'calendar_hover_title_scope.dart';

class CalendarTaskTitleHoverReporter extends StatelessWidget {
  const CalendarTaskTitleHoverReporter({
    super.key,
    required this.title,
    required this.child,
    this.enabled = true,
  });

  final String title;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final controller = CalendarHoverTitleScope.maybeOf(context);
    final bool shouldReport = enabled && controller != null;

    void reportHover() {
      controller?.hover(title);
    }

    return Listener(
      onPointerDown: shouldReport ? (_) => controller.beginInteraction() : null,
      onPointerUp: shouldReport ? (_) => controller.endInteraction() : null,
      onPointerCancel: shouldReport ? (_) => controller.endInteraction() : null,
      child: MouseRegion(
        onEnter: shouldReport ? (_) => reportHover() : null,
        onHover: shouldReport ? (_) => reportHover() : null,
        onExit: shouldReport ? (_) => controller.clear() : null,
        child: child,
      ),
    );
  }
}
