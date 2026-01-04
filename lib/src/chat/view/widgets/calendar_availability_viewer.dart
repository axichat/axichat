// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/utils/calendar_availability_intervals.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_free_busy_editor.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _availabilityViewerHorizontalPadding = 16.0;
const double _availabilityViewerVerticalPadding = 8.0;
const double _availabilityViewerSectionSpacing = 8.0;
const double _availabilityViewerTitleSpacing = 6.0;
const double _availabilityViewerSourceSpacing = 6.0;
const double _availabilityViewerSourceButtonSpacing = 8.0;
const double _availabilityViewerHeaderIconSize = 18.0;
const double _availabilityViewerSourceMinHeight = 36.0;
const double _availabilityViewerHintSpacing = 6.0;
const double _availabilityViewerHeaderSpacing = 12.0;
const double _availabilityViewerRangeHintSpacing = 6.0;

const EdgeInsets _availabilityViewerPadding = EdgeInsets.symmetric(
  horizontal: _availabilityViewerHorizontalPadding,
  vertical: _availabilityViewerVerticalPadding,
);

const String _availabilityViewerTitleFallback = 'Free/busy';
const String _availabilityViewerOwnerPrefix = 'Free/busy for';
const String _availabilityViewerSourceLabel = 'Compare with';
const String _availabilityViewerPersonalLabel = 'Personal calendar';
const String _availabilityViewerChatLabel = 'Chat calendar';
const String _availabilityViewerMutualHint = 'Tap mutual time to request.';
const String _availabilityViewerLocalOwner = 'local';
const String _availabilityViewerRangeSeparator = ' - ';
const String _availabilityViewerBusyLabel = 'Busy';
const String _availabilityViewerFreeLabel = 'Free';
const String _availabilityViewerMutualLabel = 'Mutual';
const String _availabilityViewerBusyPrefix = 'Busy: ';
const String _availabilityViewerTitleSeparator = ' | ';
const String _availabilityViewerUnknownOwnerLabel = 'Unknown';

const int _availabilityViewerMinutesPerHour = 60;
const int _availabilityViewerHoursPerDay = 24;
const int _availabilityViewerDaysPerWeek = 7;
const int _availabilityViewerMinutesPerDay =
    _availabilityViewerMinutesPerHour * _availabilityViewerHoursPerDay;

typedef AvailabilityRequestHandler = Future<void> Function(
  DateTime start,
  DateTime end,
);

Future<void> showCalendarAvailabilityShareViewer({
  required BuildContext context,
  required CalendarAvailabilityShare share,
  required bool enableChatCalendar,
  required T Function<T>() locate,
  AvailabilityRequestHandler? onRequest,
  String? ownerLabel,
  String? chatLabel,
}) {
  return Navigator.of(context).push(
    AxiFadePageRoute<void>(
      duration: baseAnimationDuration,
      builder: (routeContext) => MultiBlocProvider(
        providers: [
          BlocProvider<CalendarBloc>.value(
            value: locate<CalendarBloc>(),
          ),
          if (enableChatCalendar)
            BlocProvider<ChatCalendarBloc>.value(
              value: locate<ChatCalendarBloc>(),
            ),
        ],
        child: CalendarAvailabilityShareViewerScreen(
          share: share,
          enableChatCalendar: enableChatCalendar,
          onRequest: onRequest,
          ownerLabel: ownerLabel,
          chatLabel: chatLabel,
        ),
      ),
    ),
  );
}

enum _AvailabilityViewerSource {
  personal,
  chat;

  bool get isPersonal => this == _AvailabilityViewerSource.personal;
  bool get isChat => this == _AvailabilityViewerSource.chat;
}

class CalendarAvailabilityShareViewerScreen extends StatefulWidget {
  const CalendarAvailabilityShareViewerScreen({
    super.key,
    required this.share,
    required this.enableChatCalendar,
    this.onRequest,
    this.ownerLabel,
    this.chatLabel,
  });

  final CalendarAvailabilityShare share;
  final bool enableChatCalendar;
  final AvailabilityRequestHandler? onRequest;
  final String? ownerLabel;
  final String? chatLabel;

  @override
  State<CalendarAvailabilityShareViewerScreen> createState() =>
      _CalendarAvailabilityShareViewerScreenState();
}

