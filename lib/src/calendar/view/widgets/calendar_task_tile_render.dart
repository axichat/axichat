// ignore_for_file: unnecessary_getters_setters

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../models/calendar_task.dart';
import '../controllers/task_interaction_controller.dart';

typedef TaskTileContextMenuCallback = void Function(
  Offset localPosition,
  Offset normalizedPosition,
);

class CalendarTaskTileRenderRegion extends SingleChildRenderObjectWidget {
  const CalendarTaskTileRenderRegion({
    super.key,
    required this.task,
    required this.interactionController,
    required this.minutesPerStep,
    required this.stepHeight,
    required this.enableInteractions,
    required this.isSelectionMode,
    required this.isSelected,
    required this.isPopoverOpen,
    required this.onResizePreview,
    required this.onResizeEnd,
    required this.onResizePointerMove,
    required this.onDragPointerDown,
    required this.onTap,
    required this.onToggleSelection,
    required this.onContextMenuPosition,
    this.handleExtent = 8.0,
    required super.child,
  });

  final CalendarTask task;
  final TaskInteractionController interactionController;
  final int minutesPerStep;
  final double stepHeight;
  final bool enableInteractions;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isPopoverOpen;
  final ValueChanged<CalendarTask>? onResizePreview;
  final ValueChanged<CalendarTask>? onResizeEnd;
  final ValueChanged<Offset>? onResizePointerMove;
  final ValueChanged<Offset>? onDragPointerDown;
  final void Function(CalendarTask task, Rect globalBounds)? onTap;
  final VoidCallback? onToggleSelection;
  final TaskTileContextMenuCallback? onContextMenuPosition;
  final double handleExtent;

  @override
  RenderCalendarTaskTile createRenderObject(BuildContext context) {
    return RenderCalendarTaskTile(
      task: task,
      interactionController: interactionController,
      minutesPerStep: minutesPerStep,
      stepHeight: stepHeight,
      enableInteractions: enableInteractions,
      isSelectionMode: isSelectionMode,
      isSelected: isSelected,
      isPopoverOpen: isPopoverOpen,
      onResizePreview: onResizePreview,
      onResizeEnd: onResizeEnd,
      onResizePointerMove: onResizePointerMove,
      onDragPointerDown: onDragPointerDown,
      onTap: onTap,
      onToggleSelection: onToggleSelection,
      onContextMenuPosition: onContextMenuPosition,
      handleExtent: handleExtent,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCalendarTaskTile renderObject,
  ) {
    renderObject
      ..task = task
      ..interactionController = interactionController
      ..minutesPerStep = minutesPerStep
      ..stepHeight = stepHeight
      ..enableInteractions = enableInteractions
      ..isSelectionMode = isSelectionMode
      ..isSelected = isSelected
      ..isPopoverOpen = isPopoverOpen
      ..onResizePreview = onResizePreview
      ..onResizeEnd = onResizeEnd
      ..onResizePointerMove = onResizePointerMove
      ..onDragPointerDown = onDragPointerDown
      ..onTap = onTap
      ..onToggleSelection = onToggleSelection
      ..onContextMenuPosition = onContextMenuPosition
      ..handleExtent = handleExtent;
  }
}

class RenderCalendarTaskTile extends RenderMouseRegion {
  RenderCalendarTaskTile({
    required CalendarTask task,
    required TaskInteractionController interactionController,
    required int minutesPerStep,
    required double stepHeight,
    required bool enableInteractions,
    required bool isSelectionMode,
    required bool isSelected,
    required bool isPopoverOpen,
    ValueChanged<CalendarTask>? onResizePreview,
    ValueChanged<CalendarTask>? onResizeEnd,
    ValueChanged<Offset>? onResizePointerMove,
    ValueChanged<Offset>? onDragPointerDown,
    void Function(CalendarTask task, Rect globalBounds)? onTap,
    VoidCallback? onToggleSelection,
    TaskTileContextMenuCallback? onContextMenuPosition,
    double handleExtent = 8.0,
    super.child,
  })  : _task = task,
        _interactionController = interactionController,
        _minutesPerStep = minutesPerStep,
        _stepHeight = stepHeight,
        _enableInteractions = enableInteractions,
        _isSelectionMode = isSelectionMode,
        _isSelected = isSelected,
        _isPopoverOpen = isPopoverOpen,
        _onResizePreview = onResizePreview,
        _onResizeEnd = onResizeEnd,
        _onResizePointerMove = onResizePointerMove,
        _onDragPointerDown = onDragPointerDown,
        _onTap = onTap,
        _onToggleSelection = onToggleSelection,
        _onContextMenuPosition = onContextMenuPosition,
        _handleExtent = handleExtent {
    onEnter = _handlePointerEnter;
    onExit = _handlePointerExit;
    cursor = SystemMouseCursors.click;
  }

