import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/view/base_task_tile.dart';
import 'package:axichat/src/calendar/view/edit_task_dropdown.dart';
import 'package:axichat/src/calendar/view/task_edit_session_tracker.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _taskFooterPaddingTop = 4.0;
const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];

class ChatCalendarTaskCard extends StatefulWidget {
  const ChatCalendarTaskCard({
    super.key,
    required this.task,
    this.footerDetails = _emptyInlineSpans,
  });

  final CalendarTask task;
  final List<InlineSpan> footerDetails;

  @override
  State<ChatCalendarTaskCard> createState() => _ChatCalendarTaskCardState();
}

class _ChatCalendarTaskCardState extends State<ChatCalendarTaskCard> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCalendarBloc, CalendarState>(
      builder: (context, state) {
        final CalendarTask resolvedTask =
            state.model.tasks[widget.task.id] ?? widget.task;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatCalendarTaskTile(
              task: resolvedTask,
              onTap: () => _showTaskEditSheet(context, resolvedTask),
            ),
            if (widget.footerDetails.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: _taskFooterPaddingTop),
                child: Text.rich(
                  TextSpan(children: widget.footerDetails),
                  style: context.textTheme.muted,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showTaskEditSheet(
    BuildContext context,
    CalendarTask task,
  ) async {
    if (!TaskEditSessionTracker.instance.begin(task.id, this)) {
      return;
    }
    final ChatCalendarBloc bloc = context.read<ChatCalendarBloc>();
    final String baseId = baseTaskIdFrom(task.id);
    final CalendarTask latestTask = bloc.state.model.tasks[baseId] ?? task;
    final CalendarTask? storedTask = bloc.state.model.tasks[task.id];
    final String? occurrenceKey = occurrenceKeyFrom(task.id);
    final CalendarTask? occurrenceTask =
        storedTask == null && occurrenceKey != null
            ? latestTask.occurrenceForId(task.id)
            : null;
    final CalendarTask displayTask = storedTask ?? occurrenceTask ?? latestTask;
    final bool shouldUpdateOccurrence =
        storedTask == null && occurrenceTask != null;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final locate = context.read;

    try {
      await showAdaptiveBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        showCloseButton: false,
        builder: (sheetContext) {
          final mediaQuery = MediaQuery.of(sheetContext);
          final double maxHeight =
              mediaQuery.size.height - mediaQuery.viewPadding.vertical;
          return BlocProvider.value(
            value: locate<ChatCalendarBloc>(),
            child: Builder(
              builder: (context) => EditTaskDropdown<ChatCalendarBloc>(
                task: displayTask,
                maxHeight: maxHeight,
                isSheet: true,
                onClose: () => Navigator.of(sheetContext).maybePop(),
                scaffoldMessenger: scaffoldMessenger,
                locationHelper: LocationAutocompleteHelper.fromState(
                    locate<ChatCalendarBloc>().state),
                onTaskUpdated: (updatedTask) {
                  locate<ChatCalendarBloc>().add(
                    CalendarEvent.taskUpdated(
                      task: updatedTask,
                    ),
                  );
                },
                onTaskDeleted: (taskId) {
                  locate<ChatCalendarBloc>().add(
                    CalendarEvent.taskDeleted(taskId: taskId),
                  );
                  Navigator.of(sheetContext).maybePop();
                },
                onOccurrenceUpdated: shouldUpdateOccurrence
                    ? (updatedTask, scope) {
                        locate<ChatCalendarBloc>().add(
                          CalendarEvent.taskOccurrenceUpdated(
                            taskId: baseId,
                            occurrenceId: task.id,
                            scheduledTime: updatedTask.scheduledTime,
                            duration: updatedTask.duration,
                            endDate: updatedTask.endDate,
                            checklist: updatedTask.checklist,
                            range: scope.range,
                          ),
                        );

                        final CalendarTask seriesUpdate = latestTask.copyWith(
                          title: updatedTask.title,
                          description: updatedTask.description,
                          location: updatedTask.location,
                          deadline: updatedTask.deadline,
                          priority: updatedTask.priority,
                          isCompleted: updatedTask.isCompleted,
                          checklist: updatedTask.checklist,
                          recurrence: updatedTask.recurrence,
                          reminders: updatedTask.reminders,
                          icsMeta: updatedTask.icsMeta,
                          modifiedAt: DateTime.now(),
                        );

                        if (seriesUpdate != latestTask) {
                          locate<ChatCalendarBloc>().add(
                            CalendarEvent.taskUpdated(
                              task: seriesUpdate,
                            ),
                          );
                        }
                      }
                    : null,
              ),
            ),
          );
        },
      );
    } finally {
      TaskEditSessionTracker.instance.end(task.id, this);
    }
  }
}

class ChatCalendarTaskTile extends BaseTaskTile<ChatCalendarBloc> {
  const ChatCalendarTaskTile({
    super.key,
    required super.task,
    super.onTap,
  }) : super(
          isGuestMode: false,
          compact: true,
        );

  @override
  State<ChatCalendarTaskTile> createState() => _ChatCalendarTaskTileState();
}

class _ChatCalendarTaskTileState
    extends BaseTaskTileState<ChatCalendarTaskTile, ChatCalendarBloc> {
  bool _imported = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureTaskImported();
  }

  @override
  void didUpdateWidget(covariant ChatCalendarTaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _imported = false;
    }
  }

  void _ensureTaskImported() {
    if (_imported) {
      return;
    }
    final ChatCalendarBloc bloc = context.read<ChatCalendarBloc>();
    if (bloc.state.model.tasks.containsKey(widget.task.id)) {
      _imported = true;
      return;
    }
    bloc.add(
      CalendarEvent.tasksImported(
        tasks: <CalendarTask>[widget.task],
      ),
    );
    _imported = true;
  }

  @override
  void showEditTaskInput(BuildContext context, CalendarTask task) {
    widget.onTap?.call();
  }
}
