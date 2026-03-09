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
}
