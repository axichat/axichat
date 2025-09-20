import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import 'edit_task_dropdown.dart';
import 'resizable_task_widget.dart';

class _TaskPopoverLayout {
  const _TaskPopoverLayout({
    required this.anchor,
    required this.maxHeight,
  });

  final ShadAnchorBase anchor;
  final double maxHeight;
}

_TaskPopoverLayout _defaultTaskPopoverLayout() {
  return const _TaskPopoverLayout(
    anchor: ShadAnchor(
      childAlignment: Alignment.centerRight,
      overlayAlignment: Alignment.centerLeft,
      offset: Offset(12, 0),
    ),
    maxHeight: 560, // Increased by 40% from 400
  );
}

class OverlapInfo {
  final int columnIndex;
  final int totalColumns;

  const OverlapInfo({
    required this.columnIndex,
    required this.totalColumns,
  });
}

class CalendarGrid<T extends BaseCalendarBloc> extends StatefulWidget {
  final CalendarState state;
  final Function(DateTime, Offset)? onEmptySlotTapped;
  final Function(CalendarTask, DateTime)? onTaskDragEnd;
  final void Function(DateTime date) onDateSelected;
  final void Function(CalendarView view) onViewChanged;
  final T bloc;

  const CalendarGrid({
    super.key,
    required this.state,
    required this.bloc,
    this.onEmptySlotTapped,
    this.onTaskDragEnd,
    required this.onDateSelected,
    required this.onViewChanged,
  });

  @override
  State<CalendarGrid<T>> createState() => _CalendarGridState<T>();
}

