import 'dart:math';

import '../models/calendar_task.dart';

const _occurrenceSeparator = '::';

enum RecurrenceEndUnit {
  days,
  weeks,
  months,
  years,
}

extension RecurrenceEndUnitX on RecurrenceEndUnit {
  String get label {
    switch (this) {
      case RecurrenceEndUnit.days:
        return 'days';
      case RecurrenceEndUnit.weeks:
        return 'weeks';
      case RecurrenceEndUnit.months:
        return 'months';
      case RecurrenceEndUnit.years:
        return 'years';
    }
  }
}

extension CalendarTaskInstanceX on CalendarTask {
  /// True if this task represents a generated occurrence rather than the
  /// persisted base record.
  bool get isOccurrence => id.contains(_occurrenceSeparator);

  /// The persistent task identifier associated with this instance.
  String get baseId => isOccurrence ? id.split(_occurrenceSeparator).first : id;

  /// Identifier suffix for this occurrence, if applicable.
  String? get occurrenceKey => occurrenceKeyFrom(id);

  /// Unique key for the base (template) occurrence when this task repeats.
  String? get baseOccurrenceKey =>
      scheduledTime?.microsecondsSinceEpoch.toString();

  /// Returns the base occurrence (the first scheduled instance) for recurring
  /// tasks, applying any overrides. Returns `null` if the base occurrence has
  /// been cancelled or the task is unscheduled.
  CalendarTask? baseOccurrenceInstance() {
    final scheduled = scheduledTime;
    if (scheduled == null) return null;
    if (effectiveRecurrence.isNone) return this;

    final key = baseOccurrenceKey;
    if (key == null) return null;

    final override = occurrenceOverrides[key];
    if (override?.isCancelled == true) {
      return null;
    }

    return createOccurrenceInstance(
      originalStart: scheduled,
      occurrenceKey: key,
      override: override,
    );
  }

  /// Resolves a specific occurrence instance, applying overrides when present.
  CalendarTask? occurrenceForId(String occurrenceId) {
    final key = occurrenceKeyFrom(occurrenceId);
    if (key == null) {
      return null;
    }

    final originalStart = _originalStartForKey(key);
    if (originalStart == null) {
      return null;
    }

    final override = occurrenceOverrides[key];
    if (override?.isCancelled == true) {
      return null;
    }

    return createOccurrenceInstance(
      originalStart: originalStart,
      occurrenceKey: key,
      override: override,
    );
  }

  /// Creates a concrete occurrence instance for UI/state consumption.
  CalendarTask createOccurrenceInstance({
    required DateTime originalStart,
    required String occurrenceKey,
    TaskOccurrenceOverride? override,
  }) {
    return _copyForOccurrence(
      originalStart: originalStart,
      occurrenceKey: occurrenceKey,
      scheduledOverride: override?.scheduledTime,
      durationOverride: override?.duration,
      endDateOverride: override?.endDate,
      daySpanOverride: override?.daySpan,
    );
  }

  /// Produces additional instances of this task within the requested range
  /// based on its recurrence rule.
  List<CalendarTask> occurrencesWithin(DateTime rangeStart, DateTime rangeEnd) {
    final recurrence = effectiveRecurrence;
    final scheduled = scheduledTime;

    if (scheduled == null || recurrence.isNone) {
      return const [];
    }

    final inclusiveEnd = _minDateTime(
      rangeEnd,
      recurrence.until == null ? null : _endOfDay(recurrence.until!),
    );

    if (inclusiveEnd != null && inclusiveEnd.isBefore(scheduled)) {
      return const [];
    }

    final results = <CalendarTask>[];
    final overrides = occurrenceOverrides;
    var current = scheduled;
    var generatedCount = 1; // Base instance counts toward limits.

    while (true) {
      final next = _nextOccurrence(current, recurrence, scheduled);
      if (next == null) {
        break;
      }

      generatedCount += 1;
      current = next;

      if (recurrence.count != null && generatedCount > recurrence.count!) {
        break;
      }

      if (inclusiveEnd != null && next.isAfter(inclusiveEnd)) {
        break;
      }

      final overrideKey = next.microsecondsSinceEpoch.toString();
      final override = overrides[overrideKey];

      if (override?.isCancelled == true) {
        if (next.isAfter(rangeEnd)) {
          break;
        }
        continue;
      }

      final actualStart = override?.scheduledTime ?? next;

      if (actualStart.isAfter(rangeEnd)) {
        if (next.isAfter(rangeEnd)) {
          break;
        }
        continue;
      }

      if (actualStart.isBefore(rangeStart)) {
        continue;
      }

      results.add(
        _copyForOccurrence(
          originalStart: next,
          occurrenceKey: overrideKey,
          scheduledOverride: override?.scheduledTime,
          durationOverride: override?.duration,
          endDateOverride: override?.endDate,
          daySpanOverride: override?.daySpan,
        ),
      );
    }

    return results;
  }

