const int calendarTaskTitleMaxLength = 300;

const String calendarTaskTitleLimitWarning =
    'Task titles are limited to $calendarTaskTitleMaxLength characters. Shorten this text or move details into the description before saving.';

const String calendarTaskTitleFriendlyError =
    'Task title is too long. Please use fewer than $calendarTaskTitleMaxLength characters.';

const List<Duration> calendarDefaultStartReminderOffsets = <Duration>[
  Duration(hours: 1),
  Duration(minutes: 30),
  Duration(minutes: 15),
  Duration.zero,
];

const List<Duration> calendarDefaultDeadlineReminderOffsets = <Duration>[
  Duration(days: 1),
  Duration(hours: 1),
  Duration(minutes: 30),
  Duration(minutes: 15),
  Duration.zero,
];

const List<Duration> calendarReminderStartOptions = <Duration>[
  Duration(days: 1),
  Duration(hours: 3),
  Duration(hours: 1),
  Duration(minutes: 30),
  Duration(minutes: 15),
  Duration.zero,
];

const List<Duration> calendarReminderDeadlineOptions = <Duration>[
  Duration(days: 2),
  Duration(days: 1),
  Duration(hours: 6),
  Duration(hours: 1),
  Duration(minutes: 30),
  Duration(minutes: 15),
  Duration.zero,
];

const String calendarSnapshotUnavailableWarningTitle = 'Calendar sync';
const String calendarSnapshotUnavailableWarningMessage =
    'Calendar snapshot unavailable. Export your calendar JSON from another '
    'device and import it here to restore.';
