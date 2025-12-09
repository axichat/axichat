import 'package:flutter/material.dart';

/// AnimatedSize that snaps instantly when the duration is zero to avoid
/// re-marking layout during the same pass.
class AxiAnimatedSize extends StatelessWidget {
  const AxiAnimatedSize({
    super.key,
    required this.duration,
    this.reverseDuration,
    this.curve = Curves.linear,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.child,
    this.onEnd,
  });

  final Duration duration;
  final Duration? reverseDuration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Clip clipBehavior;
  final Widget? child;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final bool isInstant = duration == Duration.zero &&
        (reverseDuration == null || reverseDuration == Duration.zero);
    if (isInstant) {
      return child ?? const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: duration,
      reverseDuration: reverseDuration,
      curve: curve,
      alignment: alignment,
      clipBehavior: clipBehavior,
      onEnd: onEnd,
      child: child,
    );
  }
}
