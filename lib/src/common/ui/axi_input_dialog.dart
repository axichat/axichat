import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AxiInputDialog extends AlertDialog {
  const AxiInputDialog({
    super.key,
    super.title,
    super.content,
    required this.callback,
  });

  final void Function() callback;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title,
      content: content,
      actions: [
        TextButton(
          onPressed: () {
            context.pop();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            callback();
            context.pop();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.green),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
