// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/reminders/task_reminder_policy.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:crypto/crypto.dart';

enum ReminderPermissionRequestMode {
  none,
  synced,
  userInitiated;

  bool get shouldRequest => this == ReminderPermissionRequestMode.userInitiated;
}

class CalendarReminderSyncResult {
  const CalendarReminderSyncResult({
    this.notificationPermissionRequestResult,
    this.notificationPermissionMissing = false,
    this.reminderSchedulingPermissionMissing = false,
  });

  final NotificationPermissionRequestResult?
  notificationPermissionRequestResult;
  final bool notificationPermissionMissing;
  final bool reminderSchedulingPermissionMissing;

  bool get notificationPermissionRequestDenied =>
      notificationPermissionRequestResult != null &&
      !notificationPermissionRequestResult!.isGranted;

  bool get notificationDisplayPermissionNeeded =>
      notificationPermissionMissing || notificationPermissionRequestDenied;

  bool get notificationPermissionNeeded =>
      notificationPermissionMissing ||
      notificationPermissionRequestDenied ||
      reminderSchedulingPermissionMissing;
}

typedef _NotificationPermissionCheck = ({
  bool granted,
  NotificationPermissionRequestResult? requestResult,
});

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
  final Map<
    int,
    ({
      String entryKey,
      DateTime scheduledAt,
      String title,
      String? body,
      String payload,
      NotificationUrgency urgency,
    })
  >
  _displayPermissionBlockedSchedules = {};
  final Map<
    int,
    ({
      String entryKey,
      DateTime scheduledAt,
      String title,
      String? body,
      String payload,
      NotificationUrgency urgency,
    })
  >
  _exactAlarmPermissionBlockedSchedules = {};
  NotificationPermissionRequestResult? _pendingReminderPermissionRequestResult;
  AppLocalizations? _localizations;

  AppLocalizations get _l10n =>
      _localizations ?? lookupAppLocalizations(const Locale('en'));

  void updateLocalizations(AppLocalizations localizations) {
    _localizations = localizations;
  }

  Future<bool> requestReminderPermissions() async {
    final NotificationPermissionRequestResult result =
        await _notificationService.requestNotificationDisplayPermission(
          openSettingsIfRequired: true,
        );
    _pendingReminderPermissionRequestResult = null;
    if (!await _notificationService.hasPermissionResolvedFor(result)) {
      if (result ==
          NotificationPermissionRequestResult.awaitingNotificationSettings) {
        _pendingReminderPermissionRequestResult = result;
      }
      return false;
    }
    final bool reminderSchedulingPermissionGranted =
        await _requestReminderSchedulingPermissionWithSettings();
    await retryPendingPermissionBlockedReminders();
    return reminderSchedulingPermissionGranted;
  }

  Future<bool> requestSyncedReminderPermissions() {
    return requestReminderPermissions();
  }

  Future<void> retryPendingPermissionBlockedReminders() async {
    if (_pendingReminderPermissionRequestResult != null) {
      if (!await _notificationService.hasPermissionResolvedFor(
        _pendingReminderPermissionRequestResult!,
      )) {
        return;
      }
      _pendingReminderPermissionRequestResult = null;
      await _requestReminderSchedulingPermissionWithSettings();
    }
    if (_displayPermissionBlockedSchedules.isEmpty &&
        _exactAlarmPermissionBlockedSchedules.isEmpty) {
      return;
    }
    if (!await _hasNotificationDisplayPermission()) {
      return;
    }
    if (_displayPermissionBlockedSchedules.isNotEmpty) {
      await _retryDisplayPermissionBlockedSchedules();
    }
    if (_exactAlarmPermissionBlockedSchedules.isNotEmpty &&
        await _hasReminderSchedulingPermission()) {
      await _retryExactAlarmPermissionBlockedSchedules();
    }
  }

  Future<bool> _requestReminderSchedulingPermissionWithSettings() async {
    bool reminderSchedulingPermissionGranted =
        await _hasReminderSchedulingPermission();
    if (reminderSchedulingPermissionGranted) {
      return true;
    }

    final ReminderSchedulingPermissionRequestResult schedulingResult =
        await _notificationService.requestReminderSchedulingPermission(
          openSettingsFallback: true,
        );
    reminderSchedulingPermissionGranted =
        schedulingResult == ReminderSchedulingPermissionRequestResult.granted ||
        await _hasReminderSchedulingPermission();
    return reminderSchedulingPermissionGranted;
  }

  Future<void> _retryDisplayPermissionBlockedSchedules() async {
    final bool exactAlarmPermissionGranted =
        await _hasReminderSchedulingPermission();
    final DateTime now = _now();
    for (final MapEntry<
          int,
          ({
            String entryKey,
            DateTime scheduledAt,
            String title,
            String? body,
            String payload,
            NotificationUrgency urgency,
          })
        >
        entry
        in _displayPermissionBlockedSchedules.entries.toList()) {
      if (!entry.value.scheduledAt.isAfter(now)) {
        _displayPermissionBlockedSchedules.remove(entry.key);
        _exactAlarmPermissionBlockedSchedules.remove(entry.key);
        continue;
      }
      await _notificationService.cancelNotification(entry.key);
      await _notificationService.scheduleNotification(
        id: entry.key,
        scheduledAt: entry.value.scheduledAt,
        title: entry.value.title,
        body: entry.value.body,
        payload: entry.value.payload,
        urgency: entry.value.urgency,
      );
      _displayPermissionBlockedSchedules.remove(entry.key);
      if (exactAlarmPermissionGranted) {
        _exactAlarmPermissionBlockedSchedules.remove(entry.key);
      } else {
        _exactAlarmPermissionBlockedSchedules[entry.key] = entry.value;
      }
    }
  }

  Future<void> _retryExactAlarmPermissionBlockedSchedules() async {
    final DateTime now = _now();
    for (final MapEntry<
          int,
          ({
            String entryKey,
            DateTime scheduledAt,
            String title,
            String? body,
            String payload,
            NotificationUrgency urgency,
          })
        >
        entry
        in _exactAlarmPermissionBlockedSchedules.entries.toList()) {
      if (!entry.value.scheduledAt.isAfter(now)) {
        _exactAlarmPermissionBlockedSchedules.remove(entry.key);
        continue;
      }
      await _notificationService.cancelNotification(entry.key);
      await _notificationService.scheduleNotification(
        id: entry.key,
        scheduledAt: entry.value.scheduledAt,
        title: entry.value.title,
        body: entry.value.body,
        payload: entry.value.payload,
        urgency: entry.value.urgency,
      );
      _exactAlarmPermissionBlockedSchedules.remove(entry.key);
    }
  }

  /// Reconcile reminders with the provided [tasks] and [dayEvents], scheduling
  /// new alerts and cancelling obsolete ones.
  Future<CalendarReminderSyncResult> syncWithTasks(
    Iterable<CalendarTask> tasks, {
    Iterable<DayEvent> dayEvents = const [],
    ReminderPermissionRequestMode permissionRequestMode =
        ReminderPermissionRequestMode.none,
  }) async {
    await _notificationService.init();
    await _notificationService.refreshTimeZone();

    final DateTime subjectNow = _now();
    final AppLocalizations subjectL10n = _l10n;
    final Map<String, _ReminderSubject> subjects = <String, _ReminderSubject>{
      for (final CalendarTask task in tasks)
        for (final _ReminderSubject subject in _taskReminderSubjectsForSync(
          task,
          now: subjectNow,
          l10n: subjectL10n,
        ))
          _taskKey(subject.id): subject,
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

    final bool hasFutureReminders = _hasFutureReminders(subjects.values);
    final bool shouldRequestPermissions = permissionRequestMode.shouldRequest;
    final _NotificationPermissionCheck notificationPermission =
        hasFutureReminders
        ? shouldRequestPermissions
              ? await _ensureNotificationPermission()
              : (
                  granted: await _hasNotificationDisplayPermission(),
                  requestResult: null,
                )
        : (granted: true, requestResult: null);
    final bool canScheduleReminders =
        hasFutureReminders && notificationPermission.granted;
    bool reminderSchedulingPermissionGranted = true;
    if (canScheduleReminders) {
      reminderSchedulingPermissionGranted =
          await _hasReminderSchedulingPermission();
    }
    final bool reminderSchedulingPermissionMissing =
        canScheduleReminders &&
        permissionRequestMode == ReminderPermissionRequestMode.synced &&
        !reminderSchedulingPermissionGranted;
    if (canScheduleReminders &&
        shouldRequestPermissions &&
        !reminderSchedulingPermissionGranted) {
      await _ensureReminderSchedulingPermission();
      reminderSchedulingPermissionGranted =
          await _hasReminderSchedulingPermission();
    }
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
        canSchedule: canScheduleReminders,
        schedulePermissionBlocked:
            hasFutureReminders && !notificationPermission.granted,
        exactAlarmPermissionBlocked:
            canScheduleReminders && !reminderSchedulingPermissionGranted,
      );
    }
    return CalendarReminderSyncResult(
      notificationPermissionRequestResult: notificationPermission.requestResult,
      notificationPermissionMissing:
          hasFutureReminders && !notificationPermission.granted,
      reminderSchedulingPermissionMissing: reminderSchedulingPermissionMissing,
    );
  }

  Future<void> clearAll() async {
    final DateTime now = _now();
    for (final String key in _scheduledTimesByEntry.keys.toList()) {
      await _cancelEntry(key, now: now);
    }
  }

  Iterable<_ReminderSubject> _taskReminderSubjectsForSync(
    CalendarTask task, {
    required DateTime now,
    required AppLocalizations l10n,
  }) sync* {
    for (final CalendarTask instance in taskReminderInstancesForSync(
      task: task,
      now: now,
      hasFutureReminder: (CalendarTask instance) =>
          !instance.isCompleted &&
          _reminderScheduleForTask(instance, now, l10n).isNotEmpty,
    )) {
      yield _ReminderSubject.task(
        instance,
        id: _taskReminderSubjectId(task: task, instance: instance),
      );
    }
  }

  String _taskReminderSubjectId({
    required CalendarTask task,
    required CalendarTask instance,
  }) {
    if (_isBaseRecurringReminderInstance(task: task, instance: instance)) {
      return task.id;
    }
    return instance.id;
  }

  bool _isBaseRecurringReminderInstance({
    required CalendarTask task,
    required CalendarTask instance,
  }) {
    if (!task.hasRecurrenceData || !instance.isOccurrence) {
      return false;
    }
    return instance.baseId == task.id &&
        instance.occurrenceKey == task.baseOccurrenceKey;
  }

  Future<void> _scheduleRemindersFor(
    String entryKey,
    _ReminderSubject subject, {
    required List<_ScheduledReminder> reminders,
    required DateTime now,
    required bool canSchedule,
    required bool schedulePermissionBlocked,
    required bool exactAlarmPermissionBlocked,
  }) async {
    final Map<int, DateTime> tracked =
        _scheduledTimesByEntry[entryKey] ?? const <int, DateTime>{};
    final Map<int, _ScheduledReminder> desired =
        _desiredRemindersByNotificationId(subject, reminders, now: now);
    _removeStalePendingSchedulesForEntry(entryKey, desired.keys.toSet());

    if (canSchedule) {
      for (final MapEntry<int, _ScheduledReminder> entry in desired.entries) {
        final int notificationId = entry.key;
        final _ScheduledReminder reminder = entry.value;
        await _notificationService.scheduleNotification(
          id: notificationId,
          scheduledAt: reminder.time,
          title: reminder.title,
          body: reminder.body,
          payload: subject.payloadId,
          urgency: NotificationUrgency.timeSensitive,
        );
        _displayPermissionBlockedSchedules.remove(notificationId);
        if (exactAlarmPermissionBlocked) {
          _exactAlarmPermissionBlockedSchedules[notificationId] =
              _pendingSchedule(
                entryKey: entryKey,
                reminder: reminder,
                payload: subject.payloadId,
              );
        } else {
          _exactAlarmPermissionBlockedSchedules.remove(notificationId);
        }
      }
    } else if (schedulePermissionBlocked) {
      for (final MapEntry<int, _ScheduledReminder> entry in desired.entries) {
        _displayPermissionBlockedSchedules[entry.key] = _pendingSchedule(
          entryKey: entryKey,
          reminder: entry.value,
          payload: subject.payloadId,
        );
        _exactAlarmPermissionBlockedSchedules.remove(entry.key);
      }
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

  bool _hasFutureReminders(Iterable<_ReminderSubject> subjects) {
    final AppLocalizations l10n = _l10n;
    final DateTime now = _now();
    return subjects.any((_ReminderSubject subject) {
      if (subject.task?.isCompleted == true) {
        return false;
      }
      return _reminderScheduleForSubject(subject, now, l10n).isNotEmpty;
    });
  }

  Future<_NotificationPermissionCheck> _ensureNotificationPermission() async {
    if (await _hasNotificationDisplayPermission()) {
      return (
        granted: true,
        requestResult: NotificationPermissionRequestResult.granted,
      );
    }

    final NotificationPermissionRequestResult result =
        await _notificationService.requestNotificationDisplayPermission();
    if (result == NotificationPermissionRequestResult.granted) {
      return (granted: true, requestResult: result);
    }
    return (granted: false, requestResult: result);
  }

  Future<void> _ensureReminderSchedulingPermission() async {
    if (await _hasReminderSchedulingPermission()) {
      return;
    }

    await _notificationService.requestReminderSchedulingPermission();
  }

  Future<bool> _hasNotificationDisplayPermission() async {
    return _notificationService.hasNotificationDisplayPermission();
  }

  Future<bool> _hasReminderSchedulingPermission() async {
    return _notificationService.hasReminderSchedulingPermission();
  }

  Future<void> _cancelEntry(String entryKey, {required DateTime now}) async {
    final Map<int, DateTime>? entries = _scheduledTimesByEntry.remove(entryKey);
    _removePendingSchedulesForEntry(entryKey);
    if (entries == null) {
      return;
    }
    for (final MapEntry<int, DateTime> entry in entries.entries) {
      if (entry.value.isAfter(now)) {
        await _notificationService.cancelNotification(entry.key);
      }
    }
  }

  void _removeStalePendingSchedulesForEntry(
    String entryKey,
    Set<int> desiredIds,
  ) {
    _displayPermissionBlockedSchedules.removeWhere(
      (id, schedule) =>
          schedule.entryKey == entryKey && !desiredIds.contains(id),
    );
    _exactAlarmPermissionBlockedSchedules.removeWhere(
      (id, schedule) =>
          schedule.entryKey == entryKey && !desiredIds.contains(id),
    );
  }

  void _removePendingSchedulesForEntry(String entryKey) {
    _displayPermissionBlockedSchedules.removeWhere(
      (_, schedule) => schedule.entryKey == entryKey,
    );
    _exactAlarmPermissionBlockedSchedules.removeWhere(
      (_, schedule) => schedule.entryKey == entryKey,
    );
  }

  ({
    String entryKey,
    DateTime scheduledAt,
    String title,
    String? body,
    String payload,
    NotificationUrgency urgency,
  })
  _pendingSchedule({
    required String entryKey,
    required _ScheduledReminder reminder,
    required String payload,
  }) {
    return (
      entryKey: entryKey,
      scheduledAt: reminder.time,
      title: reminder.title,
      body: reminder.body,
      payload: payload,
      urgency: NotificationUrgency.timeSensitive,
    );
  }

  List<_ScheduledReminder> _reminderScheduleForTask(
    CalendarTask task,
    DateTime now,
    AppLocalizations l10n,
  ) {
    final ReminderPreferences prefs =
        taskReminderPreferencesForSelectionAnchors(
          task.effectiveReminders,
          scheduledTime: task.scheduledTime,
          deadline: task.deadline,
        );
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
    final int totalMinutes = max((duration.inSeconds / 60).ceil(), 1);
    final int days = totalMinutes ~/ Duration.minutesPerDay;
    final int hours =
        (totalMinutes % Duration.minutesPerDay) ~/ Duration.minutesPerHour;
    final int minutes = totalMinutes % Duration.minutesPerHour;
    final List<String> parts = <String>[];

    if (days > 0) {
      parts.add(
        _localizedDurationUnit(l10n.calendarReminderDurationDays, days),
      );
    }
    if (hours > 0) {
      parts.add(
        _localizedDurationUnit(l10n.calendarReminderDurationHours, hours),
      );
    }
    if (minutes > 0 || parts.isEmpty) {
      parts.add(
        _localizedDurationUnit(l10n.calendarReminderDurationMinutes, minutes),
      );
    }
    return parts.join(' ');
  }

  String _localizedDurationUnit(String Function(num count) label, int count) {
    return label(count).replaceAll('#', count.toString());
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
  _ReminderSubject.task(CalendarTask value, {String? id})
    : task = value,
      dayEvent = null,
      id = id ?? value.id,
      kind = 'task',
      payloadId =
          '${CalendarReminderController._payloadPrefix}task:${id ?? value.id}';

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
