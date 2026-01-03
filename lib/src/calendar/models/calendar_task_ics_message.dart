// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_task.dart';

const String _calendarTaskIcsMessageTaskKey = 'task';
const String _calendarTaskIcsMessageReadOnlyKey = 'readOnly';
const String _calendarTaskIcsMessageTrueValue = 'true';
const String _calendarTaskIcsMessageFalseValue = 'false';

class CalendarTaskIcsMessage {
  const CalendarTaskIcsMessage({
    required this.task,
    this.readOnly = defaultReadOnly,
  });

  static const bool defaultReadOnly = true;

  final CalendarTask task;
  final bool readOnly;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{
      _calendarTaskIcsMessageTaskKey: task.toJson(),
    };
    if (readOnly != defaultReadOnly) {
      data[_calendarTaskIcsMessageReadOnlyKey] = readOnly;
    }
    return data;
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
      final bool readOnly = _parseReadOnly(
        raw[_calendarTaskIcsMessageReadOnlyKey],
      );
      return CalendarTaskIcsMessage(task: task, readOnly: readOnly);
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

  static bool _parseReadOnly(Object? raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == _calendarTaskIcsMessageTrueValue) {
        return true;
      }
      if (normalized == _calendarTaskIcsMessageFalseValue) {
        return false;
      }
    }
    return defaultReadOnly;
  }
}
