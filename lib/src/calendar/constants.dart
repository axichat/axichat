// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const int calendarTaskTitleMaxLength = 300;
const Duration calendarDefaultTaskDuration = Duration(hours: 1);
const Duration calendarMinimumTaskDuration = Duration(minutes: 15);

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
