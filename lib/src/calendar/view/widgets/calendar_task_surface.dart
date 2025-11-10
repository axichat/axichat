import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../common/ui/ui.dart';
import '../../models/calendar_task.dart';
import '../controllers/task_interaction_controller.dart';
import '../resizable_task_widget.dart';
import 'calendar_task_geometry.dart';
import 'calendar_task_draggable.dart';

typedef CalendarTaskContextMenuBuilderFactory = TaskContextMenuBuilder?
    Function(
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
}

class CalendarTaskEntryBindings {
  CalendarTaskEntryBindings({
    required this.isSelectionMode,
    required this.isSelected,
    required this.isPopoverOpen,
    required this.splitPreviewAnimationDuration,
    required this.contextMenuGroupId,
    required this.contextMenuBuilderFactory,
    required this.enableContextMenuLongPress,
    required this.resizeHandleExtent,
    required this.interactionController,
    required this.dragFeedbackHint,
    required this.cancelBucketHoverNotifier,
    required this.callbacks,
    required this.geometryProvider,
    required this.globalRectProvider,
    required this.stepHeight,
    required this.minutesPerStep,
    required this.hourHeight,
    required this.addGeometryListener,
    required this.removeGeometryListener,
    required this.requiresLongPressToDrag,
    required this.longPressToDragDelay,
  });

  final bool isSelectionMode;
  final bool isSelected;
  final bool isPopoverOpen;
  final Duration splitPreviewAnimationDuration;
  final ValueKey<String> contextMenuGroupId;
  final CalendarTaskContextMenuBuilderFactory contextMenuBuilderFactory;
  final bool enableContextMenuLongPress;
  final double resizeHandleExtent;
  final TaskInteractionController interactionController;
  final ValueListenable<DragFeedbackHint> dragFeedbackHint;
  final ValueListenable<bool> cancelBucketHoverNotifier;
  final CalendarTaskTileCallbacks callbacks;
  final CalendarTaskGeometry? Function(String taskId) geometryProvider;
  final Rect? Function(String taskId) globalRectProvider;
  final double stepHeight;
  final int minutesPerStep;
  final double hourHeight;
  final void Function(VoidCallback listener) addGeometryListener;
  final void Function(VoidCallback listener) removeGeometryListener;
  final bool requiresLongPressToDrag;
  final Duration longPressToDragDelay;
}

class CalendarTaskSurface extends StatefulWidget {
  const CalendarTaskSurface({
    super.key,
    required this.task,
    required this.isDayView,
    required this.bindings,
  });

  final CalendarTask task;
  final bool isDayView;
  final CalendarTaskEntryBindings bindings;

  @override
  State<CalendarTaskSurface> createState() => _CalendarTaskSurfaceState();
}

class _CalendarTaskSurfaceState extends State<CalendarTaskSurface> {
  late final ShadPopoverController _menuController;
  TaskInteractionController? _attachedController;
  late final VoidCallback _controllerListener;
  String? _lastDraggingTaskId;
  late final VoidCallback _geometryListener;
  CalendarTaskEntryBindings? _geometryBindings;
  static const double _splitOverlayFallbackThreshold = 0.98;
  static const double _minSideBySideGhostWidth = 36.0;

  TaskInteractionController get _interactionController =>
      widget.bindings.interactionController;

  CalendarTaskTileCallbacks get _callbacks => widget.bindings.callbacks;

  @override
  void initState() {
    super.initState();
    _menuController = ShadPopoverController();
    _controllerListener = () {
      final String? nextId = _interactionController.draggingTaskId;
      if (_lastDraggingTaskId == nextId || !mounted) {
        return;
      }
      _lastDraggingTaskId = nextId;
      _scheduleRebuild();
    };
    _geometryListener = () {
      if (!mounted) {
        return;
      }
      final CalendarTaskGeometry geometry = _resolveGeometry();
      final double height = geometry.rect.height;
      if (height.isFinite && height > 0) {
        _interactionController.applyPendingPointerOffsetFraction(
          taskId: widget.task.id,
          height: height,
        );
      }
      _scheduleRebuild();
    };
    _attachController(widget.bindings.interactionController);
    _attachGeometryListener(widget.bindings);
  }

