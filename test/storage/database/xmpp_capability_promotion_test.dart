import 'dart:io';

import 'package:axichat/src/common/transport.dart';
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

  test(
    'markDirectChatXmppCapable promotes direct email chat and preserves metadata',
    () async {
      const jid = 'peer@axi.im';
      await database.createChat(
        Chat(
          jid: jid,
          title: 'Email Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
          lastMessage: 'email summary',
          unreadCount: 3,
          muted: true,
          favorited: true,
          deltaChatId: 42,
          emailAddress: 'peer@example.com',
          emailFromAddress: 'me@example.com',
          emailSendConfirmationEnabled: false,
          shareSignatureEnabled: true,
        ),
      );
      await database.updateChat(
        (await database.getChat(jid))!.copyWith(lastMessage: 'email summary'),
      );

      await database.markDirectChatXmppCapable(jid);

      final chat = await database.getChat(jid);
      expect(chat?.transport, MessageTransport.xmpp);
      expect(chat?.deltaChatId, 42);
      expect(chat?.emailAddress, 'peer@example.com');
      expect(chat?.emailFromAddress, 'me@example.com');
      expect(chat?.lastMessage, 'email summary');
      expect(chat?.unreadCount, 3);
      expect(chat?.muted, isTrue);
      expect(chat?.favorited, isTrue);
      expect(chat?.emailSendConfirmationEnabled, isFalse);
      expect(chat?.shareSignatureEnabled, isTrue);
    },
  );

  test(
    'markDirectChatXmppCapable does not promote missing or group chats',
    () async {
      const groupJid = 'room@conference.axi.im';
      await database.createChat(
        Chat(
          jid: groupJid,
          title: 'Room',
          type: ChatType.groupChat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
        ),
      );

      await database.markDirectChatXmppCapable('missing@axi.im');
      await database.markDirectChatXmppCapable(groupJid);

      expect(await database.getChat('missing@axi.im'), isNull);
      expect(
        (await database.getChat(groupJid))?.transport,
        MessageTransport.email,
      );
    },
  );

  test(
    'saveMessage does not promote non-Delta rows without XMPP proof owner',
    () async {
      const jid = 'mixed@axi.im';
      await database.createChat(
        Chat(
          jid: jid,
          title: 'Mixed',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
          deltaChatId: 9,
          emailAddress: 'mixed@example.com',
        ),
      );

      await database.saveMessage(
        Message(
          stanzaID: 'xmpp-1',
          senderJid: jid,
          chatJid: jid,
          timestamp: DateTime.utc(2026, 1, 2),
          body: 'xmpp hello',
        ),
        selfJid: 'me@axi.im',
      );

      final chat = await database.getChat(jid);
      expect(chat?.transport, MessageTransport.email);
      expect(chat?.deltaChatId, 9);
      expect(chat?.emailAddress, 'mixed@example.com');
    },
  );

  test(
    'saveMessage does not promote Delta rows or XMPP error placeholders',
    () async {
      const deltaJid = 'email-only@axi.im';
      const errorJid = 'error-only@axi.im';
      await database.createChat(
        Chat(
          jid: deltaJid,
          title: 'Email Only',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
          deltaChatId: 5,
          emailAddress: 'email-only@example.com',
        ),
      );
      await database.createChat(
        Chat(
          jid: errorJid,
          title: 'Error Only',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
        ),
      );

      await database.saveMessage(
        Message(
          stanzaID: 'dc-msg-77',
          senderJid: deltaJid,
          chatJid: deltaJid,
          timestamp: DateTime.utc(2026, 1, 2),
          body: 'email backfill',
          deltaChatId: 5,
          deltaMsgId: 77,
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'xmpp-error-1',
          senderJid: errorJid,
          chatJid: errorJid,
          timestamp: DateTime.utc(2026, 1, 2),
          body: 'Service unavailable',
          error: MessageError.serviceUnavailable,
        ),
        selfJid: 'me@axi.im',
      );

      expect(
        (await database.getChat(deltaJid))?.transport,
        MessageTransport.email,
      );
      expect(
        (await database.getChat(errorJid))?.transport,
        MessageTransport.email,
      );
    },
  );

  test(
    'conversation index promotes existing email-backed direct chat',
    () async {
      const jid = 'indexed@axi.im';
      await database.createChat(
        Chat(
          jid: jid,
          title: 'Indexed',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
          deltaChatId: 11,
          emailAddress: 'indexed@example.com',
        ),
      );

      await database.updateConversationIndexChatMeta(
        jid: jid,
        lastChangeTimestamp: DateTime.utc(2026, 1, 2),
        muted: true,
        favorited: true,
        archived: false,
        contactJid: jid,
      );

      final chat = await database.getChat(jid);
      expect(chat?.transport, MessageTransport.xmpp);
      expect(chat?.deltaChatId, 11);
      expect(chat?.emailAddress, 'indexed@example.com');
      expect(chat?.muted, isTrue);
      expect(chat?.favorited, isTrue);
    },
  );

  test(
    'roster sync promotes existing chats without creating new chats',
    () async {
      const existingJid = 'roster-existing@axi.im';
      const newJid = 'roster-new@axi.im';
      await database.createChat(
        Chat(
          jid: existingJid,
          title: 'Roster Existing',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 1, 1),
          transport: MessageTransport.email,
          deltaChatId: 12,
          emailAddress: 'roster-existing@example.com',
        ),
      );

      await database.saveRosterItemsOnly([
        RosterItem.fromJid(existingJid),
        RosterItem.fromJid(newJid),
      ]);

      expect(
        (await database.getChat(existingJid))?.transport,
        MessageTransport.xmpp,
      );
      expect((await database.getChat(existingJid))?.deltaChatId, 12);
      expect(await database.getChat(newJid), isNull);
      expect(await database.getRosterItem(existingJid), isNotNull);
      expect(await database.getRosterItem(newJid), isNotNull);
    },
  );
}
