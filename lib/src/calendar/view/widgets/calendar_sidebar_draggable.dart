import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../models/calendar_task.dart';
import '../models/calendar_drag_payload.dart';

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
  });

  final CalendarTask task;
  final Widget child;
  final Widget feedback;
  final Widget childWhenDragging;
  final VoidCallback? onDragSessionStarted;
  final VoidCallback? onDragSessionEnded;
  final ValueChanged<Offset>? onDragGlobalPositionChanged;

  @override
  State<CalendarSidebarDraggable> createState() =>
      _CalendarSidebarDraggableState();
}

class _CalendarSidebarDraggableState extends State<CalendarSidebarDraggable> {
  bool _dragSessionActive = false;
  Rect? _sourceBounds;
  Size _childSize = Size.zero;
  double? _pointerNormalized;
  double? _pointerOffsetY;

  void _handlePointerDown(PointerDownEvent event) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Size size = box?.size ?? Size.zero;
    final Offset globalTopLeft = box != null
        ? box.localToGlobal(Offset.zero)
        : event.position - event.localPosition;
    final double width = size.width <= 0 ? 1.0 : size.width;
    final double normalized = (event.localPosition.dx / width).clamp(0.0, 1.0);

    setState(() {
      _childSize = size;
      _sourceBounds = Rect.fromLTWH(
        globalTopLeft.dx,
        globalTopLeft.dy,
        size.width,
        size.height,
      );
      _pointerNormalized = normalized;
      _pointerOffsetY = event.localPosition.dy;
    });
  }

  CalendarDragPayload _buildPayload() {
    final Rect? bounds = _sourceBounds;
    final double pointerNormalized =
        (_pointerNormalized ?? 0.5).clamp(0.0, 1.0);
    final double pointerOffsetY = _pointerOffsetY ??
        (_childSize.height.isFinite && _childSize.height > 0
            ? _childSize.height / 2
            : 0.0);

    return CalendarDragPayload(
      task: widget.task,
      snapshot: widget.task,
      sourceBounds: bounds,
      pointerNormalizedX: pointerNormalized,
      pointerOffsetY: pointerOffsetY,
      originSlot: null,
    );
  }

  void _resetCachedPointer() {
    _pointerNormalized = null;
    _pointerOffsetY = null;
    _sourceBounds = null;
    _childSize = Size.zero;
  }

  void _handleDragStarted() {
    if (_dragSessionActive) {
      return;
    }
    _dragSessionActive = true;
    widget.onDragSessionStarted?.call();
  }

  void _handleDragUpdated(DragUpdateDetails details) {
    widget.onDragGlobalPositionChanged?.call(details.globalPosition);
  }

  void _handleDragFinished({required bool cancelled}) {
    if (_dragSessionActive) {
      _dragSessionActive = false;
      widget.onDragSessionEnded?.call();
    }
    _resetCachedPointer();
  }

  @override
  Widget build(BuildContext context) {
    final Widget listener = Listener(
      onPointerDown: _handlePointerDown,
      child: widget.child,
    );

    return Draggable<CalendarDragPayload>(
      data: _buildPayload(),
      dragAnchorStrategy: pointerDragAnchorStrategy,
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
