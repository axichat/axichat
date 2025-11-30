import 'dart:async';
import 'dart:math';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';

/// Manages scheduling and cancellation of local notifications for calendar
/// tasks based on deadlines and scheduled start times.
class CalendarReminderController {
  CalendarReminderController({
    required NotificationService notificationService,
    DateTime Function()? now,
  })  : _notificationService = notificationService,
        _now = now ?? DateTime.now;

  final NotificationService _notificationService;
  final DateTime Function() _now;
  final Map<String, Set<int>> _scheduledIdsByEntry = {};

  /// Reconcile reminders with the provided [tasks] and [dayEvents], scheduling
  /// new alerts and cancelling obsolete ones.
  Future<void> syncWithTasks(
    Iterable<CalendarTask> tasks, {
    Iterable<DayEvent> dayEvents = const [],
  }) async {
    await _notificationService.init();
    await _notificationService.refreshTimeZone();

    final Map<String, _ReminderSubject> subjects = <String, _ReminderSubject>{
      for (final CalendarTask task in tasks)
        _taskKey(task.id): _ReminderSubject.task(task),
      for (final DayEvent event in dayEvents)
        _dayEventKey(event.id): _ReminderSubject.dayEvent(event),
    };

    final Set<String> removedKeys =
        _scheduledIdsByEntry.keys.toSet().difference(subjects.keys.toSet());
    for (final String key in removedKeys) {
      await _cancelEntry(key);
    }

    for (final MapEntry<String, _ReminderSubject> entry in subjects.entries) {
      final _ReminderSubject subject = entry.value;
      if (subject.task?.isCompleted == true) {
        await _cancelEntry(entry.key);
        continue;
      }
      await _scheduleRemindersFor(entry.key, entry.value);
    }
  }

  Future<void> clearAll() async {
    final Set<int> allIds =
        _scheduledIdsByEntry.values.expand((Set<int> ids) => ids).toSet();
    for (final id in allIds) {
      await _notificationService.cancelNotification(id);
    }
    _scheduledIdsByEntry.clear();
  }

  Future<void> _scheduleRemindersFor(
    String entryKey,
    _ReminderSubject subject,
  ) async {
    await _cancelEntry(entryKey);

    final DateTime now = _now();
    final List<_ScheduledReminder> reminders = subject.when(
      task: (CalendarTask task) => _reminderScheduleForTask(task, now),
      dayEvent: (DayEvent event) => _reminderScheduleForDayEvent(event, now),
    );
    if (reminders.isEmpty) {
      return;
    }

    final Set<int> scheduledIds = <int>{};
    for (var index = 0; index < reminders.length; index++) {
      final _ScheduledReminder reminder = reminders[index];
      if (!reminder.time.isAfter(now)) {
        continue;
      }
      final int notificationId = _notificationId(entryKey, index);
      await _notificationService.scheduleNotification(
        id: notificationId,
        scheduledAt: reminder.time,
        title: reminder.title,
        body: reminder.body,
        payload: subject.payloadId,
      );
      scheduledIds.add(notificationId);
    }

    if (scheduledIds.isEmpty) {
      _scheduledIdsByEntry.remove(entryKey);
    } else {
      _scheduledIdsByEntry[entryKey] = scheduledIds;
    }
  }

  Future<void> _cancelEntry(String entryKey) async {
    final Set<int>? ids = _scheduledIdsByEntry.remove(entryKey);
    if (ids == null) {
      return;
    }
    for (final int id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  List<_ScheduledReminder> _reminderScheduleForTask(
    CalendarTask task,
    DateTime now,
  ) {
    final ReminderPreferences prefs = task.effectiveReminders;
    if (!prefs.isEnabled) {
      return const <_ScheduledReminder>[];
    }

    final List<_ScheduledReminder> reminders = <_ScheduledReminder>[];
    if (task.deadline != null && prefs.deadlineOffsets.isNotEmpty) {
      final DateTime deadline = task.deadline!.toLocal();
      for (final Duration offset in prefs.deadlineOffsets) {
        final DateTime time = deadline.subtract(offset);
        if (!time.isAfter(now)) {
          continue;
        }
        final String label = offset == Duration.zero
            ? 'Deadline now'
            : 'Due in ${_humanizeDuration(offset)}';
        reminders.add(
          _ScheduledReminder(
            time: time,
            title: '${task.title} — $label',
            body: task.description,
          ),
        );
      }
    }

    if (task.scheduledTime != null && prefs.startOffsets.isNotEmpty) {
      final DateTime start = task.scheduledTime!.toLocal();
      for (final Duration lead in prefs.startOffsets) {
        final DateTime time = start.subtract(lead);
        if (!time.isAfter(now)) {
          continue;
        }
        final String label = lead == Duration.zero
            ? 'Starting now'
            : 'Starts in ${_humanizeDuration(lead)}';
        reminders.add(
          _ScheduledReminder(
            time: time,
            title: '${task.title} — $label',
            body: task.description,
          ),
        );
      }
    }

    reminders.sort((a, b) => a.time.compareTo(b.time));
    return reminders;
  }

  List<_ScheduledReminder> _reminderScheduleForDayEvent(
    DayEvent event,
    DateTime now,
  ) {
    final ReminderPreferences prefs = event.effectiveReminders;
    if (!prefs.isEnabled || prefs.startOffsets.isEmpty) {
      return const <_ScheduledReminder>[];
    }
    final DateTime start = event.normalizedStart.toLocal();
    final List<_ScheduledReminder> reminders = <_ScheduledReminder>[];
    for (final Duration lead in prefs.startOffsets) {
      final DateTime time = start.subtract(lead);
      if (!time.isAfter(now)) {
        continue;
      }
      final String label = lead == Duration.zero
          ? 'Happening today'
          : 'In ${_humanizeDuration(lead)}';
      reminders.add(
        _ScheduledReminder(
          time: time,
          title: '${event.title} — $label',
          body: event.description,
        ),
      );
    }
    reminders.sort((a, b) => a.time.compareTo(b.time));
    return reminders;
  }

  int _notificationId(String entryKey, int index) {
    final int base = entryKey.hashCode & 0x7fffffff;
    return base + index;
  }

  String _taskKey(String id) => 'task:$id';

  String _dayEventKey(String id) => 'day:$id';

  String _humanizeDuration(Duration duration) {
    if (duration.inHours >= 24) {
      final days = duration.inDays;
      return '$days day${days == 1 ? '' : 's'}';
    }
    if (duration.inHours >= 1) {
      final hours = duration.inHours;
      return '$hours hour${hours == 1 ? '' : 's'}';
    }
    final minutes = max(duration.inMinutes, 1);
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.time,
    required this.title,
    this.body,
  });

  final DateTime time;
  final String title;
  final String? body;
}

class _ReminderSubject {
  _ReminderSubject.task(CalendarTask value)
      : task = value,
        dayEvent = null,
        payloadId = value.id;

  _ReminderSubject.dayEvent(DayEvent value)
      : task = null,
        dayEvent = value,
        payloadId = value.id;

  final CalendarTask? task;
  final DayEvent? dayEvent;
  final String payloadId;

  T when<T>({
    required T Function(CalendarTask task) task,
    required T Function(DayEvent event) dayEvent,
  }) {
    if (this.task != null) {
      return task(this.task!);
    }
    return dayEvent(this.dayEvent!);
  }
}
