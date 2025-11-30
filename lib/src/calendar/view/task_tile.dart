import 'package:flutter/material.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'base_task_tile.dart';
import 'task_input.dart' as task_input;

class TaskTile extends BaseTaskTile<CalendarBloc> {
  const TaskTile({
    super.key,
    required super.task,
    super.onTap,
    super.compact = false,
  }) : super(isGuestMode: false);

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends BaseTaskTileState<TaskTile, CalendarBloc> {
  @override
  void showEditTaskInput(BuildContext context, CalendarTask task) {
    task_input.showTaskInput(context, editingTask: task);
  }
}
