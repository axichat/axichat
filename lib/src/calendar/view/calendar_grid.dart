import 'package:flutter/material.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';

class OverlapInfo {
  final int columnIndex;
  final int totalColumns;

  const OverlapInfo({
    required this.columnIndex,
    required this.totalColumns,
  });
}

enum _ResizeDirection { top, bottom }

class _ResizeHandle extends StatefulWidget {
  final CalendarTask task;
  final _ResizeDirection direction;
  final Function(CalendarTask, DateTime, Duration) onResize;

  const _ResizeHandle({
    required this.task,
    required this.direction,
    required this.onResize,
  });

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onPanStart: (details) => setState(() => _isDragging = true),
        onPanUpdate: _handlePanUpdate,
        onPanEnd: (details) => setState(() => _isDragging = false),
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            color: (_isHovering || _isDragging)
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.task.scheduledTime == null) return;

    final originalTime = widget.task.scheduledTime!;
    final originalDuration = widget.task.duration ?? const Duration(hours: 1);

    // Calculate time delta based on drag distance (roughly 15 minutes per 20 pixels)
    final deltaMinutes = (details.delta.dy / 20 * 15).round();
    final timeDelta = Duration(minutes: deltaMinutes);

    late DateTime newTime;
    late Duration newDuration;

    if (widget.direction == _ResizeDirection.top) {
      // Resizing from top: adjust start time and duration
      newTime = originalTime.add(timeDelta);
      final newDurationMinutes =
          originalDuration.inMinutes - timeDelta.inMinutes;
      newDuration =
          Duration(minutes: newDurationMinutes.clamp(15, 1440)); // Max 24 hours

      // Adjust start time if duration was clamped
      if (newDurationMinutes < 15) {
        newTime =
            originalTime.add(originalDuration - const Duration(minutes: 15));
      }
    } else {
      // Resizing from bottom: adjust duration only
      newTime = originalTime;
      final newDurationMinutes =
          originalDuration.inMinutes + timeDelta.inMinutes;
      newDuration =
          Duration(minutes: newDurationMinutes.clamp(15, 1440)); // Max 24 hours
    }

    widget.onResize(widget.task, newTime, newDuration);
  }
}

class CalendarGrid extends StatefulWidget {
  final CalendarState state;
  final Function(CalendarTask, Offset)? onTaskTapped;
  final Function(DateTime, Offset)? onEmptySlotTapped;
  final Function(CalendarTask, DateTime)? onTaskDragEnd;
  final void Function(DateTime date) onDateSelected;
  final void Function(CalendarView view) onViewChanged;

