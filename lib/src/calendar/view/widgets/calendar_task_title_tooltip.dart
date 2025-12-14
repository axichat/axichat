import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';

class CalendarTaskTitleTooltip extends StatelessWidget {
  const CalendarTaskTitleTooltip({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return child;
    }

    return AxiTooltip(
      builder: (_) => Text(trimmed),
      child: child,
    );
  }
}
