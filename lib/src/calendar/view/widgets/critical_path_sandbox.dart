import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'calendar_task_title_hover_reporter.dart';

class CriticalPathSandbox extends StatefulWidget {
  const CriticalPathSandbox({
    super.key,
    required this.path,
    required this.tasks,
    required this.onOrderChanged,
    required this.onExit,
  });

  final CalendarCriticalPath path;
  final Map<String, CalendarTask> tasks;
  final ValueChanged<List<String>> onOrderChanged;
  final VoidCallback onExit;

  @override
  State<CriticalPathSandbox> createState() => _CriticalPathSandboxState();
}

class _CriticalPathSandboxState extends State<CriticalPathSandbox> {
  static const double _slotSize = 84;
  static const double _centerWidth = 220;
  static const double _slotGap = calendarGutterMd;
  static const double _columnGap = calendarGutterLg;
  static const double _canvasBorderWidth = 3;

  late List<int> _columns;
  late Map<_SlotLocation, String?> _slotOccupants;
  late Map<String, _SlotLocation> _taskLocations;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant CriticalPathSandbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool pathChanged = oldWidget.path.id != widget.path.id;
    final bool orderChanged = !listEquals(
      _deriveOrder(),
      widget.path.taskIds,
    );
    if (pathChanged || orderChanged) {
      _bootstrap();
    }
  }

  void _bootstrap() {
    _columns = List<int>.generate(widget.path.taskIds.length, (index) => index);
    _slotOccupants = <_SlotLocation, String?>{};
    _taskLocations = <String, _SlotLocation>{};

    for (var i = 0; i < widget.path.taskIds.length; i++) {
      final String taskId = widget.path.taskIds[i];
      final _SlotLocation location = _SlotLocation(
        columnIndex: i,
        alignment: _SlotAlignment.center,
      );
      _slotOccupants[location] = taskId;
      _taskLocations[taskId] = location;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final ShadTextTheme textTheme = context.textTheme;
    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: calendarMarginLarge,
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(
              bottom: BorderSide(color: colors.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Critical path grid',
                      style: textTheme.h3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: calendarInsetSm),
                    Text(
                      context.l10n.calendarSandboxHint,
                      style: textTheme.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: calendarGutterMd),
              ShadButton.secondary(
                onPressed: widget.onExit,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grid_view, size: 16),
                    const SizedBox(width: calendarInsetLg),
                    Text(context.l10n.calendarBackToCalendar),
                  ],
                ),
              ).withTapBounce(),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colors.border,
                  width: _canvasBorderWidth,
                ),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(calendarGutterLg),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _columns
                      .map(
                        (index) => Padding(
                          padding: EdgeInsets.only(
                            right:
                                index == _columns.length - 1 ? 0 : _columnGap,
                          ),
                          child: _GridColumn(
                            columnIndex: index,
                            slotSize: _slotSize,
                            centerWidth: _centerWidth,
                            gap: _slotGap,
                            colors: colors,
                            textTheme: textTheme,
                            taskForLocation: _taskForLocation,
                            onAddRequested: (location) =>
                                _handleAddToSlot(location, isDesktop),
                            onTaskTapped: (location, task) =>
                                _handleTaskTapped(location, task, isDesktop),
                            onDropReceived: _handleDrop,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  CalendarTask? _taskForLocation(_SlotLocation location) {
    final String? taskId = _slotOccupants[location];
    return taskId != null ? widget.tasks[taskId] : null;
  }

  Future<void> _handleAddToSlot(
    _SlotLocation location,
    bool isDesktop,
  ) async {
    final List<CalendarTask> available = widget.tasks.values
        .where((task) => !_taskLocations.containsKey(task.id))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    if (!mounted) return;
    final CalendarTask? selected = await _showTaskPicker(
      available: available,
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _placeTask(taskId: selected.id, location: location);
    });
    _commitOrder();
  }

  Future<void> _handleTaskTapped(
    _SlotLocation location,
    CalendarTask task,
    bool isDesktop,
  ) async {
    final _SlotTapAction? action = await _showSlotActions();

    if (action == _SlotTapAction.remove) {
      _removeTaskFromSlot(location, task.id);
      return;
    }
    if (action == _SlotTapAction.replace) {
      await _handleAddToSlot(location, isDesktop);
    }
  }

  void _removeTaskFromSlot(_SlotLocation location, String taskId) {
    setState(() {
      _slotOccupants[location] = null;
      _taskLocations.remove(taskId);
    });
    _commitOrder();
  }

  void _handleDrop(_SlotLocation target, _DragPayload payload) {
    setState(() {
      final _SlotLocation source = payload.from;
      if (source == target) {
        return;
      }
      final String? sourceTask = _slotOccupants[source];
      final String? targetTask = _slotOccupants[target];
      _slotOccupants[source] = targetTask;
      _slotOccupants[target] = sourceTask;

      if (sourceTask != null) {
        _taskLocations[sourceTask] = target;
      }
      if (targetTask != null) {
        _taskLocations[targetTask] = source;
      } else {
        _taskLocations.removeWhere(
          (taskId, location) => location == source && taskId != sourceTask,
        );
      }
    });
    _commitOrder();
  }

  void _placeTask({
    required String taskId,
    required _SlotLocation location,
  }) {
    final _SlotLocation? previousLocation = _taskLocations[taskId];
    final String? displaced = _slotOccupants[location];

    if (previousLocation != null) {
      _slotOccupants[previousLocation] = displaced;
      if (displaced != null) {
        _taskLocations[displaced] = previousLocation;
      } else {
        _taskLocations.removeWhere(
          (id, loc) => loc == previousLocation && id != taskId,
        );
      }
    } else if (displaced != null) {
      _taskLocations.remove(displaced);
    }

    _slotOccupants[location] = taskId;
    _taskLocations[taskId] = location;
  }

  void _commitOrder() {
    widget.onOrderChanged(_deriveOrder());
  }

  List<String> _deriveOrder() {
    final Set<String> seen = <String>{};
    final List<String> ordered = <String>[];

    for (final int index in _columns) {
      final List<_SlotAlignment> sequence = <_SlotAlignment>[
        _SlotAlignment.left,
        _SlotAlignment.top,
        _SlotAlignment.center,
        _SlotAlignment.bottom,
        _SlotAlignment.right,
      ];
      for (final _SlotAlignment alignment in sequence) {
        final _SlotLocation location = _SlotLocation(
          columnIndex: index,
          alignment: alignment,
        );
        final String? taskId = _slotOccupants[location];
        if (taskId == null || seen.contains(taskId)) {
          continue;
        }
        seen.add(taskId);
        ordered.add(taskId);
      }
    }

    return ordered;
  }
}

class _SlotActionTile extends StatelessWidget {
  const _SlotActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final ShadTextTheme textTheme = context.textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(calendarBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(calendarGutterMd),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(calendarBorderRadius),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: colors.mutedForeground,
            ),
            const SizedBox(width: calendarGutterSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: calendarInsetSm),
                    Text(
                      subtitle!,
                      style: textTheme.muted,
                    ),
                  ],
                ],
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
    );
  }
}

