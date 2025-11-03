import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/calendar_task.dart';
import 'controllers/task_interaction_controller.dart';
import 'widgets/calendar_task_tile_render.dart';

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
    required this.markCloseIntent,
  });

  final CalendarTask task;
  final Offset localPosition;
  final Offset normalizedPosition;
  final DateTime? splitTime;
  final VoidCallback markCloseIntent;
}

class ResizableTaskWidget extends StatefulWidget {
  final CalendarTask task;
  final ValueChanged<CalendarTask>? onResizePreview;
  final ValueChanged<CalendarTask>? onResizeEnd;
  final double hourHeight;
  final double stepHeight;
  final int minutesPerStep;
  final double width;
  final double height;
  final bool isDayView;
  final bool isPopoverOpen;
  final TaskInteractionController interactionController;
  final void Function(CalendarTask task, Rect globalBounds)? onTap;
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
    required this.hourHeight,
    required this.stepHeight,
    required this.minutesPerStep,
    required this.width,
    required this.height,
    required this.isDayView,
    this.isPopoverOpen = false,
    this.onTap,
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
  Offset _contextMenuLocalPosition = Offset.zero;
  Offset _contextMenuNormalizedPosition = const Offset(0.5, 0.5);
  DateTime? _contextMenuSplitTime;

  static const double _accentWidth = 4.0;
  static const double _accentPadding = 6.0;
  Color get _taskColor => widget.task.priorityColor;

  void _updateContextMenuState({
    required Offset localPosition,
    required Offset normalizedPosition,
  }) {
    final DateTime? nextSplit = widget.task.splitTimeForFraction(
      fraction: normalizedPosition.dy,
      minutesPerStep: widget.minutesPerStep,
    );
    if (_contextMenuLocalPosition == localPosition &&
        _contextMenuNormalizedPosition == normalizedPosition &&
        _contextMenuSplitTime == nextSplit) {
      return;
    }

    setState(() {
      _contextMenuLocalPosition = localPosition;
      _contextMenuNormalizedPosition = normalizedPosition;
      _contextMenuSplitTime = nextSplit;
    });
  }

  void _captureContextMenuOffsets(
    Offset localPosition,
    Offset normalizedPosition,
  ) {
    if (widget.contextMenuBuilder == null ||
        widget.contextMenuController == null ||
        widget.contextMenuGroupId == null) {
      return;
    }
    _updateContextMenuState(
      localPosition: localPosition,
      normalizedPosition: normalizedPosition,
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
        markCloseIntent: _markMenuCloseIntent,
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

  void _markMenuCloseIntent() {
    widget.contextMenuController?.hide();
  }

  @override
  Widget build(BuildContext context) {
    final TaskInteractionController controller = widget.interactionController;
    return ValueListenableBuilder<String?>(
      valueListenable: controller.hoveredTaskId,
      builder: (context, hoveredTaskId, _) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, __) {
            final CalendarTask task = widget.task;
            final bool isDragging = controller.draggingTaskId == task.id;
            final bool isHovering = hoveredTaskId == task.id;
            final TaskResizeInteraction? resizeSession =
                controller.activeResizeInteraction;
            final bool isResizing =
                resizeSession != null && resizeSession.taskId == task.id;

            Widget buildContent() {
              final Widget taskBody = _buildTaskBody(
                task: task,
                isHovering: isHovering,
                isDragging: isDragging,
                isResizing: isResizing,
              );

              final Widget sizedBody = SizedBox(
                width: widget.width,
                height: widget.height,
                child: taskBody,
              );

              final Widget contextualized = _wrapWithContextMenu(sizedBody);

              return CalendarTaskTileRenderRegion(
                task: task,
                interactionController: controller,
                minutesPerStep: widget.minutesPerStep,
                stepHeight: widget.stepHeight,
                enableInteractions: widget.enableInteractions && !isDragging,
                isSelectionMode: widget.isSelectionMode,
                isSelected: widget.isSelected,
                isPopoverOpen: widget.isPopoverOpen,
                onResizePreview: widget.onResizePreview,
                onResizeEnd: widget.onResizeEnd,
                onResizePointerMove: widget.onResizePointerMove,
                onDragPointerDown: widget.onDragPointerDown,
                onTap: widget.onTap,
                onToggleSelection: widget.onToggleSelection,
                onContextMenuPosition: _captureContextMenuOffsets,
                child: contextualized,
              );
            }

            if (widget.dragFeedbackHint == null) {
              return buildContent();
            }

            return ValueListenableBuilder<DragFeedbackHint>(
              valueListenable: widget.dragFeedbackHint!,
              builder: (_, __, ___) => buildContent(),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskBody({
    required CalendarTask task,
    required bool isHovering,
    required bool isDragging,
    required bool isResizing,
  }) {
    final bool showHoverEffects = widget.enableInteractions &&
        (widget.isPopoverOpen || isHovering || isResizing || isDragging);
    final bool selectionMode = widget.isSelectionMode;
    final bool highlightSelection = selectionMode && widget.isSelected;
    final bool isCompleted = task.isCompleted;
    final Color accentColor = _taskColor;
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

    if (availableHeight <= 6) {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: decoration,
        child: Stack(
          children: [
            _buildAccentStripe(stripeColor),
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
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
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
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
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

    final List<Widget> children = <Widget>[buildTitle()];

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
        ],
      ),
    );
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

  Offset get debugContextMenuLocalPosition => _contextMenuLocalPosition;
  Offset get debugContextMenuNormalizedPosition =>
      _contextMenuNormalizedPosition;
}
