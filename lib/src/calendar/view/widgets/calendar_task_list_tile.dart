// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
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
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.s,
                vertical: context.spacing.xs,
              ),
              decoration: BoxDecoration(
                color: _deadlineBackgroundColor(task.deadline!),
                borderRadius: context.radius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: context.sizing.menuItemIconSize,
                    color: _deadlineColor(task.deadline!),
                  ),
                  SizedBox(width: context.spacing.xs),
                  Text(
                    _deadlineLabel(context.l10n, task.deadline!),
                    style: context.textTheme.label.strong.copyWith(
                      color: _deadlineColor(task.deadline!),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
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
