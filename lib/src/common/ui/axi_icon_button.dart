import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiIconButton extends StatelessWidget {
  const AxiIconButton({
    super.key,
    required this.iconData,
    this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData iconData;
  final void Function()? onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = ShadIconButton.outline(
      decoration: ShadDecoration(border: ShadBorder.all(color: color)),
      height: 36.0,
      width: 36.0,
      foregroundColor: color,
      onPressed: onPressed,
      iconSize: context.iconTheme.size,
      icon: Icon(
        iconData,
      ),
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
