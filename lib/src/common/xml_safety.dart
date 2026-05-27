// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/message_content_limits.dart';
import 'package:xml/xml.dart';

String escapeXmlText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (!_isXmlCharacter(rune)) {
      buffer.writeCharCode(0xfffd);
      continue;
    }
    switch (rune) {
      case 0x26:
        buffer.write('&amp;');
        break;
      case 0x3c:
        buffer.write('&lt;');
        break;
      case 0x3e:
        buffer.write('&gt;');
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

String escapeXmlAttribute(String value) {
  return escapeXmlText(
    value,
  ).replaceAll("'", '&apos;').replaceAll('"', '&quot;');
}

String? escapeXmlAttributeOrNull(String? value) {
  return value == null ? null : escapeXmlAttribute(value);
}

bool _isXmlCharacter(int rune) {
  return rune == 0x09 ||
      rune == 0x0a ||
      rune == 0x0d ||
      (rune >= 0x20 && rune <= 0xd7ff) ||
      (rune >= 0xe000 && rune <= 0xfffd) ||
      (rune >= 0x10000 && rune <= 0x10ffff);
}

class XmlParseLimits {
  const XmlParseLimits({
    required this.maxBytes,
    required this.maxNodes,
    required this.maxDepth,
    required this.maxDuration,
  });

  final int maxBytes;
  final int maxNodes;
  final int maxDepth;
  final Duration maxDuration;
}

XmlDocument? tryParseXml(String raw, XmlParseLimits limits) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (utf8ByteLength(trimmed) > limits.maxBytes) {
    return null;
  }
  final start = DateTime.now();
  try {
    final document = XmlDocument.parse(trimmed);
    if (_isParseTimedOut(start, limits)) {
      return null;
    }
    return document;
  } on XmlParserException {
    return null;
  } on XmlTagException {
    return null;
  } on Exception {
    return null;
  }
}

bool _isParseTimedOut(DateTime startedAt, XmlParseLimits limits) {
  return DateTime.now().difference(startedAt) > limits.maxDuration;
}
