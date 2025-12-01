import 'dart:async';
import 'dart:convert';

import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/storage/day_event_repository.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockXmppDatabase extends Mock implements XmppDatabase {}

void main() {
  late _MockXmppDatabase database;
  late DayEventRepository repository;

  final DateTime now = DateTime(2024, 1, 10, 8);
  final DayEventEntry baselineEntry = DayEventEntry(
    id: 'day-1',
    title: 'Birthday',
    startDate: DateTime(2024, 1, 15),
    endDate: DateTime(2024, 1, 15),
    description: 'Cake and coffee',
    reminders: jsonEncode(ReminderPreferences.defaults().toJson()),
    createdAt: now,
    modifiedAt: now,
  );

  setUpAll(() {
    registerFallbackValue(baselineEntry);
  });

  setUp(() {
    database = _MockXmppDatabase();
    repository = DayEventRepository(database: Future.value(database));
  });

  test('watchDayEvents maps database entries to models', () async {
    final StreamController<List<DayEventEntry>> controller =
        StreamController<List<DayEventEntry>>();

    when(
      () => database.watchDayEvents(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) => controller.stream);

    final List<List<DayEvent>> emitted = <List<DayEvent>>[];
    unawaited(
      repository
          .watchDayEvents(
            DateTime(2024, 1, 1),
            DateTime(2024, 1, 31),
          )
          .listen(emitted.add)
          .asFuture(),
    );

    controller.add(<DayEventEntry>[baselineEntry]);
    await controller.close();

    expect(emitted, hasLength(1));
    final DayEvent mapped = emitted.single.single;
    expect(mapped.title, baselineEntry.title);
    expect(mapped.description, baselineEntry.description);
    expect(mapped.normalizedStart, baselineEntry.startDate);
    expect(mapped.effectiveReminders.isEnabled, isTrue);
  });

  test('upsert normalizes event data before persisting', () async {
    DayEventEntry? persisted;
    when(() => database.saveDayEvent(any())).thenAnswer((invocation) async {
      persisted = invocation.positionalArguments.first as DayEventEntry;
    });

    final DayEvent event = DayEvent.create(
      title: 'Multi-day holiday',
      startDate: DateTime(2024, 2, 10),
      endDate: DateTime(2024, 2, 8),
      description: 'Should normalize end date',
    );

    await repository.upsert(event);

    expect(persisted, isNotNull);
    expect(persisted!.endDate.isAtSameMomentAs(persisted!.startDate), isTrue);
    expect(persisted!.reminders, isNotEmpty);
  });

  test('replaceAll forwards normalized entries', () async {
    final List<DayEventEntry> replaced = <DayEventEntry>[];
    when(() => database.replaceDayEvents(any())).thenAnswer((invocation) async {
      replaced
        ..clear()
        ..addAll(
            invocation.positionalArguments.first as Iterable<DayEventEntry>);
    });

    final DayEvent a = DayEvent.create(
      title: 'A',
      startDate: DateTime(2024, 3, 1),
    );
    final DayEvent b = DayEvent.create(
      title: 'B',
      startDate: DateTime(2024, 3, 2),
      reminders: const ReminderPreferences(
        enabled: true,
        startOffsets: <Duration>[Duration(hours: 2)],
        deadlineOffsets: <Duration>[],
      ),
    );

    await repository.replaceAll(<DayEvent>[a, b]);

    expect(replaced, hasLength(2));
    expect(replaced.first.id, a.id);
    expect(replaced.last.reminders, isNotEmpty);
  });
}
