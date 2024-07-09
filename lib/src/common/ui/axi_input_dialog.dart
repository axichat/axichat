import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiInputDialog extends StatelessWidget {
  const AxiInputDialog({
    super.key,
    required this.title,
    required this.content,
    required this.callback,
  });

  final Widget title;
  final Widget content;
  final void Function() callback;

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: title,
      content: content,
      actions: [
        ShadButton.outline(
          onPressed: () {
            context.pop();
          },
          text: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: () {
            callback();
            context.pop();
          },
          text: const Text('Continue'),
        ),
      ],
    );
  }
}
