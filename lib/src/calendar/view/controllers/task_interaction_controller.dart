import 'dart:async';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import '../../models/calendar_task.dart';
import '../../utils/recurrence_utils.dart';
import '../resizable_task_widget.dart';

typedef ResizeAutoScrollHandler = void Function(double delta);

@immutable
class DragPreview {
  const DragPreview({
    required this.start,
    required this.duration,
  });

  final DateTime start;
  final Duration duration;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DragPreview &&
        other.start.isAtSameMomentAs(start) &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(start.millisecondsSinceEpoch, duration);
}

@immutable
class TaskClipboardState {
  const TaskClipboardState({
    this.template,
    this.pasteSlot,
  });

  final CalendarTask? template;
  final DateTime? pasteSlot;

  TaskClipboardState copyWith({
    CalendarTask? template,
    DateTime? pasteSlot,
  }) {
    return TaskClipboardState(
      template: template ?? this.template,
      pasteSlot: pasteSlot ?? this.pasteSlot,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskClipboardState &&
        other.template == template &&
        other.pasteSlot == pasteSlot;
  }

  @override
  int get hashCode => Object.hash(template, pasteSlot);
}

@immutable
class TaskResizeInteraction {
  const TaskResizeInteraction({
    required this.taskId,
    required this.handle,
  });

  final String taskId;
  final String handle;

  TaskResizeInteraction copyWith({
    String? handle,
  }) {
    return TaskResizeInteraction(
      taskId: taskId,
      handle: handle ?? this.handle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskResizeInteraction &&
        other.taskId == taskId &&
        other.handle == handle;
  }

  @override
  int get hashCode => Object.hash(taskId, handle);
}

class TaskInteractionController extends ChangeNotifier {
  TaskInteractionController()
      : preview = ValueNotifier<DragPreview?>(null),
        clipboard = ValueNotifier<TaskClipboardState>(
          const TaskClipboardState(),
        ),
        feedbackHint = ValueNotifier<DragFeedbackHint>(
          const DragFeedbackHint(
            width: 0,
            pointerOffset: 0,
            anchorDx: 0,
            anchorDy: 0,
          ),
        ),
        hoveredTaskId = ValueNotifier<String?>(null),
        dropHoverTaskId = ValueNotifier<String?>(null),
        resizeInteraction = ValueNotifier<TaskResizeInteraction?>(null);

  final ValueNotifier<DragPreview?> preview;
  final ValueNotifier<TaskClipboardState> clipboard;
  final ValueNotifier<DragFeedbackHint> feedbackHint;
  final ValueNotifier<String?> hoveredTaskId;
  final ValueNotifier<String?> dropHoverTaskId;
  final ValueNotifier<TaskResizeInteraction?> resizeInteraction;

  CalendarTask? _draggingTaskSnapshot;
  String? _draggingTaskId;
  String? _draggingTaskBaseId;
  DateTime? _dragStartScheduledTime;
  DateTime? _dragOriginSlot;
  DateTime? _pendingAnchorMinutes;

  double? dragPointerOffsetFromTop;
  double? _pendingPointerOffsetFraction;
  String? _pendingPointerTaskId;
  double? dragStartGlobalTop;
  double? draggingTaskHeight;
  double? dragStartGlobalLeft;
  double? draggingTaskWidth;
  double? activeDragWidth;
  double? dragInitialWidth;
  double? dragAnchorDx;
  double dragPointerNormalized = 0.5;
  double? dragPointerGlobalX;
  double? dragPointerGlobalY;
  bool dragHasMoved = false;

  Timer? _dragWidthDebounce;
  Timer? _pendingDragWidthTimer;
  double? _pendingDragWidth;
  bool _pendingDragForceCenter = false;
  ResizeAutoScrollHandler? _resizeAutoScrollHandler;
  bool _suppressSurfaceTap = false;

  final Map<String, CalendarTask> _resizePreviews = {};

  CalendarTask? get draggingTaskSnapshot => _draggingTaskSnapshot;
  String? get draggingTaskId => _draggingTaskId;
  String? get draggingTaskBaseId => _draggingTaskBaseId;
  DateTime? get dragStartScheduledTime => _dragStartScheduledTime;
  DateTime? get dragOriginSlot => _dragOriginSlot;
  DateTime? get pendingAnchorMinutes => _pendingAnchorMinutes;
  Map<String, CalendarTask> get resizePreviews => _resizePreviews;

  CalendarTask? get clipboardTemplate => clipboard.value.template;
  DateTime? get clipboardPasteSlot => clipboard.value.pasteSlot;
  String? get currentHoveredTaskId => hoveredTaskId.value;
  String? get currentDropHoverTaskId => dropHoverTaskId.value;
  TaskResizeInteraction? get activeResizeInteraction => resizeInteraction.value;

