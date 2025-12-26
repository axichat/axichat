import 'dart:math';

import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';

const _occurrenceSeparator = '::';
const int _baseOccurrenceCount = 1;
const int _daysPerWeek = 7;
const int _monthsPerYear = 12;
const Duration _zeroDuration = Duration.zero;

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
  bool get isOccurrence =>
      id.contains(_occurrenceSeparator) && hasRecurrenceData;

  /// True for any task whose identifier encodes a derived instance (recurrence
  /// occurrence or split segment).
  bool get hasDerivedInstance => id.contains(_occurrenceSeparator);

  /// True when the task participates in a recurring series.
  bool get isSeries => hasRecurrenceData;

  /// The persistent task identifier associated with this instance.
  String get baseId {
    if (!hasDerivedInstance) {
      return id;
    }
    final separatorIndex = id.indexOf(_occurrenceSeparator);
    if (separatorIndex == -1) {
      return id;
    }
    return id.substring(0, separatorIndex);
  }

  /// Identifier suffix for this occurrence, if applicable.
  String? get occurrenceKey => isOccurrence ? occurrenceKeyFrom(id) : null;

  /// Unique key for the base (template) occurrence when this task repeats.
  String? get baseOccurrenceKey {
    final scheduled = scheduledTime;
    if (scheduled == null) {
      return null;
    }

    final String? existingKey = occurrenceKey;
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    return scheduled.microsecondsSinceEpoch.toString();
  }

  /// Returns the base occurrence (the first scheduled instance) for recurring
  /// tasks, applying any overrides. Returns `null` if the base occurrence has
  /// been cancelled or the task is unscheduled.
  CalendarTask? baseOccurrenceInstance() {
    final scheduled = scheduledTime;
    if (scheduled == null) return null;
    if (!hasRecurrenceData) return this;

    final key = baseOccurrenceKey;
    if (key == null) return null;

    final Set<String> exDateKeys =
        _calendarDateTimeKeys(effectiveRecurrence.exDates);
    final _OverrideResolution resolution = _resolveOccurrenceOverride(
      originalStart: scheduled,
      occurrenceKey: key,
      overrides: occurrenceOverrides,
      exDateKeys: exDateKeys,
    );
    if (resolution.isExcluded) {
      return null;
    }

    return createOccurrenceInstance(
      originalStart: scheduled,
      occurrenceKey: key,
      override: resolution.override,
    );
  }

  /// Resolves a specific occurrence instance, applying overrides when present.
  CalendarTask? occurrenceForId(String occurrenceId) {
    final key = occurrenceKeyFrom(occurrenceId);
    if (key == null) {
      return null;
    }
    if (!hasRecurrenceData) {
      return null;
    }

    final originalStart = _originalStartForKey(key);
    if (originalStart == null) {
      return null;
    }

    final Set<String> exDateKeys =
        _calendarDateTimeKeys(effectiveRecurrence.exDates);
    final _OverrideResolution resolution = _resolveOccurrenceOverride(
      originalStart: originalStart,
      occurrenceKey: key,
      overrides: occurrenceOverrides,
      exDateKeys: exDateKeys,
    );
    if (resolution.isExcluded) {
      return null;
    }

    return createOccurrenceInstance(
      originalStart: originalStart,
      occurrenceKey: key,
      override: resolution.override,
    );
  }

  /// Resolves the original scheduled start for a given occurrence key.
  DateTime? originalStartForOccurrenceKey(String key) =>
      _originalStartForKey(key);

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
      priorityOverride: override?.priority,
      completedOverride: override?.isCompleted,
      titleOverride: override?.title,
      descriptionOverride: override?.description,
      locationOverride: override?.location,
      checklistOverride: override?.checklist,
    );
  }

  /// Produces additional instances of this task within the requested range
  /// based on its recurrence rule.
  List<CalendarTask> occurrencesWithin(DateTime rangeStart, DateTime rangeEnd) {
    final recurrence = effectiveRecurrence;
    final scheduled = scheduledTime;

    if (scheduled == null || !hasRecurrenceData) {
      return const [];
    }

    final bool hasRule = !recurrence.isNone;
    final Map<String, TaskOccurrenceOverride> overrides = occurrenceOverrides;
    final Duration rangeShift = _futureRangeBackwardShift(overrides);
    final DateTime adjustedRangeEnd = _extendRangeEnd(rangeEnd, rangeShift);
    final DateTime? ruleUntil = _recurrenceUntilLimit(recurrence);
    final DateTime? inclusiveEnd =
        hasRule ? _minDateTime(adjustedRangeEnd, ruleUntil) : null;

    if (hasRule && inclusiveEnd != null && inclusiveEnd.isBefore(scheduled)) {
      return const [];
    }

    final List<CalendarTask> results = <CalendarTask>[];
    final Set<String> exDateKeys = _calendarDateTimeKeys(recurrence.exDates);
    final Set<String> emittedKeys = <String>{};

    if (hasRule) {
      var current = scheduled;
      var generatedCount = _baseOccurrenceCount;

      while (true) {
        final DateTime? next = _nextOccurrence(current, recurrence, scheduled);
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

        final String occurrenceKey = _occurrenceKeyFromDateTime(next);
        if (emittedKeys.contains(occurrenceKey)) {
          continue;
        }
        final _OverrideResolution resolution = _resolveOccurrenceOverride(
          originalStart: next,
          occurrenceKey: occurrenceKey,
          overrides: overrides,
          exDateKeys: exDateKeys,
        );
        final TaskOccurrenceOverride? override = resolution.override;

        if (resolution.isExcluded) {
          if (next.isAfter(rangeEnd)) {
            break;
          }
          continue;
        }

        final DateTime actualStart = override?.scheduledTime ?? next;

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
            occurrenceKey: occurrenceKey,
            scheduledOverride: override?.scheduledTime,
            durationOverride: override?.duration,
            endDateOverride: override?.endDate,
            priorityOverride: override?.priority,
            completedOverride: override?.isCompleted,
            titleOverride: override?.title,
            descriptionOverride: override?.description,
            locationOverride: override?.location,
            checklistOverride: override?.checklist,
          ),
        );
        emittedKeys.add(occurrenceKey);
      }
    }

    if (recurrence.rDates.isNotEmpty) {
      for (final CalendarDateTime date in recurrence.rDates) {
        final DateTime originalStart = date.value;
        final String occurrenceKey = _occurrenceKeyFromDateTime(originalStart);
        if (!emittedKeys.add(occurrenceKey)) {
          continue;
        }
        final _OverrideResolution resolution = _resolveOccurrenceOverride(
          originalStart: originalStart,
          occurrenceKey: occurrenceKey,
          overrides: overrides,
          exDateKeys: exDateKeys,
        );
        final TaskOccurrenceOverride? override = resolution.override;
        if (resolution.isExcluded) {
          continue;
        }
        final DateTime actualStart = override?.scheduledTime ?? originalStart;
        if (actualStart.isBefore(rangeStart) || actualStart.isAfter(rangeEnd)) {
          continue;
        }
        results.add(
          _copyForOccurrence(
            originalStart: originalStart,
            occurrenceKey: occurrenceKey,
            scheduledOverride: override?.scheduledTime,
            durationOverride: override?.duration,
            endDateOverride: override?.endDate,
            priorityOverride: override?.priority,
            completedOverride: override?.isCompleted,
            titleOverride: override?.title,
            descriptionOverride: override?.description,
            locationOverride: override?.location,
            checklistOverride: override?.checklist,
          ),
        );
      }
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
    TaskPriority? priorityOverride,
    bool? completedOverride,
    String? titleOverride,
    String? descriptionOverride,
    String? locationOverride,
    List<TaskChecklistItem>? checklistOverride,
  }) {
    final actualStart = scheduledOverride ?? originalStart;
    final adjustedDuration = durationOverride ?? duration;
    final TaskPriority? resolvedPriority = priorityOverride ?? priority;
    final bool resolvedCompletion = completedOverride ?? isCompleted;

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
    } else if (endDate != null) {
      shiftedEndDate = endDate;
    }

    return copyWith(
      id: '$baseId$_occurrenceSeparator$occurrenceKey',
      scheduledTime: actualStart,
      duration: adjustedDuration,
      priority: resolvedPriority,
      isCompleted: resolvedCompletion,
      endDate: shiftedEndDate,
      title: titleOverride ?? title,
      description: descriptionOverride ?? description,
      location: locationOverride ?? location,
      checklist: checklistOverride ?? checklist,
    );
  }
}

