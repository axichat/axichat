// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';

const Duration calendarStateWaitTimeout = Duration(seconds: 2);

Future<bool> waitForTasksInCalendar({
  required BaseCalendarBloc bloc,
  required Set<String> taskIds,
  Duration timeout = calendarStateWaitTimeout,
}) async {
  bool containsAll(CalendarState state) =>
      taskIds.every(state.model.tasks.containsKey);
  if (containsAll(bloc.state)) {
    return true;
  }
  try {
    await bloc.stream
        .map(containsAll)
        .firstWhere((isReady) => isReady)
        .timeout(timeout);
    return true;
  } on TimeoutException {
    return false;
  }
}

Future<bool> waitForCriticalPathTasks({
  required BaseCalendarBloc bloc,
  required String pathId,
  required Set<String> taskIds,
  Duration timeout = calendarStateWaitTimeout,
}) async {
  bool containsAll(CalendarState state) {
    final CalendarCriticalPath? path = state.model.criticalPaths[pathId];
    if (path == null || path.isArchived) {
      return false;
    }
    return taskIds.every(path.taskIds.contains);
  }

  if (containsAll(bloc.state)) {
    return true;
  }
  try {
    await bloc.stream
        .map(containsAll)
        .firstWhere((isReady) => isReady)
        .timeout(timeout);
    return true;
  } on TimeoutException {
    return false;
  }
}

Future<bool> waitForCalendarChecksum({
  required BaseCalendarBloc bloc,
  required String checksum,
  Duration timeout = calendarStateWaitTimeout,
}) async {
  bool matches(CalendarState state) => state.model.checksum == checksum;
  if (matches(bloc.state)) {
    return true;
  }
  try {
    await bloc.stream
        .map(matches)
        .firstWhere((isReady) => isReady)
        .timeout(timeout);
    return true;
  } on TimeoutException {
    return false;
  }
}
