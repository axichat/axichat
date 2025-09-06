import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';

class CalendarGrid extends StatefulWidget {
  final CalendarState state;

  const CalendarGrid({
    super.key,
    required this.state,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  static const double hourHeight = 60.0;
  static const int startHour = 6;
  static const int endHour = 22;

  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.layoutBuilder(
      context,
      mobile: _buildMobileGrid(),
      tablet: _buildTabletGrid(),
      desktop: _buildDesktopGrid(),
    );
  }

  Widget _buildMobileGrid() {
    return _buildWeekView(compact: true);
  }

  Widget _buildTabletGrid() {
    return _buildWeekView(compact: false);
  }

  Widget _buildDesktopGrid() {
    return _buildWeekView(compact: false);
  }

  Widget _buildWeekView({required bool compact}) {
    final weekDates = _getWeekDates(widget.state.selectedDate);

    return Column(
      children: [
        _buildDayHeaders(weekDates, compact),
        Expanded(
          child: Row(
            children: [
              _buildTimeColumn(compact),
              ...weekDates.map((date) => Expanded(
                    child: _buildDayColumn(date, compact),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeaders(List<DateTime> weekDates, bool compact) {
    return Container(
      height: compact ? 50 : 60,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 50 : 70,
            child: const Center(child: Text('')),
          ),
          ...weekDates.map((date) => Expanded(
                child: _buildDayHeader(date, compact),
              )),
        ],
      ),
    );
  }

  Widget _buildDayHeader(DateTime date, bool compact) {
    final isToday = _isToday(date);
    final isSelected = _isSameDay(date, widget.state.selectedDate);

    return GestureDetector(
      onTap: () => _selectDate(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : isToday
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                  : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getDayName(date.weekday, compact),
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : null,
              ),
            ),
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn(bool compact) {
    return SizedBox(
      width: compact ? 50 : 70,
      child: Column(
        children: List.generate(endHour - startHour + 1, (index) {
          final hour = startHour + index;
          return Container(
            height: hourHeight,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatHour(hour),
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(DateTime date, bool compact) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Stack(
        children: [
          _buildTimeSlots(),
          ..._buildTasksForDay(date, compact),
        ],
      ),
    );
  }

  Widget _buildTimeSlots() {
    return Column(
      children: List.generate(endHour - startHour + 1, (index) {
        return Container(
          height: hourHeight,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () {
              // TODO: Handle time slot tap for new task creation
            },
          ),
        );
      }),
    );
  }

  List<Widget> _buildTasksForDay(DateTime date, bool compact) {
    final tasks = _getTasksForDay(date);
    final widgets = <Widget>[];

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.scheduledTime == null) continue;

      final widget = _buildTaskWidget(task, i, compact);
      if (widget != null) {
        widgets.add(widget);
      }
    }

    return widgets;
  }

  Widget? _buildTaskWidget(CalendarTask task, int index, bool compact) {
    if (task.scheduledTime == null) return null;

    final taskTime = task.scheduledTime!;
    final hour = taskTime.hour.toDouble();
    final minute = taskTime.minute.toDouble();

    if (hour < startHour || hour > endHour) return null;

    final topOffset =
        (hour - startHour) * hourHeight + (minute / 60 * hourHeight);
    final duration = task.duration ?? const Duration(hours: 1);
    final height = (duration.inMinutes / 60) * hourHeight;

    return Positioned(
      top: topOffset,
      left: index * 4.0, // Slight offset for overlapping tasks
      right: 4.0,
      height: height.clamp(20.0, double.infinity),
      child: GestureDetector(
        onTap: () => _showTaskDetails(task),
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: EdgeInsets.all(compact ? 2 : 4),
          decoration: BoxDecoration(
            color: task.isCompleted
                ? Colors.grey.withValues(alpha: 0.6)
                : Theme.of(context).primaryColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: task.isCompleted
                  ? Colors.grey
                  : Theme.of(context).primaryColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: compact ? 1 : 2,
              ),
              if (!compact && height > 40)
                Text(
                  TimeFormatter.formatDateTime(taskTime),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<DateTime> _getWeekDates(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  List<CalendarTask> _getTasksForDay(DateTime date) {
    return widget.state.model.tasks.values.where((task) {
      if (task.scheduledTime == null) return false;
      return _isSameDay(task.scheduledTime!, date);
    }).toList()
      ..sort((a, b) {
        if (a.scheduledTime == null && b.scheduledTime == null) return 0;
        if (a.scheduledTime == null) return 1;
        if (b.scheduledTime == null) return -1;
        return a.scheduledTime!.compareTo(b.scheduledTime!);
      });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getDayName(int weekday, bool compact) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const fullDayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return compact
        ? dayNames[weekday - 1]
        : fullDayNames[weekday - 1].substring(0, 3);
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12a';
    if (hour < 12) return '${hour}a';
    if (hour == 12) return '12p';
    return '${hour - 12}p';
  }

  void _selectDate(DateTime date) {
    context.read<CalendarBloc>().add(CalendarEvent.dateSelected(date: date));
  }

  void _showTaskDetails(CalendarTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description?.isNotEmpty == true) ...[
              const Text('Description:'),
              Text(task.description!),
              const SizedBox(height: 8),
            ],
            if (task.scheduledTime != null) ...[
              const Text('Scheduled:'),
              Text(TimeFormatter.formatDateTime(task.scheduledTime!)),
              const SizedBox(height: 8),
            ],
            const Text('Status:'),
            Text(task.isCompleted ? 'Completed' : 'Pending'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              context.read<CalendarBloc>().add(
                    CalendarEvent.taskCompleted(
                      taskId: task.id,
                      completed: !task.isCompleted,
                    ),
                  );
              Navigator.of(context).pop();
            },
            child: Text(task.isCompleted ? 'Mark Incomplete' : 'Mark Complete'),
          ),
        ],
      ),
    );
  }
}
