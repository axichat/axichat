import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class WideLayout extends StatelessWidget {
  const WideLayout(
      {super.key, required this.smallChild, required this.largeChild});

  final Widget smallChild;
  final Widget largeChild;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final splitRatio = constraints.maxWidth < 900
            ? 5
            : constraints.maxWidth < largeScreen
                ? 4
                : 3;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              flex: splitRatio,
              child: Center(
                child: smallChild,
              ),
            ),
            Flexible(
              flex: 10 - splitRatio,
              child: Center(
                child: largeChild,
              ),
            ),
          ],
        );
      },
    );
  }
}
