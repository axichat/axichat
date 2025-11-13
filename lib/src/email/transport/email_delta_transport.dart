import 'dart:async';
import 'dart:io';

import 'package:axichat/src/email/email_metadata.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';

import '../sync/delta_event_consumer.dart';
import 'chat_transport.dart';

const _deltaDomain = 'delta.chat';
const _selfDomain = 'user.delta.chat';

class EmailDeltaTransport implements ChatTransport {
  EmailDeltaTransport({
    required Future<XmppDatabase> Function() databaseBuilder,
    DeltaSafe? deltaSafe,
    Logger? logger,
  })  : _databaseBuilder = databaseBuilder,
        _deltaSafe = deltaSafe ?? DeltaSafe(),
        _log = logger ?? Logger('EmailDeltaTransport');

  final Future<XmppDatabase> Function() _databaseBuilder;
  final DeltaSafe _deltaSafe;
  final Logger _log;

  DeltaContextHandle? _context;
  bool _contextOpened = false;
  Future<void>? _contextOpening;
  DeltaEventConsumer? _eventConsumer;
  StreamSubscription<DeltaCoreEvent>? _eventSubscription;
  final List<void Function(DeltaCoreEvent)> _eventListeners = [];

  String? _databasePrefix;
  String? _databasePassphrase;
  String? _accountAddress;

  @override
  Stream<DeltaCoreEvent> get events =>
      _context?.events() ?? const Stream<DeltaCoreEvent>.empty();

  String? get selfJid => _accountAddress == null ? null : _selfJid;

  @override
  Future<void> ensureInitialized({
    required String databasePrefix,
    required String databasePassphrase,
  }) async {
    final prefixChanged =
        _databasePrefix != null && _databasePrefix != databasePrefix;
    final passphraseChanged = _databasePassphrase != null &&
        _databasePassphrase != databasePassphrase;
    final needsReplacement =
        _context != null && (prefixChanged || passphraseChanged);

    if (needsReplacement) {
      await _teardownContext();
    }

    _databasePrefix = databasePrefix;
    _databasePassphrase = databasePassphrase;
    await _ensureContextOpen();
  }

  @override
  Future<void> configureAccount({
    required String address,
    required String password,
    required String displayName,
    Map<String, String> additional = const {},
  }) async {
    if (_context == null) {
      if (_databasePrefix == null || _databasePassphrase == null) {
        throw StateError('Call ensureInitialized before configureAccount');
      }
    }
    await _ensureContextOpen();
    _accountAddress = address;
    await _context!.configureAccount(
      address: address,
      password: password,
      displayName: displayName,
      additional: additional,
    );
  }

  @override
  Future<void> start() async {
    await _ensureContextOpen();
    await _context!.startIo();
    _eventSubscription ??= _context!.events().listen((event) async {
      try {
        await _eventConsumer?.handle(event);
        for (final listener in List.of(_eventListeners)) {
          listener(event);
        }
      } on Exception catch (error, stackTrace) {
        _log.severe('Failed to handle Delta event', error, stackTrace);
      }
    });
  }

