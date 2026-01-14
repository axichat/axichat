// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/message_content_limits.dart';
import 'package:xml/xml.dart';

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
