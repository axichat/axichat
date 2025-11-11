import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/resizable_task_widget.dart';

void main() {
  testWidgets('ResizableTaskWidget invokes onTap when tapped', (tester) async {
    final task = CalendarTask.create(title: 'Sample Task');
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResizableTaskWidget(
            interactionController: TaskInteractionController(),
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

  testWidgets('Secondary pointer down does not trigger drag pointer callback',
      (tester) async {
    final task = CalendarTask.create(title: 'Secondary Pointer Task');
    Offset? capturedOffset;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResizableTaskWidget(
            interactionController: TaskInteractionController(),
            task: task,
            onResizePreview: (_) {},
            onResizeEnd: (_) {},
            hourHeight: 40,
            stepHeight: 10,
            minutesPerStep: 15,
            width: 120,
            height: 40,
            isDayView: false,
            onDragPointerDown: (offset) => capturedOffset = offset,
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await gesture.down(tester.getCenter(find.byType(ResizableTaskWidget)));
    await tester.pump();
    await gesture.up();

    expect(capturedOffset, isNull);
  });

  testWidgets('Primary pointer down forwards to drag pointer callback',
      (tester) async {
    final task = CalendarTask.create(title: 'Primary Pointer Task');
    Offset? capturedOffset;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResizableTaskWidget(
            interactionController: TaskInteractionController(),
            task: task,
            onResizePreview: (_) {},
            onResizeEnd: (_) {},
            hourHeight: 40,
            stepHeight: 10,
            minutesPerStep: 15,
            width: 120,
            height: 40,
            isDayView: false,
            onDragPointerDown: (offset) => capturedOffset = offset,
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.down(tester.getCenter(find.byType(ResizableTaskWidget)));
    await tester.pump();
    await gesture.up();

    expect(capturedOffset, isNotNull);
  });
}
