// ignore_for_file: prefer_const_declarations, prefer_const_constructors

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/controllers/task_draft_controller.dart';
import 'package:axichat/src/calendar/view/widgets/recurrence_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceFormValue resolveLinkedLimits', () {
    test('fills until when only count provided for daily cadence', () {
      final start = DateTime(2024, 5, 1, 9);
      final value = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        count: 3,
      );

      final resolved = value.resolveLinkedLimits(start);
      expect(resolved.until, start.add(const Duration(days: 2)));
      expect(resolved.count, 3);
    });

    test('fills count when only until provided for weekly multi-day cadence',
        () {
      final start = DateTime(2024, 5, 6, 10); // Monday
      final until = DateTime(2024, 5, 13, 10); // Next Monday
      final value = RecurrenceFormValue(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        weekdays: {DateTime.monday, DateTime.wednesday},
        until: until,
      );

      final resolved = value.resolveLinkedLimits(start);
      expect(resolved.count, 3); // Mon, Wed, next Mon
      expect(resolved.until, until);
    });

    test('derives limits for monthly cadence with clamped day', () {
      final start = DateTime(2024, 1, 31, 8);
      final value = const RecurrenceFormValue(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        count: 2,
      );

      final resolved = value.resolveLinkedLimits(start);
      expect(resolved.count, 2);
      expect(resolved.until, DateTime(2024, 2, 29, 8));
    });
  });

  group('TaskDraftController recurrence normalization', () {
    test('synchronizes until when count set after start', () {
      final controller = TaskDraftController();
      final start = DateTime(2024, 5, 1, 9);

      controller.updateStart(start);
      controller.setRecurrence(const RecurrenceFormValue(
        frequency: RecurrenceFrequency.daily,
        count: 4,
      ));

      expect(controller.recurrence.count, 4);
      expect(
        controller.recurrence.until,
        start.add(const Duration(days: 3)),
      );
    });
  });
}
