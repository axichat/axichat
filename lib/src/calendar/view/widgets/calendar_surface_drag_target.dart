// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';

import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/models/calendar_drag_payload.dart';
import 'calendar_render_surface.dart';

/// Bridges Flutter's [DragTarget] events into the [RenderCalendarSurface].
class CalendarSurfaceDragTarget extends StatefulWidget {
  const CalendarSurfaceDragTarget({
    super.key,
    required this.controller,
    required this.interactionController,
    required this.child,
  });

  final CalendarSurfaceController controller;
  final TaskInteractionController interactionController;
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

  bool _flushPendingOperations() {
    final bool updateHandled = _maybeDispatchPendingUpdate();
    final bool dropHandled = _maybeDispatchPendingDrop();
    return updateHandled || dropHandled;
  }

  bool _maybeDispatchPendingUpdate() {
    final CalendarDragPayload? pendingPayload = _pendingPayload;
    final Offset? pendingOffset = _pendingOffset;
    if (pendingPayload == null || pendingOffset == null) {
      return false;
    }
    final bool handled = widget.controller.dispatchDragPayloadUpdate(
      pendingPayload,
      pendingOffset,
    );
    if (handled) {
      _pendingPayload = null;
      _pendingOffset = null;
    }
    return handled;
  }

  bool _maybeDispatchPendingDrop() {
    final CalendarDragPayload? dropPayload = _pendingDropPayload;
    final Offset? dropOffset = _pendingDropOffset;
    if (dropPayload == null || dropOffset == null) {
      return false;
    }
    final bool handled = widget.controller.dispatchDragPayloadDrop(
      dropPayload,
      dropOffset,
    );
    if (handled) {
      _pendingDropPayload = null;
      _pendingDropOffset = null;
    }
    return handled;
  }

  void _scheduleDeferredUpdate(CalendarDragPayload payload, Offset offset) {
    _pendingPayload = payload;
    _pendingOffset = offset;
    _flushPendingOperations();
  }

  void _scheduleDeferredDrop(CalendarDragPayload payload, Offset offset) {
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

  bool _shouldDeferToActiveGridDrag(CalendarDragPayload payload) {
    final CalendarInteractionSession? session =
        widget.interactionController.activeInteractionSession;
    if (session == null || !session.isDrag) {
      return false;
    }
    return session.source == CalendarInteractionSource.taskSurface &&
        session.taskId == payload.task.id;
  }

  bool _handleWillAccept(DragTargetDetails<CalendarDragPayload> details) {
    if (_shouldDeferToActiveGridDrag(details.data)) {
      return true;
    }
    if (!widget.controller.dispatchDragPayloadUpdate(
      details.data,
      details.offset,
    )) {
      _scheduleDeferredUpdate(details.data, details.offset);
    }
    return true;
  }

  void _handleMove(DragTargetDetails<CalendarDragPayload> details) {
    if (_shouldDeferToActiveGridDrag(details.data)) {
      return;
    }
    final bool handled = widget.controller.dispatchDragPayloadUpdate(
      details.data,
      details.offset,
    );
    if (!handled) {
      _scheduleDeferredUpdate(details.data, details.offset);
    }
  }

  void _handleAccept(DragTargetDetails<CalendarDragPayload> details) {
    _cancelDeferredUpdate();
    final bool handled = widget.controller.dispatchDragPayloadDrop(
      details.data,
      details.offset,
    );
    if (!handled) {
      _scheduleDeferredDrop(details.data, details.offset);
    }
  }

  void _handleLeave(CalendarDragPayload? payload) {
    _cancelDeferredUpdate();
    if (payload == null) {
      return;
    }
    if (_shouldDeferToActiveGridDrag(payload)) {
      return;
    }
    widget.controller.dispatchDragPayloadExit(payload);
  }

  @override
  Widget build(BuildContext context) {
    _flushPendingOperations();
    return DragTarget<CalendarDragPayload>(
      onWillAcceptWithDetails: _handleWillAccept,
      onMove: _handleMove,
      onAcceptWithDetails: _handleAccept,
      onLeave: _handleLeave,
      builder: (context, _, _) => widget.child,
    );
  }
}
