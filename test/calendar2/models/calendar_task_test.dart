import 'package:axichat/src/calendar2/models/calendar_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarTask.create', () {
    test('generates id and timestamps with trimmed input', () {
      final task = CalendarTask.create(
        title: '  New Task  ',
        description: '  description  ',
        tags: const [' work ', '', 'urgent'],
        location: '  HQ  ',
      );

      expect(task.id, isNotEmpty);
      expect(task.title, 'New Task');
      expect(task.description, 'description');
      expect(task.location, 'HQ');
      expect(task.tags, equals(['work', 'urgent']));
      expect(task.createdAt, isNotNull);
      expect(task.updatedAt, task.createdAt);
      expect(task.isAllDay, isFalse);
      expect(task.important, isFalse);
      expect(task.urgent, isFalse);
    });

    test('computes spanDaysCount based on end date', () {
      final start = DateTime(2024, 2, 10, 9);
      final end = DateTime(2024, 2, 12, 17);
      final task = CalendarTask.create(
        title: 'Trip',
        scheduledStart: start,
        endDate: end,
      );

      expect(task.spanDaysCount, 3);
    });
  });

  group('CalendarTask priorityColor', () {
    test('returns red when both important and urgent', () {
      final task = CalendarTask.create(
        title: 'Alert',
        important: true,
        urgent: true,
      );

      expect(task.priorityColor, const Color(0xFFDC2626));
    });

    test('returns green when important only', () {
      final task = CalendarTask.create(
        title: 'Strategy',
        important: true,
      );

      expect(task.priorityColor, const Color(0xFF2563EB));
    });

    test('returns orange when urgent only', () {
      final task = CalendarTask.create(
        title: 'Call',
        urgent: true,
      );

      expect(task.priorityColor, const Color(0xFFF97316));
    });

    test('returns grey when neither important nor urgent', () {
      final task = CalendarTask.create(title: 'Note');

      expect(task.priorityColor, const Color(0xFF9CA3AF));
    });
  });

  group('CalendarTask.sanitized', () {
    test('normalizes tags and bumps updatedAt', () {
      final task = CalendarTask.create(
        title: 'Review',
        tags: const ['  alpha ', 'alpha', ' BETA '],
      );

      final sanitized = task.sanitized();

      expect(sanitized.tags, equals(['alpha', 'BETA']));
      expect(sanitized.updatedAt.isAfter(task.updatedAt), isTrue);
    });
  });
}
