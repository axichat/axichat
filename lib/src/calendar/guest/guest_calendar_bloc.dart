// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/common/safe_logging.dart';

class GuestCalendarBloc extends BaseCalendarBloc {
  GuestCalendarBloc({
    required super.storage,
    super.reminderController,
  }) : super(
          storagePrefix: guestStoragePrefix,
        );

  @override
  Future<void> onTaskAdded(CalendarTask task) async {
    // Guest mode: no sync required
  }

  @override
  Future<void> onTaskUpdated(CalendarTask task) async {
    // Guest mode: no sync required
  }

  @override
  Future<void> onTaskDeleted(CalendarTask task) async {
    // Guest mode: no sync required
  }

  @override
  Future<void> onTaskCompleted(CalendarTask task) async {
    // Guest mode: no sync required
  }

  @override
  Future<void> onDayEventAdded(DayEvent event) async {
    // Guest mode: no sync required
  }

  @override
  Future<void> onDayEventUpdated(DayEvent event) async {
    // Guest mode: no sync required
  }

  @override
  Future<void> onDayEventDeleted(DayEvent event) async {
    // Guest mode: no sync required
  }

  @override
  void logError(String message, Object error) {
    SafeLogging.debugLog(message, name: 'GuestCalendarBloc');
  }
}
