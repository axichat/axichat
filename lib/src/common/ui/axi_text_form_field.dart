import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiTextFormField extends ShadInputFormField {
  AxiTextFormField({
    super.key,
    super.controller,
    super.placeholder,
    super.keyboardType,
    super.enabled,
    super.obscureText,
    super.validator,
    super.onChanged,
    super.onSubmitted,
    super.initialValue,
    super.description,
    super.inputFormatters,
    super.suffix,
    super.expands,
    super.minLines,
    super.maxLines,
    super.autocorrect,
  });

  @override
  Widget? get error => super.error != null && super.error is Text
      ? Padding(
          padding: inputSubtextInsets,
          child: super.error,
        )
      : null;
}
