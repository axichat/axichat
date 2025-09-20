import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show LayerLink;

import '../models/calendar_task.dart';

class ResizableTaskWidget extends StatefulWidget {
  final CalendarTask task;
  final Function(CalendarTask) onResize;
  final double dayWidth;
  final double hourHeight;
  final double quarterHeight;
  final double width;
  final double height;
  final bool isDayView;
  final void Function(CalendarTask task, Rect globalBounds)? onTap;
  final LayerLink overlayLink;

  const ResizableTaskWidget({
    super.key,
    required this.task,
    required this.onResize,
    required this.dayWidth,
    required this.hourHeight,
    required this.quarterHeight,
    required this.width,
    required this.height,
    required this.isDayView,
    this.onTap,
    required this.overlayLink,
  });

  @override
  State<ResizableTaskWidget> createState() => _ResizableTaskWidgetState();
}

class _ResizableTaskWidgetState extends State<ResizableTaskWidget> {
  bool isHovering = false;
  bool isResizing = false;
  String? activeHandle;

  // Track drag from start position
  double _dragStartY = 0;
  double _dragStartX = 0;
  double _totalDragDeltaY = 0;
  double _totalDragDeltaX = 0;

  // Original values when resize starts
  late double _originalStartHour;
  late double _originalDurationHours;
  late DateTime _originalScheduledTime;
  late DateTime? _originalEndDate;

  // Temporary values during resize
  DateTime? _tempScheduledTime;
  Duration? _tempDuration;
  DateTime? _tempEndDate;

