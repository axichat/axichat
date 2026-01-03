// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
    this.semanticsLabel,
  });

  final bool enabled;
  final String? placeholder;
  final String? Function(String)? confirmValidator;
  final FormFieldValidator<String>? validator;
  final TextEditingController controller;
  final String? semanticsLabel;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final defaultLabel = widget.confirmValidator != null
        ? l10n.authPasswordConfirm
        : l10n.authPassword;
    final semanticsLabel = widget.semanticsLabel ?? defaultLabel;
    return Semantics(
      label: semanticsLabel,
      textField: true,
      child: AxiTextFormField(
        placeholder: Text(
          widget.placeholder ?? defaultLabel,
        ),
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
          final localizations = context.l10n;
          final confirmationValidator = widget.confirmValidator ??
              (value) => _defaultValidator(
                    localizations,
                    value,
                  );
          final baseResult = confirmationValidator(text);
          if (baseResult != null) {
            return baseResult;
          }
          if (widget.validator != null) {
            return widget.validator!(text);
          }
          return null;
        },
      ),
    );
  }

  String? _defaultValidator(AppLocalizations l10n, String text) {
    if (text.isEmpty) {
      return l10n.authPasswordRequired;
    }
    if (text.length > passwordMaxLength) {
      return l10n.authPasswordMaxLength(passwordMaxLength);
    }
    return null;
  }
}
