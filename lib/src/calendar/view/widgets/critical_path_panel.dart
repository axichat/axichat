// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const String _criticalPathShareActionLabel = 'Share to chat';

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
  }) taskTileBuilder;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final bool requiresLongPressForReorder;
  final bool hideCompleted;
  final ValueChanged<bool> onToggleHideCompleted;
  final ValueChanged<bool>? onExpandedChanged;
  final VoidCallback? onCloseOrdering;
  final VoidCallback? onAddTaskToFocusedPath;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final TextStyle headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: calendarSubtitleColor,
    );
    final bool hasPaths = paths.isNotEmpty;
    final CalendarCriticalPath? orderingPath = _pathById(orderingPathId);
    final CalendarCriticalPath? reorderTarget = orderingPath;
    final bool showingSinglePath = orderingPath != null;
    final List<CalendarTask> focusedTasks =
        reorderTarget != null ? _tasksForPath(reorderTarget) : const [];
    final Iterable<CalendarCriticalPath> visiblePaths = orderingPath != null
        ? <CalendarCriticalPath>[orderingPath]
        : paths.where(
            (path) => !(hideCompleted && _isPathCompleted(path)),
          );
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.zero,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      padding: calendarPaddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _handleToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: calendarInsetSm),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: animationDuration,
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: calendarInsetSm),
                  Flexible(
                    child: Text(
                      context.l10n.calendarCriticalPathsTitle.toUpperCase(),
                      style: headerStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  if (showingSinglePath && onCloseOrdering != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: calendarInsetSm),
                      child: ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: onCloseOrdering,
                        child: Text(context.l10n.calendarCriticalPathsAll),
                      ).withTapBounce(),
                    ),
                  ],
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
                          size: 16,
                          color: hideCompleted
                              ? colors.primary
                              : colors.mutedForeground,
                        ),
                        const SizedBox(width: calendarInsetSm),
                        Text(
                          'Completed',
                          style: context.textTheme.small.copyWith(
                            color: hideCompleted
                                ? colors.primary
                                : colors.mutedForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ).withTapBounce(),
                  const SizedBox(width: calendarInsetSm),
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
                      child: const Icon(Icons.add, size: 16),
                    ).withTapBounce(),
                  ),
                ],
              ),
            ),
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
                  const SizedBox(height: calendarGutterMd),
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
                        onFocus: () => onFocusPath(
                          focusedPathId == path.id ? null : path,
                        ),
                        onRename: () => onRenamePath(path),
                        onDelete: () => onDeletePath(path),
                        onShare: () => onSharePath(
                          path,
                          _tasksForPath(path),
                        ),
                        onOpen: () {
                          _handleExpand();
                          onOpenPath(path);
                        },
                      ),
                      const SizedBox(height: calendarInsetMd),
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
                        onReorder: (oldIndex, newIndex) => _handleReorder(
                          reorderTarget,
                          oldIndex,
                          newIndex,
                        ),
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
    return computeCriticalPathProgress(
      path: path,
      tasks: tasks,
    );
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
    return progress.total > 0 && progress.completed >= progress.total;
  }

  void _handleReorder(
    CalendarCriticalPath path,
    int oldIndex,
    int newIndex,
  ) {
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
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final double progressValue =
        progress.total == 0 ? 0 : progress.completed / progress.total;
    final BorderRadius radius = BorderRadius.circular(calendarBorderRadius);
    final bool highlighted = isFocused || isActive;
    final Color borderColor = highlighted ? colors.primary : colors.border;
    final double borderWidth = highlighted ? 1.5 : 1;
    final Color backgroundColor = isActive
        ? colors.primary.withValues(alpha: 0.08)
        : colors.muted.withValues(alpha: 0.04);
    return InkWell(
      borderRadius: radius,
      mouseCursor: SystemMouseCursors.click,
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(calendarGutterMd),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    path.name,
                    style: context.textTheme.h4.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _PathActions(
                  onFocus: onFocus,
                  onRename: onRename,
                  onDelete: onDelete,
                  onShare: onShare,
                  isFocused: isFocused,
                ),
              ],
            ),
            const SizedBox(height: calendarInsetSm),
            Text(
              '${progress.completed} of ${progress.total} tasks completed in order',
              style: context.textTheme.muted.copyWith(fontSize: 12),
            ),
            const SizedBox(height: calendarInsetSm),
            Text(
              'Complete tasks in the listed order to advance',
              style: context.textTheme.muted.copyWith(fontSize: 11),
            ),
            const SizedBox(height: calendarInsetSm),
            _CriticalPathProgressBar(
              progressValue: progressValue,
              animationDuration: animationDuration,
            ),
          ],
        ),
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
                  'Progress',
                  style: context.textTheme.muted.copyWith(fontSize: 12),
                ),
                Text(
                  '$percent%',
                  style: context.textTheme.muted.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: calendarInsetSm),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(999),
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
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.isFocused,
  });

  final VoidCallback onFocus;
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: calendarGutterSm),
          child: ShadButton.secondary(
            size: ShadButtonSize.sm,
            onPressed: widget.onFocus,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isFocused ? Icons.visibility_off : Icons.visibility,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: calendarInsetLg),
                Text(widget.isFocused ? 'Unfocus' : 'Focus'),
              ],
            ),
          ).withTapBounce(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: calendarInsetMd),
          child: AxiPopover(
            controller: _menuController,
            closeOnTapOutside: true,
            padding: EdgeInsets.zero,
            popover: (context) {
              return AxiMenu(
                actions: [
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
                    label: _criticalPathShareActionLabel,
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
              buttonSize: 40,
              tapTargetSize: 48,
              iconSize: 20,
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
  }) taskTileBuilder;
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
        const SizedBox(height: calendarGutterSm),
        Row(
          children: [
            Text(
              context.l10n.calendarCriticalPathTaskOrderTitle,
              style: textTheme.h4.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (onAddTask != null)
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: onAddTask,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 14),
                    const SizedBox(width: calendarInsetSm),
                    Text(context.l10n.calendarCriticalPathAddTask),
                  ],
                ),
              ).withTapBounce(),
          ],
        ),
        const SizedBox(height: calendarInsetSm),
        Text(
          context.l10n.calendarCriticalPathDragHint,
          style: textTheme.muted,
        ),
        const SizedBox(height: calendarGutterSm),
        if (tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(calendarGutterMd),
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
            proxyDecorator: (child, __, ___) {
              return Material(
                color: Colors.transparent,
                child: child,
              );
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
      height: 36,
      width: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.drag_indicator,
            size: 18,
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
  const CriticalPathProgress({required this.total, required this.completed});

  final int total;
  final int completed;
}

CriticalPathProgress computeCriticalPathProgress({
  required CalendarCriticalPath path,
  required Map<String, CalendarTask> tasks,
}) {
  final int total = path.taskIds.length;
  int completed = 0;
  for (final String id in path.taskIds) {
    final String baseId = baseTaskIdFrom(id);
    final CalendarTask? task = tasks[baseId] ?? tasks[id];
    if (task == null || !task.isCompleted) {
      break;
    }
    completed += 1;
  }
  return CriticalPathProgress(
    total: total,
    completed: completed,
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
      spacing: calendarInsetSm,
      runSpacing: calendarInsetSm,
      children: paths
          .map(
            (path) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: calendarInsetMd,
                vertical: calendarInsetSm,
              ),
              decoration: BoxDecoration(
                color: colors.muted.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(calendarBorderRadius),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.route,
                    size: 14,
                    color: colors.mutedForeground,
                  ),
                  const SizedBox(width: calendarInsetSm),
                  Text(
                    path.name,
                    style: textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onRemovePath != null) ...[
                    const SizedBox(width: calendarInsetSm),
                    AxiIconButton(
                      iconData: Icons.close,
                      iconSize: 14,
                      buttonSize: 28,
                      tapTargetSize: 32,
                      backgroundColor: Colors.transparent,
                      borderColor: Colors.transparent,
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

Future<CriticalPathPickerResult?> showCriticalPathPicker({
  required BuildContext context,
  required List<CalendarCriticalPath> paths,
  bool stayOpen = false,
  Future<String?> Function(CalendarCriticalPath path)? onPathSelected,
  Future<String?> Function()? onCreateNewPath,
}) {
  final colors = context.colorScheme;
  final textTheme = context.textTheme;
  return showAdaptiveBottomSheet<CriticalPathPickerResult>(
    context: context,
    dialogMaxWidth: 420,
    surfacePadding: const EdgeInsets.all(calendarGutterLg),
    showCloseButton: false,
    builder: (sheetContext) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.sizeOf(context).height;
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : screenHeight;
          final listViewportHeight = availableHeight * 0.7;
          final ValueNotifier<String?> statusNotifier =
              ValueNotifier<String?>(null);
          final ValueNotifier<bool> busyNotifier = ValueNotifier<bool>(false);

          return SafeArea(
            top: true,
            bottom: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth,
                maxHeight: availableHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        context.l10n.calendarCriticalPathAddToTitle,
                        style: textTheme.h3.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      AxiIconButton(
                        iconData: LucideIcons.x,
                        tooltip: MaterialLocalizations.of(sheetContext)
                            .closeButtonTooltip,
                        iconSize: 16,
                        buttonSize: 34,
                        tapTargetSize: 40,
                        backgroundColor: Colors.transparent,
                        borderColor: Colors.transparent,
                        color: colors.mutedForeground,
                        onPressed: () => Navigator.of(sheetContext).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: calendarGutterMd),
                  if (paths.isEmpty) ...[
                    Text(
                      context.l10n.calendarCriticalPathCreatePrompt,
                      style: textTheme.muted,
                    ),
                    const SizedBox(height: calendarGutterMd),
                  ] else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: listViewportHeight,
                      ),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: busyNotifier,
                        builder: (context, isBusy, _) {
                          return Scrollbar(
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: paths.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: calendarInsetSm),
                              itemBuilder: (_, index) {
                                final path = paths[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(
                                    calendarBorderRadius.toDouble(),
                                  ),
                                  mouseCursor: SystemMouseCursors.click,
                                  onTap: isBusy
                                      ? null
                                      : () async {
                                          if (stayOpen &&
                                              onPathSelected != null) {
                                            busyNotifier.value = true;
                                            final String? status =
                                                await onPathSelected(path);
                                            if (!sheetContext.mounted) {
                                              return;
                                            }
                                            busyNotifier.value = false;
                                            statusNotifier.value = status ??
                                                'Added to ${path.name}';
                                            return;
                                          }
                                          Navigator.of(sheetContext).pop(
                                            CriticalPathPickerResult.path(
                                              path.id,
                                            ),
                                          );
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: calendarGutterMd,
                                      vertical: calendarInsetMd,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.card,
                                      borderRadius: BorderRadius.circular(
                                        calendarBorderRadius.toDouble(),
                                      ),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: colors.muted.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.route,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: calendarGutterSm),
                                        Expanded(
                                          child: Text(
                                            path.name,
                                            style: textTheme.small.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: colors.mutedForeground,
                                        ),
                                      ],
                                    ),
                                  ),
                                ).withTapBounce(enabled: !isBusy);
                              },
                            ),
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
                        padding: const EdgeInsets.only(
                          top: calendarGutterSm,
                          bottom: calendarGutterSm,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(calendarInsetMd),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(calendarBorderRadius),
                            border: Border.all(color: colors.primary),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(width: calendarInsetSm),
                              Expanded(
                                child: Text(
                                  status,
                                  style: textTheme.small.copyWith(
                                    fontWeight: FontWeight.w700,
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
                  const SizedBox(height: calendarGutterLg),
                  ShadButton.ghost(
                    onPressed: () async {
                      final bool isBusy = busyNotifier.value;
                      if (isBusy) {
                        return;
                      }
                      if (stayOpen && onCreateNewPath != null) {
                        busyNotifier.value = true;
                        final String? status = await onCreateNewPath();
                        if (!sheetContext.mounted) {
                          return;
                        }
                        busyNotifier.value = false;
                        if (status != null) {
                          statusNotifier.value = status;
                        }
                        return;
                      }
                      Navigator.of(sheetContext).pop(
                        const CriticalPathPickerResult.createNew(),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 16),
                        const SizedBox(width: calendarInsetSm),
                        Text(context.l10n.calendarCriticalPathsNew),
                      ],
                    ),
                  ).withTapBounce(),
                ],
              ),
            ),
          );
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
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final result = await showAdaptiveBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    dialogMaxWidth: 420,
    surfacePadding: const EdgeInsets.all(calendarGutterLg),
    showCloseButton: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final colors = context.colorScheme;
          final textTheme = context.textTheme;
          final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
          FocusScope.of(dialogContext).requestFocus(focusNode);
          return SafeArea(
            top: true,
            bottom: true,
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.disabled,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: textTheme.h3.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AxiIconButton(
                        iconData: LucideIcons.x,
                        tooltip: MaterialLocalizations.of(dialogContext)
                            .closeButtonTooltip,
                        iconSize: 16,
                        buttonSize: 34,
                        tapTargetSize: 40,
                        backgroundColor: Colors.transparent,
                        borderColor: Colors.transparent,
                        color: colors.mutedForeground,
                        onPressed: () => Navigator.of(dialogContext).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: calendarGutterSm),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: keyboardInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.calendarCriticalPathNamePrompt,
                            style: textTheme.muted,
                          ),
                          const SizedBox(height: calendarGutterSm),
                          AxiTextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            placeholder: Text(
                              context.l10n.calendarCriticalPathNamePlaceholder,
                            ),
                            validator: (value) {
                              final String trimmed = value.trim();
                              if (trimmed.isEmpty) {
                                return context
                                    .l10n.calendarCriticalPathNameEmptyError;
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
                  const SizedBox(height: calendarGutterMd),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ShadButton.outline(
                        onPressed: () => Navigator.of(dialogContext).maybePop(),
                        child: Text(context.l10n.commonCancel),
                      ).withTapBounce(),
                      const SizedBox(width: calendarInsetSm),
                      ShadButton(
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            focusNode.requestFocus();
                            return;
                          }
                          Navigator.of(dialogContext)
                              .pop(controller.text.trim());
                        },
                        child: Text(context.l10n.commonSave),
                      ).withTapBounce(),
                    ],
                  ),
                ],
              ),
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

