import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';

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
  static const int startHour = 6;
  static const int endHour = 22;

  double _getHourHeight(BuildContext context, bool compact) {
    if (compact) return 45.0;
    return ResponsiveHelper.isMobile(context) ? 50.0 : 60.0;
  }

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

    return Container(
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius:
            const BorderRadius.all(Radius.circular(calendarBorderRadius)),
        border: Border.all(color: calendarBorderColor, width: 1),
        boxShadow: calendarLightShadow,
      ),
      child: Column(
        children: [
          _buildDayHeaders(weekDates, compact),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: calendarContainerColor,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(calendarBorderRadius),
                ),
              ),
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeColumn(compact),
                    ...weekDates.map((date) => Expanded(
                          child: _buildDayColumn(date, compact),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(List<DateTime> weekDates, bool compact) {
    return Container(
      height: compact ? calendarDayHeaderHeight * 1.8 : calendarHeaderHeight,
      decoration: const BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(calendarBorderRadius),
        ),
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 50 : 70,
            child: Center(
              child: Icon(
                Icons.schedule,
                color: calendarTimeLabelColor,
                size: compact ? 16 : 20,
              ),
            ),
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

    return AnimatedContainer(
      duration: baseAnimationDuration,
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectDate(date),
          borderRadius: BorderRadius.circular(calendarEventRadius),
          child: Container(
            margin: calendarPadding4,
            decoration: BoxDecoration(
              color: isSelected
                  ? calendarSelectedDayColor
                  : isToday
                      ? calendarSelectedDayColor.withValues(alpha: 0.5)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(calendarEventRadius),
              border: isToday
                  ? Border.all(
                      color: const Color(0xff007AFF),
                      width: 1) // Blue accent for today
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _getDayName(date.weekday, compact),
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      fontWeight: FontWeight.w600,
                      color: calendarSubtitleColor,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 1),
                Flexible(
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: compact ? 16 : 20,
                      fontWeight: FontWeight.bold,
                      color: isToday
                          ? const Color(0xff007AFF) // Blue for today
                          : calendarTitleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeColumn(bool compact) {
    final hourHeight = _getHourHeight(context, compact);
    return Container(
      width: compact ? 50 : 70,
      decoration: const BoxDecoration(
        color: calendarContainerColor,
        border: Border(
          right: BorderSide(
            color: calendarBorderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: List.generate(endHour - startHour + 1, (index) {
          final hour = startHour + index;
          final isCurrentHour = DateTime.now().hour == hour;
          return Container(
            height: hourHeight,
            alignment: Alignment.topCenter,
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: calendarSpacing8),
              child: Text(
                _formatHour(hour),
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: isCurrentHour ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrentHour
                      ? calendarTitleColor
                      : calendarTimeLabelColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(DateTime date, bool compact) {
    final isSelected = _isSameDay(date, widget.state.selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? calendarSelectedDayColor : calendarContainerColor,
        border: const Border(
          left: BorderSide(
            color: calendarBorderColor,
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          _buildTimeSlots(compact),
          ..._buildTasksForDay(date, compact),
        ],
      ),
    );
  }

  Widget _buildTimeSlots(bool compact) {
    final hourHeight = _getHourHeight(context, compact);

    return Column(
      children: List.generate(endHour - startHour + 1, (index) {
        return Container(
          height: hourHeight,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(
              top: BorderSide(
                color: calendarBorderColor,
                width: 1,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // TODO: Handle time slot tap for new task creation
              },
              child: const SizedBox.expand(),
            ),
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

    final hourHeight = _getHourHeight(context, compact);
    final topOffset =
        (hour - startHour) * hourHeight + (minute / 60 * hourHeight);
    final duration = task.duration ?? const Duration(hours: 1);
    final height = (duration.inMinutes / 60) * hourHeight;

    // Get priority color
    Color taskColor = _getTaskColor(task);

    return Positioned(
      top: topOffset,
      left: index * 6.0 + 4.0,
      right: 6.0,
      height: height.clamp(32, double.infinity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTaskDetails(task),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 1),
              padding:
                  EdgeInsets.all(compact ? calendarSpacing6 : calendarSpacing8),
              decoration: BoxDecoration(
                color: task.isCompleted
                    ? taskColor.withValues(alpha: 0.3)
                    : taskColor,
                borderRadius: const BorderRadius.all(
                    Radius.circular(calendarEventRadius)),
                boxShadow: calendarLightShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!compact && height > 50) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: compact ? 9 : 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: compact ? 1 : 2,
                        ),
                      ),
                    ],
                  ),
                  if (!compact && height > 45) ...[
                    const SizedBox(height: 4),
                    Text(
                      TimeFormatter.formatDateTime(taskTime),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTaskColor(CalendarTask task) {
    // Hash-based consistent color assignment using task ID
    final hash = task.id.hashCode.abs();
    final colorIndex = hash % calendarEventColors.length;
    return calendarEventColors[colorIndex];
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
