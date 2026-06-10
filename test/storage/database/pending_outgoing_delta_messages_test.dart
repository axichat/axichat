import 'dart:io';

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

  test('pending outgoing Delta query selects by column state', () async {
    const chatId = 7;
    const accountId = 3;
    const chatJid = 'alice@example.com';
    await database.createChat(
      Chat(
        jid: chatJid,
        title: 'Alice',
        type: ChatType.chat,
        deltaChatId: chatId,
        lastChangeTimestamp: DateTime.utc(2026, 1, 1),
      ),
    );

    Future<void> saveCandidate({
      required String stanzaId,
      required int deltaAccountId,
      required int? deltaChatId,
      required int? deltaMsgId,
    }) {
      return database.saveMessage(
        Message(
          stanzaID: stanzaId,
          senderJid: 'me@example.com',
          chatJid: chatJid,
          timestamp: DateTime.utc(2026, 1, 1),
          body: stanzaId,
          deltaAccountId: deltaAccountId,
          deltaChatId: deltaChatId,
          deltaMsgId: deltaMsgId,
        ),
        selfJid: 'me@example.com',
      );
    }

    await saveCandidate(
      stanzaId: 'opaque-pending-key',
      deltaAccountId: accountId,
      deltaChatId: chatId,
      deltaMsgId: null,
    );
    await saveCandidate(
      stanzaId: 'legacy-dc-pending-key',
      deltaAccountId: accountId,
      deltaChatId: chatId,
      deltaMsgId: null,
    );
    await saveCandidate(
      stanzaId: 'other-account-pending',
      deltaAccountId: accountId + 1,
      deltaChatId: chatId,
      deltaMsgId: null,
    );
    await saveCandidate(
      stanzaId: 'already-bound',
      deltaAccountId: accountId,
      deltaChatId: chatId,
      deltaMsgId: 42,
    );
    await saveCandidate(
      stanzaId: 'xmpp-row-no-delta-chat',
      deltaAccountId: accountId,
      deltaChatId: null,
      deltaMsgId: null,
    );

    final pending = await database.getPendingOutgoingDeltaMessages(
      deltaAccountId: accountId,
      deltaChatId: chatId,
    );

    expect(pending.map((message) => message.stanzaID).toSet(), {
      'opaque-pending-key',
      'legacy-dc-pending-key',
    });
  });
}
