// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _xhtmlImXmlns = 'http://jabber.org/protocol/xhtml-im';
const String _xhtmlXmlns = 'http://www.w3.org/1999/xhtml';
const String _xhtmlImTag = 'html';
const String _xhtmlImBodyTag = 'body';
const String _xmlLangAttr = 'xml:lang';
const String _langAttr = 'lang';
const String _xhtmlImManagerId = 'axi.xhtml_im';

final class XhtmlImData implements mox.StanzaHandlerExtension {
  const XhtmlImData({
    required this.xhtmlBody,
    required this.plainText,
    this.lang,
  });

  final String xhtmlBody;
  final String plainText;
  final String? lang;

  mox.XMLNode toXml() {
    final bodyAttributes = <String, String>{
      if (lang?.isNotEmpty == true) _xmlLangAttr: lang!,
    };
    return mox.XMLNode.xmlns(
      tag: _xhtmlImTag,
      xmlns: _xhtmlImXmlns,
      children: [
        mox.XMLNode.xmlns(
          tag: _xhtmlImBodyTag,
          xmlns: _xhtmlXmlns,
          attributes: bodyAttributes,
          text: xhtmlBody,
        ),
      ],
    );
  }
}

final class XhtmlImManager extends mox.XmppManagerBase {
  XhtmlImManager() : super(_xhtmlImManagerId);

  @override
  List<String> getDiscoFeatures() => const [_xhtmlImXmlns];

  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: 'message',
          tagName: _xhtmlImTag,
          tagXmlns: _xhtmlImXmlns,
          callback: _onMessage,
          priority: -99,
        ),
      ];

  @override
  Future<bool> isSupported() async => true;

  Future<mox.StanzaHandlerData> _onMessage(
    mox.Stanza message,
    mox.StanzaHandlerData state,
  ) async {
    final htmlNode = message.firstTag(_xhtmlImTag, xmlns: _xhtmlImXmlns);
    if (htmlNode == null) return state;
    final bodyNode = htmlNode.firstTag(_xhtmlImBodyTag, xmlns: _xhtmlXmlns) ??
        htmlNode.firstTag(_xhtmlImBodyTag);
    if (bodyNode == null) return state;
    final markup = _xhtmlBodyMarkup(bodyNode);
    final markupPlain = HtmlContentCodec.toPlainText(markup);
    final fallbackPlain = _plainBodyText(message);
    final resolvedPlain = markupPlain.isNotEmpty ? markupPlain : fallbackPlain;
    final resolvedMarkup = (markupPlain.isNotEmpty || fallbackPlain.isEmpty)
        ? markup
        : HtmlContentCodec.fromPlainText(fallbackPlain);
    if (resolvedPlain.isEmpty && resolvedMarkup.isEmpty) return state;
    final lang = bodyNode.attributes[_xmlLangAttr]?.toString() ??
        bodyNode.attributes[_langAttr]?.toString();
    return state
      ..extensions.set(
        XhtmlImData(
          xhtmlBody: resolvedMarkup,
          plainText: resolvedPlain,
          lang: lang?.isNotEmpty == true ? lang : null,
        ),
      );
  }

  List<mox.XMLNode> _messageSendingCallback(
    mox.TypedMap<mox.StanzaHandlerExtension> extensions,
  ) {
    final data = extensions.get<XhtmlImData>();
    if (data == null) return const [];
    final nodes = <mox.XMLNode>[data.toXml()];
    if (_shouldIncludePlainBody(extensions)) {
      nodes.insert(
        0,
        mox.XMLNode(
          tag: _xhtmlImBodyTag,
          text: data.plainText,
        ),
      );
    }
    return nodes;
  }

  bool _shouldIncludePlainBody(
    mox.TypedMap<mox.StanzaHandlerExtension> extensions,
  ) {
    return extensions.get<mox.MessageBodyData>() == null;
  }

  String _xhtmlBodyMarkup(mox.XMLNode body) {
    if (body.children.isEmpty) {
      final text = body.innerText();
      return text.trim().isEmpty ? '' : HtmlContentCodec.fromPlainText(text);
    }
    final buffer = StringBuffer();
    for (final child in body.children) {
      buffer.write(child.toXml());
    }
    return buffer.toString().trim();
  }

  String _plainBodyText(mox.Stanza message) {
    final bodyNode = message.firstTag(_xhtmlImBodyTag);
    if (bodyNode == null) return '';
    return bodyNode.innerText().trim();
  }

  @override
  Future<void> postRegisterCallback() async {
    await super.postRegisterCallback();
    getAttributes()
        .getManagerById<mox.MessageManager>(mox.messageManager)
        ?.registerMessageSendingCallback(_messageSendingCallback);
  }
}
