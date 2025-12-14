import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

const Duration _demoTaskDuration = Duration(minutes: 60);
const Duration _demoReminderLeadShort = Duration(minutes: 15);
const Duration _demoReminderLeadMedium = Duration(hours: 1);

/// Seeds a dense, feature-rich schedule for the demo account.
class DemoCalendar {
  DemoCalendar._();

  static CalendarModel franklin({
    required DateTime anchor,
  }) {
    final DateTime weekStart = _startOfWeek(anchor);

    final List<CalendarTask> tasks = <CalendarTask>[
      ..._scheduledWeekTasks(weekStart),
      ..._unscheduledTasks(),
      ..._reminderTasks(weekStart),
    ];

    CalendarModel model = CalendarModel.empty();
    for (final CalendarTask task in tasks) {
      model = model.addTask(task);
    }

    final List<DayEvent> dayEvents = _dayEvents(weekStart);
    for (final DayEvent event in dayEvents) {
      model = model.addDayEvent(event);
    }

    model = _attachCriticalPaths(model);

    return model;
  }
}

CalendarTask _scheduledTask({
  required String title,
  required DateTime scheduledTime,
  String? description,
  String? location,
  TaskPriority priority = TaskPriority.none,
  Duration duration = _demoTaskDuration,
  ReminderPreferences? reminders,
  List<TaskChecklistItem> checklist = const <TaskChecklistItem>[],
}) {
  final CalendarTask base = CalendarTask.create(
    title: title,
    description: description,
    scheduledTime: scheduledTime,
    duration: duration,
    location: location,
    priority: priority,
    reminders: reminders,
    checklist: checklist,
  );
  return base.withScheduled(
    scheduledTime: scheduledTime,
    duration: duration,
  );
}

CalendarTask _deadlineTask({
  required String title,
  required DateTime deadline,
  String? description,
  String? location,
  TaskPriority priority = TaskPriority.none,
  ReminderPreferences? reminders,
  List<TaskChecklistItem> checklist = const <TaskChecklistItem>[],
}) =>
    CalendarTask.create(
      title: title,
      description: description,
      deadline: deadline,
      location: location,
      priority: priority,
      reminders: reminders,
      checklist: checklist,
    );

CalendarTask _unscheduledTask({
  required String title,
  String? description,
  String? location,
  TaskPriority priority = TaskPriority.none,
  List<TaskChecklistItem> checklist = const <TaskChecklistItem>[],
}) =>
    CalendarTask.create(
      title: title,
      description: description,
      location: location,
      priority: priority,
      checklist: checklist,
    );

DateTime _startOfWeek(DateTime date) {
  final DateTime midnight = DateTime(date.year, date.month, date.day);
  final int daysFromMonday = midnight.weekday - DateTime.monday;
  return midnight.subtract(Duration(days: daysFromMonday));
}

DateTime _atWeekdayTime(
  DateTime weekStart,
  int weekdayOffset, {
  required int hour,
  required int minute,
}) {
  final DateTime day = weekStart.add(Duration(days: weekdayOffset));
  return DateTime(day.year, day.month, day.day, hour, minute);
}

