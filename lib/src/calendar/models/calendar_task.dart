import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'calendar_checklist_item.dart';
import 'calendar_date_time.dart';
import 'calendar_ics_meta.dart';
import 'calendar_ics_raw.dart';
import 'calendar_item.dart';
import 'reminder_preferences.dart';

export 'calendar_checklist_item.dart';

part 'calendar_task.freezed.dart';
part 'calendar_task.g.dart';

const int _taskOccurrenceOverrideRecurrenceIdField = 10;
const int _taskOccurrenceOverrideRangeField = 11;

const int _recurrenceRuleBySecondsField = 5;
const int _recurrenceRuleByMinutesField = 6;
const int _recurrenceRuleByHoursField = 7;
const int _recurrenceRuleByDaysField = 8;
const int _recurrenceRuleByMonthDaysField = 9;
const int _recurrenceRuleByYearDaysField = 10;
const int _recurrenceRuleByWeekNumbersField = 11;
const int _recurrenceRuleByMonthsField = 12;
const int _recurrenceRuleBySetPositionsField = 13;
const int _recurrenceRuleWeekStartField = 14;
const int _recurrenceRuleRDatesField = 15;
const int _recurrenceRuleExDatesField = 16;
const int _recurrenceRuleRawPropertiesField = 17;

const int _calendarTaskIcsMetaField = 17;

const List<CalendarDateTime> _emptyCalendarDateTimes = <CalendarDateTime>[];
const List<CalendarRawProperty> _emptyCalendarRawProperties =
    <CalendarRawProperty>[];

@freezed
@HiveType(typeId: 36)
class TaskOccurrenceOverride with _$TaskOccurrenceOverride {
  const factory TaskOccurrenceOverride({
    @HiveField(0) DateTime? scheduledTime,
    @HiveField(1) Duration? duration,
    @HiveField(2) DateTime? endDate,
    @HiveField(3) bool? isCancelled,
    @HiveField(4) TaskPriority? priority,
    @HiveField(5) bool? isCompleted,
    @HiveField(6) String? title,
    @HiveField(7) String? description,
    @HiveField(8) String? location,
    @HiveField(9) List<TaskChecklistItem>? checklist,
    @HiveField(_taskOccurrenceOverrideRecurrenceIdField)
    CalendarDateTime? recurrenceId,
    @HiveField(_taskOccurrenceOverrideRangeField) RecurrenceRange? range,
  }) = _TaskOccurrenceOverride;

  factory TaskOccurrenceOverride.fromJson(Map<String, dynamic> json) =>
      _$TaskOccurrenceOverrideFromJson(json);
}

@HiveType(typeId: 35)
enum RecurrenceFrequency {
  @HiveField(0)
  none,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekdays,
  @HiveField(3)
  weekly,
  @HiveField(4)
  monthly,
}

@freezed
@HiveType(typeId: 34)
class RecurrenceRule with _$RecurrenceRule {
  const factory RecurrenceRule({
    @HiveField(0) required RecurrenceFrequency frequency,
    @HiveField(1) @Default(1) int interval,
    @HiveField(2) List<int>? byWeekdays,
    @HiveField(3) DateTime? until,
    @HiveField(4) int? count,
    @HiveField(_recurrenceRuleBySecondsField) List<int>? bySeconds,
    @HiveField(_recurrenceRuleByMinutesField) List<int>? byMinutes,
    @HiveField(_recurrenceRuleByHoursField) List<int>? byHours,
    @HiveField(_recurrenceRuleByDaysField) List<RecurrenceWeekday>? byDays,
    @HiveField(_recurrenceRuleByMonthDaysField) List<int>? byMonthDays,
    @HiveField(_recurrenceRuleByYearDaysField) List<int>? byYearDays,
    @HiveField(_recurrenceRuleByWeekNumbersField) List<int>? byWeekNumbers,
    @HiveField(_recurrenceRuleByMonthsField) List<int>? byMonths,
    @HiveField(_recurrenceRuleBySetPositionsField) List<int>? bySetPositions,
    @HiveField(_recurrenceRuleWeekStartField) CalendarWeekday? weekStart,
    @HiveField(_recurrenceRuleRDatesField)
    @Default(_emptyCalendarDateTimes)
    List<CalendarDateTime> rDates,
    @HiveField(_recurrenceRuleExDatesField)
    @Default(_emptyCalendarDateTimes)
    List<CalendarDateTime> exDates,
    @HiveField(_recurrenceRuleRawPropertiesField)
    @Default(_emptyCalendarRawProperties)
    List<CalendarRawProperty> rawProperties,
  }) = _RecurrenceRule;

