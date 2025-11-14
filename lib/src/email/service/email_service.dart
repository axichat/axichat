import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:delta_ffi/delta_safe.dart';

import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';

const _defaultPageSize = 50;
const _maxFanOutRecipients = 20;
const _attachmentFanOutWarningBytes = 8 * 1024 * 1024;
const _foregroundKeepaliveInterval = Duration(seconds: 45);
const _foregroundFetchTimeout = Duration(seconds: 8);
const _notificationFlushDelay = Duration(milliseconds: 500);

class EmailAccount {
  const EmailAccount({required this.address, required this.password});

  final String address;
  final String password;
}

class EmailProvisioningException implements Exception {
  const EmailProvisioningException(this.message);

  final String message;

  @override
  String toString() => 'EmailProvisioningException: $message';
}

class FanOutValidationException implements Exception {
  const FanOutValidationException(this.message);

  final String message;

  @override
  String toString() => 'FanOutValidationException: $message';
}

class EmailService {
  EmailService({
    required CredentialStore credentialStore,
    required Future<XmppDatabase> Function() databaseBuilder,
    EmailDeltaTransport? transport,
    String chatmailDomain = 'nine.testrun.org',
    NotificationService? notificationService,
    Logger? logger,
    ForegroundTaskBridge? foregroundBridge,
  })  : _credentialStore = credentialStore,
        _databaseBuilder = databaseBuilder,
        _transport = transport ??
            EmailDeltaTransport(
              databaseBuilder: databaseBuilder,
              logger: logger,
            ),
        _chatmailDomain = chatmailDomain,
        _log = logger ?? Logger('EmailService'),
        _notificationService = notificationService,
        _foregroundBridge = foregroundBridge ?? foregroundTaskBridge {
    _eventListener = (event) => unawaited(_processDeltaEvent(event));
    _transport.addEventListener(_eventListener);
    _listenerAttached = true;
  }

  final CredentialStore _credentialStore;
  final Future<XmppDatabase> Function() _databaseBuilder;
  final EmailDeltaTransport _transport;
  final String _chatmailDomain;
  final Logger _log;
  final NotificationService? _notificationService;
  final ForegroundTaskBridge? _foregroundBridge;
  late final void Function(DeltaCoreEvent) _eventListener;
  var _listenerAttached = false;

  String? _databasePrefix;
  String? _databasePassphrase;
  EmailAccount? _activeAccount;
  String? _activeCredentialScope;
  bool _running = false;
  final Map<String, RegisteredCredentialKey> _addressKeys = {};
  final Map<String, RegisteredCredentialKey> _passwordKeys = {};
  bool _foregroundKeepaliveEnabled = false;
  bool _foregroundKeepaliveListenerAttached = false;
  bool _foregroundKeepaliveServiceAcquired = false;
  bool _foregroundKeepaliveTickScheduled = false;
  int _foregroundKeepaliveOperationId = 0;
  final List<_PendingNotification> _pendingNotifications = [];
  Timer? _notificationFlushTimer;
  String? _pendingPushToken;

  EmailAccount? get activeAccount => _activeAccount;

  bool get isRunning => _running;

  Stream<DeltaCoreEvent> get events => _transport.events;

  Future<EmailAccount?> currentAccount(String jid) async {
    final scope = _scopeForJid(jid);
    final address =
        await _credentialStore.read(key: _addressKeyForScope(scope));
    final password =
        await _credentialStore.read(key: _passwordKeyForScope(scope));
    if (address == null || password == null) {
      return null;
    }
    return EmailAccount(address: address, password: password);
  }

