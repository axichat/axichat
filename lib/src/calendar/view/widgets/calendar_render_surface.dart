// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/layout/calendar_layout.dart';
import 'package:axichat/src/calendar/view/models/calendar_drag_payload.dart';
import 'package:axichat/src/calendar/utils/calendar_free_busy_style.dart';
import 'calendar_task_geometry.dart';
import 'calendar_task_surface.dart';

/// Controller that exposes geometry computed by [RenderCalendarSurface].
class CalendarSurfaceController {
  RenderCalendarSurface? _renderObject;
  final List<VoidCallback> _geometryListeners = <VoidCallback>[];
  bool _geometryDirty = false;

  void _attach(RenderCalendarSurface renderObject) {
    _renderObject = renderObject;
  }

  void _detach(RenderCalendarSurface renderObject) {
    if (_renderObject == renderObject) {
      _renderObject = null;
    }
  }

  void addGeometryListener(VoidCallback listener) {
    _geometryListeners.add(listener);
  }

  void removeGeometryListener(VoidCallback listener) {
    _geometryListeners.remove(listener);
  }

  void _markGeometryDirty() {
    _geometryDirty = true;
  }

  void _dispatchGeometryChanged() {
    if (!_geometryDirty) {
      return;
    }
    _geometryDirty = false;
    _notifyGeometryChanged();
  }

  void _notifyGeometryChanged() {
    if (_geometryListeners.isEmpty) {
      return;
    }
    final callbacks = List<VoidCallback>.from(_geometryListeners);
    for (final callback in callbacks) {
      callback();
    }
  }

  CalendarTaskGeometry? geometryForTask(String taskId) =>
      _renderObject?.geometryForTask(taskId);

  Rect? localRectForTask(String taskId) =>
      _renderObject?.localRectForTask(taskId);

  Rect? globalRectForTask(String taskId) =>
      _renderObject?.globalRectForTask(taskId);

  DateTime? slotForOffset(Offset localOffset) =>
      _renderObject?.slotForOffset(localOffset);

  CalendarLayoutMetrics? get resolvedMetrics => _renderObject?.metrics;

  bool containsTaskAt(Offset localPosition) =>
      _renderObject?.containsTaskAt(localPosition) ?? false;

  Rect? columnBoundsForDate(DateTime date) =>
      _renderObject?.columnBoundsForDate(date);

  double? columnWidthForOffset(Offset localOffset) =>
      _renderObject?.columnWidthForOffset(localOffset);

  RenderCalendarSurface? get _activeSurface {
    final RenderCalendarSurface? surface = _renderObject;
    if (surface == null || !surface.attached) {
      return null;
    }
    return surface;
  }

  bool dispatchDragPayloadUpdate(
    CalendarDragPayload payload,
    Offset globalPosition,
  ) {
    final RenderCalendarSurface? surface = _activeSurface;
    if (surface == null) {
      return false;
    }
    surface.handleDragPayloadUpdate(payload, globalPosition);
    return true;
  }

  bool dispatchDragPayloadDrop(
    CalendarDragPayload payload,
    Offset globalPosition,
  ) {
    final RenderCalendarSurface? surface = _activeSurface;
    if (surface == null) {
      return false;
    }
    surface.handleDragPayloadDrop(payload, globalPosition);
    return true;
  }

  bool dispatchDragPayloadExit(CalendarDragPayload payload) {
    final RenderCalendarSurface? surface = _activeSurface;
    if (surface == null) {
      return false;
    }
    surface.handleDragPayloadExit(payload);
    return true;
  }
}

/// Describes the visible day columns rendered inside [CalendarRenderSurface].
@immutable
class CalendarDayColumn {
  const CalendarDayColumn({
    required this.date,
  });

  final DateTime date;

  DateTime get normalizedDate => DateTime(date.year, date.month, date.day);
}

typedef CalendarSurfacePaintCallback = void Function();

@immutable
class CalendarSurfaceTapDetails {
  const CalendarSurfaceTapDetails({
    required this.slotStart,
    required this.localPosition,
    required this.hitTask,
  });

  final DateTime slotStart;
  final Offset localPosition;
  final bool hitTask;
}

@immutable
class CalendarSurfaceDragUpdateDetails {
  const CalendarSurfaceDragUpdateDetails({
    required this.slotStart,
    required this.localPosition,
    required this.globalPosition,
    required this.columnWidth,
    required this.previewStart,
    required this.previewDuration,
    this.hoverTaskId,
    this.narrowedWidth,
    this.overlapsScheduled = false,
    this.shouldNarrowWidth = false,
    this.forceCenterPointer = false,
  });

  final DateTime slotStart;
  final Offset localPosition;
  final Offset globalPosition;
  final double? columnWidth;
  final DateTime previewStart;
  final Duration previewDuration;
  final String? hoverTaskId;
  final double? narrowedWidth;
  final bool overlapsScheduled;
  final bool shouldNarrowWidth;
  final bool forceCenterPointer;
}

@immutable
class CalendarSurfaceDragEndDetails {
  const CalendarSurfaceDragEndDetails({
    required this.slotStart,
    required this.globalPosition,
  });

  final DateTime slotStart;
  final Offset globalPosition;
}

class CalendarRenderSurface extends MultiChildRenderObjectWidget {
  const CalendarRenderSurface({
    super.key,
    required super.children,
    required this.columns,
    required this.startHour,
    required this.endHour,
    required this.zoomIndex,
    required this.allowDayViewZoom,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.layoutCalculator,
    required this.layoutTheme,
    required this.controller,
    required this.verticalScrollController,
    required this.minutesPerStep,
    required this.interactionController,
    required this.availabilityWindows,
    required this.availabilityOverlays,
    this.hoveredSlot,
    this.onTap,
    this.dragPreview,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragExit,
    this.onDragAutoScroll,
    this.onDragAutoScrollStop,
    this.isTaskDragInProgress,
    this.onGeometryChanged,
  });

  final List<CalendarDayColumn> columns;
  final int startHour;
  final int endHour;
  final int zoomIndex;
  final bool allowDayViewZoom;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final CalendarLayoutCalculator layoutCalculator;
  final CalendarLayoutTheme layoutTheme;
  final CalendarSurfaceController controller;
  final ScrollController verticalScrollController;
  final int minutesPerStep;
  final TaskInteractionController interactionController;
  final List<CalendarAvailabilityWindow> availabilityWindows;
  final List<CalendarAvailabilityOverlay> availabilityOverlays;
  final DateTime? hoveredSlot;
  final ValueChanged<CalendarSurfaceTapDetails>? onTap;
  final DragPreview? dragPreview;
  final ValueChanged<CalendarSurfaceDragUpdateDetails>? onDragUpdate;
  final ValueChanged<CalendarSurfaceDragEndDetails>? onDragEnd;
  final VoidCallback? onDragExit;
  final ValueChanged<Offset>? onDragAutoScroll;
  final VoidCallback? onDragAutoScrollStop;
  final ValueGetter<bool>? isTaskDragInProgress;
  final VoidCallback? onGeometryChanged;

