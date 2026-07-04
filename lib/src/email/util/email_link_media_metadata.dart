// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/message_links.dart';
import 'package:axichat/src/email/util/email_header_safety.dart'
    as email_headers;
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';

Future<Message> syncEmailLinkMediaMetadataFromText({
  required XmppDatabase db,
  required Message message,
  required int deltaId,
  required String? text,
}) async {
  final existingMetadataId = message.fileMetadataID?.trim();
  if (existingMetadataId != null &&
      existingMetadataId.isNotEmpty &&
      !isLinkMediaFileMetadata(existingMetadataId)) {
    return message;
  }
  if (message.pseudoMessageType != null || deltaId <= DeltaMessageId.none) {
    return _clearEmailLinkMediaMetadata(db: db, message: message);
  }
  final metadata = _emailLinkMediaMetadataFromText(text, deltaId);
  if (metadata == null) {
    return _clearEmailLinkMediaMetadata(db: db, message: message);
  }
  if (existingMetadataId != null &&
      existingMetadataId.isNotEmpty &&
      existingMetadataId != metadata.id) {
    await db.clearMessageAttachment(message.stanzaID);
  }
  if (await _emailLinkMediaSourceUrlChanged(db: db, metadata: metadata)) {
    await db.clearMessageAttachment(message.stanzaID);
    await db.deleteFileMetadata(metadata.id);
  }
  await _saveEmailLinkMediaMetadataIfChanged(db: db, metadata: metadata);
  return message.copyWith(fileMetadataID: metadata.id);
}

FileMetadataData? _emailLinkMediaMetadataFromText(String? text, int deltaId) {
  final media = firstMediaLinkInText(text);
  if (media == null) return null;
  return FileMetadataData(
    id: emailLinkMediaFileMetadataId(deltaId),
    sourceUrls: [media.url],
    filename: email_headers.sanitizeEmailAttachmentFilename(media.filename),
    mimeType: email_headers.sanitizeEmailMimeType(media.mimeType),
  );
}

Future<void> _saveEmailLinkMediaMetadataIfChanged({
  required XmppDatabase db,
  required FileMetadataData metadata,
}) async {
  final existing = await db.getFileMetadata(metadata.id);
  if (existing?.sourceUrls?.firstOrNull == metadata.sourceUrls?.firstOrNull) {
    return;
  }
  await db.saveFileMetadata(metadata);
}

Future<bool> _emailLinkMediaSourceUrlChanged({
  required XmppDatabase db,
  required FileMetadataData metadata,
}) async {
  final existing = await db.getFileMetadata(metadata.id);
  return existing != null &&
      existing.sourceUrls?.firstOrNull != metadata.sourceUrls?.firstOrNull;
}

Future<Message> _clearEmailLinkMediaMetadata({
  required XmppDatabase db,
  required Message message,
}) async {
  if (!isLinkMediaFileMetadata(message.fileMetadataID)) return message;
  await db.clearMessageAttachment(message.stanzaID);
  return message.copyWith(fileMetadataID: null);
}

String emailLinkMediaFileMetadataId(int deltaId) =>
    linkMediaFileMetadataId('email-msg-$deltaId');
