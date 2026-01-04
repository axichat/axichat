// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;
import 'package:axichat/src/common/url_safety.dart';

class HtmlContentCodec {
  static const Set<String> _blockTags = <String>{
    'address',
    'article',
    'aside',
    'blockquote',
    'div',
    'dl',
    'fieldset',
    'figcaption',
    'figure',
    'footer',
    'form',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'header',
    'hr',
    'li',
    'main',
    'nav',
    'ol',
    'p',
    'pre',
    'section',
    'table',
    'tbody',
    'tfoot',
    'thead',
    'tr',
    'ul',
  };
  static const Set<String> _lineBreakTags = <String>{
    'br',
    'hr',
  };
  static const Set<String> _sanitizedAllowedTags = <String>{
    'a',
    'b',
    'blockquote',
    'br',
    'code',
    'div',
    'em',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'hr',
    'i',
    'img',
    'li',
    'ol',
    'p',
    'pre',
    'span',
    'strong',
    'table',
    'tbody',
    'td',
    'th',
    'thead',
    'tfoot',
    'tr',
    'u',
    'ul',
  };
  static const Set<String> _sanitizedVoidTags = <String>{
    'br',
    'hr',
    'img',
  };
  static const Set<String> _plainTextHtmlTags = <String>{
    'body',
    'br',
    'div',
    'html',
    'p',
    'span',
  };
  static const Set<String> _sanitizedLinkSchemes = <String>{
    'http',
    'https',
    'mailto',
    'xmpp',
  };
  static const Set<String> _sanitizedHostOptionalSchemes = <String>{
    'mailto',
    'xmpp',
  };
  static const Set<String> _sanitizedImageSchemes = <String>{
    'https',
  };
  static const String _hrefAttribute = 'href';
  static const String _srcAttribute = 'src';
  static const String _titleAttribute = 'title';
  static const String _altAttribute = 'alt';
  static const String _widthAttribute = 'width';
  static const String _heightAttribute = 'height';
  static const String _colspanAttribute = 'colspan';
  static const String _rowspanAttribute = 'rowspan';
  static const int _maxHtmlInputLength = 200000;
  static const int _maxHtmlNodeCount = 5000;
  static const int _maxHtmlDepth = 40;
  static const Duration _maxHtmlParseDuration = Duration(milliseconds: 100);
  static const Map<String, Set<String>> _sanitizedAllowedAttributes =
      <String, Set<String>>{
    'a': <String>{_hrefAttribute, _titleAttribute},
    'img': <String>{
      _srcAttribute,
      _altAttribute,
      _titleAttribute,
      _widthAttribute,
      _heightAttribute,
    },
    'td': <String>{_colspanAttribute, _rowspanAttribute},
    'th': <String>{_colspanAttribute, _rowspanAttribute},
  };
  static const String _lineBreak = '\n';
  static const String _doubleLineBreak = '\n\n';
  static final RegExp _spaceCollapse = RegExp(r'[ \t]+');
  static final RegExp _multiLineBreaks = RegExp(r'\n{3,}');

  static String? normalizeHtml(String? html) {
    final trimmed = html?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool isPlainTextHtml(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return true;
    try {
      final fragment = html_parser.parseFragment(_truncateHtmlInput(trimmed));
      final budget = _HtmlNodeBudget(
        maxNodes: _maxHtmlNodeCount,
        maxDepth: _maxHtmlDepth,
        maxDuration: _maxHtmlParseDuration,
      );
      return _isPlainTextNodes(fragment.nodes, budget, 0);
    } on Exception {
      return false;
    }
  }

  static String fromPlainText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final escaped = _escapeHtml(trimmed);
    return escaped.replaceAll(_lineBreak, '<br />$_lineBreak');
  }

  static String sanitizeHtml(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return '';
    try {
      final fragment = html_parser.parseFragment(_truncateHtmlInput(trimmed));
      final buffer = StringBuffer();
      final budget = _HtmlNodeBudget(
        maxNodes: _maxHtmlNodeCount,
        maxDepth: _maxHtmlDepth,
        maxDuration: _maxHtmlParseDuration,
      );
      for (final node in fragment.nodes) {
        _appendSanitizedHtml(buffer, node, budget, 0);
      }
      return buffer.toString().trim();
    } on Exception {
      return '';
    }
  }

