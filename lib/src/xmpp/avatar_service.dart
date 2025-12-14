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
  static const int _maxAvatarBytes = 512 * 1024;
  static const int _maxAvatarBase64Length = ((_maxAvatarBytes + 2) ~/ 3) * 4;
  static const int _avatarBytesCacheLimit = 64;
  static const Duration _avatarPublishTimeout = Duration(seconds: 30);
  final LinkedHashMap<String, Uint8List> _avatarBytesCache = LinkedHashMap();

  Uint8List? cachedAvatarBytes(String path) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return null;
    final bytes = _avatarBytesCache.remove(normalizedPath);
    if (bytes == null) return null;
    _avatarBytesCache[normalizedPath] = bytes;
    return bytes;
  }

  void _cacheAvatarBytes(String path, Uint8List bytes) {
    if (bytes.isEmpty) return;
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return;
    _avatarBytesCache.remove(normalizedPath);
    _avatarBytesCache[normalizedPath] = bytes;
    while (_avatarBytesCache.length > _avatarBytesCacheLimit) {
      _avatarBytesCache.remove(_avatarBytesCache.keys.first);
    }
  }

  void _evictCachedAvatarBytes(String path) {
    _avatarBytesCache.remove(path.trim());
  }

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
      if (bytes.length > _maxAvatarBytes) return;

      final path = await _writeAvatarFile(
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
      final rawEncoded = vcard.photo?.binval?.trim();
      if (rawEncoded == null || rawEncoded.isEmpty) return;
      if (rawEncoded.length > _maxAvatarBase64Length * 2) return;
      final encoded = rawEncoded.replaceAll(RegExp(r'\s+'), '');
      if (encoded.isEmpty) return;
      if (encoded.length > _maxAvatarBase64Length) return;

      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) return;
      if (bytes.length > _maxAvatarBytes) return;

      final path = await _writeAvatarFile(
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
    final filtered = metadata
        .where((item) => item.length > 0 && item.length <= _maxAvatarBytes);
    if (filtered.isEmpty) return null;
    final sorted = [...filtered]..sort(
        (a, b) {
          final sizeA = (a.width ?? 0) * (a.height ?? 0);
          final sizeB = (b.width ?? 0) * (b.height ?? 0);
          final dimensionCompare = sizeB.compareTo(sizeA);
          if (dimensionCompare != 0) return dimensionCompare;
          return b.length.compareTo(a.length);
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
      _evictCachedAvatarBytes(existingPath);
      final cacheDirectory = await _avatarCacheDirectory();
      if (!_isSafeAvatarCachePath(
        cacheDirectory: cacheDirectory,
        filePath: existingPath,
      )) {
        _avatarLog
            .warning('Refusing to delete avatar outside cache directory.');
        return;
      }
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
    final targetJid = _avatarSafeBareJid(payload.jid ?? myJid);
    if (targetJid == null) {
      throw XmppAvatarException();
    }
    try {
      return await _publishAvatarOnce(
        payload: payload,
        targetJid: targetJid,
        public: public,
      );
    } on XmppAvatarException catch (error, stackTrace) {
      final cause = error.wrapped;
      if (cause is mox.AvatarError || cause is mox.PubSubError) {
        final retryPublic = !public;
        try {
          return await _publishAvatarOnce(
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

  Future<AvatarUploadResult> _publishAvatarOnce({
    required AvatarUploadPayload payload,
    required String targetJid,
    required bool public,
  }) async {
    const openAccessModel = 'open';
    const rosterAccessModel = 'roster';
    final pubsub = _connection.getManager<mox.PubSubManager>();
    if (pubsub == null) {
      throw XmppAvatarException('PubSub is unavailable');
    }
    final host = mox.JID.fromString(targetJid);
    final accessModel = public ? openAccessModel : rosterAccessModel;
    final publishOptions = mox.PubSubPublishOptions(accessModel: accessModel);

    final dataPayload =
        (mox.XmlBuilder.withNamespace('data', mox.userAvatarDataXmlns)
              ..text(base64Encode(payload.bytes)))
            .build();
    final dataResult = await pubsub
        .publish(
          host,
          mox.userAvatarDataXmlns,
          dataPayload,
          id: payload.hash,
          options: publishOptions,
          autoCreate: true,
        )
        .timeout(_avatarPublishTimeout);
    if (dataResult.isType<mox.PubSubError>()) {
      throw XmppAvatarException(dataResult.get<mox.PubSubError>());
    }

    final metadataPayload =
        (mox.XmlBuilder.withNamespace('metadata', mox.userAvatarMetadataXmlns)
              ..child(
                (mox.XmlBuilder('info')
                      ..attr('bytes', payload.bytes.length.toString())
                      ..attr('height', payload.height.toString())
                      ..attr('width', payload.width.toString())
                      ..attr('type', payload.mimeType)
                      ..attr('id', payload.hash))
                    .build(),
              ))
            .build();
    final metadataResult = await pubsub
        .publish(
          host,
          mox.userAvatarMetadataXmlns,
          metadataPayload,
          id: payload.hash,
          options: publishOptions,
          autoCreate: true,
        )
        .timeout(_avatarPublishTimeout);
    if (metadataResult.isType<mox.PubSubError>()) {
      throw XmppAvatarException(metadataResult.get<mox.PubSubError>());
    }

    final path = await _writeAvatarFile(
      bytes: payload.bytes,
    );
    await _storeAvatar(jid: targetJid, path: path, hash: payload.hash);
    final vCardManager = _connection.getManager<mox.VCardManager>();
    vCardManager?.setLastHash(targetJid, payload.hash);

    return AvatarUploadResult(path: path, hash: payload.hash);
  }

  Future<Uint8List?> loadAvatarBytes(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return null;

    final cacheDirectory = await _avatarCacheDirectory();
    if (!_isSafeAvatarCachePath(
      cacheDirectory: cacheDirectory,
      filePath: normalizedPath,
    )) {
      _avatarLog.warning('Rejected avatar path outside cache directory.');
      _evictCachedAvatarBytes(normalizedPath);
      return null;
    }

    final cached = cachedAvatarBytes(normalizedPath);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final file = File(normalizedPath);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final isEncrypted = p.extension(normalizedPath).toLowerCase() == '.enc';
      if (!isEncrypted) {
        _cacheAvatarBytes(normalizedPath, bytes);
        return bytes;
      }
      if (avatarEncryptionKey == null) {
        _avatarLog.warning(
          'Avatar key unavailable; cannot decrypt cached avatar.',
        );
        return null;
      }
      final decrypted = await _decryptAvatarBytes(bytes);
      if (decrypted.isEmpty) return null;
      _cacheAvatarBytes(normalizedPath, decrypted);
      return decrypted;
    } catch (error, stackTrace) {
      _avatarLog.warning(
        'Failed to load cached avatar; deleting corrupted cache entry.',
        error,
        stackTrace,
      );
      _evictCachedAvatarBytes(normalizedPath);
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
    required List<int> bytes,
  }) async {
    final directory = await _avatarCacheDirectory();
    final contentHash = sha256.convert(bytes).toString();
    final filename = '$contentHash.enc';
    final file = File(p.join(directory.path, filename));
    final encrypted = await _encryptAvatarBytes(bytes);
    await file.writeAsBytes(encrypted, flush: true);
    final rawBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    _cacheAvatarBytes(file.path, rawBytes);
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

  bool _isSafeAvatarCachePath({
    required Directory cacheDirectory,
    required String filePath,
  }) {
    final normalizedFile = p.normalize(filePath.trim());
    if (normalizedFile.isEmpty) return false;
    if (!p.isAbsolute(normalizedFile)) return false;
    final normalizedRoot = p.normalize(cacheDirectory.path);
    return p.isWithin(normalizedRoot, normalizedFile);
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
