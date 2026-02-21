// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/controllers/task_checklist_controller.dart';

import 'calendar_completion_checkbox.dart';
import 'task_form_section.dart';

class TaskChecklist extends StatefulWidget {
  const TaskChecklist({
    super.key,
    required this.controller,
    this.label = 'Checklist',
    this.addPlaceholder =
        'Add checklist item', // Note: overridden by callers with l10n
    this.enabled = true,
  });

  final TaskChecklistController controller;
  final String label;
  final String addPlaceholder;
  final bool enabled;

  @override
  State<TaskChecklist> createState() => _TaskChecklistState();
}

class _TaskChecklistState extends State<TaskChecklist> {
  final TextEditingController _newItemController = TextEditingController();
  final FocusNode _newItemFocusNode = FocusNode(
    debugLabel: 'taskChecklistAddItem',
  );
  final Map<String, TextEditingController> _itemControllers = {};
  bool _syncingPendingEntry = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncControllers);
    _newItemController.addListener(_handlePendingEntryChanged);
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant TaskChecklist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncControllers);
      widget.controller.addListener(_syncControllers);
      _syncControllers();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllers);
    _newItemController.removeListener(_handlePendingEntryChanged);
    _newItemController.dispose();
    _newItemFocusNode.dispose();
    for (final controller in _itemControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final Set<String> activeIds = widget.controller.items
        .map((item) => item.id)
        .toSet();
    final List<String> staleIds = _itemControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _itemControllers.remove(id)?.dispose();
    }
    for (final item in widget.controller.items) {
      final existing = _itemControllers[item.id];
      if (existing == null) {
        _itemControllers[item.id] = TextEditingController(text: item.label);
      } else if (existing.text != item.label) {
        existing.value = TextEditingValue(
          text: item.label,
          selection: TextSelection.collapsed(offset: item.label.length),
        );
      }
    }
    final pendingEntry = widget.controller.pendingEntry;
    if (_newItemController.text != pendingEntry) {
      _syncingPendingEntry = true;
      _newItemController.value = TextEditingValue(
        text: pendingEntry,
        selection: TextSelection.collapsed(offset: pendingEntry.length),
      );
      _syncingPendingEntry = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handlePendingEntryChanged() {
    if (_syncingPendingEntry) {
      return;
    }
    widget.controller.setPendingEntry(_newItemController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final items = widget.controller.items;
        final int total = items.length;
        final int completed = widget.controller.completedCount;
        final double progress = widget.controller.progress;

        final colors = context.colorScheme;
        final textTheme = context.textTheme;
        final List<String> membership = List<String>.from(
          items.map((item) => item.id),
          growable: false,
        )..sort();

        final Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TaskSectionDivider(),
            TaskSectionHeader(
              title: widget.label,
              trailing: total > 0
                  ? Text('$completed / $total', style: textTheme.muted)
                  : null,
            ),
            if (items.isNotEmpty) ...[
              SizedBox(height: context.spacing.xxs),
              TaskChecklistProgressBar(
                progress: progress,
                activeColor: colors.primary,
                backgroundColor: colors.border.withValues(alpha: 0.55),
              ),
            ],
            AnimatedSize(
              duration: baseAnimationDuration,
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: baseAnimationDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: items.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: context.spacing.xxs,
                        ),
                        child: ReorderableListView.builder(
                          key: ValueKey<String>(membership.join(';')),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorder: widget.controller.reorder,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _ChecklistItemRow(
                              key: ValueKey(item.id),
                              item: item,
                              controller: _itemControllers[item.id]!,
                              index: index,
                              onChanged: (value) =>
                                  widget.controller.toggleItem(item.id, value),
                              onLabelChanged: (value) =>
                                  widget.controller.updateLabel(item.id, value),
                              onRemove: () =>
                                  widget.controller.removeItem(item.id),
                            );
                          },
                        ),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: context.spacing.xxs),
              child: _ChecklistAddField(
                controller: _newItemController,
                placeholder: widget.addPlaceholder,
                focusNode: _newItemFocusNode,
                onSubmitted: () {
                  widget.controller.commitPendingEntry();
                  _newItemFocusNode.requestFocus();
                },
              ),
            ),
          ],
        );
        if (widget.enabled) {
          return content;
        }
        return IgnorePointer(child: content);
      },
    );
  }
}

