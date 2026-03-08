import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late XmppDrift db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('email_spam_status_test');
    final file = File('${tempDir.path}/db.sqlite');
    db = XmppDrift(
      file: file,
      passphrase: 'passphrase',
      executor: NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'markEmailChatsSpam updates email-backed aliases without touching xmpp chats',
    () async {
      const address = 'alice@example.com';
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);

      await db.createChat(
        Chat(
          jid: 'dc-1@delta.chat',
          title: 'Alice placeholder',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime(2024, 1, 1),
          transport: MessageTransport.email,
          deltaChatId: 1,
          contactID: address,
          contactJid: address,
          emailAddress: address,
        ),
      );
      await db.createChat(
        Chat(
          jid: address,
          title: 'Alice canonical',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime(2024, 1, 1),
          transport: MessageTransport.email,
          contactID: address,
          contactJid: address,
          emailAddress: address,
        ),
      );
      await db.createChat(
        Chat(
          jid: 'alice@axi.im',
          title: 'Alice XMPP',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime(2024, 1, 1),
          transport: MessageTransport.xmpp,
          contactJid: address,
        ),
      );

      await db.markEmailChatsSpam(
        address: address,
        spam: true,
        spamUpdatedAt: timestamp,
      );

      expect((await db.getChat('dc-1@delta.chat'))!.spam, isTrue);
      expect((await db.getChat(address))!.spam, isTrue);
      expect((await db.getChat('alice@axi.im'))!.spam, isFalse);
      expect((await db.getChat('dc-1@delta.chat'))!.spamUpdatedAt, timestamp);
      expect((await db.getChat(address))!.spamUpdatedAt, timestamp);

      await db.markEmailChatsSpam(address: address, spam: false);

      expect((await db.getChat('dc-1@delta.chat'))!.spam, isFalse);
      expect((await db.getChat(address))!.spam, isFalse);
      expect((await db.getChat('alice@axi.im'))!.spam, isFalse);
      expect((await db.getChat('dc-1@delta.chat'))!.spamUpdatedAt, isNull);
      expect((await db.getChat(address))!.spamUpdatedAt, isNull);
    },
  );
}
