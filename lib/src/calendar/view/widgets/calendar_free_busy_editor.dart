// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/layout/calendar_layout.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_render_surface.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/calendar/view/resizable_task_widget.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

const double _freeBusyGridViewportHeight = 360.0;
const double _freeBusyPreviewViewportHeight = 220.0;
const double _freeBusyTileSplitIconSize = 16.0;
const double _freeBusyTileOverlayPadding = 6.0;
const double _freeBusyTileOverlayGap = 6.0;
const double _freeBusyTileControlMinHeight = 40.0;
const double _freeBusySwitchScale = 0.9;
const double _freeBusyHeaderFontSize = 12.0;
const double _freeBusyTapSlop = 4.0;
const double _freeBusyResizeHandleExtent = 8.0;
const double _freeBusySheetSpacing = 16.0;
const double _freeBusySheetGap = 8.0;
const double _freeBusySheetActionSpacing = 8.0;
const double _freeBusySheetLabelLetterSpacing = 0.4;
const double _freeBusySheetActionPaddingHorizontal = 12.0;
const double _freeBusySheetActionPaddingVertical = 10.0;
const double _freeBusySheetActionCornerRadius = 12.0;
const int _freeBusyDayLabelLength = 3;
const int _freeBusyZoomIndex = 0;
const int _freeBusyMinutesPerStep = 15;
const int _freeBusyStartHour = 0;
const int _freeBusyEndHour = 24;
const Duration _freeBusyDayStep = Duration(days: 1);
const Duration _freeBusyMinimumDuration = calendarMinimumTaskDuration;
const String _freeBusyFreeLabel = 'Free';
const String _freeBusyBusyLabel = 'Busy';
const String _freeBusyMutualLabel = 'Mutual';
const String _freeBusyEditTitle = 'Edit availability';
const String _freeBusyEditSubtitle = 'Adjust the time range and status.';
const String _freeBusyToggleLabel = 'Free/Busy';
const String _freeBusySplitLabel = 'Split';
const String _freeBusySplitTooltip = 'Split segment';
const String _freeBusyToggleToFreeLabel = 'Mark free';
const String _freeBusyToggleToBusyLabel = 'Mark busy';
const String _freeBusyRangeLabel = 'Range';
const Uuid _freeBusySegmentIdGenerator = Uuid();

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
    this.onIntervalTapped,
  });

  const CalendarFreeBusyEditor.preview({
    Key? key,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<CalendarFreeBusyInterval> intervals,
    String? tzid,
    ValueChanged<CalendarFreeBusyInterval>? onIntervalTapped,
  }) : this(
          key: key,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          intervals: intervals,
          tzid: tzid,
          onIntervalsChanged: _noopIntervalsChanged,
          viewportHeight: _freeBusyPreviewViewportHeight,
          isReadOnly: true,
          onIntervalTapped: onIntervalTapped,
        );

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<CalendarFreeBusyInterval> intervals;
  final ValueChanged<List<CalendarFreeBusyInterval>> onIntervalsChanged;
  final String? tzid;
  final double viewportHeight;
  final bool isReadOnly;
  final ValueChanged<CalendarFreeBusyInterval>? onIntervalTapped;

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
  final ShadPopoverController _contextMenuController = ShadPopoverController();
  final ValueKey<String> _contextMenuGroupId =
      const ValueKey<String>('free-busy-context-menu');
  List<_FreeBusySegment> _segments = <_FreeBusySegment>[];
  String? _activeSegmentId;
  int? _activePointerId;
  Offset? _pointerDownLocal;
  bool _pointerDownPrimary = false;
  bool _tapCandidate = false;
  bool _suppressInsert = false;

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
    _contextMenuController.dispose();
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
        const double headerHeight = calendarWeekHeaderHeight;
        final double bodyHeight = math.max(0, viewportHeight - headerHeight);
        final CalendarLayoutMetrics metrics = _layoutCalculator.resolveMetrics(
          zoomIndex: _freeBusyZoomIndex,
          isDayView: false,
          availableHeight: bodyHeight,
        );

        final double contentHeight = _contentHeightForMetrics(metrics);
        final Widget content = _FreeBusyGridFrame(
          width: resolvedWidth,
          header: _FreeBusyGridHeaderRow(
            dates: columns,
            timeColumnWidth: timeColumnWidth,
            dayWidth: dayWidth,
          ),
          body: _FreeBusyGridSurface(
            width: resolvedWidth,
            height: bodyHeight,
            contentHeight: contentHeight,
            columns: columns,
            controller: _surfaceController,
            verticalController: _verticalController,
            layoutCalculator: _layoutCalculator,
            layoutTheme: _layoutTheme,
            interactionController: _interactionController,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: (event) => _handlePointerUp(
              event,
              timeColumnWidth: timeColumnWidth,
              dayWidth: dayWidth,
              columns: columns,
              metrics: metrics,
            ),
            onPointerCancel: _handlePointerCancel,
            tiles: _FreeBusyTileStack(
              columns: columns,
              segments: _segments,
              timeColumnWidth: timeColumnWidth,
              dayWidth: dayWidth,
              metrics: metrics,
              interactionController: _interactionController,
              isReadOnly: widget.isReadOnly,
              activeId: _activeSegmentId,
              onSelect: _handleSegmentSelected,
              onToggleType: _handleToggleType,
              onSplit: _handleSplitSegment,
              onResizePreview: _handleResizePreview,
              onResizeEnd: _handleResizeCommit,
              onSuppressInsert: _markInsertSuppressed,
              contextMenuController: _contextMenuController,
              contextMenuGroupId: _contextMenuGroupId,
              contextMenuBuilderFactory: _contextMenuBuilderFor,
              enableContextMenuLongPress: !_shouldUseEditSheet(),
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
    if (widget.isReadOnly) {
      widget.onIntervalTapped?.call(segment.toInterval(widget.tzid));
      return;
    }
    final bool useSheet = _shouldUseEditSheet();
    if (useSheet) {
      _openEditSheet(segment);
    }
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
      segment.modifiedAt = DateTime.now();
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
      final DateTime now = DateTime.now();
      final _FreeBusySegment left = _FreeBusySegment(
        id: _freeBusySegmentIdGenerator.v4(),
        start: segment.start,
        end: snapped,
        type: segment.type,
        createdAt: now,
        modifiedAt: now,
      );
      final _FreeBusySegment right = _FreeBusySegment(
        id: _freeBusySegmentIdGenerator.v4(),
        start: snapped,
        end: segment.end,
        type: segment.type,
        createdAt: now,
        modifiedAt: now,
      );
      _segments
        ..removeAt(index)
        ..insertAll(
          index,
          [left, right],
        );
      _segments = _mergeAdjacent(_segments);
    });
    _emitIntervals();
  }

  void _handleSplitSegmentAt(
    _FreeBusySegment segment,
    DateTime splitTime,
  ) {
    if (widget.isReadOnly) {
      return;
    }
    final DateTime start = segment.start;
    final DateTime end = segment.end;
    final Duration span = end.difference(start);
    if (span <= _freeBusyMinimumDuration * 2) {
      return;
    }
    DateTime snapped = _snapToStep(splitTime);
    snapped = _clampDateTime(
      snapped,
      min: start.add(_freeBusyMinimumDuration),
      max: end.subtract(_freeBusyMinimumDuration),
    );
    if (!snapped.isAfter(start) || !snapped.isBefore(end)) {
      return;
    }
    setState(() {
      final int index = _segments.indexOf(segment);
      if (index == -1) {
        return;
      }
      final DateTime now = DateTime.now();
      final _FreeBusySegment left = _FreeBusySegment(
        id: _freeBusySegmentIdGenerator.v4(),
        start: segment.start,
        end: snapped,
        type: segment.type,
        createdAt: now,
        modifiedAt: now,
      );
      final _FreeBusySegment right = _FreeBusySegment(
        id: _freeBusySegmentIdGenerator.v4(),
        start: snapped,
        end: segment.end,
        type: segment.type,
        createdAt: now,
        modifiedAt: now,
      );
      _segments
        ..removeAt(index)
        ..insertAll(
          index,
          [left, right],
        );
      _segments = _mergeAdjacent(_segments);
    });
    _emitIntervals();
  }

  void _handleResizePreview(CalendarTask task) {
    if (widget.isReadOnly) {
      return;
    }
    _applyTaskResize(task, emit: false);
  }

  void _handleResizeCommit(CalendarTask task) {
    if (widget.isReadOnly) {
      return;
    }
    _applyTaskResize(task, emit: true);
  }

  void _applyTaskResize(
    CalendarTask task, {
    required bool emit,
  }) {
    final int index = _segmentIndexFor(task.id);
    if (index == -1) {
      return;
    }
    final _FreeBusySegment current = _segments[index];
    final DateTime start = task.scheduledTime ?? current.start;
    final Duration duration = task.duration ?? _freeBusyMinimumDuration;
    final DateTime end = start.add(duration);
    final DateTime dayStart = _startOfDay(current.start);
    final DateTime dayEnd = _endOfDay(current.start, widget.rangeEnd);
    final bool startChanged = !start.isAtSameMomentAs(current.start);
    final bool endChanged = !end.isAtSameMomentAs(current.end);

    setState(() {
      if (startChanged) {
        final DateTime clampedStart = _clampDateTime(
          start,
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
      }
      if (endChanged) {
        final DateTime clampedEnd = _clampDateTime(
          end,
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
      current.modifiedAt = DateTime.now();
      _segments = _mergeAdjacent(_segments);
    });
    if (emit) {
      _emitIntervals();
    }
  }

  void _updateSegmentRange(
    _FreeBusySegment segment, {
    required DateTime start,
    required DateTime end,
  }) {
    if (widget.isReadOnly) {
      return;
    }
    if (!end.isAfter(start)) {
      return;
    }
    final DateTime dayStart = _startOfDay(segment.start);
    final DateTime dayEnd = _endOfDay(segment.start, widget.rangeEnd);
    final DateTime clampedStart = _clampDateTime(
      start,
      min: dayStart,
      max: end.subtract(_freeBusyMinimumDuration),
    );
    final DateTime clampedEnd = _clampDateTime(
      end,
      min: clampedStart.add(_freeBusyMinimumDuration),
      max: dayEnd,
    );
    setState(() {
      final int index = _segments.indexOf(segment);
      if (index == -1) {
        return;
      }
      if (index > 0) {
        final _FreeBusySegment previous = _segments[index - 1];
        if (_isSameDay(previous.start, segment.start)) {
          previous.end = clampedStart;
        }
      }
      if (index + 1 < _segments.length) {
        final _FreeBusySegment next = _segments[index + 1];
        if (_isSameDay(next.start, segment.start)) {
          next.start = clampedEnd;
        }
      }
      segment.start = clampedStart;
      segment.end = clampedEnd;
      segment.modifiedAt = DateTime.now();
      _segments = _mergeAdjacent(_segments);
    });
    _emitIntervals();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.isReadOnly) {
      return;
    }
    _suppressInsert = false;
    _activePointerId = event.pointer;
    _pointerDownLocal = event.localPosition;
    _pointerDownPrimary = _isPrimaryPointer(event);
    _tapCandidate = _pointerDownPrimary;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_tapCandidate || event.pointer != _activePointerId) {
      return;
    }
    final Offset? down = _pointerDownLocal;
    if (down == null) {
      return;
    }
    if ((event.localPosition - down).distance > _freeBusyTapSlop) {
      _tapCandidate = false;
    }
  }

  void _handlePointerUp(
    PointerUpEvent event, {
    required double timeColumnWidth,
    required double dayWidth,
    required List<DateTime> columns,
    required CalendarLayoutMetrics metrics,
  }) {
    final bool shouldInsert = _tapCandidate &&
        _pointerDownPrimary &&
        event.pointer == _activePointerId &&
        _interactionController.activeResizeInteraction == null &&
        !_suppressInsert;
    _resetPointerState();
    _suppressInsert = false;
    if (!shouldInsert) {
      return;
    }
    final DateTime? slot = _slotForLocalPosition(
      event.localPosition,
      timeColumnWidth: timeColumnWidth,
      dayWidth: dayWidth,
      columns: columns,
      metrics: metrics,
    );
    if (slot == null) {
      return;
    }
    _insertSegmentAt(slot);
  }

  void _handlePointerCancel() {
    _resetPointerState();
    _suppressInsert = false;
  }

  void _resetPointerState() {
    _activePointerId = null;
    _pointerDownLocal = null;
    _pointerDownPrimary = false;
    _tapCandidate = false;
  }

  void _markInsertSuppressed() {
    _suppressInsert = true;
  }

  int _segmentIndexFor(String id) {
    return _segments.indexWhere((segment) => segment.id == id);
  }

  _FreeBusySegment? _segmentAt(DateTime target) {
    for (final _FreeBusySegment segment in _segments) {
      if (!target.isBefore(segment.start) && target.isBefore(segment.end)) {
        return segment;
      }
    }
    return null;
  }

  DateTime? _slotForLocalPosition(
    Offset localPosition, {
    required double timeColumnWidth,
    required double dayWidth,
    required List<DateTime> columns,
    required CalendarLayoutMetrics metrics,
  }) {
    final double x = localPosition.dx;
    if (x <= timeColumnWidth) {
      return null;
    }
    final int columnIndex = ((x - timeColumnWidth) / dayWidth).floor();
    if (columnIndex < 0 || columnIndex >= columns.length) {
      return null;
    }
    final DateTime dayStart = columns[columnIndex];
    final double scrollOffset = _verticalController.hasClients
        ? _verticalController.position.pixels
        : 0;
    final double y = localPosition.dy + scrollOffset;
    final double minutesFromStart =
        (y / metrics.slotHeight) * metrics.minutesPerSlot;
    final int snappedMinutes =
        (minutesFromStart / _freeBusyMinutesPerStep).round() *
            _freeBusyMinutesPerStep;
    final DateTime base = DateTime(dayStart.year, dayStart.month, dayStart.day);
    final DateTime slot = base.add(Duration(minutes: snappedMinutes));
    final DateTime rangeStart = widget.rangeStart;
    final DateTime rangeEnd = widget.rangeEnd;
    final DateTime dayEnd = _endOfDay(dayStart, rangeEnd);
    final DateTime maxStart = dayEnd.subtract(_freeBusyMinimumDuration);
    return _clampDateTime(slot, min: rangeStart, max: maxStart);
  }

  void _insertSegmentAt(DateTime slot) {
    if (widget.isReadOnly) {
      return;
    }
    final _FreeBusySegment? target = _segmentAt(slot);
    if (target == null) {
      return;
    }
    final DateTime start = target.start;
    final DateTime end = target.end;
    final Duration span = end.difference(start);
    if (span <= _freeBusyMinimumDuration) {
      _handleToggleType(target);
      return;
    }
    DateTime insertStart = _snapToStep(slot);
    insertStart = _clampDateTime(
      insertStart,
      min: start,
      max: end.subtract(_freeBusyMinimumDuration),
    );
    DateTime insertEnd = insertStart.add(_freeBusyMinimumDuration);
    if (insertStart.isBefore(start.add(_freeBusyMinimumDuration))) {
      insertStart = start;
      insertEnd = start.add(_freeBusyMinimumDuration);
    }
    if (insertEnd.isAfter(end.subtract(_freeBusyMinimumDuration))) {
      insertEnd = end;
      insertStart = end.subtract(_freeBusyMinimumDuration);
    }
    final DateTime now = DateTime.now();
    final _FreeBusySegment inserted = _FreeBusySegment(
      id: _freeBusySegmentIdGenerator.v4(),
      start: insertStart,
      end: insertEnd,
      type: target.type.toggled,
      createdAt: now,
      modifiedAt: now,
    );
    final List<_FreeBusySegment> next = <_FreeBusySegment>[];
    if (insertStart.isAfter(start)) {
      next.add(
        _FreeBusySegment(
          id: _freeBusySegmentIdGenerator.v4(),
          start: start,
          end: insertStart,
          type: target.type,
          createdAt: now,
          modifiedAt: now,
        ),
      );
    }
    next.add(inserted);
    if (insertEnd.isBefore(end)) {
      next.add(
        _FreeBusySegment(
          id: _freeBusySegmentIdGenerator.v4(),
          start: insertEnd,
          end: end,
          type: target.type,
          createdAt: now,
          modifiedAt: now,
        ),
      );
    }
    setState(() {
      final int index = _segments.indexOf(target);
      if (index == -1) {
        return;
      }
      _segments
        ..removeAt(index)
        ..insertAll(index, next);
      _segments = _mergeAdjacent(_segments);
      _activeSegmentId = inserted.id;
    });
    _emitIntervals();
  }

  bool _isPrimaryPointer(PointerDownEvent event) {
    final bool primaryPressed = (event.buttons & kPrimaryButton) != 0;
    if (primaryPressed) {
      return true;
    }
    if (event.buttons != 0) {
      return false;
    }
    final PointerDeviceKind kind = event.kind;
    if (kind == PointerDeviceKind.mouse || kind == PointerDeviceKind.trackpad) {
      return false;
    }
    return true;
  }

  void _emitIntervals() {
    final List<CalendarFreeBusyInterval> intervals = _intervalsFromSegments(
      segments: _segments,
      tzid: widget.tzid,
    );
    widget.onIntervalsChanged(intervals);
  }

  bool _shouldUseEditSheet() {
    final bool isDesktop = ResponsiveHelper.isDesktop(context);
    final bool hasMouse =
        RendererBinding.instance.mouseTracker.mouseIsConnected;
    return !isDesktop || !hasMouse;
  }

  TaskContextMenuBuilder? _contextMenuBuilderFor(
    _FreeBusySegment segment,
  ) {
    if (widget.isReadOnly || _shouldUseEditSheet()) {
      return null;
    }
    return (context, request) {
      final String toggleLabel = segment.type.isFree
          ? _freeBusyToggleToBusyLabel
          : _freeBusyToggleToFreeLabel;
      final List<Widget> items = [
        ShadContextMenuItem(
          leading: const Icon(Icons.swap_horiz),
          onPressed: () {
            request.markCloseIntent();
            _contextMenuController.hide();
            _handleToggleType(segment);
          },
          child: Text(toggleLabel),
        ),
      ];
      final DateTime? splitTime = request.splitTime;
      if (splitTime != null) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(Icons.call_split),
            onPressed: () {
              request.markCloseIntent();
              _contextMenuController.hide();
              _handleSplitSegmentAt(segment, splitTime);
            },
            child: Text(
              'Split at ${TimeFormatter.formatTime(splitTime)}',
            ),
          ),
        );
      }
      return items;
    };
  }

  Future<void> _openEditSheet(_FreeBusySegment segment) async {
    await showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _FreeBusyEditSheet(
        segment: segment,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
        onToggle: () => _handleToggleType(segment),
        onSplit: () => _handleSplitSegment(segment),
        onRangeChanged: (start, end) =>
            _updateSegmentRange(segment, start: start, end: end),
      ),
    );
  }

  double _fallbackWidth(int columnCount) {
    final double timeColumnWidth = _layoutTheme.timeColumnWidth;
    const double minDayWidth = calendarCompactDayColumnWidth;
    return timeColumnWidth + (minDayWidth * columnCount);
  }

  double _contentHeightForMetrics(CalendarLayoutMetrics metrics) {
    final int totalSlots = _layoutTheme.visibleHourRows * metrics.slotsPerHour;
    return metrics.slotHeight * totalSlots;
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
    required this.contentHeight,
    required this.columns,
    required this.controller,
    required this.verticalController,
    required this.layoutCalculator,
    required this.layoutTheme,
    required this.interactionController,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.tiles,
  });

  final double width;
  final double height;
  final double contentHeight;
  final List<DateTime> columns;
  final CalendarSurfaceController controller;
  final ScrollController verticalController;
  final CalendarLayoutCalculator layoutCalculator;
  final CalendarLayoutTheme layoutTheme;
  final TaskInteractionController interactionController;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerUpEvent> onPointerUp;
  final VoidCallback onPointerCancel;
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
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: onPointerDown,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        onPointerCancel: (_) => onPointerCancel(),
        child: Stack(
          children: [
            SizedBox(
              height: height,
              child: SingleChildScrollView(
                controller: verticalController,
                child: SizedBox(
                  width: width,
                  height: contentHeight,
                  child: Stack(
                    children: [
                      IgnorePointer(
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
                      Positioned.fill(child: tiles),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
    required this.interactionController,
    required this.isReadOnly,
    required this.activeId,
    required this.onSelect,
    required this.onToggleType,
    required this.onSplit,
    required this.onResizePreview,
    required this.onResizeEnd,
    required this.onSuppressInsert,
    required this.contextMenuController,
    required this.contextMenuGroupId,
    required this.contextMenuBuilderFactory,
    required this.enableContextMenuLongPress,
  });

  final List<DateTime> columns;
  final List<_FreeBusySegment> segments;
  final double timeColumnWidth;
  final double dayWidth;
  final CalendarLayoutMetrics metrics;
  final TaskInteractionController interactionController;
  final bool isReadOnly;
  final String? activeId;
  final ValueChanged<_FreeBusySegment> onSelect;
  final ValueChanged<_FreeBusySegment> onToggleType;
  final ValueChanged<_FreeBusySegment> onSplit;
  final ValueChanged<CalendarTask> onResizePreview;
  final ValueChanged<CalendarTask> onResizeEnd;
  final VoidCallback onSuppressInsert;
  final ShadPopoverController contextMenuController;
  final ValueKey<String> contextMenuGroupId;
  final TaskContextMenuBuilder? Function(_FreeBusySegment segment)
      contextMenuBuilderFactory;
  final bool enableContextMenuLongPress;

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
            child: _FreeBusyTaskTile(
              segment: segment,
              isActive: activeId == segment.id,
              interactionController: interactionController,
              minutesPerStep: metrics.minutesPerSlot,
              stepHeight: metrics.slotHeight,
              hourHeight: metrics.hourHeight,
              width: entry.width,
              height: entry.height,
              isReadOnly: isReadOnly,
              contextMenuController: contextMenuController,
              contextMenuGroupId: contextMenuGroupId,
              contextMenuBuilder: contextMenuBuilderFactory(segment),
              enableContextMenuLongPress: enableContextMenuLongPress,
              onSelect: () => onSelect(segment),
              onToggleType: () => onToggleType(segment),
              onSplit: () => onSplit(segment),
              onResizePreview: onResizePreview,
              onResizeEnd: onResizeEnd,
              onSuppressInsert: onSuppressInsert,
            ),
          ),
        );
      }
    }
    return Stack(children: tiles);
  }
}

