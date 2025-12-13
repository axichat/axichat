part of 'package:axichat/src/xmpp/xmpp_service.dart';

class AvatarUploadPayload {
  const AvatarUploadPayload({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.hash,
    this.jid,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final String hash;
  final String? jid;
}

class AvatarUploadResult {
  const AvatarUploadResult({
    required this.path,
    required this.hash,
  });

  final String path;
  final String hash;
}

mixin AvatarService on XmppBase {
  final _avatarLog = Logger('AvatarService');
  final Set<String> _avatarRefreshInProgress = {};
  Directory? _avatarDirectory;
  final AesGcm _avatarCipher = AesGcm.with256bits();

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      mox.UserAvatarManager(),
      SafeVCardManager(),
    ]);

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.UserAvatarUpdatedEvent>((event) async {
        await _refreshAvatarForJid(
          event.jid.toBare().toString(),
          metadata: event.metadata,
        );
      })
      ..registerHandler<mox.VCardAvatarUpdatedEvent>((event) async {
        final bareJid = event.jid.toBare().toString();
        if (event.hash.isEmpty) {
          await _clearAvatarForJid(bareJid);
          return;
        }
        await _refreshAvatarFromVCard(bareJid, event.hash);
      })
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (event.resumed) return;
        await _refreshRosterAvatarsFromCache();
      });
  }

  void scheduleAvatarRefresh(
    Iterable<String> jids, {
    bool force = false,
  }) {
    for (final jid in jids) {
      unawaited(_refreshAvatarForJid(jid, force: force));
    }
  }

  Future<void> _refreshRosterAvatarsFromCache() async {
    List<String> rosterJids;
    try {
      rosterJids = await _dbOpReturning<XmppDatabase, List<String>>(
        (db) async => (await db.getRoster()).map((item) => item.jid).toList(),
      );
    } on XmppAbortedException {
      return;
    }
    if (rosterJids.isEmpty) return;
    scheduleAvatarRefresh(rosterJids);
  }

  Future<void> _refreshAvatarForJid(
    String jid, {
    bool force = false,
    List<mox.UserAvatarMetadata>? metadata,
  }) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;
    final added = _avatarRefreshInProgress.add(bareJid);
    if (!force && !added) return;
    try {
      final manager = _connection.getManager<mox.UserAvatarManager>();
      if (manager == null) return;

      final existingHash = await _storedAvatarHash(bareJid);
      final selectedMetadata = metadata != null && metadata.isNotEmpty
          ? _selectMetadata(metadata)
          : await _loadMetadata(manager, bareJid);
      if (selectedMetadata == null) return;
      if (!force &&
          existingHash != null &&
          existingHash == selectedMetadata.id) {
        return;
      }

      final avatarDataResult = await manager.getUserAvatarData(
        mox.JID.fromString(bareJid),
        selectedMetadata.id,
      );
      if (avatarDataResult.isType<mox.AvatarError>()) return;
      final avatarData = avatarDataResult.get<mox.UserAvatarData>();
      final bytes = avatarData.data;
      if (bytes.isEmpty) return;

      final path = await _writeAvatarFile(
        hash: avatarData.hash,
        bytes: bytes,
      );

      await _storeAvatar(
        jid: bareJid,
        path: path,
        hash: avatarData.hash,
      );
    } catch (error, stackTrace) {
      _avatarLog.warning('Failed to refresh avatar.', error, stackTrace);
    } finally {
      _avatarRefreshInProgress.remove(bareJid);
    }
  }

  Future<void> _refreshAvatarFromVCard(String jid, String hash) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;
    if (hash.isEmpty) {
      await _clearAvatarForJid(bareJid);
      return;
    }
    final added = _avatarRefreshInProgress.add(bareJid);
    if (!added) return;
    try {
      final existingHash = await _storedAvatarHash(bareJid);
      if (existingHash == hash) return;

      final manager = _connection.getManager<mox.VCardManager>();
      if (manager == null) return;

      final vcardResult =
          await manager.requestVCard(mox.JID.fromString(bareJid));
      if (vcardResult.isType<mox.VCardError>()) return;
      final vcard = vcardResult.get<mox.VCard>();
      final encoded = vcard.photo?.binval?.replaceAll('\n', '').trim();
      if (encoded == null || encoded.isEmpty) return;

      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) return;

      final path = await _writeAvatarFile(
        hash: hash,
        bytes: bytes,
      );

      await _storeAvatar(
        jid: bareJid,
        path: path,
        hash: hash,
      );
    } catch (error, stackTrace) {
      _avatarLog.warning('Failed to refresh vCard avatar.', error, stackTrace);
    } finally {
      _avatarRefreshInProgress.remove(bareJid);
    }
  }

  Future<mox.UserAvatarMetadata?> _loadMetadata(
    mox.UserAvatarManager manager,
    String jid,
  ) async {
    final metadataResult =
        await manager.getLatestMetadata(mox.JID.fromString(jid));
    if (metadataResult.isType<mox.AvatarError>()) return null;
    final items = metadataResult.get<List<mox.UserAvatarMetadata>>();
    if (items.isEmpty) return null;
    return _selectMetadata(items);
  }

  mox.UserAvatarMetadata? _selectMetadata(
    List<mox.UserAvatarMetadata> metadata,
  ) {
    if (metadata.isEmpty) return null;
    final sorted = [...metadata]..sort(
        (a, b) {
          final sizeA = (a.width ?? 0) * (a.height ?? 0);
          final sizeB = (b.width ?? 0) * (b.height ?? 0);
          return sizeB.compareTo(sizeA);
        },
      );
    return sorted.first;
  }

  Future<String?> _storedAvatarHash(String jid) async {
    try {
      final hash = await _dbOpReturning<XmppDatabase, String?>(
        (db) async {
          final roster = await db.getRosterItem(jid);
          if (roster?.avatarHash != null) return roster!.avatarHash;
          final chat = await db.getChat(jid);
          return chat?.avatarHash ?? chat?.contactAvatarHash;
        },
      );
      if (hash != null) return hash;
      final myBareJid = _myJid?.toBare().toString();
      if (myBareJid != null && myBareJid == jid && isStateStoreReady) {
        return await _dbOpReturning<XmppStateStore, String?>(
          (ss) => ss.read(key: selfAvatarHashKey) as String?,
        );
      }
      return null;
    } on XmppAbortedException {
      return null;
    }
  }

  Future<String?> _storedAvatarPath(String jid) async {
    try {
      final path = await _dbOpReturning<XmppDatabase, String?>(
        (db) async {
          final roster = await db.getRosterItem(jid);
          if (roster?.avatarPath != null) return roster!.avatarPath;
          final chat = await db.getChat(jid);
          return chat?.avatarPath ?? chat?.contactAvatarPath;
        },
      );
      if (path != null) return path;
      final myBareJid = _myJid?.toBare().toString();
      if (myBareJid != null && myBareJid == jid && isStateStoreReady) {
        return await _dbOpReturning<XmppStateStore, String?>(
          (ss) => ss.read(key: selfAvatarPathKey) as String?,
        );
      }
      return null;
    } on XmppAbortedException {
      return null;
    }
  }

  Future<void> _clearAvatarForJid(String jid) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;
    final existingPath = await _storedAvatarPath(bareJid);

    await _dbOp<XmppDatabase>(
      (db) async {
        final rosterItem = await db.getRosterItem(bareJid);
        final chat = await db.getChat(bareJid);
        if (rosterItem != null) {
          await db.updateRosterAvatar(
            jid: bareJid,
            avatarPath: null,
            avatarHash: null,
          );
        }
        if (chat != null) {
          await db.updateChatAvatar(
            jid: bareJid,
            avatarPath: null,
            avatarHash: null,
          );
        }
      },
      awaitDatabase: true,
    );

    final myBareJid = _myJid?.toBare().toString();
    if (myBareJid != null && myBareJid == bareJid && isStateStoreReady) {
      await _dbOp<XmppStateStore>(
        (ss) async {
          await ss.write(key: selfAvatarPathKey, value: null);
          await ss.write(key: selfAvatarHashKey, value: null);
        },
        awaitDatabase: true,
      );
      owner._notifySelfAvatarUpdated(null);
    }

    if (existingPath != null && existingPath.isNotEmpty) {
      final file = File(existingPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } on Exception catch (error, stackTrace) {
          _avatarLog.fine('Failed to delete avatar file', error, stackTrace);
        }
      }
    }
  }

  Future<void> _storeAvatar({
    required String jid,
    required String path,
    required String hash,
  }) async {
    final myBareJid = _myJid?.toBare().toString();
    await _dbOp<XmppDatabase>(
      (db) async {
        final rosterItem = await db.getRosterItem(jid);
        final chat = await db.getChat(jid);
        if (rosterItem != null) {
          await db.updateRosterAvatar(
            jid: jid,
            avatarPath: path,
            avatarHash: hash,
          );
        }
        if (chat != null) {
          await db.updateChatAvatar(
            jid: jid,
            avatarPath: path,
            avatarHash: hash,
          );
        }
      },
      awaitDatabase: true,
    );
    if (myBareJid != null && myBareJid == jid) {
      await _persistOwnAvatar(path, hash);
      owner._notifySelfAvatarUpdated(StoredAvatar(path: path, hash: hash));
    }
  }

  Future<void> _persistOwnAvatar(String path, String hash) async {
    if (!isStateStoreReady) return;
    try {
      await _dbOp<XmppStateStore>(
        (ss) async {
          await ss.write(key: selfAvatarPathKey, value: path);
          await ss.write(key: selfAvatarHashKey, value: hash);
        },
        awaitDatabase: true,
      );
    } on XmppAbortedException {
      return;
    }
  }

  Future<AvatarUploadResult> publishAvatar(
    AvatarUploadPayload payload, {
    bool public = false,
  }) async {
    final manager = _connection.getManager<mox.UserAvatarManager>();
    final targetJid = _avatarSafeBareJid(payload.jid ?? myJid);
    if (manager == null || targetJid == null) {
      throw XmppAvatarException();
    }
    try {
      return await _publishAvatarOnce(
        manager,
        payload: payload,
        targetJid: targetJid,
        public: public,
      );
    } on XmppAvatarException catch (error, stackTrace) {
      final cause = error.wrapped;
      if (cause is mox.AvatarError) {
        final retryPublic = !public;
        try {
          return await _publishAvatarOnce(
            manager,
            payload: payload,
            targetJid: targetJid,
            public: retryPublic,
          );
        } on XmppAvatarException catch (retryError, retryStackTrace) {
          final retryCause = retryError.wrapped;
          final isAvatarError = retryCause is mox.AvatarError;
          final log = isAvatarError ? _avatarLog.warning : _avatarLog.severe;
          log(
            'Failed to publish avatar',
            retryError,
            isAvatarError ? null : retryStackTrace,
          );
          rethrow;
        } catch (retryError, retryStackTrace) {
          _avatarLog.severe(
              'Failed to publish avatar', retryError, retryStackTrace);
          throw XmppAvatarException(retryError);
        }
      }

      final isAvatarError = cause is mox.AvatarError;
      final log = isAvatarError ? _avatarLog.warning : _avatarLog.severe;
      log('Failed to publish avatar', error, isAvatarError ? null : stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      _avatarLog.severe('Failed to publish avatar', error, stackTrace);
      throw XmppAvatarException(error);
    }
  }

  Future<AvatarUploadResult> _publishAvatarOnce(
    mox.UserAvatarManager manager, {
    required AvatarUploadPayload payload,
    required String targetJid,
    required bool public,
  }) async {
    final dataResult = await manager.publishUserAvatar(
      base64Encode(payload.bytes),
      payload.hash,
      public,
    );
    if (dataResult.isType<mox.AvatarError>()) {
      throw XmppAvatarException(dataResult.get<mox.AvatarError>());
    }

    final metadataResult = await manager.publishUserAvatarMetadata(
      mox.UserAvatarMetadata(
        payload.hash,
        payload.bytes.length,
        payload.width,
        payload.height,
        payload.mimeType,
        null,
      ),
      public,
    );
    if (metadataResult.isType<mox.AvatarError>()) {
      throw XmppAvatarException(metadataResult.get<mox.AvatarError>());
    }

    final path = await _writeAvatarFile(
      hash: payload.hash,
      bytes: payload.bytes,
    );
    await _storeAvatar(jid: targetJid, path: path, hash: payload.hash);
    final vCardManager = _connection.getManager<mox.VCardManager>();
    vCardManager?.setLastHash(targetJid, payload.hash);

    return AvatarUploadResult(path: path, hash: payload.hash);
  }

  Future<Uint8List?> loadAvatarBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final isEncrypted = p.extension(path).toLowerCase() == '.enc';
      if (!isEncrypted) {
        return bytes;
      }
      if (avatarEncryptionKey == null) {
        _avatarLog.warning('Avatar key unavailable; cannot decrypt $path');
        return null;
      }
      return await _decryptAvatarBytes(bytes);
    } catch (error, stackTrace) {
      _avatarLog.warning(
        'Failed to load avatar from $path; deleting corrupted cache entry.',
        error,
        stackTrace,
      );
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
  }

  Future<Uint8List> _encryptAvatarBytes(List<int> bytes) async {
    final key = avatarEncryptionKey;
    if (key == null) {
      throw XmppAvatarException('Avatar encryption key unavailable');
    }
    final nonce = secureBytes(12);
    final secretBox = await _avatarCipher.encrypt(
      bytes,
      secretKey: key,
      nonce: nonce,
    );
    final macBytes = secretBox.mac.bytes;
    final combinedLength =
        nonce.length + secretBox.cipherText.length + macBytes.length;
    final combined = Uint8List(combinedLength)
      ..setRange(0, nonce.length, nonce)
      ..setRange(
        nonce.length,
        nonce.length + secretBox.cipherText.length,
        secretBox.cipherText,
      )
      ..setRange(
        combinedLength - macBytes.length,
        combinedLength,
        macBytes,
      );
    return combined;
  }

  Future<Uint8List> _decryptAvatarBytes(Uint8List encrypted) async {
    final key = avatarEncryptionKey;
    if (key == null) {
      throw XmppAvatarException('Avatar decryption key unavailable');
    }
    const nonceLength = 12;
    const macLength = 16;
    if (encrypted.length <= nonceLength + macLength) {
      throw XmppAvatarException('Encrypted avatar payload too small');
    }
    final nonce = encrypted.sublist(0, nonceLength);
    final macBytes = encrypted.sublist(encrypted.length - macLength);
    final cipherText =
        encrypted.sublist(nonceLength, encrypted.length - macLength);
    final box = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final decrypted = await _avatarCipher.decrypt(
      box,
      secretKey: key,
    );
    return Uint8List.fromList(decrypted);
  }

  Future<String> _writeAvatarFile({
    required String hash,
    required List<int> bytes,
  }) async {
    final directory = await _avatarCacheDirectory();
    final filename = '$hash.enc';
    final file = File(p.join(directory.path, filename));
    final encrypted = await _encryptAvatarBytes(bytes);
    await file.writeAsBytes(encrypted, flush: true);
    return file.path;
  }

  Future<Directory> _avatarCacheDirectory() async {
    final cached = _avatarDirectory;
    if (cached != null && await cached.exists()) {
      return cached;
    }
    final supportDir = await getApplicationSupportDirectory();
    final directory = Directory(p.join(supportDir.path, 'avatars'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _avatarDirectory = directory;
    return directory;
  }

  String? _avatarSafeBareJid(String? jid) {
    if (jid == null || jid.isEmpty) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } on Exception {
      return null;
    }
  }
}
