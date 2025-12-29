import 'dart:async';

import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/email/email_metadata.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart'
    show serverOnlyChatMessageCap;
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';

const _deltaDomain = 'delta.chat';
const _deltaSelfJid = 'dc-self@$_deltaDomain';
const int _deltaChatLastSpecialId = DeltaChatId.lastSpecial;
const int _deltaChatIdUnset = DeltaChatId.none;
const _bootstrapYieldEveryMessages = 40;
const int _deltaMessageIdUnset = DeltaMessageId.none;
const int _minimumHistoryWindow = 1;
const int _deltaChatlistArchivedOnlyFlag = DeltaChatlistFlags.archivedOnly;
const String _deltaAttachmentFallbackPrefix = 'attachment-';

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
    DeltaMessageDeliveryStatus(
  acked: false,
  received: false,
  displayed: false,
);
const DeltaMessageDeliveryStatus _deltaOutgoingDeliveredStatus =
    DeltaMessageDeliveryStatus(
  acked: true,
  received: true,
  displayed: false,
);
const DeltaMessageDeliveryStatus _deltaOutgoingReadStatus =
    DeltaMessageDeliveryStatus(
  acked: true,
  received: true,
  displayed: true,
);
const DeltaMessageDeliveryStatus _deltaOutgoingUnknownStatus =
    DeltaMessageDeliveryStatus(
  acked: true,
  received: false,
  displayed: false,
);
const DeltaMessageDeliveryStatus _deltaIncomingUnseenStatus =
    DeltaMessageDeliveryStatus(
  acked: false,
  received: true,
  displayed: false,
);
const DeltaMessageDeliveryStatus _deltaIncomingSeenStatus =
    DeltaMessageDeliveryStatus(
  acked: false,
  received: true,
  displayed: true,
);

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

class DeltaEventConsumer {
  DeltaEventConsumer({
    required Future<XmppDatabase> Function() databaseBuilder,
    required DeltaContextHandle context,
    MessageStorageMode messageStorageMode = MessageStorageMode.local,
    String? Function()? selfJidProvider,
    Logger? logger,
  })  : _databaseBuilder = databaseBuilder,
        _context = context,
        _messageStorageMode = messageStorageMode,
        _selfJidProvider = selfJidProvider,
        _log = logger ?? Logger('DeltaEventConsumer');

  final Future<XmppDatabase> Function() _databaseBuilder;
  final DeltaContextHandle _context;
  MessageStorageMode _messageStorageMode;
  final String? Function()? _selfJidProvider;
  final Logger _log;

  void updateMessageStorageMode(MessageStorageMode mode) {
    _messageStorageMode = mode;
  }

  String get _selfJid => _selfJidProvider?.call() ?? _deltaSelfJid;

