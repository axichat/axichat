import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/view/error_display.dart';

/// Shared error banner wrapper for calendar surfaces (full calendar + guest)
/// so the ErrorDisplay layout and margin logic stay consistent.
class CalendarErrorBanner extends StatelessWidget {
  const CalendarErrorBanner({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onDismiss,
    this.margin,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? calendarPaddingXl,
      child: ErrorDisplay(
        error: error,
        onRetry: onRetry,
        onDismiss: onDismiss,
      ),
    );
  }
}
