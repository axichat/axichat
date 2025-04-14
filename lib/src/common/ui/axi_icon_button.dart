import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiIconButton extends StatelessWidget {
  const AxiIconButton({
    super.key,
    required this.iconData,
    required this.onPressed,
    this.tooltip,
  });

  final IconData iconData;
  final void Function() onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = ShadButton.outline(
      height: 36.0,
      width: 36.0,
      icon: Icon(
        iconData,
        size: 20.0,
      ),
      onPressed: onPressed,
    );

    if (tooltip == null) return child;

    return AxiTooltip(
      builder: (context) => Text(
        tooltip!,
        style: context.textTheme.muted,
      ),
      child: child,
    );
  }
}
