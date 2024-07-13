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
      await _dbOp<XmppDatabase>((db) async {
        await db.messagesAccessor.insertOne(Message(
          stanzaID: stanzaID,
          originID: originID,
          myJid: user!.jid.toString(),
          senderJid: user!.jid.toString(),
          chatJid: jid,
          body: text,
        ));
      });
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
      await _dbOp<XmppDatabase>((db) async {
        if (await db.chatsAccessor.selectOne(jid) case final chat?) {
          await db.chatsAccessor.updateOne(chat.copyWith(
            unreadCount: chat.open ? 0 : chat.unreadCount + 1,
            lastMessage: text,
            lastChangeTimestamp: DateTime.timestamp(),
          ));
        } else {
          await db.chatsAccessor.insertOne(Chat(
            jid: jid,
            myJid: user!.jid.toString(),
            myNickname: user!.username,
            title: mox.JID.fromString(jid).local,
            type: ChatType.chat,
            unreadCount: 1,
            lastMessage: text,
            lastChangeTimestamp: DateTime.timestamp(),
          ));
        }
      });
    }
  }

  Future<bool> _handleError(mox.MessageEvent event) async {
    if (event.type != 'error') return false;

    _log.info('Handling error message...');
    if (event.error == null || event.id == null) return true;

    await _dbOp<XmppDatabase>((db) async {
      if (await db.messagesAccessor.selectOne(event.id!) case final message?) {
        final error = switch (event.error!) {
          mox.ServiceUnavailableError _ => MessageError.serviceUnavailable,
          mox.RemoteServerNotFoundError _ => MessageError.serverNotFound,
          mox.RemoteServerTimeoutError _ => MessageError.serverTimeout,
          _ => MessageError.unknown,
        };

        await db.messagesAccessor.updateOne(message.copyWith(error: error));
      }
    });
    return true;
  }

  Future<void> _handleChatState(mox.MessageEvent event, String jid) async {
    if (event.extensions.get<mox.ChatState>() case final state?) {
      await _dbOp<XmppDatabase>((db) async {
        if (await db.chatsAccessor.selectOne(jid) case final chat?) {
          _log.info('Updating chat state to ${state.name}...');
          await db.chatsAccessor.updateOne(chat.copyWith(chatState: state));
        }
      });
    }
  }

  Future<bool> _handleCorrection(mox.MessageEvent event, String jid) async {
    final correction = event.extensions.get<mox.LastMessageCorrectionData>();
    if (correction == null) return false;
    await _dbOp<XmppDatabase>((db) async {
      if (await db.messagesAccessor.selectOneByOriginID(correction.id)
          case final message?) {
        if (!message.authorized(event.from) || !message.editable) return;
        await db.messagesAccessor.updateOne(message.copyWith(
          edited: true,
          body: event.extensions.get<mox.MessageBodyData>()?.body,
        ));
      }
    });
    return true;
  }

  Future<bool> _handleRetraction(mox.MessageEvent event, String jid) async {
    final retraction = event.extensions.get<mox.MessageRetractionData>();
    if (retraction == null) return false;
    var retracted = false;
    await _dbOp<XmppDatabase>((db) async {
      if (await db.messagesAccessor.selectOneByOriginID(retraction.id)
          case final message?) {
        if (!message.authorized(event.from)) return;
        if (message.fileMetadataID case final id?) {
          await db.fileMetadataAccessor.deleteOne(id);
        }
        await db.messagesAccessor.updateOne(message.copyWith(
          body: '',
          retracted: true,
          fileMetadataID: null,
          error: MessageError.none,
          warning: MessageWarning.none,
        ));
        retracted = true;
      }
    });
    return retracted;
  }

  Future<bool> _handleReactions(mox.MessageEvent event, String jid) async {
    final reactions = event.extensions.get<mox.MessageReactionsData>();
    if (reactions == null || event.type == 'groupchat') return false;
    await _dbOp<XmppDatabase>((db) async {
      if (await db.messagesAccessor.selectOne(reactions.messageId)
          case final message?) {}
    });
    return true;
  }

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

  Future<bool> _downloadAllowed(String chatJid) async {
    if (!(await Permission.storage.status).isGranted) return false;
    if ((await _connection.getConnectionState()) !=
        mox.XmppConnectionState.connected) return false;
    var allowed = false;
    await _dbOp<XmppDatabase>((db) async {
      allowed = (await db.rosterAccessor.selectOne(chatJid) != null);
    });
    return allowed;
  }
}
