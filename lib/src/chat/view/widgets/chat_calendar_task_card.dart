// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_linked_task_registry.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/utils/calendar_state_waiter.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/view/base_task_tile.dart';
import 'package:axichat/src/calendar/view/edit_task_dropdown.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/models/task_context_action.dart';
import 'package:axichat/src/calendar/view/task_edit_session_tracker.dart';
import 'package:axichat/src/chat/view/widgets/calendar_task_copy_sheet.dart';
import 'package:axichat/src/chat/view/widgets/chat_inline_details.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/demo/demo_mode.dart';
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
    required this.storageManager,
    required this.personalCalendarBloc,
    required this.chatCalendarBloc,
    this.requireImportConfirmation = false,
    this.allowChatCopy = true,
    this.demoQuickAdd = false,
    this.isShareFragment = false,
    this.footerDetails = _emptyInlineSpans,
  });

  final CalendarTask task;
  final bool readOnly;
  final CalendarStorageManager storageManager;
  final CalendarBloc? personalCalendarBloc;
  final ChatCalendarBloc? chatCalendarBloc;
  final bool requireImportConfirmation;
  final bool allowChatCopy;
  final bool demoQuickAdd;
  final bool isShareFragment;
  final List<InlineSpan> footerDetails;

  @override
  State<ChatCalendarTaskCard> createState() => _ChatCalendarTaskCardState();
}

