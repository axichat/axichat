import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class NarrowLayout extends StatelessWidget {
  const NarrowLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: smallScreen),
        child: child,
      ),
    );
  }
}
