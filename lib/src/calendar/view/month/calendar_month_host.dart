// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/view/month/calendar_month_view.dart';
import 'package:axichat/src/calendar/view/month/day_event_editor.dart';

class CalendarMonthHost extends StatelessWidget {
  const CalendarMonthHost({
    super.key,
    required this.state,
    required this.onEvent,
  });

  final CalendarState state;
  final ValueChanged<CalendarEvent> onEvent;

  @override
  Widget build(BuildContext context) {
    final _MonthViewport viewport = _MonthViewport.forAnchor(
      state.selectedDate,
    );
    final List<DayEvent> visibleEvents = state.dayEventsInRange(
      viewport.start,
      viewport.end,
    );
    return CalendarMonthView(
      state: state,
      visibleEvents: visibleEvents,
      onDateSelected: (DateTime date) =>
          onEvent(CalendarEvent.dateSelected(date: date)),
      onCreateEvent: (DateTime date) =>
          _openComposer(context, initialDate: date),
      onEditEvent: (DayEvent event) => _openComposer(
        context,
        initialDate: event.normalizedStart,
        existing: event,
      ),
    );
  }

  Future<void> _openComposer(
    BuildContext context, {
    required DateTime initialDate,
    DayEvent? existing,
  }) async {
    onEvent(CalendarEvent.dateSelected(date: initialDate));
    final DayEventEditorResult? result = await showDayEventEditor(
      context: context,
      initialDate: initialDate,
      existing: existing,
    );
    if (result == null) {
      return;
    }
    if (result.deleted && existing != null) {
      onEvent(CalendarEvent.dayEventDeleted(eventId: existing.id));
      return;
    }
    final DayEventDraft? draft = result.draft;
    if (draft == null) {
      return;
    }

    if (existing == null) {
      onEvent(
        CalendarEvent.dayEventAdded(
          title: draft.title,
          startDate: draft.startDate,
          endDate: draft.endDate,
          description: draft.description,
          reminders: draft.reminders,
          icsMeta: draft.icsMeta,
        ),
      );
      return;
    }

    final DayEvent updated = existing.normalizedCopy(
      title: draft.title,
      startDate: draft.startDate,
      endDate: draft.endDate,
      description: draft.description,
      reminders: draft.reminders,
      icsMeta: draft.icsMeta,
      modifiedAt: DateTime.now(),
    );
    onEvent(CalendarEvent.dayEventUpdated(event: updated));
  }
}

class _MonthViewport {
  const _MonthViewport({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory _MonthViewport.forAnchor(DateTime anchor) {
    final DateTime monthStart = DateTime(anchor.year, anchor.month, 1);
    final DateTime leading = monthStart.subtract(
      Duration(days: monthStart.weekday - DateTime.monday),
    );
    final DateTime monthEnd = DateTime(anchor.year, anchor.month + 1, 0);
    final DateTime trailing = monthEnd.add(
      Duration(days: DateTime.sunday - monthEnd.weekday),
    );
    return _MonthViewport(start: leading, end: trailing);
  }
}
