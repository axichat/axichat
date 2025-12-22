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
