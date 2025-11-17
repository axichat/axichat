import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiFab extends StatelessWidget {
  const AxiFab({
    super.key,
    required this.text,
    required this.iconData,
    this.onPressed,
    this.tooltip,
  });

  final String text;
  final IconData iconData;
  final void Function()? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = ShadButton(
      onPressed: onPressed,
      leading: Icon(iconData),
      child: Text(text),
    ).withTapBounce(enabled: onPressed != null);

    if (tooltip != null) {
      button = AxiTooltip(
        builder: (_) => Text(tooltip!),
        child: button,
      );
    }

    return button;
  }
}
