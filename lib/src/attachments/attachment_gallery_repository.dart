// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/drift.dart';

const bool _attachmentGalleryExcludeRetracted = false;
const int _attachmentGalleryFallbackEpochMs = 0;
final DateTime _attachmentGalleryFallbackTimestamp =
    DateTime.fromMillisecondsSinceEpoch(_attachmentGalleryFallbackEpochMs);

class AttachmentGalleryItem {
  const AttachmentGalleryItem({
    required this.message,
    required this.metadata,
  });

  final Message message;
  final FileMetadataData metadata;
}

final class AttachmentGalleryRepository {
  AttachmentGalleryRepository(this._database);

  final XmppDrift _database;

  Stream<List<AttachmentGalleryItem>> watch({
    String? chatJid,
  }) {
    final messages = _database.messages;
    final messageAttachments = _database.messageAttachments;
    final fileMetadata = _database.fileMetadata;
    final attachmentQuery = _database.select(messageAttachments).join([
      innerJoin(messages, messages.id.equalsExp(messageAttachments.messageId)),
      innerJoin(
        fileMetadata,
        fileMetadata.id.equalsExp(messageAttachments.fileMetadataId),
      ),
    ]);
    attachmentQuery.where(
      messages.retracted.equals(_attachmentGalleryExcludeRetracted),
    );
    if (chatJid != null && chatJid.trim().isNotEmpty) {
      attachmentQuery.where(messages.chatJid.equals(chatJid));
    }
    final fallbackQuery = _database.select(messages).join([
      innerJoin(
        fileMetadata,
        fileMetadata.id.equalsExp(messages.fileMetadataID),
      ),
      leftOuterJoin(
        messageAttachments,
        messageAttachments.messageId.equalsExp(messages.id),
      ),
    ]);
    fallbackQuery.where(
      messageAttachments.id.isNull() &
          messages.retracted.equals(_attachmentGalleryExcludeRetracted),
    );
    if (chatJid != null && chatJid.trim().isNotEmpty) {
      fallbackQuery.where(messages.chatJid.equals(chatJid));
    }
    return Stream.multi((multi) {
      var attachmentItems = const <AttachmentGalleryItem>[];
      var fallbackItems = const <AttachmentGalleryItem>[];
      void emit() {
        final combined = <AttachmentGalleryItem>[
          ...attachmentItems,
          ...fallbackItems,
        ];
        combined.sort(_compareByTimestamp);
        multi.add(List.unmodifiable(combined));
      }

      final attachmentSubscription = attachmentQuery.watch().listen(
        (rows) {
          attachmentItems = _mapItems(
            rows: rows,
            messages: messages,
            fileMetadata: fileMetadata,
          );
          emit();
        },
        onError: multi.addError,
      );
      final fallbackSubscription = fallbackQuery.watch().listen(
        (rows) {
          fallbackItems = _mapItems(
            rows: rows,
            messages: messages,
            fileMetadata: fileMetadata,
          );
          emit();
        },
        onError: multi.addError,
      );
      multi.onCancel = () {
        unawaited(attachmentSubscription.cancel());
        unawaited(fallbackSubscription.cancel());
      };
    });
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

int _compareByTimestamp(AttachmentGalleryItem a, AttachmentGalleryItem b) {
  final aTimestamp = a.message.timestamp ?? _attachmentGalleryFallbackTimestamp;
  final bTimestamp = b.message.timestamp ?? _attachmentGalleryFallbackTimestamp;
  return bTimestamp.compareTo(aTimestamp);
}
