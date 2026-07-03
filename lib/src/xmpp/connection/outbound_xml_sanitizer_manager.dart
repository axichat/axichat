// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

final class OutboundXmlSanitizerManager extends mox.XmppManagerBase {
  OutboundXmlSanitizerManager() : super(_managerId);

  static const String _managerId = 'axi.outbound_xml_sanitizer';
  static const int _outgoingHandlerPriority = -1000000;

  @override
  List<mox.StanzaHandler> getOutgoingPreStanzaHandlers() => [
    mox.StanzaHandler(
      priority: _outgoingHandlerPriority,
      callback: _onOutgoingStanza,
    ),
  ];

  @override
  Future<bool> isSupported() async => true;

  Future<mox.StanzaHandlerData> _onOutgoingStanza(
    mox.Stanza stanza,
    mox.StanzaHandlerData state,
  ) async {
    state.stanza = _sanitizeStanzaForMoxWire(state.stanza);
    return state;
  }
}

mox.Stanza _sanitizeStanzaForMoxWire(mox.Stanza stanza) {
  final sanitized = mox.Stanza(
    tag: stanza.tag,
    to: stanza.to,
    from: stanza.from,
    type: stanza.type,
    id: stanza.id,
    children: stanza.children
        .map(_sanitizeXmlNodeForMoxWire)
        .toList(growable: false),
  );
  sanitized.attributes = _escapeXmlAttributesForMoxWire(stanza.attributes);
  return sanitized;
}

mox.XMLNode _sanitizeXmlNodeForMoxWire(mox.XMLNode node) {
  return mox.XMLNode(
    tag: node.tag,
    attributes: _escapeXmlAttributesForMoxWire(node.attributes),
    children: node.children
        .map(_sanitizeXmlNodeForMoxWire)
        .toList(growable: false),
    closeTag: node.closeTag,
    text: node.text == null
        ? null
        : _shouldPreserveRawXmlText(node)
        ? _replaceInvalidXmlCharacters(node.text!)
        : _escapeXmlTextForMoxWire(node.text!),
    isDeclaration: node.isDeclaration,
  );
}

Map<String, dynamic> _escapeXmlAttributesForMoxWire(
  Map<String, dynamic> attributes,
) {
  return {
    for (final entry in attributes.entries)
      if (entry.value != null)
        entry.key: _escapeXmlAttributeValueForMoxWire(entry.value!),
  };
}

Object _escapeXmlAttributeValueForMoxWire(Object value) {
  return switch (value) {
    final String text => _escapeXmlAttributeForMoxWire(text),
    final int integer => integer,
    _ => _escapeXmlAttributeForMoxWire(value.toString()),
  };
}

bool _shouldPreserveRawXmlText(mox.XMLNode node) {
  return node.tag == _xhtmlImBodyTag && node.xmlns == _xhtmlXmlns;
}

@visibleForTesting
mox.XMLNode sanitizeOutboundXmlNodeForTest(mox.XMLNode node) =>
    _sanitizeXmlNodeForMoxWire(node);

@visibleForTesting
mox.Stanza sanitizeOutboundStanzaForTest(mox.Stanza stanza) =>
    _sanitizeStanzaForMoxWire(stanza);

String _escapeXmlTextForMoxWire(String value) {
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

String _escapeXmlAttributeForMoxWire(String value) {
  return _escapeXmlTextForMoxWire(
    value,
  ).replaceAll("'", '&apos;').replaceAll('"', '&quot;');
}

String _replaceInvalidXmlCharacters(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    buffer.writeCharCode(_isXmlCharacter(rune) ? rune : 0xfffd);
  }
  return buffer.toString();
}

bool _isXmlCharacter(int rune) {
  return rune == 0x09 ||
      rune == 0x0a ||
      rune == 0x0d ||
      (rune >= 0x20 && rune <= 0xd7ff) ||
      (rune >= 0xe000 && rune <= 0xfffd) ||
      (rune >= 0x10000 && rune <= 0x10ffff);
}
