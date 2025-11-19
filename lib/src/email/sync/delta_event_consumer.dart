import 'dart:async';

import 'package:axichat/src/email/email_metadata.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

const _deltaDomain = 'delta.chat';
const _deltaSelfJid = 'dc-self@$_deltaDomain';

class DeltaEventType {
  static const info = 100;
  static const error = 300;
  static const errorSelfNotInGroup = 410;
  static const msgsChanged = 2000;
  static const incomingMsg = 2005;
  static const incomingMsgBunch = 2006;
  static const msgDelivered = 2010;
  static const msgFailed = 2012;
  static const msgRead = 2015;
  static const chatModified = 2020;
  static const configureProgress = 2041;
  static const accountsBackgroundFetchDone = 2200;
  static const connectivityChanged = 2100;
  static const channelOverflow = 2400;
}

class DeltaEventConsumer {
  DeltaEventConsumer({
    required Future<XmppDatabase> Function() databaseBuilder,
    required DeltaContextHandle context,
    Logger? logger,
  })  : _databaseBuilder = databaseBuilder,
        _context = context,
        _log = logger ?? Logger('DeltaEventConsumer');

  final Future<XmppDatabase> Function() _databaseBuilder;
  final DeltaContextHandle _context;
  final Logger _log;

  XmppDatabase? _database;

  Future<void> handle(DeltaCoreEvent event) async {
    switch (event.type) {
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
    await db.saveMessage(message);
    await _updateChatTimestamp(chatId: chatId, timestamp: timestamp);
  }

  Future<void> _hydrateMessage(int chatId, int msgId) async {
    final msg = await _context.getMessage(msgId);
    if (msg == null) return;
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
    await db.saveMessage(message);
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
    return _database ??= await _databaseBuilder();
  }

  Future<Message> _attachFileMetadata({
    required XmppDatabase db,
    required Message message,
    required DeltaMessage delta,
  }) async {
    if (!delta.hasFile || delta.filePath == null) {
      return message;
    }
    final metadataId = deltaFileMetadataId(delta.id);
    final existing = await db.getFileMetadata(metadataId);
    final metadata = _metadataFromDelta(delta: delta, metadataId: metadataId);
    if (existing != null) {
      final merged = existing.copyWith(
        path: metadata.path ?? existing.path,
        mimeType: metadata.mimeType ?? existing.mimeType,
        sizeBytes: metadata.sizeBytes ?? existing.sizeBytes,
        width: metadata.width ?? existing.width,
        height: metadata.height ?? existing.height,
      );
      if (merged != existing) {
        await db.saveFileMetadata(merged);
      }
      return message.copyWith(fileMetadataID: existing.id);
    }
    await db.saveFileMetadata(metadata);
    return message.copyWith(fileMetadataID: metadata.id);
  }

  FileMetadataData _metadataFromDelta({
    required DeltaMessage delta,
    required String metadataId,
  }) {
    return FileMetadataData(
      id: metadataId,
      filename: delta.fileName ?? p.basename(delta.filePath!),
      path: delta.filePath,
      mimeType: delta.fileMime,
      sizeBytes: delta.fileSize,
      width: delta.width,
      height: delta.height,
    );
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
