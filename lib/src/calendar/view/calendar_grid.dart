import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/responsive_helper.dart';
import 'edit_task_dropdown.dart';
import 'resizable_task_widget.dart';

class _TaskPopoverLayout {
  const _TaskPopoverLayout({
    required this.topLeft,
    required this.maxHeight,
  });

  final Offset topLeft;
  final double maxHeight;
}

_TaskPopoverLayout _defaultTaskPopoverLayout() {
  return const _TaskPopoverLayout(
    topLeft: Offset.zero,
    maxHeight: 560,
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
  final Map<String, _TaskPopoverLayout> _taskPopoverLayouts = {};
  OverlayEntry? _activePopoverEntry;
  String? _activeTaskPopoverId;
  bool _popoverDismissArmed = false;
  final Map<String, GlobalKey> _taskItemKeys = {};
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
    _activePopoverEntry?.remove();
    _activePopoverEntry = null;
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
      for (final id in _taskPopoverLayouts.keys)
        if (!activeIds.contains(id)) id,
    ];

    for (final id in removedIds) {
      if (_activeTaskPopoverId == id) {
        // Keep the active popover alive even if its backing tile
        // wasn't part of this build (e.g., due to animation).
        continue;
      }
      _taskPopoverLayouts.remove(id);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_activeTaskPopoverId == id) {
            _closeTaskPopover(id, reason: 'cleanup');
          }
        });
      }
    }
  }

  void _updateActivePopoverLayoutForTask(String taskId) {
    final key = _taskItemKeys[taskId];
    if (key == null) return;
    final context = key.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final rect = offset & renderBox.size;
    final layout = _calculateTaskPopoverLayout(rect);
    _taskPopoverLayouts[taskId] = layout;
    if (_activeTaskPopoverId == taskId) {
      _activePopoverEntry?.markNeedsBuild();
    }
  }

  _TaskPopoverLayout _calculateTaskPopoverLayout(Rect bounds) {
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final EdgeInsets safePadding = mediaQuery.padding;
    const double dropdownWidth = 360.0;
    const double dropdownMaxHeight = 728.0;
    const double minimumHeight = 160.0;
    const double margin = 16.0;

    final double usableLeft = margin;
    final double usableRight = screenSize.width - margin;
    final double usableTop = safePadding.top + margin;
    final double usableBottom = screenSize.height - safePadding.bottom - margin;
    final double usableHeight = math.max(0, usableBottom - usableTop);

    final double leftSpace = bounds.left - usableLeft;
    final double rightSpace = usableRight - bounds.right;

    final bool placeOnRight;
    if (rightSpace >= dropdownWidth && leftSpace < dropdownWidth) {
      placeOnRight = true;
    } else if (leftSpace >= dropdownWidth && rightSpace < dropdownWidth) {
      placeOnRight = false;
    } else {
      placeOnRight = rightSpace >= leftSpace;
    }

    double effectiveMaxHeight = dropdownMaxHeight;
    if (usableHeight <= 0) {
      effectiveMaxHeight = minimumHeight;
    } else {
      effectiveMaxHeight = math.min(dropdownMaxHeight, usableHeight);
      if (effectiveMaxHeight < minimumHeight) {
        effectiveMaxHeight = usableHeight;
      }
    }

    final double halfHeight = effectiveMaxHeight / 2;
    final double taskCenterY = bounds.top + (bounds.height / 2);
    final double clampedCenterY = taskCenterY.clamp(
      usableTop + halfHeight,
      usableBottom - halfHeight,
    );

    double top = clampedCenterY - halfHeight;
    if (top < usableTop) {
      top = usableTop;
    }
    if (top + effectiveMaxHeight > usableBottom) {
      top = usableBottom - effectiveMaxHeight;
    }

    double left = placeOnRight
        ? bounds.right + _taskPopoverHorizontalGap
        : bounds.left - dropdownWidth - _taskPopoverHorizontalGap;

    left = left.clamp(usableLeft, usableRight - dropdownWidth);

    return _TaskPopoverLayout(
      topLeft: Offset(left, top),
      maxHeight: effectiveMaxHeight,
    );
  }

  void _onScheduledTaskTapped(CalendarTask task, Rect bounds) {
    if (_activeTaskPopoverId == task.id) {
      _closeTaskPopover(task.id, reason: 'toggle-close');
      return;
    }

    final layout = _calculateTaskPopoverLayout(bounds);
    _openTaskPopover(task, layout);
  }

  void _closeTaskPopover(String taskId, {String reason = 'manual'}) {
    _taskPopoverLayouts.remove(taskId);
    if (_activeTaskPopoverId != taskId) {
      return;
    }

    _activeTaskPopoverId = null;
    _popoverDismissArmed = false;
    _activePopoverEntry?.remove();
    _activePopoverEntry = null;
    if (mounted) {
      setState(() {});
    }
  }

  void _openTaskPopover(CalendarTask task, _TaskPopoverLayout layout) {
    if (_activeTaskPopoverId != null && _activeTaskPopoverId != task.id) {
      _closeTaskPopover(_activeTaskPopoverId!, reason: 'switch-target');
    }

    _taskPopoverLayouts[task.id] = layout;
    _activeTaskPopoverId = task.id;
    _popoverDismissArmed = false;
    _ensurePopoverEntry();
    if (mounted) {
      setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _popoverDismissArmed = true;
      _activePopoverEntry?.markNeedsBuild();
    });
  }

  void _ensurePopoverEntry() {
    if (_activePopoverEntry != null) {
      _activePopoverEntry!.markNeedsBuild();
      return;
    }

    final overlayState = Overlay.of(context, rootOverlay: true);

    _activePopoverEntry = OverlayEntry(
      builder: (overlayContext) {
        final taskId = _activeTaskPopoverId;
        if (taskId == null) {
          return const SizedBox.shrink();
        }

        final layout =
            _taskPopoverLayouts[taskId] ?? _defaultTaskPopoverLayout();

        final renderBox = overlayState.context.findRenderObject() as RenderBox?;
        final offset = renderBox == null
            ? layout.topLeft
            : renderBox.globalToLocal(layout.topLeft);

        const double popoverWidth = 360.0;

        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  final currentId = _activeTaskPopoverId;
                  if (currentId == null || !_popoverDismissArmed) {
                    return;
                  }

                  final overlayBox =
                      overlayState.context.findRenderObject() as RenderBox?;
                  if (overlayBox == null) {
                    _closeTaskPopover(currentId, reason: 'outside-tap');
                    return;
                  }

                  final layout = _taskPopoverLayouts[currentId] ??
                      _defaultTaskPopoverLayout();
                  final Offset topLeft = layout.topLeft;
                  final Rect popoverRect = Rect.fromLTWH(
                    topLeft.dx,
                    topLeft.dy,
                    popoverWidth,
                    layout.maxHeight,
                  );

                  final Offset localPosition =
                      overlayBox.globalToLocal(event.position);

                  if (!popoverRect.contains(localPosition)) {
                    _closeTaskPopover(currentId, reason: 'outside-tap');
                  }
                },
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy,
              width: popoverWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: layout.maxHeight),
                child: Material(
                  color: Colors.transparent,
                  child: BlocProvider<T>.value(
                    value: widget.bloc,
                    child: BlocBuilder<T, CalendarState>(
                      builder: (context, state) {
                        final baseId = baseTaskIdFrom(taskId);
                        final latestTask = state.model.tasks[baseId];
                        if (latestTask == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _closeTaskPopover(taskId, reason: 'missing-task');
                          });
                          return const SizedBox.shrink();
                        }

                        return EditTaskDropdown(
                          task: latestTask,
                          maxHeight: layout.maxHeight,
                          onClose: () => _closeTaskPopover(taskId,
                              reason: 'dropdown-close'),
                          onTaskUpdated: (updatedTask) {
                            context.read<T>().add(
                                  CalendarEvent.taskUpdated(
                                    task: updatedTask,
                                  ),
                                );
                          },
                          onTaskDeleted: (deletedTaskId) {
                            context.read<T>().add(
                                  CalendarEvent.taskDeleted(
                                    taskId: deletedTaskId,
                                  ),
                                );
                            _closeTaskPopover(taskId,
                                reason: 'task-deleted');
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(_activePopoverEntry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _popoverDismissArmed = true;
    });
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
              ..._buildTasksForDayWithWidth(date, compact, constraints.maxWidth,
                  isDayView: isDayView, visibleTaskIds: visibleTaskIds),
              if (_shouldShowCurrentTimeIndicator(date))
                _buildCurrentTimeIndicator(
                  date,
                  constraints.maxWidth,
                  compact,
                  isDayView,
                ),
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
          final isPopoverOpen = _activeTaskPopoverId == task.id;
          if (isPopoverOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateActivePopoverLayoutForTask(task.id);
            });
          }

          final globalKey =
              _taskItemKeys.putIfAbsent(task.id, () => GlobalKey());

          return KeyedSubtree(
            key: globalKey,
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
              hourHeight: hourSlotHeight,
              quarterHeight: quarterSlotHeight,
              width: eventWidth,
              height: clampedHeight,
              isDayView: isDayView,
              isPopoverOpen: isPopoverOpen,
              enableInteractions: !task.isOccurrence,
              onTap: (tappedTask, bounds) {
                _onScheduledTaskTapped(tappedTask, bounds);
              },
            ),
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
    final tasks = widget.state.tasksForDate(date);
    return tasks
        .where((task) => task.scheduledTime != null)
        .toList()
      ..sort((a, b) {
        final aTime = a.scheduledTime;
        final bTime = b.scheduledTime;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
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
