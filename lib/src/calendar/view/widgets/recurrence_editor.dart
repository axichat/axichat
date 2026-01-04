// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/deadline_picker_field.dart';
import 'package:axichat/src/calendar/view/widgets/task_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const String _recurrenceFrequencyYearlyLabel = 'Yearly';
const String _recurrenceIntervalYearLabel = 'year(s)';
const String _recurrenceRepeatEveryLabel = 'Repeat every';
const String _recurrenceAdvancedLabel = 'Advanced rules';
const String _recurrenceAdvancedSummary = 'Advanced rules applied';
const String _recurrenceAdvancedActiveLabel = 'Active';
const String _recurrenceAdvancedAddTooltip = 'Add';
const String _recurrenceAdvancedByDayLabel = 'Weekday rules';
const String _recurrenceAdvancedByDayHelper =
    'Add weekday rules like every Monday or 1st Friday.';
const String _recurrenceAdvancedMonthsLabel = 'Months';
const String _recurrenceAdvancedMonthDaysLabel = 'Month days';
const String _recurrenceAdvancedYearDaysLabel = 'Year days';
const String _recurrenceAdvancedWeekNumbersLabel = 'Week numbers';
const String _recurrenceAdvancedSetPositionsLabel = 'Set positions';
const String _recurrenceAdvancedRDatesLabel = 'Additional dates';
const String _recurrenceAdvancedExDatesLabel = 'Excluded dates';
const String _recurrenceAdvancedNumberHint = 'e.g. 1, 15, -1';
const String _recurrenceAdvancedMonthDaysHint = _recurrenceAdvancedNumberHint;
const String _recurrenceAdvancedYearDaysHint = 'e.g. 1, 120, -1';
const String _recurrenceAdvancedWeekNumbersHint = 'e.g. 1, 20, -1';
const String _recurrenceAdvancedSetPositionsHint = 'e.g. 1, -1';
const String _recurrenceAdvancedRDatesHint = 'Pick a date to add';
const String _recurrenceAdvancedExDatesHint = 'Pick a date to exclude';
const String _recurrenceAdvancedTimeSummaryLabel = 'Time filters';
const String _recurrenceTimeHoursLabel = 'Hours';
const String _recurrenceTimeMinutesLabel = 'Minutes';
const String _recurrenceTimeSecondsLabel = 'Seconds';
const String _recurrenceLabelSpacer = ' ';
const String _recurrenceValueSeparator = ', ';
const String _recurrenceValuePadChar = '0';
const String _recurrenceEveryKey = 'every';
const String _recurrenceEndHeaderLabel = 'Ends';
const String _recurrenceEndModeNeverLabel = 'Never';
const String _recurrenceEndModeUntilLabel = 'On date';
const String _recurrenceEndModeCountLabel = 'After';
const String _recurrenceEndModeDerivedUntilLabel = 'Ends on';
const String _recurrenceEndModeDerivedCountLabel = '≈';
const String _recurrenceEndModeDerivedCountSuffix = 'occurrences';
const String _recurrenceNumberSplitPattern = r'[,\s]+';
const String _recurrenceMonthLabelJan = 'Jan';
const String _recurrenceMonthLabelFeb = 'Feb';
const String _recurrenceMonthLabelMar = 'Mar';
const String _recurrenceMonthLabelApr = 'Apr';
const String _recurrenceMonthLabelMay = 'May';
const String _recurrenceMonthLabelJun = 'Jun';
const String _recurrenceMonthLabelJul = 'Jul';
const String _recurrenceMonthLabelAug = 'Aug';
const String _recurrenceMonthLabelSep = 'Sep';
const String _recurrenceMonthLabelOct = 'Oct';
const String _recurrenceMonthLabelNov = 'Nov';
const String _recurrenceMonthLabelDec = 'Dec';
const String _recurrenceOrdinalEveryLabel = 'Every';
const String _recurrenceOrdinalFirstLabel = '1st';
const String _recurrenceOrdinalSecondLabel = '2nd';
const String _recurrenceOrdinalThirdLabel = '3rd';
const String _recurrenceOrdinalFourthLabel = '4th';
const String _recurrenceOrdinalFifthLabel = '5th';
const String _recurrenceOrdinalLastLabel = 'Last';
const String _recurrenceOrdinalSecondLastLabel = '2nd last';
const String _recurrenceOrdinalThirdLastLabel = '3rd last';
const String _recurrenceOrdinalFourthLastLabel = '4th last';
const String _recurrenceOrdinalFifthLastLabel = '5th last';
const String _recurrenceWeekdayShortMon = 'Mon';
const String _recurrenceWeekdayShortTue = 'Tue';
const String _recurrenceWeekdayShortWed = 'Wed';
const String _recurrenceWeekdayShortThu = 'Thu';
const String _recurrenceWeekdayShortFri = 'Fri';
const String _recurrenceWeekdayShortSat = 'Sat';
const String _recurrenceWeekdayShortSun = 'Sun';
const String _recurrenceWeekdayLongMonday = 'Monday';
const String _recurrenceWeekdayLongTuesday = 'Tuesday';
const String _recurrenceWeekdayLongWednesday = 'Wednesday';
const String _recurrenceWeekdayLongThursday = 'Thursday';
const String _recurrenceWeekdayLongFriday = 'Friday';
const String _recurrenceWeekdayLongSaturday = 'Saturday';
const String _recurrenceWeekdayLongSunday = 'Sunday';

const int _recurrenceMonthMin = 1;
const int _recurrenceMonthMax = 12;
const int _recurrenceMonthDayMax = 31;
const int _recurrenceYearDayMax = 366;
const int _recurrenceWeekNumberMax = 53;
const int _recurrenceSetPositionMax = 366;
const int _recurrenceOrdinalMax = 53;
const int _recurrenceOrdinalEveryValue = 0;
const int _recurrenceHourMax = 23;
const int _recurrenceMinuteMax = 59;
const int _recurrenceSecondMax = 59;
const double _recurrenceCompactRadius = 10;
const double _recurrenceSmallFontSize = 10;
const double _recurrenceHelperFontSize = 11;
const double _recurrenceBodyFontSize = 12;
const double _recurrenceInputHintFontSize = 13;
const double _recurrenceIconTinySize = 14;
const double _recurrenceIconSmallSize = 16;
const double _recurrenceIconMediumSize = 18;
const double _recurrenceEndInputVerticalPadding = 10;
const double _recurrenceLabelLetterSpacing = 0.4;

const List<CalendarWeekday> _orderedWeekdays = <CalendarWeekday>[
  CalendarWeekday.monday,
  CalendarWeekday.tuesday,
  CalendarWeekday.wednesday,
  CalendarWeekday.thursday,
  CalendarWeekday.friday,
  CalendarWeekday.saturday,
  CalendarWeekday.sunday,
];

class _MonthOption {
  const _MonthOption({
    required this.value,
    required this.label,
  });

  final int value;
  final String label;
}

const List<_MonthOption> _monthOptions = <_MonthOption>[
  _MonthOption(value: 1, label: _recurrenceMonthLabelJan),
  _MonthOption(value: 2, label: _recurrenceMonthLabelFeb),
  _MonthOption(value: 3, label: _recurrenceMonthLabelMar),
  _MonthOption(value: 4, label: _recurrenceMonthLabelApr),
  _MonthOption(value: 5, label: _recurrenceMonthLabelMay),
  _MonthOption(value: 6, label: _recurrenceMonthLabelJun),
  _MonthOption(value: 7, label: _recurrenceMonthLabelJul),
  _MonthOption(value: 8, label: _recurrenceMonthLabelAug),
  _MonthOption(value: 9, label: _recurrenceMonthLabelSep),
  _MonthOption(value: 10, label: _recurrenceMonthLabelOct),
  _MonthOption(value: 11, label: _recurrenceMonthLabelNov),
  _MonthOption(value: 12, label: _recurrenceMonthLabelDec),
];

class _OrdinalOption {
  const _OrdinalOption({
    required this.position,
    required this.label,
  });

  final int? position;
  final String label;
}

const List<_OrdinalOption> _ordinalOptions = <_OrdinalOption>[
  _OrdinalOption(position: null, label: _recurrenceOrdinalEveryLabel),
  _OrdinalOption(position: 1, label: _recurrenceOrdinalFirstLabel),
  _OrdinalOption(position: 2, label: _recurrenceOrdinalSecondLabel),
  _OrdinalOption(position: 3, label: _recurrenceOrdinalThirdLabel),
  _OrdinalOption(position: 4, label: _recurrenceOrdinalFourthLabel),
  _OrdinalOption(position: 5, label: _recurrenceOrdinalFifthLabel),
  _OrdinalOption(position: -1, label: _recurrenceOrdinalLastLabel),
  _OrdinalOption(position: -2, label: _recurrenceOrdinalSecondLastLabel),
  _OrdinalOption(position: -3, label: _recurrenceOrdinalThirdLastLabel),
  _OrdinalOption(position: -4, label: _recurrenceOrdinalFourthLastLabel),
  _OrdinalOption(position: -5, label: _recurrenceOrdinalFifthLastLabel),
];

