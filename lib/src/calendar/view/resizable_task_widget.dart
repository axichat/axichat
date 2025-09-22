import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/calendar_task.dart';

class ResizableTaskWidget extends StatefulWidget {
  final CalendarTask task;
  final Function(CalendarTask) onResize;
  final double hourHeight;
  final double quarterHeight;
  final double width;
  final double height;
  final bool isDayView;
  final bool isPopoverOpen;
  final void Function(CalendarTask task, Rect globalBounds)? onTap;
  final VoidCallback? onDragStarted;
  final bool enableInteractions;

  const ResizableTaskWidget({
    super.key,
    required this.task,
    required this.onResize,
    required this.hourHeight,
    required this.quarterHeight,
    required this.width,
    required this.height,
    required this.isDayView,
    this.isPopoverOpen = false,
    this.onTap,
    this.onDragStarted,
    this.enableInteractions = true,
  });

  @override
  State<ResizableTaskWidget> createState() => _ResizableTaskWidgetState();
}

class _ResizableTaskWidgetState extends State<ResizableTaskWidget> {
  bool isHovering = false;
  bool isResizing = false;
  String? activeHandle;

  double _dragStartY = 0;
  double _totalDragDeltaY = 0;

  late double _originalStartHour;
  late double _originalDurationHours;
  DateTime? _tempScheduledTime;
  Duration? _tempDuration;

  Color get _taskColor => widget.task.priorityColor;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final taskColor = _taskColor;

    Widget buildFeedback() {
      return Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: taskColor.withOpacity(0.8),
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
      );
    }

    Widget buildTaskBody() {
      final showHoverEffects = widget.enableInteractions &&
          (widget.isPopoverOpen || isHovering || isResizing);
      final decoration = BoxDecoration(
        color: task.isCompleted
            ? taskColor.withOpacity(0.5)
            : taskColor.withOpacity(isResizing ? 0.7 : 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isResizing
              ? Colors.white.withOpacity(0.5)
              : taskColor.withOpacity(0.3),
          width: isResizing ? 2 : 1,
        ),
        boxShadow: showHoverEffects
            ? const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : const [],
      );

      final double availableHeight =
          (widget.height - 4).clamp(0.0, double.infinity);
      final bool showHandles =
          showHoverEffects && !task.isCompleted && availableHeight >= 14;

      if (availableHeight <= 6) {
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: decoration,
          child: Stack(
            children: [
              if (showHandles) ..._buildResizeHandles(),
            ],
          ),
        );
      }

      final double padding;
      if (availableHeight >= 96) {
        padding = 8;
      } else if (availableHeight >= 72) {
        padding = 6;
      } else if (availableHeight >= 48) {
        padding = 4;
      } else {
        padding = 2;
      }

      final double innerHeight =
          (availableHeight - padding * 2).clamp(0.0, double.infinity);

      if (innerHeight <= 10) {
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: decoration,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        );
      }

      final bool stackedTime = innerHeight >= 36;
      final bool inlineTime =
          !stackedTime && innerHeight >= 16 && widget.width >= 140;
      final bool showTime = stackedTime || inlineTime;
      final bool showDescription =
          task.description?.isNotEmpty == true && innerHeight >= 56;

      final double spacing = innerHeight >= 90
          ? 6
          : innerHeight >= 64
              ? 4
              : innerHeight >= 40
                  ? 2
                  : 0;

      final int titleLines = innerHeight >= 48 ? 2 : 1;
      final int descriptionLines = showDescription
          ? math.max(1, (innerHeight / 18).floor() - (stackedTime ? 1 : 0))
          : 0;
      final TextOverflow descriptionOverflow =
          descriptionLines >= 4 ? TextOverflow.fade : TextOverflow.ellipsis;

      Widget buildTitle() {
        final title = Text(
          task.title,
          maxLines: titleLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        );

        if (showTime && inlineTime) {
          final timeText = task.effectiveDaySpan > 1
              ? '${_formatTimeRange()} (${task.effectiveDaySpan} days)'
              : _formatTimeRange();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.effectiveDaySpan > 1) ...[
                Icon(
                  Icons.calendar_view_week,
                  size: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(child: title),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  timeText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.effectiveDaySpan > 1) ...[
              Icon(
                Icons.calendar_view_week,
                size: 12,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(child: title),
          ],
        );
      }

      final children = <Widget>[buildTitle()];

      if (showTime && !inlineTime) {
        if (spacing > 0) {
          children.add(SizedBox(height: spacing));
        }
        children.add(
          Text(
            task.effectiveDaySpan > 1
                ? '${_formatTimeRange()} (${task.effectiveDaySpan} days)'
                : _formatTimeRange(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }

      if (showDescription) {
        if (spacing > 0) {
          children.add(SizedBox(height: spacing));
        }
        children.add(
          Text(
            task.description!,
            maxLines: descriptionLines,
            overflow: descriptionOverflow,
            softWrap: true,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 10,
              height: 1.2,
            ),
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.all(2),
        decoration: decoration,
        child: Stack(
          children: [
            ClipRect(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
            if (showHandles) ..._buildResizeHandles(),
          ],
        ),
      );
    }

    Widget buildInteractiveContent() {
      return MouseRegion(
        onEnter: (_) {
          if (!widget.isPopoverOpen && widget.enableInteractions) {
            setState(() => isHovering = true);
          }
        },
        onExit: (_) {
          if (!widget.isPopoverOpen && widget.enableInteractions) {
            setState(() => isHovering = false);
          }
        },
        cursor: widget.enableInteractions && isResizing
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
          child: buildTaskBody(),
        ),
      );
    }

    final content = SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.enableInteractions
          ? Draggable<CalendarTask>(
              data: task,
              feedback: buildFeedback(),
              onDragStarted: widget.onDragStarted,
              onDragEnd: (_) {
                if (mounted) {
                  setState(() => isHovering = false);
                }
              },
              childWhenDragging: Container(
                decoration: BoxDecoration(
                  color: taskColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: taskColor, width: 1),
                ),
              ),
              child: buildInteractiveContent(),
            )
          : buildInteractiveContent(),
    );

    return content;
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

    return handles;
  }

  void _startResize(String handleType, DragStartDetails details) {
    if (widget.task.scheduledTime == null) return;

    setState(() {
      isResizing = true;
      activeHandle = handleType;
      _dragStartY = details.localPosition.dy;
      _totalDragDeltaY = 0;

      // Store original values
      final time = widget.task.scheduledTime!;
      _originalStartHour = time.hour + (time.minute / 60.0);
      _originalDurationHours =
          (widget.task.duration ?? const Duration(hours: 1)).inMinutes / 60.0;
      // Clear temporary values
      _tempScheduledTime = null;
      _tempDuration = null;
    });

    HapticFeedback.selectionClick();
  }

  void _updateResize(String handleType, DragUpdateDetails details) {
    if (!isResizing || widget.task.scheduledTime == null) return;

    // Accumulate total drag distance
    _totalDragDeltaY = details.localPosition.dy - _dragStartY;

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

        // Update in real-time
        widget.onResize(widget.task.copyWith(
          duration: _tempDuration,
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
      _tempScheduledTime = null;
      _tempDuration = null;
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
