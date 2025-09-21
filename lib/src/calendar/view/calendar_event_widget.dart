import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/ui/ui.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
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
      childWhenDragging: _buildEventContainer(isGhost: true, interactive: false),
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
                const SizedBox(width: 4),
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
            const SizedBox(height: 2),
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
            const SizedBox(height: 3),
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
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 8,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 2),
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

        // Left resize handle for multi-day events
        if (widget.task.effectiveDaySpan > 1)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 8,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                onHorizontalDragStart: (_) =>
                    _startResize(ResizeDirection.left),
                onHorizontalDragUpdate: (details) =>
                    _updateResize(details, ResizeDirection.left),
                onHorizontalDragEnd: (_) => _endResize(),
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 3,
                      height: 40,
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

        // Right resize handle for multi-day events
        if (widget.task.effectiveDaySpan > 1)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 8,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                onHorizontalDragStart: (_) =>
                    _startResize(ResizeDirection.right),
                onHorizontalDragUpdate: (details) =>
                    _updateResize(details, ResizeDirection.right),
                onHorizontalDragEnd: (_) => _endResize(),
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 3,
                      height: 40,
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
    if (widget.task.isOccurrence) {
      return;
    }
    setState(() {
      _isResizing = true;
      _resizeAccumulatedDelta = 0;
      _resizeStartTime = widget.task.scheduledTime;
      _resizeStartDuration = widget.task.duration ?? const Duration(hours: 1);
    });
    HapticFeedback.selectionClick();
  }

  void _updateResize(dynamic details, ResizeDirection direction) {
    if (!widget.isDayView || widget.task.isOccurrence ||
        _resizeStartTime == null ||
        _resizeStartDuration == null) {
      return;
    }

    const quarterHeight = 15.0; // Height per 15 minutes (60px hour / 4)

    late DateTime newStartTime;
    late Duration newDuration;
    late int newDaySpan;

    switch (direction) {
      case ResizeDirection.top:
        // Accumulate vertical drag
        _resizeAccumulatedDelta += details.delta.dy;

        // Snap to quarter-hour intervals
        final quarterChange = (_resizeAccumulatedDelta / quarterHeight).round();
        final deltaMinutes = quarterChange * 15;

        // Resize from top: adjust start time and duration
        final adjustedStartTime =
            _resizeStartTime!.add(Duration(minutes: deltaMinutes));
        final adjustedDuration = Duration(
          minutes: _resizeStartDuration!.inMinutes - deltaMinutes.toInt(),
        );

        // Constrain to minimum 15 minutes (1 quarter)
        if (adjustedDuration.inMinutes >= 15) {
          newStartTime = adjustedStartTime;
          newDuration = adjustedDuration;
          newDaySpan = widget.task.effectiveDaySpan;
        } else {
          return;
        }
        break;

      case ResizeDirection.bottom:
        // Accumulate vertical drag
        _resizeAccumulatedDelta += details.delta.dy;

        // Snap to quarter-hour intervals
        final quarterChange = (_resizeAccumulatedDelta / quarterHeight).round();
        final deltaMinutes = quarterChange * 15;

        // Resize from bottom: adjust duration only
        final adjustedDuration = Duration(
          minutes: _resizeStartDuration!.inMinutes + deltaMinutes.toInt(),
        );

        // Constrain to minimum 15 minutes and maximum 24 hours
        if (adjustedDuration.inMinutes >= 15 &&
            adjustedDuration.inMinutes <= 1440) {
          newStartTime = _resizeStartTime!;
          newDuration = adjustedDuration;
          newDaySpan = widget.task.effectiveDaySpan;
        } else {
          return;
        }
        break;

      case ResizeDirection.left:
        // Accumulate horizontal drag
        _resizeAccumulatedDelta += details.delta.dx;

        // Horizontal drag for left handle - adjust start date and daySpan
        final deltaDays = -(_resizeAccumulatedDelta / widget.width).round();

        final adjustedStartTime =
            _resizeStartTime!.add(Duration(days: deltaDays));
        final adjustedDaySpan =
            (widget.task.effectiveDaySpan - deltaDays).toInt();

        if (adjustedDaySpan >= 1 && adjustedDaySpan <= 7) {
          newStartTime = adjustedStartTime;
          newDuration = _resizeStartDuration!;
          newDaySpan = adjustedDaySpan;
        } else {
          return;
        }
        break;

      case ResizeDirection.right:
        // Accumulate horizontal drag
        _resizeAccumulatedDelta += details.delta.dx;

        // Horizontal drag for right handle - adjust daySpan only
        final deltaDays = (_resizeAccumulatedDelta / widget.width).round();

        final adjustedDaySpan =
            (widget.task.effectiveDaySpan + deltaDays).toInt();

        // Constrain to maximum 7 days
        final maxSpan = 7 - _resizeStartTime!.weekday + 1;

        if (adjustedDaySpan >= 1 && adjustedDaySpan <= maxSpan) {
          newStartTime = _resizeStartTime!;
          newDuration = _resizeStartDuration!;
          newDaySpan = adjustedDaySpan;
        } else {
          return;
        }
        break;
    }

    // Round to nearest quarter hour for clean snapping
    final roundedMinutes = (newStartTime.minute / 15).round() * 15;
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

    // Store the temporary values for final resize
    _tempStartTime = newStartTime;
    _tempDuration = newDuration;
    _tempDaySpan = newDaySpan;
  }

  DateTime? _tempStartTime;
  Duration? _tempDuration;
  int? _tempDaySpan;

  void _endResize() {
    if (widget.task.isOccurrence) {
      return;
    }
    setState(() => _isResizing = false);

    if (_tempStartTime != null && _tempDuration != null) {
      final startHour = _tempStartTime!.hour + (_tempStartTime!.minute / 60.0);

      context.read<CalendarBloc>().add(
            CalendarEvent.taskResized(
              taskId: widget.task.baseId,
              startHour: startHour,
              duration: _tempDuration!.inMinutes / 60.0,
              daySpan: _tempDaySpan ?? widget.task.effectiveDaySpan,
            ),
          );

      _tempStartTime = null;
      _tempDuration = null;
      _tempDaySpan = null;
    }

    // Clean up tracking variables
    _resizeAccumulatedDelta = 0;
    _resizeStartTime = null;
    _resizeStartDuration = null;
  }
}

enum ResizeDirection {
  top,
  bottom,
  left,
  right,
}