DateTime _extendRangeEnd(DateTime rangeEnd, Duration shift) {
  if (shift == _zeroDuration) {
    return rangeEnd;
  }
  return rangeEnd.add(shift);
}

Duration _futureRangeBackwardShift(
  Map<String, TaskOccurrenceOverride> overrides,
) {
  var maxShift = _zeroDuration;
  for (final TaskOccurrenceOverride override in overrides.values) {
    final RecurrenceRange? range = override.range;
    if (range == null || !range.isThisAndFuture) {
      continue;
    }
    final DateTime? overrideStart = override.scheduledTime;
    final DateTime? originalStart = override.recurrenceId?.value;
    if (overrideStart == null || originalStart == null) {
      continue;
    }
    final Duration shift = originalStart.difference(overrideStart);
    if (shift.compareTo(_zeroDuration) <= 0) {
      continue;
    }
    if (shift.compareTo(maxShift) > 0) {
      maxShift = shift;
    }
  }
  return maxShift;
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
    case RecurrenceFrequency.yearly:
      return _addMonths(
        current,
        max(1, rule.interval) * _monthsPerYear,
        baseStart.day,
      );
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
    case RecurrenceFrequency.yearly:
      return (amount: effective, unit: RecurrenceEndUnit.years);
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
  final List<int> rawWeekdays = _resolveWeeklyDays(rule, baseStart);
  final weekdays = rawWeekdays
      .map((day) => day == DateTime.sunday ? DateTime.sunday : day)
      .toList()
    ..sort();

  final currentWeekday =
      current.weekday == DateTime.sunday ? DateTime.sunday : current.weekday;
  for (final day in weekdays) {
    if (day > currentWeekday) {
      final delta = day - currentWeekday;
      return current.add(Duration(days: delta));
    }
  }

  final firstDay = weekdays.first;
  final weeksToAdd = max(1, rule.interval);
  final daysUntilNext =
      (weeksToAdd * _daysPerWeek) - (currentWeekday - firstDay);
  return current.add(Duration(days: daysUntilNext));
}

