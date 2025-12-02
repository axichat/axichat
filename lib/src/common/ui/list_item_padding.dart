import 'package:flutter/material.dart';

class ListItemPadding extends StatelessWidget {
  const ListItemPadding({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: child,
    );
  }
}
