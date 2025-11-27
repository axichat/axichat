import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../common/ui/ui.dart';
import '../../models/calendar_critical_path.dart';
import '../../models/calendar_task.dart';
import '../../utils/recurrence_utils.dart';

class CriticalPathPanel extends StatefulWidget {
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
  State<CriticalPathPanel> createState() => _CriticalPathPanelState();
}

class _CriticalPathPanelState extends State<CriticalPathPanel> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _expand() {
    if (_isExpanded) {
      return;
    }
    setState(() {
      _isExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final bool hasPaths = widget.paths.isNotEmpty;
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
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: calendarInsetSm),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _isExpanded ? 0.25 : 0,
                    duration: widget.animationDuration,
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: calendarInsetSm),
                  Text(
                    'Critical Paths',
                    style: context.textTheme.muted.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () {
                      _expand();
                      widget.onCreatePath();
                    },
                    child: const Text('New path'),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedCrossFade(
              duration: widget.animationDuration,
              alignment: Alignment.topCenter,
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: calendarGutterMd),
                  if (!hasPaths)
                    Text(
                      'No critical paths yet. Create one to track must-do sequences.',
                      style: context.textTheme.muted,
                    )
                  else ...[
                    for (final CalendarCriticalPath path in widget.paths) ...[
                      CriticalPathCard(
                        path: path,
                        animationDuration: widget.animationDuration,
                        isFocused: widget.focusedPathId == path.id,
                        progress: _progressFor(path),
                        onFocus: () => widget.onFocusPath(
                          widget.focusedPathId == path.id ? null : path,
                        ),
                        onRename: () => widget.onRenamePath(path),
                        onDelete: () => widget.onDeletePath(path),
                      ),
                      const SizedBox(height: calendarInsetMd),
                    ],
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
    final int total = path.taskIds.length;
    var completed = 0;
    for (final String id in path.taskIds) {
      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? task = widget.tasks[baseId] ?? widget.tasks[id];
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

class _PathActions extends StatefulWidget {
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
                const SizedBox(width: calendarInsetSm),
                Text(widget.isFocused ? 'Unfocus' : 'Focus'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: calendarInsetMd),
          child: ShadPopover(
            controller: _menuController,
            closeOnTapOutside: true,
            padding: EdgeInsets.zero,
            popover: (context) {
              return Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(calendarBorderRadius),
                    border: Border.all(color: colors.border),
                    boxShadow: calendarElevation2,
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PathMenuItem(
                          icon: Icons.drive_file_rename_outline,
                          label: 'Rename',
                          onTap: () {
                            _closeMenu();
                            widget.onRename();
                          },
                        ),
                        Divider(
                          height: calendarBorderStroke,
                          thickness: calendarBorderStroke,
                          color: colors.border,
                        ),
                        _PathMenuItem(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          destructive: true,
                          onTap: () {
                            _closeMenu();
                            widget.onDelete();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
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

class _PathMenuItem extends StatelessWidget {
  const _PathMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color foreground =
        destructive ? colors.destructive : colors.foreground;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: calendarMenuItemPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: calendarGutterSm),
            Text(
              label,
              style: context.textTheme.small.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
  final colors = context.colorScheme;
  final textTheme = context.textTheme;
  return showAdaptiveBottomSheet<CriticalPathPickerResult>(
    context: context,
    dialogMaxWidth: 420,
    surfacePadding: const EdgeInsets.all(calendarGutterLg),
    builder: (sheetContext) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Add to critical path',
                style: textTheme.h3.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              AxiIconButton(
                iconData: Icons.close,
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
              'Create a critical path to start tracking dependencies.',
              style: textTheme.muted,
            ),
            const SizedBox(height: calendarGutterMd),
          ] else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Scrollbar(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: paths.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: calendarInsetSm),
                  itemBuilder: (_, index) {
                    final path = paths[index];
                    return ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      padding: const EdgeInsets.symmetric(
                        horizontal: calendarGutterMd,
                        vertical: calendarInsetMd,
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(
                        CriticalPathPickerResult.path(path.id),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.route, size: 16),
                          const SizedBox(width: calendarInsetMd),
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
                    );
                  },
                ),
              ),
            ),
          ShadButton(
            onPressed: () => Navigator.of(sheetContext).pop(
              const CriticalPathPickerResult.createNew(),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 16),
                SizedBox(width: calendarInsetSm),
                Text('New critical path'),
              ],
            ),
          ).withTapBounce(),
        ],
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
  String? errorText;
  final result = await showShadDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final colors = context.colorScheme;
          final textTheme = context.textTheme;
          FocusScope.of(dialogContext).requestFocus(focusNode);
          return ShadDialog(
            title: Text(
              title,
              style: textTheme.h4.copyWith(fontWeight: FontWeight.w700),
            ),
            actions: [
              ShadButton.outline(
                onPressed: () => Navigator.of(dialogContext).maybePop(),
                child: const Text('Cancel'),
              ).withTapBounce(),
              ShadButton(
                onPressed: () {
                  final String trimmed = controller.text.trim();
                  if (trimmed.isEmpty) {
                    setState(() => errorText = 'Name cannot be empty');
                    return;
                  }
                  Navigator.of(dialogContext).pop(trimmed);
                },
                child: const Text('Save'),
              ).withTapBounce(),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Name your critical path',
                  style: textTheme.muted,
                ),
                const SizedBox(height: calendarGutterSm),
                AxiTextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  placeholder: const Text('Path name'),
                  onSubmitted: (value) {
                    final String trimmed = value.trim();
                    if (trimmed.isEmpty) {
                      setState(() => errorText = 'Name cannot be empty');
                      return;
                    }
                    Navigator.of(dialogContext).pop(trimmed);
                  },
                ),
                if (errorText != null) ...[
                  const SizedBox(height: calendarInsetMd),
                  Text(
                    errorText!,
                    style: textTheme.small.copyWith(
                      color: colors.destructive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
