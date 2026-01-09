// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

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
import 'package:axichat/src/chat/view/widgets/chat_inline_details.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _taskFooterPaddingTop = 4.0;
const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];

class ChatCalendarTaskCard extends StatefulWidget {
  const ChatCalendarTaskCard({
    super.key,
    required this.task,
    required this.readOnly,
    this.requireImportConfirmation = false,
    this.footerDetails = _emptyInlineSpans,
  });

  final CalendarTask task;
  final bool readOnly;
  final bool requireImportConfirmation;
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
        final TaskEditMode editMode =
            widget.readOnly ? TaskEditMode.readOnly : TaskEditMode.full;
        final VoidCallback tapAction = widget.readOnly
            ? () => _showTaskEditSheet(
                  context,
                  resolvedTask,
                  editMode: editMode,
                )
            : () => _handleEditableTap(
                  resolvedTask,
                  taskInCalendar: taskInCalendar,
                  editMode: editMode,
                );
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
                child: ChatInlineDetails(details: widget.footerDetails),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showTaskEditSheet(
    BuildContext context,
    CalendarTask task, {
    required TaskEditMode editMode,
  }) async {
    final bool shouldTrackSession = editMode.allowsAnyEdits;
    if (shouldTrackSession &&
        !TaskEditSessionTracker.instance.begin(task.id, this)) {
      return;
    }
    CalendarState calendarState() => context.read<ChatCalendarBloc>().state;
    final String baseId = baseTaskIdFrom(task.id);
    final CalendarTask latestTask = calendarState().model.tasks[baseId] ?? task;
    final CalendarTask? storedTask = calendarState().model.tasks[task.id];
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
          final CalendarTaskCopyStyle copyStyle = editMode.isReadOnly
              ? CalendarTaskCopyStyle.shallowClone
              : CalendarTaskCopyStyle.linked;
          return BlocProvider.value(
            value: locate<ChatCalendarBloc>(),
            child: Builder(
              builder: (context) => EditTaskDropdown<ChatCalendarBloc>(
                task: displayTask,
                maxHeight: maxHeight,
                isSheet: true,
                editMode: editMode,
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
                  if (!editMode.allowsAnyEdits) {
                    return;
                  }
                  locate<ChatCalendarBloc>().add(
                    CalendarEvent.taskUpdated(
                      task: updatedTask,
                    ),
                  );
                },
                onTaskDeleted: (taskId) {
                  if (!editMode.allowsFullEdits) {
                    return;
                  }
                  locate<ChatCalendarBloc>().add(
                    CalendarEvent.taskDeleted(taskId: taskId),
                  );
                  Navigator.of(sheetContext).maybePop();
                },
                onOccurrenceUpdated: shouldUpdateOccurrence
                    ? (updatedTask, scope) {
                        if (!editMode.allowsAnyEdits) {
                          return;
                        }
                        final DateTime? scheduledTime = editMode.allowsFullEdits
                            ? updatedTask.scheduledTime
                            : null;
                        final Duration? duration = editMode.allowsFullEdits
                            ? updatedTask.duration
                            : null;
                        final DateTime? endDate = editMode.allowsFullEdits
                            ? updatedTask.endDate
                            : null;
                        locate<ChatCalendarBloc>().add(
                          CalendarEvent.taskOccurrenceUpdated(
                            taskId: baseId,
                            occurrenceId: task.id,
                            scheduledTime: scheduledTime,
                            duration: duration,
                            endDate: endDate,
                            checklist: updatedTask.checklist,
                            range: scope.range,
                          ),
                        );

                        final DateTime now = DateTime.now();
                        final CalendarTask seriesUpdate =
                            editMode.allowsFullEdits
                                ? latestTask.copyWith(
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
                                    modifiedAt: now,
                                  )
                                : latestTask.copyWith(
                                    checklist: updatedTask.checklist,
                                    modifiedAt: now,
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

  Future<void> _handleEditableTap(
    CalendarTask task, {
    required bool taskInCalendar,
    required TaskEditMode editMode,
  }) async {
    if (!taskInCalendar && widget.requireImportConfirmation) {
      final l10n = context.l10n;
      final approved = await confirm(
        context,
        title: l10n.chatCalendarTaskImportConfirmTitle,
        message: l10n.chatCalendarTaskImportConfirmMessage,
        confirmLabel: l10n.chatCalendarTaskImportConfirmLabel,
        cancelLabel: l10n.chatCalendarTaskImportCancelLabel,
        destructiveConfirm: false,
      );
      if (approved != true) return;
    }
    if (!mounted) return;
    if (!taskInCalendar) {
      _ensureTaskImported(task);
    }
    await _showTaskEditSheet(
      context,
      task,
      editMode: editMode,
    );
  }

  List<TaskContextAction> _inlineActionsForTask(
    CalendarTask task, {
    required CalendarTaskCopyStyle copyStyle,
  }) {
    final l10n = context.l10n;
    return <TaskContextAction>[
      TaskContextAction(
        icon: Icons.copy,
        label: l10n.chatCalendarTaskCopyActionLabel,
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
    final l10n = context.l10n;
    final CalendarStorageManager storageManager =
        context.read<CalendarStorageManager>();
    final bool canAddToPersonal = storageManager.isAuthStorageReady &&
        _maybeReadPersonalCalendarBloc() != null;
    final bool canAddToChat = _maybeReadChatCalendarBloc() != null;

    if (!canAddToPersonal && !canAddToChat) {
      FeedbackSystem.showInfo(
        context,
        l10n.chatCalendarTaskCopyUnavailableMessage,
      );
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
    if (decision.addToPersonal && _maybeReadPersonalCalendarBloc() != null) {
      final CalendarTask personalTask = task.copyForCalendar(style);
      final bool copied = _copyTaskToCalendar(
        task: personalTask,
        style: style,
        state: context.read<CalendarBloc>().state,
        dispatch: context.read<CalendarBloc>().add,
      );
      didCopy = didCopy || copied;
    }
    if (decision.addToChat && _maybeReadChatCalendarBloc() != null) {
      final CalendarTask chatTask = task.copyForCalendar(style);
      final bool copied = _copyTaskToCalendar(
        task: chatTask,
        style: style,
        state: context.read<ChatCalendarBloc>().state,
        dispatch: context.read<ChatCalendarBloc>().add,
      );
      didCopy = didCopy || copied;
    }

    if (style.isLinked) {
      final Set<String> linkedStorageIds = <String>{};
      if (decision.addToPersonal && _maybeReadPersonalCalendarBloc() != null) {
        linkedStorageIds.add(context.read<CalendarBloc>().id);
      }
      if (decision.addToChat && _maybeReadChatCalendarBloc() != null) {
        linkedStorageIds.add(context.read<ChatCalendarBloc>().id);
      }
      if (linkedStorageIds.length > 1) {
        await CalendarLinkedTaskRegistry.instance.addLinks(
          taskId: task.id,
          storageIds: linkedStorageIds,
        );
      }
    }

    if (!mounted) {
      return;
    }
    if (didCopy) {
      FeedbackSystem.showSuccess(
        context,
        l10n.chatCalendarTaskCopySuccessMessage,
      );
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
      final l10n = context.l10n;
      FeedbackSystem.showInfo(
        context,
        l10n.chatCalendarTaskCopyAlreadyAddedMessage,
      );
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
    if (context
        .read<ChatCalendarBloc>()
        .state
        .model
        .tasks
        .containsKey(task.id)) {
      return;
    }
    context.read<ChatCalendarBloc>().add(
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
