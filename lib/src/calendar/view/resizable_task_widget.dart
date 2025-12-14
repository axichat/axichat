import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'controllers/task_interaction_controller.dart';
import 'widgets/calendar_task_title_hover_reporter.dart';
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
  final bool contextMenuLongPressEnabled;
  final double resizeHandleExtent;

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
    this.contextMenuLongPressEnabled = true,
    this.resizeHandleExtent = 8.0,
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
      longPressEnabled: widget.contextMenuLongPressEnabled,
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
              final taskBody = _ResizableTaskBody(
                task: task,
                isHovering: isHovering,
                isDragging: isDragging,
                isResizing: isResizing,
                enableInteractions: widget.enableInteractions,
                isPopoverOpen: widget.isPopoverOpen,
                isSelectionMode: widget.isSelectionMode,
                isSelected: widget.isSelected,
                height: widget.height,
                width: widget.width,
                accentColor: _taskColor,
                accentWidth: _accentWidth,
                accentPadding: _accentPadding,
                timeLabel: _formatTimeRange(),
              );

              final Widget sizedBody = SizedBox(
                width: widget.width,
                height: widget.height,
                child: taskBody,
              );

              final Widget contextualized = _wrapWithContextMenu(sizedBody);

              return CalendarTaskTitleHoverReporter(
                title: task.title,
                enabled: widget.enableInteractions &&
                    !isDragging &&
                    !isResizing &&
                    !widget.isPopoverOpen,
                child: CalendarTaskTileRenderRegion(
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
                  handleExtent: widget.resizeHandleExtent,
                  child: contextualized,
                ),
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

class _ResizableTaskBody extends StatelessWidget {
  const _ResizableTaskBody({
    required this.task,
    required this.isHovering,
    required this.isDragging,
    required this.isResizing,
    required this.enableInteractions,
    required this.isPopoverOpen,
    required this.isSelectionMode,
    required this.isSelected,
    required this.height,
    required this.width,
    required this.accentColor,
    required this.accentWidth,
    required this.accentPadding,
    required this.timeLabel,
  });

  static const double _minDescriptionHeight = 56;
  static const double _minLocationHeight = 64;
  static const double _minLocationWidth = 120;
  static const double _minDeadlineHeight = 72;
  static const double _minDeadlineWidth = 140;

  final CalendarTask task;
  final bool isHovering;
  final bool isDragging;
  final bool isResizing;
  final bool enableInteractions;
  final bool isPopoverOpen;
  final bool isSelectionMode;
  final bool isSelected;
  final double height;
  final double width;
  final Color accentColor;
  final double accentWidth;
  final double accentPadding;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final showHoverEffects = enableInteractions &&
        (isPopoverOpen || isHovering || isResizing || isDragging);
    final highlightSelection = isSelectionMode && isSelected;
    final isCompleted = task.isCompleted;
    final baseBlendAlpha = isCompleted ? 0.06 : 0.12;
    final activeBlendAlpha = isCompleted ? 0.1 : 0.18;
    final selectionBlendAlpha = highlightSelection
        ? (isCompleted ? 0.18 : 0.26)
        : (showHoverEffects ? activeBlendAlpha : baseBlendAlpha);
    final backgroundColor = Color.alphaBlend(
      accentColor.withValues(alpha: selectionBlendAlpha),
      calendarContainerColor,
    );
    final borderColor = highlightSelection
        ? accentColor
        : showHoverEffects
            ? accentColor.withValues(alpha: 0.45)
            : Color.lerp(calendarBorderColor, accentColor, 0.18)!;
    final boxShadows = highlightSelection
        ? calendarMediumShadow
        : showHoverEffects
            ? calendarLightShadow
            : const <BoxShadow>[];
    final titleColor = isCompleted ? calendarSubtitleColor : calendarTitleColor;
    const secondaryColor = calendarSubtitleColor;
    final stripeColor = highlightSelection
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
    final availableHeight = (height - 4).clamp(0.0, double.infinity);
    if (availableHeight <= 6) {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: decoration,
        child: Stack(
          children: [
            _TaskAccentStripe(
              color: stripeColor,
              accentWidth: accentWidth,
            ),
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

    final innerHeight =
        (availableHeight - padding * 2).clamp(0.0, double.infinity);

    if (innerHeight <= 10) {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: decoration,
        child: Stack(
          children: [
            _TaskAccentStripe(
              color: stripeColor,
              accentWidth: accentWidth,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding + accentWidth + accentPadding,
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

    final stackedTime = innerHeight >= 36;
    final inlineTime = !stackedTime && innerHeight >= 16 && width >= 140;
    final showTime = stackedTime || inlineTime;
    final showDescription = task.description?.isNotEmpty == true &&
        innerHeight >= _minDescriptionHeight;
    final bool showLocation = task.location?.isNotEmpty == true &&
        innerHeight >= _minLocationHeight &&
        width >= _minLocationWidth;
    final bool showDeadline = task.deadline != null &&
        innerHeight >= _minDeadlineHeight &&
        width >= _minDeadlineWidth;

    final double spacing = innerHeight >= 90
        ? calendarInsetLg
        : innerHeight >= 64
            ? calendarInsetMd
            : innerHeight >= 40
                ? calendarInsetSm
                : 0.0;

    final titleLines = innerHeight >= 48 ? 2 : 1;
    final descriptionLines = showDescription
        ? math.max(1, (innerHeight / 18).floor() - (stackedTime ? 1 : 0))
        : 0;
    final descriptionOverflow =
        descriptionLines >= 4 ? TextOverflow.fade : TextOverflow.ellipsis;

    Widget titleSection() {
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: calendarInsetLg),
            Flexible(
              child: Text(
                timeLabel,
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

    final children = <Widget>[titleSection()];

    if (showTime && !inlineTime) {
      if (spacing > 0) {
        children.add(SizedBox(height: spacing));
      }
      children.add(
        Text(
          timeLabel,
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

    if (showDeadline) {
      if (spacing > 0) {
        children.add(SizedBox(height: spacing));
      }
      children.add(_TaskDeadlineBadge(deadline: task.deadline!));
    }

    if (showLocation) {
      if (spacing > 0) {
        children.add(SizedBox(height: spacing));
      }
      children.add(_TaskLocationRow(location: task.location!));
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: decoration,
      child: Stack(
        children: [
          _TaskAccentStripe(
            color: stripeColor,
            accentWidth: accentWidth,
          ),
          ClipRect(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                padding + accentWidth + accentPadding,
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
}

class _TaskAccentStripe extends StatelessWidget {
  const _TaskAccentStripe({
    required this.color,
    required this.accentWidth,
  });

  final Color color;
  final double accentWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: accentWidth,
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
}

class _TaskDeadlineBadge extends StatelessWidget {
  const _TaskDeadlineBadge({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final Color color = _deadlineColor(deadline);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: _deadlineBackgroundColor(deadline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: calendarInsetMd),
          Text(
            _deadlineLabel(deadline),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskLocationRow extends StatelessWidget {
  const _TaskLocationRow({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('📍 ', style: TextStyle(fontSize: 11)),
        Expanded(
          child: Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: calendarSubtitleColor,
            ),
          ),
        ),
      ],
    );
  }
}

Color _deadlineColor(DateTime deadline) {
  final now = DateTime.now();
  if (deadline.isBefore(now)) {
    return calendarDangerColor;
  } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
    return calendarWarningColor;
  }
  return calendarPrimaryColor;
}

Color _deadlineBackgroundColor(DateTime deadline) {
  final now = DateTime.now();
  if (deadline.isBefore(now)) {
    return calendarDangerColor.withValues(alpha: 0.1);
  } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
    return calendarWarningColor.withValues(alpha: 0.1);
  }
  return calendarPrimaryColor.withValues(alpha: 0.08);
}

String _deadlineLabel(DateTime deadline) {
  return TimeFormatter.formatFriendlyDateTime(deadline);
}
