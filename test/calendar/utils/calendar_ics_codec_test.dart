import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/calendar_ics_codec.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarIcsCodec decode', () {
    const String lineBreak = '\n';
    const String calendarStart = 'BEGIN:VCALENDAR';
    const String calendarEnd = 'END:VCALENDAR';
    const String versionLine = 'VERSION:2.0';
    const String prodIdLine = 'PRODID:-//Axichat//Calendar//EN';
    const String eventStart = 'BEGIN:VEVENT';
    const String eventEnd = 'END:VEVENT';
    const String todoStart = 'BEGIN:VTODO';
    const String todoEnd = 'END:VTODO';
    const String alarmStart = 'BEGIN:VALARM';
    const String alarmEnd = 'END:VALARM';
    const String alarmActionLine = 'ACTION:DISPLAY';
    const String alarmTriggerAfterLine = 'TRIGGER;RELATED=START:PT15M';
    const String methodCancelLine = 'METHOD:CANCEL';
    const String uidLabel = 'UID:';
    const String summaryLabel = 'SUMMARY:';
    const String rruleLabel = 'RRULE:';
    const String rruleName = 'RRULE';
    const String dtStampLine = 'DTSTAMP:20240101T000000Z';
    const String allDayStartLine = 'DTSTART;VALUE=DATE:20240101';
    const String allDayEndLine = 'DTEND;VALUE=DATE:20240103';
    const String todoStartLine = 'DTSTART:20240101T090000Z';
    const String overrideStartLine = 'DTSTART:20240102T090000Z';
    const String recurrenceIdLine = 'RECURRENCE-ID:20240102T090000Z';
    const String yearlyRuleValue = 'FREQ=YEARLY;BYMONTH=2;BYDAY=MO';
    const String yearlyRuleLine = '$rruleLabel$yearlyRuleValue';
    const String recurringRuleLine = 'RRULE:FREQ=DAILY';
    const String timedEventUid = 'event-2';
    const String timedEventSummary = 'Timed Event';
    const String timedEventEndLine = 'DTEND:20240101T100000Z';
    const int timedStartYear = 2024;
    const int timedStartMonth = 1;
    const int timedStartDay = 1;
    const int timedStartHour = 9;
    const int timedStartMinute = 0;
    const int timedStartSecond = 0;
    const String todoDueLine = 'DUE:20240101T110000Z';
    const String alarmTriggerBeforeStartLine = 'TRIGGER;RELATED=START:-PT15M';
    const String alarmTriggerBeforeEndLine = 'TRIGGER;RELATED=END:-PT30M';
    const int reminderStartOffsetMinutes = 15;
    const int reminderDeadlineOffsetMinutes = 30;
    const Duration startReminderOffset =
        Duration(minutes: reminderStartOffsetMinutes);
    const Duration deadlineReminderOffset =
        Duration(minutes: reminderDeadlineOffsetMinutes);
    const int reminderOffsetCount = 1;
    const String checklistTaskUid = 'todo-checklist';
    const String checklistSummary = 'Checklist Task';
    const String checklistPropertyPrefix = 'X-AXICHAT-CHECKLIST:';
    const String checklistItemIdFirst = 'item-a';
    const String checklistItemIdSecond = 'item-b';
    const String checklistItemLabelFirst = 'First';
    const String checklistItemLabelSecond = 'Second';
    const int checklistOrderFirst = 1;
    const int checklistOrderSecond = 0;
    const int checklistItemCount = 2;
    const String checklistJson =
        '[{"id":"$checklistItemIdSecond","label":"$checklistItemLabelSecond",'
        '"isCompleted":true,"order":$checklistOrderSecond},'
        '{"id":"$checklistItemIdFirst","label":"$checklistItemLabelFirst",'
        '"isCompleted":false,"order":$checklistOrderFirst}]';
    const String checklistLine = '$checklistPropertyPrefix$checklistJson';
    const String criticalPathId = 'path-1';
    const String criticalPathTaskFirstId = 'task-first';
    const String criticalPathTaskSecondId = 'task-second';
    const String criticalPathTaskFirstSummary = 'First Task';
    const String criticalPathTaskSecondSummary = 'Second Task';
    const String axiTaskIdLabel = 'X-AXICHAT-ID:';
    const String criticalPathIdLabel = 'X-AXICHAT-PATH-ID:';
    const String criticalPathOrderLabel = 'X-AXICHAT-PATH-ORDER:';
    const int criticalPathOrderFirst = 0;
    const int criticalPathOrderSecond = 1;
    const String allDayUid = 'event-1';
    const String allDaySummary = 'All Day';
    const String todoUid = 'todo-1';
    const String todoSummary = 'After Alarm';
    const int singleItemCount = 1;
    const List<String> expectedCriticalPathOrder = <String>[
      criticalPathTaskFirstId,
      criticalPathTaskSecondId,
    ];
    final DateTime expectedStart = DateTime(2024, 1, 1);
    final DateTime expectedEnd = DateTime(2024, 1, 2);
    final DateTime expectedTimedStart = DateTime.utc(
      timedStartYear,
      timedStartMonth,
      timedStartDay,
      timedStartHour,
      timedStartMinute,
      timedStartSecond,
    );

    test('maps all-day VEVENT to DayEvent with exclusive DTEND', () {
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        eventStart,
        '$uidLabel$allDayUid',
        dtStampLine,
        allDayStartLine,
        allDayEndLine,
        '$summaryLabel$allDaySummary',
        eventEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.dayEvents, hasLength(singleItemCount));
      expect(model.tasks, isEmpty);
      final event = model.dayEvents.values.first;
      expect(event.startDate, equals(expectedStart));
      expect(event.endDate, equals(expectedEnd));
    });

    test('maps recurring all-day VEVENT to a task', () {
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        eventStart,
        '$uidLabel$allDayUid',
        dtStampLine,
        allDayStartLine,
        allDayEndLine,
        recurringRuleLine,
        '$summaryLabel$allDaySummary',
        eventEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.dayEvents, isEmpty);
      expect(model.tasks, hasLength(singleItemCount));
    });

    test('maps timed VEVENT to a task', () {
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        eventStart,
        '$uidLabel$timedEventUid',
        dtStampLine,
        todoStartLine,
        timedEventEndLine,
        '$summaryLabel$timedEventSummary',
        eventEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.dayEvents, isEmpty);
      expect(model.tasks, hasLength(singleItemCount));
      final CalendarTask task = model.tasks.values.first;
      expect(task.scheduledTime, equals(expectedTimedStart));
      expect(task.deadline, isNull);
    });

    test('ignores after-start alarms when mapping reminders', () {
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        todoStart,
        '$uidLabel$todoUid',
        dtStampLine,
        todoStartLine,
        '$summaryLabel$todoSummary',
        alarmStart,
        alarmActionLine,
        alarmTriggerAfterLine,
        alarmEnd,
        todoEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.tasks, hasLength(singleItemCount));
      final remindersEnabled =
          model.tasks.values.first.reminders?.isEnabled ?? false;
      expect(remindersEnabled, isFalse);
    });

    test('maps start and deadline alarms to reminder offsets', () {
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        todoStart,
        '$uidLabel$todoUid',
        dtStampLine,
        todoStartLine,
        todoDueLine,
        '$summaryLabel$todoSummary',
        alarmStart,
        alarmActionLine,
        alarmTriggerBeforeStartLine,
        alarmEnd,
        alarmStart,
        alarmActionLine,
        alarmTriggerBeforeEndLine,
        alarmEnd,
        todoEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.tasks, hasLength(singleItemCount));
      final CalendarTask task = model.tasks.values.first;
      final ReminderPreferences reminders =
          task.reminders ?? ReminderPreferences.defaults();
      expect(reminders.isEnabled, isTrue);
      expect(reminders.startOffsets, hasLength(reminderOffsetCount));
      expect(reminders.deadlineOffsets, hasLength(reminderOffsetCount));
      expect(reminders.startOffsets.first, equals(startReminderOffset));
      expect(reminders.deadlineOffsets.first, equals(deadlineReminderOffset));
    });

    test('preserves checklist item order from X-AXICHAT-CHECKLIST', () {
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        todoStart,
        '$uidLabel$checklistTaskUid',
        dtStampLine,
        todoStartLine,
        '$summaryLabel$checklistSummary',
        checklistLine,
        todoEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.tasks, hasLength(singleItemCount));
      final CalendarTask task = model.tasks.values.first;
      expect(task.checklist, hasLength(checklistItemCount));
      expect(task.checklist.first.id, equals(checklistItemIdSecond));
      expect(task.checklist.first.label, equals(checklistItemLabelSecond));
      expect(task.checklist.last.id, equals(checklistItemIdFirst));
      expect(task.checklist.last.label, equals(checklistItemLabelFirst));
    });

    test('preserves critical path order from X-AXICHAT-PATH-ORDER', () {
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        todoStart,
        '$uidLabel$criticalPathTaskFirstId',
        '$axiTaskIdLabel$criticalPathTaskFirstId',
        '$summaryLabel$criticalPathTaskFirstSummary',
        '$criticalPathIdLabel$criticalPathId',
        '$criticalPathOrderLabel$criticalPathOrderFirst',
        todoEnd,
        todoStart,
        '$uidLabel$criticalPathTaskSecondId',
        '$axiTaskIdLabel$criticalPathTaskSecondId',
        '$summaryLabel$criticalPathTaskSecondSummary',
        '$criticalPathIdLabel$criticalPathId',
        '$criticalPathOrderLabel$criticalPathOrderSecond',
        todoEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.criticalPaths, hasLength(singleItemCount));
      final CalendarCriticalPath path = model.criticalPaths.values.first;
      expect(path.taskIds, equals(expectedCriticalPathOrder));
    });

    test('stores unsupported RRULE as raw props and treats task as recurring',
        () {
      const String rawUid = 'todo-raw';
      const String rawSummary = 'Unsupported rule';
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        todoStart,
        '$uidLabel$rawUid',
        dtStampLine,
        todoStartLine,
        '$summaryLabel$rawSummary',
        yearlyRuleLine,
        todoEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.tasks, hasLength(singleItemCount));
      final CalendarTask task = model.tasks.values.first;
      final RecurrenceRule? recurrence = task.recurrence;
      expect(recurrence, isNotNull);
      expect(task.hasRecurrenceData, isTrue);
      CalendarRawProperty? rawRule;
      for (final CalendarRawProperty property in recurrence!.rawProperties) {
        if (property.name == rruleName && property.value == yearlyRuleValue) {
          rawRule = property;
          break;
        }
      }
      expect(rawRule, isNotNull);
    });

    test('marks METHOD:CANCEL overrides as cancelled', () {
      const String cancelUid = 'todo-cancel';
      const String cancelSummary = 'Cancel me';
      const String overrideSummary = 'Instance';
      final String ics = <String>[
        calendarStart,
        versionLine,
        prodIdLine,
        methodCancelLine,
        todoStart,
        '$uidLabel$cancelUid',
        dtStampLine,
        todoStartLine,
        recurringRuleLine,
        '$summaryLabel$cancelSummary',
        todoEnd,
        todoStart,
        '$uidLabel$cancelUid',
        dtStampLine,
        recurrenceIdLine,
        overrideStartLine,
        '$summaryLabel$overrideSummary',
        todoEnd,
        calendarEnd,
      ].join(lineBreak);

      final CalendarModel model = const CalendarIcsCodec().decode(ics);

      expect(model.deletedTaskIds, isEmpty);
      expect(model.tasks, hasLength(singleItemCount));
      final CalendarTask task = model.tasks.values.first;
      expect(task.occurrenceOverrides, hasLength(singleItemCount));
      final TaskOccurrenceOverride override =
          task.occurrenceOverrides.values.first;
      expect(override.isCancelled, isTrue);
    });
  });

  group('CalendarIcsCodec encode', () {
    const String exdateLabel = 'EXDATE:';
    const String recurrenceIdProperty = 'RECURRENCE-ID';
    const String recurrenceIdLabel = '$recurrenceIdProperty:';
    const String summaryLabel = 'SUMMARY:';
    const String calendarStart = 'BEGIN:VCALENDAR';
    const String calendarEnd = 'END:VCALENDAR';
    const String todoStart = 'BEGIN:VTODO';
    const String todoEnd = 'END:VTODO';
    const String eventStart = 'BEGIN:VEVENT';
    const String eventEnd = 'END:VEVENT';
    const String title = 'Daily task';
    const String overrideTitle = 'Override title';
    const String baseTaskId = 'task-1';
    const String dtStartProperty = 'DTSTART';
    const String tzidParameter = 'TZID';
    const String tzidValue = 'America/New_York';
    const String valueParameter = 'VALUE';
    const String valueDate = 'DATE';
    const String recurrenceIdTzidPrefix =
        '$recurrenceIdProperty;$tzidParameter=$tzidValue:';
    const String recurrenceIdValueDatePrefix =
        '$recurrenceIdProperty;$valueParameter=$valueDate:';
    const String baseLocalStartValue = '20240101T090000';
    const String baseDateValue = '20240101';
    const int startYear = 2024;
    const int startMonth = 1;
    const int startDay = 1;
    const int startHour = 9;
    const int startMinute = 0;
    const int startSecond = 0;
    const int durationHours = 1;
    const int oneDay = 1;
    const List<TaskChecklistItem> emptyChecklist = <TaskChecklistItem>[];
    const String reminderTaskId = 'task-reminders';
    const String reminderSummary = 'Reminder Task';
    const String reminderStartTriggerLine = 'TRIGGER;RELATED=START:-PT15M';
    const String reminderEndTriggerLine = 'TRIGGER;RELATED=END:-PT30M';
    const int reminderStartOffsetMinutes = 15;
    const int reminderDeadlineOffsetMinutes = 30;
    const Duration reminderStartOffset =
        Duration(minutes: reminderStartOffsetMinutes);
    const Duration reminderDeadlineOffset =
        Duration(minutes: reminderDeadlineOffsetMinutes);
    const List<Duration> reminderStartOffsets = <Duration>[
      reminderStartOffset,
    ];
    const List<Duration> reminderDeadlineOffsets = <Duration>[
      reminderDeadlineOffset,
    ];
    const ReminderPreferences reminderPreferences = ReminderPreferences(
      enabled: true,
      startOffsets: reminderStartOffsets,
      deadlineOffsets: reminderDeadlineOffsets,
    );
    const Duration reminderDeadlineDelta = Duration(hours: durationHours);
    const String checklistTaskId = 'task-checklist';
    const String checklistTaskTitle = 'Checklist Task';
    const String checklistPercentLine = 'PERCENT-COMPLETE:50';
    const String checklistPropertyName = 'X-AXICHAT-CHECKLIST';
    const String checklistItemIdFirst = 'check-1';
    const String checklistItemIdSecond = 'check-2';
    const String checklistItemLabelFirst = 'First';
    const String checklistItemLabelSecond = 'Second';
    const List<TaskChecklistItem> checklistItems = <TaskChecklistItem>[
      TaskChecklistItem(
        id: checklistItemIdFirst,
        label: checklistItemLabelFirst,
        isCompleted: true,
      ),
      TaskChecklistItem(
        id: checklistItemIdSecond,
        label: checklistItemLabelSecond,
        isCompleted: false,
      ),
    ];
    const String dayEventId = 'day-event-1';
    const String dayEventTitle = 'Conference';
    const String dayEventStartLine = 'DTSTART;VALUE=DATE:20240101';
    const String dayEventEndLine = 'DTEND;VALUE=DATE:20240103';
    const int dayEventStartYear = 2024;
    const int dayEventStartMonth = 1;
    const int dayEventStartDay = 1;
    const int dayEventEndDay = 2;
    const String criticalPathId = 'critical-path-1';
    const String criticalPathName = 'Critical Path';
    const String criticalPathTaskFirstId = 'critical-task-1';
    const String criticalPathTaskSecondId = 'critical-task-2';
    const String criticalPathOrderFirstLine = 'X-AXICHAT-PATH-ORDER:0';
    const String criticalPathOrderSecondLine = 'X-AXICHAT-PATH-ORDER:1';
    const String criticalPathIdLine = 'X-AXICHAT-PATH-ID:$criticalPathId';

    test('emits EXDATE for cancelled override without RECURRENCE-ID', () {
      final DateTime scheduledStart = DateTime.utc(
        startYear,
        startMonth,
        startDay,
        startHour,
        startMinute,
        startSecond,
      );
      final DateTime cancelledStart =
          scheduledStart.add(const Duration(days: oneDay));
      final String occurrenceKey =
          cancelledStart.microsecondsSinceEpoch.toString();
      const TaskOccurrenceOverride override =
          TaskOccurrenceOverride(isCancelled: true);
      final Map<String, TaskOccurrenceOverride> overrides =
          <String, TaskOccurrenceOverride>{occurrenceKey: override};
      final CalendarTask task = CalendarTask(
        id: baseTaskId,
        title: title,
        description: null,
        scheduledTime: scheduledStart,
        duration: const Duration(hours: durationHours),
        isCompleted: false,
        createdAt: scheduledStart,
        modifiedAt: scheduledStart,
        location: null,
        deadline: null,
        priority: null,
        startHour: null,
        endDate: null,
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
        ),
        occurrenceOverrides: overrides,
        reminders: null,
        checklist: emptyChecklist,
        icsMeta: null,
      );
      final CalendarModel model = CalendarModel.empty().addTask(task);

      final String encoded = const CalendarIcsCodec().encode(model);
      final String exdate = '$exdateLabel${_formatIcsUtc(cancelledStart)}';

      expect(encoded.contains(calendarStart), isTrue);
      expect(encoded.contains(calendarEnd), isTrue);
      expect(encoded.contains(todoStart), isTrue);
      expect(encoded.contains(todoEnd), isTrue);
      expect(encoded.contains(exdate), isTrue);
    });

    test('writes RECURRENCE-ID from override key when missing in meta', () {
      final DateTime scheduledStart = DateTime.utc(
        startYear,
        startMonth,
        startDay,
        startHour,
        startMinute,
        startSecond,
      );
      final DateTime overrideStart =
          scheduledStart.add(const Duration(days: oneDay));
      final String occurrenceKey =
          overrideStart.microsecondsSinceEpoch.toString();
      const TaskOccurrenceOverride override =
          TaskOccurrenceOverride(title: overrideTitle);
      final Map<String, TaskOccurrenceOverride> overrides =
          <String, TaskOccurrenceOverride>{occurrenceKey: override};
      final CalendarTask task = CalendarTask(
        id: baseTaskId,
        title: title,
        description: null,
        scheduledTime: scheduledStart,
        duration: const Duration(hours: durationHours),
        isCompleted: false,
        createdAt: scheduledStart,
        modifiedAt: scheduledStart,
        location: null,
        deadline: null,
        priority: null,
        startHour: null,
        endDate: null,
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
        ),
        occurrenceOverrides: overrides,
        reminders: null,
        checklist: emptyChecklist,
        icsMeta: null,
      );
      final CalendarModel model = CalendarModel.empty().addTask(task);

      final String encoded = const CalendarIcsCodec().encode(model);
      final String recurrenceId =
          '$recurrenceIdLabel${_formatIcsUtc(overrideStart)}';
      const String overrideSummary = '$summaryLabel$overrideTitle';

      expect(encoded.contains(calendarStart), isTrue);
      expect(encoded.contains(calendarEnd), isTrue);
      expect(
          encoded.contains(eventStart) || encoded.contains(todoStart), isTrue);
      expect(encoded.contains(eventEnd) || encoded.contains(todoEnd), isTrue);
      expect(encoded.contains(overrideSummary), isTrue);
      expect(encoded.contains(recurrenceId), isTrue);
    });

    test('writes RECURRENCE-ID with TZID from raw DTSTART', () {
      final DateTime scheduledStart = DateTime(
        startYear,
        startMonth,
        startDay,
        startHour,
        startMinute,
        startSecond,
      );
      final DateTime overrideStart =
          scheduledStart.add(const Duration(days: oneDay));
      final String occurrenceKey =
          overrideStart.microsecondsSinceEpoch.toString();
      const TaskOccurrenceOverride override =
          TaskOccurrenceOverride(title: overrideTitle);
      final Map<String, TaskOccurrenceOverride> overrides =
          <String, TaskOccurrenceOverride>{occurrenceKey: override};
      const CalendarRawProperty rawDtStart = CalendarRawProperty(
        name: dtStartProperty,
        value: baseLocalStartValue,
        parameters: <CalendarPropertyParameter>[
          CalendarPropertyParameter(
            name: tzidParameter,
            values: <String>[tzidValue],
          ),
        ],
      );
      const CalendarIcsMeta meta = CalendarIcsMeta(
        rawProperties: <CalendarRawProperty>[rawDtStart],
      );
      final CalendarTask task = CalendarTask(
        id: baseTaskId,
        title: title,
        description: null,
        scheduledTime: scheduledStart,
        duration: const Duration(hours: durationHours),
        isCompleted: false,
        createdAt: scheduledStart,
        modifiedAt: scheduledStart,
        location: null,
        deadline: null,
        priority: null,
        startHour: null,
        endDate: null,
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
        ),
        occurrenceOverrides: overrides,
        reminders: null,
        checklist: emptyChecklist,
        icsMeta: meta,
      );
      final CalendarModel model = CalendarModel.empty().addTask(task);

      final String encoded = const CalendarIcsCodec().encode(model);

      expect(encoded.contains(recurrenceIdTzidPrefix), isTrue);
    });

    test('writes all-day RECURRENCE-ID when DTSTART is date-only', () {
      final DateTime scheduledStart = DateTime(
        startYear,
        startMonth,
        startDay,
      );
      final DateTime overrideStart =
          scheduledStart.add(const Duration(days: oneDay));
      final String occurrenceKey =
          overrideStart.microsecondsSinceEpoch.toString();
      const TaskOccurrenceOverride override =
          TaskOccurrenceOverride(title: overrideTitle);
      final Map<String, TaskOccurrenceOverride> overrides =
          <String, TaskOccurrenceOverride>{occurrenceKey: override};
      const CalendarRawProperty rawDtStart = CalendarRawProperty(
        name: dtStartProperty,
        value: baseDateValue,
        parameters: <CalendarPropertyParameter>[
          CalendarPropertyParameter(
            name: valueParameter,
            values: <String>[valueDate],
          ),
        ],
      );
      const CalendarIcsMeta meta = CalendarIcsMeta(
        rawProperties: <CalendarRawProperty>[rawDtStart],
      );
      final CalendarTask task = CalendarTask(
        id: baseTaskId,
        title: title,
        description: null,
        scheduledTime: scheduledStart,
        duration: const Duration(hours: durationHours),
        isCompleted: false,
        createdAt: scheduledStart,
        modifiedAt: scheduledStart,
        location: null,
        deadline: null,
        priority: null,
        startHour: null,
        endDate: null,
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
        ),
        occurrenceOverrides: overrides,
        reminders: null,
        checklist: emptyChecklist,
        icsMeta: meta,
      );
      final CalendarModel model = CalendarModel.empty().addTask(task);

      final String encoded = const CalendarIcsCodec().encode(model);
      final String recurrenceId =
          '$recurrenceIdValueDatePrefix${_formatIcsDate(overrideStart)}';

      expect(encoded.contains(recurrenceId), isTrue);
    });

    test('writes reminder triggers for start and deadline offsets', () {
      final DateTime scheduledStart = DateTime.utc(
        startYear,
        startMonth,
        startDay,
        startHour,
        startMinute,
        startSecond,
      );
      final DateTime deadline = scheduledStart.add(reminderDeadlineDelta);
      final CalendarTask task = CalendarTask(
        id: reminderTaskId,
        title: reminderSummary,
        description: null,
        scheduledTime: scheduledStart,
        duration: const Duration(hours: durationHours),
        isCompleted: false,
        createdAt: scheduledStart,
        modifiedAt: scheduledStart,
        location: null,
        deadline: deadline,
        priority: null,
        startHour: null,
        endDate: null,
        recurrence: null,
        occurrenceOverrides: const <String, TaskOccurrenceOverride>{},
        reminders: reminderPreferences,
        checklist: emptyChecklist,
        icsMeta: null,
      );
      final CalendarModel model = CalendarModel.empty().addTask(task);

      final String encoded = const CalendarIcsCodec().encode(model);

      expect(encoded.contains(reminderStartTriggerLine), isTrue);
      expect(encoded.contains(reminderEndTriggerLine), isTrue);
    });

    test('writes checklist percent and payload', () {
      final DateTime timestamp = DateTime.utc(
        startYear,
        startMonth,
        startDay,
        startHour,
        startMinute,
        startSecond,
      );
      final CalendarTask task = CalendarTask(
        id: checklistTaskId,
        title: checklistTaskTitle,
        description: null,
        scheduledTime: null,
        duration: null,
        isCompleted: false,
        createdAt: timestamp,
        modifiedAt: timestamp,
        location: null,
        deadline: null,
        priority: null,
        startHour: null,
        endDate: null,
        recurrence: null,
        occurrenceOverrides: const <String, TaskOccurrenceOverride>{},
        reminders: null,
        checklist: checklistItems,
        icsMeta: null,
      );
      final CalendarModel model = CalendarModel.empty().addTask(task);

      final String encoded = const CalendarIcsCodec().encode(model);

      expect(encoded.contains(checklistPercentLine), isTrue);
      expect(encoded.contains(checklistPropertyName), isTrue);
    });

    test('writes exclusive DTEND for day events', () {
      final DateTime baseDate = DateTime(
        dayEventStartYear,
        dayEventStartMonth,
        dayEventStartDay,
      );
      final DayEvent event = DayEvent(
        id: dayEventId,
        title: dayEventTitle,
        startDate: baseDate,
        endDate: DateTime(
          dayEventStartYear,
          dayEventStartMonth,
          dayEventEndDay,
        ),
        description: null,
        reminders: null,
        createdAt: baseDate,
        modifiedAt: baseDate,
        icsMeta: null,
      );
      final CalendarModel model = CalendarModel.empty().addDayEvent(event);

      final String encoded = const CalendarIcsCodec().encode(model);

      expect(encoded.contains(dayEventStartLine), isTrue);
      expect(encoded.contains(dayEventEndLine), isTrue);
    });

    test('writes critical path order properties for tasks', () {
      final DateTime baseTime = DateTime.utc(
        startYear,
        startMonth,
        startDay,
        startHour,
        startMinute,
        startSecond,
      );
      final CalendarTask firstTask = CalendarTask(
        id: criticalPathTaskFirstId,
        title: criticalPathTaskFirstId,
        description: null,
        scheduledTime: null,
        duration: null,
        isCompleted: false,
        createdAt: baseTime,
        modifiedAt: baseTime,
        location: null,
        deadline: null,
        priority: null,
        startHour: null,
        endDate: null,
        recurrence: null,
        occurrenceOverrides: const <String, TaskOccurrenceOverride>{},
        reminders: null,
        checklist: emptyChecklist,
        icsMeta: null,
      );
      final CalendarTask secondTask = CalendarTask(
        id: criticalPathTaskSecondId,
        title: criticalPathTaskSecondId,
        description: null,
        scheduledTime: null,
        duration: null,
        isCompleted: false,
        createdAt: baseTime,
        modifiedAt: baseTime,
        location: null,
        deadline: null,
        priority: null,
        startHour: null,
        endDate: null,
        recurrence: null,
        occurrenceOverrides: const <String, TaskOccurrenceOverride>{},
        reminders: null,
        checklist: emptyChecklist,
        icsMeta: null,
      );
      final CalendarCriticalPath path = CalendarCriticalPath(
        id: criticalPathId,
        name: criticalPathName,
        taskIds: const <String>[
          criticalPathTaskFirstId,
          criticalPathTaskSecondId,
        ],
        isArchived: false,
        createdAt: baseTime,
        modifiedAt: baseTime,
      );
      final CalendarModel model =
          CalendarModel.empty().addTask(firstTask).addTask(secondTask).copyWith(
        criticalPaths: <String, CalendarCriticalPath>{
          criticalPathId: path,
        },
      );

      final String encoded = const CalendarIcsCodec().encode(model);

      expect(encoded.contains(criticalPathIdLine), isTrue);
      expect(encoded.contains(criticalPathOrderFirstLine), isTrue);
      expect(encoded.contains(criticalPathOrderSecondLine), isTrue);
    });
  });
}

