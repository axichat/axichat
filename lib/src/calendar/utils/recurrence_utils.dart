import 'dart:math';

import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';

const _occurrenceSeparator = '::';
const int _baseOccurrenceCount = 1;
const int _daysPerWeek = 7;
const int _monthsPerYear = 12;
const int _daysInLeapYear = 366;
const int _daysInCommonYear = 365;
const int _minInterval = 1;
const int _firstMonthIndex = 1;
const int _firstDayOfMonth = 1;
const int _firstDayOfYear = 1;
const int _minDaysInFirstWeek = 4;
const int _zeroValue = 0;
const int _setPositionBase = 1;
const int _negativeIndexOffset = 1;
const Duration _weekDuration = Duration(days: _daysPerWeek);
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

extension RecurrenceRuleYearlyExpansionX on RecurrenceRule {
  bool get usesYearlyExpansion {
    if (frequency != RecurrenceFrequency.yearly) {
      return false;
    }
    return _hasRuleValues(byMonths) ||
        _hasRuleValues(byMonthDays) ||
        _hasRuleValues(byDays) ||
        _hasRuleValues(byYearDays) ||
        _hasRuleValues(byWeekNumbers) ||
        _hasRuleValues(bySetPositions);
  }
}

extension RecurrenceRuleMonthlyExpansionX on RecurrenceRule {
  bool get usesMonthlyExpansion {
    if (frequency != RecurrenceFrequency.monthly) {
      return false;
    }
    return _hasRuleValues(byMonths) ||
        _hasRuleValues(byMonthDays) ||
        _hasRuleValues(byDays) ||
        _hasRuleValues(bySetPositions);
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
      final DateTime rangeLimit = inclusiveEnd ?? rangeEnd;
      final Iterable<DateTime> generated = recurrence.usesYearlyExpansion
          ? _yearlyOccurrencesWithin(
              baseStart: scheduled,
              rule: recurrence,
              rangeEnd: rangeLimit,
            )
          : recurrence.usesMonthlyExpansion
              ? _monthlyOccurrencesWithin(
                  baseStart: scheduled,
                  rule: recurrence,
                  rangeEnd: rangeLimit,
                )
              : _simpleOccurrencesWithin(
                  baseStart: scheduled,
                  rule: recurrence,
                  rangeEnd: rangeLimit,
                );

      var generatedCount = _baseOccurrenceCount;
      for (final DateTime next in generated) {
        generatedCount += 1;

        if (recurrence.count != null && generatedCount > recurrence.count!) {
          break;
        }

        if (next.isAfter(rangeLimit)) {
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
    final DateTime? resolved = _dateTimeFromOccurrenceKey(key);
    if (resolved != null) {
      return resolved;
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
  for (final MapEntry<String, TaskOccurrenceOverride> entry
      in overrides.entries) {
    final TaskOccurrenceOverride override = entry.value;
    final RecurrenceRange? range = override.range;
    if (range == null || !range.isThisAndFuture) {
      continue;
    }
    final DateTime? overrideStart = override.scheduledTime;
    final DateTime? originalStart = _rangeOriginalStart(
      key: entry.key,
      override: override,
    );
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
      return current.add(Duration(days: max(_minInterval, rule.interval)));
    case RecurrenceFrequency.weekdays:
      return _addWeekdays(current, max(_minInterval, rule.interval));
    case RecurrenceFrequency.weekly:
      return _nextWeeklyOccurrence(current, rule, baseStart);
    case RecurrenceFrequency.monthly:
      return _addMonths(
          current, max(_minInterval, rule.interval), baseStart.day);
    case RecurrenceFrequency.yearly:
      return _addMonths(
        current,
        max(_minInterval, rule.interval) * _monthsPerYear,
        baseStart.day,
      );
  }
}

Iterable<DateTime> _simpleOccurrencesWithin({
  required DateTime baseStart,
  required RecurrenceRule rule,
  required DateTime rangeEnd,
}) {
  final List<DateTime> results = <DateTime>[];
  var current = baseStart;
  while (true) {
    final DateTime? next = _nextOccurrence(current, rule, baseStart);
    if (next == null || next.isAfter(rangeEnd)) {
      break;
    }
    results.add(next);
    current = next;
  }
  return results;
}

Iterable<DateTime> _monthlyOccurrencesWithin({
  required DateTime baseStart,
  required RecurrenceRule rule,
  required DateTime rangeEnd,
}) {
  final int interval = max(_minInterval, rule.interval);
  final List<int>? allowedMonths = _resolveMonthlyMonths(rule.byMonths);
  final List<DateTime> results = <DateTime>[];
  var current = baseStart;

  while (!current.isAfter(rangeEnd)) {
    final int year = current.year;
    final int month = current.month;
    if (allowedMonths == null || allowedMonths.contains(month)) {
      final List<DateTime> candidates = _monthlyCandidatesForMonth(
        year: year,
        month: month,
        rule: rule,
        baseStart: baseStart,
      );
      for (final DateTime candidate in candidates) {
        final bool isBaseMonth =
            year == baseStart.year && month == baseStart.month;
        if (isBaseMonth && !candidate.isAfter(baseStart)) {
          continue;
        }
        if (candidate.isAfter(rangeEnd)) {
          continue;
        }
        results.add(candidate);
      }
    }
    current = _addMonths(current, interval, baseStart.day);
  }

  results.sort();
  return results;
}

Iterable<DateTime> _yearlyOccurrencesWithin({
  required DateTime baseStart,
  required RecurrenceRule rule,
  required DateTime rangeEnd,
}) {
  final int interval = max(_minInterval, rule.interval);
  final int baseYear = baseStart.year;
  final int lastYear = rangeEnd.year;
  final List<DateTime> results = <DateTime>[];

  for (var year = baseYear; year <= lastYear; year += interval) {
    final List<DateTime> candidates = _yearlyCandidatesForYear(
      year: year,
      rule: rule,
      baseStart: baseStart,
    );
    for (final DateTime candidate in candidates) {
      if (year == baseYear && !candidate.isAfter(baseStart)) {
        continue;
      }
      if (candidate.isAfter(rangeEnd)) {
        continue;
      }
      results.add(candidate);
    }
  }

  return results;
}

List<int>? _resolveMonthlyMonths(List<int>? byMonths) {
  if (!_hasRuleValues(byMonths)) {
    return null;
  }
  final Set<int> seen = <int>{};
  for (final int month in byMonths!) {
    if (month < _firstMonthIndex || month > _monthsPerYear) {
      continue;
    }
    seen.add(month);
  }
  if (seen.isEmpty) {
    return null;
  }
  final List<int> resolved = seen.toList()..sort();
  return resolved;
}

List<DateTime> _monthlyCandidatesForMonth({
  required int year,
  required int month,
  required RecurrenceRule rule,
  required DateTime baseStart,
}) {
  final List<DateTime> candidates = <DateTime>[];
  _addMonthCandidates(
    candidates: candidates,
    year: year,
    month: month,
    rule: rule,
    baseStart: baseStart,
  );
  final List<DateTime> sorted = _uniqueSortedDates(candidates);
  if (_hasRuleValues(rule.bySetPositions)) {
    return _applySetPositions(sorted, rule.bySetPositions!);
  }
  return sorted;
}

List<DateTime> _yearlyCandidatesForYear({
  required int year,
  required RecurrenceRule rule,
  required DateTime baseStart,
}) {
  final List<DateTime> candidates = <DateTime>[];
  final List<int> months = _resolveYearlyMonths(
    byMonths: rule.byMonths,
    fallbackMonth: baseStart.month,
  );
  if (_hasRuleValues(rule.byYearDays)) {
    _addYearDayCandidates(
      candidates: candidates,
      year: year,
      rule: rule,
      months: months,
      hasByMonths: _hasRuleValues(rule.byMonths),
      baseStart: baseStart,
    );
  } else {
    for (final int month in months) {
      _addMonthCandidates(
        candidates: candidates,
        year: year,
        month: month,
        rule: rule,
        baseStart: baseStart,
      );
    }
  }

  final List<DateTime> sorted = _uniqueSortedDates(candidates);
  final List<DateTime> weekFiltered = _filterByWeekNumbers(sorted, rule);
  if (_hasRuleValues(rule.bySetPositions)) {
    return _applySetPositions(weekFiltered, rule.bySetPositions!);
  }
  return weekFiltered;
}

void _addYearDayCandidates({
  required List<DateTime> candidates,
  required int year,
  required RecurrenceRule rule,
  required List<int> months,
  required bool hasByMonths,
  required DateTime baseStart,
}) {
  final List<int> byYearDays = rule.byYearDays ?? const <int>[];
  final Set<int>? allowedWeekdays =
      _weekdaySetFromByDays(rule.byDays ?? const <RecurrenceWeekday>[]);
  for (final int yearDay in byYearDays) {
    final int? resolved = _resolveYearDay(yearDay, year);
    if (resolved == null) {
      continue;
    }
    final DateTime date = DateTime(year, DateTime.january, _firstDayOfYear)
        .add(Duration(days: resolved - _firstDayOfYear));
    if (hasByMonths && !months.contains(date.month)) {
      continue;
    }
    if (!_dayMatchesMonthDay(rule.byMonthDays, date)) {
      continue;
    }
    if (allowedWeekdays != null && !allowedWeekdays.contains(date.weekday)) {
      continue;
    }
    candidates.add(_withBaseTime(date, baseStart));
  }
}

void _addMonthCandidates({
  required List<DateTime> candidates,
  required int year,
  required int month,
  required RecurrenceRule rule,
  required DateTime baseStart,
}) {
  final int daysInMonth = _daysInMonth(year, month);
  final bool hasByDays = _hasRuleValues(rule.byDays);
  final bool hasByMonthDays = _hasRuleValues(rule.byMonthDays);
  final List<int> baseDays = _resolveBaseMonthDays(
    daysInMonth: daysInMonth,
    fallbackDay: baseStart.day,
    byMonthDays: rule.byMonthDays,
    expandForByDays: hasByDays,
  );
  final List<int> resolvedDays = hasByDays
      ? _applyByDays(
          year: year,
          month: month,
          daysInMonth: daysInMonth,
          baseDays: baseDays,
          byDays: rule.byDays ?? const <RecurrenceWeekday>[],
          hasMonthDayFilter: hasByMonthDays,
        )
      : baseDays;
  for (final int day in resolvedDays) {
    candidates.add(_withBaseTime(DateTime(year, month, day), baseStart));
  }
}

List<int> _resolveYearlyMonths({
  required List<int>? byMonths,
  required int fallbackMonth,
}) {
  final List<int> source =
      _hasRuleValues(byMonths) ? byMonths! : <int>[fallbackMonth];
  final Set<int> seen = <int>{};
  for (final int month in source) {
    if (month < _firstMonthIndex || month > _monthsPerYear) {
      continue;
    }
    seen.add(month);
  }
  if (seen.isEmpty) {
    return <int>[fallbackMonth];
  }
  final List<int> resolved = seen.toList()..sort();
  return resolved;
}

List<int> _resolveBaseMonthDays({
  required int daysInMonth,
  required int fallbackDay,
  required List<int>? byMonthDays,
  required bool expandForByDays,
}) {
  if (_hasRuleValues(byMonthDays)) {
    return _resolveMonthDays(
      byMonthDays: byMonthDays!,
      daysInMonth: daysInMonth,
    );
  }
  if (expandForByDays) {
    return _allDaysInMonth(daysInMonth);
  }
  final int day = min(fallbackDay, daysInMonth);
  return <int>[day];
}

List<int> _resolveMonthDays({
  required List<int> byMonthDays,
  required int daysInMonth,
}) {
  final Set<int> resolved = <int>{};
  for (final int day in byMonthDays) {
    final int? normalized = _resolveMonthDay(day, daysInMonth);
    if (normalized == null) {
      continue;
    }
    resolved.add(normalized);
  }
  final List<int> days = resolved.toList()..sort();
  return days;
}

List<int> _applyByDays({
  required int year,
  required int month,
  required int daysInMonth,
  required List<int> baseDays,
  required List<RecurrenceWeekday> byDays,
  required bool hasMonthDayFilter,
}) {
  final Set<int> resolvedDays = <int>{};
  final Set<int> baseDaySet = baseDays.toSet();
  final Set<int> plainWeekdays = _plainWeekdaySet(byDays);

  if (plainWeekdays.isNotEmpty) {
    for (final int day in baseDays) {
      final int weekday = DateTime(year, month, day).weekday;
      if (plainWeekdays.contains(weekday)) {
        resolvedDays.add(day);
      }
    }
  }

  for (final RecurrenceWeekday entry in byDays) {
    if (entry.position == null) {
      continue;
    }
    final int? resolved = _resolveWeekdayPosition(
      year: year,
      month: month,
      daysInMonth: daysInMonth,
      entry: entry,
    );
    if (resolved == null) {
      continue;
    }
    if (hasMonthDayFilter && !baseDaySet.contains(resolved)) {
      continue;
    }
    resolvedDays.add(resolved);
  }

  if (resolvedDays.isEmpty) {
    return const <int>[];
  }
  final List<int> days = resolvedDays.toList()..sort();
  return days;
}

int? _resolveMonthDay(int day, int daysInMonth) {
  if (day == _zeroValue) {
    return null;
  }
  if (day > _zeroValue) {
    return day > daysInMonth ? null : day;
  }
  final int resolved = daysInMonth + day + _negativeIndexOffset;
  return resolved < _firstDayOfMonth ? null : resolved;
}

int? _resolveYearDay(int day, int year) {
  if (day == _zeroValue) {
    return null;
  }
  final int daysInYear = _daysInYear(year);
  if (day > _zeroValue) {
    return day > daysInYear ? null : day;
  }
  final int resolved = daysInYear + day + _negativeIndexOffset;
  return resolved < _firstDayOfYear ? null : resolved;
}

int _daysInYear(int year) {
  final bool isLeap = (year % 4 == _zeroValue && year % 100 != _zeroValue) ||
      year % 400 == _zeroValue;
  return isLeap ? _daysInLeapYear : _daysInCommonYear;
}

int? _resolveWeekdayPosition({
  required int year,
  required int month,
  required int daysInMonth,
  required RecurrenceWeekday entry,
}) {
  final int position = entry.position ?? _zeroValue;
  if (position == _zeroValue) {
    return null;
  }
  final int weekday = entry.weekday.isoValue;
  if (position > _zeroValue) {
    final DateTime firstDate = DateTime(year, month, _firstDayOfMonth);
    final int delta =
        (weekday - firstDate.weekday + _daysPerWeek) % _daysPerWeek;
    final int day =
        _firstDayOfMonth + delta + (position - _setPositionBase) * _daysPerWeek;
    return day > daysInMonth ? null : day;
  }
  final int offset = position.abs() - _setPositionBase;
  final DateTime lastDate = DateTime(year, month, daysInMonth);
  final int delta = (lastDate.weekday - weekday + _daysPerWeek) % _daysPerWeek;
  final int day = daysInMonth - delta - (offset * _daysPerWeek);
  return day < _firstDayOfMonth ? null : day;
}

Set<int> _plainWeekdaySet(List<RecurrenceWeekday> byDays) {
  final Set<int> weekdays = <int>{};
  for (final RecurrenceWeekday entry in byDays) {
    if (entry.position != null) {
      continue;
    }
    weekdays.add(entry.weekday.isoValue);
  }
  return weekdays;
}

Set<int>? _weekdaySetFromByDays(List<RecurrenceWeekday> byDays) {
  if (byDays.isEmpty) {
    return null;
  }
  final Set<int> weekdays = <int>{};
  for (final RecurrenceWeekday entry in byDays) {
    weekdays.add(entry.weekday.isoValue);
  }
  return weekdays;
}

bool _dayMatchesMonthDay(List<int>? byMonthDays, DateTime date) {
  if (!_hasRuleValues(byMonthDays)) {
    return true;
  }
  final int daysInMonth = _daysInMonth(date.year, date.month);
  final Set<int> allowed = _resolveMonthDays(
    byMonthDays: byMonthDays!,
    daysInMonth: daysInMonth,
  ).toSet();
  return allowed.contains(date.day);
}

List<int> _allDaysInMonth(int daysInMonth) {
  return List<int>.generate(
    daysInMonth,
    (index) => index + _firstDayOfMonth,
  );
}

DateTime _withBaseTime(DateTime date, DateTime baseStart) {
  return DateTime(
    date.year,
    date.month,
    date.day,
    baseStart.hour,
    baseStart.minute,
    baseStart.second,
    baseStart.millisecond,
    baseStart.microsecond,
  );
}

List<DateTime> _uniqueSortedDates(List<DateTime> dates) {
  final Set<int> seen = <int>{};
  final List<DateTime> unique = <DateTime>[];
  for (final DateTime date in dates) {
    final int key = date.microsecondsSinceEpoch;
    if (!seen.add(key)) {
      continue;
    }
    unique.add(date);
  }
  unique.sort();
  return unique;
}

List<DateTime> _applySetPositions(
  List<DateTime> sorted,
  List<int> positions,
) {
  if (sorted.isEmpty || positions.isEmpty) {
    return sorted;
  }
  final Set<int> indexes = <int>{};
  final int length = sorted.length;
  for (final int position in positions) {
    if (position == _zeroValue) {
      continue;
    }
    final int index =
        position > _zeroValue ? position - _setPositionBase : length + position;
    if (index < _zeroValue || index >= length) {
      continue;
    }
    indexes.add(index);
  }
  if (indexes.isEmpty) {
    return const <DateTime>[];
  }
  final List<DateTime> selected = indexes.map((index) => sorted[index]).toList()
    ..sort();
  return selected;
}

List<DateTime> _filterByWeekNumbers(
  List<DateTime> dates,
  RecurrenceRule rule,
) {
  if (dates.isEmpty || !_hasRuleValues(rule.byWeekNumbers)) {
    return dates;
  }
  final CalendarWeekday weekStart = rule.weekStart ?? CalendarWeekday.monday;
  final int year = dates.first.year;
  final DateTime week1Start = _week1StartForYear(
    year: year,
    weekStart: weekStart,
  );
  final int totalWeeks = _totalWeeksInYear(
    year: year,
    weekStart: weekStart,
    week1Start: week1Start,
  );
  final Set<int> allowedWeeks = _resolveWeekNumbers(
    values: rule.byWeekNumbers!,
    totalWeeks: totalWeeks,
  );
  if (allowedWeeks.isEmpty) {
    return const <DateTime>[];
  }
  final List<DateTime> filtered = <DateTime>[];
  for (final DateTime date in dates) {
    final int weekNumber = _weekNumberForDate(
      date: date,
      weekStart: weekStart,
      week1Start: week1Start,
    );
    if (allowedWeeks.contains(weekNumber)) {
      filtered.add(date);
    }
  }
  return filtered;
}

Set<int> _resolveWeekNumbers({
  required List<int> values,
  required int totalWeeks,
}) {
  final Set<int> resolved = <int>{};
  for (final int value in values) {
    if (value == _zeroValue) {
      continue;
    }
    if (value > _zeroValue) {
      if (value <= totalWeeks) {
        resolved.add(value);
      }
      continue;
    }
    final int normalized = totalWeeks + value + _setPositionBase;
    if (normalized >= _setPositionBase && normalized <= totalWeeks) {
      resolved.add(normalized);
    }
  }
  return resolved;
}

DateTime _week1StartForYear({
  required int year,
  required CalendarWeekday weekStart,
}) {
  final DateTime yearStart = DateTime(year, DateTime.january, _firstDayOfYear);
  final DateTime weekStartDate = _startOfWeek(
    date: yearStart,
    weekStart: weekStart,
  );
  final int daysBeforeYearStart = yearStart.difference(weekStartDate).inDays;
  const int daysInWeek = _daysPerWeek;
  final int daysInFirstWeek = daysInWeek - daysBeforeYearStart;
  if (daysInFirstWeek >= _minDaysInFirstWeek) {
    return weekStartDate;
  }
  return weekStartDate.add(_weekDuration);
}

DateTime _startOfWeek({
  required DateTime date,
  required CalendarWeekday weekStart,
}) {
  final int startWeekday = weekStart.isoValue;
  final int delta = (date.weekday - startWeekday + _daysPerWeek) % _daysPerWeek;
  return date.subtract(Duration(days: delta));
}

int _weekNumberForDate({
  required DateTime date,
  required CalendarWeekday weekStart,
  required DateTime week1Start,
}) {
  final DateTime weekStartDate = _startOfWeek(
    date: date,
    weekStart: weekStart,
  );
  final int diffDays = weekStartDate.difference(week1Start).inDays;
  final int weekIndex = diffDays ~/ _daysPerWeek;
  return weekIndex + _setPositionBase;
}

int _totalWeeksInYear({
  required int year,
  required CalendarWeekday weekStart,
  required DateTime week1Start,
}) {
  final int lastDay = _daysInMonth(year, DateTime.december);
  final DateTime lastDate = DateTime(year, DateTime.december, lastDay);
  final int lastWeek = _weekNumberForDate(
    date: lastDate,
    weekStart: weekStart,
    week1Start: week1Start,
  );
  return max(lastWeek, _setPositionBase);
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

DateTime? _dateTimeFromOccurrenceKey(String key) {
  final int? micros = int.tryParse(key);
  if (micros == null) {
    return null;
  }
  return DateTime.fromMicrosecondsSinceEpoch(micros);
}

DateTime? _rangeOriginalStart({
  required String key,
  required TaskOccurrenceOverride override,
}) {
  return override.recurrenceId?.value ?? _dateTimeFromOccurrenceKey(key);
}

Set<String> _calendarDateTimeKeys(List<CalendarDateTime> dates) {
  final Set<String> keys = <String>{};
  for (final CalendarDateTime date in dates) {
    keys.add(_occurrenceKeyFromDateTime(date.value));
  }
  return keys;
}

bool _hasRuleValues<T>(List<T>? values) => values != null && values.isNotEmpty;

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
    final DateTime? originalStart = _rangeOriginalStart(
      key: key,
      override: override,
    );
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
