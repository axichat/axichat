import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/resizable_task_widget.dart';

void main() {
  testWidgets('ResizableTaskWidget invokes onTap when tapped', (tester) async {
    final task = CalendarTask.create(title: 'Sample Task');
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResizableTaskWidget(
            task: task,
            onResizePreview: (_) {},
            onResizeEnd: (_) {},
            hourHeight: 40,
            stepHeight: 10,
            minutesPerStep: 15,
            width: 100,
            height: 40,
            isDayView: false,
            onTap: (selectedTask, bounds) {
              tapped = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ResizableTaskWidget));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
