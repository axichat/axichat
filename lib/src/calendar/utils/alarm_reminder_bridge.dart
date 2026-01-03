// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

const List<CalendarAlarm> _emptyAlarms = <CalendarAlarm>[];

class AlarmReminderSplit {
  const AlarmReminderSplit({
    required this.reminders,
    required this.advancedAlarms,
  });

  final ReminderPreferences reminders;
  final List<CalendarAlarm> advancedAlarms;

  bool get hasAdvancedAlarms => advancedAlarms.isNotEmpty;
}

extension CalendarAlarmReminderX on CalendarAlarm {
  bool get isReminderCompatible {
    if (action != CalendarAlarmAction.display) {
      return false;
    }
    if (repeat != null ||
        duration != null ||
        description != null ||
        summary != null ||
        acknowledged != null) {
      return false;
    }
    if (attachments.isNotEmpty || recipients.isNotEmpty) {
      return false;
    }
    if (trigger.type != CalendarAlarmTriggerType.relative) {
      return false;
    }
    if (trigger.offset == null) {
      return false;
    }
    if (trigger.offsetDirection != CalendarAlarmOffsetDirection.before) {
      return false;
    }
    return true;
  }

  ReminderAnchor? get reminderAnchor {
    if (!isReminderCompatible) {
      return null;
    }
    final CalendarAlarmRelativeTo relativeTo =
        trigger.relativeTo ?? CalendarAlarmRelativeTo.start;
    return relativeTo == CalendarAlarmRelativeTo.end
        ? ReminderAnchor.deadline
        : ReminderAnchor.start;
  }

  Duration? get reminderOffset => isReminderCompatible ? trigger.offset : null;
}

AlarmReminderSplit splitAlarms(List<CalendarAlarm> alarms) {
  if (alarms.isEmpty) {
    return AlarmReminderSplit(
      reminders: ReminderPreferences.defaults(),
      advancedAlarms: _emptyAlarms,
    );
  }
  final List<Duration> startOffsets = <Duration>[];
  final List<Duration> deadlineOffsets = <Duration>[];
  final List<CalendarAlarm> advanced = <CalendarAlarm>[];
  for (final CalendarAlarm alarm in alarms) {
    final ReminderAnchor? anchor = alarm.reminderAnchor;
    final Duration? offset = alarm.reminderOffset;
    if (anchor == null || offset == null) {
      advanced.add(alarm);
      continue;
    }
    if (anchor.isDeadline) {
      deadlineOffsets.add(offset);
    } else {
      startOffsets.add(offset);
    }
  }
  final ReminderPreferences reminders = ReminderPreferences(
    enabled: startOffsets.isNotEmpty || deadlineOffsets.isNotEmpty,
    startOffsets: startOffsets,
    deadlineOffsets: deadlineOffsets,
  ).normalized();
  return AlarmReminderSplit(
    reminders: reminders,
    advancedAlarms: advanced.isEmpty
        ? _emptyAlarms
        : List<CalendarAlarm>.unmodifiable(
            advanced,
          ),
  );
}

AlarmReminderSplit splitAlarmsWithFallback({
  required List<CalendarAlarm> alarms,
  required ReminderPreferences fallback,
}) {
  if (alarms.isEmpty) {
    return AlarmReminderSplit(
      reminders: fallback.normalized(),
      advancedAlarms: _emptyAlarms,
    );
  }
  final AlarmReminderSplit split = splitAlarms(alarms);
  if (split.reminders.isEnabled) {
    return split;
  }
  return AlarmReminderSplit(
    reminders: fallback.normalized(),
    advancedAlarms: split.advancedAlarms,
  );
}

ReminderPreferences remindersFromAlarms(List<CalendarAlarm> alarms) =>
    splitAlarms(alarms).reminders;

List<CalendarAlarm> alarmsFromReminders(ReminderPreferences? reminders) {
  final ReminderPreferences resolved =
      (reminders ?? ReminderPreferences.defaults()).normalized();
  if (!resolved.isEnabled) {
    return _emptyAlarms;
  }
  final List<CalendarAlarm> alarms = <CalendarAlarm>[];
  for (final Duration offset in resolved.startOffsets) {
    alarms.add(_buildRelativeAlarm(offset, CalendarAlarmRelativeTo.start));
  }
  for (final Duration offset in resolved.deadlineOffsets) {
    alarms.add(_buildRelativeAlarm(offset, CalendarAlarmRelativeTo.end));
  }
  return List<CalendarAlarm>.unmodifiable(alarms);
}

List<CalendarAlarm> mergeAdvancedAlarms({
  required List<CalendarAlarm> advancedAlarms,
  required ReminderPreferences reminders,
}) {
  final List<CalendarAlarm> merged = <CalendarAlarm>[
    ...advancedAlarms,
  ];
  final List<CalendarAlarm> reminderAlarms = alarmsFromReminders(reminders);
  for (final CalendarAlarm alarm in reminderAlarms) {
    if (!merged.contains(alarm)) {
      merged.add(alarm);
    }
  }
  return merged;
}

List<CalendarAlarm> resolveAlarmsForExport({
  required List<CalendarAlarm> alarms,
  required ReminderPreferences? reminders,
}) {
  if (alarms.isNotEmpty) {
    return alarms;
  }
  return alarmsFromReminders(reminders);
}

CalendarAlarm _buildRelativeAlarm(
  Duration offset,
  CalendarAlarmRelativeTo anchor,
) {
  return CalendarAlarm(
    action: CalendarAlarmAction.display,
    trigger: CalendarAlarmTrigger(
      type: CalendarAlarmTriggerType.relative,
      absolute: null,
      offset: offset,
      relativeTo: anchor,
      offsetDirection: CalendarAlarmOffsetDirection.before,
    ),
    repeat: null,
    duration: null,
    description: null,
    summary: null,
    attachments: const <CalendarAttachment>[],
    acknowledged: null,
    recipients: const <CalendarAlarmRecipient>[],
  );
}
