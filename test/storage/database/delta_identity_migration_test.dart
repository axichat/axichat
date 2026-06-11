// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/util/email_message_ids.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late XmppDrift database;

  setUp(() {
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('message identity migration (v60)', () {
    test(
      'backfills delta chat scope from unambiguous account mapping',
      () async {
        const jid = 'alice@example.com';
        await database.createChat(
          Chat(
            jid: jid,
            title: 'Alice',
            type: ChatType.chat,
            lastChangeTimestamp: DateTime.utc(2026, 1, 1),
            transport: MessageTransport.email,
          ),
        );
        await database.upsertEmailChatAccount(
          chatJid: jid,
          deltaAccountId: 1,
          deltaChatId: 7,
        );
        await database.saveMessage(
          Message(
            stanzaID: 'dc-msg-42',
            senderJid: jid,
            chatJid: jid,
            timestamp: DateTime.utc(2026, 1, 2),
            body: 'legacy unscoped',
            originID: '<Legacy@Example.org>',
            deltaAccountId: 1,
            deltaMsgId: 42,
          ),
        );

        await database.migrateMessageIdentityToLadder();

        final migrated = await database.getMessageByStanzaID('dc-msg-42');
        expect(migrated?.deltaChatId, 7);
        expect(migrated?.originID, 'Legacy@example.org');
      },
    );

    test('backfills delta chat scope from the chat row as fallback', () async {
      const jid = 'bob@example.com';
      await database.createChat(
        Chat(
          jid: jid,
          title: 'Bob',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
          deltaChatId: 9,
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'dc-msg-43',
          senderJid: jid,
          chatJid: jid,
          timestamp: DateTime.utc(2026, 1, 2),
          originID: 'clean@example.org',
          deltaAccountId: 0,
          deltaMsgId: 43,
        ),
      );

      await database.migrateMessageIdentityToLadder();

      final migrated = await database.getMessageByStanzaID('dc-msg-43');
      expect(migrated?.deltaChatId, 9);
      expect(migrated?.originID, 'clean@example.org');
    });

    test('leaves ambiguous rows unscoped', () async {
      const jid = 'multi@example.com';
      await database.createChat(
        Chat(
          jid: jid,
          title: 'Multi',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
        ),
      );
      await database.upsertEmailChatAccount(
        chatJid: jid,
        deltaAccountId: 1,
        deltaChatId: 7,
      );
      await database.upsertEmailChatAccount(
        chatJid: jid,
        deltaAccountId: 1,
        deltaChatId: 8,
      );
      await database.saveMessage(
        Message(
          stanzaID: 'dc-msg-44',
          senderJid: jid,
          chatJid: jid,
          timestamp: DateTime.utc(2026, 1, 2),
          originID: 'kept@example.org',
          deltaAccountId: 1,
          deltaMsgId: 44,
        ),
      );

      await database.migrateMessageIdentityToLadder();

      final migrated = await database.getMessageByStanzaID('dc-msg-44');
      expect(migrated?.deltaChatId, isNull);
    });

    test('rewrites GEN_ and missing origins to derived keys', () async {
      const jid = 'carol@example.com';
      final timestamp = DateTime.utc(2026, 1, 3, 9);
      await database.createChat(
        Chat(
          jid: jid,
          title: 'Carol',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
          deltaChatId: 11,
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'dc-local-msg-0-11-50',
          senderJid: jid,
          chatJid: jid,
          timestamp: timestamp,
          subject: 'Hi',
          body: 'gen body',
          originID: 'GEN_abcd1234efgh',
          deltaAccountId: 0,
          deltaChatId: 11,
          deltaMsgId: 50,
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'dc-local-msg-0-11-51',
          senderJid: jid,
          chatJid: jid,
          timestamp: timestamp,
          subject: 'Hi',
          body: 'missing body',
          deltaAccountId: 0,
          deltaChatId: 11,
          deltaMsgId: 51,
        ),
      );

      await database.migrateMessageIdentityToLadder();

      final fromGen = await database.getMessageByStanzaID(
        'dc-local-msg-0-11-50',
      );
      final fromMissing = await database.getMessageByStanzaID(
        'dc-local-msg-0-11-51',
      );
      expect(isDerivedEmailMessageKey(fromGen?.originID), isTrue);
      expect(isDerivedEmailMessageKey(fromMissing?.originID), isTrue);
      expect(
        fromGen?.originID,
        derivedEmailMessageKey(
          subject: 'Hi',
          timestamp: timestamp,
          bodyText: 'gen body',
        ),
      );
    });

    test('does not touch XMPP rows', () async {
      const jid = 'dave@axi.im';
      await database.createChat(
        Chat(
          jid: jid,
          title: 'Dave',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.xmpp,
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'xmpp-1',
          senderJid: jid,
          chatJid: jid,
          timestamp: DateTime.utc(2026, 1, 2),
          originID: 'XMPP-Origin-Unchanged',
        ),
      );

      await database.migrateMessageIdentityToLadder();

      final untouched = await database.getMessageByStanzaID('xmpp-1');
      expect(untouched?.originID, 'XMPP-Origin-Unchanged');
      expect(untouched?.deltaChatId, isNull);
    });
  });

  group('delta locator uniqueness (v61)', () {
    test('second row with an identical delta locator is refused', () async {
      final first = Message(
        stanzaID: 'row-a',
        senderJid: 'alice@example.com',
        chatJid: 'alice@example.com',
        body: 'first',
        timestamp: DateTime.utc(2026, 1, 1),
        deltaAccountId: 1,
        deltaChatId: 7,
        deltaMsgId: 42,
      );
      final duplicate = Message(
        stanzaID: 'row-b',
        senderJid: 'alice@example.com',
        chatJid: 'alice@example.com',
        body: 'duplicate',
        timestamp: DateTime.utc(2026, 1, 2),
        deltaAccountId: 1,
        deltaChatId: 7,
        deltaMsgId: 42,
      );

      await database.saveMessage(first);
      await database.saveMessage(duplicate);

      final stored = await database.getMessagesByDeltaIds(
        const [42],
        deltaAccountId: 1,
        deltaChatId: 7,
      );
      expect(stored, hasLength(1));
      expect(stored.single.stanzaID, 'row-a');
      expect(await database.getMessageByStanzaID('row-b'), isNull);
    });

    test('rows without full delta locators stay unconstrained', () async {
      await database.saveMessage(
        Message(
          stanzaID: 'xmpp-a',
          senderJid: 'bob@example.com',
          chatJid: 'bob@example.com',
          body: 'one',
          timestamp: DateTime.utc(2026, 1, 1),
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'xmpp-b',
          senderJid: 'bob@example.com',
          chatJid: 'bob@example.com',
          body: 'two',
          timestamp: DateTime.utc(2026, 1, 2),
        ),
      );

      expect(await database.getMessageByStanzaID('xmpp-a'), isNotNull);
      expect(await database.getMessageByStanzaID('xmpp-b'), isNotNull);
    });
  });
}
