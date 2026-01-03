// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

abstract class CalendarException implements Exception {
  const CalendarException(this.message, [this.context]);

  final String message;
  final String? context;

  @override
  String toString() =>
      'CalendarException: $message${context != null ? ' ($context)' : ''}';
}

class CalendarStorageException extends CalendarException {
  const CalendarStorageException(super.message, [super.context]);
}

class CalendarSyncException extends CalendarException {
  const CalendarSyncException(super.message, [super.context]);
}

class CalendarValidationException extends CalendarException {
  const CalendarValidationException(String field, String reason)
      : super('Validation failed', 'field=$field reason=$reason');
}

class CalendarTaskNotFoundException extends CalendarException {
  const CalendarTaskNotFoundException(String taskId)
      : super('Task not found', 'taskId=$taskId');
}

class CalendarDayEventNotFoundException extends CalendarException {
  const CalendarDayEventNotFoundException(String eventId)
      : super('Day event not found', 'eventId=$eventId');
}

class CalendarConflictException extends CalendarException {
  const CalendarConflictException(super.message, [super.context]);
}
