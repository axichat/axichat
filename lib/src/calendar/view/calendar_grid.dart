import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';
import 'edit_task_dropdown.dart';
import 'layout/calendar_layout.dart'
    show
        CalendarLayoutCalculator,
        CalendarLayoutMetrics,
        CalendarLayoutTheme,
        CalendarZoomLevel,
        kCalendarZoomLevels;
import 'controllers/zoom_controls_controller.dart';
import 'controllers/task_interaction_controller.dart';
import 'controllers/task_popover_controller.dart';
import 'controllers/slot_drag_controller.dart';
import 'resizable_task_widget.dart';
import 'widgets/calendar_task_entries_builder.dart';
import 'widgets/calendar_task_surface.dart';

export 'layout/calendar_layout.dart' show OverlapInfo, calculateOverlapColumns;

class CalendarGrid<T extends BaseCalendarBloc> extends StatefulWidget {
  final CalendarState state;
  final Function(DateTime, Offset)? onEmptySlotTapped;
  final Function(CalendarTask, DateTime)? onTaskDragEnd;
  final void Function(DateTime date) onDateSelected;
  final void Function(CalendarView view) onViewChanged;
  final TaskFocusRequest? focusRequest;

  const CalendarGrid({
    super.key,
    required this.state,
    this.onEmptySlotTapped,
    this.onTaskDragEnd,
    required this.onDateSelected,
    required this.onViewChanged,
    this.focusRequest,
  });

  @override
  State<CalendarGrid<T>> createState() => _CalendarGridState<T>();
}