class _ChatCalendarTaskCardState extends State<ChatCalendarTaskCard> {
  @override
  Widget build(BuildContext context) {
    final chatBloc = widget.chatCalendarBloc;
    if (chatBloc == null) {
      return _buildTaskCard(
        context,
        resolvedTask: widget.task,
        taskInCalendar: false,
        editMode: TaskEditMode.readOnly,
        allowEdit: false,
      );
    }
    return BlocBuilder<ChatCalendarBloc, CalendarState>(
      bloc: chatBloc,
      builder: (context, state) {
        final CalendarTask resolvedTask =
            state.model.tasks[widget.task.id] ?? widget.task;
        final bool taskInCalendar = state.model.tasks.containsKey(
          widget.task.id,
        );
        final bool allowEdit = !widget.readOnly;
        final TaskEditMode editMode =
            widget.readOnly ? TaskEditMode.readOnly : TaskEditMode.full;
        return _buildTaskCard(
          context,
          resolvedTask: resolvedTask,
          taskInCalendar: taskInCalendar,
          editMode: editMode,
          allowEdit: allowEdit,
        );
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context, {
    required CalendarTask resolvedTask,
    required bool taskInCalendar,
    required TaskEditMode editMode,
    required bool allowEdit,
  }) {
    final bool tileReadOnly =
        widget.readOnly || !taskInCalendar || widget.chatCalendarBloc == null;
    final VoidCallback? tapAction = allowEdit && widget.chatCalendarBloc != null
        ? () => _handleEditableTap(
              resolvedTask,
              taskInCalendar: taskInCalendar,
              editMode: editMode,
            )
        : widget.readOnly && widget.chatCalendarBloc != null
            ? () => _showTaskEditSheet(
                  context,
                  resolvedTask,
                  editMode: editMode,
                )
            : null;
    final bool shareFragment = widget.isShareFragment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatCalendarTaskTile(
          task: resolvedTask,
          readOnly: tileReadOnly,
          onTap: tapAction,
          marginOverride: shareFragment ? _shareMargin() : null,
          hideActionMenu: shareFragment,
        ),
        if (widget.footerDetails.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: _taskFooterPaddingTop),
            child: ChatInlineDetails(details: widget.footerDetails),
          ),
      ],
    );
  }

  Future<void> _showTaskEditSheet(
    BuildContext context,
    CalendarTask task, {
    required TaskEditMode editMode,
  }) async {
    final chatBloc = widget.chatCalendarBloc;
    if (chatBloc == null) {
      return;
    }
    final bool shouldTrackSession = editMode.allowsAnyEdits;
    if (shouldTrackSession &&
        !TaskEditSessionTracker.instance.begin(task.id, this)) {
      return;
    }
    CalendarState calendarState() => chatBloc.state;
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
    final CalendarTaskCopyStyle copyStyle = editMode.isReadOnly
        ? CalendarTaskCopyStyle.shallowClone
        : CalendarTaskCopyStyle.linked;
    final List<TaskContextAction> inlineActions = _inlineActionsForTask(
      displayTask,
      copyStyle: copyStyle,
    );
    final LocationAutocompleteHelper locationHelper =
        LocationAutocompleteHelper.fromState(calendarState());
    final CalendarMethod? collectionMethod =
        calendarState().model.collection?.method;

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
            value: chatBloc,
            child: Builder(
              builder: (context) => EditTaskDropdown<ChatCalendarBloc>(
                task: displayTask,
                maxHeight: maxHeight,
                isSheet: true,
                editMode: editMode,
                inlineActions: inlineActions,
                collectionMethod: collectionMethod,
                onClose: () => Navigator.of(sheetContext).maybePop(),
                scaffoldMessenger: scaffoldMessenger,
                locationHelper: locationHelper,
                onTaskUpdated: (updatedTask) {
                  if (!editMode.allowsAnyEdits) {
                    return;
                  }
                  chatBloc.add(CalendarEvent.taskUpdated(task: updatedTask));
                },
                onTaskDeleted: (taskId) {
                  if (!editMode.allowsFullEdits) {
                    return;
                  }
                  chatBloc.add(CalendarEvent.taskDeleted(taskId: taskId));
                  Navigator.of(sheetContext).maybePop();
                },
                onOccurrenceUpdated: shouldUpdateOccurrence
                    ? (
                        updatedTask,
                        scope, {
                        required bool scheduleTouched,
                        required bool checklistTouched,
                      }) {
                        if (!editMode.allowsAnyEdits) {
                          return;
                        }
                        final bool canUpdateSchedule =
                            editMode.allowsFullEdits && scheduleTouched;
                        final bool canUpdateChecklist =
                            editMode.allowsChecklistEdits && checklistTouched;
                        if (!canUpdateSchedule && !canUpdateChecklist) {
                          return;
                        }
                        chatBloc.add(
                          CalendarEvent.taskOccurrenceUpdated(
                            taskId: baseId,
                            occurrenceId: task.id,
                            scheduledTime: canUpdateSchedule
                                ? updatedTask.scheduledTime
                                : null,
                            duration:
                                canUpdateSchedule ? updatedTask.duration : null,
                            endDate:
                                canUpdateSchedule ? updatedTask.endDate : null,
                            checklist: canUpdateChecklist
                                ? updatedTask.checklist
                                : null,
                            range: scope.range,
                          ),
                        );
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
    if (widget.demoQuickAdd) {
      await _handleDemoQuickAdd();
      return;
    }
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
    await _showTaskEditSheet(context, task, editMode: editMode);
  }

  Future<void> _handleDemoQuickAdd() async {
    if (!kEnableDemoChats) return;
    final CalendarBloc? personalBloc = _maybeReadPersonalCalendarBloc();
    if (personalBloc == null) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCalendarTaskCopyUnavailableMessage,
      );
      return;
    }
    final base = demoNow();
    final scheduled = DateTime(
      base.year,
      base.month,
      base.day + 1,
      13,
    );
    final task = CalendarTask.create(
      title: 'hang out',
      scheduledTime: scheduled,
      duration: const Duration(hours: 1),
    );
    personalBloc.add(CalendarEvent.tasksImported(tasks: <CalendarTask>[task]));
    await waitForTasksInCalendar(
      bloc: personalBloc,
      taskIds: <String>{task.id},
    );
    if (!mounted) return;
    FeedbackSystem.showSuccess(
      context,
      context.l10n.chatCalendarTaskCopySuccessMessage,
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
        onSelected: () async {
          await _handleCopyTask(task: task, style: copyStyle);
        },
      ),
    ];
  }

  Future<void> _handleCopyTask({
    required CalendarTask task,
    required CalendarTaskCopyStyle style,
  }) async {
    final l10n = context.l10n;
    final CalendarStorageManager storageManager = widget.storageManager;
    final bool canAddToPersonal = storageManager.isAuthStorageReady &&
        widget.personalCalendarBloc != null;
    final bool canAddToChat =
        widget.allowChatCopy && widget.chatCalendarBloc != null;

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
    if (!mounted) {
      return;
    }
    if (decision == null) {
      return;
    }

    final CalendarBloc? personalBloc = widget.personalCalendarBloc;
    final ChatCalendarBloc? chatBloc = widget.chatCalendarBloc;
    bool didCopy = false;
    if (decision.addToPersonal && personalBloc != null) {
      final CalendarTask personalTask = task.copyForCalendar(style);
      final bool copied = await _copyTaskToCalendar(
        task: personalTask,
        style: style,
        bloc: personalBloc,
      );
      didCopy = didCopy || copied;
    }
    if (decision.addToChat && chatBloc != null) {
      final CalendarTask chatTask = task.copyForCalendar(style);
      final bool copied = await _copyTaskToCalendar(
        task: chatTask,
        style: style,
        bloc: chatBloc,
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

  Future<bool> _copyTaskToCalendar({
    required CalendarTask task,
    required CalendarTaskCopyStyle style,
    required BaseCalendarBloc bloc,
  }) async {
    final bool alreadyAdded = bloc.state.model.tasks.containsKey(task.id);
    if (style.isLinked && alreadyAdded) {
      final l10n = context.l10n;
      FeedbackSystem.showInfo(
        context,
        l10n.chatCalendarTaskCopyAlreadyAddedMessage,
      );
      return false;
    }
    final List<CalendarTask> tasks = <CalendarTask>[task];
    bloc.add(CalendarEvent.tasksImported(tasks: tasks));
    final Set<String> taskIds = <String>{}..add(task.id);
    return waitForTasksInCalendar(bloc: bloc, taskIds: taskIds);
  }

  CalendarBloc? _maybeReadPersonalCalendarBloc() {
    return widget.personalCalendarBloc;
  }

  ChatCalendarBloc? _maybeReadChatCalendarBloc() {
    return widget.chatCalendarBloc;
  }

  void _ensureTaskImported(CalendarTask task) {
    final chatBloc = widget.chatCalendarBloc;
    if (chatBloc == null) {
      return;
    }
    if (chatBloc.state.model.tasks.containsKey(task.id)) {
      return;
    }
    chatBloc.add(CalendarEvent.tasksImported(tasks: <CalendarTask>[task]));
  }

  EdgeInsets _shareMargin() {
    final CalendarResponsiveSpec spec =
        ResponsiveHelper.specForSizeClass(CalendarSizeClass.compact);
    final double vertical = spec.contentPadding.vertical / 2;
    return EdgeInsets.only(top: vertical);
  }
}

class ChatCalendarTaskTile extends BaseTaskTile<ChatCalendarBloc> {
  const ChatCalendarTaskTile({
    super.key,
    required super.task,
    super.onTap,
    bool readOnly = false,
    super.marginOverride,
    super.hideActionMenu,
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
