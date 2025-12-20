part of 'package:axichat/src/xmpp/xmpp_service.dart';

final RegExp _crlfPattern = RegExp(r'[\r\n]');

const String _messageStatusSyncEnvelopeKey = 'message_status_sync';
const int _messageStatusSyncEnvelopeVersion = 1;
const String _messageStatusSyncEnvelopeIdKey = 'id';
const String _messageStatusSyncEnvelopeVersionKey = 'v';
const String _messageStatusSyncEnvelopeAckedKey = 'acked';
const String _messageStatusSyncEnvelopeReceivedKey = 'received';
const String _messageStatusSyncEnvelopeDisplayedKey = 'displayed';

final class _MessageStatusSyncEnvelope {
  const _MessageStatusSyncEnvelope({
    required this.id,
    required this.acked,
    required this.received,
    required this.displayed,
  });

  final String id;
  final bool acked;
  final bool received;
  final bool displayed;

  Map<String, dynamic> toJson() => {
        _messageStatusSyncEnvelopeVersionKey: _messageStatusSyncEnvelopeVersion,
        _messageStatusSyncEnvelopeIdKey: id,
        _messageStatusSyncEnvelopeAckedKey: acked,
        _messageStatusSyncEnvelopeReceivedKey: received,
        _messageStatusSyncEnvelopeDisplayedKey: displayed,
      };