  @override
  RenderCalendarSurface createRenderObject(BuildContext context) {
    return RenderCalendarSurface(
      columns: columns,
      startHour: startHour,
      endHour: endHour,
      zoomIndex: zoomIndex,
      allowDayViewZoom: allowDayViewZoom,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      layoutCalculator: layoutCalculator,
      layoutTheme: layoutTheme,
      controller: controller,
      verticalScrollController: verticalScrollController,
      minutesPerStep: minutesPerStep,
      interactionController: interactionController,
      availabilityWindows: availabilityWindows,
      availabilityOverlays: availabilityOverlays,
      hoveredSlot: hoveredSlot,
      devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
      onTap: onTap,
      dragPreview: dragPreview,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      onDragExit: onDragExit,
      onDragAutoScroll: onDragAutoScroll,
      onDragAutoScrollStop: onDragAutoScrollStop,
      isTaskDragInProgress: isTaskDragInProgress,
      onGeometryChanged: onGeometryChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCalendarSurface renderObject,
  ) {
    renderObject
      ..columns = columns
      ..startHour = startHour
      ..endHour = endHour
      ..zoomIndex = zoomIndex
      ..allowDayViewZoom = allowDayViewZoom
      ..weekStartDate = weekStartDate
      ..weekEndDate = weekEndDate
      ..layoutCalculator = layoutCalculator
      ..layoutTheme = layoutTheme
      ..controller = controller
      ..verticalScrollController = verticalScrollController
      ..minutesPerStep = minutesPerStep
      ..interactionController = interactionController
      ..availabilityWindows = availabilityWindows
      ..availabilityOverlays = availabilityOverlays
      ..hoveredSlot = hoveredSlot
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0
      ..onTap = onTap
      ..dragPreview = dragPreview
      ..onDragUpdate = onDragUpdate
      ..onDragEnd = onDragEnd
      ..onDragExit = onDragExit
      ..onDragAutoScroll = onDragAutoScroll
      ..onDragAutoScrollStop = onDragAutoScrollStop
      ..isTaskDragInProgress = isTaskDragInProgress
      ..onGeometryChanged = onGeometryChanged;
  }
}

class CalendarSurfaceTaskEntry
    extends ParentDataWidget<CalendarSurfaceParentData> {
  const CalendarSurfaceTaskEntry({
    super.key,
    required this.task,
    required this.bindings,
    required super.child,
  });

  final CalendarTask task;
  final CalendarTaskEntryBindings bindings;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData as CalendarSurfaceParentData;
    bool needsLayout = false;
    if (parentData.task != task) {
      parentData.task = task;
      needsLayout = true;
    }
    if (!identical(parentData.bindings, bindings)) {
      parentData.bindings = bindings;
    }

    if (needsLayout) {
      final parent = renderObject.parent;
      if (parent is RenderObject) {
        parent.markNeedsLayout();
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => CalendarRenderSurface;
}

class CalendarSurfaceParentData extends ContainerBoxParentData<RenderBox> {
  CalendarTask? task;
  CalendarTaskEntryBindings? bindings;
  CalendarTaskGeometry geometry = CalendarTaskGeometry.empty;
}

class _DayColumnGeometry {
  const _DayColumnGeometry({
    required this.date,
    required this.bounds,
  });

  final DateTime date;
  final Rect bounds;

  bool contains(DateTime target) =>
      date.year == target.year &&
      date.month == target.month &&
      date.day == target.day;
}

class _TaskHit {
  const _TaskHit({
    required this.task,
    required this.geometry,
  });

  final CalendarTask task;
  final CalendarTaskGeometry geometry;
}

class _DragLayoutOverride {
  const _DragLayoutOverride({
    required this.rect,
    required this.columnDate,
  });

  final Rect rect;
  final DateTime columnDate;
}

class _PreviewMetrics {
  const _PreviewMetrics({
    required this.start,
    required this.duration,
  });

  final DateTime start;
  final Duration duration;
}

bool _rectContainsInclusive(Rect rect, Offset point) {
  return point.dx >= rect.left &&
      point.dx < rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
}

class RenderCalendarSurface extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CalendarSurfaceParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CalendarSurfaceParentData> {
  RenderCalendarSurface({
    required List<CalendarDayColumn> columns,
    required int startHour,
    required int endHour,
    required int zoomIndex,
    required bool allowDayViewZoom,
    required DateTime weekStartDate,
    required DateTime weekEndDate,
    required CalendarLayoutCalculator layoutCalculator,
    required CalendarLayoutTheme layoutTheme,
    required CalendarSurfaceController controller,
    required ScrollController verticalScrollController,
    required int minutesPerStep,
    required TaskInteractionController interactionController,
    required List<CalendarAvailabilityWindow> availabilityWindows,
    required List<CalendarAvailabilityOverlay> availabilityOverlays,
    DateTime? hoveredSlot,
    required double devicePixelRatio,
    this.onTap,
    DragPreview? dragPreview,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragExit,
    this.onDragAutoScroll,
    this.onDragAutoScrollStop,
    this.isTaskDragInProgress,
    this.onGeometryChanged,
  })  : _columns = columns,
        _startHour = startHour,
        _endHour = endHour,
        _zoomIndex = zoomIndex,
        _allowDayViewZoom = allowDayViewZoom,
        _weekStartDate = weekStartDate,
        _weekEndDate = weekEndDate,
        _layoutCalculator = layoutCalculator,
        _layoutTheme = layoutTheme,
        _controller = controller,
        _verticalScrollController = verticalScrollController,
        _minutesPerStep = minutesPerStep,
        _interactionController = interactionController,
        _availabilityWindows = availabilityWindows,
        _availabilityOverlays = availabilityOverlays,
        _hoveredSlot = hoveredSlot,
        _devicePixelRatio = devicePixelRatio,
        _dragPreview = dragPreview;

  bool _geometryDispatchPending = false;

  List<CalendarDayColumn> get columns => _columns;
  List<CalendarDayColumn> _columns;
  set columns(List<CalendarDayColumn> value) {
    if (_columns == value) return;
    _columns = value;
    markNeedsLayout();
  }

  int get startHour => _startHour;
  int _startHour;
  set startHour(int value) {
    if (_startHour == value) return;
    _startHour = value;
    markNeedsLayout();
  }

  int get endHour => _endHour;
  int _endHour;
  set endHour(int value) {
    if (_endHour == value) return;
    _endHour = value;
    markNeedsLayout();
  }

  int get zoomIndex => _zoomIndex;
  int _zoomIndex;
  set zoomIndex(int value) {
    if (_zoomIndex == value) return;
    _zoomIndex = value;
    markNeedsLayout();
  }

  bool get allowDayViewZoom => _allowDayViewZoom;
  bool _allowDayViewZoom;
  set allowDayViewZoom(bool value) {
    if (_allowDayViewZoom == value) return;
    _allowDayViewZoom = value;
    markNeedsLayout();
  }

  DateTime get weekStartDate => _weekStartDate;
  DateTime _weekStartDate;
  set weekStartDate(DateTime value) {
    if (_weekStartDate == value) return;
    _weekStartDate = value;
    markNeedsLayout();
  }

  DateTime get weekEndDate => _weekEndDate;
  DateTime _weekEndDate;
  set weekEndDate(DateTime value) {
    if (_weekEndDate == value) return;
    _weekEndDate = value;
    markNeedsLayout();
  }

  CalendarLayoutCalculator get layoutCalculator => _layoutCalculator;
  CalendarLayoutCalculator _layoutCalculator;
  set layoutCalculator(CalendarLayoutCalculator value) {
    if (_layoutCalculator == value) return;
    _layoutCalculator = value;
    markNeedsLayout();
  }

  CalendarLayoutTheme get layoutTheme => _layoutTheme;
  CalendarLayoutTheme _layoutTheme;
  set layoutTheme(CalendarLayoutTheme value) {
    if (_layoutTheme == value) return;
    _layoutTheme = value;
    markNeedsLayout();
  }

  CalendarSurfaceController? get controller => _controller;
  CalendarSurfaceController? _controller;
  set controller(CalendarSurfaceController? value) {
    if (identical(_controller, value)) {
      return;
    }
    _controller?._detach(this);
    _controller = value;
    _controller?._attach(this);
  }

  ScrollController? get verticalScrollController => _verticalScrollController;
  ScrollController? _verticalScrollController;
  set verticalScrollController(ScrollController? value) {
    if (identical(_verticalScrollController, value)) {
      return;
    }
    _verticalScrollController = value;
  }

  int get minutesPerStep => _minutesPerStep;
  int _minutesPerStep;
  set minutesPerStep(int value) {
    if (_minutesPerStep == value) {
      return;
    }
    _minutesPerStep = value;
  }

  TaskInteractionController? get interactionController =>
      _interactionController;
  TaskInteractionController? _interactionController;
  set interactionController(TaskInteractionController? value) {
    if (identical(_interactionController, value)) {
      return;
    }
    _interactionController = value;
    markNeedsPaint();
  }

  List<CalendarAvailabilityWindow> get availabilityWindows =>
      _availabilityWindows;
  List<CalendarAvailabilityWindow> _availabilityWindows;
  set availabilityWindows(List<CalendarAvailabilityWindow> value) {
    if (identical(_availabilityWindows, value)) {
      return;
    }
    _availabilityWindows = value;
    markNeedsPaint();
  }

  List<CalendarAvailabilityOverlay> get availabilityOverlays =>
      _availabilityOverlays;
  List<CalendarAvailabilityOverlay> _availabilityOverlays;
  set availabilityOverlays(List<CalendarAvailabilityOverlay> value) {
    if (identical(_availabilityOverlays, value)) {
      return;
    }
    _availabilityOverlays = value;
    markNeedsPaint();
  }

  DateTime? get hoveredSlot => _hoveredSlot;
  DateTime? _hoveredSlot;
  set hoveredSlot(DateTime? value) {
    if (_slotsMatch(_hoveredSlot, value)) {
      return;
    }
    _hoveredSlot = value;
    markNeedsPaint();
  }

  ValueChanged<CalendarSurfaceTapDetails>? onTap;
  DragPreview? get dragPreview => _dragPreview;
  DragPreview? _dragPreview;
  set dragPreview(DragPreview? value) {
    if (_dragPreview == value) {
      return;
    }
    _dragPreview = value;
    markNeedsLayout();
  }

  ValueChanged<CalendarSurfaceDragUpdateDetails>? onDragUpdate;
  ValueChanged<CalendarSurfaceDragEndDetails>? onDragEnd;
  VoidCallback? onDragExit;
  ValueChanged<Offset>? onDragAutoScroll;
  VoidCallback? onDragAutoScrollStop;
  ValueGetter<bool>? isTaskDragInProgress;
  VoidCallback? onGeometryChanged;

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  CalendarLayoutMetrics? get metrics => _metrics;
  CalendarLayoutMetrics? _metrics;

  final Map<String, CalendarTaskGeometry> _taskGeometries =
      <String, CalendarTaskGeometry>{};
  final List<_DayColumnGeometry> _dayGeometries = <_DayColumnGeometry>[];
  static const double _tapTolerance = 12.0;
  static const double _scrollTapSuppressionThreshold = 1.0;
  static const double _availabilityOverlayAlpha = 0.08;
  static const double _availabilityWindowAlpha = 0.12;
  static const double _availabilityOverlayInset = 1.0;
  static const double _availabilityOverlayMinHeight = 1.0;
  static const double _availabilityOverlayMinWidth = 0.0;
  static const Duration _availabilityOverlayEndEpsilon =
      Duration(microseconds: 1);
  int? _activePointerId;
  Offset? _pointerDownLocal;
  DateTime? _pointerDownSlot;
  bool _pointerDownHitTask = false;
  bool _pointerDownIsPrimary = false;
  bool _pointerDragSessionActive = false;
  double? _pointerDownScrollOffset;
  String? _currentHoverTaskId;
  String? _externalDragTaskId;

  bool get _isDragInProgress => isTaskDragInProgress?.call() ?? false;

  void _updateHoverTask(String? taskId) {
    if (_currentHoverTaskId == taskId) {
      return;
    }
    _currentHoverTaskId = taskId;
    _interactionController?.setDropHoverTaskId(taskId);
  }

  _TaskHit? _taskHitTest(Offset localPosition) {
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData as CalendarSurfaceParentData;
      final CalendarTask? task = parentData.task;
      final CalendarTaskGeometry geometry = parentData.geometry;
      if (task != null &&
          geometry.rect.width > 0 &&
          geometry.rect.height > 0 &&
          geometry.rect.contains(localPosition)) {
        return _TaskHit(task: task, geometry: geometry);
      }
      child = childAfter(child);
    }
    return null;
  }

  _DragLayoutOverride? _dragOverrideForTask(
    CalendarTask task,
    CalendarLayoutMetrics metrics,
  ) {
    final TaskInteractionController? controller = _interactionController;
    if (controller == null ||
        controller.draggingTaskId != task.id ||
        !controller.dragHasMoved) {
      return null;
    }
    return _resolveActiveDragLayoutOverride(
      metrics,
      requireMovement: true,
    );
  }

  _DragLayoutOverride? _resolveActiveDragLayoutOverride(
    CalendarLayoutMetrics metrics, {
    bool requireMovement = false,
  }) {
    final TaskInteractionController? controller = _interactionController;
    final DragPreview? preview = _dragPreview;
    if (controller == null || preview == null) {
      return null;
    }
    if (requireMovement && !controller.dragHasMoved) {
      return null;
    }

    final _DayColumnGeometry? columnGeometry = _geometryForDate(preview.start);
    if (columnGeometry == null) {
      return null;
    }

    final double top = _verticalOffsetForTime(preview.start, metrics);
    final double height = math.max(
      metrics.heightForDuration(preview.duration),
      metrics.slotHeight,
    );
    final double columnTop = columnGeometry.bounds.top;
    final double columnBottom = columnGeometry.bounds.bottom;
    final double clampedTop = top.clamp(
      columnTop,
      math.max(columnTop, columnBottom - height),
    );
    final double clampedBottom = math
        .min(clampedTop + height, columnBottom)
        .clamp(clampedTop, double.infinity);
    if (clampedBottom <= clampedTop) {
      return null;
    }

    double width = controller.activeDragWidth ??
        controller.draggingTaskWidth ??
        columnGeometry.bounds.width;
    if (!width.isFinite || width <= 0) {
      width = columnGeometry.bounds.width;
    }
    width = width.clamp(0.0, columnGeometry.bounds.width);
    if (width <= 0) {
      return null;
    }

    final double normalized = controller.dragPointerNormalized.clamp(0.0, 1.0);
    final double anchorDx =
        (controller.dragAnchorDx ?? (width * normalized)).clamp(0.0, width);
    final double columnCenter =
        columnGeometry.bounds.left + (columnGeometry.bounds.width / 2);
    double left = columnCenter - anchorDx;
    final double minLeft = columnGeometry.bounds.left;
    final double maxLeft = columnGeometry.bounds.right - width;
    if (left < minLeft || left > maxLeft) {
      left = left.clamp(minLeft, maxLeft);
    }

    final Rect rect = Rect.fromLTWH(
      left,
      clampedTop,
      width,
      clampedBottom - clampedTop,
    );
    final DateTime normalizedColumnDate = DateTime(
      columnGeometry.date.year,
      columnGeometry.date.month,
      columnGeometry.date.day,
    );
    return _DragLayoutOverride(
      rect: rect,
      columnDate: normalizedColumnDate,
    );
  }

  _PreviewMetrics? _computePreviewMetricsForPointer({
    required Offset localPosition,
    required Offset globalPosition,
    required CalendarLayoutMetrics metrics,
    required TaskInteractionController controller,
    required CalendarTask draggingTask,
    required _DayColumnGeometry columnGeometry,
  }) {
    final double slotHeight = metrics.slotHeight;
    if (slotHeight <= 0) {
      return null;
    }

    final Duration baseDuration = _resolvePreviewDuration(
      controller,
      draggingTask,
    );
    final int minutesPerSlot = metrics.minutesPerSlot;
    final double previewSlotSpan =
        baseDuration.inMinutes / math.max(1, minutesPerSlot);
    if (!previewSlotSpan.isFinite || previewSlotSpan <= 0) {
      return null;
    }

    final double previewHeight = previewSlotSpan * slotHeight;
    double pointerOffset = controller.dragPointerOffsetFromTop ??
        _pointerOffsetForDrag(controller);
    if (!pointerOffset.isFinite || pointerOffset < 0) {
      pointerOffset = 0;
    }
    final DateTime columnDate = DateTime(
      columnGeometry.date.year,
      columnGeometry.date.month,
      columnGeometry.date.day,
    );

    final double columnTop = columnGeometry.bounds.top;
    final double columnBottom = columnGeometry.bounds.bottom;
    final double columnHeight = columnBottom - columnTop;
    if (!columnHeight.isFinite || columnHeight <= 0) {
      return null;
    }

    final double pointerClampHeight = columnHeight.isFinite && columnHeight > 0
        ? columnHeight
        : double.infinity;
    pointerOffset = pointerOffset.clamp(0.0, pointerClampHeight);

    final double pointerCurrentGlobalY =
        controller.dragPointerGlobalY ?? globalPosition.dy;
    final double pointerCurrentGlobalX =
        controller.dragPointerGlobalX ?? globalPosition.dx;
    final double? pointerStartGlobalY = controller.dragPointerStartGlobalY;
    final double? dragStartGlobalTop = controller.dragStartGlobalTop;
    final double pointerLocalDy = localPosition.dy;
    double pointerTopLocal;
    if (pointerStartGlobalY != null && dragStartGlobalTop != null) {
      final double initialPointerOffset =
          pointerStartGlobalY - dragStartGlobalTop;
      final double pointerTopGlobal =
          pointerCurrentGlobalY - initialPointerOffset;
      final Offset pointerTopLocalOffset = globalToLocal(
        Offset(pointerCurrentGlobalX, pointerTopGlobal),
      );
      pointerTopLocal = _clampLocalOffset(pointerTopLocalOffset).dy;
    } else {
      pointerTopLocal = pointerLocalDy - pointerOffset;
    }
    final double maxTop = previewHeight.isFinite && previewHeight > 0
        ? math.max(columnTop, columnBottom - previewHeight)
        : columnBottom;
    pointerTopLocal = pointerTopLocal.clamp(columnTop, maxTop);

    final double minutesPerPixel =
        slotHeight == 0 ? 0.0 : minutesPerSlot / slotHeight;
    final double pointerTopMinutes = minutesPerPixel == 0
        ? 0.0
        : (pointerTopLocal - columnTop) * minutesPerPixel;
    final double pointerLocalMinutes = minutesPerPixel == 0
        ? 0.0
        : (pointerLocalDy - columnTop) * minutesPerPixel;

    final int rawStepMinutes = minutesPerStep;
    final int stepMinutes = rawStepMinutes > 0
        ? rawStepMinutes
        : (minutesPerSlot > 0 ? minutesPerSlot : 15);
    final double dayMinutes = (endHour - startHour) * 60.0;
    final double previewMinutes = baseDuration.inMinutes.toDouble();
    final double maxStartMinutes = math.max(0.0, dayMinutes - previewMinutes);
    final int maxStepIndex = stepMinutes > 0
        ? math.max(0, (maxStartMinutes / stepMinutes).floor())
        : 0;

    int stepIndex = stepMinutes > 0
        ? ((pointerTopMinutes / stepMinutes).round()).clamp(0, maxStepIndex)
        : 0;
    double topMinutes = stepIndex * stepMinutes.toDouble();
    double bottomMinutes = topMinutes + previewMinutes;
    const double epsilon = 1e-6;

    while (pointerLocalMinutes + epsilon < topMinutes && stepIndex > 0) {
      stepIndex -= 1;
      topMinutes = stepIndex * stepMinutes.toDouble();
      bottomMinutes = topMinutes + previewMinutes;
    }
    while (pointerLocalMinutes - epsilon > bottomMinutes &&
        stepIndex < maxStepIndex) {
      stepIndex += 1;
      topMinutes = stepIndex * stepMinutes.toDouble();
      bottomMinutes = topMinutes + previewMinutes;
    }

    double finalStartMinutes = topMinutes;
    if (finalStartMinutes > maxStartMinutes && stepMinutes > 0) {
      final int boundedIndex =
          math.min(maxStepIndex, (maxStartMinutes / stepMinutes).floor());
      finalStartMinutes = boundedIndex * stepMinutes.toDouble();
      stepIndex = boundedIndex;
    }
    finalStartMinutes = finalStartMinutes.clamp(0.0, maxStartMinutes);

    final double finalTopLocal =
        columnTop + metrics.verticalOffsetForMinutes(finalStartMinutes);
    final double clampedTopLocal = finalTopLocal.clamp(
        columnTop, math.max(columnTop, columnBottom - previewHeight));

    double updatedPointerOffset = pointerLocalDy - clampedTopLocal;
    if (!updatedPointerOffset.isFinite) {
      updatedPointerOffset = pointerOffset;
    }
    updatedPointerOffset = updatedPointerOffset.clamp(0.0, pointerClampHeight);
    controller.setDragPointerOffsetFromTop(
      updatedPointerOffset,
      notify: false,
    );

    final DateTime dayStart = DateTime(
      columnGeometry.date.year,
      columnGeometry.date.month,
      columnGeometry.date.day,
      startHour,
    );
    int effectiveMinutes;
    if (stepMinutes > 0) {
      effectiveMinutes = stepIndex * stepMinutes;
    } else {
      final double fallbackMinutes = minutesPerPixel == 0
          ? 0.0
          : (clampedTopLocal - columnTop) * minutesPerPixel;
      effectiveMinutes = fallbackMinutes.round();
    }
    final DateTime candidateStart =
        dayStart.add(Duration(minutes: effectiveMinutes));
    final DateTime effectiveStart = _clampPreviewStart(
      candidateStart,
      columnDate,
      baseDuration,
      snapToStep: false,
    );

    return _PreviewMetrics(
      start: effectiveStart,
      duration: baseDuration,
    );
  }

  Offset _pointerGlobalForDragTarget({
    required CalendarDragPayload payload,
    required Offset dragTargetOffset,
    required TaskInteractionController controller,
  }) {
    if (payload.originSlot != null) {
      return _pointerGlobalForScheduledDrag(
        payload: payload,
        dragTargetOffset: dragTargetOffset,
        controller: controller,
      );
    }
    return _pointerGlobalForUnscheduledDrag(
      payload: payload,
      dragTargetOffset: dragTargetOffset,
      controller: controller,
    );
  }

  Offset _pointerGlobalForScheduledDrag({
    required CalendarDragPayload payload,
    required Offset dragTargetOffset,
    required TaskInteractionController controller,
  }) {
    final double width = controller.draggingTaskWidth ??
        controller.activeDragWidth ??
        controller.dragInitialWidth ??
        payload.sourceBounds?.width ??
        0.0;
    final double height =
        controller.draggingTaskHeight ?? payload.sourceBounds?.height ?? 0.0;

    double anchorDx;
    if (controller.dragAnchorDx != null) {
      anchorDx = controller.dragAnchorDx!;
      if (width > 0) {
        anchorDx = math.min(math.max(anchorDx, 0.0), width);
      }
    } else if (payload.pointerNormalizedX != null && width > 0) {
      anchorDx = math.min(
        math.max(width * payload.pointerNormalizedX!, 0.0),
        width,
      );
    } else if (width > 0) {
      final double normalized =
          (controller.dragPointerNormalized.clamp(0.0, 1.0) as num).toDouble();
      anchorDx = width * normalized;
    } else {
      anchorDx = 0.0;
    }

    double anchorDy;
    if (controller.dragPointerOffsetFromTop != null) {
      anchorDy = controller.dragPointerOffsetFromTop!;
    } else if (payload.pointerOffsetY != null) {
      anchorDy = payload.pointerOffsetY!;
    } else if (height > 0) {
      anchorDy = height / 2;
    } else {
      anchorDy = 0.0;
    }
    if (!anchorDy.isFinite) {
      anchorDy = 0.0;
    }
    if (height > 0) {
      anchorDy = math.min(math.max(anchorDy, 0.0), height);
    } else if (anchorDy < 0) {
      anchorDy = 0.0;
    }

    return dragTargetOffset + Offset(anchorDx, anchorDy);
  }

  Offset _pointerGlobalForUnscheduledDrag({
    required CalendarDragPayload payload,
    required Offset dragTargetOffset,
    required TaskInteractionController controller,
  }) {
    final double overlayWidth = payload.sourceBounds?.width ??
        controller.draggingTaskWidth ??
        controller.activeDragWidth ??
        controller.dragInitialWidth ??
        0.0;
    final double overlayHeight =
        payload.sourceBounds?.height ?? controller.draggingTaskHeight ?? 0.0;

    double anchorDx;
    if (payload.pointerNormalizedX != null && overlayWidth > 0) {
      anchorDx = ((overlayWidth * payload.pointerNormalizedX!)
              .clamp(0.0, overlayWidth) as num)
          .toDouble();
    } else if (controller.dragAnchorDx != null) {
      final double fallbackWidth = overlayWidth > 0
          ? overlayWidth
          : (controller.draggingTaskWidth ??
              controller.activeDragWidth ??
              controller.dragInitialWidth ??
              0.0);
      final double candidate = controller.dragAnchorDx!;
      anchorDx = fallbackWidth > 0
          ? (candidate.clamp(0.0, fallbackWidth) as num).toDouble()
          : candidate;
    } else if (overlayWidth > 0) {
      final double normalized =
          (controller.dragPointerNormalized.clamp(0.0, 1.0) as num).toDouble();
      anchorDx = overlayWidth * normalized;
    } else {
      anchorDx = 0.0;
    }

    double anchorDy;
    if (payload.pointerOffsetY != null) {
      anchorDy = payload.pointerOffsetY!;
    } else if (controller.dragPointerOffsetFromTop != null) {
      anchorDy = controller.dragPointerOffsetFromTop!;
    } else if (overlayHeight > 0) {
      anchorDy = overlayHeight / 2;
    } else {
      anchorDy = 0.0;
    }
    if (!anchorDy.isFinite) {
      anchorDy = 0.0;
    }
    final double heightClamp = overlayHeight > 0
        ? overlayHeight
        : (controller.draggingTaskHeight ?? double.infinity);
    if (heightClamp.isFinite && heightClamp > 0) {
      anchorDy = (anchorDy.clamp(0.0, heightClamp) as num).toDouble();
    } else if (anchorDy < 0) {
      anchorDy = 0.0;
    }

    return dragTargetOffset + Offset(anchorDx, anchorDy);
  }

  Offset _pointerGlobalForPayloadOnly(
    CalendarDragPayload payload,
    Offset dragTargetOffset,
  ) {
    final double width = payload.sourceBounds?.width ?? 0.0;
    final double height = payload.sourceBounds?.height ?? 0.0;
    double anchorDx;
    if (payload.pointerNormalizedX != null && width > 0) {
      anchorDx = math.min(
        math.max(width * payload.pointerNormalizedX!, 0.0),
        width,
      );
    } else if (width > 0) {
      anchorDx = width / 2;
    } else {
      anchorDx = 0.0;
    }
    double anchorDy = payload.pointerOffsetY ?? (height > 0 ? height / 2 : 0.0);
    if (!anchorDy.isFinite) {
      anchorDy = 0.0;
    }
    if (height > 0) {
      anchorDy = math.min(math.max(anchorDy, 0.0), height);
    } else if (anchorDy < 0) {
      anchorDy = 0.0;
    }
    return Offset(
      dragTargetOffset.dx + anchorDx,
      dragTargetOffset.dy + anchorDy,
    );
  }

  void _handlePointerDragUpdate(
    Offset localPosition,
    Offset globalPosition,
  ) {
    _pointerDragSessionActive = true;
    _pointerDownLocal = null;
    _pointerDownSlot = null;
    _pointerDownHitTask = false;
    final TaskInteractionController? controller = _interactionController;
    if (controller == null) {
      onDragAutoScroll?.call(globalPosition);
      return;
    }
    onDragAutoScroll?.call(globalPosition);
    controller.updateDragPointerGlobalPosition(globalPosition);
    final CalendarTask? draggingTask = controller.draggingTaskSnapshot;
    if (draggingTask == null) {
      return;
    }

    final Offset clampedLocal = _clampLocalOffset(localPosition);
    if (_isInTimeColumn(clampedLocal)) {
      _updateHoverTask(null);
      onDragExit?.call();
      onDragAutoScrollStop?.call();
      return;
    }

    final CalendarLayoutMetrics? metrics = _metrics;
    if (metrics == null) {
      _updateHoverTask(null);
      onDragExit?.call();
      onDragAutoScrollStop?.call();
      return;
    }

    _DayColumnGeometry? columnGeometry = _geometryForOffset(clampedLocal);
    columnGeometry ??= _geometryForHorizontal(clampedLocal.dx);
    if (columnGeometry == null) {
      _updateHoverTask(null);
      onDragExit?.call();
      onDragAutoScrollStop?.call();
      return;
    }

    final _PreviewMetrics? previewMetrics = _computePreviewMetricsForPointer(
      localPosition: clampedLocal,
      globalPosition: globalPosition,
      metrics: metrics,
      controller: controller,
      draggingTask: draggingTask,
      columnGeometry: columnGeometry,
    );
    if (previewMetrics == null) {
      _updateHoverTask(null);
      onDragExit?.call();
      onDragAutoScrollStop?.call();
      return;
    }

    DateTime previewStart = previewMetrics.start;
    final Duration previewDuration = previewMetrics.duration;

    final _TaskHit? hit = _taskHitTest(clampedLocal);
    final String? hoverTaskId =
        hit != null && controller.draggingTaskId != hit.task.id
            ? hit.task.id
            : null;
    final _TaskHit? hoverHit = hoverTaskId != null ? hit : null;
    _updateHoverTask(hoverTaskId);

    if (hoverHit != null) {
      final DateTime targetDate = hoverHit.geometry.columnDate ??
          DateTime(
            previewStart.year,
            previewStart.month,
            previewStart.day,
          );
      final DateTime? hoverStart =
          _computePreviewStartForHover(targetDate, globalPosition);
      if (hoverStart != null) {
        previewStart = hoverStart;
      }
    }

    if (!controller.dragHasMoved) {
      controller.markDragMoved();
    }

    final bool overlapsScheduled =
        _previewOverlapsScheduled(previewStart, previewDuration);

    final double? columnWidth = columnWidthForOffset(clampedLocal);

    onDragUpdate?.call(
      CalendarSurfaceDragUpdateDetails(
        slotStart: previewStart,
        localPosition: clampedLocal,
        globalPosition: globalPosition,
        columnWidth: columnWidth,
        previewStart: previewStart,
        previewDuration: previewDuration,
        hoverTaskId: hoverTaskId,
        narrowedWidth: null,
        overlapsScheduled: overlapsScheduled,
        shouldNarrowWidth: false,
        forceCenterPointer: false,
      ),
    );
  }

  void _trackPointerMovement(Offset localPosition) {
    final Offset? down = _pointerDownLocal;
    if (down == null) {
      return;
    }
    if ((localPosition - down).distance > _tapTolerance) {
      _pointerDragSessionActive = true;
    }
  }

  double _currentScrollOffset() {
    final ScrollController? controller = _verticalScrollController;
    if (controller == null || !controller.hasClients) {
      return 0.0;
    }
    return controller.position.pixels;
  }

  bool _didScrollDuringPointerGesture() {
    final double? start = _pointerDownScrollOffset;
    if (start == null) {
      return false;
    }
    final double delta = (_currentScrollOffset() - start).abs();
    return delta > _scrollTapSuppressionThreshold;
  }

  void _handlePointerUp(Offset localPosition, Offset globalPosition) {
    final bool dragActive = _isDragInProgress;
    final bool dragSessionActive = dragActive || _pointerDragSessionActive;
    if (dragActive) {
      final TaskInteractionController? controller = _interactionController;
      final CalendarTask? draggingTask = controller?.draggingTaskSnapshot;
      DateTime? dropStart;
      if (controller != null && draggingTask != null) {
        final CalendarLayoutMetrics? metrics = _metrics;
        final Offset clampedLocal = _clampLocalOffset(localPosition);
        _DayColumnGeometry? columnGeometry;
        if (metrics != null && !_isInTimeColumn(clampedLocal)) {
          columnGeometry = _geometryForOffset(clampedLocal);
          columnGeometry ??= _geometryForHorizontal(clampedLocal.dx);
        } else {
          columnGeometry = null;
        }
        if (metrics != null && columnGeometry != null) {
          final _PreviewMetrics? previewMetrics =
              _computePreviewMetricsForPointer(
            localPosition: clampedLocal,
            globalPosition: globalPosition,
            metrics: metrics,
            controller: controller,
            draggingTask: draggingTask,
            columnGeometry: columnGeometry,
          );
          dropStart = previewMetrics?.start;
        }
      }
      if (dropStart != null) {
        onDragEnd?.call(
          CalendarSurfaceDragEndDetails(
            slotStart: dropStart,
            globalPosition: globalPosition,
          ),
        );
      } else {
        onDragExit?.call();
      }
      onDragAutoScrollStop?.call();
      _resetPointerState();
      return;
    }

    final bool suppressTap =
        _interactionController?.consumeSurfaceTapSuppression() ?? false;
    final bool scrolledDuringGesture = _didScrollDuringPointerGesture();

    if (dragSessionActive || suppressTap || scrolledDuringGesture) {
      onDragAutoScrollStop?.call();
      _resetPointerState();
      return;
    }

    final DateTime? slotTime = slotForOffset(localPosition);
    final DateTime? snappedSlot =
        slotTime != null ? _snapToStep(slotTime) : null;

    if (onTap != null && _pointerDownSlot != null && _pointerDownIsPrimary) {
      final Offset down = _pointerDownLocal ?? localPosition;
      if ((localPosition - down).distance <= _tapTolerance) {
        final DateTime slot = snappedSlot ?? slotTime ?? _pointerDownSlot!;
        onTap!(
          CalendarSurfaceTapDetails(
            slotStart: slot,
            localPosition: localPosition,
            hitTask: _pointerDownHitTask || containsTaskAt(localPosition),
          ),
        );
      }
    }
    onDragAutoScrollStop?.call();
    _resetPointerState();
  }

  void _handlePointerCancel() {
    onDragExit?.call();
    onDragAutoScrollStop?.call();
    _resetPointerState();
    _updateHoverTask(null);
  }

  void _resetPointerState() {
    _activePointerId = null;
    _pointerDownLocal = null;
    _pointerDownSlot = null;
    _pointerDownHitTask = false;
    _pointerDownIsPrimary = false;
    _pointerDragSessionActive = false;
    _pointerDownScrollOffset = null;
    _updateHoverTask(null);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller?._attach(this);
  }

  @override
  void detach() {
    _controller?._detach(this);
    super.detach();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! CalendarSurfaceParentData) {
      child.parentData = CalendarSurfaceParentData();
    }
  }

  double get _timeColumnWidth => layoutTheme.timeColumnWidth;

  @override
  void performLayout() {
    final bool isDayView = columns.length <= 1;
    final double availableHeight =
        constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;
    final CalendarLayoutMetrics resolvedMetrics =
        layoutCalculator.resolveMetrics(
      zoomIndex: zoomIndex,
      isDayView: isDayView,
      availableHeight: availableHeight,
      allowDayViewZoom: allowDayViewZoom,
    );
    final double contentHeight = resolvedMetrics.slotHeight *
        layoutTheme.visibleHourRows *
        resolvedMetrics.slotsPerHour;
    final double widthFallback = _timeColumnWidth +
        math.max(1, columns.length) * layoutTheme.eventMinWidth;
    final double resolvedWidth =
        constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? math.max(constraints.maxWidth, widthFallback)
            : widthFallback;

    size = constraints.constrain(Size(resolvedWidth, contentHeight));

    _metrics = resolvedMetrics;
    _dayGeometries
      ..clear()
      ..addAll(_resolveDayGeometries());

    final Map<String, OverlapInfo> overlapMap = _computeOverlapMap();
    final Map<String, CalendarTaskGeometry> nextGeometries =
        <String, CalendarTaskGeometry>{};

    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData as CalendarSurfaceParentData;
      final CalendarTask? task = parentData.task;

      CalendarTaskGeometry geometry = CalendarTaskGeometry.empty;
      if (task != null && task.scheduledTime != null) {
        final DateTime scheduled = task.scheduledTime!;
        final _DayColumnGeometry? columnGeometry = _geometryForDate(scheduled);
        if (columnGeometry != null) {
          final _DragLayoutOverride? dragOverride =
              _dragOverrideForTask(task, resolvedMetrics);
          if (dragOverride != null) {
            final Rect rect = dragOverride.rect;
            final double columnWidth = rect.width;
            final double narrowedWidth = layoutCalculator.computeNarrowedWidth(
              columnWidth,
              rect.width,
            );
            final double splitWidthFactor = rect.width == 0
                ? 1.0
                : (narrowedWidth / rect.width).clamp(0.0, 1.0);
            geometry = CalendarTaskGeometry(
              rect: rect,
              narrowedWidth: narrowedWidth,
              splitWidthFactor: splitWidthFactor,
              columnDate: dragOverride.columnDate,
            );
            child.layout(
              BoxConstraints.tight(rect.size),
              parentUsesSize: true,
            );
            parentData.offset = rect.topLeft;
            parentData.geometry = geometry;
            nextGeometries[task.id] = geometry;
            child = childAfter(child);
            continue;
          }
          final OverlapInfo overlap = overlapMap[task.id] ??
              const OverlapInfo(columnIndex: 0, totalColumns: 1);

          final CalendarTaskLayout? layout = layoutCalculator.resolveTaskLayout(
            task: task,
            dayDate: columnGeometry.date,
            weekStartDate: weekStartDate,
            weekEndDate: weekEndDate,
            isDayView: isDayView,
            startHour: startHour,
            endHour: endHour,
            dayWidth: columnGeometry.bounds.width,
            metrics: resolvedMetrics,
            overlap: overlap,
          );

          if (layout != null && layout.width > 0 && layout.height > 0) {
            final Rect rect = Rect.fromLTWH(
              columnGeometry.bounds.left + layout.left,
              layout.top,
              math.min(layout.width, columnGeometry.bounds.width),
              layout.height,
            );
            final double narrowedWidth = layoutCalculator.computeNarrowedWidth(
              columnGeometry.bounds.width,
              rect.width,
            );
            final double splitWidthFactor = rect.width == 0
                ? 1.0
                : (narrowedWidth / rect.width).clamp(0.0, 1.0);
            geometry = CalendarTaskGeometry(
              rect: rect,
              narrowedWidth: narrowedWidth,
              splitWidthFactor: splitWidthFactor,
              columnDate: columnGeometry.date,
            );

            child.layout(
              BoxConstraints.tight(rect.size),
              parentUsesSize: true,
            );
            parentData.offset = rect.topLeft;
            parentData.geometry = geometry;
            nextGeometries[task.id] = geometry;
          }
        }
      }

      if (geometry == CalendarTaskGeometry.empty) {
        child.layout(
          const BoxConstraints.tightFor(width: 0, height: 0),
          parentUsesSize: true,
        );
        parentData
          ..offset = Offset.zero
          ..geometry = CalendarTaskGeometry.empty;
      }

      child = childAfter(child);
    }

    _taskGeometries
      ..clear()
      ..addAll(nextGeometries);
    _geometryDispatchPending = true;
    _controller?._markGeometryDirty();
    markNeedsPaint();
    invokeLayoutCallback((_) {
      _flushGeometryCallbacks();
    });
  }

