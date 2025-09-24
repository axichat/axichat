import 'package:flutter_test/flutter_test.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/calendar_grid.dart'
    show calculateOverlapColumns;

void main() {
  CalendarTask _task({
    required String title,
    required int hour,
    required int minute,
    int durationMinutes = 60,
  }) {
    return CalendarTask.create(
      title: title,
      scheduledTime: DateTime(2024, 1, 15, hour, minute),
      duration: Duration(minutes: durationMinutes),
    );
  }

  test('non-overlapping tasks occupy full width', () {
    final a = _task(title: 'A', hour: 9, minute: 0, durationMinutes: 30);
    final b = _task(title: 'B', hour: 10, minute: 0, durationMinutes: 30);

    final overlaps = calculateOverlapColumns([a, b]);

    expect(overlaps[a.id]?.columnIndex, 0);
    expect(overlaps[a.id]?.totalColumns, 1);
    expect(overlaps[b.id]?.columnIndex, 0);
    expect(overlaps[b.id]?.totalColumns, 1);
  });

  test('overlapping tasks split columns evenly', () {
    final a = _task(title: 'A', hour: 9, minute: 0, durationMinutes: 60);
    final b = _task(title: 'B', hour: 9, minute: 30, durationMinutes: 60);

    final overlaps = calculateOverlapColumns([a, b]);

    expect(overlaps[a.id]?.totalColumns, 2);
    expect(overlaps[b.id]?.totalColumns, 2);
    expect(overlaps[a.id]?.columnIndex, isNot(overlaps[b.id]?.columnIndex));
  });

  test('sequential tasks stay full width when new overlaps occur', () {
    final t1 = _task(title: 'T1', hour: 10, minute: 0, durationMinutes: 15);
    final t2 = _task(title: 'T2', hour: 10, minute: 15, durationMinutes: 15);
    final t3 = _task(title: 'T3', hour: 10, minute: 30, durationMinutes: 15);
    final split =
        _task(title: 'Split', hour: 10, minute: 0, durationMinutes: 15);

    final overlaps = calculateOverlapColumns([t1, t2, t3, split]);

    expect(overlaps[t1.id]?.totalColumns, 2);
    expect(overlaps[split.id]?.totalColumns, 2);
    expect(overlaps[t2.id]?.columnIndex, 0);
    expect(overlaps[t2.id]?.totalColumns, 1);
    expect(overlaps[t3.id]?.columnIndex, 0);
    expect(overlaps[t3.id]?.totalColumns, 1);
  });
}
