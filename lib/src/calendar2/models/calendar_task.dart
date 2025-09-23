import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'duration_adapter.dart';

part 'calendar_task.freezed.dart';
part 'calendar_task.g.dart';

const _uuid = Uuid();

@freezed
class CalendarTask with _$CalendarTask {
  const CalendarTask._();

  const factory CalendarTask({
    required String id,
    required String title,
    String? description,
    DateTime? scheduledStart,
    @DurationJsonConverter() Duration? duration,
    DateTime? endDate,
    DateTime? deadline,
    @Default(false) bool isAllDay,
    @Default(false) bool important,
    @Default(false) bool urgent,
    @Default(<String>[]) List<String> tags,
    String? location,
    @Default(false) bool completed,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CalendarTask;

  factory CalendarTask.fromJson(Map<String, dynamic> json) =>
      _$CalendarTaskFromJson(json);

  factory CalendarTask.create({
    required String title,
    String? description,
    DateTime? scheduledStart,
    Duration? duration,
    DateTime? endDate,
    DateTime? deadline,
    bool isAllDay = false,
    bool important = false,
    bool urgent = false,
    List<String> tags = const <String>[],
    String? location,
    bool completed = false,
  }) {
    final now = DateTime.now();
    final sanitizedTags = _sanitizeTags(tags);
    final sanitizedTitle = title.trim();
    final sanitizedDescription = description?.trim();
    final sanitizedLocation = location?.trim();
    final normalizedLocation =
        sanitizedLocation == null || sanitizedLocation.isEmpty
            ? null
            : sanitizedLocation;

    return CalendarTask(
      id: _uuid.v4(),
      title: sanitizedTitle,
      description: sanitizedDescription,
      scheduledStart: scheduledStart,
      duration: duration,
      endDate: endDate,
      deadline: deadline,
      isAllDay: isAllDay,
      important: important,
      urgent: urgent,
      tags: sanitizedTags,
      location: normalizedLocation,
      completed: completed,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Returns true when the task has been scheduled on the calendar grid.
  bool get isScheduled => scheduledStart != null;

  /// Returns the effective start time for the task.
  DateTime? get effectiveStart => scheduledStart;

  /// Returns the effective end time for the task considering the explicit end
  /// date or the duration.
  DateTime? get effectiveEnd {
    if (endDate != null) {
      return endDate;
    }
    if (scheduledStart != null && duration != null) {
      return scheduledStart!.add(duration!);
    }
    return scheduledStart;
  }

  /// Returns the inclusive number of days the task spans.
  int get spanDaysCount {
    final start = scheduledStart;
    final end = effectiveEnd;
    if (start == null || end == null) {
      return 1;
    }
    final startDate = _stripTime(start);
    final endDate = _stripTime(end);
    return endDate.difference(startDate).inDays + 1;
  }

  /// Returns the color used to render the task in the grid based on its
  /// priority flags.
  Color get priorityColor {
    if (important && urgent) {
      return const Color(0xFFDC2626); // Red
    }
    if (important) {
      return const Color(0xFF2563EB); // Blue
    }
    if (urgent) {
      return const Color(0xFFF97316); // Orange
    }
    return const Color(0xFF9CA3AF); // Neutral grey
  }

  /// Convenience helper to mark the task as completed while updating the
  /// timestamp.
  CalendarTask markCompleted(bool value) => copyWith(
        completed: value,
        updatedAt: DateTime.now(),
      );

  /// Updates the task with the provided fields and bumps the [updatedAt]
  /// timestamp.
  CalendarTask updatedCopy({
    String? title,
    String? description,
    DateTime? scheduledStart,
    Duration? duration,
    DateTime? endDate,
    DateTime? deadline,
    bool? isAllDay,
    bool? important,
    bool? urgent,
    List<String>? tags,
    String? location,
    bool? completed,
    DateTime? timestamp,
  }) {
    final sanitizedTags = tags == null ? this.tags : _sanitizeTags(tags);
    final trimmedTitle = title?.trim();
    final trimmedDescription = description?.trim();
    final trimmedLocation = location?.trim();
    final normalizedLocation =
        trimmedLocation == null || trimmedLocation.isEmpty
            ? null
            : trimmedLocation;
    final appliedTimestamp = timestamp ?? DateTime.now();

    final resolvedLocation =
        location == null ? this.location : normalizedLocation;

    return copyWith(
      title: trimmedTitle ?? this.title,
      description: trimmedDescription ?? this.description,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      duration: duration ?? this.duration,
      endDate: endDate ?? this.endDate,
      deadline: deadline ?? this.deadline,
      isAllDay: isAllDay ?? this.isAllDay,
      important: important ?? this.important,
      urgent: urgent ?? this.urgent,
      tags: sanitizedTags,
      location: resolvedLocation,
      completed: completed ?? this.completed,
      updatedAt: appliedTimestamp,
    );
  }

  /// Returns a sanitized copy of the task with normalized strings, tags, and
  /// the updated timestamp.
  CalendarTask sanitized({DateTime? timestamp}) => updatedCopy(
        title: title,
        description: description,
        scheduledStart: scheduledStart,
        duration: duration,
        endDate: endDate,
        deadline: deadline,
        isAllDay: isAllDay,
        important: important,
        urgent: urgent,
        tags: tags,
        location: location,
        completed: completed,
        timestamp: timestamp,
      );
}

List<String> _sanitizeTags(List<String> tags) {
  final deduped = <String>{};
  for (final tag in tags) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty) {
      deduped.add(trimmed);
    }
  }
  return List.unmodifiable(deduped);
}

DateTime _stripTime(DateTime input) =>
    DateTime(input.year, input.month, input.day);
