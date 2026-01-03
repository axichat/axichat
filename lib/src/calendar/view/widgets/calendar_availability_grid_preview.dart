// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/layout/calendar_layout.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_render_surface.dart';
import 'package:axichat/src/common/ui/ui.dart';

const double _availabilityPreviewViewportHeight = 240.0;
const int _availabilityPreviewStartHour = 0;
const int _availabilityPreviewEndHour = 24;
const int _availabilityPreviewZoomIndex = 0;
const int _availabilityPreviewMinutesPerStep = 15;
const int _availabilityPreviewDayLabelLength = 3;
const double _availabilityPreviewHeaderFontSize = 12.0;
const Duration _availabilityPreviewDayStep = Duration(days: 1);

const List<String> _availabilityPreviewDayNames = <String>[
  'SUNDAY',
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
];

class CalendarAvailabilityGridPreview extends StatefulWidget {
  const CalendarAvailabilityGridPreview({
    super.key,
    required this.rangeOverlay,
    required this.overlays,
  });

  final CalendarAvailabilityOverlay rangeOverlay;
  final List<CalendarAvailabilityOverlay> overlays;

  @override
  State<CalendarAvailabilityGridPreview> createState() =>
      _CalendarAvailabilityGridPreviewState();
}

class _CalendarAvailabilityGridPreviewState
    extends State<CalendarAvailabilityGridPreview> {
  final CalendarSurfaceController _surfaceController =
      CalendarSurfaceController();
  final ScrollController _verticalController = ScrollController();
  final CalendarLayoutCalculator _layoutCalculator =
      const CalendarLayoutCalculator();
  final CalendarLayoutTheme _layoutTheme = CalendarLayoutTheme.material;
  late final TaskInteractionController _interactionController =
      TaskInteractionController();

  @override
  void dispose() {
    _verticalController.dispose();
    _interactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime rangeStart = widget.rangeOverlay.rangeStart.value;
    final DateTime rangeEnd = widget.rangeOverlay.rangeEnd.value;
    final List<DateTime> columns = _resolvePreviewColumns(
      rangeStart,
      rangeEnd,
    );
    if (columns.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _fallbackWidth(columns.length);
        final double timeColumnWidth = _layoutTheme.timeColumnWidth;
        const double minDayWidth = calendarCompactDayColumnWidth;
        final double requiredWidth =
            timeColumnWidth + (minDayWidth * columns.length);
        final double resolvedWidth = math.max(requiredWidth, availableWidth);
        final bool needsHorizontalScroll = resolvedWidth > availableWidth;
        final double dayWidth =
            (resolvedWidth - timeColumnWidth) / columns.length;

        final Widget content = _AvailabilityGridFrame(
          width: resolvedWidth,
          header: _AvailabilityGridHeaderRow(
            dates: columns,
            timeColumnWidth: timeColumnWidth,
            dayWidth: dayWidth,
          ),
          body: _AvailabilityGridSurface(
            width: resolvedWidth,
            height: _availabilityPreviewViewportHeight,
            columns: columns,
            overlays: widget.overlays,
            controller: _surfaceController,
            verticalController: _verticalController,
            layoutCalculator: _layoutCalculator,
            layoutTheme: _layoutTheme,
            interactionController: _interactionController,
          ),
        );

        if (!needsHorizontalScroll) {
          return content;
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: resolvedWidth,
            child: content,
          ),
        );
      },
    );
  }

  double _fallbackWidth(int columnCount) {
    final double timeColumnWidth = _layoutTheme.timeColumnWidth;
    const double minDayWidth = calendarCompactDayColumnWidth;
    return timeColumnWidth + (minDayWidth * columnCount);
  }
}

class _AvailabilityGridFrame extends StatelessWidget {
  const _AvailabilityGridFrame({
    required this.width,
    required this.header,
    required this.body,
  });

