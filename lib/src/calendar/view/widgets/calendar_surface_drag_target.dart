import 'package:flutter/widgets.dart';

import '../models/calendar_drag_payload.dart';
import 'calendar_render_surface.dart';

/// Bridges Flutter's [DragTarget] events into the [RenderCalendarSurface].
class CalendarSurfaceDragTarget extends StatefulWidget {
  const CalendarSurfaceDragTarget({
    super.key,
    required this.surfaceKey,
    required this.child,
  });

  final GlobalKey surfaceKey;
  final Widget child;

  @override
  State<CalendarSurfaceDragTarget> createState() =>
      _CalendarSurfaceDragTargetState();
}

class _CalendarSurfaceDragTargetState extends State<CalendarSurfaceDragTarget> {
  CalendarDragPayload? _pendingPayload;
  Offset? _pendingOffset;
  CalendarDragPayload? _pendingDropPayload;
  Offset? _pendingDropOffset;

  RenderCalendarSurface? get _renderSurface {
    final BuildContext? surfaceContext = widget.surfaceKey.currentContext;
    if (surfaceContext == null) {
      return null;
    }
    final RenderObject? renderObject = surfaceContext.findRenderObject();
    return renderObject is RenderCalendarSurface ? renderObject : null;
  }

  bool _flushPendingOperations() {
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null) {
      return false;
    }

    bool handled = false;
    final CalendarDragPayload? pendingPayload = _pendingPayload;
    final Offset? pendingOffset = _pendingOffset;
    if (pendingPayload != null && pendingOffset != null) {
      _pendingPayload = null;
      _pendingOffset = null;
      surface.handleDragPayloadUpdate(pendingPayload, pendingOffset);
      handled = true;
    }

    final CalendarDragPayload? dropPayload = _pendingDropPayload;
    final Offset? dropOffset = _pendingDropOffset;
    if (dropPayload != null && dropOffset != null) {
      _pendingDropPayload = null;
      _pendingDropOffset = null;
      surface.handleDragPayloadDrop(dropPayload, dropOffset);
      handled = true;
    }

    return handled;
  }

  void _scheduleDeferredUpdate(
    CalendarDragPayload payload,
    Offset offset,
  ) {
    _pendingPayload = payload;
    _pendingOffset = offset;
    _flushPendingOperations();
  }

  void _scheduleDeferredDrop(
    CalendarDragPayload payload,
    Offset offset,
  ) {
    _pendingDropPayload = payload;
    _pendingDropOffset = offset;
    if (!_flushPendingOperations() && mounted) {
      setState(() {});
    }
  }

  void _cancelDeferredUpdate() {
    _pendingPayload = null;
    _pendingOffset = null;
    _pendingDropPayload = null;
    _pendingDropOffset = null;
  }

  bool _handleWillAccept(DragTargetDetails<CalendarDragPayload> details) {
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null) {
      _scheduleDeferredUpdate(details.data, details.offset);
      return true;
    }
    surface.handleDragPayloadUpdate(details.data, details.offset);
    return true;
  }

  void _handleMove(DragTargetDetails<CalendarDragPayload> details) {
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null) {
      _scheduleDeferredUpdate(details.data, details.offset);
      return;
    }
    surface.handleDragPayloadUpdate(details.data, details.offset);
  }

  void _handleAccept(DragTargetDetails<CalendarDragPayload> details) {
    _cancelDeferredUpdate();
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null) {
      _scheduleDeferredDrop(details.data, details.offset);
      return;
    }
    surface.handleDragPayloadDrop(details.data, details.offset);
  }

  void _handleLeave(CalendarDragPayload? payload) {
    _cancelDeferredUpdate();
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null || payload == null) {
      return;
    }
    surface.handleDragPayloadExit(payload);
  }

  @override
  Widget build(BuildContext context) {
    _flushPendingOperations();
    return DragTarget<CalendarDragPayload>(
      onWillAcceptWithDetails: _handleWillAccept,
      onMove: _handleMove,
      onAcceptWithDetails: _handleAccept,
      onLeave: _handleLeave,
      builder: (context, _, __) => widget.child,
    );
  }
}
