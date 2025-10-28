import 'package:flutter/material.dart';

import '../../models/calendar_task.dart';
import 'calendar_drag_interop.dart';

class CalendarSidebarDraggable extends StatefulWidget {
  const CalendarSidebarDraggable({
    super.key,
    required this.task,
    required this.child,
    required this.feedback,
    required this.childWhenDragging,
  });

  final CalendarTask task;
  final Widget child;
  final Widget feedback;
  final Widget childWhenDragging;

  @override
  State<CalendarSidebarDraggable> createState() =>
      _CalendarSidebarDraggableState();
}

class _CalendarSidebarDraggableState extends State<CalendarSidebarDraggable> {
  CalendarDragHandle? _handle;
  Offset _anchorOffset = Offset.zero;
  Size _childSize = Size.zero;
  Offset? _lastGlobal;
  Offset? _startGlobalPosition;
  RenderBox? _overlayBox;

  Offset _anchorStrategy(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      _childSize = box.size;
      _anchorOffset = box.globalToLocal(position);
    }
    _startGlobalPosition = position;
    return _anchorOffset;
  }

  void _startDrag() {
    final OverlayState? overlay =
        Overlay.of(context, rootOverlay: true);
    _overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    _handle = CalendarDragCoordinator.instance.startSession(
      task: widget.task,
      pointerOffset: _anchorOffset,
      feedbackSize: _childSize,
    );
    _lastGlobal = _startGlobalPosition;
    if (_startGlobalPosition != null) {
      _handle?.update(_startGlobalPosition!);
    }
  }

  void _updateDrag(DragUpdateDetails details) {
    Offset? nextGlobal;
    final RenderBox? overlayBox = _overlayBox;
    if (overlayBox != null) {
      nextGlobal = overlayBox.localToGlobal(details.localPosition);
    }
    nextGlobal ??= (_lastGlobal ?? _startGlobalPosition ?? details.globalPosition) +
        details.delta;
    _lastGlobal = nextGlobal;
    _handle?.update(nextGlobal);
  }

  void _completeDrag(DraggableDetails details) {
    final Offset position =
        _lastGlobal ?? _startGlobalPosition ?? details.offset;
    _handle?.end(position);
    _handle = null;
    _overlayBox = null;
  }

  void _cancelDrag(Velocity velocity, Offset offset) {
    final Offset position = _lastGlobal ?? _startGlobalPosition ?? offset;
    _handle?.end(position);
    _handle = null;
    _overlayBox = null;
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<CalendarTask>(
      data: widget.task,
      dragAnchorStrategy: _anchorStrategy,
      feedback: widget.feedback,
      childWhenDragging: widget.childWhenDragging,
      rootOverlay: true,
      onDragStarted: _startDrag,
      onDragUpdate: _updateDrag,
      onDragEnd: _completeDrag,
      onDraggableCanceled: _cancelDrag,
      child: widget.child,
    );
  }
}
