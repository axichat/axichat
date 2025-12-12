import 'dart:async';

import 'package:axichat/src/email/email_metadata.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart'
    show serverOnlyChatMessageCap;
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

const _deltaDomain = 'delta.chat';
const _deltaSelfJid = 'dc-self@$_deltaDomain';

enum DeltaEventType {
  info(100),
  error(300),
  errorSelfNotInGroup(410),
  msgsChanged(2000),
  incomingMsg(2005),
  incomingMsgBunch(2006),
  msgDelivered(2010),
  msgFailed(2012),
  msgRead(2015),
  chatModified(2020),
  configureProgress(2041),
  accountsBackgroundFetchDone(2200),
  connectivityChanged(2100),
  channelOverflow(2400);

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

class DeltaEventConsumer {
  DeltaEventConsumer({
    required Future<XmppDatabase> Function() databaseBuilder,
    required DeltaContextHandle context,
    MessageStorageMode messageStorageMode = MessageStorageMode.local,
    Logger? logger,
  })  : _databaseBuilder = databaseBuilder,
        _context = context,
        _messageStorageMode = messageStorageMode,
        _log = logger ?? Logger('DeltaEventConsumer');

  final Future<XmppDatabase> Function() _databaseBuilder;
  final DeltaContextHandle _context;
  MessageStorageMode _messageStorageMode;
  final Logger _log;

  void updateMessageStorageMode(MessageStorageMode mode) {
    _messageStorageMode = mode;
  }

  Future<void> handle(DeltaCoreEvent event) async {
    final eventType = DeltaEventType.fromCode(event.type);
    if (eventType == null) {
      _log.finer('Ignoring Delta event ${event.type}');
      return;
    }
    switch (eventType) {
      case DeltaEventType.incomingMsg:
        await _handleIncoming(event.data1, event.data2);
        break;
      case DeltaEventType.msgsChanged:
        if (event.data2 > 0) {
          await _hydrateMessage(event.data1, event.data2);
        }
        break;
      case DeltaEventType.msgDelivered:
        await _markAcked(event.data2);
        break;
      case DeltaEventType.msgFailed:
        await _markFailed(
          msgId: event.data2,
          reason: event.data2Text,
        );
        break;
      case DeltaEventType.msgRead:
        await _markDisplayed(event.data2);
        break;
      case DeltaEventType.chatModified:
        await _refreshChat(event.data1);
        break;
      default:
        _log.finer('Ignoring Delta event ${event.type}');
    }
  }

  Future<void> _handleIncoming(int chatId, int msgId) async {
    final msg = await _context.getMessage(msgId);
    if (msg == null) {
      _log.warning('Incoming event for missing msgId=$msgId');
      return;
    }
    if (_isDeltaStockMessage(msg) ||
        (!msg.isOutgoing && await _isDeltaSystemChat(chatId))) {
      _log.finer('Dropping Delta stock message msgId=$msgId chatId=$chatId');
      return;
    }
    final chat = await _ensureChat(chatId);
    final stanzaId = _stanzaId(msg.id);
    final db = await _db();
    final existing = await db.getMessageByStanzaID(stanzaId);
    if (existing != null) {
      return;
    }
    final timestamp = msg.timestamp ?? DateTime.timestamp();
    final emailAddress = chat.emailAddress?.toLowerCase();
    if (emailAddress != null &&
        emailAddress.isNotEmpty &&
        await db.isEmailAddressBlocked(emailAddress)) {
      await db.incrementEmailBlockCount(emailAddress);
      return;
    }
    var warning = MessageWarning.none;
    final bool isSpamAddress = emailAddress != null &&
        emailAddress.isNotEmpty &&
        await db.isEmailAddressSpam(emailAddress);
    if (isSpamAddress) {
      warning = MessageWarning.emailSpamQuarantined;
      await db.markChatSpam(jid: chat.jid, spam: true);
    }
    var message = Message(
      stanzaID: stanzaId,
      senderJid: chat.jid,
      chatJid: chat.jid,
      timestamp: timestamp,
      body: msg.text,
      warning: warning,
      encryptionProtocol: EncryptionProtocol.none,
      received: true,
      acked: true,
      deltaChatId: chat.deltaChatId,
      deltaMsgId: msg.id,
    );
    message = await _applyShareMetadata(
      db: db,
      message: message,
      rawBody: msg.text,
      chatId: chatId,
      msgId: msg.id,
    );
    message = await _attachFileMetadata(db: db, message: message, delta: msg);
    await _storeMessage(
      db: db,
      message: message,
      chatJid: chat.jid,
    );
    await _updateChatTimestamp(chatId: chatId, timestamp: timestamp);
  }

