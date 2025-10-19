import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../common/ui/ui.dart';
import '../../models/calendar_task.dart';
import '../controllers/task_interaction_controller.dart';
import '../resizable_task_widget.dart';

typedef CalendarTaskContextMenuBuilderFactory = TaskContextMenuBuilder Function(
  ShadPopoverController controller,
);

class CalendarTaskTileCallbacks {
  const CalendarTaskTileCallbacks({
    required this.onResizePreview,
    required this.onResizeEnd,
    required this.onResizePointerMove,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnded,
    required this.onDragPointerDown,
    required this.onEnterSelectionMode,
    required this.onToggleSelection,
    required this.onTap,
    required this.computePreviewStartForHover,
    required this.defaultPreviewStart,
    required this.previewOverlapsScheduled,
    required this.updateDragPreview,
    required this.stopEdgeAutoScroll,
    required this.updateDragFeedbackWidth,
    required this.clearDragPreview,
    required this.cancelPendingDragWidth,
    required this.resetDragFeedbackHint,
    required this.doesPreviewOverlap,
    required this.onTaskDrop,
    required this.isWidthDebounceActive,
    required this.isPreviewAnchor,
  });

  final ValueChanged<CalendarTask> onResizePreview;
  final ValueChanged<CalendarTask> onResizeEnd;
  final ValueChanged<Offset> onResizePointerMove;
  final void Function(CalendarTask task, Rect bounds) onDragStarted;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<CalendarTask> onDragEnded;
  final ValueChanged<Offset> onDragPointerDown;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onToggleSelection;
  final void Function(CalendarTask task, Rect globalBounds)? onTap;
  final DateTime? Function(Offset offset) computePreviewStartForHover;
  final DateTime Function() defaultPreviewStart;
  final bool Function(DateTime start, Duration duration)
      previewOverlapsScheduled;
  final void Function(DateTime previewStart, Duration previewDuration)
      updateDragPreview;
  final VoidCallback stopEdgeAutoScroll;
  final void Function(
    double width, {
    bool forceApply,
    bool forceCenterPointer,
  }) updateDragFeedbackWidth;
  final VoidCallback clearDragPreview;
  final VoidCallback cancelPendingDragWidth;
  final VoidCallback resetDragFeedbackHint;
  final bool Function() doesPreviewOverlap;
  final void Function(CalendarTask task, DateTime dropTime) onTaskDrop;
  final bool Function() isWidthDebounceActive;
  final bool Function(DateTime anchor) isPreviewAnchor;
}

class CalendarTaskEntryBindings {
  const CalendarTaskEntryBindings({
    required this.isSelectionMode,
    required this.isSelected,
    required this.isPopoverOpen,
    required this.dragTargetKey,
    required this.splitPreviewAnimationDuration,
    required this.contextMenuGroupId,
    required this.contextMenuBuilderFactory,
    required this.interactionController,
    required this.dragFeedbackHint,
    required this.callbacks,
    required this.updateBounds,
    required this.stepHeight,
    required this.minutesPerStep,
    required this.hourHeight,
    required this.schedulePopoverLayoutUpdate,
  });

  final bool isSelectionMode;
  final bool isSelected;
  final bool isPopoverOpen;
  final GlobalKey dragTargetKey;
  final Duration splitPreviewAnimationDuration;
  final ValueKey<String> contextMenuGroupId;
  final CalendarTaskContextMenuBuilderFactory contextMenuBuilderFactory;
  final TaskInteractionController interactionController;
  final ValueListenable<DragFeedbackHint> dragFeedbackHint;
  final CalendarTaskTileCallbacks callbacks;
  final void Function(Rect bounds) updateBounds;
  final double stepHeight;
  final int minutesPerStep;
  final double hourHeight;
  final VoidCallback schedulePopoverLayoutUpdate;
}

class CalendarTaskSurface extends StatelessWidget {
  const CalendarTaskSurface({
    super.key,
    required this.task,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.isDayView,
    required this.bindings,
    required this.narrowedWidth,
    required this.splitWidthFactor,
  });

  final CalendarTask task;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool isDayView;
  final CalendarTaskEntryBindings bindings;
  final double narrowedWidth;
  final double splitWidthFactor;

  TaskInteractionController get _interactionController =>
      bindings.interactionController;

  CalendarTaskTileCallbacks get _callbacks => bindings.callbacks;

