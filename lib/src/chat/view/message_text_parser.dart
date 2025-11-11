import 'package:axichat/src/common/ui/dynamic_inline_text.dart';
import 'package:flutter/material.dart';

class ParsedMessageText {
  const ParsedMessageText({
    required this.body,
    required this.links,
  });

  final TextSpan body;
  final List<DynamicTextLink> links;
}

final _linkPattern = RegExp(
  r'((https?:\/\/|mailto:|xmpp:|www\.)[^\s<>()\[\]{}]+)',
  caseSensitive: false,
);

const _trailingPunctuation = '.,!?:;)';

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

  for (final match in _linkPattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(TextSpan(
        text: text.substring(index, match.start),
        style: baseStyle,
      ));
    }

    final matchText = match.group(0)!;
    var linkText = matchText;
    var linkStart = match.start;
    var linkEnd = match.end;
    while (linkText.isNotEmpty &&
        _trailingPunctuation.contains(linkText[linkText.length - 1])) {
      linkText = linkText.substring(0, linkText.length - 1);
      linkEnd -= 1;
    }

    if (linkText.isEmpty) {
      spans.add(TextSpan(text: matchText, style: baseStyle));
      index = match.end;
      continue;
    }

    final normalized = _normalizeLink(linkText);
    spans.add(
      TextSpan(
        text: linkText,
        style: linkStyle,
      ),
    );
    links.add(
      DynamicTextLink(
        range: TextRange(start: linkStart, end: linkEnd),
        url: normalized,
      ),
    );

    if (linkEnd < match.end) {
      spans.add(
        TextSpan(
          text: matchText.substring(linkText.length),
          style: baseStyle,
        ),
      );
    }

    index = match.end;
  }

  if (index < text.length) {
    spans.add(TextSpan(
      text: text.substring(index),
      style: baseStyle,
    ));
  }

  return ParsedMessageText(
    body: TextSpan(style: baseStyle, children: spans),
    links: links,
  );
}

String _normalizeLink(String value) {
  final trimmed = value.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('xmpp:')) {
    return trimmed;
  }
  if (lower.startsWith('www.')) {
    return 'https://$trimmed';
  }
  return 'https://$trimmed';
}
