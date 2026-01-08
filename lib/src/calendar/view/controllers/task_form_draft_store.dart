// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/view/controllers/task_draft_controller.dart';
import 'package:axichat/src/calendar/view/widgets/recurrence_editor.dart';

const int _maxTaskDraftEntries = 8;

enum TaskFormVisibility {
  open,
  suspended;

  bool get isOpen => this == TaskFormVisibility.open;

  bool get isSuspended => this == TaskFormVisibility.suspended;
}

enum TaskEditSurface {
  popover,
  sheet;

  bool get isPopover => this == TaskEditSurface.popover;

  bool get isSheet => this == TaskEditSurface.sheet;
}

enum TaskEditHost {
  grid,
  sidebar;

  bool get isGrid => this == TaskEditHost.grid;

  bool get isSidebar => this == TaskEditHost.sidebar;
}

enum QuickAddSurface {
  dialog,
  sheet;

  bool get isDialog => this == QuickAddSurface.dialog;

  bool get isSheet => this == QuickAddSurface.sheet;
}

class TaskEditSessionState {
  const TaskEditSessionState({
    required this.taskId,
    required this.surface,
    required this.host,
    required this.visibility,
  });

  final String taskId;
  final TaskEditSurface surface;
  final TaskEditHost host;
  final TaskFormVisibility visibility;

  bool get isOpen => visibility.isOpen;

  bool get isSuspended => visibility.isSuspended;

  TaskEditSessionState copyWith({
    String? taskId,
    TaskEditSurface? surface,
    TaskEditHost? host,
    TaskFormVisibility? visibility,
  }) {
    return TaskEditSessionState(
      taskId: taskId ?? this.taskId,
      surface: surface ?? this.surface,
      host: host ?? this.host,
      visibility: visibility ?? this.visibility,
    );
  }
}

class QuickAddSessionState {
  const QuickAddSessionState({
    required this.surface,
    required this.visibility,
    this.prefilledDateTime,
    this.prefilledText,
  });

  final QuickAddSurface surface;
  final TaskFormVisibility visibility;
  final DateTime? prefilledDateTime;
  final String? prefilledText;

  bool get isOpen => visibility.isOpen;

  bool get isSuspended => visibility.isSuspended;

  QuickAddSessionState copyWith({
    QuickAddSurface? surface,
    TaskFormVisibility? visibility,
    DateTime? prefilledDateTime,
    String? prefilledText,
  }) {
    return QuickAddSessionState(
      surface: surface ?? this.surface,
      visibility: visibility ?? this.visibility,
      prefilledDateTime: prefilledDateTime ?? this.prefilledDateTime,
      prefilledText: prefilledText ?? this.prefilledText,
    );
  }
}

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

class CalendarTaskDraftStore extends ChangeNotifier {
  TaskSidebarDraft? _sidebarDraft;
  QuickAddDraft? _quickAddDraft;
  final Map<String, TaskEditDraft> _taskDrafts = <String, TaskEditDraft>{};
  final ListQueue<String> _taskDraftOrder = ListQueue<String>();
  TaskEditSessionState? _editSession;
  QuickAddSessionState? _quickAddSession;
  bool _calendarVisible = true;

  TaskSidebarDraft? get sidebarDraft => _sidebarDraft;
  QuickAddDraft? get quickAddDraft => _quickAddDraft;
  TaskEditSessionState? get editSession => _editSession;
  QuickAddSessionState? get quickAddSession => _quickAddSession;
  bool get isCalendarVisible => _calendarVisible;

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
    _touchTaskDraft(taskId);
    _pruneTaskDrafts();
  }

  void clearTaskDraft(String taskId) {
    _taskDrafts.remove(taskId);
    _taskDraftOrder.remove(taskId);
  }

  void clearAll() {
    _sidebarDraft = null;
    _quickAddDraft = null;
    _taskDrafts.clear();
    _taskDraftOrder.clear();
    _editSession = null;
    _quickAddSession = null;
  }

  void setCalendarVisible(bool value) {
    if (_calendarVisible == value) {
      return;
    }
    _calendarVisible = value;
    if (!value) {
      _editSession = _suspendSession(_editSession);
      _quickAddSession = _suspendSession(_quickAddSession);
    }
    notifyListeners();
  }

  void activateEditSession(TaskEditSessionState session) {
    _editSession = session.copyWith(visibility: TaskFormVisibility.open);
    notifyListeners();
  }

  void suspendEditSession(String taskId) {
    if (_editSession?.taskId != taskId) {
      return;
    }
    final TaskEditSessionState? suspended = _suspendSession(_editSession);
    if (suspended == _editSession) {
      return;
    }
    _editSession = suspended;
    notifyListeners();
  }

  void clearEditSession(String taskId) {
    if (_editSession?.taskId != taskId) {
      return;
    }
    _editSession = null;
    notifyListeners();
  }

  void activateQuickAddSession(QuickAddSessionState session) {
    _quickAddSession = session.copyWith(visibility: TaskFormVisibility.open);
    notifyListeners();
  }

  void suspendQuickAddSession() {
    final QuickAddSessionState? suspended = _suspendSession(_quickAddSession);
    if (suspended == _quickAddSession) {
      return;
    }
    _quickAddSession = suspended;
    notifyListeners();
  }

  void clearQuickAddSession() {
    if (_quickAddSession == null) {
      return;
    }
    _quickAddSession = null;
    notifyListeners();
  }

  void _touchTaskDraft(String taskId) {
    _taskDraftOrder
      ..remove(taskId)
      ..add(taskId);
  }

  void _pruneTaskDrafts() {
    if (_taskDrafts.length <= _maxTaskDraftEntries) {
      return;
    }
    while (_taskDrafts.length > _maxTaskDraftEntries &&
        _taskDraftOrder.isNotEmpty) {
      final String oldest = _taskDraftOrder.removeFirst();
      if (_editSession?.taskId == oldest) {
        _taskDraftOrder.add(oldest);
        continue;
      }
      _taskDrafts.remove(oldest);
    }
  }

  T? _suspendSession<T extends Object>(T? session) {
    if (session is TaskEditSessionState) {
      if (session.isSuspended) {
        return session;
      }
      return session.copyWith(visibility: TaskFormVisibility.suspended) as T;
    }
    if (session is QuickAddSessionState) {
      if (session.isSuspended) {
        return session;
      }
      return session.copyWith(visibility: TaskFormVisibility.suspended) as T;
    }
    return session;
  }
}
