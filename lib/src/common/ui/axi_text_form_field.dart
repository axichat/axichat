import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'axi_input_form_field.dart';

class AxiTextFormField extends StatelessWidget {
  const AxiTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.keyboardType,
    this.enabled,
    this.obscureText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.initialValue,
    this.description,
    this.inputFormatters,
    this.trailing,
    this.expands,
    this.minLines,
    this.maxLines,
    this.autocorrect,
    this.textInputAction,
    this.autofocus,
    this.style,
    this.placeholderStyle,
    this.placeholderAlignment,
    this.inputPadding,
    this.crossAxisAlignment,
    this.constraints,
    this.padding,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Widget? placeholder;
  final TextInputType? keyboardType;
  final bool? enabled;
  final bool? obscureText;
  final String? Function(String)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? initialValue;
  final Widget? description;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? trailing;
  final bool? expands;
  final int? minLines;
  final int? maxLines;
  final bool? autocorrect;
  final TextInputAction? textInputAction;
  final bool? autofocus;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final Alignment? placeholderAlignment;
  final EdgeInsets? inputPadding;
  final CrossAxisAlignment? crossAxisAlignment;
  final BoxConstraints? constraints;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return AxiInputFormField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      keyboardType: keyboardType,
      enabled: enabled ?? true,
      obscureText: obscureText ?? false,
      validator: validator,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      initialValue: initialValue,
      description: description,
      inputFormatters: inputFormatters,
      trailing: trailing,
      expands: expands ?? false,
      minLines: minLines,
      maxLines: maxLines,
      autocorrect: autocorrect ?? true,
      textInputAction: textInputAction,
      autofocus: autofocus ?? false,
      style: style,
      placeholderStyle: placeholderStyle,
      placeholderAlignment: placeholderAlignment,
      inputPadding: inputPadding,
      crossAxisAlignment: crossAxisAlignment,
      constraints: constraints,
      padding: padding,
    );
  }
}