  DateTime? _originalStartForKey(String key) {
    final micros = int.tryParse(key);
    if (micros != null) {
      return DateTime.fromMicrosecondsSinceEpoch(micros);
    }
    if (baseOccurrenceKey != null && key == baseOccurrenceKey) {
      return scheduledTime;
    }
    return null;
  }

  CalendarTask _copyForOccurrence({
    required DateTime originalStart,
    required String occurrenceKey,
    DateTime? scheduledOverride,
    Duration? durationOverride,
    DateTime? endDateOverride,
    int? daySpanOverride,
  }) {
    final actualStart = scheduledOverride ?? originalStart;
    final adjustedDuration = durationOverride ?? duration;
    final adjustedDaySpan = daySpanOverride ?? daySpan;

    DateTime? shiftedEndDate;
    if (endDateOverride != null) {
      shiftedEndDate = endDateOverride;
    } else if (scheduledTime != null && endDate != null) {
      final baseStart = DateTime(
        scheduledTime!.year,
        scheduledTime!.month,
        scheduledTime!.day,
      );
      final baseEnd = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
      );
      final span = baseEnd.difference(baseStart);
      shiftedEndDate = DateTime(
        actualStart.year,
        actualStart.month,
        actualStart.day,
      ).add(span);
    } else if (adjustedDuration != null) {
      shiftedEndDate = actualStart.add(adjustedDuration);
    } else if (adjustedDaySpan != null && adjustedDaySpan > 1) {
      shiftedEndDate = actualStart.add(Duration(days: adjustedDaySpan - 1));
    } else if (endDate != null) {
      shiftedEndDate = endDate;
    }

    return copyWith(
      id: '$baseId$_occurrenceSeparator$occurrenceKey',
      scheduledTime: actualStart,
      duration: adjustedDuration,
      daySpan: adjustedDaySpan,
      endDate: shiftedEndDate,
    );
  }
}

DateTime? _nextOccurrence(
  DateTime current,
  RecurrenceRule rule,
  DateTime baseStart,
) {
  switch (rule.frequency) {
    case RecurrenceFrequency.none:
      return null;
    case RecurrenceFrequency.daily:
      return current.add(Duration(days: max(1, rule.interval)));
    case RecurrenceFrequency.weekdays:
      return _addWeekdays(current, max(1, rule.interval));
    case RecurrenceFrequency.weekly:
      return _nextWeeklyOccurrence(current, rule, baseStart);
    case RecurrenceFrequency.monthly:
      return _addMonths(current, max(1, rule.interval), baseStart.day);
  }
}

DateTime? calculateRecurrenceEndDate({
  required DateTime start,
  required RecurrenceFrequency frequency,
  required int interval,
  List<int>? byWeekdays,
  required RecurrenceEndUnit unit,
  required int amount,
}) {
  if (amount <= 0) {
    return null;
  }

  final normalizedStart = start;
  final limit = _inclusiveLimitForUnit(normalizedStart, unit, amount);
  final rule = RecurrenceRule(
    frequency: frequency,
    interval: interval,
    byWeekdays: byWeekdays,
  );

  var current = normalizedStart;
  var last = normalizedStart;

  while (true) {
    final next = _nextOccurrence(current, rule, normalizedStart);
    if (next == null || next.isAfter(limit)) {
      break;
    }
    last = next;
    current = next;
  }

  return DateTime(last.year, last.month, last.day);
}

