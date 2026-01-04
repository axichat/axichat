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
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_free_busy_editor.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _availabilityViewerHorizontalPadding = 16.0;
const double _availabilityViewerVerticalPadding = 12.0;
const double _availabilityViewerSectionSpacing = 12.0;
const double _availabilityViewerTitleSpacing = 4.0;
const double _availabilityViewerSourceSpacing = 8.0;
const double _availabilityViewerSourceButtonSpacing = 8.0;
const double _availabilityViewerHeaderIconSize = 18.0;
const double _availabilityViewerSourceMinHeight = 36.0;
const double _availabilityViewerHintSpacing = 6.0;

const EdgeInsets _availabilityViewerPadding = EdgeInsets.symmetric(
  horizontal: _availabilityViewerHorizontalPadding,
  vertical: _availabilityViewerVerticalPadding,
);

const String _availabilityViewerTitle = 'Availability';
const String _availabilityViewerSubtitle = 'Free/busy with mutual time.';
const String _availabilityViewerSourceLabel = 'Compare with';
const String _availabilityViewerPersonalLabel = 'Personal calendar';
const String _availabilityViewerChatLabel = 'Chat calendar';
const String _availabilityViewerMutualHint = 'Tap mutual time to request.';
const String _availabilityViewerLocalOwner = 'local';
const String _availabilityViewerRangeSeparator = ' - ';

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
  });

  final CalendarAvailabilityShare share;
  final bool enableChatCalendar;
  final AvailabilityRequestHandler? onRequest;

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
    final rangeLabel = _formatRange(
      share.overlay.rangeStart.value,
      share.overlay.rangeEnd.value,
    );
    final bool canUseChat = widget.enableChatCalendar;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: _availabilityViewerPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvailabilityViewerHeader(
                title: _availabilityViewerTitle,
                subtitle: _availabilityViewerSubtitle,
                onClose: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: _availabilityViewerSectionSpacing),
              Text(
                rangeLabel,
                style: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: _availabilityViewerSectionSpacing),
              if (canUseChat)
                _AvailabilityViewerSourceToggle(
                  label: _availabilityViewerSourceLabel,
                  selected: _source,
                  onSelected: _handleSourceSelected,
                ),
              if (canUseChat)
                const SizedBox(height: _availabilityViewerSectionSpacing),
              if (widget.onRequest != null)
                Text(
                  _availabilityViewerMutualHint,
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              if (widget.onRequest != null)
                const SizedBox(height: _availabilityViewerHintSpacing),
              Expanded(
                child: _AvailabilityViewerGrid(
                  share: share,
                  source: _source,
                  enableChatCalendar: canUseChat,
                  onRequest: widget.onRequest,
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
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
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
              Text(
                subtitle,
                style: textTheme.small.copyWith(
                  color: context.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailabilityViewerSourceToggle extends StatelessWidget {
  const _AvailabilityViewerSourceToggle({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final _AvailabilityViewerSource selected;
  final ValueChanged<_AvailabilityViewerSource> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: _availabilityViewerSourceSpacing),
        Row(
          children: [
            _AvailabilityViewerSourceButton(
              label: _availabilityViewerPersonalLabel,
              isSelected: selected.isPersonal,
              onPressed: () => onSelected(_AvailabilityViewerSource.personal),
            ),
            const SizedBox(width: _availabilityViewerSourceButtonSpacing),
            _AvailabilityViewerSourceButton(
              label: _availabilityViewerChatLabel,
              isSelected: selected.isChat,
              onPressed: () => onSelected(_AvailabilityViewerSource.chat),
            ),
          ],
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
  });

  final CalendarAvailabilityShare share;
  final _AvailabilityViewerSource source;
  final bool enableChatCalendar;
  final AvailabilityRequestHandler? onRequest;

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
              );
            },
          )
        : BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              return _AvailabilityViewerGridContent(
                share: share,
                model: state.model,
                onRequest: onRequest,
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
  });

  final CalendarAvailabilityShare share;
  final CalendarModel model;
  final AvailabilityRequestHandler? onRequest;

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

String _formatRange(DateTime start, DateTime end) {
  final String startLabel = TimeFormatter.formatFriendlyDateTime(start);
  final String endLabel = TimeFormatter.formatFriendlyDateTime(end);
  if (startLabel == endLabel) {
    return startLabel;
  }
  return '$startLabel$_availabilityViewerRangeSeparator$endLabel';
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
