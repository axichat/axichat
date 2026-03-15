// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:ui';

import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/sync/pending_outgoing_email.dart';
import 'package:axichat/src/email/util/async_queue.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/email/util/email_message_ids.dart';
import 'package:axichat/src/email/util/email_message_merge.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/email/util/delta_message_ids.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';

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

class DeltaEventConsumer {
  DeltaEventConsumer({
    required Future<XmppDatabase> Function() databaseBuilder,
    required DeltaContextHandle context,
    AttachmentAutoDownload defaultChatAttachmentAutoDownload =
        AttachmentAutoDownload.blocked,
    AppLocalizations Function()? localizationsProvider,
    String? Function()? selfJidProvider,
    Logger? logger,
  }) : _databaseBuilder = databaseBuilder,
       _context = context,
       _defaultChatAttachmentAutoDownload = defaultChatAttachmentAutoDownload,
       _localizationsProvider = localizationsProvider,
       _selfJidProvider = selfJidProvider,
       _log = logger ?? Logger('DeltaEventConsumer');

  final Future<XmppDatabase> Function() _databaseBuilder;
  final DeltaContextHandle _context;
  AttachmentAutoDownload _defaultChatAttachmentAutoDownload;
  final AppLocalizations Function()? _localizationsProvider;
  final String? Function()? _selfJidProvider;
  final Logger _log;
  Future<void>? _chatlistRefreshInFlight;
  Future<Set<int>>? _archivedChatlistInFlight;
  DateTime? _archivedChatlistFetchedAt;
  final Set<int> _archivedChatIds = <int>{};
  final EmailAsyncQueue _autoDownloadQueue = EmailAsyncQueue();
  final EmailAsyncQueue _originIdHydrationQueue = EmailAsyncQueue();
  final Set<int> _originIdHydrationPending = <int>{};

  AppLocalizations get _l10n =>
      _localizationsProvider?.call() ??
      lookupAppLocalizations(const Locale('en'));

  void updateDefaultChatAttachmentAutoDownload(AttachmentAutoDownload value) {
    _defaultChatAttachmentAutoDownload = value;
  }

  String get _selfJid =>
      _selfJidProvider?.call().resolveDeltaPlaceholderJid() ?? _emptyJid;

  int get _deltaAccountId =>
      _context.accountId ?? DeltaAccountDefaults.legacyId;

  Future<bool> bootstrapFromCore() async {
    final int deltaAccountId = _deltaAccountId;
    final chatlist = await _context.getChatlist();
    final archivedChatlist = await _context.getChatlist(
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
      final chat = await _ensureChat(chatId);
      var updated = chat;
      final isArchived = archivedChatIds.contains(chatId);
      if (updated.archived != isArchived) {
        updated = updated.copyWith(archived: isArchived);
      }
      if (entry.msgId > 0 && !_isDeltaMessageMarkerId(entry.msgId)) {
        final last = await _context.getMessage(entry.msgId);
        final timestamp = last?.timestamp;
        final preview = _previewTextForDeltaMessage(last);
        if (timestamp != null && timestamp != updated.lastChangeTimestamp) {
          updated = updated.copyWith(lastChangeTimestamp: timestamp);
        }
        if (preview != null &&
            preview.isNotEmpty &&
            preview != updated.lastMessage) {
          updated = updated.copyWith(lastMessage: preview);
        }
      }
      if (updated != chat) {
        await db.updateChat(updated);
      }
    }

    for (final chatId in entriesByChatId.keys) {
      if (await _isDeltaSystemChat(chatId)) {
        continue;
      }
      final chat = await _ensureChat(chatId);
      final msgIds = await _context.getChatMessageIds(chatId: chatId);
      final filteredMsgIds = msgIds
          .where((id) => !_isDeltaMessageMarkerId(id))
          .toList();
      if (filteredMsgIds.isEmpty) {
        continue;
      }
      const int startIndex = 0;
      for (var index = startIndex; index < filteredMsgIds.length; index++) {
        final msg = await _context.getMessage(filteredMsgIds[index]);
        if (msg == null) continue;
        await _ingestDeltaMessage(
          chatId: chatId,
          msg: msg,
          chat: chat,
          skipSystemChatCheck: true,
        );
      }

      final last = await _context.getMessage(filteredMsgIds.last);
      final lastTimestamp = last?.timestamp;
      if (lastTimestamp != null) {
        final stored = await db.getChatByDeltaChatId(
          chatId,
          accountId: deltaAccountId,
        );
        if (stored != null && stored.lastChangeTimestamp != lastTimestamp) {
          await db.updateChat(
            stored.copyWith(lastChangeTimestamp: lastTimestamp),
          );
          await db.repairChatSummaryPreservingTimestamp(stored.jid);
        }
      }
      await _updateUnreadCount(chatId);
    }

    return didBootstrap;
  }

