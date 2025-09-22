import 'dart:developer' as developer;

import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../bloc/base_calendar_bloc.dart';
import '../models/calendar_task.dart';
import '../reminders/calendar_reminder_controller.dart';
import '../storage/storage_builders.dart';

class GuestCalendarBloc extends BaseCalendarBloc {
  GuestCalendarBloc({
    required Storage storage,
    CalendarReminderController? reminderController,
  }) : super(
          storage: storage,
          storagePrefix: guestStoragePrefix,
          storageId: 'state',
          reminderController: reminderController,
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
  void logError(String message, Object error) {
    developer.log(message, name: 'GuestCalendarBloc');
  }
}