Future<void> addTaskToCriticalPath({
  required BuildContext context,
  required BaseCalendarBloc bloc,
  required CalendarTask task,
}) async {
  await addTasksToCriticalPath(
    context: context,
    bloc: bloc,
    tasks: [task],
  );
}

Future<void> addTasksToCriticalPath({
  required BuildContext context,
  required BaseCalendarBloc bloc,
  required List<CalendarTask> tasks,
}) async {
  if (tasks.isEmpty) return;

  final CriticalPathPickerResult? result = await showCriticalPathPicker(
    context: context,
    paths: bloc.state.criticalPaths,
    stayOpen: true,
    onPathSelected: (path) async {
      for (final CalendarTask task in tasks) {
        bloc.add(
          CalendarEvent.criticalPathTaskAdded(
            pathId: path.id,
            taskId: task.id,
          ),
        );
      }
      return 'Added to "${path.name}"';
    },
    onCreateNewPath: () async {
      final String? name = await promptCriticalPathName(
        context: context,
        title: context.l10n.calendarCriticalPathsNew,
      );
      if (!context.mounted || name == null) {
        return null;
      }
      final Set<String> previousIds =
          bloc.state.criticalPaths.map((path) => path.id).toSet();
      bloc.add(
        CalendarEvent.criticalPathCreated(
          name: name,
          taskId: tasks.first.id,
        ),
      );
      final String? createdId = await waitForNewPathId(
        bloc: bloc,
        previousIds: previousIds,
      );
      if (createdId == null) {
        return null;
      }
      for (final CalendarTask task in tasks.skip(1)) {
        bloc.add(
          CalendarEvent.criticalPathTaskAdded(
            pathId: createdId,
            taskId: task.id,
          ),
        );
      }
      return 'Created "$name" and added task${tasks.length > 1 ? 's' : ''}.';
    },
  );
  if (!context.mounted) {
    return;
  }
  if (result == null) {
    return;
  }

  if (result.createNew) {
    final String? name = await promptCriticalPathName(
      context: context,
      title: context.l10n.calendarCriticalPathsNew,
    );
    if (!context.mounted) {
      return;
    }
    if (name == null) {
      return;
    }
    return;
  }

  final String? pathId = result.pathId;
  if (pathId == null) {
    return;
  }
  for (final CalendarTask task in tasks) {
    bloc.add(
      CalendarEvent.criticalPathTaskAdded(
        pathId: pathId,
        taskId: task.id,
      ),
    );
  }
}

Future<String?> waitForNewPathId({
  required BaseCalendarBloc bloc,
  required Set<String> previousIds,
}) async {
  try {
    final Set<String> updatedIds = await bloc.stream
        .map(
          (state) => state.criticalPaths.map((path) => path.id).toSet(),
        )
        .firstWhere((ids) => ids.length > previousIds.length)
        .timeout(const Duration(seconds: 2));
    final Set<String> difference = updatedIds.difference(previousIds);
    return difference.isNotEmpty ? difference.first : null;
  } on TimeoutException {
    return null;
  }
}
