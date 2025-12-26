import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _availabilityCardRadius = 18.0;
const double _availabilityAccentWidth = 4.0;
const double _availabilityAccentRadius = 14.0;
const double _availabilityContentSpacing = 6.0;
const double _availabilitySectionSpacing = 8.0;
const double _availabilityIntervalSpacing = 6.0;
const double _availabilityIntervalDotSize = 8.0;
const double _availabilityIntervalDotRadius = 4.0;
const double _availabilityActionSpacing = 8.0;
const int _availabilityIntervalPreviewLimit = 6;
const int _availabilityRequestDescriptionMaxLines = 3;

const EdgeInsets _availabilityCardPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 10);
const EdgeInsets _availabilityFooterPadding = EdgeInsets.only(top: 4);
const EdgeInsets _availabilityActionPadding = EdgeInsets.only(top: 6);
const EdgeInsets _availabilityIntervalRowPadding = EdgeInsets.only(bottom: 4);

const String _availabilityShareLabel = 'Availability';
const String _availabilityRequestLabel = 'Availability request';
const String _availabilityAcceptedLabel = 'Availability accepted';
const String _availabilityDeclinedLabel = 'Availability declined';
const String _availabilityRangeSeparator = ' - ';
const String _availabilityIntervalSeparator = ': ';
const String _availabilityIntervalsEmptyLabel = 'No availability intervals.';
const String _availabilityMorePrefix = 'and ';
const String _availabilityMoreSuffix = ' more';
const String _availabilityRequestButtonLabel = 'Request time';
const String _availabilityAcceptButtonLabel = 'Accept';
const String _availabilityDeclineButtonLabel = 'Decline';
const String _availabilityRequestTitleFallback = 'Requested time';

const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];

class CalendarAvailabilityMessageCard extends StatelessWidget {
  const CalendarAvailabilityMessageCard({
    super.key,
    required this.message,
    this.footerDetails = _emptyInlineSpans,
    this.onRequest,
    this.onAccept,
    this.onDecline,
  });

  final CalendarAvailabilityMessage message;
  final List<InlineSpan> footerDetails;
  final VoidCallback? onRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor = _accentColorForMessage(context, message);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_availabilityCardRadius),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvailabilityAccent(color: accentColor),
          Expanded(
            child: Padding(
              padding: _availabilityCardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: _availabilityContentSpacing,
                children: [
                  message.map(
                    share: (value) => _AvailabilityShareBody(
                      overlay: value.share.overlay,
                      onRequest: onRequest,
                    ),
                    request: (value) => _AvailabilityRequestBody(
                      request: value.request,
                      onAccept: onAccept,
                      onDecline: onDecline,
                    ),
                    response: (value) => _AvailabilityResponseBody(
                      response: value.response,
                    ),
                  ),
                  if (footerDetails.isNotEmpty)
                    Padding(
                      padding: _availabilityFooterPadding,
                      child: Text.rich(
                        TextSpan(children: footerDetails),
                        style: context.textTheme.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityAccent extends StatelessWidget {
  const _AvailabilityAccent({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _availabilityAccentWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(_availabilityAccentRadius),
        ),
      ),
    );
  }
}

class _AvailabilityShareBody extends StatelessWidget {
  const _AvailabilityShareBody({
    required this.overlay,
    required this.onRequest,
  });

  final CalendarAvailabilityOverlay overlay;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final List<_AvailabilityIntervalPreview> intervals =
        _intervalPreviewFor(overlay.intervals);
    final preview = _limitIntervalPreview(intervals);
    final bool hasMore = preview.remainingCount > 0;
    final textTheme = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _availabilitySectionSpacing,
      children: [
        Text(
          _availabilityShareLabel,
          style: textTheme.large.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          _formatRange(
            overlay.rangeStart.value,
            overlay.rangeEnd.value,
          ),
          style: textTheme.small.copyWith(
            color: context.colorScheme.mutedForeground,
          ),
        ),
        if (preview.intervals.isEmpty)
          Text(
            _availabilityIntervalsEmptyLabel,
            style: textTheme.small.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final interval in preview.intervals)
                Padding(
                  padding: _availabilityIntervalRowPadding,
                  child: _AvailabilityIntervalRow(interval: interval),
                ),
              if (hasMore)
                Text(
                  '$_availabilityMorePrefix${preview.remainingCount}'
                  '$_availabilityMoreSuffix',
                  style: textTheme.small.copyWith(
                    color: context.colorScheme.mutedForeground,
                  ),
                ),
            ],
          ),
        if (onRequest != null)
          Padding(
            padding: _availabilityActionPadding,
            child: ShadButton(
              size: ShadButtonSize.sm,
              onPressed: onRequest,
              child: const Text(_availabilityRequestButtonLabel),
            ),
          ),
      ],
    );
  }
}

class _AvailabilityRequestBody extends StatelessWidget {
  const _AvailabilityRequestBody({
    required this.request,
    this.onAccept,
    this.onDecline,
  });

