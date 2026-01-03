// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:collection';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/utils/calendar_free_busy_style.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/layout/calendar_layout.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_render_surface.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

const double _freeBusyGridViewportHeight = 360.0;
const double _freeBusyPreviewViewportHeight = 220.0;
const double _freeBusyTileCornerRadius = 10.0;
const double _freeBusyTileBorderWidth = 1.0;
const double _freeBusyTilePadding = 8.0;
const double _freeBusyTileLabelSpacing = 6.0;
const double _freeBusyTileHandleHeight = 8.0;
const double _freeBusyTileHandleIconSize = 12.0;
const double _freeBusyTileActionSpacing = 6.0;
const double _freeBusyTileSplitIconSize = 16.0;
const double _freeBusyHeaderFontSize = 12.0;
const int _freeBusyDayLabelLength = 3;
const int _freeBusyZoomIndex = 0;
const int _freeBusyMinutesPerStep = 15;
const int _freeBusyStartHour = 0;
const int _freeBusyEndHour = 24;
const Duration _freeBusyDayStep = Duration(days: 1);
const Duration _freeBusyMinimumDuration = calendarMinimumTaskDuration;
const String _freeBusyFreeLabel = 'Free';
const String _freeBusyBusyLabel = 'Busy';

const List<String> _freeBusyDayNames = <String>[
  'SUNDAY',
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
];

class CalendarFreeBusyEditor extends StatefulWidget {
  const CalendarFreeBusyEditor({
    super.key,
    required this.rangeStart,
    required this.rangeEnd,
    required this.intervals,
    required this.onIntervalsChanged,
    this.tzid,
    this.viewportHeight = _freeBusyGridViewportHeight,
    this.isReadOnly = false,
  });

  const CalendarFreeBusyEditor.preview({
    Key? key,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<CalendarFreeBusyInterval> intervals,
    String? tzid,
  }) : this(
          key: key,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          intervals: intervals,
          tzid: tzid,
          onIntervalsChanged: _noopIntervalsChanged,
          viewportHeight: _freeBusyPreviewViewportHeight,
          isReadOnly: true,
        );

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<CalendarFreeBusyInterval> intervals;
  final ValueChanged<List<CalendarFreeBusyInterval>> onIntervalsChanged;
  final String? tzid;
  final double viewportHeight;
  final bool isReadOnly;

  static void _noopIntervalsChanged(List<CalendarFreeBusyInterval> _) {}

  @override
  State<CalendarFreeBusyEditor> createState() => _CalendarFreeBusyEditorState();
}

class _CalendarFreeBusyEditorState extends State<CalendarFreeBusyEditor> {
  final CalendarSurfaceController _surfaceController =
      CalendarSurfaceController();
  final ScrollController _verticalController = ScrollController();
  final CalendarLayoutCalculator _layoutCalculator =
      const CalendarLayoutCalculator();
  final CalendarLayoutTheme _layoutTheme = CalendarLayoutTheme.material;
  late final TaskInteractionController _interactionController =
      TaskInteractionController();
  final Map<_ResizeKey, double> _resizeCarryover =
      HashMap<_ResizeKey, double>();
  List<_FreeBusySegment> _segments = <_FreeBusySegment>[];
  String? _activeSegmentId;

