// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:axichat/src/common/ui/ui.dart';

class TaskPopoverLayout {
  const TaskPopoverLayout({required this.topLeft, required this.maxHeight});

  final Offset topLeft;
  final double maxHeight;
}

TaskPopoverLayout defaultTaskPopoverLayout() => const TaskPopoverLayout(
  topLeft: Offset.zero,
  maxHeight: calendarTaskPopoverFallbackHeight,
);

TaskPopoverLayout calculateTaskPopoverLayout({
  required Rect bounds,
  required Size screenSize,
  required EdgeInsets safePadding,
  required double screenMargin,
  required double popoverGap,
  double bottomInset = 0,
  double dropdownWidth = calendarTaskPopoverWidth,
  double dropdownMaxHeight = calendarGridPopoverMaxHeight,
  double minimumHeight = calendarTaskPopoverMinHeight,
}) {
  final double usableLeft = screenMargin;
  final double usableRight = screenSize.width - screenMargin;
  final double usableTop = safePadding.top + screenMargin;
  final double usableBottom =
      screenSize.height - safePadding.bottom - bottomInset - screenMargin;
  final double usableHeight = math.max(0, usableBottom - usableTop);

  final double leftSpace = bounds.left - usableLeft;
  final double rightSpace = usableRight - bounds.right;

  final bool placeOnRight;
  if (rightSpace >= dropdownWidth && leftSpace < dropdownWidth) {
    placeOnRight = true;
  } else if (leftSpace >= dropdownWidth && rightSpace < dropdownWidth) {
    placeOnRight = false;
  } else {
    placeOnRight = rightSpace >= leftSpace;
  }

  double effectiveMaxHeight = dropdownMaxHeight;
  if (usableHeight <= 0) {
    effectiveMaxHeight = minimumHeight;
  } else {
    effectiveMaxHeight = math.min(dropdownMaxHeight, usableHeight);
    if (effectiveMaxHeight < minimumHeight) {
      effectiveMaxHeight = usableHeight;
    }
  }

  final double halfHeight = effectiveMaxHeight / 2;
  final double triggerCenterY = bounds.top + (bounds.height / 2);
  final double clampedCenterY = triggerCenterY.clamp(
    usableTop + halfHeight,
    usableBottom - halfHeight,
  );

  double top = clampedCenterY - halfHeight;
  if (top < usableTop) {
    top = usableTop;
  }
  if (top + effectiveMaxHeight > usableBottom) {
    top = usableBottom - effectiveMaxHeight;
  }

  double left = placeOnRight
      ? bounds.right + popoverGap
      : bounds.left - dropdownWidth - popoverGap;
  left = left.clamp(usableLeft, usableRight - dropdownWidth);

  return TaskPopoverLayout(
    topLeft: Offset(left, top),
    maxHeight: effectiveMaxHeight,
  );
}

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
