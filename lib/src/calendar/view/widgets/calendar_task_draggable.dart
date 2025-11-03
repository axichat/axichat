import 'package:flutter/material.dart';
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
    widget.interactionController.removeListener(_controllerListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final bool canDrag = widget.enabled && !_suppressDrag && !_isResizing;
    final CalendarDragPayload payload = _buildPayload();

    final Widget interactiveChild = Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );

    return Draggable<CalendarDragPayload>(
      data: payload,
      dragAnchorStrategy: _centerDragAnchorStrategy,
      maxSimultaneousDrags: canDrag ? 1 : 0,
      feedback: widget.feedbackBuilder(context, widget.task, _geometry),
      childWhenDragging: widget.childWhenDragging ?? widget.child,
      onDragStarted: _handleDragStarted,
      onDragUpdate: widget.onDragUpdate,
      onDragEnd: (details) => _handleDragFinished(cancelled: false),
      onDraggableCanceled: (_, __) => _handleDragFinished(cancelled: true),
      child: interactiveChild,
    );
  }

  static Offset _centerDragAnchorStrategy(
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

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) {
      return;
    }
    final Offset local = event.localPosition;
    final CalendarTaskGeometry geometry = _geometry;
    final Size size = geometry.rect.size;
    final bool suppressDrag = _isPointerOverResizeHandle(local, size);

    final double width = size.width.isFinite && size.width > 0
        ? size.width
        : geometry.rect.width;
    final double height = size.height.isFinite && size.height > 0
        ? size.height
        : geometry.rect.height;

    final double anchorX = width.isFinite && width > 0 ? width / 2 : local.dx;
    final double anchorY =
        height.isFinite && height > 0 ? height / 2 : local.dy;
    final Offset anchorLocal = Offset(anchorX, anchorY);
    final Offset fallbackTopLeft = event.position - anchorLocal;

    setState(() {
      _suppressDrag = suppressDrag;
      _lastPointerLocal = anchorLocal;
      _lastPointerGlobal = event.position;
      _pointerNormalized = width.isFinite && width > 0
          ? 0.5
          : (anchorLocal.dx / (width == 0 ? 1.0 : width)).clamp(0.0, 1.0);
      _pointerOffsetY = anchorY;
      _sourceBounds = _resolveGlobalBounds(
        fallbackTopLeft: fallbackTopLeft,
      );
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_suppressDrag) {
      setState(() {
        _suppressDrag = false;
      });
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_suppressDrag) {
      setState(() {
        _suppressDrag = false;
      });
    }
  }

  void _handleDragStarted() {
    widget.interactionController.suppressSurfaceTapOnce();
    final Rect? bounds = _sourceBounds ?? _resolveGlobalBounds();
    if (bounds != null) {
      widget.onDragStarted(widget.task, bounds);
    }
  }

  void _handleDragFinished({required bool cancelled}) {
    if (_suppressDrag) {
      setState(() {
        _suppressDrag = false;
      });
    }
    widget.onDragEnded(widget.task);
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

  CalendarDragPayload _buildPayload() {
    final Rect? bounds = _sourceBounds ?? _resolveGlobalBounds();
    final double pointerNormalized =
        (_pointerNormalized ?? 0.5).clamp(0.0, 1.0);
    final double pointerOffsetY = _pointerOffsetY ??
        (_geometry.rect.height.isFinite && _geometry.rect.height > 0
            ? _geometry.rect.height / 2
            : 0.0);
    final CalendarTask snapshot = widget.snapshotBuilder?.call() ?? widget.task;

    return CalendarDragPayload(
      task: widget.task,
      snapshot: snapshot,
      sourceBounds: bounds,
      pointerNormalizedX: pointerNormalized,
      pointerOffsetY: pointerOffsetY,
      originSlot: widget.task.scheduledTime,
    );
  }
}
