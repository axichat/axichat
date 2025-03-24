part of 'package:chat/src/xmpp/xmpp_service.dart';

extension on mox.MessageEvent {
  bool get displayable {
    return extensions.get<mox.MessageBodyData>()?.body?.isNotEmpty ??
        false ||
            extensions.get<mox.StatelessFileSharingData>() != null ||
            extensions.get<mox.FileUploadNotificationData>() != null;
  }
}

mixin MessageService on XmppBase {
  Stream<List<Message>> messageStream(
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

  Future<void> sendMessage({
    required String jid,
    required String text,
    EncryptionProtocol encryptionProtocol = EncryptionProtocol.omemo,
  }) async {
    if (_connection.getManager<mox.MessageManager>() case final mm?) {
      final stanzaID = _connection.generateId();
      final originID = _connection.generateId();
      _log.info('Sending message: $stanzaID '
          'with body: ${text.substring(0, min(10, text.length))}...');
      await _dbOp<XmppDatabase>((db) async {
        await db.saveMessage(Message(
          stanzaID: stanzaID,
          originID: originID,
          senderJid: myJid.toString(),
          chatJid: jid,
          body: text,
          encryptionProtocol: encryptionProtocol,
        ));
      });

      try {
        await mm.sendMessage(
          mox.JID.fromString(jid),
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageBodyData(text),
            mox.MarkableData(true),
            mox.MessageIdData(stanzaID),
            mox.StableIdData(originID, null),
            mox.ChatState.active,
          ]),
        );
      } on Exception catch (e) {
        _log.info(
            'Failed to send message: $stanzaID. '
            'Storing with error to allow resend...',
            e);
        await _dbOp<XmppDatabase>((db) async {
          await db.saveMessageError(
            error: MessageError.unknown,
            stanzaID: stanzaID,
          );
        });
        throw XmppMessageException();
      }
    }
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

  Future<void> _handleMessage(mox.MessageEvent event) async {
    if (await _handleError(event)) throw EventHandlerAbortedException();

    final get = event.extensions.get;
    final isCarbon = get<mox.CarbonsData>()?.isCarbon ?? false;
    final to = event.to.toBare().toString();
    final from = event.from.toBare().toString();
    final chatJid = isCarbon ? to : from;

    await _handleChatState(event, chatJid);

    if (await _handleCorrection(event, from)) {
      throw EventHandlerAbortedException();
    }
    if (await _handleRetraction(event, from)) {
      throw EventHandlerAbortedException();
    }

    // TODO: Include InvalidKeyExchangeSignatureError for OMEMO.
    if (!event.displayable && event.encryptionError == null) {
      throw EventHandlerAbortedException();
    }
    if (get<mox.FileUploadNotificationData>() case final data?) {
      if (data.metadata.name == null) throw EventHandlerAbortedException();
    }

    await _handleFile(event, from);

    final metadata = _extractFileMetadata(event);
    if (metadata != null) {
      await _dbOp<XmppDatabase>((db) async {
        await db.saveFileMetadata(metadata);
      });
    }

    final body = get<mox.ReplyData>()?.withoutFallback ??
        get<mox.MessageBodyData>()?.body ??
        '';

    final message = Message(
      stanzaID: event.id ?? _connection.generateId(),
      senderJid: from,
      chatJid: chatJid,
      body: body,
      timestamp: get<mox.DelayedDeliveryData>()?.timestamp,
      fileMetadataID: metadata?.id,
      noStore: get<mox.MessageProcessingHintData>()
              ?.hints
              .contains(mox.MessageProcessingHint.noStore) ??
          false,
      quoting: get<mox.ReplyData>()?.id,
      originID: get<mox.StableIdData>()?.originId,
      occupantID: get<mox.OccupantIdData>()?.id,
      encryptionProtocol:
          event.encrypted ? EncryptionProtocol.omemo : EncryptionProtocol.none,
      acked: true,
      received: true,
    );
    await _dbOp<XmppDatabase>((db) async {
      await db.saveMessage(message);
    });
  }

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
