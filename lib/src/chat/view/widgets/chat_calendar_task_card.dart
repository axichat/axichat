import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_linked_task_registry.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/view/base_task_tile.dart';
import 'package:axichat/src/calendar/view/edit_task_dropdown.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/models/task_context_action.dart';
import 'package:axichat/src/calendar/view/task_edit_session_tracker.dart';
import 'package:axichat/src/chat/view/widgets/calendar_task_copy_sheet.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _taskFooterPaddingTop = 4.0;
const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];
const String _taskCopyActionLabel = 'Copy to calendar';
const String _taskCopyUnavailableMessage = 'Calendar is unavailable.';
const String _taskCopyAlreadyAddedMessage = 'Task already added.';
const String _taskCopySuccessMessage = 'Task copied.';

class ChatCalendarTaskCard extends StatefulWidget {
  const ChatCalendarTaskCard({
    super.key,
    required this.task,
    required this.readOnly,
    this.footerDetails = _emptyInlineSpans,
  });

  final CalendarTask task;
  final bool readOnly;
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
        final bool taskInCalendar =
            state.model.tasks.containsKey(widget.task.id);
        final bool tileReadOnly = widget.readOnly || !taskInCalendar;
        final VoidCallback tapAction = widget.readOnly
            ? () => _showTaskEditSheet(
                  context,
                  resolvedTask,
                  readOnly: true,
                )
            : () {
                _ensureTaskImported(resolvedTask);
                _showTaskEditSheet(context, resolvedTask);
              };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatCalendarTaskTile(
              task: resolvedTask,
              readOnly: tileReadOnly,
              onTap: tapAction,
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
    CalendarTask task, {
    bool readOnly = false,
  }) async {
    final bool shouldTrackSession = !readOnly;
    if (shouldTrackSession &&
        !TaskEditSessionTracker.instance.begin(task.id, this)) {
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
          final CalendarTaskCopyStyle copyStyle = readOnly
              ? CalendarTaskCopyStyle.shallowClone
              : CalendarTaskCopyStyle.linked;
          return BlocProvider.value(
            value: locate<ChatCalendarBloc>(),
            child: Builder(
              builder: (context) => EditTaskDropdown<ChatCalendarBloc>(
                task: displayTask,
                maxHeight: maxHeight,
                isSheet: true,
                readOnly: readOnly,
                inlineActionsBloc: locate<ChatCalendarBloc>(),
                inlineActionsBuilder: (_) => _inlineActionsForTask(
                  displayTask,
                  copyStyle: copyStyle,
                ),
                onClose: () => Navigator.of(sheetContext).maybePop(),
                scaffoldMessenger: scaffoldMessenger,
                locationHelper: LocationAutocompleteHelper.fromState(
                  locate<ChatCalendarBloc>().state,
                ),
                onTaskUpdated: (updatedTask) {
                  if (readOnly) {
                    return;
                  }
                  locate<ChatCalendarBloc>().add(
                    CalendarEvent.taskUpdated(
                      task: updatedTask,
                    ),
                  );
                },
                onTaskDeleted: (taskId) {
                  if (readOnly) {
                    return;
                  }
                  locate<ChatCalendarBloc>().add(
                    CalendarEvent.taskDeleted(taskId: taskId),
                  );
                  Navigator.of(sheetContext).maybePop();
                },
                onOccurrenceUpdated: shouldUpdateOccurrence
                    ? (updatedTask, scope) {
                        if (readOnly) {
                          return;
                        }
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
      if (shouldTrackSession) {
        TaskEditSessionTracker.instance.end(task.id, this);
      }
    }
  }

  List<TaskContextAction> _inlineActionsForTask(
    CalendarTask task, {
    required CalendarTaskCopyStyle copyStyle,
  }) {
    return <TaskContextAction>[
      TaskContextAction(
        icon: Icons.copy,
        label: _taskCopyActionLabel,
        onSelected: () => unawaited(
          _handleCopyTask(
            task: task,
            style: copyStyle,
          ),
        ),
      ),
    ];
  }

  Future<void> _handleCopyTask({
    required CalendarTask task,
    required CalendarTaskCopyStyle style,
  }) async {
    final CalendarBloc? personalBloc = _maybeReadPersonalCalendarBloc();
    final ChatCalendarBloc? chatBloc = _maybeReadChatCalendarBloc();
    final CalendarStorageManager storageManager =
        context.read<CalendarStorageManager>();
    final bool canAddToPersonal =
        storageManager.isAuthStorageReady && personalBloc != null;
    final bool canAddToChat = chatBloc != null;

    if (!canAddToPersonal && !canAddToChat) {
      FeedbackSystem.showInfo(context, _taskCopyUnavailableMessage);
      return;
    }

    final CalendarTaskCopyDecision? decision = await showCalendarTaskCopySheet(
      context: context,
      task: task,
      canAddToPersonal: canAddToPersonal,
      canAddToChat: canAddToChat,
    );
    if (!mounted || decision == null) {
      return;
    }

    bool didCopy = false;
    if (decision.addToPersonal && personalBloc != null) {
      final CalendarTask personalTask = task.copyForCalendar(style);
      final bool copied = _copyTaskToCalendar(
        task: personalTask,
        style: style,
        state: personalBloc.state,
        dispatch: personalBloc.add,
      );
      didCopy = didCopy || copied;
    }
    if (decision.addToChat && chatBloc != null) {
      final CalendarTask chatTask = task.copyForCalendar(style);
      final bool copied = _copyTaskToCalendar(
        task: chatTask,
        style: style,
        state: chatBloc.state,
        dispatch: chatBloc.add,
      );
      didCopy = didCopy || copied;
    }

    if (style.isLinked) {
      final Set<String> linkedStorageIds = <String>{};
      if (decision.addToPersonal && personalBloc != null) {
        linkedStorageIds.add(personalBloc.id);
      }
      if (decision.addToChat && chatBloc != null) {
        linkedStorageIds.add(chatBloc.id);
      }
      if (linkedStorageIds.length > 1) {
        await CalendarLinkedTaskRegistry.instance.addLinks(
          taskId: task.id,
          storageIds: linkedStorageIds,
        );
      }
    }

    if (didCopy) {
      FeedbackSystem.showSuccess(context, _taskCopySuccessMessage);
    }
  }

  bool _copyTaskToCalendar({
    required CalendarTask task,
    required CalendarTaskCopyStyle style,
    required CalendarState state,
    required void Function(CalendarEvent event) dispatch,
  }) {
    final bool alreadyAdded = state.model.tasks.containsKey(task.id);
    if (style.isLinked && alreadyAdded) {
      FeedbackSystem.showInfo(context, _taskCopyAlreadyAddedMessage);
      return false;
    }
    final List<CalendarTask> tasks = <CalendarTask>[task];
    dispatch(
      CalendarEvent.tasksImported(
        tasks: tasks,
      ),
    );
    return true;
  }

  CalendarBloc? _maybeReadPersonalCalendarBloc() {
    try {
      return context.read<CalendarBloc>();
    } on FlutterError {
      return null;
    }
  }

  ChatCalendarBloc? _maybeReadChatCalendarBloc() {
    try {
      return context.read<ChatCalendarBloc>();
    } on FlutterError {
      return null;
    }
  }

  void _ensureTaskImported(CalendarTask task) {
    final ChatCalendarBloc bloc = context.read<ChatCalendarBloc>();
    if (bloc.state.model.tasks.containsKey(task.id)) {
      return;
    }
    bloc.add(
      CalendarEvent.tasksImported(
        tasks: <CalendarTask>[task],
      ),
    );
  }
}

class ChatCalendarTaskTile extends BaseTaskTile<ChatCalendarBloc> {
  const ChatCalendarTaskTile({
    super.key,
    required super.task,
    super.onTap,
    bool readOnly = false,
  }) : super(
          isGuestMode: false,
          compact: true,
          isReadOnly: readOnly,
        );

  @override
  State<ChatCalendarTaskTile> createState() => _ChatCalendarTaskTileState();
}

class _ChatCalendarTaskTileState
    extends BaseTaskTileState<ChatCalendarTaskTile, ChatCalendarBloc> {
  @override
  void showEditTaskInput(BuildContext context, CalendarTask task) {
    widget.onTap?.call();
  }
}
