import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/widgets.dart';

import '../../models/calendar_task.dart';
import '../controllers/task_interaction_controller.dart';
import '../models/calendar_drag_payload.dart';
import 'calendar_task_geometry.dart';

typedef CalendarTaskSnapshotBuilder = CalendarTask Function();
typedef CalendarTaskGlobalRectProvider = Rect? Function(String taskId);

/// Wraps a task tile with Flutter's [Draggable] infrastructure.
class CalendarTaskDraggable extends StatefulWidget {
  const CalendarTaskDraggable({
    super.key,
    required this.task,
    required this.geometry,
    required this.globalRectProvider,
    required this.interactionController,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnded,
    required this.child,
    required this.feedbackBuilder,
    this.enabled = true,
    this.snapshotBuilder,
    this.childWhenDragging,
    this.requiresLongPress = false,
    this.longPressDelay,
  });

  final CalendarTask task;
  final CalendarTaskGeometry geometry;
  final CalendarTaskGlobalRectProvider globalRectProvider;
  final TaskInteractionController interactionController;
  final void Function(CalendarTask task, Rect bounds) onDragStarted;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final ValueChanged<CalendarTask> onDragEnded;
  final CalendarTaskSnapshotBuilder? snapshotBuilder;
  final Widget Function(
    BuildContext context,
    CalendarTask task,
    CalendarTaskGeometry geometry,
  ) feedbackBuilder;
  final Widget child;
  final Widget? childWhenDragging;
  final bool enabled;
  final bool requiresLongPress;
  final Duration? longPressDelay;

  @override
  State<CalendarTaskDraggable> createState() => _CalendarTaskDraggableState();
}

class _CalendarTaskDraggableState extends State<CalendarTaskDraggable> {
  static const double _resizeHandleExtent = 12.0;

  Offset? _lastPointerLocal;
  Offset? _lastPointerGlobal;
  double? _pointerNormalized;
  double? _pointerOffsetY;
  Rect? _sourceBounds;
  bool _suppressDrag = false;
  String? _lastResizeTaskId;
  late final VoidCallback _controllerListener;
  int? _trackedPointerId;
  bool _dragSessionActive = false;
  DateTime? _lastDragUpdateTime;
  static const Duration _syntheticUpdateDelay = Duration(milliseconds: 24);

  TaskInteractionController get _controller => widget.interactionController;
  CalendarTaskGeometry get _geometry => widget.geometry;

  bool get _isResizing =>
      _controller.activeResizeInteraction?.taskId == widget.task.id;

  @override
  void initState() {
    super.initState();
    _controllerListener = () {
      final String? resizeTaskId = _controller.activeResizeInteraction?.taskId;
      if (!mounted || _lastResizeTaskId == resizeTaskId) {
        return;
      }
      _lastResizeTaskId = resizeTaskId;
      if (mounted) {
        setState(() {});
      }
    };
    _lastResizeTaskId = _controller.activeResizeInteraction?.taskId;
    _controller.addListener(_controllerListener);
  }

