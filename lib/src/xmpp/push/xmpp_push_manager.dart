// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String xmppPushManager = 'xmpp.push';
const String xmppPushXmlns = 'urn:xmpp:push:0';
const String xmppPushPublishOptionsFormType =
    'http://jabber.org/protocol/pubsub#publish-options';
const String _xmppPushModuleField = 'pushModule';

class XmppPushManager extends mox.XmppManagerBase {
  XmppPushManager() : super(xmppPushManager);

  bool? _supported;

  @override
  Future<bool> isSupported() async {
    final cached = _supported;
    if (cached != null) return cached;
    final disco = getAttributes().getManagerById<mox.DiscoManager>(
      mox.discoManager,
    );
    if (disco == null) {
      _supported = false;
      return false;
    }
    final supported = await disco.supportsFeature(
      getAttributes().getConnectionSettings().jid.toBare(),
      xmppPushXmlns,
    );
    _supported = supported;
    return supported;
  }

  @override
  Future<void> onXmppEvent(mox.XmppEvent event) async {
    if (event is mox.StreamNegotiationsDoneEvent && await isNewStream()) {
      _supported = null;
    }
  }

  Future<bool> enable({
    required String accountJid,
    required String componentJid,
    required String node,
    required String pushModule,
  }) async {
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        buildEnableStanza(
          accountJid: accountJid,
          componentJid: componentJid,
          node: node,
          pushModule: pushModule,
        ),
        shouldEncrypt: false,
      ),
    );
    return result?.attributes['type'] == 'result';
  }

  Future<bool> disable({
    required String accountJid,
    required String componentJid,
    required String node,
  }) async {
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        buildDisableStanza(
          accountJid: accountJid,
          componentJid: componentJid,
          node: node,
        ),
        shouldEncrypt: false,
      ),
    );
    return result?.attributes['type'] == 'result';
  }

  static mox.Stanza buildEnableStanza({
    required String accountJid,
    required String componentJid,
    required String node,
    required String pushModule,
  }) {
    return mox.Stanza.iq(
      to: accountJid,
      type: 'set',
      children: [
        mox.XMLNode.xmlns(
          tag: 'enable',
          xmlns: xmppPushXmlns,
          attributes: <String, String>{'jid': componentJid, 'node': node},
          children: [_enableOptionsForm(pushModule)],
        ),
      ],
    );
  }

  static mox.Stanza buildDisableStanza({
    required String accountJid,
    required String componentJid,
    required String node,
  }) {
    return mox.Stanza.iq(
      to: accountJid,
      type: 'set',
      children: [
        mox.XMLNode.xmlns(
          tag: 'disable',
          xmlns: xmppPushXmlns,
          attributes: <String, String>{'jid': componentJid, 'node': node},
        ),
      ],
    );
  }

  static mox.XMLNode _enableOptionsForm(String pushModule) {
    return mox.DataForm(
      type: 'submit',
      instructions: const <String>[],
      fields: [
        const mox.DataFormField(
          varAttr: 'FORM_TYPE',
          type: 'hidden',
          values: [xmppPushPublishOptionsFormType],
          options: <mox.DataFormOption>[],
          isRequired: false,
        ),
        mox.DataFormField(
          varAttr: _xmppPushModuleField,
          values: [pushModule],
          options: const <mox.DataFormOption>[],
          isRequired: false,
        ),
      ],
      reported: const <mox.DataFormField>[],
      items: const <List<mox.DataFormField>>[],
    ).toXml();
  }
}
