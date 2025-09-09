import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/calendar_task.dart';
import '../view/base_calendar_widget.dart';
import 'guest_calendar_bloc.dart';
import 'guest_task_input.dart' as guest_input;
import 'guest_task_tile.dart';

class GuestCalendarWidget extends BaseCalendarWidget<GuestCalendarBloc> {
  const GuestCalendarWidget({super.key}) : super(isGuestMode: true);

  @override
  State<GuestCalendarWidget> createState() => _GuestCalendarWidgetState();
}

class _GuestCalendarWidgetState
    extends BaseCalendarWidgetState<GuestCalendarWidget, GuestCalendarBloc> {
  @override
  Widget build(BuildContext context) {
    // Guest calendar uses the globally provided GuestCalendarBloc from app.dart
    final guestCalendarBloc = context.watch<GuestCalendarBloc?>();

    if (guestCalendarBloc == null) {
      return const Scaffold(
        body: Center(
          child: Text('Guest calendar not available'),
        ),
      );
    }

    return super.build(context);
  }

  @override
  Widget buildTaskTile(CalendarTask task, bool compact) {
    return GuestTaskTile(
      task: task,
      compact: compact,
    );
  }

  @override
  void showTaskInput(BuildContext context, DateTime initialDate) {
    guest_input.showGuestTaskInput(context, initialDate: initialDate);
  }
}
