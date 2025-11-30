import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/controllers/task_checklist_controller.dart';

import 'calendar_completion_checkbox.dart';

class TaskChecklist extends StatefulWidget {
  const TaskChecklist({
    super.key,
    required this.controller,
    this.label = 'Checklist',
    this.addPlaceholder = 'Add checklist item',
  });

  final TaskChecklistController controller;
  final String label;
  final String addPlaceholder;

  @override
  State<TaskChecklist> createState() => _TaskChecklistState();
}

class _TaskChecklistState extends State<TaskChecklist> {
  final TextEditingController _newItemController = TextEditingController();
  final Map<String, TextEditingController> _itemControllers = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncControllers);
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
    _newItemController.dispose();
    for (final controller in _itemControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final Set<String> activeIds =
        widget.controller.items.map((item) => item.id).toSet();
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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final items = widget.controller.items;
        final int total = items.length;
        final int completed = widget.controller.completedCount;
        final double progress = widget.controller.progress;

        return Container(
          padding: const EdgeInsets.all(calendarGutterMd),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    widget.label,
                    style: textTheme.h4.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (total > 0)
                    Text(
                      '$completed / $total',
                      style: textTheme.muted,
                    ),
                ],
              ),
              const SizedBox(height: calendarInsetMd),
              TaskChecklistProgressBar(
                progress: progress,
                activeColor: colors.primary,
                backgroundColor: colors.muted.withValues(alpha: 0.2),
              ),
              if (items.isNotEmpty) const SizedBox(height: calendarInsetMd),
              ...items.map((item) => _ChecklistItemRow(
                    item: item,
                    controller: _itemControllers[item.id]!,
                    onChanged: (value) =>
                        widget.controller.toggleItem(item.id, value),
                    onLabelChanged: (value) =>
                        widget.controller.updateLabel(item.id, value),
                    onRemove: () => widget.controller.removeItem(item.id),
                  )),
              _ChecklistAddField(
                controller: _newItemController,
                placeholder: widget.addPlaceholder,
                onSubmitted: () {
                  widget.controller.addItem(_newItemController.text);
                  _newItemController.clear();
                },
              ),
            ],
          ),
        );
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
      tween: Tween<double>(
        begin: _previousProgress,
        end: _targetProgress,
      ),
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: widget.backgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(widget.activeColor),
              minHeight: 6,
            ),
          ),
        );
      },
    );
  }
}

class _ChecklistItemRow extends StatelessWidget {
  const _ChecklistItemRow({
    required this.item,
    required this.controller,
    required this.onChanged,
    required this.onLabelChanged,
    required this.onRemove,
  });

  final TaskChecklistItem item;
  final TextEditingController controller;
  final ValueChanged<bool> onChanged;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: calendarInsetSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CalendarCompletionCheckbox(
            value: item.isCompleted,
            onChanged: onChanged,
            size: 18,
          ),
          const SizedBox(width: calendarInsetMd),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onLabelChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Checklist item',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: calendarGutterSm,
                  vertical: calendarInsetSm,
                ),
              ),
            ),
          ),
          const SizedBox(width: calendarInsetSm),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            splashRadius: 18,
            color: colors.muted,
            onPressed: onRemove,
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
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: placeholder,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: calendarGutterMd,
          vertical: calendarInsetSm,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.add),
          color: colors.primary,
          onPressed: onSubmitted,
        ),
      ),
    );
  }
}
