import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart' show RenderBox, RendererBinding;
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
import 'resizable_task_widget.dart';
import 'widgets/calendar_render_surface.dart';
import 'widgets/calendar_surface_drag_target.dart';
import 'widgets/calendar_task_surface.dart';
import 'widgets/calendar_task_geometry.dart';

export 'layout/calendar_layout.dart' show OverlapInfo, calculateOverlapColumns;

class _CalendarScrollController extends ScrollController {
  _CalendarScrollController({required this.onAttached});

  final VoidCallback onAttached;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    onAttached();
  }
}

class CalendarGrid<T extends BaseCalendarBloc> extends StatefulWidget {
  final CalendarState state;
  final Function(DateTime, Offset)? onEmptySlotTapped;
  final Function(CalendarTask, DateTime)? onTaskDragEnd;
  final void Function(DateTime date) onDateSelected;
  final void Function(CalendarView view) onViewChanged;
  final TaskFocusRequest? focusRequest;
  final VoidCallback? onDragSessionStarted;
  final ValueChanged<Offset>? onDragGlobalPositionChanged;
  final VoidCallback? onDragSessionEnded;

  const CalendarGrid({
    super.key,
    required this.state,
    this.onEmptySlotTapped,
    this.onTaskDragEnd,
    required this.onDateSelected,
    required this.onViewChanged,
    this.focusRequest,
    this.onDragSessionStarted,
    this.onDragGlobalPositionChanged,
    this.onDragSessionEnded,
  });

  @override
  State<CalendarGrid<T>> createState() => _CalendarGridState<T>();
}

