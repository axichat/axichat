// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/chat/models/rfc_email_group.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  const chatId = 7;
  const contactJid = 'alice@example.com';

  late XmppDrift database;
  late MockDeltaContextHandle context;
  late DeltaEventConsumer consumer;

  setUp(() {
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
    context = MockDeltaContextHandle();
    consumer = DeltaEventConsumer(
      databaseBuilder: () async => database,
      core: DeltaContextEventCore(context),
      selfJidProvider: () => 'me@example.com',
    );
    when(() => context.getChat(any())).thenAnswer(
      (invocation) async => DeltaChat(
        id: invocation.positionalArguments.first as int,
        name: 'Alice',
        contactAddress: contactJid,
      ),
    );
    when(() => context.supportsMessageRfc724Mid).thenReturn(true);
    when(() => context.supportsMessageInfo).thenReturn(true);
    when(
      () => context.getMessageRfc724Mid(any()),
    ).thenAnswer((_) async => '<Shared@Example.COM>');
    when(() => context.getMessageInfo(any())).thenAnswer((_) async => null);
    when(
      () => context.getMessageMimeHeaders(any()),
    ).thenAnswer((_) async => null);
    when(
      () => context.getMessageIdsByRfc724Mid(any()),
    ).thenAnswer((_) async => const <int>[]);
    when(
      () => context.getMessageRfc822Body(any()),
    ).thenAnswer((_) async => null);
    when(() => context.getQuotedMessage(any())).thenAnswer((_) async => null);
    when(() => context.chatSendCapabilities(any())).thenAnswer(
      (_) async => const DeltaChatSendCapabilities(
        exists: true,
        canSend: true,
        isEncrypted: false,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> ingest(DeltaMessage part) async {
    when(() => context.getMessage(part.id)).thenAnswer((_) async => part);
    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: part.id,
      ),
    );
  }

  test(
    'multipart email ingests as one grouped email with every attachment',
    () async {
      final timestamp = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final parts = [
        DeltaMessage(
          id: 11,
          chatId: chatId,
          text: 'Vacation photos attached',
          timestamp: timestamp,
        ),
        DeltaMessage(
          id: 12,
          chatId: chatId,
          filePath: '/delta/photo.jpg',
          fileName: 'photo.jpg',
          fileMime: 'image/jpeg',
          fileSize: 4096,
          timestamp: timestamp,
        ),
        DeltaMessage(
          id: 13,
          chatId: chatId,
          filePath: '/delta/notes.pdf',
          fileName: 'notes.pdf',
          fileMime: 'application/pdf',
          fileSize: 2048,
          timestamp: timestamp,
        ),
      ];

      for (final part in parts) {
        await ingest(part);
      }

      final stored = await database.getMessagesByOriginID('Shared@example.com');
      expect(stored, hasLength(3));
      for (final row in stored) {
        expect(row.originID, 'Shared@example.com');
        expect(row.chatJid, contactJid);
        expect(row.senderJid, contactJid);
        expect(row.deltaChatId, chatId);
      }
      expect(stored.map((row) => row.deltaMsgId), [11, 12, 13]);
      expect(stored[0].fileMetadataID, isNull);
      expect(stored[1].fileMetadataID, 'dc-file-12');
      expect(stored[2].fileMetadataID, 'dc-file-13');

      for (final row in stored.skip(1)) {
        final attachments = await database.getMessageAttachments(row.id!);
        expect(attachments.map((attachment) => attachment.fileMetadataId), [
          row.fileMetadataID,
        ]);
      }

      final groups = buildRfcEmailGroupsByMessageStanzaId(
        messages: stored,
        attachmentsForMessage: (message) =>
            message.fileMetadataID == null ? [] : [message.fileMetadataID!],
        bodyTextForMessage: (message) =>
            rfcEmailBodyText(message: message, resolvedHtmlBody: null),
        requireMeaningfulBody: false,
      );
      final group = groups[stored[0].stanzaID];
      expect(group, isNotNull);
      for (final row in stored) {
        expect(groups[row.stanzaID], same(group));
      }
      expect(group!.leader.stanzaID, stored[0].stanzaID);
      expect(group.attachmentIdsByStanzaId.values.expand((ids) => ids), [
        'dc-file-12',
        'dc-file-13',
      ]);
    },
  );

  test('core chat id outranks a stale event chat id at ingest', () async {
    const staleEventChatId = 99;
    when(() => context.getChat(staleEventChatId)).thenAnswer(
      (_) async => const DeltaChat(
        id: staleEventChatId,
        name: 'Stale',
        contactAddress: 'stale@example.com',
      ),
    );
    final timestamp = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final body = DeltaMessage(
      id: 21,
      chatId: chatId,
      text: 'Body delivered under a stale event',
      timestamp: timestamp,
    );
    when(() => context.getMessage(body.id)).thenAnswer((_) async => body);

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: staleEventChatId,
        data2: body.id,
      ),
    );

    final rows = await database.getMessagesByDeltaIds(const [21]);
    expect(rows, hasLength(1));
    expect(rows.single.chatJid, contactJid);
    expect(rows.single.deltaChatId, chatId);
  });

  test('a part ingested into the wrong chat is re-homed intact', () async {
    const strayChatId = 99;
    when(() => context.getChat(strayChatId)).thenAnswer(
      (_) async => const DeltaChat(
        id: strayChatId,
        name: 'Stray',
        contactAddress: 'stray@example.com',
      ),
    );
    final timestamp = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final body = DeltaMessage(
      id: 11,
      chatId: chatId,
      text: 'Vacation photos attached',
      timestamp: timestamp,
    );
    final strayPart = DeltaMessage(
      id: 12,
      chatId: strayChatId,
      filePath: '/delta/photo.jpg',
      fileName: 'photo.jpg',
      fileMime: 'image/jpeg',
      fileSize: 4096,
      timestamp: timestamp,
    );
    final rehomedPart = DeltaMessage(
      id: 12,
      chatId: chatId,
      filePath: '/delta/photo.jpg',
      fileName: 'photo.jpg',
      fileMime: 'image/jpeg',
      fileSize: 4096,
      timestamp: timestamp,
    );

    await ingest(body);
    when(
      () => context.getMessage(strayPart.id),
    ).thenAnswer((_) async => strayPart);
    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: strayChatId,
        data2: strayPart.id,
      ),
    );

    final misplaced = await database.getMessagesByOriginID(
      'Shared@example.com',
    );
    expect(
      misplaced.map((row) => row.chatJid),
      containsAll(['stray@example.com']),
    );

    await ingest(rehomedPart);

    final stored = await database.getMessagesByOriginID('Shared@example.com');
    expect(stored, hasLength(2));
    for (final row in stored) {
      expect(row.chatJid, contactJid);
      expect(row.senderJid, contactJid);
      expect(row.deltaChatId, chatId);
    }
    final filePart = stored.singleWhere((row) => row.deltaMsgId == 12);
    expect(filePart.fileMetadataID, 'dc-file-12');
    final attachments = await database.getMessageAttachments(filePart.id!);
    expect(attachments.map((attachment) => attachment.fileMetadataId), [
      'dc-file-12',
    ]);

    final groups = buildRfcEmailGroupsByMessageStanzaId(
      messages: stored,
      attachmentsForMessage: (message) =>
          message.fileMetadataID == null ? [] : [message.fileMetadataID!],
      bodyTextForMessage: (message) =>
          rfcEmailBodyText(message: message, resolvedHtmlBody: null),
      requireMeaningfulBody: false,
    );
    final group = groups[stored[0].stanzaID];
    expect(group, isNotNull);
    expect(groups[filePart.stanzaID], same(group));
    expect(group!.attachmentIdsByStanzaId.values.expand((ids) => ids), [
      'dc-file-12',
    ]);
  });
}
