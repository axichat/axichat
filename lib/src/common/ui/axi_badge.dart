import 'package:flutter/material.dart';

class AxiBadge extends StatelessWidget {
  const AxiBadge({
    super.key,
    required this.count,
    this.offset,
    required this.child,
  });

  final int count;
  final Offset? offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: count,
      offset: offset ?? const Offset(12, -12),
      largeSize: 19,
      isLabelVisible: count > 0,
      child: child,
    );
  }
}
