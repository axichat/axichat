import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('DayEvent', () {
    test('create normalizes dates and reminders', () {
      final DayEvent event = DayEvent.create(
        title: 'Anniversary',
        startDate: DateTime(2024, 6, 1, 12, 30),
        endDate: DateTime(2024, 6, 1, 23, 59),
        reminders: const ReminderPreferences(
          startOffsets: <Duration>[Duration(hours: 1)],
        ),
      );

      expect(event.normalizedStart.hour, 0);
      expect(event.normalizedEnd.hour, 0);
      expect(event.reminders?.isEnabled, isTrue);
    });

    test('occursOn returns true for inclusive ranges', () {
      final DayEvent holiday = DayEvent.create(
        title: 'Holiday',
        startDate: DateTime(2024, 12, 24),
        endDate: DateTime(2024, 12, 26),
      );

      expect(holiday.occursOn(DateTime(2024, 12, 24)), isTrue);
      expect(holiday.occursOn(DateTime(2024, 12, 25)), isTrue);
      expect(holiday.occursOn(DateTime(2024, 12, 26)), isTrue);
      expect(holiday.occursOn(DateTime(2024, 12, 27)), isFalse);
    });

    test('normalizedCopy clamps invalid end dates', () {
      final DayEvent source = DayEvent.create(
        title: 'Conference',
        startDate: DateTime(2024, 3, 10),
      );

      final DayEvent updated = source.normalizedCopy(
        endDate: DateTime(2024, 3, 8),
        reminders: const ReminderPreferences(
          startOffsets: <Duration>[
            Duration(hours: 2),
            Duration(hours: 2),
            Duration(minutes: -10),
          ],
        ),
      );

      expect(updated.normalizedEnd, equals(updated.normalizedStart));
      expect(updated.effectiveReminders.startOffsets,
          contains(const Duration(hours: 2)));
      expect(updated.effectiveReminders.startOffsets, hasLength(1));
    });

    test('JSON round-trip preserves fields', () {
      final DayEvent event = DayEvent.create(
        title: 'Birthday',
        description: 'Ice cream',
        startDate: DateTime(2024, 7, 14),
        reminders: const ReminderPreferences(
          startOffsets: <Duration>[Duration(hours: 1)],
        ),
      );

      final Map<String, dynamic> json = event.toJson();
      final DayEvent restored = DayEvent.fromJson(json);

      expect(restored.title, equals(event.title));
      expect(restored.description, equals(event.description));
      expect(restored.normalizedStart, equals(event.normalizedStart));
      expect(restored.effectiveReminders.isEnabled, isTrue);
      expect(
        restored.effectiveReminders.startOffsets,
        contains(const Duration(hours: 1)),
      );
    });
  });
}
