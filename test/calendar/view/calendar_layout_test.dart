import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/layout/calendar_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarLayoutCalculator', () {
    test(
      'midnight-ending tasks stay within a single day column',
      () {
        final start = DateTime(2024, 1, 1, 23);
        final task = CalendarTask(
          id: 'task-midnight',
          title: 'Late Session',
          scheduledTime: start,
          duration: const Duration(hours: 1),
          createdAt: start,
          modifiedAt: start,
        );

        const calculator = CalendarLayoutCalculator();
        final metrics = calculator.resolveMetrics(
          zoomIndex: 0,
          isDayView: false,
          availableHeight: 1200,
          allowDayViewZoom: true,
        );

        final layout = calculator.resolveTaskLayout(
          task: task,
          dayDate: DateTime(2024, 1, 1),
          weekStartDate: DateTime(2023, 12, 31),
          weekEndDate: DateTime(2024, 1, 6),
          isDayView: false,
          startHour: 0,
          endHour: 24,
          dayWidth: 200,
          metrics: metrics,
          overlap: const OverlapInfo(columnIndex: 0, totalColumns: 1),
        );

        expect(layout, isNotNull);
        expect(layout!.spanDays, equals(1));
        final inset = CalendarLayoutTheme.material.eventHorizontalInset;
        expect(layout.left, equals(inset));
        expect(layout.width, equals(200 - (inset * 2)));
      },
    );
  });
}
