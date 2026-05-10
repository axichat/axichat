// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';

/// Shared calendar text field with consistent styling across the quick add
/// modal, popover editor, and sidebar forms. It routes through the shared Axi
/// input stack so padding, caret geometry, and typing motion stay consistent.
class TaskTextField extends StatelessWidget {
  const TaskTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.labelText,
    this.labelStyle,
    this.hintText,
    this.hintStyle,
    this.minLines = 1,
    int? maxLines,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.contentPadding,
    this.textStyle,
    this.helperText,
    this.helperStyle,
    this.errorText,
    this.errorStyle,
  }) : maxLines = maxLines ?? minLines;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? labelText;
  final TextStyle? labelStyle;
  final String? hintText;
  final TextStyle? hintStyle;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;
  final String? helperText;
  final TextStyle? helperStyle;
  final String? errorText;
  final TextStyle? errorStyle;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets? resolvedPadding = contentPadding?.resolve(
      Directionality.of(context),
    );
    final Widget field = AxiTextInput(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      variant: AxiInputVariant.underline,
      decoration: errorText == null
          ? null
          : const ShadDecoration(hasError: true),
      style: textStyle,
      placeholderStyle: hintStyle,
      placeholder: hintText == null ? null : Text(hintText!),
      padding: resolvedPadding,
      leading: prefix,
      trailing: suffix,
    );

    if (labelText == null && helperText == null && errorText == null) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText case final String label) ...[
          Text(
            label,
            style:
                labelStyle ??
                context.textTheme.small.copyWith(
                  color: context.colorScheme.mutedForeground,
                ),
          ),
          SizedBox(height: context.spacing.xs),
        ],
        field,
        if (errorText case final String error)
          Padding(
            padding: inputSubtextInsets,
            child: Text(
              error,
              style:
                  errorStyle ??
                  context.textTheme.small.copyWith(
                    color: context.colorScheme.destructive,
                  ),
            ),
          )
        else if (helperText case final String helper)
          Padding(
            padding: inputSubtextInsets,
            child: Text(
              helper,
              style:
                  helperStyle ??
                  context.textTheme.small.copyWith(
                    color: context.colorScheme.mutedForeground,
                  ),
            ),
          ),
      ],
    );
  }
}
