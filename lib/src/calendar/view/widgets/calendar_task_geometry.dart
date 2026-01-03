// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

/// Describes the layout geometry of a calendar task entry.
class CalendarTaskGeometry {
  const CalendarTaskGeometry({
    required this.rect,
    required this.narrowedWidth,
    required this.splitWidthFactor,
    this.columnDate,
  });

  static const CalendarTaskGeometry empty = CalendarTaskGeometry(
    rect: Rect.zero,
    narrowedWidth: 0,
    splitWidthFactor: 1,
  );

  final Rect rect;
  final double narrowedWidth;
  final double splitWidthFactor;
  final DateTime? columnDate;

  @override
  int get hashCode => Object.hash(rect, narrowedWidth, splitWidthFactor,
      columnDate?.millisecondsSinceEpoch);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarTaskGeometry &&
        rect == other.rect &&
        narrowedWidth == other.narrowedWidth &&
        splitWidthFactor == other.splitWidthFactor &&
        other.columnDate == columnDate;
  }
}
