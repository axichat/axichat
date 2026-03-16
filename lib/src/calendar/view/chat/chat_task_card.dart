// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_linked_task_registry.dart';
import 'package:axichat/src/calendar/view/tasks/location_autocomplete.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';
import 'package:axichat/src/calendar/view/shell/responsive_helper.dart';
import 'package:axichat/src/calendar/view/tasks/base_task_tile.dart';
import 'package:axichat/src/calendar/view/tasks/edit_task_dropdown.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/tasks/task_edit_session_tracker.dart';
import 'package:axichat/src/calendar/view/tasks/task_copy_sheet.dart';
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
    this.requireImportConfirmation = false,
    this.allowChatCopy = true,
    this.canAddToPersonalCalendar = false,
    this.onCopyToPersonalCalendar,
    this.demoQuickAdd = false,
    this.isShareFragment = false,
    this.footerDetails = _emptyInlineSpans,
  }) : assert(
         !canAddToPersonalCalendar || onCopyToPersonalCalendar != null,
         'Personal calendar access must be wired explicitly when enabled.',
       );

  final CalendarTask task;
  final bool readOnly;
  final bool requireImportConfirmation;
  final bool allowChatCopy;
  final bool canAddToPersonalCalendar;
  final Future<String?> Function(CalendarTask task)? onCopyToPersonalCalendar;
  final bool demoQuickAdd;
  final bool isShareFragment;
  final List<InlineSpan> footerDetails;

  @override
  State<ChatCalendarTaskCard> createState() => _ChatCalendarTaskCardState();
}

class _ChatCalendarTaskCardState extends State<ChatCalendarTaskCard> {
  Completer<String?>? _pendingImportCompleter;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCalendarBloc, CalendarState>(
      listenWhen: (previous, current) =>
          previous.isLoading != current.isLoading,
      listener: _handleCalendarStateChanged,
      child: BlocBuilder<ChatCalendarBloc, CalendarState>(
        builder: (context, state) {
          final CalendarTask resolvedTask =
              state.model.tasks[widget.task.id] ?? widget.task;
          final bool taskInCalendar = state.model.tasks.containsKey(
            widget.task.id,
          );
          final bool tileReadOnly = widget.readOnly || !taskInCalendar;
          final TaskEditMode editMode = widget.readOnly
              ? TaskEditMode.readOnly
              : TaskEditMode.full;
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
          final bool shareFragment = widget.isShareFragment;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatCalendarTaskTile(
                task: resolvedTask,
                readOnly: tileReadOnly,
                shareFragment: shareFragment,
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
        },
      ),
    );
  }

