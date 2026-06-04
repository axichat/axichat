// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiOtpFormField extends StatelessWidget {
  const AxiOtpFormField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.length = defaultLength,
    this.validator,
    this.onChanged,
  });

  static const int defaultLength = 6;

  final TextEditingController controller;
  final bool enabled;
  final int length;
  final String? Function(String)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: _digitsOnly(controller.text),
      enabled: enabled,
      validator: (value) => validator?.call(_digitsOnly(value ?? '')),
      builder: (field) {
        final spacing = context.spacing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ShadInputOTP(
                maxLength: length,
                enabled: enabled,
                gap: spacing.xs,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                initialValue: field.value,
                onChanged: (value) {
                  final digits = _digitsOnly(value);
                  if (controller.text != digits) {
                    controller.value = TextEditingValue(
                      text: digits,
                      selection: TextSelection.collapsed(offset: digits.length),
                    );
                  }
                  field.didChange(digits);
                  onChanged?.call(digits);
                },
                children: [
                  ShadInputOTPGroup(
                    children: [
                      for (var index = 0; index < length; index++)
                        const ShadInputOTPSlot(),
                    ],
                  ),
                ],
              ),
            ),
            if (field.hasError) ...[
              SizedBox(height: spacing.xs),
              Text(
                field.errorText!,
                style: context.textTheme.small.copyWith(
                  color: context.colorScheme.destructive,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}
