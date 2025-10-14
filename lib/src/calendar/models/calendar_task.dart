import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../common/ui/ui.dart';
import '../utils/smart_parser.dart';

part 'calendar_task.freezed.dart';
part 'calendar_task.g.dart';

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
  }) = _RecurrenceRule;

  const RecurrenceRule._();

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) =>
      _$RecurrenceRuleFromJson(json);

  static const RecurrenceRule none = RecurrenceRule(
    frequency: RecurrenceFrequency.none,
    interval: 1,
    until: null,
    count: null,
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
class CalendarTask with _$CalendarTask {
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
    @HiveField(11) double? startHour,
    @HiveField(12) DateTime? endDate,
    @HiveField(13) RecurrenceRule? recurrence,
    @HiveField(14)
    @Default({})
    Map<String, TaskOccurrenceOverride> occurrenceOverrides,
  }) = _CalendarTask;

  factory CalendarTask.fromJson(Map<String, dynamic> json) =>
      _$CalendarTaskFromJson(json);

  factory CalendarTask.create({
    required String title,
    String? description,
    DateTime? scheduledTime,
    Duration? duration,
    String? location,
    DateTime? deadline,
    DateTime? endDate,
    TaskPriority priority = TaskPriority.none,
    double? startHour,
    RecurrenceRule? recurrence,
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
      startHour: startHour,
      recurrence: recurrence?.isNone == true ? null : recurrence,
      occurrenceOverrides: const {},
      createdAt: now,
      modifiedAt: now,
    );
  }

  factory CalendarTask.fromNaturalLanguage(String input) {
    // Use enhanced smart parser to parse natural language input
    return SmartTaskParser.parseToTask(input);
  }
}

extension CalendarTaskExtensions on CalendarTask {
  DateTime? get effectiveEndDate {
    if (endDate != null) return endDate;
    if (scheduledTime != null && duration != null) {
      return scheduledTime!.add(duration!);
    }
    return null;
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
}