  static String? canonicalizeHtml(String? html) {
    final trimmed = html?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final sanitized = sanitizeHtml(trimmed);
    if (sanitized.isEmpty) return null;
    final collapsed = sanitized.replaceAll(_spaceCollapse, ' ');
    final normalized =
        collapsed.replaceAll(_multiLineBreaks, _doubleLineBreak).trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String toPlainText(String html) {
    try {
      final fragment = html_parser.parseFragment(_truncateHtmlInput(html));
      final buffer = StringBuffer();
      final budget = _HtmlNodeBudget(
        maxNodes: _maxHtmlNodeCount,
        maxDepth: _maxHtmlDepth,
        maxDuration: _maxHtmlParseDuration,
      );
      _appendPlainText(buffer, fragment.nodes, budget, 0);
      return _normalizePlainText(buffer.toString());
    } on Exception {
      return '';
    }
  }

  static String? toXhtml(String html) {
    try {
      final fragment = html_parser.parseFragment(_truncateHtmlInput(html));
      final builder = xml.XmlBuilder();
      final budget = _HtmlNodeBudget(
        maxNodes: _maxHtmlNodeCount,
        maxDepth: _maxHtmlDepth,
        maxDuration: _maxHtmlParseDuration,
      );
      for (final node in fragment.nodes) {
        _appendXml(builder, node, budget, 0);
      }
      final encoded = builder.buildFragment().toXmlString();
      final normalized = encoded.trim();
      return normalized.isEmpty ? null : normalized;
    } on Exception {
      return null;
    }
  }

  static void _appendPlainText(
    StringBuffer buffer,
    List<dom.Node> nodes,
    _HtmlNodeBudget budget,
    int depth,
  ) {
    for (final node in nodes) {
      if (!budget.allow(depth)) {
        return;
      }
      if (node is dom.Text) {
        buffer.write(node.text);
        continue;
      }
      if (node is dom.Element) {
        final tag = (node.localName ?? '').toLowerCase();
        if (_lineBreakTags.contains(tag)) {
          _appendLineBreak(buffer);
          continue;
        }
        final isBlock = _blockTags.contains(tag);
        if (isBlock) {
          _appendLineBreak(buffer);
        }
        _appendPlainText(buffer, node.nodes, budget, depth + 1);
        if (isBlock) {
          _appendLineBreak(buffer);
        }
        continue;
      }
      if (node.nodes.isNotEmpty) {
        _appendPlainText(buffer, node.nodes, budget, depth + 1);
      }
    }
  }

  static bool _isPlainTextNodes(
    List<dom.Node> nodes,
    _HtmlNodeBudget budget,
    int depth,
  ) {
    for (final node in nodes) {
      if (!budget.allow(depth)) {
        return false;
      }
      if (node is dom.Text) {
        continue;
      }
      if (node is dom.Comment) {
        continue;
      }
      if (node is dom.Element) {
        final tag = (node.localName ?? '').toLowerCase();
        if (!_plainTextHtmlTags.contains(tag)) {
          return false;
        }
        if (node.attributes.isNotEmpty) {
          return false;
        }
        if (!_isPlainTextNodes(node.nodes, budget, depth + 1)) {
          return false;
        }
        continue;
      }
      if (node.nodes.isNotEmpty &&
          !_isPlainTextNodes(node.nodes, budget, depth + 1)) {
        return false;
      }
    }
    return true;
  }

  static void _appendXml(
    xml.XmlBuilder builder,
    dom.Node node,
    _HtmlNodeBudget budget,
    int depth,
  ) {
    if (!budget.allow(depth)) {
      return;
    }
    if (node is dom.Text) {
      builder.text(node.text);
      return;
    }
    if (node is dom.Element) {
      final tag = (node.localName ?? '').toLowerCase();
      final attributes = <String, String>{};
      for (final entry in node.attributes.entries) {
        attributes[entry.key.toString()] = entry.value;
      }
      builder.element(
        tag,
        attributes: attributes,
        nest: () {
          for (final child in node.nodes) {
            _appendXml(builder, child, budget, depth + 1);
          }
        },
      );
      return;
    }
    for (final child in node.nodes) {
      _appendXml(builder, child, budget, depth + 1);
    }
  }

  static void _appendSanitizedHtml(
    StringBuffer buffer,
    dom.Node node,
    _HtmlNodeBudget budget,
    int depth,
  ) {
    if (!budget.allow(depth)) {
      return;
    }
    if (node is dom.Text) {
      buffer.write(_escapeHtml(node.text));
      return;
    }
    if (node is dom.Element) {
      final tag = (node.localName ?? '').toLowerCase();
      if (!_sanitizedAllowedTags.contains(tag)) {
        for (final child in node.nodes) {
          _appendSanitizedHtml(buffer, child, budget, depth + 1);
        }
        return;
      }
      final attributes = _sanitizeAttributes(tag, node.attributes);
      buffer
        ..write('<')
        ..write(tag);
      final entries = attributes.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        buffer
          ..write(' ')
          ..write(entry.key)
          ..write('="')
          ..write(_escapeHtml(entry.value))
          ..write('"');
      }
      if (_sanitizedVoidTags.contains(tag)) {
        buffer.write(' />');
        return;
      }
      buffer.write('>');
      for (final child in node.nodes) {
        _appendSanitizedHtml(buffer, child, budget, depth + 1);
      }
      buffer
        ..write('</')
        ..write(tag)
        ..write('>');
      return;
    }
    if (node.nodes.isNotEmpty) {
      for (final child in node.nodes) {
        _appendSanitizedHtml(buffer, child, budget, depth + 1);
      }
    }
  }