extension CalendarWeekdayLabelX on CalendarWeekday {
  String get shortLabel => switch (this) {
        CalendarWeekday.monday => _recurrenceWeekdayShortMon,
        CalendarWeekday.tuesday => _recurrenceWeekdayShortTue,
        CalendarWeekday.wednesday => _recurrenceWeekdayShortWed,
        CalendarWeekday.thursday => _recurrenceWeekdayShortThu,
        CalendarWeekday.friday => _recurrenceWeekdayShortFri,
        CalendarWeekday.saturday => _recurrenceWeekdayShortSat,
        CalendarWeekday.sunday => _recurrenceWeekdayShortSun,
      };

  String get longLabel => switch (this) {
        CalendarWeekday.monday => _recurrenceWeekdayLongMonday,
        CalendarWeekday.tuesday => _recurrenceWeekdayLongTuesday,
        CalendarWeekday.wednesday => _recurrenceWeekdayLongWednesday,
        CalendarWeekday.thursday => _recurrenceWeekdayLongThursday,
        CalendarWeekday.friday => _recurrenceWeekdayLongFriday,
        CalendarWeekday.saturday => _recurrenceWeekdayLongSaturday,
        CalendarWeekday.sunday => _recurrenceWeekdayLongSunday,
      };
}

extension RecurrenceFrequencyX on RecurrenceFrequency {
  bool get isNone => this == RecurrenceFrequency.none;

  bool get isWeekly => this == RecurrenceFrequency.weekly;

  bool get isMonthly => this == RecurrenceFrequency.monthly;

  bool get isYearly => this == RecurrenceFrequency.yearly;

  bool get isMonthlyOrYearly => isMonthly || isYearly;
}

class RecurrenceFormValue {
  const RecurrenceFormValue({
    this.frequency = RecurrenceFrequency.none,
    this.interval = 1,
    Set<int>? weekdays,
    this.until,
    this.count,
    List<RecurrenceWeekday>? byDays,
    List<int>? byMonthDays,
    List<int>? byYearDays,
    List<int>? byWeekNumbers,
    List<int>? byMonths,
    List<int>? bySetPositions,
    List<CalendarDateTime>? rDates,
    List<CalendarDateTime>? exDates,
    List<int>? byHours,
    List<int>? byMinutes,
    List<int>? bySeconds,
  })  : weekdays = weekdays ?? const <int>{},
        byDays = byDays ?? const <RecurrenceWeekday>[],
        byMonthDays = byMonthDays ?? const <int>[],
        byYearDays = byYearDays ?? const <int>[],
        byWeekNumbers = byWeekNumbers ?? const <int>[],
        byMonths = byMonths ?? const <int>[],
        bySetPositions = bySetPositions ?? const <int>[],
        rDates = rDates ?? const <CalendarDateTime>[],
        exDates = exDates ?? const <CalendarDateTime>[],
        byHours = byHours ?? const <int>[],
        byMinutes = byMinutes ?? const <int>[],
        bySeconds = bySeconds ?? const <int>[];

  factory RecurrenceFormValue.fromRule(RecurrenceRule? rule) {
    if (rule == null || rule.frequency.isNone) {
      return const RecurrenceFormValue();
    }

    final List<RecurrenceWeekday> ruleByDays = List<RecurrenceWeekday>.from(
      rule.byDays ?? const <RecurrenceWeekday>[],
    );
    final Set<int> derivedWeekdays = _weekdaySetFromRule(rule, ruleByDays);
    final List<RecurrenceWeekday> advancedByDays =
        _advancedByDaysForFrequency(rule.frequency, ruleByDays);

    return RecurrenceFormValue(
      frequency: rule.frequency,
      interval: rule.interval,
      weekdays: derivedWeekdays,
      until: rule.count != null ? null : rule.until,
      count: rule.count,
      byDays: advancedByDays,
      byMonthDays: List<int>.from(rule.byMonthDays ?? const <int>[]),
      byYearDays: List<int>.from(rule.byYearDays ?? const <int>[]),
      byWeekNumbers: List<int>.from(rule.byWeekNumbers ?? const <int>[]),
      byMonths: List<int>.from(rule.byMonths ?? const <int>[]),
      bySetPositions: List<int>.from(rule.bySetPositions ?? const <int>[]),
      rDates: List<CalendarDateTime>.from(rule.rDates),
      exDates: List<CalendarDateTime>.from(rule.exDates),
      byHours: List<int>.from(rule.byHours ?? const <int>[]),
      byMinutes: List<int>.from(rule.byMinutes ?? const <int>[]),
      bySeconds: List<int>.from(rule.bySeconds ?? const <int>[]),
    );
  }

  final RecurrenceFrequency frequency;
  final int interval;
  final Set<int> weekdays;
  final DateTime? until;
  final int? count;
  final List<RecurrenceWeekday> byDays;
  final List<int> byMonthDays;
  final List<int> byYearDays;
  final List<int> byWeekNumbers;
  final List<int> byMonths;
  final List<int> bySetPositions;
  final List<CalendarDateTime> rDates;
  final List<CalendarDateTime> exDates;
  final List<int> byHours;
  final List<int> byMinutes;
  final List<int> bySeconds;

  bool get isActive => !frequency.isNone;

  bool get hasAdvancedData =>
      byDays.isNotEmpty ||
      byMonthDays.isNotEmpty ||
      byYearDays.isNotEmpty ||
      byWeekNumbers.isNotEmpty ||
      byMonths.isNotEmpty ||
      bySetPositions.isNotEmpty ||
      rDates.isNotEmpty ||
      exDates.isNotEmpty ||
      byHours.isNotEmpty ||
      byMinutes.isNotEmpty ||
      bySeconds.isNotEmpty;

  RecurrenceFormValue resolveLinkedLimits(DateTime? start) {
    if (start == null || !isActive) {
      return this;
    }
    if (count == null || until != null) {
      return this;
    }

    final _RecurrenceLimitSolver solver = _RecurrenceLimitSolver(start, this);
    final DateTime? derivedUntil = solver.untilForCount(count!);
    if (derivedUntil == null || derivedUntil == until) {
      return this;
    }

    return copyWith(until: derivedUntil);
  }

  RecurrenceFormValue copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    Set<int>? weekdays,
    DateTime? until,
    bool clearUntil = false,
    int? count,
    bool clearCount = false,
    List<RecurrenceWeekday>? byDays,
    List<int>? byMonthDays,
    List<int>? byYearDays,
    List<int>? byWeekNumbers,
    List<int>? byMonths,
    List<int>? bySetPositions,
    List<CalendarDateTime>? rDates,
    List<CalendarDateTime>? exDates,
    List<int>? byHours,
    List<int>? byMinutes,
    List<int>? bySeconds,
  }) {
    return RecurrenceFormValue(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      until: clearUntil ? null : until ?? this.until,
      count: clearCount ? null : count ?? this.count,
      byDays: byDays ?? this.byDays,
      byMonthDays: byMonthDays ?? this.byMonthDays,
      byYearDays: byYearDays ?? this.byYearDays,
      byWeekNumbers: byWeekNumbers ?? this.byWeekNumbers,
      byMonths: byMonths ?? this.byMonths,
      bySetPositions: bySetPositions ?? this.bySetPositions,
      rDates: rDates ?? this.rDates,
      exDates: exDates ?? this.exDates,
      byHours: byHours ?? this.byHours,
      byMinutes: byMinutes ?? this.byMinutes,
      bySeconds: bySeconds ?? this.bySeconds,
    );
  }

  RecurrenceRule? toRule({required DateTime start}) {
    final RecurrenceFormValue normalized = resolveLinkedLimits(start);
    if (normalized.frequency.isNone) {
      return null;
    }

    final DateTime? effectiveUntil =
        normalized.count != null ? null : normalized.until;
    final List<RecurrenceWeekday> normalizedByDays =
        _normalizeByDays(normalized.byDays);
    final List<int> normalizedByMonths = _normalizeNumericList(
      normalized.byMonths,
      min: _recurrenceMonthMin,
      max: _recurrenceMonthMax,
      allowNegative: false,
    );
    final List<int> normalizedByMonthDays = _normalizeNumericList(
      normalized.byMonthDays,
      min: _recurrenceMonthMin,
      max: _recurrenceMonthDayMax,
      allowNegative: true,
    );
    final List<int> normalizedByYearDays = _normalizeNumericList(
      normalized.byYearDays,
      min: _recurrenceMonthMin,
      max: _recurrenceYearDayMax,
      allowNegative: true,
    );
    final List<int> normalizedByWeekNumbers = _normalizeNumericList(
      normalized.byWeekNumbers,
      min: _recurrenceMonthMin,
      max: _recurrenceWeekNumberMax,
      allowNegative: true,
    );
    final List<int> normalizedBySetPositions = _normalizeNumericList(
      normalized.bySetPositions,
      min: _recurrenceMonthMin,
      max: _recurrenceSetPositionMax,
      allowNegative: true,
    );
    final List<CalendarDateTime> normalizedRDates =
        _normalizeDateTimes(normalized.rDates);
    final List<CalendarDateTime> normalizedExDates =
        _normalizeDateTimes(normalized.exDates);
    final List<int> normalizedByHours = _normalizeNumericList(
      normalized.byHours,
      min: 0,
      max: _recurrenceHourMax,
      allowNegative: false,
    );
    final List<int> normalizedByMinutes = _normalizeNumericList(
      normalized.byMinutes,
      min: 0,
      max: _recurrenceMinuteMax,
      allowNegative: false,
    );
    final List<int> normalizedBySeconds = _normalizeNumericList(
      normalized.bySeconds,
      min: 0,
      max: _recurrenceSecondMax,
      allowNegative: false,
    );

    List<RecurrenceWeekday>? resolvedByDays;
    List<int>? resolvedByWeekdays;
    if (normalized.frequency.isWeekly) {
      final List<RecurrenceWeekday> mergedByDays =
          _mergeWeekdaysIntoByDays(normalizedByDays, normalized.weekdays);
      if (mergedByDays.isNotEmpty) {
        resolvedByDays = mergedByDays;
      } else {
        final List<int> normalizedWeekdays =
            _normalizeWeekdayList(normalized.weekdays);
        resolvedByWeekdays = normalizedWeekdays.isEmpty
            ? _normalizeWeekdayList(<int>[start.weekday])
            : normalizedWeekdays;
      }
    } else if (normalizedByDays.isNotEmpty) {
      resolvedByDays = normalizedByDays;
    }

    RecurrenceRule buildRule({
      required RecurrenceFrequency frequency,
      List<int>? byWeekdays,
      List<RecurrenceWeekday>? byDays,
    }) {
      return RecurrenceRule(
        frequency: frequency,
        interval: normalized.interval,
        byWeekdays: byWeekdays,
        until: effectiveUntil,
        count: normalized.count,
        bySeconds: normalizedBySeconds.isEmpty ? null : normalizedBySeconds,
        byMinutes: normalizedByMinutes.isEmpty ? null : normalizedByMinutes,
        byHours: normalizedByHours.isEmpty ? null : normalizedByHours,
        byDays: byDays,
        byMonthDays:
            normalizedByMonthDays.isEmpty ? null : normalizedByMonthDays,
        byYearDays: normalizedByYearDays.isEmpty ? null : normalizedByYearDays,
        byWeekNumbers:
            normalizedByWeekNumbers.isEmpty ? null : normalizedByWeekNumbers,
        byMonths: normalizedByMonths.isEmpty ? null : normalizedByMonths,
        bySetPositions:
            normalizedBySetPositions.isEmpty ? null : normalizedBySetPositions,
        rDates: normalizedRDates,
        exDates: normalizedExDates,
      );
    }

    switch (normalized.frequency) {
      case RecurrenceFrequency.none:
        return null;
      case RecurrenceFrequency.daily:
        return buildRule(
          frequency: RecurrenceFrequency.daily,
        );
      case RecurrenceFrequency.weekdays:
        return buildRule(
          frequency: RecurrenceFrequency.weekdays,
          byWeekdays: _normalizeWeekdayList(const <int>[
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ]),
        );
      case RecurrenceFrequency.weekly:
        return buildRule(
          frequency: RecurrenceFrequency.weekly,
          byWeekdays: resolvedByWeekdays,
          byDays: resolvedByDays,
        );
      case RecurrenceFrequency.monthly:
        return buildRule(
          frequency: RecurrenceFrequency.monthly,
          byDays: resolvedByDays,
        );
      case RecurrenceFrequency.yearly:
        return buildRule(
          frequency: RecurrenceFrequency.yearly,
          byDays: resolvedByDays,
        );
    }
  }
}