  Future<EmailAccount> ensureProvisioned({
    required String displayName,
    required String databasePrefix,
    required String databasePassphrase,
    required String jid,
  }) async {
    final scope = _scopeForJid(jid);
    final needsInit = _databasePrefix != databasePrefix ||
        _databasePassphrase != databasePassphrase;
    if (needsInit) {
      _databasePrefix = databasePrefix;
      _databasePassphrase = databasePassphrase;
      await _transport.ensureInitialized(
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
      );
      if (!_listenerAttached) {
        _transport.addEventListener(_eventListener);
        _listenerAttached = true;
      }
    }

    if (!_listenerAttached) {
      _transport.addEventListener(_eventListener);
      _listenerAttached = true;
    }

    _activeCredentialScope = scope;

    final addressKey = _addressKeyForScope(scope);
    final passwordKey = _passwordKeyForScope(scope);

    var address = await _credentialStore.read(key: addressKey);
    var password = await _credentialStore.read(key: passwordKey);
    var generatedAddress = false;

    if (address == null || password == null) {
      final preferredAddress = _preferredAddressFromJid(jid) ??
          _generateAddress(localPart: displayName);
      address = preferredAddress;
      password = generateRandomString(length: 24);
      await _credentialStore.write(key: addressKey, value: address);
      await _credentialStore.write(key: passwordKey, value: password);
      generatedAddress = true;
    }

    _log.info('Configuring Chatmail account credentials');
    try {
      await _transport.configureAccount(
        address: address,
        password: password,
        displayName: displayName,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      _log.warning(
        'Failed to configure Chatmail account for $jid',
        error,
        stackTrace,
      );
      if (generatedAddress) {
        await _clearCredentials(scope);
        throw EmailProvisioningException(
          'Email address $address is unavailable. Please choose a different username.',
        );
      }
      rethrow;
    }

    await start();
    await _applyPendingPushToken();

    final account = EmailAccount(address: address, password: password);
    _activeAccount = account;
    return account;
  }

  Future<void> start() async {
    if (_running) return;
    await _transport.start();
    _running = true;
  }

  Future<void> stop() async {
    if (!_running) return;
    await _transport.stop();
    _running = false;
  }

  Future<void> shutdown({
    String? jid,
    bool clearCredentials = false,
  }) async {
    await stop();
    await _stopForegroundKeepalive();
    _clearNotificationQueue();
    if (!clearCredentials) {
      return;
    }
    final scope = _scopeForOptionalJid(jid);
    if (scope != null) {
      await _clearCredentials(scope);
    }
  }

  Future<void> burn({String? jid}) async {
    final scope = _scopeForOptionalJid(jid);
    await stop();
    _detachTransportListener();
    await _stopForegroundKeepalive();
    _clearNotificationQueue();
    await _transport.dispose();
    _running = false;
    if (scope != null) {
      await _clearCredentials(scope);
    }
    _databasePrefix = null;
    _databasePassphrase = null;
    _activeAccount = null;
    _activeCredentialScope = null;
    _pendingPushToken = null;
  }

  Future<Chat> ensureChatForAddress({
    required String address,
    String? displayName,
  }) async {
    await _ensureReady();
    final chatId = await _transport.ensureChatForAddress(
      address: address,
      displayName: displayName,
    );
    return _waitForChat(chatId);
  }

  Future<Chat> ensureChatForEmailChat(Chat chat) async {
    await _ensureReady();
    if (chat.deltaChatId != null) {
      return chat;
    }
    final address = chat.emailAddress;
    if (address == null) {
      throw StateError('Email chat ${chat.jid} missing emailAddress metadata.');
    }
    final chatId = await _transport.ensureChatForAddress(
      address: address,
      displayName: chat.contactDisplayName ?? chat.title,
    );
    return _waitForChat(chatId);
  }

  Future<int> sendMessage({
    required Chat chat,
    required String body,
  }) async {
    final deltaChat = await ensureChatForEmailChat(chat);
    final chatId = deltaChat.deltaChatId!;
    await _ensureReady();
    return _transport.sendText(chatId: chatId, body: body);
  }

  Future<int> sendAttachment({
    required Chat chat,
    required EmailAttachment attachment,
  }) async {
    final deltaChat = await ensureChatForEmailChat(chat);
    final chatId = deltaChat.deltaChatId!;
    await _ensureReady();
    return _transport.sendAttachment(
      chatId: chatId,
      attachment: attachment,
    );
  }

  Future<FanOutSendReport> fanOutSend({
    required List<FanOutTarget> targets,
    String? body,
    EmailAttachment? attachment,
    bool useSubjectToken = true,
    String? shareId,
  }) async {
    await _ensureReady();
    if (targets.isEmpty) {
      throw const FanOutValidationException('Select at least one recipient.');
    }
    final resolvedTargets = await _resolveFanOutTargets(targets);
    if (resolvedTargets.isEmpty) {
      throw const FanOutValidationException('Unable to resolve recipients.');
    }
    if (resolvedTargets.length > _maxFanOutRecipients) {
      throw const FanOutValidationException(
        'Fan-out limited to $_maxFanOutRecipients recipients.',
      );
    }
    final trimmedBody = body?.trim();
    final hasBody = trimmedBody?.isNotEmpty == true;
    final hasAttachment = attachment != null;
    if (!hasBody && !hasAttachment) {
      throw const FanOutValidationException('Message cannot be empty.');
    }
    final db = await _databaseBuilder();
    final existingShare =
        shareId == null ? null : await db.getMessageShareById(shareId);
    final existingParticipants = <MessageParticipantData>[];
    final existingShareId = existingShare?.shareId ?? shareId;
    if (existingShareId != null) {
      existingParticipants
          .addAll(await db.getParticipantsForShare(existingShareId));
    }
    final resolvedShareId =
        shareId ?? existingShare?.shareId ?? ShareTokenCodec.generateShareId();
    final resolvedToken = existingShare?.subjectToken ??
        (useSubjectToken
            ? ShareTokenCodec.subjectToken(resolvedShareId)
            : null);

    final transmitBody = resolvedToken != null && hasBody
        ? ShareTokenCodec.injectToken(token: resolvedToken, body: trimmedBody!)
        : trimmedBody ?? '';

    final sanitizedBody = resolvedToken != null && hasBody
        ? ShareTokenCodec.stripToken(transmitBody)?.cleanedBody ?? trimmedBody!
        : trimmedBody ?? '';

    final captionText = attachment?.caption?.trim();
    final transmitCaption =
        resolvedToken != null && captionText?.isNotEmpty == true
            ? ShareTokenCodec.injectToken(
                token: resolvedToken,
                body: captionText!,
              )
            : captionText;
    final sanitizedCaption =
        resolvedToken != null && captionText?.isNotEmpty == true
            ? ShareTokenCodec.stripToken(transmitCaption)?.cleanedBody ??
                captionText!
            : captionText;

    final participants = await _buildShareParticipants(
      shareId: resolvedShareId,
      chats: resolvedTargets.values,
      existingParticipants: existingParticipants,
    );
    final shareRecord = MessageShareData(
      shareId: resolvedShareId,
      originatorDcMsgId: existingShare?.originatorDcMsgId,
      subjectToken: resolvedToken,
      createdAt: existingShare?.createdAt ?? DateTime.timestamp(),
      participantCount: participants.length,
    );
    await db.createMessageShare(
      share: shareRecord,
      participants: participants,
    );

    final statuses = <FanOutRecipientStatus>[];
    var originatorCaptured = existingShare?.originatorDcMsgId != null;
    for (final entry in resolvedTargets.values) {
      try {
        final normalizedChat = entry.deltaChatId == null
            ? await ensureChatForEmailChat(entry)
            : entry;
        final chatId = normalizedChat.deltaChatId!;
        int msgId;
        if (hasAttachment) {
          final updatedAttachment = attachment.copyWith(
            caption: transmitCaption,
          );
          msgId = await _transport.sendAttachment(
            chatId: chatId,
            attachment: updatedAttachment,
            shareId: resolvedShareId,
            captionOverride: sanitizedCaption,
          );
        } else {
          msgId = await _transport.sendText(
            chatId: chatId,
            body: transmitBody,
            shareId: resolvedShareId,
            localBodyOverride: sanitizedBody,
          );
        }
        if (!originatorCaptured) {
          await db.assignShareOriginator(
            shareId: resolvedShareId,
            originatorDcMsgId: msgId,
          );
          originatorCaptured = true;
        }
        statuses.add(
          FanOutRecipientStatus(
            chat: normalizedChat,
            state: FanOutRecipientState.sent,
            deltaMsgId: msgId,
          ),
        );
      } on Exception catch (error, stackTrace) {
        _log.warning(
          'Failed to send fan-out message to ${entry.jid}',
          error,
          stackTrace,
        );
        statuses.add(
          FanOutRecipientStatus(
            chat: entry,
            state: FanOutRecipientState.failed,
            error: error,
          ),
        );
      }
    }

    final attachmentWarning = hasAttachment &&
        resolvedTargets.length > 1 &&
        attachment.sizeBytes > _attachmentFanOutWarningBytes;

    return FanOutSendReport(
      shareId: resolvedShareId,
      subjectToken: resolvedToken,
      statuses: statuses,
      attachmentWarning: attachmentWarning,
    );
  }

  Future<ShareContext?> shareContextForMessage(Message message) async {
    final deltaMsgId = message.deltaMsgId;
    if (deltaMsgId == null) return null;
    await _ensureReady();
    final db = await _databaseBuilder();
    final shareId = await db.getShareIdForDeltaMessage(deltaMsgId);
    if (shareId == null) return null;
    final participants = await db.getParticipantsForShare(shareId);
    final chats = <Chat>[];
    for (final participant in participants) {
      final chat = await db.getChat(participant.contactJid);
      if (chat != null) {
        chats.add(chat);
      }
    }
    return ShareContext(
      shareId: shareId,
      participants: chats,
    );
  }

  Future<EmailAttachment?> attachmentForMessage(Message message) async {
    final metadataId = message.fileMetadataID;
    if (metadataId == null) return null;
    await _ensureReady();
    final db = await _databaseBuilder();
    final metadata = await db.getFileMetadata(metadataId);
    if (metadata == null) return null;
    final path = metadata.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final size = metadata.sizeBytes ?? await file.length();
    return EmailAttachment(
      path: path,
      fileName: metadata.filename,
      sizeBytes: size,
      mimeType: metadata.mimeType,
      width: metadata.width,
      height: metadata.height,
      caption: message.body,
    );
  }

  Future<int> sendToAddress({
    required String address,
    String? displayName,
    required String body,
  }) async {
    final chat = await ensureChatForAddress(
      address: address,
      displayName: displayName,
    );
    return sendMessage(chat: chat, body: body);
  }

  Future<void> setClientState([bool active = true]) async {
    if (active) {
      await start();
    } else {
      await stop();
    }
  }

  Future<void> registerPushToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) return;
    _pendingPushToken = normalized;
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _transport.registerPushToken(normalized);
  }

  Future<void> handleNetworkAvailable() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _transport.notifyNetworkAvailable();
  }

  Future<void> handleNetworkLost() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _transport.notifyNetworkLost();
  }

  Future<bool> performBackgroundFetch({
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    return _transport.performBackgroundFetch(timeout);
  }

  Future<void> setForegroundKeepalive(bool enabled) async {
    if (!enabled) {
      await _stopForegroundKeepalive();
      return;
    }

    final operationId = ++_foregroundKeepaliveOperationId;

    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    if (_foregroundKeepaliveEnabled) {
      return;
    }
    final bridge = _foregroundBridge;
    if (bridge == null) {
      _log.fine('Foreground bridge unavailable, skipping keepalive.');
      return;
    }

    await start();
    if (!_isForegroundKeepaliveOpCurrent(operationId)) {
      return;
    }

    _attachForegroundKeepaliveListener();

    try {
      await bridge.acquire(
        clientId: foregroundClientEmailKeepalive,
        config: buildForegroundServiceConfig(
          notificationText: 'Email sync active',
        ),
      );
      _foregroundKeepaliveServiceAcquired = true;
      if (!_isForegroundKeepaliveOpCurrent(operationId)) {
        await _releaseForegroundKeepaliveResources();
        return;
      }
      await bridge.send([
        emailKeepalivePrefix,
        emailKeepaliveStartCommand,
        _foregroundKeepaliveInterval.inMilliseconds,
      ]);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to enable email foreground keepalive',
        error,
        stackTrace,
      );
      _foregroundKeepaliveEnabled = false;
      await _releaseForegroundKeepaliveResources();
      return;
    }

    if (!_isForegroundKeepaliveOpCurrent(operationId)) {
      await _releaseForegroundKeepaliveResources();
      return;
    }

    _foregroundKeepaliveEnabled = true;
    unawaited(_foregroundKeepaliveTick());
  }

  Stream<List<Message>> messageStreamForChat(
    String jid, {
    int start = 0,
    int end = _defaultPageSize,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield await db.getChatMessages(
      jid,
      start: start,
      end: end,
      filter: filter,
    );
    yield* db.watchChatMessages(
      jid,
      start: start,
      end: end,
      filter: filter,
    );
  }

  Stream<List<Draft>> draftsStream({
    int start = 0,
    int end = _defaultPageSize,
  }) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield await db.getDrafts(start: start, end: end);
    yield* db.watchDrafts(start: start, end: end);
  }

  Stream<List<Chat>> chatsStream({
    int start = 0,
    int end = _defaultPageSize,
  }) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield _sortChats(await db.getChats(start: start, end: end));
    yield* db.watchChats(start: start, end: end).map<List<Chat>>(_sortChats);
  }

  Stream<Chat?> chatStream(String jid) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield await db.getChat(jid);
    yield* db.watchChat(jid);
  }

  Future<void> _processDeltaEvent(DeltaCoreEvent event) async {
    switch (event.type) {
      case DeltaEventType.incomingMsg:
        _queueNotification(chatId: event.data1, msgId: event.data2);
        break;
      case DeltaEventType.incomingMsgBunch:
        await _flushQueuedNotifications();
        break;
      case DeltaEventType.msgsChanged:
      case DeltaEventType.chatModified:
        break;
      case DeltaEventType.msgDelivered:
      case DeltaEventType.msgFailed:
      case DeltaEventType.msgRead:
      default:
        break;
    }
  }

  void _queueNotification({required int chatId, required int msgId}) {
    _pendingNotifications
        .add(_PendingNotification(chatId: chatId, msgId: msgId));
    _notificationFlushTimer ??= Timer(_notificationFlushDelay, () {
      _notificationFlushTimer = null;
      unawaited(_flushQueuedNotifications());
    });
  }

  Future<void> _flushQueuedNotifications() async {
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
    if (_pendingNotifications.isEmpty) return;
    final pending = List<_PendingNotification>.from(_pendingNotifications);
    _pendingNotifications.clear();
    for (final entry in pending) {
      await _notifyIncoming(chatId: entry.chatId, msgId: entry.msgId);
    }
  }

  Future<void> _notifyIncoming({
    required int chatId,
    required int msgId,
  }) async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    try {
      final db = await _databaseBuilder();
      final message = await db.getMessageByStanzaID(_stanzaId(msgId));
      if (message == null) {
        return;
      }
      final selfJid = selfSenderJid;
      if (selfJid != null && message.senderJid == selfJid) {
        return;
      }
      final notificationBody =
          await _notificationBody(db: db, message: message);
      if (notificationBody == null) {
        return;
      }
      final chat = await db.getChat(message.chatJid);
      if (chat?.muted ?? false) {
        return;
      }
      await notificationService.sendNotification(
        title: chat?.title ?? message.senderJid,
        body: notificationBody,
        payload: chat?.jid,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise notification for email message ${_stanzaId(msgId)}',
        error,
        stackTrace,
      );
    }
  }

  void _detachTransportListener() {
    if (!_listenerAttached) return;
    _transport.removeEventListener(_eventListener);
    _listenerAttached = false;
  }

  void _clearNotificationQueue() {
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
    _pendingNotifications.clear();
  }

  bool _isForegroundKeepaliveOpCurrent(int operationId) =>
      operationId == _foregroundKeepaliveOperationId;

  Future<void> _applyPendingPushToken() async {
    final token = _pendingPushToken;
    if (token == null || token.isEmpty) return;
    await _transport.registerPushToken(token);
  }

  Future<void> _stopForegroundKeepalive() async {
    _foregroundKeepaliveOperationId++;
    if (!_foregroundKeepaliveEnabled &&
        !_foregroundKeepaliveListenerAttached &&
        !_foregroundKeepaliveServiceAcquired) {
      return;
    }
    _foregroundKeepaliveEnabled = false;
    _foregroundKeepaliveTickScheduled = false;
    final bridge = _foregroundBridge;
    if (bridge != null && _foregroundKeepaliveServiceAcquired) {
      try {
        await bridge.send([
          emailKeepalivePrefix,
          emailKeepaliveStopCommand,
        ]);
      } on Exception catch (error, stackTrace) {
        _log.finer('Failed to stop email keepalive', error, stackTrace);
      }
    }
    await _releaseForegroundKeepaliveResources();
  }

  void _attachForegroundKeepaliveListener() {
    if (_foregroundKeepaliveListenerAttached) {
      return;
    }
    final bridge = _foregroundBridge;
    if (bridge == null) {
      return;
    }
    bridge.registerListener(
      foregroundClientEmailKeepalive,
      _handleForegroundTaskMessage,
    );
    _foregroundKeepaliveListenerAttached = true;
  }

  Future<void> _releaseForegroundKeepaliveResources() async {
    final bridge = _foregroundBridge;
    if (bridge == null) {
      _foregroundKeepaliveListenerAttached = false;
      _foregroundKeepaliveServiceAcquired = false;
      return;
    }
    if (_foregroundKeepaliveServiceAcquired) {
      await bridge.release(foregroundClientEmailKeepalive);
      _foregroundKeepaliveServiceAcquired = false;
    }
    if (_foregroundKeepaliveListenerAttached) {
      bridge.unregisterListener(foregroundClientEmailKeepalive);
      _foregroundKeepaliveListenerAttached = false;
    }
  }

  void _handleForegroundTaskMessage(String data) {
    if (!data.startsWith('$emailKeepaliveTickPrefix$join')) {
      return;
    }
    if (!_foregroundKeepaliveEnabled || _foregroundKeepaliveTickScheduled) {
      return;
    }
    _foregroundKeepaliveTickScheduled = true;
    unawaited(_runForegroundKeepaliveTick());
  }

  Future<void> _runForegroundKeepaliveTick() async {
    try {
      await _foregroundKeepaliveTick();
    } finally {
      _foregroundKeepaliveTickScheduled = false;
    }
  }

  Future<void> _foregroundKeepaliveTick() async {
    if (!_foregroundKeepaliveEnabled) {
      return;
    }
    try {
      await handleNetworkAvailable();
      await performBackgroundFetch(timeout: _foregroundFetchTimeout);
    } on Exception catch (error, stackTrace) {
      _log.finer('Foreground keepalive tick failed', error, stackTrace);
    }
  }

  Future<void> _ensureReady() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      throw StateError('Call ensureProvisioned before using EmailService.');
    }
    if (!_running) {
      await start();
    }
  }

  Future<String?> _notificationBody({
    required XmppDatabase db,
    required Message message,
  }) async {
    final trimmed = message.body?.trim();
    if (trimmed?.isNotEmpty == true) {
      return trimmed;
    }
    final metadataId = message.fileMetadataID;
    if (metadataId == null) {
      return null;
    }
    final metadata = await db.getFileMetadata(metadataId);
    if (metadata == null) {
      return 'Attachment';
    }
    final filename = metadata.filename.trim();
    return filename.isEmpty ? 'Attachment' : 'Attachment: $filename';
  }

  String? get selfSenderJid => _transport.selfJid;

  Future<Map<String, Chat>> _resolveFanOutTargets(
    List<FanOutTarget> targets,
  ) async {
    final resolved = <String, Chat>{};
    for (final target in targets) {
      Chat chat;
      if (target.chat != null) {
        chat = await ensureChatForEmailChat(target.chat!);
      } else {
        final address = target.address;
        if (address == null || address.isEmpty) {
          continue;
        }
        chat = await ensureChatForAddress(
          address: address,
          displayName: target.displayName ?? address,
        );
      }
      resolved.putIfAbsent(chat.jid, () => chat);
    }
    return resolved;
  }

  Future<List<MessageParticipantData>> _buildShareParticipants({
    required String shareId,
    required Iterable<Chat> chats,
    Iterable<MessageParticipantData> existingParticipants = const [],
  }) async {
    final participants = <String, MessageParticipantData>{};
    for (final participant in existingParticipants) {
      participants[participant.contactJid] = participant;
    }
    final senderJid = _senderParticipantJid();
    if (senderJid != null && senderJid.isNotEmpty) {
      participants[senderJid] = MessageParticipantData(
        shareId: shareId,
        contactJid: senderJid,
        role: MessageParticipantRole.sender,
      );
    }
    for (final chat in chats) {
      participants.putIfAbsent(
        chat.jid,
        () => MessageParticipantData(
          shareId: shareId,
          contactJid: chat.jid,
          role: MessageParticipantRole.recipient,
        ),
      );
    }
    return participants.values.toList();
  }

  String? _senderParticipantJid() => selfSenderJid ?? _defaultDeltaSelfJid;

  Future<Chat> _waitForChat(int chatId) async {
    final jid = _chatJid(chatId);
    final db = await _databaseBuilder();

    final existing = await db.getChat(jid);
    if (existing != null) {
      return existing;
    }

    try {
      final chat = await db
          .watchChat(jid)
          .where((chat) => chat != null)
          .cast<Chat>()
          .first
          .timeout(const Duration(seconds: 10));
      return chat;
    } on TimeoutException {
      throw StateError('Email chat $chatId was not persisted within timeout.');
    }
  }

  String _generateAddress({required String localPart}) {
    final normalizedLocal =
        localPart.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9._-]'), '');
    return '$normalizedLocal@$_chatmailDomain';
  }

  String? _preferredAddressFromJid(String jid) {
    final bare = _normalizeJid(jid);
    final parts = bare.split('@');
    if (parts.length != 2) {
      return null;
    }
    final local = parts[0].toLowerCase();
    final domain = parts[1].toLowerCase();
    if (local.isEmpty || domain.isEmpty) {
      return null;
    }
    if (_chatmailDomain.toLowerCase() == domain) {
      return '$local@$domain';
    }
    final resolvedDomain =
        _chatmailDomain.isEmpty ? domain : _chatmailDomain.toLowerCase();
    return '$local@$resolvedDomain';
  }

  List<Chat> _sortChats(List<Chat> chats) => List<Chat>.of(chats)
    ..sort((a, b) {
      if (a.favorited == b.favorited) {
        return b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp);
      }
      return (a.favorited ? 0 : 1) - (b.favorited ? 0 : 1);
    });

  RegisteredCredentialKey _addressKeyForScope(String scope) {
    return _addressKeys.putIfAbsent(
      scope,
      () => CredentialStore.registerKey('chatmail_address_$scope'),
    );
  }

  RegisteredCredentialKey _passwordKeyForScope(String scope) {
    return _passwordKeys.putIfAbsent(
      scope,
      () => CredentialStore.registerKey('chatmail_password_$scope'),
    );
  }

  String _scopeForJid(String jid) => _normalizeJid(jid).toLowerCase();

  String? _scopeForOptionalJid(String? jid) =>
      jid == null ? _activeCredentialScope : _scopeForJid(jid);

  String _normalizeJid(String jid) => jid.split('/').first;

  Future<void> _clearCredentials(String scope) async {
    await _credentialStore.delete(key: _addressKeyForScope(scope));
    await _credentialStore.delete(key: _passwordKeyForScope(scope));
    if (_activeCredentialScope == scope) {
      _activeCredentialScope = null;
      _activeAccount = null;
    }
  }
}

const _deltaDomain = 'delta.chat';
const _defaultDeltaSelfJid = 'dc-self@$_deltaDomain';

String _chatJid(int chatId) => 'dc-$chatId@$_deltaDomain';

String _stanzaId(int msgId) => 'dc-msg-$msgId';

class _PendingNotification {
  const _PendingNotification({required this.chatId, required this.msgId});

  final int chatId;
  final int msgId;
}
