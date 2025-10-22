import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_geometry.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_surface.dart';

void main() {
  testWidgets('CalendarTaskSurface reuses popover controller across rebuilds',
      (tester) async {
    final interactionController = TaskInteractionController();
    final task = CalendarTask.create(title: 'Persistent Menu');

    final callbacks = CalendarTaskTileCallbacks(
      onResizePreview: (_) {},
      onResizeEnd: (_) {},
      onResizePointerMove: (_) {},
      onDragStarted: (_, __) {},
      onDragUpdate: (_) {},
      onDragEnded: (_) {},
      onDragPointerDown: (_) {},
      onEnterSelectionMode: () {},
      onToggleSelection: () {},
      onTap: (_, __) {},
      computePreviewStartForHover: (_) => null,
      defaultPreviewStart: () => DateTime(2024),
      previewOverlapsScheduled: (_, __) => false,
      updateDragPreview: (_, __) {},
      stopEdgeAutoScroll: () {},
      updateDragFeedbackWidth: (_,
          {forceApply = false, forceCenterPointer = false}) {},
      clearDragPreview: () {},
      cancelPendingDragWidth: () {},
      resetDragFeedbackHint: () {},
      doesPreviewOverlap: () => false,
      onTaskDrop: (_, __) {},
      isWidthDebounceActive: () => false,
      isPreviewAnchor: (_) => false,
    );

    bool isPopoverOpen = false;
    late void Function(void Function()) triggerRebuild;

    const geometry = CalendarTaskGeometry(
      rect: Rect.fromLTWH(0, 0, 240, 72),
      narrowedWidth: 200,
      splitWidthFactor: 200 / 240,
    );

    CalendarTaskEntryBindings buildBindings() => CalendarTaskEntryBindings(
          isSelectionMode: false,
          isSelected: false,
          isPopoverOpen: isPopoverOpen,
          dragTargetKey: GlobalKey(),
          splitPreviewAnimationDuration: Duration.zero,
          contextMenuGroupId: const ValueKey<String>('calendar-menu'),
          contextMenuBuilderFactory: (_) =>
              (context, request) => const <Widget>[],
          interactionController: interactionController,
          dragFeedbackHint: interactionController.feedbackHint,
          callbacks: callbacks,
          updateBounds: (_) {},
          stepHeight: 16,
          minutesPerStep: 15,
          hourHeight: 48,
          schedulePopoverLayoutUpdate: () {},
          geometry: geometry,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              triggerRebuild = setState;
              return SizedBox(
                width: 240,
                height: 72,
                child: CalendarTaskSurface(
                  task: task,
                  isDayView: true,
                  bindings: buildBindings(),
                ),
              );
            },
          ),
        ),
      ),
    );

    final dynamic initialState = tester.state(find.byType(CalendarTaskSurface));
    final initialController = initialState.menuController;

    isPopoverOpen = true;
    triggerRebuild(() {});
    await tester.pump();

    final dynamic updatedState = tester.state(find.byType(CalendarTaskSurface));
    expect(updatedState.menuController, same(initialController));
  });
}
