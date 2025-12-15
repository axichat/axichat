import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/common/ui/ui.dart';

class LocationInlineSuggestion extends StatefulWidget {
  const LocationInlineSuggestion({
    super.key,
    required this.controller,
    required this.helper,
    required this.child,
    this.contentPadding = EdgeInsets.zero,
    this.textStyle,
    this.suggestionColor,
  });

  final TextEditingController controller;
  final LocationAutocompleteHelper? helper;
  final Widget child;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? textStyle;
  final Color? suggestionColor;

  @override
  State<LocationInlineSuggestion> createState() =>
      _LocationInlineSuggestionState();
}

class _LocationInlineSuggestionState extends State<LocationInlineSuggestion> {
  _InlineSuggestion? _suggestion;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant LocationInlineSuggestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
    }
    if (oldWidget.helper != widget.helper) {
      _handleTextChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    if (!mounted) return;
    setState(() {
      _suggestion = _computeSuggestion(widget.controller.value);
    });
  }

  _InlineSuggestion? _computeSuggestion(TextEditingValue value) {
    final helper = widget.helper;
    if (helper == null) {
      return null;
    }
    if (!value.selection.isCollapsed) {
      return null;
    }
    final caret = value.selection.baseOffset >= 0
        ? value.selection.baseOffset
        : value.text.length;
    final prefix = value.text.substring(0, math.min(caret, value.text.length));
    final match = _locationTriggerPattern.firstMatch(prefix);
    if (match == null) {
      return null;
    }
    final rawQuery = match.group(2) ?? '';
    final trimmed = rawQuery.trimLeft();
    if (trimmed.length < 2) {
      return null;
    }
    final completion = helper.inlineCompletion(trimmed);
    if (completion == null) {
      return null;
    }

    final int replaceEnd = caret;
    final int replaceStart = replaceEnd - trimmed.length;
    if (replaceStart < 0) {
      return null;
    }

    final visiblePrefix = value.text.substring(0, replaceEnd);
    return _InlineSuggestion(
      prefixText: visiblePrefix,
      replaceStart: replaceStart,
      replaceEnd: replaceEnd,
      remainingText: completion.remainingText,
      replacementText: completion.suggestion.label,
    );
  }

  void _applySuggestion() {
    final suggestion = _suggestion;
    if (suggestion == null) {
      return;
    }
    final value = widget.controller.value;
    final newText = value.text.replaceRange(
      suggestion.replaceStart,
      suggestion.replaceEnd,
      suggestion.replacementText,
    );
    final int caretPosition =
        suggestion.replaceStart + suggestion.replacementText.length;
    widget.controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: caretPosition),
      composing: TextRange.empty,
    );
  }

  TextStyle _resolvedTextStyle(BuildContext context) {
    return widget.textStyle ??
        TextStyle(
          fontSize: 14,
          color: calendarTitleColor,
        );
  }

  Color _resolvedSuggestionColor(BuildContext context) {
    return widget.suggestionColor ?? calendarSubtitleColor;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.helper == null) {
      return widget.child;
    }
    final suggestion = _suggestion;
    return Stack(
      children: [
        widget.child,
        if (suggestion != null)
          Positioned.fill(
            child: Padding(
              padding: widget.contentPadding,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SuggestionText(
                  prefixText: suggestion.prefixText,
                  remainingText: suggestion.remainingText,
                  textStyle: _resolvedTextStyle(context),
                  color: _resolvedSuggestionColor(context),
                  onTap: _applySuggestion,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SuggestionText extends StatelessWidget {
  const _SuggestionText({
    required this.prefixText,
    required this.remainingText,
    required this.textStyle,
    required this.color,
    required this.onTap,
  });

  final String prefixText;
  final String remainingText;
  final TextStyle textStyle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (remainingText.isEmpty) {
      return const SizedBox.shrink();
    }
    final direction = Directionality.of(context);
    final textPainter = TextPainter(
      text: TextSpan(text: prefixText, style: textStyle),
      textDirection: direction,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    final double prefixWidth = textPainter.size.width;

    return Transform.translate(
      offset: Offset(prefixWidth, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Text(
          remainingText,
          style: textStyle.copyWith(color: color),
        ),
      ),
    );
  }
}

class _InlineSuggestion {
  const _InlineSuggestion({
    required this.prefixText,
    required this.replaceStart,
    required this.replaceEnd,
    required this.remainingText,
    required this.replacementText,
  });

  final String prefixText;
  final int replaceStart;
  final int replaceEnd;
  final String remainingText;
  final String replacementText;
}

final RegExp _locationTriggerPattern =
    RegExp(r'(?:^|[\s,.;])(at|in|@)\s+([^\n]*)$', caseSensitive: false);
