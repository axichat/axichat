import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
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
    const String allDayUid = 'event-1';
    const String allDaySummary = 'All Day';
    const String todoUid = 'todo-1';
    const String todoSummary = 'After Alarm';
    const int singleItemCount = 1;
    final DateTime expectedStart = DateTime(2024, 1, 1);
    final DateTime expectedEnd = DateTime(2024, 1, 2);

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
