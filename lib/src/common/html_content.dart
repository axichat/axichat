// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;
import 'package:axichat/src/common/url_safety.dart';

class HtmlContentCodec {
  static const String _webViewViewportContent =
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no';
  static const String _webViewBaseStyle = '''
html, body {
  margin: 0 !important;
  padding: 0 !important;
  width: auto !important;
  max-width: 100% !important;
  overflow-x: hidden !important;
  -webkit-text-size-adjust: 100% !important;
  font-size: 15px !important;
  line-height: 1.45 !important;
}
body {
  overflow-wrap: anywhere !important;
  word-break: break-word !important;
}
body * {
  box-sizing: border-box !important;
  font-size: inherit !important;
  line-height: inherit !important;
}
img {
  max-width: 100% !important;
  height: auto !important;
}
table {
  max-width: 100% !important;
  width: auto !important;
  table-layout: auto !important;
  display: block !important;
}
tbody, thead, tfoot, tr, td, th {
  display: block !important;
  width: auto !important;
  max-width: 100% !important;
}
div, p, span, a, li, td, th {
  max-width: 100% !important;
  overflow-wrap: anywhere !important;
  word-break: break-word !important;
  white-space: normal !important;
  font-size: inherit !important;
  line-height: inherit !important;
}
pre, code {
  white-space: pre-wrap !important;
  word-break: break-word !important;
  font-size: 0.95em !important;
}
*[width], *[style*="width"], *[style*="min-width"], *[style*="max-width"] {
  max-width: 100% !important;
}
*[nowrap], *[style*="white-space"] {
  white-space: normal !important;
}
''';
  static const Set<String> _webViewStylePropertiesToStrip = <String>{
    'font-size',
    'line-height',
    'max-width',
    'min-width',
    'white-space',
    'width',
  };
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
  static const Set<String> _lineBreakTags = <String>{'br', 'hr'};
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
  static const Set<String> _sanitizedVoidTags = <String>{'br', 'hr', 'img'};
  static const Set<String> _plainTextHtmlTags = <String>{
    'a',
    'b',
    'body',
    'br',
    'div',
    'em',
    'font',
    'html',
    'i',
    'p',
    'small',
    'span',
    'strong',
    'sub',
    'sup',
    'u',
  };
  static const Set<String> _plainTextHtmlIgnoredTags = <String>{
    'head',
    'link',
    'meta',
    'style',
    'title',
  };
  static const Set<String> _plainTextHtmlGlobalAttributes = <String>{
    'class',
    'dir',
    'id',
    'lang',
    'title',
  };
  static const Set<String> _plainTextHtmlLinkAttributes = <String>{
    'href',
    'rel',
    'target',
    'title',
  };
  static const Set<String> _plainTextHtmlFontAttributes = <String>{
    'color',
    'face',
    'size',
  };
  static const Set<String> _plainTextHtmlStyleProperties = <String>{
    'background-color',
    'color',
    'direction',
    'display',
    'font-family',
    'font-size',
    'font-style',
    'font-weight',
    'line-height',
    'margin',
    'margin-bottom',
    'margin-left',
    'margin-right',
    'margin-top',
    'padding',
    'padding-bottom',
    'padding-left',
    'padding-right',
    'padding-top',
    'text-align',
    'text-decoration',
    'unicode-bidi',
    'white-space',
  };
  static const String _directionAttribute = 'dir';
  static const Set<String> _plainTextDirectionValues = <String>{
    'auto',
    'ltr',
    'rtl',
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
  static const Set<String> _sanitizedImageSchemes = <String>{'https', 'data'};
  static const String _hrefAttribute = 'href';
  static const String _srcAttribute = 'src';
  static const String _titleAttribute = 'title';
  static const String _altAttribute = 'alt';
  static const String _widthAttribute = 'width';
  static const String _heightAttribute = 'height';
  static const String _colspanAttribute = 'colspan';
  static const String _rowspanAttribute = 'rowspan';
  static const int _maxHtmlInputLength = 8000000;
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
      final document = _prepareEmailHtmlDocument(
        trimmed,
        allowRemoteImages: false,
        includeWebViewChrome: false,
      );
      final nodes = document.body?.nodes.isNotEmpty == true
          ? document.body!.nodes
          : document.nodes;
      final budget = _HtmlNodeBudget(
        maxNodes: _maxHtmlNodeCount,
        maxDepth: _maxHtmlDepth,
        maxDuration: _maxHtmlParseDuration,
      );
      return _isPlainTextNodes(nodes, budget, 0);
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

  static String simplifyHtmlForWebView(String html) {
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
        _appendSimplifiedWebViewHtml(buffer, node, budget, 0);
      }
      final simplified = buffer.toString().trim();
      if (simplified.isNotEmpty) {
        return simplified;
      }
    } on Exception {
      // Fall back to the standard sanitizer below.
    }
    return sanitizeHtml(trimmed);
  }

  static bool webViewSimplificationLosesContent(String html) {
    final originalText = toPlainText(html).trim();
    if (originalText.isEmpty) {
      return false;
    }
    final simplifiedText = toPlainText(simplifyHtmlForWebView(html)).trim();
    if (simplifiedText.isEmpty) {
      return true;
    }
    final originalLength = originalText.length;
    final simplifiedLength = simplifiedText.length;
    if (simplifiedLength * 2 < originalLength) {
      return true;
    }
    final originalLines = '\n'.allMatches(originalText).length + 1;
    final simplifiedLines = '\n'.allMatches(simplifiedText).length + 1;
    return originalLines >= 3 && simplifiedLines == 1;
  }

  static String? canonicalizeHtml(String? html) {
    final trimmed = html?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final sanitized = sanitizeHtml(trimmed);
    if (sanitized.isEmpty) return null;
    final collapsed = sanitized.replaceAll(_spaceCollapse, ' ');
    final normalized = collapsed
        .replaceAll(_multiLineBreaks, _doubleLineBreak)
        .trim();
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

  static bool shouldRenderRichEmailHtml({
    required String? normalizedHtmlBody,
    required String? normalizedHtmlText,
    required String renderedText,
  }) {
    if (normalizedHtmlBody == null) {
      return false;
    }
    if (isPlainTextHtml(normalizedHtmlBody)) {
      return false;
    }
    final comparableRenderedText = _normalizePlainText(renderedText);
    if (comparableRenderedText.isEmpty) {
      return true;
    }
    final comparableHtmlText = _normalizePlainText(normalizedHtmlText ?? '');
    if (comparableHtmlText.isEmpty) {
      return true;
    }
    return comparableRenderedText != comparableHtmlText;
  }

  static List<String> imageSources(String html) {
    try {
      final fragment = html_parser.parseFragment(_truncateHtmlInput(html));
      final budget = _HtmlNodeBudget(
        maxNodes: _maxHtmlNodeCount,
        maxDepth: _maxHtmlDepth,
        maxDuration: _maxHtmlParseDuration,
      );
      final sources = <String>[];
      final seenSources = <String>{};
      _collectImageSources(fragment.nodes, sources, seenSources, budget, 0);
      return sources;
    } on Exception {
      return const <String>[];
    }
  }

  static bool containsRemoteImages(String html) {
    for (final source in imageSources(html)) {
      final uri = Uri.tryParse(source);
      final scheme = uri?.scheme.trim().toLowerCase();
      if (scheme == 'https') return true;
    }
    return false;
  }

  static String prepareEmailHtmlForFlutterHtml(
    String html, {
    required bool allowRemoteImages,
  }) {
    try {
      final document = _prepareEmailHtmlDocument(
        html,
        allowRemoteImages: allowRemoteImages,
        includeWebViewChrome: false,
      );
      final bodyHtml = document.body?.innerHtml.trim();
      final sourceHtml = bodyHtml != null && bodyHtml.isNotEmpty
          ? bodyHtml
          : document.outerHtml;
      final simplifiedHtml = simplifyHtmlForWebView(sourceHtml);
      if (simplifiedHtml.isNotEmpty) {
        return simplifiedHtml;
      }
      return sourceHtml;
    } on Exception {
      return html;
    }
  }

  static String prepareEmailHtmlForWebView(
    String html, {
    required bool allowRemoteImages,
  }) {
    try {
      final document = _prepareEmailHtmlDocument(
        html,
        allowRemoteImages: allowRemoteImages,
        includeWebViewChrome: true,
      );
      return document.outerHtml;
    } on Exception {
      return html;
    }
  }

  static dom.Document _prepareEmailHtmlDocument(
    String html, {
    required bool allowRemoteImages,
    required bool includeWebViewChrome,
  }) {
    final document = html_parser.parse(_truncateHtmlInput(html));
    _removeHiddenEmailNodes(document.nodes);
    if (includeWebViewChrome) {
      final head =
          document.head ??
          (() {
            final createdHead = dom.Element.tag('head');
            final htmlElement = document.documentElement;
            final body = document.body;
            if (htmlElement != null) {
              final bodyIndex = body == null
                  ? -1
                  : htmlElement.nodes.indexOf(body);
              if (bodyIndex >= 0) {
                htmlElement.nodes.insert(bodyIndex, createdHead);
              } else {
                htmlElement.append(createdHead);
              }
            }
            return createdHead;
          })();
      for (final viewport in head.querySelectorAll('meta[name="viewport"]')) {
        viewport.remove();
      }
      head.append(
        dom.Element.tag('meta')
          ..attributes['name'] = 'viewport'
          ..attributes['content'] = _webViewViewportContent,
      );
      final styleElement = document.createElement('style')
        ..id = 'axichat-email-webview-style'
        ..text = _webViewBaseStyle;
      head.append(styleElement);
    }
    _normalizeWebViewNodes(document.nodes);
    for (final script in document.querySelectorAll('script')) {
      script.remove();
    }
    if (!allowRemoteImages) {
      for (final image in document.querySelectorAll('img')) {
        final source = image.attributes[_srcAttribute];
        final uri = Uri.tryParse(source?.trim() ?? '');
        final scheme = uri?.scheme.trim().toLowerCase();
        if (scheme == 'https') {
          image.remove();
        }
      }
    }
    _trimLeadingWebViewWhitespace(document.body);
    return document;
  }

  static void _normalizeWebViewNodes(List<dom.Node> nodes) {
    for (final node in nodes) {
      if (node is dom.Element) {
        node.attributes.remove('nowrap');
        final width = node.attributes['width']?.trim();
        if (width != null && width.isNotEmpty) {
          node.attributes.remove('width');
        }
        final style = node.attributes['style']?.trim();
        if (style != null && style.isNotEmpty) {
          final declarations = style
              .split(';')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .where((declaration) {
                final separatorIndex = declaration.indexOf(':');
                if (separatorIndex <= 0) {
                  return true;
                }
                final property = declaration
                    .substring(0, separatorIndex)
                    .trim()
                    .toLowerCase();
                return !_webViewStylePropertiesToStrip.contains(property);
              })
              .toList();
          if (declarations.isEmpty) {
            node.attributes.remove('style');
          } else {
            node.attributes['style'] = declarations.join('; ');
          }
        }
      }
      if (node.nodes.isNotEmpty) {
        _normalizeWebViewNodes(node.nodes);
      }
    }
  }

  static void _removeHiddenEmailNodes(List<dom.Node> nodes) {
    for (final node in nodes.toList()) {
      if (node is dom.Element) {
        if (_isHiddenEmailElement(node)) {
          node.remove();
          continue;
        }
      }
      if (node.nodes.isNotEmpty) {
        _removeHiddenEmailNodes(node.nodes);
      }
    }
  }

  static bool _isHiddenEmailElement(dom.Element element) {
    if (element.attributes.containsKey('hidden')) {
      return true;
    }
    final ariaHidden = element.attributes['aria-hidden']?.trim().toLowerCase();
    if (ariaHidden == 'true') {
      return true;
    }
    final style = element.attributes['style']?.trim().toLowerCase();
    if (style == null || style.isEmpty) {
      return false;
    }
    return style.contains('display:none') ||
        style.contains('display: none') ||
        style.contains('visibility:hidden') ||
        style.contains('visibility: hidden') ||
        style.contains('mso-hide:all') ||
        style.contains('mso-hide: all');
  }

  static void _trimLeadingWebViewWhitespace(dom.Element? body) {
    if (body == null) {
      return;
    }
    _trimLeadingWebViewNodes(body.nodes);
  }

  static void _trimLeadingWebViewNodes(List<dom.Node> nodes) {
    while (nodes.isNotEmpty && _isLeadingWebViewWhitespaceNode(nodes.first)) {
      nodes.first.remove();
    }
    if (nodes.isEmpty) {
      return;
    }
    final first = nodes.first;
    if (first is! dom.Element) {
      return;
    }
    _trimLeadingWebViewNodes(first.nodes);
    if (_isLeadingWebViewWhitespaceNode(first)) {
      first.remove();
      _trimLeadingWebViewNodes(nodes);
    }
  }

  static bool _isLeadingWebViewWhitespaceNode(dom.Node node) {
    if (node is dom.Comment) {
      return true;
    }
    if (node is dom.Text) {
      return node.text.replaceAll('\u00A0', ' ').trim().isEmpty;
    }
    if (node is! dom.Element) {
      return false;
    }
    final tag = (node.localName ?? '').toLowerCase();
    if (tag == 'br') {
      return true;
    }
    if (tag == 'img' || tag == 'video' || tag == 'audio' || tag == 'iframe') {
      return false;
    }
    if (node.nodes.isEmpty) {
      return true;
    }
    for (final child in node.nodes) {
      if (!_isLeadingWebViewWhitespaceNode(child)) {
        return false;
      }
    }
    return true;
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

  static void _collectImageSources(
    List<dom.Node> nodes,
    List<String> sources,
    Set<String> seenSources,
    _HtmlNodeBudget budget,
    int depth,
  ) {
    for (final node in nodes) {
      if (!budget.allow(depth)) {
        return;
      }
      if (node is dom.Element) {
        final tag = (node.localName ?? '').toLowerCase();
        if (tag == 'img') {
          final source = node.attributes[_srcAttribute]?.trim();
          if (source != null && source.isNotEmpty && seenSources.add(source)) {
            sources.add(source);
          }
        }
      }
      if (node.nodes.isNotEmpty) {
        _collectImageSources(
          node.nodes,
          sources,
          seenSources,
          budget,
          depth + 1,
        );
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
        if (_plainTextHtmlIgnoredTags.contains(tag)) {
          continue;
        }
        if (!_plainTextHtmlTags.contains(tag)) {
          return false;
        }
        if (!_isAllowedPlainTextElementAttributes(node)) {
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

  static bool _isAllowedPlainTextElementAttributes(dom.Element node) {
    if (node.attributes.isEmpty) {
      return true;
    }
    final tag = (node.localName ?? '').toLowerCase();
    for (final entry in node.attributes.entries) {
      final attributeName = entry.key.toString().trim().toLowerCase();
      if (attributeName == 'style') {
        if (!_hasOnlyAllowedPlainTextStyles(entry.value)) {
          return false;
        }
        continue;
      }
      if (_plainTextHtmlGlobalAttributes.contains(attributeName)) {
        if (attributeName != _directionAttribute) {
          continue;
        }
        final directionValue = entry.value.toString().trim().toLowerCase();
        if (_plainTextDirectionValues.contains(directionValue)) {
          continue;
        }
        return false;
      }
      if (tag == 'a' && _plainTextHtmlLinkAttributes.contains(attributeName)) {
        continue;
      }
      if (tag == 'font' &&
          _plainTextHtmlFontAttributes.contains(attributeName)) {
        continue;
      }
      if (attributeName.startsWith('aria-') ||
          attributeName.startsWith('data-')) {
        continue;
      }
      return false;
    }
    return true;
  }

  static bool _hasOnlyAllowedPlainTextStyles(String rawStyle) {
    final style = rawStyle.trim();
    if (style.isEmpty) {
      return true;
    }
    final declarations = style
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    for (final declaration in declarations) {
      final separatorIndex = declaration.indexOf(':');
      if (separatorIndex <= 0) {
        return false;
      }
      final property = declaration
          .substring(0, separatorIndex)
          .trim()
          .toLowerCase();
      if (!_plainTextHtmlStyleProperties.contains(property)) {
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

  static void _appendSimplifiedWebViewHtml(
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
    if (node is! dom.Element) {
      for (final child in node.nodes) {
        _appendSimplifiedWebViewHtml(buffer, child, budget, depth + 1);
      }
      return;
    }
    final tag = (node.localName ?? '').toLowerCase();
    if (tag == 'table' ||
        tag == 'tbody' ||
        tag == 'thead' ||
        tag == 'tfoot' ||
        tag == 'html' ||
        tag == 'body') {
      for (final child in node.nodes) {
        _appendSimplifiedWebViewHtml(buffer, child, budget, depth + 1);
      }
      return;
    }
    if (tag == 'tr' || tag == 'td' || tag == 'th') {
      buffer.write('<div>');
      for (final child in node.nodes) {
        _appendSimplifiedWebViewHtml(buffer, child, budget, depth + 1);
      }
      buffer.write('</div>');
      return;
    }
    if (!_sanitizedAllowedTags.contains(tag)) {
      for (final child in node.nodes) {
        _appendSimplifiedWebViewHtml(buffer, child, budget, depth + 1);
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
      _appendSimplifiedWebViewHtml(buffer, child, budget, depth + 1);
    }
    buffer
      ..write('</')
      ..write(tag)
      ..write('>');
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

  static String? _sanitizeUriValue(String value, Set<String> allowedSchemes) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (containsUnsafeUriText(trimmed) || containsSuspiciousUriText(trimmed)) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (!allowedSchemes.contains(scheme)) return null;
    if (scheme == 'data') {
      UriData? data;
      try {
        data = uri.data;
      } on FormatException {
        return null;
      }
      final mimeType = data?.mimeType.trim().toLowerCase() ?? '';
      if (!mimeType.startsWith('image/')) {
        return null;
      }
      return trimmed;
    }
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
    final withoutExtras = collapsed.replaceAll(
      _multiLineBreaks,
      _doubleLineBreak,
    );
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
