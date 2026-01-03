// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';

import 'calendar_availability.dart';
import 'calendar_critical_path.dart';
import 'calendar_task.dart';
import 'day_event.dart';
import 'reminder_preferences.dart';

part 'calendar_fragment.freezed.dart';
part 'calendar_fragment.g.dart';

const String _calendarFragmentUnionKey = 'type';
const List<TaskChecklistItem> _emptyTaskChecklistItems = <TaskChecklistItem>[];
const List<CalendarTask> _emptyCriticalPathTasks = <CalendarTask>[];

@Freezed(
  unionKey: _calendarFragmentUnionKey,
  unionValueCase: FreezedUnionCase.snake,
)
class CalendarFragment with _$CalendarFragment {
  const factory CalendarFragment.task({
    required CalendarTask task,
  }) = CalendarTaskFragment;

  const factory CalendarFragment.checklist({
    required String taskId,
    @Default(_emptyTaskChecklistItems) List<TaskChecklistItem> checklist,
  }) = CalendarChecklistFragment;

  const factory CalendarFragment.reminder({
    required String taskId,
    required ReminderPreferences reminders,
  }) = CalendarReminderFragment;

  const factory CalendarFragment.dayEvent({
    required DayEvent event,
  }) = CalendarDayEventFragment;

  const factory CalendarFragment.criticalPath({
    required CalendarCriticalPath path,
    @Default(_emptyCriticalPathTasks) List<CalendarTask> tasks,
  }) = CalendarCriticalPathFragment;

  const factory CalendarFragment.freeBusy({
    required CalendarFreeBusyInterval interval,
  }) = CalendarFreeBusyFragment;

  const factory CalendarFragment.availability({
    required CalendarAvailabilityWindow window,
  }) = CalendarAvailabilityFragment;

  factory CalendarFragment.fromJson(Map<String, dynamic> json) =>
      _$CalendarFragmentFromJson(json);
}
