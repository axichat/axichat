import 'package:hive/hive.dart';

import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/models/calendar_item.dart';
import 'package:axichat/src/calendar/models/calendar_journal.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/duration_adapter.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

final Set<HiveInterface> _registeredAdapterTargets = <HiveInterface>{};

/// Ensures all calendar-related Hive adapters are registered exactly once.
void registerCalendarHiveAdapters([HiveInterface? hive]) {
  final HiveInterface target = hive ?? Hive;
  if (_registeredAdapterTargets.contains(target)) {
    return;
  }

  if (!target.isAdapterRegistered(DurationAdapter().typeId)) {
    target.registerAdapter<Duration>(DurationAdapter());
  }
  if (!target.isAdapterRegistered(CalendarDateTimeAdapter().typeId)) {
    target.registerAdapter<CalendarDateTime>(CalendarDateTimeAdapter());
  }
  if (!target.isAdapterRegistered(CalendarWeekdayAdapter().typeId)) {
    target.registerAdapter<CalendarWeekday>(CalendarWeekdayAdapter());
  }
  if (!target.isAdapterRegistered(RecurrenceWeekdayAdapter().typeId)) {
    target.registerAdapter<RecurrenceWeekday>(RecurrenceWeekdayAdapter());
  }
  if (!target.isAdapterRegistered(RecurrenceRangeAdapter().typeId)) {
    target.registerAdapter<RecurrenceRange>(RecurrenceRangeAdapter());
  }
  if (!target.isAdapterRegistered(CalendarPropertyParameterAdapter().typeId)) {
    target.registerAdapter<CalendarPropertyParameter>(
      CalendarPropertyParameterAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarRawPropertyAdapter().typeId)) {
    target.registerAdapter<CalendarRawProperty>(CalendarRawPropertyAdapter());
  }
  if (!target.isAdapterRegistered(CalendarRawComponentAdapter().typeId)) {
    target.registerAdapter<CalendarRawComponent>(CalendarRawComponentAdapter());
  }
  if (!target.isAdapterRegistered(CalendarTimeZoneDefinitionAdapter().typeId)) {
    target.registerAdapter<CalendarTimeZoneDefinition>(
      CalendarTimeZoneDefinitionAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarAttachmentAdapter().typeId)) {
    target.registerAdapter<CalendarAttachment>(CalendarAttachmentAdapter());
  }
  if (!target.isAdapterRegistered(CalendarGeoAdapter().typeId)) {
    target.registerAdapter<CalendarGeo>(CalendarGeoAdapter());
  }
  if (!target.isAdapterRegistered(CalendarIcsStatusAdapter().typeId)) {
    target.registerAdapter<CalendarIcsStatus>(CalendarIcsStatusAdapter());
  }
  if (!target.isAdapterRegistered(CalendarPrivacyClassAdapter().typeId)) {
    target.registerAdapter<CalendarPrivacyClass>(
      CalendarPrivacyClassAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarTransparencyAdapter().typeId)) {
    target.registerAdapter<CalendarTransparency>(
      CalendarTransparencyAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarIcsComponentTypeAdapter().typeId)) {
    target.registerAdapter<CalendarIcsComponentType>(
      CalendarIcsComponentTypeAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarAlarmActionAdapter().typeId)) {
    target.registerAdapter<CalendarAlarmAction>(CalendarAlarmActionAdapter());
  }
  if (!target.isAdapterRegistered(CalendarAlarmTriggerTypeAdapter().typeId)) {
    target.registerAdapter<CalendarAlarmTriggerType>(
      CalendarAlarmTriggerTypeAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarAlarmRelativeToAdapter().typeId)) {
    target.registerAdapter<CalendarAlarmRelativeTo>(
      CalendarAlarmRelativeToAdapter(),
    );
  }
  if (!target.isAdapterRegistered(
    CalendarAlarmOffsetDirectionAdapter().typeId,
  )) {
    target.registerAdapter<CalendarAlarmOffsetDirection>(
      CalendarAlarmOffsetDirectionAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarAlarmTriggerAdapter().typeId)) {
    target.registerAdapter<CalendarAlarmTrigger>(CalendarAlarmTriggerAdapter());
  }
  if (!target.isAdapterRegistered(CalendarAlarmRecipientAdapter().typeId)) {
    target.registerAdapter<CalendarAlarmRecipient>(
      CalendarAlarmRecipientAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarAlarmAdapter().typeId)) {
    target.registerAdapter<CalendarAlarm>(CalendarAlarmAdapter());
  }
  if (!target.isAdapterRegistered(CalendarParticipantRoleAdapter().typeId)) {
    target.registerAdapter<CalendarParticipantRole>(
      CalendarParticipantRoleAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarParticipantStatusAdapter().typeId)) {
    target.registerAdapter<CalendarParticipantStatus>(
      CalendarParticipantStatusAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarParticipantTypeAdapter().typeId)) {
    target.registerAdapter<CalendarParticipantType>(
      CalendarParticipantTypeAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarOrganizerAdapter().typeId)) {
    target.registerAdapter<CalendarOrganizer>(CalendarOrganizerAdapter());
  }
  if (!target.isAdapterRegistered(CalendarAttendeeAdapter().typeId)) {
    target.registerAdapter<CalendarAttendee>(CalendarAttendeeAdapter());
  }
  if (!target.isAdapterRegistered(CalendarCriticalPathLinkAdapter().typeId)) {
    target.registerAdapter<CalendarCriticalPathLink>(
      CalendarCriticalPathLinkAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarAxiExtensionsAdapter().typeId)) {
    target.registerAdapter<CalendarAxiExtensions>(
      CalendarAxiExtensionsAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarIcsMetaAdapter().typeId)) {
    target.registerAdapter<CalendarIcsMeta>(CalendarIcsMetaAdapter());
  }
  if (!target.isAdapterRegistered(CalendarMethodAdapter().typeId)) {
    target.registerAdapter<CalendarMethod>(CalendarMethodAdapter());
  }
  if (!target.isAdapterRegistered(CalendarSharingPolicyAdapter().typeId)) {
    target.registerAdapter<CalendarSharingPolicy>(
      CalendarSharingPolicyAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarCollectionAdapter().typeId)) {
    target.registerAdapter<CalendarCollection>(CalendarCollectionAdapter());
  }
  if (!target.isAdapterRegistered(CalendarFreeBusyTypeAdapter().typeId)) {
    target.registerAdapter<CalendarFreeBusyType>(
      CalendarFreeBusyTypeAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarFreeBusyIntervalAdapter().typeId)) {
    target.registerAdapter<CalendarFreeBusyInterval>(
      CalendarFreeBusyIntervalAdapter(),
    );
  }
  if (!target.isAdapterRegistered(
    CalendarAvailabilityWindowAdapter().typeId,
  )) {
    target.registerAdapter<CalendarAvailabilityWindow>(
      CalendarAvailabilityWindowAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarAvailabilityAdapter().typeId)) {
    target.registerAdapter<CalendarAvailability>(
      CalendarAvailabilityAdapter(),
    );
  }
  if (!target
      .isAdapterRegistered(CalendarAvailabilityOverlayAdapter().typeId)) {
    target.registerAdapter<CalendarAvailabilityOverlay>(
      CalendarAvailabilityOverlayAdapter(),
    );
  }
  if (!target.isAdapterRegistered(CalendarChatRoleAdapter().typeId)) {
    target.registerAdapter<CalendarChatRole>(CalendarChatRoleAdapter());
  }
  if (!target.isAdapterRegistered(CalendarChatAclAdapter().typeId)) {
    target.registerAdapter<CalendarChatAcl>(CalendarChatAclAdapter());
  }
  if (!target.isAdapterRegistered(CalendarItemTypeAdapter().typeId)) {
    target.registerAdapter<CalendarItemType>(CalendarItemTypeAdapter());
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
  if (!target.isAdapterRegistered(CalendarJournalAdapter().typeId)) {
    target.registerAdapter<CalendarJournal>(CalendarJournalAdapter());
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

  _registeredAdapterTargets.add(target);
}
