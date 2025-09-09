import 'dart:developer' as developer;

import 'package:hive/hive.dart';

import '../bloc/base_calendar_bloc.dart';
import '../models/calendar_model.dart';
import '../models/calendar_task.dart';

class GuestCalendarBloc extends BaseCalendarBloc {
  GuestCalendarBloc({
    required Box<CalendarModel> guestCalendarBox,
  }) : super(
          calendarBox: guestCalendarBox,
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
