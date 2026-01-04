// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_availability_grid_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _availabilityCardRadius = 18.0;
const double _availabilityAccentWidth = 4.0;
const double _availabilityAccentRadius = 14.0;
const double _availabilityContentSpacing = 6.0;
const double _availabilitySectionSpacing = 8.0;
const double _availabilityActionSpacing = 8.0;
const double _availabilityHelperSpacing = 4.0;
const int _availabilityRequestDescriptionMaxLines = 3;

const EdgeInsets _availabilityCardPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 10);
const EdgeInsets _availabilityFooterPadding = EdgeInsets.only(top: 4);
const EdgeInsets _availabilityActionPadding = EdgeInsets.only(top: 6);

const String _availabilityShareLabel = 'Availability';
const String _availabilityRequestLabel = 'Availability request';
const String _availabilityAcceptedLabel = 'Availability accepted';
const String _availabilityDeclinedLabel = 'Availability declined';
const String _availabilityRangeSeparator = ' - ';
const String _availabilityIntervalsEmptyLabel = 'No availability intervals.';
const String _availabilityRequestButtonLabel = 'Request time';
const String _availabilityAcceptButtonLabel = 'Accept';
const String _availabilityDeclineButtonLabel = 'Decline';
const String _availabilityRequestTitleFallback = 'Requested time';
const String _availabilityOverlayAddButtonLabel = 'Show on calendar';
const String _availabilityOverlayRemoveButtonLabel = 'Hide from calendar';
const String _availabilityCompareToggleLabel = 'Mutual availability (preview)';
const String _availabilityCompareHelperText =
    'Highlights mutual free time in this preview.';
const String _availabilityOverlayHelperText =
    'Adds a colored overlay to your calendar view.';
const String _availabilityShadowOwnerLabel = 'local';
const bool _availabilityShadowRedacted = true;
const CalendarFreeBusyType _availabilityShadowIntervalType =
    CalendarFreeBusyType.busyTentative;

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
                      share: value.share,
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

class _AvailabilityShareBody extends StatefulWidget {
  const _AvailabilityShareBody({
    required this.share,
    required this.onRequest,
  });

  final CalendarAvailabilityShare share;
  final VoidCallback? onRequest;

  @override
  State<_AvailabilityShareBody> createState() => _AvailabilityShareBodyState();
}

class _AvailabilityShareBodyState extends State<_AvailabilityShareBody> {
  bool _showComparison = true;

  @override
  Widget build(BuildContext context) {
    final CalendarAvailabilityShare share = widget.share;
    final CalendarAvailabilityOverlay overlay = share.overlay;
    final CalendarBloc? calendarBloc = _maybeReadCalendarBloc(context);

    final Widget content = calendarBloc == null
        ? _AvailabilityShareContent(
            overlay: overlay,
            comparisonOverlay: null,
            rangeLabel: _formatRange(
              overlay.rangeStart.value,
              overlay.rangeEnd.value,
            ),
            showComparisonToggle: false,
            compareValue: _showComparison,
            onCompareChanged: null,
            overlayButtonLabel: null,
            onOverlayPressed: null,
            isOverlayApplied: false,
            onRequest: widget.onRequest,
          )
        : BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              final CalendarAvailabilityOverlay? shadowOverlay = _showComparison
                  ? _resolveShadowOverlay(
                      model: state.model,
                      shareOverlay: overlay,
                    )
                  : null;
              final bool isOverlayApplied =
                  state.model.availabilityOverlays.containsKey(share.id);

              return _AvailabilityShareContent(
                overlay: overlay,
                comparisonOverlay: shadowOverlay,
                rangeLabel: _formatRange(
                  overlay.rangeStart.value,
                  overlay.rangeEnd.value,
                ),
                showComparisonToggle: true,
                compareValue: _showComparison,
                onCompareChanged: (value) => setState(() {
                  _showComparison = value;
                }),
                overlayButtonLabel: isOverlayApplied
                    ? _availabilityOverlayRemoveButtonLabel
                    : _availabilityOverlayAddButtonLabel,
                onOverlayPressed: () => _handleOverlayPressed(
                  calendarBloc,
                  shareId: share.id,
                  overlay: overlay,
                  isApplied: isOverlayApplied,
                ),
                isOverlayApplied: isOverlayApplied,
                onRequest: widget.onRequest,
              );
            },
          );

    return content;
  }

  void _handleOverlayPressed(
    CalendarBloc bloc, {
    required String shareId,
    required CalendarAvailabilityOverlay overlay,
    required bool isApplied,
  }) {
    final String trimmedId = shareId.trim();
    if (trimmedId.isEmpty) {
      return;
    }
    if (isApplied) {
      bloc.add(
        CalendarEvent.availabilityOverlayRemoved(
          overlayId: trimmedId,
        ),
      );
      return;
    }
    bloc.add(
      CalendarEvent.availabilityOverlayUpdated(
        overlayId: trimmedId,
        overlay: overlay,
      ),
    );
  }
}