  static Map<String, String> _sanitizeAttributes(
    String tag,
    Map<Object?, String> attributes,
  ) {
    final allowed = _sanitizedAllowedAttributes[tag] ?? const <String>{};
    if (allowed.isEmpty) return const <String, String>{};
    final sanitized = <String, String>{};
    for (final entry in attributes.entries) {
      final name = entry.key.toString().toLowerCase();
      if (!allowed.contains(name)) continue;
      final rawValue = entry.value;
      if (name == _hrefAttribute) {
        final safeValue = _sanitizeUriValue(rawValue, _sanitizedLinkSchemes);
        if (safeValue != null) {
          sanitized[name] = safeValue;
        }
        continue;
      }
      if (name == _srcAttribute) {
        final safeValue = _sanitizeUriValue(rawValue, _sanitizedImageSchemes);
        if (safeValue != null) {
          sanitized[name] = safeValue;
        }
        continue;
      }
      sanitized[name] = rawValue;
    }
    return sanitized;
  }

  static String? _sanitizeUriValue(
    String value,
    Set<String> allowedSchemes,
  ) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (containsUnsafeUriText(trimmed) || containsSuspiciousUriText(trimmed)) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (!allowedSchemes.contains(scheme)) return null;
    if (uri.userInfo.trim().isNotEmpty) return null;
    if (uri.host.trim().isEmpty &&
        !_sanitizedHostOptionalSchemes.contains(scheme)) {
      return null;
    }
    return trimmed;
  }

  static void _appendLineBreak(StringBuffer buffer) {
    if (buffer.isEmpty) return;
    if (buffer.toString().endsWith(_lineBreak)) {
      return;
    }
    buffer.write(_lineBreak);
  }

  static String _normalizePlainText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final collapsed = trimmed.replaceAll(_spaceCollapse, ' ');
    final withoutExtras =
        collapsed.replaceAll(_multiLineBreaks, _doubleLineBreak);
    final lines = withoutExtras.split(_lineBreak);
    final cleaned = <String>[];
    for (final line in lines) {
      final normalizedLine = line.trim();
      if (normalizedLine.isEmpty) continue;
      cleaned.add(normalizedLine);
    }
    return cleaned.join(_lineBreak);
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _truncateHtmlInput(String html) {
    if (html.length <= _maxHtmlInputLength) {
      return html;
    }
    return html.substring(0, _maxHtmlInputLength);
  }
}

class _HtmlNodeBudget {
  _HtmlNodeBudget({
    required this.maxNodes,
    required this.maxDepth,
    required this.maxDuration,
  });

  final int maxNodes;
  final int maxDepth;
  final Duration maxDuration;
  var _visited = 0;
  final Stopwatch _timer = Stopwatch()..start();

  bool allow(int depth) {
    if (depth > maxDepth) {
      return false;
    }
    if (_timer.elapsed > maxDuration) {
      return false;
    }
    if (_visited >= maxNodes) {
      return false;
    }
    _visited += 1;
    return true;
  }
}
