// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

sealed class CalendarException implements Exception {
  const CalendarException();

  String get message;

  String? get context => null;

  @override
  String toString() =>
      'CalendarException: $message${context != null ? ' ($context)' : ''}';
}

final class CalendarStorageException extends CalendarException {
  const CalendarStorageException(this.message, [this.context]);

  @override
  final String message;

  @override
  final String? context;
}

final class CalendarSyncException extends CalendarException {
  const CalendarSyncException(this.message, [this.context]);

  @override
  final String message;

  @override
  final String? context;
}

final class CalendarValidationException extends CalendarException {
  const CalendarValidationException(String field, String reason)
    : _field = field,
      _reason = reason;

  final String _field;
  final String _reason;

  @override
  String get message => 'Validation failed';

  @override
  String get context => 'field=$_field reason=$_reason';
}

final class CalendarTaskNotFoundException extends CalendarException {
  const CalendarTaskNotFoundException(String taskId) : _taskId = taskId;

  final String _taskId;

  @override
  String get message => 'Task not found';

  @override
  String get context => 'taskId=$_taskId';
}

final class CalendarDayEventNotFoundException extends CalendarException {
  const CalendarDayEventNotFoundException(String eventId) : _eventId = eventId;

  final String _eventId;

  @override
  String get message => 'Day event not found';

  @override
  String get context => 'eventId=$_eventId';
}

final class CalendarConflictException extends CalendarException {
  const CalendarConflictException(this.message, [this.context]);

  @override
  final String message;

  @override
  final String? context;
}
