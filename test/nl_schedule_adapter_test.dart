import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/nl_schedule_adapter.dart';
import 'package:axichat/src/calendar/utils/schedule_parser.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location location;
  late ParseContext context;
  const baseAdapter = NlScheduleAdapter();

  ScheduleItem buildItem({
    String title = 'Plan workshop',
    tz.TZDateTime? start,
    tz.TZDateTime? end,
    bool allDay = false,
    String? location,
    List<String>? participants,
    double confidence = 0.96,
    Set<AmbiguityFlag>? flags,
    List<String>? assumptions,
    bool approximate = false,
    PriorityQuadrant priority = PriorityQuadrant.notImportantNotUrgent,
    Recurrence? recurrence,
    tz.TZDateTime? deadline,
    String? source,
  }) {
    return ScheduleItem(
      task: title,
      start: start,
      end: end,
      allDay: allDay,
      location: location,
      participants: participants ?? const [],
      source: source ?? title,
      confidence: confidence,
      flags: flags ?? <AmbiguityFlag>{},
      assumptions: assumptions ?? const [],
      approximate: approximate,
      priority: priority,
      recurrence: recurrence,
      deadline: deadline,
    );
  }

  tz.TZDateTime zoned(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
  ]) =>
      tz.TZDateTime(location, year, month, day, hour, minute);

  setUpAll(() {
    tzdata.initializeTimeZones();
    location = tz.getLocation('America/New_York');
    context = ParseContext(location: location, timezoneId: 'America/New_York');
  });

  DateTime wallTime(tz.TZDateTime dt) => DateTime(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
        dt.microsecond,
      );

  group('NlScheduleAdapter', () {
    test('maps scheduled bucket with explicit times', () {
      final item = buildItem(
        start: zoned(2024, 7, 1, 10),
        end: zoned(2024, 7, 1, 11),
        location: '  Office  ',
      );

      final result = baseAdapter.mapToAppTypes(item, ctx: context);

      expect(result.bucket, TaskBucket.scheduled);
      expect(result.task.scheduledTime, wallTime(zoned(2024, 7, 1, 10)));
      expect(result.task.duration, const Duration(hours: 1));
      expect(result.task.location, 'Office');
      expect(result.start, isNotNull);
      expect(result.start!.timezoneId, 'America/New_York');
      expect(result.start!.wallTime.hour, 10);
    });

    test('classifies reminder bucket when only deadline exists', () {
      final deadline = zoned(2024, 9, 10, 18);
      final item = buildItem(
        start: null,
        deadline: deadline,
        priority: PriorityQuadrant.notImportantUrgent,
      );

      final result = baseAdapter.mapToAppTypes(item, ctx: context);

      expect(result.bucket, TaskBucket.reminder);
      expect(result.task.scheduledTime, isNull);
      expect(result.task.deadline, wallTime(deadline));
      expect(result.deadline!.timezoneId, 'America/New_York');
      expect(result.task.priority, TaskPriority.urgent);
    });

    test('falls back to unscheduled bucket when no time metadata', () {
      final item = buildItem(
        start: null,
        deadline: null,
        recurrence: null,
        title: 'Brainstorm later',
      );
      final result = baseAdapter.mapToAppTypes(item, ctx: context);
      expect(result.bucket, TaskBucket.unscheduled);
      expect(result.task.scheduledTime, isNull);
      expect(result.task.deadline, isNull);
    });

    test('uses default duration when only start provided', () {
      final adapter = NlScheduleAdapter(
        config: const NlAdapterConfig(
          defaultDuration: Duration(minutes: 90),
        ),
      );
      final item = buildItem(start: zoned(2024, 2, 3, 9));
      final result = adapter.mapToAppTypes(item, ctx: context);
      expect(result.task.duration, const Duration(minutes: 90));
      final endLocal = result.task.scheduledTime!.add(result.task.duration!);
      expect(endLocal, wallTime(zoned(2024, 2, 3, 10, 30)));
    });

    test('all-day items get allDaySpan duration', () {
      final adapter = NlScheduleAdapter(
        config: const NlAdapterConfig(allDaySpan: Duration(hours: 36)),
      );
      final item = buildItem(
        start: zoned(2024, 12, 24),
        allDay: true,
      );
      final result = adapter.mapToAppTypes(item, ctx: context);
      expect(result.task.duration, const Duration(hours: 36));
    });

    test('priority mapping covers all quadrants', () {
      expect(
        baseAdapter.mapPriority(PriorityQuadrant.importantUrgent),
        TaskPriority.critical,
      );
      expect(
        baseAdapter.mapPriority(PriorityQuadrant.importantNotUrgent),
        TaskPriority.important,
      );
      expect(
        baseAdapter.mapPriority(PriorityQuadrant.notImportantUrgent),
        TaskPriority.urgent,
      );
      expect(
        baseAdapter.mapPriority(PriorityQuadrant.notImportantNotUrgent),
        TaskPriority.none,
      );
    });

    test('mergeAssumptions combines flags, notes, and confidence', () {
      final text = baseAdapter.mergeAssumptions(
        {AmbiguityFlag.noDateFound, AmbiguityFlag.locationGuessed},
        const ['Used inbox default date.'],
        0.74,
      );
      expect(text, contains('no date'));
      expect(text, contains('location guessed'));
      expect(text, contains('Used inbox default date.'));
      expect(text, contains('Confidence: 74%'));
    });

    test('maps recurrence rule to weekly with weekdays list', () {
      final recurrence = Recurrence(
        rrule: 'FREQ=WEEKLY;BYDAY=MO,WE;INTERVAL=2',
        text: 'Every other Mon/Wed',
        until: zoned(2024, 12, 1),
      );
      final mapped = baseAdapter.mapRecurrence(recurrence);
      expect(mapped, isNotNull);
      expect(mapped!.frequency, RecurrenceFrequency.weekly);
      expect(mapped.interval, 2);
      expect(mapped.byWeekdays,
          unorderedEquals([DateTime.monday, DateTime.wednesday]));
      expect(mapped.until, wallTime(recurrence.until!));
    });

    test('detects weekday-only recurrence', () {
      final recurrence = Recurrence(
        rrule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
        text: 'Weekdays',
      );
      final mapped = baseAdapter.mapRecurrence(recurrence);
      expect(mapped, isNotNull);
      expect(mapped!.frequency, RecurrenceFrequency.weekdays);
    });

    test('parses UNTIL/count from ICS string when tz until missing', () {
      final recurrence = Recurrence(
        rrule: 'FREQ=MONTHLY;UNTIL=20241231T235959Z;COUNT=10',
        text: 'Through 2024',
      );
      final mapped = baseAdapter.mapRecurrence(recurrence);
      expect(mapped, isNotNull);
      expect(mapped!.frequency, RecurrenceFrequency.monthly);
      expect(mapped.until, DateTime.utc(2024, 12, 31, 23, 59, 59).toLocal());
      expect(mapped.count, 10);
    });

    test('deduplicates and trims participants', () {
      final item = buildItem(
        start: zoned(2024, 5, 6, 14),
        participants: const ['  Alice ', 'bob', 'Alice', ''],
      );
      final result = baseAdapter.mapToAppTypes(item, ctx: context);
      expect(result.participants, equals(['Alice', 'bob']));
    });

    test('parse notes stay null when no ambiguity present', () {
      final item = buildItem(
        start: zoned(2024, 3, 3, 9),
        end: zoned(2024, 3, 3, 9, 30),
        flags: const {},
        assumptions: const [],
        confidence: 0.99,
      );
      final result = baseAdapter.mapToAppTypes(item, ctx: context);
      expect(result.parseNotes, isNull);
    });

    test('parse notes include flags when ambiguity exists', () {
      final item = buildItem(
        start: null,
        flags: {AmbiguityFlag.noDateFound},
        assumptions: const ['Interpreted "later" as unscheduled'],
        confidence: 0.4,
      );
      final result = baseAdapter.mapToAppTypes(item, ctx: context);
      expect(result.parseNotes, isNotNull);
      expect(result.parseNotes, contains('no date'));
      expect(result.parseNotes, contains('Interpreted "later" as unscheduled'));
      expect(result.parseNotes, contains('Confidence'));
    });

    test('toEvent returns null for reminder bucket', () {
      final item = buildItem(
        start: null,
        deadline: zoned(2025, 1, 1, 8),
      );
      final task = baseAdapter.toEvent(item, ctx: context);
      expect(task, isNull);
    });

    test('toEvent returns CalendarTask for scheduled bucket', () {
      final item = buildItem(start: zoned(2024, 6, 10, 8));
      final task = baseAdapter.toEvent(item, ctx: context);
      expect(task, isNotNull);
      expect(task!.scheduledTime, wallTime(zoned(2024, 6, 10, 8)));
    });

    test('metadata keeps timezone info for deadline', () {
      final item = buildItem(
        start: zoned(2024, 8, 20, 15),
        deadline: zoned(2024, 8, 19, 12),
      );
      final result = baseAdapter.mapToAppTypes(item, ctx: context);
      expect(result.deadline, isNotNull);
      expect(result.deadline!.timezoneId, 'America/New_York');
      expect(result.deadline!.utc, DateTime.utc(2024, 8, 19, 16));
    });
  });
}
