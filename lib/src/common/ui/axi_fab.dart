import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiFab extends StatelessWidget {
  const AxiFab({
    super.key,
    required this.text,
    required this.iconData,
    this.onPressed,
  });

  final String text;
  final IconData iconData;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton(
      onPressed: onPressed,
      leading: Icon(iconData),
      child: Text(text),
    );
  }
}
