import 'dart:async';
import 'dart:io';

import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/email/email_metadata.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart'
    show serverOnlyChatMessageCap;
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'chat_transport.dart';

const _selfDomain = 'user.delta.chat';
const _deltaConfigClearedValue = '';
const _deltaConfigKeyAddress = 'addr';
const _deltaConfigKeyMailPassword = 'mail_pw';
const _deltaConfigKeySendPassword = 'send_pw';
const _deltaConfigKeyDisplayName = 'displayname';
const _deltaConfigKeyMailServer = 'mail_server';
const _deltaConfigKeyMailPort = 'mail_port';
const _deltaConfigKeyMailSecurity = 'mail_security';
const _deltaConfigKeyMailUser = 'mail_user';
const _deltaConfigKeySendServer = 'send_server';
const _deltaConfigKeySendPort = 'send_port';
const _deltaConfigKeySendSecurity = 'send_security';
const _deltaConfigKeySendUser = 'send_user';

const _deltaCredentialConfigKeys = <String>[
  _deltaConfigKeyAddress,
  _deltaConfigKeyMailPassword,
  _deltaConfigKeySendPassword,
  _deltaConfigKeyDisplayName,
  _deltaConfigKeyMailServer,
  _deltaConfigKeyMailPort,
  _deltaConfigKeyMailSecurity,
  _deltaConfigKeyMailUser,
  _deltaConfigKeySendServer,
  _deltaConfigKeySendPort,
  _deltaConfigKeySendSecurity,
  _deltaConfigKeySendUser,
];

