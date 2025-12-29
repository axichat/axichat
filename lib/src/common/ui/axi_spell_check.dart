// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart'
    show SpellCheckResults, SpellCheckService, SuggestionSpan, TextEditingValue;

import 'axi_editable_text.dart' show EditableTextContextMenuBuilder;

@immutable
class SpellCheckConfiguration {
  const SpellCheckConfiguration({
    this.spellCheckService,
    this.misspelledSelectionColor,
    this.misspelledTextStyle,
    this.spellCheckSuggestionsToolbarBuilder,
  }) : _spellCheckEnabled = true;

  const SpellCheckConfiguration.disabled()
      : _spellCheckEnabled = false,
        spellCheckService = null,
        spellCheckSuggestionsToolbarBuilder = null,
        misspelledTextStyle = null,
        misspelledSelectionColor = null;

  final SpellCheckService? spellCheckService;

  final Color? misspelledSelectionColor;

  final TextStyle? misspelledTextStyle;

  final EditableTextContextMenuBuilder? spellCheckSuggestionsToolbarBuilder;

  final bool _spellCheckEnabled;

  bool get spellCheckEnabled => _spellCheckEnabled;

  SpellCheckConfiguration copyWith({
    SpellCheckService? spellCheckService,
    Color? misspelledSelectionColor,
    TextStyle? misspelledTextStyle,
    EditableTextContextMenuBuilder? spellCheckSuggestionsToolbarBuilder,
  }) {
    if (!_spellCheckEnabled) {
      // A new configuration should be constructed to enable spell check.
      return const SpellCheckConfiguration.disabled();
    }

    return SpellCheckConfiguration(
      spellCheckService: spellCheckService ?? this.spellCheckService,
      misspelledSelectionColor:
          misspelledSelectionColor ?? this.misspelledSelectionColor,
      misspelledTextStyle: misspelledTextStyle ?? this.misspelledTextStyle,
      spellCheckSuggestionsToolbarBuilder:
          spellCheckSuggestionsToolbarBuilder ??
              this.spellCheckSuggestionsToolbarBuilder,
    );
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'SpellCheckConfiguration')}('
        '${_spellCheckEnabled ? 'enabled' : 'disabled'}, '
        'service: $spellCheckService, '
        'text style: $misspelledTextStyle, '
        'toolbar builder: $spellCheckSuggestionsToolbarBuilder'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SpellCheckConfiguration &&
        other.spellCheckService == spellCheckService &&
        other.misspelledTextStyle == misspelledTextStyle &&
        other.spellCheckSuggestionsToolbarBuilder ==
            spellCheckSuggestionsToolbarBuilder &&
        other._spellCheckEnabled == _spellCheckEnabled;
  }

  @override
  int get hashCode => Object.hash(
        spellCheckService,
        misspelledTextStyle,
        spellCheckSuggestionsToolbarBuilder,
        _spellCheckEnabled,
      );
}

// Methods for displaying spell check results:

