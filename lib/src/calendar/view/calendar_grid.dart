import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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

class _ZoomLevel {
  const _ZoomLevel({required this.hourHeight, required this.daySubdivisions});

  final double hourHeight;
  final int daySubdivisions;
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

  const CalendarGrid({
    super.key,
    required this.state,
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
  static const int _defaultZoomIndex = 0;
  static const int _dayViewSubdivisions = 4;
  static const int _resizeStepMinutes = 15;
  static const List<_ZoomLevel> _zoomLevels = <_ZoomLevel>[
    _ZoomLevel(hourHeight: 78, daySubdivisions: 1),
    _ZoomLevel(hourHeight: 132, daySubdivisions: 2),
    _ZoomLevel(hourHeight: 192, daySubdivisions: 4),
  ];
  static const double _autoScrollEdgeThreshold = 24.0;
  static const double _autoScrollStepMultiplier = 0.75;

  late AnimationController _viewTransitionController;
  late Animation<double> _viewTransitionAnimation;
  late final ScrollController _verticalController;
  final GlobalKey _scrollableKey =
      GlobalKey(debugLabel: 'CalendarVerticalScroll');
  final FocusNode _focusNode = FocusNode(debugLabel: 'CalendarGridFocus');
  Timer? _clockTimer;
  bool _hasAutoScrolled = false;
  final Map<String, _TaskPopoverLayout> _taskPopoverLayouts = {};
  OverlayEntry? _activePopoverEntry;
  String? _activeTaskPopoverId;
  bool _popoverDismissArmed = false;
  final Map<String, GlobalKey> _taskItemKeys = {};
  static const double _taskPopoverHorizontalGap = 12.0;

  int _zoomIndex = _defaultZoomIndex;
  double _resolvedHourHeight = _zoomLevels[_defaultZoomIndex].hourHeight;
  double? _pendingAnchorMinutes;

  // Track hovered cell for hover effects
  DateTime? _dragPreviewStart;
  Duration? _dragPreviewDuration;

  late T _capturedBloc;
  bool _blocInitialized = false;
  CalendarTask? _copiedTask;
  final Map<String, CalendarTask> _resizePreviews = {};
  String? _draggingTaskId;
  String? _draggingTaskBaseId;
  DateTime? _contextMenuPasteSlot;
  bool _zoomControlsVisible = false;
  Timer? _zoomControlsDismissTimer;
  static const ValueKey<String> _contextMenuGroupId =
      ValueKey<String>('calendar-grid-context');

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

  _ZoomLevel get _currentZoom => _zoomLevels[_zoomIndex];
  int get _slotSubdivisions => widget.state.viewMode == CalendarView.day
      ? _dayViewSubdivisions
      : _currentZoom.daySubdivisions;
  int get _minutesPerSlot => (60 / _slotSubdivisions).round();
  int get _minutesPerStep => _resizeStepMinutes;
  bool get _canZoomIn => _zoomIndex < _zoomLevels.length - 1;
  bool get _canZoomOut => _zoomIndex > 0;
  bool get _isZoomEnabled => widget.state.viewMode != CalendarView.day;
  bool get _isSelectionMode => widget.state.isSelectionMode;
  Set<String> get _selectedTaskIds => widget.state.selectedTaskIds;

  bool _isTaskSelected(CalendarTask task) {
    return _selectedTaskIds.contains(task.baseId);
  }

  Map<LogicalKeySet, Intent> get _zoomShortcuts => {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.equal):
            const _ZoomIntent(_ZoomAction.zoomIn),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.numpadAdd):
            const _ZoomIntent(_ZoomAction.zoomIn),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.equal):
            const _ZoomIntent(_ZoomAction.zoomIn),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.numpadAdd):
            const _ZoomIntent(_ZoomAction.zoomIn),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.minus):
            const _ZoomIntent(_ZoomAction.zoomOut),
        LogicalKeySet(
                LogicalKeyboardKey.control, LogicalKeyboardKey.numpadSubtract):
            const _ZoomIntent(_ZoomAction.zoomOut),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.minus):
            const _ZoomIntent(_ZoomAction.zoomOut),
        LogicalKeySet(
                LogicalKeyboardKey.meta, LogicalKeyboardKey.numpadSubtract):
            const _ZoomIntent(_ZoomAction.zoomOut),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit0):
            const _ZoomIntent(_ZoomAction.reset),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit0):
            const _ZoomIntent(_ZoomAction.reset),
      };

  String get _zoomLabel {
    if (!_isZoomEnabled) {
      return '15m';
    }
    final subdivisions = _currentZoom.daySubdivisions;
    if (subdivisions <= 1) {
      return '1h';
    }
    final minutes = (60 / subdivisions).round();
    return '${minutes}m';
  }

  void zoomIn() {
    if (!_isZoomEnabled || !_canZoomIn) return;
    _setZoomIndex(_zoomIndex + 1);
  }

  void zoomOut() {
    if (!_isZoomEnabled || !_canZoomOut) return;
    _setZoomIndex(_zoomIndex - 1);
  }

  void zoomReset() {
    if (!_isZoomEnabled) return;
    _setZoomIndex(_defaultZoomIndex);
  }

  bool _setZoomIndex(int index) {
    if (!_isZoomEnabled) {
      return false;
    }

    final clamped = index.clamp(0, _zoomLevels.length - 1);
    if (clamped == _zoomIndex) {
      return false;
    }

    double? anchorMinutes;
    if (_verticalController.hasClients) {
      final position = _verticalController.position;
      if (position.viewportDimension > 0) {
        final viewportMid =
            position.pixels + (position.viewportDimension / 2.0);
        anchorMinutes = _offsetToMinutes(viewportMid, _resolvedHourHeight);
      }
    }

    setState(() {
      _zoomIndex = clamped;
      _hasAutoScrolled = false;
    });

    _showZoomControls();

    if (anchorMinutes != null) {
      _pendingAnchorMinutes = anchorMinutes;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollAnchor();
      });
    }

    return true;
  }

  double _offsetToMinutes(double offset, double hourHeight) {
    final bool isDayView = widget.state.viewMode == CalendarView.day;
    final int subdivisions =
        isDayView ? _dayViewSubdivisions : _currentZoom.daySubdivisions;
    if (subdivisions <= 0 || hourHeight == 0) {
      return 0;
    }
    final double slotHeight = hourHeight / subdivisions;
    final double slotMinutes = 60 / subdivisions;
    if (slotHeight == 0) {
      return 0;
    }
    return (offset / slotHeight) * slotMinutes;
  }

  double _minutesToOffset(double minutes, double hourHeight) {
    final bool isDayView = widget.state.viewMode == CalendarView.day;
    final int subdivisions =
        isDayView ? _dayViewSubdivisions : _currentZoom.daySubdivisions;
    if (subdivisions <= 0) {
      return 0;
    }
    final double slotHeight = hourHeight / subdivisions;
    final double slotMinutes = 60 / subdivisions;
    return (minutes / slotMinutes) * slotHeight;
  }

  void _restoreScrollAnchor() {
    if (_pendingAnchorMinutes == null || !_verticalController.hasClients) {
      _pendingAnchorMinutes = null;
      return;
    }

    final position = _verticalController.position;
    const double maxMinutes = 24 * 60.0;
    final double anchorMinutes =
        _pendingAnchorMinutes!.clamp(0.0, maxMinutes).toDouble();
    final double targetOffset =
        _minutesToOffset(anchorMinutes, _resolvedHourHeight) -
            (position.viewportDimension / 2.0);
    final double clampedTarget =
        targetOffset.clamp(0.0, position.maxScrollExtent).toDouble();

    if ((position.pixels - clampedTarget).abs() > 0.5) {
      _verticalController.jumpTo(clampedTarget);
    }

    _pendingAnchorMinutes = null;
  }

  void _handleAutoScroll(double globalDy) {
    if (!_verticalController.hasClients) {
      return;
    }
    final scrollContext = _scrollableKey.currentContext;
    if (scrollContext == null) {
      return;
    }
    final renderBox = scrollContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    final Offset origin = renderBox.localToGlobal(Offset.zero);
    final double top = origin.dy;
    final double bottom = top + renderBox.size.height;

    final position = _verticalController.position;
    final double current = position.pixels;
    final double slotHeight = _resolvedHourHeight / _slotSubdivisions;
    final double stepHeight =
        (_resolvedHourHeight / 60.0) * _minutesPerStep.toDouble();
    final double step =
        (stepHeight * _autoScrollStepMultiplier).clamp(stepHeight, slotHeight);
    double? target;

    if (globalDy < top + _autoScrollEdgeThreshold && current > 0) {
      target = (current - step).clamp(0.0, position.maxScrollExtent);
    } else if (globalDy > bottom - _autoScrollEdgeThreshold &&
        current < position.maxScrollExtent) {
      target = (current + step).clamp(0.0, position.maxScrollExtent);
    }

    if (target != null && (target - current).abs() > 1) {
      _verticalController.jumpTo(target);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_blocInitialized) {
      _capturedBloc = context.read<T>();
      _blocInitialized = true;
    }
  }

  @override
  void dispose() {
    _viewTransitionController.dispose();
    _clockTimer?.cancel();
    _verticalController.dispose();
    _activePopoverEntry?.remove();
    _activePopoverEntry = null;
    _focusNode.dispose();
    _zoomControlsDismissTimer?.cancel();
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

  DateTime _quantizeDropTime(
    DateTime slotTime,
    double localDy,
    double slotHeight,
    int slotMinutes,
  ) {
    final int step = _minutesPerStep;
    if (slotHeight <= 0 || slotMinutes <= 0 || step <= 0) {
      return slotTime;
    }

    final double clampedDy = localDy.clamp(0.0, slotHeight);
    final double ratio = slotHeight == 0 ? 0.0 : clampedDy / slotHeight;
    final double minutesWithinSlot = ratio * slotMinutes;
    final int stepsPerSlot = math.max(1, (slotMinutes / step).round());
    final int stepIndex =
        (minutesWithinSlot / step).round().clamp(0, stepsPerSlot - 1);
    final int snappedMinutes = stepIndex * step;
    return slotTime.add(Duration(minutes: snappedMinutes));
  }

  void _copyTask(CalendarTask task) {
    setState(() {
      _copiedTask = task;
      if (task.scheduledTime != null) {
        _contextMenuPasteSlot = task.scheduledTime;
      }
    });
  }

  void _pasteTask(DateTime slotTime) {
    final template = _copiedTask;
    if (template == null) {
      return;
    }
    _pasteTemplate(template, slotTime);
  }

  void _pasteTemplate(CalendarTask template, DateTime slotTime) {
    final priority = template.priority ?? TaskPriority.none;
    _capturedBloc.add(
      CalendarEvent.taskAdded(
        title: template.title,
        description: template.description,
        scheduledTime: slotTime,
        duration: template.duration,
        deadline: template.deadline,
        location: template.location,
        daySpan: template.daySpan,
        endDate: template.endDate,
        priority: priority,
        startHour: slotTime.hour + (slotTime.minute / 60.0),
        recurrence: template.recurrence,
      ),
    );
  }

  void _showZoomControls() {
    if (!_isZoomEnabled) {
      return;
    }
    _zoomControlsDismissTimer?.cancel();
    if (!_zoomControlsVisible) {
      setState(() {
        _zoomControlsVisible = true;
      });
    }
    _zoomControlsDismissTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _zoomControlsVisible = false;
      });
    });
  }

  void _enterSelectionMode(String taskId) {
    _capturedBloc.add(CalendarEvent.selectionModeEntered(taskId: taskId));
  }

  void _toggleTaskSelection(String taskId) {
    _capturedBloc.add(CalendarEvent.selectionToggled(taskId: taskId));
  }

  void _clearSelectionMode() {
    _capturedBloc.add(const CalendarEvent.selectionCleared());
  }

  void _handleTaskDragStarted(CalendarTask task) {
    setState(() {
      _draggingTaskId = task.id;
      _draggingTaskBaseId = task.baseId;
      _dragPreviewStart = null;
      _dragPreviewDuration = null;
    });
  }

  void _handleTaskDragEnded(CalendarTask task) {
    if (_draggingTaskId == null &&
        _draggingTaskBaseId == null &&
        _dragPreviewStart == null &&
        _dragPreviewDuration == null) {
      return;
    }
    setState(() {
      _draggingTaskId = null;
      _draggingTaskBaseId = null;
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

  static const double timeColumnWidth = 80.0;
  double _getHourHeight(BuildContext context, bool compact) {
    return _resolvedHourHeight;
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

    final gridBody = Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          _buildDayHeaders(headerDates, compact),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                final isDayView = widget.state.viewMode == CalendarView.day;
                _resolvedHourHeight = _resolveHourHeight(
                  availableHeight,
                  isDayView: isDayView,
                );
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xfffafbfc),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: SingleChildScrollView(
                    key: _scrollableKey,
                    controller: _verticalController,
                    child: AnimatedBuilder(
                      animation: _viewTransitionAnimation,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _viewTransitionAnimation,
                          child:
                              _buildGridContent(isWeekView, weekDates, compact),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    return FocusableActionDetector(
      focusNode: _focusNode,
      autofocus: true,
      shortcuts: _zoomShortcuts,
      actions: {
        _ZoomIntent: CallbackAction<_ZoomIntent>(
          onInvoke: (intent) {
            switch (intent.action) {
              case _ZoomAction.zoomIn:
                zoomIn();
                break;
              case _ZoomAction.zoomOut:
                zoomOut();
                break;
              case _ZoomAction.reset:
                zoomReset();
                break;
            }
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => _focusNode.requestFocus(),
        child: Stack(
          children: [
            Positioned.fill(child: gridBody),
            if (_isZoomEnabled && _zoomControlsVisible)
              Positioned(
                top: 8,
                right: compact ? 8 : 16,
                child: _buildZoomControls(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Material(
      elevation: 3,
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Zoom out (Ctrl/Cmd + -)',
              child: IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: _canZoomOut ? zoomOut : null,
                icon: const Icon(Icons.remove),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _zoomLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Tooltip(
              message: 'Zoom in (Ctrl/Cmd + +)',
              child: IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: _canZoomIn ? zoomIn : null,
                icon: const Icon(Icons.add),
              ),
            ),
            Tooltip(
              message: 'Reset zoom (Ctrl/Cmd + 0)',
              child: IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: _zoomIndex == _defaultZoomIndex ? null : zoomReset,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _resolveHourHeight(double availableHeight, {required bool isDayView}) {
    final zoom = _currentZoom;
    final double desiredHourHeight = isDayView ? 192.0 : zoom.hourHeight;
    final int subdivisions =
        isDayView ? _dayViewSubdivisions : zoom.daySubdivisions;
    final baseSlotHeight = desiredHourHeight / subdivisions;
    final totalSlots = (endHour - startHour + 1) * subdivisions;

    if (!availableHeight.isFinite || availableHeight <= 0) {
      return desiredHourHeight;
    }

    final minRequiredHeight = totalSlots * baseSlotHeight;
    if (availableHeight <= minRequiredHeight) {
      return desiredHourHeight;
    }

    final slotHeight = availableHeight / totalSlots;
    if (isDayView) {
      final double computedHourHeight = slotHeight * subdivisions;
      return math.max<double>(desiredHourHeight, computedHourHeight);
    }

    return math.max<double>(desiredHourHeight, slotHeight);
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

    const double usableLeft = margin;
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
                    value: _capturedBloc,
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
                            _closeTaskPopover(taskId, reason: 'task-deleted');
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
          border: const Border(
            right: BorderSide(color: calendarBorderDarkColor),
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
    final hourHeight = _getHourHeight(context, compact);
    final subdivisions = _slotSubdivisions;
    final slotHeight = hourHeight / subdivisions;
    final totalSlots = (endHour - startHour + 1) * subdivisions;
    final minutesPerSlot = _minutesPerSlot;

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
          final totalMinutes = (startHour * 60) + (index * minutesPerSlot);
          final hour = totalMinutes ~/ 60;
          final minute = totalMinutes % 60;
          final isFirstSlot = index == 0;
          final isHourBoundary = minute == 0;
          final isCurrentTime =
              _isCurrentTimeSlot(hour, minute, minutesPerSlot);

          final borderColor = isFirstSlot
              ? Colors.transparent
              : isHourBoundary
                  ? calendarBorderDarkColor
                  : calendarBorderColor.withValues(alpha: 0.3);
          final double borderWidth = isFirstSlot
              ? 0.0
              : isHourBoundary
                  ? 1.0
                  : 0.5;

          String? label;
          if (isHourBoundary) {
            label = _formatHour(hour);
          } else if (minutesPerSlot <= 30) {
            label = ':${minute.toString().padLeft(2, '0')}';
          }

          return Container(
            height: slotHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(
                top: BorderSide(color: borderColor, width: borderWidth),
              ),
            ),
            child: label == null
                ? const SizedBox.shrink()
                : Text(
                    label,
                    style: calendarTimeLabelTextStyle.copyWith(
                      fontSize: isHourBoundary ? (compact ? 10 : 11) : 9,
                      fontWeight:
                          isCurrentTime ? FontWeight.w600 : FontWeight.w400,
                      color: isCurrentTime
                          ? calendarTitleColor
                          : calendarTimeLabelColor,
                    ),
                  ),
          );
        }),
      ),
    );
  }

  bool _isCurrentTimeSlot(int hour, int minute, int slotMinutes) {
    final now = DateTime.now();
    if (now.hour != hour) {
      return false;
    }
    final slotIndex = minute ~/ slotMinutes;
    final nowIndex = now.minute ~/ slotMinutes;
    return slotIndex == nowIndex;
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
          final double hourHeight = _getHourHeight(context, compact);
          final int subdivisions = _slotSubdivisions;
          final double slotHeight = hourHeight / subdivisions;
          final int minutesPerSlot = _minutesPerSlot;

          DateTime effectivePasteSlot() {
            if (_contextMenuPasteSlot != null) {
              return _contextMenuPasteSlot!;
            }
            return _slotTimeFromOffset(
              day: date,
              dy: 0,
              slotHeight: slotHeight,
              minutesPerSlot: minutesPerSlot,
              subdivisions: subdivisions,
            );
          }

          Widget content = Stack(
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

          if (_copiedTask != null) {
            content = ShadContextMenuRegion(
              items: [
                ShadContextMenuItem(
                  leading: const Icon(Icons.content_paste_outlined),
                  onPressed: () => _pasteTask(effectivePasteSlot()),
                  child: const Text('Paste Task Here'),
                ),
              ],
              child: content,
            );
          }

          return Listener(
            behavior: HitTestBehavior.deferToChild,
            onPointerDown: (event) {
              if (_copiedTask == null) {
                return;
              }
              final DateTime slot = _slotTimeFromOffset(
                day: date,
                dy: event.localPosition.dy,
                slotHeight: slotHeight,
                minutesPerSlot: minutesPerSlot,
                subdivisions: subdivisions,
              );
              final current = _contextMenuPasteSlot;
              if (current == null || !current.isAtSameMomentAs(slot)) {
                setState(() {
                  _contextMenuPasteSlot = slot;
                });
              }
            },
            child: content,
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
    final subdivisions = _slotSubdivisions;
    final slotHeight = hourHeight / subdivisions;
    final double slotMinutes = _minutesPerSlot.toDouble();
    final double rawOffset = (minutesFromStart / slotMinutes) * slotHeight - 4;
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
    final subdivisions = _slotSubdivisions;
    final slotHeight = hourHeight / subdivisions;
    final totalSlots = (endHour - startHour + 1) * subdivisions;
    final minutesPerSlot = _minutesPerSlot;

    return Column(
      children: List.generate(totalSlots, (index) {
        final totalMinutes = (startHour * 60) + (index * minutesPerSlot);
        final hour = totalMinutes ~/ 60;
        final minute = totalMinutes % 60;
        final isFirstSlot = index == 0;
        final targetDate = date ?? widget.state.selectedDate;

        final backgroundColor = isToday
            ? (hour % 2 == 0
                ? const Color(0xff0969DA).withValues(alpha: 0.01)
                : const Color(0xff0969DA).withValues(alpha: 0.02))
            : (hour % 2 == 0 ? Colors.white : const Color(0xfffafbfc));

        final borderColor = isFirstSlot
            ? Colors.transparent
            : minute == 0
                ? calendarBorderColor
                : calendarBorderColor.withValues(alpha: 0.3);
        final double borderWidth = isFirstSlot
            ? 0.0
            : minute == 0
                ? 1.0
                : 0.5;

        return Container(
          height: slotHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              top: BorderSide(color: borderColor, width: borderWidth),
            ),
          ),
          child: Builder(
            builder: (context) {
              return _buildSlotDragTarget(
                context: context,
                targetDate: targetDate,
                hour: hour,
                minute: minute,
                slotMinutes: minutesPerSlot,
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildSlotDragTarget({
    required BuildContext context,
    required DateTime targetDate,
    required int hour,
    required int minute,
    required int slotMinutes,
  }) {
    final slotDuration = Duration(minutes: slotMinutes);
    final int subdivisions = _slotSubdivisions;
    final double slotHeight = subdivisions == 0
        ? _resolvedHourHeight
        : _resolvedHourHeight / subdivisions;
    final DateTime slotTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );

    return DragTarget<CalendarTask>(
      onWillAcceptWithDetails: (details) {
        final task = details.data;
        final Duration duration = task.duration ?? const Duration(hours: 1);
        final renderBox = context.findRenderObject() as RenderBox?;
        final DateTime previewStart;
        if (renderBox == null || slotHeight <= 0) {
          previewStart = slotTime;
        } else {
          final local = renderBox.globalToLocal(details.offset);
          previewStart =
              _quantizeDropTime(slotTime, local.dy, slotHeight, slotMinutes);
        }
        _updateDragPreview(previewStart, duration);
        return true;
      },
      onLeave: (details) {
        if (_isPreviewAnchor(slotTime)) {
          _clearDragPreview();
        }
      },
      onAcceptWithDetails: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        final DateTime dropTime;
        if (renderBox == null || slotHeight <= 0) {
          dropTime = slotTime;
        } else {
          final local = renderBox.globalToLocal(details.offset);
          dropTime =
              _quantizeDropTime(slotTime, local.dy, slotHeight, slotMinutes);
        }
        _clearDragPreview();
        _handleTaskDrop(details.data, dropTime);
      },
      onMove: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize || slotHeight <= 0) {
          return;
        }
        final local = renderBox.globalToLocal(details.offset);
        final task = details.data;
        final DateTime previewStart =
            _quantizeDropTime(slotTime, local.dy, slotHeight, slotMinutes);
        final Duration duration = task.duration ?? const Duration(hours: 1);
        _updateDragPreview(previewStart, duration);
        final global = renderBox.localToGlobal(details.offset);
        _handleAutoScroll(global.dy);
      },
      builder: (context, candidateData, rejectedData) {
        final hasTask = _hasTaskInSlot(targetDate, hour, minute, slotMinutes);
        final isPreviewSlot = _isPreviewSlot(slotTime, slotDuration);
        final isPreviewAnchor = _isPreviewAnchor(slotTime);

        Widget slot = _CalendarSlot(
          isPreviewSlot: isPreviewSlot,
          isPreviewAnchor: isPreviewAnchor,
          cursor: SystemMouseCursors.click,
          splashColor: Colors.blue.withValues(alpha: 0.2),
          highlightColor: Colors.blue.withValues(alpha: 0.1),
          onTap: () => _handleSlotTap(slotTime, hasTask: hasTask),
          child: const SizedBox.expand(),
        );

        final menuItems = <Widget>[];
        final controller = ShadPopoverController();

        if (_copiedTask != null) {
          menuItems.add(
            ShadContextMenuItem(
              leading: const Icon(Icons.content_paste_outlined),
              onPressed: () {
                controller.hide();
                _pasteTask(slotTime);
              },
              child: const Text('Paste Task Here'),
            ),
          );
        }

        if (_isSelectionMode) {
          menuItems.add(
            ShadContextMenuItem(
              leading: const Icon(Icons.highlight_off),
              onPressed: () {
                controller.hide();
                _clearSelectionMode();
              },
              child: const Text('Exit Selection Mode'),
            ),
          );
        }

        if (menuItems.isNotEmpty) {
          slot = ShadContextMenuRegion(
            controller: controller,
            groupId: _contextMenuGroupId,
            items: menuItems,
            child: slot,
          );
        }

        return slot;
      },
    );
  }

  DateTime _slotTimeFromOffset({
    required DateTime day,
    required double dy,
    required double slotHeight,
    required int minutesPerSlot,
    required int subdivisions,
  }) {
    if (minutesPerSlot <= 0) {
      return DateTime(day.year, day.month, day.day, startHour);
    }
    final int totalSlotCount = math.max(
      1,
      (endHour - startHour + 1) * subdivisions,
    );
    final double safeSlotHeight = slotHeight == 0 ? 1 : slotHeight;
    final int rawIndex = (dy / safeSlotHeight).floor();
    final int slotIndex = math.min(
      math.max(rawIndex, 0),
      totalSlotCount - 1,
    );
    final int slotMinutes = slotIndex * minutesPerSlot;
    final int totalMinutes = math.max(0, (endHour - startHour) * 60);
    final int maxMinutesFromStart = math.max(0, totalMinutes - minutesPerSlot);
    final int clampedFromStart = math.min(
      math.max(slotMinutes, 0),
      maxMinutesFromStart,
    );
    final int absoluteMinutes = (startHour * 60) + clampedFromStart;
    final int hour = absoluteMinutes ~/ 60;
    final int minute = absoluteMinutes % 60;

    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  bool _hasTaskInSlot(DateTime? date, int hour, int minute, int slotMinutes) {
    if (date == null) return false;

    final tasks = _getTasksForDay(date);
    final slotStart = DateTime(date.year, date.month, date.day, hour, minute);
    final slotEnd = slotStart.add(Duration(minutes: slotMinutes));
    final draggingId = _draggingTaskId;
    final draggingBaseId = _draggingTaskBaseId;

    return tasks.any((task) {
      if (task.scheduledTime == null) return false;
      if (draggingId != null &&
          (task.id == draggingId || task.baseId == draggingBaseId)) {
        return false;
      }

      final taskStart = task.scheduledTime!;
      final taskEnd = taskStart.add(task.duration ?? const Duration(hours: 1));

      // Check if task overlaps with this time slot
      return taskStart.isBefore(slotEnd) && taskEnd.isAfter(slotStart);
    });
  }

  void _handleSlotTap(DateTime slotTime, {required bool hasTask}) {
    if (hasTask) {
      _zoomToCell(slotTime);
      return;
    }
    if (widget.state.viewMode == CalendarView.day) {
      final normalizedDate =
          DateTime(slotTime.year, slotTime.month, slotTime.day);
      if (!DateUtils.isSameDay(widget.state.selectedDate, normalizedDate)) {
        widget.onDateSelected(normalizedDate);
      }
    }
    widget.onEmptySlotTapped?.call(slotTime, Offset.zero);
  }

  void _handleResizePreview(CalendarTask task) {
    setState(() {
      _resizePreviews[task.id] = task;
    });
  }

  void _handleResizeCommit(CalendarTask task) {
    setState(() {
      _resizePreviews.remove(task.id);
    });
    if (widget.onTaskDragEnd != null && task.scheduledTime != null) {
      final original = widget.state.model.tasks[task.baseId];
      if (original != null &&
          original.scheduledTime == task.scheduledTime &&
          original.duration == task.duration) {
        return;
      }
      widget.onTaskDragEnd!(task, task.scheduledTime!);
    }
  }

  void _zoomToCell(DateTime slotTime) {
    if (_isZoomEnabled) {
      _setZoomIndex(_zoomLevels.length - 1);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToSlot(slotTime));
    } else {
      _scrollToSlot(slotTime);
    }
  }

  void _scrollToSlot(DateTime slotTime) {
    if (!_verticalController.hasClients) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToSlot(slotTime));
      return;
    }

    final subdivisions = _slotSubdivisions;
    final double slotMinutes = _minutesPerSlot.toDouble();
    final minutesFromStart =
        (slotTime.hour * 60 + slotTime.minute) - (startHour * 60);
    if (minutesFromStart < 0) {
      return;
    }

    final hourHeight = _resolvedHourHeight;
    final slotHeight = hourHeight / subdivisions;
    final double offset = (minutesFromStart / slotMinutes) * slotHeight;

    final position = _verticalController.position;
    final viewport = position.viewportDimension;
    final target =
        (offset - viewport / 2).clamp(0.0, position.maxScrollExtent).toDouble();

    _verticalController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _handleTaskDrop(CalendarTask task, DateTime dropTime) {
    widget.onTaskDragEnd?.call(task, dropTime);
    _handleTaskDragEnded(task);
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
    final subdivisions = _slotSubdivisions;
    final slotHeight = hourHeight / subdivisions;
    final double slotMinutes = 60 / subdivisions;
    final double offset = (minutesFromStart / slotMinutes) * slotHeight;

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
    final draggingId = _draggingTaskId;
    final draggingBaseId = _draggingTaskBaseId;

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
      final bool isDraggingTask =
          (draggingId != null && task.id == draggingId) ||
              (draggingBaseId != null && task.baseId == draggingBaseId);
      final widget = _buildTaskWidget(
        task,
        overlapInfo,
        compact,
        dayWidth,
        isDayView: isDayView,
        currentDate: date, // Pass the current date for multi-day handling
        weekStartDate: weekStartDate,
        weekEndDate: weekEndDate,
        isPlaceholder: isDraggingTask,
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
      DateTime? weekEndDate,
      bool isPlaceholder = false}) {
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
    final topOffset = (startTimeHours - startHour) * _resolvedHourHeight;

    // Height is always based on task duration, not day span
    final duration = task.duration ?? const Duration(hours: 1);
    final height = (duration.inMinutes / 60.0) * _resolvedHourHeight;

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
          final double stepHeight =
              (_resolvedHourHeight / 60.0) * _minutesPerStep.toDouble();

          if (isPlaceholder) {
            return IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: 0.45,
                child: ResizableTaskWidget(
                  key: ValueKey('${task.id}-ghost'),
                  task: task,
                  onResizePreview: _handleResizePreview,
                  onResizeEnd: _handleResizeCommit,
                  hourHeight: _resolvedHourHeight,
                  stepHeight: stepHeight,
                  minutesPerStep: _minutesPerStep,
                  width: eventWidth,
                  height: clampedHeight,
                  isDayView: isDayView,
                  enableInteractions: false,
                  isSelectionMode: _isSelectionMode,
                  isSelected: _isTaskSelected(task),
                ),
              ),
            );
          }

          final menuController = ShadPopoverController();
          final bool isSelected = _isTaskSelected(task);
          final bool selectionMode = _isSelectionMode;
          final menuItems = <Widget>[
            ShadContextMenuItem(
              leading: const Icon(Icons.copy_outlined),
              onPressed: () {
                menuController.hide();
                _copyTask(task);
              },
              child: const Text('Copy Task'),
            ),
          ];

          if (_copiedTask != null && task.scheduledTime != null) {
            menuItems.add(
              ShadContextMenuItem(
                leading: const Icon(Icons.content_paste_outlined),
                onPressed: () {
                  menuController.hide();
                  _pasteTask(task.scheduledTime!);
                },
                child: const Text('Paste Task Here'),
              ),
            );
          }

          final String selectionLabel;
          if (selectionMode) {
            selectionLabel = isSelected ? 'Deselect Task' : 'Add to Selection';
          } else {
            selectionLabel = 'Select Task';
          }

          menuItems.add(
            ShadContextMenuItem(
              leading: Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              ),
              onPressed: () {
                menuController.hide();
                if (selectionMode) {
                  _toggleTaskSelection(task.baseId);
                } else {
                  _enterSelectionMode(task.baseId);
                }
              },
              child: Text(selectionLabel),
            ),
          );

          if (selectionMode) {
            menuItems.add(
              ShadContextMenuItem(
                leading: const Icon(Icons.highlight_off),
                onPressed: () {
                  menuController.hide();
                  _clearSelectionMode();
                },
                child: const Text('Exit Selection Mode'),
              ),
            );
          }

          return KeyedSubtree(
            key: globalKey,
            child: ShadContextMenuRegion(
              controller: menuController,
              groupId: _contextMenuGroupId,
              items: menuItems,
              child: ResizableTaskWidget(
                key: ValueKey(task.id),
                task: task,
                onResizePreview: _handleResizePreview,
                onResizeEnd: _handleResizeCommit,
                onDragUpdate: (details) =>
                    _handleAutoScroll(details.globalPosition.dy),
                onResizeAutoScroll: _handleAutoScroll,
                hourHeight: _resolvedHourHeight,
                stepHeight: stepHeight,
                minutesPerStep: _minutesPerStep,
                width: eventWidth,
                height: clampedHeight,
                isDayView: isDayView,
                isPopoverOpen: isPopoverOpen,
                enableInteractions: true,
                isSelectionMode: selectionMode,
                isSelected: isSelected,
                onToggleSelection: () {
                  if (selectionMode) {
                    _toggleTaskSelection(task.baseId);
                  } else {
                    _enterSelectionMode(task.baseId);
                  }
                },
                onDragStarted: _handleTaskDragStarted,
                onDragEnded: _handleTaskDragEnded,
                onTap: (tappedTask, bounds) {
                  _onScheduledTaskTapped(tappedTask, bounds);
                },
              ),
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
    return tasks.where((task) => task.scheduledTime != null).map((task) {
      final preview = _resizePreviews[task.id];
      return preview ?? task;
    }).toList()
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

class _ZoomIntent extends Intent {
  const _ZoomIntent(this.action);

  final _ZoomAction action;
}

enum _ZoomAction { zoomIn, zoomOut, reset }

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