List<CalendarTask> _scheduledWeekTasks(DateTime weekStart) {
  const String printingHouse = 'Market Street Printing House';
  const String postOffice = 'Philadelphia Post Office';
  const String workshop = 'Workshop';
  const int tuesdayOffset = 1;
  const int saturdayOffset = 5;
  const int sundayOffset = 6;

  const ReminderPreferences startReminder = ReminderPreferences(
    enabled: true,
    startOffsets: <Duration>[
      _demoReminderLeadShort,
      _demoReminderLeadMedium,
    ],
  );

  final List<CalendarTask> tasks = <CalendarTask>[];

  // Monday (0)
  tasks
    ..add(
      _scheduledTask(
        title: 'Rise & plan the day (virtues)',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 5, minute: 10),
        duration: const Duration(minutes: 25),
        priority: TaskPriority.important,
        reminders: startReminder,
        checklist: const <TaskChecklistItem>[
          TaskChecklistItem(id: 'virtue', label: 'Select virtue of the day'),
          TaskChecklistItem(id: 'top3', label: 'Write top 3 intentions'),
        ],
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Breakfast & reading',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 6, minute: 0),
        duration: const Duration(minutes: 45),
        location: 'Home',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Morning correspondence & ledgers',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 8, minute: 5),
        duration: const Duration(minutes: 70),
        location: printingHouse,
        priority: TaskPriority.important,
        reminders: startReminder,
        checklist: const <TaskChecklistItem>[
          TaskChecklistItem(id: 'letters', label: 'Reply to letters'),
          TaskChecklistItem(id: 'accounts', label: 'Update accounts'),
          TaskChecklistItem(id: 'plan', label: 'Set today’s priorities'),
        ],
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Press run: Gazette proofs & corrections',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 9, minute: 30),
        duration: const Duration(minutes: 90),
        location: printingHouse,
        priority: TaskPriority.important,
        checklist: const <TaskChecklistItem>[
          TaskChecklistItem(id: 'edit', label: 'Edit copy'),
          TaskChecklistItem(id: 'set', label: 'Set type'),
          TaskChecklistItem(id: 'proof', label: 'Proof & correct'),
        ],
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Coffee break',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 10, minute: 55),
        duration: const Duration(minutes: 15),
        location: printingHouse,
      ).copyWith(isCompleted: true),
    )
    ..add(
      _scheduledTask(
        title: 'Walk to market (fresh supplies)',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 12, minute: 10),
        duration: const Duration(minutes: 35),
        location: 'Market',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Dispatches & deliveries',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 13, minute: 20),
        duration: const Duration(minutes: 50),
        location: postOffice,
        priority: TaskPriority.urgent,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Experiments & notes (electricity)',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 15, minute: 5),
        duration: const Duration(minutes: 80),
        location: workshop,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Evening letters (friends & patrons)',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 19, minute: 10),
        duration: const Duration(minutes: 60),
        location: 'Home',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Reflection & journal',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 21, minute: 40),
        duration: const Duration(minutes: 20),
        location: 'Home',
      ),
    );

  // Tuesday (1): show overlaps in the grid.
  tasks
    ..add(
      _scheduledTask(
        title: 'Early workshop: tools & repairs',
        scheduledTime:
            _atWeekdayTime(weekStart, tuesdayOffset, hour: 6, minute: 20),
        duration: const Duration(minutes: 55),
        location: workshop,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Appointments & walk-ins',
        scheduledTime:
            _atWeekdayTime(weekStart, tuesdayOffset, hour: 8, minute: 40),
        duration: const Duration(minutes: 50),
        location: printingHouse,
      ),
    )
    ..addAll(
      <CalendarTask>[
        _scheduledTask(
          title: 'Committee meeting: civic improvements',
          scheduledTime:
              _atWeekdayTime(weekStart, tuesdayOffset, hour: 10, minute: 0),
          duration: const Duration(minutes: 60),
          location: 'State House',
          priority: TaskPriority.urgent,
        ),
        _scheduledTask(
          title: 'Printer’s client: pamphlet commission',
          scheduledTime:
              _atWeekdayTime(weekStart, tuesdayOffset, hour: 10, minute: 0),
          duration: const Duration(minutes: 45),
          location: printingHouse,
          priority: TaskPriority.urgent,
        ),
      ],
    )
    ..add(
      _scheduledTask(
        title: 'Press run: type setting & proofs',
        scheduledTime:
            _atWeekdayTime(weekStart, tuesdayOffset, hour: 11, minute: 15),
        duration: const Duration(minutes: 105),
        location: printingHouse,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Dinner with friends',
        scheduledTime:
            _atWeekdayTime(weekStart, tuesdayOffset, hour: 18, minute: 30),
        duration: const Duration(minutes: 90),
        location: 'Tavern',
      ),
    );

  // Wednesday (2)
  tasks
    ..add(
      _scheduledTask(
        title: 'Swim / exercise',
        scheduledTime: _atWeekdayTime(weekStart, 2, hour: 5, minute: 45),
        duration: const Duration(minutes: 40),
        location: 'River',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Subscriptions, invoices, and receipts',
        scheduledTime: _atWeekdayTime(weekStart, 2, hour: 9, minute: 5),
        duration: const Duration(minutes: 80),
        location: printingHouse,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Library Company: acquire new volumes',
        scheduledTime: _atWeekdayTime(weekStart, 2, hour: 13, minute: 10),
        duration: const Duration(minutes: 65),
        location: 'Library Company Hall',
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Writing block (editorial)',
        scheduledTime: _atWeekdayTime(weekStart, 2, hour: 15, minute: 30),
        duration: const Duration(minutes: 75),
        location: printingHouse,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Family time',
        scheduledTime: _atWeekdayTime(weekStart, 2, hour: 20, minute: 0),
        duration: const Duration(minutes: 75),
        location: 'Home',
      ),
    );

  // Thursday (3)
  tasks
    ..add(
      _scheduledTask(
        title: 'Post Office: routes & complaints',
        scheduledTime: _atWeekdayTime(weekStart, 3, hour: 7, minute: 50),
        duration: const Duration(minutes: 55),
        location: postOffice,
        priority: TaskPriority.urgent,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Apprentices: instruction & review',
        scheduledTime: _atWeekdayTime(weekStart, 3, hour: 10, minute: 20),
        duration: const Duration(minutes: 70),
        location: workshop,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Experiment prep (glass, silk, brass)',
        scheduledTime: _atWeekdayTime(weekStart, 3, hour: 14, minute: 0),
        duration: const Duration(minutes: 45),
        location: workshop,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Evening reading: philosophy',
        scheduledTime: _atWeekdayTime(weekStart, 3, hour: 21, minute: 0),
        duration: const Duration(minutes: 45),
        location: 'Home',
      ),
    );

  // Friday (4): longer day + critical task.
  tasks
    ..add(
      _scheduledTask(
        title: 'Morning correspondence & ledgers',
        scheduledTime: _atWeekdayTime(weekStart, 4, hour: 7, minute: 30),
        duration: const Duration(minutes: 60),
        location: printingHouse,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Weekly mail dispatch (seal & log)',
        scheduledTime: _atWeekdayTime(weekStart, 4, hour: 13, minute: 0),
        duration: const Duration(minutes: 60),
        location: postOffice,
        priority: TaskPriority.critical,
        checklist: const <TaskChecklistItem>[
          TaskChecklistItem(id: 'sort', label: 'Sort packets'),
          TaskChecklistItem(id: 'seal', label: 'Seal bags'),
          TaskChecklistItem(id: 'log', label: 'Log departures'),
        ],
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Junto: discussion & minutes',
        scheduledTime: _atWeekdayTime(weekStart, 4, hour: 19, minute: 30),
        duration: const Duration(minutes: 110),
        location: 'Junto Club',
        priority: TaskPriority.important,
      ),
    );

  // Saturday (5): errands + leisure + late evening.
  tasks
    ..add(
      _scheduledTask(
        title: 'Long walk',
        scheduledTime:
            _atWeekdayTime(weekStart, saturdayOffset, hour: 8, minute: 10),
        duration: const Duration(minutes: 75),
        location: 'Outdoors',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Errands & supplies',
        scheduledTime:
            _atWeekdayTime(weekStart, saturdayOffset, hour: 10, minute: 15),
        duration: const Duration(minutes: 95),
        location: 'Market',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Fix the kite & twine (for next storm)',
        scheduledTime:
            _atWeekdayTime(weekStart, saturdayOffset, hour: 15, minute: 40),
        duration: const Duration(minutes: 50),
        location: 'Home',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Music / relaxation',
        scheduledTime:
            _atWeekdayTime(weekStart, saturdayOffset, hour: 21, minute: 15),
        duration: const Duration(minutes: 45),
        location: 'Home',
      ),
    );

  // Sunday (6): lighter day with a few anchors.
  tasks
    ..add(
      _scheduledTask(
        title: 'Quiet reading & correspondence',
        scheduledTime:
            _atWeekdayTime(weekStart, sundayOffset, hour: 9, minute: 0),
        duration: const Duration(minutes: 75),
        location: 'Home',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Visit friends',
        scheduledTime:
            _atWeekdayTime(weekStart, sundayOffset, hour: 13, minute: 30),
        duration: const Duration(minutes: 120),
        location: 'Town',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Prepare week plan',
        scheduledTime:
            _atWeekdayTime(weekStart, sundayOffset, hour: 18, minute: 45),
        duration: const Duration(minutes: 40),
        location: 'Home',
        priority: TaskPriority.important,
      ),
    );

  return tasks;
}