Set<int> _weekdaySetFromRule(
  RecurrenceRule rule,
  List<RecurrenceWeekday> byDays,
) {
  final List<int>? byWeekdays = rule.byWeekdays;
  if (byWeekdays != null && byWeekdays.isNotEmpty) {
    return Set<int>.from(byWeekdays);
  }
  final Set<int> derived = <int>{};
  for (final RecurrenceWeekday entry in byDays) {
    if (entry.position != null) {
      continue;
    }
    derived.add(entry.weekday.isoValue);
  }
  return derived;
}

List<RecurrenceWeekday> _advancedByDaysForFrequency(
  RecurrenceFrequency frequency,
  List<RecurrenceWeekday> byDays,
) {
  if (byDays.isEmpty) {
    return const <RecurrenceWeekday>[];
  }
  if (frequency.isWeekly) {
    final List<RecurrenceWeekday> advanced =
        byDays.where((entry) => entry.position != null).toList(growable: false);
    return advanced;
  }
  return List<RecurrenceWeekday>.from(byDays);
}

List<RecurrenceWeekday> _mergeWeekdaysIntoByDays(
  List<RecurrenceWeekday> byDays,
  Set<int> weekdays,
) {
  if (byDays.isEmpty) {
    return const <RecurrenceWeekday>[];
  }
  final List<RecurrenceWeekday> merged = <RecurrenceWeekday>[
    ...byDays,
  ];
  final Set<String> seen = <String>{};
  for (final RecurrenceWeekday entry in merged) {
    final int? position = _normalizeOrdinal(entry.position);
    final String key =
        '${entry.weekday.icsValue}:${position ?? _recurrenceEveryKey}';
    seen.add(key);
  }
  for (final int weekday in weekdays) {
    final CalendarWeekday normalized = CalendarWeekday.fromIsoValue(weekday);
    final String key = '${normalized.icsValue}:$_recurrenceEveryKey';
    if (!seen.add(key)) {
      continue;
    }
    merged.add(RecurrenceWeekday(weekday: normalized));
  }
  return _normalizeByDays(merged);
}

int? _normalizeOrdinal(int? value) {
  if (value == null || value == 0) {
    return null;
  }
  if (value.abs() > _recurrenceOrdinalMax) {
    return null;
  }
  return value;
}

List<RecurrenceWeekday> _normalizeByDays(List<RecurrenceWeekday> values) {
  if (values.isEmpty) {
    return const <RecurrenceWeekday>[];
  }
  final Map<String, RecurrenceWeekday> unique = <String, RecurrenceWeekday>{};
  for (final RecurrenceWeekday entry in values) {
    final int? position = _normalizeOrdinal(entry.position);
    final String key =
        '${entry.weekday.icsValue}:${position ?? _recurrenceEveryKey}';
    unique[key] = RecurrenceWeekday(
      weekday: entry.weekday,
      position: position,
    );
  }
  final List<RecurrenceWeekday> normalized = unique.values.toList();
  normalized.sort((a, b) {
    final int positionA = a.position ?? 0;
    final int positionB = b.position ?? 0;
    if (positionA != positionB) {
      return positionA.compareTo(positionB);
    }
    return a.weekday.isoValue.compareTo(b.weekday.isoValue);
  });
  return normalized;
}

List<int> _normalizeNumericList(
  List<int> values, {
  required int min,
  required int max,
  required bool allowNegative,
}) {
  if (values.isEmpty) {
    return const <int>[];
  }
  final Set<int> unique = <int>{};
  for (final int value in values) {
    if (value == 0) {
      continue;
    }
    if (!allowNegative && value < 0) {
      continue;
    }
    final int absValue = value.abs();
    if (absValue < min || absValue > max) {
      continue;
    }
    unique.add(value);
  }
  final List<int> normalized = unique.toList()..sort();
  return normalized;
}

List<int> _normalizeWeekdayList(Iterable<int> values) {
  final Set<int> unique = <int>{};
  for (final int value in values) {
    if (value < DateTime.monday || value > DateTime.sunday) {
      continue;
    }
    unique.add(value);
  }
  final List<int> normalized = unique.toList()..sort();
  return normalized;
}

List<CalendarDateTime> _normalizeDateTimes(List<CalendarDateTime> values) {
  if (values.isEmpty) {
    return const <CalendarDateTime>[];
  }
  final Map<int, CalendarDateTime> unique = <int, CalendarDateTime>{};
  for (final CalendarDateTime entry in values) {
    unique[entry.value.microsecondsSinceEpoch] = entry;
  }
  final List<CalendarDateTime> normalized = unique.values.toList()
    ..sort(
      (a, b) => a.value.compareTo(b.value),
    );
  return normalized;
}

class RecurrenceEditorSpacing {
  const RecurrenceEditorSpacing({
    this.chipSpacing = 6,
    this.chipRunSpacing = 6,
    this.weekdaySpacing = 10,
    this.advancedSectionSpacing = 12,
    this.endSpacing = 14,
    this.fieldGap = 12,
  });

  final double chipSpacing;
  final double chipRunSpacing;
  final double weekdaySpacing;
  final double advancedSectionSpacing;
  final double endSpacing;
  final double fieldGap;
}

