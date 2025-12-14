import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show BoxHitTestResult, HitTestEntry, RenderMetaData, RendererBinding;
import 'package:flutter/widgets.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/models/calendar_drag_payload.dart';
import 'calendar_drag_exclude.dart';

class CalendarSidebarDraggable extends StatefulWidget {
  const CalendarSidebarDraggable({
    super.key,
    required this.task,
    required this.child,
    required this.feedback,
    required this.childWhenDragging,
    this.onDragSessionStarted,
    this.onDragSessionEnded,
    this.onDragGlobalPositionChanged,
    this.requiresLongPress = false,
  });

  final CalendarTask task;
  final Widget child;
  final Widget feedback;
  final Widget childWhenDragging;
  final VoidCallback? onDragSessionStarted;
  final VoidCallback? onDragSessionEnded;
  final ValueChanged<Offset>? onDragGlobalPositionChanged;
  final bool requiresLongPress;

  @override
  State<CalendarSidebarDraggable> createState() =>
      _CalendarSidebarDraggableState();
}

class _CalendarSidebarDraggableState extends State<CalendarSidebarDraggable> {
  bool _dragSessionActive = false;
  bool _suppressDrag = false;
  Rect? _sourceBounds;
  Size _childSize = Size.zero;
  double? _pointerNormalized;
  double? _pointerOffsetY;
  int? _activePointerId;
  Offset? _trackedPointer;

