import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';

import '../loading_indicator.dart';

/// Semi-transparent overlay with a centered [CalendarLoadingIndicator].
/// Used when the calendar or guest calendar blocks interactions during syncs.
class CalendarLoadingOverlay extends StatelessWidget {
  const CalendarLoadingOverlay({
    super.key,
    this.color,
    this.indicator,
  });

  final Color? color;
  final Widget? indicator;

  @override
  Widget build(BuildContext context) {
    final overlayColor =
        color ?? context.colorScheme.background.withValues(alpha: 0.6);
    return Container(
      color: overlayColor,
      child: Center(
        child: indicator ?? const CalendarLoadingIndicator(),
      ),
    );
  }
}