const _deltaOverrideConfigKeys = <String>[
  _deltaConfigKeySendPassword,
  _deltaConfigKeyMailServer,
  _deltaConfigKeyMailPort,
  _deltaConfigKeyMailSecurity,
  _deltaConfigKeyMailUser,
  _deltaConfigKeySendServer,
  _deltaConfigKeySendPort,
  _deltaConfigKeySendSecurity,
  _deltaConfigKeySendUser,
];

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

  DeltaAccountsHandle? _accounts;
  DeltaContextHandle? _context;
  bool _contextOpened = false;
  Future<void>? _contextOpening;
  bool _accountsSupported = true;
  DeltaEventConsumer? _eventConsumer;
  StreamSubscription<DeltaCoreEvent>? _eventSubscription;
  final List<void Function(DeltaCoreEvent)> _eventListeners = [];

  String? _databasePrefix;
  String? _databasePassphrase;
  String? _accountAddress;
  MessageStorageMode _messageStorageMode = MessageStorageMode.local;

  @override
  Stream<DeltaCoreEvent> get events =>
      _context?.events() ?? const Stream<DeltaCoreEvent>.empty();

  String? get selfJid => _accountAddress == null ? null : _selfJid;

  void hydrateAccountAddress(String address) {
    if (address.isEmpty) {
      return;
    }
    _accountAddress = address;
  }

  void updateMessageStorageMode(MessageStorageMode mode) {
    _messageStorageMode = mode;
    _eventConsumer?.updateMessageStorageMode(mode);
  }

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
  }

  Future<bool> isConfigured() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    await _ensureContextReady();
    return _context?.isConfigured ?? false;
  }

  Future<void> deconfigureAccount() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final context = _context;
    if (context == null) {
      return;
    }
    await stop();
    for (final key in _deltaCredentialConfigKeys) {
      try {
        await context.setConfig(key: key, value: _deltaConfigClearedValue);
      } on Exception catch (error, stackTrace) {
        _log.warning(
            'Failed to clear Delta config key $key', error, stackTrace);
      }
    }
    _accountAddress = null;
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
    await _ensureContextReady();
    _accountAddress = address;
    final context = _context!;
    final overrideKeys = additional.keys.toSet();
    for (final key in _deltaOverrideConfigKeys) {
      if (!overrideKeys.contains(key)) {
        await context.setConfig(key: key, value: _deltaConfigClearedValue);
      }
    }
    final completer = Completer<void>();
    late final StreamSubscription<DeltaCoreEvent> subscription;
    subscription = context.events().listen((event) {
      final eventType = DeltaEventType.fromCode(event.type);
      if (eventType == null) {
        return;
      }
      if (completer.isCompleted) {
        return;
      }
      if (eventType == DeltaEventType.configureProgress) {
        if (event.data1 == 1000) {
          completer.complete();
        } else if (event.data1 == 0) {
          completer.completeError(
            DeltaSafeException(
              event.data2Text ?? 'Failed to configure email account',
            ),
          );
        }
        return;
      }
      if (eventType == DeltaEventType.error) {
        completer.completeError(
          DeltaSafeException(
            event.data2Text ??
                event.data1Text ??
                'Failed to configure email account',
          ),
        );
      }
    });
    try {
      await context.configureAccount(
        address: address,
        password: password,
        displayName: displayName,
        additional: additional,
      );
      await completer.future.timeout(const Duration(seconds: 60),
          onTimeout: () {
        throw const DeltaSafeException('Email configuration timed out');
      });
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> start() async {
    await _ensureContextReady();
    await _eventConsumer?.purgeDeltaStockMessages();
    if (_accounts != null) {
      await _accounts!.startIo();
    } else {
      await _context!.startIo();
    }
    _eventSubscription ??= _context!.events().listen((event) async {
      try {
        final notifyBeforeHandle = event.type == DeltaEventCode.chatDeleted;
        if (notifyBeforeHandle) {
          for (final listener in List.of(_eventListeners)) {
            listener(event);
          }
        }
        await _eventConsumer?.handle(event);
        if (!notifyBeforeHandle) {
          for (final listener in List.of(_eventListeners)) {
            listener(event);
          }
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
    if (_accounts != null) {
      await _accounts?.stopIo();
    } else {
      await _context?.stopIo();
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _teardownContext();
    _eventListeners.clear();
  }

  Future<void> purgeStockMessages() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    await _eventConsumer?.purgeDeltaStockMessages();
  }

  Future<bool> bootstrapFromCore() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    await _ensureContextReady();
    return await _eventConsumer?.bootstrapFromCore() ?? false;
  }

  Future<void> refreshChatlistSnapshot() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final consumer = _eventConsumer;
    if (consumer == null) {
      return;
    }
    await consumer.refreshChatlistSnapshot();
  }

  Future<void> notifyNetworkAvailable() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts != null) {
      await accounts.maybeNetworkAvailable();
      return;
    }
    await _context?.maybeNetworkAvailable();
  }

  Future<void> notifyNetworkLost() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts != null) {
      await accounts.maybeNetworkLost();
      return;
    }
    await _context?.maybeNetworkLost();
  }

  Future<bool> performBackgroundFetch(Duration timeout) async {
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts == null) {
      await _context?.maybeNetworkAvailable();
      return false;
    }
    return accounts.backgroundFetch(timeout);
  }

  Future<void> backfillChatHistory({
    required int chatId,
    required String chatJid,
    required int desiredWindow,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final consumer = _eventConsumer;
    if (consumer == null) {
      return;
    }
    await consumer.backfillChatHistory(
      chatId: chatId,
      chatJid: chatJid,
      desiredWindow: desiredWindow,
      beforeMessageId: beforeMessageId,
      beforeTimestamp: beforeTimestamp,
      filter: filter,
    );
  }

  @override
  Future<int?> connectivity() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return null;
    }
    await _ensureContextReady();
    return _context?.connectivity();
  }

  bool get accountsSupported => _accountsSupported;

  bool get accountsActive => _accounts != null;

  Future<String?> getCoreConfig(String key) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return null;
    }
    await _ensureContextReady();
    final context = _context;
    if (context == null) return null;
    return context.getConfig(key);
  }

  Future<void> setCoreConfig({
    required String key,
    required String value,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final context = _context;
    if (context == null) return;
    await context.setConfig(key: key, value: value);
  }

  Future<void> registerPushToken(String token) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts != null) {
      await accounts.setPushDeviceToken(token);
      return;
    }
    _log.finer('Delta accounts unavailable; deferring push token registration');
  }

  Future<void> _ensureContextReady() async {
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
      var opened = false;
      if (_accountsSupported) {
        opened = await _tryOpenAccountsContext(prefix, passphrase);
      }
      if (!opened) {
        await _openLegacyContext(prefix, passphrase);
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

  Future<bool> _tryOpenAccountsContext(
    String prefix,
    String passphrase,
  ) async {
    var firstFailure = true;
    bool shouldRetry(Exception error) {
      final message = error.toString();
      final isAllocFailure = message.contains('allocate Delta accounts');
      final isBadInput = message.contains('No such file or directory');
      if (isAllocFailure || isBadInput) {
        return false;
      }
      if (firstFailure) {
        firstFailure = false;
        return true;
      }
      return false;
    }

    var resetAttempted = false;
    while (true) {
      try {
        _accounts ??= await _createAccounts(prefix);
      } on DeltaSafeException catch (error, stackTrace) {
        _log.warning(
          'Delta accounts unavailable, falling back to legacy mode',
          error,
          stackTrace,
        );
        _accountsSupported = false;
        await _accounts?.dispose();
        _accounts = null;
        _context = null;
        _contextOpened = false;
        _eventConsumer = null;
        return false;
      }
      final legacyFile = await _deltaDatabaseFile(prefix);
      final legacyPath = await legacyFile.exists() ? legacyFile.path : null;
      int accountId;
      try {
        accountId = await _accounts!.ensureAccount(
          legacyDatabasePath: legacyPath,
        );
      } on DeltaSafeException catch (error, stackTrace) {
        if (!shouldRetry(error)) {
          _log.warning(
            'Delta accounts ensureAccount failed; disabling accounts support',
            error,
            stackTrace,
          );
          _accountsSupported = false;
          await _accounts?.dispose();
          _accounts = null;
          _context = null;
          _contextOpened = false;
          _eventConsumer = null;
          return false;
        }
        _log.warning(
          'Delta accounts ensureAccount failed, resetting storage',
          error,
          stackTrace,
        );
        await _resetAccountsStorage(prefix);
        await _accounts?.dispose();
        _accounts = null;
        continue;
      }
      _context ??= _accounts!.contextFor(accountId);
      if (!_contextOpened) {
        try {
          await _context!.open(passphrase: passphrase);
          _contextOpened = true;
        } on DeltaSafeException catch (error, stackTrace) {
          final retry = shouldRetry(error) ||
              (resetAttempted == false && !_accountsSupported);
          if (!retry) {
            _log.warning(
              'Failed to open Delta account at ${legacyFile.path}; disabling accounts support',
              error,
              stackTrace,
            );
            _accountsSupported = false;
            await _accounts?.dispose();
            _accounts = null;
            _context = null;
            _contextOpened = false;
            _eventConsumer = null;
            return false;
          }
          resetAttempted = true;
          _log.warning(
            'Failed to open Delta account at ${legacyFile.path}, resetting storage',
            error,
            stackTrace,
          );
          await _resetAccountsStorage(prefix);
          await _accounts?.dispose();
          _accounts = null;
          _context = null;
          _contextOpened = false;
          _eventConsumer = null;
          continue;
        }
      }
      _eventConsumer ??= DeltaEventConsumer(
        databaseBuilder: _databaseBuilder,
        context: _context!,
        messageStorageMode: _messageStorageMode,
        selfJidProvider: () => _selfJid,
        logger: _log,
      );
      return true;
    }
  }

  Future<void> _openLegacyContext(String prefix, String passphrase) async {
    final file = await _deltaDatabaseFile(prefix);
    await file.parent.create(recursive: true);
    var resetAttempted = false;
    while (true) {
      if (_context == null) {
        _log.fine('Opening legacy Delta context at ${file.path}');
        _context = await _deltaSafe.createContext(
          databasePath: file.path,
          osName: 'dart',
        );
        _contextOpened = false;
        _eventConsumer = DeltaEventConsumer(
          databaseBuilder: _databaseBuilder,
          context: _context!,
          messageStorageMode: _messageStorageMode,
          selfJidProvider: () => _selfJid,
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
        _contextOpened = false;
        _eventConsumer = null;
        await _deleteDatabaseArtifacts(file);
        continue;
      }
    }
  }

  Future<void> _teardownContext() async {
    final opening = _contextOpening;
    if (opening != null) {
      await opening;
    }
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventConsumer = null;
    _contextOpened = false;
    await _context?.close();
    _context = null;
    if (_accounts != null) {
      await _accounts!.dispose();
      _accounts = null;
    }
  }

  @override
  Future<int> sendText({
    required int chatId,
    required String body,
    String? subject,
    String? shareId,
    String? localBodyOverride,
    String? htmlBody,
  }) async {
    if (_context == null) {
      throw StateError('Transport not initialized');
    }
    final sanitizedSubject = sanitizeEmailHeaderValue(subject);
    final msgId = await _context!.sendText(
      chatId: chatId,
      message: body,
      subject: sanitizedSubject,
      html: htmlBody,
    );
    final deltaMessage = await _context!.getMessage(msgId);
    await _recordOutgoing(
      chatId: chatId,
      msgId: msgId,
      body: body,
      shareId: shareId,
      localBodyOverride: localBodyOverride,
      htmlBody: htmlBody,
      timestamp: deltaMessage?.timestamp,
    );
    return msgId;
  }

  @override
  Future<int> sendAttachment({
    required int chatId,
    required EmailAttachment attachment,
    String? subject,
    String? shareId,
    String? captionOverride,
    String? htmlCaption,
  }) async {
    if (_context == null) {
      throw StateError('Transport not initialized');
    }
    final sanitizedSubject = sanitizeEmailHeaderValue(subject);
    final msgId = await _context!.sendFileMessage(
      chatId: chatId,
      viewType: _viewTypeFor(attachment),
      filePath: attachment.path,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      text: attachment.caption,
      subject: sanitizedSubject,
      html: htmlCaption,
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
      htmlBody: htmlCaption,
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
    String? htmlBody,
    DateTime? timestamp,
  }) async {
    final db = await _databaseBuilder();
    final chat = await _ensureChat(chatId);
    if (metadata != null) {
      await db.saveFileMetadata(metadata);
    }
    final displayBody = localBodyOverride ?? body;
    final resolvedBody = (displayBody?.trim().isNotEmpty == true)
        ? displayBody!.trim()
        : (metadata == null ? null : _attachmentLabel(metadata));
    final resolvedTimestamp = timestamp ?? DateTime.timestamp();
    final message = Message(
      stanzaID: _stanzaId(msgId),
      senderJid: _selfJid,
      chatJid: chat.jid,
      timestamp: resolvedTimestamp,
      body: resolvedBody,
      htmlBody: HtmlContentCodec.normalizeHtml(htmlBody),
      encryptionProtocol: EncryptionProtocol.none,
      acked: false,
      received: false,
      deltaChatId: chatId,
      deltaMsgId: msgId,
      fileMetadataID: metadata?.id,
    );
    await db.saveMessage(message);
    if (_messageStorageMode.isServerOnly) {
      await db.trimChatMessages(
        jid: chat.jid,
        maxMessages: serverOnlyChatMessageCap,
      );
    }
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
    final existing = await db.getChatByDeltaChatId(chatId);
    if (existing != null) {
      return existing;
    }
    final remote = await _context!.getChat(chatId);
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
        contactJid: chat.contactJid,
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
    // Use the real address so stored messages and status updates reflect the
    // actual sender instead of a Delta-style synthetic domain.
    return address;
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
      case DeltaChatType.mailingList:
      case DeltaChatType.outBroadcast:
      case DeltaChatType.inBroadcast:
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

  int _viewTypeFor(EmailAttachment attachment) {
    if (attachment.isGif) return DeltaMessageType.gif;
    if (attachment.isImage) return DeltaMessageType.image;
    if (attachment.isVideo) return DeltaMessageType.video;
    if (attachment.isAudio) return DeltaMessageType.audio;
    return DeltaMessageType.file;
  }

  Future<DeltaAccountsHandle> _createAccounts(String prefix) async {
    final directory = await _accountsDirectory(prefix);
    final parent = directory.parent;
    if (parent.path != directory.path) {
      await parent.create(recursive: true);
    }
    Future<void> logAccountsDirState(String reason) async {
      final entries = <String>[];
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          entries.add(p.basename(entity.path));
        }
      }
      _log.warning(
        'Delta accounts initialization failed during $reason '
        '(dirExists=${await directory.exists()}, contents=$entries)',
      );
    }

    try {
      return await _deltaSafe.createAccounts(directory: directory.path);
    } on DeltaSafeException catch (error, stackTrace) {
      await logAccountsDirState('initial create');
      _log.warning(
        'Failed to open Delta accounts at ${directory.path}, resetting storage',
        error,
        stackTrace,
      );
      await _resetAccountsStorage(prefix);
      if (parent.path != directory.path) {
        await parent.create(recursive: true);
      }
      return _deltaSafe.createAccounts(directory: directory.path);
    }
  }

  Future<Directory> _accountsDirectory(String prefix) async {
    final databaseFile = await _deltaDatabaseFile(prefix);
    return Directory('${databaseFile.path}.accounts');
  }

  Future<void> _resetAccountsStorage(String prefix) async {
    final directory = await _accountsDirectory(prefix);
    if (await directory.exists()) {
      try {
        await directory.delete(recursive: true);
      } on IOException catch (error, stackTrace) {
        _log.warning(
          'Failed to delete Delta accounts directory ${directory.path}',
          error,
          stackTrace,
        );
      }
    }
    final legacy = await _deltaDatabaseFile(prefix);
    await _deleteDatabaseArtifacts(legacy);
  }

  Future<void> deleteStorageArtifacts() async {
    final prefix = _databasePrefix;
    if (prefix == null) {
      return;
    }
    await _resetAccountsStorage(prefix);
  }

  /// Blocks an email contact in DeltaChat core.
  ///
  /// Returns true if the contact was found and blocked.
  Future<bool> blockContact(String address) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    final contactId = await context.lookupContactIdByAddress(address);
    if (contactId == null) return false;
    await context.blockContact(contactId);
    return true;
  }

  /// Unblocks an email contact in DeltaChat core.
  ///
  /// Returns true if the contact was found and unblocked.
  Future<bool> unblockContact(String address) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    final contactId = await context.lookupContactIdByAddress(address);
    if (contactId == null) return false;
    await context.unblockContact(contactId);
    return true;
  }

  /// Marks a chat as noticed in core, clearing unread badges.
  ///
  /// Returns true if the operation succeeded.
  Future<bool> markNoticedChat(int chatId) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.markNoticedChat(chatId);
  }

  /// Marks messages as seen, triggering MDN if enabled.
  ///
  /// Returns true if the operation succeeded.
  Future<bool> markSeenMessages(List<int> messageIds) async {
    if (messageIds.isEmpty) return true;
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.markSeenMessages(messageIds);
  }

  /// Returns the count of fresh (unread) messages in a chat.
  Future<int> getFreshMessageCount(int chatId) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return 0;
    return context.getFreshMessageCount(chatId);
  }

  /// Returns all fresh (unread) message IDs across all chats.
  Future<List<int>> getFreshMessageIds() async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return const [];
    return context.getFreshMessageIds();
  }

  /// Deletes messages from core and server.
  ///
  /// Returns true if the operation succeeded.
  Future<bool> deleteMessages(List<int> messageIds) async {
    if (messageIds.isEmpty) return true;
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.deleteMessages(messageIds);
  }

  /// Forwards messages to another chat.
  ///
  /// Returns true if the operation succeeded.
  Future<bool> forwardMessages({
    required List<int> messageIds,
    required int toChatId,
  }) async {
    if (messageIds.isEmpty) return true;
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.forwardMessages(messageIds: messageIds, toChatId: toChatId);
  }

  /// Searches messages in a chat.
  ///
  /// Pass chatId=0 to search all chats.
  Future<List<int>> searchMessages({
    required int chatId,
    required String query,
  }) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return const [];
    return context.searchMessages(chatId: chatId, query: query);
  }

  Future<void> hydrateMessages(List<int> messageIds) async {
    if (messageIds.isEmpty) return;
    await _ensureContextReady();
    final consumer = _eventConsumer;
    if (consumer == null) return;
    for (final messageId in messageIds) {
      await consumer.hydrateMessage(messageId);
    }
  }

  /// Sets the visibility of a chat (normal, archived, pinned).
  ///
  /// Returns true if the operation succeeded.
  Future<bool> setChatVisibility({
    required int chatId,
    required int visibility,
  }) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.setChatVisibility(chatId: chatId, visibility: visibility);
  }

  /// Triggers download of full message content for partial messages.
  ///
  /// Returns true if the download was initiated.
  Future<bool> downloadFullMessage(int messageId) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.downloadFullMessage(messageId);
  }

  /// Resends failed messages.
  ///
  /// Returns true if the resend was initiated.
  Future<bool> resendMessages(List<int> messageIds) async {
    if (messageIds.isEmpty) return true;
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.resendMessages(messageIds);
  }

  /// Sends a text message with a quote reference to another message.
  ///
  /// Returns the new message ID.
  Future<int> sendTextWithQuote({
    required int chatId,
    required String body,
    required int quotedMessageId,
    String? subject,
    String? htmlBody,
  }) async {
    if (_context == null) {
      throw StateError('Transport not initialized');
    }
    return _context!.sendTextWithQuote(
      chatId: chatId,
      message: body,
      quotedMessageId: quotedMessageId,
      subject: subject,
      html: htmlBody,
    );
  }

  /// Gets the quoted message info for a message.
  Future<DeltaQuotedMessage?> getQuotedMessage(int messageId) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return null;
    return context.getQuotedMessage(messageId);
  }

  /// Sets the draft for a chat.
  ///
  /// Pass null message to clear the draft.
  Future<bool> setDraft({
    required int chatId,
    DeltaMessage? message,
  }) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.setDraft(chatId: chatId, message: message);
  }

  /// Gets the draft for a chat.
  Future<DeltaMessage?> getDraft(int chatId) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return null;
    return context.getDraft(chatId);
  }

  /// Gets a message by ID from core.
  Future<DeltaMessage?> getMessage(int messageId) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return null;
    return context.getMessage(messageId);
  }

  /// Gets contact IDs from core.
  ///
  /// Use flags from [DeltaContactListFlags] to filter results.
  Future<List<int>> getContactIds({int flags = 0, String? query}) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return const [];
    return context.getContactIds(flags: flags, query: query);
  }

  /// Gets blocked contact IDs from core.
  Future<List<int>> getBlockedContactIds() async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return const [];
    return context.getBlockedContactIds();
  }

  /// Deletes a contact from core.
  ///
  /// Returns true if the contact was deleted.
  Future<bool> deleteContact(int contactId) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return false;
    return context.deleteContact(contactId);
  }

  /// Gets a contact by ID from core.
  Future<DeltaContact?> getContact(int contactId) async {
    await _ensureContextReady();
    final context = _context;
    if (context == null) return null;
    return context.getContact(contactId);
  }
}

String _normalizedAddress(String? raw, int chatId) {
  if (raw == null || raw.trim().isEmpty) {
    return fallbackEmailAddressForChat(chatId);
  }
  return normalizeEmailAddress(raw);
}

String _stanzaId(int msgId) => 'dc-msg-$msgId';
