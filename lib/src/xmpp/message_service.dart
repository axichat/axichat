part of 'package:axichat/src/xmpp/xmpp_service.dart';

extension MessageEvent on mox.MessageEvent {
  String get text =>
      get<mox.ReplyData>()?.withoutFallback ??
      get<mox.MessageBodyData>()?.body ??
      '';

  bool get isCarbon => get<mox.CarbonsData>()?.isCarbon ?? false;

  bool get displayable {
    final hasBody = get<mox.MessageBodyData>()?.body?.isNotEmpty ?? false;
    final hasSfs = get<mox.StatelessFileSharingData>() != null;
    final hasFun = get<mox.FileUploadNotificationData>() != null;
    final hasOob = get<mox.OOBData>() != null;
    return hasBody || hasSfs || hasFun || hasOob;
  }
}

class MamPageResult {
  const MamPageResult({
    required this.complete,
    this.firstId,
    this.lastId,
    this.count,
  });

  final bool complete;
  final String? firstId;
  final String? lastId;
  final int? count;
}

class _ServerOnlyConversation {
  _ServerOnlyConversation(this.controller, this.window);

  final StreamController<List<Message>> controller;
  final List<Message> messages = <Message>[];
  String? before;
  int? totalCount;
  bool complete = false;
  int window;
}

final _capabilityCacheKey =
    XmppStateStore.registerKey('message_peer_capabilities');

class _PeerCapabilities {
  const _PeerCapabilities({
    required this.supportsMarkers,
    required this.supportsReceipts,
  });

  final bool supportsMarkers;
  final bool supportsReceipts;

  Map<String, Object> toJson() => {
        'markers': supportsMarkers,
        'receipts': supportsReceipts,
      };

  static _PeerCapabilities fromJson(Map<dynamic, dynamic> json) =>
      _PeerCapabilities(
        supportsMarkers: json['markers'] as bool? ?? false,
        supportsReceipts: json['receipts'] as bool? ?? false,
      );

  static const empty = _PeerCapabilities(
    supportsMarkers: false,
    supportsReceipts: false,
  );
}

