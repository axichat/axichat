// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';

/// Centralized layout constants for the calendar grid. Keeping these values in
/// one place eliminates scattered magic numbers while preserving the legacy
/// visual design.
class CalendarLayoutTheme {
  const CalendarLayoutTheme({
    this.timeColumnWidth = 44.0,
    this.popoverGap = 12.0,
    this.edgeScrollFastBandHeight = 60.0,
    this.edgeScrollSlowBandHeight = 44.0,
    this.edgeScrollFastOffsetPerFrame = 9.0,
    this.edgeScrollSlowOffsetPerFrame = 4.5,
    this.eventHorizontalInset = calendarTaskColumnInset,
    this.eventColumnGap = calendarTaskColumnGap,
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
  CalendarZoomLevel(hourHeight: 64, daySubdivisions: 4, label: 'Compact'),
  CalendarZoomLevel(hourHeight: 120, daySubdivisions: 4, label: 'Comfort'),
  CalendarZoomLevel(hourHeight: 184, daySubdivisions: 4, label: 'Expanded'),
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
    final double totalMinutes =
        duration.inMicroseconds / Duration.microsecondsPerMinute;
    final double normalizedMinutes =
        math.max(totalMinutes, minutesPerSlot.toDouble());
    return (normalizedMinutes / minutesPerSlot) * slotHeight;
  }

  double verticalOffsetForMinutes(double minutesFromStart) {
    final double slots = minutesFromStart / minutesPerSlot;
    return slots * slotHeight;
  }
}

/// Immutable geometry describing how a calendar task should be rendered within
/// a day column.
class CalendarTaskLayout {
  const CalendarTaskLayout({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.clampedStart,
    required this.clampedEnd,
    required this.spanDays,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final DateTime clampedStart;
  final DateTime clampedEnd;
  final int spanDays;
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
    bool allowDayViewZoom = false,
  }) {
    final CalendarZoomLevel zoom = zoomLevels[zoomIndex];
    final bool useDayViewTheme = isDayView && !allowDayViewZoom;
    final double desiredHourHeight =
        useDayViewTheme ? theme.dayViewHourHeight : zoom.hourHeight;
    final int subdivisions =
        useDayViewTheme ? theme.dayViewSubdivisions : zoom.daySubdivisions;
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
    final double inset = theme.eventHorizontalInset;

    double offset = columnWidth * overlap.columnIndex;
    if (totalColumns == 1 || overlap.columnIndex == 0) {
      offset += inset;
    }
    return offset;
  }

  double eventWidth({
    required double dayWidth,
    required OverlapInfo overlap,
    required bool isDayView,
    required int spanDays,
  }) {
    final totalColumns = math.max(1, overlap.totalColumns);
    final columnWidth = dayWidth / totalColumns;
    final double inset = theme.eventHorizontalInset;
    final int effectiveSpan = math.max(1, spanDays);

    double width = columnWidth * effectiveSpan;

    if (totalColumns == 1) {
      width -= inset * 2;
    } else {
      final bool touchesLeftEdge = overlap.columnIndex == 0;
      final bool touchesRightEdge =
          overlap.columnIndex + effectiveSpan >= totalColumns;
      if (touchesLeftEdge) {
        width -= inset;
      }
      if (touchesRightEdge) {
        width -= inset;
      }
    }

    width = math.max(width, theme.eventMinWidth);

    if (isDayView) {
      return width;
    }

    final double adjustedWidth = width - (theme.eventColumnGap * 2);
    return math.max(adjustedWidth, theme.eventMinWidth);
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

  DateTime _normalizeEndBoundary(DateTime start, DateTime candidate) {
    if (_isExactMidnight(candidate) && candidate.isAfter(start)) {
      return candidate.subtract(const Duration(microseconds: 1));
    }
    return candidate;
  }

  bool _isExactMidnight(DateTime value) =>
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;

  CalendarTaskLayout? resolveTaskLayout({
    required CalendarTask task,
    required DateTime dayDate,
    required DateTime weekStartDate,
    required DateTime weekEndDate,
    required bool isDayView,
    required int startHour,
    required int endHour,
    required double dayWidth,
    required CalendarLayoutMetrics metrics,
    required OverlapInfo overlap,
  }) {
    final DateTime? scheduledTime = task.scheduledTime;
    if (scheduledTime == null) {
      return null;
    }

    final DateTime eventStartDate = DateTime(
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
    );
    DateTime? effectiveEnd = task.effectiveEndDate;
    effectiveEnd ??=
        task.duration != null ? scheduledTime.add(task.duration!) : null;
    final DateTime layoutEndReference = effectiveEnd == null
        ? scheduledTime
        : _normalizeEndBoundary(scheduledTime, effectiveEnd);
    final DateTime eventEndDate = DateTime(
      layoutEndReference.year,
      layoutEndReference.month,
      layoutEndReference.day,
    );

    final DateTime clampedWeekStart =
        eventStartDate.isBefore(weekStartDate) ? weekStartDate : eventStartDate;
    final DateTime clampedWeekEnd =
        eventEndDate.isAfter(weekEndDate) ? weekEndDate : eventEndDate;

    if (dayDate.isAfter(clampedWeekEnd) || dayDate.isBefore(clampedWeekStart)) {
      return null;
    }

    if (!isDayView && !DateUtils.isSameDay(dayDate, clampedWeekStart)) {
      return null;
    }

    final int minuteDelta =
        (scheduledTime.hour * 60 + scheduledTime.minute) - (startHour * 60);
    if (minuteDelta < 0) {
      return null;
    }

    if (scheduledTime.hour > endHour) {
      return null;
    }

    final double minutesFromStart = minuteDelta.toDouble();
    final double topOffset = metrics.verticalOffsetForMinutes(
      minutesFromStart,
    );
    final Duration duration = task.duration ?? const Duration(hours: 1);
    final double height = clampEventHeight(
      metrics.heightForDuration(duration),
    );

    final int spanDays = isDayView
        ? 1
        : ((clampedWeekEnd.difference(clampedWeekStart).inDays + 1)
            .clamp(1, 7));

    final double left = eventLeftOffset(
      dayWidth: dayWidth,
      overlap: overlap,
    );

    final double width = eventWidth(
      dayWidth: dayWidth,
      overlap: overlap,
      isDayView: isDayView,
      spanDays: spanDays,
    );

    return CalendarTaskLayout(
      left: left,
      top: topOffset,
      width: width,
      height: height,
      clampedStart: clampedWeekStart,
      clampedEnd: clampedWeekEnd,
      spanDays: spanDays,
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
