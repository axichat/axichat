// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:drift/drift.dart';

const String _pinnedMessagesChatIndexName = 'idx_pinned_messages_chat';
const String _pinnedMessagesChatIndexColumns = 'chat_jid, pinned_at';
const String _pinnedMessagesMessageIndexName = 'idx_pinned_messages_message';
const String _pinnedMessagesMessageIndexColumns = 'message_stanza_id';

@DataClassName('PinnedMessageEntry')
class PinnedMessages extends Table {
  TextColumn get messageStanzaId => text()();

  TextColumn get chatJid => text()();

  DateTimeColumn get pinnedAt => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {messageStanzaId, chatJid};

  List<Index> get indexes => [
        Index(_pinnedMessagesChatIndexName, _pinnedMessagesChatIndexColumns),
        Index(
          _pinnedMessagesMessageIndexName,
          _pinnedMessagesMessageIndexColumns,
        ),
      ];
}
