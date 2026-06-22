// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

class AxiHighlightedSubstringText extends StatelessWidget {
  const AxiHighlightedSubstringText({
    super.key,
    required this.text,
    required this.substring,
    required this.style,
    required this.highlightStyle,
    this.textAlign,
  });

  final String text;
  final String substring;
  final TextStyle style;
  final TextStyle highlightStyle;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final substringIndex = text.indexOf(substring);
    if (substring.isEmpty || substringIndex < 0) {
      return Text(text, style: style, textAlign: textAlign);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, substringIndex)),
          TextSpan(text: substring, style: highlightStyle),
          TextSpan(text: text.substring(substringIndex + substring.length)),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
