// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'
    show SchedulerBinding, SchedulerPhase, Ticker;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart' show RenderBox, RendererBinding;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/calendar_share.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/calendar_task_share_sheet.dart';
import 'edit_task_dropdown.dart';
import 'models/task_context_action.dart';
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
import 'task_edit_session_tracker.dart';
import 'widgets/calendar_render_surface.dart';
import 'widgets/calendar_hover_title_bubble.dart';
import 'widgets/calendar_surface_drag_target.dart';
import 'widgets/calendar_task_surface.dart';
import 'widgets/day_event_editor.dart';
import 'widgets/calendar_task_geometry.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/task_form_section.dart';
import 'feedback_system.dart';
import 'widgets/critical_path_panel.dart';
import 'calendar_navigation.dart' show calendarUnitLabel, shiftedCalendarDate;

export 'layout/calendar_layout.dart' show OverlapInfo, calculateOverlapColumns;

const double _headerNavButtonExtent = 44.0;
const String _taskShareIcsActionLabel = 'Share as .ics';
const String _taskPopoverCloseReasonMissingTask = 'missing-task';
const String _taskPopoverCloseReasonSwitchTarget = 'switch-target';
const String _taskPopoverCloseReasonTaskDeleted = 'task-deleted';
const bool _calendarUseRootOverlay = false;

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
  final ValueListenable<bool>? cancelBucketHoverNotifier;

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
    this.cancelBucketHoverNotifier,
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
  static const int _defaultZoomIndex = 0;
  static const double _mobileCompactHourHeight = 60;
  static const int _resizeStepMinutes = 15;
  static const List<CalendarZoomLevel> _zoomLevels = kCalendarZoomLevels;
  static const CalendarLayoutTheme _layoutTheme = CalendarLayoutTheme.material;
  static const double _autoScrollHorizontalSlop = 32.0;
  final CalendarTransferService _transferService =
      const CalendarTransferService();

  double get _edgeScrollFastBandHeight => _layoutTheme.edgeScrollFastBandHeight;
  double get _edgeScrollSlowBandHeight => _layoutTheme.edgeScrollSlowBandHeight;
  double get _edgeScrollFastOffsetPerFrame =>
      _layoutTheme.edgeScrollFastOffsetPerFrame;
  double get _edgeScrollSlowOffsetPerFrame =>
      _layoutTheme.edgeScrollSlowOffsetPerFrame;
  double get _taskPopoverHorizontalGap => _layoutTheme.popoverGap;
  double get _zoomControlsElevation => _layoutTheme.zoomControlsElevation;
  double get _zoomControlsPaddingHorizontal =>
      _layoutTheme.zoomControlsPaddingHorizontal;
  double get _zoomControlsPaddingVertical =>
      _layoutTheme.zoomControlsPaddingVertical;
  double get _zoomControlsLabelPaddingHorizontal =>
      _layoutTheme.zoomControlsLabelPaddingHorizontal;
  double get _zoomControlsIconSize => _layoutTheme.zoomControlsIconSize;
  ValueListenable<bool> get _cancelBucketHoverNotifier =>
      widget.cancelBucketHoverNotifier ?? _defaultCancelBucketHoverNotifier;

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
  String? _inlineErrorMessage;
  Timer? _inlineErrorTimer;

  int _zoomIndex = _defaultZoomIndex;
  double _resolvedHourHeight = 78;
  double? _pendingAnchorMinutes;

  late final TaskInteractionController _taskInteractionController;
  late final TaskPopoverController _taskPopoverController;
  late final ZoomControlsController _zoomControlsController;
  static const ValueKey<String> _contextMenuGroupId =
      ValueKey<String>('calendar-grid-context');
  static const double _desktopHandleExtent = 8.0;
  static const double _touchHandleExtent = 28.0;
  static const Duration _touchDragLongPressDelay = Duration(milliseconds: 260);
  static const ValueListenable<bool> _defaultCancelBucketHoverNotifier =
      AlwaysStoppedAnimation<bool>(false);
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
  bool _viewportRequestScheduled = false;
  bool _scrollJumpScheduled = false;
  double? _pendingScrollJumpTarget;
  DateTime? _pendingScrollSlot;
  TaskFocusRequest? _pendingFocusRequest;
  Offset? _contextMenuAnchor;
  bool _pendingPopoverGeometryUpdate = false;
  bool _dragSessionNotified = false;
  bool _suppressNextEmptySlotTap = false;
  bool _hideCompletedScheduled = false;
  int _dateSlideDirection = 0;
  int? _surfacePointerTrackingId;
  Offset? _surfacePointerTrackingOrigin;
  bool _surfacePointerTrackingMoved = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Preserve an explicitly chosen day view when the grid is rebuilt
    // (e.g., after coming from the month surface).
    _desktopDayPinned = widget.state.viewMode == CalendarView.day;
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

  void _jumpToSafely(double target) {
    if (!_verticalController.hasClients) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _verticalController.jumpTo(target);
      return;
    }
    _pendingScrollJumpTarget = target;
    if (_scrollJumpScheduled) {
      return;
    }
    _scrollJumpScheduled = true;
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrollJumpScheduled = false;
      final pendingTarget = _pendingScrollJumpTarget;
      _pendingScrollJumpTarget = null;
      if (!mounted ||
          pendingTarget == null ||
          !_verticalController.hasClients) {
        return;
      }
      _verticalController.jumpTo(pendingTarget);
    });
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
      _jumpToSafely(clampedTarget);
    }

    _pendingAnchorMinutes = null;
  }

  void _handleScrollAttach() {
    if (!mounted) {
      return;
    }
    _scheduleViewportRequests();
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
    _scheduleViewportRequests();
  }

  void _scheduleViewportRequests() {
    if (_viewportRequestScheduled) {
      return;
    }
    _viewportRequestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportRequestScheduled = false;
      if (!mounted) {
        return;
      }
      _processViewportRequests();
    });
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
    context.read<T>().add(const CalendarEvent.taskFocusCleared());
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
      _dragFeedbackHint(
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

  DragFeedbackHint _dragFeedbackHint({
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
    _processFocusRequest(widget.focusRequest);
  }

  @override
  void dispose() {
    TaskEditSessionTracker.instance.endForOwner(this);
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
    _inlineErrorTimer?.cancel();
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

  void _copyTaskInstance(CalendarTask task) {
    final CalendarTask template = task.forClipboardInstance();
    _taskInteractionController.setClipboardTemplate(template);
  }

  void _copyTaskTemplate(CalendarTask task) {
    final CalendarTask template = task.forClipboardTemplate();
    _taskInteractionController.setClipboardTemplate(template);
  }

  Future<void> _copyTaskToClipboard(CalendarTask task) async {
    final String payload = task.toShareText();
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    FeedbackSystem.showSuccess(context, 'Task copied to clipboard');
  }

  Future<void> _shareTaskIcs(CalendarTask task) async {
    await showCalendarTaskShareSheet(
      context: context,
      task: task,
    );
  }

  Future<void> _exportTaskIcs(CalendarTask task) async {
    final l10n = context.l10n;
    final String trimmedTitle = task.title.trim();
    final String subject =
        trimmedTitle.isEmpty ? l10n.calendarExportFormatIcsTitle : trimmedTitle;
    final String shareText = '$subject (${l10n.calendarExportFormatIcsTitle})';
    try {
      final file = await _transferService.exportTaskIcs(task: task);
      if (!mounted) {
        return;
      }
      final CalendarShareOutcome shareOutcome = await shareCalendarExport(
        file: file,
        subject: subject,
        text: shareText,
      );
      if (!mounted) {
        return;
      }
      FeedbackSystem.showSuccess(
        context,
        calendarShareSuccessMessage(
          outcome: shareOutcome,
          filePath: file.path,
          sharedText: l10n.calendarExportReady,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      FeedbackSystem.showError(
        context,
        l10n.calendarExportFailed('$error'),
      );
    }
  }

  void _pasteTask(DateTime slotTime) {
    final template = _taskInteractionController.clipboardTemplate;
    if (template == null) {
      return;
    }
    _pasteTemplate(template, slotTime);
  }

  void _pasteTemplate(CalendarTask template, DateTime slotTime) {
    context.read<T>().add(
          CalendarEvent.taskRepeated(
            template: template,
            scheduledTime: slotTime,
          ),
        );
  }

  void _showZoomControls() {}

  void _enterSelectionMode(String taskId) {
    context.read<T>().add(CalendarEvent.selectionModeEntered(taskId: taskId));
  }

  void _toggleTaskSelection(String taskId) {
    context.read<T>().add(CalendarEvent.selectionToggled(taskId: taskId));
  }

  void _clearSelectionMode() {
    context.read<T>().add(const CalendarEvent.selectionCleared());
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
      snapshot: task.copyWith(),
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
      _dragFeedbackHint(
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
    context.read<T>().add(
          CalendarEvent.taskSplit(
            target: task,
            splitTime: splitTime,
          ),
        );
  }

  Future<void> _promptSplitTask(CalendarTask task) async {
    final DateTime? start = task.scheduledTime;
    DateTime? end = task.effectiveEndDate ??
        (start != null && task.duration != null
            ? start.add(task.duration!)
            : null);
    if (start == null || end == null || !end.isAfter(start)) {
      _showSplitError('Task must be scheduled to use split.');
      return;
    }
    final int totalMinutes = end.difference(start).inMinutes;
    final int minimumStep = math.max(_minutesPerStep, 15);
    if (totalMinutes < minimumStep * 2) {
      _showSplitError('Task is too short to split.');
      return;
    }
    final DateTime minSelectable = start.add(Duration(minutes: minimumStep));
    final DateTime maxSelectable = end.subtract(Duration(minutes: minimumStep));
    if (!maxSelectable.isAfter(minSelectable)) {
      _showSplitError('Task is too short to split.');
      return;
    }
    final DateTime midpoint = start.add(Duration(minutes: totalMinutes ~/ 2));
    final DateTime initialCandidate = midpoint.isBefore(minSelectable)
        ? minSelectable
        : (midpoint.isAfter(maxSelectable) ? maxSelectable : midpoint);
    final DateTime? picked = await showAdaptiveBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        return _SplitTaskPickerSheet(
          initialValue: initialCandidate,
          minTime: minSelectable,
          maxTime: maxSelectable,
        );
      },
    );
    if (picked == null) {
      return;
    }
    final DateTime clamped = picked.isBefore(minSelectable)
        ? minSelectable
        : (picked.isAfter(maxSelectable) ? maxSelectable : picked);
    final int elapsedMinutes = clamped.difference(start).inMinutes;
    final double fraction =
        totalMinutes <= 0 ? 0.5 : elapsedMinutes / totalMinutes;
    final DateTime? splitTime = task.splitTimeForFraction(
      fraction: fraction,
      minutesPerStep: _minutesPerStep,
    );
    if (splitTime == null ||
        !splitTime.isAfter(start) ||
        !splitTime.isBefore(end)) {
      _showSplitError('Unable to split task at that time.');
      return;
    }
    _splitTask(task, splitTime);
  }

  void _showSplitError(String message) {
    _inlineErrorTimer?.cancel();
    setState(() {
      _inlineErrorMessage = message;
    });
    _inlineErrorTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _inlineErrorMessage = null;
      });
    });
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
    if (surfaceObject is RenderBox) {
      final Offset surfaceOrigin = surfaceObject.localToGlobal(Offset.zero);
      final Rect surfaceBounds = surfaceOrigin & surfaceObject.size;
      if (!surfaceBounds.contains(details.globalPosition)) {
        _handleSurfaceDragExit();
        return;
      }
      final HitTestResult hitTest = HitTestResult();
      final FlutterView? implicitView =
          RendererBinding.instance.platformDispatcher.implicitView;
      if (implicitView == null) {
        _handleSurfaceDragExit();
        return;
      }
      RendererBinding.instance.hitTestInView(
        hitTest,
        details.globalPosition,
        implicitView.viewId,
      );
      final bool hitSurface =
          hitTest.path.any((entry) => identical(entry.target, surfaceObject));
      if (!hitSurface) {
        _handleSurfaceDragExit();
        return;
      }
    }
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
    if (oldWidget.state.viewMode != widget.state.viewMode) {
      _dateSlideDirection = 0;
    } else if (!_isSameDay(
      oldWidget.state.selectedDate,
      widget.state.selectedDate,
    )) {
      final DateTime previous = DateTime(
        oldWidget.state.selectedDate.year,
        oldWidget.state.selectedDate.month,
        oldWidget.state.selectedDate.day,
      );
      final DateTime next = DateTime(
        widget.state.selectedDate.year,
        widget.state.selectedDate.month,
        widget.state.selectedDate.day,
      );
      final int deltaDays = next.difference(previous).inDays;
      _dateSlideDirection =
          deltaDays == 0 ? 0 : (deltaDays.isNegative ? -1 : 1);
    }
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
      _viewTransitionController.reset();
      _viewTransitionController.forward();
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

  bool get _hasMouseInput =>
      RendererBinding.instance.mouseTracker.mouseIsConnected;

  bool get _shouldEnableTouchGridMenu => !_hasMouseInput;

  bool _shouldUseSheetMenus(BuildContext context) {
    return ResponsiveHelper.isCompact(context) || !_hasMouseInput;
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
    if (!TaskEditSessionTracker.instance.begin(task.id, this)) {
      return;
    }

    final String baseId = baseTaskIdFrom(task.id);
    final CalendarTask latestTask =
        context.read<T>().state.model.tasks[baseId] ?? task;
    final CalendarTask? storedTask =
        context.read<T>().state.model.tasks[task.id];
    final String? occurrenceKey = occurrenceKeyFrom(task.id);
    final CalendarTask? occurrenceTask =
        storedTask == null && occurrenceKey != null
            ? latestTask.occurrenceForId(task.id)
            : null;
    final CalendarTask displayTask = storedTask ?? occurrenceTask ?? latestTask;
    final bool shouldUpdateOccurrence =
        storedTask == null && occurrenceTask != null;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final locate = context.read;
    final CalendarTask? inlineTask =
        locate<T>().state.model.tasks[displayTask.id] ??
            locate<T>().state.model.tasks[displayTask.baseId];
    final List<TaskContextAction> inlineActions = _taskContextActions(
      task: inlineTask ?? displayTask,
      state: locate<T>().state,
      includeDeleteAction: false,
      includeCompletionAction: false,
      includePriorityActions: false,
      includeSplitAction: true,
      stripTaskKeyword: true,
    );
    final LocationAutocompleteHelper locationHelper =
        LocationAutocompleteHelper.fromState(locate<T>().state);
    final CalendarMethod? collectionMethod =
        locate<T>().state.model.collection?.method;

    try {
      await showAdaptiveBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        showCloseButton: false,
        builder: (sheetContext) {
          final mediaQuery = MediaQuery.of(sheetContext);
          final double maxHeight =
              mediaQuery.size.height - mediaQuery.viewPadding.vertical;
          return BlocProvider.value(
            value: locate<T>(),
            child: Builder(
              builder: (context) => EditTaskDropdown<T>(
                task: displayTask,
                maxHeight: maxHeight,
                isSheet: true,
                inlineActions: inlineActions,
                collectionMethod: collectionMethod,
                onClose: () => Navigator.of(sheetContext).maybePop(),
                scaffoldMessenger: scaffoldMessenger,
                locationHelper: locationHelper,
                onTaskUpdated: (updatedTask) {
                  locate<T>().add(
                    CalendarEvent.taskUpdated(
                      task: updatedTask,
                    ),
                  );
                },
                onOccurrenceUpdated: shouldUpdateOccurrence
                    ? (updatedTask, scope,
                        {required bool scheduleTouched,
                        required bool checklistTouched}) {
                        if (scheduleTouched || checklistTouched) {
                          locate<T>().add(
                            CalendarEvent.taskOccurrenceUpdated(
                              taskId: baseId,
                              occurrenceId: task.id,
                              scheduledTime: scheduleTouched
                                  ? updatedTask.scheduledTime
                                  : null,
                              duration:
                                  scheduleTouched ? updatedTask.duration : null,
                              endDate:
                                  scheduleTouched ? updatedTask.endDate : null,
                              checklist: checklistTouched
                                  ? updatedTask.checklist
                                  : null,
                              range: scope.range,
                            ),
                          );
                        }
                      }
                    : null,
                onTaskDeleted: (taskId) {
                  locate<T>().add(
                    CalendarEvent.taskDeleted(
                      taskId: taskId,
                    ),
                  );
                  Navigator.of(sheetContext).maybePop();
                },
              ),
            ),
          );
        },
      );
    } finally {
      TaskEditSessionTracker.instance.end(task.id, this);
    }
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

  void _handleHeaderNavigate(int steps) {
    final DateTime nextDate = shiftedCalendarDate(widget.state, steps);
    widget.onDateSelected(nextDate);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _hideCompletedScheduled =
        context.watch<SettingsCubit>().state.hideCompletedScheduled;
    _updateCompactState(context);
    return ResponsiveHelper.layoutBuilder(
      context,
      mobile: _CalendarWeekView(
        gridState: this,
        compact: true,
      ),
      tablet: _CalendarWeekView(
        gridState: this,
        compact: true,
        allowWeekViewInCompact: true,
      ),
      desktop: _CalendarWeekView(
        gridState: this,
        compact: false,
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

  void _handleSurfaceTap(CalendarSurfaceTapDetails details) {
    if (_suppressNextEmptySlotTap) {
      _suppressNextEmptySlotTap = false;
      return;
    }
    if (details.hitTask) {
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
    _showGridContextMenuAt(event.position);
  }

  void _handleGridLongPressStart(LongPressStartDetails details) {
    if (!_shouldEnableTouchGridMenu) {
      return;
    }
    _suppressNextEmptySlotTap = true;
    _taskInteractionController.suppressSurfaceTapOnce();
    _showGridContextMenuAt(details.globalPosition);
  }

  void _showGridContextMenuAt(Offset globalPosition) {
    final RenderObject? renderObject =
        _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderCalendarSurface) {
      _hideGridContextMenu();
      return;
    }
    final Offset localPosition = renderObject.globalToLocal(globalPosition);
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
      _contextMenuAnchor = globalPosition;
    });
    if (!_hasGridContextMenuItems()) {
      _hideGridContextMenu();
      return;
    }
    _gridContextMenuController.show();
  }

  bool _hasGridContextMenuItems() {
    return _taskInteractionController.clipboardTemplate != null ||
        widget.onEmptySlotTapped != null;
  }

  void _handleSurfaceHover(PointerHoverEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    final DateTime? slot = _slotForGlobalPosition(event.position);
    _updateHoveredSlot(slot);
  }

  void _handleSurfacePointerDown(PointerDownEvent event) {
    if (!_shouldTrackTouchHighlight(event.kind)) {
      return;
    }
    _surfacePointerTrackingId = event.pointer;
    _surfacePointerTrackingOrigin = event.position;
    _surfacePointerTrackingMoved = false;
    final DateTime? slot = _slotForGlobalPosition(event.position);
    _updateHoveredSlot(slot);
  }

  void _handleSurfacePointerMove(PointerMoveEvent event) {
    if (!_shouldTrackTouchHighlight(event.kind)) {
      return;
    }
    if (_surfacePointerTrackingId != event.pointer) {
      return;
    }
    final Offset? origin = _surfacePointerTrackingOrigin;
    if (origin == null || _surfacePointerTrackingMoved) {
      return;
    }
    final double distance = (event.position - origin).distance;
    if (distance > kTouchSlop) {
      _surfacePointerTrackingMoved = true;
    }
  }

  void _handleSurfacePointerUp(PointerUpEvent event) {
    if (!_shouldTrackTouchHighlight(event.kind)) {
      return;
    }
    final bool moved = _surfacePointerTrackingId == event.pointer &&
        _surfacePointerTrackingMoved;
    _surfacePointerTrackingId = null;
    _surfacePointerTrackingOrigin = null;
    _surfacePointerTrackingMoved = false;
    if (moved) {
      _suppressNextEmptySlotTap = true;
      _taskInteractionController.suppressSurfaceTapOnce();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _suppressNextEmptySlotTap = false;
      });
    }
    _clearSurfaceHover();
  }

  void _handleSurfacePointerCancel(PointerCancelEvent event) {
    if (!_shouldTrackTouchHighlight(event.kind)) {
      return;
    }
    _surfacePointerTrackingId = null;
    _surfacePointerTrackingOrigin = null;
    _surfacePointerTrackingMoved = false;
    _clearSurfaceHover();
  }

  bool _shouldTrackTouchHighlight(PointerDeviceKind kind) {
    return kind != PointerDeviceKind.mouse;
  }

  DateTime? _slotForGlobalPosition(Offset globalPosition) {
    final RenderObject? renderObject =
        _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderCalendarSurface) {
      return null;
    }
    final Offset localPosition = renderObject.globalToLocal(globalPosition);
    if (localPosition.dx <= _timeColumnWidth ||
        _surfaceController.containsTaskAt(localPosition)) {
      return null;
    }
    final DateTime? slot = _surfaceController.slotForOffset(localPosition);
    if (slot == null) {
      return null;
    }
    final int step = _minutesPerStep;
    final int snappedMinute = (slot.minute ~/ step) * step;
    return DateTime(
      slot.year,
      slot.month,
      slot.day,
      slot.hour,
      snappedMinute,
    );
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

  CalendarTaskEntryBindings _createTaskBindings({
    required CalendarTask task,
    required double stepHeight,
    required double hourHeight,
  }) {
    final bool hasMouse = _hasMouseInput;
    final bool enableContextMenus = hasMouse;
    return CalendarTaskEntryBindings(
      isSelectionMode: _isSelectionMode,
      isSelected: _isTaskSelected(task),
      isPopoverOpen: _taskPopoverController.isPopoverOpen(task.id),
      splitPreviewAnimationDuration: _layoutTheme.splitPreviewAnimationDuration,
      contextMenuGroupId: _contextMenuGroupId,
      contextMenuBuilderFactory: enableContextMenus
          ? (menuController) => _taskContextMenuBuilder(
                task: task,
                menuController: menuController,
              )
          : (_) => null,
      enableContextMenuLongPress: hasMouse,
      resizeHandleExtent: hasMouse ? _desktopHandleExtent : _touchHandleExtent,
      interactionController: _taskInteractionController,
      dragFeedbackHint: _taskInteractionController.feedbackHint,
      cancelBucketHoverNotifier: _cancelBucketHoverNotifier,
      callbacks: _taskCallbacks(task),
      geometryProvider: _surfaceController.geometryForTask,
      globalRectProvider: _surfaceController.globalRectForTask,
      stepHeight: stepHeight,
      minutesPerStep: _minutesPerStep,
      hourHeight: hourHeight,
      addGeometryListener: _surfaceController.addGeometryListener,
      removeGeometryListener: _surfaceController.removeGeometryListener,
      requiresLongPressToDrag: !hasMouse,
      longPressToDragDelay:
          hasMouse ? kLongPressTimeout : _touchDragLongPressDelay,
    );
  }

  CalendarTaskTileCallbacks _taskCallbacks(CalendarTask task) {
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
      onToggleCompletion: (target, completed) =>
          _setTaskCompletion(target, completed),
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
      _closeTaskPopover(activeId, reason: _taskPopoverCloseReasonMissingTask);
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
      TaskEditSessionTracker.instance.end(taskId, this);
      return;
    }

    _taskPopoverController.deactivate();
    _activePopoverEntry?.remove();
    _activePopoverEntry = null;
    TaskEditSessionTracker.instance.end(taskId, this);
  }

  void _openTaskPopover(CalendarTask task, TaskPopoverLayout layout) {
    final activeId = _taskPopoverController.activeTaskId;
    if (activeId != null && activeId != task.id) {
      _closeTaskPopover(activeId, reason: _taskPopoverCloseReasonSwitchTarget);
    }

    if (!TaskEditSessionTracker.instance.begin(task.id, this)) {
      return;
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

    final overlayState = Overlay.of(
      context,
      rootOverlay: _calendarUseRootOverlay,
    );
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
                    value: context.read<T>(),
                    child: BlocBuilder<T, CalendarState>(
                      builder: (context, state) {
                        final baseId = baseTaskIdFrom(taskId);
                        final latestTask = state.model.tasks[baseId];
                        if (latestTask == null) {
                          if (mounted) {
                            _closeTaskPopover(
                              taskId,
                              reason: _taskPopoverCloseReasonMissingTask,
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
                        final List<TaskContextAction> inlineActions =
                            _taskContextActions(
                          task: displayTask,
                          state: state,
                          onTaskDeleted: () => _closeTaskPopover(
                            taskId,
                            reason: _taskPopoverCloseReasonTaskDeleted,
                          ),
                          includeDeleteAction: false,
                          includeCompletionAction: false,
                          includePriorityActions: false,
                          includeSplitAction: true,
                          stripTaskKeyword: true,
                        );

                        return InBoundsFadeScale(
                          child: EditTaskDropdown<T>(
                            task: displayTask,
                            maxHeight: layout.maxHeight,
                            inlineActions: inlineActions,
                            collectionMethod: state.model.collection?.method,
                            onClose: () => _closeTaskPopover(taskId,
                                reason: 'dropdown-close'),
                            scaffoldMessenger: scaffoldMessenger,
                            locationHelper:
                                LocationAutocompleteHelper.fromState(state),
                            onTaskUpdated: (updatedTask) {
                              context.read<T>().add(
                                    CalendarEvent.taskUpdated(
                                      task: updatedTask,
                                    ),
                                  );
                            },
                            onOccurrenceUpdated: shouldUpdateOccurrence
                                ? (updatedTask, scope,
                                    {required bool scheduleTouched,
                                    required bool checklistTouched}) {
                                    if (scheduleTouched || checklistTouched) {
                                      context.read<T>().add(
                                            CalendarEvent.taskOccurrenceUpdated(
                                              taskId: baseId,
                                              occurrenceId: taskId,
                                              scheduledTime: scheduleTouched
                                                  ? updatedTask.scheduledTime
                                                  : null,
                                              duration: scheduleTouched
                                                  ? updatedTask.duration
                                                  : null,
                                              endDate: scheduleTouched
                                                  ? updatedTask.endDate
                                                  : null,
                                              checklist: checklistTouched
                                                  ? updatedTask.checklist
                                                  : null,
                                              range: scope.range,
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
                              _closeTaskPopover(
                                taskId,
                                reason: _taskPopoverCloseReasonTaskDeleted,
                              );
                            },
                          ),
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

    final Size viewportSize = renderObject.size;
    final double height = viewportSize.height;
    if (!height.isFinite || height <= 0) {
      return;
    }

    final double width = viewportSize.width;
    if (!width.isFinite || width <= 0) {
      _stopEdgeAutoScroll();
      return;
    }

    final Offset localPosition = renderObject.globalToLocal(globalPosition);
    final double pointerX = localPosition.dx;
    final bool isPointerWithinGrid = pointerX >= -_autoScrollHorizontalSlop &&
        pointerX <= width + _autoScrollHorizontalSlop;
    if (!isPointerWithinGrid) {
      _stopEdgeAutoScroll();
      return;
    }

    final double y = localPosition.dy;
    if (y < 0 || y > height) {
      _stopEdgeAutoScroll();
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
      context.read<T>().add(
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
      context.read<T>().add(
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
      context.read<T>().add(
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
    final CalendarTask? resolved =
        _resolveTaskForId(task.id, widget.state) ?? _visibleTasks[task.id];
    if (resolved == null) {
      FeedbackSystem.showError(context, 'Task not found');
      _handleTaskDragEnded(task);
      return;
    }
    _handleTaskDragEnded(resolved);
    final bool handled = _applySelectionDrag(resolved, dropTime);
    if (!handled) {
      widget.onTaskDragEnd?.call(resolved, dropTime);
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
    _jumpToSafely(target);
    _hasAutoScrolled = true;
  }

  bool _taskHasImportantFlag(CalendarTask task) =>
      task.isCritical || task.isImportant;

  bool _taskHasUrgentFlag(CalendarTask task) =>
      task.isCritical || task.isUrgent;

  TaskPriority _priorityFromFlags({
    required bool important,
    required bool urgent,
  }) {
    if (important && urgent) {
      return TaskPriority.critical;
    }
    if (important) {
      return TaskPriority.important;
    }
    if (urgent) {
      return TaskPriority.urgent;
    }
    return TaskPriority.none;
  }

  void _updateTaskPriority(
    CalendarTask task, {
    required bool important,
    required bool urgent,
  }) {
    final TaskPriority next =
        _priorityFromFlags(important: important, urgent: urgent);
    context.read<T>().add(
          CalendarEvent.taskPriorityChanged(
            taskId: task.baseId,
            priority: next,
          ),
        );
  }

  void _toggleTaskCompletion(CalendarTask task) {
    context.read<T>().add(
          CalendarEvent.taskCompleted(
            taskId: task.baseId,
            completed: !task.isCompleted,
          ),
        );
  }

  void _setTaskCompletion(CalendarTask task, bool completed) {
    context.read<T>().add(
          CalendarEvent.taskCompleted(
            taskId: task.baseId,
            completed: completed,
          ),
        );
  }

  Future<void> _showAddToCriticalPathPicker(CalendarTask task) async {
    await addTaskToCriticalPath(
      context: context,
      bloc: context.read<T>(),
      task: task,
    );
  }

  List<TaskContextAction> _taskContextActions({
    required CalendarTask task,
    required CalendarState state,
    VoidCallback? onTaskDeleted,
    bool includeDeleteAction = true,
    bool includeCompletionAction = true,
    bool includePriorityActions = true,
    bool includeSplitAction = false,
    bool stripTaskKeyword = false,
  }) {
    final List<TaskContextAction> actions = <TaskContextAction>[
      TaskContextAction(
        icon: Icons.copy_outlined,
        label: 'Copy Task',
        onSelected: () => _copyTaskInstance(task),
      ),
      TaskContextAction(
        icon: Icons.send,
        label: _taskShareIcsActionLabel,
        onSelected: () => _shareTaskIcs(task),
      ),
      TaskContextAction(
        icon: Icons.file_download_outlined,
        label: context.l10n.calendarExportFormatIcsTitle,
        onSelected: () => _exportTaskIcs(task),
      ),
      TaskContextAction(
        icon: Icons.share_outlined,
        label: 'Copy to Clipboard',
        onSelected: () => _copyTaskToClipboard(task),
      ),
      TaskContextAction(
        icon: Icons.route,
        label: 'Add to Critical Path',
        onSelected: () => _showAddToCriticalPathPicker(task),
      ),
    ];

    if (includeCompletionAction) {
      actions.add(
        TaskContextAction(
          icon: task.isCompleted ? Icons.undo : Icons.check_circle_outline,
          label: task.isCompleted ? 'Mark Incomplete' : 'Mark Complete',
          onSelected: () => _toggleTaskCompletion(task),
        ),
      );
    }

    if (includePriorityActions) {
      final bool importantFlag = _taskHasImportantFlag(task);
      final bool urgentFlag = _taskHasUrgentFlag(task);

      actions.add(
        TaskContextAction(
          icon: importantFlag ? Icons.label_off : Icons.label_important_outline,
          label: importantFlag ? 'Remove Important Flag' : 'Mark as Important',
          onSelected: () => _updateTaskPriority(
            task,
            important: !importantFlag,
            urgent: urgentFlag,
          ),
        ),
      );

      actions.add(
        TaskContextAction(
          icon: urgentFlag ? Icons.flash_on : Icons.flash_off,
          label: urgentFlag ? 'Remove Urgent Flag' : 'Mark as Urgent',
          onSelected: () => _updateTaskPriority(
            task,
            important: importantFlag,
            urgent: !urgentFlag,
          ),
        ),
      );
    }

    final CalendarTask? clipboardTemplate =
        _taskInteractionController.clipboardTemplate;
    if (clipboardTemplate != null && task.scheduledTime != null) {
      actions.add(
        TaskContextAction(
          icon: Icons.content_paste_outlined,
          label: context.l10n.calendarPasteTaskHere,
          onSelected: () => _pasteTask(task.scheduledTime!),
        ),
      );
    }

    final Set<String> seriesIds = _seriesIdsForTask(task, stateSnapshot: state);
    final bool selectionModeActive = state.isSelectionMode;
    final Set<String> selectedIds = state.selectedTaskIds;
    final bool hasSeriesGroup = seriesIds.length > 1;
    final bool isSeriesTask =
        hasSeriesGroup || task.isOccurrence || task.hasRecurrenceData;
    final bool isOccurrenceSelected = selectedIds.contains(task.id);
    final bool isSeriesSelected =
        hasSeriesGroup && seriesIds.every(selectedIds.contains);
    final bool isSelected = selectedIds.contains(task.id);

    if (isSeriesTask) {
      final String occurrenceLabel = selectionModeActive
          ? (isOccurrenceSelected ? 'Deselect Task' : 'Add Task to Selection')
          : 'Select Task';
      actions.add(
        TaskContextAction(
          icon: isOccurrenceSelected
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          label: occurrenceLabel,
          onSelected: () {
            if (selectionModeActive) {
              _toggleTaskSelection(task.id);
            } else {
              _enterSelectionMode(task.id);
            }
          },
        ),
      );

      final String seriesLabel = selectionModeActive
          ? (isSeriesSelected ? 'Deselect All Repeats' : 'Add All Repeats')
          : 'Select All Repeats';
      actions.add(
        TaskContextAction(
          icon: isSeriesSelected
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          label: seriesLabel,
          onSelected: () {
            if (isSeriesSelected) {
              context.read<T>().add(
                    CalendarEvent.selectionIdsRemoved(taskIds: seriesIds),
                  );
            } else {
              context.read<T>().add(
                    CalendarEvent.selectionIdsAdded(taskIds: seriesIds),
                  );
            }
          },
        ),
      );
    } else {
      final String selectionLabel = selectionModeActive
          ? (isSelected ? 'Deselect Task' : 'Add to Selection')
          : 'Select Task';
      actions.add(
        TaskContextAction(
          icon: isSelected ? Icons.check_box : Icons.check_box_outline_blank,
          label: selectionLabel,
          onSelected: () {
            if (selectionModeActive) {
              _toggleTaskSelection(task.id);
            } else {
              _enterSelectionMode(task.id);
            }
          },
        ),
      );
    }

    if (state.model.tasks.isNotEmpty) {
      actions.add(
        TaskContextAction(
          icon: Icons.select_all,
          label: 'Select All Tasks',
          onSelected: () {
            context.read<T>().add(const CalendarEvent.selectionAllRequested());
          },
        ),
      );
    }

    if (selectionModeActive) {
      actions.add(
        TaskContextAction(
          icon: Icons.highlight_off,
          label: 'Exit Selection Mode',
          onSelected: _clearSelectionMode,
        ),
      );
    }

    if (includeSplitAction) {
      actions.add(
        TaskContextAction(
          icon: Icons.call_split,
          label: 'Split Task',
          onSelected: () => _promptSplitTask(task),
        ),
      );
    }

    if (!task.isOccurrence) {
      actions.add(
        TaskContextAction(
          icon: Icons.copy_outlined,
          label: 'Copy Template',
          onSelected: () => _copyTaskTemplate(task),
        ),
      );
    }

    if (includeDeleteAction) {
      actions.add(
        TaskContextAction(
          icon: Icons.delete_outline,
          label: 'Delete Task',
          destructive: true,
          onSelected: () {
            context.read<T>().add(
                  CalendarEvent.taskDeleted(taskId: task.id),
                );
            onTaskDeleted?.call();
          },
        ),
      );
    }

    if (!stripTaskKeyword) {
      return actions;
    }
    return actions
        .map(
          (action) => TaskContextAction(
            icon: action.icon,
            label: _stripTaskKeyword(action.label),
            onSelected: action.onSelected,
            destructive: action.destructive,
          ),
        )
        .toList(growable: false);
  }

  String _stripTaskKeyword(String label) {
    final RegExp keyword = RegExp(r'\b[Tt]ask\b');
    final String stripped =
        label.replaceAll(keyword, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return stripped.isEmpty ? label : stripped;
  }

  TaskContextMenuBuilder _taskContextMenuBuilder({
    required CalendarTask task,
    required ShadPopoverController menuController,
  }) {
    return (context, request) {
      final ThemeData theme = Theme.of(context);
      final List<TaskContextAction> actions = _taskContextActions(
        task: task,
        state: widget.state,
      );
      final List<Widget> menuItems = actions
          .map(
            (action) => ShadContextMenuItem(
              leading: Icon(
                action.icon,
                color: action.destructive ? theme.colorScheme.error : null,
              ),
              onPressed: () {
                request.markCloseIntent();
                menuController.hide();
                action.onSelected();
              },
              child: Text(action.label),
            ),
          )
          .toList();

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

      return menuItems;
    };
  }

  Set<String> _seriesIdsForTask(
    CalendarTask task, {
    CalendarState? stateSnapshot,
  }) {
    final String baseId = task.baseId;
    final CalendarState snapshot = stateSnapshot ?? widget.state;
    final CalendarTask? baseTask = snapshot.model.tasks[baseId];
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

    for (final selected in snapshot.selectedTaskIds) {
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
    return tasks
        .where(_isTaskVisible)
        .where((task) => task.scheduledTime != null)
        .map((task) {
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

  List<CalendarAvailabilityWindow> _resolveAvailabilityWindows() {
    final Map<String, CalendarAvailability> availability =
        widget.state.model.availability;
    if (availability.isEmpty) {
      return const <CalendarAvailabilityWindow>[];
    }
    final List<CalendarAvailabilityWindow> windows =
        <CalendarAvailabilityWindow>[];
    for (final CalendarAvailability entry in availability.values) {
      if (entry.windows.isEmpty) {
        windows.add(
          CalendarAvailabilityWindow(
            start: entry.start,
            end: entry.end,
            summary: entry.summary,
            description: entry.description,
          ),
        );
        continue;
      }
      windows.addAll(entry.windows);
    }
    return windows;
  }

  List<CalendarAvailabilityOverlay> _resolveAvailabilityOverlays() {
    return const <CalendarAvailabilityOverlay>[];
  }

  bool _isTaskVisible(CalendarTask task) {
    if (_hideCompletedScheduled && task.isCompleted) {
      return false;
    }
    return widget.state.isTaskInFocusedPath(task);
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

  Future<void> _openDayEventEditor({
    required DateTime date,
    DayEvent? existing,
  }) async {
    final DayEventEditorResult? result = await showDayEventEditor(
      context: context,
      initialDate: date,
      existing: existing,
    );
    if (!mounted) {
      return;
    }
    if (result == null) {
      return;
    }
    if (result.deleted && existing != null) {
      context.read<T>().add(
            CalendarEvent.dayEventDeleted(eventId: existing.id),
          );
      return;
    }
    final DayEventDraft? draft = result.draft;
    if (draft == null) {
      return;
    }
    if (existing == null) {
      context.read<T>().add(
            CalendarEvent.dayEventAdded(
              title: draft.title,
              startDate: draft.startDate,
              endDate: draft.endDate,
              description: draft.description,
              reminders: draft.reminders,
              icsMeta: draft.icsMeta,
            ),
          );
      return;
    }

    final DayEvent updated = existing.normalizedCopy(
      title: draft.title,
      description: draft.description,
      startDate: draft.startDate,
      endDate: draft.endDate,
      reminders: draft.reminders,
      icsMeta: draft.icsMeta,
      modifiedAt: DateTime.now(),
    );
    context.read<T>().add(
          CalendarEvent.dayEventUpdated(event: updated),
        );
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
    if (request == null) {
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

class _CalendarWeekView extends StatelessWidget {
  const _CalendarWeekView({
    required this.gridState,
    required this.compact,
    this.allowWeekViewInCompact = false,
  });

  final _CalendarGridState gridState;
  final bool compact;
  final bool allowWeekViewInCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gridState._taskPopoverController,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: gridState._taskInteractionController,
          builder: (context, __) {
            final weekDates =
                gridState._getWeekDates(gridState.widget.state.selectedDate);
            final bool isWeekView =
                gridState.widget.state.viewMode == CalendarView.week &&
                    (!compact || allowWeekViewInCompact);
            final responsive = ResponsiveHelper.spec(context);
            final bool showHeaderNavigation =
                responsive.sizeClass != CalendarSizeClass.expanded;
            final headerDates =
                isWeekView ? weekDates : [gridState.widget.state.selectedDate];
            final List<DayEvent> selectedDayEvents = isWeekView
                ? const <DayEvent>[]
                : gridState.widget.state
                    .dayEventsForDate(gridState.widget.state.selectedDate);
            final double horizontalPadding =
                compact ? 0 : responsive.gridHorizontalPadding;

            final gridBody = LayoutBuilder(
              builder: (context, outerConstraints) {
                final double viewportWidth = outerConstraints.maxWidth;
                final double navControlsWidth =
                    showHeaderNavigation ? _headerNavButtonExtent * 2 : 0;
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
                    viewportWidth -
                        (horizontalPadding * 2) -
                        gridState._timeColumnWidth -
                        navControlsWidth,
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

                final Widget content = Container(
                  decoration: BoxDecoration(
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
                        child: _CalendarDayHeaderRow(
                          gridState: gridState,
                          weekDates: headerDates,
                          compact: compact,
                          isWeekView: isWeekView,
                          showNavigationControls: showHeaderNavigation,
                          compactWeekDayWidth: compactWeekDayWidth,
                          enableHorizontalScroll: enableHorizontalScroll,
                          horizontalScrollController: enableHorizontalScroll
                              ? gridState._horizontalHeaderController
                              : null,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: baseAnimationDuration,
                        child: gridState._inlineErrorMessage == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  calendarGutterSm,
                                  horizontalPadding,
                                  0,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: calendarGutterMd,
                                    vertical: calendarInsetLg,
                                  ),
                                  decoration: BoxDecoration(
                                    color: calendarDangerColor.withValues(
                                        alpha: 0.08),
                                    borderRadius: BorderRadius.circular(
                                      calendarBorderRadius,
                                    ),
                                    border: Border.all(
                                      color: calendarDangerColor.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 16,
                                        color: calendarDangerColor,
                                      ),
                                      const SizedBox(width: calendarInsetLg),
                                      Expanded(
                                        child: Text(
                                          gridState._inlineErrorMessage!,
                                          style:
                                              context.textTheme.small.copyWith(
                                            color: calendarDangerColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      if (!isWeekView)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            0,
                          ),
                          child: DayEventsStrip(
                            events: selectedDayEvents,
                            onAdd: () => gridState._openDayEventEditor(
                              date: gridState.widget.state.selectedDate,
                            ),
                            onEdit: (DayEvent event) =>
                                gridState._openDayEventEditor(
                              date: event.normalizedStart,
                              existing: event,
                            ),
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableHeight = constraints.maxHeight;
                            final bool isDayView = compact ||
                                gridState.widget.state.viewMode ==
                                    CalendarView.day;
                            gridState._resolvedHourHeight =
                                gridState._resolveHourHeight(
                              availableHeight,
                              isDayView: isDayView,
                            );
                            gridState._scheduleViewportRequests();
                            return Container(
                              decoration: BoxDecoration(
                                color: calendarStripedSlotColor,
                                borderRadius: BorderRadius.zero,
                              ),
                              child: SingleChildScrollView(
                                key: gridState._scrollableKey,
                                controller: gridState._verticalController,
                                child: _CalendarGridContent(
                                  gridState: gridState,
                                  isWeekView: isWeekView,
                                  weekDates: weekDates,
                                  compact: compact,
                                  compactWeekDayWidth: compactWeekDayWidth,
                                  enableHorizontalScroll:
                                      enableHorizontalScroll,
                                  horizontalScrollController:
                                      enableHorizontalScroll
                                          ? gridState._horizontalGridController
                                          : null,
                                  hoveredSlot: gridState._hoveredSlot,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );

                return _CalendarDateSlideTransition(
                  animation: gridState._viewTransitionAnimation,
                  direction: gridState._dateSlideDirection,
                  child: content,
                );
              },
            );

            return FocusableActionDetector(
              focusNode: gridState._focusNode,
              autofocus: true,
              shortcuts: gridState._zoomShortcuts,
              actions: {
                _ZoomIntent: CallbackAction<_ZoomIntent>(
                  onInvoke: (intent) {
                    switch (intent.action) {
                      case _ZoomAction.zoomIn:
                        gridState.zoomIn();
                        break;
                      case _ZoomAction.zoomOut:
                        gridState.zoomOut();
                        break;
                      case _ZoomAction.reset:
                        gridState.zoomReset();
                        break;
                    }
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => gridState._focusNode.requestFocus(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox.expand(child: gridBody),
                    const Positioned(
                      bottom: 0,
                      left: 0,
                      child: CalendarHoverTitleBubble(),
                    ),
                    Positioned(
                      bottom: compact ? 12 : 24,
                      right: compact ? 8 : 16,
                      child: _CalendarZoomControls(gridState: gridState),
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
}

class DayEventsStrip extends StatelessWidget {
  const DayEventsStrip({
    super.key,
    required this.events,
    required this.onAdd,
    required this.onEdit,
  });

  final List<DayEvent> events;
  final VoidCallback onAdd;
  final ValueChanged<DayEvent> onEdit;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final ShadTextTheme textTheme = context.textTheme;
    final bool hasEvents = events.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        calendarGutterMd,
        calendarInsetSm,
        calendarGutterMd,
        calendarInsetLg,
      ),
      color: colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Day events',
                style: textTheme.small.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              AxiIconButton(
                iconData: Icons.add,
                iconSize: 16,
                buttonSize: 28,
                tapTargetSize: 36,
                borderColor: Colors.transparent,
                borderWidth: 0,
                backgroundColor: colors.primary.withValues(alpha: 0.08),
                color: colors.primary,
                tooltip: context.l10n.calendarAddDayEvent,
                onPressed: onAdd,
              ).withTapBounce(),
            ],
          ),
          const SizedBox(height: calendarInsetSm),
          if (!hasEvents)
            Text(
              'No day-level events for this date',
              style: textTheme.small.copyWith(
                color: colors.mutedForeground,
                fontSize: 11,
              ),
            )
          else ...[
            ...events.map(
              (DayEvent event) => _DayEventBulletRow(
                event: event,
                onTap: () => onEdit(event),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayEventBulletRow extends StatelessWidget {
  const _DayEventBulletRow({
    required this.event,
    required this.onTap,
  });

  static const double _bulletSize = 6;

  final DayEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final ShadTextTheme textTheme = context.textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: calendarInsetSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  width: _bulletSize,
                  height: _bulletSize,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const WidgetSpan(
                child: SizedBox(width: calendarGutterSm),
              ),
              TextSpan(text: event.title),
            ],
          ),
          style: textTheme.small.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colors.foreground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _CalendarDateSlideTransition extends StatelessWidget {
  const _CalendarDateSlideTransition({
    required this.animation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool hasDirection = direction != 0;
    final Offset begin = hasDirection
        ? Offset(direction.isNegative ? -0.12 : 0.12, 0.0)
        : Offset.zero;
    final Animation<Offset> offsetAnimation = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: offsetAnimation,
        child: child,
      ),
    );
  }
}

class _CalendarGridContent extends StatelessWidget {
  const _CalendarGridContent({
    required this.gridState,
    required this.isWeekView,
    required this.weekDates,
    required this.compact,
    this.compactWeekDayWidth,
    this.horizontalScrollController,
    this.enableHorizontalScroll = false,
    this.hoveredSlot,
  });

  final _CalendarGridState gridState;
  final bool isWeekView;
  final List<DateTime> weekDates;
  final bool compact;
  final double? compactWeekDayWidth;
  final ScrollController? horizontalScrollController;
  final bool enableHorizontalScroll;
  final DateTime? hoveredSlot;

  @override
  Widget build(BuildContext context) {
    final bool allowHorizontalScroll =
        enableHorizontalScroll && compactWeekDayWidth != null;
    final responsive = ResponsiveHelper.spec(context);
    final List<DateTime> columns = isWeekView
        ? weekDates
        : <DateTime>[gridState.widget.state.selectedDate];
    final bool isDayView = !isWeekView;
    final Set<String> visibleTaskIds = <String>{};
    gridState._visibleTasks.clear();
    final CalendarLayoutMetrics? resolvedMetrics =
        gridState._surfaceController.resolvedMetrics;
    final double resolvedHourHeight =
        gridState._effectiveHourHeight(resolvedMetrics);
    final double stepHeight = gridState._effectiveStepHeight(resolvedMetrics);
    final List<Widget> taskEntries = <Widget>[];
    for (final DateTime date in columns) {
      final List<CalendarTask> tasks = gridState._getTasksForDay(date);
      for (final CalendarTask task in tasks) {
        gridState._visibleTasks[task.id] = task;
        visibleTaskIds.add(task.id);

        final CalendarTaskEntryBindings bindings =
            gridState._createTaskBindings(
          task: task,
          stepHeight: stepHeight,
          hourHeight: resolvedHourHeight,
        );

        final DateTime columnDate = DateTime(date.year, date.month, date.day);
        final String keyId =
            'calendar-task-${task.id}-${columnDate.toIso8601String()}';
        taskEntries.add(
          CalendarSurfaceTaskEntry(
            key: ValueKey<String>(keyId),
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

    gridState._cleanupTaskPopovers(visibleTaskIds);
    gridState._validateActivePopoverTarget(visibleTaskIds);

    final List<CalendarDayColumn> columnSpecs =
        columns.map((date) => CalendarDayColumn(date: date)).toList();

    final DateTime weekStartDate = DateTime(
      gridState.widget.state.weekStart.year,
      gridState.widget.state.weekStart.month,
      gridState.widget.state.weekStart.day,
    );
    final DateTime weekEndDate = DateTime(
      gridState.widget.state.weekEnd.year,
      gridState.widget.state.weekEnd.month,
      gridState.widget.state.weekEnd.day,
    );

    final List<CalendarAvailabilityWindow> availabilityWindows =
        gridState._resolveAvailabilityWindows();
    final List<CalendarAvailabilityOverlay> availabilityOverlays =
        gridState._resolveAvailabilityOverlays();

    final Widget renderSurface = CalendarRenderSurface(
      key: gridState._surfaceKey,
      columns: columnSpecs,
      startHour: _CalendarGridState.startHour,
      endHour: _CalendarGridState.endHour,
      zoomIndex: gridState._zoomIndex,
      allowDayViewZoom: gridState._shouldUseCompactZoom,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      layoutCalculator: gridState._layoutCalculator,
      layoutTheme: _CalendarGridState._layoutTheme,
      controller: gridState._surfaceController,
      verticalScrollController: gridState._verticalController,
      minutesPerStep: gridState._minutesPerStep,
      interactionController: gridState._taskInteractionController,
      availabilityWindows: availabilityWindows,
      availabilityOverlays: availabilityOverlays,
      hoveredSlot: hoveredSlot,
      onTap: gridState._handleSurfaceTap,
      dragPreview: gridState._taskInteractionController.preview.value,
      onDragUpdate: gridState._handleSurfaceDragUpdate,
      onDragEnd: gridState._handleSurfaceDragEnd,
      onDragExit: gridState._handleSurfaceDragExit,
      onDragAutoScroll: gridState._handleAutoScrollForGlobal,
      onDragAutoScrollStop: gridState._stopEdgeAutoScroll,
      isTaskDragInProgress: () =>
          gridState._taskInteractionController.draggingTaskId != null ||
          gridState._taskInteractionController.draggingTaskBaseId != null,
      onGeometryChanged: gridState._handleSurfaceGeometryChanged,
      children: taskEntries,
    );

    final Widget interactiveSurface = MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: gridState._handleSurfaceHover,
      onExit: (_) => gridState._clearSurfaceHover(),
      child: renderSurface,
    );

    final Widget dragAwareSurface = CalendarSurfaceDragTarget(
      controller: gridState._surfaceController,
      child: interactiveSurface,
    );

    Widget surface = dragAwareSurface;
    if (allowHorizontalScroll) {
      final double dayWidth = compactWeekDayWidth!;
      final double totalWidth =
          gridState._timeColumnWidth + (dayWidth * columnSpecs.length);
      surface = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller:
            horizontalScrollController ?? gridState._horizontalGridController,
        child: SizedBox(
          width: totalWidth,
          child: dragAwareSurface,
        ),
      );
    }

    final Widget menuSurface = _CalendarGridContextMenu(
      controller: gridState._gridContextMenuController,
      groupId: _CalendarGridState._contextMenuGroupId,
      anchor: gridState._contextMenuAnchor,
      slot: gridState._contextMenuSlot,
      clipboardTemplate: gridState._taskInteractionController.clipboardTemplate,
      onPointerDown: gridState._handleGridPointerDown,
      onHide: gridState._hideGridContextMenu,
      onPasteTask: gridState._pasteTask,
      onQuickAddTask: gridState.widget.onEmptySlotTapped == null
          ? null
          : (slot) => gridState.widget.onEmptySlotTapped!(slot, Offset.zero),
      child: surface,
    );

    final Widget highlightSurface = Listener(
      onPointerDown: gridState._handleSurfacePointerDown,
      onPointerMove: gridState._handleSurfacePointerMove,
      onPointerUp: gridState._handleSurfacePointerUp,
      onPointerCancel: gridState._handleSurfacePointerCancel,
      child: menuSurface,
    );

    final Widget touchAwareSurface = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: gridState._shouldEnableTouchGridMenu
          ? gridState._handleGridLongPressStart
          : null,
      child: highlightSurface,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : responsive.gridHorizontalPadding,
      ),
      child: touchAwareSurface,
    );
  }
}

class _CalendarGridContextMenu extends StatelessWidget {
  const _CalendarGridContextMenu({
    required this.controller,
    required this.groupId,
    required this.anchor,
    required this.slot,
    required this.clipboardTemplate,
    required this.onPointerDown,
    required this.onHide,
    required this.onPasteTask,
    this.onQuickAddTask,
    required this.child,
  });

  final ShadContextMenuController controller;
  final Object groupId;
  final Offset? anchor;
  final DateTime? slot;
  final CalendarTask? clipboardTemplate;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback onHide;
  final ValueChanged<DateTime> onPasteTask;
  final ValueChanged<DateTime>? onQuickAddTask;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: onPointerDown,
      child: AxiContextMenu(
        controller: controller,
        groupId: groupId,
        anchor: anchor == null ? null : ShadGlobalAnchor(anchor!),
        onTapOutside: (_) => onHide(),
        items: _menuItems(context),
        child: child,
      ),
    );
  }

  List<Widget> _menuItems(BuildContext context) {
    final DateTime? targetSlot = slot;
    if (targetSlot == null) {
      return const <Widget>[];
    }
    final List<Widget> items = <Widget>[];
    if (clipboardTemplate != null) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(Icons.content_paste_outlined),
          onPressed: () {
            onHide();
            onPasteTask(targetSlot);
          },
          child: Text(context.l10n.calendarPasteTaskHere),
        ),
      );
    }
    if (onQuickAddTask != null) {
      items.add(
        ShadContextMenuItem(
          leading: const Icon(Icons.add_circle_outline),
          onPressed: () {
            onHide();
            onQuickAddTask!(targetSlot);
          },
          child: Text(context.l10n.calendarQuickAddTask),
        ),
      );
    }
    return items;
  }
}

class _CalendarDayHeaderRow extends StatelessWidget {
  const _CalendarDayHeaderRow({
    required this.gridState,
    required this.weekDates,
    required this.compact,
    required this.isWeekView,
    required this.showNavigationControls,
    this.compactWeekDayWidth,
    this.horizontalScrollController,
    this.enableHorizontalScroll = false,
  });

  final _CalendarGridState gridState;
  final List<DateTime> weekDates;
  final bool compact;
  final bool isWeekView;
  final bool showNavigationControls;
  final double? compactWeekDayWidth;
  final ScrollController? horizontalScrollController;
  final bool enableHorizontalScroll;

  @override
  Widget build(BuildContext context) {
    final bool useScrollableWeekHeader =
        enableHorizontalScroll && compactWeekDayWidth != null;
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final l10n = context.l10n;
    final String unitLabel =
        calendarUnitLabel(gridState.widget.state.viewMode, l10n);
    final Widget? leadingNav = showNavigationControls
        ? _HeaderNavButton(
            icon: Icons.chevron_left,
            tooltip: l10n.calendarPreviousUnit(unitLabel),
            onPressed: () => gridState._handleHeaderNavigate(-1),
          )
        : null;
    final Widget? trailingNav = showNavigationControls
        ? _HeaderNavButton(
            icon: Icons.chevron_right,
            tooltip: l10n.calendarNextUnit(unitLabel),
            onPressed: () => gridState._handleHeaderNavigate(1),
          )
        : null;

    return Container(
      height: calendarWeekHeaderHeight,
      decoration: BoxDecoration(
        color: calendarBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: calendarBorderColor,
            width: calendarBorderStroke,
          ),
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Container(
            width: gridState._timeColumnWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: calendarBackgroundColor,
              border: Border(
                right: BorderSide(
                  color: calendarBorderDarkColor,
                  width: calendarBorderStroke,
                ),
              ),
            ),
            child: leadingNav,
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
                      child: _CalendarDayHeader(
                        gridState: gridState,
                        date: date,
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
                    child: _CalendarDayHeader(
                      gridState: gridState,
                      date: date,
                      devicePixelRatio: devicePixelRatio,
                      showRightDivider:
                          entry.key != weekDates.length - 1 || !isWeekView,
                    ),
                  );
                }).toList(),
              ),
            ),
          if (trailingNav != null) trailingNav,
        ],
      ),
    );
  }
}

class _HeaderNavButton extends StatelessWidget {
  const _HeaderNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final Widget button = ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: onPressed,
      foregroundColor: colors.primary,
      hoverForegroundColor: colors.primary,
      hoverBackgroundColor: colors.primary.withValues(alpha: 0.08),
      child: Icon(icon, size: 16),
    ).withTapBounce();

    return SizedBox(
      width: _headerNavButtonExtent,
      height: calendarWeekHeaderHeight,
      child: Center(
        child: AxiTooltip(
          builder: (_) => Text(tooltip),
          child: button,
        ),
      ),
    );
  }
}

class _CalendarDayHeader extends StatelessWidget {
  const _CalendarDayHeader({
    required this.gridState,
    required this.date,
    required this.devicePixelRatio,
    required this.showRightDivider,
  });

  final _CalendarGridState gridState;
  final DateTime date;
  final double devicePixelRatio;
  final bool showRightDivider;

  @override
  Widget build(BuildContext context) {
    final bool isToday = gridState._isToday(date);
    final int dayEventCount = gridState.widget.state.dayEventCountForDate(date);

    return InkWell(
      onTap: gridState.widget.state.viewMode == CalendarView.week
          ? () => gridState._selectDateAndSwitchToDay(date)
          : null,
      hoverColor: calendarSidebarBackgroundColor,
      child: CustomPaint(
        painter: _DayHeaderDividerPainter(
          devicePixelRatio: devicePixelRatio,
          strokeWidth: calendarBorderStroke,
          color: calendarBorderDarkColor,
          drawRightBorder: showRightDivider,
        ),
        child: Stack(
          children: [
            Container(
              color: isToday
                  ? calendarPrimaryColor.withValues(
                      alpha: calendarDayHeaderHighlightOpacity,
                    )
                  : calendarBackgroundColor,
              child: Center(
                child: Text(
                  '${gridState._getDayOfWeekShort(date).substring(0, 3)} ${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isToday ? calendarPrimaryColor : calendarTitleColor,
                    letterSpacing: calendarDayHeaderLetterSpacing,
                  ),
                ),
              ),
            ),
            if (dayEventCount > 0)
              Positioned(
                top: 6,
                right: 8,
                child: DayEventBadge(count: dayEventCount),
              ),
          ],
        ),
      ),
    );
  }
}

class DayEventBadge extends StatelessWidget {
  const DayEventBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: calendarPrimaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: colors.primaryForeground,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CalendarZoomControls extends StatelessWidget {
  const _CalendarZoomControls({required this.gridState});

  final _CalendarGridState gridState;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    const double zoomControlsShadowAlpha = 0.12;
    final Color zoomControlsShadowColor = Theme.of(context)
        .shadowColor
        .withValues(alpha: zoomControlsShadowAlpha);
    final labelStyle = calendarZoomLabelTextStyle.copyWith(
      color: colors.foreground,
      fontFamily: theme.textTheme.small.fontFamily,
      letterSpacing: 0.2,
    );
    final bool canZoomOut = gridState._isZoomEnabled && gridState._canZoomOut;
    final bool canZoomIn = gridState._isZoomEnabled && gridState._canZoomIn;

    Widget buildButton({
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      final button = ShadIconButton.ghost(
        icon: Icon(icon, size: gridState._zoomControlsIconSize),
        padding: const EdgeInsets.all(8),
        onPressed: onPressed,
        enabled: onPressed != null,
      );
      return AxiTooltip(
        builder: (_) => Text(tooltip),
        child: button,
      );
    }

    return Material(
      elevation: gridState._zoomControlsElevation + 1,
      color: colors.card,
      shadowColor: zoomControlsShadowColor,
      shape: SquircleBorder(
        cornerRadius: 26,
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: gridState._zoomControlsPaddingHorizontal + 4,
          vertical: gridState._zoomControlsPaddingVertical + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildButton(
              tooltip: context.l10n.calendarZoomOut,
              icon: Icons.remove,
              onPressed: canZoomOut ? gridState.zoomOut : null,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: gridState._zoomControlsLabelPaddingHorizontal + 2,
              ),
              child: Text(
                gridState._zoomLabel,
                style: labelStyle,
              ),
            ),
            buildButton(
              tooltip: context.l10n.calendarZoomIn,
              icon: Icons.add,
              onPressed: canZoomIn ? gridState.zoomIn : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitTaskPickerSheet extends StatefulWidget {
  const _SplitTaskPickerSheet({
    required this.initialValue,
    required this.minTime,
    required this.maxTime,
  });

  final DateTime initialValue;
  final DateTime minTime;
  final DateTime maxTime;

  @override
  State<_SplitTaskPickerSheet> createState() => _SplitTaskPickerSheetState();
}

class _SplitTaskPickerSheetState extends State<_SplitTaskPickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = _clamp(widget.initialValue);
  }

  DateTime _clamp(DateTime value) {
    if (value.isBefore(widget.minTime)) {
      return widget.minTime;
    }
    if (value.isAfter(widget.maxTime)) {
      return widget.maxTime;
    }
    return value;
  }

  void _handleSubmit() {
    Navigator.of(context).maybePop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(
      calendarGutterLg,
      0,
      calendarGutterLg,
      calendarGutterLg,
    );
    return AxiSheetScaffold.scroll(
      header: AxiSheetHeader(
        title: Text(context.l10n.calendarSplitTaskAt),
        onClose: () => Navigator.of(context).maybePop(),
        padding: const EdgeInsets.fromLTRB(
          calendarGutterLg,
          calendarGutterLg,
          calendarGutterLg,
          calendarInsetMd,
        ),
      ),
      bodyPadding: sheetPadding,
      children: [
        DeadlinePickerField(
          value: _selected,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _selected = _clamp(value);
            });
          },
          placeholder: 'Select split time',
          showStatusColors: false,
          minDate: widget.minTime,
          maxDate: widget.maxTime,
        ),
        const SizedBox(height: calendarGutterLg),
        TaskFormActionsRow(
          padding: EdgeInsets.zero,
          gap: 12,
          children: [
            Expanded(
              child: TaskSecondaryButton(
                label: context.l10n.commonCancel,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: TaskPrimaryButton(
                label: 'Split Task',
                onPressed: _handleSubmit,
              ),
            ),
          ],
        ),
      ],
    );
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
