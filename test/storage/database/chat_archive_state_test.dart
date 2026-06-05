import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late XmppDrift database;

  setUp(() {
    database = XmppDrift.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test('unarchive restores the canonical chat jid', () async {
    const jid = 'peer@axi.im';
    await database.createChat(
      Chat(
        jid: jid,
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 5, 28, 10),
        contactJid: jid,
      ),
    );
    await database.saveMessage(
      Message(
        stanzaID: 'archive-message-1',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2026, 5, 28, 10, 1),
        body: 'Archived body',
        encryptionProtocol: EncryptionProtocol.none,
      ),
    );
    final draftId = await database.saveDraft(
      jids: const [jid, 'other@axi.im'],
      body: 'Draft body',
      draftSyncId: 'archive-draft-1',
      draftUpdatedAt: DateTime.utc(2026, 5, 28, 10, 2),
      draftSourceId: 'source',
      draftRecipients: const [],
    );
    await database.upsertEmailChatAccount(
      chatJid: jid,
      deltaAccountId: 1,
      deltaChatId: 101,
    );

    await database.markChatArchived(jid: jid, archived: true);

    final archivedChat = (await database.getChats(
      start: 0,
      end: 0,
    )).where((chat) => chat.archived).single;
    expect(archivedChat.jid, startsWith('$jid--arch--'));
    expect(archivedChat.contactJid, jid);
    expect(await database.getChat(jid), isNull);
    expect(
      (await database.getChatMessages(
        archivedChat.jid,
        start: 0,
        end: 10,
      )).single.chatJid,
      archivedChat.jid,
    );
    expect((await database.getDraft(draftId))?.jids, [
      archivedChat.jid,
      'other@axi.im',
    ]);
    expect(
      await database.getDeltaChatIdForAccount(
        chatJid: archivedChat.jid,
        deltaAccountId: 1,
      ),
      101,
    );
    expect(
      await database.getDeltaChatIdForAccount(chatJid: jid, deltaAccountId: 1),
      isNull,
    );

    await database.markChatArchived(jid: archivedChat.jid, archived: false);

    final restored = await database.getChat(jid);
    expect(restored?.jid, jid);
    expect(restored?.contactJid, jid);
    expect(restored?.archived, isFalse);
    expect(await database.getChat(archivedChat.jid), isNull);
    expect(
      (await database.getChatMessages(jid, start: 0, end: 10)).single.chatJid,
      jid,
    );
    expect((await database.getDraft(draftId))?.jids, [jid, 'other@axi.im']);
    expect(
      await database.getDeltaChatIdForAccount(chatJid: jid, deltaAccountId: 1),
      101,
    );
    expect(
      await database.getDeltaChatIdForAccount(
        chatJid: archivedChat.jid,
        deltaAccountId: 1,
      ),
      isNull,
    );
  });

  test('unarchive merges back into a reused canonical chat jid', () async {
    const jid = 'reused@axi.im';
    await database.createChat(
      Chat(
        jid: jid,
        title: 'Archived thread',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 5, 28, 11),
        contactJid: jid,
      ),
    );
    await database.saveMessage(
      Message(
        stanzaID: 'archive-message-2',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2026, 5, 28, 11, 1),
        body: 'Old thread',
        encryptionProtocol: EncryptionProtocol.none,
      ),
    );
    await database.upsertEmailChatAccount(
      chatJid: jid,
      deltaAccountId: 1,
      deltaChatId: 201,
    );
    await database.markChatArchived(jid: jid, archived: true);
    final archivedJid = (await database.getChats(
      start: 0,
      end: 0,
    )).where((chat) => chat.archived).single.jid;

    await database.createChat(
      Chat(
        jid: jid,
        title: 'Live thread',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 5, 28, 12),
        contactJid: jid,
      ),
    );
    await database.saveMessage(
      Message(
        stanzaID: 'live-message-1',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2026, 5, 28, 12, 1),
        body: 'Live thread',
        encryptionProtocol: EncryptionProtocol.none,
      ),
    );
    await database.upsertEmailChatAccount(
      chatJid: jid,
      deltaAccountId: 1,
      deltaChatId: 202,
    );

    await database.markChatArchived(jid: archivedJid, archived: false);

    final restored = await database.getChat(jid);
    expect(restored?.archived, isFalse);
    expect(await database.getChat(archivedJid), isNull);
    expect(
      (await database.getChatMessages(
        jid,
        start: 0,
        end: 10,
      )).map((message) => message.stanzaID).toSet(),
      {'archive-message-2', 'live-message-1'},
    );
    expect(
      await database.getDeltaChatIdForAccount(chatJid: jid, deltaAccountId: 1),
      202,
    );
    expect(
      await database.getDeltaChatIdsForAccount(chatJid: jid, deltaAccountId: 1),
      [202, 201],
    );
  });

  test('startup repairs a restored chat left with an archive suffix', () async {
    await database.close();
    final tempDir = await Directory.systemTemp.createTemp(
      'chat_archive_state_test',
    );
    try {
      final file = File('${tempDir.path}/db.sqlite');
      database = XmppDrift(
        file: file,
        passphrase: 'passphrase',
        executor: NativeDatabase(file),
      );
      const jid = 'bricked@axi.im';
      await database.createChat(
        Chat(
          jid: jid,
          title: 'Bricked',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 5, 28, 13),
          contactJid: jid,
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'archive-message-3',
          senderJid: jid,
          chatJid: jid,
          timestamp: DateTime.utc(2026, 5, 28, 13, 1),
          body: 'Old restored row',
          encryptionProtocol: EncryptionProtocol.none,
        ),
      );
      await database.markChatArchived(jid: jid, archived: true);
      final archivedJid = (await database.getChats(
        start: 0,
        end: 0,
      )).where((chat) => chat.archived).single.jid;
      await database.customStatement(
        'UPDATE chats SET archived = 0 WHERE jid = ?',
        [archivedJid],
      );
      await database.close();

      database = XmppDrift(
        file: file,
        passphrase: 'passphrase',
        executor: NativeDatabase(file),
      );

      final repaired = await database.getChat(jid);
      expect(repaired?.jid, jid);
      expect(repaired?.archived, isFalse);
      expect(await database.getChat(archivedJid), isNull);
      expect(
        (await database.getChatMessages(jid, start: 0, end: 10)).single.chatJid,
        jid,
      );
    } finally {
      await database.close();
      await tempDir.delete(recursive: true);
      database = XmppDrift.inMemory();
    }
  });
}
