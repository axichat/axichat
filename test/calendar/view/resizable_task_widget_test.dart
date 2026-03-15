import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/resizable_task_widget.dart';
import 'package:axichat/src/localization/app_localizations.dart';

Widget _wrapWithShadTheme(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ShadTheme(
      data: ShadThemeData(
        colorScheme: const ShadSlateColorScheme.light(),
        brightness: Brightness.light,
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('ResizableTaskWidget invokes onTap when tapped', (tester) async {
    final task = CalendarTask.create(title: 'Sample Task');
    bool tapped = false;

    await tester.pumpWidget(
      _wrapWithShadTheme(
        ResizableTaskWidget(
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
    );

    await tester.tap(find.byType(ResizableTaskWidget));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('Secondary pointer down does not classify a drag target', (
    tester,
  ) async {
    final controller = TaskInteractionController();
    final task = CalendarTask.create(title: 'Secondary Pointer Task');

    await tester.pumpWidget(
      _wrapWithShadTheme(
        ResizableTaskWidget(
          interactionController: controller,
          task: task,
          onResizePreview: (_) {},
          onResizeEnd: (_) {},
          hourHeight: 40,
          stepHeight: 10,
          minutesPerStep: 15,
          width: 120,
          height: 40,
          isDayView: false,
        ),
      ),
    );

    final gesture = await tester.createGesture(
      pointer: 21,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await gesture.down(tester.getCenter(find.byType(ResizableTaskWidget)));
    await tester.pump();

    expect(
      controller.taskPointerClassification(taskId: task.id, pointerId: 21),
      isNull,
    );

    await gesture.up();
    controller.dispose();
  });

  testWidgets('Primary body pointer classifies as body', (tester) async {
    final controller = TaskInteractionController();
    final task = CalendarTask.create(title: 'Primary Pointer Task');

    await tester.pumpWidget(
      _wrapWithShadTheme(
        ResizableTaskWidget(
          interactionController: controller,
          task: task,
          onResizePreview: (_) {},
          onResizeEnd: (_) {},
          hourHeight: 40,
          stepHeight: 10,
          minutesPerStep: 15,
          width: 120,
          height: 40,
          isDayView: false,
        ),
      ),
    );

    final gesture = await tester.createGesture(
      pointer: 22,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.down(tester.getCenter(find.byType(ResizableTaskWidget)));
    await tester.pump();

    expect(
      controller.taskPointerClassification(taskId: task.id, pointerId: 22),
      CalendarTaskPointerTarget.body,
    );

    await gesture.up();
    controller.dispose();
  });

  testWidgets('Top handle pointer classifies as resize top', (tester) async {
    final controller = TaskInteractionController();
    final task = CalendarTask.create(
      title: 'Handle Pointer Task',
      scheduledTime: DateTime(2024, 1, 1, 10),
      duration: const Duration(hours: 1),
    );

    await tester.pumpWidget(
      _wrapWithShadTheme(
        Align(
          alignment: Alignment.topLeft,
          child: ResizableTaskWidget(
            interactionController: controller,
            task: task,
            onResizePreview: (_) {},
            onResizeEnd: (_) {},
            hourHeight: 40,
            stepHeight: 10,
            minutesPerStep: 15,
            width: 120,
            height: 80,
            isDayView: false,
            resizeHandleExtent: 12,
          ),
        ),
      ),
    );

    final Rect rect = tester.getRect(find.byType(ResizableTaskWidget));
    final gesture = await tester.createGesture(
      pointer: 23,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.down(Offset(rect.center.dx, rect.top + 2));
    await tester.pump();

    expect(
      controller.taskPointerClassification(taskId: task.id, pointerId: 23),
      CalendarTaskPointerTarget.resizeTop,
    );

    await gesture.up();
    controller.dispose();
  });

  testWidgets('Unscheduled top edge still classifies as body', (tester) async {
    final controller = TaskInteractionController();
    final task = CalendarTask.create(title: 'Unscheduled Handle Edge Task');

    await tester.pumpWidget(
      _wrapWithShadTheme(
        Align(
          alignment: Alignment.topLeft,
          child: ResizableTaskWidget(
            interactionController: controller,
            task: task,
            onResizePreview: (_) {},
            onResizeEnd: (_) {},
            hourHeight: 40,
            stepHeight: 10,
            minutesPerStep: 15,
            width: 120,
            height: 80,
            isDayView: false,
            resizeHandleExtent: 12,
          ),
        ),
      ),
    );

    final Rect rect = tester.getRect(find.byType(ResizableTaskWidget));
    final gesture = await tester.createGesture(
      pointer: 24,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.down(Offset(rect.center.dx, rect.top + 2));
    await tester.pump();

    expect(
      controller.taskPointerClassification(taskId: task.id, pointerId: 24),
      CalendarTaskPointerTarget.body,
    );

    await gesture.up();
    controller.dispose();
  });

  testWidgets(
    'Bottom handle overshoot above top handle does not bank resize movement',
    (tester) async {
      Future<CalendarTask?> runDrag(List<double> yPositions) async {
        final controller = TaskInteractionController();
        final task = CalendarTask.create(
          title: 'Bottom Resize Task',
          scheduledTime: DateTime(2024, 1, 1, 10),
          duration: const Duration(hours: 1),
        );
        CalendarTask? preview;

        await tester.pumpWidget(
          _wrapWithShadTheme(
            Align(
              alignment: Alignment.topLeft,
              child: ResizableTaskWidget(
                interactionController: controller,
                task: task,
                onResizePreview: (value) => preview = value,
                onResizeEnd: (_) {},
                hourHeight: 80,
                stepHeight: 20,
                minutesPerStep: 15,
                width: 120,
                height: 80,
                isDayView: false,
              ),
            ),
          ),
        );

        final Rect rect = tester.getRect(find.byType(ResizableTaskWidget));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryButton,
        );
        await gesture.down(Offset(rect.center.dx, rect.bottom - 2));
        await tester.pump();
        for (final double y in yPositions) {
          await gesture.moveTo(Offset(rect.center.dx, rect.top + y));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
        controller.dispose();
        return preview;
      }

      final CalendarTask? directPreview = await runDrag(const <double>[25]);
      final CalendarTask? overshootPreview = await runDrag(const <double>[
        1,
        25,
      ]);

      expect(directPreview?.duration, overshootPreview?.duration);
      expect(directPreview?.scheduledTime, overshootPreview?.scheduledTime);
    },
  );

  testWidgets(
    'Top handle overshoot below bottom handle does not bank resize movement',
    (tester) async {
      Future<CalendarTask?> runDrag(List<double> yPositions) async {
        final controller = TaskInteractionController();
        final task = CalendarTask.create(
          title: 'Top Resize Task',
          scheduledTime: DateTime(2024, 1, 1, 10),
          duration: const Duration(hours: 1),
        );
        CalendarTask? preview;

        await tester.pumpWidget(
          _wrapWithShadTheme(
            Align(
              alignment: Alignment.topLeft,
              child: ResizableTaskWidget(
                interactionController: controller,
                task: task,
                onResizePreview: (value) => preview = value,
                onResizeEnd: (_) {},
                hourHeight: 80,
                stepHeight: 20,
                minutesPerStep: 15,
                width: 120,
                height: 80,
                isDayView: false,
              ),
            ),
          ),
        );

        final Rect rect = tester.getRect(find.byType(ResizableTaskWidget));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryButton,
        );
        await gesture.down(Offset(rect.center.dx, rect.top + 2));
        await tester.pump();
        for (final double y in yPositions) {
          await gesture.moveTo(Offset(rect.center.dx, rect.top + y));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
        controller.dispose();
        return preview;
      }

      final CalendarTask? directPreview = await runDrag(const <double>[55]);
      final CalendarTask? overshootPreview = await runDrag(const <double>[
        79,
        55,
      ]);

      expect(directPreview?.duration, overshootPreview?.duration);
      expect(directPreview?.scheduledTime, overshootPreview?.scheduledTime);
    },
  );

  testWidgets('Bottom handle overshoot does not bank during autoscroll', (
    tester,
  ) async {
    Future<CalendarTask?> runDrag({
      required List<double> yPositions,
      required double autoScrollOffset,
      required bool overshootFirst,
    }) async {
      final controller = TaskInteractionController();
      final task = CalendarTask.create(
        title: 'Bottom Resize Autoscroll Task',
        scheduledTime: DateTime(2024, 1, 1, 10),
        duration: const Duration(hours: 1),
      );
      CalendarTask? preview;
      double viewportOffset = 0;

      await tester.pumpWidget(
        _wrapWithShadTheme(
          Align(
            alignment: Alignment.topLeft,
            child: ResizableTaskWidget(
              interactionController: controller,
              task: task,
              onResizePreview: (value) => preview = value,
              onResizeEnd: (_) {},
              hourHeight: 80,
              stepHeight: 20,
              minutesPerStep: 15,
              viewportScrollOffsetProvider: () => viewportOffset,
              width: 120,
              height: 80,
              isDayView: false,
            ),
          ),
        ),
      );

      final Rect rect = tester.getRect(find.byType(ResizableTaskWidget));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await gesture.down(Offset(rect.center.dx, rect.bottom - 2));
      await tester.pump();

      if (overshootFirst) {
        await gesture.moveTo(Offset(rect.center.dx, rect.top + 1));
        await tester.pump();
        viewportOffset = autoScrollOffset;
        controller.dispatchResizeAutoScrollDelta(autoScrollOffset);
        await tester.pump();
      }

      for (final double y in yPositions) {
        await gesture.moveTo(Offset(rect.center.dx, rect.top + y));
        await tester.pump();
      }

      await gesture.up();
      await tester.pump();
      controller.dispose();
      return preview;
    }

    final CalendarTask? directPreview = await runDrag(
      yPositions: const <double>[25],
      autoScrollOffset: 0,
      overshootFirst: false,
    );
    final CalendarTask? overshootPreview = await runDrag(
      yPositions: const <double>[25],
      autoScrollOffset: 60,
      overshootFirst: true,
    );

    expect(directPreview?.duration, overshootPreview?.duration);
    expect(directPreview?.scheduledTime, overshootPreview?.scheduledTime);
  });
}
