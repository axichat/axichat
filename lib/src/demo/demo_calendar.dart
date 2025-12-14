import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

const int _demoWorkdayCount = 5;
const int _demoWorkdayStartHour = 8;
const int _demoWorkdayEndHour = 18;
const int _demoWorkdaySlotsPerDay = _demoWorkdayEndHour - _demoWorkdayStartHour;
const int _demoWorkdayOccupiedSlotsPerDay = 8;

const Duration _demoTaskDuration = Duration(hours: 1);
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

    assert(
      _hasExactWorkWeekOccupancy(model, weekStart),
      'Demo calendar must occupy exactly 80% of workday cells.',
    );

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

DateTime _atWeekdayHour(DateTime weekStart, int weekdayOffset, int hour) {
  final DateTime day = weekStart.add(Duration(days: weekdayOffset));
  return DateTime(day.year, day.month, day.day, hour);
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

  const ReminderPreferences startReminder = ReminderPreferences(
    enabled: true,
    startOffsets: <Duration>[
      _demoReminderLeadShort,
      _demoReminderLeadMedium,
    ],
  );

  final List<CalendarTask> tasks = <CalendarTask>[];

  // Weekdays only: Monday=0..Friday=4.
  for (var weekdayOffset = 0;
      weekdayOffset < _demoWorkdayCount;
      weekdayOffset++) {
    tasks
      ..add(
        _scheduledTask(
          title: 'Morning correspondence & ledgers',
          scheduledTime: _atWeekdayHour(weekStart, weekdayOffset, 8),
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
          scheduledTime: _atWeekdayHour(weekStart, weekdayOffset, 9),
          location: printingHouse,
          priority: TaskPriority.important,
          checklist: const <TaskChecklistItem>[
            TaskChecklistItem(id: 'edit', label: 'Edit copy'),
            TaskChecklistItem(id: 'set', label: 'Set type'),
            TaskChecklistItem(id: 'proof', label: 'Proof & correct'),
          ],
        ),
      );

    if (weekdayOffset != tuesdayOffset) {
      tasks.add(
        _scheduledTask(
          title: 'Appointments & walk-ins',
          scheduledTime: _atWeekdayHour(weekStart, weekdayOffset, 10),
          location: printingHouse,
        ),
      );
    }

    tasks
      ..add(
        _scheduledTask(
          title: 'Apprentices: instruction & review',
          scheduledTime: _atWeekdayHour(weekStart, weekdayOffset, 11),
          location: workshop,
          priority: TaskPriority.important,
        ),
      )
      ..add(
        _scheduledTask(
          title: 'Dispatches & deliveries',
          scheduledTime: _atWeekdayHour(weekStart, weekdayOffset, 13),
          location: postOffice,
          priority: TaskPriority.urgent,
        ),
      )
      ..add(
        _scheduledTask(
          title: 'Experiments & notes (electricity)',
          scheduledTime: _atWeekdayHour(weekStart, weekdayOffset, 14),
          location: workshop,
        ),
      )
      ..add(
        _scheduledTask(
          title: 'Subscriptions, invoices, and receipts',
          scheduledTime: _atWeekdayHour(weekStart, weekdayOffset, 15),
          location: printingHouse,
          priority: TaskPriority.important,
        ),
      )
      ..add(
        _scheduledTask(
          title: 'Writing block (letters, editorials, proposals)',
          scheduledTime: _atWeekdayHour(weekStart, weekdayOffset, 16),
          location: printingHouse,
        ),
      );
  }

  // Side-by-side example: overlap two meetings in the same hour on Tuesday.
  tasks.addAll(
    <CalendarTask>[
      _scheduledTask(
        title: 'Committee meeting: civic improvements',
        scheduledTime: _atWeekdayHour(weekStart, tuesdayOffset, 10),
        location: 'State House',
        priority: TaskPriority.urgent,
      ),
      _scheduledTask(
        title: 'Printer’s client: pamphlet commission',
        scheduledTime: _atWeekdayHour(weekStart, tuesdayOffset, 10),
        location: printingHouse,
        priority: TaskPriority.urgent,
      ),
    ],
  );

  // Feature highlights: a few anchored tasks with distinct priorities.
  tasks.add(
    _scheduledTask(
      title: 'Weekly mail dispatch (seal & log)',
      scheduledTime: _atWeekdayHour(weekStart, 4, 13),
      location: postOffice,
      priority: TaskPriority.critical,
      checklist: const <TaskChecklistItem>[
        TaskChecklistItem(id: 'sort', label: 'Sort packets'),
        TaskChecklistItem(id: 'seal', label: 'Seal bags'),
        TaskChecklistItem(id: 'log', label: 'Log departures'),
      ],
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

bool _hasExactWorkWeekOccupancy(CalendarModel model, DateTime weekStart) {
  final DateTime monday = weekStart;
  final DateTime friday =
      monday.add(const Duration(days: _demoWorkdayCount - 1));

  final DateTime rangeStart = DateTime(
    monday.year,
    monday.month,
    monday.day,
    _demoWorkdayStartHour,
  );
  final DateTime rangeEnd = DateTime(
    friday.year,
    friday.month,
    friday.day,
    _demoWorkdayEndHour,
  ).add(const Duration(days: 1));

  final Set<String> occupiedCells = <String>{};

  for (final CalendarTask task in model.tasks.values) {
    final DateTime? start = task.scheduledTime;
    if (start == null) {
      continue;
    }
    if (start.isBefore(rangeStart) || !start.isBefore(rangeEnd)) {
      continue;
    }
    if (start.weekday < DateTime.monday || start.weekday > DateTime.friday) {
      continue;
    }
    final int hour = start.hour;
    if (hour < _demoWorkdayStartHour || hour >= _demoWorkdayEndHour) {
      continue;
    }
    final String key = '${start.year}-${start.month}-${start.day}-$hour';
    occupiedCells.add(key);
  }

  const int totalCells = _demoWorkdayCount * _demoWorkdaySlotsPerDay;
  const int expectedOccupied =
      _demoWorkdayCount * _demoWorkdayOccupiedSlotsPerDay;

  const double occupancyRatio =
      _demoWorkdayOccupiedSlotsPerDay / _demoWorkdaySlotsPerDay;
  assert(occupancyRatio == 0.8,
      'Demo occupancy ratio constant must be exactly 0.8');

  return occupiedCells.length == expectedOccupied &&
      expectedOccupied * 5 == totalCells * 4;
}
