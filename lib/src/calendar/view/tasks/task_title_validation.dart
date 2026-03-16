// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:characters/characters.dart';

import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/localization/app_localizations.dart';

/// Shared helpers for validating calendar task titles so inline inputs,
/// quick-add surfaces, and full editors stay consistent.
class TaskTitleValidation {
  const TaskTitleValidation._();

  static String? validate(String raw, AppLocalizations l10n) {
    if (raw.trim().isEmpty) {
      return l10n.calendarTaskTitleRequired;
    }
    if (isTooLong(raw)) {
      return l10n.calendarTaskTitleTooLong(calendarTaskTitleMaxLength);
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
