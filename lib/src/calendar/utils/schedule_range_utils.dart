// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/constants.dart';

extension CalendarDurationClamp on Duration {
  Duration atLeast(Duration minimum) => compareTo(minimum) < 0 ? minimum : this;
}

Duration resolveScheduleDuration({
  required DateTime? start,
  required DateTime? end,
  Duration fallback = calendarDefaultTaskDuration,
  Duration minimum = calendarMinimumTaskDuration,
}) {
  if (start != null && end != null) {
    final Duration span = end.difference(start);
    if (span.compareTo(Duration.zero) <= 0) {
      return fallback.atLeast(minimum);
    }
    return span.atLeast(minimum);
  }
  return fallback.atLeast(minimum);
}

DateTime? shiftEndTimeWithStart({
  required DateTime? previousStart,
  required DateTime? previousEnd,
  required DateTime? nextStart,
  Duration fallbackDuration = calendarDefaultTaskDuration,
  Duration minimumDuration = calendarMinimumTaskDuration,
}) {
  final DateTime? start = nextStart;
  if (start == null) {
    return null;
  }
  final DateTime? end = previousEnd;
  if (previousStart == null && end != null) {
    if (end.isAfter(start)) {
      return end;
    }
    return start.add(minimumDuration);
  }
  final Duration span = resolveScheduleDuration(
    start: previousStart,
    end: end,
    fallback: fallbackDuration,
    minimum: minimumDuration,
  );
  return start.add(span);
}

DateTime? clampEndTime({
  required DateTime? start,
  required DateTime? end,
  Duration minimumDuration = calendarMinimumTaskDuration,
}) {
  final DateTime? resolvedEnd = end;
  if (resolvedEnd == null) {
    return null;
  }
  final DateTime? resolvedStart = start;
  if (resolvedStart == null) {
    return resolvedEnd;
  }
  if (resolvedEnd.isAfter(resolvedStart)) {
    return resolvedEnd;
  }
  return resolvedStart.add(minimumDuration);
}
