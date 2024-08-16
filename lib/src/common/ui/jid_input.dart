import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

extension ValidJid on String {
  bool get isValidJid => RegExp(
          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
      .hasMatch(this);
}

class JidInput extends StatelessWidget {
  const JidInput({
    super.key,
    this.enabled = true,
    this.initialValue,
    this.onChanged,
  });

  final bool enabled;
  final String? initialValue;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return AxiTextFormField(
      autocorrect: false,
      enabled: enabled,
      initialValue: initialValue,
      placeholder: const Text('JID'),
      description: const Text('Example: friend@axi.im'),
      onChanged: onChanged,
      validator: (text) {
        if (text.isEmpty) {
          return 'Enter a JID';
        }

        if (!text.isValidJid) {
          return 'Enter a valid jid';
        }

        return null;
      },
    );
  }
}
