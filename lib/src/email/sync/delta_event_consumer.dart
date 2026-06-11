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
  edited,
  retracted,
  isFileUploadNotification,
  fileDownloading,
  fileUploading,
  fileMetadataId,
  quoting,
  stickerPackId,
  pseudoMessageType,
  pseudoMessageData,
  reactionsPreview,
  deltaAccountId,
  deltaChatId,
  deltaMsgId,
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

enum DeltaEventType {
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
  Future<List<DeltaMessage>> getMessages(List<int> messageIds);
  Future<DeltaFreshMessageCount> getFreshMessageCountSafe(int chatId);
  Future<bool> downloadFullMessage(int messageId);
  Future<String?> getMessageRfc724Mid(int messageId);
  Future<String?> getMessageInfo(int messageId);
  Future<String?> getMessageMimeHeaders(int messageId);
  Future<String?> getMessageDebugInfo(int messageId);
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(int messageId);
  Future<DeltaContactPublicKeyImport> importContactPublicKey({
    required String address,
    required String displayName,
    required String armoredPublicKey,
  });
  Future<DeltaChatSendCapabilities> chatSendCapabilities(int chatId);
  Future<DeltaChat?> getChat(int chatId);
}

final class DeltaContextEventCore implements DeltaEventCore {
  const DeltaContextEventCore(this._context);

  final DeltaContextHandle _context;

  @override
  int get accountId => _context.accountId ?? DeltaAccountDefaults.legacyId;

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

  bool get isOutgoingDelivered =>
      isOutgoing &&
      (state == DeltaMessageState.outDelivered ||
          state == DeltaMessageState.outMdnRcvd);

  bool get isOutgoingRead =>
      isOutgoing && state == DeltaMessageState.outMdnRcvd;

  bool get isOutgoingFailed =>
      isOutgoing && state == DeltaMessageState.outFailed;

