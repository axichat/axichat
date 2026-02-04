// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'feedback_system.dart';
import 'widgets/calendar_completion_checkbox.dart';
import 'widgets/calendar_task_title_hover_reporter.dart';
import 'widgets/task_checklist.dart';
import 'widgets/calendar_task_list_tile.dart';
import 'widgets/task_tile_surface.dart';

const bool _calendarUseRootNavigator = false;

abstract class BaseTaskTile<T extends BaseCalendarBloc> extends StatefulWidget {
  const BaseTaskTile({
    super.key,
    required this.task,
    required this.isGuestMode,
    this.onTap,
    this.isReadOnly = false,
    this.compact = false,
    this.marginOverride,
    this.hideActionMenu = false,
  });

  final CalendarTask task;
  final bool isGuestMode;
  final VoidCallback? onTap;
  final bool isReadOnly;
  final bool compact;
  final EdgeInsets? marginOverride;
  final bool hideActionMenu;
}

abstract class BaseTaskTileState<W extends BaseTaskTile<T>,
    T extends BaseCalendarBloc> extends State<W> {
  bool _isUpdating = false;

  void showEditTaskInput(BuildContext context, CalendarTask task);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<T, CalendarState>(
      listener: (context, state) {
        if (!state.isLoading && _isUpdating) {
          setState(() => _isUpdating = false);
          if (state.error == null) {
            FeedbackSystem.showSuccess(
              context,
              widget.task.isCompleted
                  ? l10n.calendarTaskCompletedMessage
                  : l10n.calendarTaskUpdatedMessage,
            );
          }
        }
      },
      child: AnimatedOpacity(
        opacity: _isUpdating ? 0.6 : 1.0,
        duration: calendarSlotHoverAnimationDuration,
        child: Builder(
          builder: (context) {
            final CalendarResponsiveSpec spec = widget.compact
                ? ResponsiveHelper.specForSizeClass(CalendarSizeClass.compact)
                : ResponsiveHelper.spec(context);
            final EdgeInsets margin =
                widget.marginOverride ?? _tileMargin(spec);
            final CalendarTask task = widget.task;
            final bool isReadOnly = widget.isReadOnly;
            final Color taskColor = _getTaskColor(task);
            final Color statusColor = _getStatusColor(context);
            final String statusText = _getStatusText(l10n);
            final DateTime? scheduledTime = task.scheduledTime;
            final String? timeLabel = scheduledTime != null
                ? TimeFormatter.formatDateTime(scheduledTime)
                : null;
            final String? durationLabel = task.duration != null
                ? _formatDuration(context, task.duration!)
                : null;
            final Color timeColor = _getTimeColor(context);
            final FontWeight? timeFontWeight =
                _isOverdue() ? FontWeight.bold : null;
            void handleEdit() {
              showEditTaskInput(context, task);
            }

            void handleDelete() {
              _showDeleteConfirmation(context);
            }

            void handleToggleCompletion(bool completed) {
              _toggleTaskCompletion(context, completed);
            }

            final bool hideActions = widget.hideActionMenu;
            final VoidCallback? editAction =
                (isReadOnly || hideActions) ? null : handleEdit;
            final VoidCallback? deleteAction =
                (isReadOnly || hideActions) ? null : handleDelete;
            final ValueChanged<bool>? toggleAction =
                isReadOnly ? null : handleToggleCompletion;

            late final Widget tile;
            switch (spec.sizeClass) {
              case CalendarSizeClass.compact:
                tile = _CompactTaskTile(
                  task: task,
                  margin: margin,
                  onTap: widget.onTap,
                  taskColor: taskColor,
                  isUpdating: _isUpdating,
                  onToggleCompletion: toggleAction,
                  timeLabel: timeLabel,
                  timeColor: timeColor,
                  timeFontWeight: timeFontWeight,
                  onEdit: editAction,
                  onDelete: deleteAction,
                );
              case CalendarSizeClass.medium:
                tile = _MediumTaskTile(
                  task: task,
                  margin: margin,
                  onTap: widget.onTap,
                  taskColor: taskColor,
                  isUpdating: _isUpdating,
                  onToggleCompletion: toggleAction,
                  timeLabel: timeLabel,
                  onEdit: editAction,
                  onDelete: deleteAction,
                );
              case CalendarSizeClass.expanded:
                tile = _FullTaskTile(
                  task: task,
                  margin: margin,
                  onTap: widget.onTap,
                  isUpdating: _isUpdating,
                  onToggleCompletion: toggleAction,
                  statusColor: statusColor,
                  statusText: statusText,
                  timeLabel: timeLabel,
                  timeColor: timeColor,
                  timeFontWeight: timeFontWeight,
                  durationLabel: durationLabel,
                  onEdit: editAction,
                  onDelete: deleteAction,
                );
            }
            return CalendarTaskTitleHoverReporter(
              title: task.title,
              enabled: !_isUpdating,
              child: tile,
            );
          },
        ),
      ),
    );
  }

  EdgeInsets _tileMargin(CalendarResponsiveSpec spec) {
    final double horizontal = spec.contentPadding.left;
    final double vertical = spec.contentPadding.vertical / 2;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  void _showDeleteConfirmation(BuildContext context) {
    final locate = context.read;
    showFadeScaleDialog(
      context: context,
      useRootNavigator: _calendarUseRootNavigator,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.calendarDeleteTask),
        content: Text(
          dialogContext.l10n.calendarDeleteTaskConfirm(widget.task.title),
        ),
        actions: [
          AxiButton.secondary(
            onPressed: () => Navigator.of(dialogContext).maybePop(),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          AxiButton.destructive(
            onPressed: () {
              locate<T>().add(
                CalendarEvent.taskDeleted(taskId: widget.task.id),
              );
              Navigator.of(dialogContext).maybePop();
            },
            child: Text(dialogContext.l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _toggleTaskCompletion(BuildContext context, bool completed) {
    if (_isUpdating) {
      return;
    }
    setState(() => _isUpdating = true);
    final String baseId = widget.task.baseId;
    context.read<T>().add(
          CalendarEvent.taskCompleted(taskId: baseId, completed: completed),
        );
  }

  String _formatDuration(BuildContext context, Duration duration) {
    return TimeFormatter.formatDurationShort(context.l10n, duration);
  }

  Color _getTimeColor(BuildContext context) {
    if (widget.task.isCompleted) return calendarPrimaryColor;
    if (_isOverdue()) return calendarDangerColor;
    if (_isDueSoon()) return calendarWarningColor;
    return calendarTimeLabelColor;
  }

  Color _getStatusColor(BuildContext context) {
    if (widget.task.isCompleted) return taskCompletedColor;
    if (_isOverdue()) return calendarDangerColor;
    if (_isDueSoon()) return calendarWarningColor;
    return widget.task.priorityColor;
  }

  String _getStatusText(AppLocalizations l10n) {
    if (widget.task.isCompleted) return l10n.calendarStatusCompleted;
    if (_isOverdue()) return l10n.calendarStatusOverdue;
    if (_isDueSoon()) return l10n.calendarStatusDueSoon;
    return l10n.calendarStatusPending;
  }

  bool _isOverdue() {
    if (widget.task.scheduledTime == null || widget.task.isCompleted) {
      return false;
    }
    return widget.task.scheduledTime!.isBefore(DateTime.now());
  }

  bool _isDueSoon() {
    if (widget.task.scheduledTime == null || widget.task.isCompleted) {
      return false;
    }
    final now = DateTime.now();
    final twoHoursFromNow = now.add(const Duration(hours: 2));
    return widget.task.scheduledTime!.isAfter(now) &&
        widget.task.scheduledTime!.isBefore(twoHoursFromNow);
  }

  Color _getTaskColor(CalendarTask task) {
    return task.priorityColor;
  }
}

class _CompactTaskTile extends StatelessWidget {
  const _CompactTaskTile({
    required this.task,
    required this.margin,
    required this.onTap,
    required this.taskColor,
    required this.isUpdating,
    required this.onToggleCompletion,
    required this.timeLabel,
    required this.timeColor,
    required this.timeFontWeight,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarTask task;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color taskColor;
  final bool isUpdating;
  final ValueChanged<bool>? onToggleCompletion;
  final String? timeLabel;
  final Color timeColor;
  final FontWeight? timeFontWeight;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final Color indicatorColor =
        task.isCompleted ? taskCompletedColor : taskColor;
    final bool showActions = onEdit != null || onDelete != null;
    final double stripWidth = context.spacing.xs;
    final l10n = context.l10n;
    final String? scheduleLabel = _compactTaskScheduleLabel(
      l10n,
      task,
    );
    return TaskTileSurface(
      margin: margin,
      decoration: BoxDecoration(
        color: calendarContainerColor,
        boxShadow: calendarLightShadow,
        border: Border.all(
          color: calendarBorderColor,
          width: context.borderSide.width,
        ),
      ),
      leadingStripeColor: indicatorColor,
      leadingStripeWidth: stripWidth,
      onTap: onTap,
      child: IntrinsicHeight(
        child: Padding(
          padding: EdgeInsets.only(
            left: context.spacing.s + context.spacing.xs,
          ),
          child: CalendarTaskListTile(
            task: task,
            scheduleLabel: scheduleLabel,
            trailing: showActions
                ? _TaskActionMenu(
                    onEdit: onEdit,
                    onDelete: onDelete,
                    showIcons: false,
                    iconSize: context.sizing.iconButtonIconSize,
                  )
                : null,
            onToggleCompletion: onToggleCompletion,
          ),
        ),
      ),
    );
  }
}

String? _compactTaskScheduleLabel(
  AppLocalizations l10n,
  CalendarTask task,
) {
  final DateTime? start = task.scheduledTime;
  if (start == null) {
    return null;
  }
  final DateTime? end = task.effectiveEndDate;
  if (end != null && end.isAfter(start)) {
    if (DateUtils.isSameDay(start, end)) {
      final String dateLabel = TimeFormatter.formatFriendlyDate(start);
      final String startTime = TimeFormatter.formatTime(start);
      final String endTime = TimeFormatter.formatTime(end);
      return '$dateLabel · $startTime – $endTime';
    }
    final String startLabel = TimeFormatter.formatFriendlyDate(start);
    final String endLabel = TimeFormatter.formatFriendlyDate(end);
    return '$startLabel → $endLabel';
  }
  return TimeFormatter.formatFriendlyDateTime(l10n, start);
}

class _MediumTaskTile extends StatelessWidget {
  const _MediumTaskTile({
    required this.task,
    required this.margin,
    required this.onTap,
    required this.taskColor,
    required this.isUpdating,
    required this.onToggleCompletion,
    required this.timeLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarTask task;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color taskColor;
  final bool isUpdating;
  final ValueChanged<bool>? onToggleCompletion;
  final String? timeLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final sizing = context.sizing;
    final Color backgroundColor =
        task.isCompleted ? taskCompletedColor : taskColor;
    final Brightness textBrightness =
        ThemeData.estimateBrightnessForColor(backgroundColor);
    final Color textColor = textBrightness == Brightness.dark
        ? colors.primaryForeground
        : colors.foreground;
    final Color progressTrack = textColor.withValues(alpha: 0.25);
    final bool showActions = onEdit != null || onDelete != null;
    final TextStyle titleStyle = textTheme.p.copyWith(
      color: textColor,
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
    );
    final TextStyle timeStyle = textTheme.small.copyWith(
      color: textColor.withValues(alpha: 0.9),
    );
    return TaskTileSurface(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.radius,
        boxShadow: calendarLightShadow,
      ),
      onTap: onTap,
      child: Padding(
        padding: calendarPaddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(width: calendarGutterSm),
                _TaskCompletionToggle(
                  isUpdating: isUpdating,
                  isCompleted: task.isCompleted,
                  onToggle: onToggleCompletion,
                ),
              ],
            ),
            if (task.hasChecklist) ...[
              const SizedBox(height: calendarGutterSm),
              TaskChecklistProgressBar(
                progress: task.checklistProgress,
                activeColor: textColor,
                backgroundColor: progressTrack,
              ),
            ],
            if (timeLabel != null) ...[
              const SizedBox(height: calendarGutterSm),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: sizing.menuItemIconSize,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: calendarInsetMd),
                  Text(
                    timeLabel!,
                    style: timeStyle,
                  ),
                  if (showActions) ...[
                    const Spacer(),
                    _TaskActionMenu(onEdit: onEdit, onDelete: onDelete),
                  ],
                ],
              ),
            ] else ...[
              if (showActions) ...[
                const SizedBox(height: calendarInsetMd),
                Align(
                  alignment: Alignment.centerRight,
                  child: _TaskActionMenu(
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FullTaskTile extends StatelessWidget {
  const _FullTaskTile({
    required this.task,
    required this.margin,
    required this.onTap,
    required this.isUpdating,
    required this.onToggleCompletion,
    required this.statusColor,
    required this.statusText,
    required this.timeLabel,
    required this.timeColor,
    required this.timeFontWeight,
    required this.durationLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarTask task;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final bool isUpdating;
  final ValueChanged<bool>? onToggleCompletion;
  final Color statusColor;
  final String statusText;
  final String? timeLabel;
  final Color timeColor;
  final FontWeight? timeFontWeight;
  final String? durationLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color indicatorColor =
        task.isCompleted ? taskCompletedColor : task.priorityColor;
    final Color progressTrack = colors.muted.withValues(alpha: 0.2);
    final bool showActions = onEdit != null || onDelete != null;
    final double stripWidth = context.sizing.progressIndicatorBarHeight;
    return TaskTileSurface(
      margin: margin,
      decoration: BoxDecoration(
        color: calendarContainerColor,
        boxShadow: calendarLightShadow,
        border: Border.all(
          color: calendarBorderColor,
          width: context.borderSide.width,
        ),
      ),
      leadingStripeColor: indicatorColor,
      leadingStripeWidth: stripWidth,
      onTap: onTap,
      child: Padding(
        padding: calendarPaddingXl,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskTitle(task: task, maxLines: 3),
                  if (task.description?.isNotEmpty == true) ...[
                    const SizedBox(height: calendarGutterSm),
                    Container(
                      padding: calendarPaddingMd,
                      decoration: BoxDecoration(
                        color: calendarSelectedDayColor,
                        borderRadius: context.radius,
                      ),
                      child: Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.label.copyWith(
                          color: calendarSubtitleColor,
                        ),
                      ),
                    ),
                  ],
                  if (task.hasChecklist) ...[
                    const SizedBox(height: calendarGutterSm),
                    TaskChecklistProgressBar(
                      progress: task.checklistProgress,
                      activeColor: colors.primary,
                      backgroundColor: progressTrack,
                    ),
                  ],
                  if (timeLabel != null) ...[
                    const SizedBox(height: calendarGutterSm),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: context.sizing.menuItemIconSize,
                          color: calendarTimeLabelColor,
                        ),
                        const SizedBox(width: calendarInsetLg),
                        _TaskTimeLabel(
                          text: timeLabel!,
                          color: timeColor,
                          fontWeight: timeFontWeight,
                        ),
                        if (durationLabel != null) ...[
                          const SizedBox(width: calendarGutterLg),
                          Icon(
                            Icons.timer,
                            size: context.sizing.menuItemIconSize,
                            color: calendarTimeLabelColor,
                          ),
                          const SizedBox(width: calendarInsetLg),
                          Text(
                            durationLabel!,
                            style: context.textTheme.small.copyWith(
                              color: calendarTimeLabelColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: calendarGutterMd),
                  Row(
                    children: [
                      _TaskStatusChip(color: statusColor, text: statusText),
                      if (showActions) ...[
                        const Spacer(),
                        if (onEdit != null)
                          AxiIconButton.outline(
                            iconData: Icons.edit,
                            tooltip: context.l10n.calendarEditTaskTooltip,
                            onPressed: onEdit,
                            color: colors.mutedForeground,
                          ),
                        if (onEdit != null && onDelete != null)
                          const SizedBox(width: calendarGutterSm),
                        if (onDelete != null)
                          AxiIconButton.outline(
                            iconData: Icons.delete,
                            tooltip: context.l10n.calendarDeleteTaskTooltip,
                            onPressed: onDelete,
                            color: colors.destructive,
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: calendarGutterLg),
            _TaskCompletionToggle(
              isUpdating: isUpdating,
              isCompleted: task.isCompleted,
              onToggle: onToggleCompletion,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCompletionToggle extends StatelessWidget {
  const _TaskCompletionToggle({
    required this.isUpdating,
    required this.isCompleted,
    required this.onToggle,
  });

  final bool isUpdating;
  final bool isCompleted;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onToggle != null;
    return ActionFeedback(
      onTap: isUpdating || !isEnabled ? null : () => onToggle!(!isCompleted),
      child: isUpdating
          ? SizedBox(
              width: context.sizing.progressIndicatorSize,
              height: context.sizing.progressIndicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: context.sizing.progressIndicatorStrokeWidth,
              ),
            )
          : CalendarCompletionCheckbox(
              value: isCompleted,
              onChanged: isEnabled
                  ? (completed) {
                      if (!isUpdating) {
                        onToggle!(completed);
                      }
                    }
                  : null,
            ),
    );
  }
}

class _TaskTitle extends StatelessWidget {
  const _TaskTitle({
    required this.task,
    required this.maxLines,
  });

  final CalendarTask task;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      task.title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.p.copyWith(
        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        color: task.isCompleted ? calendarPrimaryColor : calendarTitleColor,
      ),
    );
  }
}

class _TaskTimeLabel extends StatelessWidget {
  const _TaskTimeLabel({
    required this.text,
    required this.color,
    this.fontWeight,
  });

  final String text;
  final Color color;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.small.copyWith(
        color: color,
        fontWeight: fontWeight,
      ),
    );
  }
}

class _TaskActionMenu extends StatefulWidget {
  const _TaskActionMenu({
    required this.onEdit,
    required this.onDelete,
    this.showIcons = true,
    this.iconSize,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showIcons;
  final double? iconSize;

  @override
  State<_TaskActionMenu> createState() => _TaskActionMenuState();
}

class _TaskActionMenuState extends State<_TaskActionMenu> {
  late final ShadPopoverController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShadPopoverController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleEdit() {
    if (widget.onEdit == null) {
      return;
    }
    _controller.hide();
    widget.onEdit!();
  }

  void _handleDelete() {
    if (widget.onDelete == null) {
      return;
    }
    _controller.hide();
    widget.onDelete!();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<AxiMenuAction> actions = [
      if (widget.onEdit != null)
        AxiMenuAction(
          label: l10n.chatActionEdit,
          icon: widget.showIcons ? Icons.edit : null,
          onPressed: _handleEdit,
        ),
      if (widget.onDelete != null)
        AxiMenuAction(
          label: l10n.commonDelete,
          icon: widget.showIcons ? Icons.delete : null,
          destructive: true,
          onPressed: _handleDelete,
        ),
    ];
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return AxiPopover(
      controller: _controller,
      closeOnTapOutside: true,
      padding: EdgeInsets.zero,
      decoration: ShadDecoration.none,
      shadows: const <BoxShadow>[],
      popover: (context) => AxiMenu(actions: actions),
      child: AxiIconButton.ghost(
        iconData: Icons.more_vert,
        iconSize: widget.iconSize,
        tooltip: l10n.calendarActions,
        onPressed: _controller.toggle,
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(context.sizing.containerRadius),
      ),
      child: Text(
        text,
        style: context.textTheme.label.copyWith(color: color),
      ),
    );
  }
}
