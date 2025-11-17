import 'package:flutter/material.dart';

import '../../bloc/base_calendar_bloc.dart';
import '../../bloc/calendar_event.dart';
import '../../bloc/calendar_state.dart';
import '../../models/calendar_task.dart';
import '../calendar_grid.dart';

/// Shared CalendarGrid wrapper that wires the bloc callbacks for both guest
/// and authenticated surfaces.
class CalendarGridHost<B extends BaseCalendarBloc> extends StatelessWidget {
  const CalendarGridHost({
    super.key,
    required this.state,
    required this.bloc,
    required this.onEmptySlotTapped,
    required this.onTaskDragEnd,
    required this.onDragSessionStarted,
    required this.onDragGlobalPositionChanged,
    required this.onDragSessionEnded,
    required this.cancelBucketHoverNotifier,
  });

  final CalendarState state;
  final B? bloc;
  final void Function(DateTime date, Offset position) onEmptySlotTapped;
  final void Function(CalendarTask task, DateTime date) onTaskDragEnd;
  final VoidCallback onDragSessionStarted;
  final ValueChanged<Offset> onDragGlobalPositionChanged;
  final VoidCallback onDragSessionEnded;
  final ValueNotifier<bool> cancelBucketHoverNotifier;

  @override
  Widget build(BuildContext context) {
    return CalendarGrid<B>(
      state: state,
      onEmptySlotTapped: onEmptySlotTapped,
      onTaskDragEnd: onTaskDragEnd,
      onDateSelected: (date) => bloc?.add(
        CalendarEvent.dateSelected(date: date),
      ),
      onViewChanged: (view) => bloc?.add(
        CalendarEvent.viewChanged(view: view),
      ),
      focusRequest: state.pendingFocus,
      onDragSessionStarted: onDragSessionStarted,
      onDragGlobalPositionChanged: onDragGlobalPositionChanged,
      onDragSessionEnded: onDragSessionEnded,
      cancelBucketHoverNotifier: cancelBucketHoverNotifier,
    );
  }
}
