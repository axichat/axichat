// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/chat/view/widgets/calendar_critical_path_copy_sheet.dart';
import 'package:axichat/src/chat/view/widgets/calendar_fragment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];
const String _criticalPathCopyUnavailableMessage = 'Calendar is unavailable.';
const String _criticalPathCopySuccessMessage = 'Critical path copied.';

class ChatCalendarCriticalPathCard extends StatelessWidget {
  const ChatCalendarCriticalPathCard({
    super.key,
    required this.path,
    required this.tasks,
    this.footerDetails = _emptyInlineSpans,
  });

  final CalendarCriticalPath path;
  final List<CalendarTask> tasks;
  final List<InlineSpan> footerDetails;

  @override
  Widget build(BuildContext context) {
    return CalendarFragmentCard(
      fragment: CalendarFragment.criticalPath(
        path: path,
        tasks: tasks,
      ),
      footerDetails: footerDetails,
      onTap: () => _handleCopy(context),
    );
  }

  Future<void> _handleCopy(BuildContext context) async {
    final CalendarStorageManager storageManager =
        context.read<CalendarStorageManager>();
    final bool canAddToPersonal = storageManager.isAuthStorageReady &&
        _maybeReadPersonalCalendarBloc(context) != null;
    final bool canAddToChat = _maybeReadChatCalendarBloc(context) != null;

    if (!canAddToPersonal && !canAddToChat) {
      FeedbackSystem.showInfo(context, _criticalPathCopyUnavailableMessage);
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
    if (!context.mounted || decision == null) {
      return;
    }

    final CalendarModel importModel = _buildImportModel();
    if (decision.addToPersonal &&
        _maybeReadPersonalCalendarBloc(context) != null) {
      context.read<CalendarBloc>().add(
            CalendarEvent.modelImported(
              model: importModel,
            ),
          );
    }
    if (decision.addToChat && _maybeReadChatCalendarBloc(context) != null) {
      context.read<ChatCalendarBloc>().add(
            CalendarEvent.modelImported(
              model: importModel,
            ),
          );
    }

    FeedbackSystem.showSuccess(context, _criticalPathCopySuccessMessage);
  }

  CalendarModel _buildImportModel() {
    final Set<String> availableIds = tasks.map((task) => task.id).toSet();
    final List<String> orderedIds =
        path.taskIds.where(availableIds.contains).toList(growable: false);
    final CalendarCriticalPath resolvedPath =
        path.copyWith(taskIds: orderedIds);
    final Map<String, CalendarTask> taskMap = <String, CalendarTask>{
      for (final task in tasks) task.id: task,
    };
    final CalendarModel base = CalendarModel.empty();
    final CalendarModel withTasks =
        taskMap.isEmpty ? base : base.replaceTasks(taskMap);
    return withTasks.addCriticalPath(resolvedPath);
  }

  CalendarBloc? _maybeReadPersonalCalendarBloc(BuildContext context) {
    try {
      return context.read<CalendarBloc>();
    } on FlutterError {
      return null;
    }
  }

  ChatCalendarBloc? _maybeReadChatCalendarBloc(BuildContext context) {
    try {
      return context.read<ChatCalendarBloc>();
    } on FlutterError {
      return null;
    }
  }
}
