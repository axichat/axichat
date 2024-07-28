import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiTooltip extends StatelessWidget {
  const AxiTooltip({
    super.key,
    required this.builder,
    required this.child,
  });

  final WidgetBuilder builder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShadTooltip(
      // hoverStrategies: mobileHoverStrategies,
      builder: builder,
      child: child,
    );
  }
}
