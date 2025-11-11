import 'dart:async';

import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';

const _deltaDomain = 'delta.chat';
const _deltaSelfJid = 'dc-self@$_deltaDomain';

class DeltaEventType {
  static const msgsChanged = 2000;
  static const incomingMsg = 2005;
  static const msgDelivered = 2010;
  static const msgFailed = 2012;
  static const msgRead = 2015;
  static const chatModified = 2020;
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
        await _markFailed(event.data2);
        break;
      case DeltaEventType.msgRead:
        await _markDisplayed(event.data2);
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
    final message = Message(
      stanzaID: stanzaId,
      senderJid: chat.jid,
      chatJid: chat.jid,
      timestamp: DateTime.timestamp(),
      body: msg.text,
      encryptionProtocol: EncryptionProtocol.none,
      received: true,
      acked: true,
      deltaChatId: chat.deltaChatId,
      deltaMsgId: msg.id,
    );
    await db.saveMessage(message);
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
    final message = Message(
      stanzaID: stanzaId,
      senderJid: _deltaSelfJid,
      chatJid: chat.jid,
      timestamp: DateTime.timestamp(),
      body: msg.text,
      encryptionProtocol: EncryptionProtocol.none,
      acked: true,
      deltaChatId: chat.deltaChatId,
      deltaMsgId: msg.id,
    );
    await db.saveMessage(message);
  }

  Future<void> _markAcked(int msgId) async {
    final db = await _db();
    await db.markMessageAcked(_stanzaId(msgId));
  }

  Future<void> _markFailed(int msgId) async {
    final db = await _db();
    await db.saveMessageError(
      stanzaID: _stanzaId(msgId),
      error: MessageError.serviceUnavailable,
    );
  }

  Future<void> _markDisplayed(int msgId) async {
    final db = await _db();
    await db.markMessageDisplayed(_stanzaId(msgId));
  }

  Future<Chat> _ensureChat(int chatId) async {
    final db = await _db();
    final jid = _chatJid(chatId);
    final existing = await db.getChat(jid);
    if (existing != null) {
      return existing;
    }
    final remote = await _context.getChat(chatId);
    final chat = Chat(
      jid: jid,
      title: remote?.name ?? 'Chat $chatId',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.timestamp(),
      encryptionProtocol: EncryptionProtocol.none,
      contactDisplayName: remote?.name,
      contactID: remote?.contactAddress,
      emailAddress: remote?.contactAddress,
      deltaChatId: chatId,
    );
    await db.createChat(chat);
    return chat;
  }

  Future<XmppDatabase> _db() async {
    return _database ??= await _databaseBuilder();
  }
}

String _chatJid(int chatId) => 'dc-$chatId@$_deltaDomain';

String _stanzaId(int msgId) => 'dc-msg-$msgId';
