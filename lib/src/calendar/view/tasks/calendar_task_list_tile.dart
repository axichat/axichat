// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_completion_checkbox.dart';
import 'package:axichat/src/calendar/view/grid/calendar_drag_exclude.dart';
import 'package:axichat/src/calendar/view/tasks/task_deadline_badge.dart';
import 'package:axichat/src/calendar/view/tasks/task_checklist.dart';
import 'package:axichat/src/common/ui/ui.dart';

class CalendarTaskListTile extends StatelessWidget {
  const CalendarTaskListTile({
    super.key,
    required this.task,
    this.scheduleLabel,
    this.trailing,
    this.onToggleCompletion,
    this.fillWidth = true,
  });

  final CalendarTask task;
  final String? scheduleLabel;
  final Widget? trailing;
  final ValueChanged<bool>? onToggleCompletion;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacing.m,
        context.spacing.s,
        context.spacing.s,
        context.spacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Flexible(
                fit: fillWidth ? FlexFit.tight : FlexFit.loose,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: context.textTheme.label.strong.copyWith(
                        color: task.isCompleted
                            ? calendarPrimaryColor
                            : calendarTitleColor,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (scheduleLabel != null) ...[
                      SizedBox(height: context.borderSide.width),
                      Text(
                        scheduleLabel!,
                        style: context.textTheme.labelSm.copyWith(
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
              SizedBox(width: context.spacing.xs),
              if (trailing != null) ...[
                CalendarDragExclude(child: trailing!),
                SizedBox(width: context.spacing.xs),
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
            SizedBox(height: context.spacing.xs),
            Text(
              task.description!.length > 50
                  ? '${task.description!.substring(0, 50)}...'
                  : task.description!,
              style: context.textTheme.label.copyWith(
                color: calendarSubtitleColor,
              ),
            ),
          ],
          if (task.hasChecklist) ...[
            SizedBox(height: context.spacing.xs),
            TaskChecklistProgressBar(
              progress: task.checklistProgress,
              activeColor: colors.primary,
              backgroundColor: colors.muted.withValues(alpha: 0.2),
            ),
          ],
          if (task.deadline != null) ...[
            SizedBox(height: context.spacing.m),
            TaskDeadlineBadge(deadline: task.deadline!),
          ],
          if (task.location?.isNotEmpty == true) ...[
            SizedBox(height: context.spacing.xs),
            Row(
              mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Text('📍', style: context.textTheme.label),
                Flexible(
                  fit: fillWidth ? FlexFit.tight : FlexFit.loose,
                  child: Text(
                    task.location!,
                    style: context.textTheme.label.copyWith(
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
