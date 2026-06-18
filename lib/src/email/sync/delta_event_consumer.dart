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

final class _DeltaHydrationResult {
  const _DeltaHydrationResult({
    required this.message,
    required this.repairedUnread,
    required this.unreadStateResolved,
    this.saveResult,
  });

  final DeltaMessage message;
  final bool repairedUnread;
  final bool unreadStateResolved;
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
    this.saveResult,
  });

  final bool repairedUnread;
  final bool unreadStateResolved;
  final MessageSaveResult? saveResult;
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
// For incoming Delta email, local displayed means no longer locally fresh.
// Delta InSeen is still verified separately before read receipt work completes.
const DeltaMessageDeliveryStatus _deltaIncomingNoLongerFreshStatus =
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

  bool get isIncomingSeen => !isOutgoing && state == DeltaMessageState.inSeen;

  bool get isIncomingNoticed =>
      !isOutgoing && state == DeltaMessageState.inNoticed;

  bool get isIncomingNoLongerFresh => isIncomingNoticed || isIncomingSeen;

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
    if (isIncomingNoLongerFresh) {
      return _deltaIncomingNoLongerFreshStatus;
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

  bool get isIncomingNoticed =>
      !isOutgoing && state == DeltaMessageState.inNoticed;

  bool get isIncomingNoLongerFresh => isIncomingNoticed || isIncomingSeen;

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
    if (isIncomingNoLongerFresh) {
      return _deltaIncomingNoLongerFreshStatus;
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

class DeltaEventConsumer {
  static const Duration _deltaProfileTraceSlowThreshold = Duration(
    milliseconds: 100,
  );
  static const int _deltaProfileTraceNoopBatchSize = 25;
  static const int _undisplayedReadStateReconcilePageSize = 100;
  static const int _undisplayedReadStateReconcileMaxPages = 5;
  static const int _chatLevelHydrationWindow = 32;

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
  final Set<int> _autoDownloadScheduledMessageIds = <int>{};
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

  Future<bool> bootstrapFromCore({bool includeMessages = true}) async {
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
    final isArchived = archivedChatIds.contains(chatId);
    if (updated.archived != isArchived) {
      updated = updated.copyWith(archived: isArchived);
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
    if (lastTimestamp != null && lastTimestamp != updated.lastChangeTimestamp) {
      updated = updated.copyWith(lastChangeTimestamp: lastTimestamp);
    }
    if (lastPreview != null &&
        lastPreview.isNotEmpty &&
        lastPreview != updated.lastMessage) {
      updated = updated.copyWith(lastMessage: lastPreview);
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
          eventChatId: chatId,
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
        } else {
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
          final hydratedLatestWindow =
              await _hydrateLatestChatWindowForSnapshot(
                chatId: chatId,
                chat: updated,
                db: db,
                requestedWindow:
                    freshCount.supported && freshCount.count > storedUnreadCount
                    ? freshCount.count
                    : null,
                isCurrent: isCurrent,
              );
          if (cancelled()) return;
          if (hydratedLatestWindow) {
            await _refreshStoredChatSummary(chatJid: updated.jid, db: db);
            storedUnreadCount = await db.countUnreadMessagesForChat(
              updated.jid,
              selfJid: _xmppSelfJid,
              emailSelfJid: _selfJid,
            );
          }
        }
        final unreadCount = updated.open
            ? storedUnreadCount
            : freshCount.supported && freshCount.count > storedUnreadCount
            ? freshCount.count
            : storedUnreadCount;
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
              merged.lastChangeTimestamp != updated.lastChangeTimestamp) {
            merged = merged.copyWith(
              lastChangeTimestamp: updated.lastChangeTimestamp,
            );
          }
          if (lastTimestamp != null &&
              merged.lastMessage != updated.lastMessage) {
            merged = merged.copyWith(lastMessage: updated.lastMessage);
          }
          if (merged != refreshed) {
            await db.updateChat(merged);
          }
        }
      }
    });
  }

  Future<bool> _hydrateLatestChatWindowForSnapshot({
    required int chatId,
    required Chat chat,
    required XmppDatabase db,
    required int? requestedWindow,
    bool Function()? isCurrent,
  }) async {
    bool cancelled() => isCurrent?.call() == false;
    const int maxSnapshotHydrationWindow = 64;
    const int batchSize = 8;
    final hydrationWindow = requestedWindow == null
        ? maxSnapshotHydrationWindow
        : requestedWindow < 1
        ? 1
        : requestedWindow > maxSnapshotHydrationWindow
        ? maxSnapshotHydrationWindow
        : requestedWindow;
    final rawMessageIds = await _core.getChatMessageIds(chatId: chatId);
    if (cancelled()) return false;
    final latestIds = rawMessageIds
        .where(
          (id) => id > _deltaMessageIdUnset && !_isDeltaMessageMarkerId(id),
        )
        .toList()
        .reversed
        .take(hydrationWindow)
        .toList(growable: false);
    if (latestIds.isEmpty) {
      return false;
    }
    final snapshots = await db.getMessageDeltaSnapshot(
      chat.jid,
      deltaAccountId: _deltaAccountId,
    );
    if (cancelled()) return false;
    final localDeltaIds = <int>{};
    for (final snapshot in snapshots) {
      final deltaId = snapshot.deltaMsgId;
      if (deltaId != null) {
        localDeltaIds.add(deltaId);
      }
    }
    final missingIds = latestIds
        .where((id) => !localDeltaIds.contains(id))
        .toList(growable: false);
    final hydrationCandidates = await _classifyDeltaIdsForHydration(
      db: db,
      chat: chat,
      chatId: chatId,
      candidateIds: missingIds,
    );
    final unresolvedMissingIds = hydrationCandidates.missingIds;
    if (unresolvedMissingIds.isEmpty) {
      return false;
    }
    var hydrated = false;
    for (
      var index = 0;
      index < unresolvedMissingIds.length;
      index += batchSize
    ) {
      if (cancelled()) return hydrated;
      final chunk = unresolvedMissingIds.skip(index).take(batchSize).toList();
      final messages = await Future.wait(chunk.map(_core.getMessage));
      if (cancelled()) return hydrated;
      for (final msg in messages) {
        if (msg == null) {
          continue;
        }
        await _ingestDeltaMessage(
          eventChatId: chatId,
          msg: msg,
          chat: chat,
          skipSystemChatCheck: true,
        );
        hydrated = true;
      }
    }
    return hydrated;
  }

  Future<
    ({
      List<int> missingIds,
      int storedConflictingLocatorCount,
      int storedExactCount,
      int storedStaleLocatorCount,
    })
  >
  _classifyDeltaIdsForHydration({
    required XmppDatabase db,
    required Chat chat,
    required int chatId,
    required Iterable<int> candidateIds,
  }) async {
    final missingIds = <int>[];
    var storedExactCount = 0;
    var storedStaleLocatorCount = 0;
    var storedConflictingLocatorCount = 0;
    for (final deltaId in candidateIds) {
      final stored = await db.getMessageByDeltaId(
        deltaId,
        deltaAccountId: _deltaAccountId,
      );
      if (stored == null) {
        missingIds.add(deltaId);
        continue;
      }
      if (_storedDeltaLocatorMatches(
        stored,
        msgId: deltaId,
        chatId: chatId,
        accountId: _deltaAccountId,
        chatJid: chat.jid,
      )) {
        storedExactCount += 1;
        continue;
      }
      if (stored.chatJid == chat.jid ||
          sameNormalizedAddressValue(stored.chatJid, chat.jid)) {
        final repaired = await db.rehomeDeltaMessage(
          deltaMsgId: deltaId,
          deltaAccountId: _deltaAccountId,
          deltaChatId: chatId,
          chatJid: chat.jid,
          senderJid: stored.senderJid,
          selfJid: _xmppSelfJid,
          emailSelfJid: _selfJid,
        );
        if (repaired == null) {
          missingIds.add(deltaId);
        } else {
          storedStaleLocatorCount += 1;
        }
        continue;
      }
      storedConflictingLocatorCount += 1;
    }
    return (
      missingIds: List<int>.unmodifiable(missingIds),
      storedConflictingLocatorCount: storedConflictingLocatorCount,
      storedExactCount: storedExactCount,
      storedStaleLocatorCount: storedStaleLocatorCount,
    );
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
          eventChatId: chatId,
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
        eventChatId: chatId,
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

  Future<_DeltaHydrationResult?> _hydrateMessage(
    int chatId,
    int msgId, {
    bool statusOnly = false,
    int? expectedChatId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final msg = await _core.getMessage(msgId);
    if (msg == null) {
      SafeLogging.profileTrace(
        'email.deltaHydrateMessage',
        'end',
        fields: <String, Object?>{
          'chatId': chatId,
          'msgId': msgId,
          'statusOnly': statusOnly,
          'result': 'missingCoreMessage',
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
            'statusOnly': statusOnly,
            'result': 'chatMismatch',
            'expectedChatId': expectedChatId,
            'actualChatId': resolvedChatId,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return null;
      }
    }
    final outcome = await _ingestDeltaMessage(
      eventChatId: chatId,
      msg: msg,
      statusOnly: statusOnly,
    );
    SafeLogging.profileTrace(
      'email.deltaHydrateMessage',
      'end',
      fields: <String, Object?>{
        'chatId': chatId,
        'msgId': msgId,
        'statusOnly': statusOnly,
        'result': 'ingested',
        'repairedUnread': outcome.repairedUnread,
        'unreadStateResolved': outcome.unreadStateResolved,
        'dbChange': outcome.saveResult?.change.name,
        'unreadDelta': outcome.saveResult?.unreadDelta,
        'summaryChanged': outcome.saveResult?.chatSummaryChanged,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return _DeltaHydrationResult(
      message: msg,
      repairedUnread: outcome.repairedUnread,
      unreadStateResolved: outcome.unreadStateResolved,
      saveResult: outcome.saveResult,
    );
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
    await _syncChatFromCore(chatId);
  }

  Future<void> _handleReactionsChanged(int chatId, int msgId) async {
    if (msgId <= _deltaMessageIdUnset || _isDeltaMessageMarkerId(msgId)) {
      return;
    }
    await _hydrateMessage(chatId, msgId);
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
    final hydrationResult = await _hydrateMessage(chatId, msgId);
    hydrated = hydrationResult != null;
    repairedUnreadInHydrate = hydrationResult?.repairedUnread ?? false;
    unreadStateResolved = hydrationResult?.unreadStateResolved ?? false;
    if (hydrationResult == null) {
      result = 'hydrateMissing';
      traceEnd();
      return;
    }
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
    if (result == null || result.status.isOutgoing) {
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
    await reconcileUndisplayedChatReadStateFromCore(chatId);
  }

  Future<int> reconcileUndisplayedChatReadStateFromCore(
    int chatId, {
    bool repairUnreadWhenNoTargets = false,
  }) async {
    if (chatId <= _deltaChatLastSpecialId) {
      return 0;
    }
    var totalReconciled = 0;
    var truncated = false;
    final attemptedDeltaIds = <int>{};
    for (
      var page = 0;
      page < _undisplayedReadStateReconcileMaxPages;
      page += 1
    ) {
      final queriedLimit = _undisplayedReadStateReconcilePageSize * (page + 1);
      final db = await _db();
      final messages = await db.getUndisplayedMessagesByDeltaChat(
        deltaAccountId: _deltaAccountId,
        deltaChatId: chatId,
        limit: queriedLimit,
      );
      if (messages.isEmpty) {
        if (page == 0 && repairUnreadWhenNoTargets) {
          await _updateUnreadCount(chatId);
        }
        break;
      }
      final ids = <int>[];
      for (final message in messages) {
        if (!message.countsTowardUnread(
          selfJid: _selfJid,
          isGroupChat: false,
          myOccupantJid: null,
        )) {
          continue;
        }
        final deltaMsgId = message.deltaMsgId;
        if (deltaMsgId == null) {
          continue;
        }
        if (!attemptedDeltaIds.add(deltaMsgId)) {
          continue;
        }
        ids.add(deltaMsgId);
      }
      final reconciled = await reconcileDeltaMessageReadStateFromCore(
        chatId: chatId,
        messageIds: ids,
        source: 'undisplayed',
        repairUnreadWhenNoTargets: page == 0 && repairUnreadWhenNoTargets,
      );
      totalReconciled += reconciled;
      if (messages.length < queriedLimit) {
        break;
      }
      truncated = page == _undisplayedReadStateReconcileMaxPages - 1;
    }
    if (truncated) {
      SafeLogging.profileTrace(
        'email.deltaTargetedReadStateReconcile',
        'truncated',
        fields: <String, Object?>{
          'accountId': _deltaAccountId,
          'chatId': chatId,
          'pageSize': _undisplayedReadStateReconcilePageSize,
          'maxPages': _undisplayedReadStateReconcileMaxPages,
          'reconciledCount': totalReconciled,
        },
      );
    }
    return totalReconciled;
  }

  Future<int> reconcileDeltaMessageReadStateFromCore({
    required int chatId,
    required Iterable<int> messageIds,
    String source = 'targeted',
    bool repairUnreadWhenNoTargets = false,
  }) async {
    if (chatId <= _deltaChatLastSpecialId) {
      return 0;
    }
    final stopwatch = Stopwatch()..start();
    final ids = <int>[];
    final seenIds = <int>{};
    for (final messageId in messageIds) {
      if (messageId <= _deltaMessageIdUnset ||
          _isDeltaMessageMarkerId(messageId)) {
        continue;
      }
      if (seenIds.add(messageId)) {
        ids.add(messageId);
      }
    }
    var reconciledCount = 0;
    var repairedUnread = false;
    final results = await _hydrateMessageStatuses(
      chatId,
      ids,
      expectedChatId: chatId,
    );
    for (final result in results) {
      if (result.status.isOutgoing) {
        continue;
      }
      reconciledCount += 1;
      repairedUnread = repairedUnread || result.repairedUnread;
    }
    if (ids.isNotEmpty) {
      await _updateUnreadCount(chatId);
    } else if (repairUnreadWhenNoTargets) {
      await _updateUnreadCount(chatId);
      repairedUnread = true;
    }
    SafeLogging.profileTrace(
      'email.deltaTargetedReadStateReconcile',
      'end',
      fields: <String, Object?>{
        'accountId': _deltaAccountId,
        'chatId': chatId,
        'source': source,
        'targetCount': ids.length,
        'reconciledCount': reconciledCount,
        'repairedUnread': repairedUnread,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return reconciledCount;
  }

  Future<int> reconcileChatReadStateFromCore(int chatId) async {
    if (chatId <= _deltaChatLastSpecialId) {
      return 0;
    }
    final stopwatch = Stopwatch()..start();
    final db = await _db();
    final storedMessages = await db.getMessagesByDeltaChat(
      deltaAccountId: _deltaAccountId,
      deltaChatId: chatId,
    );
    final msgIds = <int>[];
    for (final message in storedMessages) {
      final msgId = message.deltaMsgId;
      if (msgId != null &&
          msgId > _deltaMessageIdUnset &&
          !_isDeltaMessageMarkerId(msgId)) {
        msgIds.add(msgId);
      }
    }
    var reconciledCount = 0;
    var repairedUnread = false;
    final results = await _hydrateMessageStatuses(
      chatId,
      msgIds,
      expectedChatId: chatId,
    );
    for (final result in results) {
      if (result.status.isOutgoing) {
        continue;
      }
      reconciledCount += 1;
      repairedUnread = repairedUnread || result.repairedUnread;
    }
    await _updateUnreadCount(chatId);
    SafeLogging.profileTrace(
      'email.deltaChatReadStateReconcile',
      'end',
      fields: <String, Object?>{
        'accountId': _deltaAccountId,
        'chatId': chatId,
        'storedCount': storedMessages.length,
        'reconciledCount': reconciledCount,
        'repairedUnread': repairedUnread,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return reconciledCount;
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
    final hydratedLatestWindow = await _hydrateLatestChatWindowForSnapshot(
      chatId: chatId,
      chat: chat,
      db: db,
      requestedWindow: _chatLevelHydrationWindow,
    );
    SafeLogging.profileTrace(
      'email.deltaSyncChatMessages',
      'decision',
      fields: <String, Object?>{
        'chatId': chatId,
        'chatHash': SafeLogging.profileFingerprint(chat.jid.trim()),
        'hydratedLatestWindow': hydratedLatestWindow,
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

  Future<void> hydrateMessage(int msgId) async {
    final msg = await _core.getMessage(msgId);
    if (msg == null) return;
    await _ingestDeltaMessage(eventChatId: msg.chatId, msg: msg);
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
    var storedExactCount = 0;
    var storedMissingContentCount = 0;
    final idsToHydrate = <int>[];
    for (final freshId in freshIds) {
      final stored = storedByDeltaId[freshId];
      if (stored == null) {
        idsToHydrate.add(freshId);
        continue;
      }
      if (!_hasStoredMessageContent(stored)) {
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
        await _ingestDeltaMessage(eventChatId: chatId, msg: msg);
        hydratedCount += 1;
        if (chatId > _deltaChatLastSpecialId) {
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
    Chat? chat,
    bool skipSystemChatCheck = false,
    bool statusOnly = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    var result = 'completed';
    var repairedUnread = false;
    var unreadStateResolved = false;
    MessageSaveResult? saveResult;
    var resolvedChatHash = '';
    var existingState = 'unknown';
    _DeltaIngestOutcome outcome({
      bool repairedUnread = false,
      bool unreadStateResolved = false,
      MessageSaveResult? saveResult,
    }) {
      return _DeltaIngestOutcome(
        repairedUnread: repairedUnread,
        unreadStateResolved: unreadStateResolved,
        saveResult: saveResult,
      );
    }

    try {
      final int deltaAccountId = _deltaAccountId;
      final int chatId = msg.chatId > 0 ? msg.chatId : eventChatId;
      if (chatId != eventChatId) {
        chat = null;
      }
      if (!skipSystemChatCheck && await _isDeltaSystemChat(chatId)) {
        _log.finer(
          'Dropping Delta system-chat message msgId=${msg.id} chatId=$chatId',
        );
        result = 'systemChat';
        unreadStateResolved = true;
        return outcome(unreadStateResolved: unreadStateResolved);
      }
      final resolvedChat = chat ?? await _ensureChat(chatId);
      resolvedChatHash = SafeLogging.profileFingerprint(
        resolvedChat.jid.trim(),
      );
      if (_isHiddenMultiDeviceSyncMessage(msg, chat: resolvedChat)) {
        _log.finer(
          'Dropping Multi Device Synchronization placeholder message '
          'msgId=${msg.id} chatId=$chatId',
        );
        result = 'hiddenMultiDeviceSync';
        unreadStateResolved = true;
        return outcome(unreadStateResolved: unreadStateResolved);
      }
      final db = await _db();
      if (msg.isEncryptionStatusSystemMessage) {
        await db.ensureEmailEncryptionStatusMarkerForChat(resolvedChat.jid);
        result = 'encryptionStatusMarker';
        unreadStateResolved = true;
        return outcome(unreadStateResolved: unreadStateResolved);
      }
      final stanzaId = _emailRowKey();
      var existingByDeltaId = await db.recoverStaleDeltaMessageLocator(
        deltaMsgId: msg.id,
        deltaAccountId: deltaAccountId,
        deltaChatId: chatId,
        chatJid: resolvedChat.jid,
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
        existingByDeltaId = await db.rehomeDeltaMessage(
          deltaMsgId: msg.id,
          deltaAccountId: deltaAccountId,
          deltaChatId: chatId,
          chatJid: resolvedChat.jid,
          senderJid: msg.isOutgoing
              ? _resolveOutgoingSenderJid(resolvedChat)
              : resolvedChat.jid,
          selfJid: _xmppSelfJid,
          emailSelfJid: _selfJid,
        );
      }
      if (existingByDeltaId != null) {
        existingState = 'existing';
        final existing = existingByDeltaId;
        await _logEmailPartDiagnostic(
          stage: 'ingest-existing-delta',
          eventChatId: chatId,
          msg: msg,
          resolvedChat: resolvedChat,
          existingByDelta: existing,
          storedMessage: existing,
        );
        repairedUnread = await _updateExistingMessage(
          existing: existing,
          msg: msg,
          statusOnly: statusOnly,
        );
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
          await _learnAutocryptContactKeyForIncomingMessage(
            db: db,
            chat: resolvedChat,
            msg: msg,
          );
        }
        result = repairedUnread ? 'existingRepairedUnread' : 'existingUpdated';
        unreadStateResolved = true;
        return outcome(
          repairedUnread: repairedUnread,
          unreadStateResolved: unreadStateResolved,
        );
      }
      existingState = 'new';
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
        result = 'blockedAddress';
        unreadStateResolved = true;
        return outcome(unreadStateResolved: unreadStateResolved);
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
      if (isOutgoing) {
        message = await _withReconstructedQuote(
          db: db,
          message: message,
          msg: msg,
          deltaAccountId: deltaAccountId,
          chatId: chatId,
        );
      }
      await _logEmailPartDiagnostic(
        stage: 'ingest-new-before-store',
        eventChatId: chatId,
        msg: msg,
        resolvedChat: resolvedChat,
        storedMessage: message,
        resolvedOriginId: nativeOriginId,
      );
      saveResult = await _storeMessage(db: db, message: message);
      unreadStateResolved = true;
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
      if (!isOutgoing &&
          msg.needsDownload &&
          warning != MessageWarning.emailSpamQuarantined) {
        final blockAddress = normalizedAddressValue(
          resolvedChat.emailFromAddress ??
              resolvedChat.emailAddress ??
              resolvedChat.jid,
        );
        final blocklistEntry = blockAddress == null
            ? null
            : await db.getEmailBlocklistEntry(blockAddress);
        if (msg.downloadState == DeltaDownloadState.failure) {
          _autoDownloadScheduledMessageIds.remove(msg.id);
        }
        if (blocklistEntry == null &&
            _autoDownloadScheduledMessageIds.add(msg.id)) {
          fireAndForget(
            () => _autoDownloadQueue.run(() async {
              var downloaded = false;
              try {
                downloaded = await _core.downloadFullMessage(msg.id);
                if (downloaded) {
                  _originIdHydrationExhausted.remove(msg.id);
                }
              } finally {
                if (!downloaded) {
                  _autoDownloadScheduledMessageIds.remove(msg.id);
                }
              }
            }),
            operationName: 'DeltaEventConsumer.downloadFullMessage',
          );
        }
      }
      result = 'storedNew';
      return outcome(
        unreadStateResolved: unreadStateResolved,
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
        );
      }
    }
  }

  void _traceDeltaIngestEnd({
    required int eventChatId,
    required DeltaMessage msg,
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
  }) {
    SafeLogging.profileTrace(
      'email.deltaIngest',
      'end',
      fields: <String, Object?>{
        'eventChatId': eventChatId,
        'msgChatId': msg.chatId,
        'msgId': msg.id,
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
    if (deliveryStatus.acked != existing.acked ||
        deliveryStatus.received != existing.received ||
        displayed != existing.displayed) {
      merged = merged.copyWith(
        acked: deliveryStatus.acked,
        received: deliveryStatus.received,
        displayed: displayed,
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
    if (deliveryStatus.acked != existing.acked ||
        deliveryStatus.received != existing.received ||
        displayed != existing.displayed) {
      merged = merged.copyWith(
        acked: deliveryStatus.acked,
        received: deliveryStatus.received,
        displayed: displayed,
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
    if (_messageUpdateAffectsChatSummary(updatedFields)) {
      await _refreshStoredChatSummary(chatJid: next.chatJid, db: db);
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

  Future<bool> _updateExistingMessage({
    required Message existing,
    required DeltaMessage msg,
    bool statusOnly = false,
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
      return statusUpdate.repairedUnread;
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
      return repairedUnread;
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
      _traceDeltaUpdateMessage(
        msgId: msg.id,
        statusOnly: statusOnly,
        result: 'htmlOnlySkipped',
        updatedFields: updatedFields,
        repairedUnread: false,
        reuseMissReason: reuseDecision.missReason,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
      return false;
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
    return false;
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
    return SafeLogging.profileFingerprint(labels.join('|'));
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
    if (existing.rfc822BodyStatus.isPendingDownload) {
      return (missReason: 'pendingRfc822BodyDownload', reuse: false);
    }
    if (existing.rfc822BodyContentUnavailable &&
        _looksLikeDeltaBodyPlaceholder(inlineContent.rawText)) {
      return (missReason: 'unavailableRfc822Placeholder', reuse: false);
    }
    final contentMatches = _storedContentMatchesDeltaInlineProjection(
      existing: existing,
      inlineContent: inlineContent,
    );
    if (contentMatches && !msg.needsDownload) {
      return (missReason: null, reuse: true);
    }
    final hasStoredContent = _hasStoredMessageContent(existing);
    if (existing.hasRfc822BodyContent && (hasStoredContent || msg.hasFile)) {
      return (missReason: null, reuse: true);
    }
    if (_looksLikeDeltaBodyPlaceholder(inlineContent.rawText) &&
        (hasStoredContent || msg.hasFile)) {
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
    if (!hasStoredContent && !msg.hasFile) {
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

  Future<bool> _storedFileMetadataMatchesDelta({
    required XmppDatabase db,
    required Message existing,
    required DeltaMessage msg,
  }) async {
    final existingMetadataId = existing.fileMetadataID?.trim();
    if (!msg.hasFile) {
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
    if (_looksLikeDeltaBodyPlaceholder(inlineContent.rawText)) {
      return false;
    }
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

  bool _looksLikeDeltaBodyPlaceholder(String? value) {
    final trimmed = value?.trim();
    return trimmed != null &&
        trimmed.startsWith('[') &&
        trimmed.endsWith(' message]');
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
    if (message.quoting != null) {
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
    return message.copyWith(quoting: quotedRow.stanzaID);
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
  }) async {
    final inlineContent = _deltaInlineContentProjection(msg);
    var next = message.copyWith(
      body: inlineContent.body,
      htmlBody: inlineContent.htmlBody,
      subject: inlineContent.subject,
    );
    next = await _applyRfc822BodyContentForSplitMessage(
      previous: message,
      message: next,
      msg: msg,
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
    next = _applyForwardedMetadata(
      message: next,
      rawBody: metadataRawBody,
      normalizedHtml: metadataNormalizedHtml,
      sanitizedSubject: inlineContent.subject,
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
  }) async {
    if (msg.id <= _deltaMessageIdUnset) {
      return _preserveExistingRfc822BodyContent(
        previous: previous,
        message: message,
      );
    }
    final retryUnavailablePlaceholder =
        previous.rfc822BodyContentUnavailable &&
        (_looksLikeDeltaBodyPlaceholder(msg.text) ||
            _looksLikeDeltaBodyPlaceholder(message.body));
    if (previous.rfc822BodyContentUnavailable &&
        !msg.needsDownload &&
        !retryUnavailablePlaceholder) {
      return message.copyWith(
        rfc822BodyStatus: EmailRfc822BodyStatus.unavailable,
        pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
      );
    }
    final rfc822Body = await _core.getMessageRfc822Body(msg.id);
    if (rfc822Body == null || !rfc822Body.hasBody) {
      return _preserveOrMarkUnavailableRfc822BodyContent(
        previous: previous,
        message: message,
        pendingDownload: msg.needsDownload,
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
