import 'package:flutter/material.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';
import 'resizable_task_widget.dart';

class OverlapInfo {
  final int columnIndex;
  final int totalColumns;

  const OverlapInfo({
    required this.columnIndex,
    required this.totalColumns,
  });
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

  static const double hourSlotHeight = 60.0;
  static const double quarterSlotHeight = 15.0; // hourSlotHeight / 4
  static const double timeColumnWidth = 80.0;
  static const double dayHeaderHeight = 40.0;

  double _getHourHeight(BuildContext context, bool compact) {
    return hourSlotHeight; // Fixed hour height for consistent quarter-hour slots
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
          const SizedBox(
            width: timeColumnWidth,
            child: SizedBox(), // Empty space for time column
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

  Widget _buildDayHeader(DateTime date, bool compact, {bool isFirst = false}) {
    final isToday = _isToday(date);

    return InkWell(
      onTap: widget.state.viewMode == CalendarView.week
          ? () => _selectDateAndSwitchToDay(date)
          : null,
      hoverColor: calendarSidebarBackgroundColor,
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? calendarPrimaryColor.withValues(alpha: 0.05)
              : Colors.white,
          border: const Border(
            right: BorderSide(color: calendarBorderColor),
          ),
        ),
        child: Center(
          child: Text(
            '${_getDayOfWeekShort(date).substring(0, 3)} ${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isToday ? calendarPrimaryColor : calendarTitleColor,
              letterSpacing: 0.5,
            ),
          ),
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
      width: timeColumnWidth,
      decoration: const BoxDecoration(
        color: calendarSidebarBackgroundColor,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              _buildTimeSlots(compact,
                  isDayView: isDayView, date: date, isToday: isToday),
              ..._buildTasksForDayWithWidth(date, compact, constraints.maxWidth,
                  isDayView: isDayView),
            ],
          );
        },
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
                      ? const Color(0xff0969DA).withValues(alpha: 0.01)
                      : const Color(0xff0969DA).withValues(alpha: 0.02))
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
                      ? const Color(0xff0969DA).withValues(alpha: 0.01)
                      : const Color(0xff0969DA).withValues(alpha: 0.02))
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

  List<Widget> _buildTasksForDayWithWidth(
      DateTime date, bool compact, double dayWidth,
      {bool isDayView = false}) {
    final tasks = _getTasksForDay(date);
    final widgets = <Widget>[];

    // Calculate overlaps for all tasks
    final overlapMap = _calculateEventOverlaps(tasks);

    for (final task in tasks) {
      if (task.scheduledTime == null) continue;

      final overlapInfo = overlapMap[task.id] ??
          const OverlapInfo(columnIndex: 0, totalColumns: 1);
      final widget = _buildTaskWidget(
        task,
        overlapInfo,
        compact,
        dayWidth,
        isDayView: isDayView,
        currentDate: date, // Pass the current date for multi-day handling
      );
      if (widget != null) {
        widgets.add(widget);
      }
    }

    return widgets;
  }

  Widget? _buildTaskWidget(
      CalendarTask task, OverlapInfo overlapInfo, bool compact, double dayWidth,
      {bool isDayView = false, DateTime? currentDate}) {
    if (task.scheduledTime == null) return null;

    final taskTime = task.scheduledTime!;
    final hour = taskTime.hour.toDouble();
    final minute = taskTime.minute.toDouble();

    // Check if task's scheduled time is outside visible hours
    if (hour < startHour || hour > endHour) return null;

    // Calculate pixel-perfect positioning
    final startTimeHours = hour + (minute / 60.0);
    final topOffset = (startTimeHours - startHour) * hourSlotHeight;

    // Height is always based on task duration, not day span
    final duration = task.duration ?? const Duration(hours: 1);
    final height = (duration.inMinutes / 60.0) * hourSlotHeight;

    // Calculate width and position based on overlap
    final columnWidth = dayWidth / overlapInfo.totalColumns;
    final eventWidth = columnWidth - 4; // Leave 2px margin on each side
    final leftOffset =
        (columnWidth * overlapInfo.columnIndex) + 2; // 2px margin from left

    return ResizableTaskWidget(
      task: task,
      onResize: (updatedTask) {
        // Immediately update the task via drag end callback
        if (widget.onTaskDragEnd != null && updatedTask.scheduledTime != null) {
          widget.onTaskDragEnd!(updatedTask, updatedTask.scheduledTime!);
        }
      },
      dayWidth: dayWidth,
      hourHeight: hourSlotHeight,
      quarterHeight: quarterSlotHeight,
      left: leftOffset,
      top: topOffset,
      width: eventWidth,
      height: height.clamp(20, double.infinity), // Minimum height of 20px
      isDayView: isDayView,
      onTap: () {
        if (widget.onTaskTapped != null) {
          widget.onTaskTapped!(
              task, Offset(leftOffset + eventWidth, topOffset));
        }
      },
    );
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

      final taskStart = task.scheduledTime!;
      final daySpan = task.effectiveDaySpan;

      // Check if task spans across this day
      if (daySpan > 1) {
        // Multi-day task: check if date falls within the span
        final taskEnd = taskStart.add(Duration(days: daySpan - 1));
        final dateOnly = DateTime(date.year, date.month, date.day);
        final taskStartOnly =
            DateTime(taskStart.year, taskStart.month, taskStart.day);
        final taskEndOnly = DateTime(taskEnd.year, taskEnd.month, taskEnd.day);

        return dateOnly.isAtSameMomentAs(taskStartOnly) ||
            dateOnly.isAtSameMomentAs(taskEndOnly) ||
            (dateOnly.isAfter(taskStartOnly) && dateOnly.isBefore(taskEndOnly));
      }

      // Single day task: check if it's on this day
      return _isSameDay(taskStart, date);
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

  String _getDayOfWeekShort(DateTime date) {
    const dayNames = [
      'SUNDAY',
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY'
    ];
    return dayNames[date.weekday % 7];
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
}
