import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const passwordMinLength = 12;
const passwordMaxLength = 64;

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
      trailing: ShadIconButton(
        backgroundColor: context.colorScheme.muted,
        foregroundColor: context.colorScheme.mutedForeground,
        width: 24,
        height: 24,
        padding: EdgeInsets.zero,
        decoration: const ShadDecoration(
          secondaryBorder: ShadBorder.none,
          secondaryFocusedBorder: ShadBorder.none,
        ),
        icon: Icon(
          obscure ? LucideIcons.eyeOff : LucideIcons.eye,
          size: 16,
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
            if (text.length < passwordMinLength ||
                text.length > passwordMaxLength) {
              return 'Must be between $passwordMinLength '
                  'and $passwordMaxLength characters';
            }
            return null;
          },
    );
  }
}
