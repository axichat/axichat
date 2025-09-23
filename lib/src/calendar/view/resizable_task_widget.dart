import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/calendar_task.dart';

class ResizableTaskWidget extends StatefulWidget {
  final CalendarTask task;
  final ValueChanged<CalendarTask>? onResizePreview;
  final ValueChanged<CalendarTask>? onResizeEnd;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final ValueChanged<double>? onResizeAutoScroll;
  final double hourHeight;
  final double stepHeight;
  final int minutesPerStep;
  final double width;
  final double height;
  final bool isDayView;
  final bool isPopoverOpen;
  final void Function(CalendarTask task, Rect globalBounds)? onTap;
  final ValueChanged<CalendarTask>? onDragStarted;
  final ValueChanged<CalendarTask>? onDragEnded;
  final bool enableInteractions;

  const ResizableTaskWidget({
    super.key,
    required this.task,
    this.onResizePreview,
    this.onResizeEnd,
    this.onDragUpdate,
    this.onResizeAutoScroll,
    required this.hourHeight,
    required this.stepHeight,
    required this.minutesPerStep,
    required this.width,
    required this.height,
    required this.isDayView,
    this.isPopoverOpen = false,
    this.onTap,
    this.onDragStarted,
    this.onDragEnded,
    this.enableInteractions = true,
  });

  @override
  State<ResizableTaskWidget> createState() => _ResizableTaskWidgetState();
}

class _ResizableTaskWidgetState extends State<ResizableTaskWidget> {
  bool isHovering = false;
  bool isResizing = false;
  bool isDragging = false;
  String? activeHandle;
  double _totalDragDeltaY = 0;
  int _lastAppliedQuarterDelta = 0;

  late double _currentStartHour;
  late double _currentDurationHours;
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
            color: taskColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
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
          (widget.isPopoverOpen || isHovering || isResizing || isDragging);
      final decoration = BoxDecoration(
        color: task.isCompleted
            ? taskColor.withValues(alpha: 0.5)
            : taskColor.withValues(alpha: isResizing ? 0.7 : 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isResizing
              ? Colors.white.withValues(alpha: 0.5)
              : taskColor.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.9),
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
                    color: Colors.white.withValues(alpha: 0.9),
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
                color: Colors.white.withValues(alpha: 0.9),
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
              color: Colors.white.withValues(alpha: 0.9),
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
              color: Colors.white.withValues(alpha: 0.75),
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
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ),
            ),
            if (showHandles) ..._buildResizeHandles(),
          ],
        ),
      );
    }

    Widget buildInteractiveContent() {
      return IgnorePointer(
        ignoring: isDragging,
        child: MouseRegion(
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
              onDragStarted: () {
                widget.onDragStarted?.call(task);
                if (mounted) {
                  setState(() => isDragging = true);
                }
              },
              onDragUpdate: widget.onDragUpdate,
              onDragEnd: (_) {
                if (mounted) {
                  setState(() {
                    isHovering = false;
                    isDragging = false;
                  });
                }
                widget.onDragEnded?.call(task);
              },
              childWhenDragging: const SizedBox.shrink(),
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
                    color: Colors.white.withValues(
                      alpha: isResizing && activeHandle == 'top' ? 0.8 : 0.4,
                    ),
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
                    color: Colors.white.withValues(
                      alpha: isResizing && activeHandle == 'bottom' ? 0.8 : 0.4,
                    ),
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
      _totalDragDeltaY = 0;
      _lastAppliedQuarterDelta = 0;

      // Store original values
      final time = widget.task.scheduledTime!;
      _currentStartHour = time.hour + (time.minute / 60.0);
      _currentDurationHours =
          (widget.task.duration ?? const Duration(hours: 1)).inMinutes / 60.0;
      // Clear temporary values
      _tempScheduledTime = null;
      _tempDuration = null;
    });

    HapticFeedback.selectionClick();
  }

  void _updateResize(String handleType, DragUpdateDetails details) {
    if (!isResizing || widget.task.scheduledTime == null) return;

    widget.onResizeAutoScroll?.call(details.globalPosition.dy);

    // Accumulate total drag distance
    _totalDragDeltaY += details.delta.dy;

    if (handleType == 'top' || handleType == 'bottom') {
      final rawSteps = _totalDragDeltaY / widget.stepHeight;
      final int stepsToApply =
          rawSteps > 0 ? rawSteps.floor() : rawSteps.ceil();
      if (stepsToApply == _lastAppliedQuarterDelta) {
        return;
      }

      final int stepDelta = stepsToApply - _lastAppliedQuarterDelta;
      _lastAppliedQuarterDelta = stepsToApply;

      if (stepDelta == 0) {
        return;
      }

      final minutesPerStep = widget.minutesPerStep;
      final double hoursDelta = (stepDelta * minutesPerStep) / 60.0;
      final double minDurationHours = minutesPerStep / 60.0;

      if (handleType == 'top') {
        final scheduled = widget.task.scheduledTime!;
        final double currentEndHour =
            (_currentStartHour + _currentDurationHours).clamp(0.0, 24.0);

        double newStartHour = (_currentStartHour + hoursDelta)
            .clamp(0.0, currentEndHour - minDurationHours);
        final double newDurationHours = (currentEndHour - newStartHour)
            .clamp(minDurationHours, 24.0 - newStartHour);

        _currentStartHour = newStartHour;
        _currentDurationHours = newDurationHours;

        final int startMinutes = (newStartHour * 60).round();
        final int startHour = startMinutes ~/ 60;
        final int startMinute = startMinutes % 60;

        _tempScheduledTime = DateTime(
          scheduled.year,
          scheduled.month,
          scheduled.day,
          startHour,
          startMinute,
        );
        _tempDuration = Duration(minutes: (newDurationHours * 60).round());

        if (widget.onResizePreview != null) {
          widget.onResizePreview!(
            widget.task.copyWith(
              scheduledTime: _tempScheduledTime,
              duration: _tempDuration,
              startHour: _computeStartHour(_tempScheduledTime),
            ),
          );
        }
      } else if (handleType == 'bottom') {
        final double maxDuration = 24.0 - _currentStartHour;
        final double newDurationHours = (_currentDurationHours + hoursDelta)
            .clamp(minDurationHours, maxDuration);

        _currentDurationHours = newDurationHours;
        _tempScheduledTime = widget.task.scheduledTime;
        _tempDuration = Duration(minutes: (newDurationHours * 60).round());

        if (widget.onResizePreview != null) {
          widget.onResizePreview!(
            widget.task.copyWith(
              duration: _tempDuration,
              startHour: _computeStartHour(_tempScheduledTime),
            ),
          );
        }
      }
    }
  }

  void _endResize() {
    CalendarTask? result;
    if (_tempScheduledTime != null || _tempDuration != null) {
      result = widget.task.copyWith(
        scheduledTime: _tempScheduledTime ?? widget.task.scheduledTime,
        duration: _tempDuration ?? widget.task.duration,
        startHour: _computeStartHour(
          _tempScheduledTime ?? widget.task.scheduledTime,
        ),
      );
    }

    setState(() {
      isResizing = false;
      activeHandle = null;
      _totalDragDeltaY = 0;
      _tempScheduledTime = null;
      _tempDuration = null;
    });

    if (widget.onResizeEnd != null) {
      widget.onResizeEnd!(result ?? widget.task);
    }
  }

  double? _computeStartHour(DateTime? dateTime) {
    if (dateTime == null) return widget.task.startHour;
    return dateTime.hour + (dateTime.minute / 60.0);
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
