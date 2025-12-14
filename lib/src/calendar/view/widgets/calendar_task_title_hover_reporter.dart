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
    if (!enabled) {
      return child;
    }
    final controller = CalendarHoverTitleScope.maybeOf(context);
    if (controller == null) {
      return child;
    }

    void reportHover() => controller.hover(title);

    return Listener(
      onPointerDown: (_) => controller.beginInteraction(),
      onPointerUp: (_) => controller.endInteraction(),
      onPointerCancel: (_) => controller.endInteraction(),
      child: MouseRegion(
        onEnter: (_) => reportHover(),
        onHover: (_) => reportHover(),
        onExit: (_) => controller.clear(),
        child: child,
      ),
    );
  }
}
