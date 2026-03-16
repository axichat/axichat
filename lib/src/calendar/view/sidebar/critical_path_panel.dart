// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/recurrence_utils.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

import 'package:axichat/src/calendar/view/shell/calendar_sheet_header.dart';

const int _criticalPathTaskUnit = 1;
const int _criticalPathZeroCount = 0;
const double _criticalPathZeroProgress = 0.0;
const double _criticalPathMaxProgress = 1.0;
const int _criticalPathSingleTaskCount = 1;

class PendingCriticalPathSelection {
  const PendingCriticalPathSelection({
    required this.pathId,
    required this.pathName,
    required this.taskIds,
    required this.taskCount,
    required this.pendingRequestIds,
  });

  final String pathId;
  final String pathName;
  final Set<String> taskIds;
  final int taskCount;
  final Set<String> pendingRequestIds;
}

class PendingCriticalPathCreation {
  const PendingCriticalPathCreation({
    required this.requestId,
    required this.name,
    required this.targetTaskIds,
    required this.remainingTaskIds,
    required this.taskCount,
    this.createdPathId,
    this.pendingAddRequestIds = const <String>{},
  });

  final String requestId;
  final String name;
  final Set<String> targetTaskIds;
  final List<String> remainingTaskIds;
  final int taskCount;
  final String? createdPathId;
  final Set<String> pendingAddRequestIds;

  PendingCriticalPathCreation copyWith({
    String? createdPathId,
    Set<String>? pendingAddRequestIds,
  }) {
    return PendingCriticalPathCreation(
      requestId: requestId,
      name: name,
      targetTaskIds: targetTaskIds,
      remainingTaskIds: remainingTaskIds,
      taskCount: taskCount,
      createdPathId: createdPathId ?? this.createdPathId,
      pendingAddRequestIds: pendingAddRequestIds ?? this.pendingAddRequestIds,
    );
  }
}

class CriticalPathPanel extends StatelessWidget {
  const CriticalPathPanel({
    super.key,
    required this.paths,
    required this.tasks,
    required this.focusedPathId,
    required this.orderingPathId,
    required this.onCreatePath,
    required this.onRenamePath,
    required this.onDeletePath,
    required this.onSharePath,
    required this.onFocusPath,
    required this.onOpenPath,
    required this.animationDuration,
    required this.onReorderPath,
    required this.taskTileBuilder,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.requiresLongPressForReorder,
    required this.hideCompleted,
    required this.onToggleHideCompleted,
    this.onExpandedChanged,
    this.onCloseOrdering,
    this.onAddTaskToFocusedPath,
    this.onAddTaskToPath,
  });

