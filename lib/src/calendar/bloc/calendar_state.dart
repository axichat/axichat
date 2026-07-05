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

enum CalendarSyncWarningType {
  snapshotUnavailable,
  archiveIncomplete,
  snapshotPublishPending,
  snapshotPublishBlocked,
  reminderNotificationsDisabled,
}

enum CalendarAlertBadgeBucket {
  scheduled,
  unscheduled;

  bool includes(CalendarTask task) => switch (this) {
    CalendarAlertBadgeBucket.scheduled => task.scheduledTime != null,
    CalendarAlertBadgeBucket.unscheduled => task.scheduledTime == null,
  };
}

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
    @Default(<String>{}) Set<String> acknowledgedCalendarAlertKeys,
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
  CalendarAlertBadgeCounts alertBadgeCounts(DateTime now) => model
      .alertBadgeCounts(now, acknowledgedKeys: acknowledgedCalendarAlertKeys);

  Set<String> dueCalendarAlertKeys({
    required CalendarAlertBadgeBucket bucket,
    required DateTime now,
  }) => model.dueCalendarAlertKeys(
    now: now,
    bucket: bucket,
    acknowledgedKeys: acknowledgedCalendarAlertKeys,
  );

  Set<String> retainedCalendarAlertAcknowledgmentKeys(DateTime now) =>
      model.retainedCalendarAlertAcknowledgmentKeys(
        now,
        acknowledgedCalendarAlertKeys,
      );

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
  CalendarAlertBadgeCounts alertBadgeCounts(
    DateTime now, {
    Set<String> acknowledgedKeys = const <String>{},
  }) {
    var scheduled = 0;
    var unscheduled = 0;

    for (final CalendarTask task in tasks.values) {
      final _CalendarAlertInstance? dueAlert = _firstDueAlertForTask(
        task,
        now,
        acknowledgedKeys,
      );
      if (dueAlert == null) {
        continue;
      }
      if (dueAlert.bucket == CalendarAlertBadgeBucket.unscheduled) {
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

  Set<String> dueCalendarAlertKeys({
    required DateTime now,
    required CalendarAlertBadgeBucket bucket,
    Set<String> acknowledgedKeys = const <String>{},
  }) {
    final keys = <String>{};
    for (final CalendarTask task in tasks.values) {
      for (final _CalendarAlertInstance alert in _dueAlertsForTask(task, now)) {
        if (alert.bucket != bucket || acknowledgedKeys.contains(alert.key)) {
          continue;
        }
        keys.add(alert.key);
      }
    }
    return keys;
  }

  Set<String> retainedCalendarAlertAcknowledgmentKeys(
    DateTime now,
    Set<String> acknowledgedKeys,
  ) {
    if (acknowledgedKeys.isEmpty) {
      return const <String>{};
    }
    final activeKeys = <String>{};
    for (final CalendarTask task in tasks.values) {
      for (final _CalendarAlertInstance alert in _dueAlertsForTask(task, now)) {
        activeKeys.add(alert.key);
      }
    }
    final retained = <String>{};
    for (final String key in acknowledgedKeys) {
      if (activeKeys.contains(key)) {
        retained.add(key);
      }
    }
    return retained;
  }

  _CalendarAlertInstance? _firstDueAlertForTask(
    CalendarTask task,
    DateTime now,
    Set<String> acknowledgedKeys,
  ) {
    final List<_CalendarAlertInstance> due =
        _dueAlertsForTask(task, now)
            .where(
              (_CalendarAlertInstance alert) =>
                  !acknowledgedKeys.contains(alert.key),
            )
            .toList()
          ..sort(_compareCalendarAlerts);
    return due.isEmpty ? null : due.first;
  }

  Iterable<_CalendarAlertInstance> _dueAlertsForTask(
    CalendarTask task,
    DateTime now,
  ) sync* {
    if (!task.hasRecurrenceData) {
      yield* _dueAlertsForSingleTask(task, now);
      return;
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

    for (final CalendarTask candidate in candidates.values) {
      yield* _dueAlertsForSingleTask(candidate, now);
    }
  }

  Iterable<_CalendarAlertInstance> _dueAlertsForSingleTask(
    CalendarTask task,
    DateTime now,
  ) sync* {
    if (task.isCompleted) {
      return;
    }
    final DateTime? deadline = task.deadline;
    if (deadline != null && !deadline.isAfter(now)) {
      yield _CalendarAlertInstance(
        task: task,
        kind: 'deadline',
        anchorTime: deadline,
        offset: null,
        fireTime: deadline,
      );
    }

    final ReminderPreferences reminders = task.effectiveReminders;
    if (!reminders.isEnabled) {
      return;
    }
    final DateTime? scheduled = task.scheduledTime;
    if (scheduled != null) {
      for (final Duration offset in reminders.startOffsets) {
        final DateTime fireTime = scheduled.subtract(offset);
        if (fireTime.isAfter(now)) {
          continue;
        }
        yield _CalendarAlertInstance(
          task: task,
          kind: 'start-reminder',
          anchorTime: scheduled,
          offset: offset,
          fireTime: fireTime,
        );
      }
    }
    if (deadline != null) {
      for (final Duration offset in reminders.deadlineOffsets) {
        final DateTime fireTime = deadline.subtract(offset);
        if (fireTime.isAfter(now)) {
          continue;
        }
        yield _CalendarAlertInstance(
          task: task,
          kind: 'deadline-reminder',
          anchorTime: deadline,
          offset: offset,
          fireTime: fireTime,
        );
      }
    }
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

  int _compareCalendarAlerts(
    _CalendarAlertInstance left,
    _CalendarAlertInstance right,
  ) {
    final int fireTimeComparison = left.fireTime.compareTo(right.fireTime);
    if (fireTimeComparison != 0) {
      return fireTimeComparison;
    }
    return left.key.compareTo(right.key);
  }
}

@immutable
class _CalendarAlertInstance {
  const _CalendarAlertInstance({
    required this.task,
    required this.kind,
    required this.anchorTime,
    required this.offset,
    required this.fireTime,
  });

  final CalendarTask task;
  final String kind;
  final DateTime anchorTime;
  final Duration? offset;
  final DateTime fireTime;

  CalendarAlertBadgeBucket get bucket => task.scheduledTime == null
      ? CalendarAlertBadgeBucket.unscheduled
      : CalendarAlertBadgeBucket.scheduled;

  String get key {
    final Duration? alertOffset = offset;
    final String offsetKey = alertOffset == null
        ? 'none'
        : '${alertOffset.inMicroseconds}';
    return [
      task.id,
      kind,
      anchorTime.toUtc().toIso8601String(),
      offsetKey,
      fireTime.toUtc().toIso8601String(),
    ].join('|');
  }
}
