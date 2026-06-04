// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'calendar_event.dart';

part 'calendar_state.freezed.dart';

@immutable
class TaskFocusRequest {
  const TaskFocusRequest({
    required this.taskId,
    required this.anchor,
    required this.token,
  });

  final String taskId;
  final DateTime anchor;
  final int token;
}

@immutable
class CalendarSyncWarning {
  const CalendarSyncWarning({required this.type});

  final CalendarSyncWarningType type;
}

enum CalendarSyncWarningType { snapshotUnavailable, archiveIncomplete }

@immutable
class CalendarAlertBadgeCounts {
  const CalendarAlertBadgeCounts({
    required this.scheduled,
    required this.unscheduled,
  });

  static const CalendarAlertBadgeCounts empty = CalendarAlertBadgeCounts(
    scheduled: 0,
    unscheduled: 0,
  );

  final int scheduled;
  final int unscheduled;

  int get total => scheduled + unscheduled;
}

@freezed
abstract class CalendarState with _$CalendarState {
  const factory CalendarState({
    required CalendarModel model,
    @Default(false) bool isSyncing,
    @Default(false) bool isLoading,
    DateTime? lastSyncTime,
    String? syncError,
    CalendarSyncWarning? syncWarning,
    String? error,
    @Default(CalendarView.week) CalendarView viewMode,
    required DateTime selectedDate,
    int? selectedDayIndex,
    List<CalendarTask>? dueReminders,
    CalendarTask? nextTask,
    @Default(false) bool isSelectionMode,
    @Default(<String>{}) Set<String> selectedTaskIds,
    @Default(false) bool canUndo,
    @Default(false) bool canRedo,
    TaskFocusRequest? pendingFocus,
    String? focusedCriticalPathId,
    @Default(false) bool isTaskCreationSubmitting,
    String? taskCreationError,
    String? lastCreatedTaskId,
    String? importError,
    @Default(<String>[]) List<String> lastImportedTaskIds,
    String? lastImportedModelChecksum,
    @Default(false) bool isCriticalPathMutating,
    String? criticalPathMutationError,
    String? lastCreatedCriticalPathId,
    String? lastCriticalPathTaskAddedPathId,
    String? lastCriticalPathTaskAddedTaskId,
  }) = _CalendarState;

  factory CalendarState.initial() =>
      CalendarState(model: CalendarModel.empty(), selectedDate: demoNow());
}

extension CalendarStateExtensions on CalendarState {
  CalendarAlertBadgeCounts alertBadgeCounts(DateTime now) =>
      model.alertBadgeCounts(now);

  List<CalendarTask> get unscheduledTasks =>
      model.tasks.values.where((task) => task.isUnscheduled).toList();

  List<CalendarTask> get reminderTasks =>
      model.tasks.values.where((task) => task.isReminder).toList();

  List<CalendarTask> get scheduledTasks =>
      model.tasks.values.where((task) => task.isScheduled).toList();

  List<CalendarCriticalPath> get criticalPaths => model.activeCriticalPaths;

  CalendarCriticalPath? get focusedCriticalPath {
    final String? targetId = focusedCriticalPathId;
    if (targetId == null) {
      return null;
    }
    final CalendarCriticalPath? path = model.criticalPaths[targetId];
    if (path == null || path.isArchived) {
      return null;
    }
    return path;
  }

  bool isTaskInFocusedPath(CalendarTask task) {
    final CalendarCriticalPath? focus = focusedCriticalPath;
    if (focus == null) {
      return true;
    }
    if (focus.taskIds.isEmpty) {
      return false;
    }
    final String baseId = task.baseId;
    for (final String id in focus.taskIds) {
      if (baseTaskIdFrom(id) == baseId) {
        return true;
      }
    }
    return false;
  }

