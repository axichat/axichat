import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const String _chatJid = 'chat@axi.im';
const String _messageStanzaId = 'message-id';
const String _messageOriginId = 'origin-id';
const String _messageMucStanzaId = 'muc-message-id';
const String _selfActorJid = 'self@axi.im';
const String _peerActorJid = 'peer@axi.im';
const String _emptyPassphrase = '';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late XmppDrift database;

  setUp(() {
    database = XmppDrift(
      file: File(''),
      passphrase: _emptyPassphrase,
      executor: NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('older pin mutations do not override a newer unpin tombstone', () async {
    final initialPinAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final unpinnedAt = initialPinAt.add(const Duration(minutes: 5));

    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
      pinnedAt: initialPinAt,
      active: true,
    );
    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
      pinnedAt: unpinnedAt,
      active: false,
    );
    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
      pinnedAt: initialPinAt,
      active: true,
    );

    final visible = await database.getPinnedMessages(_chatJid);
    final stored = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );

    expect(visible, isEmpty);
    expect(stored, isNotNull);
    expect(stored!.active, isFalse);
    expect(stored.pinnedAt, unpinnedAt);
  });

  test('same-timestamp unpin wins over a matching pin', () async {
    final timestamp = DateTime.utc(2026, 3, 9, 12, 0, 0);

    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
      pinnedAt: timestamp,
      active: true,
    );
    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
      pinnedAt: timestamp,
      active: false,
    );
    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
      pinnedAt: timestamp,
      active: true,
    );

    final visible = await database.getPinnedMessages(_chatJid);
    final stored = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );

    expect(visible, isEmpty);
    expect(stored, isNotNull);
    expect(stored!.active, isFalse);
    expect(stored.pinnedAt, timestamp);
  });

  test(
    'alias normalization collapses newer tombstones onto the canonical id',
    () async {
      final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
      final unpinnedAt = pinnedAt.add(const Duration(minutes: 5));

      await database.applyPinnedMessageMutation(
        chatJid: _chatJid,
        messageStanzaId: _messageStanzaId,
        pinnedAt: pinnedAt,
        active: true,
      );
      await database.applyPinnedMessageMutation(
        chatJid: _chatJid,
        messageStanzaId: _messageOriginId,
        pinnedAt: unpinnedAt,
        active: false,
      );

      await database.normalizePinnedMessageAliases(
        chatJid: _chatJid,
        canonicalMessageStanzaId: _messageStanzaId,
        aliases: const {_messageStanzaId, _messageOriginId},
      );

      final visible = await database.getPinnedMessages(_chatJid);
      final canonical = await database.getPinnedMessage(
        chatJid: _chatJid,
        messageStanzaId: _messageStanzaId,
      );
      final alias = await database.getPinnedMessage(
        chatJid: _chatJid,
        messageStanzaId: _messageOriginId,
      );

      expect(visible, isEmpty);
      expect(canonical, isNotNull);
      expect(canonical!.active, isFalse);
      expect(canonical.pinnedAt, unpinnedAt);
      expect(alias, isNull);
    },
  );

  test('actor pin rows aggregate by message reference', () async {
    final selfPinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final peerPinnedAt = selfPinnedAt.add(const Duration(minutes: 5));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
      pinnedAt: selfPinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
      pinnedAt: peerPinnedAt,
      active: true,
      identityVerified: true,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfActorJid: _selfActorJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );

    expect(aggregates, hasLength(1));
    expect(
      aggregates.single.messageReferenceKind,
      MessageReferenceKind.stanzaId,
    );
    expect(aggregates.single.messageReferenceId, _messageStanzaId);
    expect(aggregates.single.pinCount, 2);
    expect(aggregates.single.pinnedBySelf, isTrue);
    expect(aggregates.single.pinnedAt, peerPinnedAt);
    expect(legacy, isNotNull);
    expect(legacy!.active, isTrue);
    expect(legacy.pinnedAt, peerPinnedAt);
  });

  test('clear all actor pins leaves a legacy tombstone', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final clearedAt = pinnedAt.add(const Duration(minutes: 5));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.clearPinnedMessageActors(
      chatJid: _chatJid,
      reference: reference,
      pinnedAt: clearedAt,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfActorJid: _selfActorJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );
    final selfActor = await database.getPinnedMessageActor(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
    );
    final peerActor = await database.getPinnedMessageActor(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
    );

    expect(aggregates, isEmpty);
    expect(legacy, isNotNull);
    expect(legacy!.active, isFalse);
    expect(legacy.pinnedAt, clearedAt);
    expect(selfActor?.active, isFalse);
    expect(peerActor?.active, isFalse);
  });

  test('clear all tombstone blocks older missing actor pins', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final clearedAt = pinnedAt.add(const Duration(minutes: 5));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.clearPinnedMessageActors(
      chatJid: _chatJid,
      reference: reference,
      pinnedAt: clearedAt,
    );
    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfActorJid: _selfActorJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );
    final peerActor = await database.getPinnedMessageActor(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
    );

    expect(aggregates, isEmpty);
    expect(legacy, isNotNull);
    expect(legacy!.active, isFalse);
    expect(legacy.pinnedAt, clearedAt);
    expect(peerActor, isNull);
  });

  test('clear all tombstone does not hide newer actor pins', () async {
    final olderPinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final clearedAt = olderPinnedAt.add(const Duration(minutes: 5));
    final newerPinnedAt = olderPinnedAt.add(const Duration(minutes: 10));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
      pinnedAt: newerPinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.clearPinnedMessageActors(
      chatJid: _chatJid,
      reference: reference,
      pinnedAt: clearedAt,
    );
    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
      pinnedAt: olderPinnedAt,
      active: true,
      identityVerified: true,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfActorJid: _selfActorJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );
    final selfActor = await database.getPinnedMessageActor(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
    );
    final peerActor = await database.getPinnedMessageActor(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
    );

    expect(aggregates, hasLength(1));
    expect(aggregates.single.pinCount, 1);
    expect(aggregates.single.pinnedBySelf, isFalse);
    expect(aggregates.single.pinnedAt, newerPinnedAt);
    expect(legacy, isNotNull);
    expect(legacy!.active, isTrue);
    expect(legacy.pinnedAt, newerPinnedAt);
    expect(selfActor, isNull);
    expect(peerActor?.active, isTrue);
  });

  test('actor unpin does not become a clear-all tombstone', () async {
    final selfPinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final peerPinnedAt = selfPinnedAt.add(const Duration(minutes: 2));
    final selfUnpinnedAt = selfPinnedAt.add(const Duration(minutes: 5));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
      pinnedAt: selfPinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
      pinnedAt: selfUnpinnedAt,
      active: false,
      identityVerified: true,
    );
    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
      pinnedAt: peerPinnedAt,
      active: true,
      identityVerified: true,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfActorJid: _selfActorJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );
    final selfActor = await database.getPinnedMessageActor(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
    );
    final peerActor = await database.getPinnedMessageActor(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _peerActorJid,
    );

    expect(aggregates, hasLength(1));
    expect(aggregates.single.pinCount, 1);
    expect(aggregates.single.pinnedBySelf, isFalse);
    expect(aggregates.single.pinnedAt, peerPinnedAt);
    expect(legacy, isNotNull);
    expect(legacy!.active, isTrue);
    expect(legacy.pinnedAt, peerPinnedAt);
    expect(selfActor?.active, isFalse);
    expect(peerActor?.active, isTrue);
  });

  test('deleting a message clears legacy and actor pin references', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const reference = MessageReference(
      kind: MessageReferenceKind.mucStanzaId,
      value: _messageMucStanzaId,
    );

    await database.saveMessage(
      Message(
        stanzaID: _messageStanzaId,
        mucStanzaId: _messageMucStanzaId,
        senderJid: _peerActorJid,
        chatJid: _chatJid,
        timestamp: pinnedAt,
        body: 'hello',
      ),
    );
    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: _messageMucStanzaId,
      pinnedAt: pinnedAt,
      active: true,
    );
    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );

    await database.deleteMessage(_messageStanzaId);

    expect(
      await database.getPinnedMessage(
        chatJid: _chatJid,
        messageStanzaId: _messageMucStanzaId,
      ),
      isNull,
    );
    expect(
      await database.getPinnedMessageActor(
        chatJid: _chatJid,
        reference: reference,
        actorJid: _selfActorJid,
      ),
      isNull,
    );
  });

  test('clearing message history clears legacy and actor pin rows', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyActorPinnedMessageMutation(
      chatJid: _chatJid,
      reference: reference,
      actorJid: _selfActorJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );

    await database.clearMessageHistory();

    expect(await database.getPinnedMessages(_chatJid), isEmpty);
    expect(
      await database.getPinnedMessageActor(
        chatJid: _chatJid,
        reference: reference,
        actorJid: _selfActorJid,
      ),
      isNull,
    );
    expect(
      await database.getPinnedMessageAggregates(
        chatJid: _chatJid,
        selfActorJid: _selfActorJid,
      ),
      isEmpty,
    );
  });

  test(
    'trimming messages clears legacy and actor MUC pin references',
    () async {
      final oldPinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
      final newTimestamp = oldPinnedAt.add(const Duration(minutes: 1));
      const reference = MessageReference(
        kind: MessageReferenceKind.mucStanzaId,
        value: _messageMucStanzaId,
      );

      await database.saveMessage(
        Message(
          stanzaID: _messageStanzaId,
          mucStanzaId: _messageMucStanzaId,
          senderJid: _peerActorJid,
          chatJid: _chatJid,
          timestamp: oldPinnedAt,
          body: 'old',
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'new-message-id',
          mucStanzaId: 'new-muc-message-id',
          senderJid: _peerActorJid,
          chatJid: _chatJid,
          timestamp: newTimestamp,
          body: 'new',
        ),
      );
      await database.applyActorPinnedMessageMutation(
        chatJid: _chatJid,
        reference: reference,
        actorJid: _selfActorJid,
        pinnedAt: oldPinnedAt,
        active: true,
        identityVerified: true,
      );

      await database.trimChatMessages(jid: _chatJid, maxMessages: 1);

      expect(
        await database.getPinnedMessage(
          chatJid: _chatJid,
          messageStanzaId: _messageMucStanzaId,
        ),
        isNull,
      );
      expect(
        await database.getPinnedMessageActor(
          chatJid: _chatJid,
          reference: reference,
          actorJid: _selfActorJid,
        ),
        isNull,
      );
    },
  );

  test('legacy migration skips email-backed pinned messages', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.saveMessage(
      Message(
        stanzaID: _messageStanzaId,
        senderJid: _peerActorJid,
        chatJid: _chatJid,
        deltaAccountId: 1,
        deltaMsgId: 2,
        timestamp: pinnedAt,
        body: 'hello',
      ),
    );
    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
      pinnedAt: pinnedAt,
      active: true,
    );

    await database.copyLegacyPinnedMessagesToActorRows(actorJid: _selfActorJid);

    expect(
      await database.getPinnedMessageActor(
        chatJid: _chatJid,
        reference: reference,
        actorJid: _selfActorJid,
      ),
      isNull,
    );
  });

  test(
    'legacy migration skips email chat pins without local messages',
    () async {
      const emailChatJid = 'mail@example.com';
      const missingMessageId = 'missing-email-message-id';
      final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
      const reference = MessageReference(
        kind: MessageReferenceKind.stanzaId,
        value: missingMessageId,
      );

      await database.createChat(
        Chat(
          jid: emailChatJid,
          title: 'Mail',
          type: ChatType.chat,
          lastChangeTimestamp: pinnedAt,
          transport: MessageTransport.email,
          emailAddress: emailChatJid,
        ),
      );
      await database.applyPinnedMessageMutation(
        chatJid: emailChatJid,
        messageStanzaId: missingMessageId,
        pinnedAt: pinnedAt,
        active: true,
      );

      await database.copyLegacyPinnedMessagesToActorRows(
        actorJid: _selfActorJid,
      );

      expect(
        await database.getPinnedMessageActor(
          chatJid: emailChatJid,
          reference: reference,
          actorJid: _selfActorJid,
        ),
        isNull,
      );
    },
  );

  test(
    'legacy migration skips direct pins for peer-authored messages',
    () async {
      final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
      const reference = MessageReference(
        kind: MessageReferenceKind.stanzaId,
        value: _messageStanzaId,
      );

      await database.saveMessage(
        Message(
          stanzaID: _messageStanzaId,
          senderJid: _peerActorJid,
          chatJid: _chatJid,
          timestamp: pinnedAt,
          body: 'hello',
        ),
      );
      await database.applyPinnedMessageMutation(
        chatJid: _chatJid,
        messageStanzaId: _messageStanzaId,
        pinnedAt: pinnedAt,
        active: true,
      );

      await database.copyLegacyPinnedMessagesToActorRows(
        actorJid: _selfActorJid,
      );

      expect(
        await database.getPinnedMessageActor(
          chatJid: _chatJid,
          reference: reference,
          actorJid: _selfActorJid,
        ),
        isNull,
      );
    },
  );
}
