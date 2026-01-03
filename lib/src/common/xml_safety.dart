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
    if (document.doctypeElement != null) {
      return null;
    }
    final budget = _XmlNodeBudget(
      maxNodes: limits.maxNodes,
      maxDepth: limits.maxDepth,
      maxDuration: limits.maxDuration,
      startedAt: start,
    );
    if (!_walkXmlNodes(document, budget, 0)) {
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

bool _walkXmlNodes(XmlNode node, _XmlNodeBudget budget, int depth) {
  if (!budget.allow(depth)) return false;
  for (final child in node.children) {
    if (!budget.allow(depth + 1)) return false;
    if (!_walkXmlNodes(child, budget, depth + 1)) {
      return false;
    }
  }
  return true;
}

bool _isParseTimedOut(DateTime startedAt, XmlParseLimits limits) {
  return DateTime.now().difference(startedAt) > limits.maxDuration;
}

class _XmlNodeBudget {
  _XmlNodeBudget({
    required this.maxNodes,
    required this.maxDepth,
    required this.maxDuration,
    required this.startedAt,
  });

  final int maxNodes;
  final int maxDepth;
  final Duration maxDuration;
  final DateTime startedAt;
  var _nodeCount = 0;

  bool allow(int depth) {
    if (depth > maxDepth) return false;
    if (DateTime.now().difference(startedAt) > maxDuration) return false;
    _nodeCount += 1;
    if (_nodeCount > maxNodes) return false;
    return true;
  }
}
