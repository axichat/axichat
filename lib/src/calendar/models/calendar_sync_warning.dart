import 'package:flutter/foundation.dart';

@immutable
class CalendarSyncWarning {
  const CalendarSyncWarning({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}
