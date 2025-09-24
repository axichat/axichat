part of 'package:axichat/src/xmpp/xmpp_service.dart';

extension MessageEvent on mox.MessageEvent {
  String get text =>
      get<mox.ReplyData>()?.withoutFallback ??
      get<mox.MessageBodyData>()?.body ??
      '';

  bool get isCarbon => get<mox.CarbonsData>()?.isCarbon ?? false;

  bool get displayable {
    return get<mox.MessageBodyData>()?.body?.isNotEmpty ??
        false ||
            get<mox.StatelessFileSharingData>() != null ||
            get<mox.FileUploadNotificationData>() != null;
  }
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

mixin MessageService on XmppBase, BaseStreamService {
  Stream<List<Message>> messageStreamForChat(
    String jid, {
    int start = 0,
    int end = 50,
  }) =>
      createSingleItemStream<List<Message>, XmppDatabase>(
        watchFunction: (db) async {
          final stream = db.watchChatMessages(jid, start: start, end: end);
          final initial = await db.getChatMessages(jid, start: start, end: end);
          return stream.startWith(initial);
        },
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

  var _messageStream = StreamController<Message>.broadcast();

  final Map<String, _PeerCapabilities> _capabilityCache = {};
  var _capabilityCacheLoaded = false;

  @override
  bool get needsReset => super.needsReset || _messageStream.hasListener;

  @override
  EventManager<mox.XmppEvent> get _eventManager => super._eventManager
    ..registerHandler<mox.MessageEvent>((event) async {
      if (await _handleError(event)) return;

      final message = Message.fromMox(event);

      await _handleChatState(event, message.chatJid);

      if (await _handleCorrection(event, message.senderJid)) return;
      if (await _handleRetraction(event, message.senderJid)) return;

      if (!event.displayable && event.encryptionError == null) return;
      if (event.encryptionError is omemo.InvalidKeyExchangeSignatureError) {
        return;
      }
      if (event.extensions.get<mox.FileUploadNotificationData>()
          case final data?) {
        if (data.metadata.name == null) return;
      }

      unawaited(_acknowledgeMessage(event));

      await _handleFile(event, message.senderJid);

      final metadata = _extractFileMetadata(event);

      if (metadata != null) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveFileMetadata(metadata),
        );
      }

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
            (db) => db.saveMessage(Message(
              stanzaID: _connection.generateId(),
              senderJid: myJid!.toString(),
              chatJid: message.chatJid,
              pseudoMessageType: PseudoMessageType.newDevice,
              pseudoMessageData: pseudoMessageData,
            )),
          );
        }

        if (replacedCount > 0) {
          await _dbOp<XmppDatabase>(
            (db) => db.saveMessage(Message(
              stanzaID: _connection.generateId(),
              senderJid: myJid!.toString(),
              chatJid: message.chatJid,
              pseudoMessageType: PseudoMessageType.changedDevice,
              pseudoMessageData: pseudoMessageData,
            )),
          );
        }
      }

      if (!message.noStore) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessage(message),
        );
      }

      _messageStream.add(message);
    })
    ..registerHandler<mox.ChatMarkerEvent>((event) async {
      _log.info('Received chat marker from ${event.from}');

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

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      mox.MessageManager(),
      mox.CarbonsManager(),
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
      // mox.StickersManager(),
      // mox.MUCManager(),
      // mox.OOBManager(),
      // mox.SFSManager(),
      // mox.HttpFileUploadManager(),
      // mox.FileUploadNotificationManager(),
    ]);

  Future<void> sendMessage({
    required String jid,
    required String text,
    EncryptionProtocol encryptionProtocol = EncryptionProtocol.omemo,
  }) async {
    final message = Message(
      stanzaID: _connection.generateId(),
      originID: _connection.generateId(),
      senderJid: myJid.toString(),
      chatJid: jid,
      body: text,
      encryptionProtocol: encryptionProtocol,
    );
    _log.info(
      'Sending message ${message.stanzaID} (length=${text.length} chars)',
    );
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessage(message),
    );

    try {
      final sent = await _connection.sendMessage(message.toMox());
      if (!sent) {
        await _handleMessageSendFailure(message.stanzaID);
        throw XmppMessageException();
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to send message ${message.stanzaID}',
        error,
        stackTrace,
      );
      await _handleMessageSendFailure(message.stanzaID);
      throw XmppMessageException();
    }
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

  Future<int> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
  }) async {
    return await _dbOpReturning<XmppDatabase, int>(
      (db) => db.saveDraft(id: id, jids: jids, body: body),
    );
  }

  Future<void> deleteDraft({required int id}) async {
    await _dbOp<XmppDatabase>(
      (db) => db.removeDraft(id),
    );
  }

  Future<void> _handleMessageSendFailure(String stanzaID) async {
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessageError(
        error: MessageError.unknown,
        stanzaID: stanzaID,
      ),
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

    await _messageStream.close();
    _messageStream = StreamController<Message>.broadcast();
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
    if (event.error == null || event.id == null) return true;

    final error = switch (event.error!) {
      mox.ServiceUnavailableError _ => MessageError.serviceUnavailable,
      mox.RemoteServerNotFoundError _ => MessageError.serverNotFound,
      mox.RemoteServerTimeoutError _ => MessageError.serverTimeout,
      _ => MessageError.unknown,
    };

    await _dbOp<XmppDatabase>(
      (db) => db.saveMessageError(stanzaID: event.id!, error: error),
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

  // Future<bool> _handleReactions(mox.MessageEvent event, String jid) async {
  //   final reactions = event.extensions.get<mox.MessageReactionsData>();
  //   if (reactions == null || event.type == 'groupchat') return false;
  //   await _dbOp<XmppDatabase>((db) async {
  //     if (await db.messagesAccessor.selectOne(reactions.messageId)
  //         case final message?) {}
  //   });
  //   return true;
  // }

  Future<void> _handleFile(mox.MessageEvent event, String jid) async {}

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