const String _icsValueT = 'T';
const String _icsValueZ = 'Z';
const String _icsPadChar = '0';
const int _icsYearWidth = 4;
const int _icsMonthWidth = 2;
const int _icsDayWidth = 2;
const int _icsHourWidth = 2;
const int _icsMinuteWidth = 2;
const int _icsSecondWidth = 2;

String _formatIcsUtc(DateTime value) {
  final DateTime resolved = value.toUtc();
  return '${_pad(resolved.year, _icsYearWidth)}'
      '${_pad(resolved.month, _icsMonthWidth)}'
      '${_pad(resolved.day, _icsDayWidth)}$_icsValueT'
      '${_pad(resolved.hour, _icsHourWidth)}'
      '${_pad(resolved.minute, _icsMinuteWidth)}'
      '${_pad(resolved.second, _icsSecondWidth)}$_icsValueZ';
}

String _formatIcsDate(DateTime value) {
  final DateTime resolved = DateTime(
    value.year,
    value.month,
    value.day,
  );
  return '${_pad(resolved.year, _icsYearWidth)}'
      '${_pad(resolved.month, _icsMonthWidth)}'
      '${_pad(resolved.day, _icsDayWidth)}';
}

String _pad(int value, int width) =>
    value.toString().padLeft(width, _icsPadChar);
