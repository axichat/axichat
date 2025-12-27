import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/common/ui/ui.dart';

extension CalendarFreeBusyTypeColorX on CalendarFreeBusyType {
  Color get baseColor => switch (this) {
        CalendarFreeBusyType.free => calendarPrimaryColor,
        CalendarFreeBusyType.busy => calendarNeutralColor,
        CalendarFreeBusyType.busyUnavailable => calendarDangerColor,
        CalendarFreeBusyType.busyTentative => calendarBorderDarkColor,
      };
}
