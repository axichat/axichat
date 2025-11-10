import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/ui/ui.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/time_formatter.dart';

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
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildDraggableEvent(),
          );
        },
      ),
    );
  }

  Widget _buildDraggableEvent() {
    if (widget.task.isOccurrence) {
      return _buildEventContainer(interactive: false);
    }

    return Draggable<CalendarTask>(
      data: widget.task,
      feedback: _buildEventContainer(isDragging: true),
      childWhenDragging:
          _buildEventContainer(isGhost: true, interactive: false),
      onDragStarted: () {
        setState(() => _isDragging = true);
        HapticFeedback.selectionClick();
        context.read<CalendarBloc>().add(
              CalendarEvent.taskDragStarted(taskId: widget.task.baseId),
            );
      },
      onDragEnd: (details) {
        setState(() => _isDragging = false);
      },
      child: _buildEventContainer(),
    );
  }

  Widget _buildEventContainer({
    bool isDragging = false,
    bool isGhost = false,
    bool interactive = true,
  }) {
    return MouseRegion(
      onEnter: (_) {
        if (interactive) {
          _onHoverChanged(true);
        }
      },
      onExit: (_) {
        if (interactive) {
          _onHoverChanged(false);
        }
      },
      cursor: _getMouseCursor(interactive),
      child: GestureDetector(
        onTap: widget.onTap ?? _handleTap,
        child: AnimatedContainer(
          duration: baseAnimationDuration,
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isGhost
                ? _eventColor.withValues(alpha: 0.3)
                : isDragging
                    ? _eventColor.withValues(alpha: 0.9)
                    : _eventColor,
            borderRadius: BorderRadius.circular(6.0),
            boxShadow: isDragging
                ? calendarMediumShadow
                : _isHovering
                    ? calendarLightShadow
                    : calendarCardShadow,
            border: _isHovering && !isDragging
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Stack(
            children: [
              _buildEventContent(),
              if (interactive && _isHovering && !isDragging && widget.isDayView)
                _buildResizeHandles(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventContent() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.height < 40 ? 6.0 : 8.0,
        vertical: widget.height < 40 ? 4.0 : 6.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Priority indicator and title row
          Row(
            children: [
              if (widget.task.effectivePriority != TaskPriority.none) ...[
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
                  widget.task.title,
                  style: TextStyle(
                    fontSize: widget.height < 40 ? 11 : 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    decoration: widget.task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: widget.height < 40 ? 1 : 2,
                ),
              ),
            ],
          ),

          // Time range
          if (widget.height > 32 && _timeRange.isNotEmpty) ...[
            const SizedBox(height: calendarInsetSm),
            Text(
              _timeRange,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],

          // Description
          if (_showDescription) ...[
            const SizedBox(height: calendarTaskDetailGap),
            Expanded(
              child: Text(
                widget.task.description!,
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

          // Location indicator
          if (widget.height > 45 &&
              widget.task.location?.isNotEmpty == true) ...[
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
                    widget.task.location!,
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

  Widget _buildResizeHandles() {
    if (widget.task.isOccurrence) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Top resize handle - at the very edge
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onVerticalDragStart: (_) => _startResize(ResizeDirection.top),
              onVerticalDragUpdate: (details) =>
                  _updateResize(details, ResizeDirection.top),
              onVerticalDragEnd: (_) => _endResize(),
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

        // Bottom resize handle - at the very edge
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onVerticalDragStart: (_) => _startResize(ResizeDirection.bottom),
              onVerticalDragUpdate: (details) =>
                  _updateResize(details, ResizeDirection.bottom),
              onVerticalDragEnd: (_) => _endResize(),
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

enum ResizeDirection {
  top,
  bottom,
  left,
  right,
}
