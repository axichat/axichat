import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/calendar_task.dart';
import 'controllers/task_interaction_controller.dart';

class DragFeedbackHint {
  const DragFeedbackHint({
    required this.width,
    required this.pointerOffset,
    required this.anchorDx,
    required this.anchorDy,
  });

  final double width;
  final double pointerOffset;
  final double anchorDx;
  final double anchorDy;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DragFeedbackHint &&
        (width - other.width).abs() < 1e-6 &&
        (pointerOffset - other.pointerOffset).abs() < 1e-3 &&
        (anchorDx - other.anchorDx).abs() < 1e-3 &&
        (anchorDy - other.anchorDy).abs() < 1e-3;
  }

  @override
  int get hashCode => Object.hash(width, pointerOffset, anchorDx, anchorDy);
}

typedef TaskContextMenuBuilder = List<Widget> Function(
  BuildContext context,
  TaskContextMenuRequest request,
);

class TaskContextMenuRequest {
  const TaskContextMenuRequest({
    required this.task,
    required this.localPosition,
    required this.normalizedPosition,
    required this.splitTime,
  });

  final CalendarTask task;
  final Offset localPosition;
  final Offset normalizedPosition;
  final DateTime? splitTime;
}

class ResizableTaskWidget extends StatefulWidget {
  static bool debugAlwaysShowHandles = false;
  static bool debugLogContextMenu = false;

  final CalendarTask task;
  final ValueChanged<CalendarTask>? onResizePreview;
  final ValueChanged<CalendarTask>? onResizeEnd;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final double hourHeight;
  final double stepHeight;
  final int minutesPerStep;
  final double width;
  final double height;
  final bool isDayView;
  final bool isPopoverOpen;
  final TaskInteractionController interactionController;
  final void Function(CalendarTask task, Rect globalBounds)? onTap;
  final void Function(CalendarTask task, Rect globalBounds)? onDragStarted;
  final ValueChanged<CalendarTask>? onDragEnded;
  final bool enableInteractions;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelection;
  final ValueListenable<DragFeedbackHint>? dragFeedbackHint;
  final ValueChanged<Offset>? onDragPointerDown;
  final ShadPopoverController? contextMenuController;
  final ValueKey<String>? contextMenuGroupId;
  final TaskContextMenuBuilder? contextMenuBuilder;
  final ValueChanged<Offset>? onResizePointerMove;

  const ResizableTaskWidget({
    super.key,
    required this.interactionController,
    required this.task,
    this.onResizePreview,
    this.onResizeEnd,
    this.onDragUpdate,
    required this.hourHeight,
    required this.stepHeight,
    required this.minutesPerStep,
    required this.width,
    required this.height,
    required this.isDayView,
    this.isPopoverOpen = false,
    this.onTap,
    this.onDragStarted,
    this.onDragEnded,
    this.enableInteractions = true,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
    this.dragFeedbackHint,
    this.onDragPointerDown,
    this.contextMenuController,
    this.contextMenuGroupId,
    this.contextMenuBuilder,
    this.onResizePointerMove,
  });

  @override
  State<ResizableTaskWidget> createState() => _ResizableTaskWidgetState();
}

class _ResizableTaskWidgetState extends State<ResizableTaskWidget> {
  double _totalDragDeltaY = 0;
  int _lastAppliedQuarterDelta = 0;
  Offset _contextMenuLocalPosition = Offset.zero;
  Offset _contextMenuNormalizedPosition = const Offset(0.5, 0.5);
  DateTime? _contextMenuSplitTime;
  int _lastPointerButtons = 0;
  bool _lastPointerWasSecondary = false;
  Offset? _contextMenuGlobalPosition;

  static const double _accentWidth = 4.0;
  static const double _accentPadding = 6.0;

  late double _currentStartHour;
  late double _currentDurationHours;
  DateTime? _tempScheduledTime;
  Duration? _tempDuration;