  Future<bool> bootstrapFromCore() async {
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
        final preview = last?.text?.trim();
        if (timestamp != null && timestamp != updated.lastChangeTimestamp) {
          updated = updated.copyWith(lastChangeTimestamp: timestamp);
        }
        if (preview != null &&
            preview.isNotEmpty &&
            preview != updated.lastMessage) {
          updated = updated.copyWith(lastMessage: preview);
        }
      }
      final freshCount = await _context.getFreshMessageCountSafe(chatId);
      if (freshCount.supported && freshCount.count != updated.unreadCount) {
        updated = updated.copyWith(unreadCount: freshCount.count);
      }
      if (updated != chat) {
        await db.updateChat(updated);
      }
      await Future<void>.delayed(Duration.zero);
    }

    for (final chatId in entriesByChatId.keys) {
      if (await _isDeltaSystemChat(chatId)) {
        continue;
      }
      final chat = await _ensureChat(chatId);
      final msgIds = await _context.getChatMessageIds(chatId: chatId);
      final filteredMsgIds =
          msgIds.where((id) => !_isDeltaMessageMarkerId(id)).toList();
      if (filteredMsgIds.isEmpty) {
        continue;
      }
      final int startIndex = _messageStorageMode.isServerOnly &&
              filteredMsgIds.length > serverOnlyChatMessageCap
          ? filteredMsgIds.length - serverOnlyChatMessageCap
          : 0;
      var imported = 0;
      for (var index = startIndex; index < filteredMsgIds.length; index++) {
        final msg = await _context.getMessage(filteredMsgIds[index]);
        if (msg == null) continue;
        await _ingestDeltaMessage(
          chatId: chatId,
          msg: msg,
          chat: chat,
          skipSystemChatCheck: true,
        );
        imported += 1;
        if (imported % _bootstrapYieldEveryMessages == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      final last = await _context.getMessage(filteredMsgIds.last);
      final lastTimestamp = last?.timestamp;
      if (lastTimestamp != null) {
        final stored = await db.getChatByDeltaChatId(chatId);
        if (stored != null && stored.lastChangeTimestamp != lastTimestamp) {
          await db
              .updateChat(stored.copyWith(lastChangeTimestamp: lastTimestamp));
        }
      }
    }

    return didBootstrap;
  }

  Future<void> refreshChatlistSnapshot() async {
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
    final deltaChats = await db.getDeltaChats();
    for (final chat in deltaChats) {
      final deltaChatId = chat.deltaChatId;
      if (deltaChatId == null || deltaChatId <= _deltaChatLastSpecialId) {
        continue;
      }
      if (!knownChatIds.contains(deltaChatId)) {
        await db.removeChatMessages(chat.jid);
        await db.removeChat(chat.jid);
      }
    }
    var processed = 0;
    for (final entry in entriesByChatId.values) {
      final chatId = entry.chatId;
      if (await _isDeltaSystemChat(chatId)) {
        continue;
      }
      final chat = await _ensureChat(chatId);
      var updated = chat;
      final isArchived = archivedChatIds.contains(chatId);
      if (updated.archived != isArchived) {
        updated = updated.copyWith(archived: isArchived);
      }
      if (entry.msgId > 0 && !_isDeltaMessageMarkerId(entry.msgId)) {
        final last = await _context.getMessage(entry.msgId);
        final timestamp = last?.timestamp;
        final preview = last?.text?.trim();
        final newerTimestamp =
            timestamp != null && timestamp.isAfter(updated.lastChangeTimestamp);
        if (newerTimestamp) {
          updated = updated.copyWith(lastChangeTimestamp: timestamp);
        }
        if (newerTimestamp && preview != null && preview.isNotEmpty) {
          updated = updated.copyWith(lastMessage: preview);
        }
      }
      final freshCount = await _context.getFreshMessageCountSafe(chatId);
      if (freshCount.supported && freshCount.count != updated.unreadCount) {
        updated = updated.copyWith(unreadCount: freshCount.count);
      }
      if (updated != chat) {
        await db.updateChat(updated);
      }
      processed += 1;
      if (processed % _bootstrapYieldEveryMessages == 0) {
        await Future<void>.delayed(Duration.zero);
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
    if (desiredWindow < _minimumHistoryWindow) {
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
    final messageIds =
        rawMessageIds.where((id) => !_isDeltaMessageMarkerId(id)).toList();
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
        if (imported > _deltaMessageIdUnset &&
            imported % _bootstrapYieldEveryMessages == _deltaMessageIdUnset) {
          await Future<void>.delayed(Duration.zero);
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
      if (imported > _deltaMessageIdUnset &&
          imported % _bootstrapYieldEveryMessages == _deltaMessageIdUnset) {
        await Future<void>.delayed(Duration.zero);
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

  Future<void> _hydrateMessage(int chatId, int msgId) async {
    final msg = await _context.getMessage(msgId);
    if (msg == null) return;
    await _ingestDeltaMessage(chatId: chatId, msg: msg);
  }

  Future<void> _handleMessagesChanged(int chatId, int msgId) async {
    if (msgId > _deltaMessageIdUnset) {
      if (_isDeltaMessageMarkerId(msgId)) {
        return;
      }
      await _hydrateMessage(chatId, msgId);
      return;
    }
    if (chatId == _deltaChatIdUnset) {
      await refreshChatlistSnapshot();
      return;
    }
    if (chatId <= _deltaChatLastSpecialId) {
      return;
    }
    await _syncChatMessages(chatId);
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
    await _hydrateMessage(chatId, msgId);
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
    final chat = await db.getChatByDeltaChatId(chatId);
    if (chat == null) return;
    await db.removeChatMessages(chat.jid);
    await db.removeChat(chat.jid);
  }

  Future<void> _updateUnreadCount(int chatId) async {
    final supportsFreshMessages = await _context.probeFreshMessagesSupport();
    if (!supportsFreshMessages) {
      return;
    }
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(chatId);
    if (chat == null) return;
    final freshCount = await _context.getFreshMessageCount(chatId);
    if (freshCount != chat.unreadCount) {
      await db.updateChat(chat.copyWith(unreadCount: freshCount));
    }
  }

  Future<void> _syncChatMessages(int chatId) async {
    if (await _isDeltaSystemChat(chatId)) {
      return;
    }
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(chatId);
    if (chat == null) {
      return;
    }
    final messageIds = await _context.getChatMessageIds(chatId: chatId);
    final filteredIds =
        messageIds.where((id) => !_isDeltaMessageMarkerId(id)).toList();
    if (filteredIds.isEmpty) {
      await db.removeChatMessages(chat.jid);
      return;
    }
    final startIndex = _messageStorageMode.isServerOnly &&
            filteredIds.length > serverOnlyChatMessageCap
        ? filteredIds.length - serverOnlyChatMessageCap
        : _deltaMessageIdUnset;
    final visibleIds = filteredIds
        .skip(startIndex)
        .where((id) => id > _deltaMessageIdUnset)
        .toList(growable: false);
    if (visibleIds.isEmpty) {
      await db.removeChatMessages(chat.jid);
      return;
    }
    final visibleIdSet = visibleIds.toSet();
    final localMessages = await db.getAllMessagesForChat(chat.jid);
    final localDeltaMessages = localMessages
        .where((message) => message.deltaMsgId != null)
        .toList(growable: false);
    final localDeltaIds =
        localDeltaMessages.map((message) => message.deltaMsgId!).toSet();
    var processed = 0;
    for (final message in localDeltaMessages) {
      final deltaId = message.deltaMsgId!;
      if (visibleIdSet.contains(deltaId)) {
        continue;
      }
      await db.deleteMessage(message.stanzaID);
      processed += 1;
      if (processed % _bootstrapYieldEveryMessages == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (final deltaId in visibleIds) {
      if (localDeltaIds.contains(deltaId)) {
        continue;
      }
      final msg = await _context.getMessage(deltaId);
      if (msg == null) {
        continue;
      }
      await _ingestDeltaMessage(
        chatId: chatId,
        msg: msg,
        chat: chat,
        skipSystemChatCheck: true,
      );
      processed += 1;
      if (processed % _bootstrapYieldEveryMessages == 0) {
        await Future<void>.delayed(Duration.zero);
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
    if (_isDeltaStockMessage(msg) ||
        (!skipSystemChatCheck && await _isDeltaSystemChat(chatId))) {
      _log.finer('Dropping Delta stock message msgId=${msg.id} chatId=$chatId');
      return;
    }
    final resolvedChat = chat ?? await _ensureChat(chatId);
    final stanzaId = _stanzaId(msg.id);
    final db = await _db();
    final existing = await db.getMessageByStanzaID(stanzaId);
    if (existing != null) {
      await _updateExistingMessage(existing: existing, msg: msg);
      return;
    }
    final timestamp = msg.timestamp ?? DateTime.timestamp();
    final isOutgoing = msg.isOutgoing;
    final senderJid = isOutgoing ? _selfJid : resolvedChat.jid;
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
      error: resolvedError,
      warning: warning,
      encryptionProtocol: EncryptionProtocol.none,
      received: deliveryStatus.received,
      acked: deliveryStatus.acked,
      displayed: deliveryStatus.displayed,
      deltaChatId: resolvedChat.deltaChatId,
      deltaMsgId: msg.id,
    );
    message = await _buildDeltaMessageContent(
      db: db,
      message: message,
      chatId: chatId,
      msg: msg,
    );
    await _storeMessage(
      db: db,
      message: message,
      chatJid: resolvedChat.jid,
    );
    if (!isOutgoing &&
        msg.hasFile &&
        resolvedChat.attachmentAutoDownload.isAllowed) {
      unawaited(_context.downloadFullMessage(msg.id));
    }
    await _updateChatTimestamp(chatId: chatId, timestamp: timestamp);
  }

  Future<void> _updateExistingMessage({
    required Message existing,
    required DeltaMessage msg,
  }) async {
    final db = await _db();
    var next = existing;
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
    if (next != existing) {
      await db.updateMessage(next);
    }
  }

  Future<Chat> _ensureChat(int chatId) async {
    final db = await _db();
    final existing = await db.getChatByDeltaChatId(chatId);
    if (existing != null) {
      return existing;
    }
    final remote = await _context.getChat(chatId);
    final chat = _chatFromRemote(
      chatId: chatId,
      remote: remote,
    );
    final existingByAddress = await db.getChat(chat.jid);
    if (existingByAddress != null) {
      final merged = existingByAddress.copyWith(
        deltaChatId: chatId,
        emailAddress: chat.emailAddress,
        contactDisplayName: chat.contactDisplayName,
        contactID: chat.contactID,
      );
      await db.updateChat(merged);
      return merged;
    }
    await db.createChat(chat);
    return chat;
  }

  Chat _chatFromRemote({
    required int chatId,
    required DeltaChat? remote,
  }) {
    final emailAddress = _normalizedAddress(
      remote?.contactAddress,
      chatId,
    );
    final title = remote?.name ?? remote?.contactName ?? emailAddress;
    return Chat(
      jid: emailAddress,
      title: title,
      type: _mapChatType(remote?.type),
      lastChangeTimestamp: DateTime.timestamp(),
      encryptionProtocol: EncryptionProtocol.none,
      contactDisplayName: remote?.contactName ?? remote?.name ?? emailAddress,
      contactID: emailAddress,
      contactJid: emailAddress,
      emailAddress: emailAddress,
      deltaChatId: chatId,
    );
  }

  Future<void> _refreshChat(int chatId) async {
    final db = await _db();
    final remote = await _context.getChat(chatId);
    if (remote == null) return;
    final existing = await db.getChatByDeltaChatId(chatId);
    if (existing == null) {
      await db.createChat(_chatFromRemote(chatId: chatId, remote: remote));
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
  }

  Future<void> _refreshArchivedState(int chatId) async {
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(chatId);
    if (chat == null) return;
    final archivedChatlist = await _context.getChatlist(
      flags: _deltaChatlistArchivedOnlyFlag,
    );
    final isArchived = archivedChatlist.any((entry) => entry.chatId == chatId);
    if (chat.archived != isArchived) {
      await db.updateChat(chat.copyWith(archived: isArchived));
    }
  }

  Future<void> _updateChatTimestamp({
    required int chatId,
    required DateTime timestamp,
  }) async {
    final db = await _db();
    final chat = await db.getChatByDeltaChatId(chatId);
    if (chat == null) return;
    if (!chat.lastChangeTimestamp.isBefore(timestamp)) return;
    await db.updateChat(chat.copyWith(lastChangeTimestamp: timestamp));
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
    final resolvedBody = rawText?.trim().isNotEmpty == true
        ? rawText
        : (normalizedHtml == null
            ? rawText
            : HtmlContentCodec.toPlainText(normalizedHtml));
    var next = message.copyWith(
      body: resolvedBody?.trim().isEmpty == true ? null : resolvedBody,
      htmlBody: normalizedHtml,
    );
    next = await _applyShareMetadata(
      db: db,
      message: next,
      rawBody: rawText,
      rawHtml: rawHtml,
      chatId: chatId,
      msgId: msg.id,
    );
    next = await _attachFileMetadata(db: db, message: next, delta: msg);
    return next;
  }

  Future<void> _storeMessage({
    required XmppDatabase db,
    required Message message,
    required String chatJid,
  }) async {
    await db.saveMessage(message);
    if (_messageStorageMode.isServerOnly) {
      await db.trimChatMessages(
        jid: chatJid,
        maxMessages: serverOnlyChatMessageCap,
      );
    }
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
    final resolvedMetadata =
        _metadataFromDelta(delta: delta, metadataId: metadataId);
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
      filename:
          existing.filename.isNotEmpty ? existing.filename : next.filename,
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
    final fallbackName = '$_deltaAttachmentFallbackPrefix$deltaId';
    return sanitizeEmailAttachmentFilename(
      explicitName,
      fallbackPath: fallbackPath,
      fallbackName: fallbackName,
    );
  }

  String _attachmentLabel(FileMetadataData metadata) {
    final sizeBytes = metadata.sizeBytes;
    final label = metadata.filename.trim();
    if (sizeBytes == null) return '📎 $label';
    final sizeLabel = _formatBytes(sizeBytes);
    return '📎 $label ($sizeLabel)';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final precision = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
  }

  Future<Message> _applyShareMetadata({
    required XmppDatabase db,
    required Message message,
    required String? rawBody,
    required String? rawHtml,
    required int chatId,
    required int msgId,
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
    final cleanedHtml =
        ShareTokenHtmlCodec.stripInjectedToken(message.htmlBody);
    final sanitized = message.copyWith(
      body: cleanedBody,
      htmlBody: cleanedHtml,
    );
    if (share != null) {
      final existingShareId = await db.getShareIdForDeltaMessage(msgId);
      if (existingShareId == null) {
        await db.insertMessageCopy(
          shareId: share.shareId,
          dcMsgId: msgId,
          dcChatId: chatId,
        );
      }
    }
    return sanitized;
  }

  Future<void> purgeDeltaStockMessages() async {
    try {
      final db = await _db();
      final chats = await db.getChats(start: 0, end: 0);
      for (final chat in chats) {
        if (chat.deltaChatId == null) continue;
        final messages = await db.getAllMessagesForChat(chat.jid);
        for (final message in messages) {
          if (await _isDeltaStockStoredMessage(db, message)) {
            await db.deleteMessage(message.stanzaID);
          }
        }
      }
    } on StateError catch (error, stackTrace) {
      _log.fine(
        'Skipping Delta stock purge because the database is unavailable.',
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      _log.warning('Failed to purge Delta stock messages.', error, stackTrace);
    }
  }

  bool _isDeltaMessageMarkerId(int msgId) =>
      msgId == DeltaMessageId.marker1 || msgId == DeltaMessageId.dayMarker;

  bool _isDeltaStockMessage(DeltaMessage msg) =>
      _matchesDeltaWelcomeText(msg.text) ||
      _matchesDeltaWelcomeText(msg.subject) ||
      _matchesDeltaWelcomeAttachment(msg.fileName) ||
      _matchesDeltaWelcomeAttachment(msg.filePath);

  Future<bool> _isDeltaStockStoredMessage(
    XmppDatabase db,
    Message message,
  ) async {
    if (_matchesDeltaWelcomeText(message.body)) return true;
    final metadataId = message.fileMetadataID;
    if (metadataId != null) {
      final metadata = await db.getFileMetadata(metadataId);
      if (_matchesDeltaWelcomeAttachment(metadata?.filename) ||
          _matchesDeltaWelcomeAttachment(metadata?.path)) {
        return true;
      }
    }
    final deltaMsgId = message.deltaMsgId;
    if (deltaMsgId == null) return false;
    final deltaMessage = await _context.getMessage(deltaMsgId);
    if (deltaMessage == null) return false;
    if (_isDeltaStockMessage(deltaMessage)) return true;
    return await _isDeltaSystemChat(deltaMessage.chatId);
  }

  Future<bool> _isDeltaSystemChat(int chatId) async {
    final remote = await _context.getChat(chatId);
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

String _stanzaId(int msgId) => 'dc-msg-$msgId';

String _stripSubjectHeader(String body, String subject) {
  final trimmedBody = body.trimLeft();
  if (!trimmedBody.startsWith(subject)) {
    return trimmedBody;
  }
  var remainder = trimmedBody.substring(subject.length);
  remainder = remainder.replaceFirst(RegExp(r'^\s+'), '');
  return remainder;
}

bool _matchesDeltaWelcomeText(String? text) {
  if (text == null) return false;
  final normalized = text.toLowerCase();
  if (normalized.contains('autocrypt setup message')) {
    return true;
  }
  final mentionsDelta =
      normalized.contains('delta chat') || normalized.contains('deltachat');
  if (normalized.contains('messages in this chat are generated locally')) {
    return true;
  }
  final generatedLocally = normalized.contains('generated locally') ||
      normalized.contains('created locally') ||
      normalized.contains('generated automatically');
  final mentionsSetup = normalized.contains('setup message') ||
      normalized.contains('autocrypt setup message');
  final mentionsDevice = normalized.contains('device message');
  if (generatedLocally && (mentionsDelta || mentionsDevice || mentionsSetup)) {
    return true;
  }
  return normalized.contains('welcome to delta chat') ||
      normalized.contains('welcome to deltachat') ||
      normalized.contains('generated locally by your delta chat app') ||
      (mentionsDelta && mentionsDevice) ||
      (mentionsDelta && mentionsSetup);
}

bool _matchesDeltaWelcomeAttachment(String? value) {
  if (value == null) return false;
  final normalized = value.toLowerCase();
  return normalized.contains('welcome-image') ||
      normalized.endsWith('welcome.jpg') ||
      normalized.contains('core-welcome');
}
