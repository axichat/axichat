import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'dart:async';

import 'package:shadcn_ui/shadcn_ui.dart';

class CalendarTaskTitleTooltip extends StatefulWidget {
  const CalendarTaskTitleTooltip({
    super.key,
    required this.title,
    required this.child,
    this.enabled = true,
    this.waitDuration = const Duration(milliseconds: 1000),
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
  Timer? _showTimer;
  bool _hovering = false;
  bool _pointerDown = false;

  @override
  void dispose() {
    _showTimer?.cancel();
    _showTimer = null;
    super.dispose();
  }

  void _scheduleShow() {
    _showTimer?.cancel();
    _showTimer = Timer(widget.waitDuration, () {
      if (!mounted || !_hovering || _pointerDown || !widget.enabled) {
        return;
      }
      _tooltipKey.currentState?.ensureTooltipVisible();
    });
  }

  void _hideTooltip() {
    _showTimer?.cancel();
    _showTimer = null;
    Tooltip.dismissAllToolTips();
  }

  void _handlePointerDown(PointerDownEvent _) {
    if (_pointerDown) {
      return;
    }
    _pointerDown = true;
    _hideTooltip();
  }

  void _handlePointerUp(PointerUpEvent _) {
    if (!_pointerDown) {
      return;
    }
    _pointerDown = false;
  }

  void _handlePointerCancel(PointerCancelEvent _) {
    if (!_pointerDown) {
      return;
    }
    _pointerDown = false;
  }

  void _handleEnter(PointerEnterEvent _) {
    _hovering = true;
    if (!widget.enabled || _pointerDown) {
      return;
    }
    _scheduleShow();
  }

  void _handleHover(PointerHoverEvent _) {
    if (!_hovering || !widget.enabled || _pointerDown) {
      return;
    }
    _scheduleShow();
  }

  void _handleExit(PointerExitEvent _) {
    _hovering = false;
    _hideTooltip();
  }

  @override
  Widget build(BuildContext context) {
    final String trimmed = widget.title.trim();
    if (trimmed.isEmpty) {
      return widget.child;
    }

    final bool allowTooltip = widget.enabled && !_pointerDown;
    final Widget base = MouseRegion(
      onEnter: _handleEnter,
      onHover: _handleHover,
      onExit: _handleExit,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: widget.child,
      ),
    );
    if (!allowTooltip) {
      return base;
    }

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

    final colors = ShadTheme.of(context, listen: false).colorScheme;
    final radius = ShadTheme.of(context, listen: false).radius;
    final textStyle = ShadTheme.of(context, listen: false).textTheme.muted;
    return Tooltip(
      key: _tooltipKey,
      message: trimmed,
      preferBelow: true,
      verticalOffset: 12,
      exitDuration: widget.exitDuration,
      triggerMode: TooltipTriggerMode.manual,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.popover,
        borderRadius: radius,
        border: Border.all(color: colors.border),
      ),
      textStyle: textStyle,
      child: base,
    );
  }
}
