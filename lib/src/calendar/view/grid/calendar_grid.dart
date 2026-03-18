// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/interop/calendar_share.dart';
import 'package:axichat/src/calendar/interop/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/view/tasks/location_autocomplete.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';
import 'package:axichat/src/calendar/view/shell/responsive_helper.dart';
import 'package:axichat/src/calendar/task/task_share_formatter.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_task_share_sheet.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/common/ui/axi_surface_scope.dart' as axi_surface;
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox, RendererBinding;
import 'package:flutter/scheduler.dart'
    show SchedulerBinding, SchedulerPhase, Ticker;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/view/shell/calendar_navigation.dart'
    show calendarUnitLabel, shiftedCalendarDate;
import 'package:axichat/src/calendar/view/grid/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/tasks/task_popover_controller.dart';
import 'package:axichat/src/calendar/view/tasks/edit_task_dropdown.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/grid/calendar_layout.dart'
    show
        CalendarLayoutMetrics,
        CalendarLayoutTheme,
        CalendarZoomLevel,
        kCalendarZoomLevels,
        resolveCalendarLayoutMetrics;
import 'package:axichat/src/calendar/view/tasks/resizable_task_widget.dart';
import 'package:axichat/src/calendar/view/tasks/task_edit_session_tracker.dart';
import 'calendar_hover_title_bubble.dart';
import 'calendar_render_surface.dart';
import 'calendar_surface_drag_target.dart';
import 'calendar_task_surface.dart';
import 'package:axichat/src/calendar/view/sidebar/critical_path_panel.dart';
import 'package:axichat/src/calendar/view/month/day_event_editor.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_date_time_field.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';

export 'package:axichat/src/calendar/view/grid/calendar_layout.dart'
    show OverlapInfo, calculateOverlapColumns;

const double _headerNavButtonExtent = 44.0;
const String _taskPopoverCloseReasonMissingTask = 'missing-task';
const String _taskPopoverCloseReasonSwitchTarget = 'switch-target';
const String _taskPopoverCloseReasonTaskDeleted = 'task-deleted';

class ZoomControlsController extends ChangeNotifier {
  ZoomControlsController({
    Duration autoHideDuration = const Duration(seconds: 5),
    bool initiallyVisible = false,
  }) : _autoHideDuration = autoHideDuration,
       _isVisible = initiallyVisible;

  final Duration _autoHideDuration;
  bool _isVisible;
  Timer? _autoHideTimer;
  bool _disposed = false;

  bool get isVisible => _isVisible;

  void show() {
    if (_autoHideDuration <= Duration.zero) {
      _autoHideTimer?.cancel();
    } else {
      _startTimer();
    }
    _setVisible(true);
  }

  void hide() {
    _autoHideTimer?.cancel();
    _setVisible(false);
  }

  void _startTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(_autoHideDuration, () {
      if (_disposed) {
        return;
      }
      _setVisible(false);
    });
  }

  void _setVisible(bool next) {
    if (_isVisible == next || _disposed) {
      return;
    }
    _isVisible = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoHideTimer?.cancel();
    super.dispose();
  }
}

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
  final ValueListenable<bool>? nonGridDragRegionHoverNotifier;
  final ValueListenable<bool>? composeWindowDragRegionHoverNotifier;
  final ValueListenable<int>? dragCompletionRevision;

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
    this.nonGridDragRegionHoverNotifier,
    this.composeWindowDragRegionHoverNotifier,
    this.dragCompletionRevision,
  });

  @override
  State<CalendarGrid<T>> createState() => _CalendarGridState<T>();
}

