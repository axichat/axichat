// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'axi_input.dart';

const int _axiTextInputDefaultMaxLines = 1;

class AxiTextInput extends StatelessWidget {
  const AxiTextInput({
    super.key,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.placeholder,
    this.enabled = true,
    this.readOnly = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.obscureText = false,
    this.minLines,
    this.maxLines = _axiTextInputDefaultMaxLines,
    this.expands = false,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.inputFormatters,
    this.decoration,
    this.variant = AxiInputVariant.ghost,
    this.style,
    this.strutStyle,
    this.cursorHeight,
    this.placeholderStyle,
    this.padding,
    this.inputPadding,
    this.leading,
    this.trailing,
    this.constraints,
    this.groupId,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? initialValue;
  final Widget? placeholder;
  final bool enabled;
  final bool readOnly;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool obscureText;
  final int? minLines;
  final int maxLines;
  final bool expands;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final ShadDecoration? decoration;
  final AxiInputVariant variant;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final double? cursorHeight;
  final TextStyle? placeholderStyle;
  final EdgeInsets? padding;
  final EdgeInsets? inputPadding;
  final Widget? leading;
  final Widget? trailing;
  final BoxConstraints? constraints;
  final Object? groupId;

  @override
  Widget build(BuildContext context) {
    return AxiInput(
      controller: controller,
      focusNode: focusNode,
      initialValue: initialValue,
      placeholder: placeholder,
      enabled: enabled,
      readOnly: readOnly,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: maxLines,
      expands: expands,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      decoration: decoration,
      variant: variant,
      style: style,
      strutStyle: strutStyle,
      cursorHeight: cursorHeight,
      placeholderStyle: placeholderStyle,
      padding: padding,
      inputPadding: inputPadding,
      leading: leading,
      trailing: trailing,
      constraints: constraints,
      groupId: groupId,
    );
  }
}
