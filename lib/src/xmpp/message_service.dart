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

mixin MessageService on XmppBase {
  Stream<List<Message>> messageStreamForChat(
    String jid, {
    int start = 0,
    int end = 50,
  }) =>
      StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppDatabase, Stream<List<Message>>>(
          (db) => db.watchChatMessages(jid, start: start, end: end),
        ),
      ));

  Stream<List<Draft>> draftsStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      StreamCompleter.fromFuture(Future.value(
        _dbOpReturning<XmppDatabase, Stream<List<Draft>>>(
          (db) async => db
              .watchDrafts(start: start, end: end)
              .startWith(await db.getDrafts(start: start, end: end)),
        ),
      ));

  final _log = Logger('MessageService');

  var _messageStream = StreamController<Message>.broadcast();

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
        await _dbOp<XmppDatabase>((db) async {
          await db.saveFileMetadata(metadata);
        });
      }

      if (event.get<mox.OmemoData>() case final data?) {
        final newRatchets = data.newRatchets.values.map((e) => e.length);
        final newCount = newRatchets.fold(0, (v, e) => v + e);
        final replacedRatchets =
            data.replacedRatchets.values.map((e) => e.length);
        final replacedCount = replacedRatchets.fold(0, (v, e) => v + e);
        final pseudoMessageData = {
          'ratchetsAdded': newRatchets,
          'ratchetsReplaced': replacedRatchets,
        };

        if (newCount > 0) {
          await _dbOp<XmppDatabase>((db) async {
            await db.saveMessage(Message(
              stanzaID: _connection.generateId(),
              senderJid: myJid!.toString(),
              chatJid: message.chatJid,
              pseudoMessageType: PseudoMessageType.newDevice,
              pseudoMessageData: pseudoMessageData,
            ));
          });
        }

        if (replacedCount > 0) {
          await _dbOp<XmppDatabase>((db) async {
            await db.saveMessage(Message(
              stanzaID: _connection.generateId(),
              senderJid: myJid!.toString(),
              chatJid: message.chatJid,
              pseudoMessageType: PseudoMessageType.changedDevice,
              pseudoMessageData: pseudoMessageData,
            ));
          });
        }
      }

      if (!message.noStore) {
        await _dbOp<XmppDatabase>((db) async {
          await db.saveMessage(message);
        });
      }

      _messageStream.add(message);
    })
    ..registerHandler<mox.ChatMarkerEvent>((event) async {
      _log.info('Received chat marker from ${event.from}');

      await _dbOp<XmppDatabase>((db) async {
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
      });
    })
    ..registerHandler<mox.DeliveryReceiptReceivedEvent>((event) async {
      await _dbOp<XmppDatabase>((db) async {
        await db.markMessageReceived(event.id);
      });
    });

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      MessageManager(),
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
    await _dbOp<XmppDatabase>((db) async {
      await db.saveMessage(message);
    });

    if (!await _connection.sendMessage(message.toMox())) {
      _log.info(
        'Failed to send message: ${message.stanzaID}. '
        'Storing with error to allow resend...',
        e,
      );

      await _dbOp<XmppDatabase>((db) async {
        await db.saveMessageError(
          error: MessageError.unknown,
          stanzaID: message.stanzaID,
        );
      });

      throw XmppMessageException();
    }
  }

  Future<bool> _canSendChatMarkers({required String to}) async {
    return to != myJid &&
        await _dbOpReturning<XmppDatabase, bool>((db) async {
          final chat = await db.getChat(to);
          return chat?.markerResponsive ?? false;
        });
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
  }

  Future<void> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
  }) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.saveDraft(id: id, jids: jids, body: body);
    });
  }

  Future<void> deleteDraft({required int id}) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.removeDraft(id);
    });
  }

  Future<void> _acknowledgeMessage(mox.MessageEvent event) async {
    final to = event.from.toBare().toString();
    final result = await _connection.discoInfoQuery(to);
    if (result == null || result.isType<mox.DiscoError>()) return;

    final info = result.get<mox.DiscoInfo>();
    final markable =
        event.extensions.get<mox.MarkableData>()?.isMarkable ?? false;
    final deliveryReceiptRequested = event.extensions
            .get<mox.MessageDeliveryReceiptData>()
            ?.receiptRequested ??
        false;
    final id = event.extensions.get<mox.StableIdData>()?.originId ?? event.id;

    if (markable &&
        info.features.contains(mox.chatMarkersXmlns) &&
        id != null) {
      await _connection.sendChatMarker(
        to: to,
        stanzaID: id,
        marker: mox.ChatMarker.received,
      );
    } else if (deliveryReceiptRequested &&
        info.features.contains(mox.deliveryXmlns) &&
        id != null) {
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
    }
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

    await _dbOp<XmppDatabase>((db) async {
      await db.saveMessageError(stanzaID: event.id!, error: error);
    });
    return true;
  }

  Future<void> _handleChatState(mox.MessageEvent event, String jid) async {
    if (event.extensions.get<mox.ChatState>() case final state?) {
      await _dbOp<XmppDatabase>((db) async {
        await db.updateChatState(chatJid: jid, state: state);
      });
    }
  }

  Future<bool> _handleCorrection(mox.MessageEvent event, String jid) async {
    final correction = event.extensions.get<mox.LastMessageCorrectionData>();
    if (correction == null) return false;
    var edited = false;
    await _dbOp<XmppDatabase>((db) async {
      if (await db.getMessageByOriginID(correction.id) case final message?) {
        if (!message.authorized(event.from) || !message.editable) return;
        await db.saveMessageEdit(
          stanzaID: message.stanzaID,
          body: event.extensions.get<mox.MessageBodyData>()?.body,
        );
        edited = true;
      }
    });
    return edited;
  }

  Future<bool> _handleRetraction(mox.MessageEvent event, String jid) async {
    final retraction = event.extensions.get<mox.MessageRetractionData>();
    if (retraction == null) return false;
    var retracted = false;
    await _dbOp<XmppDatabase>((db) async {
      if (await db.getMessageByOriginID(retraction.id) case final message?) {
        if (!message.authorized(event.from)) return;
        await db.markMessageRetracted(message.stanzaID);
        retracted = true;
      }
    });
    return retracted;
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

class OmemoDeviceData extends mox.StanzaHandlerExtension {
  OmemoDeviceData({required this.id});

  final int id;
}

class MessageManager extends mox.MessageManager {
  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: 'message',
          callback: _attachDevice,
          priority: mox.MessageManager.messageHandlerPriority + 1,
        ),
        ...super.getIncomingStanzaHandlers(),
      ];

  Future<mox.StanzaHandlerData> _attachDevice(
    mox.Stanza stanza,
    mox.StanzaHandlerData state,
  ) async {
    if (state.stanza
            .firstTag('encrypted', xmlns: mox.omemoXmlns)
            ?.firstTag('header')
            ?.attributes['sid']
        case final String sid) {
      final deviceID = int.parse(sid);
      return state
        ..extensions.set<OmemoDeviceData>(
          OmemoDeviceData(id: deviceID),
        );
    }

    return state;
  }
}
