import 'dart:async';
import 'dart:math';

import 'package:axichat/src/calendar/models/calendar_task.dart';
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
  final Map<String, Set<int>> _scheduledIdsByTask = {};

  /// Reconcile reminders with the provided [tasks], scheduling new alerts and
  /// cancelling obsolete ones.
  Future<void> syncWithTasks(Iterable<CalendarTask> tasks) async {
    final tasksById = {for (final task in tasks) task.id: task};

    // Cancel reminders for removed tasks.
    final removedTaskIds =
        _scheduledIdsByTask.keys.toSet().difference(tasksById.keys.toSet());
    for (final taskId in removedTaskIds) {
      await _cancelTask(taskId);
    }

    // Schedule (or refresh) reminders for current tasks.
    for (final task in tasksById.values) {
      if (task.isCompleted) {
        await _cancelTask(task.id);
        continue;
      }
      await _scheduleRemindersFor(task);
    }
  }

  Future<void> clearAll() async {
    final allIds = _scheduledIdsByTask.values.expand((ids) => ids).toSet();
    for (final id in allIds) {
      await _notificationService.cancelNotification(id);
    }
    _scheduledIdsByTask.clear();
  }

  Future<void> _scheduleRemindersFor(CalendarTask task) async {
    await _cancelTask(task.id);

    final now = _now();
    final reminders = _reminderSchedule(task, now);
    if (reminders.isEmpty) {
      return;
    }

    final scheduledIds = <int>{};
    for (var index = 0; index < reminders.length; index++) {
      final reminder = reminders[index];
      if (!reminder.time.isAfter(now)) {
        continue;
      }
      final notificationId = _notificationId(task.id, index);
      await _notificationService.scheduleNotification(
        id: notificationId,
        scheduledAt: reminder.time,
        title: reminder.title,
        body: reminder.body,
        payload: task.id,
      );
      scheduledIds.add(notificationId);
    }

    if (scheduledIds.isEmpty) {
      _scheduledIdsByTask.remove(task.id);
    } else {
      _scheduledIdsByTask[task.id] = scheduledIds;
    }
  }

  Future<void> _cancelTask(String taskId) async {
    final ids = _scheduledIdsByTask.remove(taskId);
    if (ids == null) {
      return;
    }
    for (final id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  List<_ScheduledReminder> _reminderSchedule(
    CalendarTask task,
    DateTime now,
  ) {
    final reminders = <_ScheduledReminder>[];

    if (task.deadline != null) {
      reminders.addAll(
        _deadlineReminders(task, now, task.deadline!),
      );
    }

    if (task.scheduledTime != null) {
      reminders.addAll(
        _scheduledStartReminders(task, now, task.scheduledTime!),
      );
    }

    reminders.sort((a, b) => a.time.compareTo(b.time));
    return reminders;
  }

  Iterable<_ScheduledReminder> _deadlineReminders(
    CalendarTask task,
    DateTime now,
    DateTime deadline,
  ) sync* {
    final sanitizedDeadline = deadline.toLocal();
    final checkpoints = <Duration>[
      const Duration(hours: 24),
      const Duration(hours: 1),
      const Duration(minutes: 15),
      Duration.zero,
    ];

    for (final offset in checkpoints) {
      final time = sanitizedDeadline.subtract(offset);
      if (!time.isAfter(now)) {
        continue;
      }
      final label = offset == Duration.zero
          ? 'Deadline now'
          : '${_humanizeDuration(offset)} remaining';
      yield _ScheduledReminder(
        time: time,
        title: '${task.title} — $label',
        body: task.description,
      );
    }
  }

  Iterable<_ScheduledReminder> _scheduledStartReminders(
    CalendarTask task,
    DateTime now,
    DateTime start,
  ) sync* {
    final sanitizedStart = start.toLocal();
    final leadTimes = <Duration>[
      const Duration(minutes: 15),
      Duration.zero,
    ];

    for (final lead in leadTimes) {
      final time = sanitizedStart.subtract(lead);
      if (!time.isAfter(now)) {
        continue;
      }
      final label = lead == Duration.zero
          ? 'Starting now'
          : 'Starts in ${_humanizeDuration(lead)}';
      yield _ScheduledReminder(
        time: time,
        title: '${task.title} — $label',
        body: task.description,
      );
    }
  }

  int _notificationId(String taskId, int index) {
    final base = taskId.hashCode & 0x7fffffff;
    return base + index;
  }

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