  final List<CalendarCriticalPath> paths;
  final Map<String, CalendarTask> tasks;
  final String? focusedPathId;
  final String? orderingPathId;
  final VoidCallback onCreatePath;
  final void Function(CalendarCriticalPath path) onRenamePath;
  final void Function(CalendarCriticalPath path) onDeletePath;
  final void Function(CalendarCriticalPath path, List<CalendarTask> tasks)
  onSharePath;
  final void Function(CalendarCriticalPath? path) onFocusPath;
  final void Function(CalendarCriticalPath path) onOpenPath;
  final Duration animationDuration;
  final void Function(String pathId, List<String> orderedTaskIds) onReorderPath;
  final Widget Function(
    CalendarTask task,
    Widget? trailing, {
    bool requiresLongPress,
  })
  taskTileBuilder;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final bool requiresLongPressForReorder;
  final bool hideCompleted;
  final ValueChanged<bool> onToggleHideCompleted;
  final ValueChanged<bool>? onExpandedChanged;
  final VoidCallback? onCloseOrdering;
  final VoidCallback? onAddTaskToFocusedPath;
  final Future<void> Function(CalendarCriticalPath path)? onAddTaskToPath;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final l10n = context.l10n;
    final TextStyle headerStyle = context.textTheme.sectionLabelM;
    final bool hasPaths = paths.isNotEmpty;
    final CalendarCriticalPath? orderingPath = _pathById(orderingPathId);
    final CalendarCriticalPath? reorderTarget = orderingPath;
    final bool showingSinglePath = orderingPath != null;
    final List<CalendarTask> focusedTasks = reorderTarget != null
        ? _tasksForPath(reorderTarget)
        : const [];
    final Iterable<CalendarCriticalPath> visiblePaths = orderingPath != null
        ? <CalendarCriticalPath>[orderingPath]
        : paths.where((path) => !(hideCompleted && _isPathCompleted(path)));
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.zero,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: EdgeInsets.all(context.spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AxiPlainHeaderButton(
                  onPressed: _handleToggleExpanded,
                  padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
                  backgroundColor: Colors.transparent,
                  hoverBackgroundColor: Colors.transparent,
                  pressedBackgroundColor: Colors.transparent,
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: animationDuration,
                        child: Icon(
                          Icons.expand_more,
                          size: context.sizing.menuItemIconSize,
                          color: colors.mutedForeground,
                        ),
                      ),
                      SizedBox(width: context.spacing.xxs),
                      Flexible(
                        child: Text(
                          context.l10n.calendarCriticalPathsTitle.toUpperCase(),
                          style: headerStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showingSinglePath && onCloseOrdering != null) ...[
                    SizedBox(width: context.spacing.xxs),
                    ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: onCloseOrdering,
                      child: Text(context.l10n.calendarCriticalPathsAll),
                    ),
                  ],
                  SizedBox(width: context.spacing.xxs),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => onToggleHideCompleted(!hideCompleted),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hideCompleted
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: context.sizing.menuItemIconSize,
                          color: hideCompleted
                              ? colors.primary
                              : colors.mutedForeground,
                        ),
                        SizedBox(width: context.spacing.xxs),
                        Text(
                          l10n.calendarCriticalPathCompletedLabel,
                          style: context.textTheme.label.strong.copyWith(
                            color: hideCompleted
                                ? colors.primary
                                : colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.spacing.xxs),
                  AxiTooltip(
                    builder: (context) => Text(
                      context.l10n.calendarCriticalPathsNew,
                      style: context.textTheme.muted,
                    ),
                    child: ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () {
                        _handleExpand();
                        onCreatePath();
                      },
                      child: Icon(
                        Icons.add,
                        size: context.sizing.menuItemIconSize,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ClipRect(
            child: AnimatedCrossFade(
              duration: animationDuration,
              alignment: Alignment.topCenter,
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: context.spacing.m),
                  if (!hasPaths)
                    Text(
                      context.l10n.calendarCriticalPathsEmpty,
                      style: context.textTheme.muted,
                    )
                  else ...[
                    for (final CalendarCriticalPath path in visiblePaths) ...[
                      CriticalPathCard(
                        path: path,
                        animationDuration: animationDuration,
                        isFocused: focusedPathId == path.id,
                        isActive: orderingPathId == path.id,
                        progress: _progressFor(path),
                        onFocus: () =>
                            onFocusPath(focusedPathId == path.id ? null : path),
                        onRename: () => onRenamePath(path),
                        onDelete: () => onDeletePath(path),
                        onShare: () => onSharePath(path, _tasksForPath(path)),
                        onAddTask: onAddTaskToPath == null
                            ? null
                            : () => unawaited(onAddTaskToPath!(path)),
                        onOpen: () {
                          _handleExpand();
                          onOpenPath(path);
                        },
                      ),
                      SizedBox(height: context.spacing.xs),
                    ],
                    if (reorderTarget == null)
                      const SizedBox.shrink()
                    else
                      _FocusedPathTasks(
                        path: reorderTarget,
                        tasks: focusedTasks,
                        animationDuration: animationDuration,
                        taskTileBuilder: taskTileBuilder,
                        requiresLongPressForReorder:
                            requiresLongPressForReorder,
                        onReorder: (oldIndex, newIndex) =>
                            _handleReorder(reorderTarget, oldIndex, newIndex),
                        onAddTask: onAddTaskToFocusedPath,
                      ),
                  ],
                ],
              ),
              sizeCurve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

  CriticalPathProgress _progressFor(CalendarCriticalPath path) {
    return computeCriticalPathProgress(path: path, tasks: tasks);
  }

  CalendarTask? _taskForId(String id) {
    final String baseId = baseTaskIdFrom(id);
    return tasks[baseId] ?? tasks[id];
  }

  CalendarCriticalPath? _pathById(String? pathId) {
    if (pathId == null) {
      return null;
    }
    for (final CalendarCriticalPath path in paths) {
      if (path.id == pathId) {
        return path;
      }
    }
    return null;
  }

  List<CalendarTask> _tasksForPath(CalendarCriticalPath path) {
    final List<CalendarTask> ordered = <CalendarTask>[];
    for (final String id in path.taskIds) {
      final CalendarTask? task = _taskForId(id);
      if (task != null) {
        ordered.add(task);
      }
    }
    return ordered;
  }

  bool _isPathCompleted(CalendarCriticalPath path) {
    final CriticalPathProgress progress = _progressFor(path);
    return progress.total > _criticalPathZeroCount &&
        progress.completed >= progress.total;
  }

  void _handleReorder(CalendarCriticalPath path, int oldIndex, int newIndex) {
    final List<String> ordered = List<String>.from(path.taskIds);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final String moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    onReorderPath(path.id, ordered);
  }

  void _handleToggleExpanded() {
    onToggleExpanded();
    onExpandedChanged?.call(!isExpanded);
  }

  void _handleExpand() {
    if (isExpanded) {
      return;
    }
    onToggleExpanded();
    onExpandedChanged?.call(true);
  }
}

class CriticalPathCard extends StatelessWidget {
  const CriticalPathCard({
    super.key,
    required this.path,
    required this.progress,
    required this.isFocused,
    required this.isActive,
    required this.onFocus,
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.animationDuration,
    this.onAddTask,
    required this.onOpen,
  });

  final CalendarCriticalPath path;
  final CriticalPathProgress progress;
  final bool isFocused;
  final bool isActive;
  final VoidCallback onFocus;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final Duration animationDuration;
  final VoidCallback? onAddTask;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final double progressValue = progress.progressValue;
    final bool highlighted = isFocused || isActive;
    final Color borderColor = highlighted ? colors.primary : colors.border;
    final BorderSide baseBorder = context.borderSide;
    final double borderWidth = highlighted
        ? baseBorder.width * 2
        : baseBorder.width;
    final Color backgroundColor = isActive
        ? colors.primary.withValues(alpha: 0.08)
        : colors.muted.withValues(alpha: 0.04);
    final RoundedSuperellipseBorder decoratedShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
      side: BorderSide(color: borderColor, width: borderWidth),
    );
    return AxiTapBounce(
      child: ShadFocusable(
        builder: (context, _, _) {
          return Material(
            type: MaterialType.transparency,
            shape: decoratedShape,
            clipBehavior: Clip.antiAlias,
            child: ShadGestureDetector(
              cursor: SystemMouseCursors.click,
              onTap: onOpen,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: backgroundColor,
                  shape: decoratedShape,
                ),
                child: Padding(
                  padding: EdgeInsets.all(context.spacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              path.name,
                              style: context.textTheme.small.strong,
                            ),
                          ),
                          _PathActions(
                            onFocus: onFocus,
                            onAddTask: onAddTask,
                            onRename: onRename,
                            onDelete: onDelete,
                            onShare: onShare,
                            isFocused: isFocused,
                          ),
                        ],
                      ),
                      SizedBox(height: context.spacing.xxs),
                      Text(
                        l10n.calendarCriticalPathProgressSummary(
                          progress.completed,
                          progress.total,
                        ),
                        style: context.textTheme.label,
                      ),
                      SizedBox(height: context.spacing.xxs),
                      Text(
                        l10n.calendarCriticalPathProgressHint,
                        style: context.textTheme.labelSm,
                      ),
                      SizedBox(height: context.spacing.xxs),
                      _CriticalPathProgressBar(
                        progressValue: progressValue,
                        animationDuration: animationDuration,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CriticalPathProgressBar extends StatefulWidget {
  const _CriticalPathProgressBar({
    required this.progressValue,
    required this.animationDuration,
  });

  final double progressValue;
  final Duration animationDuration;

  @override
  State<_CriticalPathProgressBar> createState() =>
      _CriticalPathProgressBarState();
}

class _CriticalPathProgressBarState extends State<_CriticalPathProgressBar> {
  late double _startValue;
  late double _targetValue;

  @override
  void initState() {
    super.initState();
    final double clamped = widget.progressValue.clamp(0.0, 1.0);
    _startValue = clamped;
    _targetValue = clamped;
  }

  @override
  void didUpdateWidget(covariant _CriticalPathProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double next = widget.progressValue.clamp(0.0, 1.0);
    if (next != _targetValue) {
      setState(() {
        _startValue = _targetValue;
        _targetValue = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _startValue, end: _targetValue),
      duration: widget.animationDuration,
      curve: Curves.easeInOut,
      builder: (context, animatedValue, _) {
        final double fill = animatedValue.clamp(0.0, 1.0);
        final int percent = (fill * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.calendarCriticalPathProgressLabel,
                  style: context.textTheme.label,
                ),
                Text(
                  l10n.calendarCriticalPathProgressPercent(percent),
                  style: context.textTheme.label.strong.copyWith(
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.xxs),
            Stack(
              children: [
                Container(
                  height: context.sizing.progressIndicatorBarHeight,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(
                      context.radii.container,
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(
                    height: context.sizing.progressIndicatorBarHeight,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(
                        context.radii.container,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PathActions extends StatefulWidget {
  const _PathActions({
    required this.onFocus,
    required this.onAddTask,
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.isFocused,
  });

  final VoidCallback onFocus;
  final VoidCallback? onAddTask;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final bool isFocused;

  @override
  State<_PathActions> createState() => _PathActionsState();
}

class _PathActionsState extends State<_PathActions> {
  late final ShadPopoverController _menuController;

  @override
  void initState() {
    super.initState();
    _menuController = ShadPopoverController();
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _closeMenu() {
    _menuController.hide();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final String focusLabel = widget.isFocused
        ? l10n.calendarCriticalPathUnfocus
        : l10n.calendarCriticalPathFocus;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(right: context.spacing.s),
          child: AxiButton.secondary(
            onPressed: widget.onFocus,
            leading: Icon(
              widget.isFocused ? Icons.visibility_off : Icons.visibility,
              size: context.sizing.menuItemIconSize,
              color: colors.primary,
            ),
            child: Text(focusLabel),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
          child: AxiPopover(
            controller: _menuController,
            closeOnTapOutside: true,
            padding: EdgeInsets.zero,
            decoration: ShadDecoration.none,
            shadows: const <BoxShadow>[],
            popover: (context) {
              return AxiMenu(
                actions: [
                  if (widget.onAddTask != null)
                    AxiMenuAction(
                      icon: Icons.add,
                      label: l10n.calendarCriticalPathAddTask,
                      onPressed: () {
                        _closeMenu();
                        widget.onAddTask?.call();
                      },
                    ),
                  AxiMenuAction(
                    icon: Icons.drive_file_rename_outline,
                    label: context.l10n.commonRename,
                    onPressed: () {
                      _closeMenu();
                      widget.onRename();
                    },
                  ),
                  AxiMenuAction(
                    icon: Icons.send,
                    label: l10n.calendarCriticalPathShareAction,
                    onPressed: () {
                      _closeMenu();
                      widget.onShare();
                    },
                  ),
                  AxiMenuAction(
                    icon: Icons.delete_outline,
                    label: context.l10n.commonDelete,
                    destructive: true,
                    onPressed: () {
                      _closeMenu();
                      widget.onDelete();
                    },
                  ),
                ],
              );
            },
            child: AxiIconButton(
              iconData: Icons.more_horiz,
              backgroundColor: colors.card,
              borderColor: colors.border,
              color: colors.mutedForeground,
              buttonSize: context.sizing.iconButtonSize,
              tapTargetSize: context.sizing.iconButtonTapTarget,
              iconSize: context.sizing.iconButtonIconSize,
              onPressed: _menuController.toggle,
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusedPathTasks extends StatelessWidget {
  const _FocusedPathTasks({
    required this.path,
    required this.tasks,
    required this.animationDuration,
    required this.taskTileBuilder,
    required this.requiresLongPressForReorder,
    required this.onReorder,
    this.onAddTask,
  });

  final CalendarCriticalPath path;
  final List<CalendarTask> tasks;
  final Duration animationDuration;
  final Widget Function(
    CalendarTask task,
    Widget? trailing, {
    bool requiresLongPress,
  })
  taskTileBuilder;
  final bool requiresLongPressForReorder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    final ShadTextTheme textTheme = context.textTheme;
    final ShadColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: context.spacing.s),
        Text(
          context.l10n.calendarCriticalPathTaskOrderTitle,
          style: context.textTheme.small.strong,
        ),
        if (onAddTask != null) ...[
          SizedBox(height: context.spacing.xxs),
          SizedBox(
            width: double.infinity,
            child: AxiButton.outline(
              onPressed: onAddTask,
              widthBehavior: AxiButtonWidth.expand,
              leading: Icon(Icons.add, size: context.sizing.menuItemIconSize),
              child: Text(context.l10n.calendarCriticalPathAddTask),
            ),
          ),
        ],
        SizedBox(height: context.spacing.xxs),
        Text(context.l10n.calendarCriticalPathDragHint, style: textTheme.muted),
        SizedBox(height: context.spacing.s),
        if (tasks.isEmpty)
          Container(
            padding: EdgeInsets.all(context.spacing.m),
            decoration: BoxDecoration(
              color: colors.muted.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(calendarBorderRadius),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              context.l10n.calendarCriticalPathEmptyTasks,
              style: textTheme.muted,
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: tasks.length,
            buildDefaultDragHandles: false,
            onReorder: onReorder,
            proxyDecorator: (child, _, _) {
              return Material(color: Colors.transparent, child: child);
            },
            itemBuilder: (context, index) {
              final CalendarTask task = tasks[index];
              final Widget handle = _CriticalPathReorderHandle(
                index: index,
                requiresLongPress: requiresLongPressForReorder,
              );
              return KeyedSubtree(
                key: ValueKey(task.id),
                child: taskTileBuilder(
                  task,
                  handle,
                  requiresLongPress: requiresLongPressForReorder,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _CriticalPathReorderHandle extends StatelessWidget {
  const _CriticalPathReorderHandle({
    required this.index,
    required this.requiresLongPress,
  });

  final int index;
  final bool requiresLongPress;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final Widget icon = SizedBox(
      height: context.sizing.iconButtonSize,
      width: context.sizing.iconButtonSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: context.radius,
        ),
        child: Center(
          child: Icon(
            Icons.drag_indicator,
            size: context.sizing.menuItemIconSize,
            color: colors.mutedForeground,
          ),
        ),
      ),
    );
    final Widget handle = requiresLongPress
        ? ReorderableDelayedDragStartListener(index: index, child: icon)
        : ReorderableDragStartListener(index: index, child: icon);
    return MouseRegion(cursor: SystemMouseCursors.grab, child: handle);
  }
}

class CriticalPathProgress {
  const CriticalPathProgress({
    required this.total,
    required this.completed,
    required this.progressValue,
  });

  final int total;
  final int completed;
  final double progressValue;
}

CriticalPathProgress computeCriticalPathProgress({
  required CalendarCriticalPath path,
  required Map<String, CalendarTask> tasks,
}) {
  final int total = path.taskIds.length;
  if (total == _criticalPathZeroCount) {
    return const CriticalPathProgress(
      total: _criticalPathZeroCount,
      completed: _criticalPathZeroCount,
      progressValue: _criticalPathZeroProgress,
    );
  }
  int completed = _criticalPathZeroCount;
  for (final String id in path.taskIds) {
    final String baseId = baseTaskIdFrom(id);
    final CalendarTask? task = tasks[baseId] ?? tasks[id];
    if (task == null) {
      break;
    }
    if (task.isCompleted) {
      completed += _criticalPathTaskUnit;
      continue;
    }
    break;
  }
  final double progressValue = (completed / total).clamp(
    _criticalPathZeroProgress,
    _criticalPathMaxProgress,
  );
  return CriticalPathProgress(
    total: total,
    completed: completed,
    progressValue: progressValue,
  );
}

class CriticalPathMembershipList extends StatelessWidget {
  const CriticalPathMembershipList({
    super.key,
    required this.paths,
    this.onRemovePath,
    this.emptyLabel,
  });

  final List<CalendarCriticalPath> paths;
  final ValueChanged<String>? onRemovePath;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    if (paths.isEmpty) {
      if (emptyLabel == null || emptyLabel!.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(emptyLabel!, style: textTheme.muted);
    }
    return Wrap(
      spacing: context.spacing.xxs,
      runSpacing: context.spacing.xxs,
      children: paths
          .map(
            (path) => Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.xs,
                vertical: context.spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: colors.muted.withValues(alpha: 0.08),
                borderRadius: context.radius,
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.route,
                    size: context.sizing.menuItemIconSize,
                    color: colors.mutedForeground,
                  ),
                  SizedBox(width: context.spacing.xxs),
                  Text(path.name, style: textTheme.small.strong),
                  if (onRemovePath != null) ...[
                    SizedBox(width: context.spacing.xxs),
                    AxiIconButton.ghost(
                      iconData: Icons.close,
                      color: colors.mutedForeground,
                      onPressed: () => onRemovePath!(path.id),
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class CriticalPathPickerResult {
  const CriticalPathPickerResult._({
    required this.pathId,
    required this.createNew,
  });

  const CriticalPathPickerResult.createNew()
    : this._(pathId: null, createNew: true);

  const CriticalPathPickerResult.path(String pathId)
    : this._(pathId: pathId, createNew: false);

  final String? pathId;
  final bool createNew;
}

class _CriticalPathPickerList extends StatefulWidget {
  const _CriticalPathPickerList({
    required this.paths,
    required this.isBusy,
    required this.onPathPressed,
  });

  final List<CalendarCriticalPath> paths;
  final bool isBusy;
  final Future<void> Function(CalendarCriticalPath path) onPathPressed;

  @override
  State<_CriticalPathPickerList> createState() =>
      _CriticalPathPickerListState();
}

class _CriticalPathPickerListState extends State<_CriticalPathPickerList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final bool enabled = !widget.isBusy;
    final RoundedSuperellipseBorder itemShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
    );
    final RoundedSuperellipseBorder decoratedShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
      side: BorderSide(color: colors.border, width: context.borderSide.width),
    );
    final double iconSize = context.sizing.menuItemIconSize;
    final double iconContainerSize = context.sizing.menuItemHeight;
    final BorderRadius iconRadius = context.radius;
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: widget.paths.length,
        separatorBuilder: (_, _) => SizedBox(height: context.spacing.xxs),
        itemBuilder: (context, index) {
          final path = widget.paths[index];
          return AxiTapBounce(
            enabled: enabled,
            child: ShadFocusable(
              canRequestFocus: enabled,
              builder: (context, _, _) {
                return Material(
                  type: MaterialType.transparency,
                  shape: itemShape,
                  clipBehavior: Clip.antiAlias,
                  child: ShadGestureDetector(
                    cursor: enabled
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    onTap: enabled
                        ? () async {
                            await widget.onPathPressed(path);
                          }
                        : null,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.card,
                        shape: decoratedShape,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacing.m,
                          vertical: context.spacing.xs,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: iconContainerSize,
                              height: iconContainerSize,
                              decoration: BoxDecoration(
                                color: colors.muted.withValues(alpha: 0.12),
                                borderRadius: iconRadius,
                              ),
                              child: Icon(Icons.route, size: iconSize),
                            ),
                            SizedBox(width: context.spacing.s),
                            Expanded(
                              child: Text(
                                path.name,
                                style: textTheme.small.strong,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: iconSize,
                              color: colors.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

Future<CriticalPathPickerResult?> showCriticalPathPicker({
  required BuildContext context,
  required List<CalendarCriticalPath> paths,
  BaseCalendarBloc? bloc,
  ValueNotifier<PendingCriticalPathSelection?>? pendingSelectionNotifier,
  ValueNotifier<PendingCriticalPathCreation?>? pendingCreationNotifier,
  bool stayOpen = false,
  Future<String?> Function(CalendarCriticalPath path)? onPathSelected,
  Future<String?> Function()? onCreateNewPath,
}) {
  final colors = context.colorScheme;
  final textTheme = context.textTheme;
  final BuildContext modalContext = context.calendarModalContext;
  return showAdaptiveBottomSheet<CriticalPathPickerResult>(
    context: modalContext,
    dialogMaxWidth: 420,
    surfacePadding: EdgeInsets.all(context.spacing.m),
    showCloseButton: false,
    builder: (sheetContext) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.sizeOf(context).height;
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : screenHeight;
          final listViewportHeight = availableHeight * 0.7;
          final ValueNotifier<String?> statusNotifier = ValueNotifier<String?>(
            null,
          );
          final ValueNotifier<PendingCriticalPathSelection?> selectionNotifier =
              pendingSelectionNotifier ??
              ValueNotifier<PendingCriticalPathSelection?>(null);
          final ValueNotifier<PendingCriticalPathCreation?> creationNotifier =
              pendingCreationNotifier ??
              ValueNotifier<PendingCriticalPathCreation?>(null);

          bool isBusy(CalendarState? state) {
            if (state == null) {
              return false;
            }
            final bool hasPendingSelection = selectionNotifier.value != null;
            final bool hasPendingCreation = creationNotifier.value != null;
            return state.isCriticalPathMutating &&
                (hasPendingSelection || hasPendingCreation);
          }

          Widget content = ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: availableHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalendarSheetHeader(
                  title: sheetContext.l10n.calendarCriticalPathAddToTitle,
                  onClose: () => Navigator.of(sheetContext).maybePop(),
                ),
                SizedBox(height: context.spacing.m),
                if (paths.isEmpty) ...[
                  Text(
                    context.l10n.calendarCriticalPathCreatePrompt,
                    style: textTheme.muted,
                  ),
                  SizedBox(height: context.spacing.m),
                ] else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: listViewportHeight),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        selectionNotifier,
                        creationNotifier,
                      ]),
                      builder: (context, _) {
                        final CalendarState? currentState = bloc?.state;
                        return _CriticalPathPickerList(
                          paths: paths,
                          isBusy: isBusy(currentState),
                          onPathPressed: (path) async {
                            if (stayOpen && onPathSelected != null) {
                              final String? status = await onPathSelected(path);
                              if (!sheetContext.mounted) {
                                return;
                              }
                              if (status != null) {
                                statusNotifier.value = status;
                              }
                              return;
                            }
                            Navigator.of(
                              sheetContext,
                            ).pop(CriticalPathPickerResult.path(path.id));
                          },
                        );
                      },
                    ),
                  ),
                ValueListenableBuilder<String?>(
                  valueListenable: statusNotifier,
                  builder: (context, status, _) {
                    if (status == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: EdgeInsets.only(
                        top: context.spacing.s,
                        bottom: context.spacing.s,
                      ),
                      child: Container(
                        padding: EdgeInsets.all(context.spacing.xs),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            calendarBorderRadius,
                          ),
                          border: Border.all(color: colors.primary),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: context.sizing.menuItemIconSize,
                              color: colors.primary,
                            ),
                            SizedBox(width: context.spacing.xxs),
                            Expanded(
                              child: Text(
                                status,
                                style: textTheme.small.strong.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: context.spacing.m),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    selectionNotifier,
                    creationNotifier,
                  ]),
                  builder: (context, _) {
                    final CalendarState? currentState = bloc?.state;
                    final bool busy = isBusy(currentState);
                    return AxiButton.ghost(
                      loading: busy,
                      onPressed: busy
                          ? null
                          : () async {
                              if (stayOpen && onCreateNewPath != null) {
                                final String? status = await onCreateNewPath();
                                if (!sheetContext.mounted) {
                                  return;
                                }
                                if (status != null) {
                                  statusNotifier.value = status;
                                }
                                return;
                              }
                              Navigator.of(
                                sheetContext,
                              ).pop(const CriticalPathPickerResult.createNew());
                            },
                      leading: Icon(
                        Icons.add,
                        size: context.sizing.menuItemIconSize,
                      ),
                      child: Text(context.l10n.calendarCriticalPathsNew),
                    );
                  },
                ),
              ],
            ),
          );
          if (bloc == null) {
            return content;
          }
          content = BlocListener<BaseCalendarBloc, CalendarState>(
            bloc: bloc,
            listener: (context, state) {
              final PendingCriticalPathSelection? pendingSelection =
                  selectionNotifier.value;
              if (pendingSelection != null) {
                final String? requestId = state.criticalPathMutationRequestId;
                if (requestId != null &&
                    pendingSelection.pendingRequestIds.contains(requestId) &&
                    state.criticalPathMutationError != null) {
                  statusNotifier.value = null;
                  selectionNotifier.value = null;
                  FeedbackSystem.showError(
                    context,
                    context.l10n.calendarCriticalPathAddFailed(
                      pendingSelection.taskCount,
                    ),
                  );
                } else if (requestId != null &&
                    pendingSelection.pendingRequestIds.contains(requestId)) {
                  pendingSelection.pendingRequestIds.remove(requestId);
                  final CalendarCriticalPath? path =
                      state.model.criticalPaths[pendingSelection.pathId];
                  final bool added =
                      path != null &&
                      pendingSelection.taskIds.every(path.taskIds.contains);
                  if (added) {
                    selectionNotifier.value = null;
                    statusNotifier.value = context.l10n
                        .calendarCriticalPathAddSuccess(
                          pendingSelection.taskCount,
                          pendingSelection.pathName,
                        );
                  } else if (pendingSelection.pendingRequestIds.isEmpty) {
                    statusNotifier.value = null;
                    selectionNotifier.value = null;
                    FeedbackSystem.showError(
                      context,
                      context.l10n.calendarCriticalPathAddFailed(
                        pendingSelection.taskCount,
                      ),
                    );
                  }
                }
              }

              final PendingCriticalPathCreation? pendingCreation =
                  creationNotifier.value;
              if (pendingCreation == null) {
                return;
              }
              if (pendingCreation.createdPathId == null &&
                  state.criticalPathMutationRequestId ==
                      pendingCreation.requestId &&
                  state.criticalPathMutationError != null) {
                creationNotifier.value = null;
                FeedbackSystem.showError(
                  context,
                  pendingCreation.createdPathId == null
                      ? context.l10n.calendarCriticalPathCreateFailed
                      : context.l10n.calendarCriticalPathAddFailed(
                          pendingCreation.taskCount,
                        ),
                );
                return;
              }
              if (pendingCreation.createdPathId == null) {
                final String? createdPathId =
                    state.criticalPathMutationRequestId ==
                        pendingCreation.requestId
                    ? state.lastCreatedCriticalPathId
                    : null;
                if (createdPathId == null) {
                  return;
                }
                if (pendingCreation.targetTaskIds.isEmpty) {
                  creationNotifier.value = null;
                  statusNotifier.value = context.l10n
                      .calendarCriticalPathQueuedCreate(pendingCreation.name);
                  return;
                }
                final Set<String> addRequestIds = <String>{};
                for (final String taskId in pendingCreation.remainingTaskIds) {
                  final String addRequestId = const Uuid().v4();
                  addRequestIds.add(addRequestId);
                  bloc.add(
                    CalendarEvent.criticalPathTaskAdded(
                      requestId: addRequestId,
                      pathId: createdPathId,
                      taskId: taskId,
                    ),
                  );
                }
                creationNotifier.value = pendingCreation.copyWith(
                  createdPathId: createdPathId,
                  pendingAddRequestIds: addRequestIds,
                );
                return;
              }
              final String? requestId = state.criticalPathMutationRequestId;
              if (requestId == null ||
                  !pendingCreation.pendingAddRequestIds.contains(requestId)) {
                return;
              }
              if (state.criticalPathMutationError != null) {
                creationNotifier.value = null;
                FeedbackSystem.showError(
                  context,
                  context.l10n.calendarCriticalPathAddFailed(
                    pendingCreation.taskCount,
                  ),
                );
                return;
              }
              pendingCreation.pendingAddRequestIds.remove(requestId);
              if (pendingCreation.pendingAddRequestIds.isNotEmpty) {
                return;
              }
              final CalendarCriticalPath? path =
                  state.model.criticalPaths[pendingCreation.createdPathId];
              final bool createdAndAdded =
                  path != null &&
                  pendingCreation.targetTaskIds.every(path.taskIds.contains);
              if (!createdAndAdded) {
                return;
              }
              creationNotifier.value = null;
              statusNotifier.value = context.l10n
                  .calendarCriticalPathCreateSuccess(
                    pendingCreation.taskCount,
                    pendingCreation.name,
                  );
            },
            child: content,
          );
          return content;
        },
      );
    },
  );
}

Future<String?> promptCriticalPathName({
  required BuildContext context,
  required String title,
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final FocusNode focusNode = FocusNode();
  final GlobalKey<ShadFormState> formKey = GlobalKey<ShadFormState>();
  final BuildContext modalContext = context.calendarModalContext;
  final result = await showAdaptiveBottomSheet<String>(
    context: modalContext,
    isScrollControlled: true,
    preferDialogOnMobile: true,
    dialogMaxWidth: 420,
    surfacePadding: EdgeInsets.all(context.spacing.m),
    showCloseButton: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, _) {
          final textTheme = context.textTheme;
          return ShadForm(
            key: formKey,
            autovalidateMode: ShadAutovalidateMode.disabled,
            fieldIdSeparator: null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalendarSheetHeader(
                  title: title,
                  onClose: () => Navigator.of(dialogContext).maybePop(),
                ),
                SizedBox(height: context.spacing.s),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.calendarCriticalPathNamePrompt,
                          style: textTheme.muted,
                        ),
                        SizedBox(height: context.spacing.s),
                        AxiTextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          placeholder: Text(
                            context.l10n.calendarCriticalPathNamePlaceholder,
                          ),
                          validator: (value) {
                            final String trimmed = value.trim();
                            if (trimmed.isEmpty) {
                              return context
                                  .l10n
                                  .calendarCriticalPathNameEmptyError;
                            }
                            return null;
                          },
                          onSubmitted: (value) {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.of(dialogContext).pop(value.trim());
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.spacing.m),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AxiButton.outline(
                      onPressed: () => closeSheetWithKeyboardDismiss(
                        context,
                        () => Navigator.of(dialogContext).maybePop(),
                      ),
                      child: Text(context.l10n.commonCancel),
                    ),
                    SizedBox(width: context.spacing.s),
                    AxiButton.primary(
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          focusNode.requestFocus();
                          return;
                        }
                        Navigator.of(dialogContext).pop(controller.text.trim());
                      },
                      child: Text(context.l10n.commonSave),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
  focusNode.dispose();
  controller.dispose();
  if (result == null || result.trim().isEmpty) {
    return null;
  }
  return result.trim();
}

String? _resolveCriticalPathName({
  required BaseCalendarBloc bloc,
  required String pathId,
  required Map<String, String> fallbackNames,
}) {
  return bloc.state.model.criticalPaths[pathId]?.name ?? fallbackNames[pathId];
}

Future<void> addTaskToCriticalPath({
  required BuildContext context,
  required BaseCalendarBloc bloc,
  required CalendarTask task,
}) async {
  await addTasksToCriticalPath(context: context, bloc: bloc, tasks: [task]);
}

Future<void> addTasksToCriticalPath({
  required BuildContext context,
  required BaseCalendarBloc bloc,
  required List<CalendarTask> tasks,
}) async {
  if (tasks.isEmpty) return;

  final List<CalendarCriticalPath> paths = bloc.state.criticalPaths;
  final Map<String, String> pathNamesById = <String, String>{}
    ..addEntries(paths.map((path) => MapEntry(path.id, path.name)));
  final int taskCount = tasks.length;
  final Set<String> targetTaskIds = <String>{}
    ..addAll(tasks.map((task) => baseTaskIdFrom(task.id)));
  final ValueNotifier<PendingCriticalPathSelection?> pendingSelectionNotifier =
      ValueNotifier<PendingCriticalPathSelection?>(null);
  final ValueNotifier<PendingCriticalPathCreation?> pendingCreationNotifier =
      ValueNotifier<PendingCriticalPathCreation?>(null);
  await showCriticalPathPicker(
    context: context,
    paths: paths,
    bloc: bloc,
    pendingSelectionNotifier: pendingSelectionNotifier,
    pendingCreationNotifier: pendingCreationNotifier,
    stayOpen: true,
    onPathSelected: (path) async {
      final Set<String> existingTaskIds = <String>{}..addAll(path.taskIds);
      final List<CalendarTask> tasksToAdd = tasks
          .where((task) => !existingTaskIds.contains(baseTaskIdFrom(task.id)))
          .toList();
      final int skippedCount = taskCount - tasksToAdd.length;
      if (skippedCount == taskCount) {
        FeedbackSystem.showError(
          context,
          context.l10n.calendarCriticalPathAlreadyContainsTasks(taskCount),
        );
        return null;
      }
      if (skippedCount > 0) {
        FeedbackSystem.showError(
          context,
          context.l10n.calendarCriticalPathAlreadyContainsTasks(skippedCount),
        );
      }
      final Set<String> addedTaskIds = <String>{}
        ..addAll(tasksToAdd.map((task) => baseTaskIdFrom(task.id)));
      final Set<String> requestIds = <String>{};
      for (final CalendarTask task in tasksToAdd) {
        final String requestId = const Uuid().v4();
        requestIds.add(requestId);
        bloc.add(
          CalendarEvent.criticalPathTaskAdded(
            requestId: requestId,
            pathId: path.id,
            taskId: task.id,
          ),
        );
      }
      final String? resolvedName = _resolveCriticalPathName(
        bloc: bloc,
        pathId: path.id,
        fallbackNames: pathNamesById,
      );
      if (resolvedName != null) {
        pendingSelectionNotifier.value = PendingCriticalPathSelection(
          pathId: path.id,
          pathName: resolvedName,
          taskIds: addedTaskIds,
          taskCount: tasksToAdd.length,
          pendingRequestIds: requestIds,
        );
      }
      return null;
    },
    onCreateNewPath: () async {
      final String? name = await promptCriticalPathName(
        context: context,
        title: context.l10n.calendarCriticalPathsNew,
      );
      if (!context.mounted || name == null) {
        return null;
      }
      final String requestId = const Uuid().v4();
      bloc.add(
        CalendarEvent.criticalPathCreated(
          requestId: requestId,
          name: name,
          taskId: tasks.first.id,
        ),
      );
      pendingCreationNotifier.value = PendingCriticalPathCreation(
        requestId: requestId,
        name: name,
        targetTaskIds: targetTaskIds,
        remainingTaskIds: tasks
            .skip(_criticalPathSingleTaskCount)
            .map((task) => task.id)
            .toList(growable: false),
        taskCount: taskCount,
      );
      return null;
    },
  );
}
