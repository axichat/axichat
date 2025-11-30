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
  });
}
