import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import 'feedback_system.dart';
import 'task_input.dart';

class TaskTile extends StatefulWidget {
  final CalendarTask task;
  final VoidCallback? onTap;
  final bool compact;

  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.compact = false,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CalendarBloc, CalendarState>(
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
        child: ResponsiveHelper.layoutBuilder(
          context,
          mobile: _buildCompactTile(context),
          tablet: _buildMediumTile(context),
          desktop: _buildFullTile(context),
        ),
      ),
    );
  }

  Widget _buildCompactTile(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        dense: true,
        leading: _buildCheckbox(context),
        title: _buildTitle(context, maxLines: 1, fontSize: 14),
        subtitle: widget.task.scheduledTime != null
            ? _buildTime(context, fontSize: 12)
            : null,
        trailing: _buildActionButton(context),
        onTap: widget.onTap,
      ),
    );
  }

  Widget _buildMediumTile(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildCheckbox(context),
        title: _buildTitle(context, maxLines: 2, fontSize: 16),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.task.scheduledTime != null)
              _buildTime(context, fontSize: 14)!,
            if (widget.task.description?.isNotEmpty == true)
              Text(
                widget.task.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
          ],
        ),
        trailing: _buildActionsMenu(context),
        onTap: widget.onTap,
      ),
    );
  }

  Widget _buildFullTile(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildCheckbox(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(context, maxLines: 3, fontSize: 16),
                  if (widget.task.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                  if (widget.task.scheduledTime != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        _buildTime(context, fontSize: 14)!,
                        if (widget.task.duration != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(widget.task.duration!),
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusChip(context),
                      const Spacer(),
                      _buildEditButton(context),
                      const SizedBox(width: 8),
                      _buildDeleteButton(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    return ActionFeedback(
      onTap: () {
        setState(() => _isUpdating = true);
        context.read<CalendarBloc>().add(
              CalendarEvent.taskCompleted(
                taskId: widget.task.id,
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
          : Checkbox(
              value: widget.task.isCompleted,
              onChanged: (completed) {
                if (completed != null && !_isUpdating) {
                  setState(() => _isUpdating = true);
                  context.read<CalendarBloc>().add(
                        CalendarEvent.taskCompleted(
                          taskId: widget.task.id,
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
        color: widget.task.isCompleted
            ? Theme.of(context).textTheme.bodySmall?.color
            : null,
      ),
    );
  }

  Widget? _buildTime(BuildContext context, {required double fontSize}) {
    if (widget.task.scheduledTime == null) return null;

    return Text(
      _formatTime(widget.task.scheduledTime!),
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
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
      onPressed: () => showTaskInput(context, editingTask: widget.task),
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
        showTaskInput(context, editingTask: widget.task);
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
              context.read<CalendarBloc>().add(
                    CalendarEvent.taskDeleted(taskId: widget.task.id),
                  );
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inHours}h';
  }

  Color _getTimeColor(BuildContext context) {
    if (_isOverdue()) return Colors.red;
    if (_isDueSoon()) return Colors.orange;
    return Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
  }

  Color _getStatusColor(BuildContext context) {
    if (widget.task.isCompleted) return Colors.green;
    if (_isOverdue()) return Colors.red;
    if (_isDueSoon()) return Colors.orange;
    return Theme.of(context).primaryColor;
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
}
