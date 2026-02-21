// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:drift/drift.dart';

@DataClassName('PinnedMessageEntry')
class PinnedMessages extends Table {
  TextColumn get messageStanzaId => text()();

  TextColumn get chatJid => text()();

  DateTimeColumn get pinnedAt => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {messageStanzaId, chatJid};

  List<Index> get indexes => [
    Index('idx_pinned_messages_chat', 'chat_jid, pinned_at'),
    Index('idx_pinned_messages_message', 'message_stanza_id'),
  ];
}
