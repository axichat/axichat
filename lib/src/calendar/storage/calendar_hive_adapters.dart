import 'package:hive/hive.dart';

import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/duration_adapter.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

/// Ensures all calendar-related Hive adapters are registered exactly once.
void registerCalendarHiveAdapters([HiveInterface? hive]) {
  final target = hive ?? Hive;

  if (!target.isAdapterRegistered(DurationAdapter().typeId)) {
    target.registerAdapter<Duration>(DurationAdapter());
  }
  if (!target.isAdapterRegistered(TaskPriorityAdapter().typeId)) {
    target.registerAdapter<TaskPriority>(TaskPriorityAdapter());
  }
  if (!target.isAdapterRegistered(TaskChecklistItemAdapter().typeId)) {
    target.registerAdapter<TaskChecklistItem>(TaskChecklistItemAdapter());
  }
  if (!target.isAdapterRegistered(TaskOccurrenceOverrideAdapter().typeId)) {
    target.registerAdapter<TaskOccurrenceOverride>(
      TaskOccurrenceOverrideAdapter(),
    );
  }
  if (!target.isAdapterRegistered(ReminderPreferencesAdapter().typeId)) {
    target.registerAdapter<ReminderPreferences>(ReminderPreferencesAdapter());
  }
  if (!target.isAdapterRegistered(CalendarTaskAdapter().typeId)) {
    target.registerAdapter<CalendarTask>(CalendarTaskAdapter());
  }
  if (!target.isAdapterRegistered(RecurrenceRuleAdapter().typeId)) {
    target.registerAdapter<RecurrenceRule>(RecurrenceRuleAdapter());
  }
  if (!target.isAdapterRegistered(RecurrenceFrequencyAdapter().typeId)) {
    target.registerAdapter<RecurrenceFrequency>(
      RecurrenceFrequencyAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarCriticalPathAdapter().typeId)) {
    target.registerAdapter<CalendarCriticalPath>(
      CalendarCriticalPathAdapter(),
    );
  }
  if (!target.isAdapterRegistered(DayEventAdapter().typeId)) {
    target.registerAdapter<DayEvent>(DayEventAdapter());
  }
  if (!target.isAdapterRegistered(CalendarModelAdapter().typeId)) {
    target.registerAdapter<CalendarModel>(CalendarModelAdapter());
  }
}
