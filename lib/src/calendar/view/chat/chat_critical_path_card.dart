// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/sidebar/critical_path_copy_sheet.dart';
import 'package:axichat/src/calendar/view/tasks/fragment_card.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];

class ChatCalendarCriticalPathCard extends StatefulWidget {
  const ChatCalendarCriticalPathCard({
    super.key,
    required this.path,
    required this.tasks,
    required this.canAddToPersonal,
    required this.canAddToChat,
    this.onCopyToPersonalCalendar,
    this.footerDetails = _emptyInlineSpans,
  }) : assert(
         !canAddToPersonal || onCopyToPersonalCalendar != null,
         'Personal calendar access must be wired explicitly when enabled.',
       );

  final CalendarCriticalPath path;
  final List<CalendarTask> tasks;
  final List<InlineSpan> footerDetails;
  final bool canAddToPersonal;
  final bool canAddToChat;
  final Future<bool> Function(
    CalendarModel model,
    String pathId,
    Set<String> taskIds,
  )?
  onCopyToPersonalCalendar;

  @override
  State<ChatCalendarCriticalPathCard> createState() =>
      _ChatCalendarCriticalPathCardState();
}

class _ChatCalendarCriticalPathCardState
    extends State<ChatCalendarCriticalPathCard> {
  final Map<String, Completer<bool>> _pendingImportCompleters =
      <String, Completer<bool>>{};
  int _handledImportOutcomeToken = 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCalendarBloc, CalendarState>(
      listener: _handleCalendarStateChanged,
      child: CalendarFragmentCard(
        fragment: CalendarFragment.criticalPath(
          path: widget.path,
          tasks: widget.tasks,
        ),
        footerDetails: widget.footerDetails,
        onTap: () => _handleCopy(context),
      ),
    );
  }

  Future<void> _handleCopy(BuildContext context) async {
    if (!widget.canAddToPersonal && !widget.canAddToChat) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCriticalPathCopyUnavailableMessage,
      );
      return;
    }

    final CalendarCriticalPathCopyDecision? decision =
        await showCalendarCriticalPathCopySheet(
          context: context,
          path: widget.path,
          tasks: widget.tasks,
          canAddToPersonal: widget.canAddToPersonal,
          canAddToChat: widget.canAddToChat,
        );
    if (decision == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final CalendarModel importModel = _importModel();
    final CalendarCriticalPath? importPath =
        importModel.criticalPaths[widget.path.id];
    final Set<String> taskIds = <String>{}
      ..addAll(importPath?.taskIds ?? const <String>[]);
    final onCopyToPersonalCalendar = widget.onCopyToPersonalCalendar;
    final bool canCopyToPersonal =
        widget.canAddToPersonal && onCopyToPersonalCalendar != null;
    final bool canCopyToChat = widget.canAddToChat;
    bool didCopy = false;
    if (decision.addToPersonal && canCopyToPersonal) {
      final bool copied = await onCopyToPersonalCalendar(
        importModel,
        widget.path.id,
        taskIds,
      );
      didCopy = didCopy || copied;
    }
    if (decision.addToChat && canCopyToChat) {
      if (!context.mounted) {
        return;
      }
      final bool copied = await _copyCriticalPathToCalendar(
        bloc: context.read<ChatCalendarBloc>(),
        model: importModel,
      );
      didCopy = didCopy || copied;
    }

    if (!context.mounted) {
      return;
    }
    if (didCopy) {
      FeedbackSystem.showSuccess(
        context,
        context.l10n.chatCriticalPathCopySuccessMessage,
      );
    }
  }

  CalendarModel _importModel() {
    final Set<String> availableIds = widget.tasks
        .map((task) => task.id)
        .toSet();
    final List<String> orderedIds = widget.path.taskIds
        .where(availableIds.contains)
        .toList(growable: false);
    final CalendarCriticalPath resolvedPath = widget.path.copyWith(
      taskIds: orderedIds,
    );
    final Map<String, CalendarTask> taskMap = <String, CalendarTask>{
      for (final task in widget.tasks) task.id: task,
    };
    final CalendarModel base = CalendarModel.empty();
    final CalendarModel withTasks = taskMap.isEmpty
        ? base
        : base.replaceTasks(taskMap);
    return withTasks.addCriticalPath(resolvedPath);
  }

  Future<bool> _copyCriticalPathToCalendar({
    required BaseCalendarBloc bloc,
    required CalendarModel model,
  }) async {
    final String requestId = const Uuid().v4();
    final Completer<bool> completer = Completer<bool>();
    _pendingImportCompleters[requestId] = completer;
    bloc.add(CalendarEvent.modelImported(requestId: requestId, model: model));
    try {
      return await completer.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _pendingImportCompleters.remove(requestId);
      return false;
    }
  }

  void _handleCalendarStateChanged(BuildContext _, CalendarState state) {
    if (state.importOutcomeToken == _handledImportOutcomeToken) {
      return;
    }
    _handledImportOutcomeToken = state.importOutcomeToken;
    final String? requestId = state.importRequestId;
    if (requestId == null) {
      return;
    }
    final Completer<bool>? completer = _pendingImportCompleters.remove(
      requestId,
    );
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(state.importError == null);
  }
}