  const CalendarGrid({
    super.key,
    required this.state,
    this.onTaskTapped,
    this.onEmptySlotTapped,
    this.onTaskDragEnd,
    required this.onDateSelected,
    required this.onViewChanged,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid>
    with TickerProviderStateMixin {
  static const int startHour = 0;
  static const int endHour = 24;
  late AnimationController _viewTransitionController;
  late Animation<double> _viewTransitionAnimation;

  // Track hovered cell for hover effects
  String? _hoveredCellKey;

  @override
  void initState() {
    super.initState();
    _viewTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _viewTransitionAnimation = CurvedAnimation(
      parent: _viewTransitionController,
      curve: Curves.easeInOut,
    );
    _viewTransitionController.value = 1.0; // Start fully visible
  }

  @override
  void dispose() {
    _viewTransitionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect view mode changes and animate transitions
    if (oldWidget.state.viewMode != widget.state.viewMode) {
      _viewTransitionController.reset();
      _viewTransitionController.forward();
    }
  }

  double _getHourHeight(BuildContext context, bool compact) {
    if (compact) return 36.0;
    return ResponsiveHelper.isMobile(context) ? 40.0 : 48.0;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.layoutBuilder(
      context,
      mobile: _buildMobileGrid(),
      tablet: _buildTabletGrid(),
      desktop: _buildDesktopGrid(),
    );
  }

  Widget _buildMobileGrid() {
    return _buildWeekView(compact: true);
  }

  Widget _buildTabletGrid() {
    return _buildWeekView(compact: false);
  }

  Widget _buildDesktopGrid() {
    return _buildWeekView(compact: false);
  }

  Widget _buildWeekView({required bool compact}) {
    final weekDates = _getWeekDates(widget.state.selectedDate);
    final isWeekView = widget.state.viewMode == CalendarView.week;

    // In day view, show only the selected day; in week view, show all 7 days
    final headerDates = isWeekView ? weekDates : [widget.state.selectedDate];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius
            .zero, // Remove rounded corners for sharp 90-degree edges
      ),
      child: Column(
        children: [
          _buildDayHeaders(headerDates, compact),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xfffafbfc),
                borderRadius: BorderRadius.zero, // Remove rounded corners
              ),
              child: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: _viewTransitionAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _viewTransitionAnimation,
                      child: _buildGridContent(isWeekView, weekDates, compact),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent(
      bool isWeekView, List<DateTime> weekDates, bool compact) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isWeekView && isMobile) {
      // Mobile week view: horizontal scroll for day columns
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeColumn(compact),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: weekDates.map((date) {
                  return SizedBox(
                    width: 120, // Fixed width for mobile day columns
                    child: _buildDayColumn(date, compact),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    } else if (isWeekView) {
      // Desktop/tablet week view: equal width columns
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeColumn(compact),
          ...weekDates.map((date) => Expanded(
                child: _buildDayColumn(date, compact),
              )),
        ],
      );
    } else {
      // Day view: single column
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeColumn(compact),
          Expanded(
            child: _buildDayColumn(widget.state.selectedDate, compact,
                isDayView: true),
          ),
        ],
      );
    }
  }

