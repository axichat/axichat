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

  test('pending outgoing Delta query only returns dc-pending rows', () async {
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
          deltaChatId: chatId,
          deltaMsgId: deltaMsgId,
        ),
        selfJid: 'me@example.com',
      );
    }

    await saveCandidate(
      stanzaId: 'dc-pending-valid',
      deltaAccountId: accountId,
      deltaMsgId: null,
    );
    await saveCandidate(
      stanzaId: 'pending-lookalike',
      deltaAccountId: accountId,
      deltaMsgId: null,
    );
    await saveCandidate(
      stanzaId: 'dc-pending-other-account',
      deltaAccountId: accountId + 1,
      deltaMsgId: null,
    );
    await saveCandidate(
      stanzaId: 'dc-pending-already-bound',
      deltaAccountId: accountId,
      deltaMsgId: 42,
    );

    final pending = await database.getPendingOutgoingDeltaMessages(
      deltaAccountId: accountId,
      deltaChatId: chatId,
    );

    expect(pending.map((message) => message.stanzaID), ['dc-pending-valid']);
  });
}
