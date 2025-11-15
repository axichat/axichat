import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

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

    expect(
      directOnly.map((msg) => msg.stanzaID),
      isNot(contains('share-1')),
    );
    expect(
      allWithContact.map((msg) => msg.stanzaID),
      contains('share-1'),
    );
    expect(
      allWithContact.map((msg) => msg.stanzaID),
      contains('direct-1'),
    );
  });
}