class RecurrenceEditor extends StatefulWidget {
  const RecurrenceEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.fallbackWeekday,
    this.referenceStart,
    this.spacing = const RecurrenceEditorSpacing(),
    this.showAdvancedToggle = true,
    this.forceAdvanced = false,
    this.chipPadding = const EdgeInsets.symmetric(
        horizontal: calendarGutterMd, vertical: calendarGutterSm),
    this.weekdayChipPadding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.intervalSelectWidth = 120,
  });

  final RecurrenceFormValue value;
  final ValueChanged<RecurrenceFormValue> onChanged;
  final bool enabled;
  final int? fallbackWeekday;
  final DateTime? referenceStart;
  final RecurrenceEditorSpacing spacing;
  final bool showAdvancedToggle;
  final bool forceAdvanced;
  final EdgeInsets chipPadding;
  final EdgeInsets weekdayChipPadding;
  final double intervalSelectWidth;

  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<RecurrenceEditor> {
  late TextEditingController _countController;
  bool _advancedExpanded = false;

  RecurrenceFormValue get value => widget.value;

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(
      text: value.count?.toString() ?? '',
    );
    _advancedExpanded = widget.forceAdvanced || value.hasAdvancedData;
  }

  @override
  void didUpdateWidget(covariant RecurrenceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value.count != widget.value.count &&
        _countController.text != (widget.value.count?.toString() ?? '')) {
      _countController.text = widget.value.count?.toString() ?? '';
    }
    if (!_advancedExpanded && widget.value.hasAdvancedData) {
      _advancedExpanded = true;
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final selectedFrequency = value.frequency;
    final spacing = widget.spacing;
    final DateTime? referenceStart = widget.referenceStart;
    final bool showAdvancedToggle = widget.showAdvancedToggle;
    final bool forceAdvanced = widget.forceAdvanced;
    final bool hasAdvancedData = value.hasAdvancedData;
    final bool isAdvancedVisible = forceAdvanced || _advancedExpanded;
    final bool canToggleAdvanced = showAdvancedToggle && !forceAdvanced;
    final children = <Widget>[
      Wrap(
        spacing: spacing.chipSpacing,
        runSpacing: spacing.chipRunSpacing,
        children: RecurrenceFrequency.values
            .map(
              (freq) => _RecurrenceFrequencyChip(
                isSelected: selectedFrequency == freq,
                enabled: enabled,
                padding: widget.chipPadding,
                label: _frequencyLabel(freq),
                onPressed: enabled
                    ? () => widget.onChanged(
                          _normalizedForFrequency(freq),
                        )
                    : null,
              ),
            )
            .toList(),
      ),
    ];

    if (selectedFrequency.isWeekly) {
      children
        ..add(SizedBox(height: spacing.weekdaySpacing))
        ..add(
          _RecurrenceWeekdaySelector(
            enabled: enabled,
            padding: widget.weekdayChipPadding,
            selectedWeekdays: value.weekdays,
            onWeekdayToggled: _toggleWeekday,
          ),
        );
    }

    if (!selectedFrequency.isNone) {
      children
        ..add(SizedBox(height: spacing.advancedSectionSpacing))
        ..add(
          _RecurrenceIntervalRow(
            enabled: enabled,
            currentInterval: value.interval,
            intervalWidth: widget.intervalSelectWidth,
            fieldGap: spacing.fieldGap,
            unitLabel: _intervalUnitLabel(value.frequency),
            onIntervalChanged: (newValue) =>
                widget.onChanged(value.copyWith(interval: newValue)),
          ),
        )
        ..add(SizedBox(height: spacing.endSpacing))
        ..add(
          _RecurrenceEndControls(
            enabled: enabled,
            value: value,
            referenceStart: referenceStart,
            countController: _countController,
            onModeChanged: (mode) {
              if (!enabled) {
                return;
              }
              switch (mode) {
                case _RecurrenceEndMode.never:
                  widget.onChanged(
                    value.copyWith(
                      clearCount: true,
                      clearUntil: true,
                    ),
                  );
                  break;
                case _RecurrenceEndMode.until:
                  widget.onChanged(
                    value.copyWith(
                      clearCount: true,
                    ),
                  );
                  break;
                case _RecurrenceEndMode.count:
                  widget.onChanged(
                    value.copyWith(
                      clearUntil: true,
                    ),
                  );
                  break;
              }
            },
            onUntilChanged: (selected) {
              widget.onChanged(
                value.copyWith(
                  until: selected == null
                      ? null
                      : DateTime(
                          selected.year,
                          selected.month,
                          selected.day,
                        ),
                  clearCount: true,
                ),
              );
            },
            onCountChanged: (text) {
              final parsed = int.tryParse(text);
              widget.onChanged(
                value.copyWith(
                  count: parsed != null && parsed > 0 ? parsed : null,
                  clearUntil: parsed != null && parsed > 0,
                ),
              );
            },
          ),
        );
    }

    if (!selectedFrequency.isNone && (showAdvancedToggle || forceAdvanced)) {
      children
        ..add(SizedBox(height: spacing.advancedSectionSpacing))
        ..add(
          _RecurrenceAdvancedToggle(
            isExpanded: isAdvancedVisible,
            hasAdvancedData: hasAdvancedData,
            onPressed: canToggleAdvanced ? _toggleAdvanced : null,
          ),
        );
      if (isAdvancedVisible) {
        children
          ..add(SizedBox(height: spacing.advancedSectionSpacing))
          ..add(
            _RecurrenceAdvancedFields(
              enabled: enabled,
              referenceStart: referenceStart,
              value: value,
              onChanged: widget.onChanged,
            ),
          );
      } else if (hasAdvancedData) {
        children
          ..add(const SizedBox(height: calendarInsetSm))
          ..add(const _RecurrenceAdvancedSummary());
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  void _toggleAdvanced() {
    setState(() {
      _advancedExpanded = !_advancedExpanded;
    });
  }

  RecurrenceFormValue _normalizedForFrequency(RecurrenceFrequency frequency) {
    var result = value.copyWith(
      frequency: frequency,
      interval: 1,
    );

    if (frequency.isNone) {
      result = result.copyWith(
        clearCount: true,
        clearUntil: true,
        weekdays: const <int>{},
        byDays: const <RecurrenceWeekday>[],
        byMonthDays: const <int>[],
        byYearDays: const <int>[],
        byWeekNumbers: const <int>[],
        byMonths: const <int>[],
        bySetPositions: const <int>[],
        rDates: const <CalendarDateTime>[],
        exDates: const <CalendarDateTime>[],
        byHours: const <int>[],
        byMinutes: const <int>[],
        bySeconds: const <int>[],
      );
    }

    if (frequency.isWeekly) {
      if (result.weekdays.isEmpty) {
        final fallback = widget.fallbackWeekday ?? DateTime.now().weekday;
        result = result.copyWith(weekdays: {fallback});
      }
    } else {
      result = result.copyWith(weekdays: const <int>{});
    }

    return result;
  }

  void _toggleWeekday(int weekday) {
    final current = value.weekdays;
    final updated = current.contains(weekday)
        ? (current.length == 1
            ? current
            : (Set<int>.from(current)..remove(weekday)))
        : (Set<int>.from(current)..add(weekday));

    widget.onChanged(value.copyWith(weekdays: updated));
  }

  String _frequencyLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.none:
        return 'Never';
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekdays:
        return 'Weekdays';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.yearly:
        return _recurrenceFrequencyYearlyLabel;
    }
  }

  String _intervalUnitLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.monthly:
        return 'month(s)';
      case RecurrenceFrequency.yearly:
        return _recurrenceIntervalYearLabel;
      case RecurrenceFrequency.weekly:
      case RecurrenceFrequency.weekdays:
        return 'week(s)';
      case RecurrenceFrequency.daily:
        return 'day(s)';
      case RecurrenceFrequency.none:
        return 'time(s)';
    }
  }
}

class _RecurrenceFrequencyChip extends StatelessWidget {
  const _RecurrenceFrequencyChip({
    required this.isSelected,
    required this.enabled,
    required this.padding,
    required this.label,
    this.onPressed,
  });

  final bool isSelected;
  final bool enabled;
  final EdgeInsets padding;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return ShadButton.raw(
      variant:
          isSelected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: padding,
      backgroundColor:
          isSelected ? calendarPrimaryColor : calendarContainerColor,
      hoverBackgroundColor: isSelected
          ? calendarPrimaryHoverColor
          : calendarPrimaryColor.withValues(alpha: enabled ? 0.08 : 0.04),
      foregroundColor: isSelected
          ? colors.primaryForeground
          : enabled
              ? calendarPrimaryColor
              : calendarSubtitleColor,
      hoverForegroundColor:
          isSelected ? colors.primaryForeground : calendarPrimaryHoverColor,
      onPressed: enabled ? onPressed : null,
      child: Text(
        label,
        style: TextStyle(
          fontSize: _recurrenceBodyFontSize,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    ).withTapBounce();
  }
}

class _RecurrenceWeekdaySelector extends StatelessWidget {
  const _RecurrenceWeekdaySelector({
    required this.selectedWeekdays,
    required this.padding,
    required this.enabled,
    required this.onWeekdayToggled,
  });

  final Set<int> selectedWeekdays;
  final EdgeInsets padding;
  final bool enabled;
  final ValueChanged<int> onWeekdayToggled;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _values = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final Color unselectedBackground =
        colors.muted.withValues(alpha: enabled ? 0.12 : 0.08);
    final Color unselectedHover =
        colors.muted.withValues(alpha: enabled ? 0.18 : 0.1);
    final Color selectedForeground = colors.primaryForeground;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(_values.length, (index) {
        final weekday = _values[index];
        final isSelected = selectedWeekdays.contains(weekday);
        return ShadButton.raw(
          variant: isSelected
              ? ShadButtonVariant.primary
              : ShadButtonVariant.outline,
          size: ShadButtonSize.sm,
          padding: padding,
          backgroundColor:
              isSelected ? calendarPrimaryColor : unselectedBackground,
          hoverBackgroundColor:
              isSelected ? calendarPrimaryHoverColor : unselectedHover,
          foregroundColor:
              isSelected ? selectedForeground : calendarPrimaryColor,
          hoverForegroundColor:
              isSelected ? selectedForeground : calendarPrimaryHoverColor,
          onPressed: enabled ? () => onWeekdayToggled(weekday) : null,
          child: Text(
            _labels[index],
            style: TextStyle(
              fontSize: _recurrenceBodyFontSize,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ).withTapBounce();
      }),
    );
  }
}

class _RecurrenceIntervalRow extends StatelessWidget {
  const _RecurrenceIntervalRow({
    required this.enabled,
    required this.currentInterval,
    required this.intervalWidth,
    required this.fieldGap,
    required this.unitLabel,
    required this.onIntervalChanged,
  });