  @override
  void initState() {
    super.initState();
    _segments = _normalizeSegments(
      _segmentsFromIntervals(
        intervals: widget.intervals,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CalendarFreeBusyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool rangeChanged = oldWidget.rangeStart != widget.rangeStart ||
        oldWidget.rangeEnd != widget.rangeEnd;
    if (rangeChanged || oldWidget.intervals != widget.intervals) {
      _segments = _normalizeSegments(
        _segmentsFromIntervals(
          intervals: widget.intervals,
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        ),
      );
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _interactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime rangeStart = widget.rangeStart;
    final DateTime rangeEnd = widget.rangeEnd;
    final List<DateTime> columns = _resolveColumns(rangeStart, rangeEnd);
    if (columns.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _fallbackWidth(columns.length);
        final double timeColumnWidth = _layoutTheme.timeColumnWidth;
        const double minDayWidth = calendarCompactDayColumnWidth;
        final double requiredWidth =
            timeColumnWidth + (minDayWidth * columns.length);
        final double resolvedWidth = math.max(requiredWidth, availableWidth);
        final bool needsHorizontalScroll = resolvedWidth > availableWidth;
        final double dayWidth =
            (resolvedWidth - timeColumnWidth) / columns.length;
        final double viewportHeight = widget.viewportHeight;
        final CalendarLayoutMetrics metrics = _layoutCalculator.resolveMetrics(
          zoomIndex: _freeBusyZoomIndex,
          isDayView: false,
          availableHeight: viewportHeight,
        );
        final double minutesPerPixel =
            metrics.minutesPerSlot / metrics.slotHeight;

        final Widget content = _FreeBusyGridFrame(
          width: resolvedWidth,
          header: _FreeBusyGridHeaderRow(
            dates: columns,
            timeColumnWidth: timeColumnWidth,
            dayWidth: dayWidth,
          ),
          body: _FreeBusyGridSurface(
            width: resolvedWidth,
            height: viewportHeight,
            columns: columns,
            controller: _surfaceController,
            verticalController: _verticalController,
            layoutCalculator: _layoutCalculator,
            layoutTheme: _layoutTheme,
            interactionController: _interactionController,
            tiles: _FreeBusyTileStack(
              columns: columns,
              segments: _segments,
              timeColumnWidth: timeColumnWidth,
              dayWidth: dayWidth,
              metrics: metrics,
              minutesPerPixel: minutesPerPixel,
              isReadOnly: widget.isReadOnly,
              activeId: _activeSegmentId,
              onSelect: _handleSegmentSelected,
              onToggleType: _handleToggleType,
              onSplit: _handleSplitSegment,
              onResize: _handleResizeDelta,
            ),
          ),
        );

        if (!needsHorizontalScroll) {
          return content;
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: resolvedWidth,
            child: content,
          ),
        );
      },
    );
  }

  void _handleSegmentSelected(_FreeBusySegment segment) {
    setState(() {
      _activeSegmentId = segment.id;
    });
  }

  void _handleToggleType(_FreeBusySegment segment) {
    if (widget.isReadOnly) {
      return;
    }
    setState(() {
      segment.type = segment.type.toggled;
      _segments = _mergeAdjacent(_segments);
    });
    _emitIntervals();
  }

  void _handleSplitSegment(_FreeBusySegment segment) {
    if (widget.isReadOnly) {
      return;
    }
    final DateTime start = segment.start;
    final DateTime end = segment.end;
    final Duration span = end.difference(start);
    if (span <= _freeBusyMinimumDuration * 2) {
      return;
    }
    final DateTime midpoint =
        start.add(Duration(minutes: (span.inMinutes / 2).round()));
    final DateTime snapped = _snapToStep(midpoint);
    if (!snapped.isAfter(start.add(_freeBusyMinimumDuration)) ||
        !snapped.isBefore(end.subtract(_freeBusyMinimumDuration))) {
      return;
    }
    setState(() {
      final int index = _segments.indexOf(segment);
      if (index == -1) {
        return;
      }
      _segments
        ..removeAt(index)
        ..insertAll(
          index,
          [
            segment.copyWith(end: snapped),
            segment.copyWith(start: snapped),
          ],
        );
      _segments = _mergeAdjacent(_segments);
    });
    _emitIntervals();
  }

  void _handleResizeDelta(_FreeBusyResizeRequest request) {
    if (widget.isReadOnly) {
      return;
    }
    final _ResizeKey key = _ResizeKey(
      segmentId: request.segment.id,
      direction: request.direction,
    );
    final double updated = (_resizeCarryover[key] ?? 0) + request.deltaMinutes;
    final int stepMinutes = request.minutesPerStep;
    final int steps = (updated / stepMinutes).truncate();
    if (steps == 0) {
      _resizeCarryover[key] = updated;
      return;
    }
    final double remainder = updated - (steps * stepMinutes);
    _resizeCarryover[key] = remainder;
    final int deltaMinutes = steps * stepMinutes;
    _applyResizeDelta(request.segment, request.direction, deltaMinutes);
  }

  void _applyResizeDelta(
    _FreeBusySegment segment,
    _FreeBusyResizeDirection direction,
    int deltaMinutes,
  ) {
    setState(() {
      final int index = _segments.indexOf(segment);
      if (index == -1) {
        return;
      }
      final _FreeBusySegment current = _segments[index];
      final DateTime dayStart = _startOfDay(current.start);
      final DateTime dayEnd = _endOfDay(current.start, widget.rangeEnd);
      if (direction.isTop) {
        final DateTime nextStart =
            current.start.add(Duration(minutes: deltaMinutes));
        final DateTime clampedStart = _clampDateTime(
          nextStart,
          min: dayStart,
          max: current.end.subtract(_freeBusyMinimumDuration),
        );
        if (index > 0) {
          final _FreeBusySegment previous = _segments[index - 1];
          if (_isSameDay(previous.start, current.start)) {
            previous.end = clampedStart;
          }
        }
        current.start = clampedStart;
      } else {
        final DateTime nextEnd =
            current.end.add(Duration(minutes: deltaMinutes));
        final DateTime clampedEnd = _clampDateTime(
          nextEnd,
          min: current.start.add(_freeBusyMinimumDuration),
          max: dayEnd,
        );
        if (index + 1 < _segments.length) {
          final _FreeBusySegment next = _segments[index + 1];
          if (_isSameDay(next.start, current.start)) {
            next.start = clampedEnd;
          }
        }
        current.end = clampedEnd;
      }
      _segments = _mergeAdjacent(_segments);
    });
    _emitIntervals();
  }

  void _emitIntervals() {
    final List<CalendarFreeBusyInterval> intervals = _intervalsFromSegments(
      segments: _segments,
      tzid: widget.tzid,
    );
    widget.onIntervalsChanged(intervals);
  }

  double _fallbackWidth(int columnCount) {
    final double timeColumnWidth = _layoutTheme.timeColumnWidth;
    const double minDayWidth = calendarCompactDayColumnWidth;
    return timeColumnWidth + (minDayWidth * columnCount);
  }
}

class _FreeBusyGridFrame extends StatelessWidget {
  const _FreeBusyGridFrame({
    required this.width,
    required this.header,
    required this.body,
  });

