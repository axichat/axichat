import 'package:characters/characters.dart';

import '../constants.dart';

/// Shared helpers for validating calendar task titles so inline inputs,
/// quick-add surfaces, and full editors stay consistent.
class TaskTitleValidation {
  const TaskTitleValidation._();

  static const String requiredMessage = 'Enter a task title before continuing.';

  static String? validate(String raw) {
    if (raw.trim().isEmpty) {
      return requiredMessage;
    }
    if (isTooLong(raw)) {
      return calendarTaskTitleFriendlyError;
    }
    return null;
  }

  static bool isTooLong(String raw) {
    return characterCount(raw) > calendarTaskTitleMaxLength;
  }

  static int characterCount(String raw) {
    return raw.characters.length;
  }
}