mixin MessageService on XmppBase, BaseStreamService, MucService {
  Stream<List<Message>> messageStreamForChat(
    String jid, {
    int start = 0,
    int end = 50,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) {
    StreamSubscription<List<Message>>? backendSubscription;
    StreamSubscription<MessageStorageMode>? modeSubscription;
    final controller = StreamController<List<Message>>.broadcast();

    Future<void> bindToMode(MessageStorageMode mode) async {
      await backendSubscription?.cancel();
      if (mode.isServerOnly) {
        final conversation = _serverOnlyConversationFor(
          jid,
          desiredWindow: end,
        );
        controller.add(List<Message>.unmodifiable(conversation.messages));
        backendSubscription = conversation.controller.stream.listen(
          controller.add,
          onError: controller.addError,
        );
        return;
      }
      backendSubscription = _localMessageStreamForChat(
        jid: jid,
        start: start,
        end: end,
        filter: filter,
      ).listen(
        controller.add,
        onError: controller.addError,
      );
    }

    controller.onListen = () {
      modeSubscription ??= _messageStorageModeChanges.stream.listen(bindToMode);
      unawaited(bindToMode(_messageStorageMode));
    };

    controller.onCancel = () async {
      await backendSubscription?.cancel();
      if (!controller.hasListener) {
        await modeSubscription?.cancel();
        modeSubscription = null;
      }
    };

    return controller.stream;
  }

  Stream<List<Message>> _localMessageStreamForChat({
    required String jid,
    required int start,
    required int end,
    required MessageTimelineFilter filter,
  }) {
    return createSingleItemStream<List<Message>, XmppDatabase>(
      watchFunction: (db) async {
        final messagesStream = db.watchChatMessages(
          jid,
          start: start,
          end: end,
          filter: filter,
        );
        final reactionsStream = db.watchReactionsForChat(jid);
        final initialMessages = await db.getChatMessages(
          jid,
          start: start,
          end: end,
          filter: filter,
        );
        final initialReactions = await db.getReactionsForChat(jid);
        return _combineMessageAndReactionStreams(
          messageStream: messagesStream,
          reactionStream: reactionsStream,
          initialMessages: initialMessages,
          initialReactions: initialReactions,
        );
      },
    );
  }

  MessageStorageMode get messageStorageMode => _messageStorageMode;

  void updateMessageStorageMode(MessageStorageMode mode) {
    if (_messageStorageMode == mode) return;
    _messageStorageMode = mode;
    if (mode.isServerOnly) {
      _resetServerOnlyConversations();
    }
    _messageStorageModeChanges.add(mode);
  }

  _ServerOnlyConversation _serverOnlyConversationFor(
    String jid, {
    int? desiredWindow,
  }) {
    final targetWindow = math.max(_serverOnlyWindow, desiredWindow ?? 0);
    if (_serverOnlyConversations[jid]
        case final _ServerOnlyConversation existing) {
      existing.window = math.max(existing.window, targetWindow);
      return existing;
    }
    final controller = StreamController<List<Message>>.broadcast();
    final conversation = _ServerOnlyConversation(
      controller,
      targetWindow,
    );
    controller.onListen = () {
      controller.add(List<Message>.unmodifiable(conversation.messages));
    };
    _serverOnlyConversations[jid] = conversation;
    return conversation;
  }

  void _emitServerOnlyConversation(String jid) {
    final conversation = _serverOnlyConversations[jid];
    if (conversation == null) return;
    if (!conversation.controller.hasListener) return;
    conversation.controller.add(
      List<Message>.unmodifiable(conversation.messages),
    );
  }

  void _addServerOnlyMessage(
    String jid,
    Message message, {
    int? desiredWindow,
  }) {
    final conversation = _serverOnlyConversationFor(
      jid,
      desiredWindow: desiredWindow,
    );
    conversation.messages.removeWhere(
      (existing) =>
          existing.stanzaID == message.stanzaID ||
          (message.originID != null && message.originID == existing.originID),
    );
    conversation.messages.add(message);
    conversation.messages.sort(
      (a, b) => (b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    final window = desiredWindow == null
        ? conversation.window
        : (conversation.window = math.max(conversation.window, desiredWindow));
    if (conversation.messages.length > window) {
      conversation.messages.removeRange(
        window,
        conversation.messages.length,
      );
    }
    _emitServerOnlyConversation(jid);
  }

  void _resetServerOnlyConversations() {
    for (final conversation in _serverOnlyConversations.values) {
      conversation.controller.close();
    }
    _serverOnlyConversations.clear();
  }

  String? _stableKeyForEvent(mox.MessageEvent event) {
    final stableIdData = event.extensions.get<mox.StableIdData>();
    final stanzaIds = stableIdData?.stanzaIds;
    if (stanzaIds != null && stanzaIds.isNotEmpty) {
      final stanza = stanzaIds.first;
      return 'sid:${stanza.id}@${stanza.by.toBare()}';
    }
    if (stableIdData?.originId case final origin?) {
      return 'oid:$origin';
    }
    if (event.id != null) {
      return 'mid:${event.id}-${event.from.toBare()}';
    }
    return null;
  }

  bool _stableKeySeen(String chatJid, String key) =>
      _seenStableKeys[chatJid]?.contains(key) ?? false;

  void _rememberStableKey(String chatJid, String key) {
    final seen = _seenStableKeys.putIfAbsent(chatJid, () => <String>{});
    final order = _stableKeyOrder.putIfAbsent(chatJid, () => Queue<String>());
    if (seen.contains(key)) return;
    seen.add(key);
    order.addLast(key);
    if (order.length > _stableKeyLimit) {
      final evicted = order.removeFirst();
      seen.remove(evicted);
    }
  }

  Future<bool> _isDuplicate(
    Message message,
    mox.MessageEvent event, {
    String? stableKey,
  }) async {
    final chatJid = message.chatJid;
    if (stableKey != null && _stableKeySeen(chatJid, stableKey)) {
      return true;
    }
    if (_messageStorageMode.isServerOnly) {
      final existing = _serverOnlyConversations[chatJid]?.messages.any(
                (candidate) =>
                    candidate.stanzaID == message.stanzaID ||
                    (message.originID != null &&
                        message.originID == candidate.originID),
              ) ??
          false;
      return existing;
    }
    if (message.originID != null) {
      final existing = await _dbOpReturning<XmppDatabase, Message?>(
        (db) => db.getMessageByOriginID(message.originID!),
      );
      if (existing != null) return true;
    }
    final existing = await _dbOpReturning<XmppDatabase, Message?>(
      (db) => db.getMessageByStanzaID(message.stanzaID),
    );
    return existing != null;
  }

  RegisteredStateKey _lastSeenKeyFor(String jid) => _lastSeenKeys.putIfAbsent(
        jid,
        () => XmppStateStore.registerKey('mam_last_seen_$jid'),
      );

  Future<void> _recordLastSeenTimestamp(
    String chatJid,
    DateTime? timestamp,
  ) async {
    if (timestamp == null) return;
    await _dbOp<XmppStateStore>(
      (ss) => ss.write(
        key: _lastSeenKeyFor(chatJid),
        value: timestamp.toIso8601String(),
      ),
      awaitDatabase: true,
    );
  }

  Future<DateTime?> loadLastSeenTimestamp(String chatJid) async {
    return await _dbOpReturning<XmppStateStore, DateTime?>(
      (ss) {
        final raw = ss.read(key: _lastSeenKeyFor(chatJid)) as String?;
        return raw == null ? null : DateTime.tryParse(raw);
      },
    );
  }

  Future<List<Message>> searchChatMessages({
    required String jid,
    required String query,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    SearchSortOrder sortOrder = SearchSortOrder.newestFirst,
    int limit = 200,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    return await _dbOpReturning<XmppDatabase, List<Message>>(
      (db) => db.searchChatMessages(
        jid: jid,
        query: trimmed,
        filter: filter,
        limit: limit,
        ascending: sortOrder == SearchSortOrder.oldestFirst,
      ),
    );
  }

  Stream<List<Draft>> draftsStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      createPaginatedStream<Draft, XmppDatabase>(
        watchFunction: (db) async => db.watchDrafts(start: start, end: end),
        getFunction: (db) => db.getDrafts(start: start, end: end),
      );

  final _log = Logger('MessageService');

  final _messageStream = StreamController<Message>.broadcast();
  final _messageStorageModeChanges =
      StreamController<MessageStorageMode>.broadcast();

  static const _stableKeyLimit = 500;
  static const _serverOnlyWindow = 200;
  static const _mamDiscoChatLimit = 500;

  final Map<String, Set<String>> _seenStableKeys = {};
  final Map<String, Queue<String>> _stableKeyOrder = {};
  final Map<String, _ServerOnlyConversation> _serverOnlyConversations = {};
  final Map<String, RegisteredStateKey> _lastSeenKeys = {};
  MessageStorageMode _messageStorageMode = MessageStorageMode.local;

  final Map<String, _PeerCapabilities> _capabilityCache = {};
  var _capabilityCacheLoaded = false;

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.MessageEvent>((event) async {
        if (await _handleError(event)) return;

        final reactionOnly = await _handleReactions(event);
        if (reactionOnly) return;

        var message = Message.fromMox(event);
        final isGroupChat = event.type == 'groupchat';
        final stableKey = _stableKeyForEvent(event);

        message = message.copyWith(
          timestamp: message.timestamp ?? DateTime.timestamp(),
        );

        if (await _isDuplicate(message, event, stableKey: stableKey)) {
          _log.fine(
            'Dropping duplicate message for ${message.chatJid} (${message.stanzaID})',
          );
          return;
        }

        if (stableKey != null) {
          _rememberStableKey(message.chatJid, stableKey);
        }

        await _handleChatState(event, message.chatJid);

        if (await _handleCorrection(event, message.senderJid)) return;
        if (await _handleRetraction(event, message.senderJid)) return;

        if (await _handleCalendarSync(event)) return;

        if (!event.displayable && event.encryptionError == null) return;
        if (event.encryptionError is omemo.InvalidKeyExchangeSignatureError) {
          return;
        }
        if (event.extensions.get<mox.FileUploadNotificationData>()
            case final data?) {
          if (data.metadata.name == null) return;
        }

        unawaited(_acknowledgeMessage(event));

        final metadata = _extractFileMetadata(event);

        if (metadata != null) {
          await _dbOp<XmppDatabase>(
            (db) => db.saveFileMetadata(metadata),
          );
          message = message.copyWith(fileMetadataID: metadata.id);
        }

        await _handleFile(event, message.senderJid);

        if (event.get<mox.OmemoData>() case final data?) {
          final newRatchets = data.newRatchets.values.map((e) => e.length);
          final newCount = newRatchets.fold(0, (v, e) => v + e);
          final replacedRatchets =
              data.replacedRatchets.values.map((e) => e.length);
          final replacedCount = replacedRatchets.fold(0, (v, e) => v + e);
          final pseudoMessageData = {
            'ratchetsAdded': newRatchets.toList(),
            'ratchetsReplaced': replacedRatchets.toList(),
          };

          if (newCount > 0) {
            await _dbOp<XmppDatabase>(
              (db) => db.saveMessage(
                Message(
                  stanzaID: _connection.generateId(),
                  senderJid: myJid!.toString(),
                  chatJid: message.chatJid,
                  pseudoMessageType: PseudoMessageType.newDevice,
                  pseudoMessageData: pseudoMessageData,
                ),
                chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
              ),
            );
          }

          if (replacedCount > 0) {
            await _dbOp<XmppDatabase>(
              (db) => db.saveMessage(
                Message(
                  stanzaID: _connection.generateId(),
                  senderJid: myJid!.toString(),
                  chatJid: message.chatJid,
                  pseudoMessageType: PseudoMessageType.changedDevice,
                  pseudoMessageData: pseudoMessageData,
                ),
                chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
              ),
            );
          }
        }

        if (isGroupChat) {
          handleMucIdentifiersFromMessage(event, message);
        }

        if (!message.noStore && _messageStorageMode.isLocal) {
          await _dbOp<XmppDatabase>(
            (db) => db.saveMessage(
              message,
              chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
            ),
          );
        } else if (_messageStorageMode.isServerOnly) {
          _addServerOnlyMessage(message.chatJid, message);
        }

        await _recordLastSeenTimestamp(message.chatJid, message.timestamp);

        _messageStream.add(message);
      })
      ..registerHandler<mox.ChatMarkerEvent>((event) async {
        _log.info('Received chat marker');

        await _dbOp<XmppDatabase>(
          (db) async {
            switch (event.type) {
              case mox.ChatMarker.displayed:
                db.markMessageDisplayed(event.id);
                db.markMessageReceived(event.id);
                db.markMessageAcked(event.id);
              case mox.ChatMarker.received:
                db.markMessageReceived(event.id);
                db.markMessageAcked(event.id);
              case mox.ChatMarker.acknowledged:
                db.markMessageAcked(event.id);
            }
          },
        );
      })
      ..registerHandler<mox.DeliveryReceiptReceivedEvent>((event) async {
        await _dbOp<XmppDatabase>(
          (db) => db.markMessageReceived(event.id),
        );
      });
  }

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      mox.MessageManager(),
      mox.CarbonsManager(),
      mox.MAMManager(),
      MamStreamManagementGuard(),
      mox.MessageDeliveryReceiptManager(),
      mox.ChatMarkerManager(),
      mox.MessageRepliesManager(),
      mox.ChatStateManager(),
      mox.DelayedDeliveryManager(),
      mox.MessageRetractionManager(),
      mox.LastMessageCorrectionManager(),
      mox.MessageReactionsManager(),
      mox.MessageProcessingHintManager(),
      mox.EmeManager(),
      MUCManager(),
      mox.OOBManager(),
      mox.HttpFileUploadManager(),
      mox.FileUploadNotificationManager(),
      // mox.StickersManager(),
      // mox.MUCManager(),
      // mox.SFSManager(),
    ]);

  mox.MessageEvent _buildOutgoingMessageEvent({
    required Message message,
    Message? quotedMessage,
    List<mox.StanzaHandlerExtension> extraExtensions = const [],
    ChatType chatType = ChatType.chat,
  }) {
    final quotedJid = quotedMessage == null
        ? null
        : mox.JID.fromString(quotedMessage.senderJid);
    final targetJid = mox.JID.fromString(message.chatJid);
    final isGroupChat = chatType == ChatType.groupChat;
    final isPrivateMucMessage = isGroupChat && targetJid.resource.isNotEmpty;
    final toJid =
        isGroupChat && !isPrivateMucMessage ? targetJid.toBare() : targetJid;
    final type = isGroupChat && !isPrivateMucMessage ? 'groupchat' : 'chat';

    return message.toMox(
      quotedBody: quotedMessage?.body,
      quotedJid: quotedJid,
      extraExtensions: extraExtensions,
      toJidOverride: toJid,
      type: type,
    );
  }

  Future<void> sendMessage({
    required String jid,
    required String text,
    EncryptionProtocol encryptionProtocol = EncryptionProtocol.omemo,
    Message? quotedMessage,
    bool? storeLocally,
    bool noStore = false,
    List<mox.StanzaHandlerExtension> extraExtensions = const [],
    ChatType chatType = ChatType.chat,
  }) async {
    final senderJid = myJid;
    if (senderJid == null) {
      _log.warning('Attempted to send a message before a JID was bound.');
      throw XmppMessageException();
    }
    final shouldStore = _messageStorageMode.isLocal && (storeLocally ?? true);
    final message = Message(
      stanzaID: _connection.generateId(),
      originID: _connection.generateId(),
      senderJid: senderJid,
      chatJid: jid,
      body: text,
      encryptionProtocol: encryptionProtocol,
      noStore: noStore,
      quoting: quotedMessage?.stanzaID,
      timestamp: DateTime.timestamp(),
    );
    _log.info(
      'Sending message ${message.stanzaID} (length=${text.length} chars)',
    );
    if (shouldStore) {
      await _dbOp<XmppDatabase>(
        (db) => db.saveMessage(
          message,
          chatType: chatType,
        ),
      );
    } else if (_messageStorageMode.isServerOnly) {
      final stableKey = message.originID != null
          ? 'oid:${message.originID}'
          : 'mid:${message.stanzaID}-${_myJid?.toBare() ?? senderJid}';
      _rememberStableKey(jid, stableKey);
      _addServerOnlyMessage(jid, message);
    }

    try {
      final stanza = _buildOutgoingMessageEvent(
        message: message,
        quotedMessage: quotedMessage,
        extraExtensions: extraExtensions,
        chatType: chatType,
      );
      final sent = await _connection.sendMessage(
        stanza,
      );
      if (!sent) {
        if (shouldStore) {
          await _handleMessageSendFailure(message.stanzaID);
        }
        throw XmppMessageException();
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to send message ${message.stanzaID}',
        error,
        stackTrace,
      );
      if (shouldStore) {
        await _handleMessageSendFailure(message.stanzaID);
      }
      throw XmppMessageException();
    }
    await _recordLastSeenTimestamp(message.chatJid, message.timestamp);
  }

  Future<void> sendAttachment({
    required String jid,
    required EmailAttachment attachment,
    EncryptionProtocol encryptionProtocol = EncryptionProtocol.omemo,
    Message? quotedMessage,
    ChatType chatType = ChatType.chat,
  }) async {
    final senderJid = myJid;
    if (senderJid == null) {
      _log.warning('Attempted to send an attachment before a JID was bound.');
      throw XmppMessageException();
    }
    final uploadManager = _connection.getManager<mox.HttpFileUploadManager>();
    if (uploadManager == null) {
      _log.warning('HTTP upload manager unavailable; ensure it is registered.');
      throw XmppMessageException();
    }
    if (!await uploadManager.isSupported()) {
      _log.warning('Server does not advertise HTTP file upload support.');
      throw XmppMessageException();
    }
    final file = File(attachment.path);
    if (!await file.exists()) {
      _log.warning('Attachment missing on disk: ${attachment.path}');
      throw XmppMessageException();
    }
    final size =
        attachment.sizeBytes > 0 ? attachment.sizeBytes : await file.length();
    final filename = attachment.fileName.isEmpty
        ? p.basename(file.path)
        : p.normalize(attachment.fileName);
    final contentType = attachment.mimeType?.isNotEmpty == true
        ? attachment.mimeType!
        : 'application/octet-stream';
    mox.HttpFileUploadSlot slot;
    try {
      final slotResult = await uploadManager.requestUploadSlot(
        filename,
        size,
        contentType: contentType,
      );
      if (slotResult.isType<mox.HttpFileUploadError>()) {
        final error = slotResult.get<mox.HttpFileUploadError>();
        if (error is mox.FileTooBigError) {
          throw XmppFileTooBigException(_maxUploadSize(error));
        }
        throw XmppMessageException();
      }
      slot = slotResult.get<mox.HttpFileUploadSlot>();
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to request upload slot for $filename',
        error,
        stackTrace,
      );
      throw XmppMessageException();
    }
    final getUrl = slot.getUrl.toString();
    final putUrl = slot.putUrl.toString();
    final metadata = FileMetadataData(
      id: attachment.metadataId ?? uuid.v4(),
      filename: filename,
      path: file.path,
      mimeType: contentType,
      sizeBytes: size,
      width: attachment.width,
      height: attachment.height,
      sourceUrls: [getUrl],
    );
    await _dbOp<XmppDatabase>((db) => db.saveFileMetadata(metadata));
    final body = attachment.caption?.trim().isNotEmpty == true
        ? attachment.caption!.trim()
        : _attachmentLabel(filename, size);
    final message = Message(
      stanzaID: _connection.generateId(),
      originID: _connection.generateId(),
      senderJid: senderJid,
      chatJid: jid,
      body: body,
      encryptionProtocol: encryptionProtocol,
      timestamp: DateTime.timestamp(),
      fileMetadataID: metadata.id,
      quoting: quotedMessage?.stanzaID,
    );
    final shouldStore = _messageStorageMode.isLocal;
    if (shouldStore) {
      await _dbOp<XmppDatabase>(
        (db) => db.saveMessage(
          message,
          chatType: chatType,
        ),
      );
    } else if (_messageStorageMode.isServerOnly) {
      final stableKey = message.originID != null
          ? 'oid:${message.originID}'
          : 'mid:${message.stanzaID}-${_myJid?.toBare() ?? senderJid}';
      _rememberStableKey(jid, stableKey);
      _addServerOnlyMessage(jid, message);
    }
    try {
      await _uploadFileToSlot(
        slot,
        file,
        sizeBytes: size,
        putUrl: putUrl,
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to upload attachment $filename',
        error,
        stackTrace,
      );
      if (shouldStore) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            stanzaID: message.stanzaID,
            error: MessageError.fileUploadFailure,
          ),
        );
      }
      throw XmppMessageException();
    }

    try {
      final extraExtensions = [
        const mox.MessageProcessingHintData(
          [mox.MessageProcessingHint.store],
        ),
        mox.OOBData(getUrl, filename),
      ];
      final stanza = _buildOutgoingMessageEvent(
        message: message,
        quotedMessage: quotedMessage,
        extraExtensions: extraExtensions,
        chatType: chatType,
      );
      final sent = await _connection.sendMessage(
        stanza,
      );
      if (!sent) {
        if (shouldStore) {
          await _dbOp<XmppDatabase>(
            (db) => db.saveMessageError(
              stanzaID: message.stanzaID,
              error: MessageError.fileUploadFailure,
            ),
          );
        }
        throw XmppMessageException();
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to send attachment message ${message.stanzaID}',
        error,
        stackTrace,
      );
      if (shouldStore) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            stanzaID: message.stanzaID,
            error: MessageError.fileUploadFailure,
          ),
        );
      }
      throw XmppMessageException();
    }
    await _recordLastSeenTimestamp(message.chatJid, message.timestamp);
  }

  Future<void> _uploadFileToSlot(
    mox.HttpFileUploadSlot slot,
    File file, {
    int? sizeBytes,
    required String putUrl,
  }) async {
    final client = http.Client();
    try {
      final request = http.StreamedRequest(
        'PUT',
        Uri.parse(putUrl),
      )..headers.addAll(slot.headers);
      request.contentLength = sizeBytes ?? await file.length();
      await file.openRead().pipe(request.sink);
      final response = await client.send(request);
      await response.stream.drain();
      final success = response.statusCode >= 200 && response.statusCode < 300;
      if (!success) {
        throw XmppMessageException();
      }
    } finally {
      client.close();
    }
  }

  String _attachmentLabel(String filename, int sizeBytes) {
    final prettySize = _formatBytes(sizeBytes);
    return '📎 $filename ($prettySize)';
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Unknown size';
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

  int? _maxUploadSize(mox.FileTooBigError error) {
    final dynamic dynamicError = error;
    try {
      return dynamicError.maxSize as int?;
    } catch (_) {
      try {
        return dynamicError.maxFileSize as int?;
      } catch (_) {
        try {
          return dynamicError.max as int?;
        } catch (_) {
          return null;
        }
      }
    }
  }

  Future<void> reactToMessage({
    required String stanzaID,
    required String emoji,
  }) async {
    if (emoji.isEmpty) return;
    final sender = myJid;
    final fromJid = _myJid;
    if (sender == null || fromJid == null) return;
    final message = await _dbOpReturning<XmppDatabase, Message?>(
      (db) => db.getMessageByStanzaID(stanzaID),
    );
    if (message == null) return;
    final existing = await _dbOpReturning<XmppDatabase, List<Reaction>>(
      (db) => db.getReactionsForMessageSender(
        messageId: message.stanzaID,
        senderJid: sender,
      ),
    );
    final emojis = existing.map((reaction) => reaction.emoji).toList();
    if (emojis.contains(emoji)) {
      emojis.remove(emoji);
    } else {
      emojis.add(emoji);
    }
    final reactionEvent = mox.MessageEvent(
      fromJid,
      mox.JID.fromString(message.chatJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageReactionsData(message.stanzaID, emojis),
      ]),
      id: _connection.generateId(),
    );
    try {
      final sent = await _connection.sendMessage(reactionEvent);
      if (!sent) {
        throw XmppMessageException();
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to send reaction for ${message.stanzaID}',
        error,
        stackTrace,
      );
      rethrow;
    }
    await _dbOp<XmppDatabase>(
      (db) => db.replaceReactions(
        messageId: message.stanzaID,
        senderJid: sender,
        emojis: emojis,
      ),
    );
  }

  Future<Message?> loadMessageByStanzaId(String stanzaID) async {
    return await _dbOpReturning<XmppDatabase, Message?>(
      (db) => db.getMessageByStanzaID(stanzaID),
    );
  }

  Future<void> resendMessage(
    String stanzaID, {
    ChatType? chatType,
  }) async {
    final message = await _dbOpReturning<XmppDatabase, Message?>(
      (db) => db.getMessageByStanzaID(stanzaID),
    );
    if (message == null || message.body?.isNotEmpty != true) {
      return;
    }
    final resolvedChatType = chatType ??
        await _dbOpReturning<XmppDatabase, ChatType?>(
          (db) async => (await db.getChat(message.chatJid))?.type,
        ) ??
        ChatType.chat;
    Message? quoted;
    if (message.quoting != null) {
      quoted = await _dbOpReturning<XmppDatabase, Message?>(
        (db) => db.getMessageByStanzaID(message.quoting!),
      );
    }
    await sendMessage(
      jid: message.chatJid,
      text: message.body!,
      encryptionProtocol: message.encryptionProtocol,
      quotedMessage: quoted,
      chatType: resolvedChatType,
    );
  }

  Future<bool> _canSendChatMarkers({required String to}) async {
    if (to == myJid) return false;
    final capabilities = await _capabilitiesFor(to);
    return capabilities.supportsMarkers;
  }

  Future<void> sendReadMarker(String to, String stanzaID) async {
    if (!await _canSendChatMarkers(to: to)) return;

    _connection.sendChatMarker(
      to: to,
      stanzaID: stanzaID,
      marker: mox.ChatMarker.received,
    );

    await _connection.sendChatMarker(
      to: to,
      stanzaID: stanzaID,
      marker: mox.ChatMarker.displayed,
    );

    await _dbOp<XmppDatabase>(
      (db) async {
        db.markMessageDisplayed(stanzaID);
        db.markMessageReceived(stanzaID);
        db.markMessageAcked(stanzaID);
      },
    );
  }

  Future<MamPageResult> fetchLatestFromArchive({
    required String jid,
    int pageSize = 50,
    bool isMuc = false,
  }) async =>
      _fetchMamPage(
        jid: jid,
        before: '',
        pageSize: pageSize,
        isMuc: isMuc,
      );

  Future<MamPageResult> fetchBeforeFromArchive({
    required String jid,
    required String before,
    int pageSize = 50,
    bool isMuc = false,
  }) async =>
      _fetchMamPage(
        jid: jid,
        before: before,
        pageSize: pageSize,
        isMuc: isMuc,
      );

  Future<MamPageResult> fetchSinceFromArchive({
    required String jid,
    required DateTime since,
    int pageSize = 50,
    bool isMuc = false,
  }) async =>
      _fetchMamPage(
        jid: jid,
        start: since,
        pageSize: pageSize,
        isMuc: isMuc,
      );

  Future<MamPageResult> _fetchMamPage({
    required String jid,
    String? before,
    DateTime? start,
    int pageSize = 50,
    bool isMuc = false,
  }) async {
    final mamManager = _connection.getManager<mox.MAMManager>();
    if (mamManager == null) {
      _log.warning('MAM manager unavailable; ensure it is registered.');
      throw XmppMessageException();
    }
    final peerJid = mox.JID.fromString(jid);
    final options = mox.MAMQueryOptions(
      withJid: isMuc ? null : peerJid,
      start: start,
      formType: mox.mamXmlns,
      forceForm: true,
    );
    final result = await mamManager.queryArchive(
      to: isMuc ? peerJid : null,
      options: options,
      rsm: mox.ResultSetManagement(
        before: before,
        max: pageSize,
      ),
    );
    final rsm = result?.rsm;
    return MamPageResult(
      complete: result?.complete ?? false,
      firstId: rsm?.first,
      lastId: rsm?.last,
      count: rsm?.count,
    );
  }

  Future<DraftSaveResult> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
    String? subject,
    List<EmailAttachment> attachments = const [],
  }) async {
    final previousMetadataIds = id == null
        ? const <String>[]
        : await _dbOpReturning<XmppDatabase, List<String>>(
            (db) async {
              final draft = await db.getDraft(id);
              return draft?.attachmentMetadataIds ?? const <String>[];
            },
          );
    final metadataIds = <String>[];
    for (final attachment in attachments) {
      final metadataId = await _persistDraftAttachmentMetadata(attachment);
      metadataIds.add(metadataId);
    }
    final savedId = await _dbOpReturning<XmppDatabase, int>(
      (db) => db.saveDraft(
        id: id,
        jids: jids,
        body: body,
        subject: subject,
        attachmentMetadataIds: metadataIds,
      ),
    );
    final staleMetadataIds = previousMetadataIds
        .where((existing) => !metadataIds.contains(existing))
        .toList();
    if (staleMetadataIds.isNotEmpty) {
      await _deleteAttachmentMetadata(staleMetadataIds);
    }
    return DraftSaveResult(
      draftId: savedId,
      attachmentMetadataIds: List.unmodifiable(metadataIds),
    );
  }

  Future<List<EmailAttachment>> loadDraftAttachments(
    Iterable<String> metadataIds,
  ) async {
    if (metadataIds.isEmpty) return const [];
    return await _dbOpReturning<XmppDatabase, List<EmailAttachment>>(
      (db) async {
        final attachments = <EmailAttachment>[];
        for (final metadataId in metadataIds) {
          final metadata = await db.getFileMetadata(metadataId);
          final path = metadata?.path;
          if (metadata == null || path == null || path.isEmpty) {
            continue;
          }
          final file = File(path);
          if (!await file.exists()) {
            continue;
          }
          final size = metadata.sizeBytes ?? await file.length();
          attachments.add(
            EmailAttachment(
              path: path,
              fileName: metadata.filename,
              sizeBytes: size,
              mimeType: metadata.mimeType,
              width: metadata.width,
              height: metadata.height,
              metadataId: metadata.id,
            ),
          );
        }
        return attachments;
      },
    );
  }

  Future<void> deleteDraft({required int id}) async {
    final metadataIds = await _dbOpReturning<XmppDatabase, List<String>>(
      (db) async {
        final draft = await db.getDraft(id);
        return draft?.attachmentMetadataIds ?? const <String>[];
      },
    );
    await _dbOp<XmppDatabase>(
      (db) => db.removeDraft(id),
    );
    if (metadataIds.isNotEmpty) {
      await _deleteAttachmentMetadata(metadataIds);
    }
  }

  Future<void> _handleMessageSendFailure(String stanzaID) async {
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessageError(
        error: MessageError.unknown,
        stanzaID: stanzaID,
      ),
    );
  }

  Future<String> _persistDraftAttachmentMetadata(
      EmailAttachment attachment) async {
    final metadata = FileMetadataData(
      id: attachment.metadataId ?? uuid.v4(),
      filename: attachment.fileName,
      path: attachment.path,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      width: attachment.width,
      height: attachment.height,
    );
    await _dbOp<XmppDatabase>((db) => db.saveFileMetadata(metadata));
    return metadata.id;
  }

  Future<void> _deleteAttachmentMetadata(
    Iterable<String> metadataIds,
  ) async {
    if (metadataIds.isEmpty) return;
    await _dbOp<XmppDatabase>(
      (db) async {
        for (final metadataId in metadataIds) {
          await db.deleteFileMetadata(metadataId);
        }
      },
    );
  }

  Future<void> _ensureCapabilityCacheLoaded() async {
    if (_capabilityCacheLoaded) return;
    await _dbOp<XmppStateStore>((ss) {
      final stored =
          (ss.read(key: _capabilityCacheKey) as Map<dynamic, dynamic>?) ?? {};
      _capabilityCache
        ..clear()
        ..addAll(stored.map(
          (key, value) => MapEntry(
            key as String,
            _PeerCapabilities.fromJson(value as Map<dynamic, dynamic>),
          ),
        ));
    }, awaitDatabase: true);
    _capabilityCacheLoaded = true;
  }

  Future<void> _persistCapabilityCache() async {
    if (!_capabilityCacheLoaded) return;
    await _dbOp<XmppStateStore>(
      (ss) => ss.write(
        key: _capabilityCacheKey,
        value: _capabilityCache.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      ),
      awaitDatabase: true,
    );
  }

  Future<_PeerCapabilities> _capabilitiesFor(String jid) async {
    await _ensureCapabilityCacheLoaded();
    if (_capabilityCache[jid] case final _PeerCapabilities cached) {
      return cached;
    }

    final result = await _connection.discoInfoQuery(jid);
    if (result == null || result.isType<mox.StanzaError>()) {
      const fallback = _PeerCapabilities.empty;
      _capabilityCache[jid] = fallback;
      await _persistCapabilityCache();
      await _dbOp<XmppDatabase>(
        (db) => db.markChatMarkerResponsive(
          jid: jid,
          responsive: fallback.supportsMarkers,
        ),
      );
      return fallback;
    }

    final info = result.get<mox.DiscoInfo>();
    final features = info.features;
    final capabilities = _PeerCapabilities(
      supportsMarkers: features.contains(mox.chatMarkersXmlns),
      supportsReceipts: features.contains(mox.deliveryXmlns),
    );

    _capabilityCache[jid] = capabilities;
    await _persistCapabilityCache();

    await _dbOp<XmppDatabase>(
      (db) => db.markChatMarkerResponsive(
        jid: jid,
        responsive: capabilities.supportsMarkers,
      ),
    );

    return capabilities;
  }

  Future<bool> _supportsMam(String jid) async {
    final result = await _connection.discoInfoQuery(jid);
    if (result == null || result.isType<mox.StanzaError>()) {
      return false;
    }
    final info = result.get<mox.DiscoInfo>();
    return info.features.contains(mox.mamXmlns);
  }

  Future<void> _verifyMamSupportOnLogin() async {
    if (connectionState != ConnectionState.connected) return;
    final accountJid = myJid;
    if (accountJid != null) {
      final supportsMam = await _supportsMam(accountJid);
      if (!supportsMam) {
        _log.warning(
          'Archive queries may be limited: server did not advertise MAM v2.',
        );
      }
    }

    List<Chat> chats;
    try {
      chats = await _dbOpReturning<XmppDatabase, List<Chat>>(
        (db) => db.getChats(start: 0, end: _mamDiscoChatLimit),
      );
    } on XmppAbortedException {
      return;
    }

    final mucChats =
        chats.where((chat) => chat.type == ChatType.groupChat).toList();
    if (mucChats.isEmpty) return;

    var missingMam = false;
    for (final chat in mucChats) {
      try {
        final hasMam = await _supportsMam(chat.jid);
        if (!hasMam) {
          missingMam = true;
        }
      } on Exception catch (error, stackTrace) {
        _log.fine('MAM disco for a group chat failed.', error, stackTrace);
      }
    }
    if (missingMam) {
      _log.warning(
        'Archive backfill may be incomplete: one or more group chats did not advertise MAM v2.',
      );
    }
  }

  Future<void> _acknowledgeMessage(mox.MessageEvent event) async {
    if (event.isCarbon) return;

    final markable =
        event.extensions.get<mox.MarkableData>()?.isMarkable ?? false;
    final deliveryReceiptRequested = event.extensions
            .get<mox.MessageDeliveryReceiptData>()
            ?.receiptRequested ??
        false;

    if (!markable && !deliveryReceiptRequested) return;

    final id = event.extensions.get<mox.StableIdData>()?.originId ?? event.id;
    if (id == null) return;

    final peer = event.from.toBare().toString();
    final capabilities = await _capabilitiesFor(peer);

    if (markable && capabilities.supportsMarkers) {
      await _connection.sendChatMarker(
        to: peer,
        stanzaID: id,
        marker: mox.ChatMarker.received,
      );

      await _dbOp<XmppDatabase>(
        (db) async {
          db.markMessageReceived(id);
          db.markMessageAcked(id);
        },
      );
    }

    if (deliveryReceiptRequested && capabilities.supportsReceipts) {
      await _connection.sendMessage(
        mox.MessageEvent(
          _myJid!,
          event.from.toBare(),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageDeliveryReceivedData(id),
          ]),
        ),
      );

      await _dbOp<XmppDatabase>(
        (db) async {
          db.markMessageReceived(id);
          db.markMessageAcked(id);
        },
      );
    }
  }

  @override
  Future<void> _reset() async {
    await super._reset();

    _resetServerOnlyConversations();
    _seenStableKeys.clear();
    _stableKeyOrder.clear();
    _lastSeenKeys.clear();
    _capabilityCache.clear();
    _capabilityCacheLoaded = false;
  }

  // Future<void> _handleMessage(mox.MessageEvent event) async {
  //   if (await _handleError(event)) throw EventHandlerAbortedException();
  //
  //   final get = event.extensions.get;
  //   final isCarbon = get<mox.CarbonsData>()?.isCarbon ?? false;
  //   final to = event.to.toBare().toString();
  //   final from = event.from.toBare().toString();
  //   final chatJid = isCarbon ? to : from;
  //
  //   await _handleChatState(event, chatJid);
  //
  //   if (await _handleCorrection(event, from)) {
  //     throw EventHandlerAbortedException();
  //   }
  //   if (await _handleRetraction(event, from)) {
  //     throw EventHandlerAbortedException();
  //   }
  //
  //   // TODO: Include InvalidKeyExchangeSignatureError for OMEMO.
  //   if (!event.displayable && event.encryptionError == null) {
  //     throw EventHandlerAbortedException();
  //   }
  //   if (get<mox.FileUploadNotificationData>() case final data?) {
  //     if (data.metadata.name == null) throw EventHandlerAbortedException();
  //   }
  //
  //   await _handleFile(event, from);
  //
  //   final metadata = _extractFileMetadata(event);
  //   if (metadata != null) {
  //     await _dbOp<XmppDatabase>((db) async {
  //       await db.saveFileMetadata(metadata);
  //     });
  //   }
  //
  //   final body = get<mox.ReplyData>()?.withoutFallback ??
  //       get<mox.MessageBodyData>()?.body ??
  //       '';
  //
  //   final message = Message(
  //     stanzaID: event.id ?? _connection.generateId(),
  //     senderJid: from,
  //     chatJid: chatJid,
  //     body: body,
  //     timestamp: get<mox.DelayedDeliveryData>()?.timestamp,
  //     fileMetadataID: metadata?.id,
  //     noStore: get<mox.MessageProcessingHintData>()
  //             ?.hints
  //             .contains(mox.MessageProcessingHint.noStore) ??
  //         false,
  //     quoting: get<mox.ReplyData>()?.id,
  //     originID: get<mox.StableIdData>()?.originId,
  //     occupantID: get<mox.OccupantIdData>()?.id,
  //     encryptionProtocol:
  //         event.encrypted ? EncryptionProtocol.omemo : EncryptionProtocol.none,
  //     acked: true,
  //     received: true,
  //   );
  //   await _dbOp<XmppDatabase>((db) async {
  //     await db.saveMessage(message);
  //   });
  // }

  Future<bool> _handleError(mox.MessageEvent event) async {
    if (event.type != 'error') return false;

    _log.info('Handling error message...');
    final stanzaId = event.id;
    if (stanzaId == null) return true;

    final stanzaError = event.error;
    final error = switch (stanzaError) {
      mox.ServiceUnavailableError _ => MessageError.serviceUnavailable,
      mox.RemoteServerNotFoundError _ => MessageError.serverNotFound,
      mox.RemoteServerTimeoutError _ => MessageError.serverTimeout,
      _ => MessageError.unknown,
    };

    await _dbOp<XmppDatabase>(
      (db) => db.saveMessageError(
        stanzaID: stanzaId,
        error: error,
      ),
    );
    return true;
  }

  Future<void> _handleChatState(mox.MessageEvent event, String jid) async {
    if (event.extensions.get<mox.ChatState>() case final state?) {
      await _dbOp<XmppDatabase>(
        (db) => db.updateChatState(chatJid: jid, state: state),
      );
    }
  }

  Future<bool> _handleCorrection(mox.MessageEvent event, String jid) async {
    final correction = event.extensions.get<mox.LastMessageCorrectionData>();
    if (correction == null) return false;

    return await _dbOpReturning<XmppDatabase, bool>(
      (db) async {
        if (await db.getMessageByOriginID(correction.id) case final message?) {
          if (!message.authorized(event.from) || !message.editable) {
            return false;
          }
          await db.saveMessageEdit(
            stanzaID: message.stanzaID,
            body: event.extensions.get<mox.MessageBodyData>()?.body,
          );
          return true;
        }
        return false;
      },
    );
  }

  Future<bool> _handleRetraction(mox.MessageEvent event, String jid) async {
    final retraction = event.extensions.get<mox.MessageRetractionData>();
    if (retraction == null) return false;

    return await _dbOpReturning<XmppDatabase, bool>(
      (db) async {
        if (await db.getMessageByOriginID(retraction.id) case final message?) {
          if (!message.authorized(event.from)) return false;
          await db.markMessageRetracted(message.stanzaID);
          return true;
        }
        return false;
      },
    );
  }

  Future<bool> _handleReactions(mox.MessageEvent event) async {
    final reactions = event.extensions.get<mox.MessageReactionsData>();
    if (reactions == null) return false;
    return await _dbOpReturning<XmppDatabase, bool>(
      (db) async {
        final message = await db.getMessageByStanzaID(reactions.messageId);
        if (message == null) {
          _log.fine(
            'Dropping reactions for unknown message ${reactions.messageId}',
          );
          return !event.displayable;
        }
        await db.replaceReactions(
          messageId: message.stanzaID,
          senderJid: event.from.toBare().toString(),
          emojis: reactions.emojis,
        );
        return !event.displayable;
      },
    );
  }

  Future<bool> _handleCalendarSync(mox.MessageEvent event) async {
    // Check if this is a calendar sync message by looking at the message body
    final messageText = event.text;
    if (messageText.isEmpty) return false;

    try {
      final messageData = jsonDecode(messageText);
      if (messageData is! Map<String, dynamic> ||
          !messageData.containsKey('calendar_sync')) {
        return false;
      }

      // SECURITY: Only accept calendar sync messages from our own JID
      final senderJid = event.from.toBare().toString();
      if (senderJid != myJid) {
        _log.warning(
            'Rejected calendar sync message from unauthorized JID: $senderJid');
        return true; // Handled - don't process as regular chat message
      }

      // This is a calendar sync message - parse and process it
      final syncData = messageData['calendar_sync'] as Map<String, dynamic>;
      final syncMessage = CalendarSyncMessage.fromJson(syncData);

      _log.info(
          'Received calendar sync message type: ${syncMessage.type} from ${event.from}');

      // Route to CalendarSyncManager for processing
      if (owner is XmppService &&
          (owner as XmppService)._calendarSyncCallback != null) {
        try {
          await (owner as XmppService)._calendarSyncCallback!(syncMessage);
          unawaited(_acknowledgeMessage(event));
        } catch (e) {
          _log.warning('Calendar sync callback failed: $e');
        }
      } else {
        _log.info('No calendar sync callback registered - message ignored');
      }

      return true; // Handled - don't process as regular chat message
    } catch (e) {
      // Not a valid calendar sync message, let it be processed normally
      return false;
    }
  }

  Future<void> _handleFile(mox.MessageEvent event, String jid) async {}

  Stream<List<Message>> _combineMessageAndReactionStreams({
    required Stream<List<Message>> messageStream,
    required Stream<List<Reaction>> reactionStream,
    required List<Message> initialMessages,
    required List<Reaction> initialReactions,
  }) {
    final controller = StreamController<List<Message>>.broadcast();
    StreamSubscription<List<Message>>? messageSubscription;
    StreamSubscription<List<Reaction>>? reactionSubscription;
    var listeners = 0;
    var closed = false;
    var currentMessages = initialMessages;
    var currentReactions = initialReactions;

    void emit() {
      if (!controller.hasListener) return;
      controller.add(
        _applyReactionPreviews(currentMessages, currentReactions),
      );
    }

    void start() {
      emit();
      messageSubscription = messageStream.listen((messages) {
        currentMessages = messages;
        emit();
      });
      reactionSubscription = reactionStream.listen((reactions) {
        currentReactions = reactions;
        emit();
      });
    }

    Future<void> stop() async {
      if (closed) return;
      closed = true;
      await messageSubscription?.cancel();
      await reactionSubscription?.cancel();
      await controller.close();
    }

    controller.onListen = () {
      listeners++;
      if (listeners == 1) {
        start();
      } else {
        emit();
      }
    };

    controller.onCancel = () async {
      listeners--;
      if (listeners <= 0) {
        await stop();
      }
    };

    return controller.stream;
  }

  List<Message> _applyReactionPreviews(
    List<Message> messages,
    List<Reaction> reactions,
  ) {
    if (messages.isEmpty) return messages;
    final allowedIds = <String>{};
    for (final message in messages) {
      allowedIds.add(message.stanzaID);
    }
    if (allowedIds.isEmpty || reactions.isEmpty) {
      return messages
          .map(
            (message) => message.reactionsPreview.isEmpty
                ? message
                : message.copyWith(reactionsPreview: const []),
          )
          .toList();
    }
    final grouped = <String, Map<String, _ReactionBucket>>{};
    final selfJid = myJid;
    for (final reaction in reactions) {
      if (!allowedIds.contains(reaction.messageID)) continue;
      final buckets = grouped.putIfAbsent(
        reaction.messageID,
        () => <String, _ReactionBucket>{},
      );
      final bucket = buckets.putIfAbsent(
        reaction.emoji,
        () => _ReactionBucket(reaction.emoji),
      );
      bucket.add(reaction.senderJid, selfJid);
    }
    return messages.map((message) {
      final id = message.stanzaID;
      final buckets = grouped[id];
      if (buckets == null || buckets.isEmpty) {
        return message.reactionsPreview.isEmpty
            ? message
            : message.copyWith(reactionsPreview: const []);
      }
      final previews =
          buckets.values.map((bucket) => bucket.toPreview()).toList()
            ..sort((a, b) {
              final countCompare = b.count.compareTo(a.count);
              if (countCompare != 0) return countCompare;
              return a.emoji.compareTo(b.emoji);
            });
      return message.copyWith(reactionsPreview: previews);
    }).toList();
  }

  FileMetadataData? _extractFileMetadata(mox.MessageEvent event) {
    final statelessData = event.extensions.get<mox.StatelessFileSharingData>();
    if (statelessData == null || statelessData.sources.isEmpty) {
      if (event.extensions.get<mox.OOBData>()?.url case final url?) {
        return FileMetadataData(
          id: uuid.v4(),
          sourceUrls: [url],
          filename: p.basename(url),
        );
      }
      return null;
    }
    final urls = statelessData.sources
        .whereType<mox.StatelessFileSharingUrlSource>()
        .map((e) => e.url)
        .toList();
    if (urls.isNotEmpty) {
      return FileMetadataData(
        id: uuid.v4(),
        sourceUrls: urls,
        filename:
            p.normalize(statelessData.metadata.name ?? p.basename(urls.first)),
        sizeBytes: statelessData.metadata.size,
        plainTextHashes: statelessData.metadata.hashes,
      );
    } else {
      final encryptedSource = statelessData.sources
          .whereType<mox.StatelessFileSharingEncryptedSource>()
          .first;
      return FileMetadataData(
        id: uuid.v4(),
        sourceUrls: [encryptedSource.source.url],
        filename: p.normalize(statelessData.metadata.name ??
            p.basename(encryptedSource.source.url)),
        encryptionKey: base64Encode(encryptedSource.key),
        encryptionIV: base64Encode(encryptedSource.iv),
        encryptionScheme: encryptedSource.encryption.toNamespace(),
        cipherTextHashes: encryptedSource.hashes,
        plainTextHashes: statelessData.metadata.hashes,
        sizeBytes: statelessData.metadata.size,
      );
    }
  }

// Future<bool> _downloadAllowed(String chatJid) async {
//   if (!(await Permission.storage.status).isGranted) return false;
//   if ((await _connection.getConnectionState()) !=
//       mox.XmppConnectionState.connected) return false;
//   var allowed = false;
//   await _dbOp<XmppDatabase>((db) async {
//     allowed = (await db.rosterAccessor.selectOne(chatJid) != null);
//   });
//   return allowed;
// }
}

class _ReactionBucket {
  _ReactionBucket(this.emoji);

  final String emoji;
  var count = 0;
  var reactedBySelf = false;

  void add(String senderJid, String? selfJid) {
    count += 1;
    if (!reactedBySelf && senderJid == selfJid) {
      reactedBySelf = true;
    }
  }

  ReactionPreview toPreview() => ReactionPreview(
        emoji: emoji,
        count: count,
        reactedBySelf: reactedBySelf,
      );
}
