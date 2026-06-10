// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/xmpp/pubsub/message_collections_pubsub_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

void main() {
  MessageCollectionSyncPayload payload({String? stanzaId}) {
    return MessageCollectionSyncPayload(
      collectionId: 'favorites',
      chatJid: 'alice@example.com',
      messageReferenceId: 'ref-1',
      messageStanzaId: stanzaId,
      messageOriginId: 'origin@example.com',
      updatedAt: DateTime.utc(2026, 6, 10, 12),
      active: true,
      sourceId: 'source-1',
    );
  }

  group('collection payload publishing', () {
    test('never emits delta handle attributes', () {
      final node = payload(stanzaId: 'real-xmpp-id').toXml();
      expect(node.attributes.containsKey('delta_account_id'), isFalse);
      expect(node.attributes.containsKey('delta_msg_id'), isFalse);
    });

    test('keeps real XMPP stanza ids', () {
      final node = payload(stanzaId: 'real-xmpp-id').toXml();
      expect(node.attributes['message_stanza_id'], 'real-xmpp-id');
      expect(node.attributes['message_origin_id'], 'origin@example.com');
    });

    test('suppresses device-local delta row keys from the stanza alias', () {
      for (final local in [
        'dc-msg-42',
        'dc-local-msg-0-7-42',
        'dc-pending-abc',
      ]) {
        final node = payload(stanzaId: local).toXml();
        expect(node.attributes.containsKey('message_stanza_id'), isFalse);
      }
    });
  });

  group('collection payload receipt', () {
    mox.XMLNode legacyNode({
      String? stanzaId,
      String? deltaAccountId,
      String? deltaMsgId,
    }) {
      return mox.XMLNode.xmlns(
        tag: 'entry',
        xmlns: messageCollectionsPubSubNode,
        attributes: {
          'collection_id': 'favorites',
          'chat_jid': 'alice@example.com',
          'message_reference_id': 'ref-1',
          'updated_at': DateTime.utc(2026, 6, 10, 12).toIso8601String(),
          'active': '1',
          'source_id': 'source-1',
          'message_origin_id': 'origin@example.com',
          'message_stanza_id': ?stanzaId,
          'delta_account_id': ?deltaAccountId,
          'delta_msg_id': ?deltaMsgId,
        },
      );
    }

    test('strips delta handles from legacy payloads', () {
      final parsed = MessageCollectionSyncPayload.fromXml(
        legacyNode(deltaAccountId: '1', deltaMsgId: '42'),
      );
      expect(parsed, isNotNull);
      expect(parsed!.messageOriginId, 'origin@example.com');
      final republished = parsed.toXml();
      expect(republished.attributes.containsKey('delta_account_id'), isFalse);
      expect(republished.attributes.containsKey('delta_msg_id'), isFalse);
    });

    test('drops device-local delta row keys arriving as stanza aliases', () {
      final parsed = MessageCollectionSyncPayload.fromXml(
        legacyNode(stanzaId: 'dc-local-msg-1-7-42'),
      );
      expect(parsed, isNotNull);
      expect(parsed!.messageStanzaId, isNull);
    });

    test('keeps real XMPP stanza aliases', () {
      final parsed = MessageCollectionSyncPayload.fromXml(
        legacyNode(stanzaId: 'real-xmpp-id'),
      );
      expect(parsed, isNotNull);
      expect(parsed!.messageStanzaId, 'real-xmpp-id');
    });
  });
}
