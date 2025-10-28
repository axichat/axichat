import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../models/calendar_task.dart';

/// Details describing a drag/update/drop that targets the calendar surface.
class CalendarDragDetails {
  const CalendarDragDetails({
    required this.task,
    required this.globalPosition,
    required this.localPosition,
    this.pointerOffsetFromOrigin = Offset.zero,
    this.feedbackSize,
  });

  final CalendarTask task;
  final Offset globalPosition;
  final Offset localPosition;
  final Offset pointerOffsetFromOrigin;
  final Size? feedbackSize;
}

/// Contract implemented by render targets that wish to receive calendar drags.
abstract class CalendarDragTargetDelegate {
  bool get isAttached;
  bool get canAcceptDrop => true;

  void didEnter(CalendarDragDetails details);

  void didMove(CalendarDragDetails details);

  void didLeave(CalendarDragDetails details);

  void didDrop(CalendarDragDetails details);
}

/// Global coordinator that mirrors Flutter's drag target dispatch semantics.
class CalendarDragCoordinator {
  CalendarDragCoordinator._();

  static final CalendarDragCoordinator instance = CalendarDragCoordinator._();

  final Set<CalendarDragTargetDelegate> _targets =
      <CalendarDragTargetDelegate>{};
  final ValueNotifier<bool> _dragActive = ValueNotifier<bool>(false);
  final ValueNotifier<Offset?> _dragGlobalPosition =
      ValueNotifier<Offset?>(null);

  void registerTarget(CalendarDragTargetDelegate target) {
    _targets.add(target);
  }

  void unregisterTarget(CalendarDragTargetDelegate target) {
    _targets.remove(target);
  }

  /// Hit tests the render tree and returns the active targets under [globalPosition].
  List<CalendarDragTargetDelegate> hitTestTargets(Offset globalPosition) {
    final LinkedHashSet<CalendarDragTargetDelegate> matches =
        LinkedHashSet<CalendarDragTargetDelegate>();
    for (final RenderView view in RendererBinding.instance.renderViews) {
      final HitTestResult result = HitTestResult();
      RendererBinding.instance.hitTestInView(
        result,
        globalPosition,
        view.flutterView.viewId,
      );
      for (final HitTestEntry<dynamic> entry in result.path) {
        final Object target = entry.target;
        if (target is CalendarDragTargetDelegate && target.isAttached) {
          matches.add(target);
        }
      }
    }
    return matches.toList(growable: false);
  }

  ValueListenable<bool> get dragActiveListenable => _dragActive;
  ValueListenable<Offset?> get dragPositionListenable => _dragGlobalPosition;

  void _notifyDragStart() {
    if (!_dragActive.value) {
      _dragActive.value = true;
    }
  }

  void _notifyDragPosition(Offset position) {
    _dragGlobalPosition.value = position;
  }

  void _notifyDragEnd() {
    if (_dragActive.value) {
      _dragActive.value = false;
    }
    if (_dragGlobalPosition.value != null) {
      _dragGlobalPosition.value = null;
    }
  }

  CalendarDragHandle startSession({
    required CalendarTask task,
    required Offset pointerOffset,
    Size? feedbackSize,
  }) {
    _notifyDragStart();
    return CalendarDragHandle._(
      coordinator: this,
      task: task,
      pointerOffset: pointerOffset,
      feedbackSize: feedbackSize,
    );
  }
}

class CalendarDragHandle {
  CalendarDragHandle._({
    required CalendarDragCoordinator coordinator,
    required this.task,
    required Offset pointerOffset,
    Size? feedbackSize,
  })  : _coordinator = coordinator,
        _pointerOffset = pointerOffset,
        _feedbackSize = feedbackSize;

  final CalendarDragCoordinator _coordinator;
  final CalendarTask task;
  final Offset _pointerOffset;
  final Size? _feedbackSize;
  final Map<CalendarDragTargetDelegate, CalendarDragDetails> _activeTargets =
      <CalendarDragTargetDelegate, CalendarDragDetails>{};
  CalendarDragTargetDelegate? _dropTarget;
  CalendarDragDetails? _dropDetails;
  Offset? _lastGlobalPosition;

  void update(Offset globalPosition) {
    _lastGlobalPosition = globalPosition;
    _dispatch(globalPosition);
    _coordinator._notifyDragPosition(globalPosition);
  }

  void end(Offset globalPosition) {
    update(globalPosition);
    final CalendarDragTargetDelegate? dropTarget = _dropTarget;
    final CalendarDragDetails? dropDetails = _dropDetails;
    if (dropTarget != null && dropDetails != null) {
      dropTarget.didDrop(dropDetails);
    }
    _leaveAllTargets();
    _coordinator._notifyDragEnd();
    _reset();
  }

  void cancel() {
    _leaveAllTargets();
    _coordinator._notifyDragEnd();
    _reset();
  }

  void _reset() {
    _activeTargets.clear();
    _dropTarget = null;
    _dropDetails = null;
  }

  void _dispatch(Offset globalPosition) {
    final List<CalendarDragTargetDelegate> targets =
        _coordinator.hitTestTargets(globalPosition);
    final Map<CalendarDragTargetDelegate, CalendarDragDetails> nextActive =
        <CalendarDragTargetDelegate, CalendarDragDetails>{};

    for (final CalendarDragTargetDelegate target in targets) {
      final CalendarDragDetails details = _buildDetails(target, globalPosition);
      final CalendarDragDetails? previous = _activeTargets[target];
      if (previous == null) {
        target.didEnter(details);
      } else {
        target.didMove(details);
      }
      nextActive[target] = details;
    }

    for (final MapEntry<CalendarDragTargetDelegate, CalendarDragDetails> entry
        in _activeTargets.entries) {
      if (!nextActive.containsKey(entry.key)) {
        entry.key.didLeave(entry.value);
      }
    }

    _activeTargets
      ..clear()
      ..addAll(nextActive);

    CalendarDragTargetDelegate? dropCandidate;
    CalendarDragDetails? dropDetails;
    for (final CalendarDragTargetDelegate target in targets) {
      if (!target.canAcceptDrop) {
        continue;
      }
      dropCandidate = target;
      dropDetails = nextActive[target];
      break;
    }
    _dropTarget = dropCandidate;
    _dropDetails = dropDetails;
  }

  CalendarDragDetails _buildDetails(
    CalendarDragTargetDelegate target,
    Offset globalPosition,
  ) {
    final RenderBox? renderTarget =
        target is RenderBox ? target as RenderBox : null;
    final Offset localPosition = renderTarget != null
        ? renderTarget.globalToLocal(globalPosition)
        : globalPosition;
    return CalendarDragDetails(
      task: task,
      globalPosition: globalPosition,
      localPosition: localPosition,
      pointerOffsetFromOrigin: _pointerOffset,
      feedbackSize: _feedbackSize,
    );
  }

  Offset? get lastGlobalPosition => _lastGlobalPosition;

  void _leaveAllTargets() {
    for (final MapEntry<CalendarDragTargetDelegate, CalendarDragDetails> entry
        in _activeTargets.entries) {
      entry.key.didLeave(entry.value);
    }
    _activeTargets.clear();
    _dropTarget = null;
    _dropDetails = null;
  }
}
