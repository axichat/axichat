// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';

import 'recurrence_editor.dart';

RecurrenceEditorSpacing calendarRecurrenceSpacingStandard(
  BuildContext context,
) => RecurrenceEditorSpacing(
  chipSpacing: context.spacing.s,
  chipRunSpacing: context.spacing.s,
  weekdaySpacing: context.spacing.m,
  advancedSectionSpacing: context.spacing.m,
  endSpacing: context.spacing.m,
  fieldGap: context.spacing.m,
);

RecurrenceEditorSpacing calendarRecurrenceSpacingCompact(
  BuildContext context,
) => RecurrenceEditorSpacing(
  chipSpacing: context.spacing.s,
  chipRunSpacing: context.spacing.s,
  weekdaySpacing: context.spacing.s,
  advancedSectionSpacing: context.spacing.m,
  endSpacing: context.spacing.m,
  fieldGap: context.spacing.m,
);
