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

  test('Delta id lookup can be scoped by Delta chat id', () async {
    const deltaAccountId = 1;
    const deltaMsgId = 42;
    const firstChatId = 7;
    const secondChatId = 8;
    const firstJid = 'first@example.com';
    const secondJid = 'second@example.com';

    await database.saveMessage(
      Message(
        stanzaID: 'dc-msg-42',
        senderJid: firstJid,
        chatJid: firstJid,
        timestamp: DateTime.utc(2026, 1, 1),
        body: 'first',
        deltaAccountId: deltaAccountId,
        deltaChatId: firstChatId,
        deltaMsgId: deltaMsgId,
      ),
    );
    await database.saveMessage(
      Message(
        stanzaID: 'dc-local-msg-1-8-42',
        senderJid: secondJid,
        chatJid: secondJid,
        timestamp: DateTime.utc(2026, 1, 2),
        body: 'second',
        deltaAccountId: deltaAccountId,
        deltaChatId: secondChatId,
        deltaMsgId: deltaMsgId,
      ),
    );

    final first = await database.getMessageByDeltaId(
      deltaMsgId,
      deltaAccountId: deltaAccountId,
      deltaChatId: firstChatId,
    );
    final second = await database.getMessageByDeltaId(
      deltaMsgId,
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
    );
    final secondList = await database.getMessagesByDeltaIds(
      const [deltaMsgId],
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
    );

    expect(first?.chatJid, firstJid);
    expect(second?.chatJid, secondJid);
    expect(secondList, hasLength(1));
    expect(secondList.single.chatJid, secondJid);
  });
}
