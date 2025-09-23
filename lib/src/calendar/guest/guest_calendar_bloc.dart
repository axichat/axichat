import 'dart:developer' as developer;

import '../bloc/base_calendar_bloc.dart';
import '../models/calendar_task.dart';
import '../storage/storage_builders.dart';

class GuestCalendarBloc extends BaseCalendarBloc {
  GuestCalendarBloc({
    required super.storage,
    super.reminderController,
  }) : super(
          storagePrefix: guestStoragePrefix,
          storageId: 'state',
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
