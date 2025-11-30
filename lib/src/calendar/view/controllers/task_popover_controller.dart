import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'package:axichat/src/common/ui/ui.dart';

class TaskPopoverLayout {
  const TaskPopoverLayout({
    required this.topLeft,
    required this.maxHeight,
  });

  final Offset topLeft;
  final double maxHeight;
}

TaskPopoverLayout defaultTaskPopoverLayout() => const TaskPopoverLayout(
      topLeft: Offset.zero,
      maxHeight: calendarTaskPopoverFallbackHeight,
    );

class TaskPopoverController extends ChangeNotifier {
  final Map<String, TaskPopoverLayout> _layouts = {};

  String? _activeTaskId;
  bool _dismissArmed = false;

  UnmodifiableMapView<String, TaskPopoverLayout> get layouts =>
      UnmodifiableMapView(_layouts);
  String? get activeTaskId => _activeTaskId;
  bool get dismissArmed => _dismissArmed;

  TaskPopoverLayout layoutFor(String taskId) =>
      _layouts[taskId] ?? defaultTaskPopoverLayout();

  void setLayout(String taskId, TaskPopoverLayout layout) {
    final TaskPopoverLayout? current = _layouts[taskId];
    if (current != null &&
        current.topLeft == layout.topLeft &&
        current.maxHeight == layout.maxHeight) {
      return;
    }
    _layouts[taskId] = layout;
    notifyListeners();
  }

  void removeLayout(String taskId) {
    if (_layouts.remove(taskId) != null) {
      notifyListeners();
    }
  }

  Iterable<String> cleanupLayouts(Set<String> activeTaskIds) {
    final removed = <String>[];
    final keys = List<String>.from(_layouts.keys);
    for (final id in keys) {
      if (!activeTaskIds.contains(id)) {
        if (_activeTaskId == id) {
          continue;
        }
        _layouts.remove(id);
        removed.add(id);
      }
    }
    if (removed.isNotEmpty) {
      notifyListeners();
    }
    return removed;
  }

  bool isPopoverOpen(String taskId) => _activeTaskId == taskId;

  void activate(String taskId, TaskPopoverLayout layout) {
    _layouts[taskId] = layout;
    _activeTaskId = taskId;
    _dismissArmed = false;
    notifyListeners();
  }

  void markDismissReady() {
    if (_dismissArmed) {
      return;
    }
    _dismissArmed = true;
    notifyListeners();
  }

  void deactivate() {
    if (_activeTaskId == null && !_dismissArmed) {
      return;
    }
    _activeTaskId = null;
    _dismissArmed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _layouts.clear();
    _activeTaskId = null;
    _dismissArmed = false;
    super.dispose();
  }
}
