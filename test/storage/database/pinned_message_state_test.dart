import 'dart:io';

import 'package:axichat/src/storage/database.dart';
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
}
