// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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

  static CalendarModel franklin({required DateTime anchor}) {
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
  return base.withScheduled(scheduledTime: scheduledTime, duration: duration);
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
  const String printingHouse = 'Market Street Studio Hub';
  const String postOffice = 'Philadelphia Shipping Office';
  const String workshop = 'Workshop';
  const int tuesdayOffset = 1;
  const int saturdayOffset = 5;
  const int sundayOffset = 6;

  const ReminderPreferences startReminder = ReminderPreferences(
    enabled: true,
    startOffsets: <Duration>[_demoReminderLeadShort, _demoReminderLeadMedium],
  );

  final List<CalendarTask> tasks = <CalendarTask>[];

  // Monday (0)
  tasks
    ..add(
      _scheduledTask(
        title: 'Rise & plan the day (priorities)',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 5, minute: 10),
        duration: const Duration(minutes: 25),
        priority: TaskPriority.important,
        reminders: startReminder,
        checklist: const <TaskChecklistItem>[
          TaskChecklistItem(id: 'virtue', label: 'Select focus for the day'),
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
        title: 'Morning inbox & followups',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 8, minute: 5),
        duration: const Duration(minutes: 70),
        location: printingHouse,
        priority: TaskPriority.important,
        reminders: startReminder,
        checklist: const <TaskChecklistItem>[
          TaskChecklistItem(id: 'letters', label: 'Reply to messages'),
          TaskChecklistItem(id: 'accounts', label: 'Update dashboards'),
          TaskChecklistItem(id: 'plan', label: "Set today's priorities"),
        ],
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Publishing block: newsletter edits & revisions',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 9, minute: 30),
        duration: const Duration(minutes: 90),
        location: printingHouse,
        priority: TaskPriority.important,
        checklist: const <TaskChecklistItem>[
          TaskChecklistItem(id: 'edit', label: 'Edit draft'),
          TaskChecklistItem(id: 'set', label: 'Set layout'),
          TaskChecklistItem(id: 'proof', label: 'Review & correct'),
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
        title: 'Walk to store (fresh supplies)',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 12, minute: 10),
        duration: const Duration(minutes: 35),
        location: 'Market',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Shipments & deliveries',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 13, minute: 20),
        duration: const Duration(minutes: 50),
        location: postOffice,
        priority: TaskPriority.urgent,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Prototypes & notes (hardware)',
        scheduledTime: _atWeekdayTime(weekStart, 0, hour: 15, minute: 5),
        duration: const Duration(minutes: 80),
        location: workshop,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Evening messages (friends & clients)',
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
        title: 'Early workshop: tools & prep',
        scheduledTime: _atWeekdayTime(
          weekStart,
          tuesdayOffset,
          hour: 7,
          minute: 0,
        ),
        duration: const Duration(minutes: 55),
        location: workshop,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Appointments & check-ins',
        scheduledTime: _atWeekdayTime(
          weekStart,
          tuesdayOffset,
          hour: 8,
          minute: 40,
        ),
        duration: const Duration(minutes: 50),
        location: printingHouse,
      ),
    )
    ..addAll(<CalendarTask>[
      _scheduledTask(
        title: 'Committee meeting: product improvements',
        scheduledTime: _atWeekdayTime(
          weekStart,
          tuesdayOffset,
          hour: 9,
          minute: 30,
        ),
        duration: const Duration(minutes: 90),
        location: 'Main Office',
        priority: TaskPriority.urgent,
      ),
      _scheduledTask(
        title: 'Client request: campaign brochure',
        scheduledTime: _atWeekdayTime(
          weekStart,
          tuesdayOffset,
          hour: 10,
          minute: 0,
        ),
        duration: const Duration(minutes: 45),
        location: printingHouse,
        priority: TaskPriority.urgent,
      ),
    ])
    ..add(
      _scheduledTask(
        title: 'Publishing block: layout pass & proofs',
        scheduledTime: _atWeekdayTime(
          weekStart,
          tuesdayOffset,
          hour: 11,
          minute: 15,
        ),
        duration: const Duration(minutes: 105),
        location: printingHouse,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Teammates: instruction & review',
        scheduledTime: _atWeekdayTime(
          weekStart,
          tuesdayOffset,
          hour: 14,
          minute: 0,
        ),
        duration: const Duration(minutes: 70),
        location: workshop,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Research block: acquire new references',
        scheduledTime: _atWeekdayTime(
          weekStart,
          tuesdayOffset,
          hour: 15,
          minute: 10,
        ),
        duration: const Duration(minutes: 60),
        location: 'Research Team Room',
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Dinner with friends',
        scheduledTime: _atWeekdayTime(
          weekStart,
          tuesdayOffset,
          hour: 18,
          minute: 30,
        ),
        duration: const Duration(minutes: 90),
        location: 'Cafe',
      ),
    );

  // Wednesday (2)
  tasks
    ..add(
      _scheduledTask(
        title: 'Swim / exercise',
        scheduledTime: _atWeekdayTime(weekStart, 2, hour: 5, minute: 45),
        duration: const Duration(minutes: 40),
        location: 'Gym',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Billing, invoices, and receipts',
        scheduledTime: _atWeekdayTime(weekStart, 2, hour: 9, minute: 5),
        duration: const Duration(minutes: 80),
        location: printingHouse,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Research block: acquire new references',
        scheduledTime: _atWeekdayTime(weekStart, 2, hour: 13, minute: 10),
        duration: const Duration(minutes: 65),
        location: 'Research Team Room',
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
        title: 'Shipping desk: routes & complaints',
        scheduledTime: _atWeekdayTime(weekStart, 3, hour: 7, minute: 50),
        duration: const Duration(minutes: 55),
        location: postOffice,
        priority: TaskPriority.urgent,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Teammates: instruction & review',
        scheduledTime: _atWeekdayTime(weekStart, 3, hour: 9, minute: 30),
        duration: const Duration(minutes: 70),
        location: workshop,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Prototype prep (parts, cables, tools)',
        scheduledTime: _atWeekdayTime(weekStart, 3, hour: 14, minute: 0),
        duration: const Duration(minutes: 45),
        location: workshop,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Evening reading: strategy',
        scheduledTime: _atWeekdayTime(weekStart, 3, hour: 21, minute: 0),
        duration: const Duration(minutes: 45),
        location: 'Home',
      ),
    );

  // Friday (4): longer day + critical task.
  tasks
    ..add(
      _scheduledTask(
        title: 'Morning inbox & followups',
        scheduledTime: _atWeekdayTime(weekStart, 4, hour: 7, minute: 30),
        duration: const Duration(minutes: 60),
        location: printingHouse,
        priority: TaskPriority.important,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Weekly shipment dispatch (pack & log)',
        scheduledTime: _atWeekdayTime(weekStart, 4, hour: 13, minute: 0),
        duration: const Duration(minutes: 90),
        location: postOffice,
        priority: TaskPriority.critical,
        checklist: const <TaskChecklistItem>[
          TaskChecklistItem(id: 'sort', label: 'Sort packages'),
          TaskChecklistItem(id: 'seal', label: 'Seal boxes'),
          TaskChecklistItem(id: 'log', label: 'Log departures'),
        ],
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Sync: discussion & minutes',
        scheduledTime: _atWeekdayTime(weekStart, 4, hour: 19, minute: 30),
        duration: const Duration(minutes: 110),
        location: 'Team Hub',
        priority: TaskPriority.important,
      ),
    );

  // Saturday (5): errands + leisure + late evening.
  tasks
    ..add(
      _scheduledTask(
        title: 'Long walk',
        scheduledTime: _atWeekdayTime(
          weekStart,
          saturdayOffset,
          hour: 7,
          minute: 25,
        ),
        duration: const Duration(minutes: 135),
        location: 'Outdoors',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Errands & supplies',
        scheduledTime: _atWeekdayTime(
          weekStart,
          saturdayOffset,
          hour: 10,
          minute: 45,
        ),
        duration: const Duration(minutes: 135),
        location: 'Market',
        priority: TaskPriority.urgent,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Fix the router & cabling (for next sprint)',
        scheduledTime: _atWeekdayTime(
          weekStart,
          saturdayOffset,
          hour: 16,
          minute: 0,
        ),
        duration: const Duration(minutes: 80),
        location: 'Home',
        priority: TaskPriority.critical,
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Music / relaxation',
        scheduledTime: _atWeekdayTime(
          weekStart,
          saturdayOffset,
          hour: 21,
          minute: 15,
        ),
        duration: const Duration(minutes: 45),
        location: 'Home',
      ),
    );

  // Sunday (6): lighter day with a few anchors.
  tasks
    ..add(
      _scheduledTask(
        title: 'Quiet reading & catchup',
        scheduledTime: _atWeekdayTime(
          weekStart,
          sundayOffset,
          hour: 9,
          minute: 0,
        ),
        duration: const Duration(minutes: 75),
        location: 'Home',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Visit friends',
        scheduledTime: _atWeekdayTime(
          weekStart,
          sundayOffset,
          hour: 13,
          minute: 30,
        ),
        duration: const Duration(minutes: 120),
        location: 'Town',
      ),
    )
    ..add(
      _scheduledTask(
        title: 'Prepare week plan',
        scheduledTime: _atWeekdayTime(
          weekStart,
          sundayOffset,
          hour: 18,
          minute: 45,
        ),
        duration: const Duration(minutes: 40),
        location: 'Home',
        priority: TaskPriority.important,
      ),
    );

  return tasks;
}

