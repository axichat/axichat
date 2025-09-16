import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
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
    final weekday = date.weekday;
    final daysToSubtract = weekday == DateTime.sunday ? 0 : weekday;
    return DateTime(date.year, date.month, date.day - daysToSubtract);
  }

  DateTime get weekEnd {
    final start = weekStart;
    return start
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  List<CalendarTask> get tasksForSelectedWeek {
    final start = weekStart;
    final end = weekEnd;
    return scheduledTasks.where((task) {
      final taskDate = task.scheduledTime!;
      return taskDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
          taskDate.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<CalendarTask> get tasksForSelectedDay {
    if (selectedDayIndex == null) return [];
    final dayStart = weekStart.add(Duration(days: selectedDayIndex!));
    final dayEnd =
        dayStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    return scheduledTasks.where((task) {
      final taskDate = task.scheduledTime!;
      return taskDate.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
          taskDate.isBefore(dayEnd.add(const Duration(seconds: 1)));
    }).toList();
  }
}