  Future<void> refreshChatlistSnapshot() async {
    final inFlight = _chatlistRefreshInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _refreshChatlistSnapshotInternal();
    _chatlistRefreshInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_chatlistRefreshInFlight, future)) {
        _chatlistRefreshInFlight = null;
      }
    }
  }

  Future<void> _refreshChatlistSnapshotInternal() async {
    final int deltaAccountId = _deltaAccountId;
    final chatlist = await _context.getChatlist();
    final archivedChatlist = await _context.getChatlist(
      flags: _deltaChatlistArchivedOnlyFlag,
    );
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

    final db = await _db();
    final knownChatIds = entriesByChatId.keys.toSet();
    final deltaChats = await db.getDeltaChats(accountId: deltaAccountId);
    for (final chat in deltaChats) {
      final deltaChatId = chat.deltaChatId;
      if (deltaChatId == null || deltaChatId <= _deltaChatLastSpecialId) {
        continue;
      }
      if (!knownChatIds.contains(deltaChatId)) {
        await db.deleteEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: deltaAccountId,
        );
        await db.trimChatMessages(
          jid: chat.jid,
          maxMessages: 0,
          deltaAccountId: deltaAccountId,
        );
        final remaining = await db.countEmailChatAccounts(chat.jid);
        if (remaining == 0) {
          await db.removeChat(chat.jid);
        }
      }
    }
    for (final entry in entriesByChatId.values) {
      final chatId = entry.chatId;
      if (await _isDeltaSystemChat(chatId)) {
        continue;
      }
      final chat = await _ensureChat(chatId);
      final isArchived = archivedChatIds.contains(chatId);
      var updated = chat;
      var hydratedMessages = false;
      DateTime? lastTimestamp;
      String? lastPreview;
      if (entry.msgId > 0 && !_isDeltaMessageMarkerId(entry.msgId)) {
        final existing = await db.getMessageByDeltaId(
          entry.msgId,
          deltaAccountId: deltaAccountId,
        );
        if (existing != null) {
          lastTimestamp = existing.timestamp;
          lastPreview = await _previewTextForStoredMessage(
            db: db,
            message: existing,
          );
        } else {
          final last = await _context.getMessage(entry.msgId);
          lastTimestamp = last?.timestamp;
          lastPreview = _previewTextForDeltaMessage(last);
          if (last != null) {
            final stanzaId = _stanzaId(entry.msgId);
            final stored = await db.getMessageByStanzaID(stanzaId);
            if (stored == null) {
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
      }
      var storedUnreadCount = await db.countUnreadMessagesForChat(
        updated.jid,
        selfJid: _selfJid,
      );
      final freshCount = await _context.getFreshMessageCountSafe(chatId);
      if (storedUnreadCount > 0 ||
          (freshCount.supported && freshCount.count > 0)) {
        await _syncChatMessages(chatId);
        await _refreshStoredChatSummary(chatJid: updated.jid, db: db);
        hydratedMessages = true;
        storedUnreadCount = await db.countUnreadMessagesForChat(
          updated.jid,
          selfJid: _selfJid,
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
  }

  Future<int> backfillChatHistory({
    required int chatId,
    required String chatJid,
    required int desiredWindow,
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
    final localCount = await db.countChatMessages(
      chatJid,
      filter: filter,
      includePseudoMessages: false,
    );
    if (localCount >= desiredWindow) {
      return _deltaMessageIdUnset;
    }
    final needed = desiredWindow - localCount;
    final chat = await _ensureChat(chatId);
    final marker = beforeMessageId ?? _deltaMessageIdUnset;
    final hasMarker = marker > _deltaMessageIdUnset;
    final rawMessageIds = await _context.getChatMessageIds(
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
        final msg = await _context.getMessage(messageId);
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
      final msg = await _context.getMessage(messageId);
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

  Future<void> handle(DeltaCoreEvent event) async {
    final eventType = DeltaEventType.fromCode(event.type);
    if (eventType == null) {
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
    final msg = await _context.getMessage(msgId);
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
    if (msg != null && !msg.isOutgoing) {
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
    await _hydrateMessage(chatId, msgId);
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
    );
    await db.trimChatMessages(
      jid: chat.jid,
      maxMessages: 0,
      deltaAccountId: deltaAccountId,
    );
    final remaining = await db.countEmailChatAccounts(chat.jid);
    if (remaining == 0) {
      await db.removeChat(chat.jid);
    }
  }

  Future<void> _updateUnreadCount(int chatId) async {
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (chat == null) return;
    final unreadCount = await db.countUnreadMessagesForChat(
      chat.jid,
      selfJid: _selfJid,
    );
    if (unreadCount != chat.unreadCount) {
      await db.updateChat(chat.copyWith(unreadCount: unreadCount));
    }
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
    final messageIds = await _context.getChatMessageIds(chatId: chatId);
    final filteredIds = messageIds
        .where((id) => !_isDeltaMessageMarkerId(id))
        .toList();
    if (filteredIds.isEmpty) {
      await db.trimChatMessages(
        jid: chat.jid,
        maxMessages: 0,
        deltaAccountId: _deltaAccountId,
      );
      return;
    }
    const int startIndex = 0;
    final visibleIds = filteredIds
        .skip(startIndex)
        .where((id) => id > _deltaMessageIdUnset)
        .toList(growable: false);
    if (visibleIds.isEmpty) {
      await db.trimChatMessages(
        jid: chat.jid,
        maxMessages: 0,
        deltaAccountId: _deltaAccountId,
      );
      return;
    }
    final visibleIdSet = visibleIds.toSet();
    final snapshots = await db.getMessageDeltaSnapshot(chat.jid);
    final localDeltaIds = <int>{};
    final refreshIds = <int>{};
    final staleStanzaIds = <String>[];
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
      } else {
        staleStanzaIds.add(snapshot.stanzaId);
      }
    }
    if (staleStanzaIds.isNotEmpty) {
      await db.deleteMessagesByStanzaIds(staleStanzaIds);
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
      final messages = await Future.wait(chunk.map(_context.getMessage));
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
    final msg = await _context.getMessage(msgId);
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
    final int deltaAccountId = _deltaAccountId;
    final stanzaId = _stanzaId(msg.id);
    final db = await _db();
    final existing = await db.getMessageByStanzaID(stanzaId);
    if (existing != null) {
      await _updateExistingMessage(existing: existing, msg: msg);
      await _scheduleOriginIdHydrationIfNeeded(
        existing: existing,
        msgId: msg.id,
        accountId: deltaAccountId,
      );
      return;
    }
    final existingByDeltaId = await db.getMessageByDeltaId(
      msg.id,
      deltaAccountId: deltaAccountId,
    );
    if (existingByDeltaId != null) {
      await _updateExistingMessage(existing: existingByDeltaId, msg: msg);
      await _scheduleOriginIdHydrationIfNeeded(
        existing: existingByDeltaId,
        msgId: msg.id,
        accountId: deltaAccountId,
      );
      return;
    }
    final existingByChat = await db.getMessageByDeltaId(
      msg.id,
      chatJid: resolvedChat.jid,
    );
    if (existingByChat != null) {
      await _updateExistingMessage(existing: existingByChat, msg: msg);
      await _scheduleOriginIdHydrationIfNeeded(
        existing: existingByChat,
        msgId: msg.id,
        accountId: deltaAccountId,
      );
      return;
    }
    final Message? persistedPending = msg.isOutgoing
        ? await _matchPersistedOutgoingMessage(
            db: db,
            msg: msg,
            chatId: chatId,
            deltaAccountId: deltaAccountId,
          )
        : null;
    if (persistedPending != null) {
      final Message updatedPending = persistedPending.copyWith(
        deltaMsgId: msg.id,
        deltaChatId: chatId,
        deltaAccountId: deltaAccountId,
      );
      if (updatedPending != persistedPending) {
        await db.updateMessage(updatedPending);
      }
      await _updateExistingMessage(existing: updatedPending, msg: msg);
      await _scheduleOriginIdHydrationIfNeeded(
        existing: updatedPending,
        msgId: msg.id,
        accountId: deltaAccountId,
      );
      return;
    }
    const String? originId = null;
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
    final resolvedError = msg.isOutgoingFailed
        ? DeltaErrorMapper.resolve(msg.error)
        : MessageError.none;
    var message = Message(
      stanzaID: stanzaId,
      senderJid: senderJid,
      chatJid: resolvedChat.jid,
      timestamp: timestamp,
      originID: originId,
      error: resolvedError,
      warning: warning,
      encryptionProtocol: EncryptionProtocol.none,
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
    await _storeMessage(db: db, message: message, chatJid: resolvedChat.jid);
    await _refreshStoredChatSummary(chatJid: resolvedChat.jid, db: db);
    await _scheduleOriginIdHydration(msgId: msg.id, accountId: deltaAccountId);
    final bool isSpamQuarantined =
        warning == MessageWarning.emailSpamQuarantined;
    final fileSize = msg.fileSize;
    final shouldAutoDownloadPartial =
        !isOutgoing && msg.needsDownload && !isSpamQuarantined;
    if (shouldAutoDownloadPartial) {
      final shouldDownload = msg.hasFile
          ? (resolvedChat.attachmentAutoDownload ??
                        _defaultChatAttachmentAutoDownload)
                    .isAllowed &&
                (fileSize == null || fileSize <= maxAttachmentAutoDownloadBytes)
          : true;
      if (shouldDownload) {
        fireAndForget(
          () => _autoDownloadQueue.run(
            () async => _context.downloadFullMessage(msg.id),
          ),
          operationName: 'DeltaEventConsumer.downloadFullMessage',
        );
      }
    }
    await _updateChatTimestamp(chatId: chatId, timestamp: timestamp);
  }

  Future<Message?> _matchPersistedOutgoingMessage({
    required XmppDatabase db,
    required DeltaMessage msg,
    required int chatId,
    required int deltaAccountId,
  }) async {
    const maxTimestampDelta = Duration(minutes: 2);
    final maxTimestampDeltaMicros = maxTimestampDelta.inMicroseconds;
    final PendingOutgoingEmailSignature incomingSignature =
        PendingOutgoingEmailSignature.fromOutgoing(
          subject: msg.subject,
          text: msg.text,
          html: msg.html,
          fileName: msg.fileName,
          filePath: msg.filePath,
        );
    if (incomingSignature.isEmpty) {
      return null;
    }
    final List<Message> candidates = await db.getPendingOutgoingDeltaMessages(
      deltaAccountId: deltaAccountId,
      deltaChatId: chatId,
    );
    if (candidates.isEmpty) {
      return null;
    }
    final int? incomingTimestampMicros = msg.timestamp?.microsecondsSinceEpoch;
    Message? closestMatch;
    int? closestDelta;
    final Map<String, FileMetadataData?> metadataById =
        <String, FileMetadataData?>{};
    for (final Message candidate in candidates) {
      if (!_isSelfPendingSender(candidate)) {
        continue;
      }
      final String? metadataId = candidate.fileMetadataID?.trim();
      FileMetadataData? metadata;
      if (metadataId != null && metadataId.isNotEmpty) {
        if (metadataById.containsKey(metadataId)) {
          metadata = metadataById[metadataId];
        } else {
          metadata = await db.getFileMetadata(metadataId);
          metadataById[metadataId] = metadata;
        }
      }
      final PendingOutgoingEmailSignature candidateSignature =
          PendingOutgoingEmailSignature.fromMessage(
            message: candidate,
            metadata: metadata,
          );
      if (!candidateSignature.matches(incomingSignature)) {
        continue;
      }
      if (incomingTimestampMicros == null) {
        return candidate;
      }
      final int? candidateTimestamp =
          candidate.timestamp?.microsecondsSinceEpoch;
      if (candidateTimestamp == null) {
        return candidate;
      }
      final int delta = (candidateTimestamp - incomingTimestampMicros).abs();
      if (delta > maxTimestampDeltaMicros) {
        continue;
      }
      if (closestDelta == null || delta < closestDelta) {
        closestDelta = delta;
        closestMatch = candidate;
      }
    }
    return closestMatch;
  }

  String _resolveOutgoingSenderJid(Chat chat) {
    final String resolvedSelf = _selfJid;
    if (resolvedSelf.isNotEmpty) {
      return resolvedSelf;
    }
    final String? fallback = chat.emailFromAddress.resolveDeltaPlaceholderJid();
    return fallback ?? _emptyJid;
  }

  bool _isSelfPendingSender(Message message) {
    final String normalizedSender = normalizedAddressValueOrEmpty(
      message.senderJid,
    );
    if (normalizedSender.isEmpty) {
      return false;
    }
    if (normalizedSender.isDeltaPlaceholderJid) {
      return true;
    }
    final String normalizedSelf = normalizedAddressValueOrEmpty(_selfJid);
    if (normalizedSelf.isEmpty) {
      return false;
    }
    return normalizedSender == normalizedSelf;
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
      if (deliveryStatus.acked != existing.acked ||
          deliveryStatus.received != existing.received ||
          deliveryStatus.displayed != existing.displayed) {
        next = next.copyWith(
          acked: deliveryStatus.acked,
          received: deliveryStatus.received,
          displayed: deliveryStatus.displayed,
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
    next = await _buildDeltaMessageContent(
      db: db,
      message: next,
      chatId: msg.chatId,
      msg: msg,
    );
    next = _preserveHtmlIfEquivalent(existing: existing, next: next);
    final updatedFields = existing.diffFields(next);
    if (_shouldSkipHtmlOnlyUpdate(
      existing: existing,
      updatedFields: updatedFields,
    )) {
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
      }
      await db.updateMessage(next);
      await _refreshStoredChatSummary(chatJid: next.chatJid, db: db);
    }
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

  String _canonicalHtml(String? html) {
    return HtmlContentCodec.canonicalizeHtml(html) ?? '';
  }

  Future<void> _scheduleOriginIdHydration({
    required int msgId,
    required int accountId,
  }) async {
    if (_originIdHydrationPending.contains(msgId)) {
      return;
    }
    _originIdHydrationPending.add(msgId);
    await _originIdHydrationQueue.run(() async {
      try {
        await _hydrateOriginId(msgId: msgId, accountId: accountId);
      } on Exception catch (error, stackTrace) {
        _log.fine('Failed to hydrate Delta origin ID.', error, stackTrace);
      } finally {
        _originIdHydrationPending.remove(msgId);
      }
    });
  }

  Future<void> _scheduleOriginIdHydrationIfNeeded({
    required Message existing,
    required int msgId,
    required int accountId,
  }) async {
    final String? existingOrigin = existing.originID?.trim();
    if (existingOrigin != null && existingOrigin.isNotEmpty) {
      return;
    }
    await _scheduleOriginIdHydration(msgId: msgId, accountId: accountId);
  }

  Future<void> _hydrateOriginId({
    required int msgId,
    required int accountId,
  }) async {
    final stanzaId = _stanzaId(msgId);
    const maxAttempts = 60;
    const attemptStep = 1;
    const delay = Duration(seconds: 1);
    const lastAttemptIndex = maxAttempts - attemptStep;
    for (int attempt = 0; attempt < maxAttempts; attempt += attemptStep) {
      final originId = await _resolveOriginId(msgId);
      if (originId != null) {
        final db = await _db();
        final existing =
            await db.getMessageByDeltaId(msgId, deltaAccountId: accountId) ??
            await db.getMessageByStanzaID(stanzaId);
        if (existing == null) {
          return;
        }
        final existingOrigin = existing.originID?.trim();
        if (existingOrigin != null && existingOrigin.isNotEmpty) {
          return;
        }
        final duplicate = await db.getMessageByOriginID(originId);
        if (duplicate != null &&
            canMergeOriginMessages(existing: existing, duplicate: duplicate)) {
          final primary = resolveOriginMergePrimary(
            existing: existing,
            duplicate: duplicate,
            selfJid: _selfJid,
          );
          final primaryIsExisting = primary.stanzaID == existing.stanzaID;
          final secondary = primaryIsExisting ? duplicate : existing;
          final merged = mergeOriginMessages(
            primary: primary,
            duplicate: secondary,
            originId: originId,
          );
          await db.updateMessage(merged);
          await db.deleteMessage(secondary.stanzaID);
          return;
        }
        await db.updateMessage(existing.copyWith(originID: originId));
        return;
      }
      if (attempt < lastAttemptIndex) {
        await Future<void>.delayed(delay);
      }
    }
  }

  Future<String?> _resolveOriginId(int msgId) async {
    final headers = await _context.getMessageMimeHeaders(msgId);
    return parseEmailMessageId(headers);
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
    final chat = await resolvedDb.getChat(chatJid);
    if (chat == null) {
      return;
    }
    final messages = await resolvedDb.getChatMessages(
      chatJid,
      start: 0,
      end: 1,
      filter: MessageTimelineFilter.allWithContact,
    );
    final lastMessage = messages.isEmpty ? null : messages.first;
    final preview = lastMessage == null
        ? null
        : await _previewTextForStoredMessage(
            db: resolvedDb,
            message: lastMessage,
          );
    final updated = chat.copyWith(
      lastMessage: preview,
      lastChangeTimestamp: lastMessage?.timestamp ?? chat.lastChangeTimestamp,
    );
    if (updated != chat) {
      await resolvedDb.updateChat(updated);
    }
  }

  Future<String?> _previewTextForStoredMessage({
    required XmppDatabase db,
    required Message message,
  }) async {
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

  String? _previewTextForDeltaMessage(DeltaMessage? message) {
    if (message == null) {
      return null;
    }
    final sanitizedSubject = sanitizeEmailSubjectValue(message.subject);
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
    final remote = await _context.getChat(chatId);
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
        transport: MessageTransport.email,
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
    final remote = await _context.getChat(chatId);
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
    final archivedChatlist = await _context.getChatlist(
      flags: _deltaChatlistArchivedOnlyFlag,
    );
    return archivedChatlist
        .where((entry) => entry.chatId > _deltaChatLastSpecialId)
        .map((entry) => entry.chatId)
        .toSet();
  }

  Future<void> _updateChatTimestamp({
    required int chatId,
    required DateTime timestamp,
  }) async {
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: _deltaAccountId,
    );
    if (chat == null) return;
    if (!chat.lastChangeTimestamp.isBefore(timestamp)) return;
    await db.updateChat(chat.copyWith(lastChangeTimestamp: timestamp));
    await db.repairChatSummaryPreservingTimestamp(chat.jid);
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

  Future<Message> _buildDeltaMessageContent({
    required XmppDatabase db,
    required Message message,
    required int chatId,
    required DeltaMessage msg,
  }) async {
    final rawText = clampMessageText(msg.text);
    final rawHtml = clampMessageHtml(msg.html);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(rawHtml);
    final sanitizedSubject = sanitizeEmailSubjectValue(msg.subject);
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
    next = await _applyShareMetadata(
      db: db,
      message: next,
      rawBody: rawText,
      rawHtml: rawHtml,
      chatId: chatId,
      msgId: msg.id,
      deltaAccountId: message.deltaAccountId,
    );
    next = await _attachFileMetadata(db: db, message: next, delta: msg);
    return next;
  }

  Future<void> _storeMessage({
    required XmppDatabase db,
    required Message message,
    required String chatJid,
  }) async {
    await db.saveMessage(message, selfJid: _selfJid);
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
    final resolvedMetadata = _metadataFromDelta(
      delta: delta,
      metadataId: metadataId,
    );
    final merged = _mergeMetadata(existing, resolvedMetadata);
    if (merged != null && (existing == null || merged != existing)) {
      await db.saveFileMetadata(merged);
    }
    var next = message.copyWith(
      fileMetadataID: merged?.id ?? existing?.id ?? resolvedMetadata.id,
    );
    final normalizedBody = next.body?.trim() ?? '';
    if (normalizedBody.isEmpty) {
      next = next.copyWith(body: _attachmentLabel(merged ?? resolvedMetadata));
    }
    return next;
  }

  FileMetadataData _metadataFromDelta({
    required DeltaMessage delta,
    required String metadataId,
  }) {
    final path = delta.filePath?.trim();
    final sanitizedPath = path == null || path.isEmpty ? null : path;
    final sanitizedMimeType = sanitizeEmailMimeType(delta.fileMime);
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
    return sanitizeEmailAttachmentFilename(
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
    final remote = await _context.getChat(chatId);
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

String _stanzaId(int msgId) => deltaMessageStanzaId(msgId);

String _stripSubjectHeader(String body, String subject) {
  final trimmedBody = body.trimLeft();
  if (!trimmedBody.startsWith(subject)) {
    return trimmedBody;
  }
  var remainder = trimmedBody.substring(subject.length);
  remainder = remainder.replaceFirst(RegExp(r'^\s+'), '');
  return remainder;
}
