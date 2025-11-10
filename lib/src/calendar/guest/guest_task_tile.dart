import 'package:flutter/material.dart';
import '../models/calendar_task.dart';
import '../view/base_task_tile.dart';
import 'guest_calendar_bloc.dart';
import 'guest_task_input.dart' as guest_input;

class GuestTaskTile extends BaseTaskTile<GuestCalendarBloc> {
  const GuestTaskTile({
    super.key,
    required super.task,
    super.onTap,
    super.compact = false,
  }) : super(isGuestMode: true);

  @override
  State<GuestTaskTile> createState() => _GuestTaskTileState();
}

class _GuestTaskTileState
    extends BaseTaskTileState<GuestTaskTile, GuestCalendarBloc> {
  @override
  void showEditTaskInput(BuildContext context, CalendarTask task) {
    guest_input.showGuestTaskInput(context, editingTask: task);
  }
}