  final double width;
  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(calendarBorderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: calendarBackgroundColor,
          border: Border.all(
            color: calendarBorderColor,
            width: calendarBorderStroke,
          ),
        ),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeBusyGridHeaderRow extends StatelessWidget {
  const _FreeBusyGridHeaderRow({
    required this.dates,
    required this.timeColumnWidth,
    required this.dayWidth,
  });

  final List<DateTime> dates;
  final double timeColumnWidth;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    final BorderSide divider = BorderSide(
      color: calendarBorderDarkColor,
      width: calendarBorderStroke,
    );
    final BorderSide bottom = BorderSide(
      color: calendarBorderColor,
      width: calendarBorderStroke,
    );

    return Container(
      height: calendarWeekHeaderHeight,
      decoration: BoxDecoration(
        color: calendarBackgroundColor,
        border: Border(bottom: bottom),
      ),
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            height: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: calendarBackgroundColor,
                border: Border(right: divider),
              ),
            ),
          ),
          for (final DateTime date in dates)
            SizedBox(
              width: dayWidth,
              height: double.infinity,
              child: _FreeBusyDayHeader(
                date: date,
                showRightDivider: date != dates.last,
              ),
            ),
        ],
      ),
    );
  }
}

class _FreeBusyDayHeader extends StatelessWidget {
  const _FreeBusyDayHeader({
    required this.date,
    required this.showRightDivider,
  });

  final DateTime date;
  final bool showRightDivider;