({int amount, RecurrenceEndUnit unit})? deriveEndAfterFromCount({
  required int? count,
  required RecurrenceFrequency frequency,
  required int interval,
}) {
  if (count == null || count <= 0) {
    return null;
  }

  final effective = (count - 1) * interval + 1;
  switch (frequency) {
    case RecurrenceFrequency.daily:
    case RecurrenceFrequency.weekdays:
      return (amount: effective, unit: RecurrenceEndUnit.days);
    case RecurrenceFrequency.weekly:
      return (amount: effective, unit: RecurrenceEndUnit.weeks);
    case RecurrenceFrequency.monthly:
      if (effective % 12 == 0) {
        return (
          amount: effective ~/ 12,
          unit: RecurrenceEndUnit.years,
        );
      }
      return (amount: effective, unit: RecurrenceEndUnit.months);
    case RecurrenceFrequency.none:
      return null;
  }
}

DateTime _inclusiveLimitForUnit(
  DateTime start,
  RecurrenceEndUnit unit,
  int amount,
) {
  switch (unit) {
    case RecurrenceEndUnit.days:
      return start.add(Duration(days: amount - 1));
    case RecurrenceEndUnit.weeks:
      return start.add(Duration(days: amount * 7 - 1));
    case RecurrenceEndUnit.months:
      return _addMonths(start, amount - 1, start.day);
    case RecurrenceEndUnit.years:
      return _addMonths(start, amount * 12 - 1, start.day);
  }
}

DateTime _addWeekdays(DateTime start, int weekdays) {
  var remaining = weekdays;
  var candidate = start;

  while (remaining > 0) {
    candidate = candidate.add(const Duration(days: 1));
    final weekday = candidate.weekday;
    final isWeekend =
        weekday == DateTime.saturday || weekday == DateTime.sunday;
    if (!isWeekend) {
      remaining -= 1;
    }
  }

  return candidate;
}

DateTime _addMonths(DateTime start, int months, int desiredDay) {
  final totalMonths = start.month - 1 + months;
  final year = start.year + totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDay = _daysInMonth(year, month);
  final day = min(desiredDay, lastDay);

  return DateTime(
    year,
    month,
    day,
    start.hour,
    start.minute,
    start.second,
    start.millisecond,
    start.microsecond,
  );
}

DateTime _nextWeeklyOccurrence(
  DateTime current,
  RecurrenceRule rule,
  DateTime baseStart,
) {
  final rawWeekdays = (rule.byWeekdays != null && rule.byWeekdays!.isNotEmpty)
      ? rule.byWeekdays!
      : <int>[baseStart.weekday];
  final weekdays = rawWeekdays
      .map((day) => day == DateTime.sunday ? 7 : day)
      .toList()
    ..sort();

  final currentWeekday =
      current.weekday == DateTime.sunday ? 7 : current.weekday;
  for (final day in weekdays) {
    if (day > currentWeekday) {
      final delta = day - currentWeekday;
      return current.add(Duration(days: delta));
    }
  }

  final firstDay = weekdays.first;
  final weeksToAdd = max(1, rule.interval);
  final daysUntilNext = (weeksToAdd * 7) - (currentWeekday - firstDay);
  return current.add(Duration(days: daysUntilNext));
}

int _daysInMonth(int year, int month) {
  if (month == DateTime.february) {
    final isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    return isLeap ? 29 : 28;
  }
  const monthLengths = <int>{
    1,
    3,
    5,
    7,
    8,
    10,
    12,
  };
  if (monthLengths.contains(month)) {
    return 31;
  }
  return 30;
}

DateTime? _minDateTime(DateTime a, DateTime? b) {
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

DateTime _endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
}

String baseTaskIdFrom(String taskId) {
  final separatorIndex = taskId.indexOf(_occurrenceSeparator);
  if (separatorIndex == -1) {
    return taskId;
  }
  return taskId.substring(0, separatorIndex);
}

String? occurrenceKeyFrom(String taskId) {
  final separatorIndex = taskId.indexOf(_occurrenceSeparator);
  if (separatorIndex == -1) {
    return null;
  }
  return taskId.substring(separatorIndex + _occurrenceSeparator.length);
}
