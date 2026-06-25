// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/util/async_queue.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart'
    as email_headers;
import 'package:axichat/src/email/util/email_message_ids.dart';
import 'package:axichat/src/email/util/synthetic_forward_html.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

const int _deltaChatLastSpecialId = DeltaChatId.lastSpecial;
const int _deltaMessageIdUnset = DeltaMessageId.none;
const int _deltaChatlistArchivedOnlyFlag = DeltaChatlistFlags.archivedOnly;
const String _emptyJid = '';
const int _attachmentSizeUnitBase = 1024;

final class DeltaHydrationResult {
  const DeltaHydrationResult({
    required this.message,
    required this.repairedUnread,
    required this.unreadStateResolved,
    required this.affectsUserChat,
    required this.changedLocalProjection,
    this.chatJid,
    this.saveResult,
  });

  final DeltaMessage message;
  final bool repairedUnread;
  final bool unreadStateResolved;
  final bool affectsUserChat;
  final bool changedLocalProjection;
  final String? chatJid;
  final MessageSaveResult? saveResult;
}

final class _DeltaStatusHydrationResult {
  const _DeltaStatusHydrationResult({
    required this.status,
    required this.repairedUnread,
    required this.unreadStateResolved,
    this.updatedFields = const <MessageDiffField>[],
  });

  final DeltaMessageStatus status;
  final bool repairedUnread;
  final bool unreadStateResolved;
  final List<MessageDiffField> updatedFields;
}

final class _DeltaIngestOutcome {
  const _DeltaIngestOutcome({
    required this.repairedUnread,
    required this.unreadStateResolved,
    required this.ignoredFreshProjection,
    required this.affectsUserChat,
    required this.changedLocalProjection,
    this.chatJid,
    this.saveResult,
  });

  final bool repairedUnread;
  final bool unreadStateResolved;
  final bool ignoredFreshProjection;
  final bool affectsUserChat;
  final bool changedLocalProjection;
  final String? chatJid;
  final MessageSaveResult? saveResult;
}

final class _DeltaContentTiming {
  int inlineProjectionMs = 0;
  int rfc822FetchMs = 0;
  int rfc822VisibleHtmlMs = 0;
  int forwardedMetadataMs = 0;
  int shareMetadataMs = 0;
  int attachmentMetadataMs = 0;

  Map<String, Object?> toTraceFields() => <String, Object?>{
    if (inlineProjectionMs > 0) 'contentInlineMs': inlineProjectionMs,
    if (rfc822FetchMs > 0) 'contentRfc822FetchMs': rfc822FetchMs,
    if (rfc822VisibleHtmlMs > 0)
      'contentRfc822VisibleHtmlMs': rfc822VisibleHtmlMs,
    if (forwardedMetadataMs > 0) 'contentForwardedMs': forwardedMetadataMs,
    if (shareMetadataMs > 0) 'contentShareMs': shareMetadataMs,
    if (attachmentMetadataMs > 0) 'contentAttachmentMs': attachmentMetadataMs,
  };
}

final class _DeltaIngestTiming {
  final _DeltaContentTiming content = _DeltaContentTiming();
  int systemChatMs = 0;
  int ensureChatMs = 0;
  int hiddenSyncCheckMs = 0;
  int databaseMs = 0;
  int encryptionStatusMarkerMs = 0;
  int locatorRecoveryMs = 0;
  int locatorRehomeMs = 0;
  int existingDiagnosticMs = 0;
  int existingUpdateMs = 0;
  int existingAutocryptMs = 0;
  int originIdMs = 0;
  int blocklistMs = 0;
  int spamCheckMs = 0;
  int contentMs = 0;
  int quoteMs = 0;
  int newDiagnosticMs = 0;
  int storeMs = 0;
  int encryptionMarkerMs = 0;
  int autocryptMs = 0;
  int downloadGateMs = 0;

  Map<String, Object?> toTraceFields() => <String, Object?>{
    if (systemChatMs > 0) 'systemChatMs': systemChatMs,
    if (ensureChatMs > 0) 'ensureChatMs': ensureChatMs,
    if (hiddenSyncCheckMs > 0) 'hiddenSyncCheckMs': hiddenSyncCheckMs,
    if (databaseMs > 0) 'databaseMs': databaseMs,
    if (encryptionStatusMarkerMs > 0)
      'encryptionStatusMarkerMs': encryptionStatusMarkerMs,
    if (locatorRecoveryMs > 0) 'locatorRecoveryMs': locatorRecoveryMs,
    if (locatorRehomeMs > 0) 'locatorRehomeMs': locatorRehomeMs,
    if (existingDiagnosticMs > 0) 'existingDiagnosticMs': existingDiagnosticMs,
    if (existingUpdateMs > 0) 'existingUpdateMs': existingUpdateMs,
    if (existingAutocryptMs > 0) 'existingAutocryptMs': existingAutocryptMs,
    if (originIdMs > 0) 'originIdMs': originIdMs,
    if (blocklistMs > 0) 'blocklistMs': blocklistMs,
    if (spamCheckMs > 0) 'spamCheckMs': spamCheckMs,
    if (contentMs > 0) 'contentMs': contentMs,
    if (quoteMs > 0) 'quoteMs': quoteMs,
    if (newDiagnosticMs > 0) 'newDiagnosticMs': newDiagnosticMs,
    if (storeMs > 0) 'storeMs': storeMs,
    if (encryptionMarkerMs > 0) 'encryptionMarkerMs': encryptionMarkerMs,
    if (autocryptMs > 0) 'autocryptMs': autocryptMs,
    if (downloadGateMs > 0) 'downloadGateMs': downloadGateMs,
    ...content.toTraceFields(),
  };
}

final class DeltaFreshSyncResult {
  const DeltaFreshSyncResult({
    this.freshIdCount = 0,
    this.storedExactCount = 0,
    this.storedMissingContentCount = 0,
    this.hydratedCount = 0,
    this.affectedChatCount = 0,
    this.cancelled = false,
  });

  final int freshIdCount;
  final int storedExactCount;
  final int storedMissingContentCount;
  final int hydratedCount;
  final int affectedChatCount;
  final bool cancelled;

  bool get hadFreshIds => freshIdCount > 0;

  bool get projectedLocalState => affectedChatCount > 0 || hydratedCount > 0;
}

enum MessageDiffField {
  stanzaId,
  senderJid,
  chatJid,
  timestamp,
  id,
  originId,
  occupantId,
  body,
  htmlBody,
  subject,
  error,
  warning,
  encryptionProtocol,
  trust,
  trusted,
  deviceId,
  noStore,
  acked,
  received,
  displayed,
  deltaSeenSynced,
  edited,
  retracted,
  isFileUploadNotification,
  fileDownloading,
  fileUploading,
  fileMetadataId,
  replyStanzaId,
  replyOriginId,
  replyMucStanzaId,
  stickerPackId,
  pseudoMessageType,
  pseudoMessageData,
  reactionsPreview,
  deltaAccountId,
  deltaChatId,
  deltaMsgId,
  rfc822BodyStatus,
}

extension MessageDiffFieldX on MessageDiffField {
  String get logLabel => name;
}

final class _DeltaChatJidMessageId {
  const _DeltaChatJidMessageId({
    required this.accountId,
    required this.chatId,
    required this.chatJid,
    required this.msgId,
  });

  final int accountId;
  final int chatId;
  final String chatJid;
  final int msgId;
}

Future<T> _timedDeltaTraceStep<T>(
  Future<T> Function() operation,
  void Function(int elapsedMs) record,
) async {
  final stopwatch = Stopwatch()..start();
  try {
    return await operation();
  } finally {
    record(stopwatch.elapsedMilliseconds);
  }
}

T _timedDeltaTraceStepSync<T>(
  T Function() operation,
  void Function(int elapsedMs) record,
) {
  final stopwatch = Stopwatch()..start();
  try {
    return operation();
  } finally {
    record(stopwatch.elapsedMilliseconds);
  }
}

enum DeltaEventType {
  warning(DeltaEventCode.warning),
  error(DeltaEventCode.error),
  errorSelfNotInGroup(DeltaEventCode.errorSelfNotInGroup),
  msgsChanged(DeltaEventCode.msgsChanged),
  reactionsChanged(DeltaEventCode.reactionsChanged),
  incomingReaction(DeltaEventCode.incomingReaction),
  incomingWebxdcNotify(DeltaEventCode.incomingWebxdcNotify),
  msgsNoticed(DeltaEventCode.msgsNoticed),
  incomingMsg(DeltaEventCode.incomingMsg),
  incomingMsgBunch(DeltaEventCode.incomingMsgBunch),
  msgDelivered(DeltaEventCode.msgDelivered),
  msgFailed(DeltaEventCode.msgFailed),
  msgRead(DeltaEventCode.msgRead),
  chatModified(DeltaEventCode.chatModified),
  chatDeleted(DeltaEventCode.chatDeleted),
  contactsChanged(DeltaEventCode.contactsChanged),
  configureProgress(DeltaEventCode.configureProgress),
  imexProgress(DeltaEventCode.imexProgress),
  imexFileWritten(DeltaEventCode.imexFileWritten),
  accountsBackgroundFetchDone(DeltaEventCode.accountsBackgroundFetchDone),
  connectivityChanged(DeltaEventCode.connectivityChanged),
  channelOverflow(DeltaEventCode.channelOverflow);

  const DeltaEventType(this.code);

  final int code;

  static DeltaEventType? fromCode(int value) {
    for (final type in DeltaEventType.values) {
      if (type.code == value) {
        return type;
      }
    }
    return null;
  }
}

abstract interface class DeltaEventCore {
  int get accountId;
  bool get supportsMessageRfc724Mid;
  bool get supportsMessageInfo;
  bool get supportsMessageDebugInfo;

  Future<List<DeltaChatlistEntry>> getChatlist({int flags = 0});
  Future<List<int>> getChatMessageIds({
    required int chatId,
    int? beforeMessageId,
  });
  Future<DeltaMessage?> getMessage(int messageId);
  Future<DeltaMessageStatus?> getMessageStatus(int messageId);
  Future<List<DeltaMessage>> getMessages(List<int> messageIds);
  Future<List<DeltaMessageStatus>> getMessageStatuses(List<int> messageIds);
  Future<List<int>> getFreshMessageIds();
  Future<DeltaFreshMessageCount> getFreshMessageCountSafe(int chatId);
  Future<bool> downloadFullMessage(int messageId);
  Future<String?> getMessageRfc724Mid(int messageId);
  Future<String?> getMessageInfo(int messageId);
  Future<String?> getMessageMimeHeaders(int messageId);
  Future<String?> getMessageDebugInfo(int messageId);
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(int messageId);
  Future<DeltaQuotedMessage?> getQuotedMessage(int messageId);
  Future<DeltaContactPublicKeyImport> importContactPublicKey({
    required String address,
    required String displayName,
    required String armoredPublicKey,
  });
  Future<DeltaChatSendCapabilities> chatSendCapabilities(int chatId);
  Future<DeltaChat?> getChat(int chatId);
}

final class DeltaContextEventCore implements DeltaEventCore {
  const DeltaContextEventCore(this._context, {int? accountId})
    : _accountId = accountId;

  final DeltaContextHandle _context;
  final int? _accountId;

  @override
  int get accountId {
    final accountId = _accountId ?? _context.accountId;
    if (accountId == null || accountId == DeltaAccountDefaults.legacyId) {
      throw StateError('Delta event core requires a real account id.');
    }
    return accountId;
  }

  @override
  bool get supportsMessageRfc724Mid => _context.supportsMessageRfc724Mid;

  @override
  bool get supportsMessageInfo => _context.supportsMessageInfo;

  @override
  bool get supportsMessageDebugInfo => _context.supportsMessageDebugInfo;

  @override
  Future<List<DeltaChatlistEntry>> getChatlist({int flags = 0}) =>
      _context.getChatlist(flags: flags);

  @override
  Future<List<int>> getChatMessageIds({
    required int chatId,
    int? beforeMessageId,
  }) {
    if (beforeMessageId == null) {
      return _context.getChatMessageIds(chatId: chatId);
    }
    return _context.getChatMessageIds(
      chatId: chatId,
      beforeMessageId: beforeMessageId,
    );
  }

  @override
  Future<DeltaMessage?> getMessage(int messageId) =>
      _context.getMessage(messageId);

  @override
  Future<DeltaMessageStatus?> getMessageStatus(int messageId) =>
      _context.getMessageStatus(messageId);

  @override
  Future<List<DeltaMessage>> getMessages(List<int> messageIds) async {
    final messages = <DeltaMessage>[];
    for (final messageId in messageIds) {
      final message = await _context.getMessage(messageId);
      if (message != null) {
        messages.add(message);
      }
    }
    return messages;
  }

  @override
  Future<List<DeltaMessageStatus>> getMessageStatuses(
    List<int> messageIds,
  ) async {
    final statuses = <DeltaMessageStatus>[];
    for (final messageId in messageIds) {
      final status = await _context.getMessageStatus(messageId);
      if (status != null) {
        statuses.add(status);
      }
    }
    return statuses;
  }

  @override
  Future<List<int>> getFreshMessageIds() => _context.getFreshMessageIds();

  @override
  Future<DeltaFreshMessageCount> getFreshMessageCountSafe(int chatId) =>
      _context.getFreshMessageCountSafe(chatId);

  @override
  Future<bool> downloadFullMessage(int messageId) =>
      _context.downloadFullMessage(messageId);

  @override
  Future<String?> getMessageRfc724Mid(int messageId) =>
      _context.getMessageRfc724Mid(messageId);

  @override
  Future<String?> getMessageInfo(int messageId) =>
      _context.getMessageInfo(messageId);

  @override
  Future<String?> getMessageMimeHeaders(int messageId) =>
      _context.getMessageMimeHeaders(messageId);

  @override
  Future<String?> getMessageDebugInfo(int messageId) =>
      _context.getMessageDebugInfo(messageId);

  @override
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(int messageId) =>
      _context.getMessageRfc822Body(messageId);

  @override
  Future<DeltaQuotedMessage?> getQuotedMessage(int messageId) =>
      _context.getQuotedMessage(messageId);

  @override
  Future<DeltaContactPublicKeyImport> importContactPublicKey({
    required String address,
    required String displayName,
    required String armoredPublicKey,
  }) => _context.importContactPublicKey(
    address: address,
    displayName: displayName,
    armoredPublicKey: armoredPublicKey,
  );

  @override
  Future<DeltaChatSendCapabilities> chatSendCapabilities(int chatId) =>
      _context.chatSendCapabilities(chatId);

  @override
  Future<DeltaChat?> getChat(int chatId) => _context.getChat(chatId);
}

class DeltaMessageDeliveryStatus {
  const DeltaMessageDeliveryStatus({
    required this.acked,
    required this.received,
    required this.displayed,
  });

  final bool acked;
  final bool received;
  final bool displayed;
}

const DeltaMessageDeliveryStatus _deltaOutgoingPendingStatus =
    DeltaMessageDeliveryStatus(acked: false, received: false, displayed: false);
const DeltaMessageDeliveryStatus _deltaOutgoingDeliveredStatus =
    DeltaMessageDeliveryStatus(acked: true, received: true, displayed: false);
const DeltaMessageDeliveryStatus _deltaOutgoingReadStatus =
    DeltaMessageDeliveryStatus(acked: true, received: true, displayed: true);
const DeltaMessageDeliveryStatus _deltaOutgoingUnknownStatus =
    DeltaMessageDeliveryStatus(acked: true, received: false, displayed: false);
const DeltaMessageDeliveryStatus _deltaIncomingUnseenStatus =
    DeltaMessageDeliveryStatus(acked: false, received: true, displayed: false);
const DeltaMessageDeliveryStatus _deltaIncomingSeenStatus =
    DeltaMessageDeliveryStatus(acked: false, received: true, displayed: true);

extension DeltaMessageStateChecks on DeltaMessage {
  bool get hasKnownState => state != null;

  bool get hasUserVisibleAttachment {
    if (!hasFile) {
      return false;
    }
    return switch (viewType) {
      DeltaMessageType.image ||
      DeltaMessageType.gif ||
      DeltaMessageType.sticker ||
      DeltaMessageType.audio ||
      DeltaMessageType.voice ||
      DeltaMessageType.video ||
      DeltaMessageType.file ||
      DeltaMessageType.webxdc ||
      DeltaMessageType.vcard => true,
      _ => false,
    };
  }

  bool get isOutgoingDelivered =>
      isOutgoing &&
      (state == DeltaMessageState.outDelivered ||
          state == DeltaMessageState.outMdnRcvd);

  bool get isOutgoingRead =>
      isOutgoing && state == DeltaMessageState.outMdnRcvd;

  bool get isOutgoingFailed =>
      isOutgoing && state == DeltaMessageState.outFailed;

  bool get isIncomingSeen => !isOutgoing && state == DeltaMessageState.inSeen;

  DeltaMessageDeliveryStatus get deliveryStatus {
    if (isOutgoing) {
      if (!hasKnownState) {
        return _deltaOutgoingUnknownStatus;
      }
      if (isOutgoingRead) {
        return _deltaOutgoingReadStatus;
      }
      if (isOutgoingDelivered) {
        return _deltaOutgoingDeliveredStatus;
      }
      return _deltaOutgoingPendingStatus;
    }
    if (isIncomingSeen) {
      return _deltaIncomingSeenStatus;
    }
    return _deltaIncomingUnseenStatus;
  }
}

extension DeltaMessageStatusStateChecks on DeltaMessageStatus {
  bool get hasKnownState => state != null;

  bool get isOutgoingDelivered =>
      isOutgoing &&
      (state == DeltaMessageState.outDelivered ||
          state == DeltaMessageState.outMdnRcvd);

  bool get isOutgoingRead =>
      isOutgoing && state == DeltaMessageState.outMdnRcvd;

  bool get isOutgoingFailed =>
      isOutgoing && state == DeltaMessageState.outFailed;

  bool get isIncomingSeen => !isOutgoing && state == DeltaMessageState.inSeen;

  DeltaMessageDeliveryStatus get deliveryStatus {
    if (isOutgoing) {
      if (!hasKnownState) {
        return _deltaOutgoingUnknownStatus;
      }
      if (isOutgoingRead) {
        return _deltaOutgoingReadStatus;
      }
      if (isOutgoingDelivered) {
        return _deltaOutgoingDeliveredStatus;
      }
      return _deltaOutgoingPendingStatus;
    }
    if (isIncomingSeen) {
      return _deltaIncomingSeenStatus;
    }
    return _deltaIncomingUnseenStatus;
  }
}

