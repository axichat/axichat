// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Duration axiAtLeastBaseAnimationDuration(Duration duration) =>
    duration.compareTo(baseAnimationDuration) < 0
    ? baseAnimationDuration
    : duration;

bool axiShouldEnableIosEdgeSwipe(TargetPlatform platform) =>
    platform == TargetPlatform.iOS ||
    (kDebugMode && platform == TargetPlatform.android);

class AxiIosEdgeSwipeDismiss extends StatefulWidget {
  static const double _dismissProgressThreshold = 0.40;
  static const double _dismissVelocityThreshold = 500;

  const AxiIosEdgeSwipeDismiss({
    super.key,
    required this.child,
    required this.onDismissRequested,
    this.enabled = true,
    this.duration = baseAnimationDuration,
  });

  final Widget child;
  final FutureOr<bool> Function() onDismissRequested;
  final bool enabled;
  final Duration duration;

  @override
  State<AxiIosEdgeSwipeDismiss> createState() => _AxiIosEdgeSwipeDismissState();
}

class _AxiIosEdgeSwipeDismissState extends State<AxiIosEdgeSwipeDismiss>
    with SingleTickerProviderStateMixin {
  static const double _shownValue = 1.0;
  static const double _dismissedValue = 0.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: _shownValue,
  );
  bool _dragging = false;
  bool _dismissInProgress = false;

  bool get _gestureEnabled =>
      widget.enabled && axiShouldEnableIosEdgeSwipe(defaultTargetPlatform);

  Duration get _duration => axiAtLeastBaseAnimationDuration(widget.duration);

  @override
  void didUpdateWidget(covariant AxiIosEdgeSwipeDismiss oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging || _dismissInProgress || _controller.value == _shownValue) {
      return;
    }
    if (!widget.enabled ||
        !oldWidget.enabled ||
        widget.child != oldWidget.child) {
      _controller.value = _shownValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving =
        _dragging ||
        _dismissInProgress ||
        _controller.isAnimating ||
        _controller.value != _shownValue;
    final content = moving
        ? AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => AxiSwipeBackTransition(
              value: _controller.value,
              foreground: widget.child,
              cupertinoStyle: true,
            ),
          )
        : widget.child;
    if (!_gestureEnabled) {
      return content;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: content),
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: context.sizing.compactPaneEdgeSwipeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _handleHorizontalDragStart,
            onHorizontalDragUpdate: _handleHorizontalDragUpdate,
            onHorizontalDragEnd: _handleHorizontalDragEnd,
            onHorizontalDragCancel: _handleHorizontalDragCancel,
          ),
        ),
      ],
    );
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    if (!_gestureEnabled) {
      return;
    }
    _controller.stop();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _dragging = true;
      _dismissInProgress = false;
    });
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_dragging || _dismissInProgress) {
      return;
    }
    final width = context.size?.width ?? 0;
    if (width <= 0) {
      return;
    }
    final delta = details.primaryDelta ?? details.delta.dx;
    _controller.value = (_controller.value - (delta / width)).clamp(
      _dismissedValue,
      _shownValue,
    );
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!_dragging || _dismissInProgress) {
      return;
    }
    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
    final draggedProgress = _shownValue - _controller.value;
    if (draggedProgress >= AxiIosEdgeSwipeDismiss._dismissProgressThreshold ||
        velocity >= AxiIosEdgeSwipeDismiss._dismissVelocityThreshold) {
      unawaited(_completeDismiss());
      return;
    }
    setState(() {
      _dragging = false;
    });
    unawaited(_animateTo(_shownValue));
  }

  void _handleHorizontalDragCancel() {
    if (!_dragging || _dismissInProgress) {
      return;
    }
    setState(() {
      _dragging = false;
    });
    unawaited(_animateTo(_shownValue));
  }

  Future<void> _completeDismiss() async {
    setState(() {
      _dismissInProgress = true;
      _dragging = false;
    });
    await _animateTo(_dismissedValue);
    if (!mounted) {
      return;
    }
    final dismissed = await widget.onDismissRequested();
    if (!mounted) {
      return;
    }
    if (!dismissed) {
      setState(() {
        _dismissInProgress = false;
      });
      await _animateTo(_shownValue);
      return;
    }
    setState(() {
      _dismissInProgress = false;
    });
  }

  Future<void> _animateTo(double value) async {
    if (_controller.value == value) {
      return;
    }
    await _controller.animateTo(
      value,
      duration: _duration,
      curve: Curves.easeIn,
    );
  }
}

class AxiSwipeBackTransition extends StatelessWidget {
  static const double _backgroundParallaxFraction = 1 / 3;

  const AxiSwipeBackTransition({
    super.key,
    required this.value,
    required this.foreground,
    required this.cupertinoStyle,
    this.background,
    this.centerChildren = false,
  });

  final double value;
  final Widget foreground;
  final bool cupertinoStyle;
  final Widget? background;
  final bool centerChildren;

  @override
  Widget build(BuildContext context) {
    final barrierColor = context.dialogBarrierColor;
    final scrimAlpha = cupertinoStyle
        ? (barrierColor.a *
                  context.motion.compactPaneSwipeScrimOpacityFactor *
                  value)
              .clamp(0.0, 1.0)
        : 0.0;
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final background = this.background;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (background != null)
                Transform.translate(
                  offset: Offset(
                    cupertinoStyle
                        ? -width * value * _backgroundParallaxFraction
                        : 0,
                    0,
                  ),
                  child: _wrapChild(background),
                ),
              if (scrimAlpha > 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: barrierColor.withValues(alpha: scrimAlpha),
                  ),
                ),
              Transform.translate(
                offset: Offset(width * (1 - value), 0),
                child: _wrapChild(foreground),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _wrapChild(Widget child) =>
      centerChildren ? Center(child: child) : child;
}