  Iterable<_DayColumnGeometry> _resolveDayGeometries() {
    if (columns.isEmpty || size.width <= _timeColumnWidth) {
      return const Iterable<_DayColumnGeometry>.empty();
    }

    final int dayCount = columns.length;
    final double availableWidth = size.width - _timeColumnWidth;
    final double columnWidth = dayCount == 0 ? 0 : availableWidth / dayCount;
    final List<_DayColumnGeometry> resolved = <_DayColumnGeometry>[];

    for (int i = 0; i < columns.length; i++) {
      final CalendarDayColumn column = columns[i];
      final double left = _timeColumnWidth + (i * columnWidth);
      resolved.add(
        _DayColumnGeometry(
          date: column.normalizedDate,
          bounds: Rect.fromLTWH(
            left,
            0,
            columnWidth,
            size.height,
          ),
        ),
      );
    }
    return resolved;
  }

  _DayColumnGeometry? _geometryForDate(DateTime date) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    for (final geometry in _dayGeometries) {
      if (geometry.date == normalized) {
        return geometry;
      }
    }
    return null;
  }

  _DayColumnGeometry? _geometryForOffset(Offset localOffset) {
    for (final _DayColumnGeometry geometry in _dayGeometries) {
      if (_rectContainsInclusive(geometry.bounds, localOffset)) {
        return geometry;
      }
    }
    return null;
  }

  _DayColumnGeometry? _geometryForHorizontal(double dx) {
    for (final _DayColumnGeometry geometry in _dayGeometries) {
      if (dx >= geometry.bounds.left && dx <= geometry.bounds.right) {
        return geometry;
      }
    }
    return null;
  }

  Map<String, OverlapInfo> _computeOverlapMap() {
    final Map<DateTime, List<CalendarTask>> grouped =
        <DateTime, List<CalendarTask>>{};
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData as CalendarSurfaceParentData;
      final CalendarTask? task = parentData.task;
      if (task != null && task.scheduledTime != null) {
        final DateTime normalized = DateTime(
          task.scheduledTime!.year,
          task.scheduledTime!.month,
          task.scheduledTime!.day,
        );
        grouped.putIfAbsent(normalized, () => <CalendarTask>[]);
        grouped[normalized]!.add(task);
      }
      child = childAfter(child);
    }

    final Map<String, OverlapInfo> overlaps = <String, OverlapInfo>{};
    grouped.forEach((_, tasks) {
      overlaps.addAll(calculateOverlapColumns(tasks));
    });
    return overlaps;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintBackground(context.canvas, offset);
    defaultPaint(context, offset);
    if (_metrics != null) {
      _paintCurrentTimeIndicator(context.canvas, offset, _metrics!);
    }
  }

  void _flushGeometryCallbacks() {
    if (!_geometryDispatchPending) {
      return;
    }
    _geometryDispatchPending = false;
    _controller?._dispatchGeometryChanged();
    onGeometryChanged?.call();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  void _paintBackground(Canvas canvas, Offset offset) {
    final Rect bounds = offset & size;
    final Paint basePaint = Paint()..color = calendarBackgroundColor;
    canvas.drawRect(bounds, basePaint);

    final Rect timeColumnRect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      _timeColumnWidth,
      bounds.height,
    );
    final Paint timeColumnPaint = Paint()
      ..color = calendarSidebarBackgroundColor;
    canvas.drawRect(timeColumnRect, timeColumnPaint);

    if (_dayGeometries.isEmpty || _metrics == null) {
      return;
    }

    final CalendarLayoutMetrics resolvedMetrics = _metrics!;
    _paintDayColumns(canvas, offset, resolvedMetrics);
    _paintAvailabilityWindows(canvas, offset, resolvedMetrics);
    _paintAvailabilityOverlays(canvas, offset, resolvedMetrics);
    _paintGridLines(canvas, offset, resolvedMetrics);
    _paintVerticalDividers(canvas, offset);
    _paintTimeColumnLabels(canvas, offset, resolvedMetrics);
    _paintDragPreview(canvas, offset, resolvedMetrics);
    _paintHoverHighlight(canvas, offset, resolvedMetrics);
  }

  void _paintDayColumns(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
  ) {
    final DateTime today = DateTime.now();
    final double slotHeight = metrics.slotHeight;
    final int totalSlots = layoutTheme.visibleHourRows * metrics.slotsPerHour;
    final double maxHeight = size.height;

    final Paint paint = Paint();
    for (final _DayColumnGeometry column in _dayGeometries) {
      final bool isToday = _isSameDay(column.date, today);
      for (int slot = 0; slot < totalSlots; slot++) {
        final double top = slot * slotHeight;
        if (top >= maxHeight) {
          break;
        }
        final int totalMinutes =
            (startHour * 60) + (slot * metrics.minutesPerSlot);
        final int hour = (totalMinutes ~/ 60) % 24;
        paint.color = _slotBackgroundColor(
          isToday: isToday,
          hour: hour,
          isEvenSlot: slot.isEven,
        );
        final Rect slotRect = Rect.fromLTWH(
          offset.dx + column.bounds.left,
          offset.dy + top,
          column.bounds.width,
          slotHeight,
        );
        canvas.drawRect(slotRect, paint);
      }
    }
  }

  void _paintAvailabilityWindows(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
  ) {
    if (_availabilityWindows.isEmpty || _dayGeometries.isEmpty) {
      return;
    }
    final Paint paint = Paint()
      ..color =
          calendarPrimaryColor.withValues(alpha: _availabilityWindowAlpha);
    for (final _DayColumnGeometry column in _dayGeometries) {
      for (final CalendarAvailabilityWindow window in _availabilityWindows) {
        _paintAvailabilityInterval(
          canvas,
          offset,
          metrics,
          column,
          window.start.value,
          window.end.value,
          paint,
        );
      }
    }
  }

  void _paintAvailabilityOverlays(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
  ) {
    if (_availabilityOverlays.isEmpty || _dayGeometries.isEmpty) {
      return;
    }
    for (final CalendarAvailabilityOverlay overlay in _availabilityOverlays) {
      for (final CalendarFreeBusyInterval interval in overlay.intervals) {
        final Paint paint = Paint()
          ..color = interval.type.baseColor
              .withValues(alpha: _availabilityOverlayAlpha);
        for (final _DayColumnGeometry column in _dayGeometries) {
          _paintAvailabilityInterval(
            canvas,
            offset,
            metrics,
            column,
            interval.start.value,
            interval.end.value,
            paint,
          );
        }
      }
    }
  }

  void _paintAvailabilityInterval(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
    _DayColumnGeometry column,
    DateTime start,
    DateTime end,
    Paint paint,
  ) {
    final DateTime dayStart = DateTime(
      column.date.year,
      column.date.month,
      column.date.day,
      startHour,
    );
    final DateTime dayEnd = DateTime(
      column.date.year,
      column.date.month,
      column.date.day,
      endHour,
    );
    final DateTime clippedStart = _maxDateTime(start, dayStart);
    final DateTime clippedEnd = _minDateTime(end, dayEnd);
    final DateTime resolvedEnd = _normalizeOverlayEnd(clippedStart, clippedEnd);
    if (!resolvedEnd.isAfter(clippedStart)) {
      return;
    }
    final double startMinutes =
        clippedStart.difference(dayStart).inMicroseconds /
            Duration.microsecondsPerMinute;
    final double endMinutes = resolvedEnd.difference(dayStart).inMicroseconds /
        Duration.microsecondsPerMinute;
    final double top = metrics.verticalOffsetForMinutes(startMinutes);
    final double height = math.max(_availabilityOverlayMinHeight,
        metrics.verticalOffsetForMinutes(endMinutes) - top);
    const double inset = _availabilityOverlayInset;
    final double width = math.max(
      _availabilityOverlayMinWidth,
      column.bounds.width - (inset * 2),
    );
    final Rect rect = Rect.fromLTWH(
      offset.dx + column.bounds.left + inset,
      offset.dy + top,
      width,
      height,
    );
    canvas.drawRect(rect, paint);
  }

  DateTime _normalizeOverlayEnd(DateTime start, DateTime candidate) {
    if (_isExactMidnight(candidate) && candidate.isAfter(start)) {
      return candidate.subtract(_availabilityOverlayEndEpsilon);
    }
    return candidate;
  }

  bool _isExactMidnight(DateTime value) =>
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;

  DateTime _maxDateTime(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  DateTime _minDateTime(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  void _paintGridLines(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
  ) {
    final double slotHeight = metrics.slotHeight;
    final int totalSlots = layoutTheme.visibleHourRows * metrics.slotsPerHour;
    final double startX = offset.dx + _timeColumnWidth;
    final double endX = offset.dx + size.width;

    final double hourStrokeWidth =
        math.max(1.0 / _devicePixelRatio, calendarBorderStroke);
    final double slotStrokeWidth =
        math.max(1.0 / _devicePixelRatio, calendarSubSlotBorderStroke);

    final Paint hourLinePaint = Paint()
      ..color = calendarBorderDarkColor
      ..strokeWidth = hourStrokeWidth;
    final Paint subSlotPaint = Paint()
      ..color = calendarBorderColor.withValues(alpha: 0.6)
      ..strokeWidth = slotStrokeWidth;

    for (int slot = 0; slot <= totalSlots; slot++) {
      final double dy = offset.dy + (slot * slotHeight);
      final double snappedDy =
          (dy * _devicePixelRatio).roundToDouble() / _devicePixelRatio;
      final bool isHourBoundary = slot % metrics.slotsPerHour == 0;
      final Paint paint = isHourBoundary ? hourLinePaint : subSlotPaint;
      canvas.drawLine(
          Offset(startX, snappedDy), Offset(endX, snappedDy), paint);
    }
  }

  void _paintVerticalDividers(Canvas canvas, Offset offset) {
    final Paint dividerPaint = Paint()
      ..color = calendarBorderDarkColor
      ..strokeWidth = calendarBorderStroke;
    final double top = offset.dy;
    final double bottom = offset.dy + size.height;
    // Time column divider.
    canvas.drawLine(
      Offset(offset.dx + _timeColumnWidth, top),
      Offset(offset.dx + _timeColumnWidth, bottom),
      dividerPaint,
    );
    for (int i = 0; i < _dayGeometries.length; i++) {
      final _DayColumnGeometry column = _dayGeometries[i];
      final double boundaryX = offset.dx + column.bounds.right;
      canvas.drawLine(
        Offset(boundaryX, top),
        Offset(boundaryX, bottom),
        dividerPaint,
      );
    }
  }

  void _paintTimeColumnLabels(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
  ) {
    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );
    const double padding = calendarInsetMd;
    final double labelRight = offset.dx + _timeColumnWidth - padding;
    final int totalSlots = layoutTheme.visibleHourRows * metrics.slotsPerHour;
    final Paint tickPaint = Paint()..color = calendarBorderDarkColor;

    for (int slot = 0; slot < totalSlots; slot++) {
      final int minutesFromStart = slot * metrics.minutesPerSlot;
      final int absoluteMinutes = (startHour * 60) + minutesFromStart;
      final int hour = absoluteMinutes ~/ 60;
      final int minute = absoluteMinutes % 60;
      final bool isHourMark = minute == 0;

      painter.text = TextSpan(
        text: isHourMark
            ? _formatHourLabel(hour)
            : minute.toString().padLeft(2, '0'),
        style: isHourMark
            ? calendarTimeLabelTextStyle
            : calendarMinorTimeLabelTextStyle,
      );
      painter.layout();
      final double slotTop = offset.dy + (slot * metrics.slotHeight);
      final double labelDy =
          slotTop + (metrics.slotHeight - painter.height) / 2;
      final double dx = labelRight - painter.width;
      painter.paint(canvas, Offset(dx, labelDy));

      final double tickY = slotTop;
      final double tickLength = isHourMark ? 12.0 : 8.0;
      tickPaint.strokeWidth = isHourMark ? 1.5 : 1.0;
      final double tickEndX = offset.dx + _timeColumnWidth - calendarInsetSm;
      final double tickStartX = tickEndX - tickLength;
      canvas.drawLine(
        Offset(tickStartX, tickY),
        Offset(tickEndX, tickY),
        tickPaint,
      );
    }
  }

  void _paintCurrentTimeIndicator(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
  ) {
    final DateTime now = DateTime.now();
    final _DayColumnGeometry? geometry = _geometryForDate(now);
    if (geometry == null) {
      return;
    }
    final int minutesFromStart =
        (now.hour * 60 + now.minute) - (startHour * 60);
    if (minutesFromStart < 0 || minutesFromStart > (endHour - startHour) * 60) {
      return;
    }

    final double pixelsPerMinute = metrics.slotHeight / metrics.minutesPerSlot;
    final double dy = offset.dy + (minutesFromStart * pixelsPerMinute);
    final Paint indicatorPaint = Paint()
      ..color = calendarPrimaryColor
      ..strokeWidth = 2.0;

    final double circleX = offset.dx + geometry.bounds.left + 4;
    final Offset circleCenter = Offset(circleX, dy);
    canvas.drawCircle(circleCenter, 4, indicatorPaint);
    canvas.drawLine(
      Offset(circleCenter.dx + 8, dy),
      Offset(offset.dx + geometry.bounds.right, dy),
      indicatorPaint,
    );
  }

  void _paintDragPreview(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
  ) {
    final DragPreview? preview = _dragPreview;
    if (preview == null || preview.duration <= Duration.zero) {
      return;
    }
    final _DragLayoutOverride? override =
        _resolveActiveDragLayoutOverride(metrics);
    if (override == null) {
      return;
    }

    final Rect previewRect = override.rect.shift(offset);
    if (previewRect.width <= 0 || previewRect.height <= 0) {
      return;
    }

    final RRect fillRect = RRect.fromRectAndRadius(
      previewRect.deflate(0.5),
      const Radius.circular(calendarBorderRadius),
    );
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = calendarPrimaryColor.withValues(
        alpha: calendarSlotPreviewOpacity,
      );
    canvas.drawRRect(fillRect, fillPaint);

    final RRect outlineRect = RRect.fromRectAndRadius(
      previewRect.deflate(0.5),
      const Radius.circular(calendarBorderRadius),
    );
    final Paint outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = calendarPrimaryColor.withValues(
        alpha: calendarSlotPreviewOpacity,
      );
    canvas.drawRRect(outlineRect, outlinePaint);

    final double anchorHeight =
        math.min(metrics.slotHeight, previewRect.height);
    final Rect anchorBounds = Rect.fromLTWH(
      previewRect.left + 1,
      previewRect.top + 1,
      math.max(0.0, previewRect.width - 2),
      anchorHeight,
    );
    final Paint anchorPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = calendarPrimaryColor.withValues(
        alpha: calendarSlotPreviewAnchorOpacity,
      );
    final RRect anchorRect = RRect.fromRectAndCorners(
      anchorBounds,
      topLeft: const Radius.circular(calendarBorderRadius - 1),
      topRight: const Radius.circular(calendarBorderRadius - 1),
      bottomLeft: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );
    canvas.drawRRect(anchorRect, anchorPaint);
  }

  void _paintHoverHighlight(
    Canvas canvas,
    Offset offset,
    CalendarLayoutMetrics metrics,
  ) {
    final DateTime? slot = _hoveredSlot;
    if (slot == null) {
      return;
    }
    if (_interactionController?.draggingTaskId != null ||
        _interactionController?.activeResizeInteraction != null ||
        _isDragInProgress) {
      return;
    }
    final _DayColumnGeometry? geometry = _geometryForDate(slot);
    if (geometry == null) {
      return;
    }
    final double slotHeight = metrics.slotHeight;
    if (slotHeight <= 0) {
      return;
    }
    final double top = _verticalOffsetForTime(slot, metrics);
    final double clampedTop = top.clamp(
      0.0,
      math.max(0.0, size.height - slotHeight),
    );
    final Rect rect = Rect.fromLTWH(
      offset.dx + geometry.bounds.left,
      offset.dy + clampedTop,
      geometry.bounds.width,
      slotHeight,
    );
    final Paint hoverPaint = Paint()
      ..color = calendarSlotHoverColor.withValues(alpha: 0.6);
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(1.0),
      const Radius.circular(4),
    );
    canvas.drawRRect(rrect, hoverPaint);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      return false;
    }
    final bool hitChild = hitTestChildren(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return hitChild || hitTestSelf(position);
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    super.handleEvent(event, entry);
    if (_isInTimeColumn(entry.localPosition)) {
      if (event is PointerDownEvent) {
        _activePointerId = null;
        _pointerDownLocal = null;
        _pointerDownSlot = null;
        _pointerDownHitTask = false;
        _pointerDownIsPrimary = false;
        _pointerDragSessionActive = false;
        _pointerDownScrollOffset = null;
      }
      return;
    }
    if (event is PointerDownEvent) {
      _pointerDragSessionActive = false;
      final bool isPrimary = _isPrimaryPointer(event);
      _pointerDownIsPrimary = isPrimary;
      if (!isPrimary) {
        _pointerDownLocal = null;
        _pointerDownSlot = null;
        _pointerDownHitTask = false;
        _pointerDownScrollOffset = null;
        return;
      }
      _activePointerId ??= event.pointer;
      if (_activePointerId == event.pointer) {
        _pointerDownLocal = entry.localPosition;
        _pointerDownSlot = slotForOffset(entry.localPosition);
        _pointerDownHitTask = containsTaskAt(entry.localPosition);
        _pointerDownScrollOffset = _currentScrollOffset();
      }
      return;
    }

    if (event.pointer != _activePointerId) {
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        onDragAutoScrollStop?.call();
      }
      return;
    }

    if (event is PointerMoveEvent) {
      _trackPointerMovement(entry.localPosition);
      if (_isDragInProgress) {
        _handlePointerDragUpdate(entry.localPosition, event.position);
      }
      return;
    }

    if (event is PointerUpEvent) {
      _handlePointerUp(entry.localPosition, event.position);
      return;
    }

    if (event is PointerCancelEvent) {
      _handlePointerCancel();
    }
  }

  bool _isPrimaryPointer(PointerDownEvent event) {
    if (event.kind == ui.PointerDeviceKind.mouse) {
      return event.buttons == kPrimaryButton;
    }
    return true;
  }

  CalendarTaskGeometry? geometryForTask(String taskId) =>
      _taskGeometries[taskId];

  Rect? localRectForTask(String taskId) => _taskGeometries[taskId]?.rect;

  Rect? globalRectForTask(String taskId) {
    final Rect? rect = localRectForTask(taskId);
    if (rect == null) {
      return null;
    }
    final Matrix4 transform = getTransformTo(null);
    final Float64List storage = Float64List.fromList(transform.storage);
    final double perspective = storage[15];
    if (perspective == 0 && storage[14] == 0) {
      return MatrixUtils.transformRect(transform, rect);
    }
    final Matrix4 copy = Matrix4.fromList(storage);
    copy
      ..setEntry(2, 0, 0.0)
      ..setEntry(2, 1, 0.0)
      ..setEntry(2, 3, 0.0)
      ..setEntry(3, 0, 0.0)
      ..setEntry(3, 1, 0.0)
      ..setEntry(3, 2, 0.0)
      ..setEntry(3, 3, 1.0);
    return MatrixUtils.transformRect(copy, rect);
  }

  bool containsTaskAt(Offset localPosition) {
    for (final CalendarTaskGeometry geometry in _taskGeometries.values) {
      if (geometry.rect.contains(localPosition)) {
        return true;
      }
    }
    return false;
  }

  bool _previewOverlapsScheduled(DateTime previewStart, Duration duration) {
    final DateTime previewEnd = previewStart.add(duration);
    final String? draggingId = _interactionController?.draggingTaskId;
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData as CalendarSurfaceParentData;
      final CalendarTask? task = parentData.task;
      if (task == null) {
        child = childAfter(child);
        continue;
      }
      if (draggingId != null && task.id == draggingId) {
        child = childAfter(child);
        continue;
      }
      final DateTime? taskStart = task.scheduledTime;
      if (taskStart == null) {
        child = childAfter(child);
        continue;
      }
      final Duration taskDuration = task.duration ?? const Duration(hours: 1);
      final DateTime taskEnd = taskStart.add(taskDuration);
      if (previewStart.isBefore(taskEnd) && previewEnd.isAfter(taskStart)) {
        return true;
      }
      child = childAfter(child);
    }
    return false;
  }

  Rect? columnBoundsForDate(DateTime date) => _geometryForDate(date)?.bounds;

  double? columnWidthForOffset(Offset localOffset) =>
      _geometryForOffset(localOffset)?.bounds.width;

  bool _isInTimeColumn(Offset localPosition) =>
      localPosition.dx <= _timeColumnWidth;

  Offset _clampLocalOffset(Offset localPosition) {
    final double effectiveWidth = size.width.isFinite && size.width > 0
        ? size.width
        : (_dayGeometries.isNotEmpty
            ? _dayGeometries.last.bounds.right
            : localPosition.dx);
    final double effectiveHeight = size.height.isFinite && size.height > 0
        ? size.height
        : (_dayGeometries.isNotEmpty
            ? _dayGeometries.last.bounds.bottom
            : localPosition.dy);
    final double dx = localPosition.dx.clamp(0.0, effectiveWidth);
    final double dy = localPosition.dy.clamp(0.0, effectiveHeight);
    return Offset(dx, dy);
  }

  DateTime? slotForOffset(Offset localOffset) {
    if (_metrics == null || _dayGeometries.isEmpty) {
      return null;
    }
    final CalendarLayoutMetrics resolvedMetrics = _metrics!;
    final double slotHeight = resolvedMetrics.slotHeight;
    if (slotHeight <= 0) {
      return null;
    }
    final double rawSlotsFromStart = localOffset.dy / slotHeight;
    final int slotIndex = rawSlotsFromStart.floor();
    final int minutesFromStart = slotIndex * resolvedMetrics.minutesPerSlot;
    final int maxMinutes = (endHour - startHour) * 60;
    final int clampedMinutes = minutesFromStart.clamp(0, maxMinutes);
    final int totalMinutes = startHour * 60 + clampedMinutes;
    final int hour = totalMinutes ~/ 60;
    final int minute = totalMinutes % 60;

    _DayColumnGeometry? geometry;
    for (final _DayColumnGeometry candidate in _dayGeometries) {
      if (_rectContainsInclusive(candidate.bounds, localOffset)) {
        geometry = candidate;
        break;
      }
    }
    geometry ??= _dayGeometries.isEmpty ? null : _dayGeometries.first;
    if (geometry == null) {
      return null;
    }

    return DateTime(
      geometry.date.year,
      geometry.date.month,
      geometry.date.day,
      hour,
      minute,
    );
  }

  DragPreview? previewForGlobalPosition(Offset globalPosition) {
    final TaskInteractionController? controller = _interactionController;
    final CalendarTask? draggingTask = controller?.draggingTaskSnapshot;
    final CalendarLayoutMetrics? metrics = _metrics;
    if (controller == null || draggingTask == null || metrics == null) {
      return null;
    }

    final Offset localPosition =
        _clampLocalOffset(globalToLocal(globalPosition));
    if (_isInTimeColumn(localPosition)) {
      return null;
    }

    final _DayColumnGeometry? columnGeometry =
        _geometryForOffset(localPosition);
    if (columnGeometry == null) {
      return null;
    }

    final _PreviewMetrics? previewMetrics = _computePreviewMetricsForPointer(
      localPosition: localPosition,
      globalPosition: globalPosition,
      metrics: metrics,
      controller: controller,
      draggingTask: draggingTask,
      columnGeometry: columnGeometry,
    );
    if (previewMetrics == null) {
      return null;
    }

    return DragPreview(
      start: previewMetrics.start,
      duration: previewMetrics.duration,
    );
  }

  Duration _resolvePreviewDuration(
    TaskInteractionController controller,
    CalendarTask task,
  ) {
    final Duration? explicitDuration =
        controller.draggingTaskSnapshot?.effectiveDuration ??
            task.effectiveDuration;
    if (explicitDuration != null && explicitDuration.inMinutes > 0) {
      return explicitDuration;
    }

    final bool scheduledDrag = controller.dragOriginSlot != null ||
        controller.dragStartScheduledTime != null ||
        controller.draggingTaskSnapshot?.scheduledTime != null;
    if (scheduledDrag) {
      final CalendarLayoutMetrics? metrics = _metrics;
      final double? height = controller.draggingTaskHeight;
      if (metrics != null &&
          height != null &&
          height.isFinite &&
          height > 0 &&
          metrics.slotHeight > 0) {
        final double slots = height / metrics.slotHeight;
        final int minutes = math.max<int>(
          metrics.minutesPerSlot,
          (slots * metrics.minutesPerSlot).round(),
        );
        if (minutes > 0) {
          return Duration(minutes: minutes);
        }
      }
    }

    return controller.draggingTaskSnapshot?.duration ??
        task.duration ??
        const Duration(hours: 1);
  }

  double _pointerOffsetForDrag(TaskInteractionController controller) {
    final double? stored = controller.dragPointerOffsetFromTop;
    if (stored != null && stored.isFinite && stored >= 0) {
      return stored;
    }
    final double? height = controller.draggingTaskHeight;
    if (height != null && height.isFinite && height > 0) {
      final double fallback = height / 2;
      controller.setDragPointerOffsetFromTop(fallback, notify: false);
      return fallback;
    }
    final CalendarLayoutMetrics? metrics = _metrics;
    if (metrics != null && metrics.slotHeight > 0) {
      final double fallback = metrics.slotHeight / 2;
      controller.setDragPointerOffsetFromTop(fallback, notify: false);
      return fallback;
    }
    return 0.0;
  }

  DateTime? _computePreviewStartForHover(
    DateTime targetDate,
    Offset globalPosition,
  ) {
    final TaskInteractionController? controller = _interactionController;
    final CalendarTask? task = controller?.draggingTaskSnapshot;
    if (controller == null || task == null) {
      return null;
    }
    final DateTime? computed =
        _computePreviewStartFromGlobalOffset(globalPosition, targetDate);
    if (computed != null) {
      final Duration duration = _resolvePreviewDuration(controller, task);
      final DateTime snapped = _snapToStep(computed);
      return _clampPreviewStart(
        snapped,
        targetDate,
        duration,
        snapToStep: true,
      );
    }
    return null;
  }

  DateTime? _computePreviewStartFromGlobalOffset(
    Offset globalPosition,
    DateTime targetDate,
  ) {
    final TaskInteractionController? controller = _interactionController;
    if (controller == null || _metrics == null) {
      return null;
    }
    final DateTime? origin = controller.dragOriginSlot;
    final DateTime? dragStartTime = controller.dragStartScheduledTime;
    final double? dragTopGlobal = controller.dragStartGlobalTop;
    if (origin == null || dragTopGlobal == null) {
      return null;
    }

    final double pointerOffset = controller.dragPointerOffsetFromTop ??
        _computePointerTopOffset(globalPosition.dy);
    final double pointerTopGlobal = globalPosition.dy - pointerOffset;
    final double deltaPixels = pointerTopGlobal - dragTopGlobal;
    final double pixelsPerMinute = _metrics!.hourHeight / 60.0;
    if (pixelsPerMinute == 0) {
      return dragStartTime ?? origin;
    }

    final DateTime baseTime = dragStartTime ?? origin;
    final DateTime baseDateTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      baseTime.hour,
      baseTime.minute,
      baseTime.second,
      baseTime.millisecond,
      baseTime.microsecond,
    );

    final double minutesDelta = deltaPixels / pixelsPerMinute;
    final Duration delta = Duration(
      microseconds:
          (minutesDelta * 60 * Duration.microsecondsPerSecond).round(),
    );

    final DateTime candidate = baseDateTime.add(delta);
    return candidate;
  }

  double _computePointerTopOffset(double pointerGlobalDy) {
    final TaskInteractionController? controller = _interactionController;
    if (controller == null) {
      return 0;
    }
    final double? stored = controller.dragPointerOffsetFromTop;
    if (stored != null) {
      return stored;
    }
    final double referenceTop =
        controller.dragStartGlobalTop ?? pointerGlobalDy;
    double offset = pointerGlobalDy - referenceTop;
    final double height = controller.draggingTaskHeight ?? 0;
    if (height > 0) {
      offset = offset.clamp(0.0, height);
    } else {
      offset = math.max(0.0, offset);
    }
    controller.setDragPointerOffsetFromTop(offset);
    return offset;
  }

  DateTime _clampPreviewStart(
    DateTime candidate,
    DateTime targetDate,
    Duration previewDuration, {
    required bool snapToStep,
  }) {
    final DateTime dayStart = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      startHour,
    );
    final DateTime dayEnd = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      endHour,
    );

    if (candidate.isBefore(dayStart)) {
      return dayStart;
    }

    DateTime latestStart;
    if (snapToStep) {
      final int stepMinutes = minutesPerStep <= 0 ? 15 : minutesPerStep;
      latestStart = dayEnd.subtract(Duration(minutes: stepMinutes));
    } else {
      latestStart = dayEnd.subtract(previewDuration);
    }
    if (latestStart.isBefore(dayStart)) {
      latestStart = dayStart;
    }
    if (candidate.isAfter(latestStart)) {
      return latestStart;
    }
    return candidate;
  }

  DateTime _snapToStep(DateTime timestamp) {
    final int stepMinutes = minutesPerStep <= 0 ? 15 : minutesPerStep;
    final int totalMinutes = (timestamp.hour * 60) + timestamp.minute;
    final int snappedMinutes =
        (totalMinutes / stepMinutes).round() * stepMinutes;
    final int snappedHour = snappedMinutes ~/ 60;
    final int snappedMinute = snappedMinutes % 60;
    return DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      snappedHour,
      snappedMinute,
    );
  }

  void handleDragPayloadUpdate(
    CalendarDragPayload payload,
    Offset dragTargetOffset,
  ) {
    final Offset pointerGlobal =
        _pointerGlobalForPayloadOnly(payload, dragTargetOffset);
    _ensureExternalDragInitialized(
      payload,
      dragTargetOffset,
      pointerGlobal,
    );
    _handleExternalDragUpdate(payload, dragTargetOffset);
  }

  void handleDragPayloadDrop(
    CalendarDragPayload payload,
    Offset dragTargetOffset,
  ) {
    final Offset pointerGlobal =
        _pointerGlobalForPayloadOnly(payload, dragTargetOffset);
    _ensureExternalDragInitialized(
      payload,
      dragTargetOffset,
      pointerGlobal,
    );
    _handleExternalDragDrop(payload, dragTargetOffset);
    _externalDragTaskId = null;
  }

  void handleDragPayloadExit(CalendarDragPayload payload) {
    _handleExternalDragExit(payload.task.id);
  }

  void _handleExternalDragUpdate(
    CalendarDragPayload payload,
    Offset dragTargetOffset,
  ) {
    final TaskInteractionController? controller = _interactionController;
    final Offset pointerGlobal = controller == null
        ? _pointerGlobalForPayloadOnly(payload, dragTargetOffset)
        : _pointerGlobalForDragTarget(
            payload: payload,
            dragTargetOffset: dragTargetOffset,
            controller: controller,
          );
    final Offset local = _clampLocalOffset(globalToLocal(pointerGlobal));
    _handlePointerDragUpdate(local, pointerGlobal);
    if (controller != null && !controller.dragHasMoved) {
      controller.markDragMoved();
    }
  }

  void _handleExternalDragExit([String? taskId]) {
    if (_externalDragTaskId != null &&
        (taskId == null || _externalDragTaskId == taskId)) {
      _interactionController?.clearPreview();
      _interactionController?.resetFeedbackHint();
    }
    onDragExit?.call();
    onDragAutoScrollStop?.call();
    _updateHoverTask(null);
  }

  void _handleExternalDragDrop(
    CalendarDragPayload payload,
    Offset dragTargetOffset,
  ) {
    final TaskInteractionController? controller = _interactionController;
    final CalendarTask? draggingTask = controller?.draggingTaskSnapshot;
    final Offset pointerGlobal = controller == null
        ? _pointerGlobalForPayloadOnly(payload, dragTargetOffset)
        : _pointerGlobalForDragTarget(
            payload: payload,
            dragTargetOffset: dragTargetOffset,
            controller: controller,
          );
    final Offset local = _clampLocalOffset(globalToLocal(pointerGlobal));
    DateTime? dropStart;
    final CalendarLayoutMetrics? metrics = _metrics;
    _DayColumnGeometry? columnGeometry;
    if (metrics != null && !_isInTimeColumn(local)) {
      columnGeometry = _geometryForOffset(local);
      columnGeometry ??= _geometryForHorizontal(local.dx);
    } else {
      columnGeometry = null;
    }
    if (controller != null) {
      controller.updateDragPointerGlobalPosition(pointerGlobal);
    }
    if (controller != null &&
        draggingTask != null &&
        metrics != null &&
        columnGeometry != null) {
      final _PreviewMetrics? previewMetrics = _computePreviewMetricsForPointer(
        localPosition: local,
        globalPosition: pointerGlobal,
        metrics: metrics,
        controller: controller,
        draggingTask: draggingTask,
        columnGeometry: columnGeometry,
      );
      dropStart = previewMetrics?.start;
    }
    if (dropStart != null) {
      onDragEnd?.call(
        CalendarSurfaceDragEndDetails(
          slotStart: dropStart,
          globalPosition: pointerGlobal,
        ),
      );
    } else {
      onDragExit?.call();
    }
    onDragAutoScrollStop?.call();
    _updateHoverTask(null);
  }

  void _ensureExternalDragInitialized(
    CalendarDragPayload payload,
    Offset dragTargetOffset,
    Offset pointerGlobal,
  ) {
    final TaskInteractionController? controller = _interactionController;
    if (controller == null) {
      return;
    }
    if (controller.draggingTaskId != null &&
        controller.draggingTaskId == payload.task.id) {
      return;
    }
    final CalendarLayoutMetrics? metrics = _metrics;
    Size feedbackSize = payload.sourceBounds?.size ??
        Size(
          controller.draggingTaskWidth ?? 0,
          controller.draggingTaskHeight ?? metrics?.slotHeight ?? 0,
        );
    if (payload.originSlot == null) {
      final double slotHeight = metrics?.slotHeight ?? 0;
      final Duration duration = payload.snapshot.duration ??
          payload.task.duration ??
          const Duration(hours: 1);
      double resolvedHeight =
          feedbackSize.height.isFinite && feedbackSize.height > 0
              ? feedbackSize.height
              : 0.0;
      if (metrics != null) {
        final double durationHeight = metrics.heightForDuration(duration);
        if (durationHeight.isFinite && durationHeight > 0) {
          resolvedHeight = math.max(resolvedHeight, durationHeight);
        }
      }
      if (slotHeight > 0) {
        resolvedHeight = math.max(resolvedHeight, slotHeight);
      }
      if (resolvedHeight > 0) {
        feedbackSize = Size(feedbackSize.width, resolvedHeight);
      }
    }
    final Offset pointerOffset = _resolvePointerOffset(
      controller: controller,
      payload: payload,
      feedbackSize: feedbackSize,
      globalPosition: pointerGlobal,
    );
    controller.beginExternalDrag(
      task: payload.task,
      snapshot: payload.snapshot,
      pointerOffset: pointerOffset,
      feedbackSize: feedbackSize,
      globalPosition: dragTargetOffset,
    );
    controller.suppressSurfaceTapOnce();
    _externalDragTaskId = payload.task.id;
  }

  Offset _resolvePointerOffset({
    required TaskInteractionController controller,
    required CalendarDragPayload payload,
    required Size feedbackSize,
    required Offset globalPosition,
  }) {
    final double width = feedbackSize.width;
    double dx;
    if (payload.pointerNormalizedX != null && width.isFinite && width > 0) {
      dx = (width * payload.pointerNormalizedX!).clamp(0.0, width);
    } else if (payload.sourceBounds != null) {
      dx = globalPosition.dx - payload.sourceBounds!.left;
      if (width.isFinite && width > 0) {
        dx = dx.clamp(0.0, width);
      }
    } else {
      dx = controller.dragAnchorDx ?? 0.0;
    }

    final double height = feedbackSize.height;
    double? dy = payload.pointerOffsetY;
    if (dy == null || !dy.isFinite) {
      dy = controller.dragPointerOffsetFromTop;
    }
    final bool dyInvalid = dy == null || !dy.isFinite;
    if (dyInvalid) {
      dy = (height.isFinite && height > 0) ? height / 2 : 0.0;
    }
    if (height.isFinite && height > 0) {
      dy = dy.clamp(0.0, height);
    } else if (dy < 0) {
      dy = 0.0;
    }
    return Offset(dx, dy);
  }

  Color _slotBackgroundColor({
    required bool isToday,
    required int hour,
    required bool isEvenSlot,
  }) {
    if (isToday) {
      final double targetAlpha = isEvenSlot
          ? calendarTodaySlotLightOpacity
          : calendarTodaySlotDarkOpacity;
      return calendarPrimaryColor.withValues(alpha: targetAlpha);
    }
    if (hour.isEven) {
      return isEvenSlot ? calendarStripedSlotColor : calendarBackgroundColor;
    }
    return isEvenSlot ? calendarBackgroundColor : calendarStripedSlotColor;
  }

  bool _slotsMatch(DateTime? a, DateTime? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return a == null && b == null;
    }
    return a.isAtSameMomentAs(b);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatHourLabel(int hour) {
    final int normalized = hour % 24;
    if (normalized == 0) {
      return '12 AM';
    }
    if (normalized < 12) {
      return '$normalized AM';
    }
    if (normalized == 12) {
      return '12 PM';
    }
    return '${normalized - 12} PM';
  }

  double _verticalOffsetForTime(
    DateTime timestamp,
    CalendarLayoutMetrics metrics,
  ) {
    final double totalMinutes = (timestamp.hour * 60 + timestamp.minute) +
        (timestamp.second / 60.0) +
        (timestamp.millisecond / 60000.0) +
        (timestamp.microsecond / 60000000.0);
    final double minutesFromStart = totalMinutes - (startHour * 60).toDouble();
    final double clamped = minutesFromStart.clamp(0.0, 24.0 * 60.0);
    return metrics.verticalOffsetForMinutes(clamped);
  }
}
