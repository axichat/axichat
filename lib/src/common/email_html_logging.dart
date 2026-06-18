// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const bool emailHtmlLoggingEnabled = bool.fromEnvironment(
  'AXI_EMAIL_HTML_LOGGING',
);
const bool emailPlainTextBubbleExperiment = bool.fromEnvironment(
  'AXI_PLAIN_EMAIL_BUBBLES',
);

const Set<String> _maskedAttributes = {
  'href',
  'src',
  'alt',
  'title',
  'aria-label',
  'placeholder',
  'srcdoc',
};

final Set<Object> _loggedEmailHtmlStageKeys = <Object>{};

void logEmailHtmlStages({
  required Object contentKey,
  required Map<String, String?> stages,
  bool dedupe = true,
  bool force = false,
}) {
  if (!force && !emailHtmlLoggingEnabled) {
    return;
  }
  final entries = <MapEntry<String, String?>>[];
  for (final entry in stages.entries) {
    if (!dedupe || _loggedEmailHtmlStageKeys.add((contentKey, entry.key))) {
      entries.add(entry);
    }
  }
  if (entries.isEmpty) {
    return;
  }
  for (final entry in entries) {
    debugPrint('=== axichat email html [$contentKey] ${entry.key} BEGIN ===');
    _printChunked(maskEmailHtml(entry.value ?? ''));
  }
  debugPrint('=== axichat email html [$contentKey] END ===');
}

String maskEmailHtml(String html) {
  if (html.isEmpty) {
    return html;
  }
  try {
    final document = html_parser.parse(html);
    for (final node in document.nodes) {
      _maskNode(node);
    }
    return document.outerHtml;
  } on Exception {
    return '<masking-failed length=${html.length}>';
  }
}

void _maskNode(dom.Node node) {
  if (node is dom.Text) {
    node.data = _maskText(node.data);
    return;
  }
  if (node is dom.Comment) {
    _maskComment(node);
    return;
  }
  if (node is dom.Element) {
    _maskElement(node);
  }
}

void _maskElement(dom.Element element) {
  final tag = element.localName ?? '';
  for (final attribute in _maskedAttributes) {
    final value = element.attributes[attribute];
    if (value != null) {
      element.attributes[attribute] = _maskUrlOrText(attribute, value);
    }
  }
  final style = element.attributes['style'];
  if (style != null) {
    element.attributes['style'] = _maskCssUrls(style);
  }
  if (tag == 'style') {
    for (final child in element.nodes.whereType<dom.Text>()) {
      child.data = _maskCssUrls(child.data);
    }
    return;
  }
  for (final child in element.nodes) {
    _maskNode(child);
  }
}

void _maskComment(dom.Comment comment) {
  final data = comment.data ?? '';
  if (RegExp(r'^\s*\[if', caseSensitive: false).hasMatch(data)) {
    comment.data = _maskConditionalComment(data);
    return;
  }
  comment.data = _maskText(data);
}

String _maskConditionalComment(String data) {
  final start = RegExp(
    r'^\s*\[if[^\]]*\]>?',
    caseSensitive: false,
  ).firstMatch(data);
  if (start == null) {
    return _maskText(data);
  }
  final end = RegExp(r'<!\[endif\]\s*$', caseSensitive: false).firstMatch(data);
  final bodyEnd = end?.start ?? data.length;
  final body = data.substring(start.end, bodyEnd);
  return [
    data.substring(0, start.end),
    maskEmailHtml(body),
    if (end != null) data.substring(end.start),
  ].join();
}

String _maskUrlOrText(String attribute, String value) {
  if (attribute == 'href' || attribute == 'src') {
    return _maskUrl(value);
  }
  if (attribute == 'srcdoc') {
    return 'masked-srcdoc-length-${value.length}';
  }
  return _maskText(value);
}

String _maskUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.startsWith('cid:')) {
    return 'cid:masked';
  }
  if (trimmed.startsWith('data:')) {
    final separator = trimmed.indexOf(',');
    final header = separator > 0 ? trimmed.substring(0, separator) : 'data:';
    return '$header,masked-length-${trimmed.length}';
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return _maskText(trimmed);
  }
  return '${uri.scheme}://${uri.host}/masked';
}

String _maskCssUrls(String css) => css.replaceAllMapped(
  RegExp(r'url\(\s*[\x27"]?([^)\x27"]*)[\x27"]?\s*\)'),
  (match) => 'url(${_maskUrl(match.group(1) ?? '')})',
);

String _maskText(String text) => text
    .replaceAll(RegExp(r'\p{L}', unicode: true), 'x')
    .replaceAll(RegExp(r'\p{N}', unicode: true), '0');

void _printChunked(String text) {
  const chunkSize = 800;
  for (var start = 0; start < text.length; start += chunkSize) {
    final end = start + chunkSize > text.length
        ? text.length
        : start + chunkSize;
    debugPrint(text.substring(start, end));
  }
}