class _CalendarGridState<T extends BaseCalendarBloc>
    extends State<CalendarGrid<T>>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<CalendarGrid<T>> {
  static const int startHour = 0;
  static const int endHour = 24;
  static const int _defaultZoomIndex = 1;
  static const double _mobileCompactHourHeight = 60;
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
  late final ScrollController _horizontalHeaderController;
  late final ScrollController _horizontalGridController;
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
  static const ValueKey<String> _contextMenuGroupId =
      ValueKey<String>('calendar-grid-context');
  Ticker? _edgeAutoScrollTicker;
  final Map<String, CalendarTask> _visibleTasks = <String, CalendarTask>{};
  final CalendarSurfaceController _surfaceController =
      CalendarSurfaceController();
  final GlobalKey _surfaceKey = GlobalKey(debugLabel: 'calendar-surface');
  late final ShadPopoverController _gridContextMenuController;
  DateTime? _contextMenuSlot;
  double _edgeAutoScrollOffsetPerFrame = 0;
  bool get _isWidthDebounceActive =>
      _taskInteractionController.isWidthDebounceActive;
  int? _lastHandledFocusToken;
  bool _isCompactActive = false;
  int? _preCompactZoomIndex;
  CalendarView? _lastNonDayView;
  bool _waitingForDayView = false;
  CalendarView? _pendingRestoreView;
  bool _syncingHorizontalScroll = false;
  DateTime? _hoveredSlot;
  bool _desktopDayPinned = false;
  bool _autoScrollPending = false;
  DateTime? _pendingScrollSlot;
  DateTime? _pendingZoomScrollTarget;
  TaskFocusRequest? _pendingFocusRequest;
  Offset? _contextMenuAnchor;
  bool _pendingPopoverGeometryUpdate = false;
  bool _dragSessionNotified = false;

  @override
  bool get wantKeepAlive => true;

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
    _verticalController = _CalendarScrollController(
      onAttached: _handleScrollAttach,
    );
    _horizontalHeaderController = ScrollController();
    _horizontalGridController = ScrollController();
    _horizontalHeaderController.addListener(_handleHorizontalHeaderScroll);
    _horizontalGridController.addListener(_handleHorizontalGridScroll);
    _taskInteractionController = TaskInteractionController();
    _gridContextMenuController = ShadPopoverController();
    _taskInteractionController.clipboard.addListener(
      _handleClipboardChanged,
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
    _scheduleAutoScroll();
  }

  CalendarZoomLevel get _currentZoom => _zoomLevels[_zoomIndex];
  int get _slotSubdivisions => _currentLayoutMetrics.slotsPerHour;
  int get _minutesPerSlot => _currentLayoutMetrics.minutesPerSlot;
  int get _minutesPerStep => _resizeStepMinutes;
  bool get _canZoomIn => _zoomIndex < _zoomLevels.length - 1;
  bool get _canZoomOut => _zoomIndex > 0;
  bool get _shouldUseCompactZoom =>
      _isCompactActive || widget.state.viewMode == CalendarView.day;
  bool get _isZoomEnabled =>
      widget.state.viewMode != CalendarView.day || _shouldUseCompactZoom;
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
      return;
    }

    final position = _verticalController.position;
    if (!position.hasViewportDimension || position.viewportDimension <= 0) {
      return;
    }
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

  void _handleScrollAttach() {
    if (!mounted) {
      return;
    }
    _processViewportRequests();
  }

  void _handleClipboardChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleHorizontalHeaderScroll() {
    if (_syncingHorizontalScroll ||
        !_horizontalHeaderController.hasClients ||
        !_horizontalGridController.hasClients) {
      return;
    }
    _syncingHorizontalScroll = true;
    final double targetOffset = _horizontalHeaderController.offset.clamp(
      0.0,
      _horizontalGridController.position.maxScrollExtent,
    );
    _horizontalGridController.jumpTo(targetOffset);
    _syncingHorizontalScroll = false;
  }

  void _handleHorizontalGridScroll() {
    if (_syncingHorizontalScroll ||
        !_horizontalHeaderController.hasClients ||
        !_horizontalGridController.hasClients) {
      return;
    }
    _syncingHorizontalScroll = true;
    final double targetOffset = _horizontalGridController.offset.clamp(
      0.0,
      _horizontalHeaderController.position.maxScrollExtent,
    );
    _horizontalHeaderController.jumpTo(targetOffset);
    _syncingHorizontalScroll = false;
  }

  void _scheduleAutoScroll() {
    _autoScrollPending = true;
    _maybeAutoScroll();
  }

  void _processViewportRequests() {
    if (!mounted) {
      return;
    }
    _restoreScrollAnchor();
    _flushPendingScrollTargets();
    _maybeAutoScroll();
    _fulfillFocusRequestIfReady();
  }

  void _flushPendingScrollTargets() {
    if (!_verticalController.hasClients) {
      return;
    }
    if (_pendingZoomScrollTarget != null) {
      final DateTime target = _pendingZoomScrollTarget!;
      _pendingZoomScrollTarget = null;
      _scrollToSlot(target, allowDeferral: false);
    }
    if (_pendingScrollSlot != null) {
      final DateTime target = _pendingScrollSlot!;
      _pendingScrollSlot = null;
      _scrollToSlot(target, allowDeferral: false);
    }
  }

  void _fulfillFocusRequestIfReady() {
    if (_pendingFocusRequest == null || !_verticalController.hasClients) {
      return;
    }
    final TaskFocusRequest request = _pendingFocusRequest!;
    _pendingFocusRequest = null;
    _scrollToSlot(request.anchor, allowDeferral: false);
    _capturedBloc.add(const CalendarEvent.taskFocusCleared());
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
    final double currentOffset = _verticalController.offset;
    final double nextOffset = (currentOffset + _edgeAutoScrollOffsetPerFrame)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((nextOffset - currentOffset).abs() <= 0.1) {
      _stopEdgeAutoScroll();
      return;
    }

    _verticalController.jumpTo(nextOffset);
    final double appliedDelta = nextOffset - currentOffset;
    if (appliedDelta.abs() > 0) {
      _taskInteractionController.dispatchResizeAutoScrollDelta(appliedDelta);
    }
  }

  void _stopEdgeAutoScroll() {
    _edgeAutoScrollOffsetPerFrame = 0;
    if (_edgeAutoScrollTicker?.isActive ?? false) {
      _edgeAutoScrollTicker!.stop();
    }
  }

  void _setDragFeedbackHint(DragFeedbackHint hint) {
    if (_taskInteractionController.feedbackHint.value == hint) {
      return;
    }
    if (!mounted) {
      return;
    }
    _taskInteractionController.setFeedbackHint(hint);
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
    double normalizedPointer =
        _taskInteractionController.dragPointerNormalized.clamp(0.0, 1.0);
    final double pointerGlobalX =
        _taskInteractionController.dragPointerGlobalX ??
            (_taskInteractionController.dragStartGlobalLeft ?? 0.0) +
                (currentWidth * normalizedPointer);
    if (shouldCenter) {
      normalizedPointer = 0.5;
      _taskInteractionController.setDragPointerNormalized(normalizedPointer);
    }
    _setDragFeedbackHint(
      _buildDragHint(
        width: width,
        pointerFraction: shouldCenter ? 0.5 : null,
        anchorDx:
            shouldCenter ? width / 2 : _taskInteractionController.dragAnchorDx,
        anchorDy: _taskInteractionController.dragPointerOffsetFromTop,
      ),
    );
    final double adjustedLeft = width > 0
        ? pointerGlobalX - (width * normalizedPointer)
        : pointerGlobalX;
    _taskInteractionController.dragStartGlobalLeft = adjustedLeft;
    if (width > 0) {
      _taskInteractionController.draggingTaskWidth = width;
      _taskInteractionController.dragAnchorDx = width * normalizedPointer;
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

    final double pointerOffset = (baseWidth * normalized).clamp(0.0, baseWidth);
    final double anchorX = anchorDx ??
        (pointerFraction != null
            ? pointerFraction * baseWidth
            : _taskInteractionController.dragAnchorDx ?? pointerOffset);
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
    _taskInteractionController.clipboard
        .removeListener(_handleClipboardChanged);
    _horizontalHeaderController.removeListener(_handleHorizontalHeaderScroll);
    _horizontalGridController.removeListener(_handleHorizontalGridScroll);
    _horizontalHeaderController.dispose();
    _horizontalGridController.dispose();
    _gridContextMenuController.dispose();
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
      originSlot: _computeOriginSlot(task.scheduledTime),
    );
    _notifyDragSessionStarted();
    final double? globalX = _taskInteractionController.dragPointerGlobalX;
    final double? globalY = _taskInteractionController.dragPointerGlobalY;
    if (globalX != null && globalY != null) {
      _notifyDragGlobalPosition(Offset(globalX, globalY));
    }
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
    );
  }

  void _handleDragPointerDown(
    Offset normalizedOffset, {
    double? pointerOffsetPixels,
    String? taskId,
  }) {
    double normalizedX = normalizedOffset.dx;
    double normalizedY = normalizedOffset.dy;
    if (!normalizedX.isFinite) {
      normalizedX = 0.5;
    }
    if (!normalizedY.isFinite) {
      normalizedY = 0.5;
    }
    if (normalizedX < 0) {
      normalizedX = 0;
    } else if (normalizedX > 1) {
      normalizedX = 1;
    }
    if (normalizedY < 0) {
      normalizedY = 0;
    } else if (normalizedY > 1) {
      normalizedY = 1;
    }
    _taskInteractionController.setDragPointerNormalized(normalizedX);
    _taskInteractionController.setPendingPointerOffsetFraction(
      normalizedY,
      taskId: taskId,
    );
    final double? offset = pointerOffsetPixels != null &&
            pointerOffsetPixels.isFinite &&
            pointerOffsetPixels >= 0
        ? pointerOffsetPixels
        : null;
    _taskInteractionController.setDragPointerOffsetFromTop(
      offset,
      notify: false,
    );
    _taskInteractionController.dragHasMoved = false;
  }

  void _notifyDragSessionStarted() {
    if (_dragSessionNotified) {
      return;
    }
    _dragSessionNotified = true;
    widget.onDragSessionStarted?.call();
  }

  void _notifyDragGlobalPosition(Offset position) {
    widget.onDragGlobalPositionChanged?.call(position);
  }

  void _notifyDragSessionEnded() {
    if (!_dragSessionNotified) {
      return;
    }
    _dragSessionNotified = false;
    widget.onDragSessionEnded?.call();
  }

  void _handleTaskPointerDown(CalendarTask task, Offset normalizedOffset) {
    double? pointerOffset;
    final CalendarTaskGeometry? geometry =
        _surfaceController.geometryForTask(task.id);
    final double normalizedDy =
        (normalizedOffset.dy.clamp(0.0, 1.0) as num).toDouble();
    if (geometry != null) {
      final double height = geometry.rect.height;
      if (height.isFinite && height > 0) {
        pointerOffset = normalizedDy * height;
      }
    }
    _handleDragPointerDown(
      normalizedOffset,
      pointerOffsetPixels: pointerOffset,
      taskId: task.id,
    );
  }

  DateTime? _computeOriginSlot(DateTime? scheduled) {
    if (scheduled == null) {
      return null;
    }
    final int minutesPerSlot = _minutesPerSlot;
    if (minutesPerSlot <= 0) {
      return scheduled;
    }
    final int slotMinutes =
        (scheduled.minute ~/ minutesPerSlot) * minutesPerSlot;
    return DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
      scheduled.hour,
      slotMinutes,
    );
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
    final CalendarTask? draggingTask =
        _taskInteractionController.draggingTaskSnapshot;
    if (draggingTask == null) {
      return;
    }
    final double? startLeft = _taskInteractionController.dragStartGlobalLeft;
    final double baseWidth = _taskInteractionController.dragInitialWidth ??
        _taskInteractionController.draggingTaskWidth ??
        0.0;
    if (startLeft == null || baseWidth <= 0) {
      return;
    }
    _taskInteractionController
        .updateDragPointerGlobalPosition(details.globalPosition);
    _notifyDragSessionStarted();
    _notifyDragGlobalPosition(details.globalPosition);
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

    final RenderObject? surfaceObject =
        _surfaceKey.currentContext?.findRenderObject();
    if (surfaceObject is RenderCalendarSurface) {
      final DragPreview? preview =
          surfaceObject.previewForGlobalPosition(details.globalPosition);
      if (preview != null) {
        _updateDragPreview(preview.start, preview.duration);
      }
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
    _notifyDragSessionEnded();
  }

  @override
  void didUpdateWidget(covariant CalendarGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_waitingForDayView && widget.state.viewMode == CalendarView.day) {
      _waitingForDayView = false;
    }
    if (_pendingRestoreView != null &&
        widget.state.viewMode == _pendingRestoreView) {
      _pendingRestoreView = null;
    }
    if (!_isCompactActive && widget.state.viewMode != CalendarView.day) {
      _lastNonDayView = null;
    }
    if (!_isCompactActive &&
        oldWidget.state.viewMode != widget.state.viewMode) {
      if (widget.state.viewMode == CalendarView.day && !_waitingForDayView) {
        _desktopDayPinned = true;
      } else if (widget.state.viewMode == CalendarView.week) {
        _desktopDayPinned = false;
      }
    }
    // Detect view mode changes and animate transitions
    if (oldWidget.state.viewMode != widget.state.viewMode) {
      _viewTransitionController.reset();
      _viewTransitionController.forward();
      _hasAutoScrolled = false;
      _scheduleAutoScroll();
    } else if (!_isSameDay(
        oldWidget.state.selectedDate, widget.state.selectedDate)) {
      _hasAutoScrolled = false;
      _scheduleAutoScroll();
    }

    if (widget.focusRequest != null &&
        (oldWidget.focusRequest == null ||
            oldWidget.focusRequest!.token != widget.focusRequest!.token)) {
      _processFocusRequest(widget.focusRequest);
    }

    _validateActivePopoverTarget(const <String>{});
  }

  double get _timeColumnWidth => _layoutTheme.timeColumnWidth;
  double _getHourHeight(BuildContext context, bool compact) {
    return _resolvedHourHeight;
  }

  bool _shouldUseSheetMenus(BuildContext context) {
    final bool hasMouse =
        RendererBinding.instance.mouseTracker.mouseIsConnected;
    return ResponsiveHelper.isCompact(context) || !hasMouse;
  }

  void _applyCompactZoomPreset() {
    _preCompactZoomIndex ??= _zoomIndex;
    const int target = 0;
    if (_zoomIndex != target) {
      _setZoomIndex(target);
    }
  }

  void _restoreZoomPreset() {
    final int target = _preCompactZoomIndex ?? _defaultZoomIndex;
    _preCompactZoomIndex = null;
    if (_zoomIndex != target) {
      _setZoomIndex(target);
    }
  }

  Future<void> _showTaskEditSheet(CalendarTask task) async {
    final bloc = _capturedBloc;
    final CalendarState state = bloc.state;
    final String baseId = baseTaskIdFrom(task.id);
    final CalendarTask latestTask = state.model.tasks[baseId] ?? task;
    final CalendarTask? storedTask = state.model.tasks[task.id];
    final String? occurrenceKey = occurrenceKeyFrom(task.id);
    final CalendarTask? occurrenceTask =
        storedTask == null && occurrenceKey != null
            ? latestTask.occurrenceForId(task.id)
            : null;
    final CalendarTask displayTask = storedTask ?? occurrenceTask ?? latestTask;
    final bool shouldUpdateOccurrence =
        storedTask == null && occurrenceTask != null;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final double maxHeight =
            mediaQuery.size.height - mediaQuery.padding.top;
        return SafeArea(
          top: false,
          child: EditTaskDropdown(
            task: displayTask,
            maxHeight: maxHeight,
            isSheet: true,
            onClose: () => Navigator.of(sheetContext).pop(),
            scaffoldMessenger: scaffoldMessenger,
            onTaskUpdated: (updatedTask) {
              bloc.add(
                CalendarEvent.taskUpdated(
                  task: updatedTask,
                ),
              );
            },
            onOccurrenceUpdated: shouldUpdateOccurrence
                ? (updatedTask) {
                    bloc.add(
                      CalendarEvent.taskOccurrenceUpdated(
                        taskId: baseId,
                        occurrenceId: task.id,
                        scheduledTime: updatedTask.scheduledTime,
                        duration: updatedTask.duration,
                        endDate: updatedTask.endDate,
                      ),
                    );

                    final CalendarTask seriesUpdate = latestTask.copyWith(
                      title: updatedTask.title,
                      description: updatedTask.description,
                      location: updatedTask.location,
                      deadline: updatedTask.deadline,
                      priority: updatedTask.priority,
                      isCompleted: updatedTask.isCompleted,
                    );

                    if (seriesUpdate != latestTask) {
                      bloc.add(
                        CalendarEvent.taskUpdated(
                          task: seriesUpdate,
                        ),
                      );
                    }
                  }
                : null,
            onTaskDeleted: (taskId) {
              bloc.add(
                CalendarEvent.taskDeleted(
                  taskId: taskId,
                ),
              );
              Navigator.of(sheetContext).pop();
            },
          ),
        );
      },
    );
  }

  void _updateCompactState(BuildContext context) {
    final CalendarResponsiveSpec spec = ResponsiveHelper.spec(context);
    final bool isCompactWidth = spec.sizeClass == CalendarSizeClass.compact;
    if (_isCompactActive != isCompactWidth) {
      _isCompactActive = isCompactWidth;
      if (_isCompactActive) {
        _applyCompactZoomPreset();
      } else {
        _restoreZoomPreset();
      }
    }

    if (_isCompactActive) {
      if (widget.state.viewMode != CalendarView.day) {
        _lastNonDayView ??= widget.state.viewMode;
        if (!_waitingForDayView) {
          _waitingForDayView = true;
          widget.onViewChanged(CalendarView.day);
        }
      }
    } else {
      if (_pendingRestoreView == null &&
          _lastNonDayView != null &&
          widget.state.viewMode == CalendarView.day) {
        _pendingRestoreView = _lastNonDayView;
        _lastNonDayView = null;
        widget.onViewChanged(_pendingRestoreView!);
      } else if (widget.state.viewMode == CalendarView.day &&
          !_desktopDayPinned &&
          !_waitingForDayView) {
        widget.onViewChanged(CalendarView.week);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _updateCompactState(context);
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
    return _buildWeekView(
      compact: true,
      allowWeekViewInCompact: true,
    );
  }

  Widget _buildDesktopGrid() {
    return _buildWeekView(compact: false);
  }

  Widget _buildWeekView({
    required bool compact,
    bool allowWeekViewInCompact = false,
  }) {
    return AnimatedBuilder(
      animation: _taskPopoverController,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: _taskInteractionController,
          builder: (context, __) {
            final weekDates = _getWeekDates(widget.state.selectedDate);
            final bool isWeekView =
                widget.state.viewMode == CalendarView.week &&
                    (!compact || allowWeekViewInCompact);
            final headerDates =
                isWeekView ? weekDates : [widget.state.selectedDate];
            final responsive = ResponsiveHelper.spec(context);
            final double horizontalPadding =
                compact ? 0 : responsive.gridHorizontalPadding;

            final gridBody = LayoutBuilder(
              builder: (context, outerConstraints) {
                final double viewportWidth = outerConstraints.maxWidth;
                double? compactWeekDayWidth = (compact && isWeekView)
                    ? ResponsiveHelper.dayColumnWidth(
                        context,
                        fallback: calendarCompactDayColumnWidth,
                      )
                    : null;
                bool enableHorizontalScroll = false;

                if (compactWeekDayWidth != null && isWeekView) {
                  final double availableForColumns = math.max(
                    0.0,
                    viewportWidth - (horizontalPadding * 2) - _timeColumnWidth,
                  );
                  if (availableForColumns <= 0) {
                    enableHorizontalScroll = true;
                  }
                  final double estimatedWidth = availableForColumns > 0
                      ? availableForColumns / headerDates.length
                      : compactWeekDayWidth;
                  const double minColumnWidth = 48.0;
                  final double clampedWidth =
                      estimatedWidth.isFinite && estimatedWidth > 0
                          ? estimatedWidth
                              .clamp(minColumnWidth, compactWeekDayWidth)
                              .toDouble()
                          : compactWeekDayWidth;
                  compactWeekDayWidth = clampedWidth;
                  final bool needsScroll =
                      estimatedWidth.isFinite && estimatedWidth > 0
                          ? estimatedWidth < minColumnWidth
                          : enableHorizontalScroll;
                  enableHorizontalScroll =
                      enableHorizontalScroll || needsScroll;
                }

                return Container(
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
                          horizontal: horizontalPadding,
                        ),
                        child: _buildDayHeaders(
                          headerDates,
                          compact,
                          isWeekView: isWeekView,
                          compactWeekDayWidth: compactWeekDayWidth,
                          horizontalScrollController: enableHorizontalScroll
                              ? _horizontalHeaderController
                              : null,
                          enableHorizontalScroll: enableHorizontalScroll,
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableHeight = constraints.maxHeight;
                            final bool isDayView = compact ||
                                widget.state.viewMode == CalendarView.day;
                            _resolvedHourHeight = _resolveHourHeight(
                              availableHeight,
                              isDayView: isDayView,
                            );
                            _processViewportRequests();
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
                                        compactWeekDayWidth,
                                        enableHorizontalScroll:
                                            enableHorizontalScroll,
                                        horizontalScrollController:
                                            enableHorizontalScroll
                                                ? _horizontalGridController
                                                : null,
                                        hoveredSlot: _hoveredSlot,
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
              },
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
          ],
        ),
      ),
    );
  }

  double _resolveHourHeight(double availableHeight, {required bool isDayView}) {
    var metrics = _layoutCalculator.resolveMetrics(
      zoomIndex: _zoomIndex,
      isDayView: isDayView,
      availableHeight: availableHeight,
      allowDayViewZoom: _shouldUseCompactZoom,
    );
    if (_shouldUseCompactZoom && _zoomIndex == 0) {
      final double compactHourHeight =
          math.min(metrics.hourHeight, _mobileCompactHourHeight);
      if (compactHourHeight != metrics.hourHeight) {
        final double compactSlotHeight =
            compactHourHeight / metrics.slotsPerHour;
        metrics = CalendarLayoutMetrics(
          hourHeight: compactHourHeight,
          slotHeight: compactSlotHeight,
          minutesPerSlot: metrics.minutesPerSlot,
          slotsPerHour: metrics.slotsPerHour,
        );
      }
    }
    _currentLayoutMetrics = metrics;
    return metrics.hourHeight;
  }

  double _effectiveHourHeight(CalendarLayoutMetrics? metrics) {
    final double resolved =
        metrics?.hourHeight ?? _currentLayoutMetrics.hourHeight;
    return resolved > 0 ? resolved : _currentLayoutMetrics.hourHeight;
  }

  double _effectiveStepHeight(CalendarLayoutMetrics? metrics) {
    final CalendarLayoutMetrics resolved = metrics ?? _currentLayoutMetrics;
    final double slotHeight = resolved.slotHeight;
    final int minutesPerSlot = resolved.minutesPerSlot;
    if (slotHeight > 0 && minutesPerSlot > 0) {
      final double ratio =
          _minutesPerStep.toDouble() / minutesPerSlot.toDouble();
      return slotHeight * ratio;
    }
    final double hourHeight = _effectiveHourHeight(metrics);
    return (hourHeight / 60.0) * _minutesPerStep.toDouble();
  }

  Widget _buildGridContent(
    bool isWeekView,
    List<DateTime> weekDates,
    bool compact,
    double? compactWeekDayWidth, {
    ScrollController? horizontalScrollController,
    bool enableHorizontalScroll = false,
    DateTime? hoveredSlot,
  }) {
    final bool allowHorizontalScroll =
        enableHorizontalScroll && compactWeekDayWidth != null;
    final responsive = ResponsiveHelper.spec(context);
    final List<DateTime> columns =
        isWeekView ? weekDates : <DateTime>[widget.state.selectedDate];
    final Set<String> visibleTaskIds = <String>{};
    _visibleTasks.clear();
    final List<Widget> taskEntries = _buildTaskEntries(
      columns: columns,
      visibleTaskIds: visibleTaskIds,
      isDayView: !isWeekView,
    );

    _cleanupTaskPopovers(visibleTaskIds);
    _validateActivePopoverTarget(visibleTaskIds);

    final List<CalendarDayColumn> columnSpecs =
        columns.map((date) => CalendarDayColumn(date: date)).toList();

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

    final Widget renderSurface = CalendarRenderSurface(
      key: _surfaceKey,
      columns: columnSpecs,
      startHour: startHour,
      endHour: endHour,
      zoomIndex: _zoomIndex,
      allowDayViewZoom: _shouldUseCompactZoom,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      layoutCalculator: _layoutCalculator,
      layoutTheme: _layoutTheme,
      controller: _surfaceController,
      minutesPerStep: _minutesPerStep,
      interactionController: _taskInteractionController,
      hoveredSlot: hoveredSlot,
      onTap: _handleSurfaceTap,
      dragPreview: _taskInteractionController.preview.value,
      onDragUpdate: _handleSurfaceDragUpdate,
      onDragEnd: _handleSurfaceDragEnd,
      onDragExit: _handleSurfaceDragExit,
      onDragAutoScroll: _handleAutoScrollForGlobal,
      onDragAutoScrollStop: _stopEdgeAutoScroll,
      isTaskDragInProgress: () =>
          _taskInteractionController.draggingTaskId != null ||
          _taskInteractionController.draggingTaskBaseId != null,
      onGeometryChanged: _handleSurfaceGeometryChanged,
      children: taskEntries,
    );

    final Widget interactiveSurface = MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: _handleSurfaceHover,
      onExit: (_) => _clearSurfaceHover(),
      child: renderSurface,
    );

    final Widget dragAwareSurface = CalendarSurfaceDragTarget(
      surfaceKey: _surfaceKey,
      child: interactiveSurface,
    );

    Widget surface = dragAwareSurface;
    if (allowHorizontalScroll) {
      final double dayWidth = compactWeekDayWidth;
      final double totalWidth =
          _timeColumnWidth + (dayWidth * columnSpecs.length);
      surface = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalScrollController ?? _horizontalGridController,
        child: SizedBox(
          width: totalWidth,
          child: dragAwareSurface,
        ),
      );
    }

    final List<Widget> gridMenuItems = _buildGridContextMenuItems();
    final Widget menuSurface = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleGridPointerDown,
      child: ShadContextMenu(
        controller: _gridContextMenuController,
        groupId: _contextMenuGroupId,
        anchor: _contextMenuAnchor != null
            ? ShadGlobalAnchor(_contextMenuAnchor!)
            : null,
        onTapOutside: (_) => _hideGridContextMenu(),
        items: gridMenuItems,
        child: surface,
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : responsive.gridHorizontalPadding,
      ),
      child: menuSurface,
    );
  }

  void _handleSurfaceTap(CalendarSurfaceTapDetails details) {
    if (details.hitTask) {
      _zoomToCell(details.slotStart);
      return;
    }
    if (widget.state.viewMode == CalendarView.day) {
      final DateTime normalized = DateTime(
        details.slotStart.year,
        details.slotStart.month,
        details.slotStart.day,
      );
      if (!DateUtils.isSameDay(widget.state.selectedDate, normalized)) {
        widget.onDateSelected(normalized);
      }
    }
    widget.onEmptySlotTapped?.call(details.slotStart, Offset.zero);
  }

  void _handleGridPointerDown(PointerDownEvent event) {
    _clearSurfaceHover();
    final RenderObject? renderObject =
        _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderCalendarSurface) {
      _hideGridContextMenu();
      return;
    }
    final bool isSecondaryClick = event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kSecondaryButton) != 0;
    if (!isSecondaryClick) {
      _hideGridContextMenu();
      return;
    }
    final Offset localPosition = renderObject.globalToLocal(event.position);
    if (_surfaceController.containsTaskAt(localPosition)) {
      _hideGridContextMenu();
      return;
    }
    final DateTime? slot = renderObject.slotForOffset(localPosition);
    if (slot == null) {
      _hideGridContextMenu();
      return;
    }
    setState(() {
      _contextMenuSlot = slot;
      _contextMenuAnchor = event.position;
    });
    if (_buildGridContextMenuItems().isEmpty) {
      _hideGridContextMenu();
      return;
    }
    _gridContextMenuController.show();
  }

  void _handleSurfaceHover(PointerHoverEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    final RenderObject? renderObject =
        _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderCalendarSurface) {
      _updateHoveredSlot(null);
      return;
    }
    final Offset localPosition = renderObject.globalToLocal(event.position);
    if (localPosition.dx <= _timeColumnWidth ||
        _surfaceController.containsTaskAt(localPosition)) {
      _updateHoveredSlot(null);
      return;
    }
    final DateTime? slot = _surfaceController.slotForOffset(localPosition);
    if (slot == null) {
      _updateHoveredSlot(null);
      return;
    }
    final int step = _minutesPerStep;
    final int snappedMinute = (slot.minute ~/ step) * step;
    final DateTime snapped = DateTime(
      slot.year,
      slot.month,
      slot.day,
      slot.hour,
      snappedMinute,
    );
    _updateHoveredSlot(snapped);
  }

  void _updateHoveredSlot(DateTime? slot) {
    final DateTime? current = _hoveredSlot;
    final bool unchanged = (current == null && slot == null) ||
        (current != null && slot != null && current.isAtSameMomentAs(slot));
    if (unchanged) {
      return;
    }
    setState(() {
      _hoveredSlot = slot;
    });
  }

  void _clearSurfaceHover() {
    if (_hoveredSlot == null) {
      return;
    }
    setState(() {
      _hoveredSlot = null;
    });
  }

  void _hideGridContextMenu() {
    if (_contextMenuSlot != null || _contextMenuAnchor != null) {
      setState(() {
        _contextMenuSlot = null;
        _contextMenuAnchor = null;
      });
    }
    _gridContextMenuController.hide();
  }

  List<Widget> _buildGridContextMenuItems() {
    final DateTime? slot = _contextMenuSlot;
    if (slot == null) {
      return const <Widget>[];
    }

    final List<Widget> items = <Widget>[];
    final CalendarTask? clipboardTemplate =
        _taskInteractionController.clipboardTemplate;

    if (clipboardTemplate != null) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(Icons.content_paste_outlined),
          onPressed: () {
            _hideGridContextMenu();
            _pasteTask(slot);
          },
          child: const Text('Paste Task Here'),
        ),
      );
    }

    if (widget.onEmptySlotTapped != null) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(Icons.add_circle_outline),
          onPressed: () {
            _hideGridContextMenu();
            widget.onEmptySlotTapped?.call(slot, Offset.zero);
          },
          child: const Text('Quick Add Task'),
        ),
      );
    }

    return items;
  }

  void _handleSurfaceDragUpdate(
    CalendarSurfaceDragUpdateDetails details,
  ) {
    final CalendarTask? dragging =
        _taskInteractionController.draggingTaskSnapshot;
    if (dragging == null) {
      return;
    }
    _notifyDragSessionStarted();
    _notifyDragGlobalPosition(details.globalPosition);
    _updateDragPreview(details.previewStart, details.previewDuration);

    final double? columnWidth = details.columnWidth ??
        _surfaceController.columnWidthForOffset(details.localPosition);
    final double baselineWidth = _taskInteractionController.dragInitialWidth ??
        _taskInteractionController.draggingTaskWidth ??
        columnWidth ??
        0;

    double targetWidth = baselineWidth;
    bool forceApply = !details.shouldNarrowWidth;
    bool forceCenterPointer = details.forceCenterPointer;

    if (details.shouldNarrowWidth) {
      if (details.narrowedWidth != null && details.narrowedWidth! > 0) {
        targetWidth = details.narrowedWidth!;
      } else if (columnWidth != null && columnWidth > 0) {
        targetWidth = columnWidth;
      }
    } else if (columnWidth != null && columnWidth > 0) {
      targetWidth = columnWidth;
    }

    if (targetWidth <= 0 && columnWidth != null) {
      targetWidth = columnWidth;
    }

    if (details.forceCenterPointer && targetWidth < baselineWidth) {
      forceCenterPointer = true;
    }

    _updateDragFeedbackWidth(
      targetWidth,
      forceApply: forceApply,
      forceCenterPointer: forceCenterPointer,
    );
  }

  void _handleSurfaceDragEnd(CalendarSurfaceDragEndDetails details) {
    final CalendarTask? dragging =
        _taskInteractionController.draggingTaskSnapshot;
    if (dragging == null) {
      return;
    }
    _handleTaskDrop(dragging, details.slotStart);
    _clearDragPreview();
    _cancelPendingDragWidth();
    _resetDragFeedbackHint();
    _stopEdgeAutoScroll();
    _notifyDragSessionEnded();
  }

  void _handleSurfaceDragExit() {
    _clearDragPreview();
    _cancelPendingDragWidth();
    _resetDragFeedbackHint();
    _stopEdgeAutoScroll();
    _notifyDragSessionEnded();
  }

  void _handleSurfaceGeometryChanged() {
    if (!mounted || _pendingPopoverGeometryUpdate) {
      return;
    }
    _pendingPopoverGeometryUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _pendingPopoverGeometryUpdate = false;
        return;
      }
      _refreshPopoverLayouts();
      _pendingPopoverGeometryUpdate = false;
    });
  }

  void _refreshPopoverLayouts() {
    final Iterable<String> trackedIds =
        List<String>.from(_taskPopoverController.layouts.keys);
    for (final String taskId in trackedIds) {
      _updateActivePopoverLayoutForTask(taskId);
    }
    final String? activeId = _taskPopoverController.activeTaskId;
    if (activeId != null && !trackedIds.contains(activeId)) {
      _updateActivePopoverLayoutForTask(activeId);
    }
  }

  List<Widget> _buildTaskEntries({
    required List<DateTime> columns,
    required Set<String> visibleTaskIds,
    required bool isDayView,
  }) {
    final List<Widget> entries = <Widget>[];
    final CalendarLayoutMetrics? resolvedMetrics =
        _surfaceController.resolvedMetrics;
    final double resolvedHourHeight = _effectiveHourHeight(resolvedMetrics);
    final double stepHeight = _effectiveStepHeight(resolvedMetrics);

    for (final DateTime date in columns) {
      final List<CalendarTask> tasks = _getTasksForDay(date);
      for (final CalendarTask task in tasks) {
        _visibleTasks[task.id] = task;
        visibleTaskIds.add(task.id);

        final CalendarTaskEntryBindings bindings = _createTaskBindings(
          task: task,
          stepHeight: stepHeight,
          hourHeight: resolvedHourHeight,
        );

        entries.add(
          CalendarSurfaceTaskEntry(
            key: ValueKey<String>('calendar-task-${task.id}'),
            task: task,
            bindings: bindings,
            child: CalendarTaskSurface(
              task: task,
              isDayView: isDayView,
              bindings: bindings,
            ),
          ),
        );
      }
    }

    return entries;
  }

  CalendarTaskEntryBindings _createTaskBindings({
    required CalendarTask task,
    required double stepHeight,
    required double hourHeight,
  }) {
    return CalendarTaskEntryBindings(
      isSelectionMode: _isSelectionMode,
      isSelected: _isTaskSelected(task),
      isPopoverOpen: _taskPopoverController.isPopoverOpen(task.id),
      dragTargetKey: _taskPopoverController.keyForTask(task.id),
      splitPreviewAnimationDuration: _layoutTheme.splitPreviewAnimationDuration,
      contextMenuGroupId: _contextMenuGroupId,
      contextMenuBuilderFactory: (menuController) =>
          _buildTaskContextMenuBuilder(
        task: task,
        menuController: menuController,
      ),
      interactionController: _taskInteractionController,
      dragFeedbackHint: _taskInteractionController.feedbackHint,
      callbacks: _buildTaskCallbacks(task),
      geometryProvider: _surfaceController.geometryForTask,
      globalRectProvider: _surfaceController.globalRectForTask,
      stepHeight: stepHeight,
      minutesPerStep: _minutesPerStep,
      hourHeight: hourHeight,
      addGeometryListener: _surfaceController.addGeometryListener,
      removeGeometryListener: _surfaceController.removeGeometryListener,
    );
  }

  CalendarTaskTileCallbacks _buildTaskCallbacks(CalendarTask task) {
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
    );
  }

  void _validateActivePopoverTarget(Set<String> activeIds) {
    final String? activeId = _taskPopoverController.activeTaskId;
    if (activeId == null) {
      return;
    }
    if (activeIds.contains(activeId)) {
      return;
    }
    final CalendarTask? resolved = _resolveTaskForId(activeId, widget.state);
    if (resolved == null) {
      _closeTaskPopover(activeId, reason: 'missing-task');
    }
  }

  void _cleanupTaskPopovers(Set<String> activeIds) {
    final removedIds = _taskPopoverController.cleanupLayouts(activeIds);
    for (final id in removedIds) {
      if (!mounted) continue;
      if (_taskPopoverController.activeTaskId == id) {
        _closeTaskPopover(id, reason: 'cleanup');
      }
    }
  }

  void _updateActivePopoverLayoutForTask(String taskId) {
    final CalendarTask? task = _visibleTasks[taskId];
    if (task == null) return;
    final Rect? rect = _surfaceController.globalRectForTask(taskId);
    if (rect == null) return;
    final layout = _calculateTaskPopoverLayout(rect);
    _taskPopoverController.setLayout(taskId, layout);
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
    if (_shouldUseSheetMenus(context)) {
      _showTaskEditSheet(task);
      return;
    }
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
    _armPopoverDismissQueue();
  }

  void _armPopoverDismissQueue() {
    if (!mounted) {
      return;
    }
    _taskPopoverController.markDismissReady();
    _activePopoverEntry?.markNeedsBuild();
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
                          if (mounted) {
                            _closeTaskPopover(
                              taskId,
                              reason: 'missing-task',
                            );
                          }
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
    _armPopoverDismissQueue();
  }

  Widget _buildDayHeaders(
    List<DateTime> weekDates,
    bool compact, {
    required bool isWeekView,
    double? compactWeekDayWidth,
    ScrollController? horizontalScrollController,
    bool enableHorizontalScroll = false,
  }) {
    final bool useScrollableWeekHeader =
        enableHorizontalScroll && compactWeekDayWidth != null;
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

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
          CustomPaint(
            painter: _TimeHeaderPainter(
              borderColor: calendarBorderDarkColor,
              strokeWidth: calendarBorderStroke,
              devicePixelRatio: devicePixelRatio,
            ),
            child: Container(
              width: _timeColumnWidth,
              color: calendarSidebarBackgroundColor,
            ),
          ),
          if (useScrollableWeekHeader)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: horizontalScrollController,
                child: Row(
                  children: weekDates.asMap().entries.map((entry) {
                    final date = entry.value;
                    return SizedBox(
                      width: compactWeekDayWidth,
                      child: _buildDayHeader(
                        date,
                        compact,
                        devicePixelRatio: devicePixelRatio,
                        showRightDivider:
                            entry.key != weekDates.length - 1 || !isWeekView,
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                children: weekDates.asMap().entries.map((entry) {
                  final date = entry.value;
                  return Expanded(
                    child: _buildDayHeader(
                      date,
                      compact,
                      devicePixelRatio: devicePixelRatio,
                      showRightDivider:
                          entry.key != weekDates.length - 1 || !isWeekView,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(
    DateTime date,
    bool compact, {
    required double devicePixelRatio,
    required bool showRightDivider,
  }) {
    final isToday = _isToday(date);

    return InkWell(
      onTap: widget.state.viewMode == CalendarView.week
          ? () => _selectDateAndSwitchToDay(date)
          : null,
      hoverColor: calendarSidebarBackgroundColor,
      child: CustomPaint(
        painter: _DayHeaderDividerPainter(
          devicePixelRatio: devicePixelRatio,
          strokeWidth: calendarBorderStroke,
          color: calendarBorderDarkColor,
          drawRightBorder: showRightDivider,
        ),
        child: Container(
          color: isToday
              ? calendarPrimaryColor.withValues(
                  alpha: calendarDayHeaderHighlightOpacity)
              : calendarBackgroundColor,
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
      ),
    );
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
    _handleAutoScrollForGlobal(globalPosition);
  }

  void _handleAutoScrollForGlobal(Offset globalPosition) {
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

    final bool isResizing =
        _taskInteractionController.activeResizeInteraction != null;
    const double resizeBandFactor = 0.55;
    const double resizeFastSpeedFactor = 0.4;
    const double resizeSlowSpeedFactor = 0.55;

    final double fastBandHeight = isResizing
        ? (_edgeScrollFastBandHeight * resizeBandFactor)
        : _edgeScrollFastBandHeight;
    final double slowBandHeight = isResizing
        ? (_edgeScrollSlowBandHeight * resizeBandFactor)
        : _edgeScrollSlowBandHeight;
    final double fastOffsetPerFrame = isResizing
        ? (_edgeScrollFastOffsetPerFrame * resizeFastSpeedFactor)
        : _edgeScrollFastOffsetPerFrame;
    final double slowOffsetPerFrame = isResizing
        ? (_edgeScrollSlowOffsetPerFrame * resizeSlowSpeedFactor)
        : _edgeScrollSlowOffsetPerFrame;

    double? offsetPerFrame;
    if (y <= fastBandHeight || y < 0) {
      offsetPerFrame = -fastOffsetPerFrame;
    } else if (y <= fastBandHeight + slowBandHeight) {
      offsetPerFrame = -slowOffsetPerFrame;
    } else if (y >= height - fastBandHeight || y > height) {
      offsetPerFrame = fastOffsetPerFrame;
    } else if (y >= height - (fastBandHeight + slowBandHeight)) {
      offsetPerFrame = slowOffsetPerFrame;
    }

    if (offsetPerFrame != null) {
      _handleEdgeAutoScrollMove(offsetPerFrame, globalPosition);
    } else {
      _stopEdgeAutoScroll();
    }
  }

  void _scrollToSlot(
    DateTime slotTime, {
    bool allowDeferral = true,
  }) {
    if (!_verticalController.hasClients) {
      if (allowDeferral) {
        _pendingScrollSlot = slotTime;
      } else {
        _pendingScrollSlot ??= slotTime;
      }
      return;
    }

    final position = _verticalController.position;
    if (!position.hasViewportDimension || position.viewportDimension <= 0) {
      if (allowDeferral) {
        _pendingScrollSlot = slotTime;
      } else {
        _pendingScrollSlot ??= slotTime;
      }
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

    final viewport = position.viewportDimension;
    final target =
        (offset - viewport / 2).clamp(0.0, position.maxScrollExtent).toDouble();

    _verticalController.animateTo(
      target,
      duration: _layoutTheme.scrollAnimationDuration,
      curve: Curves.easeOut,
    );
  }

  void _zoomToCell(DateTime slotTime) {
    if (_isZoomEnabled) {
      _pendingZoomScrollTarget = slotTime;
      _setZoomIndex(_zoomLevels.length - 1);
    } else {
      _scrollToSlot(slotTime);
    }
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
    if (!_autoScrollPending || _hasAutoScrolled || !mounted) return;
    if (!_verticalController.hasClients) {
      return;
    }
    final position = _verticalController.position;
    if (!position.hasViewportDimension || position.viewportDimension <= 0) {
      return;
    }
    _autoScrollPending = false;

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

    final viewport = position.viewportDimension;
    double target = offset - viewport / 2;
    target = target.clamp(0.0, position.maxScrollExtent).toDouble();
    _verticalController.jumpTo(target);
    _hasAutoScrolled = true;
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
    _pendingFocusRequest = request;
    _fulfillFocusRequestIfReady();
  }
}

class _TimeHeaderPainter extends CustomPainter {
  const _TimeHeaderPainter({
    required this.borderColor,
    required this.strokeWidth,
    required this.devicePixelRatio,
  });

  final Color borderColor;
  final double strokeWidth;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;

    final double halfStroke = strokeWidth / 2;
    final double snappedRight =
        ((size.width - halfStroke) * devicePixelRatio).roundToDouble() /
            devicePixelRatio;
    final Rect verticalRect = Rect.fromLTWH(
      snappedRight,
      0,
      strokeWidth,
      size.height,
    );
    canvas.drawRect(verticalRect, paint);

    final double snappedTop =
        (0.0 * devicePixelRatio).roundToDouble() / devicePixelRatio;
    final Rect horizontalRect = Rect.fromLTWH(
      0,
      snappedTop,
      size.width,
      strokeWidth,
    );
    canvas.drawRect(horizontalRect, paint);
  }

  @override
  bool shouldRepaint(covariant _TimeHeaderPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}

class _DayHeaderDividerPainter extends CustomPainter {
  const _DayHeaderDividerPainter({
    required this.devicePixelRatio,
    required this.strokeWidth,
    required this.color,
    required this.drawRightBorder,
  });

  final double devicePixelRatio;
  final double strokeWidth;
  final Color color;
  final bool drawRightBorder;

  @override
  void paint(Canvas canvas, Size size) {
    if (!drawRightBorder) {
      return;
    }
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final double halfStroke = strokeWidth / 2;
    final double snappedRight =
        ((size.width - halfStroke) * devicePixelRatio).roundToDouble() /
            devicePixelRatio;
    final Rect rect = Rect.fromLTWH(
      snappedRight,
      0,
      strokeWidth,
      size.height,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _DayHeaderDividerPainter oldDelegate) {
    return oldDelegate.devicePixelRatio != devicePixelRatio ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color ||
        oldDelegate.drawRightBorder != drawRightBorder;
  }
}

class _ZoomIntent extends Intent {
  const _ZoomIntent(this.action);

  final _ZoomAction action;
}

enum _ZoomAction { zoomIn, zoomOut, reset }