class _FreeBusyTaskTile extends StatelessWidget {
  const _FreeBusyTaskTile({
    required this.segment,
    required this.isActive,
    required this.interactionController,
    required this.minutesPerStep,
    required this.stepHeight,
    required this.hourHeight,
    required this.width,
    required this.height,
    required this.isReadOnly,
    required this.onSelect,
    required this.onToggleType,
    required this.onSplit,
    required this.onResizePreview,
    required this.onResizeEnd,
    required this.onSuppressInsert,
    required this.contextMenuController,
    required this.contextMenuGroupId,
    required this.contextMenuBuilder,
    required this.enableContextMenuLongPress,
  });

  final _FreeBusySegment segment;
  final bool isActive;
  final TaskInteractionController interactionController;
  final int minutesPerStep;
  final double stepHeight;
  final double hourHeight;
  final double width;
  final double height;
  final bool isReadOnly;
  final VoidCallback onSelect;
  final VoidCallback onToggleType;
  final VoidCallback onSplit;
  final ValueChanged<CalendarTask> onResizePreview;
  final ValueChanged<CalendarTask> onResizeEnd;
  final VoidCallback onSuppressInsert;
  final ShadPopoverController contextMenuController;
  final ValueKey<String> contextMenuGroupId;
  final TaskContextMenuBuilder? contextMenuBuilder;
  final bool enableContextMenuLongPress;