class TaskChecklistProgressBar extends StatefulWidget {
  const TaskChecklistProgressBar({
    super.key,
    required this.progress,
    required this.activeColor,
    required this.backgroundColor,
  });

  final double progress;
  final Color activeColor;
  final Color backgroundColor;

  @override
  State<TaskChecklistProgressBar> createState() =>
      _TaskChecklistProgressBarState();
}

class _TaskChecklistProgressBarState extends State<TaskChecklistProgressBar> {
  late double _previousProgress;
  late double _targetProgress;

  @override
  void initState() {
    super.initState();
    _targetProgress = widget.progress.clamp(0.0, 1.0);
    _previousProgress = _targetProgress;
  }

  @override
  void didUpdateWidget(covariant TaskChecklistProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousProgress = _targetProgress;
    _targetProgress = widget.progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: baseAnimationDuration,
      tween: Tween<double>(begin: _previousProgress, end: _targetProgress),
      builder: (context, value, _) {
        final borderRadius = context.radius;
        final colors = context.colorScheme;
        const double trackMix = 0.08;
        final Color trackColor = Color.lerp(
          widget.backgroundColor,
          colors.foreground,
          trackMix,
        )!;
        final double barHeight = context.sizing.progressIndicatorBarHeight;
        return ShadProgress(
          value: value,
          minHeight: barHeight,
          backgroundColor: trackColor,
          color: widget.activeColor,
          borderRadius: borderRadius,
          innerBorderRadius: borderRadius,
        );
      },
    );
  }
}

class _ChecklistItemRow extends StatelessWidget {
  const _ChecklistItemRow({
    super.key,
    required this.item,
    required this.controller,
    required this.index,
    required this.onChanged,
    required this.onLabelChanged,
    required this.onRemove,
  });

  final TaskChecklistItem item;
  final TextEditingController controller;
  final int index;
  final ValueChanged<bool> onChanged;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final double iconSize = context.sizing.menuItemIconSize;
    final double buttonSize = context.sizing.inputSuffixButtonSize;
    final double tapTargetSize = context.sizing.menuItemHeight;
    final double cornerRadius = context.radii.container;
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CalendarCompletionCheckbox(
            value: item.isCompleted,
            onChanged: onChanged,
            size: iconSize,
          ),
          SizedBox(width: context.spacing.xxs),
          Expanded(
            child: AxiTextField(
              controller: controller,
              onChanged: onLabelChanged,
              style: textTheme.p,
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                hintText: context.l10n.calendarChecklistItem,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: context.spacing.xxs,
                ),
              ),
            ),
          ),
          AxiIconButton(
            iconData: Icons.close,
            iconSize: iconSize,
            buttonSize: buttonSize,
            tapTargetSize: tapTargetSize,
            backgroundColor: colors.muted.withValues(alpha: 0.08),
            borderColor: Colors.transparent,
            borderWidth: context.borderSide.width * 0,
            color: colors.mutedForeground,
            cornerRadius: cornerRadius,
            tooltip: context.l10n.calendarRemoveItem,
            onPressed: onRemove,
          ),
          SizedBox(width: context.spacing.xxs),
          MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.xxs),
                child: Icon(
                  Icons.drag_indicator,
                  size: context.sizing.menuItemIconSize,
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistAddField extends StatelessWidget {
  const _ChecklistAddField({
    required this.controller,
    required this.placeholder,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final double iconSize = context.sizing.menuItemIconSize;
    final double buttonSize = context.sizing.menuItemHeight;
    return Row(
      children: [
        AxiIconButton.ghost(
          iconData: Icons.add,
          iconSize: iconSize,
          buttonSize: buttonSize,
          tapTargetSize: buttonSize,
          color: colors.primary,
          cornerRadius: context.radii.squircle,
          tooltip: context.l10n.calendarAddChecklistItem,
          onPressed: onSubmitted,
        ),
        SizedBox(width: context.spacing.xxs),
        Expanded(
          child: AxiTextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (_) => onSubmitted(),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              isCollapsed: true,
              hintText: placeholder,
              hintStyle: context.textTheme.muted,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: context.spacing.xxs,
              ),
            ),
            style: context.textTheme.p,
          ),
        ),
      ],
    );
  }
}
