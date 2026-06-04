import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late XmppDrift db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server_announcement_test');
    db = XmppDrift(
      file: File('${tempDir.path}/db.sqlite'),
      passphrase: 'passphrase',
      executor: NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('axi.im server announcement chats are favorited by default', () async {
    await db.saveMessage(
      Message(
        stanzaID: 'server-announcement',
        senderJid: 'axi.im',
        chatJid: 'axi.im',
        body: 'Maintenance window',
        timestamp: DateTime.utc(2026),
      ),
      selfJid: 'alice@axi.im',
    );

    final chat = await db.getChat('axi.im');

    expect(chat?.favorited, isTrue);
    expect(chat?.contactJid, 'axi.im');
  });

  test('existing axi.im server announcement chats become favorited', () async {
    await db.createChat(
      Chat(
        jid: 'axi.im',
        title: 'axi.im',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2025),
      ),
    );

    await db.saveMessage(
      Message(
        stanzaID: 'server-announcement-update',
        senderJid: 'axi.im',
        chatJid: 'axi.im',
        body: 'Maintenance window',
        timestamp: DateTime.utc(2026),
      ),
      selfJid: 'alice@axi.im',
    );

    expect((await db.getChat('axi.im'))?.favorited, isTrue);
  });
}
