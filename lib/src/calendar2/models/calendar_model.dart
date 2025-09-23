import 'package:freezed_annotation/freezed_annotation.dart';

import 'calendar_task.dart';

part 'calendar_model.freezed.dart';
part 'calendar_model.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum CalendarView {
  day,
  week,
  month,
}

@freezed
class CalendarModel with _$CalendarModel {
  const CalendarModel._();

  const factory CalendarModel({
    @Default(1) int version,
    required DateTime lastUpdated,
    required DateTime selectedDate,
    @Default(CalendarView.week) CalendarView view,
    @Default(<String, CalendarTask>{}) Map<String, CalendarTask> tasks,
  }) = _CalendarModel;

  factory CalendarModel.fromJson(Map<String, dynamic> json) =>
      _$CalendarModelFromJson(json);

  factory CalendarModel.empty({DateTime? selectedDate}) {
    final now = DateTime.now();
    final normalizedDate = _stripTime(selectedDate ?? now);
    return CalendarModel(
      version: 1,
      lastUpdated: now,
      selectedDate: normalizedDate,
    );
  }

  CalendarModel addTask(CalendarTask task) {
    final now = DateTime.now();
    final updatedTask = task.sanitized(timestamp: now);
    final updatedTasks = Map<String, CalendarTask>.from(tasks)
      ..[updatedTask.id] = updatedTask;
    return copyWith(
      tasks: Map.unmodifiable(updatedTasks),
      lastUpdated: now,
    );
  }

  CalendarModel updateTask(CalendarTask task) {
    if (!tasks.containsKey(task.id)) {
      return this;
    }
    final existing = tasks[task.id]!;
    final now = DateTime.now();
    final merged = task.copyWith(createdAt: existing.createdAt);
    final updatedTask = merged.sanitized(timestamp: now);
    final updatedTasks = Map<String, CalendarTask>.from(tasks)
      ..[task.id] = updatedTask;
    return copyWith(
      tasks: Map.unmodifiable(updatedTasks),
      lastUpdated: now,
    );
  }

  CalendarModel deleteTask(String taskId) {
    if (!tasks.containsKey(taskId)) {
      return this;
    }
    final updatedTasks = Map<String, CalendarTask>.from(tasks)..remove(taskId);
    return copyWith(
      tasks: Map.unmodifiable(updatedTasks),
      lastUpdated: DateTime.now(),
    );
  }

  List<CalendarTask> get unscheduledTasks {
    final unscheduled = tasks.values.where((task) => !task.isScheduled).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(unscheduled);
  }

  List<CalendarTask> get scheduledTasks {
    final scheduled = tasks.values.where((task) => task.isScheduled).toList()
      ..sort((a, b) {
        final aStart = a.scheduledStart ?? a.createdAt;
        final bStart = b.scheduledStart ?? b.createdAt;
        return aStart.compareTo(bStart);
      });
    return List.unmodifiable(scheduled);
  }

  DateTime get weekStart {
    final normalized = _stripTime(selectedDate);
    final weekday = normalized.weekday;
    final delta = weekday - DateTime.monday;
    return normalized.subtract(Duration(days: delta));
  }

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  List<CalendarTask> get tasksForSelectedWeek {
    final start = weekStart;
    final end = weekEnd;
    final filtered = scheduledTasks
        .where(
          (task) => _rangesOverlap(
            task.effectiveStart,
            task.effectiveEnd,
            start,
            end,
          ),
        )
        .toList();
    return List.unmodifiable(filtered);
  }

  List<CalendarTask> get tasksForSelectedDay {
    final date = _stripTime(selectedDate);
    final filtered =
        scheduledTasks.where((task) => _occursOnDate(task, date)).toList();
    return List.unmodifiable(filtered);
  }
}

DateTime _stripTime(DateTime input) =>
    DateTime(input.year, input.month, input.day);

bool _rangesOverlap(
  DateTime? startA,
  DateTime? endA,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  if (startA == null) {
    return false;
  }
  final taskStart = startA;
  final taskEnd = endA ?? startA;
  final taskStartDate = _stripTime(taskStart);
  final taskEndDate = _stripTime(taskEnd);
  final start = _stripTime(rangeStart);
  final end = _stripTime(rangeEnd);
  return !(taskEndDate.isBefore(start) || taskStartDate.isAfter(end));
}

bool _occursOnDate(CalendarTask task, DateTime date) {
  final start = task.effectiveStart;
  if (start == null) {
    return false;
  }
  final end = task.effectiveEnd ?? start;
  final target = _stripTime(date);
  final startDate = _stripTime(start);
  final endDate = _stripTime(end);
  return !target.isBefore(startDate) && !target.isAfter(endDate);
}