  void _handleCalendarStateChanged(BuildContext _, CalendarState state) {
    final Completer<String?>? completer = _pendingImportCompleter;
    if (completer == null || completer.isCompleted || state.isLoading) {
      return;
    }
    if (state.importError == null &&
        state.lastImportedTaskIds.isEmpty &&
        state.lastImportedModelChecksum == null) {
      return;
    }
    _pendingImportCompleter = null;
    if (state.importError != null) {
      completer.complete(null);
      return;
    }
    completer.complete(context.read<ChatCalendarBloc>().id);
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
    final chatCalendarBloc = locate<ChatCalendarBloc>();

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
            value: chatCalendarBloc,
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
                  context.read<ChatCalendarBloc>().add(
                    CalendarEvent.taskUpdated(task: updatedTask),
                  );
                },
                onTaskDeleted: (taskId) {
                  if (!editMode.allowsFullEdits) {
                    return;
                  }
                  context.read<ChatCalendarBloc>().add(
                    CalendarEvent.taskDeleted(taskId: taskId),
                  );
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
                        context.read<ChatCalendarBloc>().add(
                          CalendarEvent.taskOccurrenceUpdated(
                            taskId: baseId,
                            occurrenceId: task.id,
                            scheduledTime: canUpdateSchedule
                                ? updatedTask.scheduledTime
                                : null,
                            duration: canUpdateSchedule
                                ? updatedTask.duration
                                : null,
                            endDate: canUpdateSchedule
                                ? updatedTask.endDate
                                : null,
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
    final onCopyToPersonalCalendar = widget.onCopyToPersonalCalendar;
    if (!widget.canAddToPersonalCalendar || onCopyToPersonalCalendar == null) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCalendarTaskCopyUnavailableMessage,
      );
      return;
    }
    final base = demoNow();
    final scheduled = DateTime(base.year, base.month, base.day + 1, 13);
    final task = CalendarTask.create(
      title: 'hang out',
      scheduledTime: scheduled,
      duration: const Duration(hours: 1),
    );
    final String? storageId = await onCopyToPersonalCalendar(task);
    if (!mounted || storageId == null) return;
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
    final onCopyToPersonalCalendar = widget.onCopyToPersonalCalendar;
    final bool canAddToPersonal =
        widget.canAddToPersonalCalendar && onCopyToPersonalCalendar != null;
    final bool canAddToChat = widget.allowChatCopy;

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

    String? personalStorageId;
    if (decision.addToPersonal && canAddToPersonal) {
      final CalendarTask personalTask = task.copyForCalendar(style);
      personalStorageId = await onCopyToPersonalCalendar(personalTask);
      if (!mounted) {
        return;
      }
    }
    String? chatStorageId;
    if (decision.addToChat && canAddToChat) {
      final CalendarTask chatTask = task.copyForCalendar(style);
      chatStorageId = await _copyTaskToCalendar(
        task: chatTask,
        style: style,
        bloc: context.read<ChatCalendarBloc>(),
      );
      if (!mounted) {
        return;
      }
    }

    if (style.isLinked && personalStorageId != null && chatStorageId != null) {
      final Set<String> linkedStorageIds = <String>{};
      linkedStorageIds.add(personalStorageId);
      linkedStorageIds.add(chatStorageId);
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
    final bool didCopy = personalStorageId != null || chatStorageId != null;
    if (didCopy) {
      FeedbackSystem.showSuccess(
        context,
        l10n.chatCalendarTaskCopySuccessMessage,
      );
    }
  }

  Future<String?> _copyTaskToCalendar({
    required CalendarTask task,
    required CalendarTaskCopyStyle style,
    required BaseCalendarBloc bloc,
  }) async {
    if (_pendingImportCompleter != null || bloc.state.isLoading) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCalendarTaskCopyUnavailableMessage,
      );
      return null;
    }
    final bool alreadyAdded = bloc.state.model.tasks.containsKey(task.id);
    if (style.isLinked && alreadyAdded) {
      final l10n = context.l10n;
      FeedbackSystem.showInfo(
        context,
        l10n.chatCalendarTaskCopyAlreadyAddedMessage,
      );
      return null;
    }
    final List<CalendarTask> tasks = <CalendarTask>[task];
    final Completer<String?> completer = Completer<String?>();
    _pendingImportCompleter = completer;
    bloc.add(CalendarEvent.tasksImported(tasks: tasks));
    try {
      return await completer.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _pendingImportCompleter = null;
      return null;
    }
  }

  void _ensureTaskImported(CalendarTask task) {
    if (context.read<ChatCalendarBloc>().state.model.tasks.containsKey(
      task.id,
    )) {
      return;
    }
    context.read<ChatCalendarBloc>().add(
      CalendarEvent.tasksImported(tasks: <CalendarTask>[task]),
    );
  }

  EdgeInsets _shareMargin() {
    final CalendarResponsiveSpec spec = ResponsiveHelper.specForSizeClass(
      context,
      CalendarSizeClass.compact,
    );
    final double vertical = spec.contentPadding.vertical / 2;
    return EdgeInsets.only(top: vertical);
  }
}

class ChatCalendarTaskTile extends BaseTaskTile<ChatCalendarBloc> {
  const ChatCalendarTaskTile({
    super.key,
    required super.task,
    required bool shareFragment,
    super.onTap,
    bool readOnly = false,
    super.marginOverride,
    super.hideActionMenu,
  }) : super(
         isGuestMode: false,
         compact: true,
         isReadOnly: readOnly,
         compactShareFragment: shareFragment,
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