  static _MessageStatusSyncEnvelope? tryParseEnvelope(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final payload = decoded[_messageStatusSyncEnvelopeKey];
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final version = payload[_messageStatusSyncEnvelopeVersionKey] as int?;
      if (version != _messageStatusSyncEnvelopeVersion) {
        return null;
      }
      final id = payload[_messageStatusSyncEnvelopeIdKey] as String?;
      if (id == null || id.isEmpty) {
        return null;
      }
      final acked =
          payload[_messageStatusSyncEnvelopeAckedKey] as bool? ?? false;
      final received =
          payload[_messageStatusSyncEnvelopeReceivedKey] as bool? ?? false;
      final displayed =
          payload[_messageStatusSyncEnvelopeDisplayedKey] as bool? ?? false;
      final normalizedDisplayed = displayed;
      final normalizedReceived = normalizedDisplayed || received;
      final normalizedAcked = normalizedReceived || acked;
      return _MessageStatusSyncEnvelope(
        id: id,
        acked: normalizedAcked,
        received: normalizedReceived,
        displayed: normalizedDisplayed,
      );
    } catch (_) {
      return null;
    }
  }

  static bool isEnvelope(String raw) => tryParseEnvelope(raw) != null;
}

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
const Duration _httpAttachmentGetTimeout = Duration(minutes: 2);
const int _xmppAttachmentDownloadLimitFallbackBytes = 50 * 1024 * 1024;
const int _xmppAttachmentDownloadMaxRedirects = 5;
const int _aesGcmTagLengthBytes = 16;
const int _attachmentMaxFilenameLength = 120;
const int serverOnlyChatMessageCap = 500;
const int mamLoginBackfillMessageLimit = 50;
const Set<String> _safeHttpUploadLogHeaders = {
  HttpHeaders.contentLengthHeader,
  HttpHeaders.contentTypeHeader,
};
const Set<String> _allowedHttpUploadPutHeaders = {
  'authorization',
  'cookie',
  'expires',
};

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
  ImpatientCompleter<XmppDatabase> get _database;
  set _database(ImpatientCompleter<XmppDatabase> value);
  String? get _databasePrefix;
  String? get _databasePassphrase;
  Future<XmppDatabase> _buildDatabase(String prefix, String passphrase);
  void _notifyDatabaseReloaded();

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
        return !CalendarSyncMessage.isCalendarSyncEnvelope(body) &&
            !_MessageStatusSyncEnvelope.isEnvelope(body);
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

  Future<void> _storeMessage(
    Message message, {
    required ChatType chatType,
  }) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.saveMessage(
        message,
        chatType: chatType,
      );
      if (messageStorageMode.isServerOnly) {
        await db.trimChatMessages(
          jid: message.chatJid,
          maxMessages: serverOnlyChatMessageCap,
        );
      }
    });
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

  MessageStorageMode get messageStorageMode =>
      _messageStorageMode.isServerOnly && !_mamSupported
          ? MessageStorageMode.local
          : _messageStorageMode;

  void updateMessageStorageMode(MessageStorageMode mode) {
    final previous = messageStorageMode;
    _messageStorageMode = mode;
    final next = messageStorageMode;
    if (mode.isServerOnly && !_mamSupported) {
      _log.warning(
        'Server-only storage requires MAM; using local persistence instead.',
      );
    }
    if (previous == next) return;
    unawaited(
      _applyMessageStorageModeChange(
        previous: previous,
        next: next,
      ),
    );
  }

  Future<void> _applyMessageStorageModeChange({
    required MessageStorageMode previous,
    required MessageStorageMode next,
  }) async {
    _log.info('Message storage mode change: $previous -> $next');
    if (next.isServerOnly) {
      await purgeMessageHistory();
    }
    await _reopenDatabaseForStorageMode(
      previous: previous,
      next: next,
    );
  }

  Future<void> _reopenDatabaseForStorageMode({
    required MessageStorageMode previous,
    required MessageStorageMode next,
  }) async {
    if (!_database.isCompleted) return;
    final currentDb = _database.value;
    final wantsInMemory = next.isServerOnly && _mamSupported;
    final isCurrentInMemory =
        currentDb is XmppDrift ? currentDb.isInMemory : false;
    if (wantsInMemory == isCurrentInMemory) return;
    _log.info(
      'Reopening database for storage mode change '
      '($previous -> $next); inMemoryTarget=$wantsInMemory',
    );
    final prefix = _databasePrefix;
    final passphrase = _databasePassphrase;
    if (prefix == null || passphrase == null) {
      _log.warning(
        'Unable to reopen database for storage mode change; missing prefix or passphrase.',
      );
      return;
    }
    try {
      await currentDb?.close();
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to close existing database during storage mode change.',
        error,
        stackTrace,
      );
    }
    _database = ImpatientCompleter(Completer<XmppDatabase>());
    _database.complete(await _buildDatabase(prefix, passphrase));
    _notifyDatabaseReloaded();
  }

  void _updateMamSupport(bool supported) {
    if (_mamSupported == supported) return;
    final previousEffective = messageStorageMode;
    _mamSupported = supported;
    if (!_mamSupportController.isClosed) {
      _mamSupportController.add(supported);
    }
    final nextEffective = messageStorageMode;
    if (previousEffective != nextEffective) {
      unawaited(
        _applyMessageStorageModeChange(
          previous: previousEffective,
          next: nextEffective,
        ),
      );
    }
  }

  @visibleForTesting
  void setMamSupportOverride(bool? supported) {
    _mamSupportOverride = supported;
    if (supported != null) {
      _updateMamSupport(supported);
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

  Future<void> _hydrateDuplicatePayload({
    required Message incoming,
    FileMetadataData? metadata,
    String? body,
  }) async {
    final hasText = body?.trim().isNotEmpty == true;
    await _dbOp<XmppDatabase>((db) async {
      Message? existing;
      if (incoming.originID?.isNotEmpty == true) {
        existing = await db.getMessageByOriginID(incoming.originID!);
      }
      existing ??= await db.getMessageByStanzaID(incoming.stanzaID);
      if (existing == null) return;

      final shouldUpdateDisplayed = incoming.displayed && !existing.displayed;
      final shouldUpdateReceived =
          (incoming.received || shouldUpdateDisplayed) && !existing.received;
      final shouldUpdateAcked =
          (incoming.acked || shouldUpdateReceived) && !existing.acked;

      final needsMetadata = metadata != null &&
          (existing.fileMetadataID == null || existing.fileMetadataID!.isEmpty);
      final needsBody =
          hasText && (existing.body == null || existing.body!.isEmpty);
      if (!needsMetadata &&
          !needsBody &&
          !shouldUpdateAcked &&
          !shouldUpdateReceived &&
          !shouldUpdateDisplayed) {
        return;
      }

      await db.updateMessageAttachment(
        stanzaID: existing.stanzaID,
        metadata: needsMetadata ? metadata : null,
        body: needsBody ? body : null,
      );

      if (shouldUpdateDisplayed) {
        await db.markMessageDisplayed(incoming.originID ?? incoming.stanzaID);
      }
      if (shouldUpdateReceived) {
        await db.markMessageReceived(incoming.originID ?? incoming.stanzaID);
      }
      if (shouldUpdateAcked) {
        await db.markMessageAcked(incoming.originID ?? incoming.stanzaID);
      }
    });
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
    final key = _lastSeenKeyFor(chatJid);
    await _dbOp<XmppStateStore>(
      (ss) async {
        final raw = ss.read(key: key) as String?;
        final existing = raw == null ? null : DateTime.tryParse(raw);
        if (existing != null && !timestamp.isAfter(existing)) {
          return;
        }
        await ss.write(
          key: key,
          value: timestamp.toIso8601String(),
        );
      },
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
  static const Duration _conversationIndexMutedForeverDuration =
      Duration(days: 3650);
  bool _mamLoginSyncInFlight = false;

  final Map<String, Set<String>> _seenStableKeys = {};
  final Map<String, Queue<String>> _stableKeyOrder = {};
  final Map<String, RegisteredStateKey> _lastSeenKeys = {};
  MessageStorageMode _messageStorageMode = MessageStorageMode.local;
  bool _mamSupported = false;
  bool? _mamSupportOverride;
  final StreamController<bool> _mamSupportController =
      StreamController<bool>.broadcast();

  final Map<String, _PeerCapabilities> _capabilityCache = {};
  var _capabilityCacheLoaded = false;
  final Map<String, Future<String?>> _inboundAttachmentDownloads = {};
  Directory? _attachmentDirectory;

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.MessageEvent>((event) async {
        if (await _handleError(event)) return;

        final reactionOnly = await _handleReactions(event);
        if (reactionOnly) return;

        final metadata = _extractFileMetadata(event);
        final hasAttachmentMetadata = metadata != null;

        var message = Message.fromMox(event, accountJid: myJid);
        final isGroupChat = event.type == 'groupchat';
        final stableKey = _stableKeyForEvent(event);

        message = message.copyWith(
          timestamp: message.timestamp ?? DateTime.timestamp(),
        );
        final accountJid = myJid;
        if (accountJid != null &&
            !isGroupChat &&
            message.senderJid.toLowerCase() == accountJid.toLowerCase() &&
            (event.isCarbon || event.isFromMAM)) {
          message = message.copyWith(acked: true);
        }
        if (metadata != null) {
          message = message.copyWith(fileMetadataID: metadata.id);
        }
        if (metadata != null && (message.body?.trim().isEmpty ?? true)) {
          const fallbackFilename = 'Attachment';
          final filename = metadata.filename.trim();
          final labelFilename =
              filename.isNotEmpty ? filename : fallbackFilename;
          final sizeBytes = metadata.sizeBytes ?? 0;
          message = message.copyWith(
            body: _attachmentLabel(labelFilename, sizeBytes),
          );
        }

        if (await _isDuplicate(message, event, stableKey: stableKey)) {
          _log.fine(
            'Dropping duplicate message for ${message.chatJid} (${message.stanzaID})',
          );
          await _hydrateDuplicatePayload(
            incoming: message,
            metadata: metadata,
            body: message.body,
          );
          return;
        }

        if (stableKey != null) {
          _rememberStableKey(message.chatJid, stableKey);
        }

        await _handleChatState(event, message.chatJid);

        if (await _handleCorrection(event, message.senderJid)) return;
        if (await _handleRetraction(event, message.senderJid)) return;

        if (await _handleMessageStatusSync(event)) return;
        if (await _handleCalendarSync(event)) return;

        if (!event.displayable &&
            event.encryptionError == null &&
            !hasAttachmentMetadata) {
          return;
        }
        if (event.encryptionError is omemo.InvalidKeyExchangeSignatureError) {
          return;
        }

        unawaited(_acknowledgeMessage(event));

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
            await _storeMessage(
              Message(
                stanzaID: _connection.generateId(),
                senderJid: myJid!.toString(),
                chatJid: message.chatJid,
                pseudoMessageType: PseudoMessageType.newDevice,
                pseudoMessageData: pseudoMessageData,
              ),
              chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
            );
          }

          if (replacedCount > 0) {
            await _storeMessage(
              Message(
                stanzaID: _connection.generateId(),
                senderJid: myJid!.toString(),
                chatJid: message.chatJid,
                pseudoMessageType: PseudoMessageType.changedDevice,
                pseudoMessageData: pseudoMessageData,
              ),
              chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
            );
          }
        }

        if (isGroupChat) {
          handleMucIdentifiersFromMessage(event, message);
        }

        if (!message.noStore) {
          await _storeMessage(
            message,
            chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
          );
        }
        if (metadata != null && !isGroupChat) {
          unawaited(
            _autoDownloadTrustedInboundAttachment(
              message: message,
              metadataId: metadata.id,
            ),
          );
        }

        await _recordLastSeenTimestamp(message.chatJid, message.timestamp);
        final isDirectChat = !isGroupChat &&
            message.chatJid.isNotEmpty &&
            !_isMucChatJid(message.chatJid);
        final isPeerChat = isDirectChat && message.chatJid != myJid;
        if (isPeerChat && this is AvatarService) {
          unawaited(
            (this as AvatarService).prefetchAvatarForJid(message.chatJid),
          );
        }
        if (isDirectChat) {
          unawaited(
            _upsertConversationIndexForPeer(
              peerJid: message.chatJid,
              lastTimestamp: message.timestamp ?? DateTime.timestamp(),
              lastId: message.originID ?? message.stanzaID,
            ),
          );
        }

        _messageStream.add(message);
      })
      ..registerHandler<mox.ChatMarkerEvent>((event) async {
        _log.info('Received chat marker');

        final isDisplayed = event.type == mox.ChatMarker.displayed;
        final isReceived = isDisplayed || event.type == mox.ChatMarker.received;
        const bool isAcked = true;
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

        await _broadcastMessageStatusSync(
          id: event.id,
          acked: isAcked,
          received: isReceived,
          displayed: isDisplayed,
        );
      })
      ..registerHandler<mox.DeliveryReceiptReceivedEvent>((event) async {
        await _dbOp<XmppDatabase>(
          (db) async {
            db.markMessageReceived(event.id);
            db.markMessageAcked(event.id);
          },
        );

        await _broadcastMessageStatusSync(
          id: event.id,
          acked: true,
          received: true,
          displayed: false,
        );
      });
  }

  Future<void> syncMessageArchiveOnLogin() async {
    if (_mamLoginSyncInFlight) return;
    if (connectionState != ConnectionState.connected) return;
    _mamLoginSyncInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) return;
      await _resolveMamSupportForAccount();
      if (!_mamSupported) return;

      final chats = await _loadChatsForMamSync();

      for (final chat in chats) {
        if (connectionState != ConnectionState.connected) return;
        if (chat.defaultTransport.isEmail) continue;

        final chatJid = chat.remoteJid;
        if (chatJid.isEmpty) continue;
        if (!chatJid.contains('@')) continue;
        try {
          final localCount = await countLocalMessages(
            jid: chatJid,
            includePseudoMessages: false,
          );
          final lastSeen = await loadLastSeenTimestamp(chatJid);
          final shouldBackfillLatest = messageStorageMode.isServerOnly ||
              localCount == 0 ||
              lastSeen == null;

          if (shouldBackfillLatest) {
            await fetchLatestFromArchive(
              jid: chatJid,
              pageSize: mamLoginBackfillMessageLimit,
              isMuc: chat.type == ChatType.groupChat,
            );
            continue;
          }

          await _catchUpChatFromArchive(
            jid: chatJid,
            since: lastSeen,
            isMuc: chat.type == ChatType.groupChat,
          );
        } on XmppAbortedException {
          return;
        } on Exception catch (error, stackTrace) {
          _log.fine(
            'Failed to sync one or more chat archives during login.',
            error,
            stackTrace,
          );
        }
      }
    } on XmppAbortedException {
      return;
    } finally {
      _mamLoginSyncInFlight = false;
    }
  }

  Future<List<Chat>> _loadChatsForMamSync() async {
    final chats = <Chat>[];
    var start = 0;
    while (true) {
      final page = await _dbOpReturning<XmppDatabase, List<Chat>>(
        (db) => db.getChats(
          start: start,
          end: start + _mamDiscoChatLimit,
        ),
      );
      if (page.isEmpty) break;
      chats.addAll(page);
      if (page.length < _mamDiscoChatLimit) break;
      start += page.length;
    }
    return List<Chat>.unmodifiable(chats);
  }

  Future<void> _catchUpChatFromArchive({
    required String jid,
    required DateTime? since,
    required bool isMuc,
  }) async {
    if (since == null) return;
    String? afterId;
    while (true) {
      final result = await fetchSinceFromArchive(
        jid: jid,
        since: since,
        pageSize: mamLoginBackfillMessageLimit,
        isMuc: isMuc,
        after: afterId,
      );
      final nextAfterId = result.lastId ?? afterId;
      if (result.complete || nextAfterId == null || nextAfterId == afterId) {
        break;
      }
      afterId = nextAfterId;
    }
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
      mox.SFSManager(),
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
    final accountJid = myJid;
    if (accountJid == null) {
      _log.warning('Attempted to send a message before a JID was bound.');
      throw XmppMessageException();
    }
    if (!_isFirstPartyJid(myJid: _myJid, jid: jid)) {
      _log.warning('Blocked XMPP send to foreign domain: $jid');
      throw XmppForeignDomainException();
    }
    if (chatType == ChatType.chat && !_isMucChatJid(jid) && jid != accountJid) {
      if (this is AvatarService) {
        unawaited(
          (this as AvatarService).prefetchAvatarForJid(jid),
        );
      }
    }
    final senderJid = chatType == ChatType.groupChat
        ? (roomStateFor(jid)?.myOccupantId ?? accountJid)
        : accountJid;
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
      await _storeMessage(message, chatType: chatType);
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
      if (chatType == ChatType.chat && !_isMucChatJid(jid)) {
        unawaited(
          _upsertConversationIndexForPeer(
            peerJid: jid,
            lastTimestamp: message.timestamp ?? DateTime.timestamp(),
            lastId: message.originID ?? message.stanzaID,
          ),
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

  Future<void> _upsertConversationIndexForPeer({
    required String peerJid,
    required DateTime lastTimestamp,
    required String? lastId,
  }) async {
    if (connectionState != ConnectionState.connected) return;
    final normalizedPeer = peerJid.trim();
    if (normalizedPeer.isEmpty) return;
    if (_isMucChatJid(normalizedPeer)) return;

    final manager = _connection.getManager<ConversationIndexManager>();
    if (manager == null) return;

    late final mox.JID peerBare;
    try {
      peerBare = mox.JID.fromString(normalizedPeer).toBare();
    } on Exception {
      return;
    }

    final chat = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(peerBare.toString()),
    );
    if (chat != null && !chat.transport.isXmpp) return;

    final cached = manager.cachedForPeer(peerBare);
    final cachedTimestamp = cached?.lastTimestamp;
    final lastTimestampUtc = lastTimestamp.toUtc();
    final nextTimestamp =
        cachedTimestamp != null && cachedTimestamp.isAfter(lastTimestampUtc)
            ? cachedTimestamp
            : lastTimestampUtc;

    final mutedUntil = (chat?.muted ?? false)
        ? DateTime.timestamp()
            .add(_conversationIndexMutedForeverDuration)
            .toUtc()
        : null;

    final trimmedLastId = lastId?.trim();
    await manager.upsert(
      ConvItem(
        peerBare: peerBare,
        lastTimestamp: nextTimestamp,
        lastId: trimmedLastId?.isNotEmpty == true ? trimmedLastId : null,
        pinned: chat?.favorited ?? false,
        archived: chat?.archived ?? false,
        mutedUntil: mutedUntil,
      ),
    );
  }

  Future<void> sendAttachment({
    required String jid,
    required EmailAttachment attachment,
    EncryptionProtocol encryptionProtocol = EncryptionProtocol.omemo,
    Message? quotedMessage,
    ChatType chatType = ChatType.chat,
  }) async {
    final accountJid = myJid;
    if (accountJid == null) {
      _log.warning('Attempted to send an attachment before a JID was bound.');
      throw XmppMessageException();
    }
    final senderJid = chatType == ChatType.groupChat
        ? (roomStateFor(jid)?.myOccupantId ?? accountJid)
        : accountJid;
    if (!_isFirstPartyJid(myJid: _myJid, jid: jid)) {
      _log.warning('Blocked XMPP attachment send to foreign domain.');
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
      'maxSize=${uploadSupport.maxFileSizeBytes ?? 'unspecified'}',
    );
    if (!await uploadManager.isSupported()) {
      _log.warning('Server does not advertise HTTP file upload support.');
      throw XmppUploadNotSupportedException();
    }
    final file = File(attachment.path);
    if (!await file.exists()) {
      _log.warning('Attachment missing on disk.');
      throw XmppMessageException();
    }
    final actualSize = await file.length();
    _log.fine(
      'Attachment size check: declared=${attachment.sizeBytes} '
      'actual=$actualSize',
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
    await _storeMessage(message, chatType: chatType);
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
        'contentType=$contentType',
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
      _validateHttpUploadSlotUrls(
        putUrl: putUrl,
        getUrl: getUrl,
      );
      return _UploadSlot(
        getUrl: getUrl,
        putUrl: putUrl,
        headers: _parseHttpUploadPutHeaders(slot),
      );
    } on TimeoutException {
      throw XmppUploadUnavailableException();
    }
  }

  List<_UploadSlotHeader> _parseHttpUploadPutHeaders(mox.XMLNode? slot) {
    final put = slot?.firstTag('put');
    if (put == null) return const [];
    final headers = <_UploadSlotHeader>[];
    for (final tag in put.findTags('header')) {
      final rawName = tag.attributes['name']?.toString() ?? '';
      final rawValue = tag.innerText();
      final cleanedName = rawName.replaceAll(_crlfPattern, '').trim();
      final cleanedValue = rawValue.replaceAll(_crlfPattern, '').trim();
      if (cleanedName.isEmpty || cleanedValue.isEmpty) continue;
      if (!_allowedHttpUploadPutHeaders.contains(cleanedName.toLowerCase())) {
        continue;
      }
      headers.add(_UploadSlotHeader(name: cleanedName, value: cleanedValue));
    }
    return List.unmodifiable(headers);
  }

  void _validateHttpUploadSlotUrls({
    required String putUrl,
    required String getUrl,
  }) {
    final putUri = Uri.tryParse(putUrl);
    final getUri = Uri.tryParse(getUrl);
    if (putUri == null || getUri == null) {
      throw XmppUploadMisconfiguredException('Upload slot URL invalid.');
    }
    const allowInsecure = !kReleaseMode && kAllowInsecureXmppHttpUploadSlots;
    final putIsHttps = putUri.scheme.toLowerCase() == 'https';
    final getIsHttps = getUri.scheme.toLowerCase() == 'https';
    if (putIsHttps && getIsHttps) return;
    if (allowInsecure) {
      _log.warning(
        'Using non-HTTPS upload slot URLs '
        '(development override enabled).',
      );
      return;
    }
    throw XmppUploadMisconfiguredException('Upload slot URLs must use HTTPS.');
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
      for (final header in slot.headers) {
        request.headers.add(header.name, header.value);
      }
      final hasContentTypeHeader = slot.headers.any(
        (header) => header.name.toLowerCase() == HttpHeaders.contentTypeHeader,
      );
      if (!hasContentTypeHeader) {
        request.headers.contentType = ContentType.parse(contentType);
      }
      request.headers.contentLength = uploadLength;
      final safeHeaders = <String>{
        ...slot.headers
            .map((header) => header.name.toLowerCase())
            .where(_safeHttpUploadLogHeaders.contains),
        ..._safeHttpUploadLogHeaders,
      }.toList()
        ..sort();
      final redactedHeaders = slot.headers
          .where(
            (header) =>
                !_safeHttpUploadLogHeaders.contains(header.name.toLowerCase()),
          )
          .length;
      final headerSuffix =
          redactedHeaders > 0 ? ' (+$redactedHeaders redacted)' : '';
      _log.finer(
        'HTTP upload PUT started len=$uploadLength '
        'headers=${safeHeaders.join(',')}$headerSuffix',
      );
      await file.openRead().timeout(_httpUploadPutTimeout).forEach(request.add);
      _log.finer(
        'HTTP upload PUT stream sent in ${stopwatch.elapsedMilliseconds}ms '
        'len=$uploadLength',
      );
      final response = await request.close().timeout(_httpUploadPutTimeout);
      final statusCode = response.statusCode;
      _log.finer(
        'HTTP upload PUT received status $statusCode '
        'after ${stopwatch.elapsedMilliseconds}ms',
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
          '(bodyLen=${bodyBytes.length})',
        );
        throw XmppMessageException();
      }
      _log.finer(
        'HTTP upload PUT completed with $statusCode '
        'in ${stopwatch.elapsedMilliseconds}ms '
        'bodyLen=${bodyBytes.length}',
      );
    } on TimeoutException {
      _log.warning(
        'HTTP upload timed out after ${_httpUploadPutTimeout.inSeconds}s',
      );
      throw XmppUploadUnavailableException();
    } catch (error, stackTrace) {
      _log.warning(
        'HTTP upload failed.',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      client.close();
      stopwatch.stop();
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

  Future<bool> resolveMamSupport() async {
    await _resolveMamSupportForAccount();
    return _mamSupported;
  }

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

  Future<void> _resolveMamSupportForAccount() async {
    if (_mamSupportOverride != null) {
      _updateMamSupport(_mamSupportOverride!);
      return;
    }
    final accountJid = myJid;
    if (accountJid == null) {
      _updateMamSupport(false);
      return;
    }
    try {
      final supported = await _supportsMam(accountJid);
      _updateMamSupport(supported);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to resolve MAM support.', error, stackTrace);
      _updateMamSupport(false);
    }
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
      _updateMamSupport(supportsMam);
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
    _updateMamSupport(_mamSupported && !missingMam);
  }

  Future<void> _acknowledgeMessage(mox.MessageEvent event) async {
    if (event.isCarbon) return;
    final body = event.get<mox.MessageBodyData>()?.body?.trim();
    if (body != null &&
        body.isNotEmpty &&
        _MessageStatusSyncEnvelope.isEnvelope(body)) {
      return;
    }

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

  Future<bool> _handleMessageStatusSync(mox.MessageEvent event) async {
    final raw = event.get<mox.MessageBodyData>()?.body?.trim();
    if (raw == null || raw.isEmpty) {
      return false;
    }
    final from = event.from.toBare().toString().toLowerCase();
    final to = event.to.toBare().toString().toLowerCase();
    final accountJid = myJid;
    final self = accountJid?.toLowerCase();
    if (self == null || self.isEmpty) {
      return false;
    }
    if (from != self || to != self) {
      return false;
    }

    final envelope = _MessageStatusSyncEnvelope.tryParseEnvelope(raw);
    if (envelope == null) {
      if (raw.contains(_messageStatusSyncEnvelopeKey)) {
        _log.fine('Dropped malformed message status sync envelope from self');
        return true;
      }
      return false;
    }

    await _dbOp<XmppDatabase>(
      (db) async {
        if (envelope.displayed) {
          db.markMessageDisplayed(envelope.id);
        }
        if (envelope.received) {
          db.markMessageReceived(envelope.id);
        }
        if (envelope.acked) {
          db.markMessageAcked(envelope.id);
        }
      },
    );
    return true;
  }

  Future<void> _broadcastMessageStatusSync({
    required String id,
    required bool acked,
    required bool received,
    required bool displayed,
  }) async {
    final accountJid = myJid;
    if (accountJid == null || accountJid.isEmpty) {
      return;
    }

    final normalizedDisplayed = displayed;
    final normalizedReceived = normalizedDisplayed || received;
    final normalizedAcked = normalizedReceived || acked;

    final db = await database;
    final message =
        await db.getMessageByStanzaID(id) ?? await db.getMessageByOriginID(id);
    if (message == null) {
      return;
    }
    if (message.senderJid.toLowerCase() != accountJid.toLowerCase()) {
      return;
    }
    final body = message.body;
    if (body != null &&
        body.isNotEmpty &&
        (CalendarSyncMessage.isCalendarSyncEnvelope(body) ||
            _MessageStatusSyncEnvelope.isEnvelope(body))) {
      return;
    }

    final envelopeJson = jsonEncode({
      _messageStatusSyncEnvelopeKey: _MessageStatusSyncEnvelope(
        id: id,
        acked: normalizedAcked,
        received: normalizedReceived,
        displayed: normalizedDisplayed,
      ).toJson(),
    });

    try {
      await sendMessage(
        jid: accountJid,
        text: envelopeJson,
        storeLocally: false,
      );
    } on Exception catch (error, stackTrace) {
      _log.finer('Failed to broadcast message status sync', error, stackTrace);
    }
  }

  @override
  Future<void> _reset() async {
    await super._reset();

    _mamLoginSyncInFlight = false;
    _resetStableKeyCache();
    _lastSeenKeys.clear();
    _capabilityCache.clear();
    _capabilityCacheLoaded = false;
    _inboundAttachmentDownloads.clear();
    _attachmentDirectory = null;
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
    final fun = event.extensions.get<mox.FileUploadNotificationData>();
    final statelessData = event.extensions.get<mox.StatelessFileSharingData>();
    final oob = event.extensions.get<mox.OOBData>();
    final oobUrl = oob?.url;
    final oobDesc = oob?.desc?.trim();
    final oobName = oobDesc?.isNotEmpty == true ? oobDesc : null;
    if (statelessData == null || statelessData.sources.isEmpty) {
      if (fun != null) {
        final name = fun.metadata.name;
        final fallbackName =
            oobName ?? (oobUrl == null ? null : _filenameFromUrl(oobUrl));
        return FileMetadataData(
          id: uuid.v4(),
          sourceUrls: oobUrl == null ? null : [oobUrl],
          filename: p.normalize(name ?? fallbackName ?? 'attachment'),
          mimeType: fun.metadata.mediaType,
          sizeBytes: fun.metadata.size,
          width: fun.metadata.width,
          height: fun.metadata.height,
          plainTextHashes: fun.metadata.hashes,
        );
      }
      if (oobUrl != null) {
        return FileMetadataData(
          id: uuid.v4(),
          sourceUrls: [oobUrl],
          filename: oobName ?? _filenameFromUrl(oobUrl),
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
        mimeType: statelessData.metadata.mediaType,
        sizeBytes: statelessData.metadata.size,
        width: statelessData.metadata.width,
        height: statelessData.metadata.height,
        plainTextHashes: statelessData.metadata.hashes,
      );
    } else {
      final encryptedSources = statelessData.sources
          .whereType<mox.StatelessFileSharingEncryptedSource>();
      final encryptedSource =
          encryptedSources.isEmpty ? null : encryptedSources.first;
      if (encryptedSource == null) {
        if (oobUrl != null) {
          return FileMetadataData(
            id: uuid.v4(),
            sourceUrls: [oobUrl],
            filename: oobName ?? _filenameFromUrl(oobUrl),
          );
        }
        return null;
      }
      return FileMetadataData(
        id: uuid.v4(),
        sourceUrls: [encryptedSource.source.url],
        filename: p.normalize(statelessData.metadata.name ??
            p.basename(encryptedSource.source.url)),
        mimeType: statelessData.metadata.mediaType,
        encryptionKey: base64Encode(encryptedSource.key),
        encryptionIV: base64Encode(encryptedSource.iv),
        encryptionScheme: encryptedSource.encryption.toNamespace(),
        cipherTextHashes: encryptedSource.hashes,
        plainTextHashes: statelessData.metadata.hashes,
        sizeBytes: statelessData.metadata.size,
        width: statelessData.metadata.width,
        height: statelessData.metadata.height,
      );
    }
  }

  String _filenameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments;
    final candidate = segments != null && segments.isNotEmpty
        ? segments.last
        : p.basename(url);
    final normalized = p.basename(candidate).trim();
    return normalized.isEmpty ? 'attachment' : normalized;
  }

  Stream<FileMetadataData?> fileMetadataStream(String id) =>
      createSingleItemStream<FileMetadataData?, XmppDatabase>(
        watchFunction: (db) async {
          final stream = db.watchFileMetadata(id);
          final initial = await db.getFileMetadata(id);
          return stream.startWith(initial);
        },
      );

  Future<String?> downloadInboundAttachment({
    required String metadataId,
    String? stanzaId,
  }) async {
    final existing = _inboundAttachmentDownloads[metadataId];
    if (existing != null) return await existing;
    final future = _downloadInboundAttachment(
      metadataId: metadataId,
      stanzaId: stanzaId,
    );
    _inboundAttachmentDownloads[metadataId] = future;
    try {
      return await future;
    } finally {
      if (_inboundAttachmentDownloads[metadataId] == future) {
        _inboundAttachmentDownloads.remove(metadataId);
      }
    }
  }

  Future<String?> _downloadInboundAttachment({
    required String metadataId,
    String? stanzaId,
  }) async {
    File? tmpFile;
    File? decryptedTmp;
    try {
      final metadata = await _dbOpReturning<XmppDatabase, FileMetadataData?>(
        (db) => db.getFileMetadata(metadataId),
      );
      if (metadata == null) return null;

      final existingPath = metadata.path?.trim();
      if (existingPath != null && existingPath.isNotEmpty) {
        final existingFile = File(existingPath);
        if (await existingFile.exists()) return existingFile.path;
      }

      final urls = metadata.sourceUrls;
      final url = urls == null || urls.isEmpty ? null : urls.first.trim();
      if (url == null || url.isEmpty) {
        throw XmppMessageException();
      }

      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw XmppMessageException();
      }
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        throw XmppMessageException();
      }
      if (uri.userInfo.trim().isNotEmpty) {
        throw XmppMessageException();
      }
      if (uri.host.trim().isEmpty) {
        throw XmppMessageException();
      }

      final encrypted = metadata.encryptionScheme?.isNotEmpty == true;
      const allowInsecureHosts =
          !kReleaseMode && kAllowInsecureXmppAttachmentDownloads;
      final allowHttp = !kReleaseMode ||
          encrypted ||
          _hasExpectedSha256Hash(metadata.plainTextHashes) ||
          _hasExpectedSha256Hash(metadata.cipherTextHashes);

      await _validateInboundAttachmentDownloadUri(
        uri,
        allowHttp: allowHttp,
        allowInsecureHosts: allowInsecureHosts,
      );

      final directory = await _attachmentCacheDirectory();
      final safeFileName = _attachmentFileName(metadata);
      final finalFile = File(p.join(directory.path, safeFileName));
      tmpFile = File(p.join(directory.path, '.${metadata.id}.download'));
      final maxBytes = _attachmentDownloadLimitBytes(metadata);
      final expectedSize = metadata.sizeBytes;
      if (expectedSize != null && expectedSize > 0 && expectedSize > maxBytes) {
        throw XmppFileTooBigException(maxBytes);
      }
      final responseMimeType = await _downloadUrlToFile(
        uri: uri,
        destination: tmpFile,
        maxBytes: maxBytes,
        allowHttp: allowHttp,
        allowInsecureHosts: allowInsecureHosts,
      );

      late final int resolvedSizeBytes;
      if (encrypted) {
        final cipherBytes = await tmpFile.readAsBytes();
        await _verifySha256Hash(
          expected: metadata.cipherTextHashes,
          bytes: cipherBytes,
        );
        final plainBytes = await _decryptAttachmentBytes(
          metadata: metadata,
          cipherBytes: cipherBytes,
        );
        await _verifySha256Hash(
          expected: metadata.plainTextHashes,
          bytes: plainBytes,
        );
        resolvedSizeBytes = plainBytes.length;
        decryptedTmp =
            File(p.join(directory.path, '.${metadata.id}.decrypted'));
        await decryptedTmp.writeAsBytes(plainBytes, flush: true);
        await _replaceFile(source: decryptedTmp, destination: finalFile);
        decryptedTmp = null;
      } else {
        await _verifySha256HashForFile(
          expected: metadata.plainTextHashes,
          file: tmpFile,
        );
        await _replaceFile(source: tmpFile, destination: finalFile);
        tmpFile = null;
        resolvedSizeBytes = await finalFile.length();
      }

      final resolvedMime = metadata.mimeType?.trim().isNotEmpty == true
          ? metadata.mimeType
          : responseMimeType?.trim().isNotEmpty == true
              ? responseMimeType
              : null;
      final updatedMetadata = metadata.copyWith(
        path: finalFile.path,
        mimeType: resolvedMime,
        sizeBytes: resolvedSizeBytes,
      );
      await _dbOp<XmppDatabase>(
        (db) => db.saveFileMetadata(updatedMetadata),
        awaitDatabase: true,
      );
      return finalFile.path;
    } on XmppAbortedException {
      return null;
    } on XmppException catch (_) {
      if (stanzaId != null) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            stanzaID: stanzaId,
            error: MessageError.fileDownloadFailure,
          ),
          awaitDatabase: true,
        );
      }
      rethrow;
    } on Exception {
      if (stanzaId != null) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            stanzaID: stanzaId,
            error: MessageError.fileDownloadFailure,
          ),
          awaitDatabase: true,
        );
      }
      throw XmppMessageException();
    } finally {
      try {
        await tmpFile?.delete();
      } on Exception {
        // Ignore cleanup failures.
      }
      try {
        await decryptedTmp?.delete();
      } on Exception {
        // Ignore cleanup failures.
      }
    }
  }

  int _attachmentDownloadLimitBytes(FileMetadataData metadata) {
    final limit = httpUploadSupport.maxFileSizeBytes;
    if (limit != null && limit > 0) return limit;
    return _xmppAttachmentDownloadLimitFallbackBytes;
  }

  Future<Directory> _attachmentCacheDirectory() async {
    final cached = _attachmentDirectory;
    if (cached != null && await cached.exists()) {
      return cached;
    }
    final supportDir = await getApplicationSupportDirectory();
    final prefix = _databasePrefix;
    final normalizedPrefix = prefix == null || prefix.isEmpty
        ? 'shared'
        : prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final directory = Directory(
      p.join(supportDir.path, 'attachments', normalizedPrefix),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _attachmentDirectory = directory;
    return directory;
  }

  String _attachmentFileName(FileMetadataData metadata) {
    final sanitized = _sanitizeAttachmentFilename(metadata.filename);
    return '${metadata.id}_$sanitized';
  }

  String _sanitizeAttachmentFilename(String filename) {
    final base = p.basename(filename).trim();
    if (base.isEmpty) return 'attachment';
    final strippedSeparators = base.replaceAll(RegExp(r'[\\/]'), '_');
    final collapsedWhitespace =
        strippedSeparators.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsedWhitespace.isEmpty) return 'attachment';
    final safe = collapsedWhitespace.replaceAll(
      RegExp(r'[^a-zA-Z0-9._() \[\]-]'),
      '_',
    );
    final normalized = safe.trim();
    if (normalized.isEmpty) return 'attachment';
    if (normalized.length <= _attachmentMaxFilenameLength) return normalized;
    final extension = p.extension(normalized);
    final baseName = p.basenameWithoutExtension(normalized);
    final maxBase = _attachmentMaxFilenameLength - extension.length;
    if (maxBase <= 0) {
      return normalized.substring(0, _attachmentMaxFilenameLength);
    }
    return '${baseName.substring(0, maxBase)}$extension';
  }

  Future<void> _replaceFile({
    required File source,
    required File destination,
  }) async {
    if (await destination.exists()) {
      await destination.delete();
    }
    await source.rename(destination.path);
  }

  Future<String?> _downloadUrlToFile({
    required Uri uri,
    required File destination,
    required int maxBytes,
    required bool allowHttp,
    required bool allowInsecureHosts,
  }) async {
    final client = HttpClient()..connectionTimeout = _httpAttachmentGetTimeout;
    try {
      var redirects = 0;
      var current = uri;
      while (true) {
        await _validateInboundAttachmentDownloadUri(
          current,
          allowHttp: allowHttp,
          allowInsecureHosts: allowInsecureHosts,
        );
        final request =
            await client.getUrl(current).timeout(_httpAttachmentGetTimeout)
              ..followRedirects = false
              ..maxRedirects = 0;
        final response =
            await request.close().timeout(_httpAttachmentGetTimeout);
        final statusCode = response.statusCode;

        if (_isHttpRedirectStatusCode(statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.listen((_) {}).cancel();
          if (location == null || location.trim().isEmpty) {
            throw XmppMessageException();
          }
          if (redirects >= _xmppAttachmentDownloadMaxRedirects) {
            throw XmppMessageException();
          }
          final redirected = current.resolve(location.trim());
          final redirectedScheme = redirected.scheme.toLowerCase();
          if (current.scheme.toLowerCase() == 'https' &&
              redirectedScheme == 'http') {
            throw XmppMessageException();
          }
          current = redirected;
          redirects += 1;
          continue;
        }

        final success = statusCode >= 200 && statusCode < 300;
        if (!success) {
          throw XmppMessageException();
        }

        final mimeType = response.headers.contentType?.mimeType;
        final responseLength = response.contentLength;
        if (responseLength != -1 && responseLength > maxBytes) {
          throw XmppFileTooBigException(maxBytes);
        }
        final sink = destination.openWrite();
        var received = 0;
        try {
          await for (final chunk
              in response.timeout(_httpAttachmentGetTimeout)) {
            received += chunk.length;
            if (received > maxBytes) {
              throw XmppFileTooBigException(maxBytes);
            }
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
        return mimeType;
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _validateInboundAttachmentDownloadUri(
    Uri uri, {
    required bool allowHttp,
    required bool allowInsecureHosts,
  }) async {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw XmppMessageException();
    }
    if (scheme == 'http' && !allowHttp) {
      throw XmppMessageException();
    }
    if (uri.userInfo.trim().isNotEmpty) {
      throw XmppMessageException();
    }
    final host = uri.host.trim();
    if (host.isEmpty) {
      throw XmppMessageException();
    }
    if (!allowInsecureHosts) {
      final safe = await isSafeHostForRemoteConnection(host)
          .timeout(_httpAttachmentGetTimeout);
      if (!safe) {
        throw XmppMessageException();
      }
    }
  }

  bool _isHttpRedirectStatusCode(int statusCode) => switch (statusCode) {
        HttpStatus.movedPermanently ||
        HttpStatus.found ||
        HttpStatus.seeOther ||
        HttpStatus.temporaryRedirect ||
        HttpStatus.permanentRedirect =>
          true,
        _ => false,
      };

  Future<Uint8List> _decryptAttachmentBytes({
    required FileMetadataData metadata,
    required List<int> cipherBytes,
  }) async {
    final scheme = metadata.encryptionScheme?.trim();
    final keyEncoded = metadata.encryptionKey?.trim();
    final ivEncoded = metadata.encryptionIV?.trim();
    if (scheme == null ||
        scheme.isEmpty ||
        keyEncoded == null ||
        keyEncoded.isEmpty ||
        ivEncoded == null ||
        ivEncoded.isEmpty) {
      throw XmppMessageException();
    }
    final keyBytes = base64Decode(keyEncoded);
    final ivBytes = base64Decode(ivEncoded);
    switch (scheme) {
      case mox.sfsEncryptionAes128GcmNoPaddingXmlns:
      case mox.sfsEncryptionAes256GcmNoPaddingXmlns:
        if (cipherBytes.length <= _aesGcmTagLengthBytes) {
          throw XmppMessageException();
        }
        final macBytes =
            cipherBytes.sublist(cipherBytes.length - _aesGcmTagLengthBytes);
        final body =
            cipherBytes.sublist(0, cipherBytes.length - _aesGcmTagLengthBytes);
        final secretBox = SecretBox(
          body,
          nonce: ivBytes,
          mac: Mac(macBytes),
        );
        final algorithm = scheme == mox.sfsEncryptionAes128GcmNoPaddingXmlns
            ? AesGcm.with128bits()
            : AesGcm.with256bits();
        final decrypted = await algorithm.decrypt(
          secretBox,
          secretKey: SecretKey(keyBytes),
        );
        return Uint8List.fromList(decrypted);
      case mox.sfsEncryptionAes256CbcPkcs7Xmlns:
        final algorithm = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
        final secretBox = SecretBox(
          cipherBytes,
          nonce: ivBytes,
          mac: Mac.empty,
        );
        final decrypted = await algorithm.decrypt(
          secretBox,
          secretKey: SecretKey(keyBytes),
        );
        return Uint8List.fromList(decrypted);
    }
    throw XmppMessageException();
  }

  Future<void> _verifySha256Hash({
    required Map<mox.HashFunction, String>? expected,
    required List<int> bytes,
  }) async {
    if (expected == null || expected.isEmpty) return;
    final hashValue = expected[mox.HashFunction.sha256];
    if (hashValue == null || hashValue.trim().isEmpty) return;
    final expectedBytes = _decodeSha256Expected(hashValue);
    if (expectedBytes == null) {
      throw XmppMessageException();
    }
    final computed = sha256.convert(bytes).bytes;
    if (!_constantTimeBytesEqual(computed, expectedBytes)) {
      throw XmppMessageException();
    }
  }

  bool _hasExpectedSha256Hash(Map<mox.HashFunction, String>? expected) {
    if (expected == null || expected.isEmpty) return false;
    final hashValue = expected[mox.HashFunction.sha256];
    if (hashValue == null || hashValue.trim().isEmpty) return false;
    return _decodeSha256Expected(hashValue) != null;
  }

  Future<void> _verifySha256HashForFile({
    required Map<mox.HashFunction, String>? expected,
    required File file,
  }) async {
    if (expected == null || expected.isEmpty) return;
    final hashValue = expected[mox.HashFunction.sha256];
    if (hashValue == null || hashValue.trim().isEmpty) return;
    final expectedBytes = _decodeSha256Expected(hashValue);
    if (expectedBytes == null) {
      throw XmppMessageException();
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (!_constantTimeBytesEqual(digest.bytes, expectedBytes)) {
      throw XmppMessageException();
    }
  }

  Uint8List? _decodeSha256Expected(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final looksLikeHex =
        trimmed.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed);
    if (looksLikeHex) {
      try {
        final bytes = <int>[];
        for (var index = 0; index < trimmed.length; index += 2) {
          bytes.add(int.parse(trimmed.substring(index, index + 2), radix: 16));
        }
        return Uint8List.fromList(bytes);
      } on Exception {
        return null;
      }
    }
    final normalized = _normalizeBase64(trimmed);
    try {
      final decoded = base64Decode(normalized);
      return decoded.length == 32 ? Uint8List.fromList(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  String _normalizeBase64(String input) {
    final sanitized = input.replaceAll('-', '+').replaceAll('_', '/');
    final padding = sanitized.length % 4;
    if (padding == 0) return sanitized;
    return '$sanitized${'=' * (4 - padding)}';
  }

  bool _constantTimeBytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var result = 0;
    for (var index = 0; index < left.length; index++) {
      result |= left[index] ^ right[index];
    }
    return result == 0;
  }

  Future<void> _autoDownloadTrustedInboundAttachment({
    required Message message,
    required String metadataId,
  }) async {
    final trimmedMetadataId = metadataId.trim();
    if (trimmedMetadataId.isEmpty) return;
    final stanzaId = message.stanzaID.trim();
    if (stanzaId.isEmpty) return;
    try {
      final accountJid = myJid?.trim();
      final isSelf = accountJid != null &&
          message.senderJid.trim().toLowerCase() == accountJid.toLowerCase();
      var isTrusted = isSelf;
      if (!isTrusted) {
        isTrusted = await _dbOpReturning<XmppDatabase, bool>(
          (db) async => (await db.getRosterItem(message.chatJid)) != null,
        );
      }
      if (!isTrusted) return;
      await downloadInboundAttachment(
        metadataId: trimmedMetadataId,
        stanzaId: stanzaId,
      );
    } on Exception {
      // Best-effort: errors are reflected on the message via fileDownloadFailure.
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
    List<_UploadSlotHeader>? headers,
  }) : headers = headers ?? const [];

  // ignore: unused_element
  factory _UploadSlot.fromMox(mox.HttpFileUploadSlot slot) {
    return _UploadSlot(
      getUrl: slot.getUrl.toString(),
      putUrl: slot.putUrl.toString(),
      headers: slot.headers.entries
          .map(
            (entry) => _UploadSlotHeader(
              name: entry.key,
              value: entry.value,
            ),
          )
          .where(
            (header) => _allowedHttpUploadPutHeaders
                .contains(header.name.toLowerCase()),
          )
          .toList(growable: false),
    );
  }

  final String getUrl;
  final String putUrl;
  final List<_UploadSlotHeader> headers;
}

class _UploadSlotHeader {
  const _UploadSlotHeader({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
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