  final bool enabled;
  final int currentInterval;
  final double intervalWidth;
  final double fieldGap;
  final String unitLabel;
  final ValueChanged<int> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    final options = List.generate(12, (index) => index + 1)
        .map(
          (value) => ShadOption<int>(
            value: value,
            child: Text('$value'),
          ),
        )
        .toList();

    return Row(
      children: [
        Text(
          _recurrenceRepeatEveryLabel,
          style: TextStyle(
            fontSize: _recurrenceBodyFontSize,
            color: calendarSubtitleColor,
          ),
        ),
        SizedBox(width: fieldGap),
        SizedBox(
          width: intervalWidth,
          child: AxiSelect<int>(
            enabled: enabled,
            initialValue: currentInterval.clamp(1, 12),
            onChanged: (newValue) {
              if (newValue == null) return;
              onIntervalChanged(newValue);
            },
            options: options,
            selectedOptionBuilder: (context, selected) => Text('$selected'),
            decoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                radius: BorderRadius.circular(_recurrenceCompactRadius),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: _recurrenceIconSmallSize,
              color: calendarSubtitleColor,
            ),
          ),
        ),
        SizedBox(width: fieldGap),
        Text(
          unitLabel,
          style: TextStyle(
            fontSize: _recurrenceBodyFontSize,
            color: calendarSubtitleColor,
          ),
        ),
      ],
    );
  }
}

enum _RecurrenceEndMode {
  never,
  until,
  count;
}

extension _RecurrenceEndModeX on _RecurrenceEndMode {
  bool get isUntil => this == _RecurrenceEndMode.until;

  bool get isCount => this == _RecurrenceEndMode.count;

  String get label => switch (this) {
        _RecurrenceEndMode.never => _recurrenceEndModeNeverLabel,
        _RecurrenceEndMode.until => _recurrenceEndModeUntilLabel,
        _RecurrenceEndMode.count => _recurrenceEndModeCountLabel,
      };
}

class _RecurrenceEndControls extends StatelessWidget {
  const _RecurrenceEndControls({
    required this.enabled,
    required this.value,
    required this.referenceStart,
    required this.countController,
    required this.onModeChanged,
    required this.onUntilChanged,
    required this.onCountChanged,
  });

  final bool enabled;
  final RecurrenceFormValue value;
  final DateTime? referenceStart;
  final TextEditingController countController;
  final ValueChanged<_RecurrenceEndMode> onModeChanged;
  final ValueChanged<DateTime?> onUntilChanged;
  final ValueChanged<String> onCountChanged;

  @override
  Widget build(BuildContext context) {
    final _RecurrenceEndMode mode = _endModeForValue(value);
    final TextStyle labelStyle = TextStyle(
      fontSize: _recurrenceSmallFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _recurrenceLabelLetterSpacing,
    );
    final TextStyle helperStyle = TextStyle(
      fontSize: _recurrenceHelperFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
    );
    final DateTime? derivedUntil = _deriveUntilForCount(
      start: referenceStart,
      value: value,
      mode: mode,
    );
    final int? derivedCount = _deriveCountForUntil(
      start: referenceStart,
      value: value,
      mode: mode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _recurrenceEndHeaderLabel.toUpperCase(),
          style: labelStyle,
        ),
        const SizedBox(height: calendarInsetLg),
        Wrap(
          spacing: calendarGutterSm,
          runSpacing: calendarGutterSm,
          children: _RecurrenceEndMode.values
              .map(
                (option) => _RecurrenceEndModeChip(
                  isSelected: option == mode,
                  enabled: enabled,
                  label: option.label,
                  onPressed: enabled ? () => onModeChanged(option) : null,
                ),
              )
              .toList(),
        ),
        if (mode.isUntil) ...[
          const SizedBox(height: calendarInsetLg),
          DeadlinePickerField(
            value: value.until,
            placeholder: _recurrenceEndModeUntilLabel,
            showStatusColors: false,
            showTimeSelectors: false,
            onChanged: enabled ? onUntilChanged : (_) {},
          ),
          if (derivedCount != null) ...[
            const SizedBox(height: calendarInsetSm),
            Text(
              '$_recurrenceEndModeDerivedCountLabel'
              '$_recurrenceLabelSpacer'
              '$derivedCount'
              '$_recurrenceLabelSpacer'
              '$_recurrenceEndModeDerivedCountSuffix',
              style: helperStyle,
            ),
          ],
        ] else if (mode.isCount) ...[
          const SizedBox(height: calendarInsetLg),
          AxiTextField(
            controller: countController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: context.l10n.calendarRepeatTimes,
              hintStyle: TextStyle(
                color: calendarSubtitleColor.withValues(alpha: 0.55),
                fontSize: _recurrenceInputHintFontSize,
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: calendarGutterMd,
                vertical: _recurrenceEndInputVerticalPadding,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(calendarBorderRadius),
                borderSide: BorderSide(color: calendarBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(calendarBorderRadius),
                borderSide: BorderSide(color: calendarBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(calendarBorderRadius),
                borderSide: BorderSide(color: calendarPrimaryColor, width: 2),
              ),
              filled: true,
              fillColor: calendarContainerColor,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: onCountChanged,
          ),
          if (derivedUntil != null) ...[
            const SizedBox(height: calendarInsetSm),
            Text(
              '$_recurrenceEndModeDerivedUntilLabel'
              '$_recurrenceLabelSpacer'
              '${_formatDerivedDate(derivedUntil, referenceStart)}',
              style: helperStyle,
            ),
          ],
        ],
      ],
    );
  }
}

class _RecurrenceEndModeChip extends StatelessWidget {
  const _RecurrenceEndModeChip({
    required this.isSelected,
    required this.enabled,
    required this.label,
    this.onPressed,
  });

  final bool isSelected;
  final bool enabled;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.raw(
      variant:
          isSelected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterMd,
        vertical: calendarGutterSm,
      ),
      backgroundColor:
          isSelected ? calendarPrimaryColor : calendarContainerColor,
      hoverBackgroundColor: isSelected
          ? calendarPrimaryHoverColor
          : calendarPrimaryColor.withValues(alpha: enabled ? 0.08 : 0.04),
      foregroundColor: isSelected
          ? context.colorScheme.primaryForeground
          : enabled
              ? calendarPrimaryColor
              : calendarSubtitleColor,
      hoverForegroundColor: isSelected
          ? context.colorScheme.primaryForeground
          : calendarPrimaryHoverColor,
      onPressed: enabled ? onPressed : null,
      child: Text(
        label,
        style: TextStyle(
          fontSize: _recurrenceBodyFontSize,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    ).withTapBounce();
  }
}

_RecurrenceEndMode _endModeForValue(RecurrenceFormValue value) {
  if (value.count != null) {
    return _RecurrenceEndMode.count;
  }
  if (value.until != null) {
    return _RecurrenceEndMode.until;
  }
  return _RecurrenceEndMode.never;
}

DateTime? _deriveUntilForCount({
  required DateTime? start,
  required RecurrenceFormValue value,
  required _RecurrenceEndMode mode,
}) {
  if (start == null || !mode.isCount || value.count == null) {
    return null;
  }
  return _RecurrenceLimitSolver(start, value).untilForCount(value.count!);
}

int? _deriveCountForUntil({
  required DateTime? start,
  required RecurrenceFormValue value,
  required _RecurrenceEndMode mode,
}) {
  if (start == null || !mode.isUntil || value.until == null) {
    return null;
  }
  return _RecurrenceLimitSolver(start, value).countThrough(value.until!);
}

String _formatDerivedDate(DateTime value, DateTime? referenceStart) {
  final bool showTime = referenceStart != null && !_isMidnight(referenceStart);
  return showTime
      ? TimeFormatter.formatFriendlyDateTime(value)
      : TimeFormatter.formatFriendlyDate(value);
}

bool _isMidnight(DateTime date) {
  return date.hour == 0 &&
      date.minute == 0 &&
      date.second == 0 &&
      date.millisecond == 0 &&
      date.microsecond == 0;
}

String _ordinalLabelForValue(int value) {
  for (final _OrdinalOption option in _ordinalOptions) {
    final int optionValue = option.position ?? _recurrenceOrdinalEveryValue;
    if (optionValue == value) {
      return option.label;
    }
  }
  return value.toString();
}

String _formatByDayEntry(RecurrenceWeekday entry) {
  final int? position = entry.position;
  final int resolvedValue = position ?? _recurrenceOrdinalEveryValue;
  return '${_ordinalLabelForValue(resolvedValue)}'
      '$_recurrenceLabelSpacer'
      '${entry.weekday.shortLabel}';
}

