import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../models/calendar_task.dart';
import 'task_interaction_controller.dart';

/// Coordinates drag preview calculations and slot geometry for the calendar grid.
class CalendarSlotDragController {
  CalendarSlotDragController({
    required this.interactionController,
    required this.getTasksForDay,
    required this.getMinutesPerSlot,
    required this.getMinutesPerStep,
    required this.getStartHour,
    required this.getEndHour,
    required this.getResolvedHourHeight,
  });

  final TaskInteractionController interactionController;
  final List<CalendarTask> Function(DateTime day) getTasksForDay;
  final int Function() getMinutesPerSlot;
  final int Function() getMinutesPerStep;
  final int Function() getStartHour;
  final int Function() getEndHour;
  final double Function() getResolvedHourHeight;

  double computePointerTopOffset(Offset pointerGlobal) {
    final double? stored = interactionController.dragPointerOffsetFromTop;
    if (stored != null) {
      return stored;
    }

    final double referenceTop =
        interactionController.dragStartGlobalTop ?? pointerGlobal.dy;
    double offset = pointerGlobal.dy - referenceTop;
    final double height = interactionController.draggingTaskHeight ?? 0;
    if (height > 0) {
      offset = offset.clamp(0.0, height);
    } else {
      offset = math.max(0.0, offset);
    }
    interactionController.dragPointerOffsetFromTop = offset;
    return offset;
  }

