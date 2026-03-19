// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;
import 'package:axichat/src/common/url_safety.dart';

class HtmlContentCodec {
  static const String _htmlNamespaceUri = 'http://www.w3.org/1999/xhtml';
  static const Set<String> _flutterTableWrapperTags = <String>{
    'table',
    'tbody',
    'tfoot',
    'thead',
    'col',
    'colgroup',
  };
  static const Set<String> _flutterTableCellTags = <String>{'td', 'th'};
  static const String _tableCellInlineDisplayStyle =
      'display:inline-block; vertical-align:top; margin-right:8px;';
  static const String _tableCellHeaderStyle =
      'display:inline-block; vertical-align:top; margin-right:8px; font-weight:bold;';
  static const String _tableRowStyle =
      'display:block; padding:0; margin:0 0 4px 0;';
  static const String _webViewViewportContent =
      'width=device-width, initial-scale=1.0, viewport-fit=cover';
  static const String _webViewBaseStyle = '''
html, body {
  margin: 0 !important;
  padding: 0 !important;
  width: 100% !important;
  min-width: 0 !important;
  max-width: 100% !important;
  overflow-x: hidden !important;
  -webkit-text-size-adjust: 100% !important;
  font-size: 16px !important;
  line-height: 1.5 !important;
}
body {
  overflow-wrap: anywhere !important;
  word-break: break-word !important;
}
body * {
  box-sizing: border-box !important;
  font-size: inherit !important;
  line-height: inherit !important;
  max-width: 100% !important;
  min-width: 0 !important;
}
img {
  max-width: 100% !important;
  height: auto !important;
}
table {
  max-width: 100% !important;
  width: 100% !important;
  table-layout: fixed !important;
  border-collapse: collapse !important;
}
tbody, thead, tfoot, tr {
  width: 100% !important;
  max-width: 100% !important;
}
td, th {
  width: auto !important;
  max-width: 100% !important;
  overflow-wrap: anywhere !important;
  word-break: break-word !important;
  white-space: normal !important;
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
  static const Set<String> _remoteImageSchemes = <String>{'http', 'https'};
  static const Set<String> _sanitizedHostOptionalSchemes = <String>{
    'mailto',
    'xmpp',
  };
  static const Set<String> _sanitizedImageSchemes = <String>{'https', 'data'};
  static const Set<String> _webViewRemovedTags = <String>{
    'audio',
    'base',
    'button',
    'embed',
    'form',
    'frame',
    'frameset',
    'iframe',
    'input',
    'link',
    'meta',
    'object',
    'option',
    'select',
    'source',
    'svg',
    'textarea',
    'track',
    'video',
  };
  static const Set<String> _webViewRemovedAttributes = <String>{
    'action',
    'formaction',
    'poster',
    'ping',
    'srcdoc',
    'srcset',
  };
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
  static final RegExp _cssImportPattern = RegExp(
    r'@import\b[^;]*;?',
    caseSensitive: false,
  );
  static final RegExp _cssUrlPattern = RegExp(
    r'url\s*\([^)]*\)',
    caseSensitive: false,
  );
  static final RegExp _cssExpressionPattern = RegExp(
    r'expression\s*\([^)]*\)',
    caseSensitive: false,
  );
  static final RegExp _cssBehaviorPattern = RegExp(
    r'(?:-moz-binding|behavior)\s*:[^;]+;?',
    caseSensitive: false,
  );
  static final RegExp _blockedWebViewContentPattern = RegExp(
    r'<\s*(?:script|audio|base|button|embed|form|frame|frameset|iframe|input|link|meta|object|option|select|source|svg|textarea|track|video)\b|'
    r'\bon[a-z0-9_-]+\s*=|'
    r'\bxlink:href\s*=|'
    r'\b(?:action|formaction|poster|ping|srcdoc|srcset)\s*=|'
    r'javascript\s*:|vbscript\s*:|expression\s*\(|@import\b|url\s*\(|-moz-binding|behavior\s*:',
    caseSensitive: false,
  );
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
      if (_remoteImageSchemes.contains(scheme)) return true;
    }
    return false;
  }

  static bool containsBlockedWebViewContent(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    try {
      final fragment = html_parser.parseFragment(_truncateHtmlInput(trimmed));
      final budget = _HtmlNodeBudget(
        maxNodes: _maxHtmlNodeCount,
        maxDepth: _maxHtmlDepth,
        maxDuration: _maxHtmlParseDuration,
      );
      return _containsBlockedWebViewNodes(fragment.nodes, budget, 0);
    } on Exception {
      return _blockedWebViewContentPattern.hasMatch(trimmed);
    }
  }

  static String prepareEmailHtmlForFlutterHtml(
    String html, {
    required bool allowRemoteImages,
  }) {
    try {
      final document = _prepareFlutterHtmlDocument(
        html,
        allowRemoteImages: allowRemoteImages,
      );
      for (final styleElement in document.querySelectorAll('style')) {
        styleElement.remove();
      }
      final bodyHtml = document.body?.innerHtml.trim();
      final sourceHtml = bodyHtml != null && bodyHtml.isNotEmpty
          ? bodyHtml
          : document.outerHtml;
      if (sourceHtml.isNotEmpty) {
        return sourceHtml;
      }
    } on Exception {
      return sanitizeHtml(html);
    }
    return sanitizeHtml(html);
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
      return sanitizeHtml(html);
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
    _normalizeWebViewNodes(
      document.nodes,
      allowRemoteImages: allowRemoteImages,
    );
    _trimLeadingWebViewWhitespace(document.body);
    return document;
  }

  static dom.Document _prepareFlutterHtmlDocument(
    String html, {
    required bool allowRemoteImages,
  }) {
    final document = html_parser.parse(_truncateHtmlInput(html));
    _removeHiddenEmailNodes(document.nodes);
    _normalizeFlutterHtmlNodes(
      document.nodes,
      allowRemoteImages: allowRemoteImages,
    );
    _flattenFlutterTableLayout(document.nodes);
    _trimEmptyFlutterHtmlNodes(document.nodes);
    return document;
  }

  static void _flattenFlutterTableLayout(List<dom.Node> nodes) {
    var index = 0;
    while (index < nodes.length) {
      final node = nodes[index];
      if (node is dom.Element) {
        final tag = (node.localName ?? '').toLowerCase();
        if (tag == 'tr') {
          final rowNode = _formatFlutterTableRow(node);
          nodes[index] = rowNode;
          _flattenFlutterTableLayout(rowNode.nodes);
          index++;
          continue;
        }
        if (_flutterTableCellTags.contains(tag)) {
          final cellNode = _formatFlutterTableCell(node);
          if (cellNode == null) {
            nodes.removeAt(index);
            continue;
          }
          nodes[index] = cellNode;
          index++;
          continue;
        }
        if (_flutterTableWrapperTags.contains(tag)) {
          final replacementNodes = node.nodes.toList();
          _flattenFlutterTableLayout(replacementNodes);
          nodes.removeAt(index);
          for (
            var offset = replacementNodes.length - 1;
            offset >= 0;
            offset--
          ) {
            nodes.insert(index, replacementNodes[offset]);
          }
          continue;
        }
        if (node.nodes.isNotEmpty) {
          _flattenFlutterTableLayout(node.nodes);
        }
      }
      index++;
    }
  }

  static void _normalizeWebViewNodes(
    List<dom.Node> nodes, {
    required bool allowRemoteImages,
  }) {
    for (final node in List<dom.Node>.from(nodes)) {
      if (node is dom.Element) {
        if (_isBlockedWebViewElement(node)) {
          node.remove();
          continue;
        }
        final tag = (node.localName ?? '').toLowerCase();
        if (tag == 'style') {
          final sanitizedStyleText = _sanitizeWebViewStyleElementText(
            node.text,
          );
          if (sanitizedStyleText == null) {
            node.remove();
            continue;
          }
          node.text = sanitizedStyleText;
          continue;
        }
        var removeNode = false;
        final attributeNames = node.attributes.keys
            .map((key) => key.toString())
            .toList();
        for (final attributeName in attributeNames) {
          final normalizedName = attributeName.trim().toLowerCase();
          if (normalizedName.isEmpty) {
            node.attributes.remove(attributeName);
            continue;
          }
          if (normalizedName.startsWith('on') ||
              _webViewRemovedAttributes.contains(normalizedName)) {
            node.attributes.remove(attributeName);
            continue;
          }
          final rawValue = node.attributes[attributeName] ?? '';
          if (normalizedName == _hrefAttribute) {
            final safeValue = _sanitizeUriValue(
              rawValue,
              _sanitizedLinkSchemes,
            );
            if (safeValue == null) {
              node.attributes.remove(attributeName);
            } else {
              node.attributes[attributeName] = safeValue;
            }
            continue;
          }
          if (normalizedName == _srcAttribute) {
            if (tag != 'img') {
              node.attributes.remove(attributeName);
              continue;
            }
            final safeValue = _sanitizeWebViewImageSource(
              rawValue,
              allowRemoteImages: allowRemoteImages,
            );
            if (safeValue == null) {
              removeNode = true;
              break;
            }
            node.attributes[attributeName] = safeValue;
            continue;
          }
        }
        if (removeNode) {
          node.remove();
          continue;
        }
        node.attributes.remove('nowrap');
        final width = node.attributes['width']?.trim();
        if (width != null && width.isNotEmpty) {
          node.attributes.remove('width');
        }
        final style = node.attributes['style']?.trim();
        if (style != null && style.isNotEmpty) {
          final sanitizedStyle = _sanitizeWebViewInlineStyle(style);
          if (sanitizedStyle == null) {
            node.attributes.remove('style');
          } else {
            node.attributes['style'] = sanitizedStyle;
          }
        }
      }
      if (node.nodes.isNotEmpty) {
        _normalizeWebViewNodes(
          node.nodes,
          allowRemoteImages: allowRemoteImages,
        );
      }
    }
  }

  static dom.Element _formatFlutterTableRow(dom.Element row) {
    final formattedRow = dom.Element.tag('div')
      ..attributes['style'] = _tableRowStyle;
    var hadCells = false;
    final children = row.nodes.toList();
    for (final child in children) {
      final isCell =
          child is dom.Element &&
          _flutterTableCellTags.contains((child.localName ?? '').toLowerCase());
      if (!isCell) {
        formattedRow.nodes.add(child);
        continue;
      }
      final formattedCell = _formatFlutterTableCell(child);
      if (formattedCell == null) {
        continue;
      }
      if (hadCells) {
        formattedRow.nodes.add(dom.Text(' \u00A0 '));
      }
      formattedRow.nodes.add(formattedCell);
      hadCells = true;
    }
    if (!hadCells) {
      final fallbackText = _compactFlutterTablePreviewText(row.innerHtml);
      if (fallbackText.isNotEmpty) {
        formattedRow.nodes.add(dom.Text(fallbackText));
      }
    }
    return formattedRow;
  }

  static dom.Element? _formatFlutterTableCell(dom.Element cell) {
    final flattenedText = _compactFlutterTablePreviewText(cell.innerHtml);
    if (flattenedText.isEmpty) {
      return null;
    }
    final isHeader = (cell.localName ?? '').toLowerCase() == 'th';
    return dom.Element.tag('span')
      ..attributes['style'] = isHeader
          ? _tableCellHeaderStyle
          : _tableCellInlineDisplayStyle
      ..nodes.add(dom.Text(flattenedText));
  }

  static String _compactFlutterTablePreviewText(String html) {
    final plainText = toPlainText(
      html,
    ).replaceAll('\u00A0', ' ').replaceAll(_spaceCollapse, ' ').trim();
    if (plainText.isEmpty) {
      return '';
    }
    return plainText;
  }

  static void _normalizeFlutterHtmlNodes(
    List<dom.Node> nodes, {
    required bool allowRemoteImages,
  }) {
    for (final node in List<dom.Node>.from(nodes)) {
      if (node is dom.Element) {
        if (_isBlockedWebViewElement(node)) {
          node.remove();
          continue;
        }
        final tag = (node.localName ?? '').toLowerCase();
        if (tag == 'style') {
          final sanitizedStyleText = _sanitizeWebViewStyleElementText(
            node.text,
          );
          if (sanitizedStyleText == null) {
            node.remove();
            continue;
          }
          node.text = sanitizedStyleText;
          continue;
        }
        var removeNode = false;
        final attributeNames = node.attributes.keys
            .map((key) => key.toString())
            .toList();
        for (final attributeName in attributeNames) {
          final normalizedName = attributeName.trim().toLowerCase();
          if (normalizedName.isEmpty) {
            node.attributes.remove(attributeName);
            continue;
          }
          if (normalizedName.startsWith('on') ||
              _webViewRemovedAttributes.contains(normalizedName)) {
            node.attributes.remove(attributeName);
            continue;
          }
          final rawValue = node.attributes[attributeName] ?? '';
          if (normalizedName == _hrefAttribute) {
            final safeValue = _sanitizeUriValue(
              rawValue,
              _sanitizedLinkSchemes,
            );
            if (safeValue == null) {
              node.attributes.remove(attributeName);
            } else {
              node.attributes[attributeName] = safeValue;
            }
            continue;
          }
          if (normalizedName == _srcAttribute) {
            if (tag != 'img') {
              node.attributes.remove(attributeName);
              continue;
            }
            final safeValue = _sanitizeWebViewImageSource(
              rawValue,
              allowRemoteImages: allowRemoteImages,
            );
            if (safeValue == null) {
              removeNode = true;
              break;
            }
            node.attributes[attributeName] = safeValue;
            continue;
          }
          if (normalizedName == 'style') {
            final sanitizedStyle = _sanitizeFlutterHtmlInlineStyle(rawValue);
            if (sanitizedStyle == null) {
              node.attributes.remove(attributeName);
            } else {
              node.attributes[attributeName] = sanitizedStyle;
            }
          }
        }
        if (removeNode) {
          node.remove();
          continue;
        }
      }
      if (node.nodes.isNotEmpty) {
        _normalizeFlutterHtmlNodes(
          node.nodes,
          allowRemoteImages: allowRemoteImages,
        );
      }
    }
  }

  static bool _containsBlockedWebViewNodes(
    List<dom.Node> nodes,
    _HtmlNodeBudget budget,
    int depth,
  ) {
    for (final node in nodes) {
      if (!budget.allow(depth)) {
        return false;
      }
      if (node is dom.Element) {
        if (_isBlockedWebViewElement(node)) {
          return true;
        }
        final tag = (node.localName ?? '').toLowerCase();
        if (tag == 'style' && _containsBlockedWebViewStyleElement(node.text)) {
          return true;
        }
        for (final entry in node.attributes.entries) {
          final attributeName = entry.key.toString().trim().toLowerCase();
          if (attributeName.isEmpty) {
            continue;
          }
          if (attributeName.startsWith('on') ||
              _webViewRemovedAttributes.contains(attributeName)) {
            return true;
          }
          final rawValue = entry.value;
          if (attributeName == _hrefAttribute &&
              _sanitizeUriValue(rawValue, _sanitizedLinkSchemes) == null) {
            return true;
          }
          if (attributeName == _srcAttribute) {
            if (tag != 'img') {
              return true;
            }
            if (_imgSourceNeedsBlockedNotice(rawValue)) {
              return true;
            }
          }
          if (attributeName == 'style' &&
              _containsBlockedWebViewInlineStyle(rawValue)) {
            return true;
          }
        }
      }
      if (node.nodes.isNotEmpty &&
          _containsBlockedWebViewNodes(node.nodes, budget, depth + 1)) {
        return true;
      }
    }
    return false;
  }

  static bool _isBlockedWebViewElement(dom.Element element) {
    final namespace = element.namespaceUri?.trim();
    if (namespace != null &&
        namespace.isNotEmpty &&
        namespace != _htmlNamespaceUri) {
      return true;
    }
    final tag = (element.localName ?? '').toLowerCase();
    return tag == 'script' || _webViewRemovedTags.contains(tag);
  }

  static bool _imgSourceNeedsBlockedNotice(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    final scheme = uri?.scheme.trim().toLowerCase();
    if (_remoteImageSchemes.contains(scheme) || scheme == 'data') {
      return false;
    }
    return _sanitizeUriValue(trimmed, _sanitizedImageSchemes) == null;
  }

  static bool _containsBlockedWebViewInlineStyle(String style) {
    for (final declaration in style.split(';')) {
      final trimmed = declaration.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final separatorIndex = trimmed.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }
      final property = trimmed
          .substring(0, separatorIndex)
          .trim()
          .toLowerCase();
      final value = trimmed.substring(separatorIndex + 1).trim();
      if (value.isEmpty) {
        continue;
      }
      if (property == 'behavior' || property == '-moz-binding') {
        return true;
      }
      if (_containsUnsafeCssValue(value)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsBlockedWebViewStyleElement(String cssText) {
    final trimmed = cssText.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return containsUnsafeUriText(trimmed) ||
        containsSuspiciousUriText(trimmed) ||
        _cssImportPattern.hasMatch(trimmed) ||
        _cssUrlPattern.hasMatch(trimmed) ||
        _cssExpressionPattern.hasMatch(trimmed) ||
        _cssBehaviorPattern.hasMatch(trimmed);
  }

  static String? _sanitizeWebViewImageSource(
    String value, {
    required bool allowRemoteImages,
  }) {
    final safeValue = _sanitizeUriValue(value, _sanitizedImageSchemes);
    if (safeValue == null) {
      return null;
    }
    final uri = Uri.tryParse(safeValue);
    final scheme = uri?.scheme.trim().toLowerCase();
    if (!allowRemoteImages && _remoteImageSchemes.contains(scheme)) {
      return null;
    }
    return safeValue;
  }

  static String? _sanitizeFlutterHtmlInlineStyle(String style) {
    final declarations = style
        .split(';')
        .map(_sanitizeFlutterHtmlStyleDeclaration)
        .whereType<String>()
        .toList();
    if (declarations.isEmpty) {
      return null;
    }
    return declarations.join('; ');
  }

  static String? _sanitizeFlutterHtmlStyleDeclaration(String declaration) {
    final trimmed = declaration.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final separatorIndex = trimmed.indexOf(':');
    if (separatorIndex <= 0) {
      return null;
    }
    final property = trimmed.substring(0, separatorIndex).trim().toLowerCase();
    final value = trimmed.substring(separatorIndex + 1).trim();
    if (value.isEmpty) {
      return null;
    }
    if (property == 'behavior' || property == '-moz-binding') {
      return null;
    }
    if (!const <String>{
      'color',
      'background-color',
      'font',
      'font-size',
      'font-style',
      'font-weight',
      'font-family',
      'text-decoration',
      'text-align',
      'line-height',
      'letter-spacing',
      'white-space',
      'word-break',
      'overflow-wrap',
      'vertical-align',
      'margin',
      'margin-top',
      'margin-right',
      'margin-bottom',
      'margin-left',
      'padding',
      'padding-top',
      'padding-right',
      'padding-bottom',
      'padding-left',
      'border',
      'border-top',
      'border-right',
      'border-bottom',
      'border-left',
      'border-color',
      'border-style',
      'border-width',
      'border-radius',
      'list-style',
      'list-style-type',
    }.contains(property)) {
      return null;
    }
    if (_containsUnsafeCssValue(value)) {
      return null;
    }
    return '$property: $value';
  }

  static void _trimEmptyFlutterHtmlNodes(List<dom.Node> nodes) {
    for (final node in nodes.toList()) {
      if (node.nodes.isNotEmpty) {
        _trimEmptyFlutterHtmlNodes(node.nodes);
      }
      if (node is! dom.Element) {
        continue;
      }
      if (_isEmptyFlutterHtmlElement(node)) {
        node.remove();
      }
    }
  }

  static bool _isEmptyFlutterHtmlElement(dom.Element element) {
    final tag = (element.localName ?? '').toLowerCase();
    if (tag == 'img' || tag == 'br' || tag == 'hr') {
      return false;
    }
    if (const <String>{
      'html',
      'body',
      'table',
      'thead',
      'tbody',
      'tfoot',
      'tr',
      'td',
      'th',
      'ul',
      'ol',
      'li',
      'blockquote',
    }.contains(tag)) {
      return false;
    }
    if (element.text.replaceAll('\u00A0', ' ').trim().isNotEmpty) {
      return false;
    }
    for (final child in element.nodes) {
      if (child is dom.Comment) {
        continue;
      }
      if (child is dom.Text &&
          child.text.replaceAll('\u00A0', ' ').trim().isEmpty) {
        continue;
      }
      if (child is dom.Element && _isEmptyFlutterHtmlElement(child)) {
        continue;
      }
      return false;
    }
    return true;
  }

  static String? _sanitizeWebViewInlineStyle(String style) {
    final declarations = style
        .split(';')
        .map(_sanitizeWebViewStyleDeclaration)
        .whereType<String>()
        .toList();
    if (declarations.isEmpty) {
      return null;
    }
    return declarations.join('; ');
  }

  static String? _sanitizeWebViewStyleDeclaration(String declaration) {
    final trimmed = declaration.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final separatorIndex = trimmed.indexOf(':');
    if (separatorIndex <= 0) {
      return null;
    }
    final property = trimmed.substring(0, separatorIndex).trim().toLowerCase();
    if (_webViewStylePropertiesToStrip.contains(property)) {
      return null;
    }
    final value = trimmed.substring(separatorIndex + 1).trim();
    if (value.isEmpty) {
      return null;
    }
    if (_containsUnsafeCssValue(value)) {
      return null;
    }
    return '$property: $value';
  }

  static String? _sanitizeWebViewStyleElementText(String cssText) {
    final trimmed = cssText.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (containsUnsafeUriText(trimmed) || containsSuspiciousUriText(trimmed)) {
      return null;
    }
    final sanitized = trimmed
        .replaceAll(_cssImportPattern, '')
        .replaceAll(_cssUrlPattern, '')
        .replaceAll(_cssExpressionPattern, '')
        .replaceAll(_cssBehaviorPattern, '')
        .trim();
    if (sanitized.isEmpty) {
      return null;
    }
    return sanitized;
  }

  static bool _containsUnsafeCssValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return normalized.contains('url(') ||
        normalized.contains('expression(') ||
        normalized.contains('@import') ||
        normalized.contains('javascript:') ||
        normalized.contains('vbscript:') ||
        normalized.contains('-moz-binding') ||
        normalized.contains('behavior:') ||
        containsUnsafeUriText(normalized) ||
        containsSuspiciousUriText(normalized);
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
