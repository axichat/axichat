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
  final _log = Logger('MessageService');

  Future<void> sendMessage({required String jid, required String text}) async {
    if (_connection.getManager<mox.MessageManager>() case final mm?) {
      final stanzaID = _connection.generateId();
      final originID = _connection.generateId();
      _log.info('Sending message: $stanzaID '
          'with body: ${text.substring(0, min(10, text.length))}...');
      await _dbOp<XmppDatabase>((db) async {
        await db.saveMessage(Message(
          stanzaID: stanzaID,
          originID: originID,
          senderJid: user!.jid.toString(),
          chatJid: jid,
          body: text,
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
