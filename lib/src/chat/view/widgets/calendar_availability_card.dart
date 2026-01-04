// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _availabilityCardRadius = 18.0;
const double _availabilityAccentWidth = 4.0;
const double _availabilityAccentRadius = 14.0;
const double _availabilityContentSpacing = 6.0;
const double _availabilitySectionSpacing = 8.0;
const int _availabilityRequestDescriptionMaxLines = 3;
const double _availabilityActionSpacing = 8.0;

const EdgeInsets _availabilityCardPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 10);
const EdgeInsets _availabilityFooterPadding = EdgeInsets.only(top: 4);
const EdgeInsets _availabilityActionPadding = EdgeInsets.only(top: 6);

const String _availabilityShareLabel = 'Availability';
const String _availabilityShareSubtitle = 'Tap to view free/busy.';
const String _availabilityRequestLabel = 'Availability request';
const String _availabilityAcceptedLabel = 'Availability accepted';
const String _availabilityDeclinedLabel = 'Availability declined';
const String _availabilityRangeSeparator = ' - ';
const String _availabilityAcceptButtonLabel = 'Accept';
const String _availabilityDeclineButtonLabel = 'Decline';
const String _availabilityRequestTitleFallback = 'Requested time';

const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];

class CalendarAvailabilityMessageCard extends StatelessWidget {
  const CalendarAvailabilityMessageCard({
    super.key,
    required this.message,
    this.footerDetails = _emptyInlineSpans,
    this.onOpen,
    this.onAccept,
    this.onDecline,
  });

  final CalendarAvailabilityMessage message;
  final List<InlineSpan> footerDetails;
  final VoidCallback? onOpen;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor = _accentColorForMessage(context, message);
    final bool isShare = message.maybeMap(
      share: (_) => true,
      orElse: () => false,
    );
    final Widget card = DecoratedBox(
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
    if (!isShare || onOpen == null) {
      return card;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onOpen,
      child: card,
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
    required this.share,
  });

  final CalendarAvailabilityShare share;

  @override
  Widget build(BuildContext context) {
    final overlay = share.overlay;
    final String rangeLabel = _formatRange(
      overlay.rangeStart.value,
      overlay.rangeEnd.value,
    );
    return _AvailabilityShareContent(
      rangeLabel: rangeLabel,
    );
  }
}

class _AvailabilityShareContent extends StatelessWidget {
  const _AvailabilityShareContent({
    required this.rangeLabel,
  });

  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
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
        Text(_availabilityShareSubtitle, style: helperStyle),
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
