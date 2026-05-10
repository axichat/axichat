// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

class AxiDirectionalIndexedStack extends StatefulWidget {
  const AxiDirectionalIndexedStack({
    super.key,
    required this.index,
    required this.children,
    required this.duration,
    this.curve = Curves.easeInOutCubic,
    this.alignment = Alignment.center,
    this.animationEnabled = true,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final bool animationEnabled;

  @override
  State<AxiDirectionalIndexedStack> createState() =>
      _AxiDirectionalIndexedStackState();
}

class _AxiDirectionalIndexedStackState
    extends State<AxiDirectionalIndexedStack> {
  late int _activeIndex = _resolveIndex(widget.index);
  int? _outgoingIndex;

  @override
  void didUpdateWidget(covariant AxiDirectionalIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.isEmpty) {
      _activeIndex = 0;
      _outgoingIndex = null;
      return;
    }

    final nextIndex = _resolveIndex(widget.index);
    if (nextIndex == _activeIndex) {
      if (widget.duration == Duration.zero || !widget.animationEnabled) {
        _outgoingIndex = null;
      }
      return;
    }

    if (widget.duration == Duration.zero ||
        oldWidget.children.isEmpty ||
        !oldWidget.animationEnabled ||
        !widget.animationEnabled) {
      _activeIndex = nextIndex;
      _outgoingIndex = null;
      return;
    }

    _outgoingIndex = _activeIndex;
    _activeIndex = nextIndex;
  }

  int _resolveIndex(int index) {
    if (widget.children.isEmpty) {
      return 0;
    }
    return index.clamp(0, widget.children.length - 1).toInt();
  }

  Offset _offsetFor(int childIndex) {
    if (childIndex == _activeIndex) {
      return Offset.zero;
    }
    if (childIndex < _activeIndex) {
      return const Offset(-1, 0);
    }
    return const Offset(1, 0);
  }

  void _handleTransitionEnd() {
    if (!mounted || _outgoingIndex == null) {
      return;
    }
    setState(() {
      _outgoingIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      alignment: widget.alignment,
      children: [
        for (int i = 0; i < widget.children.length; i++)
          _AxiDirectionalIndexedStackChild(
            active: i == _activeIndex,
            visible: i == _activeIndex || i == _outgoingIndex,
            offset: _offsetFor(i),
            duration: widget.duration,
            curve: widget.curve,
            onEnd: i == _activeIndex ? _handleTransitionEnd : null,
            child: widget.children[i],
          ),
      ],
    );
  }
}

class _AxiDirectionalIndexedStackChild extends StatelessWidget {
  const _AxiDirectionalIndexedStackChild({
    required this.active,
    required this.visible,
    required this.offset,
    required this.duration,
    required this.curve,
    required this.onEnd,
    required this.child,
  });

  final bool active;
  final bool visible;
  final Offset offset;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !visible,
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: AnimatedSlide(
              offset: offset,
              duration: duration,
              curve: curve,
              onEnd: onEnd,
              child: TickerMode(enabled: visible, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