List<CalendarTask> _unscheduledTasks() {
  const String printingHouse = 'Market Street Studio Hub';
  return <CalendarTask>[
    _unscheduledTask(
      title: 'Order fresh templates (landing page)',
      location: printingHouse,
      priority: TaskPriority.important,
    ),
    _unscheduledTask(
      title: 'Sketch improvements to the office setup',
      priority: TaskPriority.important,
      checklist: const <TaskChecklistItem>[
        TaskChecklistItem(id: 'draft', label: 'Draft new layout sketch'),
        TaskChecklistItem(id: 'measure', label: 'Note measurements'),
      ],
    ),
    _unscheduledTask(title: 'Read: long product briefs (notes for style)'),
    _unscheduledTask(
        title: 'Repair spare cables & adapters for the next deploy'),
    _unscheduledTask(
      title: 'Write short notes of thanks (customers and favors)',
    ),
    _unscheduledTask(title: 'Prepare Sunday dinner list'),
    _unscheduledTask(
      title: 'Sync prep: agenda & minutes',
      priority: TaskPriority.important,
      location: 'Team Hub',
    ),
    _unscheduledTask(
      title: 'Research group: planning session (schedule time)',
      priority: TaskPriority.important,
      location: 'Research Team Room',
    ),
    _unscheduledTask(title: 'Draft meeting notes (optional)'),
    _unscheduledTask(
      title: 'Organize studio shelves',
      location: 'Workshop',
      checklist: const <TaskChecklistItem>[
        TaskChecklistItem(id: 'bins', label: 'Label bins'),
        TaskChecklistItem(id: 'tools', label: 'Return tools'),
      ],
    ),
  ];
}

