import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'widgets/task_checklist.dart';

class CalendarEventWidget extends StatefulWidget {
  final CalendarTask task;
  final double width;
  final double height;
  final double topOffset;
  final double leftOffset;
  final bool isDayView;
  final int overlapCount;
  final int overlapIndex;
  final VoidCallback? onTap;
  final VoidCallback? onEditRequested;

  const CalendarEventWidget({
    super.key,
    required this.task,
    required this.width,
    required this.height,
    required this.topOffset,
    required this.leftOffset,
    required this.isDayView,
    this.overlapCount = 1,
    this.overlapIndex = 0,
    this.onTap,
    this.onEditRequested,
  });

  @override
  State<CalendarEventWidget> createState() => _CalendarEventWidgetState();
}

typedef _EventContainerBuilder = Widget Function({
  bool isDragging,
  bool isGhost,
  bool interactive,
});

class _CalendarEventWidgetState extends State<CalendarEventWidget>
    with TickerProviderStateMixin {
  bool _isHovering = false;
  bool _isDragging = false;
  bool _isResizing = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Resize tracking
  double _resizeAccumulatedDelta = 0;
  DateTime? _resizeStartTime;
  Duration? _resizeStartDuration;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color get _priorityColor => widget.task.priorityColor;

  Color get _eventColor {
    if (widget.task.isCompleted) {
      return _priorityColor.withValues(alpha: 0.85);
    }
    return _priorityColor;
  }

  String get _timeRange {
    if (widget.task.scheduledTime == null) return '';

    final startTime = widget.task.scheduledTime!;
    final duration = widget.task.duration ?? const Duration(hours: 1);
    final endTime = startTime.add(duration);

    return '${TimeFormatter.formatTime(startTime)} - ${TimeFormatter.formatTime(endTime)}';
  }

  double get _adjustedWidth {
    if (widget.overlapCount > 1) {
      return (widget.width - 4.0) / widget.overlapCount - 2.0;
    }
    return widget.width - 8.0;
  }

  double get _adjustedLeftOffset {
    final baseOffset = widget.leftOffset + 4.0;
    if (widget.overlapCount > 1) {
      final slotWidth = (widget.width - 4.0) / widget.overlapCount;
      return baseOffset + (widget.overlapIndex * slotWidth);
    }
    return baseOffset;
  }

  bool get _showDescription =>
      widget.height > 50 && widget.task.description?.isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topOffset,
      left: _adjustedLeftOffset,
      width: _adjustedWidth,
      height: widget.height.clamp(32, double.infinity),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          Widget containerBuilder({
            bool isDragging = false,
            bool isGhost = false,
            bool interactive = true,
          }) {
            return _CalendarEventContainer(
              task: widget.task,
              eventColor: _eventColor,
              isDragging: isDragging,
              isGhost: isGhost,
              interactive: interactive,
              isHovering: _isHovering,
              isDayView: widget.isDayView,
              showDescription: _showDescription,
              height: widget.height,
              timeRange: _timeRange,
              cursor: _getMouseCursor(interactive),
              onHoverChanged: _onHoverChanged,
              onTap: widget.onTap ?? _handleTap,
              onResizeStart: _startResize,
              onResizeUpdate: _updateResize,
              onResizeEnd: _endResize,
            );
          }

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: _CalendarEventDraggable(
              task: widget.task,
              canInteract: !widget.task.isOccurrence,
              onDragStart: () {
                setState(() => _isDragging = true);
                HapticFeedback.selectionClick();
                context.read<CalendarBloc>().add(
                      CalendarEvent.taskDragStarted(
                        taskId: widget.task.baseId,
                      ),
                    );
              },
              onDragEnd: (details) {
                setState(() => _isDragging = false);
              },
              builder: containerBuilder,
            ),
          );
        },
      ),
    );
  }

  SystemMouseCursor _getMouseCursor(bool interactive) {
    if (!interactive) return SystemMouseCursors.basic;
    if (_isResizing) return SystemMouseCursors.resizeUpDown;
    if (_isHovering && !_isDragging) return SystemMouseCursors.click;
    return SystemMouseCursors.grab;
  }

  void _onHoverChanged(bool hovering) {
    if (mounted && hovering != _isHovering) {
      setState(() => _isHovering = hovering);
      if (hovering) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onEditRequested?.call();
    // TODO: Show edit dropdown
  }

  void _startResize(ResizeDirection direction) {
    if (widget.task.isOccurrence || widget.task.scheduledTime == null) {
      return;
    }
    final DateTime startTime = widget.task.scheduledTime!;
    final Duration baseDuration = widget.task.duration ??
        (widget.task.effectiveEndDate != null
            ? widget.task.effectiveEndDate!.difference(startTime)
            : const Duration(hours: 1));
    final Duration normalizedDuration =
        baseDuration.inMinutes <= 0 ? const Duration(hours: 1) : baseDuration;
    setState(() {
      _isResizing = true;
      _resizeAccumulatedDelta = 0;
      _resizeStartTime = startTime;
      _resizeStartDuration = normalizedDuration;
      _resizeStartEnd =
          widget.task.effectiveEndDate ?? startTime.add(normalizedDuration);
    });
    HapticFeedback.selectionClick();
  }

  void _updateResize(dynamic details, ResizeDirection direction) {
    if (!widget.isDayView ||
        widget.task.isOccurrence ||
        _resizeStartTime == null ||
        _resizeStartDuration == null) {
      return;
    }

    const double quarterHeight = 15.0; // Height per 15 minutes

    if (direction == ResizeDirection.left ||
        direction == ResizeDirection.right) {
      _resizeAccumulatedDelta += details.delta.dx;
    } else {
      _resizeAccumulatedDelta += details.delta.dy;
    }

    DateTime newStartTime = _resizeStartTime!;
    Duration newDuration = _resizeStartDuration!;
    final DateTime? initialEnd = _resizeStartEnd;

    switch (direction) {
      case ResizeDirection.top:
        final int quarterChange =
            (_resizeAccumulatedDelta / quarterHeight).round();
        final int deltaMinutes = quarterChange * 15;
        final Duration candidateDuration =
            _resizeStartDuration! - Duration(minutes: deltaMinutes);
        if (candidateDuration.inMinutes >= 15) {
          newStartTime = _resizeStartTime!.add(Duration(minutes: deltaMinutes));
          newDuration = candidateDuration;
        } else {
          return;
        }
        break;
      case ResizeDirection.bottom:
        final int quarterChange =
            (_resizeAccumulatedDelta / quarterHeight).round();
        final int deltaMinutes = quarterChange * 15;
        final Duration candidateDuration =
            _resizeStartDuration! + Duration(minutes: deltaMinutes);
        if (candidateDuration.inMinutes >= 15 &&
            candidateDuration.inMinutes <= const Duration(days: 7).inMinutes) {
          newStartTime = _resizeStartTime!;
          newDuration = candidateDuration;
        } else {
          return;
        }
        break;
      case ResizeDirection.left:
        final int deltaDays = (-_resizeAccumulatedDelta / widget.width).round();
        if (deltaDays != 0) {
          final DateTime candidateStart =
              _resizeStartTime!.add(Duration(days: deltaDays));
          final DateTime? end = initialEnd;
          if (end != null && candidateStart.isBefore(end)) {
            newStartTime = candidateStart;
            newDuration = end.difference(candidateStart);
          } else {
            return;
          }
        }
        break;
      case ResizeDirection.right:
        final int deltaDays = (_resizeAccumulatedDelta / widget.width).round();
        final DateTime? end = initialEnd;
        if (end != null) {
          final DateTime candidateEnd = end.add(Duration(days: deltaDays));
          if (candidateEnd.isAfter(_resizeStartTime!)) {
            newStartTime = _resizeStartTime!;
            newDuration = candidateEnd.difference(_resizeStartTime!);
          } else {
            return;
          }
        } else {
          final Duration candidateDuration =
              _resizeStartDuration! + Duration(days: deltaDays);
          if (candidateDuration.inMinutes >= 15) {
            newStartTime = _resizeStartTime!;
            newDuration = candidateDuration;
          } else {
            return;
          }
        }
        break;
    }

    if (newDuration.inMinutes > const Duration(days: 7).inMinutes) {
      newDuration = const Duration(days: 7);
      if (initialEnd != null && direction == ResizeDirection.left) {
        newStartTime = initialEnd.subtract(newDuration);
      }
    }

    final int roundedMinutes = (newStartTime.minute / 15).round() * 15;
    newStartTime = DateTime(
      newStartTime.year,
      newStartTime.month,
      newStartTime.day,
      newStartTime.hour,
      roundedMinutes % 60,
    );
    if (roundedMinutes >= 60) {
      newStartTime = newStartTime.add(const Duration(hours: 1));
    }

    if (initialEnd != null) {
      newDuration = initialEnd.difference(newStartTime);
    }

    if (newDuration.inMinutes < 15) {
      return;
    }

    DateTime? endDate;
    if (initialEnd != null || widget.task.endDate != null) {
      endDate = newStartTime.add(newDuration);
    } else if (widget.task.duration != null) {
      endDate = newStartTime.add(newDuration);
    }

    _tempStartTime = newStartTime;
    _tempDuration = newDuration;
    _tempEndDate = endDate;
  }

  DateTime? _tempStartTime;
  Duration? _tempDuration;
  DateTime? _tempEndDate;
  DateTime? _resizeStartEnd;

  void _endResize() {
    if (widget.task.isOccurrence) {
      return;
    }
    setState(() => _isResizing = false);

    if (_tempStartTime != null && _tempDuration != null) {
      final bloc = context.read<CalendarBloc>();
      final CalendarState currentState = bloc.state;
      String targetId = widget.task.id;
      CalendarTask? targetTask = currentState.model.tasks[targetId];
      if (targetTask == null) {
        final String baseId = widget.task.baseId;
        targetTask = currentState.model.tasks[baseId];
        if (targetTask != null) {
          targetId = baseId;
        }
      }

      bloc.add(
        CalendarEvent.taskResized(
          taskId: targetId,
          scheduledTime: _tempStartTime,
          duration: _tempDuration,
          endDate: _tempEndDate,
        ),
      );

      _tempStartTime = null;
      _tempDuration = null;
      _tempEndDate = null;
    }

    // Clean up tracking variables
    _resizeAccumulatedDelta = 0;
    _resizeStartTime = null;
    _resizeStartDuration = null;
    _resizeStartEnd = null;
  }
}

