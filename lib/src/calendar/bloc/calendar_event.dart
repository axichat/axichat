import 'package:freezed_annotation/freezed_annotation.dart';

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

  const factory CalendarEvent.viewChanged({
    required CalendarView view,
  }) = CalendarViewChanged;

  const factory CalendarEvent.dateSelected({
    required DateTime date,
  }) = CalendarDateSelected;

  const factory CalendarEvent.errorCleared() = CalendarErrorCleared;
}

enum CalendarView { week, day, month }