List<CalendarTask> _reminderTasks(DateTime weekStart) {
  const String postOffice = 'Philadelphia Shipping Office';
  const String printingHouse = 'Market Street Studio Hub';

  const ReminderPreferences deadlineReminder = ReminderPreferences(
    enabled: true,
    deadlineOffsets: <Duration>[
      _demoReminderLeadMedium,
      _demoReminderLeadShort,
    ],
  );

  return <CalendarTask>[
    _deadlineTask(
      title: 'Reply to vendor email',
      deadline: _atWeekdayTime(weekStart, 1, hour: 20, minute: 0),
      priority: TaskPriority.important,
      reminders: deadlineReminder,
    ).copyWith(isCompleted: true),
    _deadlineTask(
      title: 'Return borrowed book',
      deadline: _atWeekdayTime(weekStart, 3, hour: 16, minute: 0),
      location: 'Research Team Room',
      priority: TaskPriority.urgent,
      reminders: deadlineReminder,
    ),
    _deadlineTask(
      title: 'Send billing receipts',
      deadline: _atWeekdayTime(weekStart, 2, hour: 18, minute: 0),
      location: printingHouse,
      priority: TaskPriority.important,
      reminders: deadlineReminder,
    ),
    _deadlineTask(
      title: 'Pay rent for the studio office',
      deadline: _atWeekdayTime(weekStart, 4, hour: 17, minute: 0),
      location: printingHouse,
      priority: TaskPriority.urgent,
      reminders: deadlineReminder,
    ),
    _deadlineTask(
      title: 'Shipping desk: confirm weekly route changes',
      deadline: _atWeekdayTime(weekStart, 0, hour: 19, minute: 0),
      location: postOffice,
      priority: TaskPriority.urgent,
      reminders: deadlineReminder,
    ).copyWith(isCompleted: true),
  ];
}

List<DayEvent> _dayEvents(DateTime weekStart) {
  return <DayEvent>[
    DayEvent.create(
      title: 'Errands day',
      startDate: weekStart.add(const Duration(days: 2)),
      description: 'Errands, supplies, and quick meetings.',
    ),
    DayEvent.create(
      title: 'Safety team drill',
      startDate: weekStart.add(const Duration(days: 3)),
      description: 'Equipment check & response practice.',
    ),
    DayEvent.create(
      title: 'Weekend guests',
      startDate: weekStart.add(const Duration(days: 5)),
      endDate: weekStart.add(const Duration(days: 6)),
      description: 'Guests in town; keep the schedule flexible.',
    ),
  ];
}

CalendarModel _attachCriticalPaths(CalendarModel model) {
  final List<CalendarTask> candidates = model.tasks.values.toList(
    growable: false,
  );

  CalendarTask? findByTitle(String title) {
    for (final CalendarTask task in candidates) {
      if (task.title == title) {
        return task;
      }
    }
    return null;
  }

  final CalendarTask? correspondence = findByTitle(
    'Morning inbox & followups',
  );
  final CalendarTask? proofs = findByTitle(
    'Publishing block: newsletter edits & revisions',
  );
  final CalendarTask? dispatches = findByTitle(
    'Weekly shipment dispatch (pack & log)',
  );

  final List<String> pathTaskIds = <String>[
    if (correspondence != null) correspondence.id,
    if (proofs != null) proofs.id,
    if (dispatches != null) dispatches.id,
  ];

  if (pathTaskIds.isEmpty) {
    return model;
  }

  final CalendarCriticalPath path = CalendarCriticalPath.create(
    name: 'Publishing & Shipping',
  );
  CalendarModel updated = model.addCriticalPath(path);
  for (final String taskId in pathTaskIds) {
    updated = updated.addTaskToCriticalPath(pathId: path.id, taskId: taskId);
  }
  return updated;
}