  bool get isIncomingNoticed =>
      !isOutgoing && state == DeltaMessageState.inNoticed;

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
    if (isIncomingSeen || isIncomingNoticed) {
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
    addIf(quoting != other.quoting, MessageDiffField.quoting);
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

class DeltaEventConsumer {
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
  final Logger _log;
  Future<void>? _chatlistRefreshInFlight;
  Future<Set<int>>? _archivedChatlistInFlight;
  DateTime? _archivedChatlistFetchedAt;
  final Set<int> _archivedChatIds = <int>{};
  final EmailAsyncQueue _autoDownloadQueue = EmailAsyncQueue();
  final EmailAsyncQueue _eventQueue = EmailAsyncQueue();
  final EmailAsyncQueue _originIdHydrationQueue = EmailAsyncQueue();
  final Set<int> _originIdHydrationPending = <int>{};
  final Set<int> _originIdHydrationExhausted = <int>{};

  final Map<String, int> _learnedAutocryptContactKeyChatIds = <String, int>{};

  AppLocalizations get _l10n =>
      _localizationsProvider?.call() ??
      lookupAppLocalizations(const Locale('en'));

  String get _selfJid =>
      _selfJidProvider?.call().resolveDeltaPlaceholderJid() ?? _emptyJid;

  String? get _xmppSelfJid => _xmppSelfJidProvider?.call();

  int get _deltaAccountId => _core.accountId;

  Future<bool> bootstrapFromCore() async {
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
    final isArchived = archivedChatIds.contains(chatId);
    if (updated.archived != isArchived) {
      updated = updated.copyWith(archived: isArchived);
    }
    if (entry.msgId > 0 && !_isDeltaMessageMarkerId(entry.msgId)) {
      final last = await _core.getMessage(entry.msgId);
      if (last == null || !_isHiddenMultiDeviceSyncMessage(last, chat: chat)) {
        final timestamp = last?.timestamp;
        final preview = _previewTextForDeltaMessage(last, chat: chat);
        if (timestamp != null && timestamp != updated.lastChangeTimestamp) {
          updated = updated.copyWith(lastChangeTimestamp: timestamp);
        }
        if (preview != null &&
            preview.isNotEmpty &&
            preview != updated.lastMessage) {
          updated = updated.copyWith(lastMessage: preview);
        }
      }
    }
    if (updated != chat) {
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
          chatId: chatId,
          msg: msg,
          chat: chat,
          skipSystemChatCheck: true,
        );
      }
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
          await db.trimChatMessages(
            jid: chat.jid,
            maxMessages: 0,
            deltaAccountId: deltaAccountId,
            deltaChatId: deltaChatId,
            selfJid: _xmppSelfJid,
            emailSelfJid: _selfJid,
          );
          await _repairActiveDeltaChatReference(
            chatJid: chat.jid,
            removedDeltaChatId: deltaChatId,
            db: db,
          );
          final remaining = await db.countEmailChatAccounts(chat.jid);
          if (remaining == 0 && chat.defaultTransport.isEmail) {
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
        var hydratedMessages = false;
        DateTime? lastTimestamp;
        String? lastPreview;
        if (entry.msgId > 0 && !_isDeltaMessageMarkerId(entry.msgId)) {
          final messageId = _DeltaChatJidMessageId(
            accountId: deltaAccountId,
            chatId: chatId,
            chatJid: updated.jid,
            msgId: entry.msgId,
          );
          final existing = await _lookupStoredDeltaMessage(db, messageId);
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
              lastTimestamp = last.timestamp;
              lastPreview = _previewTextForDeltaMessage(last, chat: updated);
              await _ingestDeltaMessage(
                chatId: chatId,
                msg: last,
                chat: updated,
                skipSystemChatCheck: true,
              );
              hydratedMessages = true;
            }
          }
        }
        if (updated.archived != isArchived) {
          updated = updated.copyWith(archived: isArchived);
        }
        if (!hydratedMessages && lastTimestamp != null) {
          final bool hasPreview = lastPreview?.isNotEmpty == true;
          final bool hasStoredPreview =
              updated.lastMessage?.trim().isNotEmpty == true;
          final bool shouldBackfillPreview = hasPreview && !hasStoredPreview;
          final bool shouldUpdateTimestamp =
              lastTimestamp.isAfter(updated.lastChangeTimestamp) ||
              shouldBackfillPreview;
          if (shouldUpdateTimestamp) {
            updated = updated.copyWith(lastChangeTimestamp: lastTimestamp);
          }
          if (hasPreview && shouldUpdateTimestamp) {
            updated = updated.copyWith(lastMessage: lastPreview);
          }
        } else if (!hydratedMessages && lastTimestamp == null) {
          await _refreshStoredChatSummary(chatJid: updated.jid, db: db);
        }
        var storedUnreadCount = await db.countUnreadMessagesForChat(
          updated.jid,
          selfJid: _xmppSelfJid,
          emailSelfJid: _selfJid,
        );
        final freshCount = await _core.getFreshMessageCountSafe(chatId);
        if (cancelled()) return;
        if (storedUnreadCount > 0 ||
            (freshCount.supported && freshCount.count > 0)) {
          await _syncChatMessages(chatId);
          if (cancelled()) return;
          await _refreshStoredChatSummary(chatJid: updated.jid, db: db);
          hydratedMessages = true;
          storedUnreadCount = await db.countUnreadMessagesForChat(
            updated.jid,
            selfJid: _xmppSelfJid,
            emailSelfJid: _selfJid,
          );
        }
        if (hydratedMessages) {
          final refreshed = await db.getChat(updated.jid);
          if (refreshed == null) {
            final nextUpdated = updated.unreadCount == storedUnreadCount
                ? updated
                : updated.copyWith(unreadCount: storedUnreadCount);
            if (nextUpdated != chat) {
              await db.updateChat(nextUpdated);
            }
          } else {
            var merged = refreshed;
            if (merged.archived != updated.archived ||
                merged.unreadCount != storedUnreadCount) {
              merged = merged.copyWith(
                archived: updated.archived,
                unreadCount: storedUnreadCount,
              );
            }
            if (merged != refreshed) {
              await db.updateChat(merged);
            }
          }
        } else {
          final nextUpdated = updated.unreadCount == storedUnreadCount
              ? updated
              : updated.copyWith(unreadCount: storedUnreadCount);
          if (nextUpdated != chat) {
            await db.updateChat(nextUpdated);
          }
        }
      }
    });
  }

  Future<int> backfillChatHistory({
    required int chatId,
    required String chatJid,
    required int desiredWindow,
    Chat? targetChat,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    const minimumHistoryWindow = 1;
    if (desiredWindow < minimumHistoryWindow) {
      return _deltaMessageIdUnset;
    }
    if (await _isDeltaSystemChat(chatId)) {
      return _deltaMessageIdUnset;
    }
    final db = await _db();
    final localCount = await db.countEmailBackedChatMessages(
      chatJid,
      deltaAccountId: _deltaAccountId,
      filter: filter,
      includePseudoMessages: false,
    );
    if (localCount >= desiredWindow) {
      return _deltaMessageIdUnset;
    }
    final needed = desiredWindow - localCount;
    final chat = targetChat ?? await _ensureChat(chatId);
    final marker = beforeMessageId ?? _deltaMessageIdUnset;
    final hasMarker = marker > _deltaMessageIdUnset;
    final rawMessageIds = await _core.getChatMessageIds(
      chatId: chatId,
      beforeMessageId: marker,
    );
    final messageIds = rawMessageIds
        .where((id) => !_isDeltaMessageMarkerId(id))
        .toList();
    if (messageIds.isEmpty) {
      return _deltaMessageIdUnset;
    }
    var imported = _deltaMessageIdUnset;
    if (hasMarker) {
      final startIndex = messageIds.length > needed
          ? messageIds.length - needed
          : _deltaMessageIdUnset;
      for (final messageId in messageIds.skip(startIndex)) {
        final msg = await _core.getMessage(messageId);
        if (msg == null) {
          continue;
        }
        await _ingestDeltaMessage(
          chatId: chatId,
          msg: msg,
          chat: chat,
          skipSystemChatCheck: true,
        );
        imported += 1;
        if (imported >= needed) {
          break;
        }
      }
      return imported;
    }
    final cutoff = beforeTimestamp;
    for (final messageId in messageIds.reversed) {
      final msg = await _core.getMessage(messageId);
      if (msg == null) {
        continue;
      }
      final timestamp = msg.timestamp;
      if (cutoff != null && timestamp != null && !timestamp.isBefore(cutoff)) {
        continue;
      }
      await _ingestDeltaMessage(
        chatId: chatId,
        msg: msg,
        chat: chat,
        skipSystemChatCheck: true,
      );
      imported += 1;
      if (imported >= needed) {
        break;
      }
    }
    return imported;
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
        await _refreshChat(event.data1);
        break;
      case DeltaEventType.chatDeleted:
        await _handleChatDeleted(event.data1);
        break;
      default:
        break;
    }
  }

  Future<DeltaMessage?> _hydrateMessage(int chatId, int msgId) async {
    final msg = await _core.getMessage(msgId);
    if (msg == null) return null;
    await _ingestDeltaMessage(chatId: chatId, msg: msg);
    return msg;
  }

  Future<void> _handleMessagesChanged(int chatId, int msgId) async {
    if (msgId > _deltaMessageIdUnset) {
      if (_isDeltaMessageMarkerId(msgId)) {
        return;
      }
      await _hydrateMessage(chatId, msgId);
      return;
    }
    if (chatId == DeltaChatId.none) {
      await refreshChatlistSnapshot();
      return;
    }
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

  Future<void> _handleReactionsChanged(int chatId, int msgId) async {
    if (msgId <= _deltaMessageIdUnset || _isDeltaMessageMarkerId(msgId)) {
      return;
    }
    await _hydrateMessage(chatId, msgId);
  }

  Future<void> _handleIncomingMessage(int chatId, int msgId) async {
    if (msgId <= _deltaMessageIdUnset) {
      await _handleMessagesChanged(chatId, msgId);
      return;
    }
    if (_isDeltaMessageMarkerId(msgId)) {
      return;
    }
    final msg = await _hydrateMessage(chatId, msgId);
    if (msg == null) {
      return;
    }
    if (!msg.isOutgoing) {
      await _updateChatSummaryForIncomingMessage(
        chatId: chatId,
        messageId: msgId,
      );
    }
    await _updateUnreadCount(chatId);
  }

  Future<void> _handleMessageStateChanged(int chatId, int msgId) async {
    if (msgId <= _deltaMessageIdUnset) {
      return;
    }
    if (_isDeltaMessageMarkerId(msgId)) {
      return;
    }
    final msg = await _hydrateMessage(chatId, msgId);
    if (msg == null) {
      return;
    }
    await _updateUnreadCount(chatId);
  }

  Future<void> _handleMessagesNoticed(int chatId) async {
    if (chatId <= _deltaChatLastSpecialId) {
      return;
    }
    await _updateUnreadCount(chatId);
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
    await db.trimChatMessages(
      jid: chat.jid,
      maxMessages: 0,
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
      selfJid: _xmppSelfJid,
      emailSelfJid: _selfJid,
    );
    await _repairActiveDeltaChatReference(
      chatJid: chat.jid,
      removedDeltaChatId: chatId,
      db: db,
    );
    final remaining = await db.countEmailChatAccounts(chat.jid);
    if (remaining == 0 && chat.defaultTransport.isEmail) {
      await db.removeChat(chat.jid);
    }
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
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (chat == null) return;
    await db.repairUnreadCountForChat(
      chat.jid,
      selfJid: _xmppSelfJid,
      emailSelfJid: _selfJid,
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
    final messageIds = await _core.getChatMessageIds(chatId: chatId);
    final filteredIds = messageIds
        .where((id) => !_isDeltaMessageMarkerId(id))
        .toList();
    if (filteredIds.isEmpty) {
      return;
    }
    const int startIndex = 0;
    final visibleIds = filteredIds
        .skip(startIndex)
        .where((id) => id > _deltaMessageIdUnset)
        .toList(growable: false);
    if (visibleIds.isEmpty) {
      return;
    }
    final visibleIdSet = visibleIds.toSet();
    final snapshots = await db.getMessageDeltaSnapshot(
      chat.jid,
      deltaAccountId: _deltaAccountId,
    );
    final localDeltaIds = <int>{};
    final refreshIds = <int>{};
    for (final snapshot in snapshots) {
      final deltaId = snapshot.deltaMsgId;
      if (deltaId == null) {
        continue;
      }
      if (visibleIdSet.contains(deltaId)) {
        localDeltaIds.add(deltaId);
        if (!snapshot.displayed) {
          refreshIds.add(deltaId);
        }
      }
    }
    final missingIds = <int>[];
    for (final deltaId in visibleIds) {
      if (!localDeltaIds.contains(deltaId)) {
        missingIds.add(deltaId);
      }
    }
    final syncIds = <int>[...missingIds, ...refreshIds];
    const int batchSize = 8;
    for (var index = 0; index < syncIds.length; index += batchSize) {
      final chunk = syncIds.skip(index).take(batchSize).toList();
      final messages = await Future.wait(chunk.map(_core.getMessage));
      for (final msg in messages) {
        if (msg == null) {
          continue;
        }
        await _ingestDeltaMessage(
          chatId: chatId,
          msg: msg,
          chat: chat,
          skipSystemChatCheck: true,
        );
      }
    }
  }

  Future<void> hydrateMessage(int msgId) async {
    final msg = await _core.getMessage(msgId);
    if (msg == null) return;
    await _ingestDeltaMessage(chatId: msg.chatId, msg: msg);
  }

  Future<void> _ingestDeltaMessage({
    required int chatId,
    required DeltaMessage msg,
    Chat? chat,
    bool skipSystemChatCheck = false,
  }) async {
    if (!skipSystemChatCheck && await _isDeltaSystemChat(chatId)) {
      _log.finer(
        'Dropping Delta system-chat message msgId=${msg.id} chatId=$chatId',
      );
      return;
    }
    final resolvedChat = chat ?? await _ensureChat(chatId);
    if (_isHiddenMultiDeviceSyncMessage(msg, chat: resolvedChat)) {
      _log.finer(
        'Dropping Multi Device Synchronization placeholder message '
        'msgId=${msg.id} chatId=$chatId',
      );
      return;
    }
    final int deltaAccountId = _deltaAccountId;
    final db = await _db();
    if (msg.isEncryptionStatusSystemMessage) {
      await db.ensureEmailEncryptionStatusMarkerForChat(resolvedChat.jid);
      return;
    }
    final stanzaId = _emailRowKey();
    final existingByDeltaId = await db.getMessageByDeltaId(
      msg.id,
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
    );
    if (existingByDeltaId != null) {
      if (_storedDeltaLocatorMatches(
        existingByDeltaId,
        msgId: msg.id,
        chatId: chatId,
        accountId: deltaAccountId,
        chatJid: resolvedChat.jid,
      )) {
        await _logEmailPartDiagnostic(
          stage: 'ingest-existing-delta',
          eventChatId: chatId,
          msg: msg,
          resolvedChat: resolvedChat,
          existingByDelta: existingByDeltaId,
          storedMessage: existingByDeltaId,
        );
        await _updateExistingMessage(existing: existingByDeltaId, msg: msg);
        final hydrationId = _DeltaChatJidMessageId(
          accountId: deltaAccountId,
          chatId: chatId,
          chatJid: resolvedChat.jid,
          msgId: msg.id,
        );
        fireAndForget(
          () => _scheduleOriginIdHydrationIfNeeded(
            existing: existingByDeltaId,
            id: hydrationId,
          ),
          operationName: 'DeltaEventConsumer.scheduleOriginIdHydration',
        );
        if (!msg.isOutgoing) {
          await _learnAutocryptContactKeyForIncomingMessage(
            db: db,
            chat: resolvedChat,
            msg: msg,
          );
        }
        return;
      }
      _log.fine(
        'Releasing stale Delta locator claim before storing new row. '
        'msgId=${msg.id} chatId=$chatId accountId=$deltaAccountId '
        'existingStanza=${existingByDeltaId.stanzaID} '
        'existingChat=${existingByDeltaId.chatJid} '
        'existingDeltaChat=${existingByDeltaId.deltaChatId}.',
      );
      await db.clearMessageDeltaHandles(existingByDeltaId.stanzaID);
    }
    final String? nativeOriginId = await _resolveNativeOriginId(msg);
    final timestamp = msg.timestamp ?? DateTime.timestamp();
    final isOutgoing = msg.isOutgoing;
    final senderJid = isOutgoing
        ? _resolveOutgoingSenderJid(resolvedChat)
        : resolvedChat.jid;
    final emailAddress = resolvedChat.emailAddress?.toLowerCase();
    if (!isOutgoing &&
        emailAddress != null &&
        emailAddress.isNotEmpty &&
        await db.isEmailAddressBlocked(emailAddress)) {
      await db.incrementEmailBlockCount(emailAddress);
      return;
    }
    var warning = MessageWarning.none;
    if (!isOutgoing &&
        emailAddress != null &&
        emailAddress.isNotEmpty &&
        await db.isEmailAddressSpam(emailAddress)) {
      warning = MessageWarning.emailSpamQuarantined;
      await db.markEmailChatsSpam(
        address: emailAddress,
        spam: true,
        spamUpdatedAt: timestamp,
      );
      await db.markChatSpam(
        jid: resolvedChat.jid,
        spam: true,
        spamUpdatedAt: timestamp,
      );
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
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
      deltaMsgId: msg.id,
    );
    message = await _buildDeltaMessageContent(
      db: db,
      message: message,
      chatId: chatId,
      msg: msg,
    );
    final String originId = nativeOriginId ?? _derivedOriginIdForMessage(msg);
    if (nativeOriginId == null) {
      message = message.copyWith(originID: originId);
    }
    await _logEmailPartDiagnostic(
      stage: 'ingest-new-before-store',
      eventChatId: chatId,
      msg: msg,
      resolvedChat: resolvedChat,
      storedMessage: message,
      resolvedOriginId: originId,
    );
    await _storeMessage(db: db, message: message, chatJid: resolvedChat.jid);
    await _ensureEmailEncryptionStatusMarkerForMessage(
      db: db,
      message: message,
    );
    if (!isOutgoing) {
      await _learnAutocryptContactKeyForIncomingMessage(
        db: db,
        chat: resolvedChat,
        msg: msg,
      );
    }
    await _refreshStoredChatSummary(chatJid: resolvedChat.jid, db: db);
    final bool isSpamQuarantined =
        warning == MessageWarning.emailSpamQuarantined;
    final blockAddress = normalizedAddressValue(
      resolvedChat.emailFromAddress ??
          resolvedChat.emailAddress ??
          resolvedChat.jid,
    );
    final isBlocklisted =
        blockAddress != null &&
        await db.getEmailBlocklistEntry(blockAddress) != null;
    final shouldAutoDownloadPartial =
        !isOutgoing &&
        msg.needsDownload &&
        !isSpamQuarantined &&
        !isBlocklisted;
    if (shouldAutoDownloadPartial) {
      fireAndForget(
        () => _autoDownloadQueue.run(() async {
          await _core.downloadFullMessage(msg.id);
          _originIdHydrationExhausted.remove(msg.id);
        }),
        operationName: 'DeltaEventConsumer.downloadFullMessage',
      );
    }
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
    if (value.startsWith('[') && value.endsWith(' message]')) {
      return 'delta-size-placeholder';
    }
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
    final scoped = await db.getMessageByDeltaId(
      id.msgId,
      deltaAccountId: id.accountId,
      deltaChatId: id.chatId,
    );
    if (scoped == null ||
        !_storedDeltaLocatorMatches(
          scoped,
          msgId: id.msgId,
          chatId: id.chatId,
          accountId: id.accountId,
          chatJid: id.chatJid,
        )) {
      return null;
    }
    return scoped;
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

  EncryptionProtocol _encryptionProtocolForDelta(DeltaMessage msg) {
    return msg.showPadlock
        ? EncryptionProtocol.openPgp
        : EncryptionProtocol.none;
  }

  Future<void> _updateExistingMessage({
    required Message existing,
    required DeltaMessage msg,
    String? originId,
  }) async {
    final db = await _db();
    var next = existing;
    if (originId != null && originId != existing.originID) {
      next = next.copyWith(originID: originId);
    }
    final DateTime? timestamp = msg.timestamp;
    if (timestamp != null && next.timestamp != timestamp) {
      next = next.copyWith(timestamp: timestamp);
    }
    if (msg.hasKnownState) {
      final deliveryStatus = msg.deliveryStatus;
      final displayed = existing.displayed || deliveryStatus.displayed;
      if (deliveryStatus.acked != existing.acked ||
          deliveryStatus.received != existing.received ||
          displayed != existing.displayed) {
        next = next.copyWith(
          acked: deliveryStatus.acked,
          received: deliveryStatus.received,
          displayed: displayed,
        );
      }
      if (msg.isOutgoingFailed) {
        if (existing.error == MessageError.none) {
          next = next.copyWith(error: DeltaErrorMapper.resolve(msg.error));
        }
      } else if (msg.isOutgoingDelivered || msg.isOutgoingRead) {
        if (existing.error != MessageError.none) {
          next = next.copyWith(error: MessageError.none);
        }
      }
    }
    final encryptionProtocol = _encryptionProtocolForDelta(msg);
    if (next.encryptionProtocol != encryptionProtocol) {
      next = next.copyWith(encryptionProtocol: encryptionProtocol);
    }
    if (!msg.isOutgoing) {
      final incomingError = _messageErrorForDelta(msg);
      if (incomingError != MessageError.none && next.error != incomingError) {
        next = next.copyWith(error: incomingError);
      } else if (incomingError == MessageError.none &&
          next.error == MessageError.notEncryptedForDevice) {
        next = next.copyWith(error: MessageError.none);
      }
    }
    next = await _buildDeltaMessageContent(
      db: db,
      message: next,
      chatId: msg.chatId,
      msg: msg,
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
      return;
    }
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
      }
      await _refreshStoredChatSummary(chatJid: next.chatJid, db: db);
    }
    await _ensureEmailEncryptionStatusMarkerForMessage(db: db, message: next);
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
    final existingOrigin = normalizeEmailMessageId(existing.originID);
    if (existingOrigin != null && !isDerivedEmailMessageKey(existingOrigin)) {
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
    final existingOrigin = normalizeEmailMessageId(existing.originID);
    if (existingOrigin == nativeOriginId) {
      return;
    }
    if (existingOrigin != null && !isDerivedEmailMessageKey(existingOrigin)) {
      return;
    }
    await db.updateMessageOriginId(
      stanzaID: existing.stanzaID,
      originID: nativeOriginId,
    );
    final staleOrigin = existing.originID?.trim();
    if (staleOrigin != null && staleOrigin.isNotEmpty) {
      await db.rebindMessageCollectionMembershipReferences(
        chatJid: existing.chatJid,
        oldReferenceId: staleOrigin,
        newReferenceId: nativeOriginId,
      );
    }
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

  Future<String?> _resolveNativeOriginId(DeltaMessage msg) async {
    try {
      return await _resolveOriginId(msg.id);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to resolve Delta origin ID.', error, stackTrace);
      return null;
    }
  }

  String _derivedOriginIdForMessage(DeltaMessage msg) {
    _log.info(
      'No usable Message-ID for Delta msg ${msg.id}; using derived key.',
    );
    return derivedEmailMessageKey(
      subject: msg.subject,
      timestamp: msg.timestamp,
      bodyText: msg.text,
    );
  }

  Future<void> _updateChatSummaryForIncomingMessage({
    required int chatId,
    required int messageId,
  }) async {
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (chat == null) {
      return;
    }
    final stored = await db.getMessageByDeltaId(
      messageId,
      deltaAccountId: _deltaAccountId,
      deltaChatId: chatId,
    );
    if (stored == null) {
      return;
    }
    await _refreshStoredChatSummary(chatJid: chat.jid, db: db);
  }

  Future<void> _refreshStoredChatSummary({
    required String chatJid,
    XmppDatabase? db,
  }) async {
    final resolvedDb = db ?? await _db();
    await resolvedDb.repairChatSummaryPreservingTimestamp(chatJid);
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
    final previewText = ChatSubjectCodec.previewEmailText(
      body: message.text,
      subject: sanitizedSubject,
    );
    if (previewText != null) {
      return previewText;
    }
    if (message.hasFile) {
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
    final db = await _db();
    final int deltaAccountId = _deltaAccountId;
    final existing = await db.getChatByDeltaChatId(
      chatId,
      accountId: deltaAccountId,
    );
    if (existing != null) {
      await db.upsertEmailChatAccount(
        chatJid: existing.jid,
        deltaAccountId: deltaAccountId,
        deltaChatId: chatId,
      );
      return existing;
    }
    final remote = await _core.getChat(chatId);
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
      return merged;
    }
    await db.createChat(chat);
    await db.upsertEmailChatAccount(
      chatJid: chat.jid,
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
    );
    return chat;
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
  }) async {
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
    var next = message.copyWith(
      body: normalizedBody.trim().isEmpty ? null : normalizedBody,
      htmlBody: normalizedHtml,
      subject: sanitizedSubject,
    );
    next = await _applyRfc822BodyContentForSplitMessage(
      previous: message,
      message: next,
      msg: msg,
    );
    final metadataRawBody = next.hasRfc822BodyContent ? next.body : rawText;
    final metadataRawHtml = next.hasRfc822BodyContent ? next.htmlBody : rawHtml;
    final metadataNormalizedHtml = next.hasRfc822BodyContent
        ? HtmlContentCodec.normalizeHtml(next.htmlBody)
        : normalizedHtml;
    next = _applyForwardedMetadata(
      message: next,
      rawBody: metadataRawBody,
      normalizedHtml: metadataNormalizedHtml,
      sanitizedSubject: sanitizedSubject,
    );
    next = await _applyShareMetadata(
      db: db,
      message: next,
      rawBody: metadataRawBody,
      rawHtml: metadataRawHtml,
      chatId: chatId,
      msgId: msg.id,
      deltaAccountId: message.deltaAccountId,
    );
    next = await _attachFileMetadata(db: db, message: next, delta: msg);
    return next;
  }

  Future<Message> _applyRfc822BodyContentForSplitMessage({
    required Message previous,
    required Message message,
    required DeltaMessage msg,
  }) async {
    if (msg.id <= _deltaMessageIdUnset) {
      return _preserveExistingRfc822BodyContent(
        previous: previous,
        message: message,
      );
    }
    final rfc822Body = await _core.getMessageRfc822Body(msg.id);
    if (rfc822Body == null || !rfc822Body.hasBody) {
      return _preserveExistingRfc822BodyContent(
        previous: previous,
        message: message,
      );
    }
    final normalizedHtml = HtmlContentCodec.normalizeHtml(rfc822Body.htmlBody);
    final visibleHtmlText = _visibleEmailHtmlText(normalizedHtml);
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
      return _preserveExistingRfc822BodyContent(
        previous: previous,
        message: message,
      );
    }
    final hasRenderableHtml =
        normalizedHtml != null &&
        (visibleHtmlText?.isNotEmpty == true ||
            HtmlContentCodec.containsRenderableRemoteImages(normalizedHtml));
    if (resolvedBody.isEmpty && !hasRenderableHtml) {
      return _preserveExistingRfc822BodyContent(
        previous: previous,
        message: message,
      );
    }
    return message.copyWith(
      body: resolvedBody.isEmpty ? null : resolvedBody,
      htmlBody: hasRenderableHtml ? normalizedHtml : null,
      pseudoMessageData: <String, dynamic>{
        ...(message.pseudoMessageData ?? const <String, dynamic>{}),
        'emailRfc822Body': true,
      },
    );
  }

  String? _visibleEmailHtmlText(String? html) {
    final normalizedHtml = HtmlContentCodec.normalizeHtml(html);
    if (normalizedHtml == null) {
      return null;
    }
    final preparedHtml = HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
      normalizedHtml,
      allowRemoteImages: false,
    );
    final visibleText = HtmlContentCodec.toPlainText(preparedHtml).trim();
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
      pseudoMessageData: previous.pseudoMessageData,
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

  Future<void> _storeMessage({
    required XmppDatabase db,
    required Message message,
    required String chatJid,
  }) async {
    await db.saveMessage(message, selfJid: _selfJid);
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
    if (!delta.hasFile) {
      return message;
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
    final remote = await _core.getChat(chatId);
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
