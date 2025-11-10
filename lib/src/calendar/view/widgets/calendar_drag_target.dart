import 'package:flutter/widgets.dart';

import '../models/calendar_drag_payload.dart';

typedef CalendarDragTargetBuilder = Widget Function(
  BuildContext context,
  bool isHovering,
  CalendarDropDetails? details,
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
  final ValueChanged<CalendarDropDetails>? onDrop;
  final ValueChanged<CalendarDropDetails>? onEnter;
  final ValueChanged<CalendarDropDetails>? onMove;
  final ValueChanged<CalendarDropDetails>? onLeave;

  @override
  State<CalendarDragTargetRegion> createState() =>
      _CalendarDragTargetRegionState();
}

@immutable
class CalendarDropDetails {
  const CalendarDropDetails({
    required this.payload,
    required this.globalPosition,
    required this.localPosition,
  });

  final CalendarDragPayload payload;
  final Offset globalPosition;
  final Offset localPosition;
}

class _CalendarDragTargetRegionState extends State<CalendarDragTargetRegion> {
  bool _isHovering = false;
  CalendarDropDetails? _lastDetails;

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  CalendarDropDetails _buildDetails(
    DragTargetDetails<CalendarDragPayload> details,
  ) {
    final RenderBox? box = _renderBox;
    final Offset local =
        box != null ? box.globalToLocal(details.offset) : details.offset;
    return CalendarDropDetails(
      payload: details.data,
      globalPosition: details.offset,
      localPosition: local,
    );
  }

  bool _handleWillAccept(DragTargetDetails<CalendarDragPayload> details) {
    final CalendarDropDetails dropDetails = _buildDetails(details);
    setState(() {
      _isHovering = true;
      _lastDetails = dropDetails;
    });
    widget.onEnter?.call(dropDetails);
    return true;
  }

  void _handleMove(DragTargetDetails<CalendarDragPayload> details) {
    final CalendarDropDetails dropDetails = _buildDetails(details);
    _lastDetails = dropDetails;
    widget.onMove?.call(dropDetails);
  }

  void _handleLeave(CalendarDragPayload? payload) {
    if (!_isHovering) {
      return;
    }
    setState(() {
      _isHovering = false;
    });
    final CalendarDropDetails? details = _lastDetails;
    if (details != null) {
      widget.onLeave?.call(details);
    } else if (payload != null) {
      widget.onLeave?.call(
        CalendarDropDetails(
          payload: payload,
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      );
    }
    _lastDetails = null;
  }

  void _handleDrop(DragTargetDetails<CalendarDragPayload> details) {
    final CalendarDropDetails dropDetails = _buildDetails(details);
    setState(() {
      _isHovering = false;
      _lastDetails = null;
    });
    widget.onDrop?.call(dropDetails);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<CalendarDragPayload>(
      onWillAcceptWithDetails: _handleWillAccept,
      onMove: _handleMove,
      onAcceptWithDetails: _handleDrop,
      onLeave: _handleLeave,
      builder: (context, _, __) =>
          widget.builder(context, _isHovering, _lastDetails),
    );
  }
}
