import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/calendar_model.dart';
import '../models/calendar_task.dart';

part 'calendar_event.freezed.dart';

@freezed
class CalendarEvent with _$CalendarEvent {
  const factory CalendarEvent.started() = CalendarStarted;

  const factory CalendarEvent.dataChanged() = CalendarDataChanged;

  const factory CalendarEvent.taskAdded({
    required String title,
    DateTime? scheduledTime,
    String? description,
    Duration? duration,
    DateTime? deadline,
    String? location,
    int? daySpan,
    DateTime? endDate,
    @Default(TaskPriority.none) TaskPriority priority,
    double? startHour,
    RecurrenceRule? recurrence,
  }) = CalendarTaskAdded;

  const factory CalendarEvent.taskUpdated({
    required CalendarTask task,
  }) = CalendarTaskUpdated;

  const factory CalendarEvent.taskDeleted({
    required String taskId,
  }) = CalendarTaskDeleted;

  const factory CalendarEvent.taskCompleted({
    required String taskId,
    required bool completed,
  }) = CalendarTaskCompleted;

  const factory CalendarEvent.syncRequested() = CalendarSyncRequested;

  const factory CalendarEvent.syncPushed() = CalendarSyncPushed;

  const factory CalendarEvent.remoteModelApplied({
    required CalendarModel model,
  }) = CalendarRemoteModelApplied;

  const factory CalendarEvent.remoteTaskApplied({
    required CalendarTask task,
    required String operation,
  }) = CalendarRemoteTaskApplied;

  const factory CalendarEvent.viewChanged({
    required CalendarView view,
  }) = CalendarViewChanged;

  const factory CalendarEvent.dateSelected({
    required DateTime date,
  }) = CalendarDateSelected;

  const factory CalendarEvent.errorCleared() = CalendarErrorCleared;

  // Enhanced events for weekly schedule
  const factory CalendarEvent.dayViewSelected({
    required int dayIndex,
  }) = CalendarDayViewSelected;

  const factory CalendarEvent.taskDragStarted({
    required String taskId,
  }) = CalendarTaskDragStarted;

  const factory CalendarEvent.taskDropped({
    required String taskId,
    required DateTime time,
    int? dayIndex,
  }) = CalendarTaskDropped;

  const factory CalendarEvent.taskResized({
    required String taskId,
    required double startHour,
    required double duration,
    int? daySpan,
  }) = CalendarTaskResized;

  const factory CalendarEvent.taskOccurrenceUpdated({
    required String taskId,
    required String occurrenceId,
    DateTime? scheduledTime,
    Duration? duration,
    DateTime? endDate,
    int? daySpan,
    bool? isCancelled,
  }) = CalendarTaskOccurrenceUpdated;

  const factory CalendarEvent.taskPriorityChanged({
    required String taskId,
    required TaskPriority priority,
  }) = CalendarTaskPriorityChanged;

  const factory CalendarEvent.quickTaskAdded({
    required String text,
    String? description,
    DateTime? deadline,
    @Default(TaskPriority.none) TaskPriority priority,
  }) = CalendarQuickTaskAdded;
}

enum CalendarView { week, day, month }
