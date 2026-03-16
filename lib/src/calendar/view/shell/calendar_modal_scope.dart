// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/axi_surface_scope.dart';
import 'package:flutter/material.dart';

class CalendarModalScope extends InheritedWidget {
  const CalendarModalScope({
    super.key,
    required this.navigatorKey,
    required this.modalAnchorKey,
    required this.surfaceController,
    required super.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey modalAnchorKey;
  final AxiSurfaceController surfaceController;

  static CalendarModalScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CalendarModalScope>();
  }

  BuildContext? get navigatorContext =>
      modalAnchorKey.currentContext ??
      navigatorKey.currentState?.overlay?.context ??
      navigatorKey.currentContext;

  @override
  bool updateShouldNotify(CalendarModalScope oldWidget) {
    return navigatorKey != oldWidget.navigatorKey ||
        modalAnchorKey != oldWidget.modalAnchorKey ||
        surfaceController != oldWidget.surfaceController;
  }
}

extension CalendarModalContext on BuildContext {
  BuildContext get calendarModalContext {
    final scope = CalendarModalScope.maybeOf(this);
    final BuildContext? navigatorContext = scope?.navigatorContext;
    return navigatorContext ?? this;
  }
}
