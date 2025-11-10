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

class CalendarConflictException extends CalendarException {
  const CalendarConflictException(super.message, [super.context]);
}
