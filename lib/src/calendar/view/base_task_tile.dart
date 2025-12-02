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
import 'feedback_system.dart';
import 'widgets/calendar_completion_checkbox.dart';
import 'widgets/task_checklist.dart';

abstract class BaseTaskTile<T extends BaseCalendarBloc> extends StatefulWidget {
  const BaseTaskTile({
    super.key,
    required this.task,
    required this.isGuestMode,
    this.onTap,
    this.compact = false,
  });

  final CalendarTask task;
  final bool isGuestMode;
  final VoidCallback? onTap;
  final bool compact;
}

abstract class BaseTaskTileState<W extends BaseTaskTile<T>,
    T extends BaseCalendarBloc> extends State<W> {
  bool _isUpdating = false;

  void showEditTaskInput(BuildContext context, CalendarTask task);

  @override
  Widget build(BuildContext context) {
    return BlocListener<T, CalendarState>(
      listener: (context, state) {
        if (!state.isLoading && _isUpdating) {
          setState(() => _isUpdating = false);
          if (state.error == null) {
            FeedbackSystem.showSuccess(
              context,
              widget.task.isCompleted ? 'Task completed!' : 'Task updated!',
            );
          }
        }
      },
      child: AnimatedOpacity(
        opacity: _isUpdating ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Builder(
          builder: (context) {
            final CalendarResponsiveSpec spec = widget.compact
                ? ResponsiveHelper.specForSizeClass(CalendarSizeClass.compact)
                : ResponsiveHelper.spec(context);
            final EdgeInsets margin = _tileMargin(spec);
            final CalendarTask task = widget.task;
            final Color taskColor = _getTaskColor(task);
            final Color statusColor = _getStatusColor(context);
            final String statusText = _getStatusText();
            final DateTime? scheduledTime = task.scheduledTime;
            final String? timeLabel = scheduledTime != null
                ? TimeFormatter.formatDateTime(scheduledTime)
                : null;
            final String? durationLabel =
                task.duration != null ? _formatDuration(task.duration!) : null;
            final Color timeColor = _getTimeColor(context);
            final FontWeight? timeFontWeight =
                _isOverdue() ? FontWeight.bold : null;
            void handleEdit() => showEditTaskInput(context, task);
            void handleDelete() => _showDeleteConfirmation(context);
            void handleToggleCompletion(bool completed) =>
                _toggleTaskCompletion(context, completed);

            late final Widget tile;
            switch (spec.sizeClass) {
              case CalendarSizeClass.compact:
                tile = _CompactTaskTile(
                  task: task,
                  margin: margin,
                  onTap: widget.onTap,
                  taskColor: taskColor,
                  isUpdating: _isUpdating,
                  onToggleCompletion: handleToggleCompletion,
                  timeLabel: timeLabel,
                  timeColor: timeColor,
                  timeFontWeight: timeFontWeight,
                  onEdit: handleEdit,
                  onDelete: handleDelete,
                );
              case CalendarSizeClass.medium:
                tile = _MediumTaskTile(
                  task: task,
                  margin: margin,
                  onTap: widget.onTap,
                  taskColor: taskColor,
                  isUpdating: _isUpdating,
                  onToggleCompletion: handleToggleCompletion,
                  timeLabel: timeLabel,
                  timeFontWeight: timeFontWeight,
                  onEdit: handleEdit,
                  onDelete: handleDelete,
                );
              case CalendarSizeClass.expanded:
                tile = _FullTaskTile(
                  task: task,
                  margin: margin,
                  onTap: widget.onTap,
                  isUpdating: _isUpdating,
                  onToggleCompletion: handleToggleCompletion,
                  statusColor: statusColor,
                  statusText: statusText,
                  timeLabel: timeLabel,
                  timeColor: timeColor,
                  timeFontWeight: timeFontWeight,
                  durationLabel: durationLabel,
                  onEdit: handleEdit,
                  onDelete: handleDelete,
                );
            }
            return tile;
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.calendarDeleteTask),
        content: Text(
          dialogContext.l10n.calendarDeleteTaskConfirm(widget.task.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              locate<T>().add(
                CalendarEvent.taskDeleted(taskId: widget.task.id),
              );
              Navigator.of(dialogContext).maybePop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
          CalendarEvent.taskCompleted(
            taskId: baseId,
            completed: completed,
          ),
        );
  }

  String _formatDuration(Duration duration) {
    return TimeFormatter.formatDurationShort(duration);
  }

  Color _getTimeColor(BuildContext context) {
    if (widget.task.isCompleted) return calendarPrimaryColor;
    if (_isOverdue()) return Colors.red;
    if (_isDueSoon()) return Colors.orange;
    return calendarTimeLabelColor;
  }

  Color _getStatusColor(BuildContext context) {
    if (widget.task.isCompleted) return taskCompletedColor;
    if (_isOverdue()) return calendarDangerColor;
    if (_isDueSoon()) return calendarWarningColor;
    return widget.task.priorityColor;
  }

  String _getStatusText() {
    if (widget.task.isCompleted) return 'Completed';
    if (_isOverdue()) return 'Overdue';
    if (_isDueSoon()) return 'Due Soon';
    return 'Pending';
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
  final ValueChanged<bool> onToggleCompletion;
  final String? timeLabel;
  final Color timeColor;
  final FontWeight? timeFontWeight;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color indicatorColor =
        task.isCompleted ? taskCompletedColor : taskColor;
    final colors = context.colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarEventRadius),
        boxShadow: calendarLightShadow,
        border: Border(
          left: BorderSide(color: indicatorColor, width: 4),
          top: const BorderSide(color: calendarBorderColor, width: 1),
          right: const BorderSide(color: calendarBorderColor, width: 1),
          bottom: const BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(calendarEventRadius),
          child: Padding(
            padding: calendarPaddingLg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TaskTitle(task: task, maxLines: 1, fontSize: 14),
                      if (task.hasChecklist) ...[
                        const SizedBox(height: calendarInsetMd),
                        TaskChecklistProgressBar(
                          progress: task.checklistProgress,
                          activeColor: colors.primary,
                          backgroundColor: colors.muted.withValues(alpha: 0.2),
                        ),
                      ],
                      if (timeLabel != null) ...[
                        const SizedBox(height: calendarInsetMd),
                        _TaskTimeLabel(
                          text: timeLabel!,
                          fontSize: 12,
                          color: timeColor,
                          fontWeight: timeFontWeight,
                        ),
                      ],
                    ],
                  ),
                ),
                _TaskActionMenu(
                  onEdit: onEdit,
                  onDelete: onDelete,
                  showIcons: false,
                  iconSize: 20,
                ),
                const SizedBox(width: calendarGutterMd),
                _TaskCompletionToggle(
                  isUpdating: isUpdating,
                  isCompleted: task.isCompleted,
                  onToggle: onToggleCompletion,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    required this.timeFontWeight,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarTask task;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color taskColor;
  final bool isUpdating;
  final ValueChanged<bool> onToggleCompletion;
  final String? timeLabel;
  final FontWeight? timeFontWeight;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const Color textColor = Colors.white;
    final Color backgroundColor =
        task.isCompleted ? taskCompletedColor : taskColor;
    final Color progressTrack = textColor.withValues(alpha: 0.25);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(calendarEventRadius),
        boxShadow: calendarLightShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(calendarEventRadius),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
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
                        size: 12,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: calendarInsetMd),
                      Text(
                        timeLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.9),
                          fontWeight: timeFontWeight,
                        ),
                      ),
                      const Spacer(),
                      _TaskActionMenu(
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
                    ],
                  ),
                ] else ...[
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
            ),
          ),
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
  final ValueChanged<bool> onToggleCompletion;
  final Color statusColor;
  final String statusText;
  final String? timeLabel;
  final Color timeColor;
  final FontWeight? timeFontWeight;
  final String? durationLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color indicatorColor =
        task.isCompleted ? taskCompletedColor : task.priorityColor;
    final Color progressTrack = colors.muted.withValues(alpha: 0.2);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarEventRadius),
        boxShadow: calendarLightShadow,
        border: Border.all(color: calendarBorderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(calendarEventRadius - 1),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: indicatorColor, width: 4),
            ),
          ),
          child: Padding(
            padding: calendarPaddingXl,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TaskTitle(task: task, maxLines: 3, fontSize: 16),
                      if (task.description?.isNotEmpty == true) ...[
                        const SizedBox(height: calendarGutterSm),
                        Container(
                          padding: calendarPaddingMd,
                          decoration: BoxDecoration(
                            color: calendarSelectedDayColor,
                            borderRadius:
                                BorderRadius.circular(calendarEventRadius),
                          ),
                          child: Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: calendarSubtitleColor,
                              fontSize: 13,
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
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: calendarTimeLabelColor,
                            ),
                            const SizedBox(width: calendarInsetLg),
                            _TaskTimeLabel(
                              text: timeLabel!,
                              fontSize: 14,
                              color: timeColor,
                              fontWeight: timeFontWeight,
                            ),
                            if (durationLabel != null) ...[
                              const SizedBox(width: calendarGutterLg),
                              const Icon(
                                Icons.timer,
                                size: 16,
                                color: calendarTimeLabelColor,
                              ),
                              const SizedBox(width: calendarInsetLg),
                              Text(
                                durationLabel!,
                                style: const TextStyle(
                                  color: calendarTimeLabelColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: calendarGutterMd),
                      Row(
                        children: [
                          _TaskStatusChip(
                            color: statusColor,
                            text: statusText,
                          ),
                          const Spacer(),
                          AxiIconButton(
                            iconData: Icons.edit,
                            tooltip: 'Edit task',
                            onPressed: onEdit,
                            iconSize: 18,
                            buttonSize: 36,
                            tapTargetSize: 40,
                            cornerRadius: 12,
                            backgroundColor: colors.card,
                            borderColor: colors.border,
                            color: colors.mutedForeground,
                          ),
                          const SizedBox(width: calendarGutterSm),
                          AxiIconButton(
                            iconData: Icons.delete,
                            tooltip: 'Delete task',
                            onPressed: onDelete,
                            iconSize: 18,
                            buttonSize: 36,
                            tapTargetSize: 40,
                            cornerRadius: 12,
                            backgroundColor: colors.card,
                            borderColor: colors.border,
                            color: colors.destructive,
                          ),
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
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final String feedbackMessage =
        isCompleted ? 'Task marked incomplete' : 'Task completed!';
    return ActionFeedback(
      onTap: isUpdating ? null : () => onToggle(!isCompleted),
      feedbackMessage: feedbackMessage,
      child: isUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : CalendarCompletionCheckbox(
              value: isCompleted,
              onChanged: (completed) {
                if (!isUpdating) {
                  onToggle(completed);
                }
              },
            ),
    );
  }
}

class _TaskTitle extends StatelessWidget {
  const _TaskTitle({
    required this.task,
    required this.maxLines,
    required this.fontSize,
  });

  final CalendarTask task;
  final int maxLines;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      task.title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        color: task.isCompleted ? calendarPrimaryColor : calendarTitleColor,
      ),
    );
  }
}

class _TaskTimeLabel extends StatelessWidget {
  const _TaskTimeLabel({
    required this.text,
    required this.fontSize,
    required this.color,
    this.fontWeight,
  });

  final String text;
  final double fontSize;
  final Color color;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
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

  final VoidCallback onEdit;
  final VoidCallback onDelete;
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
    _controller.hide();
    widget.onEdit();
  }

  void _handleDelete() {
    _controller.hide();
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return ShadPopover(
      controller: _controller,
      closeOnTapOutside: true,
      padding: EdgeInsets.zero,
      popover: (context) => AxiMenu(
        actions: [
          AxiMenuAction(
            label: 'Edit',
            icon: widget.showIcons ? Icons.edit : null,
            onPressed: _handleEdit,
          ),
          AxiMenuAction(
            label: 'Delete',
            icon: widget.showIcons ? Icons.delete : null,
            destructive: true,
            onPressed: _handleDelete,
          ),
        ],
      ),
      child: IconButton(
        iconSize: widget.iconSize,
        tooltip: 'Task actions',
        icon: const Icon(Icons.more_vert),
        onPressed: _controller.toggle,
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({
    required this.color,
    required this.text,
  });

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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