  @override
  Future<void> stop() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _context?.stopIo();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _teardownContext();
    _eventListeners.clear();
  }

  Future<void> _ensureContextOpen() async {
    if (_contextOpening != null) {
      await _contextOpening!;
      return;
    }
    final completer = Completer<void>();
    _contextOpening = completer.future;
    try {
      final prefix = _databasePrefix;
      final passphrase = _databasePassphrase;
      if (prefix == null || passphrase == null) {
        throw StateError('Transport not initialized');
      }
      final file = await _deltaDatabaseFile(prefix);
      await file.parent.create(recursive: true);
      var resetAttempted = false;
      while (true) {
        if (_context == null) {
          _log.fine('Opening Delta context at ${file.path}');
          _context = await _deltaSafe.createContext(
            databasePath: file.path,
            osName: 'dart',
          );
          _contextOpened = false;
          _eventConsumer = DeltaEventConsumer(
            databaseBuilder: _databaseBuilder,
            context: _context!,
            logger: _log,
          );
        }
        if (_contextOpened) {
          break;
        }
        try {
          await _context!.open(passphrase: passphrase);
          _contextOpened = true;
        } on DeltaSafeException catch (error, stackTrace) {
          if (resetAttempted) {
            rethrow;
          }
          resetAttempted = true;
          _log.warning(
            'Delta context open failed, resetting mailbox database at ${file.path}',
            error,
            stackTrace,
          );
          await _context?.close();
          _context = null;
          _eventConsumer = null;
          _contextOpened = false;
          await _deleteDatabaseArtifacts(file);
          continue;
        }
      }
      completer.complete();
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      _contextOpening = null;
    }
  }

  Future<void> _teardownContext() async {
    final opening = _contextOpening;
    if (opening != null) {
      await opening;
    }
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _context?.close();
    _context = null;
    _eventConsumer = null;
    _contextOpened = false;
  }

  @override
  Future<int> sendText({
    required int chatId,
    required String body,
    String? shareId,
    String? localBodyOverride,
  }) async {
    if (_context == null) {
      throw StateError('Transport not initialized');
    }
    final msgId = await _context!.sendText(chatId: chatId, message: body);
    final deltaMessage = await _context!.getMessage(msgId);
    await _recordOutgoing(
      chatId: chatId,
      msgId: msgId,
      body: body,
      shareId: shareId,
      localBodyOverride: localBodyOverride,
      timestamp: deltaMessage?.timestamp,
    );
    return msgId;
  }

  @override
  Future<int> sendAttachment({
    required int chatId,
    required EmailAttachment attachment,
    String? shareId,
    String? captionOverride,
  }) async {
    if (_context == null) {
      throw StateError('Transport not initialized');
    }
    final msgId = await _context!.sendFileMessage(
      chatId: chatId,
      viewType: _viewTypeFor(attachment),
      filePath: attachment.path,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      text: attachment.caption,
    );
    final deltaMessage = await _context!.getMessage(msgId);
    var metadata = _metadataForAttachment(attachment, msgId);
    if (deltaMessage != null) {
      metadata = metadata.copyWith(
        path: deltaMessage.filePath ?? metadata.path,
        mimeType: deltaMessage.fileMime ?? metadata.mimeType,
        sizeBytes: deltaMessage.fileSize ?? metadata.sizeBytes,
        width: deltaMessage.width ?? metadata.width,
        height: deltaMessage.height ?? metadata.height,
      );
    }
    await _recordOutgoing(
      chatId: chatId,
      msgId: msgId,
      body: attachment.caption,
      metadata: metadata,
      shareId: shareId,
      localBodyOverride: captionOverride,
      timestamp: deltaMessage?.timestamp,
    );
    return msgId;
  }

  @override
  Future<int> ensureChatForAddress({
    required String address,
    String? displayName,
  }) async {
    if (_context == null) {
      throw StateError('Transport not initialized');
    }
    final contactId = await _context!.createContact(
      address: address,
      displayName: displayName ?? address,
    );
    final chatId = await _context!.createChatByContactId(contactId);
    await _ensureChat(chatId);
    return chatId;
  }

  Future<void> _recordOutgoing({
    required int chatId,
    required int msgId,
    String? body,
    FileMetadataData? metadata,
    String? shareId,
    String? localBodyOverride,
    DateTime? timestamp,
  }) async {
    final db = await _databaseBuilder();
    final chat = await _ensureChat(chatId);
    if (metadata != null) {
      await db.saveFileMetadata(metadata);
    }
    final displayBody = localBodyOverride ?? body;
    final resolvedTimestamp = timestamp ?? DateTime.timestamp();
    final message = Message(
      stanzaID: _stanzaId(msgId),
      senderJid: _selfJid,
      chatJid: chat.jid,
      timestamp: resolvedTimestamp,
      body: displayBody,
      encryptionProtocol: EncryptionProtocol.none,
      acked: false,
      received: false,
      deltaChatId: chatId,
      deltaMsgId: msgId,
      fileMetadataID: metadata?.id,
    );
    await db.saveMessage(message);
    await db.updateChat(
      chat.copyWith(lastChangeTimestamp: resolvedTimestamp),
    );
    if (shareId != null) {
      await db.insertMessageCopy(
        shareId: shareId,
        dcMsgId: msgId,
        dcChatId: chat.deltaChatId ?? chatId,
      );
    }
  }

  Future<Chat> _ensureChat(int chatId) async {
    final db = await _databaseBuilder();
    final jid = _chatJid(chatId);
    final existing = await db.getChat(jid);
    if (existing != null) {
      return existing;
    }
    final remote = await _context!.getChat(chatId);
    final title = remote?.name ?? remote?.contactName ?? 'Chat $chatId';
    final emailAddress = remote?.contactAddress;
    final chat = Chat(
      jid: jid,
      title: title,
      type: _mapChatType(remote?.type),
      lastChangeTimestamp: DateTime.timestamp(),
      encryptionProtocol: EncryptionProtocol.none,
      contactDisplayName: remote?.contactName ?? remote?.name ?? emailAddress,
      contactID: emailAddress,
      emailAddress: emailAddress,
      deltaChatId: chatId,
    );
    await db.createChat(chat);
    return chat;
  }

  Future<File> _deltaDatabaseFile(String prefix) async {
    final normalized = '${prefix}_email';
    return dbFileFor(normalized);
  }

  Future<void> _deleteDatabaseArtifacts(File databaseFile) async {
    final candidates = <File>[
      databaseFile,
      File('${databaseFile.path}-wal'),
      File('${databaseFile.path}-shm'),
      File('${databaseFile.path}-journal'),
    ];
    for (final candidate in candidates) {
      if (await candidate.exists()) {
        try {
          await candidate.delete();
        } on IOException catch (error, stackTrace) {
          _log.warning(
            'Failed to delete Delta database artifact ${candidate.path}',
            error,
            stackTrace,
          );
        }
      }
    }
  }

  String get _selfJid {
    final address = _accountAddress;
    if (address == null) {
      return 'dc-anon@$_selfDomain';
    }
    final local = address.replaceAll('@', '-at-').replaceAll('.', '-dot-');
    return '$local@$_selfDomain';
  }

  void addEventListener(void Function(DeltaCoreEvent event) listener) {
    if (!_eventListeners.contains(listener)) {
      _eventListeners.add(listener);
    }
  }

  void removeEventListener(void Function(DeltaCoreEvent event) listener) {
    _eventListeners.remove(listener);
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

  FileMetadataData _metadataForAttachment(
    EmailAttachment attachment,
    int msgId,
  ) {
    return FileMetadataData(
      id: deltaFileMetadataId(msgId),
      filename: attachment.fileName,
      path: attachment.path,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      width: attachment.width,
      height: attachment.height,
    );
  }

  int _viewTypeFor(EmailAttachment attachment) {
    if (attachment.isGif) return DeltaMessageType.gif;
    if (attachment.isImage) return DeltaMessageType.image;
    if (attachment.isVideo) return DeltaMessageType.video;
    if (attachment.isAudio) return DeltaMessageType.audio;
    return DeltaMessageType.file;
  }
}

String _chatJid(int chatId) => 'dc-$chatId@$_deltaDomain';

String _stanzaId(int msgId) => 'dc-msg-$msgId';