  const RecurrenceRule._();

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) =>
      _$RecurrenceRuleFromJson(json);

  static const RecurrenceRule none = RecurrenceRule(
    frequency: RecurrenceFrequency.none,
    interval: 1,
    until: null,
    count: null,
    bySeconds: null,
    byMinutes: null,
    byHours: null,
    byDays: null,
    byMonthDays: null,
    byYearDays: null,
    byWeekNumbers: null,
    byMonths: null,
    bySetPositions: null,
    weekStart: null,
    rDates: _emptyCalendarDateTimes,
    exDates: _emptyCalendarDateTimes,
    rawProperties: _emptyCalendarRawProperties,
  );

  bool get isNone => frequency == RecurrenceFrequency.none;
}

@HiveType(typeId: 31)
enum TaskPriority {
  @HiveField(0)
  none,
  @HiveField(1)
  important,
  @HiveField(2)
  urgent,
  @HiveField(3)
  critical,
}

@freezed
@HiveType(typeId: 30)
class CalendarTask with _$CalendarTask implements CalendarItemBase {
  const factory CalendarTask({
    @HiveField(0) required String id,
    @HiveField(1) required String title,
    @HiveField(2) String? description,
    @HiveField(3) DateTime? scheduledTime,
    @HiveField(4) Duration? duration,
    @HiveField(5) @Default(false) bool isCompleted,
    @HiveField(6) required DateTime createdAt,
    @HiveField(7) required DateTime modifiedAt,
    @HiveField(8) String? location,
    @HiveField(9) DateTime? deadline,
    @HiveField(10) TaskPriority? priority,
    // Legacy field: kept for Hive backward compatibility. Use computedStartHour
    // getter instead. This field is excluded from JSON serialization.
    // ignore: invalid_annotation_target
    @JsonKey(includeToJson: false) @HiveField(11) double? startHour,
    @HiveField(12) DateTime? endDate,
    @HiveField(13) RecurrenceRule? recurrence,
    @HiveField(14)
    @Default({})
    Map<String, TaskOccurrenceOverride> occurrenceOverrides,
    @HiveField(15) ReminderPreferences? reminders,
    @HiveField(16, defaultValue: <TaskChecklistItem>[])
    @Default([])
    List<TaskChecklistItem> checklist,
    @HiveField(_calendarTaskIcsMetaField) CalendarIcsMeta? icsMeta,
  }) = _CalendarTask;

  factory CalendarTask.fromJson(Map<String, dynamic> json) =>
      _$CalendarTaskFromJson(json);

  const CalendarTask._();

  @override
  CalendarItemType get itemType => CalendarItemType.task;

  factory CalendarTask.create({
    required String title,
    String? description,
    DateTime? scheduledTime,
    Duration? duration,
    String? location,
    DateTime? deadline,
    DateTime? endDate,
    TaskPriority priority = TaskPriority.none,
    RecurrenceRule? recurrence,
    ReminderPreferences? reminders,
    List<TaskChecklistItem> checklist = const [],
  }) {
    final now = DateTime.now();
    return CalendarTask(
      id: const Uuid().v4(),
      title: title,
      description: description,
      scheduledTime: scheduledTime,
      duration: duration,
      location: location,
      deadline: deadline,
      endDate: endDate,
      priority: priority == TaskPriority.none ? null : priority,
      startHour: null,
      recurrence: recurrence?.isNone == true ? null : recurrence,
      occurrenceOverrides: const {},
      checklist: checklist,
      reminders: reminders?.normalized() ?? ReminderPreferences.defaults(),
      createdAt: now,
      modifiedAt: now,
    );
  }
}

extension CalendarTaskExtensions on CalendarTask {
  /// Computes the start hour from scheduledTime. Use this instead of the
  /// legacy stored startHour field.
  double? get computedStartHour => scheduledTime != null
      ? scheduledTime!.hour + (scheduledTime!.minute / 60.0)
      : null;

  DateTime? get effectiveEndDate {
    if (endDate != null) return endDate;
    if (scheduledTime != null && duration != null) {
      return scheduledTime!.add(duration!);
    }
    return null;
  }