class _GridColumn extends StatelessWidget {
  const _GridColumn({
    required this.columnIndex,
    required this.slotSize,
    required this.centerWidth,
    required this.gap,
    required this.colors,
    required this.textTheme,
    required this.taskForLocation,
    required this.onAddRequested,
    required this.onTaskTapped,
    required this.onDropReceived,
  });

  final int columnIndex;
  final double slotSize;
  final double centerWidth;
  final double gap;
  final ShadColorScheme colors;
  final ShadTextTheme textTheme;
  final CalendarTask? Function(_SlotLocation) taskForLocation;
  final Future<void> Function(_SlotLocation) onAddRequested;
  final void Function(_SlotLocation, CalendarTask) onTaskTapped;
  final void Function(_SlotLocation, _DragPayload) onDropReceived;

  @override
  Widget build(BuildContext context) {
    final _SlotLocation top = _SlotLocation(
      columnIndex: columnIndex,
      alignment: _SlotAlignment.top,
    );
    final _SlotLocation left = _SlotLocation(
      columnIndex: columnIndex,
      alignment: _SlotAlignment.left,
    );
    final _SlotLocation center = _SlotLocation(
      columnIndex: columnIndex,
      alignment: _SlotAlignment.center,
    );
    final _SlotLocation right = _SlotLocation(
      columnIndex: columnIndex,
      alignment: _SlotAlignment.right,
    );
    final _SlotLocation bottom = _SlotLocation(
      columnIndex: columnIndex,
      alignment: _SlotAlignment.bottom,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TaskSlot(
          location: top,
          label: context.l10n.calendarBranch,
          colors: colors,
          textTheme: textTheme,
          size: slotSize,
          task: taskForLocation(top),
          onAddRequested: onAddRequested,
          onTaskTapped: onTaskTapped,
          onDropReceived: onDropReceived,
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TaskSlot(
              location: left,
              label: context.l10n.commonPrevious,
              colors: colors,
              textTheme: textTheme,
              size: slotSize,
              task: taskForLocation(left),
              onAddRequested: onAddRequested,
              onTaskTapped: onTaskTapped,
              onDropReceived: onDropReceived,
            ),
            SizedBox(width: gap),
            _TaskSlot(
              location: center,
              label: 'Main task',
              colors: colors,
              textTheme: textTheme,
              width: centerWidth,
              height: slotSize + calendarInsetLg,
              task: taskForLocation(center),
              prominent: true,
              onAddRequested: onAddRequested,
              onTaskTapped: onTaskTapped,
              onDropReceived: onDropReceived,
            ),
            SizedBox(width: gap),
            _TaskSlot(
              location: right,
              label: context.l10n.commonNext,
              colors: colors,
              textTheme: textTheme,
              size: slotSize,
              task: taskForLocation(right),
              onAddRequested: onAddRequested,
              onTaskTapped: onTaskTapped,
              onDropReceived: onDropReceived,
            ),
          ],
        ),
        SizedBox(height: gap),
        _TaskSlot(
          location: bottom,
          label: context.l10n.calendarBranch,
          colors: colors,
          textTheme: textTheme,
          size: slotSize,
          task: taskForLocation(bottom),
          onAddRequested: onAddRequested,
          onTaskTapped: onTaskTapped,
          onDropReceived: onDropReceived,
        ),
      ],
    );
  }
}

