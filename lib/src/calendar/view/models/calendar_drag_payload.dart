import 'dart:ui';

import '../../models/calendar_task.dart';

/// Payload shared between calendar draggables and drag targets.
class CalendarDragPayload {
  const CalendarDragPayload({
    required this.task,
    required this.snapshot,
    this.sourceBounds,
    this.pointerNormalizedX,
    this.pointerOffsetY,
    this.originSlot,
    this.pickupScheduledTime,
  });

  /// Task currently being dragged.
  final CalendarTask task;

  /// Snapshot captured at drag start; this can differ for unscheduled clones.
  final CalendarTask snapshot;

  /// Global bounds of the task when the drag started.
  final Rect? sourceBounds;

  /// Normalised pointer position along the horizontal axis at drag start.
  final double? pointerNormalizedX;

  /// Pointer offset from the top of the task at drag start.
  final double? pointerOffsetY;

  /// Slot anchoring the drag when the task originated from the grid.
  final DateTime? originSlot;

  /// Exact scheduled start when the drag began (before previews mutate state).
  final DateTime? pickupScheduledTime;
}
