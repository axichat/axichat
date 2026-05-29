// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:drift/drift.dart';

import 'package:axichat/src/storage/models/message_models.dart';

@DataClassName('PinnedMessageEntry')
class PinnedMessages extends Table {
  TextColumn get messageStanzaId => text()();

  TextColumn get chatJid => text()();

  DateTimeColumn get pinnedAt => dateTime()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>>? get primaryKey => {messageStanzaId, chatJid};

  List<Index> get indexes => [
    Index('idx_pinned_messages_chat', 'chat_jid, pinned_at'),
    Index('idx_pinned_messages_message', 'message_stanza_id'),
  ];
}

@DataClassName('PinEntry')
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

  List<Index> get indexes => [
    Index(
      'idx_message_pins_chat',
      'chat_jid, message_reference_kind, message_reference_id, active',
    ),
    Index('idx_message_pins_pinner', 'pinner_jid, chat_jid, active'),
  ];
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
