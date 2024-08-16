import 'package:chat/src/app.dart';
import 'package:flutter/material.dart';

class AxiListDivider extends StatelessWidget {
  const AxiListDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: context.colorScheme.border,
      thickness: 1.0,
      height: 1.0,
      indent: 16.0,
      endIndent: 16.0,
    );
  }
}
