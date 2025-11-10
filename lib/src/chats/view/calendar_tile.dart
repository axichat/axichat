import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class CalendarTile extends StatelessWidget {
  const CalendarTile({
    super.key,
    required this.onTap,
    this.nextTask,
    this.dueReminderCount = 0,
  });

  final VoidCallback onTap;
  final CalendarTask? nextTask;
  final int dueReminderCount;

  @override
  Widget build(BuildContext context) {
    return AxiListTile(
      onTap: onTap,
      leading: const Icon(
        Icons.calendar_today,
        color: axiGreen,
        size: 24,
      ),
      title: 'Calendar',
      subtitle: nextTask?.title ?? 'No upcoming tasks',
      badgeCount: dueReminderCount,
    );
  }
}