class _TaskSlot extends StatelessWidget {
  const _TaskSlot({
    required this.location,
    required this.label,
    required this.colors,
    required this.textTheme,
    required this.onAddRequested,
    required this.onDropReceived,
    required this.onTaskTapped,
    this.task,
    this.size,
    this.width,
    this.height,
    this.prominent = false,
  });

  final _SlotLocation location;
  final String label;
  final ShadColorScheme colors;
  final ShadTextTheme textTheme;
  final CalendarTask? task;
  final double? size;
  final double? width;
  final double? height;
  final bool prominent;
  final Future<void> Function(_SlotLocation) onAddRequested;
  final void Function(_SlotLocation, _DragPayload) onDropReceived;
  final void Function(_SlotLocation, CalendarTask) onTaskTapped;

  @override
  Widget build(BuildContext context) {
    final double resolvedWidth =
        width ?? size ?? _CriticalPathSandboxState._slotSize;
    final double resolvedHeight =
        height ?? size ?? _CriticalPathSandboxState._slotSize;
    final bool hasTask = task != null;

    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        onDropReceived(location, details.data);
      },
      builder: (context, candidate, rejected) {
        final bool isActive = candidate.isNotEmpty;
        final Widget card = hasTask
            ? _DraggableTaskCard(
                task: task!,
                label: label,
                colors: colors,
                textTheme: textTheme,
                location: location,
                onTap: () => onTaskTapped(location, task!),
              )
            : _EmptySlot(
                label: label,
                colors: colors,
                textTheme: textTheme,
                onTap: () => onAddRequested(location),
              );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: resolvedWidth,
          height: resolvedHeight,
          padding: const EdgeInsets.all(calendarInsetSm),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withValues(alpha: 0.08)
                : hasTask
                    ? colors.card
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(prominent ? 14 : 12),
            border: Border.all(
              color: isActive
                  ? colors.primary
                  : hasTask
                      ? colors.border
                      : Colors.transparent,
              width: isActive
                  ? 1.8
                  : hasTask
                      ? 1
                      : 0,
            ),
          ),
          child: card,
        );
      },
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({
    required this.label,
    required this.colors,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final ShadColorScheme colors;
  final ShadTextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: _DashedBorder(
        color: colors.border,
        radius: 10,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: colors.mutedForeground, size: 18),
              const SizedBox(height: calendarInsetSm),
              Text(
                label,
                style: textTheme.small.copyWith(
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableTaskCard extends StatelessWidget {
  const _DraggableTaskCard({
    required this.task,
    required this.label,
    required this.colors,
    required this.textTheme,
    required this.location,
    this.onTap,
  });

  final CalendarTask task;
  final String label;
  final ShadColorScheme colors;
  final ShadTextTheme textTheme;
  final _SlotLocation location;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget card = _TaskCard(
      task: task,
      label: label,
      colors: colors,
      textTheme: textTheme,
      onTap: onTap,
    );

    return LongPressDraggable<_DragPayload>(
      data: _DragPayload(taskId: task.id, from: location),
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _CriticalPathSandboxState._centerWidth,
            minWidth: _CriticalPathSandboxState._slotSize,
          ),
          child: card,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: card,
      ),
      child: card,
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.label,
    required this.colors,
    required this.textTheme,
    this.onTap,
  });

  final CalendarTask task;
  final String label;
  final ShadColorScheme colors;
  final ShadTextTheme textTheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool completed = task.isCompleted;

    return CalendarTaskTitleHoverReporter(
      title: task.title,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(calendarInsetMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color:
                          completed ? colors.primary : colors.mutedForeground,
                    ),
                    const SizedBox(width: calendarInsetSm),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration:
                              completed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: calendarInsetSm),
                Text(
                  label,
                  style: textTheme.small.copyWith(
                    fontSize: 11,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  const _DashedBorder({
    required this.color,
    required this.radius,
    // ignore: unused_element_parameter
    this.thickness = 1,
    // ignore: unused_element_parameter
    this.gap = 6,
    this.child,
  });

  final Color color;
  final double radius;
  final double thickness;
  final double gap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: radius,
        thickness: thickness,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.thickness,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double thickness;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = math.min(distance + gap, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += gap * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.thickness != thickness ||
        oldDelegate.gap != gap;
  }
}

class _SlotLocation {
  const _SlotLocation({
    required this.columnIndex,
    required this.alignment,
  });

  final int columnIndex;
  final _SlotAlignment alignment;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _SlotLocation &&
        other.columnIndex == columnIndex &&
        other.alignment == alignment;
  }

  @override
  int get hashCode => Object.hash(columnIndex, alignment);
}

enum _SlotAlignment { left, right, top, bottom, center }

enum _SlotTapAction { replace, remove }

class _DragPayload {
  const _DragPayload({required this.taskId, required this.from});

  final String taskId;
  final _SlotLocation from;
}

extension on _CriticalPathSandboxState {
  Future<CalendarTask?> _showTaskPicker({
    required List<CalendarTask> available,
  }) {
    return showAdaptiveBottomSheet<CalendarTask>(
      context: context,
      dialogMaxWidth: 560,
      surfacePadding: const EdgeInsets.all(calendarGutterLg),
      showCloseButton: false,
      builder: (sheetContext) {
        final ShadTextTheme textTheme = sheetContext.textTheme;
        final ShadColorScheme colors = sheetContext.colorScheme;
        return SafeArea(
          top: true,
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add task to path',
                      style: textTheme.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
              const SizedBox(height: calendarGutterSm),
              if (available.isEmpty)
                Container(
                  padding: const EdgeInsets.all(calendarGutterMd),
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(calendarBorderRadius),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All tasks are placed already',
                        style: textTheme.h4,
                      ),
                      const SizedBox(height: calendarInsetMd),
                      Text(
                        'Drag a task off a slot first, then try again.',
                        style: textTheme.muted,
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: Scrollbar(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final CalendarTask task = available[index];
                        final DateTime? deadline = task.deadline?.toLocal();
                        final String? deadlineLabel = deadline != null
                            ? 'Deadline: ${deadline.toIso8601String().split('T').first}'
                            : null;
                        return CalendarTaskTitleHoverReporter(
                          title: task.title,
                          child: InkWell(
                            onTap: () => Navigator.of(sheetContext).pop(task),
                            borderRadius:
                                BorderRadius.circular(calendarBorderRadius),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: calendarGutterMd,
                                vertical: calendarInsetMd,
                              ),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(
                                  calendarBorderRadius,
                                ),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    task.isCompleted
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 20,
                                    color: task.isCompleted
                                        ? colors.primary
                                        : colors.mutedForeground,
                                  ),
                                  const SizedBox(width: calendarGutterSm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: textTheme.small.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (deadlineLabel != null) ...[
                                          const SizedBox(
                                            height: calendarInsetSm,
                                          ),
                                          Text(
                                            deadlineLabel,
                                            style: textTheme.muted,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.add,
                                    size: 18,
                                    color: colors.mutedForeground,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: calendarInsetSm),
                      itemCount: available.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<_SlotTapAction?> _showSlotActions() {
    return showAdaptiveBottomSheet<_SlotTapAction>(
      context: context,
      dialogMaxWidth: 440,
      surfacePadding: const EdgeInsets.all(calendarGutterLg),
      showCloseButton: false,
      builder: (sheetContext) {
        final ShadTextTheme textTheme = sheetContext.textTheme;
        final ShadColorScheme colors = sheetContext.colorScheme;
        return SafeArea(
          top: true,
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Slot options',
                      style: textTheme.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
              const SizedBox(height: calendarGutterSm),
              _SlotActionTile(
                icon: Icons.swap_horiz,
                title: 'Replace task',
                subtitle: context.l10n.calendarPickDifferentTask,
                onTap: () => Navigator.of(sheetContext).pop(
                  _SlotTapAction.replace,
                ),
              ),
              const SizedBox(height: calendarInsetSm),
              _SlotActionTile(
                icon: Icons.remove_circle_outline,
                title: 'Remove from path',
                onTap: () => Navigator.of(sheetContext).pop(
                  _SlotTapAction.remove,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
