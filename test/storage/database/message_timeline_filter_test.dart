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
    tempDir = await Directory.systemTemp.createTemp('timeline_filter_test');
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

  test('message timeline filters respect share participants', () async {
    final contact = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Bob',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      deltaChatId: 1,
      emailAddress: 'bob@example.com',
    );
    final otherContact = Chat(
      jid: 'dc-2@delta.chat',
      title: 'Carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );
    await db.createChat(contact);
    await db.createChat(otherContact);

    final directMessage = Message(
      stanzaID: 'direct-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 1),
      body: 'Direct hello',
      encryptionProtocol: EncryptionProtocol.none,
    );
    await db.saveMessage(directMessage);

    const shareId = '01HX5R8W7YAYR5K1R7Q7MB5G4W';
    final sharedMessage = Message(
      stanzaID: 'share-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 2),
      body: 'Shared hello',
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: contact.deltaChatId,
      deltaMsgId: 42,
    );
    await db.saveMessage(sharedMessage);

    final participants = [
      const MessageParticipantData(
        shareId: shareId,
        contactJid: 'dc-self@delta.chat',
        role: MessageParticipantRole.sender,
      ),
      MessageParticipantData(
        shareId: shareId,
        contactJid: contact.jid,
        role: MessageParticipantRole.recipient,
      ),
      MessageParticipantData(
        shareId: shareId,
        contactJid: otherContact.jid,
        role: MessageParticipantRole.recipient,
      ),
    ];

    await db.createMessageShare(
      share: MessageShareData(
        shareId: shareId,
        originatorDcMsgId: null,
        subjectToken: shareId,
        createdAt: DateTime.utc(2024, 1, 2),
        participantCount: participants.length,
      ),
      participants: participants,
    );

    await db.insertMessageCopy(
      shareId: shareId,
      dcMsgId: sharedMessage.deltaMsgId!,
      dcChatId: contact.deltaChatId!,
    );

    final directOnly = await db.getChatMessages(
      contact.jid,
      start: 0,
      end: 10,
      filter: MessageTimelineFilter.directOnly,
    );
    final allWithContact = await db.getChatMessages(
      contact.jid,
      start: 0,
      end: 10,
      filter: MessageTimelineFilter.allWithContact,
    );

    expect(directOnly.map((msg) => msg.stanzaID), isNot(contains('share-1')));
    expect(allWithContact.map((msg) => msg.stanzaID), contains('share-1'));
    expect(allWithContact.map((msg) => msg.stanzaID), contains('direct-1'));
  });

  test(
    'saveMessage does not increment unread for direct self messages',
    () async {
      const selfJid = 'me@example.com';
      const peerJid = 'peer@example.com';
      final chat = Chat(
        jid: peerJid,
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        emailAddress: peerJid,
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'outbound-1',
          senderJid: selfJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 10),
          body: 'Outbound hello',
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final afterOutbound = await db.getChat(peerJid);
      expect(afterOutbound?.unreadCount, 0);

      await db.saveMessage(
        Message(
          stanzaID: 'inbound-1',
          senderJid: peerJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 11),
          body: 'Inbound hello',
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final afterInbound = await db.getChat(peerJid);
      expect(afterInbound?.unreadCount, 1);
    },
  );

  test(
    'saveMessage increments unread for inbound invite pseudo messages',
    () async {
      const selfJid = 'me@example.com';
      const peerJid = 'peer@example.com';
      final chat = Chat(
        jid: peerJid,
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      );
      await db.createChat(chat);

      await db.saveMessage(
        Message(
          stanzaID: 'invite-1',
          senderJid: peerJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 12),
          body: 'You have been invited to a group chat',
          pseudoMessageType: PseudoMessageType.mucInvite,
          pseudoMessageData: const {
            'room': 'room@conference.example.com',
            'token': 'invite-token',
          },
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: selfJid,
      );

      final afterInvite = await db.getChat(peerJid);
      expect(afterInvite?.unreadCount, 1);
      expect(afterInvite?.lastMessage, 'You have been invited to a group chat');

      await db.openChat(peerJid);

      final afterOpen = await db.getChat(peerJid);
      expect(afterOpen?.unreadCount, 0);
    },
  );

  test(
    'createChat rebuilds invite lastMessage from persisted messages',
    () async {
      const peerJid = 'peer@example.com';

      await db.saveMessage(
        Message(
          stanzaID: 'invite-rebuild-1',
          senderJid: peerJid,
          chatJid: peerJid,
          timestamp: DateTime.utc(2024, 1, 1, 12),
          body: 'You have been invited to a group chat',
          pseudoMessageType: PseudoMessageType.mucInvite,
          pseudoMessageData: const {
            'room': 'room@conference.example.com',
            'token': 'invite-token',
          },
          encryptionProtocol: EncryptionProtocol.none,
        ),
      );

      await db.customStatement('DELETE FROM chats WHERE jid = ?', [peerJid]);

      await db.createChat(
        Chat(
          jid: peerJid,
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        ),
      );

      final recreated = await db.getChat(peerJid);
      expect(recreated?.lastMessage, 'You have been invited to a group chat');
    },
  );

  test('same-timestamp summary updates replace a forwarded preview', () async {
    final contact = Chat(
      jid: 'shared-summary@delta.chat',
      title: 'Shared Summary',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      deltaChatId: 7,
      emailAddress: 'shared-summary@example.com',
    );
    await db.createChat(contact);

    final sharedTimestamp = DateTime.utc(2024, 1, 5, 12);
    await db.saveMessage(
      Message(
        stanzaID: 'shared-forward-1',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'forwarded payload',
        subject: 'FWD: sender@example.com',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 77,
      ),
    );
    await db.saveMessage(
      Message(
        stanzaID: 'direct-summary-1',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'latest direct message',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 78,
      ),
    );
    await db.saveMessage(
      Message(
        stanzaID: 'direct-summary-2',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'latest direct message v2',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 79,
      ),
    );

    final updatedChat = await db.getChat(contact.jid);
    expect(updatedChat?.lastMessage, 'latest direct message v2');
  });

  test(
    'repairChatSummaryPreservingTimestamp fixes stale preview without rolling back timestamp',
    () async {
      final contact = Chat(
        jid: 'repair-summary@axi.im',
        title: 'Repair Summary',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 7, 18),
      );
      await db.createChat(
        contact.copyWith(lastMessage: 'FWD: sender@example.com'),
      );

      await db.saveMessage(
        Message(
          stanzaID: 'repair-summary-1',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 7, 9),
          body: 'much newer actual message',
          encryptionProtocol: EncryptionProtocol.none,
        ),
      );

      await db.repairChatSummaryPreservingTimestamp(contact.jid);

      final repaired = await db.getChat(contact.jid);
      expect(repaired?.lastMessage, 'much newer actual message');
      expect(repaired?.lastChangeTimestamp, DateTime.utc(2024, 1, 7, 18));
    },
  );

  test('countChatMessages can exclude pseudo messages', () async {
    final contact = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Bob',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      deltaChatId: 1,
      emailAddress: 'bob@example.com',
    );
    await db.createChat(contact);

    final realMessage = Message(
      stanzaID: 'real-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 1),
      body: 'hello',
      encryptionProtocol: EncryptionProtocol.none,
    );
    final pseudoMessage = Message(
      stanzaID: 'pseudo-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 2),
      pseudoMessageType: PseudoMessageType.newDevice,
      pseudoMessageData: const {'device': 'new'},
    );

    await db.saveMessage(realMessage);
    await db.saveMessage(pseudoMessage);

    final totalCount = await db.countChatMessages(contact.jid);
    final archivedCount = await db.countChatMessages(
      contact.jid,
      includePseudoMessages: false,
    );

    expect(totalCount, 2);
    expect(archivedCount, 1);
  });

  test('chat summary follows the newest saved message', () async {
    final contact = Chat(
      jid: 'summary-test@delta.chat',
      title: 'Summary Test',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
    );
    await db.createChat(contact);

    final firstMessage = Message(
      stanzaID: 'summary-1',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 1, 12),
      body: 'first message',
      encryptionProtocol: EncryptionProtocol.none,
    );
    final secondMessage = Message(
      stanzaID: 'summary-2',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: DateTime.utc(2024, 1, 1, 12, 1),
      body: 'second message',
      encryptionProtocol: EncryptionProtocol.none,
    );

    await db.saveMessage(firstMessage);
    await db.saveMessage(secondMessage);

    final updatedChat = await db.getChat(contact.jid);

    expect(updatedChat?.lastMessage, 'second message');
    expect(updatedChat?.lastChangeTimestamp, secondMessage.timestamp);
  });

  test(
    'roster-created placeholder chats do not pin the first imported history message',
    () async {
      const jid = 'roster-history@example.com';
      await db.saveRosterItems([RosterItem.fromJid(jid)]);

      final seededChat = await db.getChat(jid);
      expect(
        seededChat?.lastChangeTimestamp,
        DateTime.fromMillisecondsSinceEpoch(0),
      );

      final oldestMessage = Message(
        stanzaID: 'history-1',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 9),
        body: 'oldest imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final middleMessage = Message(
        stanzaID: 'history-2',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 10),
        body: 'middle imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final newestMessage = Message(
        stanzaID: 'history-3',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 11),
        body: 'newest imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );

      await db.saveMessage(oldestMessage);
      await db.saveMessage(middleMessage);
      await db.saveMessage(newestMessage);

      final updatedChat = await db.getChat(jid);
      expect(updatedChat?.lastMessage, 'newest imported message');
      expect(updatedChat?.lastChangeTimestamp, newestMessage.timestamp);
    },
  );

  test(
    'imported history repairs subtitle when chat timestamp is already newer',
    () async {
      const jid = 'snapshot-history@example.com';
      final externalTimestamp = DateTime.utc(2024, 1, 1, 12);
      await db.createChat(
        Chat(
          jid: jid,
          title: 'Snapshot History',
          type: ChatType.chat,
          lastChangeTimestamp: externalTimestamp,
        ),
      );

      final oldestMessage = Message(
        stanzaID: 'snapshot-history-1',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 9),
        body: 'oldest imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final middleMessage = Message(
        stanzaID: 'snapshot-history-2',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 10),
        body: 'middle imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final newestMessage = Message(
        stanzaID: 'snapshot-history-3',
        senderJid: jid,
        chatJid: jid,
        timestamp: DateTime.utc(2024, 1, 1, 11),
        body: 'newest imported message',
        encryptionProtocol: EncryptionProtocol.none,
      );

      await db.saveMessage(oldestMessage);
      await db.saveMessage(middleMessage);
      await db.saveMessage(newestMessage);

      final updatedChat = await db.getChat(jid);
      expect(updatedChat?.lastMessage, 'newest imported message');
      expect(updatedChat?.lastChangeTimestamp, externalTimestamp);
    },
  );

  test('same-timestamp email messages follow local insertion order', () async {
    final contact = Chat(
      jid: 'ordering-test@delta.chat',
      title: 'Ordering Test',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      deltaChatId: 1,
      emailAddress: 'ordering@example.com',
    );
    await db.createChat(contact);

    final sharedTimestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final oldestMessage = Message(
      stanzaID: 'dc-msg-12',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: sharedTimestamp,
      body: 'oldest',
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: contact.deltaChatId,
      deltaMsgId: 12,
    );
    final middleMessage = Message(
      stanzaID: 'dc-msg-300',
      senderJid: 'self@example.com',
      chatJid: contact.jid,
      timestamp: sharedTimestamp,
      body: 'middle',
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: contact.deltaChatId,
      deltaMsgId: 300,
    );
    final newestMessage = Message(
      stanzaID: 'dc-msg-40',
      senderJid: contact.jid,
      chatJid: contact.jid,
      timestamp: sharedTimestamp,
      body: 'newest',
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: contact.deltaChatId,
      deltaMsgId: 40,
    );

    await db.saveMessage(oldestMessage);
    await db.saveMessage(middleMessage);
    await db.saveMessage(newestMessage);

    final messages = await db.getChatMessages(contact.jid, start: 0, end: 10);

    expect(messages.map((message) => message.stanzaID), [
      newestMessage.stanzaID,
      middleMessage.stanzaID,
      oldestMessage.stanzaID,
    ]);
  });

  test(
    'same-timestamp email paging and counts ignore delta message ids',
    () async {
      final contact = Chat(
        jid: 'paging-test@delta.chat',
        title: 'Paging Test',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        deltaChatId: 1,
        emailAddress: 'paging@example.com',
      );
      await db.createChat(contact);

      final sharedTimestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final oldestMessage = Message(
        stanzaID: 'dc-msg-12',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'oldest',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 12,
      );
      final middleMessage = Message(
        stanzaID: 'dc-msg-300',
        senderJid: 'self@example.com',
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'middle',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 300,
      );
      final newestMessage = Message(
        stanzaID: 'dc-msg-40',
        senderJid: contact.jid,
        chatJid: contact.jid,
        timestamp: sharedTimestamp,
        body: 'newest',
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: contact.deltaChatId,
        deltaMsgId: 40,
      );

      await db.saveMessage(oldestMessage);
      await db.saveMessage(middleMessage);
      await db.saveMessage(newestMessage);

      final olderMessages = await db.getChatMessagesBefore(
        contact.jid,
        beforeTimestamp: sharedTimestamp,
        beforeStanzaId: middleMessage.stanzaID,
        beforeDeltaMsgId: middleMessage.deltaMsgId,
        limit: 10,
      );
      final messagesThroughMiddle = await db.countChatMessagesThrough(
        contact.jid,
        throughTimestamp: sharedTimestamp,
        throughStanzaId: middleMessage.stanzaID,
        throughDeltaMsgId: middleMessage.deltaMsgId,
      );

      expect(olderMessages.map((message) => message.stanzaID), [
        oldestMessage.stanzaID,
      ]);
      expect(messagesThroughMiddle, 2);
    },
  );

  test(
    'conversation index chat meta updates preserve unread and summary fields',
    () async {
      final contact = Chat(
        jid: 'conversation-index@example.com',
        title: 'Conversation Index',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1, 9),
      );
      await db.createChat(contact);

      await db.saveMessage(
        Message(
          stanzaID: 'conversation-index-1',
          senderJid: contact.jid,
          chatJid: contact.jid,
          timestamp: DateTime.utc(2024, 1, 1, 10),
          body: 'Unread preserved',
          encryptionProtocol: EncryptionProtocol.none,
        ),
        selfJid: 'self@example.com',
      );

      await db.updateConversationIndexChatMeta(
        jid: contact.jid,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1, 11),
        muted: true,
        favorited: true,
        archived: true,
        contactJid: contact.jid,
      );

      final chat = await db.getChat(contact.jid);
      expect(chat?.unreadCount, 1);
      expect(chat?.lastMessage, 'Unread preserved');
      expect(chat?.muted, isTrue);
      expect(chat?.favorited, isTrue);
      expect(chat?.archived, isTrue);
      expect(chat?.lastChangeTimestamp, DateTime.utc(2024, 1, 1, 11));
    },
  );
}
