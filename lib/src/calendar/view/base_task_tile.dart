import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';
import 'feedback_system.dart';
import 'widgets/calendar_completion_checkbox.dart';

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
        child: _buildTileForSpec(
          context,
          widget.compact
              ? ResponsiveHelper.specForSizeClass(CalendarSizeClass.compact)
              : ResponsiveHelper.spec(context),
        ),
      ),
    );
  }

  Widget _buildTileForSpec(
    BuildContext context,
    CalendarResponsiveSpec spec,
  ) {
    switch (spec.sizeClass) {
      case CalendarSizeClass.compact:
        return _buildCompactTile(context, spec);
      case CalendarSizeClass.medium:
        return _buildMediumTile(context, spec);
      case CalendarSizeClass.expanded:
        return _buildFullTile(context, spec);
    }
  }

  EdgeInsets _tileMargin(CalendarResponsiveSpec spec) {
    final double horizontal = spec.contentPadding.left;
    final double vertical = spec.contentPadding.vertical / 2;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  Widget _buildCompactTile(
    BuildContext context,
    CalendarResponsiveSpec spec,
  ) {
    final taskColor = _getTaskColor(widget.task);
    return Container(
      margin: _tileMargin(spec),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarEventRadius),
        boxShadow: calendarLightShadow,
        border: Border(
          left: BorderSide(
            color: widget.task.isCompleted ? taskCompletedColor : taskColor,
            width: 4,
          ),
          top: const BorderSide(color: calendarBorderColor, width: 1),
          right: const BorderSide(color: calendarBorderColor, width: 1),
          bottom: const BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(calendarEventRadius),
          child: Padding(
            padding: calendarPaddingLg,
            child: Row(
              children: [
                _buildCheckbox(context),
                const SizedBox(width: calendarGutterMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(context, maxLines: 1, fontSize: 14),
                      if (widget.task.scheduledTime != null) ...[
                        const SizedBox(height: calendarInsetMd),
                        _buildTime(context, fontSize: 12)!,
                      ],
                    ],
                  ),
                ),
                _buildActionButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediumTile(
    BuildContext context,
    CalendarResponsiveSpec spec,
  ) {
    final taskColor = _getTaskColor(widget.task);
    const textColor = Colors.white;
    final eventColor = widget.task.isCompleted ? taskCompletedColor : taskColor;

    return Container(
      margin: _tileMargin(spec),
      decoration: BoxDecoration(
        color: eventColor,
        borderRadius: BorderRadius.circular(calendarEventRadius),
        boxShadow: calendarLightShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
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
                        widget.task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                          decoration: widget.task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: calendarGutterSm),
                    _buildCheckbox(context),
                  ],
                ),
                if (widget.task.scheduledTime != null) ...[
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
                        TimeFormatter.formatDateTime(
                            widget.task.scheduledTime!),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.9),
                          fontWeight: _isOverdue() ? FontWeight.bold : null,
                        ),
                      ),
                      const Spacer(),
                      _buildActionsMenu(context),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: calendarInsetMd),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildActionsMenu(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullTile(
    BuildContext context,
    CalendarResponsiveSpec spec,
  ) {
    final taskColor = _getTaskColor(widget.task);

    return Container(
      margin: _tileMargin(spec),
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
              left: BorderSide(
                color: widget.task.isCompleted ? taskCompletedColor : taskColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: calendarPaddingXl,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCheckbox(context),
                const SizedBox(width: calendarGutterLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: widget.task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: widget.task.isCompleted
                              ? calendarTimeLabelColor
                              : calendarTitleColor,
                        ),
                      ),
                      if (widget.task.description?.isNotEmpty == true) ...[
                        const SizedBox(height: calendarGutterSm),
                        Container(
                          padding: calendarPaddingMd,
                          decoration: BoxDecoration(
                            color: calendarSelectedDayColor,
                            borderRadius:
                                BorderRadius.circular(calendarEventRadius),
                          ),
                          child: Text(
                            widget.task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: calendarSubtitleColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      if (widget.task.scheduledTime != null) ...[
                        const SizedBox(height: calendarGutterSm),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: calendarTimeLabelColor,
                            ),
                            const SizedBox(width: calendarInsetLg),
                            Text(
                              TimeFormatter.formatDateTime(
                                  widget.task.scheduledTime!),
                              style: TextStyle(
                                fontSize: 14,
                                color: _getTimeColor(context),
                                fontWeight:
                                    _isOverdue() ? FontWeight.bold : null,
                              ),
                            ),
                            if (widget.task.duration != null) ...[
                              const SizedBox(width: calendarGutterLg),
                              const Icon(
                                Icons.timer,
                                size: 16,
                                color: calendarTimeLabelColor,
                              ),
                              const SizedBox(width: calendarInsetLg),
                              Text(
                                _formatDuration(widget.task.duration!),
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
                          _buildStatusChip(context),
                          const Spacer(),
                          _buildEditButton(context),
                          const SizedBox(width: calendarGutterSm),
                          _buildDeleteButton(context),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    return ActionFeedback(
      onTap: () {
        setState(() => _isUpdating = true);
        final baseId = widget.task.baseId;
        context.read<T>().add(
              CalendarEvent.taskCompleted(
                taskId: baseId,
                completed: !widget.task.isCompleted,
              ),
            );
      },
      feedbackMessage: widget.task.isCompleted
          ? 'Task marked incomplete'
          : 'Task completed!',
      child: _isUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : CalendarCompletionCheckbox(
              value: widget.task.isCompleted,
              onChanged: (completed) {
                if (!_isUpdating) {
                  setState(() => _isUpdating = true);
                  final baseId = widget.task.baseId;
                  context.read<T>().add(
                        CalendarEvent.taskCompleted(
                          taskId: baseId,
                          completed: completed,
                        ),
                      );
                }
              },
            ),
    );
  }

  Widget _buildTitle(BuildContext context,
      {required int maxLines, required double fontSize}) {
    return Text(
      widget.task.title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
        color:
            widget.task.isCompleted ? calendarPrimaryColor : calendarTitleColor,
      ),
    );
  }

  Widget? _buildTime(BuildContext context, {required double fontSize}) {
    if (widget.task.scheduledTime == null) return null;

    return Text(
      TimeFormatter.formatDateTime(widget.task.scheduledTime!),
      style: TextStyle(
        fontSize: fontSize,
        color: _getTimeColor(context),
        fontWeight: _isOverdue() ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return PopupMenuButton<String>(
      iconSize: 20,
      onSelected: (value) => _handleAction(context, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Text('Edit'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete'),
        ),
      ],
    );
  }

  Widget _buildActionsMenu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) => _handleAction(context, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: calendarGutterSm),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16),
              SizedBox(width: calendarGutterSm),
              Text('Delete'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: calendarGutterSm, vertical: calendarInsetSm),
      decoration: BoxDecoration(
        color: _getStatusColor(context).withValues(alpha: 0.1),
        border: Border.all(color: _getStatusColor(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(),
        style: TextStyle(
          color: _getStatusColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return IconButton(
      onPressed: () => showEditTaskInput(context, widget.task),
      icon: const Icon(Icons.edit, size: 18),
      tooltip: 'Edit task',
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return IconButton(
      onPressed: () => _showDeleteConfirmation(context),
      icon: const Icon(Icons.delete, size: 18),
      tooltip: 'Delete task',
    );
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        showEditTaskInput(context, widget.task);
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content:
            Text('Are you sure you want to delete "${widget.task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<T>()
                  .add(CalendarEvent.taskDeleted(taskId: widget.task.id));
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
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
