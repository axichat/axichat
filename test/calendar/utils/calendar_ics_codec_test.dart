import 'package:axichat/src/calendar/models/calendar_model.dart';
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
    const String summaryLabel = 'SUMMARY:';
    const String uidLabel = 'UID:';
    const String dtStampLine = 'DTSTAMP:20240101T000000Z';
    const String allDayStartLine = 'DTSTART;VALUE=DATE:20240101';
    const String allDayEndLine = 'DTEND;VALUE=DATE:20240103';
    const String todoStartLine = 'DTSTART:20240101T090000Z';
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
  });
}
