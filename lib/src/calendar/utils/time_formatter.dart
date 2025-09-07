import 'package:flutter/material.dart';

class TimeFormatter {
  /// Format DateTime to HH:mm format
  static String formatDateTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Format TimeOfDay using Flutter's built-in format
  static String formatTimeOfDay(BuildContext context, TimeOfDay time) {
    return time.format(context);
  }

  /// Format relative sync time (e.g., "Just now", "5m ago")
  static String formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Format duration to human-readable format
  static String formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min${duration.inMinutes == 1 ? '' : 's'}';
    }
    final hours = duration.inHours;
    return '$hours hour${hours == 1 ? '' : 's'}';
  }

  /// Format short duration for compact display
  static String formatDurationShort(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inHours}h';
  }
}