  void setClipboardTemplate(CalendarTask template) {
    clipboard.value = TaskClipboardState(
      template: template,
      pasteSlot: template.scheduledTime,
    );
    notifyListeners();
  }

  void updateClipboardPasteSlot(DateTime slot) {
    clipboard.value = clipboard.value.copyWith(pasteSlot: slot);
    notifyListeners();
  }

  void clearClipboard() {
    if (clipboard.value.template == null && clipboard.value.pasteSlot == null) {
      return;
    }
    clipboard.value = const TaskClipboardState();
    notifyListeners();
  }

  void suppressSurfaceTapOnce() {
    _suppressSurfaceTap = true;
  }

  bool consumeSurfaceTapSuppression() {
    if (!_suppressSurfaceTap) {
      return false;
    }
    _suppressSurfaceTap = false;
    return true;
  }

  void setHoveringTask(String taskId) {
    if (hoveredTaskId.value == taskId) {
      return;
    }
    hoveredTaskId.value = taskId;
  }

  void clearHoveringTask(String taskId) {
    if (hoveredTaskId.value != taskId) {
      return;
    }
    hoveredTaskId.value = null;
  }

  void setDropHoverTaskId(String? taskId) {
    if (dropHoverTaskId.value == taskId) {
      return;
    }
    dropHoverTaskId.value = taskId;
  }

  void beginResizeInteraction({
    required String taskId,
    required String handle,
  }) {
    final TaskResizeInteraction next =
        TaskResizeInteraction(taskId: taskId, handle: handle);
    if (resizeInteraction.value == next) {
      return;
    }
    resizeInteraction.value = next;
    notifyListeners();
  }

  void endResizeInteraction(String taskId) {
    if (resizeInteraction.value?.taskId != taskId) {
      return;
    }
    resizeInteraction.value = null;
    _resizeAutoScrollHandler = null;
    notifyListeners();
  }

  void updatePreview(DateTime start, Duration duration) {
    final DragPreview next = DragPreview(start: start, duration: duration);
    preview.value = next;
    notifyListeners();
  }

  void clearPreview() {
    if (preview.value == null) {
      return;
    }
    preview.value = null;
    notifyListeners();
  }

  void beginDrag({
    required CalendarTask task,
    required CalendarTask snapshot,
    required Rect bounds,
    required double pointerNormalized,
    required double pointerGlobalX,
    required DateTime? originSlot,
  }) {
    final double normalizedPointer = pointerNormalized.clamp(0.0, 1.0);
    _draggingTaskId = task.id;
    _draggingTaskBaseId = task.baseId;
    _draggingTaskSnapshot = snapshot;
    _dragStartScheduledTime = task.scheduledTime;
    final double resolvedHeight =
        bounds.height.isFinite && bounds.height > 0 ? bounds.height : 0.0;
    final double? pointerOffsetFraction =
        consumePendingPointerOffsetFraction(taskId: task.id);
    double pointerOffset;
    if (dragPointerOffsetFromTop != null) {
      pointerOffset = dragPointerOffsetFromTop!;
    } else if (pointerOffsetFraction != null && resolvedHeight > 0) {
      pointerOffset = pointerOffsetFraction * resolvedHeight;
    } else if (resolvedHeight > 0) {
      pointerOffset = resolvedHeight / 2;
    } else {
      pointerOffset = 0.0;
    }
    if (!pointerOffset.isFinite) {
      pointerOffset = 0.0;
    }
    if (resolvedHeight > 0) {
      pointerOffset =
          (pointerOffset.clamp(0.0, resolvedHeight) as num).toDouble();
    } else if (pointerOffset < 0) {
      pointerOffset = 0.0;
    }
    setDragPointerOffsetFromTop(pointerOffset, notify: false);
    dragStartGlobalTop = bounds.top;
    draggingTaskHeight = bounds.height;
    final double width = bounds.width.isFinite ? bounds.width : 0.0;
    final double pointerLeftOffset =
        width > 0 ? width * normalizedPointer : 0.0;
    dragStartGlobalLeft = pointerGlobalX - pointerLeftOffset;
    draggingTaskWidth = bounds.width;
    activeDragWidth = bounds.width;
    dragInitialWidth = bounds.width;
    dragAnchorDx = bounds.width * normalizedPointer;
    dragPointerNormalized = normalizedPointer;
    final double pointerGlobalY = bounds.top + pointerOffset;
    updateDragPointerGlobalPosition(
      Offset(pointerGlobalX, pointerGlobalY),
      notify: false,
    );
    dragHasMoved = false;
    _dragOriginSlot = originSlot;
    _cancelPendingWidthUpdates();
    notifyListeners();
  }

