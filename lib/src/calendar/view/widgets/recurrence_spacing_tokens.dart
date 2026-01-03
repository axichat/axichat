// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';

import 'recurrence_editor.dart';

const RecurrenceEditorSpacing calendarRecurrenceSpacingStandard =
    RecurrenceEditorSpacing(
  chipSpacing: calendarGutterSm,
  chipRunSpacing: calendarGutterSm,
  weekdaySpacing: calendarGutterMd,
  advancedSectionSpacing: calendarGutterMd,
  endSpacing: calendarRecurrenceEndGap,
  fieldGap: calendarRecurrenceFieldGap,
);

const RecurrenceEditorSpacing calendarRecurrenceSpacingCompact =
    RecurrenceEditorSpacing(
  chipSpacing: calendarInsetLg,
  chipRunSpacing: calendarInsetLg,
  weekdaySpacing: calendarRecurrenceCompactWeekdayGap,
  advancedSectionSpacing: calendarGutterMd,
  endSpacing: calendarRecurrenceEndGap,
  fieldGap: calendarRecurrenceCompactFieldGap,
);
