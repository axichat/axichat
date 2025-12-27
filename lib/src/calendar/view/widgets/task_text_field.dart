import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:axichat/src/common/ui/ui.dart';

/// Shared calendar text field with consistent styling across the quick add
/// modal, popover editor, and sidebar forms. The widget keeps the legacy
/// appearance while exposing knobs for padding, borders, and capitalization so
/// each surface can tailor behaviour without duplicating decoration code.
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
    this.borderRadius,
    this.focusBorderColor,
    this.fillColor,
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
  final double? borderRadius;
  final Color? focusBorderColor;
  final Color? fillColor;
  final TextStyle? textStyle;
  final String? helperText;
  final TextStyle? helperStyle;
  final String? errorText;
  final TextStyle? errorStyle;

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? 8;
    final Color focusedColor = focusBorderColor ?? calendarPrimaryColor;
    final Color effectiveFill = fillColor ?? calendarContainerColor;

    return TextField(
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
      style: textStyle ??
          TextStyle(
            color: calendarTitleColor,
            fontSize: 14,
          ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: labelStyle ??
            TextStyle(
              color: calendarSubtitleColor,
              fontSize: 14,
            ),
        hintText: hintText,
        hintStyle: hintStyle ??
            TextStyle(
              color: calendarTimeLabelColor,
              fontSize: 14,
            ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: calendarBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: calendarBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: focusedColor, width: 2),
        ),
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterMd,
            ),
        filled: true,
        fillColor: effectiveFill,
        prefixIcon: prefix,
        suffixIcon: suffix,
        helperText: helperText,
        helperStyle: helperStyle,
        errorText: errorText,
        errorStyle: errorStyle,
      ),
    );
  }
}