List<SuggestionSpan> _correctSpellCheckResults(
  String newText,
  String resultsText,
  List<SuggestionSpan> results,
) {
  final List<SuggestionSpan> correctedSpellCheckResults = <SuggestionSpan>[];
  int spanPointer = 0;
  int offset = 0;

  // Assumes that the order of spans has not been jumbled for optimization
  // purposes, and will only search since the previously found span.
  int searchStart = 0;

  while (spanPointer < results.length) {
    final SuggestionSpan currentSpan = results[spanPointer];
    final String currentSpanText = resultsText.substring(
      currentSpan.range.start,
      currentSpan.range.end,
    );
    final int spanLength = currentSpan.range.end - currentSpan.range.start;

    // Try finding SuggestionSpan from resultsText in new text.
    final String escapedText = RegExp.escape(currentSpanText);
    final RegExp currentSpanTextRegexp = RegExp('\\b$escapedText\\b');
    final int foundIndex =
        newText.substring(searchStart).indexOf(currentSpanTextRegexp);

    // Check whether word was found exactly where expected or elsewhere in the newText.
    final bool currentSpanFoundExactly =
        currentSpan.range.start == foundIndex + searchStart;
    final bool currentSpanFoundExactlyWithOffset =
        currentSpan.range.start + offset == foundIndex + searchStart;
    final bool currentSpanFoundElsewhere = foundIndex >= 0;

    if (currentSpanFoundExactly || currentSpanFoundExactlyWithOffset) {
      // currentSpan was found at the same index in newText and resultsText
      // or at the same index with the previously calculated adjustment by
      // the offset value, so apply it to new text by adding it to the list of
      // corrected results.
      final SuggestionSpan adjustedSpan = SuggestionSpan(
        TextRange(
            start: currentSpan.range.start + offset,
            end: currentSpan.range.end + offset),
        currentSpan.suggestions,
      );

      // Start search for the next misspelled word at the end of currentSpan.
      searchStart =
          math.min(currentSpan.range.end + 1 + offset, newText.length);
      correctedSpellCheckResults.add(adjustedSpan);
    } else if (currentSpanFoundElsewhere) {
      // Word was pushed forward but not modified.
      final int adjustedSpanStart = searchStart + foundIndex;
      final int adjustedSpanEnd = adjustedSpanStart + spanLength;
      final SuggestionSpan adjustedSpan = SuggestionSpan(
        TextRange(start: adjustedSpanStart, end: adjustedSpanEnd),
        currentSpan.suggestions,
      );

      // Start search for the next misspelled word at the end of the
      // adjusted currentSpan.
      searchStart = math.min(adjustedSpanEnd + 1, newText.length);
      // Adjust offset to reflect the difference between where currentSpan
      // was positioned in resultsText versus in newText.
      offset = adjustedSpanStart - currentSpan.range.start;
      correctedSpellCheckResults.add(adjustedSpan);
    }
    spanPointer++;
  }
  return correctedSpellCheckResults;
}

TextSpan buildTextSpanWithSpellCheckSuggestions(
  TextEditingValue value,
  bool composingWithinCurrentTextRange,
  TextStyle? style,
  TextStyle misspelledTextStyle,
  SpellCheckResults spellCheckResults,
) {
  List<SuggestionSpan> spellCheckResultsSpans =
      spellCheckResults.suggestionSpans;
  final String spellCheckResultsText = spellCheckResults.spellCheckedText;

  if (spellCheckResultsText != value.text) {
    spellCheckResultsSpans = _correctSpellCheckResults(
      value.text,
      spellCheckResultsText,
      spellCheckResultsSpans,
    );
  }

  // We will draw the TextSpan tree based on the composing region, if it is
  // available.
  // TODO(camsim99): The two separate strategies for building TextSpan trees
  // based on the availability of a composing region should be merged:
  // https://github.com/flutter/flutter/issues/124142.
  final bool shouldConsiderComposingRegion =
      defaultTargetPlatform == TargetPlatform.android;
  if (shouldConsiderComposingRegion) {
    return TextSpan(
      style: style,
      children: _buildSubtreesWithComposingRegion(
        spellCheckResultsSpans,
        value,
        style,
        misspelledTextStyle,
        composingWithinCurrentTextRange,
      ),
    );
  }

  return TextSpan(
    style: style,
    children: _buildSubtreesWithoutComposingRegion(
      spellCheckResultsSpans,
      value,
      style,
      misspelledTextStyle,
      value.selection.baseOffset,
    ),
  );
}

List<TextSpan> _buildSubtreesWithoutComposingRegion(
  List<SuggestionSpan>? spellCheckSuggestions,
  TextEditingValue value,
  TextStyle? style,
  TextStyle misspelledStyle,
  int cursorIndex,
) {
  final List<TextSpan> textSpanTreeChildren = <TextSpan>[];

  int textPointer = 0;
  int currentSpanPointer = 0;
  int endIndex;
  final String text = value.text;
  final TextStyle misspelledJointStyle =
      style?.merge(misspelledStyle) ?? misspelledStyle;
  bool cursorInCurrentSpan = false;

  // Add text interwoven with any misspelled words to the tree.
  if (spellCheckSuggestions != null) {
    while (textPointer < text.length &&
        currentSpanPointer < spellCheckSuggestions.length) {
      final SuggestionSpan currentSpan =
          spellCheckSuggestions[currentSpanPointer];

      if (currentSpan.range.start > textPointer) {
        endIndex = currentSpan.range.start < text.length
            ? currentSpan.range.start
            : text.length;
        textSpanTreeChildren.add(
          TextSpan(style: style, text: text.substring(textPointer, endIndex)),
        );
        textPointer = endIndex;
      } else {
        endIndex = currentSpan.range.end < text.length
            ? currentSpan.range.end
            : text.length;
        cursorInCurrentSpan = currentSpan.range.start <= cursorIndex &&
            currentSpan.range.end >= cursorIndex;
        textSpanTreeChildren.add(
          TextSpan(
            style: cursorInCurrentSpan ? style : misspelledJointStyle,
            text: text.substring(currentSpan.range.start, endIndex),
          ),
        );

        textPointer = endIndex;
        currentSpanPointer++;
      }
    }
  }

  // Add any remaining text to the tree if applicable.
  if (textPointer < text.length) {
    textSpanTreeChildren.add(
      TextSpan(style: style, text: text.substring(textPointer, text.length)),
    );
  }

  return textSpanTreeChildren;
}

