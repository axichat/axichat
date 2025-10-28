import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'calendar_drag_interop.dart';

typedef CalendarDragTargetBuilder = Widget Function(
  BuildContext context,
  bool isHovering,
  CalendarDragDetails? details,
);

class CalendarDragTargetRegion extends StatefulWidget {
  const CalendarDragTargetRegion({
    super.key,
    required this.builder,
    this.onDrop,
    this.onEnter,
    this.onMove,
    this.onLeave,
  });

  final CalendarDragTargetBuilder builder;
  final ValueChanged<CalendarDragDetails>? onDrop;
  final ValueChanged<CalendarDragDetails>? onEnter;
  final ValueChanged<CalendarDragDetails>? onMove;
  final ValueChanged<CalendarDragDetails>? onLeave;

  @override
  State<CalendarDragTargetRegion> createState() =>
      _CalendarDragTargetRegionState();
}

class _CalendarDragTargetRegionState extends State<CalendarDragTargetRegion> {
  bool _isHovering = false;
  CalendarDragDetails? _lastDetails;

  void _handleEnter(CalendarDragDetails details) {
    if (!_isHovering) {
      setState(() {
        _isHovering = true;
        _lastDetails = details;
      });
    } else {
      _lastDetails = details;
    }
    widget.onEnter?.call(details);
  }

  void _handleMove(CalendarDragDetails details) {
    _lastDetails = details;
    widget.onMove?.call(details);
  }

  void _handleLeave(CalendarDragDetails details) {
    if (_isHovering) {
      setState(() {
        _isHovering = false;
        _lastDetails = null;
      });
    }
    widget.onLeave?.call(details);
  }

  void _handleDrop(CalendarDragDetails details) {
    widget.onDrop?.call(details);
  }

  @override
  Widget build(BuildContext context) {
    return _CalendarDragTargetRenderWidget(
      onEnter: _handleEnter,
      onMove: _handleMove,
      onLeave: _handleLeave,
      onDrop: _handleDrop,
      child: widget.builder(context, _isHovering, _lastDetails),
    );
  }
}

class _CalendarDragTargetRenderWidget extends SingleChildRenderObjectWidget {
  const _CalendarDragTargetRenderWidget({
    this.onEnter,
    this.onMove,
    this.onLeave,
    this.onDrop,
    super.child,
  });

  final ValueChanged<CalendarDragDetails>? onEnter;
  final ValueChanged<CalendarDragDetails>? onMove;
  final ValueChanged<CalendarDragDetails>? onLeave;
  final ValueChanged<CalendarDragDetails>? onDrop;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCalendarDragTarget(
      onEnter: onEnter,
      onMove: onMove,
      onLeave: onLeave,
      onDrop: onDrop,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCalendarDragTarget renderObject,
  ) {
    renderObject
      ..onEnter = onEnter
      ..onMove = onMove
      ..onLeave = onLeave
      ..onDrop = onDrop;
  }
}

class _RenderCalendarDragTarget extends RenderProxyBox
    implements CalendarDragTargetDelegate {
  _RenderCalendarDragTarget({
    this.onEnter,
    this.onMove,
    this.onLeave,
    this.onDrop,
  });

  CalendarDragCoordinator get _coordinator => CalendarDragCoordinator.instance;

  ValueChanged<CalendarDragDetails>? onEnter;
  ValueChanged<CalendarDragDetails>? onMove;
  ValueChanged<CalendarDragDetails>? onLeave;
  ValueChanged<CalendarDragDetails>? onDrop;

  @override
  bool get canAcceptDrop => onDrop != null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _coordinator.registerTarget(this);
  }

  @override
  void detach() {
    _coordinator.unregisterTarget(this);
    super.detach();
  }

  @override
  bool get isAttached => attached;

  @override
  void didEnter(CalendarDragDetails details) {
    onEnter?.call(details);
  }

  @override
  void didMove(CalendarDragDetails details) {
    onMove?.call(details);
  }

  @override
  void didLeave(CalendarDragDetails details) {
    onLeave?.call(details);
  }

  @override
  void didDrop(CalendarDragDetails details) {
    onDrop?.call(details);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final bool hitChild = super.hitTest(result, position: position);
    if (!size.contains(position)) {
      return hitChild;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
