import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
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

@freezed
class CalendarState with _$CalendarState {
  const factory CalendarState({
    required CalendarModel model,
    @Default(false) bool isSyncing,
    @Default(false) bool isLoading,
    DateTime? lastSyncTime,
    String? syncError,
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
  }) = _CalendarState;

  factory CalendarState.initial() => CalendarState(
        model: CalendarModel.empty(),
        selectedDate: DateTime.now(),
      );
}

extension CalendarStateExtensions on CalendarState {
  List<CalendarTask> get unscheduledTasks =>
      model.tasks.values.where((task) => task.scheduledTime == null).toList();

  List<CalendarTask> get scheduledTasks =>
      model.tasks.values.where((task) => task.scheduledTime != null).toList();

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
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromMonday));
  }

  DateTime get weekEnd {
    final start = weekStart;
    return start
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
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
            baseStart, baseEnd, normalizedStart, normalizedEnd)) {
          results.add(baseInstance);
          emittedIds.add(baseInstance.id);
        }
      }

      if (task.effectiveRecurrence.isNone) {
        continue;
      }

      final generated = task.occurrencesWithin(normalizedStart, normalizedEnd);
      for (final occurrence in generated) {
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
          final DateTime? originalStart =
              task.originalStartForOccurrenceKey(entry.key);
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
    final DateTime normalizedStart =
        DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final DateTime normalizedEnd =
        DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    final List<DayEvent> events = model.dayEvents.values
        .where(
          (DayEvent event) =>
              !event.normalizedEnd.isBefore(normalizedStart) &&
              !event.normalizedStart.isAfter(normalizedEnd),
        )
        .toList();
    events.sort(
      (a, b) => a.normalizedStart.compareTo(b.normalizedStart),
    );
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
        .where(
          (path) => path.taskIds.any(
            (id) => baseTaskIdFrom(id) == baseId,
          ),
        )
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