class _CalendarAvailabilityShareViewerScreenState
    extends State<CalendarAvailabilityShareViewerScreen> {
  late _AvailabilityViewerSource _source;

  @override
  void initState() {
    super.initState();
    _source = _AvailabilityViewerSource.personal;
  }

  @override
  void didUpdateWidget(CalendarAvailabilityShareViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enableChatCalendar && _source.isChat) {
      _source = _AvailabilityViewerSource.personal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final share = widget.share;
    final DateTime rangeStart = share.overlay.rangeStart.value;
    final DateTime rangeEnd = share.overlay.rangeEnd.value;
    final String ownerLabel = _resolveOwnerLabel(
      overrideLabel: widget.ownerLabel,
      fallbackLabel: share.overlay.owner,
    );
    final String title = _formatOwnerTitle(ownerLabel);
    final String rangeLabel = _formatRange(rangeStart, rangeEnd);
    final String? rangeHint = _formatRangeDurationHint(rangeStart, rangeEnd);
    final bool canUseChat = widget.enableChatCalendar;
    final bool showRequestHint = widget.onRequest != null;
    final Widget header = _AvailabilityViewerHeader(
      title: title,
      rangeLabel: rangeLabel,
      rangeHint: rangeHint,
      onClose: () => Navigator.of(context).maybePop(),
    );
    final Widget? sourceToggle = canUseChat
        ? _AvailabilityViewerSourceToggle(
            label: _availabilityViewerSourceLabel,
            selected: _source,
            onSelected: _handleSourceSelected,
            chatLabel: widget.chatLabel,
          )
        : null;
    final bool showControls = sourceToggle != null || showRequestHint;
    final Widget controls = _AvailabilityViewerControls(
      sourceToggle: sourceToggle,
      showRequestHint: showRequestHint,
    );
    final Widget summary = ResponsiveHelper.layoutBuilder(
      context,
      mobile: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (showControls)
            const SizedBox(height: _availabilityViewerSectionSpacing),
          if (showControls) controls,
        ],
      ),
      tablet: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: header),
          if (showControls)
            const SizedBox(width: _availabilityViewerHeaderSpacing),
          if (showControls) Flexible(child: controls),
        ],
      ),
      desktop: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: header),
          if (showControls)
            const SizedBox(width: _availabilityViewerHeaderSpacing),
          if (showControls) Flexible(child: controls),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: _availabilityViewerPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              summary,
              const SizedBox(height: _availabilityViewerSectionSpacing),
              Expanded(
                child: _AvailabilityViewerGrid(
                  share: share,
                  source: _source,
                  enableChatCalendar: canUseChat,
                  onRequest: widget.onRequest,
                  ownerLabel: ownerLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSourceSelected(_AvailabilityViewerSource source) {
    setState(() {
      _source = source;
    });
  }
}

class _AvailabilityViewerHeader extends StatelessWidget {
  const _AvailabilityViewerHeader({
    required this.title,
    required this.rangeLabel,
    required this.rangeHint,
    required this.onClose,
  });

  final String title;
  final String rangeLabel;
  final String? rangeHint;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Row(
      children: [
        AxiIconButton.ghost(
          iconData: LucideIcons.arrowLeft,
          iconSize: _availabilityViewerHeaderIconSize,
          onPressed: onClose,
        ),
        const SizedBox(width: _availabilityViewerSourceSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.h4.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: _availabilityViewerTitleSpacing),
              _AvailabilityViewerRangeRow(
                label: rangeLabel,
                hint: rangeHint,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailabilityViewerRangeRow extends StatelessWidget {
  const _AvailabilityViewerRangeRow({
    required this.label,
    required this.hint,
  });

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final Color muted = context.colorScheme.mutedForeground;
    final String? trimmedHint = hint?.trim();
    final bool hasHint = trimmedHint != null && trimmedHint.isNotEmpty;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _availabilityViewerRangeHintSpacing,
      runSpacing: _availabilityViewerRangeHintSpacing,
      children: [
        Text(
          label,
          style: context.textTheme.small.copyWith(color: muted),
        ),
        if (hasHint)
          Text(
            '($trimmedHint)',
            style: context.textTheme.small.copyWith(color: muted),
          ),
      ],
    );
  }
}

class _AvailabilityViewerControls extends StatelessWidget {
  const _AvailabilityViewerControls({
    required this.sourceToggle,
    required this.showRequestHint,
  });

  final Widget? sourceToggle;
  final bool showRequestHint;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    if (sourceToggle != null) {
      children.add(sourceToggle!);
    }
    if (showRequestHint) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: _availabilityViewerHintSpacing));
      }
      children.add(
        Text(
          _availabilityViewerMutualHint,
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.mutedForeground,
          ),
        ),
      );
    }
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _AvailabilityViewerSourceToggle extends StatelessWidget {
  const _AvailabilityViewerSourceToggle({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.chatLabel,
  });

  final String label;
  final _AvailabilityViewerSource selected;
  final ValueChanged<_AvailabilityViewerSource> onSelected;
  final String? chatLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final String resolvedChatLabel = _formatChatCalendarLabel(chatLabel);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _availabilityViewerSourceButtonSpacing,
      runSpacing: _availabilityViewerSourceSpacing,
      children: [
        Text(
          label,
          style: textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.mutedForeground,
          ),
        ),
        _AvailabilityViewerSourceButton(
          label: _availabilityViewerPersonalLabel,
          isSelected: selected.isPersonal,
          onPressed: () => onSelected(_AvailabilityViewerSource.personal),
        ),
        _AvailabilityViewerSourceButton(
          label: resolvedChatLabel,
          isSelected: selected.isChat,
          onPressed: () => onSelected(_AvailabilityViewerSource.chat),
        ),
      ],
    );
  }
}