extension MessageDiffX on Message {
  List<MessageDiffField> diffFields(Message other) {
    final fields = <MessageDiffField>[];
    void addIf(bool condition, MessageDiffField field) {
      if (condition) {
        fields.add(field);
      }
    }

    addIf(stanzaID != other.stanzaID, MessageDiffField.stanzaId);
    addIf(senderJid != other.senderJid, MessageDiffField.senderJid);
    addIf(chatJid != other.chatJid, MessageDiffField.chatJid);
    addIf(timestamp != other.timestamp, MessageDiffField.timestamp);
    addIf(id != other.id, MessageDiffField.id);
    addIf(originID != other.originID, MessageDiffField.originId);
    addIf(occupantID != other.occupantID, MessageDiffField.occupantId);
    addIf(body != other.body, MessageDiffField.body);
    addIf(htmlBody != other.htmlBody, MessageDiffField.htmlBody);
    addIf(subject != other.subject, MessageDiffField.subject);
    addIf(error != other.error, MessageDiffField.error);
    addIf(warning != other.warning, MessageDiffField.warning);
    addIf(
      encryptionProtocol != other.encryptionProtocol,
      MessageDiffField.encryptionProtocol,
    );
    addIf(trust != other.trust, MessageDiffField.trust);
    addIf(trusted != other.trusted, MessageDiffField.trusted);
    addIf(deviceID != other.deviceID, MessageDiffField.deviceId);
    addIf(noStore != other.noStore, MessageDiffField.noStore);
    addIf(acked != other.acked, MessageDiffField.acked);
    addIf(received != other.received, MessageDiffField.received);
    addIf(displayed != other.displayed, MessageDiffField.displayed);
    addIf(
      deltaSeenSynced != other.deltaSeenSynced,
      MessageDiffField.deltaSeenSynced,
    );
    addIf(edited != other.edited, MessageDiffField.edited);
    addIf(retracted != other.retracted, MessageDiffField.retracted);
    addIf(
      isFileUploadNotification != other.isFileUploadNotification,
      MessageDiffField.isFileUploadNotification,
    );
    addIf(
      fileDownloading != other.fileDownloading,
      MessageDiffField.fileDownloading,
    );
    addIf(fileUploading != other.fileUploading, MessageDiffField.fileUploading);
    addIf(
      fileMetadataID != other.fileMetadataID,
      MessageDiffField.fileMetadataId,
    );
    addIf(replyStanzaId != other.replyStanzaId, MessageDiffField.replyStanzaId);
    addIf(replyOriginId != other.replyOriginId, MessageDiffField.replyOriginId);
    addIf(
      replyMucStanzaId != other.replyMucStanzaId,
      MessageDiffField.replyMucStanzaId,
    );
    addIf(stickerPackID != other.stickerPackID, MessageDiffField.stickerPackId);
    addIf(
      pseudoMessageType != other.pseudoMessageType,
      MessageDiffField.pseudoMessageType,
    );
    addIf(
      !_deepEquals(pseudoMessageData, other.pseudoMessageData),
      MessageDiffField.pseudoMessageData,
    );
    addIf(
      !_deepEquals(reactionsPreview, other.reactionsPreview),
      MessageDiffField.reactionsPreview,
    );
    addIf(
      deltaAccountId != other.deltaAccountId,
      MessageDiffField.deltaAccountId,
    );
    addIf(deltaChatId != other.deltaChatId, MessageDiffField.deltaChatId);
    addIf(deltaMsgId != other.deltaMsgId, MessageDiffField.deltaMsgId);
    addIf(
      rfc822BodyStatus != other.rfc822BodyStatus,
      MessageDiffField.rfc822BodyStatus,
    );
    return fields;
  }
}

