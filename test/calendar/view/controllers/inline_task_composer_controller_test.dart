import 'package:axichat/src/calendar/view/controllers/inline_task_composer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InlineTaskComposerController', () {
    test('applies parser schedule suggestions and expands composer', () {
      final controller = InlineTaskComposerController();
      final scheduled = DateTime(2024, 5, 3, 14, 30);

      controller.applyParserSchedule(scheduled);

      expect(controller.selectedDate,
          DateTime(scheduled.year, scheduled.month, scheduled.day));
      expect(controller.selectedTime, const TimeOfDay(hour: 14, minute: 30));
      expect(controller.isExpanded, isTrue);
    });

    test('user overrides lock schedule fields from parser updates', () {
      final controller = InlineTaskComposerController();
      final manualDate = DateTime(2024, 5, 10);

      controller.setDate(manualDate, fromUser: true);
      controller.setTime(const TimeOfDay(hour: 9, minute: 0), fromUser: true);
      controller.applyParserSchedule(DateTime(2024, 5, 12, 16, 0));

      expect(controller.selectedDate, manualDate);
      expect(controller.selectedTime, const TimeOfDay(hour: 9, minute: 0));
      expect(controller.hasManualSchedule, isTrue);
    });

    test('clearParserSuggestions only removes parser-provided values', () {
      final controller = InlineTaskComposerController();
      controller.applyParserSchedule(DateTime(2024, 5, 12, 11, 0));

      controller.clearParserSuggestions();

      expect(controller.selectedDate, isNull);
      expect(controller.selectedTime, isNull);

      controller.setDate(DateTime(2024, 5, 30), fromUser: true);
      controller.setTime(const TimeOfDay(hour: 8, minute: 45), fromUser: true);
      controller.clearParserSuggestions();

      expect(controller.selectedDate, DateTime(2024, 5, 30));
      expect(controller.selectedTime, const TimeOfDay(hour: 8, minute: 45));
    });

    test('resetSchedule releases locks so parser can suggest again', () {
      final controller = InlineTaskComposerController();
      controller.setDate(DateTime(2024, 6, 1), fromUser: true);
      controller.setTime(const TimeOfDay(hour: 10, minute: 15), fromUser: true);
      controller.resetSchedule();

      controller.applyParserSchedule(DateTime(2024, 6, 2, 13, 0));

      expect(controller.selectedDate, DateTime(2024, 6, 2));
      expect(controller.selectedTime, const TimeOfDay(hour: 13, minute: 0));
      expect(controller.hasManualSchedule, isFalse);
    });
  });
}
