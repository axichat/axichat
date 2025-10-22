import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/calendar_task.dart';
import '../controllers/task_interaction_controller.dart';
import '../layout/calendar_layout.dart';
import '../resizable_task_widget.dart' show TaskContextMenuBuilder;
import 'calendar_task_geometry.dart';
import 'calendar_task_surface.dart';

typedef CalendarTaskTileCallbacksFactory = CalendarTaskTileCallbacks Function(
  CalendarTask task,
);

typedef CalendarTaskContextMenuDelegate = TaskContextMenuBuilder Function(
  CalendarTask task,
  ShadPopoverController controller,
);

typedef TaskPopoverLayoutRequester = void Function(String taskId);

class CalendarTaskLayer extends StatelessWidget {
  const CalendarTaskLayer({
    super.key,
    required this.day,
    required this.isDayView,
    required this.startHour,
    required this.endHour,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.tasks,
    required this.layoutCalculator,
    required this.layoutMetrics,
    required this.dayWidth,
    required this.interactionController,
    required this.callbacksFactory,
    required this.registerVisibleTask,
    required this.updateVisibleBounds,
    required this.isSelectionMode,
    required this.isTaskSelected,
    required this.isPopoverOpen,
    required this.dragTargetKeyForTask,
    required this.requestPopoverLayoutUpdate,
    required this.contextMenuDelegate,
    required this.contextMenuGroupId,
    required this.splitPreviewAnimationDuration,
    required this.stepHeight,
    required this.minutesPerStep,
    required this.hourHeight,
    required this.visibleTaskIds,
    this.draggingTaskId,
  });

  final DateTime day;
  final bool isDayView;
  final int startHour;
  final int endHour;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final List<CalendarTask> tasks;
  final CalendarLayoutCalculator layoutCalculator;
  final CalendarLayoutMetrics layoutMetrics;
  final double dayWidth;
  final TaskInteractionController interactionController;
  final CalendarTaskTileCallbacksFactory callbacksFactory;
  final void Function(CalendarTask task) registerVisibleTask;
  final void Function(String taskId, Rect bounds) updateVisibleBounds;
  final bool isSelectionMode;
  final bool Function(CalendarTask task) isTaskSelected;
  final bool Function(String taskId) isPopoverOpen;
  final GlobalKey Function(String taskId) dragTargetKeyForTask;
  final TaskPopoverLayoutRequester requestPopoverLayoutUpdate;
  final CalendarTaskContextMenuDelegate contextMenuDelegate;
  final ValueKey<String> contextMenuGroupId;
  final Duration splitPreviewAnimationDuration;
  final double stepHeight;
  final int minutesPerStep;
  final double hourHeight;
  final Set<String> visibleTaskIds;
  final String? draggingTaskId;

