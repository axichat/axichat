import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/axi_tap_bounce.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContextActionButton extends StatelessWidget {
  const ContextActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.destructive = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final destructiveColor =
        destructive ? context.colorScheme.destructive : null;
    final textStyle = destructive
        ? context.textTheme.small.copyWith(color: destructiveColor)
        : null;
    return ShadButton.outline(
      onPressed: onPressed,
      child: IconTheme.merge(
        data: IconThemeData(color: destructiveColor),
        child: DefaultTextStyle.merge(
          style: textStyle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
      ),
    ).withTapBounce(enabled: onPressed != null);
  }
}
