import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/view/task_sidebar.dart';

/// Wraps [TaskSidebar] with the provided [BaseCalendarBloc] so drag sessions
/// can be handled consistently in both authenticated and guest calendars.
class CalendarSidebarHost<B extends BaseCalendarBloc> extends StatelessWidget {
  const CalendarSidebarHost({
    super.key,
    required this.sidebarKey,
    required this.onDragSessionStarted,
    required this.onDragSessionEnded,
    required this.onDragGlobalPositionChanged,
  });

  final GlobalKey<TaskSidebarState<B>> sidebarKey;
  final VoidCallback onDragSessionStarted;
  final VoidCallback onDragSessionEnded;
  final ValueChanged<Offset> onDragGlobalPositionChanged;

  @override
  Widget build(BuildContext context) {
    return TaskSidebar<B>(
      key: sidebarKey,
      onDragSessionStarted: onDragSessionStarted,
      onDragSessionEnded: onDragSessionEnded,
      onDragGlobalPositionChanged: onDragGlobalPositionChanged,
    );
  }
}