  @override
  Widget build(BuildContext context) {
    final BorderSide border = BorderSide(
      color: calendarBorderDarkColor,
      width: calendarBorderStroke,
    );
    final bool isToday = _isSameDay(date, DateTime.now());
    final Color background = isToday
        ? calendarPrimaryColor.withValues(alpha: 0.12)
        : calendarBackgroundColor;
    final Color textColor = isToday ? calendarPrimaryColor : calendarTitleColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(right: showRightDivider ? border : BorderSide.none),
      ),
      child: Center(
        child: Text(
          _dayLabel(date),
          style: context.textTheme.small.copyWith(
            fontSize: _freeBusyHeaderFontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _FreeBusyGridSurface extends StatelessWidget {
  const _FreeBusyGridSurface({
    required this.width,
    required this.height,
    required this.columns,
    required this.controller,
    required this.verticalController,
    required this.layoutCalculator,
    required this.layoutTheme,
    required this.interactionController,
    required this.tiles,
  });

  final double width;
  final double height;
  final List<DateTime> columns;
  final CalendarSurfaceController controller;
  final ScrollController verticalController;
  final CalendarLayoutCalculator layoutCalculator;
  final CalendarLayoutTheme layoutTheme;
  final TaskInteractionController interactionController;
  final Widget tiles;

  @override
  Widget build(BuildContext context) {
    final List<CalendarDayColumn> columnSpecs = columns
        .map((date) => CalendarDayColumn(date: date))
        .toList(growable: false);
    final DateTime weekStart = _normalizeDay(columns.first);
    final DateTime weekEnd = _normalizeDay(columns.last);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          SizedBox(
            height: height,
            child: SingleChildScrollView(
              controller: verticalController,
              child: SizedBox(
                width: width,
                child: IgnorePointer(
                  child: CalendarRenderSurface(
                    columns: columnSpecs,
                    startHour: _freeBusyStartHour,
                    endHour: _freeBusyEndHour,
                    zoomIndex: _freeBusyZoomIndex,
                    allowDayViewZoom: false,
                    weekStartDate: weekStart,
                    weekEndDate: weekEnd,
                    layoutCalculator: layoutCalculator,
                    layoutTheme: layoutTheme,
                    controller: controller,
                    verticalScrollController: verticalController,
                    minutesPerStep: _freeBusyMinutesPerStep,
                    interactionController: interactionController,
                    availabilityWindows: const <CalendarAvailabilityWindow>[],
                    availabilityOverlays: const <CalendarAvailabilityOverlay>[],
                    children: const <Widget>[],
                  ),
                ),
              ),
            ),
          ),
          tiles,
        ],
      ),
    );
  }
}

class _FreeBusyTileStack extends StatelessWidget {
  const _FreeBusyTileStack({
    required this.columns,
    required this.segments,
    required this.timeColumnWidth,
    required this.dayWidth,
    required this.metrics,
    required this.minutesPerPixel,
    required this.isReadOnly,
    required this.activeId,
    required this.onSelect,
    required this.onToggleType,
    required this.onSplit,
    required this.onResize,
  });

  final List<DateTime> columns;
  final List<_FreeBusySegment> segments;
  final double timeColumnWidth;
  final double dayWidth;
  final CalendarLayoutMetrics metrics;
  final double minutesPerPixel;
  final bool isReadOnly;
  final String? activeId;
  final ValueChanged<_FreeBusySegment> onSelect;
  final ValueChanged<_FreeBusySegment> onToggleType;
  final ValueChanged<_FreeBusySegment> onSplit;
  final ValueChanged<_FreeBusyResizeRequest> onResize;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = <Widget>[];
    for (final _FreeBusySegment segment in segments) {
      final List<_FreeBusyTileGeometry> geometry = _segmentGeometry(
        segment: segment,
        columns: columns,
        timeColumnWidth: timeColumnWidth,
        dayWidth: dayWidth,
        metrics: metrics,
      );
      for (final _FreeBusyTileGeometry entry in geometry) {
        tiles.add(
          Positioned(
            left: entry.left,
            top: entry.top,
            width: entry.width,
            height: entry.height,
            child: _FreeBusyTile(
              segment: segment,
              isActive: activeId == segment.id,
              minutesPerPixel: minutesPerPixel,
              minutesPerStep: metrics.minutesPerSlot,
              isReadOnly: isReadOnly,
              onSelect: () => onSelect(segment),
              onToggleType: () => onToggleType(segment),
              onSplit: () => onSplit(segment),
              onResize: (request) => onResize(
                request.copyWith(segment: segment),
              ),
            ),
          ),
        );
      }
    }
    return Stack(children: tiles);
  }
}

class _FreeBusyTile extends StatelessWidget {
  const _FreeBusyTile({
    required this.segment,
    required this.isActive,
    required this.minutesPerPixel,
    required this.minutesPerStep,
    required this.isReadOnly,
    required this.onSelect,
    required this.onToggleType,
    required this.onSplit,
    required this.onResize,
  });