bool _deepEquals(Object? first, Object? second) {
  if (identical(first, second)) {
    return true;
  }
  if (first == null || second == null) {
    return false;
  }
  if (first is Map<Object?, Object?> && second is Map<Object?, Object?>) {
    if (first.length != second.length) {
      return false;
    }
    for (final entry in first.entries) {
      if (!second.containsKey(entry.key)) {
        return false;
      }
      if (!_deepEquals(entry.value, second[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (first is List<Object?> && second is List<Object?>) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index += 1) {
      if (!_deepEquals(first[index], second[index])) {
        return false;
      }
    }
    return true;
  }
  return first == second;
}

String? _autocryptPublicKeyFromHeaders(
  String? headers, {
  required String expectedAddress,
}) {
  if (headers == null || headers.trim().isEmpty) {
    return null;
  }
  final expected = normalizedAddressValue(expectedAddress);
  if (expected == null || expected.isEmpty) {
    return null;
  }
  final unfolded = <String>[];
  String? current;
  for (final rawLine
      in headers.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    if (rawLine.startsWith(' ') || rawLine.startsWith('\t')) {
      current = current == null ? rawLine.trim() : '$current ${rawLine.trim()}';
      continue;
    }
    if (current != null) {
      unfolded.add(current);
    }
    current = rawLine;
  }
  if (current != null) {
    unfolded.add(current);
  }
  for (final line in unfolded.reversed) {
    final separatorIndex = line.indexOf(':');
    if (separatorIndex <= 0) {
      continue;
    }
    if (line.substring(0, separatorIndex).trim().toLowerCase() != 'autocrypt') {
      continue;
    }
    final attributes = <String, String>{};
    for (final part in line.substring(separatorIndex + 1).split(';')) {
      final valueSeparatorIndex = part.indexOf('=');
      if (valueSeparatorIndex <= 0) {
        continue;
      }
      final name = part.substring(0, valueSeparatorIndex).trim().toLowerCase();
      var value = part.substring(valueSeparatorIndex + 1).trim();
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1).replaceAll(r'\"', '"');
      }
      attributes[name] = value;
    }
    if (normalizedAddressValue(attributes['addr'] ?? '') != expected) {
      continue;
    }
    final keydata = attributes['keydata']?.replaceAll(RegExp(r'\s+'), '');
    if (keydata == null || keydata.isEmpty) {
      continue;
    }
    final Uint8List keyBytes;
    try {
      keyBytes = base64.decode(keydata);
    } on FormatException {
      continue;
    }
    final encoded = base64.encode(keyBytes);
    final wrapped = <String>[];
    for (var index = 0; index < encoded.length; index += 64) {
      final end = index + 64 > encoded.length ? encoded.length : index + 64;
      wrapped.add(encoded.substring(index, end));
    }
    final checksum = _openPgpArmorChecksum(keyBytes);
    return '-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n'
        '${wrapped.join('\n')}\n'
        '=$checksum\n'
        '-----END PGP PUBLIC KEY BLOCK-----\n';
  }
  return null;
}

String _openPgpArmorChecksum(Uint8List bytes) {
  var crc = 0xB704CE;
  for (final byte in bytes) {
    crc ^= byte << 16;
    for (var bit = 0; bit < 8; bit += 1) {
      crc <<= 1;
      if ((crc & 0x1000000) != 0) {
        crc ^= 0x1864CFB;
      }
    }
  }
  crc &= 0xFFFFFF;
  return base64.encode(
    Uint8List.fromList([(crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF]),
  );
}

typedef DeltaProjectionDeferralPredicate =
    bool Function(DeltaEventType eventType);
typedef DeltaProjectionDeferredCallback =
    void Function(DeltaEventType eventType);

class DeltaEventConsumer {
  static const Duration _deltaProfileTraceSlowThreshold = Duration(
    milliseconds: 100,
  );
  static const int _deltaProfileTraceNoopBatchSize = 25;

  static const String _emailPartDiagPrefix = 'EMAIL_PART_DIAG';
  static const String _emailUpdateDiffDiagPrefix = 'EMAIL_UPDATE_DIFF_DIAG';

  DeltaEventConsumer({
    required Future<XmppDatabase> Function() databaseBuilder,
    required DeltaEventCore core,
    AppLocalizations Function()? localizationsProvider,
    String? Function()? selfJidProvider,
    String? Function()? xmppSelfJidProvider,
    bool Function(int accountId, String address)?
    emailEncryptionBetaEnabledForAddress,
    DeltaProjectionDeferralPredicate? shouldDeferProjectionForEvent,
    DeltaProjectionDeferredCallback? onProjectionDeferred,
    Logger? logger,
    Future<T> Function<T>(Future<T> Function() operation)?
    databaseOperationTracker,
  }) : _databaseBuilder = databaseBuilder,
       _core = core,
       _localizationsProvider = localizationsProvider,
       _selfJidProvider = selfJidProvider,
       _xmppSelfJidProvider = xmppSelfJidProvider,
       _emailEncryptionBetaEnabledForAddress =
           emailEncryptionBetaEnabledForAddress,
       _shouldDeferProjectionForEvent = shouldDeferProjectionForEvent,
       _onProjectionDeferred = onProjectionDeferred,
       _databaseOperationTracker = databaseOperationTracker,
       _log = logger ?? Logger('DeltaEventConsumer');

  final Future<XmppDatabase> Function() _databaseBuilder;
  final Future<T> Function<T>(Future<T> Function() operation)?
  _databaseOperationTracker;
  final DeltaEventCore _core;
  final AppLocalizations Function()? _localizationsProvider;
  final String? Function()? _selfJidProvider;
  final String? Function()? _xmppSelfJidProvider;
  final bool Function(int accountId, String address)?
  _emailEncryptionBetaEnabledForAddress;
  final DeltaProjectionDeferralPredicate? _shouldDeferProjectionForEvent;
  final DeltaProjectionDeferredCallback? _onProjectionDeferred;
  final Logger _log;
  Future<void>? _chatlistRefreshInFlight;
  Future<Set<int>>? _archivedChatlistInFlight;
  DateTime? _archivedChatlistFetchedAt;
  final Set<int> _archivedChatIds = <int>{};
  final EmailAsyncQueue _eventQueue = EmailAsyncQueue();
  final EmailAsyncQueue _originIdHydrationQueue = EmailAsyncQueue();
  final Set<int> _originIdHydrationPending = <int>{};
  final Set<int> _originIdHydrationExhausted = <int>{};
  final Map<int, bool> _deltaSystemChatCoreCache = <int, bool>{};
  int _suppressedDeltaIngestNoopCount = 0;
  int _suppressedDeltaIngestNoopWorstMs = 0;
  int _suppressedDeltaUpdateNoopCount = 0;
  int _suppressedDeltaUpdateNoopWorstMs = 0;

  final Map<String, int> _learnedAutocryptContactKeyChatIds = <String, int>{};

  AppLocalizations get _l10n =>
      _localizationsProvider?.call() ??
      lookupAppLocalizations(const Locale('en'));

  String get _selfJid =>
      _selfJidProvider?.call().resolveDeltaPlaceholderJid() ?? _emptyJid;

  String? get _xmppSelfJid => _xmppSelfJidProvider?.call();

  int get _deltaAccountId => _core.accountId;

  Future<bool> bootstrapFromCore({bool includeMessages = false}) async {
    final int deltaAccountId = _deltaAccountId;
    final chatlist = await _core.getChatlist();
    final archivedChatlist = await _core.getChatlist(
      flags: _deltaChatlistArchivedOnlyFlag,
    );
    if (chatlist.isEmpty && archivedChatlist.isEmpty) {
      return false;
    }

    final archivedChatIds = archivedChatlist
        .where((entry) => entry.chatId > _deltaChatLastSpecialId)
        .map((entry) => entry.chatId)
        .toSet();

    final entriesByChatId = <int, DeltaChatlistEntry>{};
    void register(Iterable<DeltaChatlistEntry> entries) {
      for (final entry in entries) {
        if (entry.chatId <= _deltaChatLastSpecialId) continue;
        final existing = entriesByChatId[entry.chatId];
        if (existing == null ||
            (existing.msgId <= 0 && entry.msgId > existing.msgId)) {
          entriesByChatId[entry.chatId] = entry;
        }
      }
    }

    register(chatlist);
    register(archivedChatlist);

    final db = await _db();
    var didBootstrap = false;

    for (final entry in entriesByChatId.values) {
      final chatId = entry.chatId;
      if (await _isDeltaSystemChat(chatId)) {
        continue;
      }
      didBootstrap = true;
      await _bootstrapChatSummary(
        entry: entry,
        archivedChatIds: archivedChatIds,
        db: db,
      );
    }

    if (!includeMessages) {
      return didBootstrap;
    }

    for (final chatId in entriesByChatId.keys) {
      if (await _isDeltaSystemChat(chatId)) {
        continue;
      }
      await _bootstrapChatMessages(
        chatId: chatId,
        deltaAccountId: deltaAccountId,
        db: db,
      );
    }

    return didBootstrap;
  }

  Future<void> _bootstrapChatSummary({
    required DeltaChatlistEntry entry,
    required Set<int> archivedChatIds,
    required XmppDatabase db,
  }) async {
    final chatId = entry.chatId;
    final chat = await _ensureChat(chatId);
    var updated = chat;
    var changed = false;
    final isArchived = archivedChatIds.contains(chatId);
    if (updated.archived != isArchived) {
      updated = updated.copyWith(archived: isArchived);
      changed = true;
    }
    DateTime? lastTimestamp;
    String? lastPreview;
    if (entry.msgId > 0 && !_isDeltaMessageMarkerId(entry.msgId)) {
      final messageId = _DeltaChatJidMessageId(
        accountId: _deltaAccountId,
        chatId: chatId,
        chatJid: updated.jid,
        msgId: entry.msgId,
      );
      final stored = await _lookupStoredDeltaMessage(db, messageId);
      final existing = stored?.chatJid == updated.jid ? stored : null;
      if (existing != null) {
        if (!existing.isHiddenMultiDeviceSyncMessage) {
          lastTimestamp = existing.timestamp;
          lastPreview = await _previewTextForStoredMessage(
            db: db,
            message: existing,
          );
        }
      }
    }
    if (lastTimestamp != null &&
        !lastTimestamp.isBefore(updated.lastChangeTimestamp)) {
      changed = true;
      updated = updated.copyWith(
        lastChangeTimestamp: lastTimestamp,
        lastMessage: lastPreview,
      );
    }
    if (changed) {
      await db.updateChat(updated);
    }
  }

  Future<void> _bootstrapChatMessages({
    required int chatId,
    required int deltaAccountId,
    required XmppDatabase db,
  }) async {
    final chat = await _ensureChat(chatId);
    final msgIds = await _core.getChatMessageIds(chatId: chatId);
    final filteredMsgIds = msgIds
        .where((id) => !_isDeltaMessageMarkerId(id))
        .toList();
    if (filteredMsgIds.isEmpty) {
      return;
    }
    const int batchSize = 32;
    for (var index = 0; index < filteredMsgIds.length; index += batchSize) {
      final end = index + batchSize > filteredMsgIds.length
          ? filteredMsgIds.length
          : index + batchSize;
      final batch = filteredMsgIds.sublist(index, end);
      final messages = await _core.getMessages(batch);
      for (final msg in messages) {
        await _ingestDeltaMessage(
          eventChatId: chatId,
          msg: msg,
          source: 'bootstrapChatMessages',
          chat: chat,
          skipSystemChatCheck: true,
        );
      }
      await Future<void>.delayed(Duration.zero);
    }

    final stored = await db.getChatByDeltaChatId(
      chatId,
      accountId: deltaAccountId,
    );
    if (stored != null) {
      await _refreshStoredChatSummary(chatJid: stored.jid, db: db);
    }
    await _updateUnreadCount(chatId);
  }

  Future<void> refreshChatlistSnapshot({bool Function()? isCurrent}) async {
    final inFlight = _chatlistRefreshInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _refreshChatlistSnapshotInternal(isCurrent: isCurrent);
    _chatlistRefreshInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_chatlistRefreshInFlight, future)) {
        _chatlistRefreshInFlight = null;
      }
    }
  }

  Future<void> _refreshChatlistSnapshotInternal({
    bool Function()? isCurrent,
  }) async {
    bool cancelled() => isCurrent?.call() == false;
    final int deltaAccountId = _deltaAccountId;
    final chatlist = await _core.getChatlist();
    if (cancelled()) return;
    final archivedChatlist = await _core.getChatlist(
      flags: _deltaChatlistArchivedOnlyFlag,
    );
    if (cancelled()) return;
    if (chatlist.isEmpty && archivedChatlist.isEmpty) {
      return;
    }

    final archivedChatIds = archivedChatlist
        .where((entry) => entry.chatId > _deltaChatLastSpecialId)
        .map((entry) => entry.chatId)
        .toSet();
    _archivedChatIds
      ..clear()
      ..addAll(archivedChatIds);
    _archivedChatlistFetchedAt = DateTime.timestamp();

    final entriesByChatId = <int, DeltaChatlistEntry>{};
    void register(Iterable<DeltaChatlistEntry> entries) {
      for (final entry in entries) {
        if (entry.chatId <= _deltaChatLastSpecialId) continue;
        final existing = entriesByChatId[entry.chatId];
        if (existing == null ||
            (existing.msgId <= 0 && entry.msgId > existing.msgId)) {
          entriesByChatId[entry.chatId] = entry;
        }
      }
    }

    register(chatlist);
    register(archivedChatlist);
    final freshIdsByChatId = await _freshMessageIdsByChatIds(
      entriesByChatId.keys,
      isCurrent: isCurrent,
    );
    if (cancelled()) return;

    await _trackDatabaseOperation(() async {
      final db = await _db();
      if (cancelled()) return;
      final knownChatIds = entriesByChatId.keys.toSet();
      final emailChatAccounts = await db.getEmailChatAccountsForAccount(
        deltaAccountId,
      );
      if (cancelled()) return;
      for (final emailChatAccount in emailChatAccounts) {
        if (cancelled()) return;
        final deltaChatId = emailChatAccount.deltaChatId;
        if (deltaChatId <= _deltaChatLastSpecialId) {
          continue;
        }
        if (!knownChatIds.contains(deltaChatId)) {
          if (await _core.getChat(deltaChatId) != null) {
            continue;
          }
          if (cancelled()) return;
          final chat = await db.getChat(emailChatAccount.chatJid);
          if (chat == null) {
            await db.deleteEmailChatAccount(
              chatJid: emailChatAccount.chatJid,
              deltaAccountId: deltaAccountId,
              deltaChatId: deltaChatId,
            );
            continue;
          }
          await db.deleteEmailChatAccount(
            chatJid: chat.jid,
            deltaAccountId: deltaAccountId,
            deltaChatId: deltaChatId,
          );
          await _repairActiveDeltaChatReference(
            chatJid: chat.jid,
            removedDeltaChatId: deltaChatId,
            db: db,
          );
          if (await _canRemoveDetachedEmailChat(db: db, chat: chat)) {
            await db.removeChat(chat.jid);
          }
        }
      }
      for (final entry in entriesByChatId.values) {
        if (cancelled()) return;
        final chatId = entry.chatId;
        if (await _isDeltaSystemChat(chatId)) {
          continue;
        }
        if (cancelled()) return;
        final chat = await _ensureChat(chatId);
        if (cancelled()) return;
        final isArchived = archivedChatIds.contains(chatId);
        var updated = chat;
        DateTime? lastTimestamp;
        String? lastPreview;
        if (entry.msgId > 0 && !_isDeltaMessageMarkerId(entry.msgId)) {
          final messageId = _DeltaChatJidMessageId(
            accountId: deltaAccountId,
            chatId: chatId,
            chatJid: updated.jid,
            msgId: entry.msgId,
          );
          final stored = await _lookupStoredDeltaMessage(db, messageId);
          final existing = stored?.chatJid == updated.jid ? stored : null;
          if (existing != null) {
            if (!existing.isHiddenMultiDeviceSyncMessage) {
              lastTimestamp = existing.timestamp;
              lastPreview = await _previewTextForStoredMessage(
                db: db,
                message: existing,
              );
            }
          } else {
            final last = await _core.getMessage(entry.msgId);
            if (cancelled()) return;
            if (last != null &&
                !_isHiddenMultiDeviceSyncMessage(last, chat: updated)) {
              final outcome = await _ingestDeltaMessage(
                eventChatId: chatId,
                msg: last,
                source: 'chatlistSnapshot',
                chat: updated,
                skipSystemChatCheck: true,
              );
              if (cancelled()) return;
              final storedAfterIngest = await _lookupStoredDeltaMessage(
                db,
                messageId,
              );
              final persisted = storedAfterIngest?.chatJid == updated.jid
                  ? storedAfterIngest
                  : null;
              if (persisted != null &&
                  !persisted.isHiddenMultiDeviceSyncMessage) {
                lastTimestamp = persisted.timestamp;
                lastPreview = await _previewTextForStoredMessage(
                  db: db,
                  message: persisted,
                );
              } else if (outcome.saveResult?.storedMessage == true) {
                lastTimestamp = last.timestamp;
                lastPreview = _previewTextForDeltaMessage(last, chat: updated);
              }
            }
          }
        }
        if (updated.archived != isArchived) {
          updated = updated.copyWith(archived: isArchived);
        }
        if (lastTimestamp != null) {
          if (!lastTimestamp.isBefore(updated.lastChangeTimestamp)) {
            updated = updated.copyWith(
              lastChangeTimestamp: lastTimestamp,
              lastMessage: lastPreview,
            );
          }
        } else {
          await _refreshStoredChatSummary(chatJid: updated.jid, db: db);
        }
        var storedUnreadCount = await db.countUnreadMessagesForChat(
          updated.jid,
          selfJid: _xmppSelfJid,
          emailSelfJid: _selfJid,
        );
        final freshIds = freshIdsByChatId[chatId] ?? const <int>[];
        if (freshIds.isNotEmpty) {
          final freshSync = await syncFreshMessages(
            freshIds,
            isCurrent: isCurrent,
          );
          if (cancelled()) return;
          if (freshSync.projectedLocalState) {
            await _refreshStoredChatSummary(chatJid: updated.jid, db: db);
            storedUnreadCount = await db.countUnreadMessagesForChat(
              updated.jid,
              selfJid: _xmppSelfJid,
              emailSelfJid: _selfJid,
            );
          }
        }
        final unreadCount = storedUnreadCount;
        final refreshed = await db.getChat(updated.jid);
        if (refreshed == null) {
          final nextUpdated = updated.unreadCount == unreadCount
              ? updated
              : updated.copyWith(unreadCount: unreadCount);
          if (nextUpdated != chat) {
            await db.updateChat(nextUpdated);
          }
        } else {
          var merged = refreshed;
          if (merged.archived != updated.archived) {
            merged = merged.copyWith(archived: updated.archived);
          }
          if (merged.unreadCount != unreadCount) {
            merged = merged.copyWith(unreadCount: unreadCount);
          }
          if (lastTimestamp != null &&
              !lastTimestamp.isBefore(merged.lastChangeTimestamp)) {
            merged = merged.copyWith(
              lastChangeTimestamp: lastTimestamp,
              lastMessage: lastPreview,
            );
          }
          if (merged != refreshed) {
            await db.updateChat(merged);
          }
        }
      }
    });
  }

  Future<Map<int, List<int>>> _freshMessageIdsByChatIds(
    Iterable<int> chatIds, {
    bool Function()? isCurrent,
  }) async {
    bool cancelled() => isCurrent?.call() == false;
    final chatIdSet = chatIds
        .where((id) => id > _deltaChatLastSpecialId)
        .toSet();
    if (chatIdSet.isEmpty) {
      return const <int, List<int>>{};
    }
    final rawFreshIds = await _core.getFreshMessageIds();
    if (cancelled()) {
      return const <int, List<int>>{};
    }
    final freshIds = <int>[];
    final seenFreshIds = <int>{};
    for (final freshId in rawFreshIds) {
      if (freshId <= _deltaMessageIdUnset || _isDeltaMessageMarkerId(freshId)) {
        continue;
      }
      if (seenFreshIds.add(freshId)) {
        freshIds.add(freshId);
      }
    }
    if (freshIds.isEmpty) {
      return const <int, List<int>>{};
    }
    final statuses = await _core.getMessageStatuses(freshIds);
    if (cancelled()) {
      return const <int, List<int>>{};
    }
    final freshIdsByChatId = <int, List<int>>{};
    for (final status in statuses) {
      final chatId = status.chatId;
      if (!chatIdSet.contains(chatId)) {
        continue;
      }
      freshIdsByChatId.putIfAbsent(chatId, () => <int>[]).add(status.id);
    }
    return {
      for (final entry in freshIdsByChatId.entries)
        if (entry.value.isNotEmpty)
          entry.key: List<int>.unmodifiable(entry.value),
    };
  }

  Future<bool> _syncFreshMessagesForChat({
    required int chatId,
    bool Function()? isCurrent,
  }) async {
    final freshIdsByChatId = await _freshMessageIdsByChatIds([
      chatId,
    ], isCurrent: isCurrent);
    final freshIds = freshIdsByChatId[chatId] ?? const <int>[];
    if (freshIds.isEmpty) {
      return false;
    }
    final result = await syncFreshMessages(freshIds, isCurrent: isCurrent);
    return result.projectedLocalState;
  }

  Future<void> handle(DeltaCoreEvent event) {
    return _eventQueue.run(() => _handleSerialized(event));
  }

  Future<void> _handleSerialized(DeltaCoreEvent event) async {
    final eventType = DeltaEventType.fromCode(event.type);
    if (eventType == null) {
      _log.fine('Ignoring unknown Delta event code ${event.type}.');
      return;
    }
    if (_shouldDeferProjectionForEvent?.call(eventType) == true) {
      _onProjectionDeferred?.call(eventType);
      return;
    }
    switch (eventType) {
      case DeltaEventType.msgsChanged:
        await _handleMessagesChanged(event.data1, event.data2);
        break;
      case DeltaEventType.reactionsChanged:
        await _handleReactionsChanged(event.data1, event.data2);
        break;
      case DeltaEventType.incomingMsg:
        await _handleIncomingMessage(event.data1, event.data2);
        break;
      case DeltaEventType.msgDelivered:
      case DeltaEventType.msgFailed:
        _log.fine(
          'Email outgoing core event: '
          'type=${eventType.name}, chatId=${event.data1}, msgId=${event.data2}',
        );
        await _handleMessageStateChanged(event.data1, event.data2);
        break;
      case DeltaEventType.msgRead:
        await _handleMessageStateChanged(event.data1, event.data2);
        break;
      case DeltaEventType.msgsNoticed:
        await _handleMessagesNoticed(event.data1);
        break;
      case DeltaEventType.chatModified:
        _deltaSystemChatCoreCache.remove(event.data1);
        await _refreshChat(event.data1);
        break;
      case DeltaEventType.chatDeleted:
        _deltaSystemChatCoreCache.remove(event.data1);
        await _handleChatDeleted(event.data1);
        break;
      default:
        break;
    }
  }

  Future<
    ({
      _DeltaStatusHydrationResult? hydration,
      String result,
      int resolvedChatId,
    })
  >
  _applyDeltaMessageStatus({
    required int eventChatId,
    required DeltaMessageStatus status,
    int? expectedChatId,
  }) async {
    final resolvedChatId = status.chatId > 0 ? status.chatId : eventChatId;
    if (expectedChatId != null && resolvedChatId != expectedChatId) {
      return (
        hydration: null,
        result: 'chatMismatch',
        resolvedChatId: resolvedChatId,
      );
    }
    if (resolvedChatId <= _deltaChatLastSpecialId) {
      return (
        hydration: null,
        result: 'systemChat',
        resolvedChatId: resolvedChatId,
      );
    }
    final db = await _db();
    final existingByDeltaId = await db.getMessageByDeltaId(
      status.id,
      deltaAccountId: _deltaAccountId,
    );
    if (existingByDeltaId == null) {
      return (
        hydration: null,
        result: 'missingLocalMessage',
        resolvedChatId: resolvedChatId,
      );
    }
    final resolvedChat = await _ensureChat(resolvedChatId);
    var existing = existingByDeltaId;
    if (!_storedDeltaLocatorMatches(
      existing,
      msgId: status.id,
      chatId: resolvedChatId,
      accountId: _deltaAccountId,
      chatJid: resolvedChat.jid,
    )) {
      final repaired = await db.rehomeDeltaMessage(
        deltaMsgId: status.id,
        deltaAccountId: _deltaAccountId,
        deltaChatId: resolvedChatId,
        chatJid: resolvedChat.jid,
        senderJid: existing.senderJid,
        selfJid: _xmppSelfJid,
        emailSelfJid: _selfJid,
      );
      if (repaired == null) {
        return (
          hydration: null,
          result: 'staleLocatorUnrepaired',
          resolvedChatId: resolvedChatId,
        );
      }
      existing = repaired;
    }
    final next = _mergeDeltaMessageStatus(existing: existing, status: status);
    final update = await _persistStatusOnlyStatusUpdate(
      db: db,
      existing: existing,
      next: next,
      status: status,
    );
    return (
      hydration: _DeltaStatusHydrationResult(
        status: status,
        repairedUnread: update.repairedUnread,
        unreadStateResolved: true,
        updatedFields: update.updatedFields,
      ),
      result: update.updatedFields.isEmpty
          ? 'statusNoDiff'
          : update.repairedUnread
          ? 'statusRepairedUnread'
          : 'statusUpdated',
      resolvedChatId: resolvedChatId,
    );
  }

  Future<_DeltaStatusHydrationResult?> _hydrateMessageStatus(
    int chatId,
    int msgId, {
    int? expectedChatId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final status = await _core.getMessageStatus(msgId);
    if (status == null) {
      SafeLogging.profileTrace(
        'email.deltaHydrateMessageStatus',
        'end',
        fields: <String, Object?>{
          'chatId': chatId,
          'msgId': msgId,
          'result': 'missingCoreMessage',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return null;
    }
    final applied = await _applyDeltaMessageStatus(
      eventChatId: chatId,
      status: status,
      expectedChatId: expectedChatId,
    );
    SafeLogging.profileTrace(
      'email.deltaHydrateMessageStatus',
      'end',
      fields: <String, Object?>{
        'chatId': chatId,
        'msgId': msgId,
        'result': applied.result,
        'resolvedChatId': applied.resolvedChatId,
        'updatedFieldCount': applied.hydration?.updatedFields.length,
        'updatedFieldHash': applied.hydration == null
            ? null
            : _messageDiffProfileHash(applied.hydration!.updatedFields),
        'repairedUnread': applied.hydration?.repairedUnread,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return applied.hydration;
  }

  Future<List<_DeltaStatusHydrationResult>> _hydrateMessageStatuses(
    int chatId,
    Iterable<int> msgIds, {
    int? expectedChatId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final ids = <int>[];
    final seenIds = <int>{};
    for (final msgId in msgIds) {
      if (msgId <= _deltaMessageIdUnset || _isDeltaMessageMarkerId(msgId)) {
        continue;
      }
      if (seenIds.add(msgId)) {
        ids.add(msgId);
      }
    }
    if (ids.isEmpty) {
      return const <_DeltaStatusHydrationResult>[];
    }
    final statuses = await _core.getMessageStatuses(ids);
    final hydrations = <_DeltaStatusHydrationResult>[];
    var skippedCount = 0;
    for (final status in statuses) {
      final applied = await _applyDeltaMessageStatus(
        eventChatId: chatId,
        status: status,
        expectedChatId: expectedChatId,
      );
      final hydration = applied.hydration;
      if (hydration == null) {
        skippedCount += 1;
        continue;
      }
      hydrations.add(hydration);
    }
    SafeLogging.profileTrace(
      'email.deltaHydrateMessageStatuses',
      'end',
      fields: <String, Object?>{
        'chatId': chatId,
        'requestedCount': ids.length,
        'statusCount': statuses.length,
        'hydratedCount': hydrations.length,
        'skippedCount': skippedCount,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return hydrations;
  }

  Future<DeltaHydrationResult?> _hydrateMessage(
    int chatId,
    int msgId, {
    required String source,
    bool statusOnly = false,
    int? expectedChatId,
  }) async {
    final stopwatch = Stopwatch()..start();
    var coreGetMs = 0;
    final msg = await _timedDeltaTraceStep(
      () => _core.getMessage(msgId),
      (elapsedMs) => coreGetMs = elapsedMs,
    );
    if (msg == null) {
      SafeLogging.profileTrace(
        'email.deltaHydrateMessage',
        'end',
        fields: <String, Object?>{
          'chatId': chatId,
          'msgId': msgId,
          'source': source,
          'statusOnly': statusOnly,
          'result': 'missingCoreMessage',
          'coreGetMs': coreGetMs,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return null;
    }
    if (expectedChatId != null) {
      final resolvedChatId = msg.chatId > 0 ? msg.chatId : chatId;
      if (resolvedChatId != expectedChatId) {
        SafeLogging.profileTrace(
          'email.deltaHydrateMessage',
          'end',
          fields: <String, Object?>{
            'chatId': chatId,
            'msgId': msgId,
            'source': source,
            'statusOnly': statusOnly,
            'result': 'chatMismatch',
            'expectedChatId': expectedChatId,
            'actualChatId': resolvedChatId,
            'coreGetMs': coreGetMs,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return null;
      }
    }
    var ingestMs = 0;
    final outcome = await _timedDeltaTraceStep(
      () => _ingestDeltaMessage(
        eventChatId: chatId,
        msg: msg,
        source: source,
        statusOnly: statusOnly,
      ),
      (elapsedMs) => ingestMs = elapsedMs,
    );
    SafeLogging.profileTrace(
      'email.deltaHydrateMessage',
      'end',
      fields: <String, Object?>{
        'chatId': chatId,
        'msgId': msgId,
        'source': source,
        'statusOnly': statusOnly,
        'result': 'ingested',
        'repairedUnread': outcome.repairedUnread,
        'unreadStateResolved': outcome.unreadStateResolved,
        'dbChange': outcome.saveResult?.change.name,
        'unreadDelta': outcome.saveResult?.unreadDelta,
        'summaryChanged': outcome.saveResult?.chatSummaryChanged,
        'coreGetMs': coreGetMs,
        'ingestMs': ingestMs,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return DeltaHydrationResult(
      message: msg,
      repairedUnread: outcome.repairedUnread,
      unreadStateResolved: outcome.unreadStateResolved,
      affectsUserChat: outcome.affectsUserChat,
      changedLocalProjection: outcome.changedLocalProjection,
      chatJid: outcome.chatJid,
      saveResult: outcome.saveResult,
    );
  }

  Future<void> _refreshSummaryForHydrationResult(
    DeltaHydrationResult? result,
  ) async {
    if (result == null || !result.affectsUserChat) {
      return;
    }
    final chatJid = result.chatJid?.trim();
    if (chatJid == null || chatJid.isEmpty) {
      return;
    }
    await _refreshStoredChatSummary(chatJid: chatJid);
  }

  Future<void> _handleMessagesChanged(int chatId, int msgId) async {
    if (msgId > _deltaMessageIdUnset) {
      if (_isDeltaMessageMarkerId(msgId)) {
        return;
      }
      await _refreshSummaryForHydrationResult(
        await _hydrateMessage(chatId, msgId, source: 'msgsChanged'),
      );
      return;
    }
    if (chatId == DeltaChatId.none) {
      await refreshChatlistSnapshot();
      return;
    }
    if (chatId <= _deltaChatLastSpecialId) {
      return;
    }
    await _syncChatFromCore(chatId);
  }

  Future<void> _handleReactionsChanged(int chatId, int msgId) async {
    if (msgId <= _deltaMessageIdUnset || _isDeltaMessageMarkerId(msgId)) {
      return;
    }
    await _refreshSummaryForHydrationResult(
      await _hydrateMessage(chatId, msgId, source: 'reactionsChanged'),
    );
  }

  Future<void> _handleIncomingMessage(int chatId, int msgId) async {
    final stopwatch = Stopwatch()..start();
    var result = 'completed';
    var hydrated = false;
    var repairedUnreadInHydrate = false;
    var unreadStateResolved = false;
    var fallbackUnreadRepair = false;
    var fallbackUnreadRepairReason = 'none';
    void traceEnd() {
      SafeLogging.profileTrace(
        'email.deltaIncomingMessage',
        'end',
        fields: <String, Object?>{
          'chatId': chatId,
          'msgId': msgId,
          'result': result,
          'hydrated': hydrated,
          'repairedUnreadInHydrate': repairedUnreadInHydrate,
          'unreadStateResolved': unreadStateResolved,
          'fallbackUnreadRepair': fallbackUnreadRepair,
          'fallbackUnreadRepairReason': fallbackUnreadRepairReason,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    }

    if (msgId <= _deltaMessageIdUnset) {
      await _handleMessagesChanged(chatId, msgId);
      result = 'messagesChangedFallback';
      traceEnd();
      return;
    }
    if (_isDeltaMessageMarkerId(msgId)) {
      result = 'marker';
      traceEnd();
      return;
    }
    final hydrationResult = await _hydrateMessage(
      chatId,
      msgId,
      source: 'incomingMsg',
    );
    hydrated = hydrationResult != null;
    repairedUnreadInHydrate = hydrationResult?.repairedUnread ?? false;
    unreadStateResolved = hydrationResult?.unreadStateResolved ?? false;
    if (hydrationResult == null) {
      result = 'hydrateMissing';
      traceEnd();
      return;
    }
    await _refreshSummaryForHydrationResult(hydrationResult);
    if (!hydrationResult.unreadStateResolved) {
      await _updateUnreadCount(chatId);
      fallbackUnreadRepair = true;
      fallbackUnreadRepairReason = 'unresolvedHydration';
    }
    traceEnd();
  }

  Future<void> _handleMessageStateChanged(int chatId, int msgId) async {
    if (msgId <= _deltaMessageIdUnset) {
      return;
    }
    if (_isDeltaMessageMarkerId(msgId)) {
      return;
    }
    final result = await _hydrateMessageStatus(chatId, msgId);
    if (result == null) {
      final hydrationResult = await _hydrateMessage(
        chatId,
        msgId,
        source: 'messageStateChangedFallback',
      );
      if (hydrationResult == null) {
        return;
      }
      await _refreshSummaryForHydrationResult(hydrationResult);
      if (hydrationResult.message.isOutgoing) {
        return;
      }
      if (!hydrationResult.unreadStateResolved) {
        await _updateUnreadCount(chatId);
      }
      return;
    }
    if (result.status.isOutgoing) {
      return;
    }
    if (!result.unreadStateResolved) {
      await _updateUnreadCount(chatId);
    }
  }

  Future<void> _handleMessagesNoticed(int chatId) async {
    if (chatId <= _deltaChatLastSpecialId) {
      return;
    }
  }

  Future<void> _handleChatDeleted(int chatId) async {
    if (chatId <= _deltaChatLastSpecialId) {
      return;
    }
    final db = await _db();
    final int deltaAccountId = _deltaAccountId;
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: deltaAccountId,
    );
    if (chat == null) return;
    await db.deleteEmailChatAccount(
      chatJid: chat.jid,
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
    );
    await _repairActiveDeltaChatReference(
      chatJid: chat.jid,
      removedDeltaChatId: chatId,
      db: db,
    );
    if (await _canRemoveDetachedEmailChat(db: db, chat: chat)) {
      await db.removeChat(chat.jid);
    }
  }

  Future<bool> _canRemoveDetachedEmailChat({
    required XmppDatabase db,
    required Chat chat,
  }) async {
    if (!chat.defaultTransport.isEmail) {
      return false;
    }
    if (await db.countEmailChatAccounts(chat.jid) > 0) {
      return false;
    }
    return !await db.hasDisplayableMessagesForChat(chat.jid);
  }

  Future<void> _repairActiveDeltaChatReference({
    required String chatJid,
    required int removedDeltaChatId,
    required XmppDatabase db,
  }) async {
    final chat = await db.getChat(chatJid);
    if (chat == null || chat.deltaChatId != removedDeltaChatId) {
      return;
    }
    final remainingDeltaChatIds = await db.getDeltaChatIdsForAccount(
      chatJid: chatJid,
      deltaAccountId: _deltaAccountId,
    );
    final nextDeltaChatId = remainingDeltaChatIds.firstOrNull;
    if (nextDeltaChatId == null) {
      await db.clearChatDeltaChatId(chat.jid);
      return;
    }
    await db.updateChat(chat.copyWith(deltaChatId: nextDeltaChatId));
  }

  Future<void> _updateUnreadCount(int chatId) async {
    final stopwatch = Stopwatch()..start();
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (chat == null) {
      SafeLogging.profileTrace(
        'email.deltaUnreadRepair',
        'skip',
        fields: <String, Object?>{
          'chatId': chatId,
          'reason': 'missingChat',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return;
    }
    await db.repairUnreadCountForChat(
      chat.jid,
      selfJid: _xmppSelfJid,
      emailSelfJid: _selfJid,
    );
    SafeLogging.profileTrace(
      'email.deltaUnreadRepair',
      'end',
      fields: <String, Object?>{
        'chatId': chatId,
        'chatHash': SafeLogging.profileFingerprint(chat.jid.trim()),
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
  }

  Future<void> _syncChatMessages(int chatId) async {
    if (await _isDeltaSystemChat(chatId)) {
      return;
    }
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (chat == null) {
      return;
    }
    final projectedFreshMessages = await _syncFreshMessagesForChat(
      chatId: chatId,
    );
    SafeLogging.profileTrace(
      'email.deltaSyncChatMessages',
      'decision',
      fields: <String, Object?>{
        'chatId': chatId,
        'chatHash': SafeLogging.profileFingerprint(chat.jid.trim()),
        'projectedFreshMessages': projectedFreshMessages,
      },
    );
  }

  Future<void> _syncChatFromCore(int chatId) async {
    if (chatId <= _deltaChatLastSpecialId) {
      return;
    }
    await _syncChatMessages(chatId);
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (chat != null) {
      await _refreshStoredChatSummary(chatJid: chat.jid, db: db);
    }
    await _refreshChat(chatId);
    await _updateUnreadCount(chatId);
    await _refreshArchivedState(chatId);
  }

  Future<DeltaHydrationResult?> hydrateMessage(
    int msgId, {
    bool deferRfc822BodyContent = false,
  }) async {
    final msg = await _core.getMessage(msgId);
    if (msg == null) return null;
    final outcome = await _ingestDeltaMessage(
      eventChatId: msg.chatId,
      msg: msg,
      source: 'manualHydrate',
      deferRfc822BodyContent: deferRfc822BodyContent,
    );
    return DeltaHydrationResult(
      message: msg,
      repairedUnread: outcome.repairedUnread,
      unreadStateResolved: outcome.unreadStateResolved,
      affectsUserChat: outcome.affectsUserChat,
      changedLocalProjection: outcome.changedLocalProjection,
      chatJid: outcome.chatJid,
      saveResult: outcome.saveResult,
    );
  }

  Future<DeltaFreshSyncResult> syncFreshMessages(
    Iterable<int> messageIds, {
    bool Function()? isCurrent,
  }) async {
    bool cancelled() => isCurrent?.call() == false;
    final stopwatch = Stopwatch()..start();
    final freshIds = <int>[];
    final seenIds = <int>{};
    for (final messageId in messageIds) {
      if (messageId <= _deltaMessageIdUnset ||
          _isDeltaMessageMarkerId(messageId)) {
        continue;
      }
      if (seenIds.add(messageId)) {
        freshIds.add(messageId);
      }
    }
    if (freshIds.isEmpty) {
      SafeLogging.profileTrace(
        'email.deltaSyncFreshMessages',
        'end',
        fields: <String, Object?>{
          'accountId': _deltaAccountId,
          'freshIdCount': 0,
          'hydratedCount': 0,
          'affectedChatCount': 0,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return const DeltaFreshSyncResult();
    }

    final affectedChatIds = <int>{};
    final db = await _db();
    final storedByDeltaId = <int, Message>{};
    for (final message in await db.getMessagesByDeltaIds(
      freshIds,
      deltaAccountId: _deltaAccountId,
    )) {
      final deltaMsgId = message.deltaMsgId;
      if (deltaMsgId != null) {
        storedByDeltaId.putIfAbsent(deltaMsgId, () => message);
      }
    }
    final existingFileMetadataIds = await _existingFreshFileMetadataIds(
      db: db,
      messages: storedByDeltaId.values,
    );
    var storedExactCount = 0;
    var storedMissingContentCount = 0;
    final idsToHydrate = <int>[];
    for (final freshId in freshIds) {
      final stored = storedByDeltaId[freshId];
      if (stored == null) {
        idsToHydrate.add(freshId);
        continue;
      }
      if (!_hasLocallyCompleteDeltaProjection(
        message: stored,
        existingFileMetadataIds: existingFileMetadataIds,
      )) {
        storedMissingContentCount += 1;
        idsToHydrate.add(freshId);
        continue;
      }
      storedExactCount += 1;
      final deltaChatId = stored.deltaChatId;
      if (deltaChatId != null && deltaChatId > _deltaChatLastSpecialId) {
        affectedChatIds.add(deltaChatId);
      }
    }

    var hydratedCount = 0;
    var ignoredFreshCount = 0;
    const int batchSize = 32;
    for (var index = 0; index < idsToHydrate.length; index += batchSize) {
      if (cancelled()) {
        break;
      }
      final end = index + batchSize > idsToHydrate.length
          ? idsToHydrate.length
          : index + batchSize;
      final messages = await _core.getMessages(
        idsToHydrate.sublist(index, end),
      );
      if (cancelled()) {
        break;
      }
      for (final msg in messages) {
        if (msg.id <= _deltaMessageIdUnset || _isDeltaMessageMarkerId(msg.id)) {
          continue;
        }
        final chatId = msg.chatId;
        final outcome = await _ingestDeltaMessage(
          eventChatId: chatId,
          msg: msg,
          source: 'freshProjection',
        );
        if (outcome.ignoredFreshProjection) {
          ignoredFreshCount += 1;
        }
        if (outcome.changedLocalProjection) {
          hydratedCount += 1;
        }
        if (outcome.affectsUserChat && chatId > _deltaChatLastSpecialId) {
          affectedChatIds.add(chatId);
        }
      }
    }

    for (final chatId in affectedChatIds) {
      if (cancelled()) {
        break;
      }
      final db = await _db();
      final chat = await db.getChatByDeltaChatId(
        chatId,
        accountId: _deltaAccountId,
      );
      if (chat != null) {
        await _refreshStoredChatSummary(chatJid: chat.jid, db: db);
      }
      await _refreshChat(chatId);
      await _updateUnreadCount(chatId);
      await _refreshArchivedState(chatId);
    }
    SafeLogging.profileTrace(
      'email.deltaSyncFreshMessages',
      'end',
      fields: <String, Object?>{
        'accountId': _deltaAccountId,
        'freshIdCount': freshIds.length,
        'storedExactCount': storedExactCount,
        'storedMissingContentCount': storedMissingContentCount,
        'hydratedCount': hydratedCount,
        'ignoredFreshCount': ignoredFreshCount,
        'affectedChatCount': affectedChatIds.length,
        'cancelled': cancelled(),
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return DeltaFreshSyncResult(
      freshIdCount: freshIds.length,
      storedExactCount: storedExactCount,
      storedMissingContentCount: storedMissingContentCount,
      hydratedCount: hydratedCount,
      affectedChatCount: affectedChatIds.length,
      cancelled: cancelled(),
    );
  }

  Future<void> recoverOutgoingMessageStatuses({
    int limit = 100,
    Duration window = const Duration(hours: 48),
  }) async {
    final selfJid = _selfJid;
    if (selfJid.isEmpty) {
      return;
    }
    final db = await _db();
    final messages = await db.getRecoverableOutgoingDeltaMessages(
      deltaAccountId: _deltaAccountId,
      senderJid: selfJid,
      since: DateTime.timestamp().subtract(window),
      limit: limit,
    );
    final messageIdsByChat = <int, List<int>>{};
    for (final message in messages) {
      final msgId = message.deltaMsgId;
      final chatId = message.deltaChatId;
      if (msgId == null || chatId == null) {
        continue;
      }
      messageIdsByChat.putIfAbsent(chatId, () => <int>[]).add(msgId);
    }
    for (final entry in messageIdsByChat.entries) {
      await _hydrateMessageStatuses(
        entry.key,
        entry.value,
        expectedChatId: entry.key,
      );
    }
  }

  Future<_DeltaIngestOutcome> _ingestDeltaMessage({
    required int eventChatId,
    required DeltaMessage msg,
    required String source,
    Chat? chat,
    bool skipSystemChatCheck = false,
    bool statusOnly = false,
    bool deferRfc822BodyContent = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final timing = _DeltaIngestTiming();
    var result = 'completed';
    var repairedUnread = false;
    var unreadStateResolved = false;
    MessageSaveResult? saveResult;
    var resolvedChatHash = '';
    String? resolvedChatJid;
    var existingState = 'unknown';
    _DeltaIngestOutcome outcome({
      bool repairedUnread = false,
      bool unreadStateResolved = false,
      bool ignoredFreshProjection = false,
      bool affectsUserChat = false,
      bool changedLocalProjection = false,
      String? chatJid,
      MessageSaveResult? saveResult,
    }) {
      return _DeltaIngestOutcome(
        repairedUnread: repairedUnread,
        unreadStateResolved: unreadStateResolved,
        ignoredFreshProjection: ignoredFreshProjection,
        affectsUserChat: affectsUserChat,
        changedLocalProjection: changedLocalProjection,
        chatJid: chatJid ?? resolvedChatJid,
        saveResult: saveResult,
      );
    }

    try {
      final int deltaAccountId = _deltaAccountId;
      final int chatId = msg.chatId > 0 ? msg.chatId : eventChatId;
      if (chatId != eventChatId) {
        chat = null;
      }
      if (!skipSystemChatCheck &&
          await _timedDeltaTraceStep(
            () => _isDeltaSystemChat(chatId),
            (elapsedMs) => timing.systemChatMs += elapsedMs,
          )) {
        _log.finer(
          'Dropping Delta system-chat message msgId=${msg.id} chatId=$chatId',
        );
        result = 'systemChat';
        unreadStateResolved = true;
        return outcome(
          unreadStateResolved: unreadStateResolved,
          ignoredFreshProjection: true,
        );
      }
      final Chat resolvedChat;
      var changedChatMapping = false;
      if (chat != null) {
        resolvedChat = chat;
      } else {
        final ensureResult = await _timedDeltaTraceStep(
          () => _ensureChatWithResult(chatId),
          (elapsedMs) => timing.ensureChatMs += elapsedMs,
        );
        resolvedChat = ensureResult.chat;
        changedChatMapping = ensureResult.changedMapping;
      }
      resolvedChatHash = SafeLogging.profileFingerprint(
        resolvedChat.jid.trim(),
      );
      resolvedChatJid = resolvedChat.jid;
      if (_timedDeltaTraceStepSync(
        () => _isHiddenMultiDeviceSyncMessage(msg, chat: resolvedChat),
        (elapsedMs) => timing.hiddenSyncCheckMs += elapsedMs,
      )) {
        _log.finer(
          'Dropping Multi Device Synchronization placeholder message '
          'msgId=${msg.id} chatId=$chatId',
        );
        result = 'hiddenMultiDeviceSync';
        unreadStateResolved = true;
        return outcome(
          unreadStateResolved: unreadStateResolved,
          ignoredFreshProjection: !changedChatMapping,
          affectsUserChat: changedChatMapping,
        );
      }
      final db = await _timedDeltaTraceStep(
        _db,
        (elapsedMs) => timing.databaseMs += elapsedMs,
      );
      if (msg.isEncryptionStatusSystemMessage) {
        await _timedDeltaTraceStep(
          () => db.ensureEmailEncryptionStatusMarkerForChat(resolvedChat.jid),
          (elapsedMs) => timing.encryptionStatusMarkerMs += elapsedMs,
        );
        result = 'encryptionStatusMarker';
        unreadStateResolved = true;
        return outcome(
          unreadStateResolved: unreadStateResolved,
          affectsUserChat: true,
          changedLocalProjection: true,
        );
      }
      final stanzaId = _emailRowKey();
      var existingByDeltaId = await _timedDeltaTraceStep(
        () => db.recoverStaleDeltaMessageLocator(
          deltaMsgId: msg.id,
          deltaAccountId: deltaAccountId,
          deltaChatId: chatId,
          chatJid: resolvedChat.jid,
        ),
        (elapsedMs) => timing.locatorRecoveryMs += elapsedMs,
      );
      if (existingByDeltaId != null &&
          !_storedDeltaLocatorMatches(
            existingByDeltaId,
            msgId: msg.id,
            chatId: chatId,
            accountId: deltaAccountId,
            chatJid: resolvedChat.jid,
          )) {
        _log.fine(
          'Re-homing Delta message to its current core chat. '
          'msgId=${msg.id} chatId=$chatId accountId=$deltaAccountId '
          'existingStanza=${existingByDeltaId.stanzaID} '
          'existingChat=${existingByDeltaId.chatJid} '
          'existingDeltaChat=${existingByDeltaId.deltaChatId}.',
        );
        final rehomedDeltaMessage = await _timedDeltaTraceStep<Message?>(
          () => db.rehomeDeltaMessage(
            deltaMsgId: msg.id,
            deltaAccountId: deltaAccountId,
            deltaChatId: chatId,
            chatJid: resolvedChat.jid,
            senderJid: msg.isOutgoing
                ? _resolveOutgoingSenderJid(resolvedChat)
                : resolvedChat.jid,
            selfJid: _xmppSelfJid,
            emailSelfJid: _selfJid,
          ),
          (elapsedMs) => timing.locatorRehomeMs += elapsedMs,
        );
        existingByDeltaId = rehomedDeltaMessage;
      }
      if (existingByDeltaId != null) {
        existingState = 'existing';
        final existing = existingByDeltaId;
        await _timedDeltaTraceStep(
          () => _logEmailPartDiagnostic(
            stage: 'ingest-existing-delta',
            eventChatId: chatId,
            msg: msg,
            resolvedChat: resolvedChat,
            existingByDelta: existing,
            storedMessage: existing,
          ),
          (elapsedMs) => timing.existingDiagnosticMs += elapsedMs,
        );
        final update = await _timedDeltaTraceStep(
          () => _updateExistingMessage(
            existing: existing,
            msg: msg,
            statusOnly: statusOnly,
            deferRfc822BodyContent: deferRfc822BodyContent,
          ),
          (elapsedMs) => timing.existingUpdateMs += elapsedMs,
        );
        repairedUnread = update.repairedUnread;
        final hydrationId = _DeltaChatJidMessageId(
          accountId: deltaAccountId,
          chatId: chatId,
          chatJid: resolvedChat.jid,
          msgId: msg.id,
        );
        fireAndForget(
          () => _scheduleOriginIdHydrationIfNeeded(
            existing: existing,
            id: hydrationId,
          ),
          operationName: 'DeltaEventConsumer.scheduleOriginIdHydration',
        );
        if (!msg.isOutgoing) {
          await _timedDeltaTraceStep(
            () => _learnAutocryptContactKeyForIncomingMessage(
              db: db,
              chat: resolvedChat,
              msg: msg,
            ),
            (elapsedMs) => timing.existingAutocryptMs += elapsedMs,
          );
        }
        result = repairedUnread ? 'existingRepairedUnread' : 'existingUpdated';
        unreadStateResolved = true;
        return outcome(
          repairedUnread: repairedUnread,
          unreadStateResolved: unreadStateResolved,
          affectsUserChat: true,
          changedLocalProjection: update.changedLocalProjection,
        );
      }
      existingState = 'new';
      final String? nativeOriginId = await _timedDeltaTraceStep(
        () => _resolveNativeOriginId(msg),
        (elapsedMs) => timing.originIdMs += elapsedMs,
      );
      final timestamp = msg.timestamp ?? DateTime.timestamp();
      final isOutgoing = msg.isOutgoing;
      final senderJid = isOutgoing
          ? _resolveOutgoingSenderJid(resolvedChat)
          : resolvedChat.jid;
      final emailAddress = resolvedChat.emailAddress?.toLowerCase();
      if (!isOutgoing && emailAddress != null && emailAddress.isNotEmpty) {
        final blocked = await _timedDeltaTraceStep(
          () => db.isEmailAddressBlocked(emailAddress),
          (elapsedMs) => timing.blocklistMs += elapsedMs,
        );
        if (blocked) {
          await _timedDeltaTraceStep(
            () => db.incrementEmailBlockCount(emailAddress),
            (elapsedMs) => timing.blocklistMs += elapsedMs,
          );
          result = 'blockedAddress';
          unreadStateResolved = true;
          return outcome(
            unreadStateResolved: unreadStateResolved,
            affectsUserChat: true,
            changedLocalProjection: true,
          );
        }
      }
      var warning = MessageWarning.none;
      if (!isOutgoing && emailAddress != null && emailAddress.isNotEmpty) {
        final spam = await _timedDeltaTraceStep(
          () => db.isEmailAddressSpam(emailAddress),
          (elapsedMs) => timing.spamCheckMs += elapsedMs,
        );
        if (spam) {
          warning = MessageWarning.emailSpamQuarantined;
          await _timedDeltaTraceStep(
            () => db.markEmailChatsSpam(
              address: emailAddress,
              spam: true,
              spamUpdatedAt: timestamp,
            ),
            (elapsedMs) => timing.spamCheckMs += elapsedMs,
          );
          await _timedDeltaTraceStep(
            () => db.markChatSpam(
              jid: resolvedChat.jid,
              spam: true,
              spamUpdatedAt: timestamp,
            ),
            (elapsedMs) => timing.spamCheckMs += elapsedMs,
          );
        }
      }
      final deliveryStatus = msg.deliveryStatus;
      final resolvedError = _messageErrorForDelta(msg);
      var message = Message(
        stanzaID: stanzaId,
        senderJid: senderJid,
        chatJid: resolvedChat.jid,
        timestamp: timestamp,
        originID: nativeOriginId,
        error: resolvedError,
        warning: warning,
        encryptionProtocol: _encryptionProtocolForDelta(msg),
        received: deliveryStatus.received,
        acked: deliveryStatus.acked,
        displayed: deliveryStatus.displayed,
        deltaSeenSynced: msg.isIncomingSeen,
        deltaAccountId: deltaAccountId,
        deltaChatId: chatId,
        deltaMsgId: msg.id,
      );
      message = await _timedDeltaTraceStep(
        () => _buildDeltaMessageContent(
          db: db,
          message: message,
          chatId: chatId,
          msg: msg,
          deferRfc822BodyContent: deferRfc822BodyContent,
          timing: timing.content,
        ),
        (elapsedMs) => timing.contentMs += elapsedMs,
      );
      if (isOutgoing) {
        message = await _timedDeltaTraceStep(
          () => _withReconstructedQuote(
            db: db,
            message: message,
            msg: msg,
            deltaAccountId: deltaAccountId,
            chatId: chatId,
          ),
          (elapsedMs) => timing.quoteMs += elapsedMs,
        );
      }
      await _timedDeltaTraceStep(
        () => _logEmailPartDiagnostic(
          stage: 'ingest-new-before-store',
          eventChatId: chatId,
          msg: msg,
          resolvedChat: resolvedChat,
          storedMessage: message,
          resolvedOriginId: nativeOriginId,
        ),
        (elapsedMs) => timing.newDiagnosticMs += elapsedMs,
      );
      saveResult = await _timedDeltaTraceStep(
        () => _storeMessage(db: db, message: message),
        (elapsedMs) => timing.storeMs += elapsedMs,
      );
      unreadStateResolved = true;
      await _timedDeltaTraceStep(
        () => _ensureEmailEncryptionStatusMarkerForMessage(
          db: db,
          message: message,
        ),
        (elapsedMs) => timing.encryptionMarkerMs += elapsedMs,
      );
      if (!isOutgoing) {
        await _timedDeltaTraceStep(
          () => _learnAutocryptContactKeyForIncomingMessage(
            db: db,
            chat: resolvedChat,
            msg: msg,
          ),
          (elapsedMs) => timing.autocryptMs += elapsedMs,
        );
      }
      result = 'storedNew';
      return outcome(
        unreadStateResolved: unreadStateResolved,
        affectsUserChat: true,
        changedLocalProjection: true,
        saveResult: saveResult,
      );
    } finally {
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final noDiffExisting =
          result == 'existingUpdated' &&
          existingState == 'existing' &&
          !repairedUnread;
      if (noDiffExisting) {
        _suppressedDeltaIngestNoopCount += 1;
        if (elapsedMs > _suppressedDeltaIngestNoopWorstMs) {
          _suppressedDeltaIngestNoopWorstMs = elapsedMs;
        }
        if (elapsedMs >= _deltaProfileTraceSlowThreshold.inMilliseconds ||
            _suppressedDeltaIngestNoopCount >=
                _deltaProfileTraceNoopBatchSize) {
          final suppressedNoop = _suppressedDeltaIngestNoopCount;
          final suppressedWorstMs = _suppressedDeltaIngestNoopWorstMs;
          _suppressedDeltaIngestNoopCount = 0;
          _suppressedDeltaIngestNoopWorstMs = 0;
          _traceDeltaIngestEnd(
            eventChatId: eventChatId,
            msg: msg,
            source: source,
            statusOnly: statusOnly,
            existingState: existingState,
            result: elapsedMs >= _deltaProfileTraceSlowThreshold.inMilliseconds
                ? result
                : 'noDiffBatch',
            repairedUnread: repairedUnread,
            unreadStateResolved: unreadStateResolved,
            saveResult: saveResult,
            chatHash: resolvedChatHash,
            suppressedNoop: suppressedNoop,
            suppressedWorstMs: suppressedWorstMs,
            elapsedMs: elapsedMs,
            timing: timing,
          );
        }
      } else {
        final suppressedNoop = _suppressedDeltaIngestNoopCount;
        final suppressedWorstMs = _suppressedDeltaIngestNoopWorstMs;
        _suppressedDeltaIngestNoopCount = 0;
        _suppressedDeltaIngestNoopWorstMs = 0;
        _traceDeltaIngestEnd(
          eventChatId: eventChatId,
          msg: msg,
          source: source,
          statusOnly: statusOnly,
          existingState: existingState,
          result: result,
          repairedUnread: repairedUnread,
          unreadStateResolved: unreadStateResolved,
          saveResult: saveResult,
          chatHash: resolvedChatHash,
          suppressedNoop: suppressedNoop,
          suppressedWorstMs: suppressedWorstMs,
          elapsedMs: elapsedMs,
          timing: timing,
        );
      }
    }
  }

  void _traceDeltaIngestEnd({
    required int eventChatId,
    required DeltaMessage msg,
    required String source,
    required bool statusOnly,
    required String existingState,
    required String result,
    required bool repairedUnread,
    required bool unreadStateResolved,
    MessageSaveResult? saveResult,
    required String chatHash,
    required int suppressedNoop,
    required int suppressedWorstMs,
    required int elapsedMs,
    required _DeltaIngestTiming timing,
  }) {
    SafeLogging.profileTrace(
      'email.deltaIngest',
      'end',
      fields: <String, Object?>{
        'eventChatId': eventChatId,
        'msgChatId': msg.chatId,
        'msgId': msg.id,
        'source': source,
        'statusOnly': statusOnly,
        'isOutgoing': msg.isOutgoing,
        'existingState': existingState,
        'result': result,
        'repairedUnread': repairedUnread,
        'unreadStateResolved': unreadStateResolved,
        'dbChange': saveResult?.change.name,
        'unreadDelta': saveResult?.unreadDelta,
        'summaryChanged': saveResult?.chatSummaryChanged,
        'chatHash': chatHash.isEmpty ? null : chatHash,
        'suppressedNoop': suppressedNoop,
        'worstSuppressedNoopMs': suppressedWorstMs,
        if (elapsedMs >= _deltaProfileTraceSlowThreshold.inMilliseconds)
          ...timing.toTraceFields(),
        'elapsedMs': elapsedMs,
      },
    );
  }

  Future<void> _logEmailPartDiagnostic({
    required String stage,
    required int eventChatId,
    required DeltaMessage msg,
    Chat? resolvedChat,
    Message? existingByStanza,
    Message? existingByDelta,
    Message? storedMessage,
    String? resolvedOriginId,
  }) async {
    if (!_log.isLoggable(Level.FINER)) {
      return;
    }
    final native = await _loadNativeEmailPartDiagnostics(msg.id);
    _log.log(
      Level.FINER,
      '$_emailPartDiagPrefix '
      'stage=${_diagnosticValue(stage)} '
      'accountId=$_deltaAccountId '
      'eventChatId=$eventChatId '
      'msgChatId=${msg.chatId} '
      'msgId=${msg.id} '
      'existingByStanza=${_diagnosticMessageSummary(existingByStanza)} '
      'existingByDelta=${_diagnosticMessageSummary(existingByDelta)} '
      'stored=${_diagnosticMessageSummary(storedMessage)} '
      'nativeRfc724Supported=${native.nativeRfc724Supported} '
      'nativeRfc724Mid=${_diagnosticStringStats(native.nativeRfc724Mid)} '
      'nativeInfoSupported=${native.nativeInfoSupported} '
      'parsedInfoMessageId=${_diagnosticStringStats(native.parsedInfoMessageId)} '
      'resolvedOriginId=${_diagnosticStringStats(resolvedOriginId)} '
      'resolvedChatJid=${_diagnosticStringStats(resolvedChat?.jid)} '
      'resolvedChatDeltaId=${resolvedChat?.deltaChatId} '
      'subject=${_diagnosticStringStats(msg.subject)} '
      'textLength=${msg.text?.length ?? 0} '
      'text=${_diagnosticStringStats(msg.text)} '
      'htmlPresent=${msg.html?.trim().isNotEmpty == true} '
      'htmlLength=${msg.html?.length ?? 0} '
      'html=${_diagnosticStringStats(msg.html)} '
      'hasFile=${msg.hasFile} '
      'fileName=${_diagnosticStringStats(msg.fileName)} '
      'fileMime=${_diagnosticStringStats(msg.fileMime)} '
      'fileSize=${msg.fileSize} '
      'filePathPresent=${msg.filePath?.trim().isNotEmpty == true} '
      'viewType=${msg.viewType} '
      'infoType=${msg.infoType} '
      'state=${msg.state} '
      'downloadState=${msg.downloadState} '
      'needsDownload=${msg.needsDownload} '
      'isOutgoing=${msg.isOutgoing}',
    );
  }

  Future<
    ({
      bool nativeRfc724Supported,
      String? nativeRfc724Mid,
      bool nativeInfoSupported,
      String? parsedInfoMessageId,
    })
  >
  _loadNativeEmailPartDiagnostics(int msgId) async {
    final nativeRfc724Supported = _core.supportsMessageRfc724Mid;
    final nativeInfoSupported = _core.supportsMessageInfo;
    String? nativeRfc724Mid;
    String? nativeInfo;
    try {
      nativeRfc724Mid = normalizeEmailMessageId(
        await _core.getMessageRfc724Mid(msgId),
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(
        '$_emailPartDiagPrefix stage="native-rfc724-error" msgId=$msgId',
        error,
        stackTrace,
      );
    }
    try {
      nativeInfo = await _core.getMessageInfo(msgId);
    } on Exception catch (error, stackTrace) {
      _log.fine(
        '$_emailPartDiagPrefix stage="native-info-error" msgId=$msgId',
        error,
        stackTrace,
      );
    }
    final parsedInfoMessageId = parseDeltaMessageInfoMessageId(nativeInfo);
    return (
      nativeRfc724Supported: nativeRfc724Supported,
      nativeRfc724Mid: nativeRfc724Mid,
      nativeInfoSupported: nativeInfoSupported,
      parsedInfoMessageId: parsedInfoMessageId,
    );
  }

  void _logEmailUpdateDiffDiagnostic({
    required String updateSummary,
    required Message existing,
    required Message next,
    required DeltaMessage msg,
    required List<MessageDiffField> updatedFields,
  }) {
    if (!_log.isLoggable(Level.FINER)) {
      return;
    }
    final shouldLog =
        updatedFields.contains(MessageDiffField.body) ||
        updatedFields.contains(MessageDiffField.subject) ||
        updatedFields.contains(MessageDiffField.timestamp) ||
        updatedFields.contains(MessageDiffField.originId) ||
        updatedFields.contains(MessageDiffField.fileMetadataId);
    if (!shouldLog) {
      return;
    }
    _log.log(
      Level.FINER,
      '$_emailUpdateDiffDiagPrefix '
      'summary=${_diagnosticValue(updateSummary)} '
      'msgId=${msg.id} '
      'msgChatId=${msg.chatId} '
      'stanzaId=${_diagnosticValue(existing.stanzaID)} '
      'oldOriginId=${_diagnosticStringStats(existing.originID)} '
      'newOriginId=${_diagnosticStringStats(next.originID)} '
      'oldSubject=${_diagnosticStringStats(existing.subject)} '
      'newSubject=${_diagnosticStringStats(next.subject)} '
      'oldTimestamp=${_diagnosticValue(existing.timestamp)} '
      'newTimestamp=${_diagnosticValue(next.timestamp)} '
      'oldBodyLength=${existing.body?.length ?? 0} '
      'newBodyLength=${next.body?.length ?? 0} '
      'oldBody=${_diagnosticStringStats(existing.body)} '
      'newBody=${_diagnosticStringStats(next.body)} '
      'oldHtmlLength=${existing.htmlBody?.length ?? 0} '
      'newHtmlLength=${next.htmlBody?.length ?? 0} '
      'oldHtml=${_diagnosticStringStats(existing.htmlBody)} '
      'newHtml=${_diagnosticStringStats(next.htmlBody)} '
      'oldFileMetadataId=${_diagnosticValue(existing.fileMetadataID)} '
      'newFileMetadataId=${_diagnosticValue(next.fileMetadataID)} '
      'deltaSubject=${_diagnosticStringStats(msg.subject)} '
      'deltaTextLength=${msg.text?.length ?? 0} '
      'deltaText=${_diagnosticStringStats(msg.text)} '
      'deltaHtmlPresent=${msg.html?.trim().isNotEmpty == true} '
      'deltaHtmlLength=${msg.html?.length ?? 0} '
      'deltaHtml=${_diagnosticStringStats(msg.html)} '
      'deltaHasFile=${msg.hasFile} '
      'deltaFileName=${_diagnosticStringStats(msg.fileName)} '
      'deltaDownloadState=${msg.downloadState} '
      'deltaNeedsDownload=${msg.needsDownload}',
    );
  }

  Future<void> _logOriginResolutionDiagnostic({
    required int msgId,
    required String source,
    required bool nativeRfc724Supported,
    required String? nativeRfc724Mid,
    required bool nativeInfoSupported,
    required String? parsedInfoMessageId,
    required String? mimeHeaders,
    required String? parsedHeaderMessageId,
  }) async {
    if (!_log.isLoggable(Level.FINER)) {
      return;
    }
    _log.log(
      Level.FINER,
      '$_emailPartDiagPrefix '
      'stage="origin-resolution" '
      'msgId=$msgId '
      'source=${_diagnosticValue(source)} '
      'nativeRfc724Supported=$nativeRfc724Supported '
      'nativeRfc724Mid=${_diagnosticStringStats(nativeRfc724Mid)} '
      'nativeInfoSupported=$nativeInfoSupported '
      'parsedInfoMessageId=${_diagnosticStringStats(parsedInfoMessageId)} '
      'mimeHeadersPresent=${mimeHeaders?.trim().isNotEmpty == true} '
      'mimeHeadersLength=${mimeHeaders?.length ?? 0} '
      'parsedHeaderMessageId=${_diagnosticStringStats(parsedHeaderMessageId)}',
    );
  }

  String _diagnosticMessageSummary(Message? message) {
    if (message == null) {
      return 'null';
    }
    return '{'
        'stanzaId:${_diagnosticValue(message.stanzaID)},'
        'originId:${_diagnosticStringStats(message.originID)},'
        'senderJid:${_diagnosticStringStats(message.senderJid)},'
        'chatJid:${_diagnosticStringStats(message.chatJid)},'
        'deltaAccountId:${message.deltaAccountId},'
        'deltaChatId:${message.deltaChatId},'
        'deltaMsgId:${message.deltaMsgId},'
        'subject:${_diagnosticStringStats(message.subject)},'
        'bodyLength:${message.body?.length ?? 0},'
        'body:${_diagnosticStringStats(message.body)},'
        'htmlLength:${message.htmlBody?.length ?? 0},'
        'html:${_diagnosticStringStats(message.htmlBody)},'
        'fileMetadataId:${_diagnosticValue(message.fileMetadataID)},'
        'timestamp:${_diagnosticValue(message.timestamp)},'
        'received:${message.received},'
        'displayed:${message.displayed}'
        '}';
  }

  String _diagnosticStringStats(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'null';
    }
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    return '{'
        'len:${normalized.length},'
        'kind:${_diagnosticValue(_diagnosticStringKind(normalized))},'
        'hash:${_diagnosticValue(_diagnosticFingerprint(normalized))}'
        '}';
  }

  String _diagnosticStringKind(String value) {
    if (value.startsWith('Date: ') && value.contains(' Subject: ')) {
      return 'forwarded-header';
    }
    if (value.startsWith('<') && value.endsWith('>')) {
      return 'message-id';
    }
    return 'text';
  }

  String _diagnosticFingerprint(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _diagnosticValue(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is DateTime) {
      return jsonEncode(value.toIso8601String());
    }
    return jsonEncode(value.toString());
  }

  Future<void> _learnAutocryptContactKeyForIncomingMessage({
    required XmppDatabase db,
    required Chat chat,
    required DeltaMessage msg,
  }) async {
    final selfAddress = normalizedAddressValue(_selfJid);
    if (selfAddress == null ||
        _emailEncryptionBetaEnabledForAddress?.call(
              _deltaAccountId,
              selfAddress,
            ) !=
            true) {
      return;
    }
    final contactAddress = normalizedAddressValue(
      chat.emailAddress ?? chat.contactJid ?? chat.jid,
    );
    if (contactAddress == null || contactAddress.isEmpty) {
      return;
    }
    final headers = await _core.getMessageMimeHeaders(msg.id);
    final publicKey = _autocryptPublicKeyFromHeaders(
      headers,
      expectedAddress: contactAddress,
    );
    if (publicKey == null) {
      return;
    }
    final learnedKey = '$_deltaAccountId:$contactAddress:$publicKey';
    final learnedChatId = _learnedAutocryptContactKeyChatIds[learnedKey];
    if (learnedChatId != null) {
      await db.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: _deltaAccountId,
        deltaChatId: learnedChatId,
      );
      return;
    }
    try {
      final imported = await _core.importContactPublicKey(
        address: contactAddress,
        displayName: chat.contactDisplayName ?? chat.title,
        armoredPublicKey: publicKey,
      );
      final capabilities = await _core.chatSendCapabilities(imported.chatId);
      if (!capabilities.isEncryptedAndSendable) {
        _log.fine(
          'Ignoring Autocrypt contact key for $contactAddress '
          'on account $_deltaAccountId because imported chat '
          '${imported.chatId} is not ready for encrypted sends.',
        );
        return;
      }
      await db.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: _deltaAccountId,
        deltaChatId: imported.chatId,
      );
      _learnedAutocryptContactKeyChatIds[learnedKey] = imported.chatId;
      _log.fine(
        'Learned Autocrypt contact key for $contactAddress '
        'on account $_deltaAccountId.',
      );
    } on DeltaSafeException catch (error) {
      _log.fine(
        'Ignoring unusable Autocrypt contact key for $contactAddress '
        'on account $_deltaAccountId: ${error.message}',
      );
    }
  }

  Future<Message?> _lookupStoredDeltaMessage(
    XmppDatabase db,
    _DeltaChatJidMessageId id,
  ) async {
    final stored = await db.recoverStaleDeltaMessageLocator(
      deltaMsgId: id.msgId,
      deltaAccountId: id.accountId,
      deltaChatId: id.chatId,
      chatJid: id.chatJid,
    );
    if (stored == null ||
        stored.deltaMsgId != id.msgId ||
        stored.deltaAccountId != id.accountId) {
      return null;
    }
    return stored;
  }

  bool _storedDeltaLocatorMatches(
    Message message, {
    required int msgId,
    required int chatId,
    required int accountId,
    required String chatJid,
  }) {
    return message.deltaMsgId == msgId &&
        message.deltaAccountId == accountId &&
        message.chatJid == chatJid &&
        message.deltaChatId == chatId;
  }

  String _resolveOutgoingSenderJid(Chat chat) {
    final String resolvedSelf = _selfJid;
    if (resolvedSelf.isNotEmpty) {
      return resolvedSelf;
    }
    final String? fallback = chat.emailFromAddress.resolveDeltaPlaceholderJid();
    return fallback ?? _emptyJid;
  }

  bool _isSelfEmailChat(Chat chat) {
    final normalizedChatJid = normalizedAddressValueOrEmpty(chat.jid);
    final normalizedSelf = normalizedAddressValueOrEmpty(_selfJid);
    if (normalizedChatJid.isNotEmpty && normalizedChatJid == normalizedSelf) {
      return true;
    }
    final normalizedEmailAddress = normalizedAddressValueOrEmpty(
      chat.emailAddress,
    );
    return normalizedEmailAddress.isNotEmpty &&
        normalizedEmailAddress == normalizedSelf;
  }

  bool _isHiddenMultiDeviceSyncMessage(DeltaMessage msg, {required Chat chat}) {
    if (!msg.isOutgoing || !_isSelfEmailChat(chat)) {
      return false;
    }
    final String? inferredBody = msg.text?.trim().isNotEmpty == true
        ? msg.text
        : (msg.html?.trim().isNotEmpty == true
              ? HtmlContentCodec.toPlainText(msg.html!)
              : null);
    return isMultiDeviceSyncMessage(subject: msg.subject, body: inferredBody);
  }

  MessageError _messageErrorForDelta(DeltaMessage msg) {
    if (!msg.isOutgoing &&
        msg.downloadState == DeltaDownloadState.undecipherable) {
      return MessageError.notEncryptedForDevice;
    }
    if (msg.isOutgoingFailed) {
      return DeltaErrorMapper.resolve(msg.error);
    }
    return MessageError.none;
  }

  MessageError _messageErrorForDeltaStatus(DeltaMessageStatus status) {
    if (status.isOutgoingFailed) {
      return DeltaErrorMapper.resolve(status.error);
    }
    return MessageError.none;
  }

  EncryptionProtocol _encryptionProtocolForDelta(DeltaMessage msg) {
    return msg.showPadlock
        ? EncryptionProtocol.openPgp
        : EncryptionProtocol.none;
  }

  EncryptionProtocol _encryptionProtocolForDeltaStatus(
    DeltaMessageStatus status,
  ) {
    return status.showPadlock
        ? EncryptionProtocol.openPgp
        : EncryptionProtocol.none;
  }

  Message _mergeDeltaMessageState({
    required Message existing,
    required DeltaMessage msg,
  }) {
    var next = existing;
    final DateTime? timestamp = msg.timestamp;
    if (timestamp != null && next.timestamp != timestamp) {
      next = next.copyWith(timestamp: timestamp);
    }
    next = _mergeDeltaDeliveryState(existing: existing, next: next, msg: msg);
    final encryptionProtocol = _encryptionProtocolForDelta(msg);
    if (next.encryptionProtocol != encryptionProtocol) {
      next = next.copyWith(encryptionProtocol: encryptionProtocol);
    }
    return _mergeIncomingErrorState(next: next, msg: msg);
  }

  Message _mergeDeltaMessageStatus({
    required Message existing,
    required DeltaMessageStatus status,
  }) {
    var next = existing;
    final DateTime? timestamp = status.timestamp;
    if (timestamp != null && next.timestamp != timestamp) {
      next = next.copyWith(timestamp: timestamp);
    }
    next = _mergeDeltaStatusDeliveryState(
      existing: existing,
      next: next,
      status: status,
    );
    final encryptionProtocol = _encryptionProtocolForDeltaStatus(status);
    if (next.encryptionProtocol != encryptionProtocol) {
      next = next.copyWith(encryptionProtocol: encryptionProtocol);
    }
    return _mergeDeltaStatusError(next: next, status: status);
  }

  Message _mergeDeltaDeliveryState({
    required Message existing,
    required Message next,
    required DeltaMessage msg,
  }) {
    if (!msg.hasKnownState) {
      return next;
    }
    var merged = next;
    final deliveryStatus = msg.deliveryStatus;
    final displayed = existing.displayed || deliveryStatus.displayed;
    final deltaSeenSynced = existing.deltaSeenSynced || msg.isIncomingSeen;
    if (deliveryStatus.acked != existing.acked ||
        deliveryStatus.received != existing.received ||
        displayed != existing.displayed ||
        deltaSeenSynced != existing.deltaSeenSynced) {
      merged = merged.copyWith(
        acked: deliveryStatus.acked,
        received: deliveryStatus.received,
        displayed: displayed,
        deltaSeenSynced: deltaSeenSynced,
      );
    }
    if (msg.isOutgoingFailed) {
      if (existing.error == MessageError.none) {
        merged = merged.copyWith(error: DeltaErrorMapper.resolve(msg.error));
      }
    } else if (msg.isOutgoingDelivered || msg.isOutgoingRead) {
      if (existing.error != MessageError.none) {
        merged = merged.copyWith(error: MessageError.none);
      }
    }
    return merged;
  }

  Message _mergeDeltaStatusDeliveryState({
    required Message existing,
    required Message next,
    required DeltaMessageStatus status,
  }) {
    if (!status.hasKnownState) {
      return next;
    }
    var merged = next;
    final deliveryStatus = status.deliveryStatus;
    final displayed = existing.displayed || deliveryStatus.displayed;
    final deltaSeenSynced = existing.deltaSeenSynced || status.isIncomingSeen;
    if (deliveryStatus.acked != existing.acked ||
        deliveryStatus.received != existing.received ||
        displayed != existing.displayed ||
        deltaSeenSynced != existing.deltaSeenSynced) {
      merged = merged.copyWith(
        acked: deliveryStatus.acked,
        received: deliveryStatus.received,
        displayed: displayed,
        deltaSeenSynced: deltaSeenSynced,
      );
    }
    if (status.isOutgoingFailed) {
      if (existing.error == MessageError.none) {
        merged = merged.copyWith(error: DeltaErrorMapper.resolve(status.error));
      }
    } else if (status.isOutgoingDelivered || status.isOutgoingRead) {
      if (existing.error != MessageError.none) {
        merged = merged.copyWith(error: MessageError.none);
      }
    }
    return merged;
  }

  Message _mergeIncomingErrorState({
    required Message next,
    required DeltaMessage msg,
  }) {
    if (msg.isOutgoing) {
      return next;
    }
    final incomingError = _messageErrorForDelta(msg);
    if (incomingError != MessageError.none && next.error != incomingError) {
      return next.copyWith(error: incomingError);
    }
    if (incomingError == MessageError.none &&
        next.error == MessageError.notEncryptedForDevice) {
      return next.copyWith(error: MessageError.none);
    }
    return next;
  }

  Message _mergeDeltaStatusError({
    required Message next,
    required DeltaMessageStatus status,
  }) {
    if (!status.isOutgoing) {
      return next;
    }
    final statusError = _messageErrorForDeltaStatus(status);
    if (statusError != MessageError.none && next.error != statusError) {
      return next.copyWith(error: statusError);
    }
    if (statusError == MessageError.none &&
        next.error == MessageError.notEncryptedForDevice) {
      return next.copyWith(error: MessageError.none);
    }
    return next;
  }

  Future<({bool repairedUnread, List<MessageDiffField> updatedFields})>
  _persistStatusOnlyStatusUpdate({
    required XmppDatabase db,
    required Message existing,
    required Message next,
    required DeltaMessageStatus status,
  }) async {
    final updatedFields = existing.diffFields(next);
    if (updatedFields.isEmpty) {
      return (repairedUnread: false, updatedFields: const <MessageDiffField>[]);
    }
    await db.updateMessage(next);
    var repairedUnread = false;
    if (updatedFields.contains(MessageDiffField.displayed) &&
        !status.isOutgoing) {
      await db.repairUnreadCountForChat(
        next.chatJid,
        selfJid: _xmppSelfJid,
        emailSelfJid: _selfJid,
      );
      repairedUnread = true;
    }
    if (updatedFields.contains(MessageDiffField.encryptionProtocol)) {
      await _ensureEmailEncryptionStatusMarkerForMessage(db: db, message: next);
    }
    return (repairedUnread: repairedUnread, updatedFields: updatedFields);
  }

  Future<({bool repairedUnread, List<MessageDiffField> updatedFields})>
  _persistStatusOnlyUpdate({
    required XmppDatabase db,
    required Message existing,
    required Message next,
    required DeltaMessage msg,
  }) async {
    final updatedFields = existing.diffFields(next);
    if (updatedFields.isEmpty) {
      return (repairedUnread: false, updatedFields: const <MessageDiffField>[]);
    }
    await db.updateMessage(next);
    var repairedUnread = false;
    if (updatedFields.contains(MessageDiffField.displayed) && !msg.isOutgoing) {
      await db.repairUnreadCountForChat(
        next.chatJid,
        selfJid: _xmppSelfJid,
        emailSelfJid: _selfJid,
      );
      repairedUnread = true;
    }
    if (updatedFields.contains(MessageDiffField.encryptionProtocol)) {
      await _ensureEmailEncryptionStatusMarkerForMessage(db: db, message: next);
    }
    return (repairedUnread: repairedUnread, updatedFields: updatedFields);
  }

  Future<({bool repairedUnread, bool changedLocalProjection})>
  _updateExistingMessage({
    required Message existing,
    required DeltaMessage msg,
    bool statusOnly = false,
    bool deferRfc822BodyContent = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final db = await _db();
    var next = _mergeDeltaMessageState(existing: existing, msg: msg);
    if (statusOnly) {
      final statusUpdate = await _persistStatusOnlyUpdate(
        db: db,
        existing: existing,
        next: next,
        msg: msg,
      );
      _traceDeltaUpdateMessage(
        msgId: msg.id,
        statusOnly: statusOnly,
        result: statusUpdate.updatedFields.isEmpty
            ? 'statusNoDiff'
            : statusUpdate.repairedUnread
            ? 'statusRepairedUnread'
            : 'statusUpdated',
        updatedFields: statusUpdate.updatedFields,
        repairedUnread: statusUpdate.repairedUnread,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
      return (
        repairedUnread: statusUpdate.repairedUnread,
        changedLocalProjection: statusUpdate.updatedFields.isNotEmpty,
      );
    }
    final reuseDecision = await _storedContentReuseDecision(
      db: db,
      existing: existing,
      msg: msg,
    );
    if (reuseDecision.reuse) {
      final statusUpdate = await _persistStatusOnlyUpdate(
        db: db,
        existing: existing,
        next: next,
        msg: msg,
      );
      var repairedUnread = statusUpdate.repairedUnread;
      if (!repairedUnread && statusUpdate.updatedFields.isEmpty) {
        repairedUnread = await _repairMixedUnreadCountForIncomingNoDiff(
          db: db,
          message: next,
          msg: msg,
        );
      }
      if (_messageUpdateAffectsChatSummary(statusUpdate.updatedFields)) {
        await _refreshStoredChatSummary(chatJid: next.chatJid, db: db);
      }
      _traceDeltaUpdateMessage(
        msgId: msg.id,
        statusOnly: statusOnly,
        result: statusUpdate.updatedFields.isEmpty
            ? repairedUnread
                  ? 'fastRepairedUnread'
                  : 'fastNoDiff'
            : repairedUnread
            ? 'fastRepairedUnread'
            : 'fastUpdated',
        updatedFields: statusUpdate.updatedFields,
        repairedUnread: repairedUnread,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
      return (
        repairedUnread: repairedUnread,
        changedLocalProjection:
            repairedUnread || statusUpdate.updatedFields.isNotEmpty,
      );
    }
    next = await _buildDeltaMessageContent(
      db: db,
      message: next,
      chatId: msg.chatId,
      msg: msg,
      deferRfc822BodyContent: deferRfc822BodyContent,
    );
    next = _preserveHtmlIfEquivalent(existing: existing, next: next);
    next = _preserveOutgoingContentIfDeltaEmpty(
      existing: existing,
      next: next,
      msg: msg,
    );
    final updatedFields = existing.diffFields(next);
    if (_shouldSkipHtmlOnlyUpdate(
      existing: existing,
      updatedFields: updatedFields,
    )) {
      await _ensureEmailEncryptionStatusMarkerForMessage(db: db, message: next);
      _traceDeltaUpdateMessage(
        msgId: msg.id,
        statusOnly: statusOnly,
        result: 'htmlOnlySkipped',
        updatedFields: updatedFields,
        repairedUnread: false,
        reuseMissReason: reuseDecision.missReason,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
      return (repairedUnread: false, changedLocalProjection: false);
    }
    var repairedUnread = false;
    if (updatedFields.isNotEmpty) {
      if (_log.isLoggable(Level.FINE)) {
        const unknownLabel = 'unknown';
        const separator = ', ';
        final updatedLabels =
            updatedFields.map((field) => field.logLabel).toList()..sort();
        final updateSummary = updatedLabels.isEmpty
            ? unknownLabel
            : updatedLabels.join(separator);
        _log.log(Level.FINE, 'Message update diff: $updateSummary');
        _logEmailUpdateDiffDiagnostic(
          updateSummary: updateSummary,
          existing: existing,
          next: next,
          msg: msg,
          updatedFields: updatedFields,
        );
      }
      await db.updateMessage(next);
      if (updatedFields.contains(MessageDiffField.displayed) ||
          updatedFields.contains(MessageDiffField.originId)) {
        await db.repairUnreadCountForChat(
          next.chatJid,
          selfJid: _xmppSelfJid,
          emailSelfJid: _selfJid,
        );
        repairedUnread = true;
      }
      if (_messageUpdateAffectsChatSummary(updatedFields)) {
        await _refreshStoredChatSummary(chatJid: next.chatJid, db: db);
      }
    }
    await _ensureEmailEncryptionStatusMarkerForMessage(db: db, message: next);
    _traceDeltaUpdateMessage(
      msgId: msg.id,
      statusOnly: statusOnly,
      result: updatedFields.isEmpty ? 'noDiff' : 'updated',
      updatedFields: updatedFields,
      repairedUnread: repairedUnread,
      reuseMissReason: reuseDecision.missReason,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
    return (
      repairedUnread: repairedUnread,
      changedLocalProjection: updatedFields.isNotEmpty,
    );
  }

  void _traceDeltaUpdateMessage({
    required int msgId,
    required bool statusOnly,
    required String result,
    required List<MessageDiffField> updatedFields,
    required bool repairedUnread,
    required int elapsedMs,
    String? reuseMissReason,
  }) {
    final isNoDiff =
        result == 'noDiff' ||
        result == 'statusNoDiff' ||
        result == 'fastNoDiff';
    if (isNoDiff) {
      _suppressedDeltaUpdateNoopCount += 1;
      if (elapsedMs > _suppressedDeltaUpdateNoopWorstMs) {
        _suppressedDeltaUpdateNoopWorstMs = elapsedMs;
      }
      if (elapsedMs < _deltaProfileTraceSlowThreshold.inMilliseconds &&
          _suppressedDeltaUpdateNoopCount < _deltaProfileTraceNoopBatchSize) {
        return;
      }
      final suppressedNoop = _suppressedDeltaUpdateNoopCount;
      final suppressedWorstMs = _suppressedDeltaUpdateNoopWorstMs;
      _suppressedDeltaUpdateNoopCount = 0;
      _suppressedDeltaUpdateNoopWorstMs = 0;
      SafeLogging.profileTrace(
        'email.deltaUpdateMessage',
        'end',
        fields: <String, Object?>{
          'msgId': msgId,
          'statusOnly': statusOnly,
          'result': elapsedMs >= _deltaProfileTraceSlowThreshold.inMilliseconds
              ? result
              : 'noDiffBatch',
          'updatedFieldCount': updatedFields.length,
          'updatedFieldHash': _messageDiffProfileHash(updatedFields),
          'repairedUnread': repairedUnread,
          'reuseMissReason': reuseMissReason,
          'suppressedNoop': suppressedNoop,
          'worstSuppressedNoopMs': suppressedWorstMs,
          'elapsedMs': elapsedMs,
        },
      );
      return;
    }
    final suppressedNoop = _suppressedDeltaUpdateNoopCount;
    final suppressedWorstMs = _suppressedDeltaUpdateNoopWorstMs;
    _suppressedDeltaUpdateNoopCount = 0;
    _suppressedDeltaUpdateNoopWorstMs = 0;
    SafeLogging.profileTrace(
      'email.deltaUpdateMessage',
      'end',
      fields: <String, Object?>{
        'msgId': msgId,
        'statusOnly': statusOnly,
        'result': result,
        'updatedFieldCount': updatedFields.length,
        'updatedFieldHash': _messageDiffProfileHash(updatedFields),
        'repairedUnread': repairedUnread,
        'reuseMissReason': reuseMissReason,
        'suppressedNoop': suppressedNoop,
        'worstSuppressedNoopMs': suppressedWorstMs,
        'elapsedMs': elapsedMs,
      },
    );
  }

  String _messageDiffProfileHash(Iterable<MessageDiffField> fields) {
    final labels = fields.map((field) => field.logLabel).toList()..sort();
    return SafeLogging.profileFingerprint(jsonEncode(labels));
  }

  bool _shouldSkipHtmlOnlyUpdate({
    required Message existing,
    required List<MessageDiffField> updatedFields,
  }) {
    if (updatedFields.length != 1) {
      return false;
    }
    if (updatedFields.first != MessageDiffField.htmlBody) {
      return false;
    }
    final String? existingHtml = HtmlContentCodec.normalizeHtml(
      existing.htmlBody,
    );
    return existingHtml != null;
  }

  bool _messageUpdateAffectsChatSummary(Iterable<MessageDiffField> fields) {
    return fields.any(
      (field) => switch (field) {
        MessageDiffField.timestamp ||
        MessageDiffField.body ||
        MessageDiffField.htmlBody ||
        MessageDiffField.subject ||
        MessageDiffField.error ||
        MessageDiffField.warning ||
        MessageDiffField.retracted ||
        MessageDiffField.isFileUploadNotification ||
        MessageDiffField.fileMetadataId ||
        MessageDiffField.pseudoMessageType ||
        MessageDiffField.pseudoMessageData => true,
        _ => false,
      },
    );
  }

  Future<bool> _repairMixedUnreadCountForIncomingNoDiff({
    required XmppDatabase db,
    required Message message,
    required DeltaMessage msg,
  }) async {
    if (msg.isOutgoing || message.displayed || msg.deliveryStatus.displayed) {
      return false;
    }
    final xmppSelfJid = _xmppSelfJid;
    final emailSelfJid = _selfJid;
    if (xmppSelfJid == null ||
        sameNormalizedAddressValue(xmppSelfJid, emailSelfJid)) {
      return false;
    }
    await db.repairUnreadCountForChat(
      message.chatJid,
      selfJid: xmppSelfJid,
      emailSelfJid: emailSelfJid,
    );
    return true;
  }

  Future<({String? missReason, bool reuse})> _storedContentReuseDecision({
    required XmppDatabase db,
    required Message existing,
    required DeltaMessage msg,
  }) async {
    if (existing.fileDownloading ||
        existing.fileUploading ||
        existing.isFileUploadNotification) {
      return (missReason: 'localTransferState', reuse: false);
    }
    if (!await _storedFileMetadataMatchesDelta(
      db: db,
      existing: existing,
      msg: msg,
    )) {
      return (missReason: 'metadataMismatch', reuse: false);
    }
    final inlineContent = _deltaInlineContentProjection(msg);
    final hasStoredContent = _hasStoredMessageContent(existing);
    final hasStoredAttachment =
        existing.fileMetadataID?.trim().isNotEmpty == true;
    final contentMatches = _storedContentMatchesDeltaInlineProjection(
      existing: existing,
      inlineContent: inlineContent,
    );
    if (existing.rfc822BodyStatus.isPendingDownload) {
      if (msg.needsDownload &&
          (hasStoredContent || hasStoredAttachment) &&
          (!_deltaInlineContentHasStoredFields(inlineContent) ||
              contentMatches)) {
        return (missReason: null, reuse: true);
      }
      if (msg.needsDownload && (hasStoredContent || hasStoredAttachment)) {
        return (missReason: 'pendingDeltaInlineContentDiff', reuse: false);
      }
      return (missReason: 'pendingRfc822BodyDownload', reuse: false);
    }
    if (existing.rfc822BodyContentUnavailable && msg.needsDownload) {
      return (missReason: 'unavailableRfc822BodyDownload', reuse: false);
    }
    if (contentMatches && !msg.needsDownload) {
      return (missReason: null, reuse: true);
    }
    if (existing.hasRfc822BodyContent &&
        (hasStoredContent || msg.hasUserVisibleAttachment)) {
      return (missReason: null, reuse: true);
    }
    if (msg.isOutgoing &&
        !_deltaInlineContentHasStoredFields(inlineContent) &&
        hasStoredContent) {
      return (missReason: null, reuse: true);
    }
    if (msg.needsDownload) {
      return (
        missReason: 'deltaNeedsDownloadWithoutReusableStoredContent',
        reuse: false,
      );
    }
    if (!hasStoredContent && !msg.hasUserVisibleAttachment) {
      return (missReason: 'noStoredContent', reuse: false);
    }
    if (_deltaInlineContentHasStoredFields(inlineContent)) {
      return (missReason: 'meaningfulDeltaContentDiff', reuse: false);
    }
    return (missReason: 'incomingEmptyDeltaContent', reuse: false);
  }

  bool _hasStoredMessageContent(Message message) {
    return message.body?.trim().isNotEmpty == true ||
        HtmlContentCodec.normalizeHtml(message.htmlBody) != null ||
        message.subject?.trim().isNotEmpty == true;
  }

  bool _hasCompleteStoredMessageProjection(Message message) {
    if (message.hasRfc822BodyContent || message.rfc822BodyContentUnavailable) {
      return true;
    }
    if (_hasStoredMessageContent(message)) {
      return true;
    }
    if (message.fileMetadataID?.trim().isNotEmpty == true) {
      return true;
    }
    if (message.isFileUploadNotification || message.retracted) {
      return true;
    }
    final pseudoMessageData = message.pseudoMessageDataWithoutRfc822BodyStatus;
    return message.pseudoMessageType != null ||
        (pseudoMessageData != null && pseudoMessageData.isNotEmpty);
  }

  Future<Set<String>> _existingFreshFileMetadataIds({
    required XmppDatabase db,
    required Iterable<Message> messages,
  }) async {
    final expectedIds = <String>{};
    for (final message in messages) {
      final metadataId = message.fileMetadataID?.trim();
      final deltaMsgId = message.deltaMsgId;
      if (metadataId == null ||
          metadataId.isEmpty ||
          deltaMsgId == null ||
          metadataId != deltaFileMetadataId(deltaMsgId)) {
        continue;
      }
      expectedIds.add(metadataId);
    }
    if (expectedIds.isEmpty) {
      return const <String>{};
    }
    final metadata = await db.getFileMetadataForIds(expectedIds);
    return {
      for (final item in metadata)
        if (item.id.trim().isNotEmpty) item.id.trim(),
    };
  }

  bool _hasLocallyCompleteDeltaProjection({
    required Message message,
    required Set<String> existingFileMetadataIds,
  }) {
    if (message.fileDownloading || message.fileUploading) {
      return false;
    }
    final metadataId = message.fileMetadataID?.trim();
    if (metadataId != null && metadataId.isNotEmpty) {
      final deltaMsgId = message.deltaMsgId;
      if (deltaMsgId == null || metadataId != deltaFileMetadataId(deltaMsgId)) {
        return false;
      }
      return existingFileMetadataIds.contains(metadataId) &&
          _hasCompleteStoredMessageProjection(message);
    }
    return _hasCompleteStoredMessageProjection(message);
  }

  Future<bool> _storedFileMetadataMatchesDelta({
    required XmppDatabase db,
    required Message existing,
    required DeltaMessage msg,
  }) async {
    final existingMetadataId = existing.fileMetadataID?.trim();
    if (!msg.hasUserVisibleAttachment) {
      return existingMetadataId == null || existingMetadataId.isEmpty;
    }
    final expectedMetadataId = deltaFileMetadataId(msg.id);
    if (existingMetadataId != expectedMetadataId) {
      return false;
    }
    final storedMetadata = await db.getFileMetadata(expectedMetadataId);
    if (storedMetadata == null) {
      return false;
    }
    final resolvedMetadata = _metadataFromDelta(
      delta: msg,
      metadataId: expectedMetadataId,
    );
    final mergedMetadata = _mergeMetadata(storedMetadata, resolvedMetadata);
    return mergedMetadata == storedMetadata;
  }

  bool _storedContentMatchesDeltaInlineProjection({
    required Message existing,
    required ({
      String? body,
      String? htmlBody,
      String? normalizedHtml,
      String? rawHtml,
      String? rawText,
      String? subject,
    })
    inlineContent,
  }) {
    if (!_deltaInlineContentHasStoredFields(inlineContent)) {
      return false;
    }
    final existingBody = existing.body?.trim() ?? '';
    final inlineBody = inlineContent.body?.trim() ?? '';
    if (existingBody != inlineBody) {
      return false;
    }
    if (_canonicalHtml(existing.htmlBody) !=
        _canonicalHtml(inlineContent.htmlBody)) {
      return false;
    }
    return (existing.subject?.trim() ?? '') ==
        (inlineContent.subject?.trim() ?? '');
  }

  bool _deltaInlineContentHasStoredFields(
    ({
      String? body,
      String? htmlBody,
      String? normalizedHtml,
      String? rawHtml,
      String? rawText,
      String? subject,
    })
    inlineContent,
  ) {
    return inlineContent.body?.trim().isNotEmpty == true ||
        inlineContent.htmlBody != null ||
        inlineContent.subject?.trim().isNotEmpty == true;
  }

  Message _preserveHtmlIfEquivalent({
    required Message existing,
    required Message next,
  }) {
    final String? existingHtml = existing.htmlBody;
    final String? nextHtml = next.htmlBody;
    if (existingHtml == nextHtml) {
      return next;
    }
    final String existingCanonical = _canonicalHtml(existingHtml);
    final String nextCanonical = _canonicalHtml(nextHtml);
    if (existingCanonical == nextCanonical) {
      return next.copyWith(htmlBody: existingHtml);
    }
    return next;
  }

  Message _preserveOutgoingContentIfDeltaEmpty({
    required Message existing,
    required Message next,
    required DeltaMessage msg,
  }) {
    if (!msg.isOutgoing || !existing.isEmailBacked) {
      return next;
    }
    var preserved = next;
    final existingBody = existing.body;
    final rawText = clampMessageText(msg.text);
    final rawHtml = HtmlContentCodec.normalizeHtml(clampMessageHtml(msg.html));
    if (rawText?.trim().isNotEmpty != true &&
        rawHtml == null &&
        preserved.body?.trim().isNotEmpty != true &&
        existingBody?.trim().isNotEmpty == true) {
      preserved = preserved.copyWith(body: existingBody);
    }
    final existingHtml = HtmlContentCodec.normalizeHtml(existing.htmlBody);
    if (rawHtml == null &&
        HtmlContentCodec.normalizeHtml(preserved.htmlBody) == null &&
        existingHtml != null &&
        (preserved.body?.trim() ?? '') == (existing.body?.trim() ?? '')) {
      preserved = preserved.copyWith(htmlBody: existing.htmlBody);
    }
    return preserved;
  }

  String _canonicalHtml(String? html) {
    return HtmlContentCodec.canonicalizeHtml(html) ?? '';
  }

  Future<void> _scheduleOriginIdHydration({
    required _DeltaChatJidMessageId id,
  }) async {
    if (_originIdHydrationPending.contains(id.msgId)) {
      return;
    }
    _originIdHydrationPending.add(id.msgId);
    await _originIdHydrationQueue.run(() async {
      try {
        await _hydrateOriginId(id: id);
      } on Exception catch (error, stackTrace) {
        _log.fine('Failed to hydrate Delta origin ID.', error, stackTrace);
      } finally {
        _originIdHydrationPending.remove(id.msgId);
      }
    });
  }

  Future<void> _scheduleOriginIdHydrationIfNeeded({
    required Message existing,
    required _DeltaChatJidMessageId id,
  }) async {
    if (!existing.isEmailBacked) {
      return;
    }
    if (_originIdHydrationExhausted.contains(id.msgId)) {
      return;
    }
    if (normalizeEmailMessageId(existing.originID) != null) {
      return;
    }
    await _scheduleOriginIdHydration(id: id);
  }

  Future<void> _hydrateOriginId({required _DeltaChatJidMessageId id}) async {
    final nativeOriginId = await _resolveOriginId(id.msgId);
    if (nativeOriginId == null) {
      _originIdHydrationExhausted.add(id.msgId);
      _log.info('Origin ID hydration exhausted for Delta msg ${id.msgId}.');
      return;
    }
    final db = await _db();
    final existing = await _lookupStoredDeltaMessage(db, id);
    if (existing == null) {
      return;
    }
    if (normalizeEmailMessageId(existing.originID) != null) {
      return;
    }
    await db.updateMessageOriginId(
      stanzaID: existing.stanzaID,
      originID: nativeOriginId,
    );
    await db.repairUnreadCountForChat(
      existing.chatJid,
      selfJid: _xmppSelfJid,
      emailSelfJid: _selfJid,
    );
    await _refreshStoredChatSummary(chatJid: existing.chatJid, db: db);
  }

  Future<String?> _resolveOriginId(int msgId) async {
    final nativeRfc724Supported = _core.supportsMessageRfc724Mid;
    final nativeInfoSupported = _core.supportsMessageInfo;
    String? rfc724Mid;
    try {
      rfc724Mid = normalizeEmailMessageId(
        await _core.getMessageRfc724Mid(msgId),
      );
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to load Delta RFC724 Message-ID.', error, stackTrace);
    }
    if (isDeltaGeneratedMessageId(rfc724Mid)) {
      rfc724Mid = null;
    }
    if (rfc724Mid != null) {
      await _logOriginResolutionDiagnostic(
        msgId: msgId,
        source: 'rfc724_mid',
        nativeRfc724Supported: nativeRfc724Supported,
        nativeRfc724Mid: rfc724Mid,
        nativeInfoSupported: nativeInfoSupported,
        parsedInfoMessageId: null,
        mimeHeaders: null,
        parsedHeaderMessageId: null,
      );
      return rfc724Mid;
    }
    String? parsedInfoMessageId;
    try {
      final nativeInfo = await _core.getMessageInfo(msgId);
      parsedInfoMessageId = parseDeltaMessageInfoMessageId(nativeInfo);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to load Delta message info.', error, stackTrace);
    }
    if (isDeltaGeneratedMessageId(parsedInfoMessageId)) {
      parsedInfoMessageId = null;
    }
    if (parsedInfoMessageId != null) {
      await _logOriginResolutionDiagnostic(
        msgId: msgId,
        source: 'message_info',
        nativeRfc724Supported: nativeRfc724Supported,
        nativeRfc724Mid: rfc724Mid,
        nativeInfoSupported: nativeInfoSupported,
        parsedInfoMessageId: parsedInfoMessageId,
        mimeHeaders: null,
        parsedHeaderMessageId: null,
      );
      return parsedInfoMessageId;
    }
    final headers = await _core.getMessageMimeHeaders(msgId);
    var parsedHeaderMessageId = parseEmailMessageId(headers);
    if (isDeltaGeneratedMessageId(parsedHeaderMessageId)) {
      parsedHeaderMessageId = null;
    }
    await _logOriginResolutionDiagnostic(
      msgId: msgId,
      source: 'mime_headers',
      nativeRfc724Supported: nativeRfc724Supported,
      nativeRfc724Mid: rfc724Mid,
      nativeInfoSupported: nativeInfoSupported,
      parsedInfoMessageId: parsedInfoMessageId,
      mimeHeaders: headers,
      parsedHeaderMessageId: parsedHeaderMessageId,
    );
    return parsedHeaderMessageId;
  }

  Future<Message> _withReconstructedQuote({
    required XmppDatabase db,
    required Message message,
    required DeltaMessage msg,
    required int deltaAccountId,
    required int chatId,
  }) async {
    if (message.replyStanzaId != null ||
        message.replyOriginId != null ||
        message.replyMucStanzaId != null) {
      return message;
    }
    final DeltaQuotedMessage? quoted;
    try {
      quoted = await _core.getQuotedMessage(msg.id);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to load Delta quote.', error, stackTrace);
      return message;
    }
    final quotedDeltaId = quoted?.id;
    if (quotedDeltaId == null) {
      return message;
    }
    final quotedRow = await db.getMessageByDeltaId(
      quotedDeltaId,
      deltaAccountId: deltaAccountId,
    );
    if (quotedRow == null) {
      return message;
    }
    return message.copyWith(replyStanzaId: quotedRow.stanzaID);
  }

  Future<String?> _resolveNativeOriginId(DeltaMessage msg) async {
    try {
      return await _resolveOriginId(msg.id);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to resolve Delta origin ID.', error, stackTrace);
      return null;
    }
  }

  Future<void> _refreshStoredChatSummary({
    required String chatJid,
    XmppDatabase? db,
  }) async {
    final resolvedDb = db ?? await _db();
    await resolvedDb.repairChatSummaryFromMessages(chatJid);
  }

  Future<String?> _previewTextForStoredMessage({
    required XmppDatabase db,
    required Message message,
  }) async {
    if (message.isHiddenMultiDeviceSyncMessage) {
      return null;
    }
    final preview = ChatSubjectCodec.previewEmailText(
      body: message.body,
      subject: message.subject,
    );
    if (preview != null) {
      return preview;
    }
    final metadataId = message.fileMetadataID?.trim();
    if (metadataId == null || metadataId.isEmpty) {
      return null;
    }
    final metadata = await db.getFileMetadata(metadataId);
    if (metadata == null) {
      return 'Attachment';
    }
    return _attachmentLabel(metadata);
  }

  String? _previewTextForDeltaMessage(DeltaMessage? message, {Chat? chat}) {
    if (message == null) {
      return null;
    }
    if (chat != null && _isHiddenMultiDeviceSyncMessage(message, chat: chat)) {
      return null;
    }
    final sanitizedSubject = email_headers.sanitizeEmailSubjectValue(
      message.subject,
    );
    final projection = _deltaInlineContentProjection(message);
    final previewText = ChatSubjectCodec.previewEmailText(
      body: projection.body,
      subject: sanitizedSubject,
    );
    if (previewText != null) {
      return previewText;
    }
    if (message.hasUserVisibleAttachment) {
      final metadataId = deltaFileMetadataId(message.id);
      final metadata = _metadataFromDelta(
        delta: message,
        metadataId: metadataId,
      );
      return _attachmentLabel(metadata);
    }
    return null;
  }

  Future<Chat> _ensureChat(int chatId) async {
    final result = await _ensureChatWithResult(chatId);
    return result.chat;
  }

  Future<({Chat chat, bool changedMapping})> _ensureChatWithResult(
    int chatId,
  ) async {
    final db = await _db();
    final int deltaAccountId = _deltaAccountId;
    final existing = await db.getChatByDeltaChatId(
      chatId,
      accountId: deltaAccountId,
    );
    if (existing != null) {
      return (chat: existing, changedMapping: false);
    }
    final remote = await _core.getChat(chatId);
    if (remote != null) {
      _deltaSystemChatCoreCache[chatId] = _isDeltaCoreSystemChat(
        chatId: chatId,
        remote: remote,
      );
    }
    final chat = _chatFromRemote(
      chatId: chatId,
      remote: remote,
      emailFromAddress: _selfJid,
    );
    final existingByAddress = await db.getChat(chat.jid);
    if (existingByAddress != null) {
      final merged = existingByAddress.copyWith(
        deltaChatId: existingByAddress.deltaChatId ?? chatId,
        emailAddress: chat.emailAddress,
        emailFromAddress:
            existingByAddress.emailFromAddress ?? chat.emailFromAddress,
        contactDisplayName: chat.contactDisplayName,
        contactID: chat.contactID,
      );
      await db.updateChat(merged);
      await db.upsertEmailChatAccount(
        chatJid: merged.jid,
        deltaAccountId: deltaAccountId,
        deltaChatId: chatId,
      );
      return (chat: merged, changedMapping: true);
    }
    await db.createChat(chat);
    await db.upsertEmailChatAccount(
      chatJid: chat.jid,
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
    );
    return (chat: chat, changedMapping: true);
  }

  Chat _chatFromRemote({
    required int chatId,
    required DeltaChat? remote,
    String? emailFromAddress,
  }) {
    final emailAddress = _normalizedAddress(remote?.contactAddress, chatId);
    final title = remote?.name ?? remote?.contactName ?? emailAddress;
    return Chat(
      jid: emailAddress,
      title: title,
      type: _mapChatType(remote?.type),
      lastChangeTimestamp: DateTime.fromMillisecondsSinceEpoch(0),
      transport: MessageTransport.email,
      encryptionProtocol: EncryptionProtocol.none,
      contactDisplayName: remote?.contactName ?? remote?.name ?? emailAddress,
      contactID: emailAddress,
      contactJid: emailAddress,
      emailAddress: emailAddress,
      emailFromAddress: emailFromAddress,
      deltaChatId: chatId,
    );
  }

  Future<void> _refreshChat(int chatId) async {
    if (await _isDeltaSystemChat(chatId)) {
      return;
    }
    final db = await _db();
    final int deltaAccountId = _deltaAccountId;
    final remote = await _core.getChat(chatId);
    if (remote == null) return;
    final existing = await db.getChatByDeltaChatId(
      chatId,
      accountId: deltaAccountId,
    );
    if (existing == null) {
      final chat = _chatFromRemote(
        chatId: chatId,
        remote: remote,
        emailFromAddress: _selfJid,
      );
      final existingByAddress = await db.getChat(chat.jid);
      if (existingByAddress != null) {
        final merged = existingByAddress.copyWith(
          deltaChatId: existingByAddress.deltaChatId ?? chatId,
          emailAddress: chat.emailAddress,
          emailFromAddress:
              existingByAddress.emailFromAddress ?? chat.emailFromAddress,
          contactDisplayName: chat.contactDisplayName,
          contactID: chat.contactID,
        );
        await db.updateChat(merged);
        await db.upsertEmailChatAccount(
          chatJid: merged.jid,
          deltaAccountId: deltaAccountId,
          deltaChatId: chatId,
        );
        return;
      }
      await db.createChat(chat);
      await db.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: deltaAccountId,
        deltaChatId: chatId,
      );
      return;
    }
    final updated = existing.copyWith(
      title: remote.name ?? remote.contactName ?? existing.title,
      contactDisplayName:
          remote.contactName ?? remote.name ?? existing.contactDisplayName,
      contactID: remote.contactAddress ?? existing.contactID,
      emailAddress: remote.contactAddress ?? existing.emailAddress,
      type: _mapChatType(remote.type),
    );
    if (updated != existing) {
      await db.updateChat(updated);
    }
    await db.upsertEmailChatAccount(
      chatJid: existing.jid,
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
    );
  }

  Future<void> _refreshArchivedState(int chatId) async {
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (chat == null) return;
    final archivedChatIds = await _resolveArchivedChatIds();
    final isArchived = archivedChatIds.contains(chatId);
    if (chat.archived != isArchived) {
      await db.updateChat(chat.copyWith(archived: isArchived));
    }
  }

  Future<Set<int>> _resolveArchivedChatIds() async {
    const cacheTtl = Duration(seconds: 5);
    final fetchedAt = _archivedChatlistFetchedAt;
    if (fetchedAt != null &&
        DateTime.timestamp().difference(fetchedAt) < cacheTtl) {
      return _archivedChatIds;
    }
    final inFlight = _archivedChatlistInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _loadArchivedChatIds();
    _archivedChatlistInFlight = future;
    try {
      final ids = await future;
      _archivedChatIds
        ..clear()
        ..addAll(ids);
      _archivedChatlistFetchedAt = DateTime.timestamp();
      return ids;
    } finally {
      if (identical(_archivedChatlistInFlight, future)) {
        _archivedChatlistInFlight = null;
      }
    }
  }

  Future<Set<int>> _loadArchivedChatIds() async {
    final archivedChatlist = await _core.getChatlist(
      flags: _deltaChatlistArchivedOnlyFlag,
    );
    return archivedChatlist
        .where((entry) => entry.chatId > _deltaChatLastSpecialId)
        .map((entry) => entry.chatId)
        .toSet();
  }

  ChatType _mapChatType(int? type) {
    switch (type) {
      case DeltaChatType.group:
      case DeltaChatType.mailingList:
      case DeltaChatType.outBroadcast:
      case DeltaChatType.inBroadcast:
        return ChatType.groupChat;
      default:
        return ChatType.chat;
    }
  }

  Future<XmppDatabase> _db() async {
    return await _databaseBuilder();
  }

  Future<T> _trackDatabaseOperation<T>(Future<T> Function() operation) {
    final tracker = _databaseOperationTracker;
    if (tracker == null) {
      return operation();
    }
    return tracker(operation);
  }

  Future<Message> _buildDeltaMessageContent({
    required XmppDatabase db,
    required Message message,
    required int chatId,
    required DeltaMessage msg,
    bool deferRfc822BodyContent = false,
    _DeltaContentTiming? timing,
  }) async {
    final inlineContent = _timedDeltaTraceStepSync(
      () => _deltaInlineContentProjection(msg),
      (elapsedMs) {
        if (timing != null) {
          timing.inlineProjectionMs += elapsedMs;
        }
      },
    );
    var next = message.copyWith(
      body: inlineContent.body,
      htmlBody: inlineContent.htmlBody,
      subject: inlineContent.subject,
    );
    next = deferRfc822BodyContent
        ? _markRfc822BodyContentPending(previous: message, message: next)
        : await _applyRfc822BodyContentForSplitMessage(
            previous: message,
            message: next,
            msg: msg,
            timing: timing,
          );
    final metadataRawBody = next.hasRfc822BodyContent
        ? next.body
        : inlineContent.rawText;
    final metadataRawHtml = next.hasRfc822BodyContent
        ? next.htmlBody
        : inlineContent.rawHtml;
    final metadataNormalizedHtml = next.hasRfc822BodyContent
        ? HtmlContentCodec.normalizeHtml(next.htmlBody)
        : inlineContent.normalizedHtml;
    next = _timedDeltaTraceStepSync(
      () => _applyForwardedMetadata(
        message: next,
        rawBody: metadataRawBody,
        normalizedHtml: metadataNormalizedHtml,
        sanitizedSubject: inlineContent.subject,
      ),
      (elapsedMs) {
        if (timing != null) {
          timing.forwardedMetadataMs += elapsedMs;
        }
      },
    );
    next = await _timedDeltaTraceStep(
      () => _applyShareMetadata(
        db: db,
        message: next,
        rawBody: metadataRawBody,
        rawHtml: metadataRawHtml,
        chatId: chatId,
        msgId: msg.id,
        deltaAccountId: message.deltaAccountId,
      ),
      (elapsedMs) {
        if (timing != null) {
          timing.shareMetadataMs += elapsedMs;
        }
      },
    );
    next = await _timedDeltaTraceStep(
      () => _attachFileMetadata(db: db, message: next, delta: msg),
      (elapsedMs) {
        if (timing != null) {
          timing.attachmentMetadataMs += elapsedMs;
        }
      },
    );
    return next;
  }

  Message _markRfc822BodyContentPending({
    required Message previous,
    required Message message,
  }) {
    if (previous.hasRfc822BodyContent) {
      return _preserveExistingRfc822BodyContent(
        previous: previous,
        message: message,
      );
    }
    if (previous.rfc822BodyContentUnavailable) {
      return message.copyWith(
        body: null,
        htmlBody: null,
        rfc822BodyStatus: EmailRfc822BodyStatus.unavailable,
        pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
      );
    }
    return message.copyWith(
      rfc822BodyStatus: EmailRfc822BodyStatus.pendingDownload,
      pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
    );
  }

  ({
    String? body,
    String? htmlBody,
    String? normalizedHtml,
    String? rawHtml,
    String? rawText,
    String? subject,
  })
  _deltaInlineContentProjection(DeltaMessage msg) {
    final rawText = clampMessageText(msg.text);
    final rawHtml = clampMessageHtml(msg.html);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(rawHtml);
    final sanitizedSubject = email_headers.sanitizeEmailSubjectValue(
      msg.subject,
    );
    final resolvedBody = rawText?.trim().isNotEmpty == true
        ? rawText!
        : (normalizedHtml == null
              ? ''
              : HtmlContentCodec.toPlainText(normalizedHtml));
    final normalizedBody = sanitizedSubject?.isNotEmpty == true
        ? ChatSubjectCodec.stripRepeatedSubject(
            body: resolvedBody,
            subject: sanitizedSubject!,
          )
        : resolvedBody;
    return (
      body: normalizedBody.trim().isEmpty ? null : normalizedBody,
      htmlBody: normalizedHtml,
      normalizedHtml: normalizedHtml,
      rawHtml: rawHtml,
      rawText: rawText,
      subject: sanitizedSubject,
    );
  }

  Future<Message> _applyRfc822BodyContentForSplitMessage({
    required Message previous,
    required Message message,
    required DeltaMessage msg,
    _DeltaContentTiming? timing,
  }) async {
    if (msg.id <= _deltaMessageIdUnset) {
      return _preserveExistingRfc822BodyContent(
        previous: previous,
        message: message,
      );
    }
    if (previous.rfc822BodyContentUnavailable && !msg.needsDownload) {
      return message.copyWith(
        body: null,
        htmlBody: null,
        rfc822BodyStatus: EmailRfc822BodyStatus.unavailable,
        pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
      );
    }
    final rfc822Body = await _timedDeltaTraceStep(
      () => _core.getMessageRfc822Body(msg.id),
      (elapsedMs) {
        if (timing != null) {
          timing.rfc822FetchMs += elapsedMs;
        }
      },
    );
    if (rfc822Body == null || !rfc822Body.hasBody) {
      return _preserveOrMarkUnavailableRfc822BodyContent(
        previous: previous,
        message: message,
        pendingDownload: msg.needsDownload,
      );
    }
    final normalizedHtml = HtmlContentCodec.normalizeHtml(rfc822Body.htmlBody);
    final visibleHtmlText = _visibleEmailHtmlText(
      normalizedHtml,
      timing: timing,
    );
    final plainBody = clampMessageText(rfc822Body.plainText)?.trim();
    final safePlainBody =
        plainBody?.isNotEmpty == true &&
            !HtmlContentCodec.looksLikeCssBodyText(plainBody!)
        ? plainBody
        : null;
    final resolvedBody = safePlainBody ?? visibleHtmlText ?? '';
    if (safePlainBody == null &&
        normalizedHtml == null &&
        HtmlContentCodec.normalizeHtml(message.htmlBody) != null) {
      return _preserveOrMarkUnavailableRfc822BodyContent(
        previous: previous,
        message: message,
        pendingDownload: msg.needsDownload,
      );
    }
    final hasRenderableHtml =
        normalizedHtml != null &&
        (visibleHtmlText?.isNotEmpty == true ||
            HtmlContentCodec.containsRenderableRemoteImages(normalizedHtml));
    if (resolvedBody.isEmpty && !hasRenderableHtml) {
      return _preserveOrMarkUnavailableRfc822BodyContent(
        previous: previous,
        message: message,
        pendingDownload: msg.needsDownload,
      );
    }
    return message.copyWith(
      body: resolvedBody.isEmpty ? null : resolvedBody,
      htmlBody: hasRenderableHtml ? normalizedHtml : null,
      rfc822BodyStatus: EmailRfc822BodyStatus.hydrated,
      pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
    );
  }

  String? _visibleEmailHtmlText(String? html, {_DeltaContentTiming? timing}) {
    final normalizedHtml = HtmlContentCodec.normalizeHtml(html);
    if (normalizedHtml == null) {
      return null;
    }
    final visibleText = _timedDeltaTraceStepSync(
      () {
        final preparedHtml = HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
          normalizedHtml,
          allowRemoteImages: false,
        );
        return HtmlContentCodec.toPlainText(preparedHtml).trim();
      },
      (elapsedMs) {
        if (timing != null) {
          timing.rfc822VisibleHtmlMs += elapsedMs;
        }
      },
    );
    return visibleText.isEmpty ? null : visibleText;
  }

  Message _preserveExistingRfc822BodyContent({
    required Message previous,
    required Message message,
  }) {
    if (!previous.hasRfc822BodyContent) {
      return message;
    }
    return message.copyWith(
      body: previous.body,
      htmlBody: previous.htmlBody,
      rfc822BodyStatus: EmailRfc822BodyStatus.hydrated,
      pseudoMessageData: previous.pseudoMessageDataWithoutRfc822BodyStatus,
    );
  }

  Message _preserveOrMarkUnavailableRfc822BodyContent({
    required Message previous,
    required Message message,
    required bool pendingDownload,
  }) {
    if (previous.hasRfc822BodyContent) {
      return _preserveExistingRfc822BodyContent(
        previous: previous,
        message: message,
      );
    }
    return message.copyWith(
      rfc822BodyStatus: pendingDownload
          ? EmailRfc822BodyStatus.pendingDownload
          : EmailRfc822BodyStatus.unavailable,
      pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
    );
  }

  Message _applyForwardedMetadata({
    required Message message,
    required String? rawBody,
    required String? normalizedHtml,
    required String? sanitizedSubject,
  }) {
    final htmlText = normalizedHtml == null
        ? null
        : HtmlContentCodec.toPlainText(normalizedHtml);
    final originalSenderLabel =
        syntheticForwardDisplaySenderLabel(
          subjectLabel: sanitizedSubject,
          emailMarkerPresent: hasSyntheticForwardHtmlMarker(
            html: normalizedHtml,
          ),
        ) ??
        forwardedBodySenderLabel(rawBody) ??
        forwardedBodySenderLabel(htmlText);
    final normalizedSubject = sanitizedSubject?.trim().toLowerCase() ?? '';
    final isForwarded =
        originalSenderLabel != null ||
        normalizedSubject.startsWith('fwd:') ||
        normalizedSubject.startsWith('fw:') ||
        hasForwardedBodyHeader(rawBody) ||
        hasForwardedBodyHeader(htmlText);
    if (!isForwarded) {
      return message;
    }
    return message.copyWith(
      pseudoMessageData: message.pseudoMessageDataWithForwarded(
        forwardedFromJid: message.senderJid,
        forwardedOriginalSenderLabel: originalSenderLabel,
      ),
    );
  }

  Future<MessageSaveResult> _storeMessage({
    required XmppDatabase db,
    required Message message,
  }) async {
    return db.saveMessageWithResult(message, selfJid: _selfJid);
  }

  Future<void> _ensureEmailEncryptionStatusMarkerForMessage({
    required XmppDatabase db,
    required Message message,
  }) async {
    if (!message.isEmailBackedOpenPgpContent) {
      return;
    }
    await db.ensureEmailEncryptionStatusMarkerForChat(message.chatJid);
  }

  Future<Message> _attachFileMetadata({
    required XmppDatabase db,
    required Message message,
    required DeltaMessage delta,
  }) async {
    if (!delta.hasUserVisibleAttachment) {
      final metadataId = message.fileMetadataID?.trim();
      if (metadataId == null || metadataId != deltaFileMetadataId(delta.id)) {
        return message;
      }
      final messageId = message.id?.trim();
      if (messageId != null && messageId.isNotEmpty) {
        await db.replaceMessageAttachments(
          messageId: messageId,
          fileMetadataIds: const <String>[],
        );
        await db.deleteFileMetadata(metadataId);
      }
      return message.copyWith(fileMetadataID: null);
    }
    final metadataId = deltaFileMetadataId(delta.id);
    final existing = await db.getFileMetadata(metadataId);
    final previousMetadataId = message.fileMetadataID?.trim();
    FileMetadataData? previousMetadata;
    if (existing == null &&
        previousMetadataId != null &&
        previousMetadataId.isNotEmpty &&
        previousMetadataId != metadataId &&
        delta.fileName?.trim().isNotEmpty != true) {
      previousMetadata = await db.getFileMetadata(previousMetadataId);
    }
    final resolvedMetadata = _metadataFromDelta(
      delta: delta,
      metadataId: metadataId,
    );
    final merged = _mergeMetadata(
      existing ?? previousMetadata?.copyWith(id: metadataId),
      resolvedMetadata,
    );
    if (merged != null && (existing == null || merged != existing)) {
      await db.saveFileMetadata(merged);
    }
    final resolvedMetadataId =
        merged?.id ?? existing?.id ?? resolvedMetadata.id;
    final resolvedMetadataForMessage = merged ?? existing ?? resolvedMetadata;
    final messageId = message.id?.trim();
    if (previousMetadataId != null &&
        previousMetadataId.isNotEmpty &&
        previousMetadataId != resolvedMetadataId &&
        messageId != null &&
        messageId.isNotEmpty) {
      await db.updateMessageAttachment(
        stanzaID: message.stanzaID,
        metadata: resolvedMetadataForMessage,
      );
      await db.replaceMessageAttachments(
        messageId: messageId,
        fileMetadataIds: [resolvedMetadataId],
      );
      await db.deleteFileMetadata(previousMetadataId);
    }
    return message.copyWith(fileMetadataID: resolvedMetadataId);
  }

  FileMetadataData _metadataFromDelta({
    required DeltaMessage delta,
    required String metadataId,
  }) {
    final path = delta.filePath?.trim();
    final sanitizedPath = path == null || path.isEmpty ? null : path;
    final sanitizedMimeType = email_headers.sanitizeEmailMimeType(
      delta.fileMime,
    );
    return FileMetadataData(
      id: metadataId,
      filename: _resolvedFilename(
        explicitName: delta.fileName,
        fallbackPath: sanitizedPath,
        deltaId: delta.id,
      ),
      path: sanitizedPath,
      mimeType: sanitizedMimeType,
      sizeBytes: delta.fileSize,
      width: delta.width,
      height: delta.height,
    );
  }

  FileMetadataData? _mergeMetadata(
    FileMetadataData? existing,
    FileMetadataData next,
  ) {
    if (existing == null) return next;
    final merged = existing.copyWith(
      filename: existing.filename.isNotEmpty
          ? existing.filename
          : next.filename,
      path: next.path ?? existing.path,
      mimeType: next.mimeType ?? existing.mimeType,
      sizeBytes: next.sizeBytes ?? existing.sizeBytes,
      width: next.width ?? existing.width,
      height: next.height ?? existing.height,
    );
    return merged;
  }

  String _resolvedFilename({
    required String? explicitName,
    required String? fallbackPath,
    required int deltaId,
  }) {
    const fallbackPrefix = 'attachment-';
    final fallbackName = '$fallbackPrefix$deltaId';
    return email_headers.sanitizeEmailAttachmentFilename(
      explicitName,
      fallbackPath: fallbackPath,
      fallbackName: fallbackName,
    );
  }

  String _attachmentLabel(FileMetadataData metadata) {
    final filename = metadata.filename.trim();
    final label = filename.isEmpty
        ? _l10n.chatAttachmentFallbackLabel
        : filename;
    final sizeLabel = _formatAttachmentBytes(metadata.sizeBytes);
    return _l10n.chatAttachmentCaption(label, sizeLabel);
  }

  String _formatAttachmentBytes(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return _l10n.chatAttachmentUnknownSize;
    }
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= _attachmentSizeUnitBase && unitIndex < 4) {
      value /= _attachmentSizeUnitBase;
      unitIndex++;
    }
    const precisionThreshold = 10;
    final precision = value >= precisionThreshold || unitIndex == 0 ? 0 : 1;
    final unitLabel = _attachmentUnitLabel(unitIndex);
    return '${value.toStringAsFixed(precision)} $unitLabel';
  }

  String _attachmentUnitLabel(int unitIndex) {
    switch (unitIndex) {
      case 0:
        return _l10n.commonFileSizeUnitBytes;
      case 1:
        return _l10n.commonFileSizeUnitKilobytes;
      case 2:
        return _l10n.commonFileSizeUnitMegabytes;
      case 3:
        return _l10n.commonFileSizeUnitGigabytes;
      default:
        return _l10n.commonFileSizeUnitTerabytes;
    }
  }

  Future<Message> _applyShareMetadata({
    required XmppDatabase db,
    required Message message,
    required String? rawBody,
    required String? rawHtml,
    required int chatId,
    required int msgId,
    required int deltaAccountId,
  }) async {
    final match = ShareTokenHtmlCodec.parseToken(
      plainText: rawBody,
      html: rawHtml,
    );
    if (match == null) {
      return message;
    }
    final share = await db.getMessageShareByToken(match.token);
    final cleanedBody = share?.subject?.isNotEmpty == true
        ? _stripSubjectHeader(match.cleanedBody, share!.subject!)
        : match.cleanedBody;
    final cleanedHtml = ShareTokenHtmlCodec.stripInjectedToken(
      message.htmlBody,
    );
    final sanitized = message.copyWith(
      body: cleanedBody,
      htmlBody: cleanedHtml,
    );
    if (share != null) {
      final existingShareId = await db.getShareIdForDeltaMessage(
        msgId,
        deltaAccountId: deltaAccountId,
      );
      if (existingShareId == null) {
        await db.insertMessageCopy(
          shareId: share.shareId,
          dcMsgId: msgId,
          dcChatId: chatId,
          dcAccountId: deltaAccountId,
        );
      }
    }
    return sanitized;
  }

  bool _isDeltaMessageMarkerId(int msgId) =>
      msgId == DeltaMessageId.marker1 || msgId == DeltaMessageId.dayMarker;

  Future<bool> _isDeltaSystemChat(int chatId) async {
    final db = await _db();
    final mapped = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (mapped != null) {
      return false;
    }
    final cached = _deltaSystemChatCoreCache[chatId];
    if (cached != null) {
      return cached;
    }
    final remote = await _core.getChat(chatId);
    final result = _isDeltaCoreSystemChat(chatId: chatId, remote: remote);
    if (remote != null) {
      _deltaSystemChatCoreCache[chatId] = result;
    }
    return result;
  }

  bool _isDeltaCoreSystemChat({
    required int chatId,
    required DeltaChat? remote,
  }) {
    final contactId = remote?.contactId;
    if (contactId == DeltaContactId.device ||
        contactId == DeltaContactId.info) {
      return true;
    }
    final normalized = _normalizedAddress(remote?.contactAddress, chatId);
    return normalized == fallbackEmailAddressForChat(chatId);
  }
}

String _normalizedAddress(String? address, int chatId) {
  if (address == null || address.trim().isEmpty) {
    return fallbackEmailAddressForChat(chatId);
  }
  return normalizeEmailAddress(address);
}

String _emailRowKey() => const Uuid().v4();

String _stripSubjectHeader(String body, String subject) {
  final trimmedBody = body.trimLeft();
  if (!trimmedBody.startsWith(subject)) {
    return trimmedBody;
  }
  var remainder = trimmedBody.substring(subject.length);
  remainder = remainder.replaceFirst(RegExp(r'^\s+'), '');
  return remainder;
}
