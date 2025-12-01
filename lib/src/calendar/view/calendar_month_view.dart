import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';

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
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekdayHeaderRow(colors: colors),
          const Divider(height: 1),
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

  final ColorScheme colors;

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: labels
            .map(
              (String label) => Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.secondary,
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
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

  static const int _maxVisibleEvents = 3;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color borderColor = colors.outlineVariant;
    final Color background = isSelected
        ? colors.primaryContainer.withValues(alpha: 0.45)
        : colors.surface;
    final Color badgeColor =
        isToday ? colors.primary : colors.secondaryContainer;

    final List<DayEvent> visible = events.take(_maxVisibleEvents).toList();
    final int overflow = events.length - visible.length;

    return InkWell(
      onTap: () => onSelected(date),
      onLongPress: () => onCreateEvent(date),
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: background,
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday ? colors.primary : borderColor,
                    ),
                  ),
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? colors.primary
                          : (inMonth
                              ? colors.onSurface
                              : colors.outline.withValues(alpha: 0.8)),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  tooltip: 'Add day event',
                  onPressed: () => onCreateEvent(date),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...visible.map(
              (DayEvent event) => _DayEventPill(
                event: event,
                onTap: () => onEditEvent(event),
              ),
            ),
            if (overflow > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$overflow more',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayEventPill extends StatelessWidget {
  const _DayEventPill({required this.event, required this.onTap});

  final DayEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String label = event.normalizedStart == event.normalizedEnd
        ? event.title
        : '${event.title} (${_rangeLabel(event)})';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSecondaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _rangeLabel(DayEvent event) {
    final DateTime start = event.normalizedStart;
    final DateTime end = event.normalizedEnd;
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}-${end.day}';
    }
    final String startLabel = TimeFormatter.formatFriendlyDate(start);
    final String endLabel = TimeFormatter.formatFriendlyDate(end);
    return '$startLabel → $endLabel';
  }
}