  void endDrag() {
    _draggingTaskId = null;
    _draggingTaskBaseId = null;
    _draggingTaskSnapshot = null;
    _dragStartScheduledTime = null;
    _dragOriginSlot = null;
    setDragPointerOffsetFromTop(null, notify: false);
    dragStartGlobalTop = null;
    draggingTaskHeight = null;
    dragStartGlobalLeft = null;
    draggingTaskWidth = null;
    activeDragWidth = null;
    dragInitialWidth = null;
    dragAnchorDx = null;
    _pendingPointerOffsetFraction = null;
    _pendingPointerTaskId = null;
    dragPointerGlobalX = null;
    dragPointerGlobalY = null;
    dragPointerNormalized = 0.5;
    dragHasMoved = false;
    _pendingAnchorMinutes = null;
    clearPreview();
    resetFeedbackHint();
    _cancelPendingWidthUpdates();
    notifyListeners();
  }

  void updatePendingAnchorMinutes(DateTime? anchorMinutes) {
    _pendingAnchorMinutes = anchorMinutes;
    notifyListeners();
  }

  void setResizePreview(String id, CalendarTask task) {
    _resizePreviews[id] = task;
    notifyListeners();
  }

  void clearResizePreview(String id) {
    if (_resizePreviews.remove(id) != null) {
      notifyListeners();
    }
  }

  void clearResizePreviews() {
    if (_resizePreviews.isEmpty) {
      return;
    }
    _resizePreviews.clear();
    notifyListeners();
  }

  void registerResizeAutoScrollHandler(
    ResizeAutoScrollHandler? handler,
  ) {
    _resizeAutoScrollHandler = handler;
  }

  void dispatchResizeAutoScrollDelta(double delta) {
    _resizeAutoScrollHandler?.call(delta);
  }

  void setActiveDragWidth(double width) {
    activeDragWidth = width;
  }

  void setDragPointerNormalized(double normalized) {
    dragPointerNormalized = normalized;
  }

  void setDragPointerOffsetFromTop(
    double? value, {
    bool notify = true,
  }) {
    if (dragPointerOffsetFromTop == value) {
      return;
    }
    dragPointerOffsetFromTop = value;
    if (notify) {
      notifyListeners();
    }
  }

  void setPendingPointerOffsetFraction(
    double? fraction, {
    String? taskId,
  }) {
    if (fraction == null || fraction.isNaN) {
      _pendingPointerOffsetFraction = null;
      if (taskId != null && _pendingPointerTaskId == taskId) {
        _pendingPointerTaskId = null;
      }
      return;
    }
    _pendingPointerOffsetFraction =
        (fraction.clamp(0.0, 1.0) as num).toDouble();
    if (taskId != null) {
      _pendingPointerTaskId = taskId;
    }
  }

  double? consumePendingPointerOffsetFraction({String? taskId}) {
    if (taskId != null &&
        _pendingPointerTaskId != null &&
        _pendingPointerTaskId != taskId) {
      return null;
    }
    final double? fraction = _pendingPointerOffsetFraction;
    _pendingPointerOffsetFraction = null;
    if (taskId != null && _pendingPointerTaskId == taskId) {
      _pendingPointerTaskId = null;
    }
    if (fraction == null || fraction.isNaN) {
      return null;
    }
    return (fraction.clamp(0.0, 1.0) as num).toDouble();
  }

  void applyPendingPointerOffsetFraction({
    required String taskId,
    required double height,
  }) {
    if (_pendingPointerTaskId == null ||
        _pendingPointerTaskId != taskId ||
        height <= 0 ||
        !height.isFinite) {
      return;
    }
    final double? fraction = _pendingPointerOffsetFraction;
    if (fraction == null || fraction.isNaN) {
      return;
    }
    final double bounded = (fraction.clamp(0.0, 1.0) as num).toDouble();
    final double offset = bounded * height;
    setDragPointerOffsetFromTop(offset, notify: false);
  }

  void updateDragPointerGlobalPosition(
    Offset globalPosition, {
    bool notify = true,
  }) {
    final double dx = globalPosition.dx;
    final double dy = globalPosition.dy;
    final bool changed = dragPointerGlobalX != dx || dragPointerGlobalY != dy;
    dragPointerGlobalX = dx;
    dragPointerGlobalY = dy;
    if (notify && changed) {
      notifyListeners();
    }
  }