  @override
  Widget build(BuildContext context) {
    final CalendarTask task = segment.asTask;
    final Color accentColor = segment.type.tileColor;
    final bool showControls =
        !isReadOnly && height >= _freeBusyTileControlMinHeight;
    final Widget? overlay = showControls
        ? _FreeBusyTileControls(
            isFree: segment.type.isFree,
            onToggle: onToggleType,
            onSplit: onSplit,
            onSuppressInsert: onSuppressInsert,
          )
        : null;
    final Widget tile = ResizableTaskWidget(
      interactionController: interactionController,
      task: task,
      onResizePreview: isReadOnly ? null : onResizePreview,
      onResizeEnd: isReadOnly ? null : onResizeEnd,
      hourHeight: hourHeight,
      stepHeight: stepHeight,
      minutesPerStep: minutesPerStep,
      width: width,
      height: height,
      isDayView: false,
      enableInteractions: !isReadOnly,
      isSelectionMode: false,
      isSelected: isActive,
      onTap: (_, __) => onSelect(),
      contextMenuController: isReadOnly ? null : contextMenuController,
      contextMenuGroupId: isReadOnly ? null : contextMenuGroupId,
      contextMenuBuilder: isReadOnly ? null : contextMenuBuilder,
      onDragPointerDown: null,
      onResizePointerMove: null,
      contextMenuLongPressEnabled:
          isReadOnly ? false : enableContextMenuLongPress,
      resizeHandleExtent: _freeBusyResizeHandleExtent,
      accentColorOverride: accentColor,
      overlay: overlay,
    );

    return tile;
  }
}

