// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';

typedef ResizeAutoScrollHandler = void Function(double delta);

@immutable
class DragPreview {
  const DragPreview({required this.start, required this.duration});

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
  const TaskClipboardState({this.template, this.pasteSlot});

  final CalendarTask? template;
  final DateTime? pasteSlot;

  TaskClipboardState copyWith({CalendarTask? template, DateTime? pasteSlot}) {
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
  const TaskResizeInteraction({required this.taskId, required this.handle});

  final String taskId;
  final String handle;

  TaskResizeInteraction copyWith({String? handle}) {
    return TaskResizeInteraction(taskId: taskId, handle: handle ?? this.handle);
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

enum CalendarTaskPointerTarget { body, resizeTop, resizeBottom }

enum CalendarInteractionKind { drag, resizeTop, resizeBottom }

enum CalendarInteractionSource { unknown, taskSurface, external }

enum CalendarInteractionVerticalIntent { neutral, up, down }

enum CalendarInteractionHorizontalIntent { neutral, backward, forward }

@immutable
class CalendarInteractionSession {
  const CalendarInteractionSession({
    required this.kind,
    required this.taskId,
    required this.globalPosition,
    this.source = CalendarInteractionSource.unknown,
    this.verticalIntent = CalendarInteractionVerticalIntent.neutral,
    this.horizontalIntent = CalendarInteractionHorizontalIntent.neutral,
  });

  final CalendarInteractionKind kind;
  final String taskId;
  final Offset globalPosition;
  final CalendarInteractionSource source;
  final CalendarInteractionVerticalIntent verticalIntent;
  final CalendarInteractionHorizontalIntent horizontalIntent;

  bool get isResize =>
      kind == CalendarInteractionKind.resizeTop ||
      kind == CalendarInteractionKind.resizeBottom;

  bool get isDrag => kind == CalendarInteractionKind.drag;

  CalendarInteractionSession copyWith({
    CalendarInteractionKind? kind,
    String? taskId,
    Offset? globalPosition,
    CalendarInteractionSource? source,
    CalendarInteractionVerticalIntent? verticalIntent,
    CalendarInteractionHorizontalIntent? horizontalIntent,
  }) {
    return CalendarInteractionSession(
      kind: kind ?? this.kind,
      taskId: taskId ?? this.taskId,
      globalPosition: globalPosition ?? this.globalPosition,
      source: source ?? this.source,
      verticalIntent: verticalIntent ?? this.verticalIntent,
      horizontalIntent: horizontalIntent ?? this.horizontalIntent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarInteractionSession &&
        other.kind == kind &&
        other.taskId == taskId &&
        other.globalPosition == globalPosition &&
        other.source == source &&
        other.verticalIntent == verticalIntent &&
        other.horizontalIntent == horizontalIntent;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    taskId,
    globalPosition,
    source,
    verticalIntent,
    horizontalIntent,
  );
}

class TaskInteractionController extends ChangeNotifier {
  TaskInteractionController({ValueChanged<String>? onTaskInteracted})
    : _onTaskInteracted = onTaskInteracted,
      preview = ValueNotifier<DragPreview?>(null),
      clipboard = ValueNotifier<TaskClipboardState>(const TaskClipboardState()),
      resizePreviewRevision = ValueNotifier<int>(0),
      draggingTaskIdNotifier = ValueNotifier<String?>(null),
      hoveredTaskId = ValueNotifier<String?>(null),
      dropHoverTaskId = ValueNotifier<String?>(null),
      resizeInteraction = ValueNotifier<TaskResizeInteraction?>(null),
      interactionSession = ValueNotifier<CalendarInteractionSession?>(null);

  final ValueChanged<String>? _onTaskInteracted;

  final ValueNotifier<DragPreview?> preview;
  final ValueNotifier<TaskClipboardState> clipboard;
  final ValueNotifier<int> resizePreviewRevision;
  final ValueNotifier<String?> draggingTaskIdNotifier;
  final ValueNotifier<String?> hoveredTaskId;
  final ValueNotifier<String?> dropHoverTaskId;
  final ValueNotifier<TaskResizeInteraction?> resizeInteraction;
  final ValueNotifier<CalendarInteractionSession?> interactionSession;

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
  double? dragPointerStartGlobalY;
  int? _activeDragPointerId;
  bool dragHasMoved = false;

  Timer? _dragWidthDebounce;
  Timer? _pendingDragWidthTimer;
  double? _pendingDragWidth;
  bool _pendingDragForceCenter = false;
  ResizeAutoScrollHandler? _resizeAutoScrollHandler;
  final Map<int, (String taskId, CalendarTaskPointerTarget target)>
  _pendingTaskPointerTargets = <int, (String, CalendarTaskPointerTarget)>{};

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
  CalendarInteractionSession? get activeInteractionSession =>
      interactionSession.value;
  int? get activeDragPointerId => _activeDragPointerId;

  bool isDraggingTask(CalendarTask task) {
    if (_draggingTaskId == task.id) {
      return true;
    }
    return _draggingTaskBaseId != null && _draggingTaskBaseId == task.baseId;
  }

  bool shouldHighlightTaskForFirstInteraction(CalendarTask task) {
    return !task.isRead;
  }

  void acknowledgeTaskInteraction(String taskId, {bool isRead = false}) {
    if (isRead) {
      return;
    }
    final normalizedTaskId = _taskInteractionKey(taskId);
    if (normalizedTaskId.isEmpty) {
      return;
    }
    _onTaskInteracted?.call(normalizedTaskId);
  }

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

  void setHoveringTask(String taskId, {bool isRead = false}) {
    acknowledgeTaskInteraction(taskId, isRead: isRead);
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
    required Offset globalPosition,
  }) {
    final TaskResizeInteraction next = TaskResizeInteraction(
      taskId: taskId,
      handle: handle,
    );
    final CalendarInteractionKind kind = handle == 'top'
        ? CalendarInteractionKind.resizeTop
        : CalendarInteractionKind.resizeBottom;
    final CalendarInteractionSession session = CalendarInteractionSession(
      kind: kind,
      taskId: taskId,
      globalPosition: globalPosition,
      source: CalendarInteractionSource.unknown,
    );
    final bool unchanged =
        resizeInteraction.value == next && interactionSession.value == session;
    if (unchanged) {
      return;
    }
    resizeInteraction.value = next;
    interactionSession.value = session;
    notifyListeners();
  }

  void beginTaskPointerClassification({
    required String taskId,
    required int pointerId,
    required CalendarTaskPointerTarget target,
  }) {
    final (String taskId, CalendarTaskPointerTarget target)? existing =
        _pendingTaskPointerTargets[pointerId];
    if (existing != null && existing.$1 == taskId && existing.$2 == target) {
      return;
    }
    _pendingTaskPointerTargets[pointerId] = (taskId, target);
  }

  CalendarTaskPointerTarget? taskPointerClassification({
    required String taskId,
    required int pointerId,
  }) {
    final (String taskId, CalendarTaskPointerTarget target)? existing =
        _pendingTaskPointerTargets[pointerId];
    if (existing == null || existing.$1 != taskId) {
      return null;
    }
    return existing.$2;
  }

  void clearTaskPointerClassification({
    required String taskId,
    required int pointerId,
  }) {
    final (String taskId, CalendarTaskPointerTarget target)? existing =
        _pendingTaskPointerTargets[pointerId];
    if (existing == null || existing.$1 != taskId) {
      return;
    }
    _pendingTaskPointerTargets.remove(pointerId);
  }

  void endResizeInteraction(String taskId) {
    if (resizeInteraction.value?.taskId != taskId) {
      return;
    }
    resizeInteraction.value = null;
    if (interactionSession.value?.taskId == taskId &&
        interactionSession.value?.isResize == true) {
      interactionSession.value = null;
    }
    _resizeAutoScrollHandler = null;
    notifyListeners();
  }

  void updatePreview(DateTime start, Duration duration) {
    final DragPreview next = DragPreview(start: start, duration: duration);
    preview.value = next;
  }

  void clearPreview() {
    if (preview.value == null) {
      return;
    }
    preview.value = null;
  }

  void beginDrag({
    required CalendarTask task,
    required CalendarTask snapshot,
    required Rect bounds,
    required double pointerNormalized,
    required double pointerGlobalX,
    required DateTime? originSlot,
    int? pointerId,
  }) {
    clearPreview();
    setDropHoverTaskId(null);
    final double normalizedPointer = pointerNormalized.clamp(0.0, 1.0);
    _draggingTaskId = task.id;
    draggingTaskIdNotifier.value = task.id;
    _draggingTaskBaseId = task.baseId;
    _draggingTaskSnapshot = snapshot;
    _dragStartScheduledTime = task.scheduledTime;
    final double resolvedHeight = bounds.height.isFinite && bounds.height > 0
        ? bounds.height
        : 0.0;
    final double? pointerOffsetFraction = consumePendingPointerOffsetFraction(
      taskId: task.id,
    );
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
      pointerOffset = (pointerOffset.clamp(0.0, resolvedHeight) as num)
          .toDouble();
    } else if (pointerOffset < 0) {
      pointerOffset = 0.0;
    }
    dragStartGlobalTop = bounds.top;
    draggingTaskHeight = bounds.height;
    setDragPointerOffsetFromTop(pointerOffset, notify: false);
    final double width = bounds.width.isFinite ? bounds.width : 0.0;
    final double pointerLeftOffset = width > 0
        ? width * normalizedPointer
        : 0.0;
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
    _activeDragPointerId = pointerId;
    interactionSession.value = CalendarInteractionSession(
      kind: CalendarInteractionKind.drag,
      taskId: task.id,
      globalPosition: Offset(pointerGlobalX, pointerGlobalY),
      source: CalendarInteractionSource.taskSurface,
    );
    dragHasMoved = false;
    _dragOriginSlot = originSlot;
    _cancelPendingWidthUpdates();
    notifyListeners();
  }

  void endDrag() {
    _draggingTaskId = null;
    draggingTaskIdNotifier.value = null;
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
    dragPointerStartGlobalY = null;
    _activeDragPointerId = null;
    dragPointerNormalized = 0.5;
    if (interactionSession.value?.isDrag == true) {
      interactionSession.value = null;
    }
    dragHasMoved = false;
    _pendingAnchorMinutes = null;
    clearPreview();
    _cancelPendingWidthUpdates();
    notifyListeners();
  }

  void updatePendingAnchorMinutes(DateTime? anchorMinutes) {
    _pendingAnchorMinutes = anchorMinutes;
  }

  void setResizePreview(String id, CalendarTask task) {
    final CalendarTask? current = _resizePreviews[id];
    if (current == task) {
      return;
    }
    _resizePreviews[id] = task;
    resizePreviewRevision.value += 1;
  }

  void clearResizePreview(String id) {
    final CalendarTask? removed = _resizePreviews.remove(id);
    if (removed != null) {
      resizePreviewRevision.value += 1;
    }
  }

  void clearResizePreviews() {
    if (_resizePreviews.isEmpty) {
      return;
    }
    _resizePreviews.clear();
    resizePreviewRevision.value += 1;
  }

  void registerResizeAutoScrollHandler(ResizeAutoScrollHandler? handler) {
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

  void setDragPointerOffsetFromTop(double? value, {bool notify = true}) {
    final double? previous = dragPointerOffsetFromTop;
    final bool changed = previous != value;
    dragPointerOffsetFromTop = value;
    if (_draggingTaskId == null) {
      dragPointerStartGlobalY = null;
    } else if (value != null && dragStartGlobalTop != null) {
      dragPointerStartGlobalY = dragStartGlobalTop! + value;
    } else if (value == null) {
      dragPointerStartGlobalY = null;
    }
    if (notify && changed) {
      notifyListeners();
    }
  }

  void setPendingPointerOffsetFraction(double? fraction, {String? taskId}) {
    if (fraction == null || fraction.isNaN) {
      _pendingPointerOffsetFraction = null;
      if (taskId != null && _pendingPointerTaskId == taskId) {
        _pendingPointerTaskId = null;
      }
      return;
    }
    _pendingPointerOffsetFraction = (fraction.clamp(0.0, 1.0) as num)
        .toDouble();
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
    bool notify = false,
  }) {
    final double dx = globalPosition.dx;
    final double dy = globalPosition.dy;
    final bool changed = dragPointerGlobalX != dx || dragPointerGlobalY != dy;
    dragPointerGlobalX = dx;
    dragPointerGlobalY = dy;
    final CalendarInteractionSession? session = interactionSession.value;
    if (session != null && session.isDrag) {
      interactionSession.value = session.copyWith(
        globalPosition: globalPosition,
      );
    }
    if (notify && changed) {
      notifyListeners();
    }
  }

  void updateResizePointerGlobalPosition(Offset globalPosition) {
    final CalendarInteractionSession? session = interactionSession.value;
    if (session == null || !session.isResize) {
      return;
    }
    if (session.globalPosition == globalPosition) {
      return;
    }
    interactionSession.value = session.copyWith(globalPosition: globalPosition);
  }

  void updateInteractionEdgeIntent({
    required CalendarInteractionVerticalIntent verticalIntent,
    required CalendarInteractionHorizontalIntent horizontalIntent,
  }) {
    final CalendarInteractionSession? session = interactionSession.value;
    if (session == null) {
      return;
    }
    if (session.verticalIntent == verticalIntent &&
        session.horizontalIntent == horizontalIntent) {
      return;
    }
    interactionSession.value = session.copyWith(
      verticalIntent: verticalIntent,
      horizontalIntent: horizontalIntent,
    );
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
    clearPreview();
    setDropHoverTaskId(null);
    _draggingTaskId = task.id;
    draggingTaskIdNotifier.value = task.id;
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
    dragStartGlobalTop = globalPosition.dy;
    setDragPointerOffsetFromTop(pointerOffsetY, notify: false);
    draggingTaskHeight = feedbackSize?.height;
    final double clampedPointerDx = (!width.isFinite || width <= 0)
        ? pointerOffset.dx
        : pointerOffset.dx.clamp(0.0, width);
    dragStartGlobalLeft = globalPosition.dx;
    draggingTaskWidth = feedbackSize?.width;
    activeDragWidth = feedbackSize?.width;
    dragInitialWidth = feedbackSize?.width;
    dragAnchorDx = clampedPointerDx;
    dragPointerNormalized = (!width.isFinite || width <= 0)
        ? 0.5
        : (clampedPointerDx / width).clamp(0.0, 1.0);
    final Offset pointerPosition = Offset(
      globalPosition.dx + clampedPointerDx,
      globalPosition.dy + pointerOffsetY,
    );
    updateDragPointerGlobalPosition(pointerPosition, notify: false);
    interactionSession.value = CalendarInteractionSession(
      kind: CalendarInteractionKind.drag,
      taskId: task.id,
      globalPosition: pointerPosition,
      source: CalendarInteractionSource.external,
    );
    _activeDragPointerId = null;
    dragHasMoved = false;
    notifyListeners();
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

  @override
  void dispose() {
    _cancelPendingWidthUpdates();
    preview.dispose();
    clipboard.dispose();
    resizePreviewRevision.dispose();
    draggingTaskIdNotifier.dispose();
    hoveredTaskId.dispose();
    dropHoverTaskId.dispose();
    resizeInteraction.dispose();
    interactionSession.dispose();
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

  String _taskInteractionKey(String taskId) {
    return baseTaskIdFrom(taskId).trim();
  }
}
