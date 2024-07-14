import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiAdaptiveLayout extends StatelessWidget {
  const AxiAdaptiveLayout({
    super.key,
    required this.primaryChild,
    required this.secondaryChild,
    this.invertPriority = false,
  });

  final Widget primaryChild;
  final Widget secondaryChild;
  final bool invertPriority;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final primaryFlex = switch (constraints.maxWidth) {
          < smallScreen => 10,
          < mediumScreen => 5,
          < largeScreen => 4,
          _ => 3,
        };
        final secondaryFlex = 10 - primaryFlex;
        final secondaryVisible = secondaryFlex > 0;
        return ConstrainedBox(
          constraints: constraints,
          child: !secondaryVisible
              ? Center(
                  child: AnimatedSwitcher(
                    duration: animationDuration,
                    child: invertPriority ? secondaryChild : primaryChild,
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: primaryFlex,
                      child: Center(
                        child: primaryChild,
                      ),
                    ),
                    Flexible(
                      flex: secondaryFlex,
                      child: Center(
                        child: secondaryChild,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
