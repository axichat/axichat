import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';

class CalendarTaskFeedbackObserver<B extends BaseCalendarBloc>
    extends StatefulWidget {
  const CalendarTaskFeedbackObserver({super.key, required this.child});

  final Widget child;

  @override
  State<CalendarTaskFeedbackObserver<B>> createState() =>
      _CalendarTaskFeedbackObserverState<B>();
}

class _CalendarTaskFeedbackObserverState<B extends BaseCalendarBloc>
    extends State<CalendarTaskFeedbackObserver<B>> {
  Map<String, CalendarTask> _lastTasks = const <String, CalendarTask>{};
  bool _initialized = false;
  bool _awaitingUndoRemoval = false;
  Set<String> _expectedRemovalIds = const <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = context.read<B>();
    _lastTasks = Map<String, CalendarTask>.from(bloc.state.model.tasks);
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<B>();
    return BlocListener<B, CalendarState>(
      bloc: bloc,
      listenWhen: (previous, current) =>
          !mapEquals(previous.model.tasks, current.model.tasks),
      listener: (context, state) {
        if (!_initialized) {
          _lastTasks = Map<String, CalendarTask>.from(state.model.tasks);
          _initialized = true;
          return;
        }
        _handleModelChanges(context, state, bloc);
      },
      child: widget.child,
    );
  }

  void _handleModelChanges(
    BuildContext context,
    CalendarState state,
    B bloc,
  ) {
    final currentTasks = state.model.tasks;
    final added = <CalendarTask>[];
    final removed = <CalendarTask>[];

    currentTasks.forEach((id, task) {
      if (!_lastTasks.containsKey(id)) {
        added.add(task);
      }
    });
    _lastTasks.forEach((id, task) {
      if (!currentTasks.containsKey(id)) {
        removed.add(task);
      }
    });

    if (added.isNotEmpty) {
      _showAddedFeedback(context, added, bloc);
    }

    if (removed.isNotEmpty) {
      _showRemovedFeedback(context, removed, bloc);
    }

    _lastTasks = Map<String, CalendarTask>.from(currentTasks);
  }

  void _showAddedFeedback(
    BuildContext context,
    List<CalendarTask> tasks,
    B bloc,
  ) {
    final message = tasks.length == 1
        ? 'Task "${tasks.first.title}" added'
        : '${tasks.length} tasks added';
    FeedbackSystem.showSuccess(
      context,
      message,
      actionLabel: 'Undo',
      onAction: () {
        _awaitingUndoRemoval = true;
        _expectedRemovalIds = tasks.map((task) => task.id).toSet();
        bloc.add(const CalendarEvent.undoRequested());
      },
    );
  }

  void _showRemovedFeedback(
    BuildContext context,
    List<CalendarTask> tasks,
    B bloc,
  ) {
    final removedIds = tasks.map((task) => task.id).toSet();
    final removalMatchesUndo = _awaitingUndoRemoval &&
        removedIds.containsAll(_expectedRemovalIds) &&
        _expectedRemovalIds.containsAll(removedIds);

    _awaitingUndoRemoval = false;
    _expectedRemovalIds = const <String>{};

    final message = tasks.length == 1
        ? 'Task "${tasks.first.title}" removed'
        : '${tasks.length} tasks removed';

    FeedbackSystem.showWarning(
      context,
      message,
      title: 'Task removed',
      actionLabel: 'Undo',
      onAction: () {
        if (removalMatchesUndo) {
          bloc.add(const CalendarEvent.redoRequested());
        } else {
          bloc.add(const CalendarEvent.undoRequested());
        }
      },
    );
  }
}