  final _FreeBusySegment segment;
  final bool isActive;
  final double minutesPerPixel;
  final int minutesPerStep;
  final bool isReadOnly;
  final VoidCallback onSelect;
  final VoidCallback onToggleType;
  final VoidCallback onSplit;
  final ValueChanged<_FreeBusyResizeRequest> onResize;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = segment.type.baseColor;
    final Color fillColor = baseColor.withValues(alpha: 0.16);
    final Color borderColor = isActive ? baseColor : calendarBorderColor;
    final Color labelColor = baseColor;
    final String label = segment.type.label;
    final String timeRange = _formatTimeRange(segment.start, segment.end);

    return GestureDetector(
      onTap: onSelect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(_freeBusyTileCornerRadius),
          border: Border.all(
            color: borderColor,
            width: _freeBusyTileBorderWidth,
          ),
        ),
        child: Column(
          children: [
            _FreeBusyResizeHandle(
              direction: _FreeBusyResizeDirection.top,
              minutesPerPixel: minutesPerPixel,
              minutesPerStep: minutesPerStep,
              isReadOnly: isReadOnly,
              onResize: onResize,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(_freeBusyTilePadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: context.textTheme.small.copyWith(
                              color: labelColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: _freeBusyTileLabelSpacing),
                          Text(
                            timeRange,
                            style: context.textTheme.small.copyWith(
                              color: calendarSubtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isReadOnly)
                      Column(
                        children: [
                          ShadSwitch(
                            value: segment.type.isFree,
                            onChanged: (_) => onToggleType(),
                          ),
                          const SizedBox(height: _freeBusyTileActionSpacing),
                          AxiIconButton.ghost(
                            iconData: Icons.call_split,
                            tooltip: 'Split segment',
                            onPressed: onSplit,
                            iconSize: _freeBusyTileSplitIconSize,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            _FreeBusyResizeHandle(
              direction: _FreeBusyResizeDirection.bottom,
              minutesPerPixel: minutesPerPixel,
              minutesPerStep: minutesPerStep,
              isReadOnly: isReadOnly,
              onResize: onResize,
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeBusyResizeHandle extends StatelessWidget {
  const _FreeBusyResizeHandle({
    required this.direction,
    required this.minutesPerPixel,
    required this.minutesPerStep,
    required this.isReadOnly,
    required this.onResize,
  });

  final _FreeBusyResizeDirection direction;
  final double minutesPerPixel;
  final int minutesPerStep;
  final bool isReadOnly;
  final ValueChanged<_FreeBusyResizeRequest> onResize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _freeBusyTileHandleHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: isReadOnly
            ? null
            : (details) {
                final double deltaMinutes = details.delta.dy * minutesPerPixel;
                onResize(
                  _FreeBusyResizeRequest(
                    segment: _FreeBusySegment.placeholder(),
                    direction: direction,
                    deltaMinutes: deltaMinutes,
                    minutesPerStep: minutesPerStep,
                  ),
                );
              },
        child: Center(
          child: Icon(
            direction.isTop
                ? LucideIcons.gripHorizontal
                : LucideIcons.gripHorizontal,
            size: _freeBusyTileHandleIconSize,
            color: calendarSubtitleColor,
          ),
        ),
      ),
    );
  }
}

class _FreeBusyResizeRequest {
  const _FreeBusyResizeRequest({
    required this.segment,
    required this.direction,
    required this.deltaMinutes,
    required this.minutesPerStep,
  });

  final _FreeBusySegment segment;
  final _FreeBusyResizeDirection direction;
  final double deltaMinutes;
  final int minutesPerStep;

  _FreeBusyResizeRequest copyWith({
    _FreeBusySegment? segment,
  }) {
    return _FreeBusyResizeRequest(
      segment: segment ?? this.segment,
      direction: direction,
      deltaMinutes: deltaMinutes,
      minutesPerStep: minutesPerStep,
    );
  }
}

enum _FreeBusyResizeDirection {
  top,
  bottom;

  bool get isTop => this == _FreeBusyResizeDirection.top;
  bool get isBottom => this == _FreeBusyResizeDirection.bottom;
}

class _FreeBusyTileGeometry {
  const _FreeBusyTileGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class _FreeBusySegment {
  _FreeBusySegment({
    required this.id,
    required this.start,
    required this.end,
    required this.type,
  });

  factory _FreeBusySegment.placeholder() {
    return _FreeBusySegment(
      id: const Uuid().v4(),
      start: DateTime.now(),
      end: DateTime.now(),
      type: CalendarFreeBusyType.free,
    );
  }

  final String id;
  DateTime start;
  DateTime end;
  CalendarFreeBusyType type;

  _FreeBusySegment copyWith({
    DateTime? start,
    DateTime? end,
    CalendarFreeBusyType? type,
  }) {
    return _FreeBusySegment(
      id: id,
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
    );
  }
}

class _ResizeKey {
  const _ResizeKey({
    required this.segmentId,
    required this.direction,
  });

  final String segmentId;
  final _FreeBusyResizeDirection direction;

  @override
  bool operator ==(Object other) {
    return other is _ResizeKey &&
        other.segmentId == segmentId &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(segmentId, direction);
}

extension _FreeBusyTypeLabelX on CalendarFreeBusyType {
  CalendarFreeBusyType get toggled =>
      isFree ? CalendarFreeBusyType.busy : CalendarFreeBusyType.free;

  String get label => isFree ? _freeBusyFreeLabel : _freeBusyBusyLabel;
}

List<_FreeBusySegment> _segmentsFromIntervals({
  required List<CalendarFreeBusyInterval> intervals,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  if (!rangeEnd.isAfter(rangeStart)) {
    return <_FreeBusySegment>[];
  }
  final List<CalendarFreeBusyInterval> sorted =
      List<CalendarFreeBusyInterval>.from(intervals)
        ..sort((a, b) => a.start.value.compareTo(b.start.value));
  final List<_FreeBusySegment> segments = <_FreeBusySegment>[];
  const Uuid idGenerator = Uuid();
  DateTime cursor = rangeStart;
  if (sorted.isEmpty) {
    return <_FreeBusySegment>[
      _FreeBusySegment(
        id: idGenerator.v4(),
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
        _FreeBusySegment(
          id: idGenerator.v4(),
          start: cursor,
          end: clippedStart,
          type: CalendarFreeBusyType.free,
        ),
      );
    }
    segments.add(
      _FreeBusySegment(
        id: idGenerator.v4(),
        start: clippedStart,
        end: clippedEnd,
        type: _sanitizeType(interval.type),
      ),
    );
    cursor = clippedEnd;
  }
  if (cursor.isBefore(rangeEnd)) {
    segments.add(
      _FreeBusySegment(
        id: idGenerator.v4(),
        start: cursor,
        end: rangeEnd,
        type: CalendarFreeBusyType.free,
      ),
    );
  }
  return _mergeAdjacent(_splitByDay(segments));
}

List<_FreeBusySegment> _normalizeSegments(List<_FreeBusySegment> segments) {
  if (segments.isEmpty) {
    return segments;
  }
  return _mergeAdjacent(_splitByDay(segments));
}

List<_FreeBusySegment> _splitByDay(List<_FreeBusySegment> segments) {
  final List<_FreeBusySegment> result = <_FreeBusySegment>[];
  for (final _FreeBusySegment segment in segments) {
    DateTime start = segment.start;
    final DateTime end = segment.end;
    while (!_isSameDay(start, end) && start.isBefore(end)) {
      final DateTime dayEnd = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(_freeBusyDayStep);
      result.add(
        _FreeBusySegment(
          id: segment.id,
          start: start,
          end: dayEnd,
          type: segment.type,
        ),
      );
      start = dayEnd;
    }
    result.add(
      _FreeBusySegment(
        id: segment.id,
        start: start,
        end: end,
        type: segment.type,
      ),
    );
  }
  return result;
}

List<_FreeBusySegment> _mergeAdjacent(List<_FreeBusySegment> segments) {
  if (segments.isEmpty) {
    return segments;
  }
  final List<_FreeBusySegment> sorted = List<_FreeBusySegment>.from(segments)
    ..sort((a, b) => a.start.compareTo(b.start));
  final List<_FreeBusySegment> merged = <_FreeBusySegment>[];
  for (final _FreeBusySegment segment in sorted) {
    if (merged.isEmpty) {
      merged.add(segment);
      continue;
    }
    final _FreeBusySegment last = merged.last;
    if (last.type == segment.type && last.end.isAtSameMomentAs(segment.start)) {
      last.end = segment.end;
      continue;
    }
    merged.add(segment);
  }
  return merged;
}

List<CalendarFreeBusyInterval> _intervalsFromSegments({
  required List<_FreeBusySegment> segments,
  required String? tzid,
}) {
  if (segments.isEmpty) {
    return const <CalendarFreeBusyInterval>[];
  }
  final List<_FreeBusySegment> merged = _mergeAdjacent(segments);
  return merged
      .map(
        (segment) => CalendarFreeBusyInterval(
          start: CalendarDateTime(value: segment.start, tzid: tzid),
          end: CalendarDateTime(value: segment.end, tzid: tzid),
          type: segment.type,
        ),
      )
      .toList(growable: false);
}

List<_FreeBusyTileGeometry> _segmentGeometry({
  required _FreeBusySegment segment,
  required List<DateTime> columns,
  required double timeColumnWidth,
  required double dayWidth,
  required CalendarLayoutMetrics metrics,
}) {
  final List<_FreeBusyTileGeometry> geometry = <_FreeBusyTileGeometry>[];
  for (var i = 0; i < columns.length; i += 1) {
    final DateTime dayStart = columns[i];
    final DateTime dayEnd = dayStart.add(_freeBusyDayStep);
    if (!segment.end.isAfter(dayStart) || !segment.start.isBefore(dayEnd)) {
      continue;
    }
    final DateTime clippedStart = _maxDateTime(segment.start, dayStart);
    final DateTime clippedEnd = _minDateTime(segment.end, dayEnd);
    final Duration duration = clippedEnd.difference(clippedStart);
    if (duration.inMinutes <= 0) {
      continue;
    }
    final int minutesFromStart = clippedStart.difference(dayStart).inMinutes;
    final double top =
        metrics.verticalOffsetForMinutes(minutesFromStart.toDouble());
    final double height = metrics.heightForDuration(duration);
    final double left = timeColumnWidth + (dayWidth * i);
    geometry.add(
      _FreeBusyTileGeometry(
        left: left,
        top: top,
        width: dayWidth,
        height: height,
      ),
    );
  }
  return geometry;
}

DateTime _normalizeDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

List<DateTime> _resolveColumns(DateTime rangeStart, DateTime rangeEnd) {
  if (rangeEnd.isBefore(rangeStart)) {
    return const <DateTime>[];
  }
  final DateTime start = _normalizeDay(rangeStart);
  final DateTime end = _normalizeDay(rangeEnd);
  final List<DateTime> columns = <DateTime>[];
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    columns.add(cursor);
    cursor = cursor.add(_freeBusyDayStep);
  }
  return columns;
}

String _dayLabel(DateTime date) {
  final int index = date.weekday % _freeBusyDayNames.length;
  final String dayName = _freeBusyDayNames[index];
  final String shortName = dayName.substring(0, _freeBusyDayLabelLength);
  return '$shortName ${date.day}';
}

String _formatTimeRange(DateTime start, DateTime end) {
  return '${TimeFormatter.formatTime(start)} - ${TimeFormatter.formatTime(end)}';
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _endOfDay(DateTime value, DateTime rangeEnd) {
  final DateTime dayEnd =
      DateTime(value.year, value.month, value.day).add(_freeBusyDayStep);
  return dayEnd.isBefore(rangeEnd) ? dayEnd : rangeEnd;
}

DateTime _clampDateTime(
  DateTime value, {
  required DateTime min,
  required DateTime max,
}) {
  if (value.isBefore(min)) {
    return min;
  }
  if (value.isAfter(max)) {
    return max;
  }
  return value;
}

DateTime _snapToStep(DateTime value) {
  const int stepMinutes = _freeBusyMinutesPerStep;
  final int minutes = value.minute;
  final int snapped = (minutes / stepMinutes).round() * stepMinutes;
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    snapped,
  );
}

CalendarFreeBusyType _sanitizeType(CalendarFreeBusyType type) {
  return type.isFree ? CalendarFreeBusyType.free : CalendarFreeBusyType.busy;
}

DateTime _maxDateTime(DateTime first, DateTime second) {
  return first.isAfter(second) ? first : second;
}

DateTime _minDateTime(DateTime first, DateTime second) {
  return first.isBefore(second) ? first : second;
}
