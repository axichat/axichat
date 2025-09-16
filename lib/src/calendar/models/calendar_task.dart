import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../utils/smart_parser.dart';

part 'calendar_task.freezed.dart';
part 'calendar_task.g.dart';

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
    @HiveField(10) int? daySpan,
    @HiveField(11) TaskPriority? priority,
    @HiveField(12) double? startHour,
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
    int daySpan = 1,
    TaskPriority priority = TaskPriority.none,
    double? startHour,
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
      daySpan: daySpan == 1 ? null : daySpan,
      priority: priority == TaskPriority.none ? null : priority,
      startHour: startHour,
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
  int get effectiveDaySpan => daySpan ?? 1;
  TaskPriority get effectivePriority => priority ?? TaskPriority.none;

  bool get isCritical => effectivePriority == TaskPriority.critical;
  bool get isImportant => effectivePriority == TaskPriority.important;
  bool get isUrgent => effectivePriority == TaskPriority.urgent;

  bool get isScheduled => scheduledTime != null;
  bool get hasDeadline => deadline != null;

  Color get priorityColor {
    switch (effectivePriority) {
      case TaskPriority.critical:
        return const Color(0xFFDC3545); // Red
      case TaskPriority.important:
        return const Color(0xFF28A745); // Green
      case TaskPriority.urgent:
        return const Color(0xFFFD7E14); // Orange
      case TaskPriority.none:
        return const Color(0xFF0969DA); // Blue
    }
  }
}
