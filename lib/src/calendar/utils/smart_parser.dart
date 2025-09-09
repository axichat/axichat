import 'package:flutter/material.dart';

/// Parses natural language date/time strings into structured data
class SmartTaskParser {
  static final _timePattern = RegExp(
    r'(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?',
    caseSensitive: false,
  );

  static final _relativeDayPattern = RegExp(
    r'\b(today|tomorrow|yesterday)\b',
    caseSensitive: false,
  );

  static final _weekdayPattern = RegExp(
    r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b',
    caseSensitive: false,
  );

  static final _relativeTimePattern = RegExp(
    r'\b(next|this)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month|year)\b',
    caseSensitive: false,
  );

  static final _inPattern = RegExp(
    r'\bin\s+(\d+)\s+(hour|minute|day|week|month)s?\b',
    caseSensitive: false,
  );

  /// Parses a natural language input and extracts task title and scheduled time
  static TaskParseResult parse(String input) {
    String taskTitle = input;
    DateTime? scheduledTime;

    final now = DateTime.now();

    // Try to extract time first (e.g., "3pm", "15:30", "3:30 PM")
    TimeOfDay? extractedTime;
    final timeMatch = _timePattern.firstMatch(input);
    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      final minute =
          timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final period = timeMatch.group(3)?.toLowerCase();

      if (period != null) {
        if (period == 'pm' && hour != 12) hour += 12;
        if (period == 'am' && hour == 12) hour = 0;
      }

      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        extractedTime = TimeOfDay(hour: hour, minute: minute);
        taskTitle = taskTitle.replaceAll(timeMatch.group(0)!, '').trim();
      }
    }

    // Check for relative days (today, tomorrow, yesterday)
    final relativeDayMatch = _relativeDayPattern.firstMatch(input);
    if (relativeDayMatch != null) {
      final day = relativeDayMatch.group(0)!.toLowerCase();
      switch (day) {
        case 'today':
          scheduledTime = DateTime(now.year, now.month, now.day);
        case 'tomorrow':
          scheduledTime = DateTime(now.year, now.month, now.day)
              .add(const Duration(days: 1));
        case 'yesterday':
          scheduledTime = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 1));
      }
      taskTitle = taskTitle.replaceAll(relativeDayMatch.group(0)!, '').trim();
    }

    // Check for weekday references (monday, tuesday, etc.)
    if (scheduledTime == null) {
      final weekdayMatch = _weekdayPattern.firstMatch(input);
      if (weekdayMatch != null) {
        final weekdayStr = weekdayMatch.group(0)!.toLowerCase();
        final targetWeekday = _getWeekdayNumber(weekdayStr);

        if (targetWeekday != null) {
          scheduledTime = _getNextWeekday(now, targetWeekday);
          taskTitle = taskTitle.replaceAll(weekdayMatch.group(0)!, '').trim();
        }
      }
    }

    // Check for relative time expressions (next week, this month, etc.)
    if (scheduledTime == null) {
      final relativeMatch = _relativeTimePattern.firstMatch(input);
      if (relativeMatch != null) {
        final modifier = relativeMatch.group(1)!.toLowerCase();
        final unit = relativeMatch.group(2)!.toLowerCase();

        scheduledTime = _calculateRelativeTime(now, modifier, unit);
        taskTitle = taskTitle.replaceAll(relativeMatch.group(0)!, '').trim();
      }
    }

    // Check for "in X hours/days" pattern
    if (scheduledTime == null) {
      final inMatch = _inPattern.firstMatch(input);
      if (inMatch != null) {
        final amount = int.parse(inMatch.group(1)!);
        final unit = inMatch.group(2)!.toLowerCase();

        switch (unit) {
          case 'hour':
            scheduledTime = now.add(Duration(hours: amount));
          case 'minute':
            scheduledTime = now.add(Duration(minutes: amount));
          case 'day':
            scheduledTime = now.add(Duration(days: amount));
          case 'week':
            scheduledTime = now.add(Duration(days: amount * 7));
          case 'month':
            scheduledTime = DateTime(now.year, now.month + amount, now.day);
        }
        taskTitle = taskTitle.replaceAll(inMatch.group(0)!, '').trim();
      }
    }

    // Apply extracted time to the date if both exist
    if (scheduledTime != null && extractedTime != null) {
      scheduledTime = DateTime(
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        extractedTime.hour,
        extractedTime.minute,
      );
    } else if (scheduledTime == null && extractedTime != null) {
      // If only time is specified, assume today
      final today = DateTime(now.year, now.month, now.day);
      scheduledTime = DateTime(
        today.year,
        today.month,
        today.day,
        extractedTime.hour,
        extractedTime.minute,
      );

      // If the time has already passed today, assume tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
    }

    // Clean up task title
    taskTitle = _cleanTaskTitle(taskTitle);

    return TaskParseResult(
      title: taskTitle.isEmpty ? input : taskTitle,
      scheduledTime: scheduledTime,
    );
  }

  static int? _getWeekdayNumber(String weekday) {
    const weekdays = {
      'monday': DateTime.monday,
      'mon': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'tue': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'wed': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'thu': DateTime.thursday,
      'friday': DateTime.friday,
      'fri': DateTime.friday,
      'saturday': DateTime.saturday,
      'sat': DateTime.saturday,
      'sunday': DateTime.sunday,
      'sun': DateTime.sunday,
    };
    return weekdays[weekday];
  }

  static DateTime _getNextWeekday(DateTime from, int targetWeekday) {
    int daysToAdd = (targetWeekday - from.weekday) % 7;
    if (daysToAdd == 0) daysToAdd = 7; // Next occurrence, not today
    return from.add(Duration(days: daysToAdd));
  }

  static DateTime? _calculateRelativeTime(
      DateTime from, String modifier, String unit) {
    switch (unit) {
      case 'week':
        return modifier == 'next' ? from.add(const Duration(days: 7)) : from;
      case 'month':
        return modifier == 'next'
            ? DateTime(from.year, from.month + 1, from.day)
            : from;
      case 'year':
        return modifier == 'next'
            ? DateTime(from.year + 1, from.month, from.day)
            : from;
      default:
        // For weekdays with "next" or "this"
        final weekdayNum = _getWeekdayNumber(unit);
        if (weekdayNum != null) {
          if (modifier == 'next') {
            return _getNextWeekday(from, weekdayNum);
          } else {
            // "this" weekday - get the one in current week
            final startOfWeek = from.subtract(Duration(days: from.weekday - 1));
            return startOfWeek.add(Duration(days: weekdayNum - 1));
          }
        }
        return null;
    }
  }

  static String _cleanTaskTitle(String title) {
    // Remove common connecting words that might be left over
    final cleanPatterns = [
      RegExp(r'\s+at\s+$', caseSensitive: false),
      RegExp(r'\s+on\s+$', caseSensitive: false),
      RegExp(r'\s+in\s+$', caseSensitive: false),
      RegExp(r'^\s*on\s+', caseSensitive: false),
      RegExp(r'^\s*at\s+', caseSensitive: false),
    ];

    String cleaned = title;
    for (final pattern in cleanPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    return cleaned.trim();
  }
}

class TaskParseResult {
  final String title;
  final DateTime? scheduledTime;

  const TaskParseResult({
    required this.title,
    this.scheduledTime,
  });
}