class _CalendarGridState<T extends BaseCalendarBloc>
    extends State<CalendarGrid<T>> with TickerProviderStateMixin {
  static const int startHour = 0;
  static const int endHour = 24;
  static const int _defaultZoomIndex = 0;
  static const int _resizeStepMinutes = 15;
  static const List<CalendarZoomLevel> _zoomLevels = kCalendarZoomLevels;
  static const CalendarLayoutTheme _layoutTheme = CalendarLayoutTheme.material;

  double get _edgeScrollFastBandHeight => _layoutTheme.edgeScrollFastBandHeight;
  double get _edgeScrollSlowBandHeight => _layoutTheme.edgeScrollSlowBandHeight;
  double get _edgeScrollFastOffsetPerFrame =>
      _layoutTheme.edgeScrollFastOffsetPerFrame;
  double get _edgeScrollSlowOffsetPerFrame =>
      _layoutTheme.edgeScrollSlowOffsetPerFrame;
  double get _taskPopoverHorizontalGap => _layoutTheme.popoverGap;
  double get _zoomControlsElevation => _layoutTheme.zoomControlsElevation;
  double get _zoomControlsBorderRadius => _layoutTheme.zoomControlsBorderRadius;
  double get _zoomControlsPaddingHorizontal =>
      _layoutTheme.zoomControlsPaddingHorizontal;
  double get _zoomControlsPaddingVertical =>
      _layoutTheme.zoomControlsPaddingVertical;
  double get _zoomControlsLabelPaddingHorizontal =>
      _layoutTheme.zoomControlsLabelPaddingHorizontal;
  double get _zoomControlsIconSize => _layoutTheme.zoomControlsIconSize;

  late AnimationController _viewTransitionController;
  late Animation<double> _viewTransitionAnimation;
  late final ScrollController _verticalController;
  final GlobalKey _scrollableKey =
      GlobalKey(debugLabel: 'CalendarVerticalScroll');
  final FocusNode _focusNode = FocusNode(debugLabel: 'CalendarGridFocus');
  Timer? _clockTimer;
  bool _hasAutoScrolled = false;
  OverlayEntry? _activePopoverEntry;
  final CalendarLayoutCalculator _layoutCalculator =
      const CalendarLayoutCalculator();
  CalendarLayoutMetrics _currentLayoutMetrics = const CalendarLayoutMetrics(
    hourHeight: 78,
    slotHeight: 78,
    minutesPerSlot: 60,
    slotsPerHour: 1,
  );

  int _zoomIndex = _defaultZoomIndex;
  double _resolvedHourHeight = 78;
  double? _pendingAnchorMinutes;

  late T _capturedBloc;
  bool _blocInitialized = false;
  late final TaskInteractionController _taskInteractionController;
  late final TaskPopoverController _taskPopoverController;
  late final ZoomControlsController _zoomControlsController;
  late final CalendarSlotDragController _slotDragController;
  static const ValueKey<String> _contextMenuGroupId =
      ValueKey<String>('calendar-grid-context');
  Ticker? _edgeAutoScrollTicker;
  final Map<String, CalendarTask> _visibleTasks = <String, CalendarTask>{};
  final Map<String, Rect> _visibleTaskRects = <String, Rect>{};
  double _edgeAutoScrollOffsetPerFrame = 0;
  bool get _isWidthDebounceActive =>
      _taskInteractionController.isWidthDebounceActive;
  int? _lastHandledFocusToken;

  bool get _shouldFreezeWidth =>
      !_taskInteractionController.dragHasMoved && _isWidthDebounceActive;

  @override
  void initState() {
    super.initState();
    _viewTransitionController = AnimationController(
      duration: calendarViewTransitionDuration,
      vsync: this,
    );
    _viewTransitionAnimation = CurvedAnimation(
      parent: _viewTransitionController,
      curve: Curves.easeInOut,
    );
    _viewTransitionController.value = 1.0; // Start fully visible
    _verticalController = ScrollController();
    _taskInteractionController = TaskInteractionController();
    _slotDragController = CalendarSlotDragController(
      interactionController: _taskInteractionController,
      getTasksForDay: _getTasksForDay,
      getMinutesPerSlot: () => _minutesPerSlot,
      getMinutesPerStep: () => _minutesPerStep,
      getStartHour: () => startHour,
      getEndHour: () => endHour,
      getResolvedHourHeight: () => _resolvedHourHeight,
    );
    _taskPopoverController = TaskPopoverController();
    _zoomControlsController = ZoomControlsController(
      autoHideDuration: Duration.zero,
      initiallyVisible: true,
    );
    _clockTimer = Timer.periodic(_layoutTheme.clockTickInterval, (_) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoScroll());
  }

  CalendarZoomLevel get _currentZoom => _zoomLevels[_zoomIndex];
  int get _slotSubdivisions => _currentLayoutMetrics.slotsPerHour;
  int get _minutesPerSlot => _currentLayoutMetrics.minutesPerSlot;
  int get _minutesPerStep => _resizeStepMinutes;
  bool get _canZoomIn => _zoomIndex < _zoomLevels.length - 1;
  bool get _canZoomOut => _zoomIndex > 0;
  bool get _isZoomEnabled => widget.state.viewMode != CalendarView.day;
  bool get _isSelectionMode => widget.state.isSelectionMode;
  Set<String> get _selectedTaskIds => widget.state.selectedTaskIds;

  bool _isTaskSelected(CalendarTask task) {
    return _selectedTaskIds.contains(task.id);
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
    return _currentZoom.label;
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
    final int subdivisions = _slotSubdivisions;
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
    final int subdivisions = _slotSubdivisions;
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

  void _handleEdgeAutoScrollMove(double offsetPerFrame, Offset globalPosition) {
    if (!_verticalController.hasClients) {
      return;
    }
    _edgeAutoScrollOffsetPerFrame = offsetPerFrame;
    _edgeAutoScrollTicker ??= createTicker(_onEdgeAutoScrollTick);
    if (!(_edgeAutoScrollTicker!.isActive)) {
      _edgeAutoScrollTicker!.start();
    }
  }

  void _onEdgeAutoScrollTick(Duration elapsed) {
    if (_edgeAutoScrollOffsetPerFrame.abs() < 0.01 ||
        !_verticalController.hasClients) {
      _stopEdgeAutoScroll();
      return;
    }

    final position = _verticalController.position;
    final double nextOffset =
        (_verticalController.offset + _edgeAutoScrollOffsetPerFrame)
            .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((nextOffset - _verticalController.offset).abs() <= 0.1) {
      _stopEdgeAutoScroll();
      return;
    }

    _verticalController.jumpTo(nextOffset);
  }

  void _stopEdgeAutoScroll() {
    _edgeAutoScrollOffsetPerFrame = 0;
    if (_edgeAutoScrollTicker?.isActive ?? false) {
      _edgeAutoScrollTicker!.stop();
    }
  }

  void _setDragFeedbackHint(
    DragFeedbackHint hint, {
    bool deferWhenBuilding = true,
  }) {
    if (_taskInteractionController.feedbackHint.value == hint) {
      return;
    }

    void apply() {
      if (!mounted) return;
      _taskInteractionController.setFeedbackHint(hint);
    }

    if (!deferWhenBuilding) {
      apply();
      return;
    }

    final scheduler = SchedulerBinding.instance;
    switch (scheduler.schedulerPhase) {
      case SchedulerPhase.idle:
      case SchedulerPhase.postFrameCallbacks:
        apply();
        break;
      default:
        scheduler.addPostFrameCallback((_) => apply());
    }
  }

  void _updateDragFeedbackWidth(
    double width, {
    bool forceCenterPointer = false,
    bool forceApply = false,
  }) {
    if (width <= 0) {
      return;
    }

    final double currentWidth = _taskInteractionController.activeDragWidth ??
        _taskInteractionController.draggingTaskWidth ??
        width;
    final double diff = width - currentWidth;

    if (forceApply) {
      _cancelPendingDragWidth();
      _applyDragFeedbackWidthNow(
        width,
        forceCenterPointer: forceCenterPointer && width < currentWidth,
      );
      return;
    }

    bool applyImmediately = forceCenterPointer;
    if (!applyImmediately) {
      if (diff < 0) {
        applyImmediately = true;
      } else if (diff.abs() <= 0.5) {
        applyImmediately = true;
      }
    }

    if (applyImmediately) {
      _cancelPendingDragWidth();
      _applyDragFeedbackWidthNow(width, forceCenterPointer: forceCenterPointer);
      return;
    }

    final bool widthChanged = diff.abs() > 0.5;
    if (!widthChanged) {
      return;
    }

    if (_taskInteractionController.shouldReusePendingWidth(
      width: width,
      forceCenter: forceCenterPointer,
    )) {
      return;
    }

    _taskInteractionController.schedulePendingWidth(
      width: width,
      forceCenter: forceCenterPointer,
      delay: _layoutTheme.dragWidthDebounceDelay,
      onApply: () {
        if (!mounted) {
          return;
        }
        _applyDragFeedbackWidthNow(
          width,
          forceCenterPointer: forceCenterPointer,
        );
      },
    );
  }

  void _cancelPendingDragWidth() {
    _taskInteractionController.cancelPendingWidthTimer();
  }

  void _applyDragFeedbackWidthNow(
    double width, {
    bool forceCenterPointer = false,
  }) {
    final double currentWidth = _taskInteractionController.activeDragWidth ??
        _taskInteractionController.draggingTaskWidth ??
        width;
    final bool widthChanged = (currentWidth - width).abs() > 0.5;
    final bool shouldCenter = forceCenterPointer || widthChanged;
    final double pointerGlobalX = _taskInteractionController
            .dragPointerGlobalX ??
        (_taskInteractionController.dragStartGlobalLeft ?? 0.0) +
            (currentWidth * _taskInteractionController.dragPointerNormalized);
    _setDragFeedbackHint(
      _buildDragHint(
        width: width,
        pointerFraction: shouldCenter ? 0.5 : null,
        anchorDx: _taskInteractionController.dragAnchorDx,
        anchorDy: _taskInteractionController.dragPointerOffsetFromTop,
      ),
    );
    if (shouldCenter) {
      _taskInteractionController.setDragPointerNormalized(0.5);
    }
    _taskInteractionController.dragStartGlobalLeft =
        pointerGlobalX - (width / 2);
    if (width > 0) {
      _taskInteractionController.draggingTaskWidth = width;
      _taskInteractionController.dragAnchorDx =
          width * _taskInteractionController.dragPointerNormalized;
    }
    _taskInteractionController.setActiveDragWidth(width);
  }

  DragFeedbackHint _buildDragHint({
    required double width,
    double? pointerFraction,
    double? anchorDx,
    double? anchorDy,
  }) {
    double baseWidth = width;
    if (!baseWidth.isFinite || baseWidth <= 0) {
      baseWidth = _taskInteractionController.activeDragWidth ??
          _taskInteractionController.draggingTaskWidth ??
          0.0;
    }
    if (baseWidth <= 0) {
      final double anchorX = _taskInteractionController.dragAnchorDx ?? 0.0;
      final double anchorY =
          _taskInteractionController.dragPointerOffsetFromTop ?? 0.0;
      return DragFeedbackHint(
        width: 0.0,
        pointerOffset: 0.0,
        anchorDx: anchorX,
        anchorDy: anchorY,
      );
    }

    final double normalized = pointerFraction != null
        ? pointerFraction.clamp(0.0, 1.0)
        : _taskInteractionController.dragPointerNormalized.clamp(0.0, 1.0);

    if (pointerFraction != null) {
      _taskInteractionController.setDragPointerNormalized(normalized);
    }

    final double pointerOffset = (baseWidth * normalized).clamp(0.0, baseWidth);
    final double anchorX =
        anchorDx ?? _taskInteractionController.dragAnchorDx ?? pointerOffset;
    final double anchorY =
        anchorDy ?? _taskInteractionController.dragPointerOffsetFromTop ?? 0.0;

    _taskInteractionController.setActiveDragWidth(baseWidth);

    return DragFeedbackHint(
      width: baseWidth,
      pointerOffset: pointerOffset,
      anchorDx: anchorX,
      anchorDy: anchorY,
    );
  }

  void _resetDragFeedbackHint() {
    final double width = _taskInteractionController.activeDragWidth ??
        _taskInteractionController.draggingTaskWidth ??
        0.0;
    if (width <= 0) {
      _setDragFeedbackHint(
        DragFeedbackHint(
          width: 0.0,
          pointerOffset: 0.0,
          anchorDx: _taskInteractionController.dragAnchorDx ?? 0.0,
          anchorDy: _taskInteractionController.dragPointerOffsetFromTop ?? 0.0,
        ),
      );
      return;
    }
    _updateDragFeedbackWidth(width);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_blocInitialized) {
      _capturedBloc = context.read<T>();
      _blocInitialized = true;
    }
    _processFocusRequest(widget.focusRequest);
  }

  @override
  void dispose() {
    _viewTransitionController.dispose();
    _clockTimer?.cancel();
    _verticalController.dispose();
    _activePopoverEntry?.remove();
    _activePopoverEntry = null;
    _focusNode.dispose();
    _zoomControlsController.dispose();
    _edgeAutoScrollTicker?.dispose();
    _taskInteractionController.dispose();
    _taskPopoverController.dispose();
    super.dispose();
  }

  void _updateDragPreview(DateTime start, Duration duration) {
    final DragPreview? current = _taskInteractionController.preview.value;
    final bool startChanged =
        current == null || !current.start.isAtSameMomentAs(start);
    final bool durationChanged =
        current == null || current.duration != duration;
    if (!startChanged && !durationChanged) {
      return;
    }

    _taskInteractionController.updatePreview(start, duration);

    final origin = _taskInteractionController.dragOriginSlot;
    if (!_taskInteractionController.dragHasMoved &&
        !_isWidthDebounceActive &&
        origin != null &&
        !start.isAtSameMomentAs(origin)) {
      _taskInteractionController.markDragMoved();
    }
  }

  void _clearDragPreview() {
    _taskInteractionController.clearPreview();
  }

  void _copyTask(CalendarTask task) {
    _taskInteractionController.setClipboardTemplate(task);
  }

  void _pasteTask(DateTime slotTime) {
    final template = _taskInteractionController.clipboardTemplate;
    if (template == null) {
      return;
    }
    _pasteTemplate(template, slotTime);
  }

  void _pasteTemplate(CalendarTask template, DateTime slotTime) {
    _capturedBloc.add(
      CalendarEvent.taskRepeated(
        template: template,
        scheduledTime: slotTime,
      ),
    );
  }

  void _showZoomControls() {}

  void _enterSelectionMode(String taskId) {
    _capturedBloc.add(CalendarEvent.selectionModeEntered(taskId: taskId));
  }

  void _toggleTaskSelection(String taskId) {
    _capturedBloc.add(CalendarEvent.selectionToggled(taskId: taskId));
  }

  void _clearSelectionMode() {
    _capturedBloc.add(const CalendarEvent.selectionCleared());
  }

  void _handleTaskDragStarted(CalendarTask task, Rect bounds) {
    _stopEdgeAutoScroll();
    _cancelPendingDragWidth();
    final double pickupNormalizedX =
        _taskInteractionController.dragPointerNormalized.clamp(0.0, 1.0);
    final double pickupGlobalX =
        bounds.left + (bounds.width * pickupNormalizedX);
    _taskInteractionController.clearPreview();
    _taskInteractionController.beginDrag(
      task: task,
      snapshot: task,
      bounds: bounds,
      pointerNormalized: pickupNormalizedX,
      pointerGlobalX: pickupGlobalX,
      originSlot: _slotDragController.computeOriginSlot(task.scheduledTime),
    );
    _taskInteractionController.dragPointerOffsetFromTop = null;
    _taskInteractionController.setDragPointerNormalized(0.5);
    if (_taskInteractionController.draggingTaskWidth != null) {
      _taskInteractionController.dragAnchorDx =
          _taskInteractionController.draggingTaskWidth! *
              _taskInteractionController.dragPointerNormalized;
      _taskInteractionController.setActiveDragWidth(
        _taskInteractionController.draggingTaskWidth!,
      );
    }
    _setDragFeedbackHint(
      _buildDragHint(
        width: bounds.width,
        pointerFraction: 0.5,
        anchorDx: _taskInteractionController.dragAnchorDx,
        anchorDy: _taskInteractionController.dragPointerOffsetFromTop,
      ),
      deferWhenBuilding: false,
    );
  }

  void _handleDragPointerDown(Offset normalizedOffset) {
    _taskInteractionController
        .setDragPointerNormalized(normalizedOffset.dx.clamp(0.0, 1.0));
    _taskInteractionController.dragPointerOffsetFromTop = null;
    _taskInteractionController.dragHasMoved = false;
  }

  void _handleTaskPointerDown(CalendarTask task, Offset normalizedOffset) {
    _handleDragPointerDown(normalizedOffset);
  }

  void _splitTask(CalendarTask task, DateTime splitTime) {
    _capturedBloc.add(
      CalendarEvent.taskSplit(
        target: task,
        splitTime: splitTime,
      ),
    );
  }

  void _handleTaskDragUpdate(DragUpdateDetails details) {
    final double? startLeft = _taskInteractionController.dragStartGlobalLeft;
    final double baseWidth = _taskInteractionController.dragInitialWidth ??
        _taskInteractionController.draggingTaskWidth ??
        0.0;
    if (startLeft == null || baseWidth <= 0) {
      return;
    }
    _taskInteractionController.setDragPointerGlobalX(details.globalPosition.dx);
    final double widthForNormalization =
        _taskInteractionController.activeDragWidth ??
            _taskInteractionController.draggingTaskWidth ??
            baseWidth;
    final double normalized = widthForNormalization <= 0
        ? 0.5
        : ((details.globalPosition.dx - startLeft) / widthForNormalization)
            .clamp(0.0, 1.0);
    const double movementThreshold = 0.001;
    if ((_taskInteractionController.dragPointerNormalized - normalized).abs() >
        movementThreshold) {
      _taskInteractionController.markDragMoved();
    }
    _taskInteractionController.setDragPointerNormalized(normalized);
    final double effectiveWidth = _taskInteractionController.activeDragWidth ??
        _taskInteractionController.draggingTaskWidth ??
        baseWidth;
    _updateDragFeedbackWidth(effectiveWidth);
    if (effectiveWidth > 0) {
      _taskInteractionController.dragAnchorDx =
          effectiveWidth * _taskInteractionController.dragPointerNormalized;
    }
  }

  void _handleTaskDragEnded(CalendarTask task) {
    if (_taskInteractionController.draggingTaskId == null &&
        _taskInteractionController.draggingTaskBaseId == null &&
        _taskInteractionController.preview.value == null) {
      return;
    }
    _cancelPendingDragWidth();
    _taskInteractionController.endDrag();
    _stopEdgeAutoScroll();
    _setDragFeedbackHint(
      const DragFeedbackHint(
        width: 0.0,
        pointerOffset: 0.0,
        anchorDx: 0.0,
        anchorDy: 0.0,
      ),
    );
  }

  DateTime _taskTargetDate(CalendarTask task) {
    final DateTime? scheduled = task.scheduledTime;
    if (scheduled != null) {
      return DateTime(scheduled.year, scheduled.month, scheduled.day);
    }
    final DateTime selected = widget.state.selectedDate;
    return DateTime(selected.year, selected.month, selected.day);
  }

  DateTime _defaultPreviewStartForTask(CalendarTask task) {
    final DateTime targetDate = _taskTargetDate(task);
    if (task.scheduledTime != null) {
      return task.scheduledTime!;
    }
    return DateTime(
        targetDate.year, targetDate.month, targetDate.day, startHour);
  }

  DateTime? _computePreviewStartForTaskHover(
    CalendarTask targetTask,
    Offset pointerGlobal,
  ) {
    final DateTime targetDate = _taskTargetDate(targetTask);
    final DateTime? computed =
        _slotDragController.computePreviewStartFromGlobalOffset(
      pointerGlobal,
      targetDate,
    );
    if (computed != null) {
      return computed;
    }
    return _defaultPreviewStartForTask(targetTask);
  }

  bool _doesPreviewOverlap(CalendarTask task) {
    final preview = _taskInteractionController.preview.value;
    if (preview == null) {
      return false;
    }
    if (_taskInteractionController.draggingTaskId != null &&
        task.id == _taskInteractionController.draggingTaskId) {
      return false;
    }
    final taskStart = task.scheduledTime;
    if (taskStart == null) {
      return false;
    }
    final DateTime previewStart = preview.start;
    final DateTime previewEnd = previewStart.add(preview.duration);
    final DateTime taskEnd =
        taskStart.add(task.duration ?? const Duration(hours: 1));
    return previewStart.isBefore(taskEnd) && previewEnd.isAfter(taskStart);
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

    if (widget.focusRequest != null &&
        (oldWidget.focusRequest == null ||
            oldWidget.focusRequest!.token != widget.focusRequest!.token)) {
      _processFocusRequest(widget.focusRequest);
    }
  }

  double get _timeColumnWidth => _layoutTheme.timeColumnWidth;
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
    return AnimatedBuilder(
      animation: _taskPopoverController,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: _taskInteractionController,
          builder: (context, __) {
            final weekDates = _getWeekDates(widget.state.selectedDate);
            final isWeekView = widget.state.viewMode == CalendarView.week;
            final headerDates =
                isWeekView ? weekDates : [widget.state.selectedDate];
            final responsive = ResponsiveHelper.spec(context);

            final gridBody = Container(
              decoration: const BoxDecoration(
                color: calendarBackgroundColor,
                borderRadius: BorderRadius.zero,
                border: Border(
                  top: BorderSide(
                    color: calendarBorderColor,
                    width: calendarBorderStroke,
                  ),
                  left: BorderSide(
                    color: calendarBorderColor,
                    width: calendarBorderStroke,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.gridHorizontalPadding,
                    ),
                    child: _buildDayHeaders(headerDates, compact),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableHeight = constraints.maxHeight;
                        final isDayView =
                            widget.state.viewMode == CalendarView.day;
                        _resolvedHourHeight = _resolveHourHeight(
                          availableHeight,
                          isDayView: isDayView,
                        );
                        return Container(
                          decoration: const BoxDecoration(
                            color: calendarStripedSlotColor,
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
                                  child: _buildGridContent(
                                    isWeekView,
                                    weekDates,
                                    compact,
                                  ),
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
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox.expand(child: gridBody),
                    ..._buildEdgeScrollTargets(),
                    Positioned(
                      bottom: compact ? 12 : 24,
                      right: compact ? 8 : 16,
                      child: _buildZoomControls(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildEdgeScrollTargets() {
    return [
      _buildEdgeScroller(
        top: 0,
        height: _edgeScrollFastBandHeight,
        offsetPerFrame: -_edgeScrollFastOffsetPerFrame,
      ),
      _buildEdgeScroller(
        top: _edgeScrollFastBandHeight,
        height: _edgeScrollSlowBandHeight,
        offsetPerFrame: -_edgeScrollSlowOffsetPerFrame,
      ),
      _buildEdgeScroller(
        bottom: _edgeScrollFastBandHeight,
        height: _edgeScrollSlowBandHeight,
        offsetPerFrame: _edgeScrollSlowOffsetPerFrame,
      ),
      _buildEdgeScroller(
        bottom: 0,
        height: _edgeScrollFastBandHeight,
        offsetPerFrame: _edgeScrollFastOffsetPerFrame,
      ),
    ];
  }

  Widget _buildEdgeScroller({
    double? top,
    double? bottom,
    required double height,
    required double offsetPerFrame,
  }) {
    assert(top != null || bottom != null,
        'Either top or bottom must be provided for edge scroller positioning');

    return Positioned(
      top: top,
      bottom: bottom,
      left: 0,
      right: 0,
      height: height,
      child: DragTarget<CalendarTask>(
        hitTestBehavior: HitTestBehavior.translucent,
        builder: (context, candidateData, rejectedData) =>
            const SizedBox.expand(),
        onWillAcceptWithDetails: (_) => false,
        onAcceptWithDetails: (_) => _stopEdgeAutoScroll(),
        onMove: (details) =>
            _handleEdgeAutoScrollMove(offsetPerFrame, details.offset),
        onLeave: (_) => _stopEdgeAutoScroll(),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Material(
      elevation: _zoomControlsElevation,
      color: calendarBackgroundColor.withValues(
          alpha: calendarZoomControlsBackgroundOpacity),
      borderRadius: BorderRadius.circular(_zoomControlsBorderRadius),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _zoomControlsPaddingHorizontal,
          vertical: _zoomControlsPaddingVertical,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Zoom out (Ctrl/Cmd + -)',
              child: IconButton(
                iconSize: _zoomControlsIconSize,
                visualDensity: VisualDensity.compact,
                onPressed: _isZoomEnabled && _canZoomOut ? zoomOut : null,
                icon: const Icon(Icons.remove),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _zoomControlsLabelPaddingHorizontal,
              ),
              child: Text(
                _zoomLabel,
                style: calendarZoomLabelTextStyle,
              ),
            ),
            Tooltip(
              message: 'Zoom in (Ctrl/Cmd + +)',
              child: IconButton(
                iconSize: _zoomControlsIconSize,
                visualDensity: VisualDensity.compact,
                onPressed: _isZoomEnabled && _canZoomIn ? zoomIn : null,
                icon: const Icon(Icons.add),
              ),
            ),
            Tooltip(
              message: 'Reset zoom (Ctrl/Cmd + 0)',
              child: IconButton(
                iconSize: _zoomControlsIconSize,
                visualDensity: VisualDensity.compact,
                onPressed: (_isZoomEnabled && _zoomIndex != _defaultZoomIndex)
                    ? zoomReset
                    : null,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _resolveHourHeight(double availableHeight, {required bool isDayView}) {
    final metrics = _layoutCalculator.resolveMetrics(
      zoomIndex: _zoomIndex,
      isDayView: isDayView,
      availableHeight: availableHeight,
    );
    _currentLayoutMetrics = metrics;
    return metrics.hourHeight;
  }

  Widget _buildGridContent(
      bool isWeekView, List<DateTime> weekDates, bool compact) {
    final responsive = ResponsiveHelper.spec(context);
    final bool isCompact = responsive.sizeClass == CalendarSizeClass.compact;
    final visibleTaskIds = <String>{};
    _visibleTasks.clear();
    _visibleTaskRects.clear();
    late final Widget content;

    if (isWeekView && isCompact) {
      final double compactDayColumnWidth = ResponsiveHelper.dayColumnWidth(
        context,
        fallback: calendarCompactDayColumnWidth,
      );
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
                    width: compactDayColumnWidth,
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
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.gridHorizontalPadding,
      ),
      child: content,
    );
  }

  void _cleanupTaskPopovers(Set<String> activeIds) {
    final removedIds = _taskPopoverController.cleanupLayouts(activeIds);
    for (final id in removedIds) {
      if (!mounted) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_taskPopoverController.activeTaskId == id) {
          _closeTaskPopover(id, reason: 'cleanup');
        }
      });
    }
  }

  void _updateActivePopoverLayoutForTask(String taskId) {
    final key = _taskPopoverController.getKey(taskId);
    if (key == null) return;
    final context = key.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final rect = offset & renderBox.size;
    final layout = _calculateTaskPopoverLayout(rect);
    _taskPopoverController.setLayout(taskId, layout);
    if (_taskPopoverController.activeTaskId == taskId) {
      _activePopoverEntry?.markNeedsBuild();
    }
  }

  TaskPopoverLayout _calculateTaskPopoverLayout(Rect bounds) {
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final EdgeInsets safePadding = mediaQuery.padding;
    const double dropdownWidth = calendarTaskPopoverWidth;
    const double dropdownMaxHeight = calendarGridPopoverMaxHeight;
    const double minimumHeight = calendarTaskPopoverMinHeight;
    const double usableLeft = calendarPopoverScreenMargin;
    final double usableRight = screenSize.width - calendarPopoverScreenMargin;
    final double usableTop = safePadding.top + calendarPopoverScreenMargin;
    final double usableBottom =
        screenSize.height - safePadding.bottom - calendarPopoverScreenMargin;
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

    return TaskPopoverLayout(
      topLeft: Offset(left, top),
      maxHeight: effectiveMaxHeight,
    );
  }

  void _onScheduledTaskTapped(CalendarTask task, Rect bounds) {
    if (_taskPopoverController.activeTaskId == task.id) {
      _closeTaskPopover(task.id, reason: 'toggle-close');
      return;
    }

    final layout = _calculateTaskPopoverLayout(bounds);
    _openTaskPopover(task, layout);
  }

  void _closeTaskPopover(String taskId, {String reason = 'manual'}) {
    _taskPopoverController.removeLayout(taskId);
    if (_taskPopoverController.activeTaskId != taskId) {
      return;
    }

    _taskPopoverController.deactivate();
    _activePopoverEntry?.remove();
    _activePopoverEntry = null;
  }

  void _openTaskPopover(CalendarTask task, TaskPopoverLayout layout) {
    final activeId = _taskPopoverController.activeTaskId;
    if (activeId != null && activeId != task.id) {
      _closeTaskPopover(activeId, reason: 'switch-target');
    }

    _taskPopoverController.activate(task.id, layout);
    _ensurePopoverEntry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _taskPopoverController.markDismissReady();
      _activePopoverEntry?.markNeedsBuild();
    });
  }

  void _ensurePopoverEntry() {
    if (_activePopoverEntry != null) {
      _activePopoverEntry!.markNeedsBuild();
      return;
    }

    final overlayState = Overlay.of(context, rootOverlay: true);
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    _activePopoverEntry = OverlayEntry(
      builder: (overlayContext) {
        final taskId = _taskPopoverController.activeTaskId;
        if (taskId == null) {
          return const SizedBox.shrink();
        }

        final layout = _taskPopoverController.layoutFor(taskId);

        final renderBox = overlayState.context.findRenderObject() as RenderBox?;
        final offset = renderBox == null
            ? layout.topLeft
            : renderBox.globalToLocal(layout.topLeft);

        const double popoverWidth = calendarTaskPopoverWidth;

        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  final currentId = _taskPopoverController.activeTaskId;
                  if (currentId == null ||
                      !_taskPopoverController.dismissArmed) {
                    return;
                  }

                  final overlayBox =
                      overlayState.context.findRenderObject() as RenderBox?;
                  if (overlayBox == null) {
                    _closeTaskPopover(currentId, reason: 'outside-tap');
                    return;
                  }

                  final popoverLayout =
                      _taskPopoverController.layoutFor(currentId);
                  final Offset topLeft = popoverLayout.topLeft;
                  final Rect popoverRect = Rect.fromLTWH(
                    topLeft.dx,
                    topLeft.dy,
                    calendarTaskPopoverWidth,
                    popoverLayout.maxHeight,
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

                        final CalendarTask? storedTask =
                            state.model.tasks[taskId];
                        final String? occurrenceKey = occurrenceKeyFrom(taskId);
                        final CalendarTask? occurrenceTask =
                            storedTask == null && occurrenceKey != null
                                ? latestTask.occurrenceForId(taskId)
                                : null;
                        final CalendarTask displayTask =
                            storedTask ?? occurrenceTask ?? latestTask;
                        final bool shouldUpdateOccurrence =
                            storedTask == null && occurrenceTask != null;

                        return EditTaskDropdown(
                          task: displayTask,
                          maxHeight: layout.maxHeight,
                          onClose: () => _closeTaskPopover(taskId,
                              reason: 'dropdown-close'),
                          scaffoldMessenger: scaffoldMessenger,
                          onTaskUpdated: (updatedTask) {
                            context.read<T>().add(
                                  CalendarEvent.taskUpdated(
                                    task: updatedTask,
                                  ),
                                );
                          },
                          onOccurrenceUpdated: shouldUpdateOccurrence
                              ? (updatedTask) {
                                  context.read<T>().add(
                                        CalendarEvent.taskOccurrenceUpdated(
                                          taskId: baseId,
                                          occurrenceId: taskId,
                                          scheduledTime:
                                              updatedTask.scheduledTime,
                                          duration: updatedTask.duration,
                                          endDate: updatedTask.endDate,
                                        ),
                                      );

                                  final seriesUpdate = latestTask.copyWith(
                                    title: updatedTask.title,
                                    description: updatedTask.description,
                                    location: updatedTask.location,
                                    deadline: updatedTask.deadline,
                                    priority: updatedTask.priority,
                                    isCompleted: updatedTask.isCompleted,
                                  );

                                  if (seriesUpdate != latestTask) {
                                    context.read<T>().add(
                                          CalendarEvent.taskUpdated(
                                            task: seriesUpdate,
                                          ),
                                        );
                                  }
                                }
                              : null,
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
      _taskPopoverController.markDismissReady();
    });
  }

  Widget _buildDayHeaders(List<DateTime> weekDates, bool compact) {
    return Container(
      height: calendarWeekHeaderHeight,
      decoration: const BoxDecoration(
        color: calendarBackgroundColor,
        border: Border(
          bottom: BorderSide(
              color: calendarBorderColor, width: calendarBorderStroke),
        ),
        borderRadius: BorderRadius.zero, // Remove rounded corners
      ),
      child: Row(
        children: [
          Container(
            width: _timeColumnWidth,
            decoration: const BoxDecoration(
              color: calendarSidebarBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: calendarBorderColor,
                  width: calendarBorderStroke,
                ),
                right: BorderSide(
                    color: calendarBorderColor, width: calendarBorderStroke),
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
              ? calendarPrimaryColor.withValues(
                  alpha: calendarDayHeaderHighlightOpacity)
              : calendarBackgroundColor,
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
              letterSpacing: calendarDayHeaderLetterSpacing,
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
      width: _timeColumnWidth,
      decoration: const BoxDecoration(
        color: calendarSidebarBackgroundColor,
        border: Border(
          right: BorderSide(
            color: calendarBorderDarkColor,
            width: calendarBorderStroke,
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
                  : calendarBorderColor.withValues(
                      alpha: calendarTimeDividerOpacity,
                    );
          final double borderWidth = isFirstSlot
              ? 0.0
              : isHourBoundary
                  ? calendarBorderStroke
                  : calendarSubSlotBorderStroke;

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
            ? calendarPrimaryColor.withValues(
                alpha: calendarTodayColumnHighlightOpacity,
              )
            : Colors.transparent,
        border: const Border(
          right: BorderSide(
            color: calendarBorderDarkColor,
            width: calendarBorderStroke,
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
            final DateTime? stored =
                _taskInteractionController.clipboardPasteSlot;
            if (stored != null) {
              return stored;
            }
            return _slotDragController.slotTimeFromOffset(
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

          if (_taskInteractionController.clipboardTemplate != null) {
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
              if (_taskInteractionController.clipboardTemplate == null) {
                return;
              }
              final DateTime slot = _slotDragController.slotTimeFromOffset(
                day: date,
                dy: event.localPosition.dy,
                slotHeight: slotHeight,
                minutesPerSlot: minutesPerSlot,
                subdivisions: subdivisions,
              );
              final DateTime? current =
                  _taskInteractionController.clipboardPasteSlot;
              if (current == null || !current.isAtSameMomentAs(slot)) {
                _taskInteractionController.updateClipboardPasteSlot(slot);
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
              const SizedBox(width: calendarInsetMd),
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
        final Duration slotDuration = Duration(minutes: minutesPerSlot);
        final DateTime slotTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );

        final backgroundColor = isToday
            ? (hour % 2 == 0
                ? calendarPrimaryColor.withValues(
                    alpha: calendarTodaySlotLightOpacity,
                  )
                : calendarPrimaryColor.withValues(
                    alpha: calendarTodaySlotDarkOpacity,
                  ))
            : (hour % 2 == 0
                ? calendarBackgroundColor
                : calendarStripedSlotColor);

        final borderColor = isFirstSlot
            ? Colors.transparent
            : minute == 0
                ? calendarBorderColor
                : calendarBorderColor.withValues(
                    alpha: calendarTimeDividerOpacity,
                  );
        final double borderWidth = isFirstSlot
            ? 0.0
            : minute == 0
                ? calendarBorderStroke
                : calendarSubSlotBorderStroke;

        final _CalendarSlotBindings slotBindings = _CalendarSlotBindings(
          slotTime: slotTime,
          targetDate: targetDate,
          hour: hour,
          minute: minute,
          slotMinutes: minutesPerSlot,
          slotHeight: slotHeight,
          slotDuration: slotDuration,
          slotDragController: _slotDragController,
          interactionController: _taskInteractionController,
          layoutCalculator: _layoutCalculator,
          shouldFreezeWidth: () => _shouldFreezeWidth,
          updateDragPreview: _updateDragPreview,
          updateDragFeedbackWidth: _updateDragFeedbackWidth,
          cancelPendingDragWidth: _cancelPendingDragWidth,
          resetDragFeedbackHint: _resetDragFeedbackHint,
          handleTaskDrop: _handleTaskDrop,
          clearDragPreview: _clearDragPreview,
          handleSlotTap: _handleSlotTap,
          slotHoverAnimationDuration: _layoutTheme.slotHoverAnimationDuration,
          isSelectionMode: _isSelectionMode,
          clearSelectionMode: _clearSelectionMode,
          clipboardTemplateProvider: () =>
              _taskInteractionController.clipboardTemplate,
          onPasteTemplate: _pasteTask,
          contextMenuGroupId: _contextMenuGroupId,
          isWidthDebounceActive: () => _isWidthDebounceActive,
        );

        return Container(
          height: slotHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              top: BorderSide(color: borderColor, width: borderWidth),
            ),
          ),
          child: _CalendarSlotCell(bindings: slotBindings),
        );
      }),
    );
  }

  void _handleSlotTap(
    DateTime slotTime, {
    required bool hasTask,
    Offset? tapPosition,
    double? slotExtent,
  }) {
    final bool tappedTask = hasTask &&
        tapPosition != null &&
        slotExtent != null &&
        _tapHitsTask(slotTime, tapPosition, slotExtent);
    if (tappedTask) {
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

  bool _tapHitsTask(
      DateTime slotTime, Offset localPosition, double slotExtent) {
    if (slotExtent <= 0 || _minutesPerSlot <= 0) {
      return true;
    }

    final DateTime day = DateTime(slotTime.year, slotTime.month, slotTime.day);
    final tasks = _getTasksForDay(day);
    if (tasks.isEmpty) {
      return false;
    }

    final int slotMinutes = _minutesPerSlot;
    final DateTime slotEnd = slotTime.add(Duration(minutes: slotMinutes));
    final int minutesFromStart =
        (slotTime.hour * 60 + slotTime.minute) - (startHour * 60);
    final double slotsFromStart = minutesFromStart / slotMinutes;
    final double slotTopOffset = slotsFromStart * slotExtent;
    final Offset targetPoint =
        Offset(localPosition.dx, slotTopOffset + localPosition.dy);

    for (final task in tasks) {
      final DateTime? scheduled = task.scheduledTime;
      if (scheduled == null) {
        continue;
      }
      final DateTime taskEnd =
          scheduled.add(task.duration ?? const Duration(hours: 1));
      if (!slotTime.isBefore(taskEnd) || !slotEnd.isAfter(scheduled)) {
        continue;
      }
      final Rect? bounds = _visibleTaskRects[task.id];
      if (bounds != null && bounds.contains(targetPoint)) {
        return true;
      }
    }
    return false;
  }

  void _handleResizePreview(CalendarTask task) {
    _taskInteractionController.setResizePreview(task.id, task);
  }

  void _handleResizeCommit(CalendarTask task) {
    _taskInteractionController.clearResizePreview(task.id);
    _stopEdgeAutoScroll();
    final DateTime? scheduled = task.scheduledTime;
    if (widget.onTaskDragEnd != null && scheduled != null) {
      final CalendarTask? original = widget.state.model.tasks[task.baseId];
      final Duration? taskDuration =
          task.duration ?? task.effectiveEndDate?.difference(scheduled);
      final DateTime? taskEnd = task.effectiveEndDate;

      if (original != null) {
        final DateTime? originalEnd = original.effectiveEndDate;
        final Duration? originalDuration = original.duration ??
            (originalEnd != null && original.scheduledTime != null
                ? originalEnd.difference(original.scheduledTime!)
                : null);

        if (original.scheduledTime == scheduled &&
            originalDuration == taskDuration &&
            originalEnd == taskEnd) {
          return;
        }
      }

      final CalendarTask normalized = task.copyWith(
        duration: taskDuration,
        endDate: taskEnd,
      );

      widget.onTaskDragEnd!(normalized, scheduled);
    }
  }

  void _handleResizeAutoScroll(Offset globalPosition) {
    if (!_verticalController.hasClients) {
      return;
    }
    final BuildContext? scrollContext = _scrollableKey.currentContext;
    if (scrollContext == null) {
      return;
    }

    final RenderObject? renderObject = scrollContext.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    final Offset localPosition = renderObject.globalToLocal(globalPosition);
    final double y = localPosition.dy;
    final double height = renderObject.size.height;
    if (!height.isFinite || height <= 0) {
      return;
    }

    double? offsetPerFrame;
    if (y <= _edgeScrollFastBandHeight || y < 0) {
      offsetPerFrame = -_edgeScrollFastOffsetPerFrame;
    } else if (y <= _edgeScrollFastBandHeight + _edgeScrollSlowBandHeight) {
      offsetPerFrame = -_edgeScrollSlowOffsetPerFrame;
    } else if (y >= height - _edgeScrollFastBandHeight || y > height) {
      offsetPerFrame = _edgeScrollFastOffsetPerFrame;
    } else if (y >=
        height - (_edgeScrollFastBandHeight + _edgeScrollSlowBandHeight)) {
      offsetPerFrame = _edgeScrollSlowOffsetPerFrame;
    }

    if (offsetPerFrame != null) {
      _handleEdgeAutoScrollMove(offsetPerFrame, globalPosition);
    } else {
      _stopEdgeAutoScroll();
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
      duration: _layoutTheme.scrollAnimationDuration,
      curve: Curves.easeOut,
    );
  }

  CalendarTask? _resolveTaskForId(String id, CalendarState state) {
    final CalendarTask? visibleTask = _visibleTasks[id];
    if (visibleTask != null) {
      return visibleTask;
    }
    return state.model.resolveTaskInstance(id);
  }

  void _emitTaskTimeShift(CalendarTask taskInstance, DateTime targetStart) {
    final String taskId = taskInstance.id;
    final CalendarTask? directTask = widget.state.model.tasks[taskId];
    if (directTask != null) {
      _capturedBloc.add(
        CalendarEvent.taskDropped(
          taskId: taskId,
          time: targetStart,
        ),
      );
      return;
    }

    final String baseId = taskInstance.baseId;
    final CalendarTask? baseTask = widget.state.model.tasks[baseId];

    if (taskInstance.isOccurrence && baseTask != null) {
      _capturedBloc.add(
        CalendarEvent.taskOccurrenceUpdated(
          taskId: baseId,
          occurrenceId: taskInstance.id,
          scheduledTime: targetStart,
          duration: taskInstance.duration,
          endDate: taskInstance.endDate,
        ),
      );
      return;
    }

    if (baseTask != null) {
      _capturedBloc.add(
        CalendarEvent.taskDropped(
          taskId: baseId,
          time: targetStart,
        ),
      );
      return;
    }

    widget.onTaskDragEnd?.call(taskInstance, targetStart);
  }

  bool _applySelectionDrag(CalendarTask anchorTask, DateTime dropTime) {
    if (!_isSelectionMode || _selectedTaskIds.isEmpty) {
      return false;
    }

    final bool anchorSelected = _selectedTaskIds.contains(anchorTask.id) ||
        _selectedTaskIds.contains(anchorTask.baseId);
    if (!anchorSelected) {
      return false;
    }

    final DateTime? origin =
        _visibleTasks[anchorTask.id]?.scheduledTime ?? anchorTask.scheduledTime;
    if (origin == null) {
      return false;
    }

    final Duration delta = dropTime.difference(origin);
    final CalendarState state = widget.state;

    if (delta.inMinutes == 0) {
      return true;
    }

    final visited = <String>{};
    for (final id in _selectedTaskIds) {
      final CalendarTask? taskInstance = _resolveTaskForId(id, state);
      if (taskInstance == null || taskInstance.scheduledTime == null) {
        continue;
      }
      final DateTime targetStart = taskInstance.scheduledTime!.add(delta);
      _emitTaskTimeShift(taskInstance, targetStart);
      visited.add(taskInstance.id);
    }

    if (!visited.contains(anchorTask.id)) {
      final CalendarTask resolved = _visibleTasks[anchorTask.id] ?? anchorTask;
      if (resolved.scheduledTime != null) {
        final DateTime targetStart = resolved.scheduledTime!.add(delta);
        _emitTaskTimeShift(resolved, targetStart);
      }
    }

    return true;
  }

  void _handleTaskDrop(CalendarTask task, DateTime dropTime) {
    _handleTaskDragEnded(task);
    final bool handled = _applySelectionDrag(task, dropTime);
    if (!handled) {
      widget.onTaskDragEnd?.call(task, dropTime);
    }
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
    final bool compact = ResponsiveHelper.isCompact(context);

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
    final List<CalendarTask> tasks = _getTasksForDay(date);
    final String? draggingId = _taskInteractionController.draggingTaskId;
    final double stepHeight =
        (_resolvedHourHeight / 60.0) * _minutesPerStep.toDouble();

    final CalendarTaskEntriesBuilder builder = CalendarTaskEntriesBuilder(
      layoutCalculator: _layoutCalculator,
      layoutMetrics: _currentLayoutMetrics,
      interactionController: _taskInteractionController,
      callbacksFactory: (task) {
        return CalendarTaskTileCallbacks(
          onResizePreview: _handleResizePreview,
          onResizeEnd: _handleResizeCommit,
          onResizePointerMove: _handleResizeAutoScroll,
          onDragStarted: _handleTaskDragStarted,
          onDragUpdate: _handleTaskDragUpdate,
          onDragEnded: _handleTaskDragEnded,
          onDragPointerDown: (offset) => _handleTaskPointerDown(task, offset),
          onEnterSelectionMode: () => _enterSelectionMode(task.id),
          onToggleSelection: () => _toggleTaskSelection(task.id),
          onTap: _onScheduledTaskTapped,
          computePreviewStartForHover: (offset) =>
              _computePreviewStartForTaskHover(task, offset),
          defaultPreviewStart: () => _defaultPreviewStartForTask(task),
          previewOverlapsScheduled:
              _slotDragController.previewOverlapsScheduled,
          updateDragPreview: _updateDragPreview,
          stopEdgeAutoScroll: _stopEdgeAutoScroll,
          updateDragFeedbackWidth: _updateDragFeedbackWidth,
          clearDragPreview: _clearDragPreview,
          cancelPendingDragWidth: _cancelPendingDragWidth,
          resetDragFeedbackHint: _resetDragFeedbackHint,
          doesPreviewOverlap: () => _doesPreviewOverlap(task),
          onTaskDrop: _handleTaskDrop,
          isWidthDebounceActive: () => _isWidthDebounceActive,
          isPreviewAnchor: _slotDragController.isPreviewAnchor,
        );
      },
      registerVisibleTask: (task) => _visibleTasks[task.id] = task,
      updateVisibleBounds: (taskId, rect) => _visibleTaskRects[taskId] = rect,
      isSelectionMode: _isSelectionMode,
      isTaskSelected: _isTaskSelected,
      isPopoverOpen: _taskPopoverController.isPopoverOpen,
      dragTargetKeyForTask: _taskPopoverController.keyForTask,
      requestPopoverLayoutUpdate: (taskId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateActivePopoverLayoutForTask(taskId);
        });
      },
      contextMenuDelegate: (task, menuController) =>
          _buildTaskContextMenuBuilder(
        task: task,
        menuController: menuController,
      ),
      contextMenuGroupId: _contextMenuGroupId,
      splitPreviewAnimationDuration:
          _CalendarGridState._layoutTheme.splitPreviewAnimationDuration,
      stepHeight: stepHeight,
      minutesPerStep: _minutesPerStep,
      hourHeight: _resolvedHourHeight,
      draggingTaskId: draggingId,
    );

    final DateTime weekStartDate = DateTime(
      widget.state.weekStart.year,
      widget.state.weekStart.month,
      widget.state.weekStart.day,
    );
    final DateTime weekEndDate = DateTime(
      widget.state.weekEnd.year,
      widget.state.weekEnd.month,
      widget.state.weekEnd.day,
    );

    return builder.build(
      day: date,
      dayWidth: dayWidth,
      isDayView: isDayView,
      startHour: startHour,
      endHour: endHour,
      tasks: tasks,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      visibleTaskIds: visibleTaskIds,
    );
  }

  TaskContextMenuBuilder _buildTaskContextMenuBuilder({
    required CalendarTask task,
    required ShadPopoverController menuController,
  }) {
    return (context, request) {
      final List<Widget> menuItems = <Widget>[
        ShadContextMenuItem(
          leading: const Icon(Icons.copy_outlined),
          onPressed: () {
            request.markCloseIntent();
            menuController.hide();
            _copyTask(task);
          },
          child: const Text('Copy Task'),
        ),
      ];

      if (_taskInteractionController.clipboardTemplate != null &&
          task.scheduledTime != null) {
        menuItems.add(
          ShadContextMenuItem(
            leading: const Icon(Icons.content_paste_outlined),
            onPressed: () {
              request.markCloseIntent();
              menuController.hide();
              _pasteTask(task.scheduledTime!);
            },
            child: const Text('Paste Task Here'),
          ),
        );
      }

      final Set<String> seriesIds = _seriesIdsForTask(task);
      final bool hasSeriesGroup = seriesIds.length > 1;
      final bool selectionModeActive = _isSelectionMode;
      final bool isSeriesTask = hasSeriesGroup ||
          task.isOccurrence ||
          !task.effectiveRecurrence.isNone;
      final bool isOccurrenceSelected = _selectedTaskIds.contains(task.id);
      final bool isSeriesSelected =
          hasSeriesGroup && seriesIds.every(_selectedTaskIds.contains);
      final bool isSelected = _isTaskSelected(task);

      if (isSeriesTask) {
        final String occurrenceLabel;
        if (selectionModeActive) {
          occurrenceLabel =
              isOccurrenceSelected ? 'Deselect Task' : 'Add Task to Selection';
        } else {
          occurrenceLabel = 'Select Task';
        }

        menuItems.add(
          ShadContextMenuItem(
            leading: Icon(
              isOccurrenceSelected
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: () {
              request.markCloseIntent();
              menuController.hide();
              if (selectionModeActive) {
                _toggleTaskSelection(task.id);
              } else {
                _enterSelectionMode(task.id);
              }
            },
            child: Text(occurrenceLabel),
          ),
        );

        final String seriesLabel;
        if (selectionModeActive) {
          seriesLabel =
              isSeriesSelected ? 'Deselect All Repeats' : 'Add All Repeats';
        } else {
          seriesLabel = 'Select All Repeats';
        }

        menuItems.add(
          ShadContextMenuItem(
            leading: Icon(
              isSeriesSelected
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: () {
              request.markCloseIntent();
              menuController.hide();
              if (isSeriesSelected) {
                _capturedBloc.add(
                  CalendarEvent.selectionIdsRemoved(taskIds: seriesIds),
                );
              } else {
                _capturedBloc.add(
                  CalendarEvent.selectionIdsAdded(taskIds: seriesIds),
                );
              }
            },
            child: Text(seriesLabel),
          ),
        );
      } else {
        final String selectionLabel;
        if (selectionModeActive) {
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
              request.markCloseIntent();
              menuController.hide();
              if (selectionModeActive) {
                _toggleTaskSelection(task.id);
              } else {
                _enterSelectionMode(task.id);
              }
            },
            child: Text(selectionLabel),
          ),
        );
      }

      final DateTime? splitTime = request.splitTime;
      if (splitTime != null) {
        menuItems.add(
          ShadContextMenuItem(
            leading: const Icon(Icons.call_split),
            onPressed: () {
              request.markCloseIntent();
              menuController.hide();
              _splitTask(task, splitTime);
            },
            child: Text(
              'Split at ${TimeFormatter.formatTime(splitTime)}',
            ),
          ),
        );
      }

      if (selectionModeActive) {
        menuItems.add(
          ShadContextMenuItem(
            leading: const Icon(Icons.highlight_off),
            onPressed: () {
              request.markCloseIntent();
              menuController.hide();
              _clearSelectionMode();
            },
            child: const Text('Exit Selection Mode'),
          ),
        );
      }

      final bool canCopyTemplate = !task.isOccurrence;
      if (canCopyTemplate) {
        menuItems.add(
          ShadContextMenuItem(
            leading: const Icon(Icons.copy_outlined),
            onPressed: () {
              request.markCloseIntent();
              menuController.hide();
              _copyTask(task);
            },
            child: const Text('Copy Template'),
          ),
        );
      }

      menuItems.add(
        ShadContextMenuItem(
          leading: const Icon(Icons.delete_outline),
          onPressed: () {
            request.markCloseIntent();
            menuController.hide();
            _capturedBloc.add(
              CalendarEvent.taskDeleted(taskId: task.baseId),
            );
          },
          child: const Text('Delete Task'),
        ),
      );

      return menuItems;
    };
  }

  Set<String> _seriesIdsForTask(CalendarTask task) {
    final String baseId = task.baseId;
    final CalendarTask? baseTask = widget.state.model.tasks[baseId];
    final bool hasModelSibling = widget.state.model.tasks.values.any(
      (entry) => entry.baseId == baseId && entry.id != baseId,
    );
    final bool hasVisibleSibling = _visibleTasks.keys.any(
      (key) => baseTaskIdFrom(key) == baseId && key != task.id,
    );
    final bool hasSelectedSibling = _selectedTaskIds.any(
      (id) => baseTaskIdFrom(id) == baseId && id != task.id,
    );
    final bool treatAsSeries = (baseTask?.isSeries ?? false) ||
        hasModelSibling ||
        hasVisibleSibling ||
        hasSelectedSibling;

    if (baseTask == null || !treatAsSeries) {
      return {task.id};
    }

    final ids = <String>{baseId};

    if (task.id != baseId) {
      ids.add(task.id);
    }

    if (baseTask.isSeries) {
      if (task.isOccurrence) {
        ids.add(task.id);
      } else {
        final String? occurrenceKey = baseTask.baseOccurrenceKey;
        if (occurrenceKey != null && occurrenceKey.isNotEmpty) {
          ids.add('$baseId::$occurrenceKey');
        }
      }
    }

    for (final entry in widget.state.model.tasks.values) {
      if (entry.baseId == baseId) {
        ids.add(entry.id);
      }
    }

    for (final entry in _visibleTasks.entries) {
      if (baseTaskIdFrom(entry.key) == baseId) {
        ids.add(entry.key);
      }
    }

    for (final selected in _selectedTaskIds) {
      if (baseTaskIdFrom(selected) == baseId) {
        ids.add(selected);
      }
    }

    return ids;
  }

  List<DateTime> _getWeekDates(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  List<CalendarTask> _getTasksForDay(DateTime date) {
    final tasks = widget.state.tasksForDate(date);
    return tasks.where((task) => task.scheduledTime != null).map((task) {
      final preview = _taskInteractionController.resizePreviews[task.id];
      return preview ?? task;
    }).toList()
      ..sort((a, b) {
        final DateTime? aTime = a.scheduledTime;
        final DateTime? bTime = b.scheduledTime;
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

  void _processFocusRequest(TaskFocusRequest? request) {
    if (!_blocInitialized || request == null) {
      return;
    }
    if (_lastHandledFocusToken == request.token) {
      return;
    }
    _lastHandledFocusToken = request.token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToSlot(request.anchor);
      _capturedBloc.add(const CalendarEvent.taskFocusCleared());
    });
  }
}

typedef _SlotTapHandler = void Function(
  DateTime slotTime, {
  required bool hasTask,
  Offset? tapPosition,
  double? slotExtent,
});

class _CalendarSlotCell extends StatelessWidget {
  const _CalendarSlotCell({required this.bindings});

  final _CalendarSlotBindings bindings;

  @override
  Widget build(BuildContext context) {
    final CalendarSlotDragController slotDragController =
        bindings.slotDragController;
    final TaskInteractionController interactionController =
        bindings.interactionController;
    final CalendarLayoutCalculator layoutCalculator = bindings.layoutCalculator;
    final DateTime slotTime = bindings.slotTime;
    final Duration slotDuration = bindings.slotDuration;
    final int slotMinutes = bindings.slotMinutes;
    final DateTime targetDate = bindings.targetDate;
    final double slotHeight = bindings.slotHeight;
    final int hour = bindings.hour;
    final int minute = bindings.minute;

    return DragTarget<CalendarTask>(
      onWillAcceptWithDetails: (details) {
        final CalendarTask task = details.data;
        final Duration duration = task.duration ?? const Duration(hours: 1);
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        final double slotWidth = renderBox?.hasSize == true
            ? renderBox!.size.width
            : (interactionController.activeDragWidth ??
                interactionController.draggingTaskWidth ??
                0.0);
        final DateTime? originSlot = interactionController.dragOriginSlot;
        final bool isOriginCell =
            originSlot != null && slotTime.isAtSameMomentAs(originSlot);
        final double baselineWidth =
            interactionController.dragInitialWidth ?? slotWidth;
        final double currentWidth = interactionController.activeDragWidth ??
            interactionController.draggingTaskWidth ??
            baselineWidth;
        double targetWidth = baselineWidth;
        final DateTime previewStart =
            slotDragController.computePreviewStartForSlot(
                  renderBox,
                  details.offset,
                  slotTime,
                  slotMinutes,
                  slotHeight,
                ) ??
                slotTime;

        final bool hasOverlap = slotDragController.previewOverlapsScheduled(
          previewStart,
          duration,
        );
        final bool pendingNarrow =
            hasOverlap || interactionController.hasPendingWidthUpdate;
        final bool canAdjustWidth =
            !isOriginCell && (!bindings.shouldFreezeWidth() || hasOverlap);
        bool forceApply = false;
        if (canAdjustWidth) {
          final double narrowedWidth =
              layoutCalculator.computeNarrowedWidth(slotWidth, baselineWidth);
          if (pendingNarrow) {
            targetWidth = narrowedWidth;
          } else {
            targetWidth = slotWidth;
            forceApply = true;
          }
        }

        bindings.updateDragPreview(previewStart, duration);
        bindings.updateDragFeedbackWidth(
          targetWidth,
          forceCenterPointer: targetWidth < currentWidth,
          forceApply: forceApply,
        );
        return true;
      },
      onLeave: (_) {
        if (slotDragController.isPreviewAnchor(slotTime)) {
          bindings.clearDragPreview();
        }
        bindings.cancelPendingDragWidth();
        bindings.resetDragFeedbackHint();
      },
      onAcceptWithDetails: (details) {
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        final DateTime dropTime = slotDragController.computePreviewStartForSlot(
              renderBox,
              details.offset,
              slotTime,
              slotMinutes,
              slotHeight,
            ) ??
            slotTime;
        bindings.clearDragPreview();
        bindings.cancelPendingDragWidth();
        bindings.resetDragFeedbackHint();
        bindings.handleTaskDrop(details.data, dropTime);
      },
      onMove: (details) {
        final bool wasFrozen = bindings.shouldFreezeWidth();
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize || slotHeight <= 0) {
          return;
        }

        final CalendarTask task = details.data;
        final DateTime previewStart =
            slotDragController.computePreviewStartForSlot(
                  renderBox,
                  details.offset,
                  slotTime,
                  slotMinutes,
                  slotHeight,
                ) ??
                slotTime;
        final Duration duration = task.duration ?? const Duration(hours: 1);
        final bool hasOverlap = slotDragController.previewOverlapsScheduled(
          previewStart,
          duration,
        );
        final double slotWidth = renderBox.size.width;
        final double baselineWidth =
            interactionController.dragInitialWidth ?? slotWidth;
        final bool allowNarrowing = hasOverlap ||
            (interactionController.dragHasMoved &&
                !bindings.isWidthDebounceActive());
        final DateTime? originSlot = interactionController.dragOriginSlot;
        final bool isOriginCell =
            originSlot != null && slotTime.isAtSameMomentAs(originSlot);
        final bool pendingNarrow =
            hasOverlap || interactionController.hasPendingWidthUpdate;
        final bool canAdjustWidth =
            !isOriginCell && (!bindings.shouldFreezeWidth() || hasOverlap);
        final double currentWidth = interactionController.activeDragWidth ??
            interactionController.draggingTaskWidth ??
            baselineWidth;
        double targetWidth = baselineWidth;
        bool forceApply = false;
        if (canAdjustWidth) {
          if (pendingNarrow && allowNarrowing) {
            targetWidth =
                layoutCalculator.computeNarrowedWidth(slotWidth, baselineWidth);
          } else {
            targetWidth = slotWidth;
            forceApply = true;
          }
        }

        bindings.updateDragPreview(previewStart, duration);
        bindings.updateDragFeedbackWidth(
          targetWidth,
          forceCenterPointer: targetWidth < currentWidth,
          forceApply: forceApply,
        );

        if (!wasFrozen) {
          interactionController.markDragMoved();
        }
      },
      builder: (context, candidateData, rejectedData) {
        final bool hasTask = slotDragController.hasTaskInSlot(
          targetDate,
          hour,
          minute,
          slotMinutes,
        );
        final bool isPreviewSlot = slotDragController.isPreviewSlot(
          slotTime,
          slotDuration,
        );
        final bool isPreviewAnchor = slotDragController.isPreviewAnchor(
          slotTime,
        );

        Widget slot = _CalendarSlot(
          isPreviewSlot: isPreviewSlot,
          isPreviewAnchor: isPreviewAnchor,
          animationDuration: bindings.slotHoverAnimationDuration,
          cursor: SystemMouseCursors.click,
          splashColor: calendarPrimaryColor.withValues(
            alpha: calendarSlotSplashOpacity,
          ),
          highlightColor: calendarPrimaryColor.withValues(
            alpha: calendarSlotHighlightOpacity,
          ),
          onTap: (localPosition) {
            final RenderBox? renderBox =
                context.findRenderObject() as RenderBox?;
            final double? extent = renderBox != null && renderBox.hasSize
                ? renderBox.size.height
                : slotHeight > 0
                    ? slotHeight
                    : null;
            bindings.handleSlotTap(
              slotTime,
              hasTask: hasTask,
              tapPosition: localPosition,
              slotExtent: extent,
            );
          },
          child: const SizedBox.expand(),
        );

        final List<Widget> menuItems = <Widget>[];
        final ShadPopoverController controller = ShadPopoverController();

        if (bindings.clipboardTemplateProvider() != null) {
          menuItems.add(
            ShadContextMenuItem(
              leading: const Icon(Icons.content_paste_outlined),
              onPressed: () {
                controller.hide();
                bindings.onPasteTemplate(slotTime);
              },
              child: const Text('Paste Task Here'),
            ),
          );
        }

        if (bindings.isSelectionMode) {
          menuItems.add(
            ShadContextMenuItem(
              leading: const Icon(Icons.highlight_off),
              onPressed: () {
                controller.hide();
                bindings.clearSelectionMode();
              },
              child: const Text('Exit Selection Mode'),
            ),
          );
        }

        if (menuItems.isNotEmpty) {
          slot = ShadContextMenuRegion(
            controller: controller,
            groupId: bindings.contextMenuGroupId,
            items: menuItems,
            child: slot,
          );
        }

        return slot;
      },
    );
  }
}

class _CalendarSlotBindings {
  const _CalendarSlotBindings({
    required this.slotTime,
    required this.targetDate,
    required this.hour,
    required this.minute,
    required this.slotMinutes,
    required this.slotHeight,
    required this.slotDuration,
    required this.slotDragController,
    required this.interactionController,
    required this.layoutCalculator,
    required this.shouldFreezeWidth,
    required this.updateDragPreview,
    required this.updateDragFeedbackWidth,
    required this.cancelPendingDragWidth,
    required this.resetDragFeedbackHint,
    required this.handleTaskDrop,
    required this.clearDragPreview,
    required this.handleSlotTap,
    required this.slotHoverAnimationDuration,
    required this.isSelectionMode,
    required this.clearSelectionMode,
    required this.clipboardTemplateProvider,
    required this.onPasteTemplate,
    required this.contextMenuGroupId,
    required this.isWidthDebounceActive,
  });

  final DateTime slotTime;
  final DateTime targetDate;
  final int hour;
  final int minute;
  final int slotMinutes;
  final double slotHeight;
  final Duration slotDuration;
  final CalendarSlotDragController slotDragController;
  final TaskInteractionController interactionController;
  final CalendarLayoutCalculator layoutCalculator;
  final bool Function() shouldFreezeWidth;
  final void Function(DateTime previewStart, Duration previewDuration)
      updateDragPreview;
  final void Function(
    double width, {
    bool forceApply,
    bool forceCenterPointer,
  }) updateDragFeedbackWidth;
  final VoidCallback cancelPendingDragWidth;
  final VoidCallback resetDragFeedbackHint;
  final void Function(CalendarTask task, DateTime dropTime) handleTaskDrop;
  final VoidCallback clearDragPreview;
  final _SlotTapHandler handleSlotTap;
  final Duration slotHoverAnimationDuration;
  final bool isSelectionMode;
  final VoidCallback clearSelectionMode;
  final CalendarTask? Function() clipboardTemplateProvider;
  final void Function(DateTime slotTime) onPasteTemplate;
  final ValueKey<String> contextMenuGroupId;
  final bool Function() isWidthDebounceActive;
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
    required this.animationDuration,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
    this.splashColor,
    this.highlightColor,
  });

  final bool isPreviewSlot;
  final bool isPreviewAnchor;
  final Widget child;
  final Duration animationDuration;
  final ValueChanged<Offset>? onTap;
  final MouseCursor cursor;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  State<_CalendarSlot> createState() => _CalendarSlotState();
}

class _CalendarSlotState extends State<_CalendarSlot> {
  bool _hovering = false;
  Offset? _lastTapPosition;

  Color get _hoverColor =>
      calendarPrimaryColor.withValues(alpha: calendarSlotHoverOpacity);
  Color get _previewColor =>
      calendarPrimaryColor.withValues(alpha: calendarSlotPreviewOpacity);
  Color get _previewAnchorColor =>
      calendarPrimaryColor.withValues(alpha: calendarSlotPreviewAnchorOpacity);

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
        duration: widget.animationDuration,
        color: color,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTapDown: widget.onTap != null
                ? (details) => _lastTapPosition = details.localPosition
                : null,
            onTap: widget.onTap != null
                ? () {
                    final Offset position = _lastTapPosition ?? Offset.zero;
                    widget.onTap!(position);
                  }
                : null,
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
