import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const String _chatJid = 'chat@axi.im';
const String _messageStanzaId = 'message-id';
const String _messageOriginId = 'origin-id';
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

  test(
    'older collection mutations do not override a newer inactive tombstone',
    () async {
      final initialAddedAt = DateTime.utc(2026, 3, 11, 12, 0, 0);
      final removedAt = initialAddedAt.add(const Duration(minutes: 5));

      await database.applyMessageCollectionMembershipMutation(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: _messageStanzaId,
        messageStanzaId: _messageStanzaId,
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: initialAddedAt,
        active: true,
      );
      await database.applyMessageCollectionMembershipMutation(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: _messageStanzaId,
        messageStanzaId: _messageStanzaId,
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: removedAt,
        active: false,
      );
      await database.applyMessageCollectionMembershipMutation(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: _messageStanzaId,
        messageStanzaId: _messageStanzaId,
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: initialAddedAt,
        active: true,
      );

      final visible = await database.getMessageCollectionMemberships(
        SystemMessageCollection.important.id,
        chatJid: _chatJid,
      );
      final stored = await database.getMessageCollectionMembership(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: _messageStanzaId,
      );

      expect(visible, isEmpty);
      expect(stored, isNotNull);
      expect(stored!.active, isFalse);
      expect(stored.addedAt, removedAt);
    },
  );

  test(
    'alias normalization collapses collection memberships onto the canonical id',
    () async {
      final addedAt = DateTime.utc(2026, 3, 11, 12, 0, 0);
      final removedAt = addedAt.add(const Duration(minutes: 5));

      await database.applyMessageCollectionMembershipMutation(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: _messageStanzaId,
        messageStanzaId: _messageStanzaId,
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: addedAt,
        active: true,
      );
      await database.applyMessageCollectionMembershipMutation(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: _messageOriginId,
        messageStanzaId: _messageStanzaId,
        messageOriginId: _messageOriginId,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: removedAt,
        active: false,
      );

      await database.normalizeMessageCollectionMembershipAliases(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        canonicalMessageReferenceId: _messageStanzaId,
        aliases: const {_messageStanzaId, _messageOriginId},
        messageStanzaId: _messageStanzaId,
        messageOriginId: _messageOriginId,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
      );

      final visible = await database.getMessageCollectionMemberships(
        SystemMessageCollection.important.id,
        chatJid: _chatJid,
      );
      final canonical = await database.getMessageCollectionMembership(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: _messageStanzaId,
      );
      final alias = await database.getMessageCollectionMembership(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: _messageOriginId,
      );

      expect(visible, isEmpty);
      expect(canonical, isNotNull);
      expect(canonical!.active, isFalse);
      expect(canonical.addedAt, removedAt);
      expect(canonical.messageOriginId, _messageOriginId);
      expect(alias, isNull);
    },
  );

  test(
    'important search falls back to Delta ids for email-backed messages',
    () async {
      const deltaAccountId = 7;
      const deltaMsgId = 42;
      final emailMessage = Message(
        stanzaID: 'email-stanza',
        senderJid: _chatJid,
        chatJid: _chatJid,
        body: 'Important email note',
        timestamp: DateTime.utc(2026, 3, 11, 14, 0, 0),
        deltaAccountId: deltaAccountId,
        deltaMsgId: deltaMsgId,
      );
      final otherMessage = Message(
        stanzaID: 'other-stanza',
        senderJid: _chatJid,
        chatJid: _chatJid,
        body: 'Important email note',
        timestamp: DateTime.utc(2026, 3, 11, 14, 5, 0),
      );

      await database.saveMessage(emailMessage);
      await database.saveMessage(otherMessage);
      await database.applyMessageCollectionMembershipMutation(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: 'email-local-fallback',
        messageStanzaId: null,
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: deltaAccountId,
        deltaMsgId: deltaMsgId,
        addedAt: DateTime.utc(2026, 3, 11, 14, 10, 0),
        active: true,
      );

      final importantResults = await database.searchChatMessages(
        jid: _chatJid,
        query: 'Important email',
        filter: MessageTimelineFilter.directOnly,
        collectionId: SystemMessageCollection.important.id,
      );
      final allResults = await database.searchChatMessages(
        jid: _chatJid,
        query: 'Important email',
        filter: MessageTimelineFilter.directOnly,
      );

      expect(allResults, hasLength(2));
      expect(importantResults, hasLength(1));
      expect(importantResults.single.deltaMsgId, deltaMsgId);
    },
  );

  test(
    'important-only search returns collection entries without a text query',
    () async {
      const importantStanzaId = 'important-only-message';
      final importantMessage = Message(
        stanzaID: importantStanzaId,
        senderJid: _chatJid,
        chatJid: _chatJid,
        body: 'Saved for later',
        timestamp: DateTime.utc(2026, 3, 11, 15, 0, 0),
      );
      final otherMessage = Message(
        stanzaID: 'non-important-message',
        senderJid: _chatJid,
        chatJid: _chatJid,
        body: 'Not saved',
        timestamp: DateTime.utc(2026, 3, 11, 15, 5, 0),
      );

      await database.saveMessage(importantMessage);
      await database.saveMessage(otherMessage);
      await database.applyMessageCollectionMembershipMutation(
        collectionId: SystemMessageCollection.important.id,
        chatJid: _chatJid,
        messageReferenceId: importantStanzaId,
        messageStanzaId: importantStanzaId,
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: DateTime.utc(2026, 3, 11, 15, 10, 0),
        active: true,
      );

      final results = await database.searchChatMessages(
        jid: _chatJid,
        filter: MessageTimelineFilter.directOnly,
        collectionId: SystemMessageCollection.important.id,
      );

      expect(results, hasLength(1));
      expect(results.single.stanzaID, importantStanzaId);
    },
  );
}