String _formatRecurrenceDateLabel(CalendarDateTime entry) {
  final DateTime value = entry.value;
  final bool showTime = !entry.isAllDay && !_isMidnight(value);
  return showTime
      ? TimeFormatter.formatFriendlyDateTime(value)
      : TimeFormatter.formatFriendlyDate(value);
}

String _formatTimeUnits(List<int> values, {required int pad}) {
  final List<int> sorted = List<int>.from(values)..sort();
  return sorted
      .map((value) => value.toString().padLeft(pad, _recurrenceValuePadChar))
      .join(_recurrenceValueSeparator);
}

DateTime _mergeDateAndTime({
  required DateTime date,
  required DateTime? referenceStart,
}) {
  final DateTime reference = referenceStart ?? date;
  if (reference.isUtc) {
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      reference.hour,
      reference.minute,
      reference.second,
      reference.millisecond,
      reference.microsecond,
    );
  }
  return DateTime(
    date.year,
    date.month,
    date.day,
    reference.hour,
    reference.minute,
    reference.second,
    reference.millisecond,
    reference.microsecond,
  );
}

CalendarDateTime _calendarDateTimeForDate({
  required DateTime date,
  required DateTime? referenceStart,
  required CalendarDateTime? template,
}) {
  final DateTime merged = _mergeDateAndTime(
    date: date,
    referenceStart: referenceStart,
  );
  final CalendarDateTime resolvedTemplate = template ??
      CalendarDateTime(
        value: merged,
        isAllDay: false,
        isFloating: !merged.isUtc,
      );
  final bool isFloating = resolvedTemplate.isFloating ||
      (!merged.isUtc && resolvedTemplate.tzid == null);
  return CalendarDateTime(
    value: merged,
    tzid: resolvedTemplate.tzid,
    isAllDay: resolvedTemplate.isAllDay,
    isFloating: isFloating,
  );
}

class _RecurrenceAdvancedToggle extends StatelessWidget {
  const _RecurrenceAdvancedToggle({
    required this.isExpanded,
    required this.hasAdvancedData,
    this.onPressed,
  });

