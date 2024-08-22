import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PasswordInput extends StatefulWidget {
  const PasswordInput({
    super.key,
    this.enabled = false,
    this.confirmValidator,
    required this.controller,
  });

  final bool enabled;
  final String? Function(String)? confirmValidator;
  final TextEditingController controller;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool obscure = true;
  @override
  Widget build(BuildContext context) {
    return AxiTextFormField(
      placeholder: Text(
          widget.confirmValidator != null ? 'Confirm password' : 'Password'),
      enabled: widget.enabled,
      obscureText: obscure,
      controller: widget.controller,
      suffix: ShadButton(
        width: 24,
        height: 24,
        padding: EdgeInsets.zero,
        decoration: const ShadDecoration(
          secondaryBorder: ShadBorder.none,
          secondaryFocusedBorder: ShadBorder.none,
        ),
        icon: ShadImage.square(
          size: 16,
          obscure ? LucideIcons.eyeOff : LucideIcons.eye,
        ),
        onPressed: () {
          setState(() => obscure = !obscure);
        },
      ),
      validator: widget.confirmValidator ??
          (text) {
            if (text.isEmpty) {
              return 'Enter a password';
            }
            if (text.length < 8 || text.length > 64) {
              return 'Must be between 8 and 64 characters';
            }
            return null;
          },
    );
  }
}
