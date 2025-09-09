import 'package:flutter/material.dart';
import '../bloc/calendar_bloc.dart';
import '../models/calendar_task.dart';
import 'base_calendar_widget.dart';
import 'task_input.dart' as task_input;
import 'task_tile.dart';

class CalendarWidget extends BaseCalendarWidget<CalendarBloc> {
  const CalendarWidget({super.key}) : super(isGuestMode: false);

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState
    extends BaseCalendarWidgetState<CalendarWidget, CalendarBloc> {
  @override
  Widget buildTaskTile(CalendarTask task, bool compact) {
    return TaskTile(
      task: task,
      compact: compact,
    );
  }

  @override
  void showTaskInput(BuildContext context, DateTime initialDate) {
    task_input.showTaskInput(context, initialDate: initialDate);
  }
}