  double _handleExtent;
  static const double _tapSlop = 3.0;
  static const Duration _touchResizeLongPressDelay =
      Duration(milliseconds: 260);
  static const double _touchHandleHorizontalFraction = 0.45;
  static const double _touchHandleHorizontalMax = 56.0;
  static const double _touchHandleHorizontalMin = 28.0;

  CalendarTask _task;
  TaskInteractionController _interactionController;
  int _minutesPerStep;
  double _stepHeight;
  bool _enableInteractions;
  bool _isSelectionMode;
  bool _isSelected;
  bool _isPopoverOpen;
  ValueChanged<CalendarTask>? _onResizePreview;
  ValueChanged<CalendarTask>? _onResizeEnd;
  ValueChanged<Offset>? _onResizePointerMove;
  ValueChanged<Offset>? _onDragPointerDown;
  void Function(CalendarTask task, Rect globalBounds)? _onTap;
  VoidCallback? _onToggleSelection;
  TaskTileContextMenuCallback? _onContextMenuPosition;
  double get handleExtent => _handleExtent;
  set handleExtent(double value) {
    if (_handleExtent == value) {
      return;
    }
    _handleExtent = value.clamp(4.0, double.infinity);
  }

  int? _activePointer;
  Offset? _downLocalPosition;
  bool _resizeActive = false;
  bool _pendingTap = false;
  bool _lastPointerSecondary = false;
  String? _activeHandle;
  LongPressGestureRecognizer? _resizeLongPressRecognizer;
  String? _pendingResizeHandle;

  double _totalResizeDelta = 0;
  int _lastAppliedStep = 0;
  double _currentStartHour = 0;
  double _currentDurationHours = 1;
  DateTime? _tempScheduled;
  Duration? _tempDuration;

