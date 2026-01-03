// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

String _base64EncodeAvatarPublishPayload(Uint8List bytes) =>
    base64Encode(bytes);

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

sealed class _AvatarMetadataLoadResult {
  const _AvatarMetadataLoadResult();
}

final class _AvatarMetadataLoaded extends _AvatarMetadataLoadResult {
  const _AvatarMetadataLoaded(this.metadata);

  final mox.UserAvatarMetadata metadata;
}

final class _AvatarMetadataMissing extends _AvatarMetadataLoadResult {
  const _AvatarMetadataMissing();
}

final class _AvatarMetadataLoadFailed extends _AvatarMetadataLoadResult {
  const _AvatarMetadataLoadFailed();
}

mixin AvatarService on XmppBase {
  final _avatarLog = Logger('AvatarService');
  final Set<String> _avatarRefreshInProgress = {};
  final Set<String> _configuredAvatarNodes = {};
  final Map<String, DateTime> _conversationAvatarRefreshAttempts = {};
  Directory? _avatarDirectory;
  final AesGcm _avatarCipher = AesGcm.with256bits();
  static const int _maxAvatarBytes = 512 * 1024;
  static const int _maxAvatarBase64Length = ((_maxAvatarBytes + 2) ~/ 3) * 4;
  static const int _avatarBytesCacheLimit = 64;
  static const int _safeAvatarBytesCacheLimit = _avatarBytesCacheLimit;
  static const int _conversationAvatarChatStart = 0;
  static const int _conversationAvatarChatEnd = 0;
  static const Duration _conversationAvatarRefreshCooldown =
      Duration(minutes: 2);
  static const Duration _avatarPublishTimeout = Duration(seconds: 30);
  static const String _avatarConfigKeySeparator = '|';
  static const int _avatarPublishVerificationAttempts = 2;
  static const Duration _avatarPublishVerificationDelay =
      Duration(milliseconds: 350);
  static const Duration _avatarPublishVerificationTimeout =
      Duration(seconds: 5);
  static const Duration _selfAvatarRefreshInterval = Duration(minutes: 1);
  static const bool _allowAvatarPublisherFallback = true;
  static const String _mimePng = 'image/png';
  static const String _mimeJpeg = 'image/jpeg';
  static const List<int> _pngMagicBytes = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];
  static const List<int> _jpegMagicBytes = <int>[0xFF, 0xD8, 0xFF];
  final LinkedHashMap<String, Uint8List> _avatarBytesCache = LinkedHashMap();
  final LinkedHashMap<String, Uint8List> _safeAvatarBytesCache =
      LinkedHashMap();
  Timer? _selfAvatarRefreshTimer;
  bool _selfAvatarRepairAttempted = false;

  Uint8List? cachedAvatarBytes(String path) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return null;
    final bytes = _avatarBytesCache.remove(normalizedPath);
    if (bytes == null) return null;
    _avatarBytesCache[normalizedPath] = bytes;
    return bytes;
  }

  Uint8List? cachedSafeAvatarBytes(String path) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return null;
    final bytes = _safeAvatarBytesCache.remove(normalizedPath);
    if (bytes == null) return null;
    _safeAvatarBytesCache[normalizedPath] = bytes;
    return bytes;
  }

  void cacheSafeAvatarBytes(String path, Uint8List bytes) {
    _cacheSafeAvatarBytes(path, bytes);
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

  void _cacheSafeAvatarBytes(String path, Uint8List bytes) {
    if (bytes.isEmpty) return;
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return;
    _safeAvatarBytesCache.remove(normalizedPath);
    _safeAvatarBytesCache[normalizedPath] = bytes;
    while (_safeAvatarBytesCache.length > _safeAvatarBytesCacheLimit) {
      _safeAvatarBytesCache.remove(_safeAvatarBytesCache.keys.first);
    }
  }

  void _evictCachedAvatarBytes(String path) {
    _avatarBytesCache.remove(path.trim());
    _evictCachedSafeAvatarBytes(path);
  }

  void _evictCachedSafeAvatarBytes(String path) {
    _safeAvatarBytesCache.remove(path.trim());
  }

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      SafeUserAvatarManager(),
      SafeVCardManager(),
    ]);

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.UserAvatarUpdatedEvent>((event) async {
        final bareJid = event.jid.toBare().toString();
        if (event.metadata.isEmpty) {
          await _clearAvatarForJid(bareJid);
          return;
        }

        await _refreshAvatarForJid(
          bareJid,
          metadata: event.metadata,
        );
      })
      ..registerHandler<ConversationIndexItemUpdatedEvent>((event) async {
        if (connectionState != ConnectionState.connected) return;
        final peerJid = event.item.peerBare.toBare().toString();
        if (peerJid.isEmpty) return;
        if (peerJid == myJid) return;
        if (!await _shouldRefreshConversationAvatar(peerJid)) return;
        unawaited(_refreshConversationAvatars([peerJid]));
      })
      ..registerHandler<mox.VCardAvatarUpdatedEvent>((event) async {
        final bareJid = event.jid.toBare().toString();
        if (event.hash.isEmpty) {
          await _clearAvatarForJid(bareJid);
          return;
        }
        await _refreshAvatarFromVCard(bareJid, event.hash);
      })
      ..registerHandler<mox.PubSubItemsRetractedEvent>((event) async {
        final node = event.node;
        if (node != mox.userAvatarMetadataXmlns &&
            node != mox.userAvatarDataXmlns) {
          return;
        }

        final bareJid = _avatarSafeBareJid(event.from);
        if (bareJid == null) return;

        final existingHash = await _storedAvatarHash(bareJid);
        if (existingHash == null || existingHash.trim().isEmpty) return;
        if (!event.itemIds.contains(existingHash)) return;

        await _clearAvatarForJid(bareJid);
      })
      ..registerHandler<mox.PubSubNodeDeletedEvent>((event) async {
        final node = event.node;
        if (node != mox.userAvatarMetadataXmlns &&
            node != mox.userAvatarDataXmlns) {
          return;
        }

        final bareJid = _avatarSafeBareJid(event.from);
        if (bareJid == null) return;

        await _clearAvatarForJid(bareJid);
      })
      ..registerHandler<mox.PubSubNodePurgedEvent>((event) async {
        final node = event.node;
        if (node != mox.userAvatarMetadataXmlns &&
            node != mox.userAvatarDataXmlns) {
          return;
        }

        final bareJid = _avatarSafeBareJid(event.from);
        if (bareJid == null) return;

        await _clearAvatarForJid(bareJid);
      })
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        _startSelfAvatarRefreshTimer();
        if (avatarEncryptionKey != null) {
          unawaited(_notifyCachedSelfAvatarIfAvailable());
          unawaited(refreshSelfAvatarIfNeeded());
        }
        if (event.resumed) return;
        await _refreshRosterAvatarsFromCache();
      });
  }

  Future<void> cacheSelfAvatarDraft(AvatarUploadPayload payload) async {
    final myBareJid = _myJid?.toBare().toString();
    if (myBareJid == null || myBareJid.isEmpty) return;
    final targetJid = _avatarSafeBareJid(payload.jid ?? myJid);
    if (targetJid == null || targetJid != myBareJid) return;
    if (!isStateStoreReady || avatarEncryptionKey == null) return;

    try {
      final path = await _writeAvatarFile(bytes: payload.bytes);
      await _persistOwnAvatar(path, payload.hash);
      owner._notifySelfAvatarUpdated(
        StoredAvatar(path: path, hash: payload.hash),
      );
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine(
        'Failed to cache pending self avatar for immediate display.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> _reset() async {
    _avatarRefreshInProgress.clear();
    _configuredAvatarNodes.clear();
    _avatarBytesCache.clear();
    _safeAvatarBytesCache.clear();
    _avatarDirectory = null;
    _selfAvatarRepairAttempted = false;
    _selfAvatarRefreshTimer?.cancel();
    _selfAvatarRefreshTimer = null;
    await super._reset();
  }

  void _startSelfAvatarRefreshTimer() {
    _selfAvatarRefreshTimer?.cancel();
    _selfAvatarRefreshTimer = Timer.periodic(
      _selfAvatarRefreshInterval,
      (_) {
        if (connectionState != ConnectionState.connected) return;
        if (avatarEncryptionKey == null) return;
        unawaited(refreshSelfAvatarIfNeeded());
      },
    );
  }

  void scheduleAvatarRefresh(
    Iterable<String> jids, {
    bool force = false,
  }) {
    for (final jid in jids) {
      unawaited(_refreshAvatarForJid(jid, force: force));
    }
  }

  Future<void> _refreshConversationAvatars(Iterable<String> jids) async {
    if (jids.isEmpty) return;
    scheduleAvatarRefresh(jids);
  }

  Future<bool> _shouldRefreshConversationAvatar(String jid) async {
    final now = DateTime.timestamp();
    final lastAttempt = _conversationAvatarRefreshAttempts[jid];
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _conversationAvatarRefreshCooldown) {
      return false;
    }

    final existingHash = await _storedAvatarHash(jid);
    if (existingHash != null && existingHash.trim().isNotEmpty) {
      final existingPath = await _storedAvatarPath(jid);
      if (await _hasCachedAvatarFile(existingPath)) {
        return false;
      }
    }

    _conversationAvatarRefreshAttempts[jid] = now;
    return true;
  }

  Future<void> refreshAvatarsForConversationIndex() async {
    if (connectionState != ConnectionState.connected) return;
    List<Chat> chats;
    try {
      chats = await _dbOpReturning<XmppDatabase, List<Chat>>(
        (db) => db.getChats(
          start: _conversationAvatarChatStart,
          end: _conversationAvatarChatEnd,
        ),
      );
    } on XmppAbortedException {
      return;
    }
    final directJids = <String>{};
    for (final chat in chats) {
      if (!chat.transport.isXmpp) continue;
      if (chat.type != ChatType.chat) continue;
      final jid = chat.remoteJid.trim();
      if (jid.isEmpty) continue;
      directJids.add(jid);
    }
    if (directJids.isNotEmpty) {
      await _refreshConversationAvatars(directJids);
    }
    await refreshSelfAvatarIfNeeded(force: true);
  }

  Future<void> storeAvatarBytesForJid({
    required String jid,
    required Uint8List bytes,
    String? hash,
  }) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;
    if (bytes.isEmpty) return;
    if (bytes.length > _maxAvatarBytes) return;
    if (!_isSupportedAvatarBytes(bytes)) return;
    final resolvedHash = _resolveAvatarHash(bytes, hash);
    try {
      final existingHash = await _storedAvatarHash(bareJid);
      if (existingHash != null && existingHash == resolvedHash) {
        final existingPath = await _storedAvatarPath(bareJid);
        if (await _hasCachedAvatarFile(existingPath)) {
          return;
        }
      }
      final path = await _writeAvatarFile(bytes: bytes);
      await _storeAvatar(jid: bareJid, path: path, hash: resolvedHash);
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine('Failed to store avatar bytes.', error, stackTrace);
    }
  }

  String _resolveAvatarHash(Uint8List bytes, String? hash) {
    final trimmed = hash?.trim();
    if (trimmed?.isNotEmpty == true) return trimmed!;
    return sha1.convert(bytes).toString();
  }

  Future<void> prefetchAvatarForJid(String jid) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;

    switch (await _loadMetadata(bareJid)) {
      case final _AvatarMetadataLoaded loaded:
        await _refreshAvatarForJid(
          bareJid,
          metadata: [loaded.metadata],
        );
      case _AvatarMetadataMissing():
        await _refreshAvatarFromVCardRequest(bareJid);
      case _AvatarMetadataLoadFailed():
        await _refreshAvatarFromVCardRequest(bareJid);
    }
  }

  Future<void> refreshSelfAvatarIfNeeded({bool force = false}) async {
    final bareJid = _myJid?.toBare().toString();
    if (bareJid == null || bareJid.isEmpty) return;
    await _refreshAvatarForJid(bareJid, force: force);
  }

  Future<void> _notifyCachedSelfAvatarIfAvailable() async {
    if (!isStateStoreReady) return;
    final myBareJid = _myJid?.toBare().toString();
    if (myBareJid == null || myBareJid.isEmpty) return;
    if (avatarEncryptionKey == null) return;

    try {
      final stored = await _dbOpReturning<XmppStateStore, StoredAvatar?>(
        (ss) async {
          final path = ss.read(key: selfAvatarPathKey) as String?;
          final hash = ss.read(key: selfAvatarHashKey) as String?;
          if (path == null && hash == null) return null;
          return StoredAvatar(path: path, hash: hash);
        },
      );
      if (stored == null || stored.isEmpty) return;
      final path = stored.path?.trim();
      if (path == null || path.isEmpty) return;
      if (!await _hasCachedAvatarFile(path)) return;

      owner._notifySelfAvatarUpdated(
        StoredAvatar(path: path, hash: stored.hash),
      );
    } on XmppAbortedException {
      return;
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine(
        'Failed to load cached self avatar reference.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _refreshAvatarFromVCardRequest(
    String bareJid, {
    bool force = false,
  }) async {
    final normalizedJid = bareJid.trim();
    if (normalizedJid.isEmpty) return;
    final added = _avatarRefreshInProgress.add(normalizedJid);
    if (!force && !added) return;
    try {
      final manager = _connection.getManager<mox.VCardManager>();
      if (manager == null) return;

      final vcardResult =
          await manager.requestVCard(mox.JID.fromString(normalizedJid));
      if (vcardResult.isType<mox.VCardError>()) return;
      final vcard = vcardResult.get<mox.VCard>();
      final rawEncoded = vcard.photo?.binval?.trim();
      if (rawEncoded == null || rawEncoded.isEmpty) return;
      if (rawEncoded.length > _maxAvatarBase64Length * 2) return;
      final encoded = rawEncoded.replaceAll(RegExp(r'\s+'), '');
      if (encoded.isEmpty) return;
      if (encoded.length > _maxAvatarBase64Length) return;

      Uint8List bytes;
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        return;
      }
      if (bytes.isEmpty) return;
      if (bytes.length > _maxAvatarBytes) return;
      if (!_isSupportedAvatarBytes(bytes)) return;

      final hash = sha1.convert(bytes).toString();
      if (!force) {
        final existingHash = await _storedAvatarHash(normalizedJid);
        if (existingHash != null && existingHash == hash) {
          final existingPath = await _storedAvatarPath(normalizedJid);
          if (await _hasCachedAvatarFile(existingPath)) {
            return;
          }
        }
      }

      final path = await _writeAvatarFile(bytes: bytes);
      await _storeAvatar(jid: normalizedJid, path: path, hash: hash);
    } catch (error, stackTrace) {
      _avatarLog.warning('Failed to refresh vCard avatar.', error, stackTrace);
    } finally {
      _avatarRefreshInProgress.remove(normalizedJid);
    }
  }

  bool _isSupportedAvatarBytes(Uint8List bytes) =>
      _matchesSignature(bytes, _pngMagicBytes) ||
      _matchesSignature(bytes, _jpegMagicBytes);

  bool _matchesSignature(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
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

      final myBareJid = _myJid?.toBare().toString();
      final isSelf = myBareJid != null && myBareJid == bareJid;
      final existingHash = await _storedAvatarHash(bareJid);
      if (metadata != null && metadata.isEmpty) {
        await _clearAvatarForJid(bareJid);
        return;
      }

      mox.UserAvatarMetadata? selectedMetadata;
      if (metadata != null) {
        selectedMetadata = _selectMetadata(metadata);
      } else {
        switch (await _loadMetadata(bareJid)) {
          case final _AvatarMetadataLoaded loaded:
            selectedMetadata = loaded.metadata;
          case _AvatarMetadataMissing():
            if (isSelf) {
              await _maybeRepairSelfAvatar(bareJid);
              return;
            }
            await _refreshAvatarFromVCardRequest(bareJid, force: true);
            return;
          case _AvatarMetadataLoadFailed():
            if (!isSelf) {
              await _refreshAvatarFromVCardRequest(bareJid, force: true);
            }
            return;
        }
      }
      if (selectedMetadata == null) return;
      if (!force &&
          existingHash != null &&
          existingHash == selectedMetadata.id) {
        final existingPath = await _storedAvatarPath(bareJid);
        if (await _hasCachedAvatarFile(existingPath)) {
          return;
        }
      }

      final avatarDataResult = await manager.getUserAvatarData(
        mox.JID.fromString(bareJid),
        selectedMetadata.id,
      );
      if (avatarDataResult.isType<mox.AvatarError>()) return;
      final avatarData = avatarDataResult.get<mox.UserAvatarData>();
      Uint8List bytes;
      try {
        final normalized = avatarData.base64.replaceAll(RegExp(r'\s+'), '');
        bytes = base64Decode(normalized);
      } on FormatException {
        return;
      }
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
      if (existingHash == hash) {
        final existingPath = await _storedAvatarPath(bareJid);
        if (await _hasCachedAvatarFile(existingPath)) {
          return;
        }
      }

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

  Future<_AvatarMetadataLoadResult> _loadMetadata(String jid) async {
    final pubsub = _connection.getManager<mox.PubSubManager>();
    if (pubsub == null) return const _AvatarMetadataLoadFailed();
    const maxMetadataItems = 1;
    const metadataInfoTag = 'info';

    Future<moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>> getItems(
      int? maxItems,
    ) async =>
        pubsub.getItems(
          mox.JID.fromString(jid),
          mox.userAvatarMetadataXmlns,
          maxItems: maxItems,
        );

    var result = await getItems(maxMetadataItems);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final shouldRetry = error is mox.EjabberdMaxItemsError ||
          error is mox.MalformedResponseError ||
          error is mox.UnknownPubSubError;
      if (shouldRetry) {
        result = await getItems(null);
      }
    }

    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      if (error is mox.ItemNotFoundError || error is mox.NoItemReturnedError) {
        return const _AvatarMetadataMissing();
      }
      return const _AvatarMetadataLoadFailed();
    }

    final items = result.get<List<mox.PubSubItem>>();
    if (items.isEmpty) return const _AvatarMetadataMissing();

    final filteredItems = _filterAvatarItemsByPublisher(
      items: items,
      ownerBare: jid,
    );
    if (filteredItems.isEmpty) return const _AvatarMetadataMissing();

    final payload = filteredItems.first.payload;
    if (payload == null) return const _AvatarMetadataLoadFailed();

    final metadata = payload
        .findTags(metadataInfoTag)
        .map(mox.UserAvatarMetadata.fromXML)
        .toList();
    if (metadata.isEmpty) return const _AvatarMetadataMissing();

    final selected = _selectMetadata(metadata);
    if (selected == null) return const _AvatarMetadataLoadFailed();

    return _AvatarMetadataLoaded(selected);
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
    bool public = true,
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
        if (!public) {
          rethrow;
        }
        const retryPublic = false;
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
    const presenceAccessModel = 'presence';
    const avatarDataTag = 'data';
    const avatarMetadataTag = 'metadata';
    const avatarMetadataInfoTag = 'info';
    const publishModelPublishers = 'publishers';
    const maxPublishedAvatarItems = '1';
    const sendLastPublishedItemOnSubscribe = 'on_subscribe';
    const sendLastPublishedItemNever = 'never';
    const publishNotRetrievableMessage =
        'Avatar publish succeeded but is not retrievable';
    const notifyEnabled = true;
    const notifyDisabled = false;
    const deliverNotificationsEnabled = true;
    const deliverNotificationsDisabled = false;
    const deliverPayloadsEnabled = true;
    const deliverPayloadsDisabled = false;
    const persistItemsEnabled = true;
    const presenceBasedDeliveryEnabled = true;
    const presenceBasedDeliveryDisabled = false;
    final presenceBasedDelivery =
        public ? presenceBasedDeliveryDisabled : presenceBasedDeliveryEnabled;
    final pubsub = _connection.getManager<SafePubSubManager>();
    if (pubsub == null) {
      throw XmppAvatarException('PubSub is unavailable');
    }
    final host = mox.JID.fromString(targetJid);
    final accessModel = public ? openAccessModel : presenceAccessModel;
    final dataPublishOptions = mox.PubSubPublishOptions(
      accessModel: accessModel,
      maxItems: maxPublishedAvatarItems,
      persistItems: persistItemsEnabled,
      publishModel: publishModelPublishers,
      sendLastPublishedItem: sendLastPublishedItemNever,
    );
    final metadataPublishOptions = mox.PubSubPublishOptions(
      accessModel: accessModel,
      maxItems: maxPublishedAvatarItems,
      persistItems: persistItemsEnabled,
      publishModel: publishModelPublishers,
      sendLastPublishedItem: sendLastPublishedItemOnSubscribe,
    );
    final createNodeAccessModel =
        public ? mox.AccessModel.open : mox.AccessModel.presence;
    final dataNodeConfig = AxiPubSubNodeConfig(
      accessModel: createNodeAccessModel,
      publishModel: publishModelPublishers,
      deliverNotifications: deliverNotificationsDisabled,
      deliverPayloads: deliverPayloadsDisabled,
      maxItems: maxPublishedAvatarItems,
      notifyRetract: notifyDisabled,
      notifyDelete: notifyDisabled,
      notifyConfig: notifyDisabled,
      notifySub: notifyDisabled,
      presenceBasedDelivery: presenceBasedDelivery,
      persistItems: persistItemsEnabled,
      sendLastPublishedItem: sendLastPublishedItemNever,
    );
    final metadataNodeConfig = AxiPubSubNodeConfig(
      accessModel: createNodeAccessModel,
      publishModel: publishModelPublishers,
      deliverNotifications: deliverNotificationsEnabled,
      deliverPayloads: deliverPayloadsEnabled,
      maxItems: maxPublishedAvatarItems,
      notifyRetract: notifyEnabled,
      notifyDelete: notifyEnabled,
      notifyConfig: notifyEnabled,
      notifySub: notifyEnabled,
      presenceBasedDelivery: presenceBasedDelivery,
      persistItems: persistItemsEnabled,
      sendLastPublishedItem: sendLastPublishedItemOnSubscribe,
    );

    final encodedData = await compute(
      _base64EncodeAvatarPublishPayload,
      payload.bytes,
    );
    final dataPayload =
        (mox.XmlBuilder.withNamespace('data', mox.userAvatarDataXmlns)
              ..text(encodedData))
            .build();
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

    Future<void> ensureNodeConfigured({
      required String node,
      required AxiPubSubNodeConfig config,
    }) async {
      final cacheKey = _avatarConfigKey(
        node: node,
        accessModel: config.accessModel,
      );
      if (_configuredAvatarNodes.contains(cacheKey)) return;

      final configured = await pubsub
          .configureNode(host, node, config)
          .timeout(_avatarPublishTimeout);
      if (!configured.isType<mox.PubSubError>()) {
        _configuredAvatarNodes.add(cacheKey);
        return;
      }

      try {
        final created = await pubsub
            .createNodeWithConfig(
              host,
              config.toNodeConfig(),
              nodeId: node,
            )
            .timeout(_avatarPublishTimeout);
        if (created != null) {
          final confirmed = await pubsub
              .configureNode(host, node, config)
              .timeout(_avatarPublishTimeout);
          if (!confirmed.isType<mox.PubSubError>()) {
            _configuredAvatarNodes.add(cacheKey);
          }
          return;
        }
      } on Exception {
        // ignore and retry below
      }

      try {
        final created = await pubsub
            .createNode(host, nodeId: node)
            .timeout(_avatarPublishTimeout);
        if (created == null) return;
        final confirmed = await pubsub
            .configureNode(host, node, config)
            .timeout(_avatarPublishTimeout);
        if (!confirmed.isType<mox.PubSubError>()) {
          _configuredAvatarNodes.add(cacheKey);
        }
      } on Exception {
        return;
      }
    }

    Future<void> publishData() async {
      await ensureNodeConfigured(
        node: mox.userAvatarDataXmlns,
        config: dataNodeConfig,
      );
      final result = await pubsub
          .publish(
            host,
            mox.userAvatarDataXmlns,
            dataPayload,
            id: payload.hash,
            options: dataPublishOptions,
            autoCreate: true,
            createNodeConfig: dataNodeConfig.toNodeConfig(),
          )
          .timeout(_avatarPublishTimeout);
      if (result.isType<mox.PubSubError>()) {
        throw XmppAvatarException(result.get<mox.PubSubError>());
      }
    }

    Future<void> publishMetadata() async {
      await ensureNodeConfigured(
        node: mox.userAvatarMetadataXmlns,
        config: metadataNodeConfig,
      );
      final result = await pubsub
          .publish(
            host,
            mox.userAvatarMetadataXmlns,
            metadataPayload,
            id: payload.hash,
            options: metadataPublishOptions,
            autoCreate: true,
            createNodeConfig: metadataNodeConfig.toNodeConfig(),
          )
          .timeout(_avatarPublishTimeout);
      if (result.isType<mox.PubSubError>()) {
        throw XmppAvatarException(result.get<mox.PubSubError>());
      }
    }

    bool isRetriableVerificationError(mox.PubSubError error) =>
        error is mox.ItemNotFoundError ||
        error is mox.NoItemReturnedError ||
        error is mox.MalformedResponseError ||
        error is mox.UnknownPubSubError;

    Future<bool> waitForStoredItem({
      required String node,
      required String expectedTag,
    }) async {
      for (var attempt = 0;
          attempt < _avatarPublishVerificationAttempts;
          attempt++) {
        final result = await pubsub
            .getItem(host, node, payload.hash)
            .timeout(_avatarPublishVerificationTimeout);
        if (result.isType<mox.PubSubError>()) {
          final error = result.get<mox.PubSubError>();
          final shouldRetry = isRetriableVerificationError(error) &&
              attempt + 1 < _avatarPublishVerificationAttempts;
          if (!shouldRetry) {
            return false;
          }
          await Future<void>.delayed(_avatarPublishVerificationDelay);
          continue;
        }

        final item = result.get<mox.PubSubItem>();
        final storedPayload = item.payload;
        final isValid = storedPayload != null &&
            storedPayload.tag == expectedTag &&
            storedPayload.attributes['xmlns'] == node &&
            (storedPayload.innerText().trim().isNotEmpty ||
                storedPayload.findTags(avatarMetadataInfoTag).isNotEmpty);
        if (isValid) {
          return true;
        }
        if (attempt + 1 >= _avatarPublishVerificationAttempts) {
          return false;
        }
        await Future<void>.delayed(_avatarPublishVerificationDelay);
      }
      return false;
    }

    Future<void> publishOrVerifyOnTimeout({
      required Future<void> Function() publish,
      required String node,
      required String expectedTag,
    }) async {
      try {
        await publish();
      } on TimeoutException {
        final stored = await waitForStoredItem(
          node: node,
          expectedTag: expectedTag,
        );
        if (!stored) rethrow;
      }
    }

    await publishOrVerifyOnTimeout(
      publish: publishData,
      node: mox.userAvatarDataXmlns,
      expectedTag: avatarDataTag,
    );
    await publishOrVerifyOnTimeout(
      publish: publishMetadata,
      node: mox.userAvatarMetadataXmlns,
      expectedTag: avatarMetadataTag,
    );

    final metadataStored = await waitForStoredItem(
      node: mox.userAvatarMetadataXmlns,
      expectedTag: avatarMetadataTag,
    );
    final dataStored = await waitForStoredItem(
      node: mox.userAvatarDataXmlns,
      expectedTag: avatarDataTag,
    );
    if (!metadataStored || !dataStored) {
      await ensureNodeConfigured(
        node: mox.userAvatarDataXmlns,
        config: dataNodeConfig,
      );
      await ensureNodeConfigured(
        node: mox.userAvatarMetadataXmlns,
        config: metadataNodeConfig,
      );
      await publishData();
      await publishMetadata();
      final repairedMetadataStored = await waitForStoredItem(
        node: mox.userAvatarMetadataXmlns,
        expectedTag: avatarMetadataTag,
      );
      final repairedDataStored = await waitForStoredItem(
        node: mox.userAvatarDataXmlns,
        expectedTag: avatarDataTag,
      );
      if (!repairedMetadataStored || !repairedDataStored) {
        throw XmppAvatarException(publishNotRetrievableMessage);
      }
    }

    final path = await _writeAvatarFile(
      bytes: payload.bytes,
    );
    await _storeAvatar(jid: targetJid, path: path, hash: payload.hash);
    final vCardManager = _connection.getManager<mox.VCardManager>();
    vCardManager?.setLastHash(targetJid, payload.hash);

    return AvatarUploadResult(path: path, hash: payload.hash);
  }

  String _avatarConfigKey({
    required String node,
    required mox.AccessModel accessModel,
  }) =>
      '$node$_avatarConfigKeySeparator${accessModel.value}';

  Future<void> _maybeRepairSelfAvatar(String bareJid) async {
    if (_selfAvatarRepairAttempted) return;
    _selfAvatarRepairAttempted = true;

    final existingPath = await _storedAvatarPath(bareJid);
    if (existingPath == null || existingPath.trim().isEmpty) return;
    final bytes = await loadAvatarBytes(existingPath);
    if (bytes == null || bytes.isEmpty) return;
    if (bytes.length > _maxAvatarBytes) return;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    final mimeType = _detectAvatarMimeType(bytes);
    final hash = sha1.convert(bytes).toString();

    final payload = AvatarUploadPayload(
      bytes: bytes,
      mimeType: mimeType,
      width: decoded.width,
      height: decoded.height,
      hash: hash,
      jid: bareJid,
    );
    try {
      await _publishAvatarOnce(
        payload: payload,
        targetJid: bareJid,
        public: true,
      );
    } catch (error, stackTrace) {
      _avatarLog.warning('Failed to repair missing server avatar.', error);
      _avatarLog.fine('Repair failure details', error, stackTrace);
    }
  }

  String _detectAvatarMimeType(Uint8List bytes) {
    if (_matchesSignature(bytes, _pngMagicBytes)) return _mimePng;
    if (_matchesSignature(bytes, _jpegMagicBytes)) return _mimeJpeg;
    return _mimePng;
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

  bool _isAvatarItemPublisherTrusted({
    required mox.PubSubItem item,
    required String ownerBare,
  }) {
    final publisher = item.publisher?.trim();
    if (publisher == null || publisher.isEmpty) {
      return _allowAvatarPublisherFallback;
    }
    final normalizedPublisher = _avatarSafeBareJid(publisher);
    if (normalizedPublisher == null) return false;
    return normalizedPublisher == ownerBare;
  }

  List<mox.PubSubItem> _filterAvatarItemsByPublisher({
    required List<mox.PubSubItem> items,
    required String ownerBare,
  }) {
    final List<mox.PubSubItem> filtered = items
        .where(
          (item) =>
              _isAvatarItemPublisherTrusted(item: item, ownerBare: ownerBare),
        )
        .toList(growable: false);
    return filtered;
  }

  Future<bool> _hasCachedAvatarFile(String? path) async {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) return false;
    final cacheDirectory = await _avatarCacheDirectory();
    if (!_isSafeAvatarCachePath(
      cacheDirectory: cacheDirectory,
      filePath: normalized,
    )) {
      return false;
    }
    return File(normalized).exists();
  }
}
