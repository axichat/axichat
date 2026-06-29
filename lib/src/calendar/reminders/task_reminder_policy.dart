// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

const int maxRecurringTaskReminderNotifications = 48;
const Duration recurringTaskReminderLookahead = Duration(days: 90);

bool taskCanHaveReminders({
  required DateTime? scheduledTime,
  required DateTime? deadline,
}) {
  return scheduledTime != null || deadline != null;
}

bool taskShowsBothReminderAnchors({
  required DateTime? scheduledTime,
  required DateTime? deadline,
}) {
  return scheduledTime != null && deadline != null;
}

ReminderAnchor taskReminderAnchor({
  required DateTime? scheduledTime,
  required DateTime? deadline,
}) {
  if (deadline != null && scheduledTime == null) {
    return ReminderAnchor.deadline;
  }
  return ReminderAnchor.start;
}

ReminderPreferences taskReminderPreferencesForAnchors(
  ReminderPreferences reminders, {
  required DateTime? scheduledTime,
  required DateTime? deadline,
}) {
  if (!taskCanHaveReminders(scheduledTime: scheduledTime, deadline: deadline)) {
    return ReminderPreferences.defaults();
  }

  if (taskShowsBothReminderAnchors(
    scheduledTime: scheduledTime,
    deadline: deadline,
  )) {
    return reminders.normalized();
  }

  return reminders.normalized().alignedTo(
    taskReminderAnchor(scheduledTime: scheduledTime, deadline: deadline),
  );
}

ReminderPreferences taskReminderPreferencesForSelectionAnchors(
  ReminderPreferences reminders, {
  required DateTime? scheduledTime,
  required DateTime? deadline,
}) {
  if (!taskCanHaveReminders(scheduledTime: scheduledTime, deadline: deadline)) {
    return ReminderPreferences.defaults();
  }

  final ReminderPreferences normalized = reminders.normalized();
  if (taskShowsBothReminderAnchors(
    scheduledTime: scheduledTime,
    deadline: deadline,
  )) {
    return normalized;
  }

  final List<Duration> offsets = _selectionOffsetsForSingleAnchor(normalized);
  if (scheduledTime != null) {
    return ReminderPreferences(
      enabled: normalized.enabled,
      startOffsets: offsets,
    ).normalized();
  }
  return ReminderPreferences(
    enabled: normalized.enabled,
    deadlineOffsets: offsets,
  ).normalized();
}

List<Duration> _selectionOffsetsForSingleAnchor(ReminderPreferences reminders) {
  final Set<int> seen = <int>{};
  final List<Duration> offsets = <Duration>[];
  for (final Duration offset in <Duration>[
    ...reminders.startOffsets,
    ...reminders.deadlineOffsets,
  ]) {
    final int micros = offset.inMicroseconds;
    if (seen.add(micros)) {
      offsets.add(offset);
    }
  }
  offsets.sort((Duration a, Duration b) => a.compareTo(b));
  return offsets;
}

int maxRecurringTaskReminderInstances(ReminderPreferences reminders) {
  if (!reminders.isEnabled) {
    return 0;
  }
  final int reminderCount =
      reminders.startOffsets.length + reminders.deadlineOffsets.length;
  if (reminderCount <= 0) {
    return 0;
  }

  final int maxInstances =
      maxRecurringTaskReminderNotifications ~/ reminderCount;
  return maxInstances < 1 ? 1 : maxInstances;
}

Duration maxTaskReminderOffset(ReminderPreferences reminders) {
  Duration maxOffset = Duration.zero;
  for (final Duration offset in <Duration>[
    ...reminders.startOffsets,
    ...reminders.deadlineOffsets,
  ]) {
    if (offset > maxOffset) {
      maxOffset = offset;
    }
  }
  return maxOffset;
}

Duration recurringTaskReminderLookback(
  ReminderPreferences reminders, {
  required DateTime? scheduledTime,
  required DateTime? deadline,
}) {
  Duration lookback = maxTaskReminderOffset(reminders);
  if (scheduledTime == null ||
      deadline == null ||
      reminders.deadlineOffsets.isEmpty) {
    return lookback;
  }

  final Duration deadlineSpan = deadline.difference(scheduledTime);
  if (deadlineSpan > lookback) {
    lookback = deadlineSpan;
  }
  return lookback;
}

Iterable<CalendarTask> taskReminderInstancesForSync({
  required CalendarTask task,
  required DateTime now,
  required bool Function(CalendarTask task) hasFutureReminder,
}) sync* {
  if (!task.hasRecurrenceData) {
    yield task;
    return;
  }
  if (task.scheduledTime == null) {
    if (hasFutureReminder(task)) {
      yield task;
    }
    return;
  }

  final ReminderPreferences reminders = task.effectiveReminders;
  final int maxInstances = maxRecurringTaskReminderInstances(reminders);
  if (maxInstances <= 0) {
    return;
  }

  var yieldedFutureInstances = 0;
  final Set<String> yieldedIds = <String>{};
  final CalendarTask? baseInstance = task.baseOccurrenceInstance();
  if (baseInstance != null && hasFutureReminder(baseInstance)) {
    yieldedIds.add(baseInstance.id);
    yield baseInstance;
    yieldedFutureInstances += 1;
    if (yieldedFutureInstances >= maxInstances) {
      return;
    }
  }

  final Duration lookback = recurringTaskReminderLookback(
    reminders,
    scheduledTime: task.scheduledTime,
    deadline: task.deadline,
  );
  final Duration maxOffset = maxTaskReminderOffset(reminders);
  final DateTime rangeStart = now.subtract(lookback);
  final DateTime rangeEnd = now.add(recurringTaskReminderLookahead + maxOffset);
  for (final CalendarTask occurrence in task.occurrencesWithin(
    rangeStart,
    rangeEnd,
  )) {
    if (!yieldedIds.add(occurrence.id)) {
      continue;
    }
    if (!hasFutureReminder(occurrence)) {
      continue;
    }
    yield occurrence;
    yieldedFutureInstances += 1;
    if (yieldedFutureInstances >= maxInstances) {
      return;
    }
  }
}
