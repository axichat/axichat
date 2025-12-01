import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/view/calendar_month_view.dart';
import 'package:axichat/src/calendar/view/widgets/day_event_editor.dart';

class CalendarMonthHost<B extends BaseCalendarBloc> extends StatelessWidget {
  const CalendarMonthHost({
    super.key,
    required this.state,
  });

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final _MonthViewport viewport =
        _MonthViewport.forAnchor(state.selectedDate);
    final List<DayEvent> visibleEvents =
        state.dayEventsInRange(viewport.start, viewport.end);
    return CalendarMonthView(
      state: state,
      visibleEvents: visibleEvents,
      onDateSelected: (DateTime date) =>
          context.read<B>().add(CalendarEvent.dateSelected(date: date)),
      onCreateEvent: (DateTime date) => _openComposer(
        context,
        initialDate: date,
      ),
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
    final B? targetBloc = context.read<B?>();
    if (targetBloc == null) {
      return;
    }
    targetBloc.add(CalendarEvent.dateSelected(date: initialDate));
    final DayEventEditorResult? result = await showDayEventEditor(
      context: context,
      initialDate: initialDate,
      existing: existing,
    );
    if (result == null) {
      return;
    }
    if (result.deleted && existing != null) {
      targetBloc.add(CalendarEvent.dayEventDeleted(eventId: existing.id));
      return;
    }
    final DayEventDraft? draft = result.draft;
    if (draft == null) {
      return;
    }

    if (existing == null) {
      targetBloc.add(
        CalendarEvent.dayEventAdded(
          title: draft.title,
          startDate: draft.startDate,
          endDate: draft.endDate,
          description: draft.description,
          reminders: draft.reminders,
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
      modifiedAt: DateTime.now(),
    );
    targetBloc.add(CalendarEvent.dayEventUpdated(event: updated));
  }
}

class _MonthViewport {
  const _MonthViewport({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  factory _MonthViewport.forAnchor(DateTime anchor) {
    final DateTime monthStart = DateTime(anchor.year, anchor.month, 1);
    final DateTime leading = monthStart
        .subtract(Duration(days: monthStart.weekday - DateTime.monday));
    final DateTime monthEnd = DateTime(anchor.year, anchor.month + 1, 0);
    final DateTime trailing = monthEnd.add(
      Duration(days: DateTime.sunday - monthEnd.weekday),
    );
    return _MonthViewport(start: leading, end: trailing);
  }
}
