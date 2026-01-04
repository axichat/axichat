// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';

List<CalendarFreeBusyInterval> buildAvailabilityDisplayIntervals({
  required CalendarAvailabilityOverlay rangeOverlay,
  CalendarAvailabilityOverlay? comparisonOverlay,
}) {
  final DateTime rangeStart = rangeOverlay.rangeStart.value;
  final DateTime rangeEnd = rangeOverlay.rangeEnd.value;
  final String? tzid = rangeOverlay.rangeStart.tzid;
  final List<_AvailabilitySegment> sender = _segmentsForOverlay(
    rangeOverlay,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
  if (comparisonOverlay == null) {
    return _segmentsToIntervals(sender, tzid);
  }
  final List<_AvailabilitySegment> comparison = _segmentsForOverlay(
    comparisonOverlay,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
  final List<_AvailabilitySegment> merged = _mergeSegments(
    sender: sender,
    comparison: comparison,
  );
  return _segmentsToIntervals(merged, tzid);
}

List<CalendarFreeBusyInterval> buildMutualAvailabilityIntervals({
  required CalendarAvailabilityOverlay rangeOverlay,
  required CalendarAvailabilityOverlay comparisonOverlay,
}) {
  final List<CalendarFreeBusyInterval> intervals =
      buildAvailabilityDisplayIntervals(
    rangeOverlay: rangeOverlay,
    comparisonOverlay: comparisonOverlay,
  );
  return intervals
      .where((interval) => interval.type == CalendarFreeBusyType.busyTentative)
      .toList(growable: false);
}

class _AvailabilitySegment {
  const _AvailabilitySegment({
    required this.start,
    required this.end,
    required this.type,
  });

  final DateTime start;
  final DateTime end;
  final CalendarFreeBusyType type;

  bool get isFree => type.isFree;
}

List<_AvailabilitySegment> _segmentsForOverlay(
  CalendarAvailabilityOverlay overlay, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  if (!rangeEnd.isAfter(rangeStart)) {
    return <_AvailabilitySegment>[];
  }
  final List<CalendarFreeBusyInterval> sorted =
      List<CalendarFreeBusyInterval>.from(overlay.intervals)
        ..sort((a, b) => a.start.value.compareTo(b.start.value));
  final List<_AvailabilitySegment> segments = <_AvailabilitySegment>[];
  DateTime cursor = rangeStart;
  if (sorted.isEmpty) {
    return <_AvailabilitySegment>[
      _AvailabilitySegment(
        start: rangeStart,
        end: rangeEnd,
        type: CalendarFreeBusyType.free,
      ),
    ];
  }
  for (final CalendarFreeBusyInterval interval in sorted) {
    final DateTime start = interval.start.value;
    final DateTime end = interval.end.value;
    if (!end.isAfter(rangeStart) || !start.isBefore(rangeEnd)) {
      continue;
    }
    final DateTime clippedStart = _maxDateTime(start, rangeStart);
    final DateTime clippedEnd = _minDateTime(end, rangeEnd);
    if (!clippedEnd.isAfter(clippedStart)) {
      continue;
    }
    if (clippedStart.isAfter(cursor)) {
      segments.add(
        _AvailabilitySegment(
          start: cursor,
          end: clippedStart,
          type: CalendarFreeBusyType.free,
        ),
      );
    }
    segments.add(
      _AvailabilitySegment(
        start: clippedStart,
        end: clippedEnd,
        type: _sanitizeType(interval.type),
      ),
    );
    cursor = clippedEnd;
  }
  if (cursor.isBefore(rangeEnd)) {
    segments.add(
      _AvailabilitySegment(
        start: cursor,
        end: rangeEnd,
        type: CalendarFreeBusyType.free,
      ),
    );
  }
  return segments;
}

List<_AvailabilitySegment> _mergeSegments({
  required List<_AvailabilitySegment> sender,
  required List<_AvailabilitySegment> comparison,
}) {
  final List<_AvailabilitySegment> merged = <_AvailabilitySegment>[];
  var senderIndex = 0;
  var comparisonIndex = 0;
  while (senderIndex < sender.length && comparisonIndex < comparison.length) {
    final _AvailabilitySegment senderSegment = sender[senderIndex];
    final _AvailabilitySegment comparisonSegment = comparison[comparisonIndex];
    final DateTime maxStart =
        _maxDateTime(senderSegment.start, comparisonSegment.start);
    final DateTime minEnd =
        _minDateTime(senderSegment.end, comparisonSegment.end);
    if (!minEnd.isAfter(maxStart)) {
      if (senderSegment.end.isBefore(comparisonSegment.end)) {
        senderIndex += 1;
      } else {
        comparisonIndex += 1;
      }
      continue;
    }
    final bool mutuallyFree = senderSegment.isFree && comparisonSegment.isFree;
    final CalendarFreeBusyType type = mutuallyFree
        ? CalendarFreeBusyType.busyTentative
        : senderSegment.isFree
            ? CalendarFreeBusyType.free
            : CalendarFreeBusyType.busy;
    merged.add(
      _AvailabilitySegment(
        start: maxStart,
        end: minEnd,
        type: type,
      ),
    );
    if (senderSegment.end.isAtSameMomentAs(minEnd)) {
      senderIndex += 1;
    }
    if (comparisonSegment.end.isAtSameMomentAs(minEnd)) {
      comparisonIndex += 1;
    }
  }
  return merged;
}

List<CalendarFreeBusyInterval> _segmentsToIntervals(
  List<_AvailabilitySegment> segments,
  String? tzid,
) {
  return segments
      .map(
        (segment) => CalendarFreeBusyInterval(
          start: CalendarDateTime(value: segment.start, tzid: tzid),
          end: CalendarDateTime(value: segment.end, tzid: tzid),
          type: segment.type,
        ),
      )
      .toList(growable: false);
}

CalendarFreeBusyType _sanitizeType(CalendarFreeBusyType type) {
  if (type == CalendarFreeBusyType.busyTentative) {
    return CalendarFreeBusyType.busyTentative;
  }
  return type.isFree ? CalendarFreeBusyType.free : CalendarFreeBusyType.busy;
}

DateTime _maxDateTime(DateTime first, DateTime second) =>
    first.isAfter(second) ? first : second;

DateTime _minDateTime(DateTime first, DateTime second) =>
    first.isBefore(second) ? first : second;
