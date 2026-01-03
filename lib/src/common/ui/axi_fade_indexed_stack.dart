// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

const double _fadeHiddenOpacity = 0.0;
const double _fadeVisibleOpacity = 1.0;

enum AxiFadeIndexedStackTransition {
  crossFade,
  fadeOutIn,
}

class AxiFadeIndexedStack extends StatelessWidget {
  const AxiFadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    required this.duration,
    this.curve = Curves.easeInOut,
    this.alignment = Alignment.center,
    this.transitionMode = AxiFadeIndexedStackTransition.crossFade,
    this.overlapChildren = true,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final AxiFadeIndexedStackTransition transitionMode;
  final bool overlapChildren;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final int resolvedIndex = index < 0
        ? 0
        : index >= children.length
            ? children.length - 1
            : index;
    if (transitionMode == AxiFadeIndexedStackTransition.fadeOutIn) {
      return _AxiFadeIndexedStackFadeOutIn(
        index: resolvedIndex,
        duration: duration,
        curve: curve,
        alignment: alignment,
        children: children,
      );
    }
    return Stack(
      fit: StackFit.expand,
      alignment: alignment,
      children: [
        for (int i = 0; i < children.length; i++)
          _AxiFadeIndexedStackChild(
            visible: i == resolvedIndex,
            duration: duration,
            curve: curve,
            overlapChildren: overlapChildren,
            child: children[i],
          ),
      ],
    );
  }
}

class _AxiFadeIndexedStackFadeOutIn extends StatefulWidget {
  const _AxiFadeIndexedStackFadeOutIn({
    required this.index,
    required this.children,
    required this.duration,
    required this.curve,
    required this.alignment,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  State<_AxiFadeIndexedStackFadeOutIn> createState() =>
      _AxiFadeIndexedStackFadeOutInState();
}

class _AxiFadeIndexedStackFadeOutInState
    extends State<_AxiFadeIndexedStackFadeOutIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );
  late int _visibleIndex = widget.index;
  late int _targetIndex = widget.index;
  var _transitioning = false;

  @override
  void initState() {
    super.initState();
    _controller.value = _fadeVisibleOpacity;
  }

  @override
  void didUpdateWidget(covariant _AxiFadeIndexedStackFadeOutIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _opacity = CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      );
    }
    if (widget.index != _targetIndex) {
      _queueTransition(widget.index);
    }
  }

  void _queueTransition(int nextIndex) {
    _targetIndex = nextIndex;
    if (_transitioning) {
      return;
    }
    _transitioning = true;
    _runTransition();
  }

  Future<void> _runTransition() async {
    if (!mounted) return;
    if (widget.duration == Duration.zero) {
      setState(() {
        _visibleIndex = _targetIndex;
      });
      _controller.value = _fadeVisibleOpacity;
      _transitioning = false;
      return;
    }
    await _controller.reverse(from: _fadeVisibleOpacity);
    if (!mounted) return;
    setState(() {
      _visibleIndex = _targetIndex;
    });
    await _controller.forward(from: _fadeHiddenOpacity);
    if (!mounted) return;
    if (_visibleIndex != _targetIndex) {
      _runTransition();
      return;
    }
    _transitioning = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: IgnorePointer(
        ignoring: _transitioning,
        child: SizedBox.expand(
          child: IndexedStack(
            alignment: widget.alignment,
            index: _visibleIndex,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

class _AxiFadeIndexedStackChild extends StatefulWidget {
  const _AxiFadeIndexedStackChild({
    required this.visible,
    required this.duration,
    required this.curve,
    required this.overlapChildren,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Curve curve;
  final bool overlapChildren;
  final Widget child;

  @override
  State<_AxiFadeIndexedStackChild> createState() =>
      _AxiFadeIndexedStackChildState();
}

class _AxiFadeIndexedStackChildState extends State<_AxiFadeIndexedStackChild> {
  late bool _shouldTick;

  @override
  void initState() {
    super.initState();
    _shouldTick = widget.visible;
  }

  @override
  void didUpdateWidget(covariant _AxiFadeIndexedStackChild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.overlapChildren) {
      _shouldTick = widget.visible;
      return;
    }
    if (widget.visible) {
      _shouldTick = true;
      return;
    }
    if (widget.duration == Duration.zero) {
      _shouldTick = false;
      return;
    }
    _shouldTick = true;
  }

  void _handleFadeEnd() {
    if (!widget.overlapChildren || !mounted || widget.visible || !_shouldTick) {
      return;
    }
    setState(() {
      _shouldTick = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double resolvedOpacity =
        widget.visible ? _fadeVisibleOpacity : _fadeHiddenOpacity;
    final animatedChild = TickerMode(
      enabled: _shouldTick,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedOpacity(
          opacity: resolvedOpacity,
          duration: widget.duration,
          curve: widget.curve,
          onEnd: _handleFadeEnd,
          child: ExcludeSemantics(
            excluding: !widget.visible,
            child: widget.child,
          ),
        ),
      ),
    );
    if (widget.overlapChildren) {
      return animatedChild;
    }
    return Offstage(
      offstage: !widget.visible,
      child: animatedChild,
    );
  }
}
