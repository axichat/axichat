import 'dart:async';

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

const _defaultPageSize = 50;
const _maxFanOutRecipients = 20;
const _attachmentFanOutWarningBytes = 8 * 1024 * 1024;

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
  })  : _credentialStore = credentialStore,
        _databaseBuilder = databaseBuilder,
        _transport = transport ??
            EmailDeltaTransport(
              databaseBuilder: databaseBuilder,
              logger: logger,
            ),
        _chatmailDomain = chatmailDomain,
        _log = logger ?? Logger('EmailService'),
        _notificationService = notificationService {
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
  late final void Function(DeltaCoreEvent) _eventListener;
  var _listenerAttached = false;

  static final RegisteredCredentialKey _addressKey =
      CredentialStore.registerKey('chatmail_address');
  static final RegisteredCredentialKey _passwordKey =
      CredentialStore.registerKey('chatmail_password');

  String? _databasePrefix;
  String? _databasePassphrase;
  EmailAccount? _activeAccount;
  bool _running = false;

  EmailAccount? get activeAccount => _activeAccount;

  bool get isRunning => _running;

  Stream<DeltaCoreEvent> get events => _transport.events;

  Future<EmailAccount?> currentAccount() async {
    final address = await _credentialStore.read(key: _addressKey);
    final password = await _credentialStore.read(key: _passwordKey);
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

    var address = await _credentialStore.read(key: _addressKey);
    var password = await _credentialStore.read(key: _passwordKey);
    var generatedAddress = false;

    if (address == null || password == null) {
      final preferredAddress = _preferredAddressFromJid(jid) ??
          _generateAddress(localPart: displayName);
      address = preferredAddress;
      password = generateRandomString(length: 24);
      await _credentialStore.write(key: _addressKey, value: address);
      await _credentialStore.write(key: _passwordKey, value: password);
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
        await _credentialStore.delete(key: _addressKey);
        await _credentialStore.delete(key: _passwordKey);
        throw EmailProvisioningException(
          'Email address $address is unavailable. Please choose a different username.',
        );
      }
      rethrow;
    }

    await start();

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

  Future<void> shutdown() => stop();

  Future<void> burn() async {
    _detachTransportListener();
    await _transport.dispose();
    _running = false;
    _activeAccount = null;
    await _credentialStore.delete(key: _addressKey);
    await _credentialStore.delete(key: _passwordKey);
    _databasePrefix = null;
    _databasePassphrase = null;
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
        await _notifyIncoming(chatId: event.data1, msgId: event.data2);
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
    final normalizedLocal = localPart.toLowerCase();
    return '$normalizedLocal@$_chatmailDomain';
  }

  String? _preferredAddressFromJid(String jid) {
    final bare = jid.split('/').first;
    final parts = bare.split('@');
    if (parts.length != 2) {
      return null;
    }
    final local = parts[0].toLowerCase();
    final domain = parts[1].toLowerCase();
    if (local.isEmpty || domain.isEmpty) {
      return null;
    }
    return '$local@$domain';
  }

  List<Chat> _sortChats(List<Chat> chats) => List<Chat>.of(chats)
    ..sort((a, b) {
      if (a.favorited == b.favorited) {
        return b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp);
      }
      return (a.favorited ? 0 : 1) - (b.favorited ? 0 : 1);
    });
}

const _deltaDomain = 'delta.chat';
const _defaultDeltaSelfJid = 'dc-self@$_deltaDomain';

String _chatJid(int chatId) => 'dc-$chatId@$_deltaDomain';

String _stanzaId(int msgId) => 'dc-msg-$msgId';