  void beginExternalDrag({
    required CalendarTask task,
    required CalendarTask snapshot,
    required Offset pointerOffset,
    required Size? feedbackSize,
    required Offset globalPosition,
  }) {
    if (_draggingTaskId == task.id) {
      return;
    }
    _draggingTaskId = task.id;
    _draggingTaskBaseId = task.baseId;
    _draggingTaskSnapshot = snapshot;
    _dragStartScheduledTime = task.scheduledTime;
    final double width = feedbackSize?.width ?? draggingTaskWidth ?? 0;
    final double height = feedbackSize?.height ?? draggingTaskHeight ?? 0;
    double pointerOffsetY = pointerOffset.dy;
    if (!pointerOffsetY.isFinite) {
      pointerOffsetY = 0.0;
    }
    if (height.isFinite && height > 0) {
      pointerOffsetY = pointerOffsetY.clamp(0.0, height);
    } else if (pointerOffsetY < 0) {
      pointerOffsetY = 0.0;
    }
    setDragPointerOffsetFromTop(pointerOffsetY, notify: false);
    dragStartGlobalTop = globalPosition.dy - pointerOffsetY;
    draggingTaskHeight = feedbackSize?.height;
    final double clampedPointerDx = (!width.isFinite || width <= 0)
        ? pointerOffset.dx
        : pointerOffset.dx.clamp(0.0, width);
    dragStartGlobalLeft = globalPosition.dx - clampedPointerDx;
    draggingTaskWidth = feedbackSize?.width;
    activeDragWidth = feedbackSize?.width;
    dragInitialWidth = feedbackSize?.width;
    dragAnchorDx = clampedPointerDx;
    dragPointerNormalized = (!width.isFinite || width <= 0)
        ? 0.5
        : (clampedPointerDx / width).clamp(0.0, 1.0);
    updateDragPointerGlobalPosition(globalPosition, notify: false);
    dragHasMoved = false;
    notifyListeners();
  }

  void updateExternalDragPosition(Offset globalPosition) {
    updateDragPointerGlobalPosition(globalPosition);
  }

  void markDragMoved() {
    dragHasMoved = true;
    cancelWidthDebounce();
    notifyListeners();
  }

  bool get isWidthDebounceActive => _dragWidthDebounce?.isActive ?? false;
  bool get hasPendingWidthUpdate => _pendingDragWidthTimer?.isActive ?? false;

  void startWidthDebounce(Duration duration) {
    _dragWidthDebounce?.cancel();
    _dragWidthDebounce = Timer(duration, () {
      _dragWidthDebounce = null;
    });
  }

  void cancelWidthDebounce() {
    _dragWidthDebounce?.cancel();
    _dragWidthDebounce = null;
  }

  void schedulePendingWidth({
    required double width,
    required bool forceCenter,
    required Duration delay,
    required VoidCallback onApply,
  }) {
    _pendingDragWidth = width;
    _pendingDragForceCenter = forceCenter;
    _pendingDragWidthTimer?.cancel();
    _pendingDragWidthTimer = Timer(delay, () {
      _pendingDragWidthTimer = null;
      _pendingDragWidth = null;
      _pendingDragForceCenter = false;
      onApply();
    });
  }

  bool shouldReusePendingWidth({
    required double width,
    required bool forceCenter,
    double tolerance = 0.5,
  }) {
    if (!(_pendingDragWidthTimer?.isActive ?? false)) {
      return false;
    }
    if (_pendingDragWidth == null) {
      return false;
    }
    return (_pendingDragWidth! - width).abs() <= tolerance &&
        _pendingDragForceCenter == forceCenter;
  }

  void cancelPendingWidthTimer() {
    _pendingDragWidthTimer?.cancel();
    _pendingDragWidthTimer = null;
    _pendingDragWidth = null;
    _pendingDragForceCenter = false;
  }

  void resetFeedbackHint() {
    feedbackHint.value = const DragFeedbackHint(
      width: 0,
      pointerOffset: 0,
      anchorDx: 0,
      anchorDy: 0,
    );
  }

  void setFeedbackHint(DragFeedbackHint hint) {
    if (feedbackHint.value == hint) {
      return;
    }
    feedbackHint.value = hint;
  }

  @override
  void dispose() {
    _cancelPendingWidthUpdates();
    preview.dispose();
    clipboard.dispose();
    feedbackHint.dispose();
    hoveredTaskId.dispose();
    dropHoverTaskId.dispose();
    resizeInteraction.dispose();
    super.dispose();
  }

  void _cancelPendingWidthUpdates() {
    _dragWidthDebounce?.cancel();
    _dragWidthDebounce = null;
    _pendingDragWidthTimer?.cancel();
    _pendingDragWidthTimer = null;
    _pendingDragWidth = null;
    _pendingDragForceCenter = false;
  }
}
