import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../common/ui/ui.dart';
import '../../models/calendar_critical_path.dart';
import '../../models/calendar_task.dart';
import '../../utils/recurrence_utils.dart';

class CriticalPathPanel extends StatelessWidget {
  const CriticalPathPanel({
    super.key,
    required this.paths,
    required this.tasks,
    required this.focusedPathId,
    required this.onCreatePath,
    required this.onRenamePath,
    required this.onDeletePath,
    required this.onFocusPath,
    required this.animationDuration,
  });

  final List<CalendarCriticalPath> paths;
  final Map<String, CalendarTask> tasks;
  final String? focusedPathId;
  final VoidCallback onCreatePath;
  final void Function(CalendarCriticalPath path) onRenamePath;
  final void Function(CalendarCriticalPath path) onDeletePath;
  final void Function(CalendarCriticalPath? path) onFocusPath;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final bool hasPaths = paths.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: colors.border),
      ),
      padding: calendarPaddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Critical Paths',
                style: context.textTheme.muted.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (focusedPathId != null)
                Padding(
                  padding: const EdgeInsets.only(right: calendarInsetSm),
                  child: ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => onFocusPath(null),
                    child: const Text('Show all'),
                  ),
                ),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: onCreatePath,
                child: const Text('New path'),
              ),
            ],
          ),
          const SizedBox(height: calendarGutterMd),
          if (!hasPaths)
            Text(
              'No critical paths yet. Create one to track must-do sequences.',
              style: context.textTheme.muted,
            )
          else ...[
            for (final CalendarCriticalPath path in paths) ...[
              CriticalPathCard(
                path: path,
                animationDuration: animationDuration,
                isFocused: focusedPathId == path.id,
                progress: _progressFor(path),
                onFocus: () =>
                    onFocusPath(focusedPathId == path.id ? null : path),
                onRename: () => onRenamePath(path),
                onDelete: () => onDeletePath(path),
              ),
              const SizedBox(height: calendarInsetMd),
            ],
          ],
        ],
      ),
    );
  }

  CriticalPathProgress _progressFor(CalendarCriticalPath path) {
    final int total = path.taskIds.length;
    var completed = 0;
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
}

class CriticalPathCard extends StatelessWidget {
  const CriticalPathCard({
    super.key,
    required this.path,
    required this.progress,
    required this.isFocused,
    required this.onFocus,
    required this.onRename,
    required this.onDelete,
    required this.animationDuration,
  });

  final CalendarCriticalPath path;
  final CriticalPathProgress progress;
  final bool isFocused;
  final VoidCallback onFocus;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final double progressValue =
        progress.total == 0 ? 0 : progress.completed / progress.total;
    return Container(
      padding: const EdgeInsets.all(calendarGutterMd),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(
          color: isFocused ? colors.primary : colors.border,
          width: isFocused ? 1.5 : 1,
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

class _PathActions extends StatelessWidget {
  const _PathActions({
    required this.onFocus,
    required this.onRename,
    required this.onDelete,
    required this.isFocused,
  });

  final VoidCallback onFocus;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadButton.secondary(
          size: ShadButtonSize.sm,
          onPressed: onFocus,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFocused ? Icons.visibility_off : Icons.visibility,
                size: 14,
                color: colors.primary,
              ),
              const SizedBox(width: calendarInsetSm),
              Text(isFocused ? 'Unfocus' : 'Focus'),
            ],
          ),
        ),
        const SizedBox(width: calendarInsetSm),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename':
                onRename();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'rename',
              child: Text('Rename'),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(
                'Delete',
                style: TextStyle(color: colors.destructive),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.all(calendarInsetSm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Icon(
              Icons.more_horiz,
              size: 18,
              color: colors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

class CriticalPathProgress {
  const CriticalPathProgress({required this.total, required this.completed});

  final int total;
  final int completed;
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
}) {
  return showModalBottomSheet<CriticalPathPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(calendarGutterLg),
          child: Container(
            decoration: BoxDecoration(
              color: context.colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colorScheme.border),
            ),
            padding: const EdgeInsets.all(calendarGutterLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add to critical path',
                  style: context.textTheme.h3.copyWith(fontSize: 16),
                ),
                const SizedBox(height: calendarGutterMd),
                if (paths.isEmpty)
                  Text(
                    'Create a critical path to start tracking dependencies.',
                    style: context.textTheme.muted,
                  )
                else
                  ...paths.map(
                    (path) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(path.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(sheetContext).pop(
                        CriticalPathPickerResult.path(path.id),
                      ),
                    ),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add),
                  title: const Text('New critical path'),
                  onTap: () => Navigator.of(sheetContext).pop(
                    const CriticalPathPickerResult.createNew(),
                  ),
                ),
              ],
            ),
          ),
        ),
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
  String? errorText;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Path name',
                errorText: errorText,
              ),
              onSubmitted: (value) {
                final String trimmed = value.trim();
                if (trimmed.isEmpty) {
                  setState(() => errorText = 'Name cannot be empty');
                  return;
                }
                Navigator.of(dialogContext).pop(trimmed);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).maybePop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final String trimmed = controller.text.trim();
                  if (trimmed.isEmpty) {
                    setState(() => errorText = 'Name cannot be empty');
                    return;
                  }
                  Navigator.of(dialogContext).pop(trimmed);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  if (result == null || result.trim().isEmpty) {
    return null;
  }
  return result.trim();
}
