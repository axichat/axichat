import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const passwordMaxLength = 64;

class PasswordInput extends StatefulWidget {
  const PasswordInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.enabled = false,
    this.confirmValidator,
    this.validator,
  });

  final bool enabled;
  final String? placeholder;
  final String? Function(String)? confirmValidator;
  final FormFieldValidator<String>? validator;
  final TextEditingController controller;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return AxiTextFormField(
      placeholder: Text(widget.placeholder ??
          (widget.confirmValidator != null ? 'Confirm password' : 'Password')),
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
      ).withTapBounce(),
      validator: (text) {
        final confirmationValidator =
            widget.confirmValidator ?? _defaultValidator;
        final baseResult = confirmationValidator(text);
        if (baseResult != null) {
          return baseResult;
        }
        if (widget.validator != null) {
          return widget.validator!(text);
        }
        return null;
      },
    );
  }

  String? _defaultValidator(String text) {
    if (text.isEmpty) {
      return 'Enter a password';
    }
    if (text.length > passwordMaxLength) {
      return 'Must be $passwordMaxLength characters or fewer';
    }
    return null;
  }
}