class _CalendarGridState<T extends BaseCalendarBloc>
    extends State<CalendarGrid<T>> with TickerProviderStateMixin {
  static const int startHour = 0;
  static const int endHour = 24;
  late AnimationController _viewTransitionController;
  late Animation<double> _viewTransitionAnimation;
  late final ScrollController _verticalController;
  Timer? _clockTimer;
  bool _hasAutoScrolled = false;
  final Map<String, ShadPopoverController> _taskPopoverControllers = {};
  final Map<String, _TaskPopoverLayout> _taskPopoverLayouts = {};
  final Map<String, Object> _taskPopoverGroups = {};
  String? _activeTaskPopoverId;
  static final Object _fallbackPopoverGroup = Object();
  static const double _taskPopoverHoverBridgeExtent = 16.0;
  static const double _taskPopoverHorizontalGap = 12.0;

  // Track hovered cell for hover effects
  DateTime? _dragPreviewStart;
  Duration? _dragPreviewDuration;

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
    _verticalController = ScrollController();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoScroll());
  }

  @override
  void dispose() {
    _viewTransitionController.dispose();
    _clockTimer?.cancel();
    _verticalController.dispose();
    for (final controller in _taskPopoverControllers.values) {
      controller.dispose();
    }
    _taskPopoverControllers.clear();
    super.dispose();
  }

  void _updateDragPreview(DateTime start, Duration duration) {
    if (_dragPreviewStart == start && _dragPreviewDuration == duration) {
      return;
    }
    setState(() {
      _dragPreviewStart = start;
      _dragPreviewDuration = duration;
    });
  }

  void _clearDragPreview() {
    if (_dragPreviewStart == null && _dragPreviewDuration == null) {
      return;
    }
    setState(() {
      _dragPreviewStart = null;
      _dragPreviewDuration = null;
    });
  }

  bool _isPreviewAnchor(DateTime slotStart) {
    if (_dragPreviewStart == null) return false;
    return slotStart.isAtSameMomentAs(_dragPreviewStart!);
  }

  bool _isPreviewSlot(DateTime slotStart, Duration slotDuration) {
    if (_dragPreviewStart == null || _dragPreviewDuration == null) {
      return false;
    }
    final previewStart = _dragPreviewStart!;
    final previewEnd = previewStart.add(_dragPreviewDuration!);
    final slotEnd = slotStart.add(slotDuration);
    return slotStart.isBefore(previewEnd) && slotEnd.isAfter(previewStart);
  }

  @override
  void didUpdateWidget(covariant CalendarGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect view mode changes and animate transitions
    if (oldWidget.state.viewMode != widget.state.viewMode) {
      _viewTransitionController.reset();
      _viewTransitionController.forward();
      _hasAutoScrolled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoScroll());
    } else if (!_isSameDay(
        oldWidget.state.selectedDate, widget.state.selectedDate)) {
      _hasAutoScrolled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoScroll());
    }
  }

  static const double hourSlotHeight = 40.0;
  static const double quarterSlotHeight = 10.0; // hourSlotHeight / 4
  static const double timeColumnWidth = 80.0;
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
                controller: _verticalController,
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
    final visibleTaskIds = <String>{};
    late final Widget content;

    if (isWeekView && isMobile) {
      // Mobile week view: horizontal scroll for day columns
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeColumn(compact),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: weekDates.asMap().entries.map((entry) {
                  return SizedBox(
                    width: 120, // Fixed width for mobile day columns
                    child: _buildDayColumn(
                      entry.value,
                      compact,
                      isFirstColumn: entry.key == 0,
                      visibleTaskIds: visibleTaskIds,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    } else if (isWeekView) {
      // Desktop/tablet week view: equal width columns
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeColumn(compact),
          ...weekDates.asMap().entries.map(
                (entry) => Expanded(
                  child: _buildDayColumn(
                    entry.value,
                    compact,
                    isFirstColumn: entry.key == 0,
                    visibleTaskIds: visibleTaskIds,
                  ),
                ),
              ),
        ],
      );
    } else {
      // Day view: single column
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeColumn(compact),
          Expanded(
            child: _buildDayColumn(
              widget.state.selectedDate,
              compact,
              isDayView: true,
              isFirstColumn: true,
              visibleTaskIds: visibleTaskIds,
            ),
          ),
        ],
      );
    }

    _cleanupTaskPopovers(visibleTaskIds);
    return content;
  }

  void _cleanupTaskPopovers(Set<String> activeIds) {
    final removedIds = <String>[
      for (final id in _taskPopoverControllers.keys)
        if (!activeIds.contains(id)) id,
    ];

    for (final id in removedIds) {
      _taskPopoverControllers.remove(id)?.dispose();
      _taskPopoverLayouts.remove(id);
      _taskPopoverGroups.remove(id);
      if (_activeTaskPopoverId == id) {
        _activeTaskPopoverId = null;
      }
    }
  }

  ShadPopoverController _popoverControllerFor(String taskId) {
    final existing = _taskPopoverControllers[taskId];
    if (existing != null) {
      return existing;
    }

    final controller = ShadPopoverController();
    controller.addListener(() {
      if (!mounted) return;
      if (!controller.isOpen && _activeTaskPopoverId == taskId) {
        setState(() {
          _activeTaskPopoverId = null;
        });
      }
    });

    _taskPopoverControllers[taskId] = controller;
    return controller;
  }

  _TaskPopoverLayout _calculateTaskPopoverLayout(Rect bounds) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;
    const dropdownWidth = 360.0;
    const dropdownMaxHeight = 728.0; // Increased by 40% from 520
    const margin = 16.0;

    // Calculate actual usable screen area (excluding status bar, nav bar, etc)
    final usableTop = safePadding.top + margin;
    final usableBottom = screenSize.height - safePadding.bottom - margin;
    final usableHeight = usableBottom - usableTop;

    // Calculate available space on each side of the task
    final leftSpace = bounds.left - margin;
    final rightSpace = screenSize.width - bounds.right - margin;

    // Determine which side to place the popover based on available space
    final bool placeOnRight;
    if (rightSpace >= dropdownWidth) {
      placeOnRight = true; // Enough space on right
    } else if (leftSpace >= dropdownWidth) {
      placeOnRight = false; // Enough space on left
    } else {
      placeOnRight = rightSpace > leftSpace; // Use side with more space
    }

    // Calculate vertical positioning using dynamic alignment strategy
    final taskTop = bounds.top;
    final taskBottom = bounds.bottom;
    final taskCenterY = bounds.top + bounds.height / 2;

    // Start with desired max height
    double effectiveMaxHeight = dropdownMaxHeight;

    // Check total available vertical space
    if (effectiveMaxHeight > usableHeight) {
      effectiveMaxHeight = usableHeight.clamp(160.0, dropdownMaxHeight);
    }

    // Determine vertical alignment and offset based on available space
    final popoverHalfHeight = effectiveMaxHeight / 2;
    final spaceAbove = taskCenterY - usableTop;
    final spaceBelow = usableBottom - taskCenterY;

    Alignment childVerticalAlignment;
    double verticalOffset = 0;

    // Check if we can center the popover vertically
    if (spaceAbove >= popoverHalfHeight && spaceBelow >= popoverHalfHeight) {
      // Enough space to center - use center alignment
      childVerticalAlignment = Alignment.center;
      verticalOffset = 0;
    } else if (spaceAbove < popoverHalfHeight &&
        spaceBelow >= effectiveMaxHeight - spaceAbove) {
      // Not enough space above, align to top of task
      childVerticalAlignment = Alignment.topCenter;

      // Calculate offset to ensure popover doesn't go off top
      final popoverTop = taskTop;
      if (popoverTop < usableTop) {
        verticalOffset = usableTop - popoverTop;
      }

      // Check if we need to reduce height
      if (taskTop + verticalOffset + effectiveMaxHeight > usableBottom) {
        effectiveMaxHeight = usableBottom - (taskTop + verticalOffset);
        effectiveMaxHeight = effectiveMaxHeight.clamp(160.0, dropdownMaxHeight);
      }
    } else if (spaceBelow < popoverHalfHeight &&
        spaceAbove >= effectiveMaxHeight - spaceBelow) {
      // Not enough space below, align to bottom of task
      childVerticalAlignment = Alignment.bottomCenter;

      // Calculate offset to ensure popover doesn't go off bottom
      final popoverBottom = taskBottom;
      if (popoverBottom + effectiveMaxHeight > usableBottom) {
        verticalOffset = usableBottom - (popoverBottom + effectiveMaxHeight);
      }

      // Check if we need to reduce height
      if (taskBottom + verticalOffset - effectiveMaxHeight < usableTop) {
        effectiveMaxHeight = (taskBottom + verticalOffset) - usableTop;
        effectiveMaxHeight = effectiveMaxHeight.clamp(160.0, dropdownMaxHeight);
      }
    } else {
      // Limited space on both sides - use whichever has more space
      if (spaceBelow > spaceAbove) {
        // More space below - align to top of task
        childVerticalAlignment = Alignment.topCenter;
        effectiveMaxHeight = (spaceBelow * 2).clamp(160.0, dropdownMaxHeight);

        // Ensure it doesn't go off screen
        if (taskTop < usableTop) {
          verticalOffset = usableTop - taskTop;
        }
      } else {
        // More space above - align to bottom of task
        childVerticalAlignment = Alignment.bottomCenter;
        effectiveMaxHeight = (spaceAbove * 2).clamp(160.0, dropdownMaxHeight);

        // Ensure it doesn't go off screen
        if (taskBottom > usableBottom) {
          verticalOffset = usableBottom - taskBottom;
        }
      }
    }

    // Combine horizontal and vertical alignments
    final Alignment childAlignment;
    final Alignment overlayAlignment;

    if (placeOnRight) {
      if (childVerticalAlignment == Alignment.center) {
        childAlignment = Alignment.centerRight;
        overlayAlignment = Alignment.centerLeft;
      } else if (childVerticalAlignment == Alignment.topCenter) {
        childAlignment = Alignment.topRight;
        overlayAlignment = Alignment.topLeft;
      } else {
        childAlignment = Alignment.bottomRight;
        overlayAlignment = Alignment.bottomLeft;
      }
    } else {
      if (childVerticalAlignment == Alignment.center) {
        childAlignment = Alignment.centerLeft;
        overlayAlignment = Alignment.centerRight;
      } else if (childVerticalAlignment == Alignment.topCenter) {
        childAlignment = Alignment.topLeft;
        overlayAlignment = Alignment.topRight;
      } else {
        childAlignment = Alignment.bottomLeft;
        overlayAlignment = Alignment.bottomRight;
      }
    }

    // Simple horizontal offset for gap between task and popover
    const horizontalGap = _taskPopoverHorizontalGap;
    final horizontalOffset = placeOnRight ? horizontalGap : -horizontalGap;

    // Use ShadAnchorAuto when near edges for better automatic positioning
    final ShadAnchorBase anchor;
    final needsAutoPositioning =
        verticalOffset.abs() > 50; // Large offset indicates edge case

    if (needsAutoPositioning) {
      // Use auto positioning for edge cases
      final Alignment targetAlign;
      final Alignment followerAlign;

      if (placeOnRight) {
        targetAlign = Alignment.centerRight;
        followerAlign = Alignment.centerLeft;
      } else {
        targetAlign = Alignment.centerLeft;
        followerAlign = Alignment.centerRight;
      }

      anchor = ShadAnchorAuto(
        targetAnchor: targetAlign,
        followerAnchor: followerAlign,
        offset: Offset(horizontalOffset, 0),
      );
    } else {
      // Use manual positioning when we have good space
      anchor = ShadAnchor(
        childAlignment: childAlignment,
        overlayAlignment: overlayAlignment,
        offset: Offset(horizontalOffset, verticalOffset),
      );
    }

    // Debug output to understand positioning (disabled in production)
    // print('Task bounds: $bounds');
    // print('Usable area: top=$usableTop, bottom=$usableBottom');
    // print('Space: above=$spaceAbove, below=$spaceBelow');
    // print('Alignment: child=$childAlignment, overlay=$overlayAlignment');
    // print('Offset: horizontal=$horizontalOffset, vertical=$verticalOffset');
    // print('Max height: $effectiveMaxHeight');

    return _TaskPopoverLayout(
      anchor: anchor,
      maxHeight: effectiveMaxHeight,
    );
  }

  void _onScheduledTaskTapped(CalendarTask task, Rect bounds) {
    final controller = _popoverControllerFor(task.id);

    if (controller.isOpen) {
      _closeTaskPopover(task.id, reason: 'toggle-close');
      return;
    }

    final layout = _calculateTaskPopoverLayout(bounds);

    if (_activeTaskPopoverId != null && _activeTaskPopoverId != task.id) {
      _closeTaskPopover(_activeTaskPopoverId!, reason: 'switch-target');
    }

    if (!mounted) return;

    final groupId = Object();

    setState(() {
      _taskPopoverLayouts[task.id] = layout;
      _taskPopoverGroups[task.id] = groupId;
      _activeTaskPopoverId = task.id;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final updatedController = _taskPopoverControllers[task.id];
      if (updatedController != null && !updatedController.isOpen) {
        updatedController.show();
      }
    });
  }

  void _closeTaskPopover(String taskId, {String reason = 'manual'}) {
    final controller = _taskPopoverControllers[taskId];
    if (controller == null) {
      return;
    }

    if (controller.isOpen) {
      controller.hide();
    }
    _taskPopoverLayouts.remove(taskId);
    _taskPopoverGroups.remove(taskId);
    if (_activeTaskPopoverId == taskId) {
      _activeTaskPopoverId = null;
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
          Container(
            width: timeColumnWidth,
            decoration: const BoxDecoration(
              color: calendarSidebarBackgroundColor,
              border: Border(
                top: BorderSide(color: calendarBorderColor, width: 1),
                right: BorderSide(color: calendarBorderColor, width: 1),
              ),
            ),
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
          border: Border(
            right: const BorderSide(color: calendarBorderDarkColor),
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
            color: calendarBorderDarkColor,
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
            final label = minute == 0
                ? _formatHour(hour)
                : minute == 15
                    ? ':15'
                    : minute == 30
                        ? ':30'
                        : ':45';
            final isFirstSlot = index == 0;

            return Container(
              height: slotHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  top: BorderSide(
                    color: isFirstSlot
                        ? Colors.transparent
                        : minute == 0
                            ? calendarBorderColor
                            : calendarBorderColor.withValues(alpha: 0.3),
                    width: isFirstSlot
                        ? 0
                        : minute == 0
                            ? 1.0
                            : 0.5,
                  ),
                ),
              ),
              child: Text(
                label,
                style: calendarTimeLabelTextStyle.copyWith(
                  fontSize: minute == 0 ? (compact ? 10 : 11) : 9,
                  fontWeight: isCurrentTime ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrentTime
                      ? calendarTitleColor
                      : calendarTimeLabelColor,
                ),
              ),
            );
          } else {
            // Week view: hourly slots
            final hour = startHour + index;
            final isCurrentHour = DateTime.now().hour == hour;
            final isFirstSlot = index == 0;
            return Container(
              height: hourHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  top: BorderSide(
                    color: isFirstSlot
                        ? Colors.transparent
                        : calendarBorderDarkColor,
                    width: isFirstSlot ? 0 : 1.0,
                  ),
                ),
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
      {bool isDayView = false,
      bool isFirstColumn = false,
      required Set<String> visibleTaskIds}) {
    final isToday = _isToday(date);

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xff0969DA).withValues(alpha: 0.03)
            : Colors.transparent,
        border: const Border(
          right: BorderSide(
            color: calendarBorderDarkColor,
            width: 1,
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
              if (_shouldShowCurrentTimeIndicator(date))
                _buildCurrentTimeIndicator(
                  date,
                  constraints.maxWidth,
                  compact,
                  isDayView,
                ),
              ..._buildTasksForDayWithWidth(date, compact, constraints.maxWidth,
                  isDayView: isDayView, visibleTaskIds: visibleTaskIds),
            ],
          );
        },
      ),
    );
  }

  bool _shouldShowCurrentTimeIndicator(DateTime date) {
    return _isSameDay(date, DateTime.now());
  }

  Widget _buildCurrentTimeIndicator(
      DateTime date, double columnWidth, bool compact, bool isDayView) {
    final now = DateTime.now();
    final minutesFromStart = (now.hour * 60 + now.minute) - (startHour * 60);
    if (minutesFromStart < 0 || minutesFromStart > (endHour - startHour) * 60) {
      return const SizedBox.shrink();
    }

    final hourHeight = _getHourHeight(context, compact);
    final double slotHeight = isDayView ? hourHeight / 4 : hourHeight;
    final double rawOffset =
        (minutesFromStart / (isDayView ? 15 : 60)) * slotHeight - 4;
    final double position = rawOffset < 0 ? 0 : rawOffset;

    return Positioned(
      top: position,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SizedBox(
          height: 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: calendarPrimaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 2,
                  color: calendarPrimaryColor,
                ),
              ),
            ],
          ),
        ),
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
          final isFirstSlot = index == 0;
          final targetDate = date ?? widget.state.selectedDate;

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
                  color: isFirstSlot
                      ? Colors.transparent
                      : minute == 0
                          ? calendarBorderColor
                          : calendarBorderColor.withValues(alpha: 0.3),
                  width: isFirstSlot
                      ? 0
                      : minute == 0
                          ? 1.0
                          : 0.5,
                ),
              ),
            ),
            child: DragTarget<CalendarTask>(
              onWillAccept: (task) {
                if (task == null) {
                  return false;
                }
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                  minute,
                );
                final duration = task.duration ?? const Duration(hours: 1);
                _updateDragPreview(slotTime, duration);
                return true;
              },
              onLeave: (_) {
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                  minute,
                );
                if (_isPreviewAnchor(slotTime)) {
                  _clearDragPreview();
                }
              },
              onAcceptWithDetails: (details) {
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                  minute,
                );
                _clearDragPreview();
                _handleTaskDrop(details.data, slotTime);
              },
              builder: (context, candidateData, rejectedData) {
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                  minute,
                );
                const slotDuration = Duration(minutes: 15);
                final isPreviewSlot = _isPreviewSlot(slotTime, slotDuration);
                final isPreviewAnchor = _isPreviewAnchor(slotTime);

                return _CalendarSlot(
                  isPreviewSlot: isPreviewSlot,
                  isPreviewAnchor: isPreviewAnchor,
                  cursor: SystemMouseCursors.click,
                  splashColor: Colors.blue.withValues(alpha: 0.2),
                  highlightColor: Colors.blue.withValues(alpha: 0.1),
                  onTap: () {
                    if (!_hasTaskInSlot(date, hour, minute)) {
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
                  child: const SizedBox.expand(),
                );
              },
            ),
          );
        } else {
          // Week view: hourly slots
          final hour = startHour + index;
          final isFirstSlot = index == 0;
          final targetDate = date ?? widget.state.selectedDate;
          return Container(
            height: hourHeight,
            decoration: BoxDecoration(
              color: isToday
                  ? (hour % 2 == 0
                      ? const Color(0xff0969DA).withValues(alpha: 0.01)
                      : const Color(0xff0969DA).withValues(alpha: 0.02))
                  : (hour % 2 == 0 ? Colors.white : const Color(0xfffafbfc)),
              border: Border(
                top: BorderSide(
                  color: isFirstSlot ? Colors.transparent : calendarBorderColor,
                  width: isFirstSlot ? 0 : 1.0,
                ),
              ),
            ),
            child: DragTarget<CalendarTask>(
              onWillAccept: (task) {
                if (task == null) {
                  return false;
                }
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                );
                final duration = task.duration ?? const Duration(hours: 1);
                _updateDragPreview(slotTime, duration);
                return true;
              },
              onLeave: (_) {
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                );
                if (_isPreviewAnchor(slotTime)) {
                  _clearDragPreview();
                }
              },
              onAcceptWithDetails: (details) {
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                );
                _clearDragPreview();
                _handleTaskDrop(details.data, slotTime);
              },
              builder: (context, candidateData, rejectedData) {
                final slotTime = DateTime(
                  targetDate.year,
                  targetDate.month,
                  targetDate.day,
                  hour,
                );
                const slotDuration = Duration(hours: 1);
                final isPreviewSlot = _isPreviewSlot(slotTime, slotDuration);
                final isPreviewAnchor = _isPreviewAnchor(slotTime);

                return _CalendarSlot(
                  isPreviewSlot: isPreviewSlot,
                  isPreviewAnchor: isPreviewAnchor,
                  cursor: SystemMouseCursors.click,
                  splashColor: Colors.blue.withValues(alpha: 0.2),
                  highlightColor: Colors.blue.withValues(alpha: 0.1),
                  onTap: () {
                    if (!_hasTaskInSlot(date, hour, 0)) {
                      final slotTime = DateTime(
                        targetDate.year,
                        targetDate.month,
                        targetDate.day,
                        hour,
                      );
                      _handleTimeSlotTap(slotTime);
                    }
                  },
                  child: const SizedBox.expand(),
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

  void _maybeAutoScroll() {
    if (_hasAutoScrolled || !mounted) return;
    if (!_verticalController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoScroll());
      return;
    }

    final now = DateTime.now();
    final bool isDayView = widget.state.viewMode == CalendarView.day;
    final List<DateTime> weekDates = _getWeekDates(widget.state.selectedDate);
    final bool compact = ResponsiveHelper.isMobile(context);

    final bool shouldScroll = isDayView
        ? _isSameDay(widget.state.selectedDate, now)
        : weekDates.any((date) => _isSameDay(date, now));

    if (!shouldScroll) {
      _hasAutoScrolled = true;
      return;
    }

    final minutesFromStart = (now.hour * 60 + now.minute) - (startHour * 60);
    if (minutesFromStart < 0 || minutesFromStart > (endHour - startHour) * 60) {
      _hasAutoScrolled = true;
      return;
    }

    final hourHeight = _getHourHeight(context, compact);
    final double slotHeight = isDayView ? hourHeight / 4 : hourHeight;
    final double offset =
        (minutesFromStart / (isDayView ? 15 : 60)) * slotHeight;

    final position = _verticalController.position;
    final viewport = position.viewportDimension;
    double target = offset - viewport / 2;
    target = target.clamp(0.0, position.maxScrollExtent).toDouble();
    _verticalController.jumpTo(target);
    _hasAutoScrolled = true;
  }

  List<Widget> _buildTasksForDayWithWidth(
      DateTime date, bool compact, double dayWidth,
      {bool isDayView = false, required Set<String> visibleTaskIds}) {
    final tasks = _getTasksForDay(date);
    final widgets = <Widget>[];

    final weekStartDate = DateTime(
      widget.state.weekStart.year,
      widget.state.weekStart.month,
      widget.state.weekStart.day,
    );
    final weekEndDate = DateTime(
      widget.state.weekEnd.year,
      widget.state.weekEnd.month,
      widget.state.weekEnd.day,
    );

    // Calculate overlaps for all tasks
    final overlapMap = _calculateEventOverlaps(tasks);

    for (final task in tasks) {
      if (task.scheduledTime == null) continue;

      visibleTaskIds.add(task.id);
      final overlapInfo = overlapMap[task.id] ??
          const OverlapInfo(columnIndex: 0, totalColumns: 1);
      final widget = _buildTaskWidget(
        task,
        overlapInfo,
        compact,
        dayWidth,
        isDayView: isDayView,
        currentDate: date, // Pass the current date for multi-day handling
        weekStartDate: weekStartDate,
        weekEndDate: weekEndDate,
      );
      if (widget != null) {
        widgets.add(widget);
      }
    }

    return widgets;
  }

  Widget? _buildTaskWidget(
      CalendarTask task, OverlapInfo overlapInfo, bool compact, double dayWidth,
      {bool isDayView = false,
      DateTime? currentDate,
      DateTime? weekStartDate,
      DateTime? weekEndDate}) {
    if (task.scheduledTime == null || currentDate == null) return null;

    final taskTime = task.scheduledTime!;
    final dayDate =
        DateTime(currentDate.year, currentDate.month, currentDate.day);
    final eventStartDate =
        DateTime(taskTime.year, taskTime.month, taskTime.day);

    DateTime? effectiveEndDateTime = task.effectiveEndDate;
    effectiveEndDateTime ??=
        task.duration != null ? taskTime.add(task.duration!) : taskTime;
    final eventEndDate = DateTime(effectiveEndDateTime.year,
        effectiveEndDateTime.month, effectiveEndDateTime.day);

    final clampedWeekStart = weekStartDate ?? eventStartDate;
    final clampedWeekEnd = weekEndDate ?? eventEndDate;

    final clampedStart = eventStartDate.isBefore(clampedWeekStart)
        ? clampedWeekStart
        : eventStartDate;
    final clampedEnd =
        eventEndDate.isAfter(clampedWeekEnd) ? clampedWeekEnd : eventEndDate;

    if (dayDate.isAfter(clampedEnd) || dayDate.isBefore(clampedStart)) {
      return null;
    }

    if (!isDayView && !DateUtils.isSameDay(dayDate, clampedStart)) {
      return null;
    }

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
    final totalColumns =
        overlapInfo.totalColumns == 0 ? 1 : overlapInfo.totalColumns;
    final columnWidth = dayWidth / totalColumns;
    final baseWidth = columnWidth - 4; // Leave 2px margin on each side
    final leftOffset =
        (columnWidth * overlapInfo.columnIndex) + 2; // 2px margin from left

    final clampedHeight = height.clamp(20.0, double.infinity).toDouble();

    final spanDays = !isDayView
        ? ((clampedEnd.difference(dayDate).inDays + 1).clamp(1, 7)).toInt()
        : 1;
    final eventWidth = !isDayView ? (columnWidth * spanDays) - 4 : baseWidth;

    return Positioned(
      left: leftOffset,
      top: topOffset,
      width: eventWidth,
      height: clampedHeight,
      child: Builder(
        builder: (context) {
          final bloc = widget.bloc;
          final controller = _popoverControllerFor(task.id);
          final layout =
              _taskPopoverLayouts[task.id] ?? _defaultTaskPopoverLayout();
          final groupId = _taskPopoverGroups[task.id] ?? _fallbackPopoverGroup;
          final hoverBridgeExtent = _taskPopoverHoverBridgeExtent;
          final isPopoverOpen = _activeTaskPopoverId == task.id;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -hoverBridgeExtent,
                right: -hoverBridgeExtent,
                top: -hoverBridgeExtent,
                bottom: -hoverBridgeExtent,
                child: ShadMouseArea(
                  groupId: groupId,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),
              ShadPopover(
                controller: controller,
                closeOnTapOutside: false,
                groupId: groupId,
                areaGroupId: groupId,
                effects: const [],
                anchor: layout.anchor,
                padding: EdgeInsets.zero,
                popover: (popoverContext) {
                  return BlocProvider<T>.value(
                    value: bloc,
                    child: BlocBuilder<T, CalendarState>(
                      builder: (context, state) {
                        final latestTask = state.model.tasks[task.id] ?? task;

                        return EditTaskDropdown(
                          task: latestTask,
                          maxHeight: layout.maxHeight,
                          onClose: () => _closeTaskPopover(task.id,
                              reason: 'dropdown-close'),
                          onTaskUpdated: (updatedTask) {
                            context.read<T>().add(
                                  CalendarEvent.taskUpdated(task: updatedTask),
                                );
                          },
                          onTaskDeleted: (taskId) {
                            context.read<T>().add(
                                  CalendarEvent.taskDeleted(taskId: taskId),
                                );
                            _closeTaskPopover(taskId, reason: 'task-deleted');
                          },
                        );
                      },
                    ),
                  );
                },
                child: ResizableTaskWidget(
                  key: ValueKey(task.id),
                  task: task,
                  onResize: (updatedTask) {
                    if (widget.onTaskDragEnd != null &&
                        updatedTask.scheduledTime != null) {
                      widget.onTaskDragEnd!(
                        updatedTask,
                        updatedTask.scheduledTime!,
                      );
                    }
                  },
                  dayWidth: dayWidth,
                  hourHeight: hourSlotHeight,
                  quarterHeight: quarterSlotHeight,
                  width: eventWidth,
                  height: clampedHeight,
                  isDayView: isDayView,
                  isPopoverOpen: isPopoverOpen,
                  onTap: (tappedTask, bounds) {
                    _onScheduledTaskTapped(tappedTask, bounds);
                  },
                ),
              ),
            ],
          );
        },
      ),
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

class _CalendarSlot extends StatefulWidget {
  const _CalendarSlot({
    required this.isPreviewSlot,
    required this.isPreviewAnchor,
    required this.child,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
    this.splashColor,
    this.highlightColor,
  });

  final bool isPreviewSlot;
  final bool isPreviewAnchor;
  final Widget child;
  final VoidCallback? onTap;
  final MouseCursor cursor;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  State<_CalendarSlot> createState() => _CalendarSlotState();
}

class _CalendarSlotState extends State<_CalendarSlot> {
  bool _hovering = false;

  static const _baseColor = Color(0xff0969DA);

  Color get _hoverColor => _baseColor.withValues(alpha: 0.05);
  Color get _previewColor => _baseColor.withValues(alpha: 0.12);
  Color get _previewAnchorColor => _baseColor.withValues(alpha: 0.2);

  @override
  Widget build(BuildContext context) {
    final color = widget.isPreviewSlot
        ? (widget.isPreviewAnchor ? _previewAnchorColor : _previewColor)
        : _hovering
            ? _hoverColor
            : Colors.transparent;

    final effectiveCursor =
        widget.onTap != null ? widget.cursor : SystemMouseCursors.basic;

    return MouseRegion(
      cursor: effectiveCursor,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: color,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            splashColor: widget.splashColor,
            highlightColor: widget.highlightColor,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