  @override
  Widget build(BuildContext context) {
    final List<CalendarTask> scheduledTasks =
        tasks.where((task) => task.scheduledTime != null).toList();
    if (scheduledTasks.isEmpty || dayWidth <= 0) {
      return const SizedBox.shrink();
    }

    final Map<String, OverlapInfo> overlapMap =
        calculateOverlapColumns(scheduledTasks);
    final Map<String, CalendarTaskGeometry> geometryMap =
        <String, CalendarTaskGeometry>{};
    final List<Widget> children = <Widget>[];

    for (final CalendarTask task in scheduledTasks) {
      registerVisibleTask(task);
      visibleTaskIds.add(task.id);

      final bool skipTask = draggingTaskId != null &&
          draggingTaskId == task.id &&
          interactionController.dragHasMoved;
      if (skipTask) {
        continue;
      }

      final OverlapInfo overlapInfo = overlapMap[task.id] ??
          const OverlapInfo(columnIndex: 0, totalColumns: 1);

      final CalendarTaskLayout? layout = layoutCalculator.resolveTaskLayout(
        task: task,
        dayDate: day,
        weekStartDate: weekStartDate,
        weekEndDate: weekEndDate,
        isDayView: isDayView,
        startHour: startHour,
        endHour: endHour,
        dayWidth: dayWidth,
        metrics: layoutMetrics,
        overlap: overlapInfo,
      );

      if (layout == null || layout.width <= 0 || layout.height <= 0) {
        continue;
      }

      final double narrowedWidth =
          layoutCalculator.computeNarrowedWidth(dayWidth, layout.width);
      final double splitWidthFactor = layout.width == 0
          ? 0.0
          : math.max(0.0, math.min(1.0, narrowedWidth / layout.width));
      final Rect rect = Rect.fromLTWH(
        layout.left,
        layout.top,
        layout.width,
        layout.height,
      );

      final geometry = CalendarTaskGeometry(
        rect: rect,
        narrowedWidth: narrowedWidth,
        splitWidthFactor: splitWidthFactor,
      );
      geometryMap[task.id] = geometry;

      final bindings = CalendarTaskEntryBindings(
        isSelectionMode: isSelectionMode,
        isSelected: isTaskSelected(task),
        isPopoverOpen: isPopoverOpen(task.id),
        dragTargetKey: dragTargetKeyForTask(task.id),
        splitPreviewAnimationDuration: splitPreviewAnimationDuration,
        contextMenuGroupId: contextMenuGroupId,
        contextMenuBuilderFactory: (menuController) =>
            contextMenuDelegate(task, menuController),
        interactionController: interactionController,
        dragFeedbackHint: interactionController.feedbackHint,
        callbacks: callbacksFactory(task),
        updateBounds: (rect) => updateVisibleBounds(task.id, rect),
        stepHeight: stepHeight,
        minutesPerStep: minutesPerStep,
        hourHeight: hourHeight,
        schedulePopoverLayoutUpdate: () =>
            requestPopoverLayoutUpdate(task.id),
        geometry: geometry,
      );

      children.add(
        _CalendarTaskEntryWidget(
          key: ValueKey<String>('calendar-task-${task.id}'),
          task: task,
          bindings: bindings,
          geometry: geometry,
          child: CalendarTaskSurface(
            task: task,
            isDayView: isDayView,
            bindings: bindings,
          ),
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return _CalendarTaskLayerRenderWidget(
      day: day,
      isDayView: isDayView,
      startHour: startHour,
      endHour: endHour,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      layoutMetrics: layoutMetrics,
      geometryMap: geometryMap,
      children: children,
    );
  }
}

class _CalendarTaskLayerRenderWidget extends MultiChildRenderObjectWidget {
  const _CalendarTaskLayerRenderWidget({
    required List<Widget> children,
    required this.day,
    required this.isDayView,
    required this.startHour,
    required this.endHour,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.layoutMetrics,
    required this.geometryMap,
  }) : super(children: children);

  final DateTime day;
  final bool isDayView;
  final int startHour;
  final int endHour;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final CalendarLayoutMetrics layoutMetrics;
  final Map<String, CalendarTaskGeometry> geometryMap;

  @override
  RenderCalendarTaskLayer createRenderObject(BuildContext context) {
    return RenderCalendarTaskLayer(
      day: day,
      isDayView: isDayView,
      startHour: startHour,
      endHour: endHour,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      layoutMetrics: layoutMetrics,
      geometryMap: geometryMap,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCalendarTaskLayer renderObject,
  ) {
    renderObject
      ..day = day
      ..isDayView = isDayView
      ..startHour = startHour
      ..endHour = endHour
      ..weekStartDate = weekStartDate
      ..weekEndDate = weekEndDate
      ..layoutMetrics = layoutMetrics
      ..geometryMap = geometryMap;
  }
}

class _CalendarTaskEntryWidget
    extends ParentDataWidget<CalendarTaskParentData> {
  const _CalendarTaskEntryWidget({
    super.key,
    required this.task,
    required this.bindings,
    required this.geometry,
    required Widget child,
  }) : super(child: child);

  final CalendarTask task;
  final CalendarTaskEntryBindings bindings;
  final CalendarTaskGeometry geometry;

  @override
  Type get debugTypicalAncestorWidgetClass => _CalendarTaskLayerRenderWidget;

  @override
  void applyParentData(RenderObject renderObject) {
    final CalendarTaskParentData parentData =
        renderObject.parentData as CalendarTaskParentData;
    bool needsLayout = false;

    if (parentData.task != task) {
      parentData.task = task;
      needsLayout = true;
    }

    if (!identical(parentData.bindings, bindings)) {
      parentData.bindings = bindings;
    }

    if (parentData.geometry != geometry) {
      parentData.geometry = geometry;
      needsLayout = true;
    }

    if (needsLayout) {
      (renderObject.parent as RenderObject?)?.markNeedsLayout();
    }
  }
}

class CalendarTaskParentData extends ContainerBoxParentData<RenderBox> {
  CalendarTask? task;
  CalendarTaskEntryBindings? bindings;
  CalendarTaskGeometry? geometry;
}

class RenderCalendarTaskLayer extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CalendarTaskParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CalendarTaskParentData> {
  RenderCalendarTaskLayer({
    required DateTime day,
    required bool isDayView,
    required int startHour,
    required int endHour,
    required DateTime weekStartDate,
    required DateTime weekEndDate,
    required CalendarLayoutMetrics layoutMetrics,
    required Map<String, CalendarTaskGeometry> geometryMap,
  })  : _day = day,
        _isDayView = isDayView,
        _startHour = startHour,
        _endHour = endHour,
        _weekStartDate = weekStartDate,
        _weekEndDate = weekEndDate,
        _layoutMetrics = layoutMetrics,
        _geometryMap = geometryMap;

  DateTime get day => _day;
  DateTime _day;
  set day(DateTime value) {
    if (_day == value) return;
    _day = value;
    markNeedsLayout();
  }

  bool get isDayView => _isDayView;
  bool _isDayView;
  set isDayView(bool value) {
    if (_isDayView == value) return;
    _isDayView = value;
    markNeedsLayout();
  }

  int get startHour => _startHour;
  int _startHour;
  set startHour(int value) {
    if (_startHour == value) return;
    _startHour = value;
    markNeedsLayout();
  }

  int get endHour => _endHour;
  int _endHour;
  set endHour(int value) {
    if (_endHour == value) return;
    _endHour = value;
    markNeedsLayout();
  }

  DateTime get weekStartDate => _weekStartDate;
  DateTime _weekStartDate;
  set weekStartDate(DateTime value) {
    if (_weekStartDate == value) return;
    _weekStartDate = value;
    markNeedsLayout();
  }

  DateTime get weekEndDate => _weekEndDate;
  DateTime _weekEndDate;
  set weekEndDate(DateTime value) {
    if (_weekEndDate == value) return;
    _weekEndDate = value;
    markNeedsLayout();
  }

  CalendarLayoutMetrics get layoutMetrics => _layoutMetrics;
  CalendarLayoutMetrics _layoutMetrics;
  set layoutMetrics(CalendarLayoutMetrics value) {
    if (_layoutMetrics == value) return;
    _layoutMetrics = value;
    markNeedsLayout();
  }

  Map<String, CalendarTaskGeometry> get geometryMap => _geometryMap;
  Map<String, CalendarTaskGeometry> _geometryMap;
  set geometryMap(Map<String, CalendarTaskGeometry> value) {
    if (identical(_geometryMap, value)) return;
    _geometryMap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! CalendarTaskParentData) {
      child.parentData = CalendarTaskParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    RenderBox? child = firstChild;
    while (child != null) {
      final CalendarTaskParentData childParentData =
          child.parentData as CalendarTaskParentData;
      final CalendarTask? task = childParentData.task;
      final CalendarTaskGeometry? geometry = task == null
          ? null
          : _geometryMap[task.id] ?? childParentData.geometry;

      if (geometry == null ||
          geometry.rect.width <= 0 ||
          geometry.rect.height <= 0) {
        child.layout(
          const BoxConstraints.tightFor(width: 0, height: 0),
          parentUsesSize: true,
        );
        childParentData.offset = Offset.zero;
        child = childAfter(child);
        continue;
      }

      child.layout(
        BoxConstraints.tight(geometry.rect.size),
        parentUsesSize: true,
      );

      childParentData.offset = geometry.rect.topLeft;
      childParentData.bindings?.updateBounds(geometry.rect);

      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
