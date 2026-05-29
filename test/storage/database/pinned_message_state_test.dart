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
const String _selfPinnerJid = 'self@axi.im';
const String _peerPinnerJid = 'peer@axi.im';
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

  test('alias normalization rewrites message pin rows', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const originReference = MessageReference(
      kind: MessageReferenceKind.originId,
      value: _messageOriginId,
    );
    const stanzaReference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.saveMessage(
      Message(
        stanzaID: _messageStanzaId,
        originID: _messageOriginId,
        senderJid: _peerPinnerJid,
        chatJid: _chatJid,
        timestamp: pinnedAt,
        body: 'hello',
      ),
    );
    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: originReference,
      pinnerJid: _selfPinnerJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.deletePinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageOriginId,
    );

    await database.normalizePinnedMessageAliases(
      chatJid: _chatJid,
      canonicalMessageStanzaId: _messageStanzaId,
      aliases: const {_messageStanzaId, _messageOriginId},
    );

    final alias = await database.getMessagePin(
      chatJid: _chatJid,
      reference: originReference,
      pinnerJid: _selfPinnerJid,
    );
    final canonical = await database.getMessagePin(
      chatJid: _chatJid,
      reference: stanzaReference,
      pinnerJid: _selfPinnerJid,
    );
    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfPinnerJid: _selfPinnerJid,
    );

    expect(alias, isNull);
    expect(canonical?.active, isTrue);
    expect(aggregates, hasLength(1));
    expect(
      aggregates.single.messageReferenceKind,
      MessageReferenceKind.stanzaId,
    );
    expect(aggregates.single.messageReferenceId, _messageStanzaId);
  });

  test(
    'alias normalization preserves same-timestamp pin row unpin tombstones',
    () async {
      final timestamp = DateTime.utc(2026, 3, 9, 12, 0, 0);
      const originReference = MessageReference(
        kind: MessageReferenceKind.originId,
        value: _messageOriginId,
      );
      const stanzaReference = MessageReference(
        kind: MessageReferenceKind.stanzaId,
        value: _messageStanzaId,
      );

      await database.saveMessage(
        Message(
          stanzaID: _messageStanzaId,
          originID: _messageOriginId,
          senderJid: _peerPinnerJid,
          chatJid: _chatJid,
          timestamp: timestamp,
          body: 'hello',
        ),
      );
      await database.applyMessagePinMutation(
        chatJid: _chatJid,
        reference: stanzaReference,
        pinnerJid: _selfPinnerJid,
        pinnedAt: timestamp,
        active: true,
        identityVerified: true,
      );
      await database.applyMessagePinMutation(
        chatJid: _chatJid,
        reference: originReference,
        pinnerJid: _selfPinnerJid,
        pinnedAt: timestamp,
        active: false,
        identityVerified: true,
      );

      await database.normalizePinnedMessageAliases(
        chatJid: _chatJid,
        canonicalMessageStanzaId: _messageStanzaId,
        aliases: const {_messageStanzaId, _messageOriginId},
      );

      final alias = await database.getMessagePin(
        chatJid: _chatJid,
        reference: originReference,
        pinnerJid: _selfPinnerJid,
      );
      final canonical = await database.getMessagePin(
        chatJid: _chatJid,
        reference: stanzaReference,
        pinnerJid: _selfPinnerJid,
      );
      final aggregates = await database.getPinnedMessageAggregates(
        chatJid: _chatJid,
        selfPinnerJid: _selfPinnerJid,
      );

      expect(alias, isNull);
      expect(canonical?.active, isFalse);
      expect(canonical?.pinnedAt, timestamp);
      expect(aggregates, isEmpty);
    },
  );

  test('pin rows aggregate by message reference', () async {
    final selfPinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final peerPinnedAt = selfPinnedAt.add(const Duration(minutes: 5));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
      pinnedAt: selfPinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
      pinnedAt: peerPinnedAt,
      active: true,
      identityVerified: true,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfPinnerJid: _selfPinnerJid,
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

  test('clear all pins leaves a legacy tombstone', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final clearedAt = pinnedAt.add(const Duration(minutes: 5));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.clearMessagePins(
      chatJid: _chatJid,
      reference: reference,
      pinnedAt: clearedAt,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfPinnerJid: _selfPinnerJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );
    final selfPin = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
    );
    final peerPin = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
    );

    expect(aggregates, isEmpty);
    expect(legacy, isNotNull);
    expect(legacy!.active, isFalse);
    expect(legacy.pinnedAt, clearedAt);
    expect(selfPin?.active, isFalse);
    expect(peerPin?.active, isFalse);
  });

  test('clear all tombstone blocks older missing pins', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final clearedAt = pinnedAt.add(const Duration(minutes: 5));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.clearMessagePins(
      chatJid: _chatJid,
      reference: reference,
      pinnedAt: clearedAt,
    );
    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfPinnerJid: _selfPinnerJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );
    final peerPin = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
    );

    expect(aggregates, isEmpty);
    expect(legacy, isNotNull);
    expect(legacy!.active, isFalse);
    expect(legacy.pinnedAt, clearedAt);
    expect(peerPin, isNull);
  });

  test('clear all tombstone does not hide newer pins', () async {
    final olderPinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final clearedAt = olderPinnedAt.add(const Duration(minutes: 5));
    final newerPinnedAt = olderPinnedAt.add(const Duration(minutes: 10));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
      pinnedAt: newerPinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.clearMessagePins(
      chatJid: _chatJid,
      reference: reference,
      pinnedAt: clearedAt,
    );
    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
      pinnedAt: olderPinnedAt,
      active: true,
      identityVerified: true,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfPinnerJid: _selfPinnerJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );
    final selfPin = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
    );
    final peerPin = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
    );

    expect(aggregates, hasLength(1));
    expect(aggregates.single.pinCount, 1);
    expect(aggregates.single.pinnedBySelf, isFalse);
    expect(aggregates.single.pinnedAt, newerPinnedAt);
    expect(legacy, isNotNull);
    expect(legacy!.active, isTrue);
    expect(legacy.pinnedAt, newerPinnedAt);
    expect(selfPin, isNull);
    expect(peerPin?.active, isTrue);
  });

  test('own unpin does not become a clear-all tombstone', () async {
    final selfPinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    final peerPinnedAt = selfPinnedAt.add(const Duration(minutes: 2));
    final selfUnpinnedAt = selfPinnedAt.add(const Duration(minutes: 5));
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
      pinnedAt: selfPinnedAt,
      active: true,
      identityVerified: true,
    );
    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
      pinnedAt: selfUnpinnedAt,
      active: false,
      identityVerified: true,
    );
    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
      pinnedAt: peerPinnedAt,
      active: true,
      identityVerified: true,
    );

    final aggregates = await database.getPinnedMessageAggregates(
      chatJid: _chatJid,
      selfPinnerJid: _selfPinnerJid,
    );
    final legacy = await database.getPinnedMessage(
      chatJid: _chatJid,
      messageStanzaId: _messageStanzaId,
    );
    final selfPin = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
    );
    final peerPin = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
    );

    expect(aggregates, hasLength(1));
    expect(aggregates.single.pinCount, 1);
    expect(aggregates.single.pinnedBySelf, isFalse);
    expect(aggregates.single.pinnedAt, peerPinnedAt);
    expect(legacy, isNotNull);
    expect(legacy!.active, isTrue);
    expect(legacy.pinnedAt, peerPinnedAt);
    expect(selfPin?.active, isFalse);
    expect(peerPin?.active, isTrue);
  });

  test('deleting a message clears legacy and message pin references', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const reference = MessageReference(
      kind: MessageReferenceKind.mucStanzaId,
      value: _messageMucStanzaId,
    );

    await database.saveMessage(
      Message(
        stanzaID: _messageStanzaId,
        mucStanzaId: _messageMucStanzaId,
        senderJid: _peerPinnerJid,
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
    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
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
      await database.getMessagePin(
        chatJid: _chatJid,
        reference: reference,
        pinnerJid: _selfPinnerJid,
      ),
      isNull,
    );
  });

  test('clearing message history clears legacy and message pin rows', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );

    await database.clearMessageHistory();

    expect(await database.getPinnedMessages(_chatJid), isEmpty);
    expect(
      await database.getMessagePin(
        chatJid: _chatJid,
        reference: reference,
        pinnerJid: _selfPinnerJid,
      ),
      isNull,
    );
    expect(
      await database.getPinnedMessageAggregates(
        chatJid: _chatJid,
        selfPinnerJid: _selfPinnerJid,
      ),
      isEmpty,
    );
  });

  test(
    'trimming messages clears legacy and message MUC pin references',
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
          senderJid: _peerPinnerJid,
          chatJid: _chatJid,
          timestamp: oldPinnedAt,
          body: 'old',
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'new-message-id',
          mucStanzaId: 'new-muc-message-id',
          senderJid: _peerPinnerJid,
          chatJid: _chatJid,
          timestamp: newTimestamp,
          body: 'new',
        ),
      );
      await database.applyMessagePinMutation(
        chatJid: _chatJid,
        reference: reference,
        pinnerJid: _selfPinnerJid,
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
        await database.getMessagePin(
          chatJid: _chatJid,
          reference: reference,
          pinnerJid: _selfPinnerJid,
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
        senderJid: _peerPinnerJid,
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

    await database.copyLegacyPinnedMessagesToPinRows(pinnerJid: _selfPinnerJid);

    expect(
      await database.getMessagePin(
        chatJid: _chatJid,
        reference: reference,
        pinnerJid: _selfPinnerJid,
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

      await database.copyLegacyPinnedMessagesToPinRows(
        pinnerJid: _selfPinnerJid,
      );

      expect(
        await database.getMessagePin(
          chatJid: emailChatJid,
          reference: reference,
          pinnerJid: _selfPinnerJid,
        ),
        isNull,
      );
    },
  );

  test('legacy migration copies direct pins for peer messages', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.saveMessage(
      Message(
        stanzaID: _messageStanzaId,
        senderJid: _peerPinnerJid,
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

    await database.copyLegacyPinnedMessagesToPinRows(pinnerJid: _selfPinnerJid);

    final migrated = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
    );
    expect(migrated?.active, isTrue);
    expect(migrated?.pinnedAt, pinnedAt);
  });

  test('legacy migration skips pins that already have pinner rows', () async {
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: _messageStanzaId,
    );

    await database.applyMessagePinMutation(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _peerPinnerJid,
      pinnedAt: pinnedAt,
      active: true,
      identityVerified: true,
    );

    await database.copyLegacyPinnedMessagesToPinRows(pinnerJid: _selfPinnerJid);

    expect(
      await database.getMessagePin(
        chatJid: _chatJid,
        reference: reference,
        pinnerJid: _selfPinnerJid,
      ),
      isNull,
    );
    expect(
      await database.getMessagePin(
        chatJid: _chatJid,
        reference: reference,
        pinnerJid: _peerPinnerJid,
      ),
      isNotNull,
    );
  });

  test('legacy migration copies direct pins without local messages', () async {
    const missingMessageId = 'missing-direct-message-id';
    final pinnedAt = DateTime.utc(2026, 3, 9, 12, 0, 0);
    const reference = MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: missingMessageId,
    );

    await database.applyPinnedMessageMutation(
      chatJid: _chatJid,
      messageStanzaId: missingMessageId,
      pinnedAt: pinnedAt,
      active: true,
    );

    await database.copyLegacyPinnedMessagesToPinRows(pinnerJid: _selfPinnerJid);

    final migrated = await database.getMessagePin(
      chatJid: _chatJid,
      reference: reference,
      pinnerJid: _selfPinnerJid,
    );
    expect(migrated?.active, isTrue);
    expect(migrated?.pinnedAt, pinnedAt);
  });
}