  void _debugLog(
    String stage, {
    Offset? local,
    Offset? normalized,
    Offset? global,
    String? extra,
  }) {
    if (!ResizableTaskWidget.debugLogContextMenu || !kDebugMode) {
      return;
    }
    final Offset localValue = local ?? _contextMenuLocalPosition;
    final Offset normalizedValue = normalized ?? _contextMenuNormalizedPosition;
    final Offset? globalValue = global ?? _contextMenuGlobalPosition;
    debugPrint(
      'ContextMenu[$stage] task=${widget.task.id} '
      'local=$localValue normalized=$normalizedValue global=$globalValue '
      'buttons=$_lastPointerButtons secondary=$_lastPointerWasSecondary'
      '${extra != null ? ' $extra' : ''}',
    );
  }

  CalendarTask? _buildUpdatedTask() {
    final DateTime? scheduled = _tempScheduledTime ?? widget.task.scheduledTime;
    final Duration? duration = _tempDuration ?? widget.task.duration;
    DateTime? endDate = widget.task.endDate;

    if (scheduled != null && duration != null) {
      endDate = scheduled.add(duration);
    } else if (duration != null && widget.task.scheduledTime != null) {
      endDate = widget.task.scheduledTime!.add(duration);
    }

    if (scheduled == widget.task.scheduledTime &&
        duration == widget.task.duration &&
        endDate == widget.task.endDate) {
      return null;
    }

    return widget.task.copyWith(
      scheduledTime: scheduled,
      duration: duration,
      endDate: endDate,
      startHour: _computeStartHour(scheduled),
    );
  }

  Color get _taskColor => widget.task.priorityColor;

  Offset _normalizedFromLocal(Offset local) {
    final double width = widget.width;
    final double height = widget.height;
    final double normalizedX =
        width <= 0 ? 0.5 : (local.dx / width).clamp(0.0, 1.0);
    final double normalizedY =
        height <= 0 ? 0.0 : (local.dy / height).clamp(0.0, 1.0);
    return Offset(normalizedX, normalizedY);
  }

  void _updateContextMenuState({
    required Offset localPosition,
    required Offset normalizedPosition,
    Offset? globalPosition,
  }) {
    final DateTime? nextSplit = widget.task.splitTimeForFraction(
      fraction: normalizedPosition.dy,
      minutesPerStep: widget.minutesPerStep,
    );
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final Offset resolvedGlobal = globalPosition ??
        renderBox?.localToGlobal(localPosition) ??
        _contextMenuGlobalPosition ??
        Offset.zero;
    if (_contextMenuLocalPosition == localPosition &&
        _contextMenuNormalizedPosition == normalizedPosition &&
        _contextMenuSplitTime == nextSplit &&
        _contextMenuGlobalPosition == resolvedGlobal) {
      return;
    }
    String? extra;
    if (ResizableTaskWidget.debugLogContextMenu && kDebugMode) {
      final NavigatorState? rootNavigator =
          Navigator.maybeOf(context, rootNavigator: true);
      final NavigatorState? shellNavigator = Navigator.maybeOf(context);
      final RenderBox? rootOverlayBox =
          rootNavigator?.overlay?.context.findRenderObject() as RenderBox?;
      final RenderBox? shellOverlayBox =
          shellNavigator?.overlay?.context.findRenderObject() as RenderBox?;
      final Offset? rootOrigin = rootOverlayBox?.localToGlobal(Offset.zero);
      final Offset? shellOrigin = shellOverlayBox?.localToGlobal(Offset.zero);
      extra = 'shellOrigin=$shellOrigin rootOrigin=$rootOrigin';
    }

    setState(() {
      _contextMenuLocalPosition = localPosition;
      _contextMenuNormalizedPosition = normalizedPosition;
      _contextMenuSplitTime = nextSplit;
      _contextMenuGlobalPosition = resolvedGlobal;
    });
    _debugLog(
      'updateContextMenuState',
      local: localPosition,
      normalized: normalizedPosition,
      global: resolvedGlobal,
      extra: extra,
    );
  }

