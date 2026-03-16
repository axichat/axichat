// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/calendar_state_waiter.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/critical_path_copy_sheet.dart';
import 'package:axichat/src/calendar/view/fragment_card.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];

class ChatCalendarCriticalPathCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CalendarFragmentCard(
      fragment: CalendarFragment.criticalPath(path: path, tasks: tasks),
      footerDetails: footerDetails,
      onTap: () => _handleCopy(context),
    );
  }

  Future<void> _handleCopy(BuildContext context) async {
    if (!canAddToPersonal && !canAddToChat) {
      FeedbackSystem.showInfo(
        context,
        context.l10n.chatCriticalPathCopyUnavailableMessage,
      );
      return;
    }

    final CalendarCriticalPathCopyDecision? decision =
        await showCalendarCriticalPathCopySheet(
          context: context,
          path: path,
          tasks: tasks,
          canAddToPersonal: canAddToPersonal,
          canAddToChat: canAddToChat,
        );
    if (decision == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final CalendarModel importModel = _importModel();
    final CalendarCriticalPath? importPath = importModel.criticalPaths[path.id];
    final Set<String> taskIds = <String>{}
      ..addAll(importPath?.taskIds ?? const <String>[]);
    final onCopyToPersonalCalendar = this.onCopyToPersonalCalendar;
    final bool canCopyToPersonal =
        canAddToPersonal && onCopyToPersonalCalendar != null;
    final bool canCopyToChat = canAddToChat;
    bool didCopy = false;
    if (decision.addToPersonal && canCopyToPersonal) {
      final bool copied = await onCopyToPersonalCalendar(
        importModel,
        path.id,
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
        pathId: path.id,
        taskIds: taskIds,
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
    final Set<String> availableIds = tasks.map((task) => task.id).toSet();
    final List<String> orderedIds = path.taskIds
        .where(availableIds.contains)
        .toList(growable: false);
    final CalendarCriticalPath resolvedPath = path.copyWith(
      taskIds: orderedIds,
    );
    final Map<String, CalendarTask> taskMap = <String, CalendarTask>{
      for (final task in tasks) task.id: task,
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
    required String pathId,
    required Set<String> taskIds,
  }) async {
    bloc.add(CalendarEvent.modelImported(model: model));
    return waitForCriticalPathTasks(
      bloc: bloc,
      pathId: pathId,
      taskIds: taskIds,
    );
  }
}