List<TextSpan> _buildSubtreesWithComposingRegion(
  List<SuggestionSpan>? spellCheckSuggestions,
  TextEditingValue value,
  TextStyle? style,
  TextStyle misspelledStyle,
  bool composingWithinCurrentTextRange,
) {
  final List<TextSpan> textSpanTreeChildren = <TextSpan>[];

  int textPointer = 0;
  int currentSpanPointer = 0;
  int endIndex;
  SuggestionSpan currentSpan;
  final String text = value.text;
  final TextRange composingRegion = value.composing;
  final TextStyle composingTextStyle =
      style?.merge(const TextStyle(decoration: TextDecoration.underline)) ??
          const TextStyle(decoration: TextDecoration.underline);
  final TextStyle misspelledJointStyle =
      style?.merge(misspelledStyle) ?? misspelledStyle;
  bool textPointerWithinComposingRegion = false;
  bool currentSpanIsComposingRegion = false;

  // Add text interwoven with any misspelled words to the tree.
  if (spellCheckSuggestions != null) {
    while (textPointer < text.length &&
        currentSpanPointer < spellCheckSuggestions.length) {
      currentSpan = spellCheckSuggestions[currentSpanPointer];

      if (currentSpan.range.start > textPointer) {
        endIndex = currentSpan.range.start < text.length
            ? currentSpan.range.start
            : text.length;
        textPointerWithinComposingRegion =
            composingRegion.start >= textPointer &&
                composingRegion.end <= endIndex &&
                !composingWithinCurrentTextRange;

        if (textPointerWithinComposingRegion) {
          _addComposingRegionTextSpans(
            textSpanTreeChildren,
            text,
            textPointer,
            composingRegion,
            style,
            composingTextStyle,
          );
          textSpanTreeChildren.add(
            TextSpan(
                style: style,
                text: text.substring(composingRegion.end, endIndex)),
          );
        } else {
          textSpanTreeChildren.add(
            TextSpan(style: style, text: text.substring(textPointer, endIndex)),
          );
        }

        textPointer = endIndex;
      } else {
        endIndex = currentSpan.range.end < text.length
            ? currentSpan.range.end
            : text.length;
        currentSpanIsComposingRegion = textPointer >= composingRegion.start &&
            endIndex <= composingRegion.end &&
            !composingWithinCurrentTextRange;
        textSpanTreeChildren.add(
          TextSpan(
            style: currentSpanIsComposingRegion
                ? composingTextStyle
                : misspelledJointStyle,
            text: text.substring(currentSpan.range.start, endIndex),
          ),
        );

        textPointer = endIndex;
        currentSpanPointer++;
      }
    }
  }

  // Add any remaining text to the tree if applicable.
  if (textPointer < text.length) {
    if (textPointer < composingRegion.start &&
        !composingWithinCurrentTextRange) {
      _addComposingRegionTextSpans(
        textSpanTreeChildren,
        text,
        textPointer,
        composingRegion,
        style,
        composingTextStyle,
      );

      if (composingRegion.end != text.length) {
        textSpanTreeChildren.add(
          TextSpan(
              style: style,
              text: text.substring(composingRegion.end, text.length)),
        );
      }
    } else {
      textSpanTreeChildren.add(
        TextSpan(style: style, text: text.substring(textPointer, text.length)),
      );
    }
  }

  return textSpanTreeChildren;
}

void _addComposingRegionTextSpans(
  List<TextSpan> treeChildren,
  String text,
  int start,
  TextRange composingRegion,
  TextStyle? style,
  TextStyle composingTextStyle,
) {
  treeChildren.add(TextSpan(
      style: style, text: text.substring(start, composingRegion.start)));
  treeChildren.add(
    TextSpan(
      style: composingTextStyle,
      text: text.substring(composingRegion.start, composingRegion.end),
    ),
  );
}
