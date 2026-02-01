// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_completion_checkbox.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_drag_exclude.dart';
import 'package:axichat/src/calendar/view/widgets/task_checklist.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

class CalendarTaskListTile extends StatelessWidget {
  const CalendarTaskListTile({
    super.key,
    required this.task,
    this.scheduleLabel,
    this.trailing,
    this.onToggleCompletion,
  });

  final CalendarTask task;
  final String? scheduleLabel;
  final Widget? trailing;
  final ValueChanged<bool>? onToggleCompletion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: context.textTheme.small.copyWith(
                        color: task.isCompleted
                            ? calendarPrimaryColor
                            : calendarTitleColor,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (scheduleLabel != null) ...[
                      const SizedBox(height: calendarInsetSm),
                      Text(
                        scheduleLabel!,
                        style: context.textTheme.caption.copyWith(
                          color: task.isCompleted
                              ? calendarPrimaryColor
                              : calendarSubtitleColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: calendarInsetMd),
              if (trailing != null) ...[
                CalendarDragExclude(child: trailing!),
                const SizedBox(width: calendarInsetMd),
              ],
              CalendarDragExclude(
                child: CalendarCompletionCheckbox(
                  value: task.isCompleted,
                  onChanged: onToggleCompletion,
                ),
              ),
            ],
          ),
          if (task.description?.isNotEmpty == true) ...[
            const SizedBox(height: calendarInsetMd),
            Text(
              task.description!.length > 50
                  ? '${task.description!.substring(0, 50)}...'
                  : task.description!,
              style: context.textTheme.caption.copyWith(
                color: calendarSubtitleColor,
              ),
            ),
          ],
          if (task.hasChecklist) ...[
            const SizedBox(height: calendarInsetMd),
            TaskChecklistProgressBar(
              progress: task.checklistProgress,
              activeColor: colors.primary,
              backgroundColor: colors.muted.withValues(alpha: 0.2),
            ),
          ],
          if (task.deadline != null) ...[
            const SizedBox(height: calendarGutterLg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterSm,
                vertical: calendarInsetMd,
              ),
              decoration: BoxDecoration(
                color: _deadlineBackgroundColor(task.deadline!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: _deadlineColor(task.deadline!),
                  ),
                  const SizedBox(width: calendarInsetMd),
                  Text(
                    _deadlineLabel(context.l10n, task.deadline!),
                    style: context.textTheme.caption.strong.copyWith(
                      color: _deadlineColor(task.deadline!),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (task.location?.isNotEmpty == true) ...[
            const SizedBox(height: calendarInsetMd),
            Row(
              children: [
                Text(
                  '📍',
                  style: context.textTheme.caption.copyWith(height: 1),
                ),
                Expanded(
                  child: Text(
                    task.location!,
                    style: context.textTheme.caption.copyWith(
                      color: calendarSubtitleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Color _deadlineColor(DateTime deadline) {
  final now = DateTime.now();
  if (deadline.isBefore(now)) {
    return calendarDangerColor;
  } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
    return calendarWarningColor;
  }
  return calendarPrimaryColor;
}

Color _deadlineBackgroundColor(DateTime deadline) {
  final now = DateTime.now();
  if (deadline.isBefore(now)) {
    return calendarDangerColor.withValues(alpha: 0.1);
  } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
    return calendarWarningColor.withValues(alpha: 0.1);
  }
  return calendarPrimaryColor.withValues(alpha: 0.08);
}

String _deadlineLabel(AppLocalizations l10n, DateTime deadline) {
  return TimeFormatter.formatFriendlyDateTime(l10n, deadline);
}