  final bool isExpanded;
  final bool hasAdvancedData;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarSubtitleColor,
      fontWeight: FontWeight.w700,
      letterSpacing: _recurrenceLabelLetterSpacing,
    );
    final Color iconColor = calendarSubtitleColor;
    final BorderRadius radius = BorderRadius.circular(calendarBorderRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterSm,
            vertical: calendarGutterSm,
          ),
          child: Row(
            children: [
              Text(
                _recurrenceAdvancedLabel.toUpperCase(),
                style: labelStyle,
              ),
              if (hasAdvancedData) ...[
                const SizedBox(width: calendarInsetSm),
                _RecurrenceAdvancedActiveBadge(enabled: onPressed != null),
              ],
              const Spacer(),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: _recurrenceIconMediumSize,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurrenceAdvancedActiveBadge extends StatelessWidget {
  const _RecurrenceAdvancedActiveBadge({
    required this.enabled,
  });

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final Color background =
        colors.muted.withValues(alpha: enabled ? 0.18 : 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetSm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_recurrenceCompactRadius),
      ),
      child: Text(
        _recurrenceAdvancedActiveLabel,
        style: TextStyle(
          color: colors.mutedForeground,
          fontSize: _recurrenceSmallFontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecurrenceAdvancedSummary extends StatelessWidget {
  const _RecurrenceAdvancedSummary();

  @override
  Widget build(BuildContext context) {
    return Text(
      _recurrenceAdvancedSummary,
      style: context.textTheme.muted.copyWith(
        fontSize: _recurrenceBodyFontSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _RecurrenceAdvancedSection extends StatelessWidget {
  const _RecurrenceAdvancedSection({
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      fontSize: _recurrenceSmallFontSize,
      fontWeight: FontWeight.w700,
      color: context.colorScheme.mutedForeground,
      letterSpacing: _recurrenceLabelLetterSpacing,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        if (helper != null) ...[
          const SizedBox(height: calendarInsetSm),
          Text(
            helper!,
            style: context.textTheme.muted.copyWith(
              fontSize: _recurrenceHelperFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: calendarInsetSm),
        child,
      ],
    );
  }
}

class _RecurrenceAdvancedFields extends StatelessWidget {
  const _RecurrenceAdvancedFields({
    required this.enabled,
    required this.referenceStart,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final DateTime? referenceStart;
  final RecurrenceFormValue value;
  final ValueChanged<RecurrenceFormValue> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    final bool showByDays =
        value.frequency.isMonthlyOrYearly || value.byDays.isNotEmpty;
    final bool showByMonths =
        value.frequency.isYearly || value.byMonths.isNotEmpty;
    final bool showByMonthDays =
        value.frequency.isMonthlyOrYearly || value.byMonthDays.isNotEmpty;
    final bool showByYearDays =
        value.frequency.isYearly || value.byYearDays.isNotEmpty;
    final bool showByWeekNumbers =
        value.frequency.isYearly || value.byWeekNumbers.isNotEmpty;
    final bool showBySetPositions =
        value.frequency.isMonthlyOrYearly || value.bySetPositions.isNotEmpty;
    final bool showTimeSummary = value.byHours.isNotEmpty ||
        value.byMinutes.isNotEmpty ||
        value.bySeconds.isNotEmpty;

    if (showByDays) {
      children
        ..add(
          _RecurrenceAdvancedSection(
            label: _recurrenceAdvancedByDayLabel,
            helper: _recurrenceAdvancedByDayHelper,
            child: _RecurrenceOrdinalWeekdayEditor(
              enabled: enabled,
              value: value.byDays,
              onChanged: (next) => onChanged(value.copyWith(byDays: next)),
            ),
          ),
        )
        ..add(const SizedBox(height: calendarGutterMd));
    }

    if (showByMonths) {
      children
        ..add(
          _RecurrenceAdvancedSection(
            label: _recurrenceAdvancedMonthsLabel,
            child: _RecurrenceMonthSelector(
              enabled: enabled,
              selectedMonths: value.byMonths,
              onChanged: (next) => onChanged(value.copyWith(byMonths: next)),
            ),
          ),
        )
        ..add(const SizedBox(height: calendarGutterMd));
    }

    if (showByMonthDays) {
      children
        ..add(
          _RecurrenceAdvancedSection(
            label: _recurrenceAdvancedMonthDaysLabel,
            child: _RecurrenceNumberListField(
              enabled: enabled,
              hintText: _recurrenceAdvancedMonthDaysHint,
              values: value.byMonthDays,
              min: _recurrenceMonthMin,
              max: _recurrenceMonthDayMax,
              allowNegative: true,
              onChanged: (next) => onChanged(value.copyWith(byMonthDays: next)),
            ),
          ),
        )
        ..add(const SizedBox(height: calendarGutterMd));
    }

    if (showByYearDays) {
      children
        ..add(
          _RecurrenceAdvancedSection(
            label: _recurrenceAdvancedYearDaysLabel,
            child: _RecurrenceNumberListField(
              enabled: enabled,
              hintText: _recurrenceAdvancedYearDaysHint,
              values: value.byYearDays,
              min: _recurrenceMonthMin,
              max: _recurrenceYearDayMax,
              allowNegative: true,
              onChanged: (next) => onChanged(value.copyWith(byYearDays: next)),
            ),
          ),
        )
        ..add(const SizedBox(height: calendarGutterMd));
    }

    if (showByWeekNumbers) {
      children
        ..add(
          _RecurrenceAdvancedSection(
            label: _recurrenceAdvancedWeekNumbersLabel,
            child: _RecurrenceNumberListField(
              enabled: enabled,
              hintText: _recurrenceAdvancedWeekNumbersHint,
              values: value.byWeekNumbers,
              min: _recurrenceMonthMin,
              max: _recurrenceWeekNumberMax,
              allowNegative: true,
              onChanged: (next) =>
                  onChanged(value.copyWith(byWeekNumbers: next)),
            ),
          ),
        )
        ..add(const SizedBox(height: calendarGutterMd));
    }

    if (showBySetPositions) {
      children
        ..add(
          _RecurrenceAdvancedSection(
            label: _recurrenceAdvancedSetPositionsLabel,
            child: _RecurrenceNumberListField(
              enabled: enabled,
              hintText: _recurrenceAdvancedSetPositionsHint,
              values: value.bySetPositions,
              min: _recurrenceMonthMin,
              max: _recurrenceSetPositionMax,
              allowNegative: true,
              onChanged: (next) =>
                  onChanged(value.copyWith(bySetPositions: next)),
            ),
          ),
        )
        ..add(const SizedBox(height: calendarGutterMd));
    }

    children
      ..add(
        _RecurrenceAdvancedSection(
          label: _recurrenceAdvancedRDatesLabel,
          child: _RecurrenceDateListEditor(
            enabled: enabled,
            hintText: _recurrenceAdvancedRDatesHint,
            values: value.rDates,
            referenceStart: referenceStart,
            onChanged: (next) => onChanged(value.copyWith(rDates: next)),
          ),
        ),
      )
      ..add(const SizedBox(height: calendarGutterMd))
      ..add(
        _RecurrenceAdvancedSection(
          label: _recurrenceAdvancedExDatesLabel,
          child: _RecurrenceDateListEditor(
            enabled: enabled,
            hintText: _recurrenceAdvancedExDatesHint,
            values: value.exDates,
            referenceStart: referenceStart,
            onChanged: (next) => onChanged(value.copyWith(exDates: next)),
          ),
        ),
      );

    if (showTimeSummary) {
      children
        ..add(const SizedBox(height: calendarGutterMd))
        ..add(
          _RecurrenceAdvancedSection(
            label: _recurrenceAdvancedTimeSummaryLabel,
            child: _RecurrenceTimeSummary(
              byHours: value.byHours,
              byMinutes: value.byMinutes,
              bySeconds: value.bySeconds,
            ),
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _RecurrenceMonthSelector extends StatelessWidget {
  const _RecurrenceMonthSelector({
    required this.enabled,
    required this.selectedMonths,
    required this.onChanged,
  });

  final bool enabled;
  final List<int> selectedMonths;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final Set<int> selected = selectedMonths.toSet();
    return Wrap(
      spacing: calendarGutterSm,
      runSpacing: calendarInsetSm,
      children: _monthOptions
          .map(
            (option) => _RecurrenceEndModeChip(
              isSelected: selected.contains(option.value),
              enabled: enabled,
              label: option.label,
              onPressed: enabled
                  ? () {
                      final Set<int> next = Set<int>.from(selected);
                      if (!next.add(option.value)) {
                        next.remove(option.value);
                      }
                      onChanged(
                        _normalizeNumericList(
                          next.toList(),
                          min: _recurrenceMonthMin,
                          max: _recurrenceMonthMax,
                          allowNegative: false,
                        ),
                      );
                    }
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _RecurrenceNumberListField extends StatefulWidget {
  const _RecurrenceNumberListField({
    required this.enabled,
    required this.hintText,
    required this.values,
    required this.min,
    required this.max,
    required this.allowNegative,
    required this.onChanged,
  });

  final bool enabled;
  final String hintText;
  final List<int> values;
  final int min;
  final int max;
  final bool allowNegative;
  final ValueChanged<List<int>> onChanged;

  @override
  State<_RecurrenceNumberListField> createState() =>
      _RecurrenceNumberListFieldState();
}

class _RecurrenceNumberListFieldState
    extends State<_RecurrenceNumberListField> {
  static final RegExp _splitter = RegExp(_recurrenceNumberSplitPattern);
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitInput() {
    if (!widget.enabled) {
      return;
    }
    final String raw = _controller.text.trim();
    if (raw.isEmpty) {
      return;
    }
    final List<int> parsed = _parseNumbers(raw);
    if (parsed.isEmpty) {
      return;
    }
    final List<int> merged = _normalizeNumericList(
      <int>[...widget.values, ...parsed],
      min: widget.min,
      max: widget.max,
      allowNegative: widget.allowNegative,
    );
    if (merged.length == widget.values.length) {
      _controller
        ..clear()
        ..selection = const TextSelection.collapsed(offset: 0);
      _focusNode.requestFocus();
      return;
    }
    widget.onChanged(merged);
    _controller
      ..clear()
      ..selection = const TextSelection.collapsed(offset: 0);
    _focusNode.requestFocus();
  }

  List<int> _parseNumbers(String input) {
    final Iterable<String> tokens = input.split(_splitter);
    final List<int> values = <int>[];
    for (final String token in tokens) {
      final String trimmed = token.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final int? parsed = int.tryParse(trimmed);
      if (parsed == null) {
        continue;
      }
      values.add(parsed);
    }
    return values;
  }

  void _removeValue(int value) {
    final List<int> next = List<int>.from(widget.values)..remove(value);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final List<int> values = widget.values;
    final Widget inputRow = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final bool canSubmit = widget.enabled && value.text.trim().isNotEmpty;
        return Row(
          children: [
            Expanded(
              child: TaskTextField(
                controller: _controller,
                focusNode: _focusNode,
                hintText: widget.hintText,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitInput(),
                enabled: widget.enabled,
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            AxiIconButton(
              iconData: Icons.add,
              tooltip: _recurrenceAdvancedAddTooltip,
              onPressed: canSubmit ? _submitInput : null,
              color: canSubmit ? calendarPrimaryColor : calendarSubtitleColor,
              backgroundColor: calendarContainerColor,
              borderColor: calendarBorderColor,
              iconSize: calendarGutterLg,
              buttonSize: AxiIconButton.kDefaultSize,
              tapTargetSize: AxiIconButton.kTapTargetSize,
            ),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inputRow,
        if (values.isNotEmpty) ...[
          const SizedBox(height: calendarInsetSm),
          Wrap(
            spacing: calendarGutterSm,
            runSpacing: calendarInsetSm,
            children: values
                .map(
                  (value) => _RecurrenceNumberChip(
                    value: value,
                    onRemove: widget.enabled ? () => _removeValue(value) : null,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _RecurrenceNumberChip extends StatelessWidget {
  const _RecurrenceNumberChip({
    required this.value,
    this.onRemove,
  });

  final int value;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: labelStyle,
          ),
          if (onRemove != null) ...[
            const SizedBox(width: calendarInsetSm),
            _RecurrenceChipRemoveButton(onPressed: onRemove!),
          ],
        ],
      ),
    );
  }
}

class _RecurrenceChipRemoveButton extends StatelessWidget {
  const _RecurrenceChipRemoveButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: Icons.close,
      tooltip: context.l10n.commonRemove,
      onPressed: onPressed,
      color: calendarSubtitleColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: _recurrenceIconTinySize,
      buttonSize: 24,
      tapTargetSize: 32,
    );
  }
}

class _RecurrenceDateListEditor extends StatefulWidget {
  const _RecurrenceDateListEditor({
    required this.enabled,
    required this.hintText,
    required this.values,
    required this.referenceStart,
    required this.onChanged,
  });

  final bool enabled;
  final String hintText;
  final List<CalendarDateTime> values;
  final DateTime? referenceStart;
  final ValueChanged<List<CalendarDateTime>> onChanged;

  @override
  State<_RecurrenceDateListEditor> createState() =>
      _RecurrenceDateListEditorState();
}

class _RecurrenceDateListEditorState extends State<_RecurrenceDateListEditor> {
  DateTime? _pendingDate;

  void _handleDateChanged(DateTime? value) {
    setState(() {
      _pendingDate = value;
    });
  }

  void _addDate() {
    if (!widget.enabled) {
      return;
    }
    final DateTime? pending = _pendingDate;
    if (pending == null) {
      return;
    }
    final CalendarDateTime? template =
        widget.values.isNotEmpty ? widget.values.first : null;
    final CalendarDateTime entry = _calendarDateTimeForDate(
      date: pending,
      referenceStart: widget.referenceStart,
      template: template,
    );
    final List<CalendarDateTime> next = _normalizeDateTimes(
      <CalendarDateTime>[...widget.values, entry],
    );
    widget.onChanged(next);
    setState(() {
      _pendingDate = null;
    });
  }

  void _removeDate(CalendarDateTime entry) {
    final List<CalendarDateTime> next = List<CalendarDateTime>.from(
      widget.values,
    )..removeWhere(
        (value) => value.value == entry.value,
      );
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = widget.enabled && _pendingDate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DeadlinePickerField(
                value: _pendingDate,
                placeholder: widget.hintText,
                showStatusColors: false,
                showTimeSelectors: false,
                onChanged: widget.enabled ? _handleDateChanged : (_) {},
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            AxiIconButton(
              iconData: Icons.add,
              tooltip: _recurrenceAdvancedAddTooltip,
              onPressed: canSubmit ? _addDate : null,
              color: canSubmit ? calendarPrimaryColor : calendarSubtitleColor,
              backgroundColor: calendarContainerColor,
              borderColor: calendarBorderColor,
              iconSize: calendarGutterLg,
              buttonSize: AxiIconButton.kDefaultSize,
              tapTargetSize: AxiIconButton.kTapTargetSize,
            ),
          ],
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: calendarInsetSm),
          Wrap(
            spacing: calendarGutterSm,
            runSpacing: calendarInsetSm,
            children: widget.values
                .map(
                  (entry) => _RecurrenceDateChip(
                    entry: entry,
                    onRemove: widget.enabled ? () => _removeDate(entry) : null,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _RecurrenceDateChip extends StatelessWidget {
  const _RecurrenceDateChip({
    required this.entry,
    this.onRemove,
  });

  final CalendarDateTime entry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    final String label = _formatRecurrenceDateLabel(entry);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: labelStyle,
          ),
          if (onRemove != null) ...[
            const SizedBox(width: calendarInsetSm),
            _RecurrenceChipRemoveButton(onPressed: onRemove!),
          ],
        ],
      ),
    );
  }
}

class _RecurrenceOrdinalWeekdayEditor extends StatefulWidget {
  const _RecurrenceOrdinalWeekdayEditor({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final List<RecurrenceWeekday> value;
  final ValueChanged<List<RecurrenceWeekday>> onChanged;

  @override
  State<_RecurrenceOrdinalWeekdayEditor> createState() =>
      _RecurrenceOrdinalWeekdayEditorState();
}

class _RecurrenceOrdinalWeekdayEditorState
    extends State<_RecurrenceOrdinalWeekdayEditor> {
  int _selectedOrdinal = _recurrenceOrdinalEveryValue;
  CalendarWeekday _selectedWeekday = CalendarWeekday.monday;

  void _addEntry() {
    if (!widget.enabled) {
      return;
    }
    final int? position = _selectedOrdinal == _recurrenceOrdinalEveryValue
        ? null
        : _selectedOrdinal;
    final RecurrenceWeekday entry = RecurrenceWeekday(
      weekday: _selectedWeekday,
      position: position,
    );
    final List<RecurrenceWeekday> merged =
        _normalizeByDays(<RecurrenceWeekday>[...widget.value, entry]);
    if (_listsEqual(widget.value, merged)) {
      return;
    }
    widget.onChanged(merged);
  }

  bool _listsEqual(
      List<RecurrenceWeekday> left, List<RecurrenceWeekday> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  void _removeEntry(RecurrenceWeekday entry) {
    final List<RecurrenceWeekday> next = List<RecurrenceWeekday>.from(
      widget.value,
    )..remove(entry);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final List<RecurrenceWeekday> entries = widget.value;
    final bool canSubmit = widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AxiSelect<int>(
                enabled: widget.enabled,
                initialValue: _selectedOrdinal,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedOrdinal = value;
                  });
                },
                options: _ordinalOptions
                    .map(
                      (option) => ShadOption<int>(
                        value: option.position ?? _recurrenceOrdinalEveryValue,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                selectedOptionBuilder: (context, selected) =>
                    Text(_ordinalLabelForValue(selected)),
                decoration: ShadDecoration(
                  color: calendarContainerColor,
                  border: ShadBorder.all(
                    color: calendarBorderColor,
                    radius: BorderRadius.circular(_recurrenceCompactRadius),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: calendarGutterMd,
                  vertical: calendarGutterSm,
                ),
                trailing: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: _recurrenceIconSmallSize,
                  color: calendarSubtitleColor,
                ),
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            Expanded(
              child: AxiSelect<CalendarWeekday>(
                enabled: widget.enabled,
                initialValue: _selectedWeekday,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedWeekday = value;
                  });
                },
                options: _orderedWeekdays
                    .map(
                      (weekday) => ShadOption<CalendarWeekday>(
                        value: weekday,
                        child: Text(weekday.longLabel),
                      ),
                    )
                    .toList(),
                selectedOptionBuilder: (context, selected) =>
                    Text(selected.longLabel),
                decoration: ShadDecoration(
                  color: calendarContainerColor,
                  border: ShadBorder.all(
                    color: calendarBorderColor,
                    radius: BorderRadius.circular(_recurrenceCompactRadius),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: calendarGutterMd,
                  vertical: calendarGutterSm,
                ),
                trailing: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: _recurrenceIconSmallSize,
                  color: calendarSubtitleColor,
                ),
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            AxiIconButton(
              iconData: Icons.add,
              tooltip: _recurrenceAdvancedAddTooltip,
              onPressed: canSubmit ? _addEntry : null,
              color: canSubmit ? calendarPrimaryColor : calendarSubtitleColor,
              backgroundColor: calendarContainerColor,
              borderColor: calendarBorderColor,
              iconSize: calendarGutterLg,
              buttonSize: AxiIconButton.kDefaultSize,
              tapTargetSize: AxiIconButton.kTapTargetSize,
            ),
          ],
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: calendarInsetSm),
          Wrap(
            spacing: calendarGutterSm,
            runSpacing: calendarInsetSm,
            children: entries
                .map(
                  (entry) => _RecurrenceWeekdayChip(
                    entry: entry,
                    onRemove: widget.enabled ? () => _removeEntry(entry) : null,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _RecurrenceWeekdayChip extends StatelessWidget {
  const _RecurrenceWeekdayChip({
    required this.entry,
    this.onRemove,
  });

  final RecurrenceWeekday entry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    final String label = _formatByDayEntry(entry);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: labelStyle,
          ),
          if (onRemove != null) ...[
            const SizedBox(width: calendarInsetSm),
            _RecurrenceChipRemoveButton(onPressed: onRemove!),
          ],
        ],
      ),
    );
  }
}

class _RecurrenceTimeSummary extends StatelessWidget {
  const _RecurrenceTimeSummary({
    required this.byHours,
    required this.byMinutes,
    required this.bySeconds,
  });

  final List<int> byHours;
  final List<int> byMinutes;
  final List<int> bySeconds;

  @override
  Widget build(BuildContext context) {
    final List<_RecurrenceTimeSummaryRow> rows = <_RecurrenceTimeSummaryRow>[];
    if (byHours.isNotEmpty) {
      rows.add(
        _RecurrenceTimeSummaryRow(
          label: _recurrenceTimeHoursLabel,
          values: _formatTimeUnits(byHours, pad: 2),
        ),
      );
    }
    if (byMinutes.isNotEmpty) {
      rows.add(
        _RecurrenceTimeSummaryRow(
          label: _recurrenceTimeMinutesLabel,
          values: _formatTimeUnits(byMinutes, pad: 2),
        ),
      );
    }
    if (bySeconds.isNotEmpty) {
      rows.add(
        _RecurrenceTimeSummaryRow(
          label: _recurrenceTimeSecondsLabel,
          values: _formatTimeUnits(bySeconds, pad: 2),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

class _RecurrenceTimeSummaryRow extends StatelessWidget {
  const _RecurrenceTimeSummaryRow({
    required this.label,
    required this.values,
  });

  final String label;
  final String values;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarSubtitleColor,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: calendarInsetSm),
      child: Row(
        children: [
          Text(label, style: labelStyle),
          const SizedBox(width: calendarInsetSm),
          Expanded(
            child: Text(
              values,
              style: context.textTheme.muted.copyWith(
                fontSize: _recurrenceBodyFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurrenceLimitSolver {
  _RecurrenceLimitSolver(this.anchor, this.value)
      : _effectiveWeekdays = value.frequency == RecurrenceFrequency.weekdays
            ? const {
                DateTime.monday,
                DateTime.tuesday,
                DateTime.wednesday,
                DateTime.thursday,
                DateTime.friday,
              }
            : (value.weekdays.isNotEmpty
                ? Set<int>.from(value.weekdays)
                : {anchor.weekday}),
        _anchorDay = anchor.day,
        _anchorMonth = anchor.month;

  final DateTime anchor;
  final RecurrenceFormValue value;
  final Set<int> _effectiveWeekdays;
  final int _anchorDay;
  final int _anchorMonth;

  static const int _maxIterations = 5000;

  DateTime? untilForCount(int count) {
    if (count <= 1) return anchor;
    var current = anchor;
    for (var produced = 1;
        produced < count && produced < _maxIterations;
        produced++) {
      current = _nextOccurrence(current);
    }
    return current;
  }

  int? countThrough(DateTime until) {
    if (until.isBefore(anchor)) {
      return 1;
    }
    var current = anchor;
    var occurrences = 1;
    for (var guard = 0; guard < _maxIterations; guard++) {
      final next = _nextOccurrence(current);
      if (next.isAfter(until)) {
        break;
      }
      current = next;
      occurrences++;
      if (!next.isBefore(until)) {
        break;
      }
    }
    return occurrences;
  }

  DateTime _nextOccurrence(DateTime current) {
    switch (value.frequency) {
      case RecurrenceFrequency.none:
        return current;
      case RecurrenceFrequency.daily:
        return current.add(Duration(days: math.max(value.interval, 1)));
      case RecurrenceFrequency.weekdays:
      case RecurrenceFrequency.weekly:
        return _advanceWeekly(current);
      case RecurrenceFrequency.monthly:
        return _advanceMonthly(current);
      case RecurrenceFrequency.yearly:
        return _advanceYearly(current);
    }
  }

  DateTime _advanceWeekly(DateTime current) {
    final sorted = _effectiveWeekdays.toList()..sort();
    if (sorted.isEmpty) {
      sorted.add(anchor.weekday);
    }
    for (final day in sorted) {
      if (day > current.weekday) {
        return current.add(Duration(days: day - current.weekday));
      }
    }
    final int firstDay = sorted.first;
    final int intervalWeeks = math.max(value.interval, 1);
    final int daysToNextCycle = ((intervalWeeks - 1) * 7) +
        ((DateTime.sunday - current.weekday + 7) % 7) +
        firstDay;
    return current.add(Duration(days: daysToNextCycle));
  }

  DateTime _advanceMonthly(DateTime current) {
    final int intervalMonths = math.max(value.interval, 1);
    final int newMonthIndex = (current.month - 1) + intervalMonths;
    final int year = current.year + (newMonthIndex ~/ 12);
    final int month = (newMonthIndex % 12) + 1;
    final int day = _clampDay(_anchorDay, year, month);
    return DateTime(
      year,
      month,
      day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  DateTime _advanceYearly(DateTime current) {
    final int intervalYears = math.max(value.interval, 1);
    final int year = current.year + intervalYears;
    final int day = _clampDay(_anchorDay, year, _anchorMonth);
    return DateTime(
      year,
      _anchorMonth,
      day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  int _clampDay(int desiredDay, int year, int month) {
    return math.min(desiredDay, _daysInMonth(year, month));
  }

  int _daysInMonth(int year, int month) {
    final DateTime firstNext =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return firstNext.subtract(const Duration(days: 1)).day;
  }
}