  Duration? get effectiveDuration {
    if (duration != null) {
      return duration;
    }
    final DateTime? start = scheduledTime;
    final DateTime? end = endDate;
    if (start == null || end == null) {
      return null;
    }
    final Duration span = end.difference(start);
    if (span.inMinutes <= 0) {
      return null;
    }
    return span;
  }

  bool get hasExplicitDuration => duration != null;

  DateTime? get displayEnd {
    final DateTime? effective = effectiveEndDate;
    if (effective != null) {
      return effective;
    }
    final DateTime? start = scheduledTime;
    final Duration? span = effectiveDuration;
    if (start != null && span != null) {
      return start.add(span);
    }
    return start;
  }

  CalendarTask withScheduled({
    required DateTime scheduledTime,
    Duration? duration,
    DateTime? endDate,
  }) {
    final Duration? resolvedDuration = duration ??
        (endDate != null
            ? endDate.difference(scheduledTime)
            : effectiveDuration);
    final Duration normalizedDuration;
    if (resolvedDuration == null || resolvedDuration.inMinutes <= 0) {
      normalizedDuration = const Duration(hours: 1);
    } else {
      normalizedDuration = resolvedDuration;
    }
    final DateTime resolvedEnd =
        endDate ?? scheduledTime.add(normalizedDuration);

    return copyWith(
      scheduledTime: scheduledTime,
      duration: normalizedDuration,
      endDate: resolvedEnd,
    );
  }

  CalendarTask normalizedForInteraction(DateTime targetStart) {
    return withScheduled(
      scheduledTime: targetStart,
      duration: effectiveDuration,
      endDate: endDate,
    );
  }

  TaskPriority get effectivePriority => priority ?? TaskPriority.none;

  RecurrenceRule get effectiveRecurrence => recurrence ?? RecurrenceRule.none;

  bool get isCritical => effectivePriority == TaskPriority.critical;
  bool get isImportant => effectivePriority == TaskPriority.important;
  bool get isUrgent => effectivePriority == TaskPriority.urgent;

  bool get isScheduled => scheduledTime != null;
  bool get hasDeadline => deadline != null;

  Color get priorityColor {
    if (isCompleted) {
      return calendarPrimaryColor;
    }
    switch (effectivePriority) {
      case TaskPriority.critical:
        return const Color(0xFFDC3545);
      case TaskPriority.important:
        return const Color(0xFF28A745);
      case TaskPriority.urgent:
        return const Color(0xFFFD7E14);
      case TaskPriority.none:
        return const Color(0xFF9CA3AF);
    }
  }

  DateTime? splitTimeForFraction({
    required double fraction,
    required int minutesPerStep,
  }) {
    final DateTime? start = scheduledTime;
    if (start == null) {
      return null;
    }

    DateTime? end = effectiveEndDate;
    if (end == null || !end.isAfter(start)) {
      final Duration fallback = duration ?? const Duration(hours: 1);
      final Duration normalized =
          fallback.inMinutes <= 0 ? const Duration(minutes: 15) : fallback;
      end = start.add(normalized);
    }

    final int totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes <= 0) {
      return null;
    }

    final double normalized = fraction.clamp(0.0, 1.0);
    final int minimumStep = math.max(0, minutesPerStep);
    if (minimumStep > 0 && totalMinutes < minimumStep * 2) {
      return null;
    }

    int splitMinutes = (totalMinutes * normalized).round();
    if (minimumStep > 0) {
      splitMinutes = (splitMinutes / minimumStep).round() * minimumStep;
      final int maxSplit = totalMinutes - minimumStep;
      if (maxSplit <= 0) {
        return null;
      }
      splitMinutes = math.max(minimumStep, math.min(splitMinutes, maxSplit));
    }

    if (splitMinutes <= 0 || splitMinutes >= totalMinutes) {
      return null;
    }

    return start.add(Duration(minutes: splitMinutes));
  }

  bool get hasChecklist => checklist.isNotEmpty;

  int get completedChecklistCount =>
      checklist.where((item) => item.isCompleted).length;

  double get checklistProgress {
    if (checklist.isEmpty) {
      return 0;
    }
    return completedChecklistCount / checklist.length;
  }

  ReminderPreferences get effectiveReminders =>
      (reminders ?? ReminderPreferences.defaults()).normalized();
}
