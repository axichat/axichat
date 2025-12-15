import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    super.key,
    required this.state,
    this.visibleEvents,
    required this.onDateSelected,
    required this.onCreateEvent,
    required this.onEditEvent,
  });

  final CalendarState state;
  final List<DayEvent>? visibleEvents;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onCreateEvent;
  final ValueChanged<DayEvent> onEditEvent;

  @override
  Widget build(BuildContext context) {
    final DateTime monthAnchor = state.selectedDate;
    final _MonthGrid grid = _MonthGrid.forMonth(monthAnchor);
    final Map<DateTime, List<DayEvent>> eventsByDate =
        _eventsForGrid(grid, visibleEvents);
    final ShadColorScheme colors = context.colorScheme;
    final BorderSide border =
        BorderSide(color: colors.border.withValues(alpha: 0.35));

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(
            color: calendarBorderColor,
            width: calendarBorderStroke,
          ),
          left: BorderSide(color: border.color),
          right: BorderSide(color: border.color),
          bottom: BorderSide(color: border.color),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekdayHeaderRow(colors: colors),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: grid.weeks
                    .map(
                      (List<DateTime> week) => _MonthWeekRow(
                        week: week,
                        month: monthAnchor.month,
                        selectedDate: state.selectedDate,
                        today: DateTime.now(),
                        eventsByDate: eventsByDate,
                        onDateSelected: onDateSelected,
                        onCreateEvent: onCreateEvent,
                        onEditEvent: onEditEvent,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<DayEvent>> _eventsForGrid(
    _MonthGrid grid,
    List<DayEvent>? suppliedEvents,
  ) {
    final Map<DateTime, List<DayEvent>> byDate = <DateTime, List<DayEvent>>{};
    final Iterable<DayEvent> sourceEvents =
        suppliedEvents ?? state.dayEventsInRange(grid.start, grid.end);

    for (final DayEvent event in sourceEvents) {
      DateTime cursor = event.normalizedStart;
      while (!cursor.isAfter(event.normalizedEnd)) {
        if (cursor.isBefore(grid.start) || cursor.isAfter(grid.end)) {
          cursor = cursor.add(const Duration(days: 1));
          continue;
        }
        byDate.putIfAbsent(cursor, () => <DayEvent>[]).add(event);
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    for (final MapEntry<DateTime, List<DayEvent>> entry in byDate.entries) {
      entry.value.sort(
        (DayEvent a, DayEvent b) =>
            a.normalizedStart.compareTo(b.normalizedStart),
      );
    }
    return byDate;
  }
}

class _MonthGrid {
  _MonthGrid._(this.start, this.end, this.weeks);

  factory _MonthGrid.forMonth(DateTime anchor) {
    final DateTime firstOfMonth = DateTime(anchor.year, anchor.month, 1);
    final DateTime lastOfMonth = DateTime(anchor.year, anchor.month + 1, 0);
    final DateTime start = firstOfMonth
        .subtract(Duration(days: firstOfMonth.weekday - DateTime.monday));
    final DateTime end = lastOfMonth.add(
      Duration(days: DateTime.sunday - lastOfMonth.weekday),
    );

    final List<List<DateTime>> weeks = <List<DateTime>>[];
    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      final List<DateTime> week = <DateTime>[];
      for (int i = 0; i < 7; i++) {
        week.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    return _MonthGrid._(start, end, weeks);
  }

  final DateTime start;
  final DateTime end;
  final List<List<DateTime>> weeks;

  Iterable<DateTime> get days sync* {
    for (final List<DateTime> week in weeks) {
      yield* week;
    }
  }
}

class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow({required this.colors});

  final ShadColorScheme colors;

  static const List<String> labels = <String>[
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: colors.mutedForeground,
    );
    final Color divider = colors.border.withValues(alpha: 0.35);
    return SizedBox(
      height: 40,
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final bool showRightBorder = entry.key != labels.length - 1;
          return Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(
                  right: BorderSide(
                    color: showRightBorder ? divider : Colors.transparent,
                    width: 1,
                  ),
                  bottom: BorderSide(color: divider, width: 1),
                ),
              ),
              child: Center(
                child: Text(
                  entry.value,
                  style: labelStyle,
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _MonthWeekRow extends StatelessWidget {
  const _MonthWeekRow({
    required this.week,
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.eventsByDate,
    required this.onDateSelected,
    required this.onCreateEvent,
    required this.onEditEvent,
  });

  final List<DateTime> week;
  final int month;
  final DateTime selectedDate;
  final DateTime today;
  final Map<DateTime, List<DayEvent>> eventsByDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onCreateEvent;
  final ValueChanged<DayEvent> onEditEvent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: week
          .map(
            (DateTime day) => Expanded(
              child: _MonthDayTile(
                date: day,
                inMonth: day.month == month,
                isToday: _isSameDay(day, today),
                isSelected: _isSameDay(day, selectedDate),
                events: eventsByDate[DateTime(day.year, day.month, day.day)] ??
                    const <DayEvent>[],
                onSelected: onDateSelected,
                onCreateEvent: onCreateEvent,
                onEditEvent: onEditEvent,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _MonthDayTile extends StatelessWidget {
  const _MonthDayTile({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onSelected,
    required this.onCreateEvent,
    required this.onEditEvent,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<DayEvent> events;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onCreateEvent;
  final ValueChanged<DayEvent> onEditEvent;

  static const int _maxVisibleEvents = 5;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final ShadTextTheme textTheme = context.textTheme;
    final Color gridColor = colors.border.withValues(alpha: 0.18);
    final Color background = isSelected
        ? calendarPrimaryColor.withValues(alpha: 0.16)
        : (inMonth ? colors.card : colors.muted.withValues(alpha: 0.1));
    final double contentOpacity = inMonth ? 1 : 0.22;
    final Color dayColor = isToday
        ? calendarPrimaryColor
        : (inMonth
            ? colors.foreground
            : colors.mutedForeground.withValues(alpha: 0.55));
    final bool highlightDay = isToday || isSelected;
    final Color badgeBackground = highlightDay
        ? calendarPrimaryColor.withValues(
            alpha: isToday ? 0.18 : 0.12,
          )
        : Colors.transparent;
    const EdgeInsets dayPadding = EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 4,
    );

    final List<DayEvent> visible = events.take(_maxVisibleEvents).toList();
    final int overflow = events.length - visible.length;

    return InkWell(
      onTap: () {
        onSelected(date);
        onCreateEvent(date);
      },
      onLongPress: () => onSelected(date),
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: background,
          border: Border(
            right: BorderSide(color: gridColor),
            bottom: BorderSide(color: gridColor),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Opacity(
          opacity: contentOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: dayPadding,
                    decoration: BoxDecoration(
                      color: badgeBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      date.day.toString(),
                      style: textTheme.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: dayColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...visible.map(
                (DayEvent event) => _DayEventBullet(
                  event: event,
                  onTap: () => onEditEvent(event),
                  dimmed: !inMonth,
                ),
              ),
              if (overflow > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+$overflow more',
                    style: textTheme.small.copyWith(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ).withTapBounce();
  }
}

class _DayEventBullet extends StatelessWidget {
  const _DayEventBullet({
    required this.event,
    required this.onTap,
    this.dimmed = false,
  });

  final DayEvent event;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final ShadTextTheme textTheme = context.textTheme;
    final double opacity = dimmed ? 0.6 : 1;

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: calendarInsetSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(calendarBorderRadius),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: calendarGutterSm),
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.small.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ).withTapBounce(),
      ),
    );
  }
}