class _CalendarEventDraggable extends StatelessWidget {
  const _CalendarEventDraggable({
    required this.task,
    required this.canInteract,
    required this.onDragStart,
    required this.onDragEnd,
    required this.builder,
  });

  final CalendarTask task;
  final bool canInteract;
  final VoidCallback onDragStart;
  final void Function(DraggableDetails details) onDragEnd;
  final _EventContainerBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (!canInteract) {
      return builder(interactive: false);
    }
    return Draggable<CalendarTask>(
      data: task,
      feedback: builder(isDragging: true),
      childWhenDragging: builder(isGhost: true, interactive: false),
      onDragStarted: onDragStart,
      onDragEnd: onDragEnd,
      child: builder(),
    );
  }
}

class _CalendarEventContainer extends StatelessWidget {
  const _CalendarEventContainer({
    required this.task,
    required this.eventColor,
    required this.isDragging,
    required this.isGhost,
    required this.interactive,
    required this.isHovering,
    required this.isDayView,
    required this.showDescription,
    required this.height,
    required this.timeRange,
    required this.cursor,
    required this.onTap,
    required this.onHoverChanged,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final CalendarTask task;
  final Color eventColor;
  final bool isDragging;
  final bool isGhost;
  final bool interactive;
  final bool isHovering;
  final bool isDayView;
  final bool showDescription;
  final double height;
  final String timeRange;
  final MouseCursor cursor;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;
  final void Function(ResizeDirection direction) onResizeStart;
  final void Function(DragUpdateDetails details, ResizeDirection direction)
      onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (interactive) {
          onHoverChanged(true);
        }
      },
      onExit: (_) {
        if (interactive) {
          onHoverChanged(false);
        }
      },
      cursor: cursor,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: baseAnimationDuration,
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isGhost
                ? eventColor.withValues(alpha: 0.3)
                : isDragging
                    ? eventColor.withValues(alpha: 0.9)
                    : eventColor,
            borderRadius: BorderRadius.circular(6.0),
            boxShadow: isDragging
                ? calendarMediumShadow
                : isHovering
                    ? calendarLightShadow
                    : calendarCardShadow,
            border: isHovering && !isDragging
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Stack(
            children: [
              _CalendarEventContent(
                task: task,
                height: height,
                showDescription: showDescription,
                timeRange: timeRange,
              ),
              if (interactive && isHovering && !isDragging && isDayView)
                _CalendarEventResizeHandles(
                  onResizeStart: onResizeStart,
                  onResizeUpdate: onResizeUpdate,
                  onResizeEnd: onResizeEnd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarEventContent extends StatelessWidget {
  const _CalendarEventContent({
    required this.task,
    required this.height,
    required this.showDescription,
    required this.timeRange,
  });

  final CalendarTask task;
  final double height;
  final bool showDescription;
  final String timeRange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: height < 40 ? 6.0 : 8.0,
        vertical: height < 40 ? 4.0 : 6.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (task.effectivePriority != TaskPriority.none) ...[
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: calendarInsetMd),
              ],
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: height < 40 ? 11 : 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: height < 40 ? 1 : 2,
                ),
              ),
            ],
          ),
          if (height > 32 && timeRange.isNotEmpty) ...[
            const SizedBox(height: calendarInsetSm),
            Text(
              timeRange,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (showDescription && task.description != null) ...[
            const SizedBox(height: calendarTaskDetailGap),
            Expanded(
              child: Text(
                task.description!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ),
          ],
          if (task.hasChecklist && height > 32) ...[
            const SizedBox(height: calendarInsetSm),
            TaskChecklistProgressBar(
              progress: task.checklistProgress,
              activeColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
            ),
          ],
          if (height > 45 && task.location?.isNotEmpty == true) ...[
            const SizedBox(height: calendarInsetSm),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 8,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: calendarInsetSm),
                Expanded(
                  child: Text(
                    task.location!,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarEventResizeHandles extends StatelessWidget {
  const _CalendarEventResizeHandles({
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final void Function(ResizeDirection direction) onResizeStart;
  final void Function(DragUpdateDetails details, ResizeDirection direction)
      onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onVerticalDragStart: (_) => onResizeStart(ResizeDirection.top),
              onVerticalDragUpdate: (details) =>
                  onResizeUpdate(details, ResizeDirection.top),
              onVerticalDragEnd: (_) => onResizeEnd(),
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onVerticalDragStart: (_) => onResizeStart(ResizeDirection.bottom),
              onVerticalDragUpdate: (details) =>
                  onResizeUpdate(details, ResizeDirection.bottom),
              onVerticalDragEnd: (_) => onResizeEnd(),
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum ResizeDirection {
  top,
  bottom,
  left,
  right,
}
