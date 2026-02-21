// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
    final Map<DateTime, List<DayEvent>> eventsByDate = _eventsForGrid(
      grid,
      visibleEvents,
    );
    final ShadColorScheme colors = context.colorScheme;
    final BorderSide border = BorderSide(
      color: colors.border.withValues(alpha: 0.35),
    );
    final CalendarResponsiveSpec spec = ResponsiveHelper.spec(context);
    final bool chatCalendar =
        _isChatCalendar(context) &&
        spec.sizeClass != CalendarSizeClass.expanded;
    final Border gridBorder = chatCalendar
        ? Border(
            right: BorderSide(color: border.color),
            bottom: BorderSide(color: border.color),
          )
        : Border(
            left: BorderSide(color: border.color),
            right: BorderSide(color: border.color),
            bottom: BorderSide(color: border.color),
          );

    return Container(
      decoration: BoxDecoration(color: colors.card, border: gridBorder),
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

  bool _isChatCalendar(BuildContext context) {
    try {
      context.read<ChatCalendarBloc>();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _MonthGrid {
  _MonthGrid._(this.start, this.end, this.weeks);

  factory _MonthGrid.forMonth(DateTime anchor) {
    final DateTime firstOfMonth = DateTime(anchor.year, anchor.month, 1);
    final DateTime lastOfMonth = DateTime(anchor.year, anchor.month + 1, 0);
    final DateTime start = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - DateTime.monday),
    );
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

  @override
  Widget build(BuildContext context) {
    final List<String> labels =
        [
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
              DateTime.saturday,
              DateTime.sunday,
            ]
            .map((weekday) {
              final List<String> localized = MaterialLocalizations.of(
                context,
              ).narrowWeekdays;
              return localized[weekday % localized.length];
            })
            .toList(growable: false);
    final TextStyle labelStyle = context.textTheme.sectionLabelM.copyWith(
      color: colors.mutedForeground,
    );
    final Color divider = colors.border.withValues(alpha: 0.35);
    return SizedBox(
      height: calendarWeekHeaderHeight,
      child: Row(
        children: labels
            .asMap()
            .entries
            .map((entry) {
              final bool showRightBorder = entry.key != labels.length - 1;
              return Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.card,
                    border: Border(
                      right: BorderSide(
                        color: showRightBorder ? divider : Colors.transparent,
                        width: context.borderSide.width,
                      ),
                      bottom: BorderSide(
                        color: divider,
                        width: context.borderSide.width,
                      ),
                    ),
                  ),
                  child: Center(child: Text(entry.value, style: labelStyle)),
                ),
              );
            })
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
                events:
                    eventsByDate[DateTime(day.year, day.month, day.day)] ??
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
        ? calendarPrimaryColor.withValues(alpha: isToday ? 0.18 : 0.12)
        : Colors.transparent;
    final spacing = context.spacing;
    final EdgeInsets dayPadding = EdgeInsets.symmetric(
      horizontal: spacing.s,
      vertical: spacing.xs,
    );

    final List<DayEvent> visible = events.take(_maxVisibleEvents).toList();
    final int overflow = events.length - visible.length;

    final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
    );
    return AxiTapBounce(
      child: ShadFocusable(
        canRequestFocus: true,
        builder: (context, _, _) {
          return Material(
            type: MaterialType.transparency,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: ShadGestureDetector(
              cursor: SystemMouseCursors.click,
              onTap: () {
                onSelected(date);
                onCreateEvent(date);
              },
              onLongPress: () => onSelected(date),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: calendarMonthCellMinHeight,
                ),
                decoration: BoxDecoration(
                  color: background,
                  border: Border(
                    right: BorderSide(color: gridColor),
                    bottom: BorderSide(color: gridColor),
                  ),
                ),
                padding: EdgeInsets.all(context.spacing.s),
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
                              borderRadius: BorderRadius.circular(
                                context.radii.container,
                              ),
                            ),
                            child: Text(
                              date.day.toString(),
                              style: textTheme.small.strong.copyWith(
                                color: dayColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.xs),
                      ...visible.map(
                        (DayEvent event) => _DayEventBullet(
                          event: event,
                          onTap: () => onEditEvent(event),
                          dimmed: !inMonth,
                        ),
                      ),
                      if (overflow > 0)
                        Padding(
                          padding: EdgeInsets.only(top: spacing.xs),
                          child: Text(
                            context.l10n.calendarMonthOverflowMore(overflow),
                            style: textTheme.labelSm.strong.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
    final spacing = context.spacing;
    final double opacity = dimmed ? 0.6 : 1;
    final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
    );

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: EdgeInsets.only(bottom: spacing.xxs),
        child: AxiTapBounce(
          child: ShadFocusable(
            canRequestFocus: true,
            builder: (context, _, _) {
              return Material(
                type: MaterialType.transparency,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: ShadGestureDetector(
                  cursor: SystemMouseCursors.click,
                  onTap: onTap,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: spacing.xs),
                        child: Container(
                          width: spacing.s,
                          height: spacing.s,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSm.strong.copyWith(
                            color: colors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
