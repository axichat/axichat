import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late XmppDrift db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'email_encryption_status_marker_test',
    );
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

  test('creates one marker for the first OpenPGP email in a chat', () async {
    const chatJid = 'alice@example.com';
    final timestamp = DateTime.utc(2024, 1, 1, 12);
    await db.saveMessage(
      _openPgpEmail(
        chatJid: chatJid,
        stanzaId: 'pgp-1',
        timestamp: timestamp,
        deltaMsgId: 1,
      ),
    );

    await db.ensureEmailEncryptionStatusMarkerForChat(chatJid);

    final marker = await db.getMessageByStanzaID(
      emailEncryptionStatusMarkerStanzaId(chatJid),
    );
    expect(marker, isNotNull);
    expect(marker?.pseudoMessageType, PseudoMessageType.emailEncryptionStatus);
    expect(marker?.emailEncryptionStatusAnchorStanzaId, 'pgp-1');
    expect(
      marker?.timestamp,
      timestamp.subtract(const Duration(microseconds: 1)),
    );

    final messages = await db.getChatMessages(chatJid, start: 0, end: 10);
    expect(messages.map((message) => message.stanzaID), [
      'pgp-1',
      emailEncryptionStatusMarkerStanzaId(chatJid),
    ]);
  });

  test('marker does not replace the chat preview or unread count', () async {
    const chatJid = 'alice@example.com';
    await db.saveMessage(
      _openPgpEmail(
        chatJid: chatJid,
        stanzaId: 'pgp-1',
        timestamp: DateTime.utc(2024, 1, 1, 12),
        deltaMsgId: 1,
      ),
      selfJid: 'me@example.com',
    );

    await db.ensureEmailEncryptionStatusMarkerForChat(chatJid);
    await db.repairChatSummaryPreservingTimestamp(chatJid);

    final chat = await db.getChat(chatJid);
    expect(chat?.lastMessage, 'Encrypted');
    expect(chat?.unreadCount, 1);
  });

  test('updates the marker only when older OpenPGP history arrives', () async {
    const chatJid = 'alice@example.com';
    final newerTimestamp = DateTime.utc(2024, 1, 2, 12);
    final olderTimestamp = DateTime.utc(2024, 1, 1, 12);
    await db.saveMessage(
      _openPgpEmail(
        chatJid: chatJid,
        stanzaId: 'pgp-newer',
        timestamp: newerTimestamp,
        deltaMsgId: 2,
      ),
    );
    await db.ensureEmailEncryptionStatusMarkerForChat(chatJid);

    await db.saveMessage(
      _openPgpEmail(
        chatJid: chatJid,
        stanzaId: 'pgp-older',
        timestamp: olderTimestamp,
        deltaMsgId: 1,
      ),
    );
    await db.ensureEmailEncryptionStatusMarkerForChat(chatJid);

    final marker = await db.getMessageByStanzaID(
      emailEncryptionStatusMarkerStanzaId(chatJid),
    );
    expect(marker?.emailEncryptionStatusAnchorStanzaId, 'pgp-older');
    expect(
      marker?.emailEncryptionStatusAnchorTimestampMicros,
      olderTimestamp.microsecondsSinceEpoch,
    );

    final messages = await db.getChatMessages(chatJid, start: 0, end: 10);
    expect(
      messages
          .where(
            (message) =>
                message.pseudoMessageType ==
                PseudoMessageType.emailEncryptionStatus,
          )
          .length,
      1,
    );
  });

  test(
    'does not re-anchor to newer OpenPGP mail after deleting the first',
    () async {
      const chatJid = 'alice@example.com';
      final olderTimestamp = DateTime.utc(2024, 1, 1, 12);
      final newerTimestamp = DateTime.utc(2024, 1, 2, 12);
      await db.saveMessage(
        _openPgpEmail(
          chatJid: chatJid,
          stanzaId: 'pgp-older',
          timestamp: olderTimestamp,
          deltaMsgId: 1,
        ),
      );
      await db.ensureEmailEncryptionStatusMarkerForChat(chatJid);
      await db.deleteMessage('pgp-older');

      await db.saveMessage(
        _openPgpEmail(
          chatJid: chatJid,
          stanzaId: 'pgp-newer',
          timestamp: newerTimestamp,
          deltaMsgId: 2,
        ),
      );
      await db.ensureEmailEncryptionStatusMarkerForChat(chatJid);

      final marker = await db.getMessageByStanzaID(
        emailEncryptionStatusMarkerStanzaId(chatJid),
      );
      expect(marker?.emailEncryptionStatusAnchorStanzaId, 'pgp-older');
      expect(
        marker?.emailEncryptionStatusAnchorTimestampMicros,
        olderTimestamp.microsecondsSinceEpoch,
      );
    },
  );

  test('ignores plaintext email and non-email OpenPGP messages', () async {
    const chatJid = 'alice@example.com';
    await db.saveMessage(
      Message(
        stanzaID: 'plain-email',
        senderJid: chatJid,
        chatJid: chatJid,
        body: 'Plain',
        timestamp: DateTime.utc(2024, 1, 1, 12),
        deltaChatId: 1,
        deltaMsgId: 1,
      ),
    );
    await db.ensureEmailEncryptionStatusMarkerForChat(chatJid);
    expect(
      await db.getMessageByStanzaID(
        emailEncryptionStatusMarkerStanzaId(chatJid),
      ),
      isNull,
    );

    await db.saveMessage(
      Message(
        stanzaID: 'xmpp-openpgp',
        senderJid: chatJid,
        chatJid: chatJid,
        body: 'Not email-backed',
        timestamp: DateTime.utc(2024, 1, 2, 12),
        encryptionProtocol: EncryptionProtocol.openPgp,
      ),
    );
    await db.ensureEmailEncryptionStatusMarkerForChat(chatJid);
    expect(
      await db.getMessageByStanzaID(
        emailEncryptionStatusMarkerStanzaId(chatJid),
      ),
      isNull,
    );
  });
}

Message _openPgpEmail({
  required String chatJid,
  required String stanzaId,
  required DateTime timestamp,
  required int deltaMsgId,
}) {
  return Message(
    stanzaID: stanzaId,
    senderJid: chatJid,
    chatJid: chatJid,
    body: 'Encrypted',
    timestamp: timestamp,
    encryptionProtocol: EncryptionProtocol.openPgp,
    deltaChatId: 1,
    deltaMsgId: deltaMsgId,
  );
}