  DateTime get weekStart {
    final date = selectedDate;
    final weekday = date.weekday; // Monday = 1, Sunday = 7
    final daysFromMonday = weekday - DateTime.monday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysFromMonday));
  }

  DateTime get weekEnd {
    final start = weekStart;
    return start.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );
  }

  List<CalendarTask> get tasksForSelectedWeek =>
      tasksInRange(weekStart, weekEnd);

  List<CalendarTask> get tasksForSelectedDay {
    if (selectedDayIndex == null) return [];
    final dayStart = weekStart.add(Duration(days: selectedDayIndex!));
    final dayEnd = dayStart.add(
      const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999),
    );
    return tasksInRange(dayStart, dayEnd);
  }

  List<CalendarTask> tasksForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(
      const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999),
    );
    return tasksInRange(dayStart, dayEnd);
  }

  List<CalendarTask> tasksInRange(DateTime rangeStart, DateTime rangeEnd) {
    final normalizedStart = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day,
      rangeStart.hour,
      rangeStart.minute,
      rangeStart.second,
      rangeStart.millisecond,
      rangeStart.microsecond,
    );
    final normalizedEnd = DateTime(
      rangeEnd.year,
      rangeEnd.month,
      rangeEnd.day,
      rangeEnd.hour,
      rangeEnd.minute,
      rangeEnd.second,
      rangeEnd.millisecond,
      rangeEnd.microsecond,
    );

    final results = <CalendarTask>[];
    final emittedIds = <String>{};

    for (final task in model.tasks.values) {
      final baseInstance = task.baseOccurrenceInstance();
      if (baseInstance != null && baseInstance.scheduledTime != null) {
        final baseStart = baseInstance.scheduledTime!;
        final baseEnd = baseInstance.effectiveEndDate ?? baseStart;
        if (_overlapsRange(
          baseStart,
          baseEnd,
          normalizedStart,
          normalizedEnd,
        )) {
          results.add(baseInstance);
          emittedIds.add(baseInstance.id);
        }
      }

      if (!task.hasRecurrenceData) {
        continue;
      }

      final generated = task.occurrencesWithin(normalizedStart, normalizedEnd);
      for (final occurrence in generated) {
        if (emittedIds.contains(occurrence.id)) {
          continue;
        }
        final occurrenceStart = occurrence.scheduledTime;
        if (occurrenceStart == null) continue;
        final occurrenceEnd = occurrence.effectiveEndDate ?? occurrenceStart;
        if (_overlapsRange(
          occurrenceStart,
          occurrenceEnd,
          normalizedStart,
          normalizedEnd,
        )) {
          results.add(occurrence);
          emittedIds.add(occurrence.id);
        }
      }

      if (task.occurrenceOverrides.isNotEmpty) {
        for (final MapEntry<String, TaskOccurrenceOverride> entry
            in task.occurrenceOverrides.entries) {
          final override = entry.value;
          if (override.isCancelled == true) {
            continue;
          }
          final DateTime? originalStart = task.originalStartForOccurrenceKey(
            entry.key,
          );
          if (originalStart == null) {
            continue;
          }
          final CalendarTask instance = task.createOccurrenceInstance(
            originalStart: originalStart,
            occurrenceKey: entry.key,
            override: override,
          );
          if (emittedIds.contains(instance.id)) {
            continue;
          }
          final DateTime? overrideStart = instance.scheduledTime;
          if (overrideStart == null) {
            continue;
          }
          final DateTime overrideEnd =
              instance.effectiveEndDate ?? overrideStart;
          if (_overlapsRange(
            overrideStart,
            overrideEnd,
            normalizedStart,
            normalizedEnd,
          )) {
            results.add(instance);
            emittedIds.add(instance.id);
          }
        }
      }
    }

    results.sort((a, b) {
      final aTime = a.scheduledTime;
      final bTime = b.scheduledTime;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });

    return results;
  }

  List<DayEvent> dayEventsForDate(DateTime date) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    return dayEventsInRange(normalized, normalized);
  }

  List<DayEvent> dayEventsInRange(DateTime rangeStart, DateTime rangeEnd) {
    final DateTime normalizedStart = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day,
    );
    final DateTime normalizedEnd = DateTime(
      rangeEnd.year,
      rangeEnd.month,
      rangeEnd.day,
    );

    final List<DayEvent> events = model.dayEvents.values
        .where(
          (DayEvent event) =>
              !event.normalizedEnd.isBefore(normalizedStart) &&
              !event.normalizedStart.isAfter(normalizedEnd),
        )
        .toList();
    events.sort((a, b) => a.normalizedStart.compareTo(b.normalizedStart));
    return events;
  }

  int dayEventCountForDate(DateTime date) => dayEventsForDate(date).length;

  CalendarTask? currentTaskAt(DateTime moment) {
    CalendarTask? active;
    for (final task in model.tasks.values) {
      if (task.isCompleted) continue;
      final start = task.scheduledTime;
      if (start == null) continue;
      final Duration fallbackDuration =
          task.effectiveDuration ?? const Duration(hours: 1);
      final DateTime end = task.effectiveEndDate ?? start.add(fallbackDuration);
      final bool startsBeforeOrNow = !start.isAfter(moment);
      final bool endsAfterNow = end.isAfter(moment);
      if (startsBeforeOrNow && endsAfterNow) {
        if (active == null || (active.scheduledTime ?? moment).isAfter(start)) {
          active = task;
        }
      }
    }
    return active;
  }

  List<CalendarCriticalPath> criticalPathsForTask(CalendarTask task) {
    final String baseId = baseTaskIdFrom(task.id);
    return criticalPaths
        .where((path) => path.taskIds.any((id) => baseTaskIdFrom(id) == baseId))
        .toList();
  }

  bool _overlapsRange(
    DateTime eventStart,
    DateTime eventEnd,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return !eventEnd.isBefore(rangeStart) && !eventStart.isAfter(rangeEnd);
  }
}