class _AvailabilityViewerSourceButton extends StatelessWidget {
  const _AvailabilityViewerSourceButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = isSelected
        ? ShadButton.secondary(
            onPressed: onPressed,
            child: Text(label),
          )
        : ShadButton.outline(
            onPressed: onPressed,
            child: Text(label),
          );
    return ConstrainedBox(
      constraints:
          const BoxConstraints(minHeight: _availabilityViewerSourceMinHeight),
      child: button,
    );
  }
}

class _AvailabilityViewerGrid extends StatelessWidget {
  const _AvailabilityViewerGrid({
    required this.share,
    required this.source,
    required this.enableChatCalendar,
    required this.onRequest,
    required this.ownerLabel,
  });

  final CalendarAvailabilityShare share;
  final _AvailabilityViewerSource source;
  final bool enableChatCalendar;
  final AvailabilityRequestHandler? onRequest;
  final String ownerLabel;

  @override
  Widget build(BuildContext context) {
    if (source.isChat && !enableChatCalendar) {
      return const _AvailabilityViewerEmptyState(
        label: _availabilityViewerChatLabel,
      );
    }

    final Widget builder = source.isChat
        ? BlocBuilder<ChatCalendarBloc, CalendarState>(
            builder: (context, state) {
              return _AvailabilityViewerGridContent(
                share: share,
                model: state.model,
                onRequest: onRequest,
                ownerLabel: ownerLabel,
              );
            },
          )
        : BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              return _AvailabilityViewerGridContent(
                share: share,
                model: state.model,
                onRequest: onRequest,
                ownerLabel: ownerLabel,
              );
            },
          );

    return builder;
  }
}

class _AvailabilityViewerGridContent extends StatelessWidget {
  const _AvailabilityViewerGridContent({
    required this.share,
    required this.model,
    required this.onRequest,
    required this.ownerLabel,
  });

  final CalendarAvailabilityShare share;
  final CalendarModel model;
  final AvailabilityRequestHandler? onRequest;
  final String ownerLabel;

  @override
  Widget build(BuildContext context) {
    final CalendarAvailabilityOverlay overlay = share.overlay;
    final CalendarAvailabilityOverlay base = CalendarAvailabilityOverlay(
      owner: _availabilityViewerLocalOwner,
      rangeStart: overlay.rangeStart,
      rangeEnd: overlay.rangeEnd,
      isRedacted: false,
    );
    final CalendarAvailabilityOverlay comparison =
        deriveAvailabilityOverlay(model: model, base: base);
    final List<CalendarFreeBusyInterval> intervals =
        buildAvailabilityDisplayIntervals(
      rangeOverlay: overlay,
      comparisonOverlay: comparison,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _freeBusyGridFallbackHeight;
        return CalendarFreeBusyEditor.preview(
          rangeStart: overlay.rangeStart.value,
          rangeEnd: overlay.rangeEnd.value,
          intervals: intervals,
          tzid: overlay.rangeStart.tzid,
          onIntervalTapped: onRequest == null
              ? null
              : (interval) {
                  if (!interval.type.isBusyTentative) {
                    return;
                  }
                  onRequest?.call(interval.start.value, interval.end.value);
                },
          segmentTitleBuilder: (type, start, end) => _formatTileTitle(
            type: type,
            start: start,
            end: end,
            ownerLabel: ownerLabel,
          ),
        ).copyWithViewportHeight(height);
      },
    );
  }
}

