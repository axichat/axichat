// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:drift/drift.dart';

enum SystemMessageCollection {
  important;

  String get id => switch (this) {
    SystemMessageCollection.important => 'important',
  };
}

@DataClassName('MessageCollectionEntry')
class MessageCollections extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().nullable()();

  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DataClassName('MessageCollectionMembershipEntry')
class MessageCollectionMemberships extends Table {
  TextColumn get collectionId => text()();

  TextColumn get chatJid => text()();

  TextColumn get messageReferenceId => text()();

  TextColumn get messageStanzaId => text().nullable()();

  TextColumn get messageOriginId => text().nullable()();

  TextColumn get messageMucStanzaId => text().nullable()();

  IntColumn get deltaAccountId => integer().nullable()();

  IntColumn get deltaMsgId => integer().nullable()();

  DateTimeColumn get addedAt => dateTime()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>>? get primaryKey => {
    collectionId,
    chatJid,
    messageReferenceId,
  };

  List<Index> get indexes => [
    Index(
      'idx_message_collection_memberships_chat_added',
      'collection_id, chat_jid, added_at',
    ),
    Index(
      'idx_message_collection_memberships_collection_added',
      'collection_id, added_at',
    ),
    Index(
      'idx_message_collection_memberships_stanza',
      'collection_id, chat_jid, message_stanza_id',
    ),
    Index(
      'idx_message_collection_memberships_origin',
      'collection_id, chat_jid, message_origin_id',
    ),
    Index(
      'idx_message_collection_memberships_muc',
      'collection_id, chat_jid, message_muc_stanza_id',
    ),
    Index(
      'idx_message_collection_memberships_delta',
      'collection_id, chat_jid, delta_account_id, delta_msg_id',
    ),
  ];
}
