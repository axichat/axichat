import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('TaskShareFormatter', () {
    test('does not serialize reminder preferences into descriptions', () {
      final DateTime start = DateTime(2024, 8, 1, 10);
      final CalendarTask task = CalendarTask.create(
        title: 'Planning session',
        scheduledTime: start,
        duration: const Duration(hours: 1),
        description: 'Discuss roadmap',
      );

      final String baseline = TaskShareFormatter.describe(task);
      final String withReminders = TaskShareFormatter.describe(
        task.copyWith(
          reminders: const ReminderPreferences(
            enabled: true,
            startOffsets: <Duration>[
              Duration(hours: 2),
              Duration(minutes: 30),
            ],
            deadlineOffsets: <Duration>[Duration(hours: 4)],
          ),
        ),
      );

      expect(withReminders, equals(baseline));
      expect(withReminders.toLowerCase().contains('remind'), isFalse);
    });

    test('describes yearly recurrence intervals', () {
      final DateTime reference = DateTime(2024, 1, 1);
      final DateTime start = DateTime(2024, 2, 1, 9);
      const Duration duration = Duration(hours: 1);
      const int yearlyInterval = 1;
      const int everyOtherYearInterval = 2;
      const int everyThreeYearsInterval = 3;
      const String expectedEveryYear = 'every year';
      const String expectedEveryOtherYear = 'every other year';
      const String expectedEveryThreeYears = 'every 3 years';
      const String title = 'Annual review';

      CalendarTask makeTask(int interval) => CalendarTask.create(
            title: title,
            scheduledTime: start,
            duration: duration,
            recurrence: RecurrenceRule(
              frequency: RecurrenceFrequency.yearly,
              interval: interval,
            ),
          );

      final String yearlyText = TaskShareFormatter.describe(
        makeTask(yearlyInterval),
        now: reference,
      );
      final String everyOtherYearText = TaskShareFormatter.describe(
        makeTask(everyOtherYearInterval),
        now: reference,
      );
      final String everyThreeYearsText = TaskShareFormatter.describe(
        makeTask(everyThreeYearsInterval),
        now: reference,
      );

      expect(yearlyText, contains(expectedEveryYear));
      expect(everyOtherYearText, contains(expectedEveryOtherYear));
      expect(everyThreeYearsText, contains(expectedEveryThreeYears));
    });
  });
}
