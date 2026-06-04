// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:crypto/crypto.dart';

/// Manages scheduling and cancellation of local notifications for calendar
/// tasks based on deadlines and scheduled start times.
class CalendarReminderController {
  CalendarReminderController({
    required NotificationService notificationService,
    DateTime Function()? now,
  }) : _notificationService = notificationService,
       _now = now ?? DateTime.now;

  static const String _payloadPrefix = 'axichat-calendar-reminder-v1:';

  final NotificationService _notificationService;
  final DateTime Function() _now;
  final Map<String, Map<int, DateTime>> _scheduledTimesByEntry = {};
  bool _reminderSchedulingPermissionRequestedThisSession = false;
  AppLocalizations? _localizations;

  AppLocalizations get _l10n =>
      _localizations ?? lookupAppLocalizations(const Locale('en'));

  void updateLocalizations(AppLocalizations localizations) {
    _localizations = localizations;
  }

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

    final DateTime cleanupNow = _now();
    final Set<String> removedKeys = _scheduledTimesByEntry.keys
        .toSet()
        .difference(subjects.keys.toSet());
    for (final String key in removedKeys) {
      await _cancelEntry(key, now: cleanupNow);
    }

    await _ensureReminderSchedulingPermission(subjects.values);
    final AppLocalizations l10n = _l10n;
    final DateTime now = _now();

