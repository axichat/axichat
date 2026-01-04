// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/common/ui/ui.dart';

extension CalendarFreeBusyTypeColorX on CalendarFreeBusyType {
  Color get baseColor => switch (this) {
        CalendarFreeBusyType.free => calendarSuccessColor,
        CalendarFreeBusyType.busy => calendarDangerColor,
        CalendarFreeBusyType.busyUnavailable => calendarDangerColor,
        CalendarFreeBusyType.busyTentative => calendarPrimaryColor,
      };
}
