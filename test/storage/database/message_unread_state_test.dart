import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late XmppDrift db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('message_unread_test');
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
    'open mixed XMPP chats suppress unread increments for email rows',
    () async {
      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1),
        transport: MessageTransport.xmpp,
        open: true,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'mixed-email-open',
          senderJid: 'peer@example.com',
          chatJid: chat.jid,
          body: 'Email inside open XMPP chat',
          timestamp: DateTime.utc(2026, 1, 1, 10),
          deltaChatId: 7,
          deltaMsgId: 70,
        ),
        selfJid: 'self@axi.im',
      );

      expect((await db.getChat(chat.jid))?.unreadCount, 0);

      await db.updateChat(chat.copyWith(open: false));
      await db.saveMessage(
        Message(
          stanzaID: 'mixed-email-closed',
          senderJid: 'peer@example.com',
          chatJid: chat.jid,
          body: 'Email inside closed XMPP chat',
          timestamp: DateTime.utc(2026, 1, 1, 11),
          deltaChatId: 7,
          deltaMsgId: 71,
        ),
        selfJid: 'self@axi.im',
      );

      expect((await db.getChat(chat.jid))?.unreadCount, 1);
    },
  );

  test('open native email chats keep Delta unread increments', () async {
    final chat = Chat(
      jid: 'peer@example.com',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026, 1),
      transport: MessageTransport.email,
      open: true,
      deltaChatId: 8,
      emailAddress: 'peer@example.com',
    );
    await db.createChat(chat);

    await db.saveMessage(
      Message(
        stanzaID: 'native-email-open',
        senderJid: 'peer@example.com',
        chatJid: chat.jid,
        body: 'Native email unread',
        timestamp: DateTime.utc(2026, 1, 1, 10),
        deltaChatId: chat.deltaChatId,
        deltaMsgId: 80,
      ),
      selfJid: 'self@example.com',
    );

    expect((await db.getChat(chat.jid))?.unreadCount, 1);
  });

  test(
    'unread count uses email self identity for email-backed messages',
    () async {
      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1),
        transport: MessageTransport.xmpp,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'xmpp-self',
          senderJid: 'self@axi.im',
          chatJid: chat.jid,
          body: 'XMPP self',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
        selfJid: 'other@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'email-self',
          senderJid: 'self@example.com',
          chatJid: chat.jid,
          body: 'Email self',
          timestamp: DateTime.utc(2026, 1, 1, 11),
          deltaChatId: 9,
          deltaMsgId: 90,
        ),
        selfJid: 'other@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'peer-unread',
          senderJid: 'peer@axi.im',
          chatJid: chat.jid,
          body: 'Peer unread',
          timestamp: DateTime.utc(2026, 1, 1, 12),
        ),
        selfJid: 'other@axi.im',
      );

      final unreadCount = await db.countUnreadMessagesForChat(
        chat.jid,
        selfJid: 'self@axi.im',
        emailSelfJid: 'self@example.com',
      );

      expect(unreadCount, 1);
    },
  );

  test(
    'repair unread count uses both XMPP and email self identities',
    () async {
      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1),
        transport: MessageTransport.xmpp,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'xmpp-self-repair',
          senderJid: 'self@axi.im',
          chatJid: chat.jid,
          body: 'XMPP self',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
        selfJid: 'self@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'email-self-repair',
          senderJid: 'self@example.com',
          chatJid: chat.jid,
          body: 'Email self',
          timestamp: DateTime.utc(2026, 1, 1, 11),
          deltaChatId: 9,
          deltaMsgId: 90,
        ),
        selfJid: 'self@example.com',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'xmpp-peer-repair',
          senderJid: 'peer@axi.im',
          chatJid: chat.jid,
          body: 'XMPP peer',
          timestamp: DateTime.utc(2026, 1, 1, 12),
        ),
        selfJid: 'self@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'email-peer-repair',
          senderJid: 'peer@example.com',
          chatJid: chat.jid,
          body: 'Email peer',
          timestamp: DateTime.utc(2026, 1, 1, 13),
          deltaChatId: 9,
          deltaMsgId: 91,
        ),
        selfJid: 'self@example.com',
      );

      final unreadCount = await db.repairUnreadCountForChat(
        chat.jid,
        selfJid: 'self@axi.im',
        emailSelfJid: 'self@example.com',
      );

      expect(unreadCount, 2);
      expect((await db.getChat(chat.jid))?.unreadCount, 2);
    },
  );

  test(
    'deleting an own unread-shaped row preserves peer unread count',
    () async {
      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1),
        transport: MessageTransport.xmpp,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'delete-self',
          senderJid: 'self@axi.im',
          chatJid: chat.jid,
          body: 'Own pending-looking row',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
        selfJid: 'self@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'delete-peer',
          senderJid: 'peer@axi.im',
          chatJid: chat.jid,
          body: 'Peer unread',
          timestamp: DateTime.utc(2026, 1, 1, 11),
        ),
        selfJid: 'self@axi.im',
      );

      expect((await db.getChat(chat.jid))?.unreadCount, 1);

      await db.deleteMessage('delete-self', selfJid: 'self@axi.im');

      expect((await db.getChat(chat.jid))?.unreadCount, 1);
    },
  );

  test('trimming unread rows repairs count to remaining messages', () async {
    final chat = Chat(
      jid: 'peer@axi.im',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026, 1),
      transport: MessageTransport.xmpp,
    );
    await db.createChat(chat);

    await db.saveMessage(
      Message(
        stanzaID: 'trim-old',
        senderJid: 'peer@axi.im',
        chatJid: chat.jid,
        body: 'Old unread',
        timestamp: DateTime.utc(2026, 1, 1, 10),
      ),
      selfJid: 'self@axi.im',
    );
    await db.saveMessage(
      Message(
        stanzaID: 'trim-new',
        senderJid: 'peer@axi.im',
        chatJid: chat.jid,
        body: 'New unread',
        timestamp: DateTime.utc(2026, 1, 1, 11),
      ),
      selfJid: 'self@axi.im',
    );

    expect((await db.getChat(chat.jid))?.unreadCount, 2);

    await db.trimChatMessages(
      jid: chat.jid,
      maxMessages: 1,
      selfJid: 'self@axi.im',
    );

    expect((await db.getChat(chat.jid))?.unreadCount, 1);
  });

  test(
    'replacing Delta placeholder self JIDs repairs mixed unread count',
    () async {
      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1),
        transport: MessageTransport.xmpp,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'replace-xmpp-self',
          senderJid: 'self@axi.im',
          chatJid: chat.jid,
          body: 'Own XMPP row',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
        selfJid: 'self@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'replace-email-placeholder',
          senderJid: deltaAnonUserJid,
          chatJid: chat.jid,
          body: 'Own email row before account hydration',
          timestamp: DateTime.utc(2026, 1, 1, 11),
          deltaChatId: 12,
          deltaMsgId: 120,
        ),
        selfJid: 'self@example.com',
      );

      expect((await db.getChat(chat.jid))?.unreadCount, 1);

      await db.replaceDeltaPlaceholderSelfJids(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        resolvedAddress: 'self@example.com',
        placeholderJids: deltaPlaceholderJids,
        selfJid: 'self@axi.im',
        emailSelfJid: 'self@example.com',
      );

      final replaced = await db.getMessageByStanzaID(
        'replace-email-placeholder',
      );
      expect(replaced?.senderJid, 'self@example.com');
      expect((await db.getChat(chat.jid))?.unreadCount, 0);
    },
  );

  test(
    'removing Delta placeholder duplicates repairs mixed unread count',
    () async {
      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1),
        transport: MessageTransport.xmpp,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'duplicate-xmpp-self',
          senderJid: 'self@axi.im',
          chatJid: chat.jid,
          body: 'Own XMPP row',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
        selfJid: 'self@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'duplicate-email-placeholder',
          senderJid: deltaAnonUserJid,
          chatJid: chat.jid,
          body: 'Duplicate before account hydration',
          timestamp: DateTime.utc(2026, 1, 1, 11),
          deltaChatId: 13,
          deltaMsgId: 130,
        ),
        selfJid: 'self@example.com',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'duplicate-email-real',
          senderJid: 'self@example.com',
          chatJid: chat.jid,
          body: 'Duplicate after account hydration',
          timestamp: DateTime.utc(2026, 1, 1, 11),
          deltaChatId: 13,
          deltaMsgId: 130,
        ),
        selfJid: 'self@example.com',
      );

      expect((await db.getChat(chat.jid))?.unreadCount, 1);

      await db.removeDeltaPlaceholderDuplicates(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        placeholderJids: deltaPlaceholderJids,
        selfJid: 'self@axi.im',
        emailSelfJid: 'self@example.com',
      );

      expect(
        await db.getMessageByStanzaID('duplicate-email-placeholder'),
        isNull,
      );
      expect(await db.getMessageByStanzaID('duplicate-email-real'), isNotNull);
      expect((await db.getChat(chat.jid))?.unreadCount, 0);
    },
  );

  test(
    'Delta account trimming preserves native XMPP rows in mixed chats',
    () async {
      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1),
        transport: MessageTransport.xmpp,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'native-xmpp-old',
          senderJid: 'peer@axi.im',
          chatJid: chat.jid,
          body: 'Native XMPP old',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
        selfJid: 'self@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'native-xmpp-new',
          senderJid: 'peer@axi.im',
          chatJid: chat.jid,
          body: 'Native XMPP new',
          timestamp: DateTime.utc(2026, 1, 1, 11),
        ),
        selfJid: 'self@axi.im',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'mixed-email-old',
          senderJid: 'peer@example.com',
          chatJid: chat.jid,
          body: 'Mixed email old',
          timestamp: DateTime.utc(2026, 1, 1, 12),
          deltaChatId: 11,
          deltaMsgId: 110,
        ),
        selfJid: 'self@example.com',
      );
      await db.saveMessage(
        Message(
          stanzaID: 'mixed-email-pending',
          senderJid: 'self@example.com',
          chatJid: chat.jid,
          body: 'Mixed email pending',
          timestamp: DateTime.utc(2026, 1, 1, 13),
          deltaChatId: 11,
        ),
        selfJid: 'self@example.com',
      );

      await db.trimChatMessages(
        jid: chat.jid,
        maxMessages: 0,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        selfJid: 'self@axi.im',
        emailSelfJid: 'self@example.com',
      );

      expect(await db.getMessageByStanzaID('native-xmpp-old'), isNotNull);
      expect(await db.getMessageByStanzaID('native-xmpp-new'), isNotNull);
      expect(await db.getMessageByStanzaID('mixed-email-old'), isNull);
      expect(await db.getMessageByStanzaID('mixed-email-pending'), isNull);
      expect((await db.getChat(chat.jid))?.lastMessage, 'Native XMPP new');
      expect((await db.getChat(chat.jid))?.unreadCount, 2);
    },
  );
}