  @override
  void dispose() {
    _detachGeometryListener();
    _attachedController?.removeListener(_controllerListener);
    _menuController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CalendarTaskSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bindings.interactionController !=
        widget.bindings.interactionController) {
      _attachController(widget.bindings.interactionController);
    }
    if (!identical(oldWidget.bindings, widget.bindings)) {
      _attachGeometryListener(widget.bindings);
    }
  }

  @visibleForTesting
  ShadPopoverController get menuController => _menuController;

  CalendarTaskGeometry _resolveGeometry() =>
      widget.bindings.geometryProvider(widget.task.id) ??
      CalendarTaskGeometry.empty;

  void _attachController(TaskInteractionController controller) {
    if (_attachedController == controller) {
      return;
    }
    _attachedController?.removeListener(_controllerListener);
    _attachedController = controller;
    _lastDraggingTaskId = controller.draggingTaskId;
    controller.addListener(_controllerListener);
  }

  void _attachGeometryListener(CalendarTaskEntryBindings bindings) {
    if (identical(_geometryBindings, bindings)) {
      return;
    }
    _detachGeometryListener();
    _geometryBindings = bindings;
    bindings.addGeometryListener(_geometryListener);
  }

  void _detachGeometryListener() {
    final CalendarTaskEntryBindings? bindings = _geometryBindings;
    if (bindings == null) {
      return;
    }
    bindings.removeGeometryListener(_geometryListener);
    _geometryBindings = null;
  }

  void _scheduleRebuild() {
    if (!mounted) {
      return;
    }
    final SchedulerBinding scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.idle) {
      setState(() {});
      return;
    }
    scheduler.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final CalendarTask task = widget.task;
    final CalendarTaskEntryBindings bindings = widget.bindings;

    final TaskContextMenuBuilder? contextMenuBuilder =
        bindings.contextMenuBuilderFactory(_menuController);

    final CalendarTaskGeometry geometry = _resolveGeometry();
    if (geometry.rect.width <= 0 || geometry.rect.height <= 0) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<DragPreview?>(
      valueListenable: _interactionController.preview,
      builder: (context, preview, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: _interactionController.dropHoverTaskId,
          builder: (context, dropHoverTaskId, __) {
            final bool isDraggingTask =
                _interactionController.draggingTaskId != null &&
                    task.id == _interactionController.draggingTaskId;
            final bool isHoverTarget = dropHoverTaskId == task.id;
            final CalendarTask? previewTaskCandidate = _previewTaskCandidate(
              preview: preview,
              task: task,
              isHoverTarget: isHoverTarget,
            );
            final bool showSplitPreview = previewTaskCandidate != null;
            final bool allowNarrowing = _interactionController.dragHasMoved &&
                !_interactionController.isWidthDebounceActive;

            final double width = geometry.rect.width;
            final double height = geometry.rect.height;
            final double primaryWidth = showSplitPreview && allowNarrowing
                ? geometry.narrowedWidth
                : width;

            Widget buildBaseTask({required bool enableInteractions}) {
              final resizable = ResizableTaskWidget(
                key: ValueKey(task.id),
                interactionController: _interactionController,
                task: task,
                onResizePreview:
                    enableInteractions ? _callbacks.onResizePreview : null,
                onResizeEnd: enableInteractions ? _callbacks.onResizeEnd : null,
                onResizePointerMove:
                    enableInteractions ? _callbacks.onResizePointerMove : null,
                hourHeight: bindings.hourHeight,
                stepHeight: bindings.stepHeight,
                minutesPerStep: bindings.minutesPerStep,
                width: primaryWidth,
                height: height,
                isDayView: widget.isDayView,
                isPopoverOpen: bindings.isPopoverOpen,
                enableInteractions: enableInteractions,
                isSelectionMode: bindings.isSelectionMode,
                isSelected: bindings.isSelected,
                dragFeedbackHint: bindings.dragFeedbackHint,
                contextMenuController: _menuController,
                contextMenuGroupId: bindings.contextMenuGroupId,
                contextMenuBuilder: contextMenuBuilder,
                contextMenuLongPressEnabled:
                    bindings.enableContextMenuLongPress,
                resizeHandleExtent: bindings.resizeHandleExtent,
                onDragPointerDown:
                    enableInteractions ? _callbacks.onDragPointerDown : null,
                onToggleSelection: enableInteractions
                    ? () {
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
                      }
                    : null,
                onTap: enableInteractions ? _callbacks.onTap : null,
              );
              return CalendarTaskDraggable(
                task: task,
                geometry: geometry,
                globalRectProvider: bindings.globalRectProvider,
                interactionController: _interactionController,
                onDragStarted: _callbacks.onDragStarted,
                onDragUpdate: _callbacks.onDragUpdate,
                onDragEnded: _callbacks.onDragEnded,
                snapshotBuilder: () => task.copyWith(),
                feedbackBuilder: (context, dragTask, dragGeometry) =>
                    _buildDragFeedback(
                  context: context,
                  task: dragTask,
                  geometry: dragGeometry,
                  bindings: bindings,
                  baseHeight: height,
                ),
                enabled: enableInteractions,
                childWhenDragging: const SizedBox.shrink(),
                child: resizable,
                requiresLongPress: bindings.requiresLongPressToDrag,
                longPressDelay: bindings.longPressToDragDelay,
              );
            }

            Widget baseTask = buildBaseTask(
              enableInteractions: !isDraggingTask,
            );
            if (isDraggingTask) {
              baseTask = Opacity(
                opacity: 0.0,
                child: baseTask,
              );
            }

            if (previewTaskCandidate != null && !isDraggingTask) {
              final double occupantWidth =
                  math.min(primaryWidth, geometry.rect.width);
              final double ghostWidth =
                  math.max(geometry.rect.width - occupantWidth, 0.0);
              final bool widthAllowsSplit =
                  ghostWidth >= _minSideBySideGhostWidth &&
                      occupantWidth >= _minSideBySideGhostWidth;
              final bool useSideBySide = widthAllowsSplit &&
                  geometry.splitWidthFactor < _splitOverlayFallbackThreshold;

              final Widget previewGhost = _buildPreviewGhost(
                previewTaskCandidate: previewTaskCandidate,
                bindings: bindings,
                height: height,
                width: useSideBySide ? ghostWidth : width,
                keySuffix: '-preview',
              );

              if (useSideBySide) {
                final Widget occupant = SizedBox(
                  width: occupantWidth,
                  child: baseTask,
                );
                final Widget ghost = SizedBox(
                  width: ghostWidth,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: calendarSplitPreviewGhostOpacity,
                      child: previewGhost,
                    ),
                  ),
                );

                baseTask = SizedBox.expand(
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        width: occupantWidth,
                        child: occupant,
                      ),
                      Positioned(
                        right: 0,
                        width: ghostWidth,
                        child: ghost,
                      ),
                    ],
                  ),
                );
              } else {
                baseTask = Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: calendarSplitPreviewBaseFadeOpacity,
                        child: baseTask,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: calendarSplitPreviewGhostOpacity,
                          child: previewGhost,
                        ),
                      ),
                    ),
                  ],
                );
              }
            }

            final bool paintSplitBorder = showSplitPreview && !isDraggingTask;

            return AnimatedContainer(
              duration: bindings.splitPreviewAnimationDuration,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(calendarEventRadius),
                border: paintSplitBorder
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
        );
      },
    );
  }

  CalendarTask? _previewTaskCandidate({
    required DragPreview? preview,
    required CalendarTask task,
    required bool isHoverTarget,
  }) {
    final CalendarTask? dragging = _interactionController.draggingTaskSnapshot;
    if (dragging == null) {
      return null;
    }
    if (dragging.id == task.id) {
      return null;
    }
    if (isHoverTarget) {
      return dragging;
    }
    if (preview == null) {
      return null;
    }
    return _previewIntersectsTask(preview, task) ? dragging : null;
  }

  Widget _buildPreviewGhost({
    required CalendarTask previewTaskCandidate,
    required CalendarTaskEntryBindings bindings,
    required double width,
    required double height,
    required String keySuffix,
  }) {
    return ResizableTaskWidget(
      key: ValueKey('${previewTaskCandidate.id}$keySuffix'),
      interactionController: _interactionController,
      task: previewTaskCandidate,
      onResizePreview: null,
      onResizeEnd: null,
      hourHeight: bindings.hourHeight,
      stepHeight: bindings.stepHeight,
      minutesPerStep: bindings.minutesPerStep,
      width: width,
      height: height,
      isDayView: widget.isDayView,
      enableInteractions: false,
      isSelectionMode: false,
      isSelected: false,
    );
  }

  bool _previewIntersectsTask(DragPreview preview, CalendarTask task) {
    final DateTime? taskStart = task.scheduledTime;
    if (taskStart == null) {
      return false;
    }
    final Duration duration = task.duration ?? const Duration(hours: 1);
    final DateTime taskEnd = taskStart.add(duration);
    final DateTime previewEnd = preview.start.add(preview.duration);
    return preview.start.isBefore(taskEnd) && previewEnd.isAfter(taskStart);
  }

  Widget _buildDragFeedback({
    required BuildContext context,
    required CalendarTask task,
    required CalendarTaskGeometry geometry,
    required CalendarTaskEntryBindings bindings,
    required double baseHeight,
  }) {
    final double width = geometry.rect.width;
    final double height = geometry.rect.height;
    final Widget feedback = Material(
      color: Colors.transparent,
      child: ResizableTaskWidget(
        key: ValueKey('${task.id}-drag-feedback'),
        interactionController: _interactionController,
        task: task,
        hourHeight: bindings.hourHeight,
        stepHeight: bindings.stepHeight,
        minutesPerStep: bindings.minutesPerStep,
        width: width,
        height: height > 0 ? height : baseHeight,
        isDayView: widget.isDayView,
        enableInteractions: false,
        isSelectionMode: false,
        isSelected: false,
      ),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: bindings.cancelBucketHoverNotifier,
      builder: (context, hovering, child) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: hovering ? 0.45 : 1.0,
          child: child,
        );
      },
      child: feedback,
    );
  }
}