class _CalendarGridState<T extends BaseCalendarBloc>
    extends State<CalendarGrid<T>>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<CalendarGrid<T>>,
        axi_surface.AxiSurfaceRegistration<CalendarGrid<T>> {
  static const int startHour = 0;
  static const int endHour = 24;
  static const int _defaultZoomIndex = 1;
  static const double _mobileCompactHourHeight = 60;
  static const int _resizeStepMinutes = 15;
  static const List<CalendarZoomLevel> _zoomLevels = kCalendarZoomLevels;
  final CalendarTransferService _transferService =
      const CalendarTransferService();

  ValueListenable<bool> get _cancelBucketHoverNotifier =>
      widget.cancelBucketHoverNotifier ?? _defaultCancelBucketHoverNotifier;
  ValueListenable<bool> get _nonGridDragRegionHoverNotifier =>
      widget.nonGridDragRegionHoverNotifier ??
      _defaultNonGridDragRegionHoverNotifier;
  ValueListenable<bool> get _composeWindowDragRegionHoverNotifier =>
      widget.composeWindowDragRegionHoverNotifier ??
      _defaultNonGridDragRegionHoverNotifier;
  ValueListenable<int> get _dragCompletionRevision =>
      widget.dragCompletionRevision ?? _defaultDragCompletionRevision;

  late AnimationController _viewTransitionController;
  late Animation<double> _viewTransitionAnimation;
  late final ScrollController _verticalController;
  late final ScrollController _horizontalHeaderController;
  late final ScrollController _horizontalGridController;
  final GlobalKey _scrollableKey = GlobalKey(
    debugLabel: 'CalendarVerticalScroll',
  );
  final FocusNode _focusNode = FocusNode(debugLabel: 'CalendarGridFocus');
  Timer? _clockTimer;
  bool _hasAutoScrolled = false;
  final OverlayPortalController _taskPopoverPortalController =
      OverlayPortalController();
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
  static const ValueKey<String> _contextMenuGroupId = ValueKey<String>(
    'calendar-grid-context',
  );
  static const double _desktopHandleExtent = 8.0;
  static const double _touchHandleExtent = 28.0;
  static const Duration _touchDragLongPressDelay =
      calendarScrollAnimationDuration;
  static const ValueListenable<bool> _defaultCancelBucketHoverNotifier =
      AlwaysStoppedAnimation<bool>(false);
  static const ValueListenable<bool> _defaultNonGridDragRegionHoverNotifier =
      AlwaysStoppedAnimation<bool>(false);
  static const ValueListenable<int> _defaultDragCompletionRevision =
      AlwaysStoppedAnimation<int>(0);
  Ticker? _edgeAutoScrollTicker;
  final Map<String, CalendarTask> _visibleTasks = <String, CalendarTask>{};
  final CalendarSurfaceController _surfaceController =
      CalendarSurfaceController();
  final GlobalKey _surfaceKey = GlobalKey(debugLabel: 'calendar-surface');
  late final ShadPopoverController _gridContextMenuController;
  DateTime? _contextMenuSlot;
  double _edgeAutoScrollOffsetPerFrame = 0;
  Timer? _edgeAutoPageTimer;
  CalendarInteractionHorizontalIntent _edgeAutoPageIntent =
      CalendarInteractionHorizontalIntent.neutral;
  int _lastDragCompletionRevision = 0;
  int? _activeTaskDragPointerId;

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
  bool _pendingInteractionViewportRefresh = false;
  CalendarInteractionSession? _lastNotifiedTaskSurfaceDragSession;
  bool _hideCompletedScheduled = false;
  int _dateSlideDirection = 0;
  bool _isSyntheticDragRefresh = false;

  @override
  bool get isAxiSurfaceOpen => _taskPopoverController.activeTaskId != null;

  @override
  VoidCallback? get onAxiSurfaceDismiss => () {
    final String? activeId = _taskPopoverController.activeTaskId;
    if (activeId != null) {
      _closeTaskPopover(activeId, reason: 'surface-back');
    }
  };

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
    _verticalController.addListener(_handleViewportScrollChanged);
    _horizontalHeaderController = ScrollController();
    _horizontalGridController = ScrollController();
    _horizontalHeaderController.addListener(_handleHorizontalHeaderScroll);
    _horizontalGridController.addListener(_handleHorizontalGridScroll);
    _taskInteractionController = TaskInteractionController(
      onTaskInteracted: _handleTaskInteractionAcknowledged,
    );
    _gridContextMenuController = ShadPopoverController();
    _taskInteractionController.clipboard.addListener(_handleClipboardChanged);
    _taskInteractionController.preview.addListener(_handleDragPreviewChanged);
    _taskInteractionController.interactionSession.addListener(
      _handleInteractionSessionChanged,
    );
    _cancelBucketHoverNotifier.addListener(_handleBottomDragChromeHoverChanged);
    _nonGridDragRegionHoverNotifier.addListener(
      _handleNonGridDragRegionHoverChanged,
    );
    _lastDragCompletionRevision = _dragCompletionRevision.value;
    _dragCompletionRevision.addListener(_handleDragCompletionRevisionChanged);
    _taskPopoverController = TaskPopoverController();
    _zoomControlsController = ZoomControlsController(
      autoHideDuration: Duration.zero,
      initiallyVisible: true,
    );
    _clockTimer = Timer.periodic(calendarClockTickInterval, (_) {
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

  bool _isChatCalendar(BuildContext context) {
    try {
      context.read<ChatCalendarBloc>();
      return true;
    } catch (_) {
      return false;
    }
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
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.numpadSubtract,
    ): const _ZoomIntent(
      _ZoomAction.zoomOut,
    ),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.minus):
        const _ZoomIntent(_ZoomAction.zoomOut),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.numpadSubtract):
        const _ZoomIntent(_ZoomAction.zoomOut),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit0):
        const _ZoomIntent(_ZoomAction.reset),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit0):
        const _ZoomIntent(_ZoomAction.reset),
  };

  String zoomLabel(AppLocalizations l10n) {
    if (!_isZoomEnabled) {
      return l10n.calendarZoomLabelMinutes(15);
    }
    return _currentZoom.localizedLabel(l10n);
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

  void cycleZoom() {
    if (!_isZoomEnabled) {
      return;
    }
    final int nextIndex = _zoomIndex >= _zoomLevels.length - 1
        ? 0
        : _zoomIndex + 1;
    _setZoomIndex(nextIndex);
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
    final double anchorMinutes = _pendingAnchorMinutes!
        .clamp(0.0, maxMinutes)
        .toDouble();
    final double targetOffset =
        _minutesToOffset(anchorMinutes, _resolvedHourHeight) -
        (position.viewportDimension / 2.0);
    final double clampedTarget = targetOffset
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();

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
    _handleViewportScrollChanged();
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
    _handleViewportScrollChanged();
  }

  void _handleViewportScrollChanged() {
    if (_taskPopoverController.activeTaskId != null) {
      _refreshPopoverLayouts();
    }
    _refreshActiveInteractionFromSession();
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

  void _handleEdgeAutoScrollMove(double offsetPerFrame) {
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
    final CalendarInteractionSession? session =
        _taskInteractionController.activeInteractionSession;
    if (session == null) {
      _stopEdgeAutoScroll();
      return;
    }
    if (_edgeAutoScrollOffsetPerFrame.abs() >= 0.01 &&
        _verticalController.hasClients) {
      final position = _verticalController.position;
      final double currentOffset = _verticalController.offset;
      final double nextOffset = (currentOffset + _edgeAutoScrollOffsetPerFrame)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      final double appliedDelta = nextOffset - currentOffset;
      if (appliedDelta.abs() > 0.1) {
        _verticalController.jumpTo(nextOffset);
        if (session.isResize) {
          _taskInteractionController.dispatchResizeAutoScrollDelta(
            appliedDelta,
          );
        } else if (session.isDrag) {
          _refreshActiveInteractionFromSession();
        }
      } else {
        _edgeAutoScrollOffsetPerFrame = 0;
        if (session.verticalIntent !=
            CalendarInteractionVerticalIntent.neutral) {
          _taskInteractionController.updateInteractionEdgeIntent(
            verticalIntent: CalendarInteractionVerticalIntent.neutral,
            horizontalIntent: session.horizontalIntent,
          );
        }
      }
    }

    if (_edgeAutoScrollOffsetPerFrame.abs() < 0.01) {
      _stopEdgeAutoScroll();
    }
  }

  void _stopEdgeAutoScroll() {
    _edgeAutoScrollOffsetPerFrame = 0;
    if (_edgeAutoScrollTicker?.isActive ?? false) {
      _edgeAutoScrollTicker!.stop();
    }
  }

  void _cancelEdgeAutoPageTimer() {
    _edgeAutoPageTimer?.cancel();
    _edgeAutoPageTimer = null;
    _edgeAutoPageIntent = CalendarInteractionHorizontalIntent.neutral;
  }

  void _startEdgeAutoPageTimer({
    required CalendarInteractionHorizontalIntent intent,
    required Duration delay,
  }) {
    _edgeAutoPageTimer?.cancel();
    _edgeAutoPageIntent = intent;
    _edgeAutoPageTimer = Timer(delay, () {
      _handleEdgeAutoPageTimerFired(intent);
    });
  }

  void _updateEdgeAutoPageTimer(
    CalendarInteractionHorizontalIntent intent, {
    bool startRepeat = false,
  }) {
    final CalendarInteractionSession? session =
        _taskInteractionController.activeInteractionSession;
    if (_isAnyNonGridDragRegionHovering ||
        session == null ||
        !session.isDrag ||
        intent == CalendarInteractionHorizontalIntent.neutral) {
      _cancelEdgeAutoPageTimer();
      return;
    }
    if (!startRepeat &&
        _edgeAutoPageTimer != null &&
        _edgeAutoPageIntent == intent) {
      return;
    }
    final CalendarLayoutTheme layoutTheme = CalendarLayoutTheme.fromContext(
      context,
    );
    _startEdgeAutoPageTimer(
      intent: intent,
      delay: layoutTheme.edgeAutoPageDebounceDelay,
    );
  }

  void _handleEdgeAutoPageTimerFired(
    CalendarInteractionHorizontalIntent intent,
  ) {
    _edgeAutoPageTimer = null;
    if (!mounted) {
      return;
    }
    if (intent == CalendarInteractionHorizontalIntent.neutral) {
      return;
    }
    final int steps = intent == CalendarInteractionHorizontalIntent.backward
        ? -1
        : 1;
    widget.onDateSelected(shiftedCalendarDate(widget.state, steps));
    _scheduleInteractionViewportRefresh();
    _updateEdgeAutoPageTimer(intent, startRepeat: true);
  }

  void _updateDragFeedbackWidth(
    double width, {
    bool forceCenterPointer = false,
    bool forceApply = false,
  }) {
    if (width <= 0) {
      return;
    }

    final double currentWidth =
        _taskInteractionController.activeDragWidth ??
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

    final CalendarLayoutTheme layoutTheme = CalendarLayoutTheme.fromContext(
      context,
    );
    _taskInteractionController.schedulePendingWidth(
      width: width,
      forceCenter: forceCenterPointer,
      delay: layoutTheme.dragWidthDebounceDelay,
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
    final double currentWidth =
        _taskInteractionController.activeDragWidth ??
        _taskInteractionController.draggingTaskWidth ??
        width;
    final bool widthChanged = (currentWidth - width).abs() > 0.5;
    final bool shouldCenter = forceCenterPointer || widthChanged;
    double normalizedPointer = _taskInteractionController.dragPointerNormalized
        .clamp(0.0, 1.0);
    final double pointerGlobalX =
        _taskInteractionController.dragPointerGlobalX ??
        (_taskInteractionController.dragStartGlobalLeft ?? 0.0) +
            (currentWidth * normalizedPointer);
    if (shouldCenter) {
      normalizedPointer = 0.5;
      _taskInteractionController.setDragPointerNormalized(normalizedPointer);
    }
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _processFocusRequest(widget.focusRequest);
    syncAxiSurfaceRegistration(notify: false);
  }

  @override
  void dispose() {
    TaskEditSessionTracker.instance.endForOwner(this);
    _viewTransitionController.dispose();
    _clockTimer?.cancel();
    _verticalController.removeListener(_handleViewportScrollChanged);
    _verticalController.dispose();
    if (_taskPopoverPortalController.isShowing) {
      _taskPopoverPortalController.hide();
    }
    _focusNode.dispose();
    _zoomControlsController.dispose();
    _edgeAutoScrollTicker?.dispose();
    _edgeAutoPageTimer?.cancel();
    _taskInteractionController.clipboard.removeListener(
      _handleClipboardChanged,
    );
    _taskInteractionController.preview.removeListener(
      _handleDragPreviewChanged,
    );
    _taskInteractionController.interactionSession.removeListener(
      _handleInteractionSessionChanged,
    );
    _detachTaskDragPointerRoute();
    _cancelBucketHoverNotifier.removeListener(
      _handleBottomDragChromeHoverChanged,
    );
    _nonGridDragRegionHoverNotifier.removeListener(
      _handleNonGridDragRegionHoverChanged,
    );
    _dragCompletionRevision.removeListener(
      _handleDragCompletionRevisionChanged,
    );
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

  void _attachTaskDragPointerRoute(int? pointerId) {
    if (_activeTaskDragPointerId == pointerId) {
      return;
    }
    _detachTaskDragPointerRoute();
    if (pointerId == null) {
      return;
    }
    RendererBinding.instance.pointerRouter.addRoute(
      pointerId,
      _handleTaskDragPointerRoute,
    );
    _activeTaskDragPointerId = pointerId;
  }

  void _detachTaskDragPointerRoute() {
    final int? pointerId = _activeTaskDragPointerId;
    if (pointerId == null) {
      return;
    }
    RendererBinding.instance.pointerRouter.removeRoute(
      pointerId,
      _handleTaskDragPointerRoute,
    );
    _activeTaskDragPointerId = null;
  }

  void _handleTaskDragPointerRoute(PointerEvent event) {
    final int? pointerId = _activeTaskDragPointerId;
    if (pointerId == null || event.pointer != pointerId) {
      return;
    }
    if (event is PointerMoveEvent) {
      _handleTaskDragGlobalPosition(event.position);
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _detachTaskDragPointerRoute();
    }
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

  void _handleDragPreviewChanged() {
    _surfaceController.updateDragPreview(
      _taskInteractionController.preview.value,
    );
  }

  void _handleInteractionSessionChanged() {
    final CalendarInteractionSession? session =
        _taskInteractionController.activeInteractionSession;
    final CalendarInteractionSession? previous =
        _lastNotifiedTaskSurfaceDragSession;
    final bool wasActive = previous != null;
    final bool isActive =
        session != null &&
        session.isDrag &&
        session.source == CalendarInteractionSource.taskSurface;

    if (wasActive &&
        (!isActive ||
            session.taskId != previous.taskId ||
            session.source != previous.source)) {
      widget.onDragSessionEnded?.call();
    }

    if (!isActive) {
      _detachTaskDragPointerRoute();
      _lastNotifiedTaskSurfaceDragSession = null;
      return;
    }

    if (!wasActive || session.taskId != previous.taskId) {
      _attachTaskDragPointerRoute(
        _taskInteractionController.activeDragPointerId,
      );
      _lastNotifiedTaskSurfaceDragSession = session;
      _handleTaskDragStarted();
      _handleTaskDragGlobalPosition(
        session.globalPosition,
        markDragMoved: false,
      );
      widget.onDragSessionStarted?.call();
      widget.onDragGlobalPositionChanged?.call(session.globalPosition);
      return;
    }

    if (session.globalPosition != previous.globalPosition) {
      widget.onDragGlobalPositionChanged?.call(session.globalPosition);
    }
    _lastNotifiedTaskSurfaceDragSession = session;
  }

  void _handleBottomDragChromeHoverChanged() {
    if (_cancelBucketHoverNotifier.value) {
      _clearActiveInteractionEdgeIntent(clearPreview: true);
    }
  }

  void _handleNonGridDragRegionHoverChanged() {
    if (_nonGridDragRegionHoverNotifier.value) {
      _clearActiveInteractionEdgeIntent(clearPreview: true);
    }
  }

  bool get _isAnyNonGridDragRegionHovering =>
      _cancelBucketHoverNotifier.value || _nonGridDragRegionHoverNotifier.value;

  void _clearActiveInteractionEdgeIntent({bool clearPreview = false}) {
    final CalendarInteractionSession? session =
        _taskInteractionController.activeInteractionSession;
    if (session != null &&
        (session.verticalIntent != CalendarInteractionVerticalIntent.neutral ||
            session.horizontalIntent !=
                CalendarInteractionHorizontalIntent.neutral)) {
      _taskInteractionController.updateInteractionEdgeIntent(
        verticalIntent: CalendarInteractionVerticalIntent.neutral,
        horizontalIntent: CalendarInteractionHorizontalIntent.neutral,
      );
    }
    if (clearPreview) {
      _clearDragPreview();
    }
    _stopEdgeAutoScroll();
    _cancelEdgeAutoPageTimer();
  }

  void _handleDragCompletionRevisionChanged() {
    final int revision = _dragCompletionRevision.value;
    if (revision == _lastDragCompletionRevision) {
      return;
    }
    _lastDragCompletionRevision = revision;
    _stopEdgeAutoScroll();
    final bool hasLingeringDrag =
        _taskInteractionController.draggingTaskId != null ||
        _taskInteractionController.draggingTaskBaseId != null ||
        _taskInteractionController.preview.value != null ||
        _taskInteractionController.activeInteractionSession?.isDrag == true;
    if (!hasLingeringDrag) {
      return;
    }
    _cancelPendingDragWidth();
    _taskInteractionController.endDrag();
    _cancelEdgeAutoPageTimer();
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
    final String payload = task.toShareText(context.l10n);
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    FeedbackSystem.showSuccess(
      context,
      context.l10n.calendarTaskCopiedToClipboard,
    );
  }

  Future<void> _shareTaskIcs(CalendarTask task) async {
    await showCalendarTaskShareSheet(context: context, task: task);
  }

  Future<void> _exportTaskIcs(CalendarTask task) async {
    final l10n = context.l10n;
    final String trimmedTitle = task.title.trim();
    final String subject = trimmedTitle.isEmpty
        ? l10n.calendarExportFormatIcsTitle
        : trimmedTitle;
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
      FeedbackSystem.showError(context, l10n.calendarExportFailed('$error'));
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
      CalendarEvent.taskRepeated(template: template, scheduledTime: slotTime),
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

  void _handleTaskDragStarted() {
    _stopEdgeAutoScroll();
    _cancelPendingDragWidth();
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
      CalendarEvent.taskSplit(target: task, splitTime: splitTime),
    );
  }

  Future<void> _promptSplitTask(CalendarTask task) async {
    final l10n = context.l10n;
    final DateTime? start = task.scheduledTime;
    DateTime? end =
        task.effectiveEndDate ??
        (start != null && task.duration != null
            ? start.add(task.duration!)
            : null);
    if (start == null || end == null || !end.isAfter(start)) {
      _showSplitError(l10n.calendarTaskSplitRequiresSchedule);
      return;
    }
    final int totalMinutes = end.difference(start).inMinutes;
    final int minimumStep = math.max(_minutesPerStep, 15);
    if (totalMinutes < minimumStep * 2) {
      _showSplitError(l10n.calendarTaskSplitTooShort);
      return;
    }
    final DateTime minSelectable = start.add(Duration(minutes: minimumStep));
    final DateTime maxSelectable = end.subtract(Duration(minutes: minimumStep));
    if (!maxSelectable.isAfter(minSelectable)) {
      _showSplitError(l10n.calendarTaskSplitTooShort);
      return;
    }
    final DateTime midpoint = start.add(Duration(minutes: totalMinutes ~/ 2));
    final DateTime initialCandidate = midpoint.isBefore(minSelectable)
        ? minSelectable
        : (midpoint.isAfter(maxSelectable) ? maxSelectable : midpoint);
    final BuildContext modalContext = context.calendarModalContext;
    final DateTime? picked = await showAdaptiveBottomSheet<DateTime>(
      context: modalContext,
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
    final double fraction = totalMinutes <= 0
        ? 0.5
        : elapsedMinutes / totalMinutes;
    final DateTime? splitTime = task.splitTimeForFraction(
      fraction: fraction,
      minutesPerStep: _minutesPerStep,
    );
    if (splitTime == null ||
        !splitTime.isAfter(start) ||
        !splitTime.isBefore(end)) {
      _showSplitError(l10n.calendarTaskSplitUnable);
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
    if (_activeTaskDragPointerId != null) {
      return;
    }
    _handleTaskDragGlobalPosition(details.globalPosition);
  }

  void _handleTaskDragGlobalPosition(
    Offset globalPosition, {
    bool markDragMoved = true,
  }) {
    final CalendarTask? draggingTask =
        _taskInteractionController.draggingTaskSnapshot;
    if (draggingTask == null) {
      return;
    }
    _taskInteractionController.updateDragPointerGlobalPosition(globalPosition);
    if (_isAnyNonGridDragRegionHovering) {
      _clearActiveInteractionEdgeIntent(clearPreview: true);
      return;
    }
    final double? startLeft = _taskInteractionController.dragStartGlobalLeft;
    final double baseWidth =
        _taskInteractionController.dragInitialWidth ??
        _taskInteractionController.draggingTaskWidth ??
        0.0;
    if (startLeft == null || baseWidth <= 0) {
      return;
    }
    final double widthForNormalization =
        _taskInteractionController.activeDragWidth ??
        _taskInteractionController.draggingTaskWidth ??
        baseWidth;
    final double normalized = widthForNormalization <= 0
        ? 0.5
        : ((globalPosition.dx - startLeft) / widthForNormalization).clamp(
            0.0,
            1.0,
          );
    const double movementThreshold = 0.001;
    if (markDragMoved &&
        (_taskInteractionController.dragPointerNormalized - normalized).abs() >
            movementThreshold) {
      _taskInteractionController.markDragMoved();
    }
    _taskInteractionController.setDragPointerNormalized(normalized);
    if (widthForNormalization > 0) {
      _taskInteractionController.dragAnchorDx =
          widthForNormalization *
          _taskInteractionController.dragPointerNormalized;
    }
    _isSyntheticDragRefresh = !markDragMoved;
    final bool handled = _surfaceController.dispatchActiveDragUpdate(
      globalPosition,
      markDragMoved: markDragMoved,
    );
    _isSyntheticDragRefresh = false;
    if (!handled) {
      _clearDragPreview();
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
    _cancelEdgeAutoPageTimer();
    _stopEdgeAutoScroll();
  }

  @override
  void didUpdateWidget(covariant CalendarGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.cancelBucketHoverNotifier,
      widget.cancelBucketHoverNotifier,
    )) {
      (oldWidget.cancelBucketHoverNotifier ?? _defaultCancelBucketHoverNotifier)
          .removeListener(_handleBottomDragChromeHoverChanged);
      _cancelBucketHoverNotifier.addListener(
        _handleBottomDragChromeHoverChanged,
      );
    }
    if (!identical(
      oldWidget.nonGridDragRegionHoverNotifier,
      widget.nonGridDragRegionHoverNotifier,
    )) {
      (oldWidget.nonGridDragRegionHoverNotifier ??
              _defaultNonGridDragRegionHoverNotifier)
          .removeListener(_handleNonGridDragRegionHoverChanged);
      _nonGridDragRegionHoverNotifier.addListener(
        _handleNonGridDragRegionHoverChanged,
      );
    }
    if (!identical(
      oldWidget.dragCompletionRevision,
      widget.dragCompletionRevision,
    )) {
      (oldWidget.dragCompletionRevision ?? _defaultDragCompletionRevision)
          .removeListener(_handleDragCompletionRevisionChanged);
      _lastDragCompletionRevision = _dragCompletionRevision.value;
      _dragCompletionRevision.addListener(_handleDragCompletionRevisionChanged);
    }
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
      _dateSlideDirection = deltaDays == 0
          ? 0
          : (deltaDays.isNegative ? -1 : 1);
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
      oldWidget.state.selectedDate,
      widget.state.selectedDate,
    )) {
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

  void _handleTaskInteractionAcknowledged(String taskBaseId) {
    if (!mounted) {
      return;
    }
    context.read<T>().acknowledgeTaskInteraction(taskBaseId);
  }

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
    final CalendarTask? storedTask = context
        .read<T>()
        .state
        .model
        .tasks[task.id];
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
    final calendarBloc = locate<T>();

    try {
      final BuildContext modalContext = context.calendarModalContext;
      await showAdaptiveBottomSheet<void>(
        context: modalContext,
        isScrollControlled: true,
        useBottomSafeArea: false,
        surfacePadding: EdgeInsets.zero,
        showCloseButton: false,
        builder: (sheetContext) {
          final mediaQuery = MediaQuery.of(sheetContext);
          final double maxHeight =
              mediaQuery.size.height - mediaQuery.viewPadding.vertical;
          return BlocProvider.value(
            value: calendarBloc,
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
                  context.read<T>().add(
                    CalendarEvent.taskUpdated(task: updatedTask),
                  );
                },
                onOccurrenceUpdated: shouldUpdateOccurrence
                    ? (
                        updatedTask,
                        scope, {
                        required bool scheduleTouched,
                        required bool checklistTouched,
                      }) {
                        if (scheduleTouched || checklistTouched) {
                          context.read<T>().add(
                            CalendarEvent.taskOccurrenceUpdated(
                              taskId: baseId,
                              occurrenceId: task.id,
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
                onTaskDeleted: (taskId) {
                  context.read<T>().add(
                    CalendarEvent.taskDeleted(taskId: taskId),
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
    _hideCompletedScheduled = context
        .watch<SettingsCubit>()
        .state
        .hideCompletedScheduled;
    _updateCompactState(context);
    return OverlayPortal(
      controller: _taskPopoverPortalController,
      overlayChildBuilder: _buildTaskPopoverOverlay,
      child: ResponsiveHelper.layoutBuilder(
        context,
        mobile: _CalendarWeekView(gridState: this, compact: true),
        tablet: _CalendarWeekView(
          gridState: this,
          compact: true,
          allowWeekViewInCompact: true,
        ),
        desktop: _CalendarWeekView(gridState: this, compact: false),
      ),
    );
  }

  double _resolveHourHeight(
    double availableHeight, {
    required bool isDayView,
    required CalendarLayoutTheme layoutTheme,
  }) {
    var metrics = resolveCalendarLayoutMetrics(
      theme: layoutTheme,
      zoomLevels: kCalendarZoomLevels,
      zoomIndex: _zoomIndex,
      isDayView: isDayView,
      availableHeight: availableHeight,
      allowDayViewZoom: _shouldUseCompactZoom,
    );
    if (_shouldUseCompactZoom && _zoomIndex == 0) {
      final double compactHourHeight = math.min(
        metrics.hourHeight,
        _mobileCompactHourHeight,
      );
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

  double _currentViewportScrollOffset() {
    if (!_verticalController.hasClients) {
      return 0;
    }
    return _verticalController.offset;
  }

  void _handleEmptySurfaceTapUp(TapUpDetails details) {
    final DateTime? slotStart = _slotForGlobalPosition(details.globalPosition);
    if (slotStart == null) {
      return;
    }
    if (widget.state.viewMode == CalendarView.day) {
      final DateTime normalized = DateTime(
        slotStart.year,
        slotStart.month,
        slotStart.day,
      );
      if (!DateUtils.isSameDay(widget.state.selectedDate, normalized)) {
        widget.onDateSelected(normalized);
      }
    }
    widget.onEmptySlotTapped?.call(slotStart, Offset.zero);
  }

  void _handleGridPointerDown(PointerDownEvent event) {
    _clearSurfaceHover();
    final RenderObject? renderObject = _surfaceKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderCalendarSurface) {
      _hideGridContextMenu();
      return;
    }
    final bool isSecondaryClick =
        event.kind == PointerDeviceKind.mouse &&
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
    _showGridContextMenuAt(details.globalPosition);
  }

  void _showGridContextMenuAt(Offset globalPosition) {
    final RenderObject? renderObject = _surfaceKey.currentContext
        ?.findRenderObject();
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
    final DateTime? slot = _slotForGlobalPosition(event.position);
    _updateHoveredSlot(slot);
  }

  void _handleSurfacePointerMove(PointerMoveEvent event) {
    if (!_shouldTrackTouchHighlight(event.kind)) {
      return;
    }
    final DateTime? slot = _slotForGlobalPosition(event.position);
    _updateHoveredSlot(slot);
  }

  void _handleSurfacePointerUp(PointerUpEvent event) {
    if (!_shouldTrackTouchHighlight(event.kind)) {
      return;
    }
    _clearSurfaceHover();
  }

  void _handleSurfacePointerCancel(PointerCancelEvent event) {
    if (!_shouldTrackTouchHighlight(event.kind)) {
      return;
    }
    _clearSurfaceHover();
  }

  bool _shouldTrackTouchHighlight(PointerDeviceKind kind) {
    return kind != PointerDeviceKind.mouse &&
        _taskInteractionController.activeInteractionSession == null;
  }

  DateTime? _slotForGlobalPosition(Offset globalPosition) {
    final RenderObject? renderObject = _surfaceKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderCalendarSurface) {
      return null;
    }
    final Offset localPosition = renderObject.globalToLocal(globalPosition);
    if (localPosition.dx <= renderObject.layoutTheme.timeColumnWidth ||
        _surfaceController.containsTaskAt(localPosition)) {
      return null;
    }
    final DateTime? slot = _surfaceController.slotForOffset(localPosition);
    if (slot == null) {
      return null;
    }
    final int step = _minutesPerStep;
    final int snappedMinute = (slot.minute ~/ step) * step;
    return DateTime(slot.year, slot.month, slot.day, slot.hour, snappedMinute);
  }

  void _updateHoveredSlot(DateTime? slot) {
    final DateTime? current = _hoveredSlot;
    final bool unchanged =
        (current == null && slot == null) ||
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

  void _handleSurfaceDragUpdate(CalendarSurfaceDragUpdateDetails details) {
    final CalendarTask? dragging =
        _taskInteractionController.draggingTaskSnapshot;
    if (dragging == null) {
      return;
    }
    _updateDragPreview(details.previewStart, details.previewDuration);

    final double? columnWidth =
        details.columnWidth ??
        _surfaceController.columnWidthForOffset(details.localPosition);
    final double baselineWidth =
        _taskInteractionController.dragInitialWidth ??
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
  }

  void _handleSurfaceDragExit() {
    _clearDragPreview();
    _cancelPendingDragWidth();
    if (_taskInteractionController.activeInteractionSession == null) {
      _clearActiveInteractionEdgeIntent();
    }
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
      final CalendarInteractionSession? session =
          _taskInteractionController.activeInteractionSession;
      if (session?.isDrag == true) {
        _refreshActiveInteractionFromSession();
      }
      _pendingPopoverGeometryUpdate = false;
    });
  }

  void _scheduleInteractionViewportRefresh() {
    if (!mounted || _pendingInteractionViewportRefresh) {
      return;
    }
    _pendingInteractionViewportRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingInteractionViewportRefresh = false;
      if (!mounted) {
        return;
      }
      _refreshActiveInteractionFromSession();
    });
  }

  void _refreshActiveInteractionFromSession() {
    final CalendarInteractionSession? session =
        _taskInteractionController.activeInteractionSession;
    if (session == null) {
      return;
    }
    if (_isAnyNonGridDragRegionHovering) {
      _clearActiveInteractionEdgeIntent(clearPreview: true);
      return;
    }
    if (session.isDrag) {
      _handleTaskDragGlobalPosition(
        session.globalPosition,
        markDragMoved: false,
      );
      return;
    }
    if (session.isResize) {
      _taskInteractionController.dispatchResizeAutoScrollDelta(0);
    }
  }

  void _refreshPopoverLayouts() {
    final Iterable<String> trackedIds = List<String>.from(
      _taskPopoverController.layouts.keys,
    );
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
    final CalendarLayoutTheme layoutTheme = CalendarLayoutTheme.fromContext(
      context,
    );
    final bool hasMouse = _hasMouseInput;
    final bool enableContextMenus = hasMouse;
    return CalendarTaskEntryBindings(
      isSelectionMode: _isSelectionMode,
      isSelected: _isTaskSelected(task),
      isPopoverOpen: _taskPopoverController.isPopoverOpen(task.id),
      splitPreviewAnimationDuration: layoutTheme.splitPreviewAnimationDuration,
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
      cancelBucketHoverNotifier: _cancelBucketHoverNotifier,
      composeWindowDragRegionHoverNotifier:
          _composeWindowDragRegionHoverNotifier,
      callbacks: _taskCallbacks(task),
      geometryProvider: _surfaceController.geometryForTask,
      globalRectProvider: _surfaceController.globalRectForTask,
      stepHeight: stepHeight,
      minutesPerStep: _minutesPerStep,
      hourHeight: hourHeight,
      viewportScrollOffsetProvider: _currentViewportScrollOffset,
      addGeometryListener: _surfaceController.addGeometryListener,
      removeGeometryListener: _surfaceController.removeGeometryListener,
      requiresLongPressToDrag: !hasMouse,
      longPressToDragDelay: hasMouse
          ? kLongPressTimeout
          : _touchDragLongPressDelay,
    );
  }

  CalendarTaskTileCallbacks _taskCallbacks(CalendarTask task) {
    return CalendarTaskTileCallbacks(
      onResizePreview: _handleResizePreview,
      onResizeEnd: _handleResizeCommit,
      onResizePointerMove: _handleResizeAutoScroll,
      onDragStarted: _handleTaskDragStarted,
      resolveDragOriginSlot: (dragTask) =>
          _computeOriginSlot(dragTask.scheduledTime),
      onDragUpdate: _handleTaskDragUpdate,
      onDragEnded: _handleTaskDragEnded,
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
    final CalendarLayoutTheme layoutTheme = CalendarLayoutTheme.fromContext(
      context,
    );
    return calculateTaskPopoverLayout(
      bounds: bounds,
      screenSize: mediaQuery.size,
      safePadding: mediaQuery.padding,
      screenMargin: context.spacing.m,
      popoverGap: layoutTheme.popoverGap,
      bottomInset: mediaQuery.viewInsets.bottom,
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
      syncAxiSurfaceRegistration();
      return;
    }

    _taskPopoverController.deactivate();
    if (_taskPopoverPortalController.isShowing) {
      _taskPopoverPortalController.hide();
    }
    syncAxiSurfaceRegistration();
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
    syncAxiSurfaceRegistration();
    _armPopoverDismissQueue();
  }

  void _armPopoverDismissQueue() {
    if (!mounted) {
      return;
    }
    _taskPopoverController.markDismissReady();
  }

  void _ensurePopoverEntry() {
    if (_taskPopoverPortalController.isShowing) {
      return;
    }
    _taskPopoverPortalController.show();
    _armPopoverDismissQueue();
  }

  Widget _buildTaskPopoverOverlay(BuildContext overlayContext) {
    return ListenableBuilder(
      listenable: _taskPopoverController,
      builder: (context, _) {
        final String? taskId = _taskPopoverController.activeTaskId;
        if (taskId == null) {
          return const SizedBox.shrink();
        }
        final TaskPopoverLayout layout = _taskPopoverController.layoutFor(
          taskId,
        );
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(overlayContext);
        final RenderBox? overlayBox =
            Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
        final Offset offset = overlayBox == null
            ? layout.topLeft
            : overlayBox.globalToLocal(layout.topLeft);

        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  final String? currentId = _taskPopoverController.activeTaskId;
                  if (currentId == null ||
                      !_taskPopoverController.dismissArmed) {
                    return;
                  }
                  final RenderBox? currentOverlayBox =
                      Overlay.of(overlayContext).context.findRenderObject()
                          as RenderBox?;
                  if (currentOverlayBox == null) {
                    _closeTaskPopover(currentId, reason: 'outside-tap');
                    return;
                  }
                  final TaskPopoverLayout popoverLayout = _taskPopoverController
                      .layoutFor(currentId);
                  final Rect popoverRect = Rect.fromLTWH(
                    popoverLayout.topLeft.dx,
                    popoverLayout.topLeft.dy,
                    calendarTaskPopoverWidth,
                    popoverLayout.maxHeight,
                  );
                  final Offset localPosition = currentOverlayBox.globalToLocal(
                    event.position,
                  );
                  if (!popoverRect.contains(localPosition)) {
                    _closeTaskPopover(currentId, reason: 'outside-tap');
                  }
                },
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy,
              width: calendarTaskPopoverWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: layout.maxHeight),
                child: Material(
                  color: Colors.transparent,
                  child: BlocProvider<T>.value(
                    value: context.read<T>(),
                    child: BlocBuilder<T, CalendarState>(
                      builder: (context, state) {
                        final String baseId = baseTaskIdFrom(taskId);
                        final CalendarTask? latestTask =
                            state.model.tasks[baseId];
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
                            parentScrollController: _verticalController,
                            inlineActions: inlineActions,
                            collectionMethod: state.model.collection?.method,
                            onClose: () => _closeTaskPopover(
                              taskId,
                              reason: 'dropdown-close',
                            ),
                            scaffoldMessenger: scaffoldMessenger,
                            locationHelper:
                                LocationAutocompleteHelper.fromState(state),
                            onTaskUpdated: (updatedTask) {
                              context.read<T>().add(
                                CalendarEvent.taskUpdated(task: updatedTask),
                              );
                            },
                            onOccurrenceUpdated: shouldUpdateOccurrence
                                ? (
                                    updatedTask,
                                    scope, {
                                    required bool scheduleTouched,
                                    required bool checklistTouched,
                                  }) {
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
        final Duration? originalDuration =
            original.duration ??
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

  CalendarInteractionVerticalIntent _verticalIntentForPosition({
    required double y,
    required double height,
    required double fastBandHeight,
    required double slowBandHeight,
  }) {
    if (y < 0 || y <= fastBandHeight) {
      return CalendarInteractionVerticalIntent.up;
    }
    if (y > height || y >= height - fastBandHeight) {
      return CalendarInteractionVerticalIntent.down;
    }
    if (y <= fastBandHeight + slowBandHeight) {
      return CalendarInteractionVerticalIntent.up;
    }
    if (y >= height - (fastBandHeight + slowBandHeight)) {
      return CalendarInteractionVerticalIntent.down;
    }
    return CalendarInteractionVerticalIntent.neutral;
  }

  CalendarInteractionHorizontalIntent _horizontalIntentForPosition({
    required double x,
    required double width,
    required double bandWidth,
  }) {
    if (x < 0 || x > width) {
      return CalendarInteractionHorizontalIntent.neutral;
    }
    if (x <= bandWidth) {
      return CalendarInteractionHorizontalIntent.backward;
    }
    if (x >= width - bandWidth) {
      return CalendarInteractionHorizontalIntent.forward;
    }
    return CalendarInteractionHorizontalIntent.neutral;
  }

  double _offsetPerFrameForVerticalIntent({
    required CalendarInteractionVerticalIntent intent,
    required double y,
    required double height,
    required double fastBandHeight,
    required double slowBandHeight,
    required double fastOffsetPerFrame,
    required double slowOffsetPerFrame,
  }) {
    if (intent == CalendarInteractionVerticalIntent.neutral) {
      return 0;
    }
    final bool isUp = intent == CalendarInteractionVerticalIntent.up;
    if (y < 0 || y > height) {
      return isUp ? -fastOffsetPerFrame : fastOffsetPerFrame;
    }
    if (y <= fastBandHeight || y >= height - fastBandHeight) {
      return isUp ? -fastOffsetPerFrame : fastOffsetPerFrame;
    }
    return isUp ? -slowOffsetPerFrame : slowOffsetPerFrame;
  }

  void _handleAutoScrollForGlobal(Offset globalPosition) {
    final CalendarInteractionSession? session =
        _taskInteractionController.activeInteractionSession;
    if (session == null) {
      _cancelEdgeAutoPageTimer();
      _stopEdgeAutoScroll();
      return;
    }
    if (_isAnyNonGridDragRegionHovering) {
      _clearActiveInteractionEdgeIntent(clearPreview: true);
      return;
    }
    if (!_verticalController.hasClients) {
      _cancelEdgeAutoPageTimer();
      return;
    }
    final BuildContext? scrollContext = _scrollableKey.currentContext;
    if (scrollContext == null) {
      _cancelEdgeAutoPageTimer();
      return;
    }

    final RenderObject? renderObject = scrollContext.findRenderObject();
    if (renderObject is! RenderBox) {
      _cancelEdgeAutoPageTimer();
      return;
    }

    final Size viewportSize = renderObject.size;
    final double height = viewportSize.height;
    if (!height.isFinite || height <= 0) {
      _cancelEdgeAutoPageTimer();
      return;
    }

    final double width = viewportSize.width;
    if (!width.isFinite || width <= 0) {
      _cancelEdgeAutoPageTimer();
      _stopEdgeAutoScroll();
      return;
    }

    final CalendarLayoutTheme layoutTheme = CalendarLayoutTheme.fromContext(
      context,
    );
    final Offset localPosition = renderObject.globalToLocal(globalPosition);
    final double pointerX = localPosition.dx;
    final double y = localPosition.dy;
    final bool isResizing = session.isResize;
    const double resizeBandFactor = 0.55;
    const double resizeFastSpeedFactor = 0.4;
    const double resizeSlowSpeedFactor = 0.55;
    final double fastBandHeight = isResizing
        ? (layoutTheme.edgeScrollFastBandHeight * resizeBandFactor)
        : layoutTheme.edgeScrollFastBandHeight;
    final double slowBandHeight = isResizing
        ? (layoutTheme.edgeScrollSlowBandHeight * resizeBandFactor)
        : layoutTheme.edgeScrollSlowBandHeight;
    final double fastOffsetPerFrame = isResizing
        ? (layoutTheme.edgeScrollFastOffsetPerFrame * resizeFastSpeedFactor)
        : layoutTheme.edgeScrollFastOffsetPerFrame;
    final double slowOffsetPerFrame = isResizing
        ? (layoutTheme.edgeScrollSlowOffsetPerFrame * resizeSlowSpeedFactor)
        : layoutTheme.edgeScrollSlowOffsetPerFrame;
    final double horizontalBandWidth = fastBandHeight + slowBandHeight;

    final CalendarInteractionVerticalIntent verticalIntent =
        _verticalIntentForPosition(
          y: y,
          height: height,
          fastBandHeight: fastBandHeight,
          slowBandHeight: slowBandHeight,
        );
    final CalendarInteractionHorizontalIntent horizontalIntent =
        _horizontalIntentForPosition(
          x: pointerX,
          width: width,
          bandWidth: horizontalBandWidth,
        );
    final CalendarInteractionHorizontalIntent effectiveHorizontalIntent =
        _isSyntheticDragRefresh ? session.horizontalIntent : horizontalIntent;
    _taskInteractionController.updateInteractionEdgeIntent(
      verticalIntent: verticalIntent,
      horizontalIntent: effectiveHorizontalIntent,
    );
    if (!_isSyntheticDragRefresh) {
      _updateEdgeAutoPageTimer(horizontalIntent, startRepeat: false);
    }

    final double offsetPerFrame = _offsetPerFrameForVerticalIntent(
      intent: verticalIntent,
      y: y,
      height: height,
      fastBandHeight: fastBandHeight,
      slowBandHeight: slowBandHeight,
      fastOffsetPerFrame: fastOffsetPerFrame,
      slowOffsetPerFrame: slowOffsetPerFrame,
    );

    if (offsetPerFrame == 0) {
      _stopEdgeAutoScroll();
      return;
    }
    _handleEdgeAutoScrollMove(offsetPerFrame);
  }

  void _scrollToSlot(DateTime slotTime, {bool allowDeferral = true}) {
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
    final target = (offset - viewport / 2)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();

    _verticalController.animateTo(
      target,
      duration: CalendarLayoutTheme.fromContext(
        context,
      ).scrollAnimationDuration,
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
        CalendarEvent.taskDropped(taskId: taskId, time: targetStart),
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
        CalendarEvent.taskDropped(taskId: baseId, time: targetStart),
      );
      return;
    }

    widget.onTaskDragEnd?.call(taskInstance, targetStart);
  }

  bool _applySelectionDrag(CalendarTask anchorTask, DateTime dropTime) {
    if (!_isSelectionMode || _selectedTaskIds.isEmpty) {
      return false;
    }

    final bool anchorSelected =
        _selectedTaskIds.contains(anchorTask.id) ||
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
      FeedbackSystem.showError(context, context.l10n.calendarTaskNotFound);
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

    final now = demoNow();
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
    final TaskPriority next = _priorityFromFlags(
      important: important,
      urgent: urgent,
    );
    context.read<T>().add(
      CalendarEvent.taskPriorityChanged(taskId: task.baseId, priority: next),
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
      CalendarEvent.taskCompleted(taskId: task.baseId, completed: completed),
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
    final l10n = context.l10n;
    final List<TaskContextAction> actions = <TaskContextAction>[
      TaskContextAction(
        icon: Icons.copy_outlined,
        label: l10n.calendarCopyTask,
        onSelected: () => _copyTaskInstance(task),
      ),
      TaskContextAction(
        icon: Icons.send,
        label: l10n.calendarShareAsIcsAction,
        onSelected: () => _shareTaskIcs(task),
      ),
      TaskContextAction(
        icon: Icons.file_download_outlined,
        label: context.l10n.calendarExportFormatIcsTitle,
        onSelected: () => _exportTaskIcs(task),
      ),
      TaskContextAction(
        icon: Icons.share_outlined,
        label: l10n.calendarCopyToClipboardAction,
        onSelected: () => _copyTaskToClipboard(task),
      ),
      TaskContextAction(
        icon: Icons.route,
        label: l10n.calendarAddToCriticalPath,
        onSelected: () => _showAddToCriticalPathPicker(task),
      ),
    ];

    if (includeCompletionAction) {
      actions.add(
        TaskContextAction(
          icon: task.isCompleted ? Icons.undo : Icons.check_circle_outline,
          label: task.isCompleted
              ? l10n.calendarTaskMarkIncomplete
              : l10n.calendarTaskMarkComplete,
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
          label: importantFlag
              ? l10n.calendarTaskRemoveImportant
              : l10n.calendarTaskMarkImportant,
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
          label: urgentFlag
              ? l10n.calendarTaskRemoveUrgent
              : l10n.calendarTaskMarkUrgent,
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
          ? (isOccurrenceSelected
                ? l10n.calendarDeselectTask
                : l10n.calendarAddTaskToSelection)
          : l10n.calendarSelectTask;
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
          ? (isSeriesSelected
                ? l10n.calendarDeselectAllRepeats
                : l10n.calendarAddAllRepeats)
          : l10n.calendarSelectAllRepeats;
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
          ? (isSelected
                ? l10n.calendarDeselectTask
                : l10n.calendarAddToSelection)
          : l10n.calendarSelectTask;
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
          label: l10n.calendarSelectAllTasks,
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
          label: l10n.calendarExitSelectionMode,
          onSelected: _clearSelectionMode,
        ),
      );
    }

    if (includeSplitAction) {
      actions.add(
        TaskContextAction(
          icon: Icons.call_split,
          label: l10n.calendarSplitTask,
          onSelected: () => _promptSplitTask(task),
        ),
      );
    }

    if (!task.isOccurrence) {
      actions.add(
        TaskContextAction(
          icon: Icons.copy_outlined,
          label: l10n.calendarCopyTemplate,
          onSelected: () => _copyTaskTemplate(task),
        ),
      );
    }

    if (includeDeleteAction) {
      actions.add(
        TaskContextAction(
          icon: Icons.delete_outline,
          label: l10n.calendarDeleteTask,
          destructive: true,
          onSelected: () {
            context.read<T>().add(CalendarEvent.taskDeleted(taskId: task.id));
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
    final String stripped = label
        .replaceAll(keyword, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return stripped.isEmpty ? label : stripped;
  }

  TaskContextMenuBuilder _taskContextMenuBuilder({
    required CalendarTask task,
    required ShadPopoverController menuController,
  }) {
    return (context, request) {
      final List<TaskContextAction> actions = _taskContextActions(
        task: task,
        state: widget.state,
      );
      final List<Widget> menuItems = actions
          .map(
            (action) => ShadContextMenuItem(
              leading: Icon(
                action.icon,
                color: action.destructive
                    ? context.colorScheme.destructive
                    : null,
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
              context.l10n.calendarSplitTaskAtTime(
                TimeFormatter.formatTime(splitTime),
              ),
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
    final bool treatAsSeries =
        (baseTask?.isSeries ?? false) ||
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

  DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

  Map<DateTime, List<CalendarTask>> _buildWeekTaskMap(
    List<DateTime> weekDates,
  ) {
    if (weekDates.isEmpty) {
      return const <DateTime, List<CalendarTask>>{};
    }
    final DateTime weekStart = _dayKey(weekDates.first);
    final DateTime weekEnd = _dayKey(weekDates.last).add(
      const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999),
    );
    final Map<DateTime, List<CalendarTask>> bucketed = {
      for (final date in weekDates) _dayKey(date): <CalendarTask>[],
    };
    final List<CalendarTask> tasks = widget.state.tasksInRange(
      weekStart,
      weekEnd,
    );
    for (final CalendarTask task in tasks) {
      if (!_isTaskVisible(task) || task.scheduledTime == null) {
        continue;
      }
      final CalendarTask preview =
          _taskInteractionController.resizePreviews[task.id] ?? task;
      final DateTime? scheduled = preview.scheduledTime;
      if (scheduled == null) {
        continue;
      }
      final DateTime key = _dayKey(scheduled);
      final List<CalendarTask>? bucket = bucketed[key];
      if (bucket != null) {
        bucket.add(preview);
      }
    }
    return bucketed;
  }

  List<CalendarTask> _getTasksForDay(DateTime date) {
    final tasks = widget.state.tasksForDate(date);
    return tasks
        .where(_isTaskVisible)
        .where((task) => task.scheduledTime != null)
        .map((task) {
          final preview = _taskInteractionController.resizePreviews[task.id];
          return preview ?? task;
        })
        .toList();
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
    final now = demoNow();
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
    context.read<T>().add(CalendarEvent.dayEventUpdated(event: updated));
  }

  String _getDayOfWeekShort(BuildContext context, DateTime date) {
    return DateFormat('EEE', context.l10n.localeName).format(date);
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
    final CalendarLayoutTheme layoutTheme = CalendarLayoutTheme.fromContext(
      context,
    );
    final double timeColumnWidth = layoutTheme.timeColumnWidth;
    return AnimatedBuilder(
      animation: gridState._taskPopoverController,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: gridState._taskInteractionController,
          builder: (context, _) {
            final weekDates = gridState._getWeekDates(
              gridState.widget.state.selectedDate,
            );
            final bool isWeekView =
                gridState.widget.state.viewMode == CalendarView.week &&
                (!compact || allowWeekViewInCompact);
            final responsive = ResponsiveHelper.spec(context);
            final bool showHeaderNavigation =
                responsive.sizeClass != CalendarSizeClass.expanded;
            final headerDates = isWeekView
                ? weekDates
                : [gridState.widget.state.selectedDate];
            final List<DayEvent> selectedDayEvents = isWeekView
                ? const <DayEvent>[]
                : gridState.widget.state.dayEventsForDate(
                    gridState.widget.state.selectedDate,
                  );
            final double horizontalPadding = compact
                ? 0
                : responsive.gridHorizontalPadding;

            final gridBody = LayoutBuilder(
              builder: (context, outerConstraints) {
                final double viewportWidth = outerConstraints.maxWidth;
                final double navControlsWidth = showHeaderNavigation
                    ? _headerNavButtonExtent * 2
                    : 0;
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
                        timeColumnWidth -
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

                final Border border =
                    gridState._isChatCalendar(context) &&
                        responsive.sizeClass != CalendarSizeClass.expanded
                    ? const Border()
                    : Border(
                        left: BorderSide(
                          color: calendarBorderColor,
                          width: calendarBorderStroke,
                        ),
                      );
                final Widget content = Container(
                  decoration: BoxDecoration(
                    color: calendarBackgroundColor,
                    borderRadius: BorderRadius.zero,
                    border: border,
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
                          timeColumnWidth: timeColumnWidth,
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
                                  context.spacing.s,
                                  horizontalPadding,
                                  0,
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.spacing.m,
                                    vertical: context.spacing.s,
                                  ),
                                  decoration: BoxDecoration(
                                    color: calendarDangerColor.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      context.radii.container,
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
                                        size: context.sizing.menuItemIconSize,
                                        color: calendarDangerColor,
                                      ),
                                      SizedBox(width: context.spacing.s),
                                      Expanded(
                                        child: Text(
                                          gridState._inlineErrorMessage!,
                                          style: context.textTheme.small.strong
                                              .copyWith(
                                                color: calendarDangerColor,
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
                            final bool isDayView =
                                compact ||
                                gridState.widget.state.viewMode ==
                                    CalendarView.day;
                            gridState._resolvedHourHeight = gridState
                                ._resolveHourHeight(
                                  availableHeight,
                                  isDayView: isDayView,
                                  layoutTheme: layoutTheme,
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
                                  layoutTheme: layoutTheme,
                                  timeColumnWidth: timeColumnWidth,
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
                      bottom: 0,
                      right: 0,
                      child: SafeArea(
                        top: false,
                        left: false,
                        minimum: EdgeInsets.only(
                          right: compact
                              ? context.spacing.s
                              : context.spacing.m,
                          bottom: compact
                              ? context.spacing.m
                              : context.spacing.l,
                        ),
                        child: _CalendarZoomControls(gridState: gridState),
                      ),
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
    final double iconSize = context.sizing.inputSuffixIconSize;
    final double iconButtonSize = context.sizing.inputSuffixButtonSize;
    final double iconTapTarget = context.sizing.menuItemHeight;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.spacing.m,
        context.spacing.xxs,
        context.spacing.m,
        context.spacing.s,
      ),
      color: colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.calendarDayEventsLabel,
                style: textTheme.label.strong.copyWith(
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              AxiIconButton(
                iconData: Icons.add,
                iconSize: iconSize,
                buttonSize: iconButtonSize,
                tapTargetSize: iconTapTarget,
                borderColor: Colors.transparent,
                borderWidth: context.borderSide.width * 0,
                backgroundColor: colors.primary.withValues(alpha: 0.08),
                color: colors.primary,
                tooltip: context.l10n.calendarAddDayEvent,
                onPressed: onAdd,
              ).withTapBounce(),
            ],
          ),
          SizedBox(height: context.spacing.xxs),
          if (!hasEvents)
            Text(
              context.l10n.calendarDayEventsEmpty,
              style: textTheme.label.copyWith(color: colors.mutedForeground),
            )
          else ...[
            ...events.map(
              (DayEvent event) =>
                  _DayEventBulletRow(event: event, onTap: () => onEdit(event)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayEventBulletRow extends StatelessWidget {
  const _DayEventBulletRow({required this.event, required this.onTap});

  final DayEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final ShadTextTheme textTheme = context.textTheme;
    final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xxs),
      child: AxiTapBounce(
        child: ShadFocusable(
          canRequestFocus: true,
          builder: (context, _, _) {
            return Material(
              type: MaterialType.transparency,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: ShadGestureDetector(
                cursor: SystemMouseCursors.click,
                onTap: onTap,
                child: Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          width: context.spacing.s,
                          height: context.spacing.s,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      WidgetSpan(child: SizedBox(width: context.spacing.s)),
                      TextSpan(text: event.title),
                    ],
                  ),
                  style: textTheme.labelSm.strong.copyWith(
                    color: colors.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
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
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: offsetAnimation, child: child),
    );
  }
}

class _CalendarGridContent extends StatelessWidget {
  const _CalendarGridContent({
    required this.gridState,
    required this.isWeekView,
    required this.weekDates,
    required this.compact,
    required this.layoutTheme,
    required this.timeColumnWidth,
    this.compactWeekDayWidth,
    this.horizontalScrollController,
    this.enableHorizontalScroll = false,
    this.hoveredSlot,
  });

  final _CalendarGridState gridState;
  final bool isWeekView;
  final List<DateTime> weekDates;
  final bool compact;
  final CalendarLayoutTheme layoutTheme;
  final double timeColumnWidth;
  final double? compactWeekDayWidth;
  final ScrollController? horizontalScrollController;
  final bool enableHorizontalScroll;
  final DateTime? hoveredSlot;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable:
          gridState._taskInteractionController.resizePreviewRevision,
      builder: (context, _, _) {
        final bool allowHorizontalScroll =
            enableHorizontalScroll && compactWeekDayWidth != null;
        final responsive = ResponsiveHelper.spec(context);
        final List<DateTime> columns = isWeekView
            ? weekDates
            : <DateTime>[gridState.widget.state.selectedDate];
        final bool isDayView = !isWeekView;
        final Map<DateTime, List<CalendarTask>>? weekTasks = isWeekView
            ? gridState._buildWeekTaskMap(weekDates)
            : null;
        final Set<String> visibleTaskIds = <String>{};
        gridState._visibleTasks.clear();
        final CalendarLayoutMetrics? resolvedMetrics =
            gridState._surfaceController.resolvedMetrics;
        final double resolvedHourHeight = gridState._effectiveHourHeight(
          resolvedMetrics,
        );
        final double stepHeight = gridState._effectiveStepHeight(
          resolvedMetrics,
        );
        final List<Widget> taskEntries = <Widget>[];
        for (final DateTime date in columns) {
          final List<CalendarTask> tasks = weekTasks == null
              ? gridState._getTasksForDay(date)
              : (weekTasks[gridState._dayKey(date)] ?? const <CalendarTask>[]);
          for (final CalendarTask task in tasks) {
            gridState._visibleTasks[task.id] = task;
            visibleTaskIds.add(task.id);

            final CalendarTaskEntryBindings bindings = gridState
                ._createTaskBindings(
                  task: task,
                  stepHeight: stepHeight,
                  hourHeight: resolvedHourHeight,
                );

            final DateTime columnDate = DateTime(
              date.year,
              date.month,
              date.day,
            );
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

        final List<CalendarDayColumn> columnSpecs = columns
            .map((date) => CalendarDayColumn(date: date))
            .toList();

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

        final List<CalendarAvailabilityWindow> availabilityWindows = gridState
            ._resolveAvailabilityWindows();
        final List<CalendarAvailabilityOverlay> availabilityOverlays = gridState
            ._resolveAvailabilityOverlays();

        final Widget renderSurface = CalendarRenderSurface(
          key: gridState._surfaceKey,
          columns: columnSpecs,
          startHour: _CalendarGridState.startHour,
          endHour: _CalendarGridState.endHour,
          zoomIndex: gridState._zoomIndex,
          allowDayViewZoom: gridState._shouldUseCompactZoom,
          weekStartDate: weekStartDate,
          weekEndDate: weekEndDate,
          layoutTheme: layoutTheme,
          controller: gridState._surfaceController,
          verticalScrollController: gridState._verticalController,
          minutesPerStep: gridState._minutesPerStep,
          timeLabelInset: context.spacing.xs,
          timeTickInset: context.spacing.xxs,
          interactionController: gridState._taskInteractionController,
          availabilityWindows: availabilityWindows,
          availabilityOverlays: availabilityOverlays,
          hoveredSlot: hoveredSlot,
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
          interactionController: gridState._taskInteractionController,
          child: interactiveSurface,
        );

        Widget surface = dragAwareSurface;
        if (allowHorizontalScroll) {
          final double dayWidth = compactWeekDayWidth!;
          final double totalWidth =
              timeColumnWidth + (dayWidth * columnSpecs.length);
          surface = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller:
                horizontalScrollController ??
                gridState._horizontalGridController,
            child: SizedBox(width: totalWidth, child: dragAwareSurface),
          );
        }

        final Widget menuSurface = _CalendarGridContextMenu(
          controller: gridState._gridContextMenuController,
          groupId: _CalendarGridState._contextMenuGroupId,
          anchor: gridState._contextMenuAnchor,
          slot: gridState._contextMenuSlot,
          clipboardTemplate:
              gridState._taskInteractionController.clipboardTemplate,
          onPointerDown: gridState._handleGridPointerDown,
          onHide: gridState._hideGridContextMenu,
          onPasteTask: gridState._pasteTask,
          onQuickAddTask: gridState.widget.onEmptySlotTapped == null
              ? null
              : (slot) =>
                    gridState.widget.onEmptySlotTapped!(slot, Offset.zero),
          child: surface,
        );

        final Widget highlightSurface = Listener(
          onPointerDown: gridState._handleSurfacePointerDown,
          onPointerMove: gridState._handleSurfacePointerMove,
          onPointerUp: gridState._handleSurfacePointerUp,
          onPointerCancel: gridState._handleSurfacePointerCancel,
          child: menuSurface,
        );

        final Widget touchAwareSurface = _CalendarEmptySurfaceGestureLayer(
          hitTestEmptySurface: gridState._slotForGlobalPosition,
          onEmptySurfaceTapUp: gridState.widget.onEmptySlotTapped == null
              ? null
              : gridState._handleEmptySurfaceTapUp,
          onEmptySurfaceLongPressStart: gridState._shouldEnableTouchGridMenu
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
      },
    );
  }
}

class _CalendarEmptySurfaceGestureLayer extends StatefulWidget {
  const _CalendarEmptySurfaceGestureLayer({
    required this.hitTestEmptySurface,
    this.onEmptySurfaceTapUp,
    this.onEmptySurfaceLongPressStart,
    required this.child,
  });

  final DateTime? Function(Offset globalPosition) hitTestEmptySurface;
  final GestureTapUpCallback? onEmptySurfaceTapUp;
  final GestureLongPressStartCallback? onEmptySurfaceLongPressStart;
  final Widget child;

  @override
  State<_CalendarEmptySurfaceGestureLayer> createState() =>
      _CalendarEmptySurfaceGestureLayerState();
}

class _CalendarEmptySurfaceGestureLayerState
    extends State<_CalendarEmptySurfaceGestureLayer> {
  late final TapGestureRecognizer _tapRecognizer;
  late final LongPressGestureRecognizer _longPressRecognizer;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer(debugOwner: this)
      ..onTapUp = widget.onEmptySurfaceTapUp;
    _longPressRecognizer = LongPressGestureRecognizer(debugOwner: this)
      ..onLongPressStart = widget.onEmptySurfaceLongPressStart;
  }

  @override
  void didUpdateWidget(covariant _CalendarEmptySurfaceGestureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tapRecognizer.onTapUp = widget.onEmptySurfaceTapUp;
    _longPressRecognizer.onLongPressStart = widget.onEmptySurfaceLongPressStart;
  }

  @override
  void dispose() {
    _tapRecognizer.dispose();
    _longPressRecognizer.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isPrimaryPointer(event)) {
      return;
    }
    if (widget.hitTestEmptySurface(event.position) == null) {
      return;
    }
    if (widget.onEmptySurfaceTapUp != null) {
      _tapRecognizer.addPointer(event);
    }
    if (widget.onEmptySurfaceLongPressStart != null) {
      _longPressRecognizer.addPointer(event);
    }
  }

  bool _isPrimaryPointer(PointerDownEvent event) {
    if ((event.buttons & kPrimaryButton) != 0) {
      return true;
    }
    if (event.buttons != 0) {
      return false;
    }
    final PointerDeviceKind kind = event.kind;
    return kind != PointerDeviceKind.mouse &&
        kind != PointerDeviceKind.trackpad;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: widget.child,
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
    required this.timeColumnWidth,
    this.compactWeekDayWidth,
    this.horizontalScrollController,
    this.enableHorizontalScroll = false,
  });

  final _CalendarGridState gridState;
  final List<DateTime> weekDates;
  final bool compact;
  final bool isWeekView;
  final bool showNavigationControls;
  final double timeColumnWidth;
  final double? compactWeekDayWidth;
  final ScrollController? horizontalScrollController;
  final bool enableHorizontalScroll;

  @override
  Widget build(BuildContext context) {
    final bool useScrollableWeekHeader =
        enableHorizontalScroll && compactWeekDayWidth != null;
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final l10n = context.l10n;
    final String unitLabel = calendarUnitLabel(
      gridState.widget.state.viewMode,
      l10n,
    );
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

    final Widget headerRow = Row(
      children: [
        Container(
          width: timeColumnWidth,
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
        if (trailingNav != null)
          Container(
            width: _headerNavButtonExtent,
            height: double.infinity,
            decoration: BoxDecoration(
              color: calendarBackgroundColor,
              border: Border(
                left: BorderSide(
                  color: calendarBorderDarkColor,
                  width: calendarBorderStroke,
                ),
              ),
            ),
            child: trailingNav,
          ),
      ],
    );
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
      child: headerRow,
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
      child: Icon(icon, size: context.sizing.menuItemIconSize),
    );

    return SizedBox(
      width: _headerNavButtonExtent,
      height: calendarWeekHeaderHeight,
      child: Center(
        child: AxiTooltip(builder: (_) => Text(tooltip), child: button),
      ),
    );
  }
}

class _CalendarDayHeader extends StatefulWidget {
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
  State<_CalendarDayHeader> createState() => _CalendarDayHeaderState();
}

class _CalendarDayHeaderState extends State<_CalendarDayHeader> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isToday = widget.gridState._isToday(widget.date);
    final int dayEventCount = widget.gridState.widget.state
        .dayEventCountForDate(widget.date);
    final bool enabled =
        widget.gridState.widget.state.viewMode == CalendarView.week;
    final Color baseBackground = isToday
        ? calendarPrimaryColor.withValues(
            alpha: calendarDayHeaderHighlightOpacity,
          )
        : calendarBackgroundColor;
    final Color background = _hovered && enabled
        ? calendarSidebarBackgroundColor
        : baseBackground;

    return AxiPlainHeaderButton(
      onPressed: enabled
          ? () => widget.gridState._selectDateAndSwitchToDay(widget.date)
          : null,
      onHoverChange: enabled ? _setHovered : null,
      backgroundColor: Colors.transparent,
      hoverBackgroundColor: Colors.transparent,
      pressedBackgroundColor: Colors.transparent,
      child: CustomPaint(
        painter: _DayHeaderDividerPainter(
          devicePixelRatio: widget.devicePixelRatio,
          strokeWidth: calendarBorderStroke,
          color: calendarBorderDarkColor,
          drawRightBorder: widget.showRightDivider,
        ),
        child: Stack(
          children: [
            Container(
              color: background,
              child: Center(
                child: Text(
                  context.l10n.commonWeekdayDayLabel(
                    widget.gridState._getDayOfWeekShort(context, widget.date),
                    widget.date.day,
                  ),
                  style: context.textTheme.label.strong.copyWith(
                    color: isToday ? calendarPrimaryColor : calendarTitleColor,
                    letterSpacing: calendarDayHeaderLetterSpacing,
                  ),
                ),
              ),
            ),
            if (dayEventCount > 0)
              Positioned(
                top: context.spacing.s,
                right: context.spacing.s,
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
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xs,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: calendarPrimaryColor,
        borderRadius: context.radius,
      ),
      child: Text(
        count.toString(),
        style: context.textTheme.labelSm.strong.copyWith(
          color: colors.primaryForeground,
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
    return AxiButton.outline(
      onPressed: gridState._isZoomEnabled ? gridState.cycleZoom : null,
      child: Text(
        gridState.zoomLabel(context.l10n),
        style: context.textTheme.label.strong,
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
    final EdgeInsets sheetPadding = EdgeInsets.fromLTRB(
      context.spacing.m,
      0,
      context.spacing.m,
      context.spacing.m,
    );
    return AxiSheetScaffold.scroll(
      header: AxiSheetHeader(
        title: Text(context.l10n.calendarSplitTaskAt),
        onClose: () => Navigator.of(context).maybePop(),
        padding: EdgeInsets.fromLTRB(
          context.spacing.m,
          context.spacing.m,
          context.spacing.m,
          context.spacing.xs,
        ),
      ),
      bodyPadding: sheetPadding,
      children: [
        CalendarDateTimeField(
          value: _selected,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _selected = _clamp(value);
            });
          },
          placeholder: context.l10n.calendarSplitSelectTime,
          showStatusColors: false,
          minDate: widget.minTime,
          maxDate: widget.maxTime,
        ),
        SizedBox(height: context.spacing.m),
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
                label: context.l10n.calendarSplitTask,
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
    final Rect rect = Rect.fromLTWH(snappedRight, 0, strokeWidth, size.height);
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
