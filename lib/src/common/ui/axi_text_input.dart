import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'typing_text_input.dart';

const double _transparentCursorAlpha = 0.0;
const int _axiTextInputDefaultMaxLines = 1;
const String _emptyTextValue = '';

class AxiTextInput extends StatefulWidget {
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
    this.style,
    this.strutStyle,
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
  final TextStyle? style;
  final StrutStyle? strutStyle;

  @override
  State<AxiTextInput> createState() => _AxiTextInputState();
}

class _AxiTextInputState extends State<AxiTextInput> {
  late final TypingTextEditingController _typingController =
      TypingTextEditingController(
    source: widget.controller,
    initialValue: _initialValueFromWidget(),
  );

  @override
  void didUpdateWidget(covariant AxiTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.initialValue != widget.initialValue) {
      _typingController.updateSource(
        widget.controller,
        _initialValueFromWidget(),
      );
    }
  }

  @override
  void dispose() {
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color transparentCursor =
        ShadTheme.of(context).colorScheme.foreground.withValues(
              alpha: _transparentCursorAlpha,
            );
    return TypingTextAnimator(
      controller: _typingController,
      child: ShadInput(
        controller: _typingController,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        placeholder: widget.placeholder,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        expands: widget.expands,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        onSubmitted: widget.onSubmitted,
        inputFormatters: widget.inputFormatters,
        decoration: widget.decoration,
        style: widget.style,
        strutStyle: widget.strutStyle,
        cursorColor: transparentCursor,
      ),
    );
  }

  TextEditingValue _initialValueFromWidget() {
    return TextEditingValue(text: widget.initialValue ?? _emptyTextValue);
  }
}