  final CalendarAvailabilityRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final title = request.title?.trim();
    final description = request.description?.trim();
    final requestTitle =
        title?.isNotEmpty == true ? title! : _availabilityRequestTitleFallback;
    final bool hasActions = onAccept != null || onDecline != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _availabilitySectionSpacing,
      children: [
        Text(
          _availabilityRequestLabel,
          style: textTheme.large.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          requestTitle,
          style: textTheme.small.copyWith(
            color: context.colorScheme.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _formatRange(
            request.start.value,
            request.end.value,
          ),
          style: textTheme.small.copyWith(
            color: context.colorScheme.mutedForeground,
          ),
        ),
        if (description?.isNotEmpty == true)
          Text(
            description!,
            style: textTheme.small.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
            maxLines: _availabilityRequestDescriptionMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        if (hasActions)
          Padding(
            padding: _availabilityActionPadding,
            child: Wrap(
              spacing: _availabilityActionSpacing,
              runSpacing: _availabilityActionSpacing,
              children: [
                if (onAccept != null)
                  ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: onAccept,
                    child: const Text(_availabilityAcceptButtonLabel),
                  ),
                if (onDecline != null)
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: onDecline,
                    child: const Text(_availabilityDeclineButtonLabel),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AvailabilityResponseBody extends StatelessWidget {
  const _AvailabilityResponseBody({
    required this.response,
  });

  final CalendarAvailabilityResponse response;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final label = response.status.isAccepted
        ? _availabilityAcceptedLabel
        : _availabilityDeclinedLabel;
    final note = response.note?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _availabilitySectionSpacing,
      children: [
        Text(
          label,
          style: textTheme.large.copyWith(fontWeight: FontWeight.w600),
        ),
        if (note?.isNotEmpty == true)
          Text(
            note!,
            style: textTheme.small.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
          ),
      ],
    );
  }
}

class _AvailabilityIntervalRow extends StatelessWidget {
  const _AvailabilityIntervalRow({
    required this.interval,
  });

  final _AvailabilityIntervalPreview interval;

  @override
  Widget build(BuildContext context) {
    final color = _colorForInterval(context, interval.type);
    final textTheme = context.textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _availabilityIntervalDotSize,
          height: _availabilityIntervalDotSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_availabilityIntervalDotRadius),
          ),
        ),
        const SizedBox(width: _availabilityIntervalSpacing),
        Expanded(
          child: Text(
            '${interval.type.label}$_availabilityIntervalSeparator'
            '${_formatRange(interval.start, interval.end)}',
            style: textTheme.small.copyWith(
              color: context.colorScheme.foreground,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityIntervalPreview {
  const _AvailabilityIntervalPreview({
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

  final List<_AvailabilityIntervalPreview> intervals;
  final int remainingCount;
}

_IntervalPreviewResult _limitIntervalPreview(
  List<_AvailabilityIntervalPreview> intervals,
) {
  if (intervals.length <= _availabilityIntervalPreviewLimit) {
    return _IntervalPreviewResult(intervals: intervals, remainingCount: 0);
  }
  final preview =
      intervals.take(_availabilityIntervalPreviewLimit).toList(growable: false);
  final remaining = intervals.length - _availabilityIntervalPreviewLimit;
  return _IntervalPreviewResult(intervals: preview, remainingCount: remaining);
}

List<_AvailabilityIntervalPreview> _intervalPreviewFor(
  List<CalendarFreeBusyInterval> intervals,
) {
  if (intervals.isEmpty) {
    return const <_AvailabilityIntervalPreview>[];
  }
  final sorted = intervals.toList()
    ..sort((a, b) => a.start.value.compareTo(b.start.value));
  final merged = <_AvailabilityIntervalPreview>[];
  for (final interval in sorted) {
    final DateTime start = interval.start.value;
    final DateTime end = interval.end.value;
    if (merged.isEmpty) {
      merged.add(
        _AvailabilityIntervalPreview(
          type: interval.type,
          start: start,
          end: end,
        ),
      );
      continue;
    }
    final last = merged.last;
    final bool shouldMerge = last.type == interval.type &&
        !start.isAfter(last.end) &&
        end.isAfter(last.start);
    if (shouldMerge) {
      final DateTime mergedEnd = end.isAfter(last.end) ? end : last.end;
      merged[merged.length - 1] = _AvailabilityIntervalPreview(
        type: last.type,
        start: last.start,
        end: mergedEnd,
      );
      continue;
    }
    merged.add(
      _AvailabilityIntervalPreview(
        type: interval.type,
        start: start,
        end: end,
      ),
    );
  }
  return merged;
}

Color _accentColorForMessage(
  BuildContext context,
  CalendarAvailabilityMessage message,
) {
  final colors = context.colorScheme;
  return message.map(
    share: (_) => colors.primary,
    request: (_) => colors.primary,
    response: (value) =>
        value.response.status.isAccepted ? colors.primary : colors.destructive,
  );
}

Color _colorForInterval(BuildContext context, CalendarFreeBusyType type) {
  final colors = context.colorScheme;
  return switch (type) {
    CalendarFreeBusyType.free => colors.primary,
    CalendarFreeBusyType.busy => colors.mutedForeground,
    CalendarFreeBusyType.busyUnavailable => colors.destructive,
    CalendarFreeBusyType.busyTentative => colors.border,
  };
}

String _formatRange(DateTime start, DateTime end) {
  final String startLabel = TimeFormatter.formatFriendlyDateTime(start);
  final String endLabel = TimeFormatter.formatFriendlyDateTime(end);
  if (startLabel == endLabel) {
    return startLabel;
  }
  return '$startLabel$_availabilityRangeSeparator$endLabel';
}