class _FreeBusyTileControls extends StatelessWidget {
  const _FreeBusyTileControls({
    required this.isFree,
    required this.onToggle,
    required this.onSplit,
    required this.onSuppressInsert,
  });

  final bool isFree;
  final VoidCallback onToggle;
  final VoidCallback onSplit;
  final VoidCallback onSuppressInsert;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onSuppressInsert(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: calendarContainerColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: calendarBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_freeBusyTileOverlayPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: _freeBusySwitchScale,
                child: ShadSwitch(
                  value: isFree,
                  onChanged: (_) => onToggle(),
                ),
              ),
              const SizedBox(width: _freeBusyTileOverlayGap),
              AxiIconButton.ghost(
                iconData: Icons.call_split,
                tooltip: _freeBusySplitTooltip,
                onPressed: onSplit,
                iconSize: _freeBusyTileSplitIconSize,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    required this.createdAt,
    required this.modifiedAt,
  });

  final String id;
  DateTime start;
  DateTime end;
  CalendarFreeBusyType type;
  DateTime createdAt;
  DateTime modifiedAt;
}

extension _FreeBusyTypeLabelX on CalendarFreeBusyType {
  CalendarFreeBusyType get toggled =>
      isFree ? CalendarFreeBusyType.busy : CalendarFreeBusyType.free;

