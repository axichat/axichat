import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CalendarTaskTitleTooltip extends StatefulWidget {
  const CalendarTaskTitleTooltip({
    super.key,
    required this.title,
    required this.child,
    this.enabled = true,
    this.waitDuration = const Duration(milliseconds: 1500),
    this.exitDuration = const Duration(milliseconds: 100),
  });

  final String title;
  final Widget child;
  final bool enabled;
  final Duration waitDuration;
  final Duration exitDuration;

  @override
  State<CalendarTaskTitleTooltip> createState() =>
      _CalendarTaskTitleTooltipState();
}

class _CalendarTaskTitleTooltipState extends State<CalendarTaskTitleTooltip> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  Timer? _timer;
  bool _hovering = false;
  bool _pointerDown = false;

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleShow() {
    _cancelTimer();
    if (!mounted || !_hovering || _pointerDown || !widget.enabled) {
      return;
    }
    _timer = Timer(widget.waitDuration, () {
      if (!mounted || !_hovering || _pointerDown || !widget.enabled) {
        return;
      }
      _tooltipKey.currentState?.ensureTooltipVisible();
    });
  }

  void _handleEnter(PointerEnterEvent _) {
    _hovering = true;
    _scheduleShow();
  }

  void _handleHover(PointerHoverEvent _) {
    if (!_hovering) {
      return;
    }
    _scheduleShow();
  }

  void _handleExit(PointerExitEvent _) {
    _hovering = false;
    _cancelTimer();
    Tooltip.dismissAllToolTips();
  }

  void _handlePointerDown(PointerDownEvent _) {
    _pointerDown = true;
    _cancelTimer();
    Tooltip.dismissAllToolTips();
  }

  void _handlePointerUpOrCancel(PointerEvent _) {
    _pointerDown = false;
    _cancelTimer();
  }

  @override
  Widget build(BuildContext context) {
    final String trimmed = widget.title.trim();
    if (!widget.enabled || trimmed.isEmpty) {
      return widget.child;
    }

    final Widget base = MouseRegion(
      onEnter: _handleEnter,
      onHover: _handleHover,
      onExit: _handleExit,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUpOrCancel,
        onPointerCancel: _handlePointerUpOrCancel,
        child: widget.child,
      ),
    );

    final bool hasShadTheme = ShadTheme.maybeOf(context, listen: false) != null;
    if (!hasShadTheme) {
      return Tooltip(
        key: _tooltipKey,
        message: trimmed,
        exitDuration: widget.exitDuration,
        triggerMode: TooltipTriggerMode.manual,
        child: base,
      );
    }

    final theme = ShadTheme.of(context, listen: false);
    return Tooltip(
      key: _tooltipKey,
      message: trimmed,
      preferBelow: true,
      verticalOffset: 20,
      exitDuration: widget.exitDuration,
      triggerMode: TooltipTriggerMode.manual,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.popover,
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      textStyle: theme.textTheme.muted,
      child: base,
    );
  }
}
