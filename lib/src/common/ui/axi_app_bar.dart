import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class AxiAppBar extends StatelessWidget {
  const AxiAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      scrolledUnderElevation: 0.0,
      title: Text(
        'Axichat',
        style: context.textTheme.h3,
      ),
      shape: Border(
        bottom: BorderSide(color: context.colorScheme.border),
      ),
      actions: const [
        AxiVersion(),
      ],
    );
  }
}