  @override
  Widget build(BuildContext context) {
    if (bindings.isPopoverOpen) {
      bindings.schedulePopoverLayoutUpdate();
    }

    final ShadPopoverController menuController = ShadPopoverController();
    final TaskContextMenuBuilder contextMenuBuilder =
        bindings.contextMenuBuilderFactory(menuController);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: DragTarget<CalendarTask>(
        key: bindings.dragTargetKey,
        hitTestBehavior: HitTestBehavior.opaque,
        onWillAcceptWithDetails: (details) {
          final CalendarTask dragged = details.data;
          if (dragged.id == task.id) {
            return false;
          }
          final DateTime previewStart =
              _callbacks.computePreviewStartForHover(details.offset) ??
                  _callbacks.defaultPreviewStart();
          final Duration previewDuration =
              dragged.duration ?? const Duration(hours: 1);
          final bool hasOverlap = _callbacks.previewOverlapsScheduled(
            previewStart,
            previewDuration,
          );
          final bool allowNarrowing = hasOverlap ||
              (_interactionController.dragHasMoved &&
                  !_callbacks.isWidthDebounceActive());
          _callbacks.updateDragPreview(previewStart, previewDuration);
          _callbacks.stopEdgeAutoScroll();
          final double targetWidth =
              allowNarrowing && hasOverlap ? narrowedWidth : width;
          _callbacks.updateDragFeedbackWidth(
            targetWidth,
            forceApply: !hasOverlap,
            forceCenterPointer: false,
          );
          return true;
        },
        onMove: (details) {
          final DateTime previewStart =
              _callbacks.computePreviewStartForHover(details.offset) ??
                  _callbacks.defaultPreviewStart();
          final Duration previewDuration =
              details.data.duration ?? const Duration(hours: 1);
          final bool hasOverlap = _callbacks.previewOverlapsScheduled(
            previewStart,
            previewDuration,
          );
          final bool allowNarrowing = _interactionController.dragHasMoved &&
              !_callbacks.isWidthDebounceActive();
          final double targetWidth =
              allowNarrowing && hasOverlap ? narrowedWidth : width;
          _callbacks.updateDragFeedbackWidth(
            targetWidth,
            forceApply: !hasOverlap,
            forceCenterPointer: false,
          );
          _callbacks.updateDragPreview(previewStart, previewDuration);
        },
        onLeave: (details) {
          final DateTime? anchor = task.scheduledTime;
          if (anchor != null && _callbacks.isPreviewAnchor(anchor)) {
            _callbacks.clearDragPreview();
          }
          _callbacks.stopEdgeAutoScroll();
          _callbacks.cancelPendingDragWidth();
        },
        onAcceptWithDetails: (details) {
          _callbacks.clearDragPreview();
          _callbacks.stopEdgeAutoScroll();
          _callbacks.cancelPendingDragWidth();
          _callbacks.resetDragFeedbackHint();
          final DateTime dropTime =
              _callbacks.computePreviewStartForHover(details.offset) ??
                  _callbacks.defaultPreviewStart();
          _callbacks.onTaskDrop(details.data, dropTime);
        },
        builder: (context, candidateData, rejectedData) {
          final bool isDraggingTask =
              _interactionController.draggingTaskId != null &&
                  task.id == _interactionController.draggingTaskId;
          final bool previewOverlap = _callbacks.doesPreviewOverlap();
          final CalendarTask? previewTaskCandidate = candidateData.isNotEmpty
              ? candidateData.first
              : (previewOverlap
                  ? _interactionController.draggingTaskSnapshot
                  : null);
          final bool showSplitPreview = previewTaskCandidate != null;
          final bool allowNarrowing = _interactionController.dragHasMoved &&
              !_callbacks.isWidthDebounceActive();
          if (showSplitPreview && !allowNarrowing) {
            _callbacks.updateDragFeedbackWidth(
              width,
              forceApply: false,
              forceCenterPointer: false,
            );
          }
          if (isDraggingTask && !showSplitPreview) {
            _callbacks.cancelPendingDragWidth();
            _callbacks.resetDragFeedbackHint();
          }

          final double primaryWidth =
              showSplitPreview && allowNarrowing ? narrowedWidth : width;
          bindings.updateBounds(Rect.fromLTWH(left, top, primaryWidth, height));

          Widget baseTask = ResizableTaskWidget(
            key: ValueKey(task.id),
            interactionController: _interactionController,
            task: task,
            onResizePreview: _callbacks.onResizePreview,
            onResizeEnd: _callbacks.onResizeEnd,
            onResizePointerMove: _callbacks.onResizePointerMove,
            hourHeight: bindings.hourHeight,
            stepHeight: bindings.stepHeight,
            minutesPerStep: bindings.minutesPerStep,
            width: primaryWidth,
            height: height,
            isDayView: isDayView,
            isPopoverOpen: bindings.isPopoverOpen,
            enableInteractions: true,
            isSelectionMode: bindings.isSelectionMode,
            isSelected: bindings.isSelected,
            dragFeedbackHint: bindings.dragFeedbackHint,
            contextMenuController: menuController,
            contextMenuGroupId: bindings.contextMenuGroupId,
            contextMenuBuilder: contextMenuBuilder,
            onDragPointerDown: _callbacks.onDragPointerDown,
            onToggleSelection: () {
              if (bindings.isSelectionMode &&
                  bindings.isSelected &&
                  _interactionController.draggingTaskId == task.id) {
                _callbacks.onDragEnded(task);
              }
              if (bindings.isSelectionMode) {
                _callbacks.onToggleSelection();
              } else {
                _callbacks.onEnterSelectionMode();
              }
            },
            onDragStarted: _callbacks.onDragStarted,
            onDragUpdate: _callbacks.onDragUpdate,
            onDragEnded: _callbacks.onDragEnded,
            onTap: _callbacks.onTap,
          );

          if (previewTaskCandidate != null) {
            final CalendarTask previewTask = previewTaskCandidate;
            baseTask = SizedBox.expand(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: splitWidthFactor,
                      alignment: Alignment.centerLeft,
                      child: baseTask,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: splitWidthFactor,
                      alignment: Alignment.centerRight,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: calendarSplitPreviewGhostOpacity,
                          child: ResizableTaskWidget(
                            key: ValueKey('${task.id}-preview'),
                            interactionController: _interactionController,
                            task: previewTask,
                            onResizePreview: null,
                            onResizeEnd: null,
                            hourHeight: bindings.hourHeight,
                            stepHeight: bindings.stepHeight,
                            minutesPerStep: bindings.minutesPerStep,
                            width: narrowedWidth,
                            height: height,
                            isDayView: isDayView,
                            enableInteractions: false,
                            isSelectionMode: false,
                            isSelected: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return AnimatedContainer(
            duration: bindings.splitPreviewAnimationDuration,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(calendarEventRadius),
              border: showSplitPreview
                  ? Border.all(
                      color: calendarPrimaryColor.withValues(
                        alpha: calendarSplitPreviewBorderOpacity,
                      ),
                      width: calendarBorderStroke * 2,
                    )
                  : null,
            ),
            child: baseTask,
          );
        },
      ),
    );
  }
}