    for (final MapEntry<String, _ReminderSubject> entry in subjects.entries) {
      final _ReminderSubject subject = entry.value;
      if (subject.task?.isCompleted == true) {
        await _cancelEntry(entry.key, now: now);
        continue;
      }
      final List<_ScheduledReminder> reminders = _reminderScheduleForSubject(
        subject,
        now,
        l10n,
      );
      await _scheduleRemindersFor(
        entry.key,
        subject,
        reminders: reminders,
        now: now,
      );
    }
  }

  Future<void> clearAll() async {
    final DateTime now = _now();
    for (final String key in _scheduledTimesByEntry.keys.toList()) {
      await _cancelEntry(key, now: now);
    }
  }

  Future<void> _scheduleRemindersFor(
    String entryKey,
    _ReminderSubject subject, {
    required List<_ScheduledReminder> reminders,
    required DateTime now,
  }) async {
    final Map<int, DateTime> tracked =
        _scheduledTimesByEntry[entryKey] ?? const <int, DateTime>{};
    final Map<int, _ScheduledReminder> desired =
        _desiredRemindersByNotificationId(subject, reminders, now: now);

    for (final MapEntry<int, _ScheduledReminder> entry in desired.entries) {
      final int notificationId = entry.key;
      final _ScheduledReminder reminder = entry.value;
      await _notificationService.scheduleNotification(
        id: notificationId,
        scheduledAt: reminder.time,
        title: reminder.title,
        body: reminder.body,
        payload: subject.payloadId,
      );
    }

    for (final MapEntry<int, DateTime> entry in tracked.entries) {
      if (desired.containsKey(entry.key)) {
        continue;
      }
      if (entry.value.isAfter(now)) {
        await _notificationService.cancelNotification(entry.key);
      }
    }

    if (desired.isEmpty) {
      _scheduledTimesByEntry.remove(entryKey);
    } else {
      _scheduledTimesByEntry[entryKey] = <int, DateTime>{
        for (final MapEntry<int, _ScheduledReminder> entry in desired.entries)
          entry.key: entry.value.time,
      };
    }
  }

  Future<void> _ensureReminderSchedulingPermission(
    Iterable<_ReminderSubject> subjects,
  ) async {
    final AppLocalizations l10n = _l10n;
    final DateTime now = _now();
    final bool hasFutureReminders = subjects.any((_ReminderSubject subject) {
      if (subject.task?.isCompleted == true) {
        return false;
      }
      return _reminderScheduleForSubject(subject, now, l10n).isNotEmpty;
    });
    if (!hasFutureReminders) {
      return;
    }

    if (await _notificationService.hasReminderSchedulingPermission()) {
      _reminderSchedulingPermissionRequestedThisSession = false;
      return;
    }
    if (_reminderSchedulingPermissionRequestedThisSession) {
      return;
    }

    _reminderSchedulingPermissionRequestedThisSession = true;
    final ReminderSchedulingPermissionRequestResult result =
        await _notificationService.requestReminderSchedulingPermission();
    _reminderSchedulingPermissionRequestedThisSession = switch (result) {
      ReminderSchedulingPermissionRequestResult.granted => false,
      ReminderSchedulingPermissionRequestResult.denied => true,
      ReminderSchedulingPermissionRequestResult.unavailable => true,
      ReminderSchedulingPermissionRequestResult.failed => false,
    };
  }

  Future<void> _cancelEntry(String entryKey, {required DateTime now}) async {
    final Map<int, DateTime>? entries = _scheduledTimesByEntry.remove(entryKey);
    if (entries == null) {
      return;
    }
    for (final MapEntry<int, DateTime> entry in entries.entries) {
      if (entry.value.isAfter(now)) {
        await _notificationService.cancelNotification(entry.key);
      }
    }
  }

  List<_ScheduledReminder> _reminderScheduleForTask(
    CalendarTask task,
    DateTime now,
    AppLocalizations l10n,
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
            ? l10n.calendarReminderDeadlineNow
            : l10n.calendarReminderDueIn(_humanizeDuration(l10n, offset));
        reminders.add(
          _ScheduledReminder(
            time: time,
            anchor: ReminderAnchor.deadline,
            anchorTime: deadline,
            offset: offset,
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
            ? l10n.calendarReminderStartingNow
            : l10n.calendarReminderStartsIn(_humanizeDuration(l10n, lead));
        reminders.add(
          _ScheduledReminder(
            time: time,
            anchor: ReminderAnchor.start,
            anchorTime: start,
            offset: lead,
            title: '${task.title} — $label',
            body: task.description,
          ),
        );
      }
    }

    reminders.sort((a, b) => a.time.compareTo(b.time));
    return reminders;
  }

  List<_ScheduledReminder> _reminderScheduleForSubject(
    _ReminderSubject subject,
    DateTime now,
    AppLocalizations l10n,
  ) {
    return subject.when(
      task: (CalendarTask task) => _reminderScheduleForTask(task, now, l10n),
      dayEvent: (DayEvent event) =>
          _reminderScheduleForDayEvent(event, now, l10n),
    );
  }

  List<_ScheduledReminder> _reminderScheduleForDayEvent(
    DayEvent event,
    DateTime now,
    AppLocalizations l10n,
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
          ? l10n.calendarReminderHappeningToday
          : l10n.calendarReminderIn(_humanizeDuration(l10n, lead));
      reminders.add(
        _ScheduledReminder(
          time: time,
          anchor: ReminderAnchor.start,
          anchorTime: start,
          offset: lead,
          title: '${event.title} — $label',
          body: event.description,
        ),
      );
    }
    reminders.sort((a, b) => a.time.compareTo(b.time));
    return reminders;
  }

  Map<int, _ScheduledReminder> _desiredRemindersByNotificationId(
    _ReminderSubject subject,
    List<_ScheduledReminder> reminders, {
    required DateTime now,
  }) {
    final Map<int, _ScheduledReminder> desired = <int, _ScheduledReminder>{};
    for (final _ScheduledReminder reminder in reminders) {
      if (!reminder.time.isAfter(now)) {
        continue;
      }
      desired[_notificationId(subject, reminder)] = reminder;
    }
    return desired;
  }

  int _notificationId(_ReminderSubject subject, _ScheduledReminder reminder) {
    final String input = <String>[
      'calendar-reminder-v1',
      subject.kind,
      subject.id,
      reminder.anchor.name,
      reminder.anchorTime.toUtc().microsecondsSinceEpoch.toString(),
      reminder.offset.inMicroseconds.toString(),
      reminder.time.toUtc().microsecondsSinceEpoch.toString(),
    ].join('|');
    final Digest digest = sha256.convert(utf8.encode(input));
    return ((digest.bytes[0] << 24) |
            (digest.bytes[1] << 16) |
            (digest.bytes[2] << 8) |
            digest.bytes[3]) &
        0x7fffffff;
  }

  String _taskKey(String id) => 'task:$id';

  String _dayEventKey(String id) => 'day:$id';

  String _humanizeDuration(AppLocalizations l10n, Duration duration) {
    if (duration.inHours >= 24) {
      final days = duration.inDays;
      return l10n.calendarReminderDurationDays(days);
    }
    if (duration.inHours >= 1) {
      final hours = duration.inHours;
      return l10n.calendarReminderDurationHours(hours);
    }
    final minutes = max(duration.inMinutes, 1);
    return l10n.calendarReminderDurationMinutes(minutes);
  }
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.time,
    required this.anchor,
    required this.anchorTime,
    required this.offset,
    required this.title,
    this.body,
  });

  final DateTime time;
  final ReminderAnchor anchor;
  final DateTime anchorTime;
  final Duration offset;
  final String title;
  final String? body;
}

class _ReminderSubject {
  _ReminderSubject.task(CalendarTask value)
    : task = value,
      dayEvent = null,
      id = value.id,
      kind = 'task',
      payloadId =
          '${CalendarReminderController._payloadPrefix}task:${value.id}';

  _ReminderSubject.dayEvent(DayEvent value)
    : task = null,
      dayEvent = value,
      id = value.id,
      kind = 'day',
      payloadId = '${CalendarReminderController._payloadPrefix}day:${value.id}';

  final CalendarTask? task;
  final DayEvent? dayEvent;
  final String id;
  final String kind;
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
