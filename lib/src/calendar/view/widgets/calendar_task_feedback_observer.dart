// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

class CalendarTaskFeedbackObserver<B extends BaseCalendarBloc>
    extends StatefulWidget {
  const CalendarTaskFeedbackObserver({
    super.key,
    required this.child,
    required this.initialTasks,
    required this.onEvent,
  });

  final Widget child;
  final Map<String, CalendarTask> initialTasks;
  final ValueChanged<CalendarEvent> onEvent;

  @override
  State<CalendarTaskFeedbackObserver<B>> createState() =>
      _CalendarTaskFeedbackObserverState<B>();
}

class _CalendarTaskFeedbackObserverState<B extends BaseCalendarBloc>
    extends State<CalendarTaskFeedbackObserver<B>> {
  Map<String, CalendarTask> _lastTasks = const <String, CalendarTask>{};
  DateTime? _lastSyncTime;
  bool _awaitingUndoRemoval = false;
  Set<String> _expectedRemovalIds = const <String>{};
  B? _bloc;

  @override
  void initState() {
    super.initState();
    _lastTasks = Map<String, CalendarTask>.from(widget.initialTasks);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final B bloc = context.read<B>();
    if (identical(_bloc, bloc)) {
      return;
    }
    _bloc = bloc;
    _lastTasks = Map<String, CalendarTask>.from(widget.initialTasks);
    _lastSyncTime = bloc.state.lastSyncTime;
    _awaitingUndoRemoval = false;
    _expectedRemovalIds = const <String>{};
  }

  @override
  void didUpdateWidget(covariant CalendarTaskFeedbackObserver<B> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onEvent != widget.onEvent) {
      _lastTasks = Map<String, CalendarTask>.from(widget.initialTasks);
      _lastSyncTime = _bloc?.state.lastSyncTime;
      _awaitingUndoRemoval = false;
      _expectedRemovalIds = const <String>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<B, CalendarState>(
      listenWhen: (previous, current) =>
          previous.lastSyncTime != current.lastSyncTime ||
          !mapEquals(previous.model.tasks, current.model.tasks),
      listener: (context, state) {
        _handleModelChanges(context, state);
      },
      child: widget.child,
    );
  }

  void _handleModelChanges(BuildContext context, CalendarState state) {
    final currentTasks = state.model.tasks;
    final bool syncDrivenChange = state.lastSyncTime != _lastSyncTime;
    final bool tasksChanged = !mapEquals(_lastTasks, currentTasks);
    if (!tasksChanged) {
      _lastSyncTime = state.lastSyncTime;
      return;
    }
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

    if (!syncDrivenChange && added.isNotEmpty) {
      _showAddedFeedback(context, added);
    }

    if (!syncDrivenChange && removed.isNotEmpty) {
      _showRemovedFeedback(context, removed);
    }

    _lastTasks = Map<String, CalendarTask>.from(currentTasks);
    _lastSyncTime = state.lastSyncTime;
  }

  void _showAddedFeedback(BuildContext context, List<CalendarTask> tasks) {
    final l10n = context.l10n;
    final message = tasks.length == 1
        ? l10n.calendarTaskAddedMessage(tasks.first.title)
        : l10n.calendarTasksAddedMessage(tasks.length);
    FeedbackSystem.showSuccess(
      context,
      message,
      actionLabel: l10n.calendarUndo,
      onAction: () {
        _awaitingUndoRemoval = true;
        _expectedRemovalIds = tasks.map((task) => task.id).toSet();
        widget.onEvent(const CalendarEvent.undoRequested());
      },
    );
  }

  void _showRemovedFeedback(BuildContext context, List<CalendarTask> tasks) {
    final l10n = context.l10n;
    final removedIds = tasks.map((task) => task.id).toSet();
    final removalMatchesUndo =
        _awaitingUndoRemoval &&
        removedIds.containsAll(_expectedRemovalIds) &&
        _expectedRemovalIds.containsAll(removedIds);

    _awaitingUndoRemoval = false;
    _expectedRemovalIds = const <String>{};

    final message = tasks.length == 1
        ? l10n.calendarTaskRemovedMessage(tasks.first.title)
        : l10n.calendarTasksRemovedMessage(tasks.length);

    FeedbackSystem.showWarning(
      context,
      message,
      title: l10n.calendarTaskRemovedTitle,
      actionLabel: l10n.calendarUndo,
      onAction: () {
        if (removalMatchesUndo) {
          widget.onEvent(const CalendarEvent.redoRequested());
        } else {
          widget.onEvent(const CalendarEvent.undoRequested());
        }
      },
    );
  }
}
