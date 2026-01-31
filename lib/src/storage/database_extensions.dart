// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models/file_models.dart';
import 'package:drift/drift.dart';

extension AttachmentGalleryQueries on XmppDrift {
  Stream<List<AttachmentGalleryItem>> watchAttachmentGallery({
    String? chatJid,
    bool includeChat = true,
  }) {
    final trimmedJid = chatJid?.trim();
    final messagesTable = messages;
    final messageAttachmentsTable = messageAttachments;
    final fileMetadataTable = fileMetadata;
    final chatsTable = chats;
    final joins = <Join>[
      leftOuterJoin(
        messageAttachmentsTable,
        messageAttachmentsTable.messageId.equalsExp(messagesTable.id),
      ),
      innerJoin(
        fileMetadataTable,
        fileMetadataTable.id.equalsExp(
              messageAttachmentsTable.fileMetadataId,
            ) |
            (messageAttachmentsTable.id.isNull() &
                fileMetadataTable.id.equalsExp(messagesTable.fileMetadataID)),
      ),
    ];
    if (includeChat) {
      joins.add(
        leftOuterJoin(
          chatsTable,
          chatsTable.jid.equalsExp(messagesTable.chatJid),
        ),
      );
    }
    final attachmentQuery = select(messagesTable).join(joins);
    attachmentQuery.where(messagesTable.retracted.equals(false));
    if (trimmedJid != null && trimmedJid.isNotEmpty) {
      attachmentQuery.where(messagesTable.chatJid.equals(trimmedJid));
    }
    return attachmentQuery.watch().map((rows) {
      final items = rows
          .map(
            (row) => AttachmentGalleryItem(
              message: row.readTable(messagesTable),
              metadata: row.readTable(fileMetadataTable),
              chat: includeChat ? row.readTableOrNull(chatsTable) : null,
            ),
          )
          .toList(growable: false);
      return List.unmodifiable(items);
    });
  }
}