extension CalendarAlertBadgeModelExtensions on CalendarModel {
  CalendarAlertBadgeCounts alertBadgeCounts(DateTime now) {
    var scheduled = 0;
    var unscheduled = 0;

    for (final CalendarTask task in tasks.values) {
      final CalendarTask? dueTask = _dueAlertTaskFor(task, now);
      if (dueTask == null) {
        continue;
      }
      if (dueTask.scheduledTime == null) {
        unscheduled += 1;
      } else {
        scheduled += 1;
      }
    }

    if (scheduled == 0 && unscheduled == 0) {
      return CalendarAlertBadgeCounts.empty;
    }
    return CalendarAlertBadgeCounts(
      scheduled: scheduled,
      unscheduled: unscheduled,
    );
  }

  CalendarTask? _dueAlertTaskFor(CalendarTask task, DateTime now) {
    if (!task.hasRecurrenceData) {
      return _hasDueCalendarAlert(task, now) ? task : null;
    }

    final Map<String, CalendarTask> candidates = <String, CalendarTask>{};
    final CalendarTask? baseInstance = task.baseOccurrenceInstance();
    if (baseInstance != null) {
      candidates[baseInstance.id] = baseInstance;
    } else {
      candidates[task.id] = task;
    }

    final Duration maxOffset = _maxReminderOffset(task.effectiveReminders);
    final DateTime rangeStart = now.subtract(const Duration(days: 366));
    final DateTime rangeEnd = now.add(maxOffset);
    for (final CalendarTask occurrence in task.occurrencesWithin(
      rangeStart,
      rangeEnd,
    )) {
      candidates[occurrence.id] = occurrence;
    }

    final List<CalendarTask> due =
        candidates.values
            .where(
              (CalendarTask candidate) => _hasDueCalendarAlert(candidate, now),
            )
            .toList()
          ..sort((CalendarTask left, CalendarTask right) {
            final DateTime leftTime = _calendarAlertSortTime(left, now);
            final DateTime rightTime = _calendarAlertSortTime(right, now);
            return leftTime.compareTo(rightTime);
          });

    return due.isEmpty ? null : due.first;
  }

  bool _hasDueCalendarAlert(CalendarTask task, DateTime now) {
    if (task.isCompleted) {
      return false;
    }
    final DateTime? deadline = task.deadline;
    if (deadline != null && !deadline.isAfter(now)) {
      return true;
    }

    final ReminderPreferences reminders = task.effectiveReminders;
    if (!reminders.isEnabled) {
      return false;
    }
    final DateTime? scheduled = task.scheduledTime;
    if (scheduled != null &&
        _hasDueReminderFireTime(scheduled, reminders.startOffsets, now)) {
      return true;
    }
    if (deadline != null &&
        _hasDueReminderFireTime(deadline, reminders.deadlineOffsets, now)) {
      return true;
    }
    return false;
  }

  bool _hasDueReminderFireTime(
    DateTime anchor,
    List<Duration> offsets,
    DateTime now,
  ) {
    for (final Duration offset in offsets) {
      if (!anchor.subtract(offset).isAfter(now)) {
        return true;
      }
    }
    return false;
  }

  Duration _maxReminderOffset(ReminderPreferences reminders) {
    Duration maxOffset = Duration.zero;
    for (final Duration offset in reminders.startOffsets) {
      if (offset > maxOffset) {
        maxOffset = offset;
      }
    }
    for (final Duration offset in reminders.deadlineOffsets) {
      if (offset > maxOffset) {
        maxOffset = offset;
      }
    }
    return maxOffset;
  }

  DateTime _calendarAlertSortTime(CalendarTask task, DateTime now) {
    DateTime? earliest;
    void consider(DateTime value) {
      if (value.isAfter(now)) {
        return;
      }
      if (earliest == null || value.isBefore(earliest!)) {
        earliest = value;
      }
    }

    final DateTime? deadline = task.deadline;
    if (deadline != null) {
      consider(deadline);
    }
    final ReminderPreferences reminders = task.effectiveReminders;
    final DateTime? scheduled = task.scheduledTime;
    if (scheduled != null) {
      for (final Duration offset in reminders.startOffsets) {
        consider(scheduled.subtract(offset));
      }
    }
    if (deadline != null) {
      for (final Duration offset in reminders.deadlineOffsets) {
        consider(deadline.subtract(offset));
      }
    }
    return earliest ?? now;
  }
}