class _AvailabilityShareContent extends StatelessWidget {
  const _AvailabilityShareContent({
    required this.overlay,
    required this.comparisonOverlay,
    required this.rangeLabel,
    required this.showComparisonToggle,
    required this.compareValue,
    required this.onCompareChanged,
    required this.overlayButtonLabel,
    required this.onOverlayPressed,
    required this.isOverlayApplied,
    required this.onRequest,
  });

  final CalendarAvailabilityOverlay overlay;
  final CalendarAvailabilityOverlay? comparisonOverlay;
  final String rangeLabel;
  final bool showComparisonToggle;
  final bool compareValue;
  final ValueChanged<bool>? onCompareChanged;
  final String? overlayButtonLabel;
  final VoidCallback? onOverlayPressed;
  final bool isOverlayApplied;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final bool showEmptyLabel = overlay.intervals.isEmpty;
    final bool hasOverlayAction = onOverlayPressed != null;
    final bool hasActions = onRequest != null || hasOverlayAction;
    final TextStyle helperStyle = textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _availabilitySectionSpacing,
      children: [
        Text(
          _availabilityShareLabel,
          style: textTheme.large.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          rangeLabel,
          style: textTheme.small.copyWith(
            color: context.colorScheme.mutedForeground,
          ),
        ),
        CalendarAvailabilityGridPreview(
          rangeOverlay: overlay,
          comparisonOverlay: comparisonOverlay,
          onIntervalTapped: onRequest == null ? null : (_) => onRequest?.call(),
        ),
        if (showEmptyLabel)
          Text(
            _availabilityIntervalsEmptyLabel,
            style: textTheme.small.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
          ),
        if (showComparisonToggle && onCompareChanged != null) ...[
          _AvailabilityComparisonToggle(
            value: compareValue,
            onChanged: onCompareChanged!,
          ),
          const SizedBox(height: _availabilityHelperSpacing),
          Text(_availabilityCompareHelperText, style: helperStyle),
        ],
        if (hasActions)
          Padding(
            padding: _availabilityActionPadding,
            child: Wrap(
              spacing: _availabilityActionSpacing,
              runSpacing: _availabilityActionSpacing,
              children: [
                if (hasOverlayAction && overlayButtonLabel != null)
                  _AvailabilityOverlayActionButton(
                    label: overlayButtonLabel!,
                    isApplied: isOverlayApplied,
                    onPressed: onOverlayPressed,
                  ),
                if (onRequest != null)
                  ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: onRequest,
                    child: const Text(_availabilityRequestButtonLabel),
                  ),
              ],
            ),
          ),
        if (hasOverlayAction)
          Padding(
            padding: const EdgeInsets.only(top: _availabilityHelperSpacing),
            child: Text(
              _availabilityOverlayHelperText,
              style: helperStyle,
            ),
          ),
      ],
    );
  }
}

class _AvailabilityComparisonToggle extends StatelessWidget {
  const _AvailabilityComparisonToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ShadSwitch(
      value: value,
      onChanged: onChanged,
      label: const Text(_availabilityCompareToggleLabel),
    );
  }
}

class _AvailabilityOverlayActionButton extends StatelessWidget {
  const _AvailabilityOverlayActionButton({
    required this.label,
    required this.isApplied,
    required this.onPressed,
  });

  final String label;
  final bool isApplied;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ShadButton button = isApplied
        ? ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: onPressed,
            child: Text(label),
          )
        : ShadButton.secondary(
            size: ShadButtonSize.sm,
            onPressed: onPressed,
            child: Text(label),
          );
    return button;
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

String _formatRange(DateTime start, DateTime end) {
  final String startLabel = TimeFormatter.formatFriendlyDateTime(start);
  final String endLabel = TimeFormatter.formatFriendlyDateTime(end);
  if (startLabel == endLabel) {
    return startLabel;
  }
  return '$startLabel$_availabilityRangeSeparator$endLabel';
}

CalendarBloc? _maybeReadCalendarBloc(BuildContext context) {
  try {
    return context.read<CalendarBloc>();
  } on FlutterError {
    return null;
  }
}

CalendarAvailabilityOverlay? _resolveShadowOverlay({
  required CalendarModel model,
  required CalendarAvailabilityOverlay shareOverlay,
}) {
  final CalendarAvailabilityOverlay base = CalendarAvailabilityOverlay(
    owner: _availabilityShadowOwnerLabel,
    rangeStart: shareOverlay.rangeStart,
    rangeEnd: shareOverlay.rangeEnd,
    isRedacted: _availabilityShadowRedacted,
  );
  final CalendarAvailabilityOverlay derived = deriveAvailabilityOverlay(
    model: model,
    base: base,
  );
  if (derived.intervals.isEmpty) {
    return null;
  }
  final List<CalendarFreeBusyInterval> shadowIntervals = derived.intervals
      .map(
        (interval) => CalendarFreeBusyInterval(
          start: interval.start,
          end: interval.end,
          type: _availabilityShadowIntervalType,
        ),
      )
      .toList(growable: false);
  return derived.copyWith(intervals: shadowIntervals);
}