List<CalendarTask> _unscheduledTasks() {
  const String printingHouse = 'Market Street Printing House';
  return <CalendarTask>[
    _unscheduledTask(
      title: 'Order fresh typefaces (long primer)',
      location: printingHouse,
      priority: TaskPriority.important,
    ),
    _unscheduledTask(
      title: 'Sketch improvements to the Franklin stove',
      priority: TaskPriority.important,
      checklist: const <TaskChecklistItem>[
        TaskChecklistItem(id: 'draft', label: 'Draft new airflow sketch'),
        TaskChecklistItem(id: 'measure', label: 'Note measurements'),
      ],
    ),
    _unscheduledTask(
      title: 'Read: Addison & Steele (notes for style)',
    ),
    _unscheduledTask(
      title: 'Repair kite silk & twine for the next storm',
    ),
    _unscheduledTask(
      title: 'Write short notes of thanks (subscriptions and favors)',
    ),
    _unscheduledTask(
      title: 'Prepare Sunday dinner list',
    ),
    _unscheduledTask(
      title: 'Junto: prepare agenda & minutes',
      priority: TaskPriority.important,
      location: 'Junto Club',
    ),
    _unscheduledTask(
      title: 'Library Company: trustees session (schedule time)',
      priority: TaskPriority.important,
      location: 'Library Company Hall',
    ),
    _unscheduledTask(
      title: 'Draft sermon notes (optional)',
    ),
    _unscheduledTask(
      title: 'Organize workshop shelves',
      location: 'Workshop',
      checklist: const <TaskChecklistItem>[
        TaskChecklistItem(id: 'bins', label: 'Label bins'),
        TaskChecklistItem(id: 'tools', label: 'Return tools'),
      ],
    ),
  ];
}

