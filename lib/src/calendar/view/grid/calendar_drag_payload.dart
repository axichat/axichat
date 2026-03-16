// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

import 'package:axichat/src/calendar/models/calendar_task.dart';

enum CalendarDragPayloadSource { taskSurface, sidebar }

class CalendarDragPayload {
  const CalendarDragPayload({
    required this.task,
    required this.snapshot,
    required this.source,
    this.sourceBounds,
    this.pointerNormalizedX,
    this.pointerOffsetY,
    this.originSlot,
    this.pickupScheduledTime,
  });

  final CalendarTask task;
  final CalendarTask snapshot;
  final CalendarDragPayloadSource source;
  final Rect? sourceBounds;
  final double? pointerNormalizedX;
  final double? pointerOffsetY;
  final DateTime? originSlot;
  final DateTime? pickupScheduledTime;
}
