part of 'package:axichat/src/xmpp/xmpp_service.dart';

final RegExp _crlfPattern = RegExp(r'[\r\n]');

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

final _capabilityCacheKey =
    XmppStateStore.registerKey('message_peer_capabilities');
const Duration _httpUploadSlotTimeout = Duration(seconds: 30);
const Duration _httpUploadPutTimeout = Duration(minutes: 2);

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

  static const supportsAll = _PeerCapabilities(
    supportsMarkers: true,
    supportsReceipts: true,
  );
}

mixin MessageService on XmppBase, BaseStreamService, MucService, ChatsService {
  Stream<List<Message>> messageStreamForChat(
    String jid, {
    int start = 0,
    int end = 50,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) {
    List<Message> filteredMessagesForChat(
      List<Message> messages,
    ) {
      final selfJid = myJid;
      if (selfJid == null || jid != selfJid) {
        return messages;
      }

      final filtered = messages.where((message) {
        final body = message.body;
        if (body == null || body.isEmpty) return true;
        return !CalendarSyncMessage.isCalendarSyncEnvelope(body);
      }).toList(growable: false);

      return List<Message>.unmodifiable(filtered);
    }

    return _localMessageStreamForChat(
      jid: jid,
      start: start,
      end: end,
      filter: filter,
    ).map(filteredMessagesForChat);
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

  Future<int> countLocalMessages({
    required String jid,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    bool includePseudoMessages = true,
  }) async {
    return _dbOpReturning<XmppDatabase, int>(
      (db) => db.countChatMessages(
        jid,
        filter: filter,
        includePseudoMessages: includePseudoMessages,
      ),
    );
  }

  MessageStorageMode get messageStorageMode => _messageStorageMode;

  void updateMessageStorageMode(MessageStorageMode mode) {
    if (_messageStorageMode == mode) return;
    _messageStorageMode = mode;
    if (mode.isServerOnly) {
      unawaited(purgeMessageHistory());
    }
  }

  Future<void> purgeMessageHistory({bool awaitDatabase = true}) async {
    _resetStableKeyCache();
    await _dbOp<XmppDatabase>(
      (db) => db.clearMessageHistory(),
      awaitDatabase: awaitDatabase,
    );
  }

  void _resetStableKeyCache() {
    _seenStableKeys.clear();
    _stableKeyOrder.clear();
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
    String? query,
    String? subject,
    bool excludeSubject = false,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    SearchSortOrder sortOrder = SearchSortOrder.newestFirst,
    int limit = 200,
  }) async {
    final trimmed = query?.trim() ?? '';
    final trimmedSubject = subject?.trim() ?? '';
    if (trimmed.isEmpty && trimmedSubject.isEmpty) return const [];
    return await _dbOpReturning<XmppDatabase, List<Message>>(
      (db) => db.searchChatMessages(
        jid: jid,
        query: trimmed,
        subject: trimmedSubject,
        excludeSubject: excludeSubject,
        filter: filter,
        limit: limit,
        ascending: sortOrder == SearchSortOrder.oldestFirst,
      ),
    );
  }

  Future<List<String>> subjectsForChat(String jid) async =>
      await _dbOpReturning<XmppDatabase, List<String>>(
        (db) => db.subjectsForChat(jid),
      );

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

  static const _stableKeyLimit = 500;
  static const _mamDiscoChatLimit = 500;

  final Map<String, Set<String>> _seenStableKeys = {};
  final Map<String, Queue<String>> _stableKeyOrder = {};
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

        if (!message.noStore) {
          await _dbOp<XmppDatabase>(
            (db) => db.saveMessage(
              message,
              chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
            ),
          );
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
      MessageSanitizerManager(),
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
    if (!_isFirstPartyJid(myJid: _myJid, jid: jid)) {
      _log.warning('Blocked XMPP send to foreign domain: $jid');
      throw XmppForeignDomainException();
    }
    final offlineDemo = demoOfflineMode;
    final storePreference = storeLocally ?? true;
    final shouldStore = storePreference && !noStore;
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
      acked: offlineDemo,
      received: offlineDemo,
      displayed: offlineDemo,
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
    }

    if (offlineDemo) {
      await _recordLastSeenTimestamp(message.chatJid, message.timestamp);
      return;
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
      if (shouldStore) {
        await _dbOp<XmppDatabase>(
          (db) => db.markMessageAcked(message.stanzaID),
        );
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
    if (!_isFirstPartyJid(myJid: _myJid, jid: jid)) {
      _log.warning('Blocked XMPP attachment send to foreign domain: $jid');
      throw XmppForeignDomainException();
    }
    final uploadManager = _connection.getManager<mox.HttpFileUploadManager>();
    if (uploadManager == null) {
      _log.warning('HTTP upload manager unavailable; ensure it is registered.');
      throw XmppMessageException();
    }
    final uploadSupport = httpUploadSupport;
    _log.fine(
      'HTTP upload support snapshot: supported=${uploadSupport.supported} '
      'entity=${uploadSupport.entityJid ?? 'unknown'} '
      'maxSize=${uploadSupport.maxFileSizeBytes ?? 'unspecified'}',
    );
    if (!await uploadManager.isSupported()) {
      _log.warning('Server does not advertise HTTP file upload support.');
      throw XmppUploadNotSupportedException();
    }
    final file = File(attachment.path);
    if (!await file.exists()) {
      _log.warning('Attachment missing on disk: ${attachment.path}');
      throw XmppMessageException();
    }
    final actualSize = await file.length();
    _log.fine(
      'Attachment size check: declared=${attachment.sizeBytes} '
      'actual=$actualSize path=${file.path}',
    );
    if (attachment.sizeBytes > 0 && attachment.sizeBytes != actualSize) {
      _log.fine(
        'Attachment size mismatch; declared=${attachment.sizeBytes} '
        'actual=$actualSize. Using actual size.',
      );
    }
    final size = actualSize;
    final filename = attachment.fileName.isEmpty
        ? p.basename(file.path)
        : p.normalize(attachment.fileName);
    final contentType = attachment.mimeType?.isNotEmpty == true
        ? attachment.mimeType!
        : 'application/octet-stream';
    final slot = await _requestHttpUploadSlot(
      filename: filename,
      sizeBytes: size,
      contentType: contentType,
    );
    final getUrl = slot.getUrl;
    final putUrl = slot.putUrl;
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
    const shouldStore = true;
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessage(
        message,
        chatType: chatType,
      ),
    );
    _log.fine(
      'Uploading attachment $filename ($size bytes) to HTTP upload slot.',
    );
    try {
      await _uploadFileToSlot(
        slot,
        file,
        sizeBytes: size,
        putUrl: putUrl,
        contentType: contentType,
      );
      _log.fine('Upload complete for attachment $filename');
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
      await _dbOp<XmppDatabase>(
        (db) => db.markMessageAcked(message.stanzaID),
      );
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

  Future<_UploadSlot> _requestHttpUploadSlot({
    required String filename,
    required int sizeBytes,
    required String contentType,
  }) async {
    final uploadTarget = httpUploadSupport.entityJid;
    final maxSize = httpUploadSupport.maxFileSizeBytes;
    if (maxSize != null && sizeBytes > maxSize) {
      throw XmppFileTooBigException(maxSize);
    }
    if (uploadTarget == null) {
      throw XmppUploadNotSupportedException();
    }
    try {
      _log.fine(
        'Requesting HTTP upload slot for $filename size=$sizeBytes '
        'contentType=$contentType target=$uploadTarget',
      );
      return await _requestUploadSlotViaStanza(
        uploadJid: uploadTarget,
        filename: filename,
        sizeBytes: sizeBytes,
        contentType: contentType,
      );
    } on XmppUploadUnavailableException {
      _log.severe('HTTP upload service unavailable; request failed.');
      rethrow;
    } on XmppUploadNotSupportedException {
      _log.warning('HTTP upload service not supported on this server.');
      rethrow;
    } on XmppUploadMisconfiguredException {
      _log.warning('HTTP upload service misconfigured or unavailable.');
      rethrow;
    } on XmppMessageException {
      rethrow;
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to request upload slot for $filename',
        error,
        stackTrace,
      );
      throw XmppMessageException();
    }
  }

  Future<_UploadSlot> _requestUploadSlotViaStanza({
    required String uploadJid,
    required String filename,
    required int sizeBytes,
    required String contentType,
  }) async {
    try {
      final response = await _connection
          .sendStanza(
            mox.StanzaDetails(
              mox.Stanza.iq(
                to: uploadJid,
                type: 'get',
                children: [
                  mox.XMLNode.xmlns(
                    tag: 'request',
                    xmlns: mox.httpFileUploadXmlns,
                    attributes: {
                      'filename': filename,
                      'size': sizeBytes.toString(),
                      'content-type': contentType,
                    },
                  ),
                ],
              ),
            ),
          )
          .timeout(_httpUploadSlotTimeout);
      if (response == null) {
        throw XmppUploadUnavailableException();
      }
      final type = response.attributes['type']?.toString();
      if (type != 'result') {
        final error = response.firstTag('error');
        final condition = error?.firstTagByXmlns(mox.fullStanzaXmlns)?.tag;
        if (condition == 'not-acceptable') {
          throw XmppFileTooBigException(httpUploadSupport.maxFileSizeBytes);
        }
        if (condition == 'service-unavailable') {
          throw XmppUploadMisconfiguredException();
        }
        throw XmppUploadUnavailableException();
      }
      final slot = response.firstTag('slot', xmlns: mox.httpFileUploadXmlns);
      final putUrl = slot?.firstTag('put')?.attributes['url']?.toString();
      final getUrl = slot?.firstTag('get')?.attributes['url']?.toString();
      if (putUrl == null || getUrl == null) {
        throw XmppUploadMisconfiguredException();
      }
      final headers = Map<String, String>.fromEntries(
        slot
                ?.findTags('header')
                .map(
                  (tag) => MapEntry(
                    tag.attributes['name']?.toString() ?? '',
                    tag.innerText(),
                  ),
                )
                .where((entry) => entry.key.isNotEmpty) ??
            const Iterable<MapEntry<String, String>>.empty(),
      )..removeWhere((key, value) => key.isEmpty);
      final sanitizedHeaders = _sanitizeSlotHeaders(headers);
      return _UploadSlot(
        getUrl: getUrl,
        putUrl: putUrl,
        headers: sanitizedHeaders,
      );
    } on TimeoutException {
      throw XmppUploadUnavailableException();
    }
  }

  Future<void> _uploadFileToSlot(
    _UploadSlot slot,
    File file, {
    int? sizeBytes,
    required String putUrl,
    required String contentType,
  }) async {
    final client = HttpClient()..connectionTimeout = _httpUploadPutTimeout;
    final uploadLength = sizeBytes ?? await file.length();
    final stopwatch = Stopwatch()..start();
    final uri = Uri.parse(putUrl);
    try {
      final request = await client.openUrl('PUT', uri);
      slot.headers.forEach(request.headers.set);
      final hasContentTypeHeader = slot.headers.keys.any(
        (key) => key.toLowerCase() == HttpHeaders.contentTypeHeader,
      );
      if (!hasContentTypeHeader) {
        request.headers.contentType = ContentType.parse(contentType);
      }
      request.headers.contentLength = uploadLength;
      _log.finer(
        'HTTP upload PUT ${uri.path} len=$uploadLength headers=${request.headers}',
      );
      await file.openRead().timeout(_httpUploadPutTimeout).forEach(request.add);
      _log.finer(
        'HTTP upload PUT stream sent in ${stopwatch.elapsedMilliseconds}ms '
        'len=$uploadLength path=${uri.path}',
      );
      final response = await request.close().timeout(_httpUploadPutTimeout);
      final statusCode = response.statusCode;
      _log.finer(
        'HTTP upload PUT received status $statusCode '
        'after ${stopwatch.elapsedMilliseconds}ms path=${uri.path}',
      );
      final bodyBytes = await response
          .timeout(_httpUploadPutTimeout)
          .fold<List<int>>(<int>[], (buffer, data) {
        buffer.addAll(data);
        return buffer;
      });
      final success = statusCode >= 200 && statusCode < 300;
      if (!success) {
        _log.warning(
          'HTTP upload failed with status $statusCode '
          'for ${uri.path} body=${utf8.decode(bodyBytes, allowMalformed: true)}',
        );
        throw XmppMessageException();
      }
      _log.finer(
        'HTTP upload PUT completed with $statusCode '
        'in ${stopwatch.elapsedMilliseconds}ms '
        'path=${uri.path} bodyLen=${bodyBytes.length}',
      );
    } on TimeoutException {
      _log.warning(
        'HTTP upload timed out after ${_httpUploadPutTimeout.inSeconds}s '
        'for ${uri.path}',
      );
      throw XmppUploadUnavailableException();
    } catch (error, stackTrace) {
      _log.warning(
        'HTTP upload failed for ${uri.path}',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      client.close();
      stopwatch.stop();
    }
  }

  Map<String, String> _sanitizeSlotHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    headers.forEach((name, value) {
      final cleanedName = name.replaceAll(_crlfPattern, '').trim();
      final cleanedValue = value.replaceAll(_crlfPattern, '').trim();
      if (cleanedName.isEmpty || cleanedValue.isEmpty) return;
      sanitized[cleanedName] = cleanedValue;
    });
    return sanitized;
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

  // ignore: unused_element
  Future<void> _logHttpUploadServiceError({
    required String filename,
    required int sizeBytes,
    required String contentType,
  }) async {
    final target = httpUploadSupport.entityJid;
    if (target == null) {
      _log.warning('Cannot log HTTP upload IQ error: no upload entity known.');
      return;
    }
    try {
      final response = await _connection.sendStanza(
        mox.StanzaDetails(
          mox.Stanza.iq(
            to: target,
            type: 'get',
            children: [
              mox.XMLNode.xmlns(
                tag: 'request',
                xmlns: mox.httpFileUploadXmlns,
                attributes: {
                  'filename': filename,
                  'size': sizeBytes.toString(),
                  'content-type': contentType,
                },
              ),
            ],
          ),
        ),
      );
      if (response == null || response.attributes['type'] != 'error') {
        return;
      }
      final error = response.firstTag('error');
      final stanzaCondition =
          error?.firstTagByXmlns(mox.fullStanzaXmlns)?.tag ?? 'unknown';
      final text = error?.firstTag('text')?.innerText() ?? '';
      final from = response.attributes['from']?.toString();
      _log.warning(
        'HTTP upload slot request error from=${from ?? 'unknown'} '
        'condition=$stanzaCondition text=${text.isEmpty ? 'none' : text}',
      );
    } catch (error, stackTrace) {
      _log.fine(
        'Failed to log HTTP upload IQ error.',
        error,
        stackTrace,
      );
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
    if (_isMucChatJid(to)) return false;
    if (to == myJid) return false;
    final capabilities = await _capabilitiesFor(to);
    return capabilities.supportsMarkers;
  }

  Future<void> sendReadMarker(String to, String stanzaID) async {
    if (!await _canSendChatMarkers(to: to)) return;
    final messageType = _chatStateMessageType(to);
    _connection.sendChatMarker(
      to: to,
      stanzaID: stanzaID,
      marker: mox.ChatMarker.received,
      messageType: messageType,
    );

    await _connection.sendChatMarker(
      to: to,
      stanzaID: stanzaID,
      marker: mox.ChatMarker.displayed,
      messageType: messageType,
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
    String? after,
  }) async =>
      _fetchMamPage(
        jid: jid,
        start: since,
        pageSize: pageSize,
        isMuc: isMuc,
        after: after,
      );

  Future<MamPageResult> _fetchMamPage({
    required String jid,
    String? before,
    String? after,
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
        after: after,
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
    final isMuc = event.type == 'groupchat';
    final target = isMuc ? event.from.toString() : peer;
    final messageType = _chatStateMessageType(target);
    final capabilities =
        isMuc ? _PeerCapabilities.supportsAll : await _capabilitiesFor(peer);

    if (markable && capabilities.supportsMarkers) {
      await _connection.sendChatMarker(
        to: target,
        stanzaID: id,
        marker: mox.ChatMarker.received,
        messageType: messageType,
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
          mox.JID.fromString(target),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageDeliveryReceivedData(id),
          ]),
          type: messageType,
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

    _resetStableKeyCache();
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
      _trackTypingParticipant(
        chatJid: jid,
        senderJid: event.from.toString(),
        state: state,
      );
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

    final senderJid = event.from.toBare().toString();
    final selfJid = myJid;

    final syncMessage = CalendarSyncMessage.tryParseEnvelope(messageText);
    if (syncMessage == null) {
      if (selfJid != null &&
          senderJid == selfJid &&
          messageText.contains('"calendar_sync"')) {
        _log.info('Dropped malformed calendar sync envelope from self');
        return true;
      }
      return false;
    }

    if (selfJid != null && senderJid != selfJid) {
      _log.warning('Rejected calendar sync message from unauthorized sender');
      return true; // Handled - don't process as regular chat message
    }

    _log.info('Received calendar sync message type: ${syncMessage.type}');

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

class _UploadSlot {
  _UploadSlot({
    required this.getUrl,
    required this.putUrl,
    Map<String, String>? headers,
  }) : headers = headers ?? const {};

  // ignore: unused_element
  factory _UploadSlot.fromMox(mox.HttpFileUploadSlot slot) {
    return _UploadSlot(
      getUrl: slot.getUrl.toString(),
      putUrl: slot.putUrl.toString(),
      headers: Map<String, String>.from(slot.headers),
    );
  }

  final String getUrl;
  final String putUrl;
  final Map<String, String> headers;
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