  final double width;
  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(calendarBorderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: calendarBackgroundColor,
          border: Border.all(
            color: calendarBorderColor,
            width: calendarBorderStroke,
          ),
        ),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityGridHeaderRow extends StatelessWidget {
  const _AvailabilityGridHeaderRow({
    required this.dates,
    required this.timeColumnWidth,
    required this.dayWidth,
  });

  final List<DateTime> dates;
  final double timeColumnWidth;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    final BorderSide divider = BorderSide(
      color: calendarBorderDarkColor,
      width: calendarBorderStroke,
    );
    final BorderSide bottom = BorderSide(
      color: calendarBorderColor,
      width: calendarBorderStroke,
    );

    return Container(
      height: calendarWeekHeaderHeight,
      decoration: BoxDecoration(
        color: calendarBackgroundColor,
        border: Border(bottom: bottom),
      ),
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            height: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: calendarBackgroundColor,
                border: Border(right: divider),
              ),
            ),
          ),
          for (final DateTime date in dates)
            SizedBox(
              width: dayWidth,
              height: double.infinity,
              child: _AvailabilityDayHeader(
                date: date,
                showRightDivider: date != dates.last,
              ),
            ),
        ],
      ),
    );
  }
}

class _AvailabilityDayHeader extends StatelessWidget {
  const _AvailabilityDayHeader({
    required this.date,
    required this.showRightDivider,
  });

  final DateTime date;
  final bool showRightDivider;

  @override
  Widget build(BuildContext context) {
    final bool isToday = _isSameDay(date, DateTime.now());
    final Color background = isToday
        ? calendarPrimaryColor.withValues(
            alpha: calendarDayHeaderHighlightOpacity,
          )
        : calendarBackgroundColor;
    final Color foreground =
        isToday ? calendarPrimaryColor : calendarTitleColor;
    final Color dividerColor = showRightDivider
        ? calendarBorderDarkColor
        : calendarBorderDarkColor.withValues(alpha: 0.0);
    final BorderSide divider = BorderSide(
      color: dividerColor,
      width: calendarBorderStroke,
    );
    final String label = _dayLabel(date);
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      fontSize: _availabilityPreviewHeaderFontSize,
      fontWeight: FontWeight.w600,
      color: foreground,
      letterSpacing: calendarDayHeaderLetterSpacing,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(right: divider),
      ),
      child: Center(
        child: Text(label, style: labelStyle),
      ),
    );
  }
}

class _AvailabilityGridSurface extends StatelessWidget {
  const _AvailabilityGridSurface({
    required this.width,
    required this.height,
    required this.columns,
    required this.overlays,
    required this.controller,
    required this.verticalController,
    required this.layoutCalculator,
    required this.layoutTheme,
    required this.interactionController,
  });

  final double width;
  final double height;
  final List<DateTime> columns;
  final List<CalendarAvailabilityOverlay> overlays;
  final CalendarSurfaceController controller;
  final ScrollController verticalController;
  final CalendarLayoutCalculator layoutCalculator;
  final CalendarLayoutTheme layoutTheme;
  final TaskInteractionController interactionController;

  @override
  Widget build(BuildContext context) {
    final List<CalendarDayColumn> columnSpecs = columns
        .map((date) => CalendarDayColumn(date: date))
        .toList(growable: false);
    final DateTime weekStart = _normalizeDay(columns.first);
    final DateTime weekEnd = _normalizeDay(columns.last);

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        controller: verticalController,
        child: SizedBox(
          width: width,
          child: IgnorePointer(
            child: CalendarRenderSurface(
              columns: columnSpecs,
              startHour: _availabilityPreviewStartHour,
              endHour: _availabilityPreviewEndHour,
              zoomIndex: _availabilityPreviewZoomIndex,
              allowDayViewZoom: false,
              weekStartDate: weekStart,
              weekEndDate: weekEnd,
              layoutCalculator: layoutCalculator,
              layoutTheme: layoutTheme,
              controller: controller,
              verticalScrollController: verticalController,
              minutesPerStep: _availabilityPreviewMinutesPerStep,
              interactionController: interactionController,
              availabilityWindows: const <CalendarAvailabilityWindow>[],
              availabilityOverlays: overlays,
              children: const <Widget>[],
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _normalizeDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

List<DateTime> _resolvePreviewColumns(DateTime rangeStart, DateTime rangeEnd) {
  if (rangeEnd.isBefore(rangeStart)) {
    return const <DateTime>[];
  }
  final DateTime start = _normalizeDay(rangeStart);
  final DateTime end = _normalizeDay(rangeEnd);
  final List<DateTime> columns = <DateTime>[];
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    columns.add(cursor);
    cursor = cursor.add(_availabilityPreviewDayStep);
  }
  return columns;
}

String _dayLabel(DateTime date) {
  final int index = date.weekday % _availabilityPreviewDayNames.length;
  final String dayName = _availabilityPreviewDayNames[index];
  final String shortName =
      dayName.substring(0, _availabilityPreviewDayLabelLength);
  return '$shortName ${date.day}';
}
