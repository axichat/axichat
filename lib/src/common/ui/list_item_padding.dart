import 'package:flutter/material.dart';

class ListItemPadding extends StatelessWidget {
  const ListItemPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: child,
    );
  }
}
