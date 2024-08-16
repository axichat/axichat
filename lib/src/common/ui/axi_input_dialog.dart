import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiInputDialog extends StatelessWidget {
  const AxiInputDialog({
    super.key,
    required this.title,
    required this.content,
    this.callback,
    this.callbackText = 'Continue',
    this.actions = const [],
  });

  final Widget title;
  final Widget content;
  final void Function()? callback;
  final String callbackText;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: title,
      content: content,
      actions: [
        ShadButton.outline(
          onPressed: () => context.pop(),
          text: const Text('Cancel'),
        ),
        ...actions,
        ShadButton(
          onPressed: callback == null
              ? null
              : () {
                  callback!();
                  context.pop();
                },
          text: Text(callbackText),
        ),
      ],
    );
  }
}