  bool _isDragExcluded(Offset localPosition) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      return false;
    }
    final BoxHitTestResult result = BoxHitTestResult();
    box.hitTest(result, position: localPosition);
    for (final HitTestEntry entry in result.path) {
      final Object target = entry.target;
      if (target is RenderMetaData &&
          target.metaData == CalendarDragExclude.marker) {
        return true;
      }
    }
    return false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_dragSessionActive) {
      return;
    }

    final bool shouldSuppress = _isDragExcluded(event.localPosition);
    if (shouldSuppress != _suppressDrag) {
      if (!mounted) {
        return;
      }
      setState(() => _suppressDrag = shouldSuppress);
    }
    if (shouldSuppress) {
      return;
    }

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Size size = box?.size ?? Size.zero;
    final double width = size.width.isFinite ? size.width : 0.0;
    final double height = size.height.isFinite ? size.height : 0.0;
    double localX = event.localPosition.dx;
    double localY = event.localPosition.dy;
    if (width > 0) {
      localX = localX.clamp(0.0, width);
    }
    if (height > 0) {
      localY = localY.clamp(0.0, height);
    }
    final Offset anchorLocal = Offset(localX, localY);
    final double centerDx = width > 0 ? width / 2 : anchorLocal.dx;
    final double centerDy = height > 0 ? height / 2 : anchorLocal.dy;
    final Offset anchorForFeedback = Offset(
      centerDx.isFinite ? centerDx : 0.0,
      centerDy.isFinite ? centerDy : 0.0,
    );
    final Offset globalTopLeft = event.position - anchorForFeedback;
    double normalized = 0.5;
    if (width > 0 && anchorForFeedback.dx.isFinite && width.isFinite) {
      normalized = (anchorForFeedback.dx / width).clamp(0.0, 1.0);
    }
    final double feedbackAnchorNormalized = normalized;
    final double feedbackAnchorDy = anchorForFeedback.dy.isFinite
        ? anchorForFeedback.dy
        : (height.isFinite && height > 0 ? height / 2 : 0.0);
    setState(() {
      _childSize = size;
      _sourceBounds = Rect.fromLTWH(
        globalTopLeft.dx,
        globalTopLeft.dy,
        size.width,
        size.height,
      );
      _pointerNormalized = feedbackAnchorNormalized;
      _pointerOffsetY = feedbackAnchorDy;
    });
    _activePointerId = event.pointer;
    _trackedPointer = event.position;
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    if (_dragSessionActive) {
      return;
    }
    if (_activePointerId == event.pointer) {
      _activePointerId = null;
      _trackedPointer = null;
    }
    if (_suppressDrag) {
      if (mounted) {
        setState(() => _suppressDrag = false);
      } else {
        _suppressDrag = false;
      }
    }
  }

  CalendarDragPayload _dragPayload() {
    final Rect? bounds = _sourceBounds;
    final double pointerNormalized =
        (_pointerNormalized ?? 0.5).clamp(0.0, 1.0);
    final double pointerOffsetY = _pointerOffsetY ??
        (_childSize.height.isFinite && _childSize.height > 0
            ? _childSize.height / 2
            : 0.0);

    return CalendarDragPayload(
      task: widget.task,
      snapshot: widget.task.copyWith(),
      sourceBounds: bounds,
      pointerNormalizedX: pointerNormalized,
      pointerOffsetY: pointerOffsetY,
      originSlot: null,
      pickupScheduledTime: widget.task.scheduledTime,
    );
  }

  void _resetCachedPointer() {
    _pointerNormalized = null;
    _pointerOffsetY = null;
    _sourceBounds = null;
    _childSize = Size.zero;
    _trackedPointer = null;
  }

  void _handleDragStarted() {
    if (_dragSessionActive) {
      return;
    }
    _dragSessionActive = true;
    _startPointerTracking();
    widget.onDragSessionStarted?.call();
    final Offset? pointer = _trackedPointer;
    if (pointer != null) {
      widget.onDragGlobalPositionChanged?.call(pointer);
    }
  }

  void _handleDragUpdated(DragUpdateDetails details) {
    if (_activePointerId == null) {
      _trackedPointer = details.globalPosition;
      widget.onDragGlobalPositionChanged?.call(details.globalPosition);
    }
  }

  void _handleDragFinished({required bool cancelled}) {
    if (_dragSessionActive) {
      _dragSessionActive = false;
      widget.onDragSessionEnded?.call();
    }
    _stopPointerTracking();
    _resetCachedPointer();
    _activePointerId = null;
  }

  void _startPointerTracking() {
    final int? pointerId = _activePointerId;
    if (pointerId == null) {
      return;
    }
    RendererBinding.instance.pointerRouter.addRoute(
      pointerId,
      _handlePointerRoute,
    );
  }

  void _handlePointerRoute(PointerEvent event) {
    if (event.pointer != _activePointerId) {
      return;
    }
    if (event is PointerMoveEvent) {
      _trackedPointer = event.position;
      widget.onDragGlobalPositionChanged?.call(event.position);
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _stopPointerTracking();
    }
  }

  void _stopPointerTracking() {
    final int? pointerId = _activePointerId;
    if (pointerId != null) {
      RendererBinding.instance.pointerRouter.removeRoute(
        pointerId,
        _handlePointerRoute,
      );
    }
    _activePointerId = null;
  }

  @override
  void dispose() {
    _stopPointerTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget listener = Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUpOrCancel,
      onPointerCancel: _handlePointerUpOrCancel,
      child: widget.child,
    );

    final bool canDrag = !_suppressDrag;
    if (widget.requiresLongPress) {
      return LongPressDraggable<CalendarDragPayload>(
        data: _dragPayload(),
        dragAnchorStrategy: _centerDragAnchorStrategy,
        maxSimultaneousDrags: canDrag ? 1 : 0,
        feedback: widget.feedback,
        childWhenDragging: widget.childWhenDragging,
        rootOverlay: true,
        onDragStarted: _handleDragStarted,
        onDragUpdate: _handleDragUpdated,
        onDragEnd: (_) => _handleDragFinished(cancelled: false),
        onDraggableCanceled: (_, __) => _handleDragFinished(cancelled: true),
        child: listener,
      );
    }

    return Draggable<CalendarDragPayload>(
      data: _dragPayload(),
      dragAnchorStrategy: _centerDragAnchorStrategy,
      maxSimultaneousDrags: canDrag ? 1 : 0,
      feedback: widget.feedback,
      childWhenDragging: widget.childWhenDragging,
      rootOverlay: true,
      onDragStarted: _handleDragStarted,
      onDragUpdate: _handleDragUpdated,
      onDragEnd: (_) => _handleDragFinished(cancelled: false),
      onDraggableCanceled: (_, __) => _handleDragFinished(cancelled: true),
      child: listener,
    );
  }
}

Offset _centerDragAnchorStrategy(
  Draggable<Object?> draggable,
  BuildContext context,
  Offset position,
) {
  final RenderBox? renderObject = context.findRenderObject() as RenderBox?;
  if (renderObject == null || !renderObject.hasSize) {
    return Offset.zero;
  }
  final Size size = renderObject.size;
  return Offset(size.width / 2, size.height / 2);
}
