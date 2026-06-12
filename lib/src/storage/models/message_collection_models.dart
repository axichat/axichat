// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';

enum SystemMessageCollection {
  important,
  receipts,
  marketing,
  newsletters;

  String get id => switch (this) {
    SystemMessageCollection.important => 'important',
    SystemMessageCollection.receipts => 'receipts',
    SystemMessageCollection.marketing => 'marketing',
    SystemMessageCollection.newsletters => 'newsletters',
  };

  int get sortOrder => switch (this) {
    SystemMessageCollection.important => 0,
    SystemMessageCollection.receipts => 1,
    SystemMessageCollection.marketing => 2,
    SystemMessageCollection.newsletters => 3,
  };

  String label(AppLocalizations l10n) => switch (this) {
    SystemMessageCollection.important => l10n.homeTabImportant,
    SystemMessageCollection.receipts => l10n.folderSystemReceipts,
    SystemMessageCollection.marketing => l10n.folderSystemMarketing,
    SystemMessageCollection.newsletters => l10n.folderSystemNewsletters,
  };

  static SystemMessageCollection? fromId(String id) {
    final normalized = id.trim().toLowerCase();
    for (final collection in values) {
      if (collection.id == normalized) {
        return collection;
      }
    }
    return null;
  }

  static bool isSystemId(String id) {
    return fromId(id) != null;
  }
}

enum MessageCollectionNameFailure {
  empty,
  reserved,
  duplicate,
  tooLong;

  String label(AppLocalizations l10n) => switch (this) {
    MessageCollectionNameFailure.empty => l10n.folderNameEmptyError,
    MessageCollectionNameFailure.reserved => l10n.folderNameReservedError,
    MessageCollectionNameFailure.duplicate => l10n.folderNameDuplicateError,
    MessageCollectionNameFailure.tooLong => l10n.folderNameTooLongError,
  };
}

final class MessageCollectionNameException implements Exception {
  const MessageCollectionNameException(this.failure);

  final MessageCollectionNameFailure failure;
}

String? normalizeCustomMessageCollectionTitle(String title) {
  final normalized = title.trim();
  if (normalized.isEmpty) {
    return null;
  }
  if (!isWithinUtf8ByteLimit(normalized, maxBytes: 128)) {
    throw const MessageCollectionNameException(
      MessageCollectionNameFailure.tooLong,
    );
  }
  return normalized;
}

String? normalizeCustomMessageCollectionId(String title) {
  return normalizeCustomMessageCollectionTitle(title);
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
}

class FolderMessageItem extends Equatable {
  const FolderMessageItem({
    required this.collectionId,
    required this.chatJid,
    required this.messageReferenceId,
    required this.addedAt,
    required this.active,
    required this.message,
    required this.chat,
    this.isContactRuleDerived = false,
    this.messageStanzaId,
    this.messageOriginId,
    this.messageMucStanzaId,
    this.deltaAccountId,
    this.deltaMsgId,
  });

  final String collectionId;
  final String chatJid;
  final String messageReferenceId;
  final String? messageStanzaId;
  final String? messageOriginId;
  final String? messageMucStanzaId;
  final int? deltaAccountId;
  final int? deltaMsgId;
  final DateTime addedAt;
  final bool active;
  final Message? message;
  final Chat? chat;
  final bool isContactRuleDerived;

  DateTime get markedAt => addedAt;

  bool get hasMessage => message != null;

  @override
  List<Object?> get props => [
    collectionId,
    chatJid,
    messageReferenceId,
    messageStanzaId,
    messageOriginId,
    messageMucStanzaId,
    deltaAccountId,
    deltaMsgId,
    addedAt,
    active,
    message,
    chat,
    isContactRuleDerived,
  ];
}
