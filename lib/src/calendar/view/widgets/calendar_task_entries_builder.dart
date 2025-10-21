import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/calendar_task.dart';
import '../controllers/task_interaction_controller.dart';
import '../layout/calendar_layout.dart';
import '../resizable_task_widget.dart';
import 'calendar_task_surface.dart';

typedef CalendarTaskTileCallbacksFactory = CalendarTaskTileCallbacks Function(
  CalendarTask task,
);

typedef CalendarTaskContextMenuDelegate = TaskContextMenuBuilder Function(
  CalendarTask task,
  ShadPopoverController controller,
);

typedef TaskPopoverLayoutRequester = void Function(String taskId);

class CalendarTaskEntriesBuilder {
  CalendarTaskEntriesBuilder({
    required CalendarLayoutCalculator layoutCalculator,
    required CalendarLayoutMetrics layoutMetrics,
    required TaskInteractionController interactionController,
    required CalendarTaskTileCallbacksFactory callbacksFactory,
    required void Function(CalendarTask task) registerVisibleTask,
    required void Function(String taskId, Rect bounds) updateVisibleBounds,
    required bool isSelectionMode,
    required bool Function(CalendarTask task) isTaskSelected,
    required bool Function(String taskId) isPopoverOpen,
    required GlobalKey Function(String taskId) dragTargetKeyForTask,
    required TaskPopoverLayoutRequester requestPopoverLayoutUpdate,
    required CalendarTaskContextMenuDelegate contextMenuDelegate,
    required ValueKey<String> contextMenuGroupId,
    required Duration splitPreviewAnimationDuration,
    required double stepHeight,
    required int minutesPerStep,
    required double hourHeight,
    String? draggingTaskId,
  })  : _layoutCalculator = layoutCalculator,
        _layoutMetrics = layoutMetrics,
        _interactionController = interactionController,
        _callbacksFactory = callbacksFactory,
        _registerVisibleTask = registerVisibleTask,
        _updateVisibleBounds = updateVisibleBounds,
        _isSelectionMode = isSelectionMode,
        _isTaskSelected = isTaskSelected,
        _isPopoverOpen = isPopoverOpen,
        _dragTargetKeyForTask = dragTargetKeyForTask,
        _requestPopoverLayoutUpdate = requestPopoverLayoutUpdate,
        _contextMenuDelegate = contextMenuDelegate,
        _contextMenuGroupId = contextMenuGroupId,
        _splitPreviewAnimationDuration = splitPreviewAnimationDuration,
        _stepHeight = stepHeight,
        _minutesPerStep = minutesPerStep,
        _hourHeight = hourHeight,
        _draggingTaskId = draggingTaskId;

  final CalendarLayoutCalculator _layoutCalculator;
  final CalendarLayoutMetrics _layoutMetrics;
  final TaskInteractionController _interactionController;
  final CalendarTaskTileCallbacksFactory _callbacksFactory;
  final void Function(CalendarTask task) _registerVisibleTask;
  final void Function(String taskId, Rect bounds) _updateVisibleBounds;
  final bool _isSelectionMode;
  final bool Function(CalendarTask task) _isTaskSelected;
  final bool Function(String taskId) _isPopoverOpen;
  final GlobalKey Function(String taskId) _dragTargetKeyForTask;
  final TaskPopoverLayoutRequester _requestPopoverLayoutUpdate;
  final CalendarTaskContextMenuDelegate _contextMenuDelegate;
  final ValueKey<String> _contextMenuGroupId;
  final Duration _splitPreviewAnimationDuration;
  final double _stepHeight;
  final int _minutesPerStep;
  final double _hourHeight;
  final String? _draggingTaskId;

  List<Widget> build({
    required DateTime day,
    required double dayWidth,
    required bool isDayView,
    required int startHour,
    required int endHour,
    required Iterable<CalendarTask> tasks,
    required DateTime weekStartDate,
    required DateTime weekEndDate,
    required Set<String> visibleTaskIds,
  }) {
    final List<CalendarTask> taskList = tasks
        .where(
          (task) => task.scheduledTime != null,
        )
        .toList();
    if (taskList.isEmpty) {
      return const <Widget>[];
    }

    final Map<String, OverlapInfo> overlapMap =
        calculateOverlapColumns(taskList);
    final List<Widget> widgets = <Widget>[];

    for (final CalendarTask task in taskList) {
      _registerVisibleTask(task);
      visibleTaskIds.add(task.id);

      final bool isDraggingTask =
          _draggingTaskId != null && _draggingTaskId == task.id;
      if (isDraggingTask && _interactionController.dragHasMoved) {
        continue;
      }

      final OverlapInfo overlapInfo = overlapMap[task.id] ??
          const OverlapInfo(columnIndex: 0, totalColumns: 1);

      final CalendarTaskLayout? layout = _layoutCalculator.resolveTaskLayout(
        task: task,
        dayDate: day,
        weekStartDate: weekStartDate,
        weekEndDate: weekEndDate,
        isDayView: isDayView,
        startHour: startHour,
        endHour: endHour,
        dayWidth: dayWidth,
        metrics: _layoutMetrics,
        overlap: overlapInfo,
      );

      if (layout == null) {
        continue;
      }

      final double narrowedWidth =
          _layoutCalculator.computeNarrowedWidth(dayWidth, layout.width);
      final double splitWidthFactor = layout.width == 0
          ? 0.0
          : math.max(0.0, math.min(1.0, narrowedWidth / layout.width));

      final CalendarTaskEntryBindings bindings = CalendarTaskEntryBindings(
        isSelectionMode: _isSelectionMode,
        isSelected: _isTaskSelected(task),
        isPopoverOpen: _isPopoverOpen(task.id),
        dragTargetKey: _dragTargetKeyForTask(task.id),
        splitPreviewAnimationDuration: _splitPreviewAnimationDuration,
        contextMenuGroupId: _contextMenuGroupId,
        contextMenuBuilderFactory: (menuController) =>
            _contextMenuDelegate(task, menuController),
        interactionController: _interactionController,
        dragFeedbackHint: _interactionController.feedbackHint,
        callbacks: _callbacksFactory(task),
        updateBounds: (rect) => _updateVisibleBounds(task.id, rect),
        stepHeight: _stepHeight,
        minutesPerStep: _minutesPerStep,
        hourHeight: _hourHeight,
        schedulePopoverLayoutUpdate: () => _requestPopoverLayoutUpdate(task.id),
      );

      widgets.add(
        CalendarTaskSurface(
          key: ValueKey('calendar-task-${task.id}'),
          task: task,
          left: layout.left,
          top: layout.top,
          width: layout.width,
          height: layout.height,
          narrowedWidth: narrowedWidth,
          splitWidthFactor: splitWidthFactor,
          isDayView: isDayView,
          bindings: bindings,
        ),
      );
    }

    return widgets;
  }
}
