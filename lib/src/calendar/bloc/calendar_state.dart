import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import 'calendar_event.dart';

part 'calendar_state.freezed.dart';

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

    for (final task in model.tasks.values) {
      final baseInstance = task.baseOccurrenceInstance();
      if (baseInstance != null && baseInstance.scheduledTime != null) {
        final baseStart = baseInstance.scheduledTime!;
        final baseEnd = baseInstance.effectiveEndDate ?? baseStart;
        if (_overlapsRange(
            baseStart, baseEnd, normalizedStart, normalizedEnd)) {
          results.add(baseInstance);
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

  bool _overlapsRange(
    DateTime eventStart,
    DateTime eventEnd,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return !eventEnd.isBefore(rangeStart) && !eventStart.isAfter(rangeEnd);
  }
}