  Color get _taskColor => widget.task.priorityColor;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CompositedTransformTarget(
        link: widget.overlayLink,
        child: Draggable<CalendarTask>(
          data: task,
          feedback: Material(
            elevation: 8,
            color: Colors.transparent,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: _taskColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Text(
                task.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          onDragEnd: (_) {
            // Ensure hover styling resets after drag completes.
            if (mounted) {
              setState(() {
                isHovering = false;
              });
            }
          },
          childWhenDragging: Container(
            decoration: BoxDecoration(
              color: _taskColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _taskColor,
                width: 1,
              ),
            ),
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() => isHovering = true),
            onExit: (_) => setState(() => isHovering = false),
            cursor: isResizing
                ? SystemMouseCursors.resizeUpDown
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final handler = widget.onTap;
                if (handler == null) return;

                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) {
                  handler(task, Rect.zero);
                  return;
                }

                final origin = renderBox.localToGlobal(Offset.zero);
                handler(task, origin & renderBox.size);
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? _taskColor.withOpacity(0.5)
                      : _taskColor.withOpacity(isResizing ? 0.7 : 0.9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isResizing
                        ? Colors.white.withOpacity(0.5)
                        : _taskColor.withOpacity(0.3),
                    width: isResizing ? 2 : 1,
                  ),
                  boxShadow: isHovering || isResizing
                      ? const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : const [],
                ),
                child: Stack(
                  children: [
                    ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  if (task.effectiveDaySpan > 1) ...[
                                    Icon(
                                      Icons.calendar_view_week,
                                      size: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: task.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: widget.height > 40 ? 2 : 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.height > 40) ...[
                              const SizedBox(height: 2),
                              Text(
                                task.effectiveDaySpan > 1
                                    ? '${_formatTimeRange()} (${task.effectiveDaySpan} days)'
                                    : _formatTimeRange(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            if (widget.height > 56 &&
                                task.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                task.description!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 10,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if ((isHovering || isResizing) && !task.isCompleted)
                      ..._buildResizeHandles(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    final handles = <Widget>[
      // Top handle
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 6,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            onPanStart: (details) => _startResize('top', details),
            onPanUpdate: (details) => _updateResize('top', details),
            onPanEnd: (_) => _endResize(),
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                        isResizing && activeHandle == 'top' ? 0.8 : 0.4),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      // Bottom handle
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 6,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            onPanStart: (details) => _startResize('bottom', details),
            onPanUpdate: (details) => _updateResize('bottom', details),
            onPanEnd: (_) => _endResize(),
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                        isResizing && activeHandle == 'bottom' ? 0.8 : 0.4),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];

    // Add horizontal handles for week view (allows extending to multiple days)
    // Show for all tasks in week view, not just multi-day tasks
    if (!widget.isDayView) {
      handles.add(
        // Left handle
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 6,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              onPanStart: (details) => _startResize('left', details),
              onPanUpdate: (details) => _updateResize('left', details),
              onPanEnd: (_) => _endResize(),
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                          isResizing && activeHandle == 'left' ? 0.8 : 0.4),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      handles.add(
        // Right handle
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 6,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              onPanStart: (details) => _startResize('right', details),
              onPanUpdate: (details) => _updateResize('right', details),
              onPanEnd: (_) => _endResize(),
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                          isResizing && activeHandle == 'right' ? 0.8 : 0.4),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return handles;
  }

  void _startResize(String handleType, DragStartDetails details) {
    if (widget.task.scheduledTime == null) return;

    setState(() {
      isResizing = true;
      activeHandle = handleType;
      _dragStartY = details.localPosition.dy;
      _dragStartX = details.localPosition.dx;
      _totalDragDeltaY = 0;
      _totalDragDeltaX = 0;

      // Store original values
      final time = widget.task.scheduledTime!;
      _originalStartHour = time.hour + (time.minute / 60.0);
      _originalDurationHours =
          (widget.task.duration ?? const Duration(hours: 1)).inMinutes / 60.0;
      _originalScheduledTime = time;
      _originalEndDate = widget.task.effectiveEndDate ?? time;

      // Clear temporary values
      _tempScheduledTime = null;
      _tempDuration = null;
      _tempEndDate = null;
    });

    HapticFeedback.selectionClick();
  }

  void _updateResize(String handleType, DragUpdateDetails details) {
    if (!isResizing || widget.task.scheduledTime == null) return;

    // Accumulate total drag distance
    _totalDragDeltaY = details.localPosition.dy - _dragStartY;
    _totalDragDeltaX = details.localPosition.dx - _dragStartX;

    if (handleType == 'top' || handleType == 'bottom') {
      // Calculate quarter-hour changes and snap to discrete cells
      final rawSteps = _totalDragDeltaY / widget.quarterHeight;
      final quartersChanged =
          rawSteps >= 0 ? rawSteps.floor() : rawSteps.ceil();
      if (quartersChanged == 0) {
        return;
      }
      final hoursChanged = quartersChanged * 0.25;

      if (handleType == 'top') {
        // Adjust start time and duration
        final newStartHour =
            (_originalStartHour + hoursChanged).clamp(0.0, 23.75);
        final startDiff = _originalStartHour - newStartHour;
        final newDurationHours = (_originalDurationHours + startDiff)
            .clamp(0.25, 24.0 - newStartHour);

        _tempScheduledTime = DateTime(
          widget.task.scheduledTime!.year,
          widget.task.scheduledTime!.month,
          widget.task.scheduledTime!.day,
          newStartHour.floor(),
          ((newStartHour % 1) * 60).round(),
        );
        _tempDuration = Duration(minutes: (newDurationHours * 60).round());
        _tempEndDate = _originalEndDate;

        // Update in real-time
        widget.onResize(widget.task.copyWith(
          scheduledTime: _tempScheduledTime,
          duration: _tempDuration,
        ));
      } else if (handleType == 'bottom') {
        // Adjust duration only
        final maxDuration = 24.0 - _originalStartHour;
        final newDurationHours =
            (_originalDurationHours + hoursChanged).clamp(0.25, maxDuration);

        _tempScheduledTime = widget.task.scheduledTime;
        _tempDuration = Duration(minutes: (newDurationHours * 60).round());
        _tempEndDate = _originalEndDate;

        // Update in real-time
        widget.onResize(widget.task.copyWith(
          duration: _tempDuration,
        ));
      }
    } else if (handleType == 'left' || handleType == 'right') {
      // Handle horizontal resizing for multi-day events
      // Use independent start/end dates for proper manipulation
      final rawSteps = _totalDragDeltaX / widget.dayWidth;
      final daysChanged = rawSteps >= 0 ? rawSteps.floor() : rawSteps.ceil();

      // Only proceed if there's an actual change
      if (daysChanged == 0) return;

      if (handleType == 'left') {
        // Left handle: move start date, keep end date fixed
        // Dragging left (negative deltaX) = earlier start date
        // Dragging right (positive deltaX) = later start date
        final newStartDate =
            _originalScheduledTime.add(Duration(days: daysChanged));

        // Keep the same time of day for the start
        final newStartDateTime = DateTime(
          newStartDate.year,
          newStartDate.month,
          newStartDate.day,
          _originalScheduledTime.hour,
          _originalScheduledTime.minute,
        );

        // Don't allow start to go past end
        if (_originalEndDate != null &&
            newStartDateTime.isAfter(_originalEndDate!)) {
          return;
        }

        _tempScheduledTime = newStartDateTime;
        _tempDuration = widget.task.duration;
        _tempEndDate = _originalEndDate;

        // Update in real-time
        widget.onResize(widget.task.copyWith(
          scheduledTime: _tempScheduledTime,
          endDate: _tempEndDate,
          daySpan: null, // Clear deprecated field
        ));
      } else if (handleType == 'right') {
        // Right handle: move end date, keep start date fixed
        // Dragging right (positive deltaX) = later end date
        // Dragging left (negative deltaX) = earlier end date
        final originalEnd = _originalEndDate ?? _originalScheduledTime;
        final newEndDate = originalEnd.add(Duration(days: daysChanged));

        // Keep the same time of day for the end
        final newEndDateTime = DateTime(
          newEndDate.year,
          newEndDate.month,
          newEndDate.day,
          originalEnd.hour,
          originalEnd.minute,
        );

        // Don't allow end to go before start
        if (newEndDateTime.isBefore(_originalScheduledTime)) {
          return;
        }

        _tempScheduledTime = _originalScheduledTime;
        _tempDuration = widget.task.duration;
        _tempEndDate = newEndDateTime;

        // Update in real-time
        widget.onResize(widget.task.copyWith(
          scheduledTime: _tempScheduledTime,
          endDate: _tempEndDate,
          daySpan: null, // Clear deprecated field
        ));
      }
    }
  }

  void _endResize() {
    // Final update is already done in _updateResize, just clean up state
    setState(() {
      isResizing = false;
      activeHandle = null;
      _totalDragDeltaY = 0;
      _totalDragDeltaX = 0;
      _tempScheduledTime = null;
      _tempDuration = null;
      _tempEndDate = null;
    });
  }

  String _formatTimeRange() {
    if (widget.task.scheduledTime == null) return '';

    final startTime = widget.task.scheduledTime!;
    final duration = widget.task.duration ?? const Duration(hours: 1);
    final endTime = startTime.add(duration);

    String formatTime(DateTime time) {
      final hour = time.hour;
      final min = time.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0
          ? 12
          : hour > 12
              ? hour - 12
              : hour;
      return '$displayHour:${min.toString().padLeft(2, '0')} $period';
    }

    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }
}