List<CalendarTask> _reminderTasks(DateTime weekStart) {
  const String postOffice = 'Philadelphia Post Office';
  const String printingHouse = 'Market Street Printing House';

  const ReminderPreferences deadlineReminder = ReminderPreferences(
    enabled: true,
    deadlineOffsets: <Duration>[
      _demoReminderLeadMedium,
      _demoReminderLeadShort,
    ],
  );

  return <CalendarTask>[
    _deadlineTask(
      title: 'Reply to Paris letter',
      deadline: _atWeekdayTime(weekStart, 1, hour: 20, minute: 0),
      priority: TaskPriority.important,
      reminders: deadlineReminder,
    ),
    _deadlineTask(
      title: 'Return borrowed book',
      deadline: _atWeekdayTime(weekStart, 3, hour: 16, minute: 0),
      location: 'Library Company Hall',
      priority: TaskPriority.urgent,
      reminders: deadlineReminder,
    ),
    _deadlineTask(
      title: 'Send subscription receipts',
      deadline: _atWeekdayTime(weekStart, 2, hour: 18, minute: 0),
      location: printingHouse,
      priority: TaskPriority.important,
      reminders: deadlineReminder,
    ),
    _deadlineTask(
      title: 'Pay rent for the printing house',
      deadline: _atWeekdayTime(weekStart, 4, hour: 17, minute: 0),
      location: printingHouse,
      priority: TaskPriority.urgent,
      reminders: deadlineReminder,
    ),
    _deadlineTask(
      title: 'Post Office: confirm weekly route changes',
      deadline: _atWeekdayTime(weekStart, 0, hour: 19, minute: 0),
      location: postOffice,
      priority: TaskPriority.urgent,
      reminders: deadlineReminder,
    ),
  ];
}

List<DayEvent> _dayEvents(DateTime weekStart) {
  return <DayEvent>[
    DayEvent.create(
      title: 'Market day',
      startDate: weekStart.add(const Duration(days: 2)),
      description: 'Errands, supplies, and quick meetings.',
    ),
    DayEvent.create(
      title: 'Fire company drill',
      startDate: weekStart.add(const Duration(days: 3)),
      description: 'Equipment check & muster practice.',
    ),
    DayEvent.create(
      title: 'Weekend visitors',
      startDate: weekStart.add(const Duration(days: 5)),
      endDate: weekStart.add(const Duration(days: 6)),
      description: 'Guests in town; keep the schedule flexible.',
    ),
  ];
}

CalendarModel _attachCriticalPaths(CalendarModel model) {
  final List<CalendarTask> candidates =
      model.tasks.values.toList(growable: false);

  CalendarTask? findByTitle(String title) {
    for (final CalendarTask task in candidates) {
      if (task.title == title) {
        return task;
      }
    }
    return null;
  }

  final CalendarTask? correspondence =
      findByTitle('Morning correspondence & ledgers');
  final CalendarTask? proofs =
      findByTitle('Press run: Gazette proofs & corrections');
  final CalendarTask? dispatches =
      findByTitle('Weekly mail dispatch (seal & log)');

  final List<String> pathTaskIds = <String>[
    if (correspondence != null) correspondence.id,
    if (proofs != null) proofs.id,
    if (dispatches != null) dispatches.id,
  ];

  if (pathTaskIds.isEmpty) {
    return model;
  }

  final CalendarCriticalPath path =
      CalendarCriticalPath.create(name: 'Gazette & Dispatch');
  CalendarModel updated = model.addCriticalPath(path);
  for (final String taskId in pathTaskIds) {
    updated = updated.addTaskToCriticalPath(
      pathId: path.id,
      taskId: taskId,
    );
  }
  return updated;
}