  void _captureContextMenuOffsets({
    required Offset localPosition,
    required Offset normalizedPosition,
    Offset? globalPosition,
  }) {
    if (widget.contextMenuBuilder == null ||
        widget.contextMenuController == null ||
        widget.contextMenuGroupId == null) {
      return;
    }
    _updateContextMenuState(
      localPosition: localPosition,
      normalizedPosition: normalizedPosition,
      globalPosition: globalPosition,
    );
  }

  Widget _wrapWithContextMenu(Widget child) {
    final TaskContextMenuBuilder? builder = widget.contextMenuBuilder;
    final ShadPopoverController? controller = widget.contextMenuController;
    final ValueKey<String>? groupId = widget.contextMenuGroupId;
    if (builder == null || controller == null || groupId == null) {
      return child;
    }

    final items = builder(
      context,
      TaskContextMenuRequest(
        task: widget.task,
        localPosition: _contextMenuLocalPosition,
        normalizedPosition: _contextMenuNormalizedPosition,
        splitTime: _contextMenuSplitTime,
      ),
    );

    return ShadContextMenuRegion(
      controller: controller,
      groupId: groupId,
      longPressEnabled: true,
      items: items,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.interactionController,
      builder: (context, _) {
        final task = widget.task;
        final taskColor = _taskColor;
        final TaskInteractionController controller =
            widget.interactionController;
        final bool isDragging = controller.draggingTaskId == task.id;
        final bool isHovering = controller.currentHoveredTaskId == task.id;
        final TaskResizeInteraction? resizeSession =
            controller.activeResizeInteraction;
        final bool isResizing =
            resizeSession != null && resizeSession.taskId == task.id;
        final String? activeHandle = isResizing ? resizeSession.handle : null;

        Widget buildFeedbackContent(DragFeedbackHint hint) {
          final bool isCompleted = task.isCompleted;
          final Color accentColor = taskColor;
          final double blendAlpha = isCompleted ? 0.08 : 0.18;
          final Color backgroundColor = Color.alphaBlend(
            accentColor.withValues(alpha: blendAlpha),
            calendarContainerColor,
          );
          final Color borderColor =
              accentColor.withValues(alpha: isCompleted ? 0.4 : 0.5);
          final Color stripeColor =
              accentColor.withValues(alpha: isCompleted ? 0.5 : 0.9);

          final double fallbackWidth = widget.width;
          final double effectiveWidth = hint.width.isFinite && hint.width > 0
              ? hint.width
              : fallbackWidth;
          final double anchorX = hint.anchorDx.clamp(0.0, effectiveWidth);
          final double translationX = anchorX - (effectiveWidth / 2);

          return Transform.translate(
            offset: Offset(-translationX, 0),
            child: Material(
              elevation: 8,
              color: Colors.transparent,
              child: Container(
                width: effectiveWidth,
                height: widget.height,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor, width: 1.2),
                  boxShadow: calendarMediumShadow,
                ),
                child: Stack(
                  children: [
                    _buildAccentStripe(stripeColor),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _accentWidth + _accentPadding,
                        8,
                        8,
                        8,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          task.title,
                          style: taskTitleTextStyle.copyWith(
                            color: calendarTitleColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        Widget buildFeedback() {
          final ValueListenable<DragFeedbackHint>? listenable =
              widget.dragFeedbackHint;
          if (listenable == null) {
            return buildFeedbackContent(
              DragFeedbackHint(
                width: widget.width,
                pointerOffset: widget.width / 2,
                anchorDx: widget.width / 2,
                anchorDy: widget.height / 2,
              ),
            );
          }
          return ValueListenableBuilder<DragFeedbackHint>(
            valueListenable: listenable,
            builder: (context, state, child) {
              return buildFeedbackContent(state);
            },
          );
        }

        Widget buildTaskBody() {
          final bool showHoverEffects = widget.enableInteractions &&
              (widget.isPopoverOpen || isHovering || isResizing || isDragging);
          final bool selectionMode = widget.isSelectionMode;
          final bool highlightSelection = selectionMode && widget.isSelected;
          final bool isCompleted = task.isCompleted;
          final Color accentColor = taskColor;
          final double baseBlendAlpha = isCompleted ? 0.06 : 0.12;
          final double activeBlendAlpha = isCompleted ? 0.1 : 0.18;
          final double selectionBlendAlpha = highlightSelection
              ? (isCompleted ? 0.18 : 0.26)
              : (showHoverEffects ? activeBlendAlpha : baseBlendAlpha);
          final Color backgroundColor = Color.alphaBlend(
            accentColor.withValues(alpha: selectionBlendAlpha),
            calendarContainerColor,
          );
          final Color borderColor = highlightSelection
              ? accentColor
              : showHoverEffects
                  ? accentColor.withValues(alpha: 0.45)
                  : Color.lerp(calendarBorderColor, accentColor, 0.18)!;
          final List<BoxShadow> boxShadows = highlightSelection
              ? calendarMediumShadow
              : showHoverEffects
                  ? calendarLightShadow
                  : const [];
          final Color titleColor =
              isCompleted ? calendarSubtitleColor : calendarTitleColor;
          const Color secondaryColor = calendarSubtitleColor;
          final Color stripeColor = highlightSelection
              ? accentColor
              : accentColor.withValues(alpha: isCompleted ? 0.5 : 0.9);

          final decoration = BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor,
              width: highlightSelection
                  ? 2.4
                  : isResizing
                      ? 1.8
                      : 1,
            ),
            boxShadow: boxShadows,
          );

          final double availableHeight =
              (widget.height - 4).clamp(0.0, double.infinity);
          final bool showHandles =
              (ResizableTaskWidget.debugAlwaysShowHandles ||
                      showHoverEffects) &&
                  !task.isCompleted &&
                  availableHeight >= 14;

          if (availableHeight <= 6) {
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: decoration,
              child: Stack(
                children: [
                  _buildAccentStripe(stripeColor),
                  if (showHandles)
                    ..._buildResizeHandles(
                        stripeColor, isResizing, activeHandle),
                ],
              ),
            );
          }

          double padding;
          if (availableHeight >= 96) {
            padding = 8;
          } else if (availableHeight >= 72) {
            padding = 6;
          } else if (availableHeight >= 48) {
            padding = 4;
          } else {
            padding = 2;
          }

          final double innerHeight =
              (availableHeight - padding * 2).clamp(0.0, double.infinity);

          if (innerHeight <= 10) {
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: decoration,
              child: Stack(
                children: [
                  _buildAccentStripe(stripeColor),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      padding + _accentWidth + _accentPadding,
                      padding,
                      padding,
                      padding,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (showHandles)
                    ..._buildResizeHandles(
                        stripeColor, isResizing, activeHandle),
                ],
              ),
            );
          }

          final bool stackedTime = innerHeight >= 36;
          final bool inlineTime =
              !stackedTime && innerHeight >= 16 && widget.width >= 140;
          final bool showTime = stackedTime || inlineTime;
          final bool showDescription =
              task.description?.isNotEmpty == true && innerHeight >= 56;

          final double spacing = innerHeight >= 90
              ? 6
              : innerHeight >= 64
                  ? 4
                  : innerHeight >= 40
                      ? 2
                      : 0;

          final int titleLines = innerHeight >= 48 ? 2 : 1;
          final int descriptionLines = showDescription
              ? math.max(1, (innerHeight / 18).floor() - (stackedTime ? 1 : 0))
              : 0;
          final TextOverflow descriptionOverflow =
              descriptionLines >= 4 ? TextOverflow.fade : TextOverflow.ellipsis;

          Widget buildTitle() {
            final title = Text(
              task.title,
              maxLines: titleLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            );

            if (showTime && inlineTime) {
              final timeText = _formatTimeRange();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: calendarInsetLg),
                  Flexible(
                    child: Text(
                      timeText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: secondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
              ],
            );
          }

          final children = <Widget>[buildTitle()];

          if (showTime && !inlineTime) {
            if (spacing > 0) {
              children.add(SizedBox(height: spacing));
            }
            children.add(
              Text(
                _formatTimeRange(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: secondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }

          if (showDescription) {
            if (spacing > 0) {
              children.add(SizedBox(height: spacing));
            }
            children.add(
              Text(
                task.description!,
                maxLines: descriptionLines,
                overflow: descriptionOverflow,
                softWrap: true,
                style: const TextStyle(
                  color: secondaryColor,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.all(2),
            decoration: decoration,
            child: Stack(
              children: [
                _buildAccentStripe(stripeColor),
                ClipRect(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      padding + _accentWidth + _accentPadding,
                      padding,
                      padding,
                      padding,
                    ),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: children,
                      ),
                    ),
                  ),
                ),
                if (showHandles)
                  ..._buildResizeHandles(stripeColor, isResizing, activeHandle),
              ],
            ),
          );
        }

        Widget buildInteractiveContent() {
          return IgnorePointer(
            ignoring: isDragging,
            child: MouseRegion(
              onEnter: (_) {
                if (!widget.isPopoverOpen && widget.enableInteractions) {
                  widget.interactionController.setHoveringTask(task.id);
                }
              },
              onExit: (_) {
                if (!widget.isPopoverOpen && widget.enableInteractions) {
                  widget.interactionController.clearHoveringTask(task.id);
                }
              },
              cursor: widget.enableInteractions && isResizing
                  ? SystemMouseCursors.resizeUpDown
                  : SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_lastPointerWasSecondary ||
                      (_lastPointerButtons & kSecondaryButton) != 0) {
                    _lastPointerButtons = 0;
                    _lastPointerWasSecondary = false;
                    return;
                  }
                  if (widget.isSelectionMode) {
                    widget.onToggleSelection?.call();
                    return;
                  }

                  final handler = widget.onTap;
                  if (handler == null) return;

                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null) {
                    handler(task, Rect.zero);
                    return;
                  }

                  final origin = renderBox.localToGlobal(Offset.zero);
                  handler(task, origin & renderBox.size);
                },
                onSecondaryTapDown: null,
                onSecondaryTapUp: null,
                onLongPressStart: null,
                child: buildTaskBody(),
              ),
            ),
          );
        }

        Widget buildSizedContent(DragFeedbackHint hint) {
          Widget interactiveChild = widget.enableInteractions
              ? Draggable<CalendarTask>(
                  data: task,
                  feedback: buildFeedback(),
                  onDragStarted: () {
                    final renderBox = context.findRenderObject() as RenderBox?;
                    final Offset origin =
                        renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
                    final Size size = renderBox?.size ?? Size.zero;
                    widget.onDragStarted?.call(task, origin & size);
                  },
                  onDragUpdate: widget.onDragUpdate,
                  onDragEnd: (_) {
                    widget.interactionController.clearHoveringTask(task.id);
                    widget.onDragEnded?.call(task);
                  },
                  childWhenDragging: IgnorePointer(
                    child: Opacity(
                      opacity: 0.6,
                      child: buildInteractiveContent(),
                    ),
                  ),
                  child: buildInteractiveContent(),
                )
              : buildInteractiveContent();

          final listenerWrapped = Listener(
            onPointerDown: (event) {
              if (!widget.enableInteractions) return;
              _lastPointerButtons = event.buttons;
              _lastPointerWasSecondary =
                  (event.buttons & kSecondaryButton) != 0;
              final Offset local = event.localPosition;
              final Offset normalized = _normalizedFromLocal(local);
              _captureContextMenuOffsets(
                localPosition: local,
                normalizedPosition: normalized,
                globalPosition: event.position,
              );
              if (_lastPointerWasSecondary) {
                _debugLog(
                  'pointerDown-secondary',
                  local: local,
                  normalized: normalized,
                  global: event.position,
                );
                return;
              }
              widget.onDragPointerDown?.call(normalized);
              _debugLog(
                'pointerDown-primary',
                local: local,
                normalized: normalized,
                global: event.position,
              );
            },
            onPointerUp: (event) {
              if (_lastPointerWasSecondary) {
                final Offset local = event.localPosition;
                final Offset normalized = _normalizedFromLocal(local);
                _captureContextMenuOffsets(
                  localPosition: local,
                  normalizedPosition: normalized,
                  globalPosition: event.position,
                );
                _debugLog(
                  'pointerUp-secondary',
                  local: local,
                  normalized: normalized,
                  global: event.position,
                );
              }
              _lastPointerButtons = 0;
              _lastPointerWasSecondary = false;
              _debugLog('pointerUp', global: event.position);
            },
            child: interactiveChild,
          );

          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: listenerWrapped,
          );
        }

        if (widget.dragFeedbackHint == null) {
          final defaultContent = buildSizedContent(
            DragFeedbackHint(
              width: widget.width,
              pointerOffset: widget.width / 2,
              anchorDx: widget.width / 2,
              anchorDy: widget.height / 2,
            ),
          );
          return _wrapWithContextMenu(defaultContent);
        }

        final listenableBuilder = ValueListenableBuilder<DragFeedbackHint>(
          valueListenable: widget.dragFeedbackHint!,
          builder: (context, hint, child) => buildSizedContent(hint),
        );

        return _wrapWithContextMenu(listenableBuilder);
      },
    );
  }

  List<Widget> _buildResizeHandles(
    Color accentColor,
    bool isResizing,
    String? activeHandle,
  ) {
    final Color activeColor = accentColor.withValues(alpha: 0.85);
    final Color idleColor = accentColor.withValues(alpha: 0.5);

    final handles = <Widget>[
      // Top handle
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 6,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            key: ValueKey('${widget.task.id}-resize-top'),
            onPanStart: (details) => _startResize('top', details),
            onPanUpdate: (details) => _updateResize('top', details),
            onPanEnd: (_) => _endResize(),
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: isResizing && activeHandle == 'top'
                        ? activeColor
                        : idleColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      // Bottom handle
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 6,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            key: ValueKey('${widget.task.id}-resize-bottom'),
            onPanStart: (details) => _startResize('bottom', details),
            onPanUpdate: (details) => _updateResize('bottom', details),
            onPanEnd: (_) => _endResize(),
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: isResizing && activeHandle == 'bottom'
                        ? activeColor
                        : idleColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];

    return handles;
  }

  Widget _buildAccentStripe(Color color) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: _accentWidth,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            bottomLeft: Radius.circular(4),
          ),
        ),
      ),
    );
  }

  void _startResize(String handleType, DragStartDetails details) {
    if (widget.task.scheduledTime == null) return;

    widget.interactionController.beginResizeInteraction(
      taskId: widget.task.id,
      handle: handleType,
    );
    _totalDragDeltaY = 0;
    _lastAppliedQuarterDelta = 0;

    // Store original values
    final time = widget.task.scheduledTime!;
    _currentStartHour = time.hour + (time.minute / 60.0);
    _currentDurationHours =
        (widget.task.duration ?? const Duration(hours: 1)).inMinutes / 60.0;
    // Clear temporary values
    _tempScheduledTime = null;
    _tempDuration = null;

    HapticFeedback.selectionClick();
  }

  void _updateResize(String handleType, DragUpdateDetails details) {
    final TaskResizeInteraction? session =
        widget.interactionController.activeResizeInteraction;
    if (session?.taskId != widget.task.id ||
        widget.task.scheduledTime == null) {
      return;
    }

    widget.onResizePointerMove?.call(details.globalPosition);

    // Accumulate total drag distance
    _totalDragDeltaY += details.delta.dy;

    if (handleType == 'top' || handleType == 'bottom') {
      final rawSteps = _totalDragDeltaY / widget.stepHeight;
      final int stepsToApply =
          rawSteps > 0 ? rawSteps.floor() : rawSteps.ceil();
      if (stepsToApply == _lastAppliedQuarterDelta) {
        return;
      }

      final int stepDelta = stepsToApply - _lastAppliedQuarterDelta;
      _lastAppliedQuarterDelta = stepsToApply;

      if (stepDelta == 0) {
        return;
      }

      final minutesPerStep = widget.minutesPerStep;
      final double hoursDelta = (stepDelta * minutesPerStep) / 60.0;
      final double minDurationHours = minutesPerStep / 60.0;

      if (handleType == 'top') {
        final scheduled = widget.task.scheduledTime!;
        final double currentEndHour =
            (_currentStartHour + _currentDurationHours).clamp(0.0, 24.0);

        double newStartHour = (_currentStartHour + hoursDelta)
            .clamp(0.0, currentEndHour - minDurationHours);
        final double newDurationHours = (currentEndHour - newStartHour)
            .clamp(minDurationHours, 24.0 - newStartHour);

        _currentStartHour = newStartHour;
        _currentDurationHours = newDurationHours;

        final int startMinutes = (newStartHour * 60).round();
        final int startHour = startMinutes ~/ 60;
        final int startMinute = startMinutes % 60;

        _tempScheduledTime = DateTime(
          scheduled.year,
          scheduled.month,
          scheduled.day,
          startHour,
          startMinute,
        );
        _tempDuration = Duration(minutes: (newDurationHours * 60).round());

        if (widget.onResizePreview != null) {
          final preview = _buildUpdatedTask();
          if (preview != null) {
            widget.onResizePreview!(preview);
          }
        }
      } else if (handleType == 'bottom') {
        final double maxDuration = 24.0 - _currentStartHour;
        final double newDurationHours = (_currentDurationHours + hoursDelta)
            .clamp(minDurationHours, maxDuration);

        _currentDurationHours = newDurationHours;
        _tempScheduledTime = widget.task.scheduledTime;
        _tempDuration = Duration(minutes: (newDurationHours * 60).round());

        if (widget.onResizePreview != null) {
          final preview = _buildUpdatedTask();
          if (preview != null) {
            widget.onResizePreview!(preview);
          }
        }
      }
    }
  }

  void _endResize() {
    final CalendarTask? result = _buildUpdatedTask();

    widget.interactionController.endResizeInteraction(widget.task.id);
    _totalDragDeltaY = 0;
    _lastAppliedQuarterDelta = 0;
    _tempScheduledTime = null;
    _tempDuration = null;

    if (widget.onResizeEnd != null) {
      widget.onResizeEnd!(result ?? widget.task);
    }
  }

  double? _computeStartHour(DateTime? dateTime) {
    if (dateTime == null) return widget.task.startHour;
    return dateTime.hour + (dateTime.minute / 60.0);
  }

  String _formatTimeRange() {
    if (widget.task.scheduledTime == null) return '';

    final startTime = widget.task.scheduledTime!;
    final duration = widget.task.duration ?? const Duration(hours: 1);
    final endTime = startTime.add(duration);

    String formatTime(DateTime time) {
      final hour = time.hour;
      final min = time.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0
          ? 12
          : hour > 12
              ? hour - 12
              : hour;
      return '$displayHour:${min.toString().padLeft(2, '0')} $period';
    }

    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }

  Offset? get debugContextMenuGlobalPosition => _contextMenuGlobalPosition;
  Offset get debugContextMenuLocalPosition => _contextMenuLocalPosition;
  Offset get debugContextMenuNormalizedPosition =>
      _contextMenuNormalizedPosition;
}