List<int> _resolveWeeklyDays(RecurrenceRule rule, DateTime baseStart) {
  final List<int>? byWeekdays = rule.byWeekdays;
  if (byWeekdays != null && byWeekdays.isNotEmpty) {
    return byWeekdays;
  }
  final List<int>? byDays = _weekdaysFromByDays(rule.byDays);
  if (byDays != null && byDays.isNotEmpty) {
    return byDays;
  }
  return <int>[baseStart.weekday];
}

List<int>? _weekdaysFromByDays(List<RecurrenceWeekday>? byDays) {
  if (byDays == null || byDays.isEmpty) {
    return null;
  }
  final List<int> weekdays = <int>[];
  for (final RecurrenceWeekday day in byDays) {
    if (day.position != null) {
      continue;
    }
    weekdays.add(day.weekday.isoValue);
  }
  return weekdays.isEmpty ? null : weekdays;
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

DateTime? _recurrenceUntilLimit(RecurrenceRule rule) {
  final DateTime? until = rule.until;
  if (until == null) {
    return null;
  }
  if (rule.untilIsDate) {
    return _endOfDay(until);
  }
  return until;
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

String _occurrenceKeyFromDateTime(DateTime dateTime) =>
    dateTime.microsecondsSinceEpoch.toString();

Set<String> _calendarDateTimeKeys(List<CalendarDateTime> dates) {
  final Set<String> keys = <String>{};
  for (final CalendarDateTime date in dates) {
    keys.add(_occurrenceKeyFromDateTime(date.value));
  }
  return keys;
}

class _OverrideResolution {
  const _OverrideResolution({
    required this.isExcluded,
    required this.override,
  });

  final bool isExcluded;
  final TaskOccurrenceOverride? override;
}

class _RangeOverrideSelection {
  const _RangeOverrideSelection({
    required this.originalStart,
    required this.override,
  });

  final DateTime originalStart;
  final TaskOccurrenceOverride override;
}

const TaskOccurrenceOverride _emptyOverride = TaskOccurrenceOverride();
const _OverrideResolution _excludedResolution =
    _OverrideResolution(isExcluded: true, override: null);
const _OverrideResolution _noOverrideResolution =
    _OverrideResolution(isExcluded: false, override: null);

_OverrideResolution _resolveOccurrenceOverride({
  required DateTime originalStart,
  required String occurrenceKey,
  required Map<String, TaskOccurrenceOverride> overrides,
  required Set<String> exDateKeys,
}) {
  final TaskOccurrenceOverride? direct = overrides[occurrenceKey];
  if (direct?.isCancelled == true) {
    return _excludedResolution;
  }

  final bool excludedByDate = exDateKeys.contains(occurrenceKey);
  if (direct == null && excludedByDate) {
    return _excludedResolution;
  }

  final _RangeOverrideSelection? range =
      _selectRangeOverride(overrides, originalStart);
  if (direct == null && range?.override.isCancelled == true) {
    return _excludedResolution;
  }

  if (direct == null && range == null) {
    return _noOverrideResolution;
  }

  final TaskOccurrenceOverride base = range?.override ?? _emptyOverride;
  final TaskOccurrenceOverride merged = _mergeOverrides(base, direct);
  final DateTime? shiftedStart = _shiftedStartForRange(
    occurrenceStart: originalStart,
    range: range,
    direct: direct,
  );
  final DateTime? resolvedScheduledTime = shiftedStart ?? merged.scheduledTime;

  Duration? resolvedDuration = merged.duration;
  DateTime? resolvedEndDate = merged.endDate;
  if (direct?.duration == null && direct?.endDate == null && range != null) {
    final Duration? rangeDuration = _rangeDurationForOverride(
      range.override,
      range.originalStart,
    );
    if (rangeDuration != null) {
      resolvedDuration = rangeDuration;
      resolvedEndDate = null;
    }
  }

  return _OverrideResolution(
    isExcluded: false,
    override: merged.copyWith(
      scheduledTime: resolvedScheduledTime,
      duration: resolvedDuration,
      endDate: resolvedEndDate,
    ),
  );
}

_RangeOverrideSelection? _selectRangeOverride(
  Map<String, TaskOccurrenceOverride> overrides,
  DateTime occurrenceStart,
) {
  _RangeOverrideSelection? futureCandidate;
  _RangeOverrideSelection? priorCandidate;

  overrides.forEach((key, override) {
    final RecurrenceRange? range = override.range;
    if (range == null) {
      return;
    }
    final DateTime? originalStart = override.recurrenceId?.value;
    if (originalStart == null) {
      return;
    }
    if (range.isThisAndFuture) {
      if (!originalStart.isAfter(occurrenceStart)) {
        if (futureCandidate == null ||
            originalStart.isAfter(futureCandidate!.originalStart)) {
          futureCandidate = _RangeOverrideSelection(
            originalStart: originalStart,
            override: override,
          );
        }
      }
      return;
    }
    if (range.isThisAndPrior) {
      if (!originalStart.isBefore(occurrenceStart)) {
        if (priorCandidate == null ||
            originalStart.isBefore(priorCandidate!.originalStart)) {
          priorCandidate = _RangeOverrideSelection(
            originalStart: originalStart,
            override: override,
          );
        }
      }
    }
  });

  if (futureCandidate == null) {
    return priorCandidate;
  }
  if (priorCandidate == null) {
    return futureCandidate;
  }
  final int futureDistance =
      _distanceMicros(occurrenceStart, futureCandidate!.originalStart);
  final int priorDistance =
      _distanceMicros(occurrenceStart, priorCandidate!.originalStart);
  return futureDistance <= priorDistance ? futureCandidate : priorCandidate;
}

int _distanceMicros(DateTime left, DateTime right) {
  final int delta = left.microsecondsSinceEpoch - right.microsecondsSinceEpoch;
  return delta.abs();
}

DateTime? _shiftedStartForRange({
  required DateTime occurrenceStart,
  required _RangeOverrideSelection? range,
  required TaskOccurrenceOverride? direct,
}) {
  if (direct?.scheduledTime != null) {
    return direct!.scheduledTime;
  }
  if (range == null) {
    return null;
  }
  final DateTime? overrideStart = range.override.scheduledTime;
  if (overrideStart == null) {
    return null;
  }
  final Duration shift = overrideStart.difference(range.originalStart);
  return occurrenceStart.add(shift);
}

Duration? _rangeDurationForOverride(
  TaskOccurrenceOverride override,
  DateTime originalStart,
) {
  final Duration? duration = override.duration;
  if (duration != null) {
    return duration;
  }
  final DateTime? endDate = override.endDate;
  if (endDate == null) {
    return null;
  }
  final DateTime anchor = override.scheduledTime ?? originalStart;
  final Duration derived = endDate.difference(anchor);
  if (derived.compareTo(Duration.zero) <= 0) {
    return null;
  }
  return derived;
}

TaskOccurrenceOverride _mergeOverrides(
  TaskOccurrenceOverride base,
  TaskOccurrenceOverride? override,
) {
  if (override == null) {
    return base;
  }
  return TaskOccurrenceOverride(
    scheduledTime: override.scheduledTime ?? base.scheduledTime,
    duration: override.duration ?? base.duration,
    endDate: override.endDate ?? base.endDate,
    isCancelled: override.isCancelled ?? base.isCancelled,
    priority: override.priority ?? base.priority,
    isCompleted: override.isCompleted ?? base.isCompleted,
    title: override.title ?? base.title,
    description: override.description ?? base.description,
    location: override.location ?? base.location,
    checklist: override.checklist ?? base.checklist,
    recurrenceId: override.recurrenceId ?? base.recurrenceId,
    range: override.range ?? base.range,
    rawProperties: override.rawProperties.isNotEmpty
        ? override.rawProperties
        : base.rawProperties,
    rawComponents: override.rawComponents.isNotEmpty
        ? override.rawComponents
        : base.rawComponents,
  );
}
