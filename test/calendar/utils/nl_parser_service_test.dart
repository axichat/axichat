import 'dart:isolate';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/nl_parser_service.dart';
import 'package:axichat/src/calendar/utils/nl_schedule_adapter.dart';
import 'package:axichat/src/calendar/utils/schedule_parser.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  Future<Map<String, Object?>> parseInFreshIsolate(String input) {
    return Isolate.run(() async {
      final service = NlScheduleParserService(
        initializeTimezones: () => throw StateError('timezone init failed'),
      );
      final result = await service.parse(input);
      return <String, Object?>{
        'bucket': result.bucket.name,
        'timezoneId': result.context.timezoneId,
        'hasStart': result.start != null,
        'hasDeadline': result.deadline != null,
      };
    });
  }

  test('falls back to UTC when timezone init fails', () async {
    final snapshot = await parseInFreshIsolate('meet tomorrow at 2pm');

    expect(snapshot['timezoneId'], 'UTC');
    expect(snapshot['bucket'], TaskBucket.scheduled.name);
    expect(snapshot['hasStart'], isTrue);
  });

  group('task share formatting', () {
    test('omits current-year suffix and avoids repeating same-day date', () {
      final DateTime reference = DateTime.utc(2024, 3, 1);
      final DateTime start = DateTime.utc(2024, 3, 15, 9);
      final CalendarTask task = CalendarTask(
        id: 't1',
        title: 'Team sync',
        scheduledTime: start,
        duration: const Duration(minutes: 90),
        createdAt: reference,
        modifiedAt: reference,
      );

      final String shareText = task.toShareText(now: reference);

      expect(shareText, isNot(contains('2024')));
      expect(shareText, contains('on Mar 15 from 9:00 AM to 10:30 AM'));
      expect(RegExp(r'Mar 15').allMatches(shareText).length, 1);
    });

    test('keeps explicit year for non-current schedules', () {
      final DateTime reference = DateTime.utc(2024, 3, 1);
      final DateTime start = DateTime.utc(2025, 3, 15, 9);
      final CalendarTask task = CalendarTask(
        id: 't2',
        title: 'Future offsite',
        scheduledTime: start,
        duration: const Duration(minutes: 90),
        createdAt: reference,
        modifiedAt: reference,
      );

      final String shareText = task.toShareText(now: reference);

      expect(
        shareText,
        contains('on Mar 15, 2025 from 9:00 AM to 10:30 AM'),
      );
    });
  });

  test('shared task text round-trips task fields', () async {
    tzdata.initializeTimeZones();
    final ctx = ParseContext(
      location: tz.UTC,
      timezoneId: 'UTC',
      reference: DateTime.utc(2024, 1, 1),
    );

    final DateTime start = DateTime.utc(2024, 6, 1, 14, 0);
    final DateTime deadline = DateTime.utc(2024, 5, 31, 17, 0);
    final DateTime overrideOccurrence = DateTime.utc(2024, 6, 8, 14, 0);
    final Map<String, TaskOccurrenceOverride> overrides = {
      overrideOccurrence.microsecondsSinceEpoch.toString():
          TaskOccurrenceOverride(
        scheduledTime: overrideOccurrence.add(const Duration(hours: 1)),
        duration: const Duration(minutes: 45),
        isCancelled: true,
        location: 'Backup room',
      ),
    };

    final CalendarTask task = CalendarTask(
      id: 'sample',
      title: 'Shared weekly sync',
      description: 'Bring slides',
      scheduledTime: start,
      duration: const Duration(hours: 1),
      isCompleted: true,
      createdAt: DateTime.utc(2024, 1, 1),
      modifiedAt: DateTime.utc(2024, 1, 1, 1),
      location: 'HQ',
      deadline: deadline,
      priority: TaskPriority.urgent,
      endDate: null,
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        byWeekdays: const [DateTime.monday, DateTime.wednesday],
        until: DateTime.utc(2024, 7, 1),
        count: 5,
      ),
      occurrenceOverrides: overrides,
    );

    final String shareText = task.toShareText(now: ctx.reference);
    final NlScheduleParserService service = NlScheduleParserService();
    final NlAdapterResult result = await service.parse(shareText, context: ctx);
    final CalendarTask parsed = result.task;

    expect(parsed.title, task.title);
    expect(parsed.isCompleted, isTrue);
    expect(parsed.scheduledTime, task.scheduledTime);
    expect(parsed.displayEnd, task.displayEnd);
    expect(parsed.deadline, task.deadline);
    expect(parsed.location, task.location);
    expect(parsed.effectiveRecurrence.frequency,
        task.effectiveRecurrence.frequency);
    expect(parsed.effectiveRecurrence.byWeekdays,
        task.effectiveRecurrence.byWeekdays);
    expect(parsed.effectiveRecurrence.until?.toUtc(),
        task.effectiveRecurrence.until?.toUtc());
    expect(parsed.effectiveRecurrence.count, task.effectiveRecurrence.count);
    expect(parsed.description, task.description);
    expect(parsed.occurrenceOverrides.length, overrides.length);

    final TaskOccurrenceOverride? parsedOverride =
        parsed.occurrenceOverrides[overrides.keys.first];
    final TaskOccurrenceOverride sourceOverride = overrides.values.first;
    expect(parsedOverride?.isCancelled, isTrue);
    expect(parsedOverride?.scheduledTime, sourceOverride.scheduledTime);
    expect(parsedOverride?.duration, sourceOverride.duration);
    expect(parsedOverride?.location, sourceOverride.location);
  });

  test('round-trips omitted-year share text in current year', () async {
    tzdata.initializeTimeZones();
    final DateTime reference = DateTime.utc(2024, 5, 1);
    final ParseContext ctx = ParseContext(
      location: tz.UTC,
      timezoneId: 'UTC',
      reference: reference,
    );

    final DateTime start = DateTime.utc(2024, 8, 20, 16);
    final CalendarTask task = CalendarTask(
      id: 't3',
      title: 'Quarterly review',
      scheduledTime: start,
      duration: const Duration(hours: 2),
      createdAt: reference,
      modifiedAt: reference,
    );

    final String shareText = task.toShareText(now: reference);
    expect(shareText, isNot(contains('2024')));
    expect(shareText, contains('on Aug 20 from 4:00 PM to 6:00 PM'));

    final NlScheduleParserService service = NlScheduleParserService();
    final NlAdapterResult result = await service.parse(shareText, context: ctx);

    expect(result.task.scheduledTime, task.scheduledTime);
    expect(result.task.displayEnd, task.displayEnd);
    expect(result.task.title, task.title);
  });
}
