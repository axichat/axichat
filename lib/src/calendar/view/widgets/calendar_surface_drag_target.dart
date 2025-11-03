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
  RenderCalendarSurface? get _renderSurface {
    final BuildContext? surfaceContext = widget.surfaceKey.currentContext;
    if (surfaceContext == null) {
      return null;
    }
    final RenderObject? renderObject = surfaceContext.findRenderObject();
    return renderObject is RenderCalendarSurface ? renderObject : null;
  }

  bool _handleWillAccept(DragTargetDetails<CalendarDragPayload> details) {
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null) {
      return false;
    }
    surface.handleDragPayloadUpdate(details.data, details.offset);
    return true;
  }

  void _handleMove(DragTargetDetails<CalendarDragPayload> details) {
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null) {
      return;
    }
    surface.handleDragPayloadUpdate(details.data, details.offset);
  }

  void _handleAccept(DragTargetDetails<CalendarDragPayload> details) {
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null) {
      return;
    }
    surface.handleDragPayloadDrop(details.data, details.offset);
  }

  void _handleLeave(CalendarDragPayload? payload) {
    final RenderCalendarSurface? surface = _renderSurface;
    if (surface == null || payload == null) {
      return;
    }
    surface.handleDragPayloadExit(payload);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<CalendarDragPayload>(
      onWillAcceptWithDetails: _handleWillAccept,
      onMove: _handleMove,
      onAcceptWithDetails: _handleAccept,
      onLeave: _handleLeave,
      builder: (context, _, __) => widget.child,
    );
  }
}
