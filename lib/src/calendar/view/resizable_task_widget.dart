// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'controllers/task_interaction_controller.dart';
import 'widgets/calendar_task_tile_render.dart';
import 'widgets/calendar_task_title_hover_reporter.dart';

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

typedef TaskContextMenuBuilder =
    List<Widget> Function(BuildContext context, TaskContextMenuRequest request);

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
  final double Function()? viewportScrollOffsetProvider;
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
  final Color? accentColorOverride;
  final Widget? overlay;

  const ResizableTaskWidget({
    super.key,
    required this.interactionController,
    required this.task,
    this.onResizePreview,
    this.onResizeEnd,
    required this.hourHeight,
    required this.stepHeight,
    required this.minutesPerStep,
    this.viewportScrollOffsetProvider,
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
    this.accentColorOverride,
    this.overlay,
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

  void _markMenuCloseIntent() {
    widget.contextMenuController?.hide();
  }

  @override
  Widget build(BuildContext context) {
    final TaskInteractionController controller = widget.interactionController;
    final Listenable interactionChanges = Listenable.merge(<Listenable>[
      controller.draggingTaskIdNotifier,
      controller.hoveredTaskId,
      controller.resizeInteraction,
    ]);
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Duration firstInteractionPulseDuration =
        _firstInteractionPulseDuration(disableAnimations: disableAnimations);
    return ValueListenableBuilder<String?>(
      valueListenable: controller.hoveredTaskId,
      builder: (context, hoveredTaskId, _) {
        return AnimatedBuilder(
          animation: interactionChanges,
          builder: (context, _) {
            final CalendarTask task = widget.task;
            final bool isDragging =
                controller.draggingTaskIdNotifier.value == task.id;
            final bool isHovering = hoveredTaskId == task.id;
            final bool highlightOnFirstInteraction = controller
                .shouldHighlightTaskForFirstInteraction(task);
            final TaskResizeInteraction? resizeSession =
                controller.activeResizeInteraction;
            final bool isResizing =
                resizeSession != null && resizeSession.taskId == task.id;

            Widget buildContent() {
              final Color accentColor =
                  widget.accentColorOverride ?? _taskColor;
              final taskBody = _ResizableTaskBody(
                task: task,
                isHovering: isHovering,
                isDragging: isDragging,
                isResizing: isResizing,
                enableInteractions: widget.enableInteractions,
                isPopoverOpen: widget.isPopoverOpen,
                isSelectionMode: widget.isSelectionMode,
                isSelected: widget.isSelected,
                highlightOnFirstInteraction: highlightOnFirstInteraction,
                height: widget.height,
                width: widget.width,
                accentColor: accentColor,
                accentWidth: _accentWidth,
                accentPadding: _accentPadding,
                timeLabel: _formatTimeRange(context),
                overlay: widget.overlay,
              );
              final bool showFirstInteractionPulse =
                  highlightOnFirstInteraction &&
                  widget.enableInteractions &&
                  firstInteractionPulseDuration > Duration.zero;
              final Widget pulsingTaskBody = _TaskFirstInteractionPulse(
                enabled: showFirstInteractionPulse,
                duration: firstInteractionPulseDuration,
                accentColor: accentColor,
                child: taskBody,
              );

              final shape = RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(context.radii.squircle),
              );
              final Widget shapedBody = Material(
                color: Colors.transparent,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: pulsingTaskBody,
              );
              final Widget animatedBody = AxiTapBounce(
                enabled: widget.enableInteractions,
                child: shapedBody,
              );
              final Widget sizedBody = SizedBox(
                width: widget.width,
                height: widget.height,
                child: animatedBody,
              );

              final Widget contextualized = _TaskContextMenuWrapper(
                task: widget.task,
                builder: widget.contextMenuBuilder,
                controller: widget.contextMenuController,
                groupId: widget.contextMenuGroupId,
                longPressEnabled: widget.contextMenuLongPressEnabled,
                localPosition: _contextMenuLocalPosition,
                normalizedPosition: _contextMenuNormalizedPosition,
                splitTime: _contextMenuSplitTime,
                onCloseIntent: _markMenuCloseIntent,
                child: sizedBody,
              );

              return CalendarTaskTitleHoverReporter(
                title: task.title,
                enabled:
                    widget.enableInteractions &&
                    !isDragging &&
                    !isResizing &&
                    !widget.isPopoverOpen,
                child: CalendarTaskTileRenderRegion(
                  task: task,
                  interactionController: controller,
                  minutesPerStep: widget.minutesPerStep,
                  viewportScrollOffsetProvider:
                      widget.viewportScrollOffsetProvider,
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
              builder: (_, _, _) => buildContent(),
            );
          },
        );
      },
    );
  }

  String _formatTimeRange(BuildContext context) {
    if (widget.task.scheduledTime == null) return '';

    final startTime = widget.task.scheduledTime!;
    final duration = widget.task.duration ?? const Duration(hours: 1);
    final endTime = startTime.add(duration);

    return context.l10n.commonRangeLabel(
      TimeFormatter.formatTime(startTime),
      TimeFormatter.formatTime(endTime),
    );
  }

  Offset get debugContextMenuLocalPosition => _contextMenuLocalPosition;

  Offset get debugContextMenuNormalizedPosition =>
      _contextMenuNormalizedPosition;

  Duration _firstInteractionPulseDuration({required bool disableAnimations}) {
    if (disableAnimations) {
      return Duration.zero;
    }
    return Duration(microseconds: baseAnimationDuration.inMicroseconds * 6);
  }
}

class _TaskContextMenuWrapper extends StatelessWidget {
  const _TaskContextMenuWrapper({
    required this.child,
    required this.task,
    required this.builder,
    required this.controller,
    required this.groupId,
    required this.longPressEnabled,
    required this.localPosition,
    required this.normalizedPosition,
    required this.splitTime,
    required this.onCloseIntent,
  });

  final Widget child;
  final CalendarTask task;
  final TaskContextMenuBuilder? builder;
  final ShadPopoverController? controller;
  final ValueKey<String>? groupId;
  final bool longPressEnabled;
  final Offset localPosition;
  final Offset normalizedPosition;
  final DateTime? splitTime;
  final VoidCallback onCloseIntent;

  @override
  Widget build(BuildContext context) {
    final TaskContextMenuBuilder? resolvedBuilder = builder;
    final ShadPopoverController? resolvedController = controller;
    final ValueKey<String>? resolvedGroupId = groupId;
    if (resolvedBuilder == null ||
        resolvedController == null ||
        resolvedGroupId == null) {
      return child;
    }

    final items = resolvedBuilder(
      context,
      TaskContextMenuRequest(
        task: task,
        localPosition: localPosition,
        normalizedPosition: normalizedPosition,
        splitTime: splitTime,
        markCloseIntent: onCloseIntent,
      ),
    );

    return AxiContextMenuRegion(
      controller: resolvedController,
      groupId: resolvedGroupId,
      longPressEnabled: longPressEnabled,
      items: items,
      child: child,
    );
  }
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
    required this.highlightOnFirstInteraction,
    required this.height,
    required this.width,
    required this.accentColor,
    required this.accentWidth,
    required this.accentPadding,
    required this.timeLabel,
    required this.overlay,
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
  final bool highlightOnFirstInteraction;
  final double height;
  final double width;
  final Color accentColor;
  final double accentWidth;
  final double accentPadding;
  final String timeLabel;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final showHoverEffects =
        enableInteractions &&
        (isPopoverOpen || isHovering || isResizing || isDragging);
    final highlightSelection = isSelectionMode && isSelected;
    final highlightFirstInteraction =
        enableInteractions && !isSelectionMode && highlightOnFirstInteraction;
    final isCompleted = task.isCompleted;
    final baseBlendAlpha = isCompleted ? 0.06 : 0.12;
    final activeBlendAlpha = isCompleted ? 0.1 : 0.18;
    final firstInteractionBlendAlpha = isCompleted ? 0.14 : 0.22;
    final selectionBlendAlpha = highlightSelection
        ? (isCompleted ? 0.18 : 0.26)
        : (highlightFirstInteraction
              ? firstInteractionBlendAlpha
              : (showHoverEffects ? activeBlendAlpha : baseBlendAlpha));
    final backgroundColor = Color.alphaBlend(
      accentColor.withValues(alpha: selectionBlendAlpha),
      calendarContainerColor,
    );
    final borderColor = highlightSelection
        ? accentColor
        : highlightFirstInteraction
        ? accentColor.withValues(alpha: 0.72)
        : showHoverEffects
        ? accentColor.withValues(alpha: 0.45)
        : Color.lerp(calendarBorderColor, accentColor, 0.18)!;
    final boxShadows = highlightSelection
        ? calendarMediumShadow
        : highlightFirstInteraction
        ? calendarLightShadow
        : showHoverEffects
        ? calendarLightShadow
        : const <BoxShadow>[];
    final titleColor = isCompleted ? calendarSubtitleColor : calendarTitleColor;
    final Color secondaryColor = calendarSubtitleColor;
    final stripeColor = highlightSelection
        ? accentColor
        : accentColor.withValues(alpha: isCompleted ? 0.5 : 0.9);
    final BorderSide borderSide = BorderSide(
      color: borderColor,
      width: highlightSelection
          ? 2.4
          : highlightFirstInteraction
          ? 2
          : isResizing
          ? 1.8
          : 1,
    );
    final ShapeBorder shape = SquircleBorder(
      cornerRadius: context.radii.squircle,
      side: borderSide,
    );
    final decoration = ShapeDecoration(
      color: backgroundColor,
      shape: shape,
      shadows: boxShadows,
    );
    final availableHeight = (height - 4).clamp(0.0, double.infinity);
    if (availableHeight <= 6) {
      return Container(
        margin: EdgeInsets.all(spacing.xxs),
        decoration: decoration,
        child: Stack(
          children: [
            _TaskAccentStripe(color: stripeColor, accentWidth: accentWidth),
          ],
        ),
      );
    }

    double padding;
    if (availableHeight >= 96) {
      padding = spacing.s;
    } else if (availableHeight >= 72) {
      padding = spacing.xs;
    } else if (availableHeight >= 48) {
      padding = spacing.xs;
    } else {
      padding = spacing.xxs;
    }

    final innerHeight = (availableHeight - padding * 2).clamp(
      0.0,
      double.infinity,
    );

    if (innerHeight <= 10) {
      final Widget compactBody = Container(
        margin: EdgeInsets.all(spacing.xxs),
        decoration: decoration,
        child: Stack(
          children: [
            _TaskAccentStripe(color: stripeColor, accentWidth: accentWidth),
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
                  style: context.textTheme.label.strong.copyWith(
                    color: titleColor,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return _ResizableTaskOverlay(overlay: overlay, child: compactBody);
    }

    final stackedTime = innerHeight >= 36;
    final inlineTime = !stackedTime && innerHeight >= 16 && width >= 140;
    final showTime = stackedTime || inlineTime;
    final showDescription =
        task.description?.isNotEmpty == true &&
        innerHeight >= _minDescriptionHeight;
    final bool showLocation =
        task.location?.isNotEmpty == true &&
        innerHeight >= _minLocationHeight &&
        width >= _minLocationWidth;
    final bool showDeadline =
        task.deadline != null &&
        innerHeight >= _minDeadlineHeight &&
        width >= _minDeadlineWidth;

    final double gap = innerHeight >= 90
        ? spacing.s
        : innerHeight >= 64
        ? spacing.xs
        : innerHeight >= 40
        ? spacing.xxs
        : 0.0;

    final titleLines = innerHeight >= 48 ? 2 : 1;
    final descriptionLines = showDescription
        ? math.max(1, (innerHeight / 18).floor() - (stackedTime ? 1 : 0))
        : 0;
    final descriptionOverflow = descriptionLines >= 4
        ? TextOverflow.fade
        : TextOverflow.ellipsis;

    Widget titleSection() {
      final title = Text(
        task.title,
        maxLines: titleLines,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.label.strong.copyWith(
          color: titleColor,
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      );

      if (showTime && inlineTime) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            SizedBox(width: spacing.s),
            Flexible(
              child: Text(
                timeLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: context.textTheme.label.copyWith(color: secondaryColor),
              ),
            ),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: title)],
      );
    }

    final children = <Widget>[titleSection()];

    if (showTime && !inlineTime) {
      if (gap > 0) {
        children.add(SizedBox(height: gap));
      }
      children.add(
        Text(
          timeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.label.copyWith(color: secondaryColor),
        ),
      );
    }

    if (showDescription) {
      if (gap > 0) {
        children.add(SizedBox(height: gap));
      }
      children.add(
        Text(
          task.description!,
          maxLines: descriptionLines,
          overflow: descriptionOverflow,
          softWrap: true,
          style: context.textTheme.labelSm.copyWith(color: secondaryColor),
        ),
      );
    }

    if (showDeadline) {
      if (gap > 0) {
        children.add(SizedBox(height: gap));
      }
      children.add(_TaskDeadlineBadge(deadline: task.deadline!));
    }

    if (showLocation) {
      if (gap > 0) {
        children.add(SizedBox(height: gap));
      }
      children.add(_TaskLocationRow(location: task.location!));
    }

    final Widget detailedBody = Container(
      margin: EdgeInsets.all(spacing.xxs),
      decoration: decoration,
      child: Stack(
        children: [
          _TaskAccentStripe(color: stripeColor, accentWidth: accentWidth),
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
    return _ResizableTaskOverlay(overlay: overlay, child: detailedBody);
  }
}

class _ResizableTaskOverlay extends StatelessWidget {
  const _ResizableTaskOverlay({required this.child, required this.overlay});

  final Widget child;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    if (overlay == null) {
      return child;
    }
    final double overlayInset = context.spacing.xs;
    return Stack(
      children: [
        child,
        Positioned(top: overlayInset, right: overlayInset, child: overlay!),
      ],
    );
  }
}

class _TaskFirstInteractionPulse extends StatefulWidget {
  const _TaskFirstInteractionPulse({
    required this.enabled,
    required this.duration,
    required this.accentColor,
    required this.child,
  });

  final bool enabled;
  final Duration duration;
  final Color accentColor;
  final Widget child;

  @override
  State<_TaskFirstInteractionPulse> createState() =>
      _TaskFirstInteractionPulseState();
}

class _TaskFirstInteractionPulseState extends State<_TaskFirstInteractionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _TaskFirstInteractionPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool pulseEnabled = widget.enabled && widget.duration > Duration.zero;
    if (!pulseEnabled) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final double progress = _animation.value;
        final double alpha =
            lerpDouble(
              context.motion.tapHoverAlpha,
              context.motion.tapFocusAlpha,
              progress,
            ) ??
            context.motion.tapHoverAlpha;
        final double baseBorderWidth = context.borders.width;
        final double borderWidth =
            baseBorderWidth + (baseBorderWidth * progress);
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.all(context.spacing.xxs),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: SquircleBorder(
                        cornerRadius: context.radii.squircle,
                        side: BorderSide(
                          color: widget.accentColor.withValues(alpha: alpha),
                          width: borderWidth,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _syncPulse() {
    final bool pulseEnabled = widget.enabled && widget.duration > Duration.zero;
    if (!pulseEnabled) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      if (_controller.value != 0) {
        _controller.value = 0;
      }
      return;
    }
    if (_controller.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (_controller.isAnimating) {
      return;
    }
    _controller.repeat(reverse: true);
  }
}

class _TaskAccentStripe extends StatelessWidget {
  const _TaskAccentStripe({required this.color, required this.accentWidth});

  final Color color;
  final double accentWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: SquircleBorder(cornerRadius: context.radii.squircle),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(width: accentWidth, color: color),
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
    final l10n = context.l10n;
    final spacing = context.spacing;
    final Color color = _deadlineColor(deadline);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: _deadlineBackgroundColor(deadline),
        borderRadius: context.radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: context.sizing.menuItemIconSize,
            color: color,
          ),
          SizedBox(width: spacing.xs),
          Text(
            _deadlineLabel(l10n, deadline),
            style: context.textTheme.label.strong.copyWith(color: color),
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
        Text('📍', style: context.textTheme.label),
        Expanded(
          child: Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.label.copyWith(
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

String _deadlineLabel(AppLocalizations l10n, DateTime deadline) {
  return TimeFormatter.formatFriendlyDateTime(l10n, deadline);
}
