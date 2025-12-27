import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

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
    'http',
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

  static String fromPlainText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final escaped = _escapeHtml(trimmed);
    return escaped.replaceAll(_lineBreak, '<br />$_lineBreak');
  }

  static String sanitizeHtml(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return '';
    final fragment = html_parser.parseFragment(trimmed);
    final buffer = StringBuffer();
    for (final node in fragment.nodes) {
      _appendSanitizedHtml(buffer, node);
    }
    return buffer.toString().trim();
  }

  static String toPlainText(String html) {
    final fragment = html_parser.parseFragment(html);
    final buffer = StringBuffer();
    _appendPlainText(buffer, fragment.nodes);
    return _normalizePlainText(buffer.toString());
  }

  static String? toXhtml(String html) {
    final fragment = html_parser.parseFragment(html);
    final builder = xml.XmlBuilder();
    for (final node in fragment.nodes) {
      _appendXml(builder, node);
    }
    final encoded = builder.buildFragment().toXmlString();
    final normalized = encoded.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static void _appendPlainText(
    StringBuffer buffer,
    List<dom.Node> nodes,
  ) {
    for (final node in nodes) {
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
        _appendPlainText(buffer, node.nodes);
        if (isBlock) {
          _appendLineBreak(buffer);
        }
        continue;
      }
      if (node.nodes.isNotEmpty) {
        _appendPlainText(buffer, node.nodes);
      }
    }
  }

  static void _appendXml(
    xml.XmlBuilder builder,
    dom.Node node,
  ) {
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
            _appendXml(builder, child);
          }
        },
      );
      return;
    }
    for (final child in node.nodes) {
      _appendXml(builder, child);
    }
  }

  static void _appendSanitizedHtml(
    StringBuffer buffer,
    dom.Node node,
  ) {
    if (node is dom.Text) {
      buffer.write(_escapeHtml(node.text));
      return;
    }
    if (node is dom.Element) {
      final tag = (node.localName ?? '').toLowerCase();
      if (!_sanitizedAllowedTags.contains(tag)) {
        for (final child in node.nodes) {
          _appendSanitizedHtml(buffer, child);
        }
        return;
      }
      final attributes = _sanitizeAttributes(tag, node.attributes);
      buffer
        ..write('<')
        ..write(tag);
      for (final entry in attributes.entries) {
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
        _appendSanitizedHtml(buffer, child);
      }
      buffer
        ..write('</')
        ..write(tag)
        ..write('>');
      return;
    }
    if (node.nodes.isNotEmpty) {
      for (final child in node.nodes) {
        _appendSanitizedHtml(buffer, child);
      }
    }
  }

  static Map<String, String> _sanitizeAttributes(
    String tag,
    Map<Object?, String> attributes,
  ) {
    final allowed =
        _sanitizedAllowedAttributes[tag] ?? const <String>{};
    if (allowed.isEmpty) return const <String, String>{};
    final sanitized = <String, String>{};
    for (final entry in attributes.entries) {
      final name = entry.key.toString().toLowerCase();
      if (!allowed.contains(name)) continue;
      final rawValue = entry.value;
      if (name == _hrefAttribute) {
        final safeValue =
            _sanitizeUriValue(rawValue, _sanitizedLinkSchemes);
        if (safeValue != null) {
          sanitized[name] = safeValue;
        }
        continue;
      }
      if (name == _srcAttribute) {
        final safeValue =
            _sanitizeUriValue(rawValue, _sanitizedImageSchemes);
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
}