  CalendarTask get task => _task;
  set task(CalendarTask value) {
    if (_task == value) {
      return;
    }
    _task = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  TaskInteractionController get interactionController => _interactionController;
  set interactionController(TaskInteractionController value) {
    if (_interactionController == value) {
      return;
    }
    _interactionController = value;
  }

  int get minutesPerStep => _minutesPerStep;
  set minutesPerStep(int value) {
    if (_minutesPerStep == value) return;
    _minutesPerStep = value;
  }

  double get stepHeight => _stepHeight;
  set stepHeight(double value) {
    if (_stepHeight == value) return;
    _stepHeight = value;
  }

  bool get enableInteractions => _enableInteractions;
  set enableInteractions(bool value) {
    if (_enableInteractions == value) return;
    _enableInteractions = value;
    markNeedsSemanticsUpdate();
  }

  bool get isSelectionMode => _isSelectionMode;
  set isSelectionMode(bool value) {
    if (_isSelectionMode == value) return;
    _isSelectionMode = value;
    markNeedsSemanticsUpdate();
  }

  bool get isSelected => _isSelected;
  set isSelected(bool value) {
    if (_isSelected == value) return;
    _isSelected = value;
    markNeedsSemanticsUpdate();
  }

  bool get isPopoverOpen => _isPopoverOpen;
  set isPopoverOpen(bool value) {
    if (_isPopoverOpen == value) return;
    _isPopoverOpen = value;
  }

  ValueChanged<CalendarTask>? get onResizePreview => _onResizePreview;
  set onResizePreview(ValueChanged<CalendarTask>? value) {
    _onResizePreview = value;
  }

  ValueChanged<CalendarTask>? get onResizeEnd => _onResizeEnd;
  set onResizeEnd(ValueChanged<CalendarTask>? value) {
    _onResizeEnd = value;
  }

  ValueChanged<Offset>? get onResizePointerMove => _onResizePointerMove;
  set onResizePointerMove(ValueChanged<Offset>? value) {
    _onResizePointerMove = value;
  }

  ValueChanged<Offset>? get onDragPointerDown => _onDragPointerDown;
  set onDragPointerDown(ValueChanged<Offset>? value) {
    _onDragPointerDown = value;
  }

  void Function(CalendarTask task, Rect globalBounds)? get onTap => _onTap;
  set onTap(void Function(CalendarTask task, Rect globalBounds)? value) {
    _onTap = value;
  }

  VoidCallback? get onToggleSelection => _onToggleSelection;
  set onToggleSelection(VoidCallback? value) {
    _onToggleSelection = value;
  }

  TaskTileContextMenuCallback? get onContextMenuPosition =>
      _onContextMenuPosition;
  set onContextMenuPosition(TaskTileContextMenuCallback? value) {
    _onContextMenuPosition = value;
  }

  bool get _isDraggingSelf => interactionController.draggingTaskId == task.id;

  bool get _canResize =>
      enableInteractions && task.scheduledTime != null && size.height > 0;

  bool get _showHandles {
    final double available = (size.height - 4).clamp(0.0, double.infinity);
    return enableInteractions &&
        !task.isCompleted &&
        available >= 14 &&
        !_isDraggingSelf;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_showHandles) {
      return;
    }
    final Canvas canvas = context.canvas;
    final Rect bounds = offset & size;
    final double lineWidth = math.min(size.width * 0.3, 40);
    const double lineHeight = 3;
    final double dx = bounds.left + (bounds.width - lineWidth) / 2;
    final Paint paint = Paint()
      ..color = task.priorityColor.withValues(alpha: 0.5);
    if (_resizeActive && _activeHandle == 'top') {
      paint.color = task.priorityColor.withValues(alpha: 0.85);
    }
    final Rect topRect = Rect.fromLTWH(
      dx,
      bounds.top + 2,
      lineWidth,
      lineHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(topRect, const Radius.circular(1.5)),
      paint,
    );
    paint.color = task.priorityColor.withValues(
      alpha: _resizeActive && _activeHandle == 'bottom' ? 0.85 : 0.5,
    );
    final Rect bottomRect = Rect.fromLTWH(
      dx,
      bounds.bottom - lineHeight - 2,
      lineWidth,
      lineHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bottomRect, const Radius.circular(1.5)),
      paint,
    );
  }

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    super.handleEvent(event, entry);
    if (!enableInteractions || _isDraggingSelf) {
      return;
    }
    if (event is PointerHoverEvent) {
      _updateCursor(event.localPosition);
      return;
    }
    if (event is PointerDownEvent) {
      _handlePointerDown(event);
      return;
    }
    if (_activePointer != event.pointer) {
      return;
    }
    if (event is PointerMoveEvent) {
      _handlePointerMove(event);
      return;
    }
    if (event is PointerUpEvent) {
      _handlePointerUp(event);
      return;
    }
    if (event is PointerCancelEvent) {
      _handlePointerCancel();
    }
  }

  void _handlePointerEnter(PointerEnterEvent event) {
    if (isPopoverOpen || !enableInteractions) {
      return;
    }
    interactionController.setHoveringTask(task.id);
  }

  void _handlePointerExit(PointerExitEvent event) {
    interactionController.clearHoveringTask(task.id);
    cursor = SystemMouseCursors.click;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _downLocalPosition = event.localPosition;
    _pendingTap = true;
    _resizeActive = false;
    _activeHandle = null;
    _cancelResizeLongPressRecognizer();
    _lastPointerSecondary = (event.buttons & kSecondaryButton) != 0;
    onContextMenuPosition?.call(
      event.localPosition,
      _normalizedFromLocal(event.localPosition),
    );
    final bool primaryButton = event.buttons == kPrimaryButton;
    if (primaryButton) {
      onDragPointerDown?.call(_normalizedFromLocal(event.localPosition));
      final String? handle = _hitHandle(event.localPosition);
      if (_canResize && handle != null && !_resizeActive) {
        if (_shouldDelayResizeForPointer(event.kind)) {
          _startResizeLongPressRecognizer(handle, event);
        } else {
          _beginResize(handle);
        }
        return;
      }
    } else if (_hitHandle(event.localPosition) != null && _canResize) {
      // Secondary drag shouldn't initiate resize; ensure cursor updates only.
      _updateCursor(event.localPosition);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_resizeLongPressRecognizer != null &&
        _pendingResizeHandle != null &&
        _downLocalPosition != null &&
        (event.localPosition - _downLocalPosition!).distance > _tapSlop) {
      _cancelResizeLongPressRecognizer();
    }
    if (_resizeActive) {
      _updateResize(event);
      return;
    }
    if (_downLocalPosition != null &&
        (event.localPosition - _downLocalPosition!).distance > _tapSlop) {
      _pendingTap = false;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _cancelResizeLongPressRecognizer();
    if (_resizeActive) {
      _endResize();
      _resetPointerState();
      return;
    }
    if (_pendingTap && !_lastPointerSecondary) {
      _triggerTap();
    }
    _resetPointerState();
  }

  void _handlePointerCancel() {
    _cancelResizeLongPressRecognizer();
    if (_resizeActive) {
      interactionController.endResizeInteraction(task.id);
    }
    _resetPointerState();
  }

  void _triggerTap() {
    if (isSelectionMode) {
      onToggleSelection?.call();
      return;
    }
    onTap?.call(task, _globalBounds());
  }

  bool _shouldDelayResizeForPointer(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus ||
        kind == PointerDeviceKind.unknown;
  }

  void _startResizeLongPressRecognizer(
    String handle,
    PointerDownEvent event,
  ) {
    _pendingResizeHandle = handle;
    final LongPressGestureRecognizer recognizer = LongPressGestureRecognizer(
      duration: _touchResizeLongPressDelay,
    )
      ..onLongPressStart = (_) {
        if (_pendingResizeHandle != null && !_resizeActive) {
          _beginResize(_pendingResizeHandle!);
        }
      }
      ..onLongPressEnd = (_) {
        _cancelResizeLongPressRecognizer();
      }
      ..onLongPressUp = () {
        _cancelResizeLongPressRecognizer();
      };
    _resizeLongPressRecognizer = recognizer;
    recognizer.addPointer(event);
  }

  void _cancelResizeLongPressRecognizer() {
    _pendingResizeHandle = null;
    _resizeLongPressRecognizer?.dispose();
    _resizeLongPressRecognizer = null;
  }

  @override
  void dispose() {
    _cancelResizeLongPressRecognizer();
    super.dispose();
  }

  Rect _globalBounds() {
    final Offset origin = localToGlobal(Offset.zero);
    return origin & size;
  }

  void _resetPointerState() {
    _activePointer = null;
    _downLocalPosition = null;
    _resizeActive = false;
    _pendingTap = false;
    _activeHandle = null;
    _totalResizeDelta = 0;
    _lastAppliedStep = 0;
    cursor = SystemMouseCursors.click;
  }

  void _beginResize(String handle) {
    _pendingResizeHandle = null;
    _resizeActive = true;
    _activeHandle = handle;
    interactionController.suppressSurfaceTapOnce();
    interactionController.beginResizeInteraction(
      taskId: task.id,
      handle: handle,
    );
    interactionController.registerResizeAutoScrollHandler(
      _handleResizeAutoScrollDelta,
    );
    final DateTime? start = task.scheduledTime;
    final Duration duration = task.duration ?? const Duration(hours: 1);
    _currentStartHour = (start?.hour ?? 0) + ((start?.minute ?? 0) / 60.0);
    _currentDurationHours = duration.inMinutes / 60.0;
    _tempScheduled = null;
    _tempDuration = null;
    _totalResizeDelta = 0;
    _lastAppliedStep = 0;
    HapticFeedback.selectionClick();
  }

  void _updateResize(PointerMoveEvent event) {
    onResizePointerMove?.call(event.position);
    _applyResizeDelta(event.delta.dy);
  }

  void _applyResizeDelta(double deltaDy) {
    if (!_resizeActive || deltaDy == 0) {
      return;
    }
    _totalResizeDelta += deltaDy;
    final double steps = _totalResizeDelta / (stepHeight == 0 ? 1 : stepHeight);
    final int stepToApply = steps > 0 ? steps.floor() : steps.ceil();
    final int deltaSteps = stepToApply - _lastAppliedStep;
    if (deltaSteps == 0) {
      return;
    }
    _lastAppliedStep = stepToApply;
    final double stepMinutes =
        (minutesPerStep <= 0 ? 15 : minutesPerStep).clamp(1, 120).toDouble();
    final double hoursDelta = (deltaSteps * stepMinutes) / 60.0;
    final double minDurationHours = stepMinutes / 60.0;

    if (_activeHandle == 'top') {
      final DateTime scheduled = task.scheduledTime!;
      final double currentEndHour =
          (_currentStartHour + _currentDurationHours).clamp(0.0, 24.0);
      double newStartHour = (_currentStartHour + hoursDelta)
          .clamp(0.0, currentEndHour - minDurationHours);
      final double newDuration =
          (currentEndHour - newStartHour).clamp(minDurationHours, 24.0);
      _currentStartHour = newStartHour;
      _currentDurationHours = newDuration;
      final int startMinutes = (_currentStartHour * 60).round();
      final DateTime updatedStart = DateTime(
        scheduled.year,
        scheduled.month,
        scheduled.day,
        (startMinutes ~/ 60),
        startMinutes % 60,
      );
      _tempScheduled = updatedStart;
      _tempDuration = Duration(minutes: (_currentDurationHours * 60).round());
    } else if (_activeHandle == 'bottom') {
      final double maxDuration = 24.0 - _currentStartHour;
      final double nextDuration = (_currentDurationHours + hoursDelta)
          .clamp(minDurationHours, maxDuration);
      _currentDurationHours = nextDuration;
      _tempScheduled = task.scheduledTime;
      _tempDuration = Duration(minutes: (_currentDurationHours * 60).round());
    }

    final CalendarTask? preview = _buildResizePreview();
    if (preview != null) {
      onResizePreview?.call(preview);
    }
  }

  void _handleResizeAutoScrollDelta(double delta) {
    _applyResizeDelta(delta);
  }

  void _endResize() {
    final CalendarTask? preview = _buildResizePreview();
    interactionController.endResizeInteraction(task.id);
    _resizeActive = false;
    _activeHandle = null;
    _totalResizeDelta = 0;
    _lastAppliedStep = 0;
    final CalendarTask result = preview ?? task;
    onResizeEnd?.call(result);
    _tempScheduled = null;
    _tempDuration = null;
  }

  CalendarTask? _buildResizePreview() {
    final DateTime? schedule = _tempScheduled ?? task.scheduledTime;
    final Duration? duration = _tempDuration ?? task.duration;
    if (schedule == task.scheduledTime && duration == task.duration) {
      return null;
    }
    return task.copyWith(
      scheduledTime: schedule,
      duration: duration,
      endDate: schedule != null && duration != null
          ? schedule.add(duration)
          : task.endDate,
      startHour: schedule != null
          ? schedule.hour + (schedule.minute / 60.0)
          : task.startHour,
    );
  }

  String? _hitHandle(Offset localPosition) {
    if (!_showHandles) {
      return null;
    }
    final double width = size.width;
    if (_handleExtent > 10 && width.isFinite && width > 0) {
      final double handleWidth = math.max(
        _touchHandleHorizontalMin,
        math.min(
            width * _touchHandleHorizontalFraction, _touchHandleHorizontalMax),
      );
      final double left = (width - handleWidth) / 2;
      final double right = left + handleWidth;
      if (localPosition.dx < left || localPosition.dx > right) {
        return null;
      }
    }
    if (localPosition.dy <= _handleExtent) {
      return 'top';
    }
    if (localPosition.dy >= size.height - _handleExtent) {
      return 'bottom';
    }
    return null;
  }

  Offset _normalizedFromLocal(Offset localPosition) {
    final double width = size.width <= 0 ? 1 : size.width;
    final double height = size.height <= 0 ? 1 : size.height;
    return Offset(
      (localPosition.dx / width).clamp(0.0, 1.0),
      (localPosition.dy / height).clamp(0.0, 1.0),
    );
  }

  void _updateCursor(Offset localPosition) {
    final String? handle = _hitHandle(localPosition);
    if (handle != null && _showHandles) {
      if (cursor != SystemMouseCursors.resizeUpDown) {
        cursor = SystemMouseCursors.resizeUpDown;
      }
    } else if (cursor != SystemMouseCursors.click) {
      cursor = SystemMouseCursors.click;
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isEnabled = enableInteractions
      ..label = task.title
      ..textDirection = TextDirection.ltr;
    if (!enableInteractions) {
      return;
    }
    config.onTap = _handleSemanticTap;
    config.onIncrease = _handleSemanticExtend;
    config.onDecrease = _handleSemanticShrink;
    config.onLongPress = _handleSemanticSelect;
    config.isSelected = isSelected;
    config.customSemanticsActions =
        const <CustomSemanticsAction, VoidCallback>{};
  }

  void _handleSemanticTap() {
    if (isSelectionMode) {
      onToggleSelection?.call();
      return;
    }
    onTap?.call(task, _globalBounds());
  }

  void _handleSemanticExtend() {
    if (!_canResize) {
      return;
    }
    _activeHandle = 'bottom';
    _tempDuration = Duration(
      minutes: ((task.duration ?? const Duration(minutes: 15)).inMinutes +
              minutesPerStep.clamp(1, 60))
          .clamp(15, 1440),
    );
    final CalendarTask? preview = _buildResizePreview();
    if (preview != null) {
      onResizeEnd?.call(preview);
    }
  }

  void _handleSemanticShrink() {
    if (!_canResize) {
      return;
    }
    _activeHandle = 'bottom';
    final int baseMinutes =
        (task.duration ?? const Duration(minutes: 30)).inMinutes;
    final int nextMinutes =
        math.max(minutesPerStep.clamp(1, 60), baseMinutes - minutesPerStep);
    _tempDuration = Duration(minutes: nextMinutes);
    final CalendarTask? preview = _buildResizePreview();
    if (preview != null) {
      onResizeEnd?.call(preview);
    }
  }

  void _handleSemanticSelect() {
    onToggleSelection?.call();
  }
}
