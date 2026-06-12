// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late XmppDrift database;

  const deltaAccountId = 1;
  const deltaMsgId = 42;
  const firstChatId = 7;
  const secondChatId = 8;
  const firstJid = 'first@example.com';
  const secondJid = 'second@example.com';

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

  Message locatorRow({
    required String stanzaId,
    required String jid,
    required int chatId,
    DateTime? timestamp,
  }) {
    return Message(
      stanzaID: stanzaId,
      senderJid: jid,
      chatJid: jid,
      timestamp: timestamp ?? DateTime.utc(2026, 1, 1),
      body: stanzaId,
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
      deltaMsgId: deltaMsgId,
    );
  }

  test('a delta locator can only ever own one row', () async {
    await database.saveMessage(
      locatorRow(stanzaId: 'dc-msg-42', jid: firstJid, chatId: firstChatId),
    );
    await database.saveMessage(
      locatorRow(
        stanzaId: 'dc-local-msg-1-8-42',
        jid: secondJid,
        chatId: secondChatId,
        timestamp: DateTime.utc(2026, 1, 2),
      ),
    );

    final rows = await database.getMessagesByDeltaIds(const [
      deltaMsgId,
    ], deltaAccountId: deltaAccountId);
    expect(rows, hasLength(1));
    expect(rows.single.chatJid, firstJid);
  });

  test('rehomeDeltaMessage moves the row and its memberships', () async {
    await database.createChat(
      Chat(
        jid: secondJid,
        title: 'Second',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1, 1),
        transport: MessageTransport.email,
      ),
    );
    await database.saveMessage(
      locatorRow(stanzaId: 'dc-msg-42', jid: firstJid, chatId: firstChatId),
    );
    await database.applyMessageCollectionMembershipMutation(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'dc-msg-42',
      messageStanzaId: null,
      messageOriginId: null,
      messageMucStanzaId: null,
      deltaAccountId: deltaAccountId,
      deltaMsgId: deltaMsgId,
      addedAt: DateTime.utc(2026, 1, 3),
      active: true,
    );

    final rehomed = await database.rehomeDeltaMessage(
      deltaMsgId: deltaMsgId,
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
      chatJid: secondJid,
      senderJid: secondJid,
    );

    expect(rehomed, isNotNull);
    expect(rehomed!.stanzaID, 'dc-msg-42');
    expect(rehomed.chatJid, secondJid);
    expect(rehomed.deltaChatId, secondChatId);
    expect(rehomed.senderJid, secondJid);

    final tombstone = await database.getMessageCollectionMembership(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'dc-msg-42',
    );
    expect(tombstone, isNotNull);
    expect(tombstone!.active, isFalse);
    final moved = await database.getMessageCollectionMembership(
      collectionId: 'favorites',
      chatJid: secondJid,
      messageReferenceId: 'dc-msg-42',
    );
    expect(moved, isNotNull);
    expect(moved!.active, isTrue);

    await database.applyMessageCollectionMembershipMutation(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'dc-msg-42',
      messageStanzaId: null,
      messageOriginId: null,
      messageMucStanzaId: null,
      deltaAccountId: deltaAccountId,
      deltaMsgId: deltaMsgId,
      addedAt: DateTime.utc(2026, 1, 2),
      active: true,
    );
    final afterStaleRemote = await database.getMessageCollectionMembership(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'dc-msg-42',
    );
    expect(afterStaleRemote!.active, isFalse);

    final oldChat = await database.getChat(firstJid);
    final newChat = await database.getChat(secondJid);
    expect(oldChat!.unreadCount, 0);
    expect(newChat!.unreadCount, 1);
  });

  test('rehomeDeltaMessage moves pins with the row', () async {
    await database.saveMessage(
      Message(
        stanzaID: 'dc-msg-42',
        senderJid: firstJid,
        chatJid: firstJid,
        timestamp: DateTime.utc(2026, 1, 1),
        body: 'pinned body',
        originID: 'thread-42@example.com',
        deltaAccountId: deltaAccountId,
        deltaChatId: firstChatId,
        deltaMsgId: deltaMsgId,
      ),
    );
    await database.upsertPinnedMessage(
      PinnedMessageEntry(
        messageStanzaId: 'dc-msg-42',
        chatJid: firstJid,
        pinnedAt: DateTime.utc(2026, 1, 3),
        active: true,
      ),
    );
    final stored = await database.getMessageByDeltaId(
      deltaMsgId,
      deltaAccountId: deltaAccountId,
    );
    final reference = stored!.collectionReference(isGroupChat: false);
    await database.applyMessagePinMutation(
      chatJid: firstJid,
      reference: reference!,
      pinnerJid: firstJid,
      pinnedAt: DateTime.utc(2026, 1, 3),
      active: true,
      identityVerified: true,
    );

    await database.rehomeDeltaMessage(
      deltaMsgId: deltaMsgId,
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
      chatJid: secondJid,
      senderJid: secondJid,
    );

    final stalePinned = await database.getPinnedMessage(
      chatJid: firstJid,
      messageStanzaId: 'dc-msg-42',
    );
    expect(stalePinned, isNull);
    final movedPinned = await database.getPinnedMessage(
      chatJid: secondJid,
      messageStanzaId: 'dc-msg-42',
    );
    expect(movedPinned, isNotNull);
    expect(movedPinned!.active, isTrue);

    final stalePin = await database.getMessagePin(
      chatJid: firstJid,
      reference: reference,
      pinnerJid: firstJid,
    );
    expect(stalePin, isNull);
    final movedPin = await database.getMessagePin(
      chatJid: secondJid,
      reference: reference,
      pinnerJid: firstJid,
    );
    expect(movedPin, isNotNull);
    expect(movedPin!.active, isTrue);
  });

  test('same-chat delta chat renumbering keeps memberships intact', () async {
    await database.saveMessage(
      locatorRow(stanzaId: 'dc-msg-42', jid: firstJid, chatId: firstChatId),
    );
    await database.applyMessageCollectionMembershipMutation(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'dc-msg-42',
      messageStanzaId: null,
      messageOriginId: null,
      messageMucStanzaId: null,
      deltaAccountId: deltaAccountId,
      deltaMsgId: deltaMsgId,
      addedAt: DateTime.utc(2026, 1, 3),
      active: true,
    );

    final rehomed = await database.rehomeDeltaMessage(
      deltaMsgId: deltaMsgId,
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
      chatJid: firstJid,
      senderJid: firstJid,
    );

    expect(rehomed, isNotNull);
    expect(rehomed!.chatJid, firstJid);
    expect(rehomed.deltaChatId, secondChatId);

    final kept = await database.getMessageCollectionMembership(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'dc-msg-42',
    );
    expect(kept, isNotNull);
    expect(kept!.active, isTrue);
  });

  test('rehomeDeltaMessage merges already-occupied memberships', () async {
    await database.saveMessage(
      locatorRow(stanzaId: 'dc-msg-42', jid: firstJid, chatId: firstChatId),
    );
    for (final jid in const [firstJid, secondJid]) {
      await database.applyMessageCollectionMembershipMutation(
        collectionId: 'favorites',
        chatJid: jid,
        messageReferenceId: 'dc-msg-42',
        messageStanzaId: null,
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: deltaAccountId,
        deltaMsgId: deltaMsgId,
        addedAt: DateTime.utc(2026, 1, 3),
        active: true,
      );
    }

    final rehomed = await database.rehomeDeltaMessage(
      deltaMsgId: deltaMsgId,
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
      chatJid: secondJid,
      senderJid: secondJid,
    );
    expect(rehomed?.chatJid, secondJid);

    final tombstone = await database.getMessageCollectionMembership(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'dc-msg-42',
    );
    expect(tombstone, isNotNull);
    expect(tombstone!.active, isFalse);
    final kept = await database.getMessageCollectionMembership(
      collectionId: 'favorites',
      chatJid: secondJid,
      messageReferenceId: 'dc-msg-42',
    );
    expect(kept, isNotNull);
  });

  test('v62 collapse keeps the account-mapping-consistent row', () async {
    await database.customStatement(
      'DROP INDEX IF EXISTS messages_delta_locator',
    );
    await database.createChat(
      Chat(
        jid: secondJid,
        title: 'Second',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1, 1),
        transport: MessageTransport.email,
      ),
    );
    await database.upsertEmailChatAccount(
      chatJid: secondJid,
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
    );
    final ghost = locatorRow(
      stanzaId: 'ghost-row',
      jid: firstJid,
      chatId: firstChatId,
      timestamp: DateTime.utc(2026, 1, 2),
    );
    await database.into(database.messages).insert(ghost);
    await database
        .into(database.messages)
        .insert(
          locatorRow(
            stanzaId: 'real-row',
            jid: secondJid,
            chatId: secondChatId,
            timestamp: DateTime.utc(2026, 1, 1),
          ),
        );
    final storedGhost = await database.getMessageByStanzaID('ghost-row');
    await database
        .into(database.messageAttachments)
        .insert(
          MessageAttachmentsCompanion.insert(
            messageId: storedGhost!.id!,
            fileMetadataId: 'ghost-file',
          ),
        );

    final removed = await database.collapseDuplicateDeltaPairRows();

    expect(removed, 1);
    final rows = await database.getMessagesByDeltaIds(const [
      deltaMsgId,
    ], deltaAccountId: deltaAccountId);
    expect(rows, hasLength(1));
    expect(rows.single.stanzaID, 'real-row');
    expect(rows.single.chatJid, secondJid);
    final orphanAttachments = await database.getMessageAttachments(
      storedGhost.id!,
    );
    expect(orphanAttachments, isEmpty);
    await database.customStatement(
      'CREATE UNIQUE INDEX messages_delta_locator '
      'ON messages (delta_account_id, delta_msg_id)',
    );
  });

  test('v62 collapse migrates ghost memberships to the keeper chat', () async {
    await database.customStatement(
      'DROP INDEX IF EXISTS messages_delta_locator',
    );
    await database.createChat(
      Chat(
        jid: secondJid,
        title: 'Second',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1, 1),
        transport: MessageTransport.email,
      ),
    );
    await database.upsertEmailChatAccount(
      chatJid: secondJid,
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
    );
    await database
        .into(database.messages)
        .insert(
          locatorRow(stanzaId: 'ghost-row', jid: firstJid, chatId: firstChatId),
        );
    await database
        .into(database.messages)
        .insert(
          locatorRow(
            stanzaId: 'real-row',
            jid: secondJid,
            chatId: secondChatId,
            timestamp: DateTime.utc(2026, 1, 2),
          ),
        );
    await database.applyMessageCollectionMembershipMutation(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'ghost-row',
      messageStanzaId: null,
      messageOriginId: null,
      messageMucStanzaId: null,
      deltaAccountId: deltaAccountId,
      deltaMsgId: deltaMsgId,
      addedAt: DateTime.utc(2026, 1, 3),
      active: true,
    );

    final removed = await database.collapseDuplicateDeltaPairRows();

    expect(removed, 1);
    final tombstone = await database.getMessageCollectionMembership(
      collectionId: 'favorites',
      chatJid: firstJid,
      messageReferenceId: 'ghost-row',
    );
    expect(tombstone, isNotNull);
    expect(tombstone!.active, isFalse);
    final migrated = await database.getMessageCollectionMembership(
      collectionId: 'favorites',
      chatJid: secondJid,
      messageReferenceId: 'ghost-row',
    );
    expect(migrated, isNotNull);
    expect(migrated!.active, isTrue);
  });

  test(
    'v62 collapse without a mapping keeps the newest cross-chat row',
    () async {
      await database.customStatement(
        'DROP INDEX IF EXISTS messages_delta_locator',
      );
      await database
          .into(database.messages)
          .insert(
            locatorRow(
              stanzaId: 'ghost-row',
              jid: firstJid,
              chatId: firstChatId,
            ),
          );
      await database
          .into(database.messages)
          .insert(
            locatorRow(
              stanzaId: 'real-row',
              jid: secondJid,
              chatId: secondChatId,
              timestamp: DateTime.utc(2026, 1, 2),
            ),
          );

      final removed = await database.collapseDuplicateDeltaPairRows();

      expect(removed, 1);
      final rows = await database.getMessagesByDeltaIds(const [
        deltaMsgId,
      ], deltaAccountId: deltaAccountId);
      expect(rows, hasLength(1));
      expect(rows.single.stanzaID, 'real-row');
    },
  );

  test('v62 collapse includes unscoped ghost rows', () async {
    await database.customStatement(
      'DROP INDEX IF EXISTS messages_delta_locator',
    );
    await database.createChat(
      Chat(
        jid: secondJid,
        title: 'Second',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 1, 1),
        transport: MessageTransport.email,
      ),
    );
    await database.upsertEmailChatAccount(
      chatJid: secondJid,
      deltaAccountId: deltaAccountId,
      deltaChatId: secondChatId,
    );
    final unscopedGhost = Message(
      stanzaID: 'unscoped-ghost',
      senderJid: firstJid,
      chatJid: firstJid,
      timestamp: DateTime.utc(2026, 1, 1),
      body: 'unscoped',
      deltaAccountId: deltaAccountId,
      deltaMsgId: deltaMsgId,
    );
    await database.into(database.messages).insert(unscopedGhost);
    await database
        .into(database.messages)
        .insert(
          locatorRow(
            stanzaId: 'real-row',
            jid: secondJid,
            chatId: secondChatId,
            timestamp: DateTime.utc(2026, 1, 2),
          ),
        );

    final removed = await database.collapseDuplicateDeltaPairRows();

    expect(removed, 1);
    final rows = await database.getMessagesByDeltaIds(const [
      deltaMsgId,
    ], deltaAccountId: deltaAccountId);
    expect(rows, hasLength(1));
    expect(rows.single.stanzaID, 'real-row');
  });
}
