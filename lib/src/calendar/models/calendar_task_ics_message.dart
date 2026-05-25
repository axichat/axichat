// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_task.dart';

const String _calendarTaskIcsMessageTaskKey = 'task';
const String _calendarTaskIcsMessageReadOnlyKey = 'readOnly';

class CalendarTaskIcsMessage {
  const CalendarTaskIcsMessage({
    required this.task,
    bool readOnly = defaultReadOnly,
  }) : readOnly = defaultReadOnly;

  static const bool defaultReadOnly = true;

  final CalendarTask task;
  final bool readOnly;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{_calendarTaskIcsMessageTaskKey: task.toJson()};
  }

  static CalendarTaskIcsMessage? tryParse(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final taskPayload = raw[_calendarTaskIcsMessageTaskKey];
    if (taskPayload is Map<String, dynamic>) {
      final CalendarTask? task = _parseTaskMap(taskPayload);
      if (task == null) {
        return null;
      }
      return CalendarTaskIcsMessage(
        task: task,
        readOnly: _parseReadOnly(raw[_calendarTaskIcsMessageReadOnlyKey]),
      );
    }
    final CalendarTask? legacyTask = _parseTaskMap(raw);
    if (legacyTask == null) {
      return null;
    }
    return CalendarTaskIcsMessage(task: legacyTask, readOnly: defaultReadOnly);
  }

  static CalendarTask? _parseTaskMap(Map<String, dynamic> raw) {
    try {
      return CalendarTask.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static bool _parseReadOnly(Object? _) {
    // Editable task shares are no longer supported; legacy false values are
    // treated as read-only compatibility data.
    return defaultReadOnly;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarTaskIcsMessage &&
          other.task == task &&
          other.readOnly == readOnly;

  @override
  int get hashCode => Object.hash(task, readOnly);
}
