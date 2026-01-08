// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/view/controllers/task_draft_controller.dart';
import 'package:axichat/src/calendar/view/widgets/recurrence_editor.dart';

class TaskDraftSnapshot {
  const TaskDraftSnapshot({
    required this.startTime,
    required this.endTime,
    required this.deadline,
    required this.recurrence,
    required this.isImportant,
    required this.isUrgent,
    required this.reminders,
    required this.status,
    required this.transparency,
    required this.categories,
    required this.url,
    required this.geo,
    required this.advancedAlarms,
    required this.organizer,
    required this.attendees,
  });

  factory TaskDraftSnapshot.fromController(TaskDraftController controller) {
    return TaskDraftSnapshot(
      startTime: controller.startTime,
      endTime: controller.endTime,
      deadline: controller.deadline,
      recurrence: controller.recurrence,
      isImportant: controller.isImportant,
      isUrgent: controller.isUrgent,
      reminders: controller.reminders,
      status: controller.status,
      transparency: controller.transparency,
      categories: controller.categories,
      url: controller.url,
      geo: controller.geo,
      advancedAlarms: controller.advancedAlarms,
      organizer: controller.organizer,
      attendees: controller.attendees,
    );
  }

  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? deadline;
  final RecurrenceFormValue recurrence;
  final bool isImportant;
  final bool isUrgent;
  final ReminderPreferences reminders;
  final CalendarIcsStatus? status;
  final CalendarTransparency? transparency;
  final List<String> categories;
  final String? url;
  final CalendarGeo? geo;
  final List<CalendarAlarm> advancedAlarms;
  final CalendarOrganizer? organizer;
  final List<CalendarAttendee> attendees;

  bool get hasValues =>
      startTime != null ||
      endTime != null ||
      deadline != null ||
      recurrence.isActive ||
      isImportant ||
      isUrgent ||
      reminders != ReminderPreferences.defaults() ||
      status != null ||
      transparency != null ||
      categories.isNotEmpty ||
      url != null ||
      geo != null ||
      advancedAlarms.isNotEmpty ||
      organizer != null ||
      attendees.isNotEmpty;

  void applyTo(TaskDraftController controller) {
    controller
      ..updateStart(startTime)
      ..updateEnd(endTime)
      ..setDeadline(deadline)
      ..setRecurrence(recurrence)
      ..setImportant(isImportant)
      ..setUrgent(isUrgent)
      ..setReminders(reminders)
      ..setStatus(status)
      ..setTransparency(transparency)
      ..setCategories(categories)
      ..setUrl(url)
      ..setGeo(geo)
      ..setAdvancedAlarms(advancedAlarms)
      ..setOrganizer(organizer)
      ..setAttendees(attendees);
  }
}

class TaskSidebarDraft {
  const TaskSidebarDraft({
    required this.title,
    required this.description,
    required this.location,
    required this.checklist,
    required this.pendingChecklistEntry,
    required this.snapshot,
    required this.queuedCriticalPathIds,
  });

  final String title;
  final String description;
  final String location;
  final List<TaskChecklistItem> checklist;
  final String pendingChecklistEntry;
  final TaskDraftSnapshot snapshot;
  final List<String> queuedCriticalPathIds;

  bool get hasContent =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      location.trim().isNotEmpty ||
      pendingChecklistEntry.trim().isNotEmpty ||
      checklist.isNotEmpty ||
      snapshot.hasValues ||
      queuedCriticalPathIds.isNotEmpty;
}

class QuickAddDraft {
  const QuickAddDraft({
    required this.title,
    required this.description,
    required this.location,
    required this.checklist,
    required this.pendingChecklistEntry,
    required this.snapshot,
    required this.queuedCriticalPathIds,
  });

  final String title;
  final String description;
  final String location;
  final List<TaskChecklistItem> checklist;
  final String pendingChecklistEntry;
  final TaskDraftSnapshot snapshot;
  final List<String> queuedCriticalPathIds;

  bool get hasContent =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      location.trim().isNotEmpty ||
      pendingChecklistEntry.trim().isNotEmpty ||
      checklist.isNotEmpty ||
      snapshot.hasValues ||
      queuedCriticalPathIds.isNotEmpty;
}

class TaskEditDraft {
  const TaskEditDraft({
    required this.title,
    required this.description,
    required this.location,
    required this.checklist,
    required this.pendingChecklistEntry,
    required this.isImportant,
    required this.isUrgent,
    required this.isCompleted,
    required this.startTime,
    required this.endTime,
    required this.deadline,
    required this.recurrence,
    required this.reminders,
    required this.status,
    required this.transparency,
    required this.categories,
    required this.url,
    required this.geo,
    required this.advancedAlarms,
    required this.organizer,
    required this.attendees,
  });

  final String title;
  final String description;
  final String location;
  final List<TaskChecklistItem> checklist;
  final String pendingChecklistEntry;
  final bool isImportant;
  final bool isUrgent;
  final bool isCompleted;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? deadline;
  final RecurrenceFormValue recurrence;
  final ReminderPreferences reminders;
  final CalendarIcsStatus? status;
  final CalendarTransparency? transparency;
  final List<String> categories;
  final String? url;
  final CalendarGeo? geo;
  final List<CalendarAlarm> advancedAlarms;
  final CalendarOrganizer? organizer;
  final List<CalendarAttendee> attendees;
}

class CalendarTaskDraftStore {
  TaskSidebarDraft? _sidebarDraft;
  QuickAddDraft? _quickAddDraft;
  final Map<String, TaskEditDraft> _taskDrafts = <String, TaskEditDraft>{};

  TaskSidebarDraft? get sidebarDraft => _sidebarDraft;
  QuickAddDraft? get quickAddDraft => _quickAddDraft;

  TaskEditDraft? draftForTask(String taskId) => _taskDrafts[taskId];

  void setSidebarDraft(TaskSidebarDraft draft) {
    _sidebarDraft = draft;
  }

  void clearSidebarDraft() {
    _sidebarDraft = null;
  }

  void setQuickAddDraft(QuickAddDraft draft) {
    _quickAddDraft = draft;
  }

  void clearQuickAddDraft() {
    _quickAddDraft = null;
  }

  void setTaskDraft(String taskId, TaskEditDraft draft) {
    _taskDrafts[taskId] = draft;
  }

  void clearTaskDraft(String taskId) {
    _taskDrafts.remove(taskId);
  }

  void clearAll() {
    _sidebarDraft = null;
    _quickAddDraft = null;
    _taskDrafts.clear();
  }
}
