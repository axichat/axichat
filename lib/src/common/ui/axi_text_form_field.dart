import 'package:flutter/material.dart';

class AxiTextFormField extends TextFormField {
  AxiTextFormField({
    super.key,
    super.controller,
    String? labelText,
    String? hintText,
    super.keyboardType,
    super.enabled,
    super.obscureText,
    super.validator,
    super.onChanged,
  }) : super(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: labelText,
            hintText: hintText,
          ),
        );
}
