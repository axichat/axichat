import 'dart:math' as math;

import '../../models/calendar_task.dart';

/// Centralized layout constants for the calendar grid. Keeping these values in
/// one place eliminates scattered magic numbers while preserving the legacy
/// visual design.
class CalendarLayoutTheme {
  const CalendarLayoutTheme({
    this.timeColumnWidth = 80.0,
    this.popoverGap = 12.0,
    this.edgeScrollFastBandHeight = 60.0,
    this.edgeScrollSlowBandHeight = 44.0,
    this.edgeScrollFastOffsetPerFrame = 9.0,
    this.edgeScrollSlowOffsetPerFrame = 4.5,
  });

  final double timeColumnWidth;
  final double popoverGap;
  final double edgeScrollFastBandHeight;
  final double edgeScrollSlowBandHeight;
  final double edgeScrollFastOffsetPerFrame;
  final double edgeScrollSlowOffsetPerFrame;

  static const CalendarLayoutTheme material = CalendarLayoutTheme();
}

/// Describes a zoom configuration used by the calendar grid.
class CalendarZoomLevel {
  const CalendarZoomLevel({
    required this.hourHeight,
    required this.daySubdivisions,
    required this.label,
  });

  final double hourHeight;
  final int daySubdivisions;
  final String label;
}

const List<CalendarZoomLevel> kCalendarZoomLevels = <CalendarZoomLevel>[
  CalendarZoomLevel(hourHeight: 78, daySubdivisions: 4, label: 'Compact'),
  CalendarZoomLevel(hourHeight: 132, daySubdivisions: 4, label: 'Comfort'),
  CalendarZoomLevel(hourHeight: 192, daySubdivisions: 4, label: 'Expanded'),
];

/// Immutable layout metrics resolved for the active viewport.
class CalendarLayoutMetrics {
  const CalendarLayoutMetrics({
    required this.hourHeight,
    required this.slotHeight,
    required this.minutesPerSlot,
    required this.slotsPerHour,
  });

  final double hourHeight;
  final double slotHeight;
  final int minutesPerSlot;
  final int slotsPerHour;

  double heightForDuration(Duration duration) {
    final minutes = math.max(duration.inMinutes, minutesPerSlot);
    return (minutes / minutesPerSlot) * slotHeight;
  }

  double verticalOffsetForMinutes(int minutesFromStart) {
    final double slots = minutesFromStart / minutesPerSlot;
    return slots * slotHeight;
  }
}

class CalendarLayoutCalculator {
  const CalendarLayoutCalculator({
    this.theme = CalendarLayoutTheme.material,
    this.zoomLevels = kCalendarZoomLevels,
  });

  final CalendarLayoutTheme theme;
  final List<CalendarZoomLevel> zoomLevels;

  CalendarLayoutMetrics resolveMetrics({
    required int zoomIndex,
    required bool isDayView,
    required double availableHeight,
  }) {
    final CalendarZoomLevel zoom = zoomLevels[zoomIndex];
    final double desiredHourHeight = isDayView ? 192.0 : zoom.hourHeight;
    final int subdivisions = isDayView ? 4 : zoom.daySubdivisions;
    final double baseSlotHeight = desiredHourHeight / subdivisions;
    // Legacy grid renders from 00:00 through 24:00 inclusive, resulting in 25
    // visible hour rows.
    final int totalSlots = 25 * subdivisions;

    if (!availableHeight.isFinite || availableHeight <= 0) {
      return CalendarLayoutMetrics(
        hourHeight: desiredHourHeight,
        slotHeight: baseSlotHeight,
        minutesPerSlot: (60 / subdivisions).round(),
        slotsPerHour: subdivisions,
      );
    }

    final double minRequiredHeight = totalSlots * baseSlotHeight;
    if (availableHeight <= minRequiredHeight) {
      return CalendarLayoutMetrics(
        hourHeight: desiredHourHeight,
        slotHeight: baseSlotHeight,
        minutesPerSlot: (60 / subdivisions).round(),
        slotsPerHour: subdivisions,
      );
    }

    final double slotHeight = availableHeight / totalSlots;
    final double resolvedHourHeight = isDayView
        ? math.max<double>(desiredHourHeight, slotHeight * subdivisions)
        : math.max<double>(desiredHourHeight, slotHeight);

    return CalendarLayoutMetrics(
      hourHeight: resolvedHourHeight,
      slotHeight: math.max<double>(baseSlotHeight, slotHeight),
      minutesPerSlot: (60 / subdivisions).round(),
      slotsPerHour: subdivisions,
    );
  }
}

/// Simple immutable description of how overlapping events should be rendered
/// in the same column.
class OverlapInfo {
  const OverlapInfo({
    required this.columnIndex,
    required this.totalColumns,
  });

  final int columnIndex;
  final int totalColumns;
}

class _MutableOverlapInfo {
  _MutableOverlapInfo({required this.columnIndex, required this.totalColumns});

  final int columnIndex;
  int totalColumns;
}

class _ActiveTask {
  _ActiveTask({
    required this.taskId,
    required this.end,
    required this.columnIndex,
  });

  final String taskId;
  final DateTime end;
  final int columnIndex;
}

Map<String, OverlapInfo> calculateOverlapColumns(List<CalendarTask> tasks) {
  final sortedTasks = tasks.where((task) => task.scheduledTime != null).toList()
    ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

  final List<_ActiveTask> active = <_ActiveTask>[];
  final Map<String, _MutableOverlapInfo> overlapMap =
      <String, _MutableOverlapInfo>{};

  for (final CalendarTask task in sortedTasks) {
    final DateTime start = task.scheduledTime!;
    final DateTime end = start.add(task.duration ?? const Duration(hours: 1));

    active.removeWhere((entry) => !entry.end.isAfter(start));

    final Set<int> usedColumns =
        active.map((entry) => entry.columnIndex).toSet();
    var columnIndex = 0;
    while (usedColumns.contains(columnIndex)) {
      columnIndex++;
    }

    final _ActiveTask newEntry = _ActiveTask(
      taskId: task.id,
      end: end,
      columnIndex: columnIndex,
    );
    active.add(newEntry);
    active.sort((a, b) => a.columnIndex.compareTo(b.columnIndex));

    final int totalColumns = active.length;
    final _MutableOverlapInfo mutableInfo = _MutableOverlapInfo(
      columnIndex: columnIndex,
      totalColumns: totalColumns,
    );
    overlapMap[task.id] = mutableInfo;

    for (final _ActiveTask entry in active) {
      final _MutableOverlapInfo? info = overlapMap[entry.taskId];
      if (info != null && info.totalColumns < totalColumns) {
        info.totalColumns = totalColumns;
      }
    }
  }

  return overlapMap.map(
    (key, value) => MapEntry(
      key,
      OverlapInfo(
        columnIndex: value.columnIndex,
        totalColumns: value.totalColumns,
      ),
    ),
  );
}
