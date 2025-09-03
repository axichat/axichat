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

      if (await _canSendChatMarkers(to: message.chatJid)) {
        _acknowledgeMessage(event);
      }

      await _handleFile(event, message.senderJid);

      final metadata = _extractFileMetadata(event);

      if (metadata != null) {
        final db = await database;
        await db.executeOperation(
          operation: () => db.saveFileMetadata(metadata),
          operationName: 'save file metadata',
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
          final db = await database;
          await db.executeOperation(
            operation: () => db.saveMessage(Message(
              stanzaID: _connection.generateId(),
              senderJid: myJid!.toString(),
              chatJid: message.chatJid,
              pseudoMessageType: PseudoMessageType.newDevice,
              pseudoMessageData: pseudoMessageData,
            )),
            operationName: 'save new device message',
          );
        }

        if (replacedCount > 0) {
          final db = await database;
          await db.executeOperation(
            operation: () => db.saveMessage(Message(
              stanzaID: _connection.generateId(),
              senderJid: myJid!.toString(),
              chatJid: message.chatJid,
              pseudoMessageType: PseudoMessageType.changedDevice,
              pseudoMessageData: pseudoMessageData,
            )),
            operationName: 'save changed device message',
          );
        }
      }

      if (!message.noStore) {
        final db = await database;
        await db.executeOperation(
          operation: () => db.saveMessage(message),
          operationName: 'save message',
        );
      }

      _messageStream.add(message);
    })
    ..registerHandler<mox.ChatMarkerEvent>((event) async {
      _log.info('Received chat marker from ${event.from}');

      final db = await database;
      await db.executeOperation(
        operation: () async {
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
        operationName: 'update chat marker status',
      );
    })
    ..registerHandler<mox.DeliveryReceiptReceivedEvent>((event) async {
      final db = await database;
      await db.executeOperation(
        operation: () => db.markMessageReceived(event.id),
        operationName: 'mark message received',
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
    _log.info('Sending message: ${message.stanzaID} '
        'with body: ${text.substring(0, min(10, text.length))}...');
    final db = await database;
    await db.executeOperation(
      operation: () => db.saveMessage(message),
      operationName: 'save outgoing message',
    );

    if (!await _connection.sendMessage(message.toMox())) {
      _log.info(
        'Failed to send message: ${message.stanzaID}. '
        'Storing with error to allow resend...',
        e,
      );

      final db = await database;
      await db.executeOperation(
        operation: () => db.saveMessageError(
          error: MessageError.unknown,
          stanzaID: message.stanzaID,
        ),
        operationName: 'save message error',
      );

      throw XmppMessageException();
    }
  }

  Future<bool> _canSendChatMarkers({required String to}) async {
    if (to == myJid) return false;

    final db = await database;
    return await db.executeQuery<bool>(
      operation: () async {
        final chat = await db.getChat(to);
        return chat?.markerResponsive ?? false;
      },
      operationName: 'check chat marker capability',
    );
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

    final db = await database;
    await db.executeOperation(
      operation: () async {
        db.markMessageDisplayed(stanzaID);
        db.markMessageReceived(stanzaID);
        db.markMessageAcked(stanzaID);
      },
      operationName: 'mark read message status',
    );
  }

  Future<int> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
  }) async {
    final db = await database;
    return await db.executeQuery<int>(
      operation: () => db.saveDraft(id: id, jids: jids, body: body),
      operationName: 'save draft',
    );
  }

  Future<void> deleteDraft({required int id}) async {
    final db = await database;
    await db.executeOperation(
      operation: () => db.removeDraft(id),
      operationName: 'delete draft',
    );
  }

  Future<void> _acknowledgeMessage(mox.MessageEvent event) async {
    final to = event.from.toBare().toString();
    final result = await _connection.discoInfoQuery(to);
    if (result == null || result.isType<mox.StanzaError>()) return;

    final info = result.get<mox.DiscoInfo>();
    final markable =
        event.extensions.get<mox.MarkableData>()?.isMarkable ?? false;
    final deliveryReceiptRequested = event.extensions
            .get<mox.MessageDeliveryReceiptData>()
            ?.receiptRequested ??
        false;
    final id = event.extensions.get<mox.StableIdData>()?.originId ?? event.id;

    if (id == null) return;

    if (markable && info.features.contains(mox.chatMarkersXmlns)) {
      await _connection.sendChatMarker(
        to: to,
        stanzaID: id,
        marker: mox.ChatMarker.received,
      );

      final db = await database;
      await db.executeOperation(
        operation: () async {
          db.markMessageReceived(id);
          db.markMessageAcked(id);
        },
        operationName: 'acknowledge message with chat marker',
      );
    } else if (deliveryReceiptRequested &&
        info.features.contains(mox.deliveryXmlns)) {
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

      final db = await database;
      await db.executeOperation(
        operation: () async {
          db.markMessageReceived(id);
          db.markMessageAcked(id);
        },
        operationName: 'acknowledge message with delivery receipt',
      );
    }
  }

  @override
  Future<void> _reset() async {
    await super._reset();

    await _messageStream.close();
    _messageStream = StreamController<Message>.broadcast();
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

    final db = await database;
    await db.executeOperation(
      operation: () => db.saveMessageError(stanzaID: event.id!, error: error),
      operationName: 'save message error',
    );
    return true;
  }

  Future<void> _handleChatState(mox.MessageEvent event, String jid) async {
    if (event.extensions.get<mox.ChatState>() case final state?) {
      final db = await database;
      await db.executeOperation(
        operation: () => db.updateChatState(chatJid: jid, state: state),
        operationName: 'update chat state',
      );
    }
  }

  Future<bool> _handleCorrection(mox.MessageEvent event, String jid) async {
    final correction = event.extensions.get<mox.LastMessageCorrectionData>();
    if (correction == null) return false;

    final db = await database;
    return await db.executeQuery<bool>(
      operation: () async {
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
      operationName: 'handle message correction',
    );
  }

  Future<bool> _handleRetraction(mox.MessageEvent event, String jid) async {
    final retraction = event.extensions.get<mox.MessageRetractionData>();
    if (retraction == null) return false;

    final db = await database;
    return await db.executeQuery<bool>(
      operation: () async {
        if (await db.getMessageByOriginID(retraction.id) case final message?) {
          if (!message.authorized(event.from)) return false;
          await db.markMessageRetracted(message.stanzaID);
          return true;
        }
        return false;
      },
      operationName: 'handle message retraction',
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