  Widget _buildDayHeaders(List<DateTime> weekDates, bool compact) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
        borderRadius: BorderRadius.zero, // Remove rounded corners
      ),
      child: Row(
        children: [
          SizedBox(
            width:
                compact ? 50 : 90, // Updated from 70px to 90px to match target
            child: const SizedBox(), // Empty space for time column
          ),
          ...weekDates.asMap().entries.map((entry) {
            final index = entry.key;
            final date = entry.value;
            return Expanded(
              child: _buildDayHeader(date, compact, isFirst: index == 0),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(bool compact) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: calendarSelectedDayColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: calendarBorderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggleViewMode(CalendarView.week),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 4 : 6,
                    vertical: compact ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.state.viewMode == CalendarView.week
                        ? const Color(0xff007AFF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.view_week,
                    color: widget.state.viewMode == CalendarView.week
                        ? Colors.white
                        : calendarTimeLabelColor,
                    size: compact ? 12 : 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggleViewMode(CalendarView.day),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 4 : 6,
                    vertical: compact ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.state.viewMode == CalendarView.day
                        ? const Color(0xff007AFF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.view_day,
                    color: widget.state.viewMode == CalendarView.day
                        ? Colors.white
                        : calendarTimeLabelColor,
                    size: compact ? 12 : 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(DateTime date, bool compact, {bool isFirst = false}) {
    final isToday = _isToday(date);
    final isSelected = _isSameDay(date, widget.state.selectedDate) &&
        widget.state.viewMode == CalendarView.day;

    return InkWell(
      onTap: () => _selectDateAndSwitchToDay(date),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: isFirst
                ? const BorderSide(color: calendarBorderColor, width: 0.5)
                : BorderSide.none,
            right: const BorderSide(color: calendarBorderColor, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _getDayName(date.weekday, false).substring(0, 3).toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  color: calendarTimeLabelColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xff0969DA) // Use target blue color
                    : isToday
                        ? const Color(0xff0969DA)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected || isToday ? Colors.white : calendarTitleColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn(bool compact) {
    final isDayView = widget.state.viewMode == CalendarView.day;
    final hourHeight = _getHourHeight(context, compact);
    final slotHeight =
        isDayView ? hourHeight / 4 : hourHeight; // 15-minute slots in day view
    final totalSlots =
        isDayView ? (endHour - startHour + 1) * 4 : (endHour - startHour + 1);

    return Container(
      width: compact ? 50 : 90, // Updated from 70px to 90px to match target
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: calendarBorderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: List.generate(totalSlots, (index) {
          if (isDayView) {
            // Day view: 15-minute slots
            final totalMinutes = (startHour * 60) + (index * 15);
            final hour = totalMinutes ~/ 60;
            final minute = totalMinutes % 60;
            final isCurrentTime = _isCurrentTimeSlot(hour, minute);
            final showLabel = minute == 0; // Only show label on the hour

            return Container(
              height: slotHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  top: BorderSide(
                    color: minute == 0
                        ? calendarBorderColor // Stronger border for hour marks
                        : calendarBorderColor.withValues(
                            alpha: 0.3), // Lighter border for 15-minute marks
                    width: minute == 0 ? 1.0 : 0.5,
                  ),
                ),
              ),
              child: showLabel
                  ? Text(
                      _formatHour(hour),
                      style: calendarTimeLabelTextStyle.copyWith(
                        fontSize: compact ? 10 : 11,
                        fontWeight:
                            isCurrentTime ? FontWeight.w600 : FontWeight.w400,
                        color: isCurrentTime
                            ? calendarTitleColor
                            : calendarTimeLabelColor,
                      ),
                    )
                  : null,
            );
          } else {
            // Week view: hourly slots
            final hour = startHour + index;
            final isCurrentHour = DateTime.now().hour == hour;
            return Container(
              height: hourHeight,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Text(
                _formatHour(hour),
                style: calendarTimeLabelTextStyle.copyWith(
                  fontSize: compact ? 10 : 11,
                  fontWeight: isCurrentHour ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrentHour
                      ? calendarTitleColor
                      : calendarTimeLabelColor,
                ),
              ),
            );
          }
        }),
      ),
    );
  }

  bool _isCurrentTimeSlot(int hour, int minute) {
    final now = DateTime.now();
    return now.hour == hour && (now.minute ~/ 15) == (minute ~/ 15);
  }

  Widget _buildDayColumn(DateTime date, bool compact,
      {bool isDayView = false}) {
    final isToday = _isToday(date);

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xff0969DA).withValues(alpha: 0.03)
            : Colors.transparent,
        border: const Border(
          right: BorderSide(
            color: calendarBorderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none, // Allow tasks to overflow cell boundaries
        children: [
          _buildTimeSlots(compact,
              isDayView: isDayView, date: date, isToday: isToday),
          ..._buildTasksForDay(date, compact, isDayView: isDayView),
        ],
      ),
    );
  }

  Widget _buildTimeSlots(bool compact,
      {bool isDayView = false, DateTime? date, bool isToday = false}) {
    final hourHeight = _getHourHeight(context, compact);
    final slotHeight = isDayView ? hourHeight / 4 : hourHeight;
    final totalSlots =
        isDayView ? (endHour - startHour + 1) * 4 : (endHour - startHour + 1);

    return Column(
      children: List.generate(totalSlots, (index) {
        if (isDayView) {
          // Day view: 15-minute slots
          final totalMinutes = (startHour * 60) + (index * 15);
          final hour = totalMinutes ~/ 60;
          final minute = totalMinutes % 60;

          return Container(
            height: slotHeight,
            decoration: BoxDecoration(
              color: isToday
                  ? (hour % 2 == 0
                      ? const Color(0xff0969DA).withValues(alpha: 0.02)
                      : const Color(0xff0969DA).withValues(alpha: 0.04))
                  : (hour % 2 == 0 ? Colors.white : const Color(0xfffafbfc)),
              border: Border(
                top: BorderSide(
                  color: minute == 0
                      ? calendarBorderColor // Stronger border for hour marks
                      : calendarBorderColor.withValues(
                          alpha: 0.3), // Lighter border for 15-minute marks
                  width: minute == 0 ? 1.0 : 0.5,
                ),
              ),
            ),
            child: DragTarget<CalendarTask>(
              onAcceptWithDetails: (details) {
                final targetDate = date ?? widget.state.selectedDate;
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                  minute,
                );
                _handleTaskDrop(details.data, slotTime);
              },
              builder: (context, candidateData, rejectedData) {
                final isDragHovering = candidateData.isNotEmpty;
                final cellKey = '${date?.toIso8601String()}_${hour}_$minute';
                final isMouseHovering = _hoveredCellKey == cellKey;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredCellKey = cellKey),
                  onExit: (_) => setState(() => _hoveredCellKey = null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: isDragHovering
                        ? const Color(0xff0969DA).withValues(alpha: 0.15)
                        : isMouseHovering
                            ? const Color(0xff0969DA).withValues(alpha: 0.05)
                            : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Only handle tap if no tasks are present in this slot
                        if (!_hasTaskInSlot(date, hour, minute)) {
                          final targetDate = date ?? widget.state.selectedDate;
                          final slotTime = DateTime(
                            targetDate.year,
                            targetDate.month,
                            targetDate.day,
                            hour,
                            minute,
                          );
                          _handleTimeSlotTap(slotTime);
                        }
                      },
                      hoverColor: Colors
                          .transparent, // Disable InkWell hover since we handle it manually
                      splashColor: Colors.blue.withValues(alpha: 0.2),
                      highlightColor: Colors.blue.withValues(alpha: 0.1),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              },
            ),
          );
        } else {
          // Week view: hourly slots
          final hour = startHour + index;
          return Container(
            height: hourHeight,
            decoration: BoxDecoration(
              color: isToday
                  ? (hour % 2 == 0
                      ? const Color(0xff0969DA).withValues(alpha: 0.02)
                      : const Color(0xff0969DA).withValues(alpha: 0.04))
                  : (hour % 2 == 0 ? Colors.white : const Color(0xfffafbfc)),
              border: const Border(
                top: BorderSide(
                  color: calendarBorderColor,
                  width: 1.0,
                ),
              ),
            ),
            child: DragTarget<CalendarTask>(
              onAcceptWithDetails: (details) {
                final targetDate = date ?? widget.state.selectedDate;
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                );
                _handleTaskDrop(details.data, slotTime);
              },
              builder: (context, candidateData, rejectedData) {
                final isDragHovering = candidateData.isNotEmpty;
                final cellKey = '${date?.toIso8601String()}_${hour}_0';
                final isMouseHovering = _hoveredCellKey == cellKey;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredCellKey = cellKey),
                  onExit: (_) => setState(() => _hoveredCellKey = null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: isDragHovering
                        ? const Color(0xff0969DA).withValues(alpha: 0.15)
                        : isMouseHovering
                            ? const Color(0xff0969DA).withValues(alpha: 0.05)
                            : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Only handle tap if no tasks are present in this slot
                        if (!_hasTaskInSlot(date, hour, 0)) {
                          final targetDate = date ?? widget.state.selectedDate;
                          final slotTime = DateTime(
                            targetDate.year,
                            targetDate.month,
                            targetDate.day,
                            hour,
                          );
                          _handleTimeSlotTap(slotTime);
                        }
                      },
                      hoverColor: Colors
                          .transparent, // Disable InkWell hover since we handle it manually
                      splashColor: Colors.blue.withValues(alpha: 0.2),
                      highlightColor: Colors.blue.withValues(alpha: 0.1),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              },
            ),
          );
        }
      }),
    );
  }

  bool _hasTaskInSlot(DateTime? date, int hour, int minute) {
    if (date == null) return false;

    final tasks = _getTasksForDay(date);
    final slotStart = DateTime(date.year, date.month, date.day, hour, minute);
    final slotEnd = slotStart.add(const Duration(minutes: 15));

    return tasks.any((task) {
      if (task.scheduledTime == null) return false;

      final taskStart = task.scheduledTime!;
      final taskEnd = taskStart.add(task.duration ?? const Duration(hours: 1));

      // Check if task overlaps with this time slot
      return taskStart.isBefore(slotEnd) && taskEnd.isAfter(slotStart);
    });
  }

  void _handleTimeSlotTap(DateTime slotTime) {
    widget.onEmptySlotTapped?.call(slotTime, Offset.zero);
  }

  void _handleTaskDrop(CalendarTask task, DateTime dropTime) {
    widget.onTaskDragEnd?.call(task, dropTime);
  }

  List<Widget> _buildTasksForDay(DateTime date, bool compact,
      {bool isDayView = false}) {
    final tasks = _getTasksForDay(date);
    final widgets = <Widget>[];

    // Calculate overlaps for all tasks
    final overlapMap = _calculateEventOverlaps(tasks);

    // Calculate cell width more conservatively to prevent oversized tasks
    // Estimate calendar area width (screen minus sidebar, assuming ~300px sidebar)
    final screenWidth = MediaQuery.of(context).size.width;
    final estimatedCalendarWidth =
        screenWidth - 300; // Conservative sidebar width estimate
    final timeColumnWidth =
        compact ? 50.0 : 90.0; // Updated from 70.0 to 90.0 to match target

    // Calculate actual cell width
    final cellWidth = isDayView
        ? estimatedCalendarWidth - timeColumnWidth
        : (estimatedCalendarWidth - timeColumnWidth) / 7;

    // Use 90% to ensure tasks fit properly within cells
    final containerWidth = (cellWidth * 0.90).clamp(60.0, 150.0);

    for (final task in tasks) {
      if (task.scheduledTime == null) continue;

      final overlapInfo = overlapMap[task.id] ??
          const OverlapInfo(columnIndex: 0, totalColumns: 1);
      final widget = _buildTaskWidget(
        task,
        overlapInfo,
        compact,
        containerWidth,
        cellWidth,
        isDayView: isDayView,
      );
      if (widget != null) {
        widgets.add(widget);
      }
    }

    return widgets;
  }

  Widget? _buildTaskWidget(CalendarTask task, OverlapInfo overlapInfo,
      bool compact, double containerWidth, double cellWidth,
      {bool isDayView = false}) {
    if (task.scheduledTime == null) return null;

    final taskTime = task.scheduledTime!;
    final hour = taskTime.hour.toDouble();
    final minute = taskTime.minute.toDouble();

    if (hour < startHour || hour > endHour) return null;

    final hourHeight = _getHourHeight(context, compact);
    final slotHeight = isDayView ? hourHeight / 4 : hourHeight;

    late final double topOffset;
    late final double height;

    if (isDayView) {
      // Day view: position based on 15-minute slots
      final totalMinutesFromStart = ((hour - startHour) * 60) + minute;
      final slotIndex = totalMinutesFromStart / 15;
      topOffset = slotIndex * slotHeight;
      final duration = task.duration ?? const Duration(hours: 1);
      height = (duration.inMinutes / 15) * slotHeight;
    } else {
      // Week view: position based on hour slots
      topOffset = (hour - startHour) * hourHeight + (minute / 60 * hourHeight);
      final duration = task.duration ?? const Duration(hours: 1);
      height = (duration.inMinutes / 60) * hourHeight;
    }

    // Get priority color
    Color taskColor = _getTaskColor(task);

    // Calculate width and left offset based on overlap - center tasks in cells
    final columnWidth = containerWidth / overlapInfo.totalColumns;
    final eventWidth = columnWidth - 4; // Minimal padding for 95% width
    // Center the task within its cell
    final cellLeftMargin = (cellWidth - containerWidth) / 2;
    final leftOffset =
        cellLeftMargin + (columnWidth * overlapInfo.columnIndex) + 2;

    return Positioned(
      top: topOffset,
      left: leftOffset,
      width: eventWidth,
      height: height.clamp(36, double.infinity),
      child: Draggable<CalendarTask>(
        data: task,
        feedback: Transform.scale(
          scale: 1.05, // Slightly scale up during drag
          child: Material(
            elevation: 12, // Increased shadow
            borderRadius: BorderRadius.circular(4),
            child: Opacity(
              opacity: 0.8, // Semi-transparent copy
              child: Container(
                width: eventWidth,
                height: height.clamp(36, double.infinity),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: taskColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: taskColor.withValues(alpha: 0.3),
                      blurRadius: 0,
                      offset: const Offset(0, 0),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: taskTitleTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (height > 45)
                      Text(
                        TimeFormatter.formatDateTime(taskTime),
                        style: taskMetadataTextStyle.copyWith(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: Container(
            decoration: BoxDecoration(
              color: _getTaskColor(task).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _getTaskColor(task),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  // Get the actual global position of the task widget
                  final globalOffset = renderBox.localToGlobal(Offset.zero);
                  // Position dropdown to the right of the task
                  final dropdownPosition = Offset(
                    globalOffset.dx + eventWidth + 8, // Right edge + padding
                    globalOffset.dy + (height / 2) - 20, // Vertically centered
                  );
                  widget.onTaskTapped?.call(task, dropdownPosition);
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 0.5),
                  padding: EdgeInsets.all(
                      compact ? calendarSpacing4 : calendarSpacing6),
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? taskColor.withValues(alpha: 0.6)
                        : taskColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: taskColor.withValues(alpha: 0.8),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Main content
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 4),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final hasSpace = constraints.maxHeight > 32;
                              final showTime =
                                  !compact && hasSpace && height > 50;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Row(
                                      children: [
                                        if (!compact && hasSpace) ...[
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: (compact
                                                    ? taskTitleCompactTextStyle
                                                    : taskTitleTextStyle)
                                                .copyWith(
                                              decoration: task.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: showTime ? 1 : 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (showTime) ...[
                                    const SizedBox(height: 1),
                                    Flexible(
                                      child: Text(
                                        TimeFormatter.formatDateTime(taskTime),
                                        style: taskMetadataTextStyle.copyWith(
                                          fontSize: 8,
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      // Resize handles - positioned at absolute edges
                      if (height > 32) ...[
                        // Top resize handle - extends above the task
                        Positioned(
                          top: -2,
                          left: 0,
                          right: 0,
                          height: 4,
                          child: _ResizeHandle(
                            task: task,
                            direction: _ResizeDirection.top,
                            onResize: (task, newTime, newDuration) {
                              // Handle resize callback - trigger immediate task update
                              widget.onTaskDragEnd?.call(
                                  task.copyWith(
                                    scheduledTime: newTime,
                                    duration: newDuration,
                                  ),
                                  newTime);
                            },
                          ),
                        ),
                        // Bottom resize handle - extends below the task
                        Positioned(
                          bottom: -2,
                          left: 0,
                          right: 0,
                          height: 4,
                          child: _ResizeHandle(
                            task: task,
                            direction: _ResizeDirection.bottom,
                            onResize: (task, newTime, newDuration) {
                              // Handle resize callback - trigger immediate task update
                              widget.onTaskDragEnd?.call(
                                  task.copyWith(
                                    scheduledTime: newTime,
                                    duration: newDuration,
                                  ),
                                  newTime);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTaskColor(CalendarTask task) {
    // Priority-based color assignment matching target design
    switch (task.effectivePriority) {
      case TaskPriority.critical:
        return const Color(0xFFDC3545); // Red - critical (important + urgent)
      case TaskPriority.important:
        return const Color(0xFF28A745); // Green - important only
      case TaskPriority.urgent:
        return const Color(0xFFFD7E14); // Orange - urgent only
      case TaskPriority.none:
        return const Color(0xFF0969DA); // Blue - normal
    }
  }

  Map<String, OverlapInfo> _calculateEventOverlaps(List<CalendarTask> tasks) {
    // Sort tasks by start time
    final sortedTasks = List<CalendarTask>.from(tasks);
    sortedTasks.sort((a, b) {
      if (a.scheduledTime == null && b.scheduledTime == null) return 0;
      if (a.scheduledTime == null) return 1;
      if (b.scheduledTime == null) return -1;
      return a.scheduledTime!.compareTo(b.scheduledTime!);
    });

    final Map<String, OverlapInfo> overlapMap = {};
    final List<List<CalendarTask>> overlapGroups = [];

    // Group overlapping tasks
    for (final task in sortedTasks) {
      if (task.scheduledTime == null) continue;

      final taskStart = task.scheduledTime!;
      final taskEnd = taskStart.add(task.duration ?? const Duration(hours: 1));

      bool addedToGroup = false;

      // Try to add to existing group
      for (final group in overlapGroups) {
        bool overlapsWithGroup = false;

        for (final groupTask in group) {
          if (groupTask.scheduledTime == null) continue;

          final groupStart = groupTask.scheduledTime!;
          final groupEnd =
              groupStart.add(groupTask.duration ?? const Duration(hours: 1));

          // Check if tasks overlap
          if (taskStart.isBefore(groupEnd) && groupStart.isBefore(taskEnd)) {
            overlapsWithGroup = true;
            break;
          }
        }

        if (overlapsWithGroup) {
          group.add(task);
          addedToGroup = true;
          break;
        }
      }

      // Create new group if not added to existing one
      if (!addedToGroup) {
        overlapGroups.add([task]);
      }
    }

    // Calculate column positions for each group
    for (final group in overlapGroups) {
      if (group.length == 1) {
        // No overlap - single column
        overlapMap[group.first.id] = const OverlapInfo(
          columnIndex: 0,
          totalColumns: 1,
        );
      } else {
        // Multiple overlapping tasks - assign columns
        for (int i = 0; i < group.length; i++) {
          overlapMap[group[i].id] = OverlapInfo(
            columnIndex: i,
            totalColumns: group.length,
          );
        }
      }
    }

    return overlapMap;
  }

  List<DateTime> _getWeekDates(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  List<CalendarTask> _getTasksForDay(DateTime date) {
    return widget.state.model.tasks.values.where((task) {
      if (task.scheduledTime == null) return false;
      return _isSameDay(task.scheduledTime!, date);
    }).toList()
      ..sort((a, b) {
        if (a.scheduledTime == null && b.scheduledTime == null) return 0;
        if (a.scheduledTime == null) return 1;
        if (b.scheduledTime == null) return -1;
        return a.scheduledTime!.compareTo(b.scheduledTime!);
      });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getDayName(int weekday, bool compact) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const fullDayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return compact
        ? dayNames[weekday - 1]
        : fullDayNames[weekday - 1].substring(0, 3);
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    if (hour == 24) return '12 AM';
    return '${hour - 12} PM';
  }

  void _selectDateAndSwitchToDay(DateTime date) {
    widget.onDateSelected(date);
    if (widget.state.viewMode == CalendarView.week) {
      widget.onViewChanged(CalendarView.day);
    }
  }

  void _toggleViewMode(CalendarView view) {
    widget.onViewChanged(view);
  }

  void _showTaskDetails(CalendarTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description?.isNotEmpty == true) ...[
              const Text('Description:'),
              Text(task.description!),
              const SizedBox(height: 8),
            ],
            if (task.scheduledTime != null) ...[
              const Text('Scheduled:'),
              Text(TimeFormatter.formatDateTime(task.scheduledTime!)),
              const SizedBox(height: 8),
            ],
            const Text('Status:'),
            Text(task.isCompleted ? 'Completed' : 'Pending'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // Task completion would need a separate callback
              // For now, just close the dialog
              Navigator.of(context).pop();
            },
            child: Text(task.isCompleted ? 'Mark Incomplete' : 'Mark Complete'),
          ),
        ],
      ),
    );
  }
}
