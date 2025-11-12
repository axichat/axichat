import 'package:axichat/src/common/ui/axi_tap_bounce.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContextActionButton extends StatelessWidget {
  const ContextActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    ).withTapBounce(enabled: onPressed != null);
  }
}
