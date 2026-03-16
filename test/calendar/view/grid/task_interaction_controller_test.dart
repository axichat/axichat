import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/grid/task_interaction_controller.dart';

void main() {
  test('Hover updates do not notify global listeners', () {
    final controller = TaskInteractionController();
    int notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    controller.setHoveringTask('task-1');
    expect(controller.hoveredTaskId.value, 'task-1');
    expect(notifications, 0);

    controller.clearHoveringTask('task-1');
    expect(controller.hoveredTaskId.value, isNull);
    expect(notifications, 0);

    controller.dispose();
  });

  test('Resize interaction seeds and clears shared interaction session', () {
    final controller = TaskInteractionController();
    const position = Offset(12, 24);

    controller.beginResizeInteraction(
      taskId: 'task-1',
      handle: 'bottom',
      globalPosition: position,
    );

    expect(controller.activeResizeInteraction?.taskId, 'task-1');
    expect(
      controller.activeInteractionSession?.kind,
      CalendarInteractionKind.resizeBottom,
    );
    expect(controller.activeInteractionSession?.globalPosition, position);

    controller.updateResizePointerGlobalPosition(const Offset(20, 40));
    controller.updateInteractionEdgeIntent(
      verticalIntent: CalendarInteractionVerticalIntent.down,
      horizontalIntent: CalendarInteractionHorizontalIntent.forward,
    );

    expect(
      controller.activeInteractionSession?.verticalIntent,
      CalendarInteractionVerticalIntent.down,
    );
    expect(
      controller.activeInteractionSession?.horizontalIntent,
      CalendarInteractionHorizontalIntent.forward,
    );

    controller.endResizeInteraction('task-1');

    expect(controller.activeResizeInteraction, isNull);
    expect(controller.activeInteractionSession, isNull);

    controller.dispose();
  });

  test('Task pointer classification stores and clears per pointer', () {
    final controller = TaskInteractionController();

    controller.beginTaskPointerClassification(
      taskId: 'task-1',
      pointerId: 7,
      target: CalendarTaskPointerTarget.resizeTop,
    );

    expect(
      controller.taskPointerClassification(taskId: 'task-1', pointerId: 7),
      CalendarTaskPointerTarget.resizeTop,
    );
    expect(
      controller.taskPointerClassification(taskId: 'task-1', pointerId: 8),
      isNull,
    );

    controller.clearTaskPointerClassification(taskId: 'task-1', pointerId: 7);

    expect(
      controller.taskPointerClassification(taskId: 'task-1', pointerId: 7),
      isNull,
    );

    controller.dispose();
  });

  test('Drag interaction seeds and clears shared interaction session', () {
    final controller = TaskInteractionController();
    final task = CalendarTask.create(
      title: 'Drag task',
      scheduledTime: DateTime(2024, 1, 1, 10),
      duration: const Duration(hours: 1),
    );

    controller.beginDrag(
      task: task,
      snapshot: task.copyWith(),
      bounds: const Rect.fromLTWH(20, 40, 120, 80),
      pointerNormalized: 0.5,
      pointerGlobalX: 80,
      originSlot: task.scheduledTime,
      pointerId: 7,
    );

    expect(
      controller.activeInteractionSession?.kind,
      CalendarInteractionKind.drag,
    );
    expect(
      controller.activeInteractionSession?.source,
      CalendarInteractionSource.taskSurface,
    );
    expect(
      controller.activeInteractionSession?.globalPosition,
      const Offset(80, 80),
    );
    expect(controller.activeDragPointerId, 7);

    controller.updateDragPointerGlobalPosition(const Offset(96, 112));

    expect(
      controller.activeInteractionSession?.globalPosition,
      const Offset(96, 112),
    );

    controller.endDrag();

    expect(controller.activeInteractionSession, isNull);
    expect(controller.activeDragPointerId, isNull);

    controller.dispose();
  });

  test(
    'Dragging task matching also respects base id across instance changes',
    () {
      final controller = TaskInteractionController();
      final task = CalendarTask.create(
        title: 'Drag task',
        scheduledTime: DateTime(2024, 1, 1, 10),
        duration: const Duration(hours: 1),
      );
      final CalendarTask rebuiltInstance = task.copyWith(
        id: '${task.id}::rebuilt',
      );

      controller.beginDrag(
        task: task,
        snapshot: task.copyWith(),
        bounds: const Rect.fromLTWH(20, 40, 120, 80),
        pointerNormalized: 0.5,
        pointerGlobalX: 80,
        originSlot: task.scheduledTime,
      );

      expect(controller.isDraggingTask(task), isTrue);
      expect(controller.isDraggingTask(rebuiltInstance), isTrue);

      controller.endDrag();
      controller.dispose();
    },
  );

  test('External drag interaction seeds external source in shared session', () {
    final controller = TaskInteractionController();
    final task = CalendarTask.create(
      title: 'External drag task',
      scheduledTime: DateTime(2024, 1, 1, 10),
      duration: const Duration(hours: 1),
    );

    controller.beginExternalDrag(
      task: task,
      snapshot: task.copyWith(),
      pointerOffset: const Offset(24, 36),
      feedbackSize: const Size(120, 80),
      globalPosition: const Offset(40, 60),
    );

    expect(
      controller.activeInteractionSession?.kind,
      CalendarInteractionKind.drag,
    );
    expect(
      controller.activeInteractionSession?.source,
      CalendarInteractionSource.external,
    );

    controller.dispose();
  });

  test('Drag start clears stale preview and drop hover', () {
    final controller = TaskInteractionController();
    final task = CalendarTask.create(
      title: 'Drag task',
      scheduledTime: DateTime(2024, 1, 1, 10),
      duration: const Duration(hours: 1),
    );

    controller.updatePreview(task.scheduledTime!, task.duration!);
    controller.setDropHoverTaskId('other-task');

    controller.beginDrag(
      task: task,
      snapshot: task.copyWith(),
      bounds: const Rect.fromLTWH(20, 40, 120, 80),
      pointerNormalized: 0.5,
      pointerGlobalX: 80,
      originSlot: task.scheduledTime,
    );

    expect(controller.preview.value, isNull);
    expect(controller.currentDropHoverTaskId, isNull);

    controller.dispose();
  });

  test(
    'Resize preview revisions increment only when preview state changes',
    () {
      final controller = TaskInteractionController();
      final task = CalendarTask.create(
        title: 'Resize task',
        scheduledTime: DateTime(2024, 1, 1, 10),
        duration: const Duration(hours: 1),
      );
      final CalendarTask preview = task.copyWith(
        duration: const Duration(hours: 2),
      );

      expect(controller.resizePreviewRevision.value, 0);

      controller.setResizePreview(task.id, preview);
      expect(controller.resizePreviewRevision.value, 1);

      controller.setResizePreview(task.id, preview);
      expect(controller.resizePreviewRevision.value, 1);

      controller.clearResizePreview(task.id);
      expect(controller.resizePreviewRevision.value, 2);

      controller.clearResizePreview(task.id);
      expect(controller.resizePreviewRevision.value, 2);

      controller.dispose();
    },
  );
}
