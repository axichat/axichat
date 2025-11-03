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
  Offset? _lastPointerLocal;
  Offset? _lastPointerGlobal;
  double? _pointerNormalized;
  double? _pointerOffsetY;
  Rect? _sourceBounds;

  CalendarTaskGeometry get _geometry => widget.geometry;

  @override
  void didUpdateWidget(covariant CalendarTaskDraggable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_geometry != CalendarTaskGeometry.empty && _sourceBounds == null) {
      _sourceBounds = _resolveGlobalBounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final CalendarDragPayload payload = _buildPayload();

    final Widget interactiveChild = Listener(
      onPointerDown: _handlePointerDown,
      child: widget.child,
    );

    return Draggable<CalendarDragPayload>(
      data: payload,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: widget.feedbackBuilder(context, widget.task, _geometry),
      childWhenDragging: widget.childWhenDragging ?? widget.child,
      onDragStarted: _handleDragStarted,
      onDragUpdate: widget.onDragUpdate,
      onDragEnd: (details) => _handleDragFinished(cancelled: false),
      onDraggableCanceled: (_, __) => _handleDragFinished(cancelled: true),
      child: interactiveChild,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) {
      return;
    }
    final Offset local = event.localPosition;
    final CalendarTaskGeometry geometry = _geometry;
    final double width = geometry.rect.width;
    final double normalized =
        width <= 0 ? 0.5 : (local.dx / width).clamp(0.0, 1.0);
    setState(() {
      _lastPointerLocal = local;
      _lastPointerGlobal = event.position;
      _pointerNormalized = normalized;
      _pointerOffsetY = local.dy;
      _sourceBounds = _resolveGlobalBounds(
        fallbackTopLeft: event.position - local,
      );
    });
  }

  void _handleDragStarted() {
    widget.interactionController.suppressSurfaceTapOnce();
    final Rect? bounds = _sourceBounds ?? _resolveGlobalBounds();
    if (bounds != null) {
      widget.onDragStarted(widget.task, bounds);
    }
  }

  void _handleDragFinished({required bool cancelled}) {
    widget.onDragEnded(widget.task);
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
    final double pointerNormalized = _pointerNormalized ??
        widget.interactionController.dragPointerNormalized;
    final double pointerOffsetY =
        _pointerOffsetY ?? (_geometry.rect.height / 2);
    final CalendarTask snapshot = widget.snapshotBuilder?.call() ?? widget.task;

    return CalendarDragPayload(
      task: widget.task,
      snapshot: snapshot,
      sourceBounds: bounds,
      pointerNormalizedX: pointerNormalized.clamp(0.0, 1.0),
      pointerOffsetY: pointerOffsetY,
      originSlot: widget.task.scheduledTime,
    );
  }
}