  String get label => switch (this) {
        CalendarFreeBusyType.free => _freeBusyFreeLabel,
        CalendarFreeBusyType.busy => _freeBusyBusyLabel,
        CalendarFreeBusyType.busyUnavailable => _freeBusyBusyLabel,
        CalendarFreeBusyType.busyTentative => _freeBusyMutualLabel,
      };

  Color get tileColor => switch (this) {
        CalendarFreeBusyType.free => calendarSuccessColor,
        CalendarFreeBusyType.busy => calendarDangerColor,
        CalendarFreeBusyType.busyUnavailable => calendarDangerColor,
        CalendarFreeBusyType.busyTentative => calendarPrimaryColor,
      };
}

extension _FreeBusySegmentTaskX on _FreeBusySegment {
  CalendarTask get asTask {
    return CalendarTask(
      id: id,
      title: type.label,
      scheduledTime: start,
      duration: end.difference(start),
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      endDate: end,
    );
  }

  CalendarFreeBusyInterval toInterval(String? tzid) {
    return CalendarFreeBusyInterval(
      start: CalendarDateTime(value: start, tzid: tzid),
      end: CalendarDateTime(value: end, tzid: tzid),
      type: type,
    );
  }
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
  final DateTime now = DateTime.now();
  DateTime cursor = rangeStart;
  if (sorted.isEmpty) {
    return <_FreeBusySegment>[
      _FreeBusySegment(
        id: _freeBusySegmentIdGenerator.v4(),
        start: rangeStart,
        end: rangeEnd,
        type: CalendarFreeBusyType.free,
        createdAt: now,
        modifiedAt: now,
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
          id: _freeBusySegmentIdGenerator.v4(),
          start: cursor,
          end: clippedStart,
          type: CalendarFreeBusyType.free,
          createdAt: now,
          modifiedAt: now,
        ),
      );
    }
    segments.add(
      _FreeBusySegment(
        id: _freeBusySegmentIdGenerator.v4(),
        start: clippedStart,
        end: clippedEnd,
        type: _sanitizeType(interval.type),
        createdAt: now,
        modifiedAt: now,
      ),
    );
    cursor = clippedEnd;
  }
  if (cursor.isBefore(rangeEnd)) {
    segments.add(
      _FreeBusySegment(
        id: _freeBusySegmentIdGenerator.v4(),
        start: cursor,
        end: rangeEnd,
        type: CalendarFreeBusyType.free,
        createdAt: now,
        modifiedAt: now,
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
          id: _freeBusySegmentIdGenerator.v4(),
          start: start,
          end: dayEnd,
          type: segment.type,
          createdAt: segment.createdAt,
          modifiedAt: segment.modifiedAt,
        ),
      );
      start = dayEnd;
    }
    result.add(
      _FreeBusySegment(
        id: _freeBusySegmentIdGenerator.v4(),
        start: start,
        end: end,
        type: segment.type,
        createdAt: segment.createdAt,
        modifiedAt: segment.modifiedAt,
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
    if (!segment.end.isAfter(segment.start)) {
      continue;
    }
    if (merged.isEmpty) {
      merged.add(segment);
      continue;
    }
    final _FreeBusySegment last = merged.last;
    if (last.type == segment.type && last.end.isAtSameMomentAs(segment.start)) {
      last.end = segment.end;
      last.modifiedAt = DateTime.now();
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

class _FreeBusyEditSheet extends StatefulWidget {
  const _FreeBusyEditSheet({
    required this.segment,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onToggle,
    required this.onSplit,
    required this.onRangeChanged,
  });

  final _FreeBusySegment segment;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final VoidCallback onToggle;
  final VoidCallback onSplit;
  final void Function(DateTime start, DateTime end) onRangeChanged;

  @override
  State<_FreeBusyEditSheet> createState() => _FreeBusyEditSheetState();
}

class _FreeBusyEditSheetState extends State<_FreeBusyEditSheet> {
  late DateTime? _start;
  late DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.segment.start;
    _end = widget.segment.end;
  }

  @override
  Widget build(BuildContext context) {
    final header = AxiSheetHeader(
      title: const Text(_freeBusyEditTitle),
      subtitle: const Text(_freeBusyEditSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      children: [
        _FreeBusySheetActions(
          isFree: widget.segment.type.isFree,
          onToggle: widget.onToggle,
          onSplit: widget.onSplit,
        ),
        const SizedBox(height: _freeBusySheetSpacing),
        const _FreeBusySheetSectionLabel(text: _freeBusyRangeLabel),
        ScheduleRangeFields(
          start: _start,
          end: _end,
          onStartChanged: _handleStartChanged,
          onEndChanged: _handleEndChanged,
          minDate: _startOfDay(widget.segment.start),
          maxDate: _endOfDay(widget.segment.start, widget.rangeEnd),
        ),
      ],
    );
  }

  void _handleStartChanged(DateTime? value) {
    setState(() {
      _start = value;
      final DateTime? start = _start;
      final DateTime? end = _end;
      if (start != null && end != null && !end.isAfter(start)) {
        _end = _clampDateTime(
          start.add(_freeBusyMinimumDuration),
          min: start.add(_freeBusyMinimumDuration),
          max: _endOfDay(widget.segment.start, widget.rangeEnd),
        );
      }
    });
    _emitRange();
  }

  void _handleEndChanged(DateTime? value) {
    setState(() {
      _end = value;
    });
    _emitRange();
  }

  void _emitRange() {
    final DateTime? start = _start;
    final DateTime? end = _end;
    if (start == null || end == null || !end.isAfter(start)) {
      return;
    }
    widget.onRangeChanged(start, end);
  }
}

class _FreeBusySheetActions extends StatelessWidget {
  const _FreeBusySheetActions({
    required this.isFree,
    required this.onToggle,
    required this.onSplit,
  });

  final bool isFree;
  final VoidCallback onToggle;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colorScheme.card,
              borderRadius:
                  BorderRadius.circular(_freeBusySheetActionCornerRadius),
              border: Border.all(color: context.colorScheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _freeBusySheetActionPaddingHorizontal,
                vertical: _freeBusySheetActionPaddingVertical,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _freeBusyToggleLabel,
                    style: context.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.mutedForeground,
                    ),
                  ),
                  ShadSwitch(
                    value: isFree,
                    onChanged: (_) => onToggle(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: _freeBusySheetActionSpacing),
        ShadButton.outline(
          size: ShadButtonSize.sm,
          onPressed: onSplit,
          child: const Text(_freeBusySplitLabel),
        ),
      ],
    );
  }
}

class _FreeBusySheetSectionLabel extends StatelessWidget {
  const _FreeBusySheetSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _freeBusySheetGap),
      child: Text(
        text,
        style: context.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.mutedForeground,
          letterSpacing: _freeBusySheetLabelLetterSpacing,
        ),
      ),
    );
  }
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
  if (type == CalendarFreeBusyType.busyTentative) {
    return CalendarFreeBusyType.busyTentative;
  }
  return type.isFree ? CalendarFreeBusyType.free : CalendarFreeBusyType.busy;
}

DateTime _maxDateTime(DateTime first, DateTime second) {
  return first.isAfter(second) ? first : second;
}

DateTime _minDateTime(DateTime first, DateTime second) {
  return first.isBefore(second) ? first : second;
}
