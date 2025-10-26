import 'dart:ui' as ui;

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

  void registerTarget(CalendarDragTargetDelegate target) {
    _targets.add(target);
  }

  void unregisterTarget(CalendarDragTargetDelegate target) {
    _targets.remove(target);
  }

  /// Hit tests the render tree and returns the active targets under [globalPosition].
  List<CalendarDragTargetDelegate> hitTestTargets(Offset globalPosition) {
    final HitTestResult result = HitTestResult();
    final Iterable<RenderView> renderViews =
        RendererBinding.instance.renderViews;
    if (renderViews.isEmpty) {
      return const <CalendarDragTargetDelegate>[];
    }
    final ui.FlutterView flutterView = renderViews.first.flutterView;
    RendererBinding.instance.hitTestInView(
      result,
      globalPosition,
      flutterView.viewId,
    );
    final List<CalendarDragTargetDelegate> matches =
        <CalendarDragTargetDelegate>[];
    for (final HitTestEntry<dynamic> entry in result.path) {
      final Object target = entry.target;
      if (target is CalendarDragTargetDelegate && target.isAttached) {
        if (_targets.contains(target)) {
          matches.add(target);
        }
      }
    }
    return matches;
  }

  CalendarDragHandle startSession({
    required CalendarTask task,
    required Offset pointerOffset,
    Size? feedbackSize,
  }) {
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
  CalendarDragTargetDelegate? _activeTarget;
  CalendarDragDetails? _lastDetails;
  bool _pointerInsideActiveTarget = false;
  Offset? _lastGlobalPosition;

  void update(Offset globalPosition) {
    _lastGlobalPosition = globalPosition;
    _dispatch(globalPosition);
  }

  void end(Offset globalPosition) {
    update(globalPosition);
    if (_activeTarget != null && _lastDetails != null) {
      _activeTarget!.didDrop(_lastDetails!);
      if (_pointerInsideActiveTarget) {
        _activeTarget!.didLeave(_lastDetails!);
      }
    }
    _reset();
  }

  void cancel() {
    if (_activeTarget != null &&
        _lastDetails != null &&
        _pointerInsideActiveTarget) {
      _activeTarget!.didLeave(_lastDetails!);
    }
    _reset();
  }

  void _reset() {
    _activeTarget = null;
    _lastDetails = null;
    _pointerInsideActiveTarget = false;
  }

  void _dispatch(Offset globalPosition) {
    final List<CalendarDragTargetDelegate> targets =
        _coordinator.hitTestTargets(globalPosition);
    final CalendarDragTargetDelegate? nextTarget =
        targets.isNotEmpty ? targets.first : null;

    if (!identical(nextTarget, _activeTarget)) {
      if (_activeTarget != null &&
          _pointerInsideActiveTarget &&
          _lastDetails != null) {
        _activeTarget!.didLeave(_lastDetails!);
      }
      _activeTarget = nextTarget;
      _pointerInsideActiveTarget = nextTarget != null;
      if (_activeTarget != null) {
        final CalendarDragDetails enterDetails =
            _buildDetails(_activeTarget!, globalPosition);
        _activeTarget!.didEnter(enterDetails);
        _activeTarget!.didMove(enterDetails);
        _lastDetails = enterDetails;
      } else {
        _lastDetails = null;
      }
      return;
    }

    if (_activeTarget != null) {
      if (nextTarget == null &&
          _pointerInsideActiveTarget &&
          _lastDetails != null) {
        _activeTarget!.didLeave(_lastDetails!);
        _pointerInsideActiveTarget = false;
      } else if (nextTarget != null && !_pointerInsideActiveTarget) {
        final CalendarDragDetails reenterDetails =
            _buildDetails(_activeTarget!, globalPosition);
        _activeTarget!.didEnter(reenterDetails);
        _pointerInsideActiveTarget = true;
        _activeTarget!.didMove(reenterDetails);
        _lastDetails = reenterDetails;
        return;
      } else if (nextTarget != null) {
        _pointerInsideActiveTarget = true;
      }
      final CalendarDragDetails moveDetails =
          _buildDetails(_activeTarget!, globalPosition);
      _activeTarget!.didMove(moveDetails);
      _lastDetails = moveDetails;
    }
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
}
