import 'package:hive/hive.dart';

import '../models/calendar_critical_path.dart';
import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import '../models/duration_adapter.dart';

/// Ensures all calendar-related Hive adapters are registered exactly once.
void registerCalendarHiveAdapters([HiveInterface? hive]) {
  final target = hive ?? Hive;

  if (!target.isAdapterRegistered(DurationAdapter().typeId)) {
    target.registerAdapter<Duration>(DurationAdapter());
  }
  if (!target.isAdapterRegistered(TaskPriorityAdapter().typeId)) {
    target.registerAdapter<TaskPriority>(TaskPriorityAdapter());
  }
  if (!target.isAdapterRegistered(TaskOccurrenceOverrideAdapter().typeId)) {
    target.registerAdapter<TaskOccurrenceOverride>(
      TaskOccurrenceOverrideAdapter(),
    );
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
  if (!target.isAdapterRegistered(CalendarModelAdapter().typeId)) {
    target.registerAdapter<CalendarModel>(CalendarModelAdapter());
  }
}
