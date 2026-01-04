// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/utils/calendar_availability_intervals.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_free_busy_editor.dart';

class CalendarAvailabilityGridPreview extends StatelessWidget {
  const CalendarAvailabilityGridPreview({
    super.key,
    required this.rangeOverlay,
    this.comparisonOverlay,
    this.onIntervalTapped,
  });

  final CalendarAvailabilityOverlay rangeOverlay;
  final CalendarAvailabilityOverlay? comparisonOverlay;
  final ValueChanged<CalendarFreeBusyInterval>? onIntervalTapped;

  @override
  Widget build(BuildContext context) {
    final DateTime start = rangeOverlay.rangeStart.value;
    final DateTime end = rangeOverlay.rangeEnd.value;
    final List<CalendarFreeBusyInterval> intervals =
        buildAvailabilityDisplayIntervals(
      rangeOverlay: rangeOverlay,
      comparisonOverlay: comparisonOverlay,
    );
    final ValueChanged<CalendarFreeBusyInterval>? handler =
        onIntervalTapped == null
            ? null
            : (interval) {
                if (interval.type == CalendarFreeBusyType.busyTentative) {
                  onIntervalTapped!(interval);
                }
              };
    return CalendarFreeBusyEditor.preview(
      rangeStart: start,
      rangeEnd: end,
      intervals: intervals,
      tzid: rangeOverlay.rangeStart.tzid,
      onIntervalTapped: handler,
    );
  }
}
