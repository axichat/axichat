import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

    final bool hasShadTheme = ShadTheme.maybeOf(context, listen: false) != null;
    if (!hasShadTheme) {
      return Tooltip(
        message: trimmed,
        child: child,
      );
    }

    return AxiTooltip(
      builder: (_) => Text(trimmed),
      child: child,
    );
  }
}
