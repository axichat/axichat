import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'typing_text_input.dart';

const int _axiTextFieldDefaultMaxLines = 1;
const double _transparentCursorAlpha = 0.0;

class AxiTextField extends StatefulWidget {
  const AxiTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.strutStyle,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.maxLines = _axiTextFieldDefaultMaxLines,
    this.minLines,
    this.expands = false,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.autofillHints,
    this.cursorHeight,
    this.maxLength,
    this.maxLengthEnforcement,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final bool autocorrect;
  final bool enableSuggestions;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final int maxLines;
  final int? minLines;
  final bool expands;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final Iterable<String>? autofillHints;
  final double? cursorHeight;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;

  @override
  State<AxiTextField> createState() => _AxiTextFieldState();
}

class _AxiTextFieldState extends State<AxiTextField> {
  late final TypingTextEditingController _typingController =
      TypingTextEditingController(source: widget.controller);

  @override
  void didUpdateWidget(covariant AxiTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _typingController.updateSource(widget.controller, null);
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
      child: TextField(
        controller: _typingController,
        focusNode: widget.focusNode,
        decoration: widget.decoration,
        style: widget.style,
        strutStyle: widget.strutStyle,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        smartDashesType: widget.smartDashesType,
        smartQuotesType: widget.smartQuotesType,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        expands: widget.expands,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onEditingComplete: widget.onEditingComplete,
        textAlign: widget.textAlign,
        textAlignVertical: widget.textAlignVertical,
        autofillHints: widget.autofillHints,
        cursorColor: transparentCursor,
        cursorHeight: widget.cursorHeight,
        maxLength: widget.maxLength,
        maxLengthEnforcement: widget.maxLengthEnforcement,
      ),
    );
  }
}
