// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/view/availability/calendar_free_busy_style.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

const int _availabilityPreviewLimit = 6;
const double _availabilityPreviewDotSize = 8.0;
const double _availabilityPreviewDotRadius = 4.0;
const double _availabilityPreviewDotSpacing = 6.0;
const double _availabilityPreviewRowSpacing = 6.0;
const double _availabilityPreviewSectionSpacing = 8.0;
const int _availabilityPreviewMaxLines = 2;

class CalendarAvailabilityPreview extends StatelessWidget {
  const CalendarAvailabilityPreview({
    super.key,
    required this.overlay,
    this.limit = _availabilityPreviewLimit,
  });

  final CalendarAvailabilityOverlay overlay;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final List<_AvailabilityPreviewInterval> intervals = _intervalPreviewFor(
      overlay.intervals,
    );
    final _IntervalPreviewResult preview = _limitIntervalPreview(
      intervals,
      limit,
    );
    final bool hasMore = preview.remainingCount > 0;
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );

    if (preview.intervals.isEmpty) {
      return Text(
        context.l10n.calendarAvailabilityPreviewEmpty,
        style: labelStyle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _availabilityPreviewSectionSpacing,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final interval in preview.intervals)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: _availabilityPreviewRowSpacing,
                ),
                child: _AvailabilityIntervalRow(interval: interval),
              ),
          ],
        ),
        if (hasMore)
          Text(
            context.l10n.calendarAvailabilityPreviewMore(
              preview.remainingCount,
            ),
            style: labelStyle,
          ),
      ],
    );
  }
}

class _AvailabilityIntervalRow extends StatelessWidget {
  const _AvailabilityIntervalRow({required this.interval});

  final _AvailabilityPreviewInterval interval;

  @override
  Widget build(BuildContext context) {
    final Color color = interval.type.baseColor;
    final TextStyle textStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.foreground,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _availabilityPreviewDotSize,
          height: _availabilityPreviewDotSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_availabilityPreviewDotRadius),
          ),
        ),
        const SizedBox(width: _availabilityPreviewDotSpacing),
        Expanded(
          child: Text(
            context.l10n.commonLabelValue(
              interval.type.label(context.l10n),
              _formatRange(context, interval.start, interval.end),
            ),
            style: textStyle,
            maxLines: _availabilityPreviewMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AvailabilityPreviewInterval {
  const _AvailabilityPreviewInterval({
    required this.type,
    required this.start,
    required this.end,
  });

  final CalendarFreeBusyType type;
  final DateTime start;
  final DateTime end;
}

class _IntervalPreviewResult {
  const _IntervalPreviewResult({
    required this.intervals,
    required this.remainingCount,
  });

  final List<_AvailabilityPreviewInterval> intervals;
  final int remainingCount;
}

_IntervalPreviewResult _limitIntervalPreview(
  List<_AvailabilityPreviewInterval> intervals,
  int limit,
) {
  if (intervals.length <= limit) {
    return _IntervalPreviewResult(intervals: intervals, remainingCount: 0);
  }
  final preview = intervals.take(limit).toList(growable: false);
  final remaining = intervals.length - limit;
  return _IntervalPreviewResult(intervals: preview, remainingCount: remaining);
}

List<_AvailabilityPreviewInterval> _intervalPreviewFor(
  List<CalendarFreeBusyInterval> intervals,
) {
  if (intervals.isEmpty) {
    return const <_AvailabilityPreviewInterval>[];
  }
  final sorted = intervals.toList()
    ..sort((a, b) => a.start.value.compareTo(b.start.value));
  final merged = <_AvailabilityPreviewInterval>[];
  for (final CalendarFreeBusyInterval interval in sorted) {
    final DateTime start = interval.start.value;
    final DateTime end = interval.end.value;
    if (merged.isEmpty) {
      merged.add(
        _AvailabilityPreviewInterval(
          type: interval.type,
          start: start,
          end: end,
        ),
      );
      continue;
    }
    final _AvailabilityPreviewInterval last = merged.last;
    final bool shouldMerge =
        last.type == interval.type &&
        !start.isAfter(last.end) &&
        end.isAfter(last.start);
    if (shouldMerge) {
      final DateTime mergedEnd = end.isAfter(last.end) ? end : last.end;
      merged[merged.length - 1] = _AvailabilityPreviewInterval(
        type: last.type,
        start: last.start,
        end: mergedEnd,
      );
      continue;
    }
    merged.add(
      _AvailabilityPreviewInterval(type: interval.type, start: start, end: end),
    );
  }
  return merged;
}

String _formatRange(BuildContext context, DateTime start, DateTime end) {
  final String startLabel = TimeFormatter.formatFriendlyDateTime(
    context.l10n,
    start,
  );
  final String endLabel = TimeFormatter.formatFriendlyDateTime(
    context.l10n,
    end,
  );
  if (startLabel == endLabel) {
    return startLabel;
  }
  return context.l10n.commonRangeLabel(startLabel, endLabel);
}
