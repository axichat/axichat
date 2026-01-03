// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/storage/models.dart';

bool canMergeOriginMessages({
  required Message existing,
  required Message? duplicate,
}) {
  if (duplicate == null) return false;
  if (duplicate.stanzaID == existing.stanzaID) return false;
  if (duplicate.chatJid != existing.chatJid) return false;
  if (duplicate.deltaAccountId != existing.deltaAccountId) return false;
  return true;
}

Message mergeOriginMessages({
  required Message primary,
  required Message duplicate,
  required String originId,
}) {
  final resolvedBody = preferNonEmptyText(primary.body, duplicate.body);
  final resolvedHtml = preferNonEmptyText(primary.htmlBody, duplicate.htmlBody);
  final resolvedMetadata =
      preferNonEmptyText(primary.fileMetadataID, duplicate.fileMetadataID);
  final resolvedQuoting =
      preferNonEmptyText(primary.quoting, duplicate.quoting);
  final resolvedStickerPack =
      preferNonEmptyText(primary.stickerPackID, duplicate.stickerPackID);
  final fallbackTimestamp = DateTime.timestamp();
  final resolvedTimestamp =
      primary.timestamp ?? duplicate.timestamp ?? fallbackTimestamp;
  final resolvedError =
      primary.error != MessageError.none ? primary.error : duplicate.error;
  final resolvedWarning = primary.warning != MessageWarning.none
      ? primary.warning
      : duplicate.warning;
  final resolvedEncryption =
      primary.encryptionProtocol != EncryptionProtocol.none
          ? primary.encryptionProtocol
          : duplicate.encryptionProtocol;
  final resolvedTrust = primary.trust ?? duplicate.trust;
  final resolvedTrusted = primary.trusted ?? duplicate.trusted;
  final resolvedDeviceId = primary.deviceID ?? duplicate.deviceID;
  final resolvedPseudoType =
      primary.pseudoMessageType ?? duplicate.pseudoMessageType;
  final resolvedPseudoData =
      primary.pseudoMessageData ?? duplicate.pseudoMessageData;
  final resolvedReactions = primary.reactionsPreview.isNotEmpty
      ? primary.reactionsPreview
      : duplicate.reactionsPreview;
  final resolvedDeltaChatId = primary.deltaChatId ?? duplicate.deltaChatId;
  final resolvedDeltaMsgId = primary.deltaMsgId ?? duplicate.deltaMsgId;
  return primary.copyWith(
    timestamp: resolvedTimestamp,
    originID: originId,
    body: resolvedBody,
    htmlBody: resolvedHtml,
    error: resolvedError,
    warning: resolvedWarning,
    encryptionProtocol: resolvedEncryption,
    trust: resolvedTrust,
    trusted: resolvedTrusted,
    deviceID: resolvedDeviceId,
    noStore: primary.noStore || duplicate.noStore,
    acked: primary.acked || duplicate.acked,
    received: primary.received || duplicate.received,
    displayed: primary.displayed || duplicate.displayed,
    edited: primary.edited || duplicate.edited,
    retracted: primary.retracted || duplicate.retracted,
    isFileUploadNotification:
        primary.isFileUploadNotification || duplicate.isFileUploadNotification,
    fileDownloading: primary.fileDownloading || duplicate.fileDownloading,
    fileUploading: primary.fileUploading || duplicate.fileUploading,
    fileMetadataID: resolvedMetadata,
    quoting: resolvedQuoting,
    stickerPackID: resolvedStickerPack,
    pseudoMessageType: resolvedPseudoType,
    pseudoMessageData: resolvedPseudoData,
    reactionsPreview: resolvedReactions,
    deltaChatId: resolvedDeltaChatId,
    deltaMsgId: resolvedDeltaMsgId,
  );
}

Message resolveOriginMergePrimary({
  required Message existing,
  required Message duplicate,
  required String? selfJid,
}) {
  final String normalizedSelf = selfJid?.trim().toLowerCase() ?? '';
  final String existingSender = existing.senderJid.trim();
  final String duplicateSender = duplicate.senderJid.trim();
  final String normalizedExisting = existingSender.toLowerCase();
  final String normalizedDuplicate = duplicateSender.toLowerCase();
  final bool existingIsPlaceholder = normalizedExisting.isDeltaPlaceholderJid;
  final bool duplicateIsPlaceholder = normalizedDuplicate.isDeltaPlaceholderJid;
  final bool existingIsSelf = _isSelfSender(
    normalizedSender: normalizedExisting,
    isPlaceholder: existingIsPlaceholder,
    normalizedSelf: normalizedSelf,
  );
  final bool duplicateIsSelf = _isSelfSender(
    normalizedSender: normalizedDuplicate,
    isPlaceholder: duplicateIsPlaceholder,
    normalizedSelf: normalizedSelf,
  );
  if (existingIsSelf != duplicateIsSelf) {
    return existingIsSelf ? existing : duplicate;
  }
  if (existingIsSelf &&
      duplicateIsSelf &&
      existingIsPlaceholder != duplicateIsPlaceholder) {
    return existingIsPlaceholder ? duplicate : existing;
  }
  return existing;
}

String? preferNonEmptyText(String? primary, String? fallback) {
  final trimmedPrimary = primary?.trim();
  if (trimmedPrimary != null && trimmedPrimary.isNotEmpty) {
    return primary;
  }
  final trimmedFallback = fallback?.trim();
  if (trimmedFallback != null && trimmedFallback.isNotEmpty) {
    return fallback;
  }
  return primary ?? fallback;
}

bool _isSelfSender({
  required String normalizedSender,
  required bool isPlaceholder,
  required String normalizedSelf,
}) {
  if (normalizedSender.isEmpty) {
    return false;
  }
  if (isPlaceholder) {
    return true;
  }
  if (normalizedSelf.isEmpty) {
    return false;
  }
  return normalizedSender == normalizedSelf;
}
