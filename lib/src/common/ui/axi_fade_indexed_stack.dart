import 'package:flutter/material.dart';

const double _fadeHiddenOpacity = 0.0;
const double _fadeVisibleOpacity = 1.0;

class AxiFadeIndexedStack extends StatelessWidget {
  const AxiFadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    required this.duration,
    this.curve = Curves.easeInOut,
    this.alignment = Alignment.center,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final int resolvedIndex =
        index < 0 ? 0 : index >= children.length ? children.length - 1 : index;
    return Stack(
      fit: StackFit.expand,
      alignment: alignment,
      children: [
        for (var i = 0; i < children.length; i++)
          _AxiFadeIndexedStackChild(
            visible: i == resolvedIndex,
            duration: duration,
            curve: curve,
            child: children[i],
          ),
      ],
    );
  }
}

class _AxiFadeIndexedStackChild extends StatelessWidget {
  const _AxiFadeIndexedStackChild({
    required this.visible,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double resolvedOpacity =
        visible ? _fadeVisibleOpacity : _fadeHiddenOpacity;
    return TickerMode(
      enabled: visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: resolvedOpacity,
          duration: duration,
          curve: curve,
          child: ExcludeSemantics(
            excluding: !visible,
            child: child,
          ),
        ),
      ),
    );
  }
}