const double _freeBusyGridFallbackHeight = 420.0;

class _AvailabilityViewerEmptyState extends StatelessWidget {
  const _AvailabilityViewerEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: context.textTheme.small.copyWith(
          color: context.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

String _resolveOwnerLabel({
  required String? overrideLabel,
  required String fallbackLabel,
}) {
  final String? trimmedOverride = overrideLabel?.trim();
  if (trimmedOverride != null && trimmedOverride.isNotEmpty) {
    return trimmedOverride;
  }
  final String trimmedFallback = fallbackLabel.trim();
  if (trimmedFallback.isNotEmpty) {
    return trimmedFallback;
  }
  return _availabilityViewerUnknownOwnerLabel;
}

String _formatOwnerTitle(String ownerLabel) {
  final String trimmedOwner = ownerLabel.trim();
  if (trimmedOwner.isEmpty) {
    return _availabilityViewerTitleFallback;
  }
  return '$_availabilityViewerOwnerPrefix $trimmedOwner';
}

String _formatChatCalendarLabel(String? chatLabel) {
  final String trimmed = chatLabel?.trim() ?? '';
  if (trimmed.isEmpty) {
    return _availabilityViewerChatLabel;
  }
  return '$_availabilityViewerChatLabel: $trimmed';
}

String _formatRange(DateTime start, DateTime end) {
  final String startLabel = TimeFormatter.formatFriendlyDateTime(start);
  final String endLabel = TimeFormatter.formatFriendlyDateTime(end);
  if (startLabel == endLabel) {
    return startLabel;
  }
  return '$startLabel$_availabilityViewerRangeSeparator$endLabel';
}

String? _formatRangeDurationHint(DateTime start, DateTime end) {
  final Duration duration = end.difference(start);
  final int minutes = duration.inMinutes;
  if (minutes <= 0 || minutes % _availabilityViewerMinutesPerDay != 0) {
    return null;
  }
  final int days = minutes ~/ _availabilityViewerMinutesPerDay;
  if (days <= 0) {
    return null;
  }
  if (days % _availabilityViewerDaysPerWeek == 0) {
    final int weeks = days ~/ _availabilityViewerDaysPerWeek;
    return _pluralize(weeks, 'week');
  }
  return _pluralize(days, 'day');
}

String _formatTileTitle({
  required CalendarFreeBusyType type,
  required DateTime start,
  required DateTime end,
  required String ownerLabel,
}) {
  final String timeLabel = _formatTimeRange(start, end);
  final String baseLabel = _formatTileBaseLabel(
    type: type,
    ownerLabel: ownerLabel,
  );
  if (timeLabel.isEmpty) {
    return baseLabel;
  }
  return '$baseLabel$_availabilityViewerTitleSeparator$timeLabel';
}

String _formatTileBaseLabel({
  required CalendarFreeBusyType type,
  required String ownerLabel,
}) {
  if (type.isBusy || type.isBusyUnavailable) {
    final String trimmedOwner = ownerLabel.trim();
    if (trimmedOwner.isEmpty) {
      return _availabilityViewerBusyLabel;
    }
    return '$_availabilityViewerBusyPrefix$trimmedOwner';
  }
  if (type.isBusyTentative) {
    return _availabilityViewerMutualLabel;
  }
  return _availabilityViewerFreeLabel;
}

String _formatTimeRange(DateTime start, DateTime end) {
  final String startLabel = TimeFormatter.formatTime(start);
  final String endLabel = TimeFormatter.formatTime(end);
  if (startLabel == endLabel) {
    return startLabel;
  }
  return '$startLabel$_availabilityViewerRangeSeparator$endLabel';
}

String _pluralize(int value, String unit) {
  if (value == 1) {
    return '$value $unit';
  }
  return '$value ${unit}s';
}

extension _CalendarFreeBusyEditorViewportX on CalendarFreeBusyEditor {
  Widget copyWithViewportHeight(double height) {
    return CalendarFreeBusyEditor(
      key: key,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      intervals: intervals,
      onIntervalsChanged: onIntervalsChanged,
      tzid: tzid,
      viewportHeight: height,
      isReadOnly: isReadOnly,
      onIntervalTapped: onIntervalTapped,
    );
  }
}
