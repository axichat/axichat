import 'package:axichat/src/calendar/utils/schedule_parser.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location location;

  ScheduleParser buildParser(DateTime referenceUtc) {
    return ScheduleParser(
      ScheduleParseOptions(
        tzLocation: location,
        tzName: location.name,
        reference: referenceUtc,
        policy: const FuzzyPolicy(),
      ),
    );
  }

  setUpAll(() {
    tzdata.initializeTimeZones();
    location = tz.getLocation('America/New_York');
  });

  group('ScheduleParser time resolution', () {
    test('parses simple time with location context', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12)); // 08:00 local
      final result = parser.parse('meeting at 2pm in room 101');

      expect(result.start, isNotNull);
      expect(result.start!.hour, 14);
      expect(result.start!.minute, 0);
      expect(result.location, 'room 101');
      expect(result.bucket, TaskBucket.scheduled);
    });

    test('keeps numeric street addresses as locations', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('site visit at 123 Main St tomorrow at 4pm');

      expect(result.location, '123 Main St');
      expect(result.start, isNotNull);
      expect(result.start!.hour, 16);
    });

    test('title strips time/location phrases once metadata captured', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('cool meeting tomorrow at 2pm in the lodge');

      expect(result.task, 'cool meeting');
      expect(result.start!.hour, 14);
      expect(result.location, 'lodge');
    });

    test('title strips explicit priority markers from result', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('urgent budget review at 3pm in HQ');

      expect(result.task, 'budget review');
      expect(result.location, 'HQ');
      expect(result.priority, PriorityQuadrant.notImportantUrgent);
    });

    test('handles "this time tomorrow" without hijacking location', () {
      final parser =
          buildParser(DateTime.utc(2024, 5, 1, 13, 30)); // 09:30 local
      final result =
          parser.parse('cool meeting at this time tomorrow at the lodge');
      final expected =
          tz.TZDateTime(location, 2024, 5, 2, 9, 30); // next day same time

      expect(result.start, isNotNull);
      expect(result.start!.isAtSameMomentAs(expected), isTrue);
      expect(result.location, anyOf('lodge', 'the lodge'));
      expect(result.bucket, TaskBucket.scheduled);
    });

    test('does not fall back to end-of-day when explicit time given', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 11)); // 07:00 local
      final result = parser.parse('2pm');

      expect(result.start, isNotNull);
      expect(result.start!.hour, 14);
      expect(result.bucket, TaskBucket.scheduled);
    });

    test('parses compact 24h times like 1800', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('call at 1800 about qbr');

      expect(result.start, isNotNull);
      expect(result.start!.hour, 18);
    });

    test('understands "from" ranges and applies end time', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('work session from 2pm to 4pm at room 202');

      expect(result.start!.hour, 14);
      expect(result.end, isNotNull);
      expect(result.end!.hour, 16);
      expect(result.location, 'room 202');
    });

    test('respects "for two hours" spelled-out duration', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('deep dive at 1pm for two hours');

      expect(result.start!.hour, 13);
      expect(result.end, isNotNull);
      expect(result.end!.hour, 15);
    });

    test('extracts composite durations like "1h 30m"', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 8));
      final result =
          parser.parse('briefing at 9am lasting 1h 30m with Alice and Bob');

      expect(result.start!.hour, 9);
      expect(result.end, isNotNull);
      expect(result.end!.hour, 10);
      expect(result.end!.minute, 30);
      expect(result.participants, containsAll(['Alice', 'Bob']));
    });

    test('applies "going for <duration>" phrasing to end time', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result =
          parser.parse('deep work block at 3pm going for 3 hours in lab');

      expect(result.start!.hour, 15);
      expect(result.end, isNotNull);
      expect(result.end!.hour, 18);
      expect(result.location, 'lab');
    });

    test('uses "after three hours" as a relative fallback', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('send summary after three hours');

      expect(result.start, isNotNull);
      final expected = tz.TZDateTime(location, 2024, 5, 1, 11);
      expect(result.start!.isAtSameMomentAs(expected), isTrue);
    });

    test('handles "three hours later" phrasing', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('ping me three hours later');

      expect(result.start, isNotNull);
      final expected = tz.TZDateTime(location, 2024, 5, 1, 11);
      expect(result.start!.isAtSameMomentAs(expected), isTrue);
    });

    test('handles "<duration> long" phrasing after explicit start', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('connect at 4pm, lasts 90 minutes long');

      expect(result.start!.hour, 16);
      expect(result.end, isNotNull);
      expect(result.end!.hour, 17);
      expect(result.end!.minute, 30);
    });

    test('handles relative phrases like "in a couple hours"', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 14)); // 10:00 local
      final result = parser.parse('follow up in a couple hours');

      expect(result.start, isNotNull);
      final difference =
          result.start!.difference(tz.TZDateTime(location, 2024, 5, 1, 10));
      expect(difference.inHours, 2);
    });

    test('relative "in 5 hours" only schedules start time', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12)); // 08:00 local
      final result = parser.parse('task in 5 hours');

      final expected = tz.TZDateTime(location, 2024, 5, 1, 13);
      expect(result.start, isNotNull);
      expect(result.start!.isAtSameMomentAs(expected), isTrue);
      expect(result.end, isNull);
      expect(result.location, isNull);
    });

    test('relative phrases can still apply explicit durations', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result =
          parser.parse('focus block in 2 hours for 45 minutes with Sam');

      final expectedStart = tz.TZDateTime(location, 2024, 5, 1, 10);
      expect(result.start, isNotNull);
      expect(result.start!.isAtSameMomentAs(expectedStart), isTrue);
      expect(result.end, isNotNull);
      expect(result.end!.difference(result.start!).inMinutes, 45);
      expect(result.location, isNull);
      expect(result.participants, contains('Sam'));
    });

    test('does not auto-mark urgent based on proximity alone', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('call Bob at 1pm');

      expect(result.priority, PriorityQuadrant.notImportantNotUrgent);
      expect(result.task, 'call Bob');
    });

    test('does not mark urgent just because "today" is present', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('finish the report today at 4pm');

      expect(result.priority, PriorityQuadrant.notImportantNotUrgent);
      expect(result.task, 'finish the report');
    });

    test('ignores @handle while keeping real locations', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 13));
      final result = parser.parse('sync with @john at the innovation lab');

      expect(result.location, 'innovation lab');
    });

    test('does not treat feature phrases after "in" as locations', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result =
          parser.parse('polish contact list tiles in chat composer');

      expect(result.location, isNull);
      expect(result.bucket, TaskBucket.unscheduled);
      expect(result.task, contains('contact list tiles'));
      expect(result.task, contains('chat composer'));
    });

    test('still captures obvious standalone place names', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result =
          parser.parse('coffee sync tomorrow at 3pm at Starbucks');

      expect(result.location, 'Starbucks');
      expect(result.start, isNotNull);
      expect(result.start!.hour, 15);
    });

    test('plain hour without meridiem still schedules start time', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 16)); // noon local
      final result = parser.parse('stuff at 5 every day');

      expect(result.start, isNotNull);
      expect(result.start!.hour, 17);
      expect(result.recurrence, isNotNull);
      expect(result.recurrence!.rrule, 'FREQ=DAILY');
      expect(result.bucket, TaskBucket.scheduled);
    });

    test('ignores bare numbers without time cue', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('come up with 5 reasons');

      expect(result.start, isNull);
      expect(result.recurrence, isNull);
      expect(result.bucket, TaskBucket.unscheduled);
      expect(result.task, 'come up with 5 reasons');
    });
  });

  group('ScheduleParser recurrence parsing', () {
    test('parses "every day" cadence', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('standup every day at 9am');

      expect(result.recurrence, isNotNull);
      expect(result.recurrence!.rrule, 'FREQ=DAILY');
      expect(result.bucket, TaskBucket.scheduled);
    });

    test('parses "every other day"', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('journal every other day at 20:00');

      expect(result.recurrence, isNotNull);
      expect(result.recurrence!.rrule, 'FREQ=DAILY;INTERVAL=2');
    });

    test('parses "every weekend" sets', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('hike every weekend at 8am');

      expect(result.recurrence, isNotNull);
      expect(result.recurrence!.rrule, 'FREQ=WEEKLY;BYDAY=SA,SU');
    });

    test('parses ordinal weekday phrases with digits', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser
          .parse('budget review on the 2nd Tuesday of every month at noon');

      expect(result.recurrence, isNotNull);
      expect(
        result.recurrence!.rrule,
        'FREQ=MONTHLY;BYDAY=TU;BYSETPOS=2',
      );
    });

    test('parses weekday sets without explicit keyword', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result = parser.parse('Thursdays and Sundays at 5pm in HQ');

      expect(result.recurrence, isNotNull);
      expect(result.recurrence!.rrule, 'FREQ=WEEKLY;BYDAY=TH,SU');
      expect(result.location, 'HQ');
    });

    test('derives count and until for duration phrasing', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result =
          parser.parse('journaling every day for 10 days at 7am in nook');

      expect(result.recurrence, isNotNull);
      expect(result.recurrence!.count, 10);
      final until = result.recurrence!.until;
      expect(until, isNotNull);
      final expectedUntil = result.start!.add(const Duration(days: 9));
      expect(until!.isAtSameMomentAs(expectedUntil), isTrue);
      expect(result.recurrence!.rrule, contains('COUNT=10'));
      expect(result.recurrence!.rrule, contains('UNTIL='));
    });

    test('derives count when only until is specified', () {
      final parser = buildParser(DateTime.utc(2024, 5, 1, 12));
      final result =
          parser.parse('team sync every Friday at 10am until June 1');

      expect(result.recurrence, isNotNull);
      expect(result.start, isNotNull);
      final count = result.recurrence!.count;
      expect(count, isNotNull);
      expect(count, greaterThan(1));
      expect(result.recurrence!.rrule, contains('COUNT='));
      expect(result.recurrence!.rrule, contains('UNTIL='));
    });
  });
}