  @override
  void didUpdateWidget(covariant CalendarTaskDraggable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactionController != widget.interactionController) {
      oldWidget.interactionController.removeListener(_controllerListener);
      widget.interactionController.addListener(_controllerListener);
    }
    if (_geometry != CalendarTaskGeometry.empty && _sourceBounds == null) {
      _sourceBounds = _resolveGlobalBounds();
    }
    _lastResizeTaskId = _controller.activeResizeInteraction?.taskId;
  }

  @override
  void dispose() {
    _stopPointerTracking();
    widget.interactionController.removeListener(_controllerListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final bool canDrag = widget.enabled && !_suppressDrag && !_isResizing;
    final CalendarDragPayload payload = _dragPayload();

    final Widget interactiveChild = Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );

    if (widget.requiresLongPress) {
      return LongPressDraggable<CalendarDragPayload>(
        data: payload,
        dragAnchorStrategy: _dragAnchorStrategy,
        maxSimultaneousDrags: canDrag ? 1 : 0,
        feedback: widget.feedbackBuilder(context, widget.task, _geometry),
        childWhenDragging: widget.childWhenDragging ?? widget.child,
        onDragStarted: _handleDragStarted,
        onDragUpdate: _handleDragUpdate,
        onDragEnd: (details) => _handleDragFinished(cancelled: false),
        onDraggableCanceled: (_, __) => _handleDragFinished(cancelled: true),
        delay: widget.longPressDelay ?? kLongPressTimeout,
        child: interactiveChild,
      );
    }

    return Draggable<CalendarDragPayload>(
      data: payload,
      dragAnchorStrategy: _dragAnchorStrategy,
      maxSimultaneousDrags: canDrag ? 1 : 0,
      feedback: widget.feedbackBuilder(context, widget.task, _geometry),
      childWhenDragging: widget.childWhenDragging ?? widget.child,
      onDragStarted: _handleDragStarted,
      onDragUpdate: _handleDragUpdate,
      onDragEnd: (details) => _handleDragFinished(cancelled: false),
      onDraggableCanceled: (_, __) => _handleDragFinished(cancelled: true),
      child: interactiveChild,
    );
  }

  Offset _dragAnchorStrategy(
    Draggable<Object?> draggable,
    BuildContext context,
    Offset position,
  ) {
    final Offset? anchor = _lastPointerLocal;
    final RenderBox? renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null || !renderObject.hasSize) {
      return anchor ?? Offset.zero;
    }
    final Size size = renderObject.size;
    if (anchor == null) {
      return Offset(size.width / 2, size.height / 2);
    }
    final double dx = math.min(math.max(anchor.dx, 0.0), size.width);
    final double dy = math.min(math.max(anchor.dy, 0.0), size.height);
    return Offset(dx, dy);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) {
      return;
    }
    _stopPointerTracking();
    final Offset local = event.localPosition;
    final CalendarTaskGeometry geometry = _geometry;
    final Size size = geometry.rect.size;
    final bool suppressDrag = _isPointerOverResizeHandle(local, size);

    double width = size.width.isFinite && size.width > 0
        ? size.width
        : geometry.rect.width;
    double height = size.height.isFinite && size.height > 0
        ? size.height
        : geometry.rect.height;
    if (!width.isFinite || width <= 0) {
      width = 0;
    }
    if (!height.isFinite || height <= 0) {
      height = 0;
    }

    double anchorLocalX = local.dx;
    double anchorLocalY = local.dy;
    if (width > 0) {
      anchorLocalX = math.min(math.max(anchorLocalX, 0.0), width);
    }
    if (height > 0) {
      anchorLocalY = math.min(math.max(anchorLocalY, 0.0), height);
    }
    final Offset anchorLocal = Offset(anchorLocalX, anchorLocalY);
    final Offset fallbackTopLeft = event.position - anchorLocal;
    final Rect? centeredBounds = width > 0 && height > 0
        ? Rect.fromLTWH(fallbackTopLeft.dx, fallbackTopLeft.dy, width, height)
        : null;
    final Rect? resolvedBounds = centeredBounds ??
        _resolveGlobalBounds(fallbackTopLeft: fallbackTopLeft);

    double normalizedX =
        width > 0 && anchorLocal.dx.isFinite ? anchorLocal.dx / width : 0.5;
    if (!normalizedX.isFinite) {
      normalizedX = 0.5;
    }
    normalizedX = math.min(math.max(normalizedX, 0.0), 1.0);
    double pointerOffsetY = anchorLocal.dy;
    if (!pointerOffsetY.isFinite || pointerOffsetY < 0) {
      pointerOffsetY = 0.0;
    } else if (height > 0 && pointerOffsetY > height) {
      pointerOffsetY = height;
    }

    setState(() {
      _suppressDrag = suppressDrag;
      _lastPointerLocal = anchorLocal;
      _lastPointerGlobal = event.position;
      _pointerNormalized = normalizedX;
      _pointerOffsetY = pointerOffsetY;
      _sourceBounds = resolvedBounds;
    });
    _trackedPointerId = event.pointer;
    _startPointerTracking();
    widget.interactionController
        .setDragPointerOffsetFromTop(pointerOffsetY, notify: false);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_suppressDrag) {
      setState(() {
        _suppressDrag = false;
      });
    }
    if (!_dragSessionActive && _trackedPointerId == event.pointer) {
      _stopPointerTracking();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_suppressDrag) {
      setState(() {
        _suppressDrag = false;
      });
    }
    if (!_dragSessionActive && _trackedPointerId == event.pointer) {
      _stopPointerTracking();
    }
  }

  void _handleDragStarted() {
    _dragSessionActive = true;
    _lastDragUpdateTime = DateTime.now();
    widget.interactionController.suppressSurfaceTapOnce();
    final Rect? bounds = _sourceBounds ?? _resolveGlobalBounds();
    if (bounds != null) {
      widget.onDragStarted(widget.task, bounds);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _lastDragUpdateTime = DateTime.now();
    widget.onDragUpdate?.call(details);
  }

  void _handleDragFinished({required bool cancelled}) {
    if (_suppressDrag) {
      setState(() {
        _suppressDrag = false;
      });
    }
    _dragSessionActive = false;
    _lastDragUpdateTime = null;
    widget.onDragEnded(widget.task);
    _stopPointerTracking();
  }

  bool _isPointerOverResizeHandle(Offset local, Size size) {
    if (!size.isFinite) {
      return false;
    }
    final double height = size.height;
    if (height <= 0) {
      return false;
    }
    return local.dy <= _resizeHandleExtent ||
        (height - local.dy) <= _resizeHandleExtent;
  }

  Rect? _resolveGlobalBounds({Offset? fallbackTopLeft}) {
    final Rect? fromController = widget.globalRectProvider(widget.task.id);
    if (fromController != null) {
      return fromController;
    }
    final Size size = _geometry.rect.size;
    if (fallbackTopLeft != null) {
      return fallbackTopLeft & size;
    }
    if (_lastPointerGlobal != null && _lastPointerLocal != null) {
      final Offset topLeft = _lastPointerGlobal! - _lastPointerLocal!;
      return topLeft & size;
    }
    return null;
  }

  CalendarDragPayload _dragPayload() {
    final Rect? bounds = _sourceBounds ?? _resolveGlobalBounds();
    final double pointerNormalized =
        (_pointerNormalized ?? 0.5).clamp(0.0, 1.0);
    final double pointerOffsetY = _pointerOffsetY ??
        (_geometry.rect.height.isFinite && _geometry.rect.height > 0
            ? _geometry.rect.height / 2
            : 0.0);
    final CalendarTask snapshot =
        widget.snapshotBuilder?.call() ?? widget.task.copyWith();

    return CalendarDragPayload(
      task: widget.task,
      snapshot: snapshot,
      sourceBounds: bounds,
      pointerNormalizedX: pointerNormalized,
      pointerOffsetY: pointerOffsetY,
      originSlot: widget.task.scheduledTime,
      pickupScheduledTime: widget.task.scheduledTime,
    );
  }

  void _startPointerTracking() {
    final int? pointerId = _trackedPointerId;
    if (pointerId == null) {
      return;
    }
    RendererBinding.instance.pointerRouter.addRoute(
      pointerId,
      _handlePointerRoute,
    );
  }

  void _handlePointerRoute(PointerEvent event) {
    if (event.pointer != _trackedPointerId) {
      return;
    }
    if (_dragSessionActive && event is PointerMoveEvent) {
      _lastPointerGlobal = event.position;
      final DateTime now = DateTime.now();
      final DateTime? lastUpdate = _lastDragUpdateTime;
      if (lastUpdate == null ||
          now.difference(lastUpdate) >= _syntheticUpdateDelay) {
        final DragUpdateDetails syntheticDetails = DragUpdateDetails(
          sourceTimeStamp: event.timeStamp,
          delta: event.delta,
          primaryDelta: event.delta.dy,
          globalPosition: event.position,
        );
        _handleDragUpdate(syntheticDetails);
      }
    }
    if (!_dragSessionActive &&
        (event is PointerUpEvent || event is PointerCancelEvent)) {
      _stopPointerTracking();
    }
  }

  void _stopPointerTracking() {
    final int? pointerId = _trackedPointerId;
    if (pointerId != null) {
      RendererBinding.instance.pointerRouter.removeRoute(
        pointerId,
        _handlePointerRoute,
      );
    }
    _trackedPointerId = null;
  }
}
