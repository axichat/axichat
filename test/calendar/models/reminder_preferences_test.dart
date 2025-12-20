import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('ReminderPreferences', () {
    test('defaults returns disabled empty reminders (sentinel value)', () {
      final ReminderPreferences prefs = ReminderPreferences.defaults();

      // defaults() is a sentinel for "no reminders configured"
      expect(prefs.enabled, isFalse);
      expect(prefs.startOffsets, isEmpty);
      expect(prefs.deadlineOffsets, isEmpty);
      expect(prefs.isEnabled, isFalse);
    });

    test('normalized removes negatives and duplicates', () {
      const ReminderPreferences prefs = ReminderPreferences(
        startOffsets: <Duration>[
          Duration(hours: 1),
          Duration(hours: -1),
          Duration(hours: 1),
        ],
        deadlineOffsets: <Duration>[
          Duration(minutes: 30),
          Duration(minutes: 30),
        ],
      );

      final ReminderPreferences normalized = prefs.normalized();

      expect(normalized.startOffsets,
          equals(<Duration>[const Duration(hours: 1)]));
      expect(
        normalized.deadlineOffsets,
        equals(<Duration>[const Duration(minutes: 30)]),
      );
    });

    test('normalized disables when no offsets', () {
      const ReminderPreferences prefs = ReminderPreferences(
        enabled: true,
        startOffsets: <Duration>[],
        deadlineOffsets: <Duration>[],
      );

      final ReminderPreferences normalized = prefs.normalized();

      expect(normalized.isEnabled, isFalse);
    });
  });
}