  DateTime? computeOriginSlot(DateTime? scheduled) {
    if (scheduled == null) {
      return null;
    }
    final int minutesPerSlot = getMinutesPerSlot();
    if (minutesPerSlot <= 0) {
      return scheduled;
    }
    final int slotMinutes =
        (scheduled.minute ~/ minutesPerSlot) * minutesPerSlot;
    return DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
      scheduled.hour,
      slotMinutes,
    );
  }

  bool isPreviewAnchor(DateTime slotStart) {
    final preview = interactionController.preview.value;
    if (preview == null) return false;
    return slotStart.isAtSameMomentAs(preview.start);
  }

  bool isPreviewSlot(DateTime slotStart, Duration slotDuration) {
    final preview = interactionController.preview.value;
    if (preview == null) {
      return false;
    }
    final DateTime previewStart = preview.start;
    final DateTime previewEnd = previewStart.add(preview.duration);
    final DateTime slotEnd = slotStart.add(slotDuration);
    return slotStart.isBefore(previewEnd) && slotEnd.isAfter(previewStart);
  }

  DateTime? computePreviewStartForSlot(
    RenderBox? renderBox,
    Offset pointerGlobal,
    DateTime slotTime,
    int slotMinutes,
    double slotHeight,
  ) {
    final DateTime targetDate = DateTime(
      slotTime.year,
      slotTime.month,
      slotTime.day,
    );

    if (renderBox == null || slotHeight <= 0) {
      final DateTime? fallback =
          computePreviewStartFromGlobalOffset(pointerGlobal, targetDate);
      return fallback == null ? null : clampPreviewStart(fallback, targetDate);
    }

    final double pointerOffset =
        interactionController.dragPointerOffsetFromTop ??
            computePointerTopOffset(pointerGlobal);
    final Offset pointerTopGlobal = pointerGlobal.translate(0, -pointerOffset);
    final Offset localTop = renderBox.globalToLocal(pointerTopGlobal);

    final DateTime candidate = quantizePreviewStart(
      slotTime,
      localTop.dy,
      slotHeight,
      slotMinutes,
    );

    return clampPreviewStart(candidate, targetDate);
  }

  DateTime quantizePreviewStart(
    DateTime slotTime,
    double localDy,
    double slotHeight,
    int slotMinutes,
  ) {
    final int stepMinutes = getMinutesPerStep();
    if (slotHeight <= 0 || slotMinutes <= 0 || stepMinutes <= 0) {
      return slotTime;
    }

    final double ratio = localDy / slotHeight;
    final double minutesOffset = ratio * slotMinutes;
    final double rawSteps = minutesOffset / stepMinutes;
    final int snappedSteps = rawSteps.floor();
    final int snappedMinutes = snappedSteps * stepMinutes;
    return slotTime.add(Duration(minutes: snappedMinutes));
  }

  DateTime clampPreviewStart(DateTime candidate, DateTime targetDate) {
    final DateTime dayStart = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      getStartHour(),
    );
    final DateTime dayEnd = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      getEndHour(),
    );

    if (candidate.isBefore(dayStart)) {
      return dayStart;
    }

    final int stepMinutes = getMinutesPerStep();
    if (stepMinutes <= 0) {
      return candidate.isBefore(dayEnd) ? candidate : dayEnd;
    }

    if (!candidate.isBefore(dayEnd)) {
      final DateTime lastValidStart = dayEnd.subtract(
        Duration(minutes: stepMinutes),
      );
      return lastValidStart.isBefore(dayStart) ? dayStart : lastValidStart;
    }

    return candidate;
  }

  DateTime? computePreviewStartFromGlobalOffset(
    Offset pointerGlobal,
    DateTime targetDate,
  ) {
    final DateTime? origin = interactionController.dragOriginSlot;
    final DateTime? dragStartTime =
        interactionController.dragStartScheduledTime;
    final double? dragTopGlobal = interactionController.dragStartGlobalTop;
    if (origin == null || dragTopGlobal == null) {
      return null;
    }

    final double pointerOffset =
        interactionController.dragPointerOffsetFromTop ??
            computePointerTopOffset(pointerGlobal);
    final double pointerTopGlobal = pointerGlobal.dy - pointerOffset;
    final double deltaPixels = pointerTopGlobal - dragTopGlobal;
    final double pixelsPerMinute = getResolvedHourHeight() / 60.0;
    if (pixelsPerMinute == 0) {
      return dragStartTime ?? origin;
    }

    final int stepMinutes = getMinutesPerStep();
    final double minutesDelta = deltaPixels / pixelsPerMinute;
    final int snappedMinutes =
        (minutesDelta / stepMinutes).round() * stepMinutes;

    final DateTime baseTime = dragStartTime ?? origin;
    final DateTime baseDateTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      baseTime.hour,
      baseTime.minute,
    );

    final DateTime candidate =
        baseDateTime.add(Duration(minutes: snappedMinutes));
    return clampPreviewStart(candidate, targetDate);
  }

  DateTime slotTimeFromOffset({
    required DateTime day,
    required double dy,
    required double slotHeight,
    required int minutesPerSlot,
    required int subdivisions,
  }) {
    if (minutesPerSlot <= 0) {
      return DateTime(day.year, day.month, day.day, getStartHour());
    }
    final int totalSlotCount = math.max(
      1,
      (getEndHour() - getStartHour() + 1) * subdivisions,
    );
    final double safeSlotHeight = slotHeight == 0 ? 1 : slotHeight;
    final int rawIndex = (dy / safeSlotHeight).floor();
    final int slotIndex = math.min(
      math.max(rawIndex, 0),
      totalSlotCount - 1,
    );
    final int slotMinutes = slotIndex * minutesPerSlot;
    final int totalMinutes = math.max(0, (getEndHour() - getStartHour()) * 60);
    final int maxMinutesFromStart = math.max(0, totalMinutes - minutesPerSlot);
    final int clampedFromStart = math.min(
      math.max(slotMinutes, 0),
      maxMinutesFromStart,
    );
    final int absoluteMinutes = (getStartHour() * 60) + clampedFromStart;
    final int hour = absoluteMinutes ~/ 60;
    final int minute = absoluteMinutes % 60;

    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  bool hasTaskInSlot(DateTime? date, int hour, int minute, int slotMinutes) {
    if (date == null) return false;

    final tasks = getTasksForDay(date);
    final DateTime slotStart =
        DateTime(date.year, date.month, date.day, hour, minute);
    final DateTime slotEnd = slotStart.add(Duration(minutes: slotMinutes));
    final String? draggingId = interactionController.draggingTaskId;

    return tasks.any((task) {
      final DateTime? taskStart = task.scheduledTime;
      if (taskStart == null) {
        return false;
      }
      if (draggingId != null && task.id == draggingId) {
        return false;
      }
      final DateTime taskEnd =
          taskStart.add(task.duration ?? const Duration(hours: 1));
      return taskStart.isBefore(slotEnd) && taskEnd.isAfter(slotStart);
    });
  }

  bool previewOverlapsScheduled(DateTime previewStart, Duration duration) {
    final DateTime day = DateTime(
      previewStart.year,
      previewStart.month,
      previewStart.day,
    );
    final tasks = getTasksForDay(day);
    final DateTime previewEnd = previewStart.add(duration);
    final String? draggingId = interactionController.draggingTaskId;

    return tasks.any((task) {
      final DateTime? taskStart = task.scheduledTime;
      if (taskStart == null) {
        return false;
      }
      if (draggingId != null && task.id == draggingId) {
        return false;
      }
      final DateTime taskEnd =
          taskStart.add(task.duration ?? const Duration(hours: 1));
      return previewStart.isBefore(taskEnd) && previewEnd.isAfter(taskStart);
    });
  }
}