  Future<void> _hydrateMessage(int chatId, int msgId) async {
    final msg = await _context.getMessage(msgId);
    if (msg == null) return;
    if (_isDeltaStockMessage(msg) ||
        (!msg.isOutgoing && await _isDeltaSystemChat(chatId))) {
      _log.finer('Dropping Delta stock message msgId=$msgId chatId=$chatId');
      return;
    }
    final chat = await _ensureChat(chatId);
    final stanzaId = _stanzaId(msg.id);
    final db = await _db();
    final existing = await db.getMessageByStanzaID(stanzaId);
    if (existing != null) {
      return;
    }
    final timestamp = msg.timestamp ?? DateTime.timestamp();
    var message = Message(
      stanzaID: stanzaId,
      senderJid: _deltaSelfJid,
      chatJid: chat.jid,
      timestamp: timestamp,
      body: msg.text,
      encryptionProtocol: EncryptionProtocol.none,
      acked: true,
      deltaChatId: chat.deltaChatId,
      deltaMsgId: msg.id,
    );
    message = await _applyShareMetadata(
      db: db,
      message: message,
      rawBody: msg.text,
      chatId: chatId,
      msgId: msg.id,
    );
    message = await _attachFileMetadata(db: db, message: message, delta: msg);
    await _storeMessage(
      db: db,
      message: message,
      chatJid: chat.jid,
    );
    await _updateChatTimestamp(chatId: chatId, timestamp: timestamp);
  }

  Future<void> _markAcked(int msgId) async {
    final db = await _db();
    await db.markMessageAcked(_stanzaId(msgId));
  }

  Future<void> _markFailed({required int msgId, String? reason}) async {
    final db = await _db();
    final resolved = DeltaErrorMapper.resolve(reason);
    await db.saveMessageError(
      stanzaID: _stanzaId(msgId),
      error: resolved,
    );
  }

  Future<void> _markDisplayed(int msgId) async {
    final db = await _db();
    await db.markMessageDisplayed(_stanzaId(msgId));
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
      case DeltaChatType.verifiedGroup:
        return ChatType.groupChat;
      default:
        return ChatType.chat;
    }
  }

  Future<XmppDatabase> _db() async {
    return await _databaseBuilder();
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
    return FileMetadataData(
      id: metadataId,
      filename: _resolvedFilename(
        explicitName: delta.fileName,
        fallbackPath: sanitizedPath,
        deltaId: delta.id,
      ),
      path: sanitizedPath,
      mimeType: delta.fileMime,
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
    final trimmedName = explicitName?.trim();
    if (trimmedName?.isNotEmpty == true) {
      return p.normalize(trimmedName!);
    }
    if (fallbackPath?.isNotEmpty == true) {
      return p.basename(fallbackPath!);
    }
    return 'attachment-$deltaId';
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
    required int chatId,
    required int msgId,
  }) async {
    final match = ShareTokenCodec.stripToken(rawBody);
    if (match == null) {
      return message;
    }
    final share = await db.getMessageShareByToken(match.token);
    final cleanedBody = share?.subject?.isNotEmpty == true
        ? _stripSubjectHeader(match.cleanedBody, share!.subject!)
        : match.cleanedBody;
    final sanitized = message.copyWith(body: cleanedBody);
    if (share != null) {
      await db.insertMessageCopy(
        shareId: share.shareId,
        dcMsgId: msgId,
        dcChatId: chatId,
      );
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
    return !deltaMessage.isOutgoing &&
        await _isDeltaSystemChat(deltaMessage.chatId);
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
