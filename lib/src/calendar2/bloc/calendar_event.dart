import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/calendar_model.dart';
import '../models/calendar_task.dart';

part 'calendar_event.freezed.dart';

@freezed
class CalendarEvent with _$CalendarEvent {
  const factory CalendarEvent.started() = CalendarStarted;

  const factory CalendarEvent.errorCleared() = CalendarErrorCleared;

  const factory CalendarEvent.viewChanged({
    required CalendarView view,
  }) = CalendarViewChanged;

  const factory CalendarEvent.dateSelected({
    required DateTime date,
  }) = CalendarDateSelected;

  const factory CalendarEvent.quickTaskAdded({
    required String text,
    String? description,
    DateTime? deadline,
    @Default(false) bool important,
    @Default(false) bool urgent,
  }) = CalendarQuickTaskAdded;

  const factory CalendarEvent.taskAdded({
    required String title,
    String? description,
    DateTime? scheduledStart,
    Duration? duration,
    DateTime? endDate,
    DateTime? deadline,
    @Default(false) bool isAllDay,
    @Default(false) bool important,
    @Default(false) bool urgent,
    @Default(<String>[]) List<String> tags,
    String? location,
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

  const factory CalendarEvent.taskDropped({
    required String taskId,
    required DateTime time,
  }) = CalendarTaskDropped;

  const factory CalendarEvent.taskResized({
    required String taskId,
    required DateTime start,
    required Duration duration,
    DateTime? endDate,
  }) = CalendarTaskResized;

  const factory CalendarEvent.taskPriorityChanged({
    required String taskId,
    required bool important,
    required bool urgent,
  }) = CalendarTaskPriorityChanged;

  const factory CalendarEvent.dayViewSelected({
    required int dayIndex,
  }) = CalendarDayViewSelected;
}
