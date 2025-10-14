import 'dart:math' as math;

import 'package:axichat/src/common/ui/ui.dart';

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
    this.eventHorizontalInset = calendarSpacing2,
    this.eventColumnGap = calendarSpacing2,
    this.eventMinHeight = calendarEventMinHeight,
    this.eventMinWidth = calendarEventMinWidth,
    this.narrowedWidthFactor = 0.5,
    this.narrowedWidthThresholdFactor = 0.55,
    this.dayViewHourHeight = calendarDayViewDefaultHourHeight,
    this.dayViewSubdivisions = calendarDayViewDefaultSubdivisions,
    this.visibleHourRows = calendarVisibleHourRows,
    this.sidebarMinWidth = calendarSidebarMinWidth,
    this.sidebarMinWidthFraction = calendarSidebarWidthMinFraction,
    this.sidebarDefaultWidthFraction = calendarSidebarWidthDefaultFraction,
    this.sidebarMaxWidthFraction = calendarSidebarWidthMaxFraction,
    this.sidebarScrollbarThickness = calendarSidebarScrollbarThickness,
    this.sidebarScrollbarRadius = calendarSidebarScrollbarRadius,
    this.zoomControlsElevation = calendarZoomControlsElevation,
    this.zoomControlsBorderRadius = calendarZoomControlsBorderRadius,
    this.zoomControlsPaddingHorizontal = calendarZoomControlsPaddingHorizontal,
    this.zoomControlsPaddingVertical = calendarZoomControlsPaddingVertical,
    this.zoomControlsLabelPaddingHorizontal =
        calendarZoomControlsLabelPaddingHorizontal,
    this.zoomControlsIconSize = calendarZoomControlsIconSize,
    this.clockTickInterval = calendarClockTickInterval,
    this.dragWidthDebounceDelay = calendarDragWidthDebounceDelay,
    this.splitPreviewAnimationDuration =
        calendarTaskSplitPreviewAnimationDuration,
    this.scrollAnimationDuration = calendarScrollAnimationDuration,
    this.slotHoverAnimationDuration = calendarSlotHoverAnimationDuration,
  });

  final double timeColumnWidth;
  final double popoverGap;
  final double edgeScrollFastBandHeight;
  final double edgeScrollSlowBandHeight;
  final double edgeScrollFastOffsetPerFrame;
  final double edgeScrollSlowOffsetPerFrame;
  final double eventHorizontalInset;
  final double eventColumnGap;
  final double eventMinHeight;
  final double eventMinWidth;
  final double narrowedWidthFactor;
  final double narrowedWidthThresholdFactor;
  final double dayViewHourHeight;
  final int dayViewSubdivisions;
  final int visibleHourRows;
  final double sidebarMinWidth;
  final double sidebarMinWidthFraction;
  final double sidebarDefaultWidthFraction;
  final double sidebarMaxWidthFraction;
  final double sidebarScrollbarThickness;
  final double sidebarScrollbarRadius;
  final double zoomControlsElevation;
  final double zoomControlsBorderRadius;
  final double zoomControlsPaddingHorizontal;
  final double zoomControlsPaddingVertical;
  final double zoomControlsLabelPaddingHorizontal;
  final double zoomControlsIconSize;
  final Duration clockTickInterval;
  final Duration dragWidthDebounceDelay;
  final Duration splitPreviewAnimationDuration;
  final Duration scrollAnimationDuration;
  final Duration slotHoverAnimationDuration;

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
    final double desiredHourHeight =
        isDayView ? theme.dayViewHourHeight : zoom.hourHeight;
    final int subdivisions =
        isDayView ? theme.dayViewSubdivisions : zoom.daySubdivisions;
    final double baseSlotHeight = desiredHourHeight / subdivisions;
    // Legacy grid renders from 00:00 through 24:00 inclusive, resulting in 25
    // visible hour rows.
    final int totalSlots = theme.visibleHourRows * subdivisions;

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

  double eventLeftOffset({
    required double dayWidth,
    required OverlapInfo overlap,
  }) {
    final totalColumns = math.max(1, overlap.totalColumns);
    final columnWidth = dayWidth / totalColumns;
    return (columnWidth * overlap.columnIndex) + theme.eventHorizontalInset;
  }

  double eventWidth({
    required double dayWidth,
    required OverlapInfo overlap,
    required bool isDayView,
    required int spanDays,
  }) {
    final totalColumns = math.max(1, overlap.totalColumns);
    final columnWidth = dayWidth / totalColumns;
    final double baseWidth = columnWidth - (theme.eventHorizontalInset * 2);

    if (isDayView) {
      return math.max(baseWidth, theme.eventMinWidth);
    }

    final effectiveSpan = math.max(1, spanDays);
    final double multiWidth =
        (columnWidth * effectiveSpan) - (theme.eventColumnGap * 2);
    return math.max(multiWidth, theme.eventMinWidth);
  }

  double clampEventHeight(double rawHeight) {
    return math.max(theme.eventMinHeight, rawHeight);
  }

  double computeNarrowedWidth(double slotWidth, double baselineWidth) {
    final double effectiveSlotWidth =
        math.max(slotWidth - (theme.eventColumnGap * 2), 0.0);
    final double thresholdWidth =
        effectiveSlotWidth * theme.narrowedWidthThresholdFactor;

    if (baselineWidth <= thresholdWidth) {
      return baselineWidth;
    }

    final double narrowed = effectiveSlotWidth * theme.narrowedWidthFactor;
    final double minimumAllowed = math.min(theme.eventMinWidth, baselineWidth);
    return narrowed.clamp(minimumAllowed, baselineWidth);
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
