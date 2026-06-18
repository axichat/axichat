// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:drift/drift.dart';

import 'package:axichat/src/storage/models/message_models.dart';

@DataClassName('PinnedMessageEntry')
@TableIndex(
  name: 'idx_pinned_messages_chat_pinned',
  columns: {#chatJid, #active, #pinnedAt, #messageStanzaId},
)
class PinnedMessages extends Table {
  TextColumn get messageStanzaId => text()();

  TextColumn get chatJid => text()();

  DateTimeColumn get pinnedAt => dateTime()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>>? get primaryKey => {messageStanzaId, chatJid};
}

@DataClassName('PinEntry')
@TableIndex(
  name: 'idx_message_pins_chat_reference',
  columns: {#chatJid, #messageReferenceKind, #messageReferenceId},
)
@TableIndex(
  name: 'idx_message_pins_chat_active_pinned',
  columns: {#chatJid, #active, #pinnedAt, #messageReferenceId},
)
class MessagePins extends Table {
  TextColumn get chatJid => text()();

  IntColumn get messageReferenceKind => integer()();

  TextColumn get messageReferenceId => text()();

  TextColumn get pinnerJid => text()();

  DateTimeColumn get pinnedAt => dateTime()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  BoolColumn get identityVerified =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>>? get primaryKey => {
    chatJid,
    messageReferenceKind,
    messageReferenceId,
    pinnerJid,
  };
}

final class PinnedMessageAggregate {
  const PinnedMessageAggregate({
    required this.chatJid,
    required this.messageReferenceKind,
    required this.messageReferenceId,
    required this.pinnedAt,
    required this.pinCount,
    required this.pinnedBySelf,
  });

  final String chatJid;
  final MessageReferenceKind messageReferenceKind;
  final String messageReferenceId;
  final DateTime pinnedAt;
  final int pinCount;
  final bool pinnedBySelf;
}
