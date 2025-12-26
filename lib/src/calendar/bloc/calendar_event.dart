import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_warning.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

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
    DateTime? endDate,
    @Default(TaskPriority.none) TaskPriority priority,
    RecurrenceRule? recurrence,
    @Default([]) List<TaskChecklistItem> checklist,
    ReminderPreferences? reminders,
    CalendarIcsMeta? icsMeta,
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

  const factory CalendarEvent.tasksImported({
    required List<CalendarTask> tasks,
  }) = CalendarTasksImported;

  const factory CalendarEvent.modelImported({
    required CalendarModel model,
  }) = CalendarModelImported;

  const factory CalendarEvent.syncWarningRaised({
    required CalendarSyncWarning warning,
  }) = CalendarSyncWarningRaised;

  const factory CalendarEvent.syncWarningCleared() = CalendarSyncWarningCleared;

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
    DateTime? scheduledTime,
    Duration? duration,
    DateTime? endDate,
  }) = CalendarTaskResized;

  const factory CalendarEvent.taskOccurrenceUpdated({
    required String taskId,
    required String occurrenceId,
    DateTime? scheduledTime,
    Duration? duration,
    DateTime? endDate,
    bool? isCancelled,
    List<TaskChecklistItem>? checklist,
  }) = CalendarTaskOccurrenceUpdated;

  const factory CalendarEvent.taskPriorityChanged({
    required String taskId,
    required TaskPriority priority,
  }) = CalendarTaskPriorityChanged;

  const factory CalendarEvent.taskSplit({
    required CalendarTask target,
    required DateTime splitTime,
  }) = CalendarTaskSplit;

  const factory CalendarEvent.taskRepeated({
    required CalendarTask template,
    required DateTime scheduledTime,
  }) = CalendarTaskRepeated;

  const factory CalendarEvent.dayEventAdded({
    required String title,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    ReminderPreferences? reminders,
    CalendarIcsMeta? icsMeta,
  }) = CalendarDayEventAdded;

  const factory CalendarEvent.dayEventUpdated({
    required DayEvent event,
  }) = CalendarDayEventUpdated;

  const factory CalendarEvent.dayEventDeleted({
    required String eventId,
  }) = CalendarDayEventDeleted;

  const factory CalendarEvent.quickTaskAdded({
    required String text,
    String? description,
    DateTime? deadline,
    @Default(TaskPriority.none) TaskPriority priority,
    @Default([]) List<TaskChecklistItem> checklist,
    ReminderPreferences? reminders,
  }) = CalendarQuickTaskAdded;

  const factory CalendarEvent.selectionModeEntered({
    String? taskId,
  }) = CalendarSelectionModeEntered;

  const factory CalendarEvent.selectionAllRequested() =
      CalendarSelectionAllRequested;

  const factory CalendarEvent.selectionToggled({
    required String taskId,
  }) = CalendarSelectionToggled;

  const factory CalendarEvent.selectionCleared() = CalendarSelectionCleared;

  const factory CalendarEvent.selectionPriorityChanged({
    required TaskPriority priority,
  }) = CalendarSelectionPriorityChanged;

  const factory CalendarEvent.selectionCompletedToggled({
    required bool completed,
  }) = CalendarSelectionCompletedToggled;

  const factory CalendarEvent.selectionDeleted() = CalendarSelectionDeleted;

  const factory CalendarEvent.selectionRecurrenceChanged({
    RecurrenceRule? recurrence,
  }) = CalendarSelectionRecurrenceChanged;

  const factory CalendarEvent.selectionTitleChanged({
    required String title,
  }) = CalendarSelectionTitleChanged;

  const factory CalendarEvent.selectionDescriptionChanged({
    String? description,
  }) = CalendarSelectionDescriptionChanged;

  const factory CalendarEvent.selectionLocationChanged({
    String? location,
  }) = CalendarSelectionLocationChanged;

  const factory CalendarEvent.selectionChecklistChanged({
    required List<TaskChecklistItem> checklist,
  }) = CalendarSelectionChecklistChanged;

  const factory CalendarEvent.selectionTimeShifted({
    Duration? startDelta,
    Duration? endDelta,
  }) = CalendarSelectionTimeShifted;

  const factory CalendarEvent.selectionRemindersChanged({
    required ReminderPreferences reminders,
  }) = CalendarSelectionRemindersChanged;

  const factory CalendarEvent.selectionIdsAdded({
    required Set<String> taskIds,
  }) = CalendarSelectionIdsAdded;

  const factory CalendarEvent.selectionIdsRemoved({
    required Set<String> taskIds,
  }) = CalendarSelectionIdsRemoved;

  const factory CalendarEvent.undoRequested() = CalendarUndoRequested;

  const factory CalendarEvent.redoRequested() = CalendarRedoRequested;

  const factory CalendarEvent.taskFocusRequested({
    required String taskId,
  }) = CalendarTaskFocusRequested;

  const factory CalendarEvent.taskFocusCleared() = CalendarTaskFocusCleared;

  const factory CalendarEvent.criticalPathCreated({
    required String name,
    String? taskId,
  }) = CalendarCriticalPathCreated;

  const factory CalendarEvent.criticalPathRenamed({
    required String pathId,
    required String name,
  }) = CalendarCriticalPathRenamed;

  const factory CalendarEvent.criticalPathDeleted({
    required String pathId,
  }) = CalendarCriticalPathDeleted;

  const factory CalendarEvent.criticalPathTaskAdded({
    required String pathId,
    required String taskId,
    int? index,
  }) = CalendarCriticalPathTaskAdded;

  const factory CalendarEvent.criticalPathTaskRemoved({
    required String pathId,
    required String taskId,
  }) = CalendarCriticalPathTaskRemoved;

  const factory CalendarEvent.criticalPathFocused({
    String? pathId,
  }) = CalendarCriticalPathFocused;

  const factory CalendarEvent.criticalPathReordered({
    required String pathId,
    required List<String> orderedTaskIds,
  }) = CalendarCriticalPathReordered;
}

enum CalendarView { week, day, month }
