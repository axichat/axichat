import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/base_calendar_bloc.dart';
import '../task_sidebar.dart';

/// Wraps [TaskSidebar] with the provided [BaseCalendarBloc] so drag sessions
/// can be handled consistently in both authenticated and guest calendars.
class CalendarSidebarHost<B extends BaseCalendarBloc> extends StatelessWidget {
  const CalendarSidebarHost({
    super.key,
    required this.bloc,
    required this.sidebarKey,
    required this.onDragSessionStarted,
    required this.onDragSessionEnded,
    required this.onDragGlobalPositionChanged,
    this.onOpenCriticalPathSandbox,
  });

  final B? bloc;
  final GlobalKey<TaskSidebarState> sidebarKey;
  final VoidCallback onDragSessionStarted;
  final VoidCallback onDragSessionEnded;
  final ValueChanged<Offset> onDragGlobalPositionChanged;
  final ValueChanged<String>? onOpenCriticalPathSandbox;

  @override
  Widget build(BuildContext context) {
    final B? resolvedBloc = bloc;
    if (resolvedBloc == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider<BaseCalendarBloc>.value(
      value: resolvedBloc,
      child: TaskSidebar(
        key: sidebarKey,
        onDragSessionStarted: onDragSessionStarted,
        onDragSessionEnded: onDragSessionEnded,
        onDragGlobalPositionChanged: onDragGlobalPositionChanged,
        onOpenCriticalPathSandbox: onOpenCriticalPathSandbox,
      ),
    );
  }
}
