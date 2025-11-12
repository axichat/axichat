import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiIconButton extends StatelessWidget {
  static const double kDefaultSize = 36.0;

  const AxiIconButton({
    super.key,
    required this.iconData,
    this.onPressed,
    this.tooltip,
    this.color,
    this.borderColor,
  });

  final IconData iconData;
  final void Function()? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color resolvedForeground = color ?? colors.foreground;
    final Color resolvedBorder = borderColor ?? colors.border;

    Widget child = ShadIconButton.outline(
      decoration: ShadDecoration(border: ShadBorder.all(color: resolvedBorder)),
      height: kDefaultSize,
      width: kDefaultSize,
      foregroundColor: resolvedForeground,
      onPressed: onPressed,
      iconSize: context.iconTheme.size,
      icon: Icon(
        iconData,
      ),
    );

    child = child.withTapBounce(enabled: onPressed != null);

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
