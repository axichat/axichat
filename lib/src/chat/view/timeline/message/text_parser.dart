// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/message_links.dart';
import 'package:flutter/material.dart';

class ParsedMessageText {
  const ParsedMessageText({required this.body, required this.links});

  final TextSpan body;
  final List<DynamicTextLink> links;
}

ParsedMessageText parseMessageText({
  required String text,
  required TextStyle baseStyle,
  required TextStyle linkStyle,
}) {
  if (text.isEmpty) {
    return ParsedMessageText(
      body: TextSpan(text: text, style: baseStyle),
      links: const [],
    );
  }

  final spans = <InlineSpan>[];
  final links = <DynamicTextLink>[];
  var index = 0;

  for (final match in messageLinkPattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(
        TextSpan(text: text.substring(index, match.start), style: baseStyle),
      );
    }

    final matchText = match.group(0)!;
    var linkText = matchText;
    var linkStart = match.start;
    var linkEnd = match.end;
    linkText = trimTrailingLinkPunctuation(linkText);
    linkEnd -= matchText.length - linkText.length;

    if (linkText.isEmpty) {
      spans.add(TextSpan(text: matchText, style: baseStyle));
      index = match.end;
      continue;
    }

    final normalized = normalizeMessageLink(linkText);
    spans.add(TextSpan(text: linkText, style: linkStyle));
    links.add(
      DynamicTextLink(
        range: TextRange(start: linkStart, end: linkEnd),
        url: normalized,
      ),
    );

    if (linkEnd < match.end) {
      spans.add(
        TextSpan(text: matchText.substring(linkText.length), style: baseStyle),
      );
    }

    index = match.end;
  }

  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: baseStyle));
  }

  return ParsedMessageText(
    body: TextSpan(style: baseStyle, children: spans),
    links: links,
  );
}
