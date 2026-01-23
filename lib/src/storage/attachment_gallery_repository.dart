// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/drift.dart';

class AttachmentGalleryItem {
  const AttachmentGalleryItem({required this.message, required this.metadata});

  final Message message;
  final FileMetadataData metadata;
}

final class AttachmentGalleryRepository {
  AttachmentGalleryRepository(this._database);

  final XmppDrift _database;

  Stream<List<AttachmentGalleryItem>> watch({String? chatJid}) {
    const excludeRetracted = false;
    final messages = _database.messages;
    final messageAttachments = _database.messageAttachments;
    final fileMetadata = _database.fileMetadata;
    final attachmentQuery = _database.select(messages).join([
      leftOuterJoin(
        messageAttachments,
        messageAttachments.messageId.equalsExp(messages.id),
      ),
      innerJoin(
        fileMetadata,
        fileMetadata.id.equalsExp(messageAttachments.fileMetadataId) |
            (messageAttachments.id.isNull() &
                fileMetadata.id.equalsExp(messages.fileMetadataID)),
      ),
    ]);
    attachmentQuery.where(messages.retracted.equals(excludeRetracted));
    if (chatJid != null && chatJid.trim().isNotEmpty) {
      attachmentQuery.where(messages.chatJid.equals(chatJid));
    }
    return attachmentQuery.watch().map(
          (rows) => List.unmodifiable(
            _mapItems(
              rows: rows,
              messages: messages,
              fileMetadata: fileMetadata,
            ),
          ),
        );
  }
}

List<AttachmentGalleryItem> _mapItems({
  required List<TypedResult> rows,
  required ResultSetImplementation<HasResultSet, Message> messages,
  required ResultSetImplementation<HasResultSet, FileMetadataData> fileMetadata,
}) {
  return rows
      .map(
        (row) => AttachmentGalleryItem(
          message: row.readTable(messages),
          metadata: row.readTable(fileMetadata),
        ),
      )
      .toList(growable: false);
}
