// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

String _base64EncodeAvatarPublishPayload(Uint8List bytes) =>
    base64Encode(bytes);

const String _selfAvatarStateKeyName = 'self_avatar_state_v2';
const String _storedAvatarPathField = 'path';
const String _storedAvatarHashField = 'hash';
final _selfAvatarStateKey = XmppStateStore.registerKey(_selfAvatarStateKeyName);

const String _avatarRosterRefreshOperationName =
    'AvatarService.refreshRosterAvatarsOnNegotiations';
const String _avatarConversationRefreshOperationName =
    'AvatarService.refreshConversationAvatarsOnNegotiations';
final XmppOperationEvent _selfAvatarPublishStartEvent = XmppOperationEvent(
  kind: XmppOperationKind.selfAvatarPublish,
  stage: XmppOperationStage.start,
);
final XmppOperationEvent _selfAvatarPublishSuccessEvent = XmppOperationEvent(
  kind: XmppOperationKind.selfAvatarPublish,
  stage: XmppOperationStage.end,
);
final XmppOperationEvent _selfAvatarPublishFailureEvent = XmppOperationEvent(
  kind: XmppOperationKind.selfAvatarPublish,
  stage: XmppOperationStage.end,
  isSuccess: false,
);

final class RoomVCardAvatarUpdatedEvent extends mox.XmppEvent {
  RoomVCardAvatarUpdatedEvent(this.jid, this.hash);

  final mox.JID jid;
  final String hash;
}

/// Avatar manager override that skips room-avatar JIDs and repairs metadata
/// parsing plus unsubscribe behavior for XEP-0084 notifications.
class RoomAwareUserAvatarManager extends mox.UserAvatarManager {
  RoomAwareUserAvatarManager({this.shouldSkipJid});

  static const String _metadataTag = 'metadata';
  static const String _infoTag = 'info';
  static const int _maxMetadataItems = 1;
  static const bool _skipAvatarJidDefault = false;

  final bool Function(mox.JID jid)? shouldSkipJid;

  @override
  Future<void> onXmppEvent(mox.XmppEvent event) async {
    if (event is PubSubItemsRefreshedEvent) {
      fireAndForget(() => _handleRefreshEvent(event));
      return;
    }

    if (event is! mox.PubSubNotificationEvent) {
      return super.onXmppEvent(event);
    }

    fireAndForget(() async {
      if (event.item.node != mox.userAvatarMetadataXmlns) return;

      final fromRaw = event.from.trim();
      if (fromRaw.isEmpty) return;

      late final mox.JID from;
      try {
        from = mox.JID.fromString(fromRaw);
      } on Exception {
        return;
      }
      if (_shouldSkipAvatarJid(from)) {
        logger.fine('Avatar notification skipped; jid marked skippable.');
        return;
      }

      if (event.item.payload case final payload?) {
        logger.fine('Avatar notification received with inline payload.');
        await _emitFromPayload(from: from, payload: payload);
        return;
      }

      final itemId = event.item.id.trim();
      logger.fine('Avatar notification received without payload; refreshing.');
      await _refreshMetadata(
        from: from,
        itemId: itemId.isNotEmpty ? itemId : null,
      );
    });
    return;
  }

  Future<void> _handleRefreshEvent(PubSubItemsRefreshedEvent event) async {
    if (event.node != mox.userAvatarMetadataXmlns) return;
    if (_shouldSkipAvatarJid(event.from)) {
      logger.fine('Avatar refresh event skipped; jid marked skippable.');
      return;
    }
    logger.fine('Avatar refresh event received; refreshing metadata.');
    await _refreshMetadata(from: event.from);
  }

  Future<void> _refreshMetadata({required mox.JID from, String? itemId}) async {
    if (_shouldSkipAvatarJid(from)) return;
    final pubsub = getAttributes().getManagerById<mox.PubSubManager>(
      mox.pubsubManager,
    );
    if (pubsub == null) {
      logger.fine('PubSubManager unavailable; cannot refresh avatar metadata.');
      return;
    }

    final bareFrom = from.toBare();
    final normalizedItemId = itemId?.trim();
    if (normalizedItemId?.isNotEmpty == true) {
      final itemResult = await pubsub.getItem(
        bareFrom,
        mox.userAvatarMetadataXmlns,
        normalizedItemId!,
      );
      if (!itemResult.isType<mox.PubSubError>()) {
        final fetchedPayload = itemResult.get<mox.PubSubItem>().payload;
        if (fetchedPayload != null) {
          logger.fine('Avatar metadata fetched via item lookup.');
          await _emitFromPayload(from: from, payload: fetchedPayload);
          return;
        }
      }
      logger.fine('Avatar item lookup failed; falling back to getItems.');
    }

    var itemsResult = await pubsub.getItems(
      bareFrom,
      mox.userAvatarMetadataXmlns,
      maxItems: _maxMetadataItems,
    );
    if (itemsResult.isType<mox.PubSubError>()) {
      final error = itemsResult.get<mox.PubSubError>();
      final shouldRetry =
          error is mox.EjabberdMaxItemsError ||
          error is mox.MalformedResponseError ||
          error is mox.UnknownPubSubError;
      logger.fine(
        'Avatar getItems failed with ${error.runtimeType}; '
        'retry=$shouldRetry.',
      );
      if (!shouldRetry) return;
      itemsResult = await pubsub.getItems(
        bareFrom,
        mox.userAvatarMetadataXmlns,
      );
      if (itemsResult.isType<mox.PubSubError>()) return;
    }

    final items = itemsResult.get<List<mox.PubSubItem>>();
    if (items.isEmpty) {
      logger.fine('Avatar getItems returned empty list; emitting clear event.');
      getAttributes().sendEvent(
        mox.UserAvatarUpdatedEvent(from, const <mox.UserAvatarMetadata>[]),
      );
      return;
    }

    final payload = items.first.payload;
    if (payload == null) return;
    await _emitFromPayload(from: from, payload: payload);
  }

  bool _shouldSkipAvatarJid(mox.JID jid) =>
      shouldSkipJid?.call(jid) ?? _skipAvatarJidDefault;

  Future<void> _emitFromPayload({
    required mox.JID from,
    required mox.XMLNode payload,
  }) async {
    if (payload.tag != _metadataTag ||
        payload.attributes['xmlns'] != mox.userAvatarMetadataXmlns) {
      logger.warning('Received invalid user avatar metadata payload.');
      return;
    }

    final metadata = payload
        .findTags(_infoTag)
        .map(mox.UserAvatarMetadata.fromXML)
        .toList();
    logger.fine('Avatar metadata parsed. count=${metadata.length}.');
    getAttributes().sendEvent(mox.UserAvatarUpdatedEvent(from, metadata));
  }

  @override
  Future<moxlib.Result<mox.AvatarError, bool>> unsubscribe(mox.JID jid) async {
    final pubsub = getAttributes().getManagerById<mox.PubSubManager>(
      mox.pubsubManager,
    );
    if (pubsub == null) {
      return moxlib.Result(mox.UnknownAvatarError());
    }

    final result = await pubsub.unsubscribe(jid, mox.userAvatarMetadataXmlns);
    if (result.isType<mox.PubSubError>()) {
      logger.warning('Failed to unsubscribe from user avatar metadata.');
      return moxlib.Result(mox.UnknownAvatarError());
    }

    return const moxlib.Result(true);
  }
}

/// vCard avatar manager override that routes room avatar updates to a room-
/// specific event instead of the contact-avatar path.
class RoomAwareVCardManager extends mox.VCardManager {
  RoomAwareVCardManager({this.isRoomJid});

  final bool Function(mox.JID jid)? isRoomJid;

  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() => [
    mox.StanzaHandler(
      stanzaTag: 'presence',
      tagName: 'x',
      tagXmlns: mox.vCardTempUpdate,
      callback: _onPresenceSafe,
    ),
  ];

  Future<mox.StanzaHandlerData> _onPresenceSafe(
    mox.Stanza presence,
    mox.StanzaHandlerData state,
  ) async {
    final x = presence.firstTag('x', xmlns: mox.vCardTempUpdate);
    final from = presence.from;
    if (x == null || from == null) {
      return state;
    }

    final hash = x.firstTag('photo')?.innerText() ?? '';

    final jid = mox.JID.fromString(from);
    final roomAvatarJid = isRoomJid?.call(jid) ?? false;
    getAttributes().sendEvent(
      roomAvatarJid
          ? RoomVCardAvatarUpdatedEvent(jid, hash)
          : mox.VCardAvatarUpdatedEvent(jid, hash),
    );
    return state;
  }
}

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
  const AvatarUploadResult({required this.path, required this.hash});

  final String path;
  final String hash;
}

final class _PendingSelfAvatarPublish {
  const _PendingSelfAvatarPublish({
    required this.path,
    required this.hash,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.public,
    this.jid,
  });

  final String path;
  final String hash;
  final String mimeType;
  final int width;
  final int height;
  final bool public;
  final String? jid;

  static _PendingSelfAvatarPublish? fromJson(Map<String, dynamic> json) {
    final path = json[_pathKey] as String?;
    final hash = json[_hashKey] as String?;
    final mimeType = json[_mimeKey] as String?;
    final width = json[_widthKey] as int?;
    final height = json[_heightKey] as int?;
    if (path == null ||
        hash == null ||
        mimeType == null ||
        width == null ||
        height == null) {
      return null;
    }
    return _PendingSelfAvatarPublish(
      path: path,
      hash: hash,
      mimeType: mimeType,
      width: width,
      height: height,
      public: (json[_publicKey] as bool?) ?? true,
      jid: json[_jidKey] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    _pathKey: path,
    _hashKey: hash,
    _mimeKey: mimeType,
    _widthKey: width,
    _heightKey: height,
    _publicKey: public,
    _jidKey: jid,
  };

  static const _pathKey = 'path';
  static const _hashKey = 'hash';
  static const _mimeKey = 'mime';
  static const _widthKey = 'width';
  static const _heightKey = 'height';
  static const _publicKey = 'public';
  static const _jidKey = 'jid';
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

mixin AvatarService on XmppBase, BaseStreamService {
  final _avatarLog = Logger('AvatarService');
  StreamController<bool> _selfAvatarHydratingController =
      StreamController<bool>.broadcast(sync: true);
  Avatar? _cachedSelfAvatar;
  bool _hasSelfAvatarNegotiatedStream = false;
  bool _selfAvatarInitialSyncCompleted = false;
  SecretKey? _avatarEncryptionKey;
  List<int>? _avatarEncryptionSalt;
  final Map<String, Object> _avatarRefreshInProgress = <String, Object>{};
  final Set<String> _configuredAvatarNodes = {};
  final Set<String> _pubSubAvatarJids = {};
  final Map<String, DateTime> _conversationAvatarRefreshAttempts = {};
  Future<void>? _selfAvatarBootstrapFuture;
  Directory? _avatarDirectory;
  final AesGcm _avatarCipher = AesGcm.with256bits();
  static const int _maxAvatarBytes = 512 * 1024;
  static const int _maxAvatarBase64Length = ((_maxAvatarBytes + 2) ~/ 3) * 4;
  static const int _avatarBytesCacheLimit = 64;
  static const int _safeAvatarBytesCacheLimit = _avatarBytesCacheLimit;
  static const int _conversationAvatarChatStart = 0;
  static const int _conversationAvatarChatEnd = 0;
  static const Duration _conversationAvatarRefreshCooldown = Duration(
    minutes: 2,
  );
  static const Duration _avatarRefreshTimeout = Duration(seconds: 12);
  static const Duration _avatarPublishTimeout = Duration(seconds: 30);
  static const String _avatarConfigKeySeparator = '|';
  static const int _avatarPublishVerificationAttempts = 2;
  static const Duration _avatarPublishVerificationDelay = Duration(
    milliseconds: 350,
  );
  static const Duration _avatarPublishVerificationTimeout = Duration(
    seconds: 5,
  );
  static const Duration _selfAvatarRepairCooldown = Duration(minutes: 2);
  static const bool _allowAvatarPublisherFallback = true;
  static const bool _avatarSkipDefault = true;
  static const String _avatarClearReasonMetadataEmpty = 'metadata_empty';
  static const String _avatarClearReasonVcardEmpty = 'vcard_empty';
  static const String _avatarClearReasonPubSubRetract = 'pubsub_retract';
  static const String _avatarClearReasonPubSubNodeDeleted =
      'pubsub_node_deleted';
  static const String _avatarClearReasonPubSubNodePurged = 'pubsub_node_purged';
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
  final Map<String, Future<Uint8List?>> _avatarLoadsInFlight = {};
  final Map<String, Future<void>> _avatarFileOperations = {};
  DateTime? _selfAvatarRepairLastAttempt;
  int? _selfAvatarRefreshLifecycleEpoch;
  @override
  final selfAvatarPathKey = XmppStateStore.registerKey('self_avatar_path');
  @override
  final selfAvatarHashKey = XmppStateStore.registerKey('self_avatar_hash');
  @override
  final selfAvatarPendingPublishKey = XmppStateStore.registerKey(
    'self_avatar_pending_publish_v1',
  );
  final avatarEncryptionSaltKey = XmppStateStore.registerKey(
    'avatar_encryption_salt',
  );

  @override
  SecretKey? get avatarEncryptionKey => _avatarEncryptionKey;

  @override
  Avatar? get cachedSelfAvatar => _cachedSelfAvatar;

  @override
  Stream<Avatar?> get selfAvatarStream => createSingleStateStoreStream<Avatar?>(
    watchFunction: (store) async =>
        (store.watch<Object?>(key: _selfAvatarStateKey) ??
                const Stream<Object?>.empty())
            .startWith(null)
            .map((_) {
              final avatar = _readStoredSelfAvatar(store);
              _setCachedSelfAvatar(avatar);
              return _cachedSelfAvatar;
            })
            .distinct(_storedAvatarsMatch),
  );

  @override
  bool get selfAvatarHydrating => _isSelfAvatarRefreshRunning();

  @override
  Stream<bool> get selfAvatarHydratingStream =>
      _selfAvatarHydratingController.stream;

  void _emitSelfAvatarHydrating() {
    if (_selfAvatarHydratingController.isClosed) return;
    _selfAvatarHydratingController.add(selfAvatarHydrating);
  }

  void _clearSelfAvatarNegotiationState() {
    final bareJid = _myJid?.toBare().toString();
    if (bareJid != null && bareJid.isNotEmpty) {
      _avatarRefreshInProgress.remove(bareJid);
    }
    _hasSelfAvatarNegotiatedStream = false;
    _selfAvatarInitialSyncCompleted = false;
    _selfAvatarRefreshLifecycleEpoch = null;
    _selfAvatarBootstrapFuture = null;
    _emitSelfAvatarHydrating();
  }

  bool _isSelfAvatarRefreshRunning() {
    final bareJid = _myJid?.toBare().toString();
    if (bareJid == null || bareJid.isEmpty) {
      return false;
    }
    return _avatarRefreshInProgress.containsKey(bareJid);
  }

  Object? _startAvatarRefresh(String bareJid) {
    final normalizedJid = bareJid.trim();
    if (normalizedJid.isEmpty) {
      return null;
    }
    if (_avatarRefreshInProgress.containsKey(normalizedJid)) {
      return null;
    }
    final refreshToken = Object();
    _avatarRefreshInProgress[normalizedJid] = refreshToken;
    return refreshToken;
  }

  bool _ownsAvatarRefresh(String bareJid, Object refreshToken) =>
      identical(_avatarRefreshInProgress[bareJid], refreshToken);

  void _finishAvatarRefresh(String bareJid, Object refreshToken) {
    if (_ownsAvatarRefresh(bareJid, refreshToken)) {
      _avatarRefreshInProgress.remove(bareJid);
    }
  }

  void _setCachedSelfAvatar(Avatar? avatar) {
    _cachedSelfAvatar = avatar;
  }

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

  Future<Uint8List?> resolveSafeAvatarBytes({
    String? avatarPath,
    Uint8List? avatarBytes,
  }) async {
    final providedBytes = avatarBytes != null && avatarBytes.isNotEmpty
        ? avatarBytes
        : null;
    final normalizedPath = avatarPath?.trim();
    if (providedBytes != null) {
      final safeBytes = await sanitizeAvatarBytes(providedBytes);
      if (safeBytes == null || safeBytes.isEmpty) {
        return null;
      }
      if (normalizedPath != null && normalizedPath.isNotEmpty) {
        _cacheSafeAvatarBytes(normalizedPath, safeBytes);
      }
      return safeBytes;
    }
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return null;
    }
    final safeCached = cachedSafeAvatarBytes(normalizedPath);
    if (safeCached != null && safeCached.isNotEmpty) {
      return safeCached;
    }
    final cached = cachedAvatarBytes(normalizedPath);
    if (cached != null && cached.isNotEmpty) {
      final safeBytes = await sanitizeAvatarBytes(cached);
      if (safeBytes == null || safeBytes.isEmpty) {
        return null;
      }
      _cacheSafeAvatarBytes(normalizedPath, safeBytes);
      return safeBytes;
    }
    final bytes = await loadAvatarBytes(normalizedPath);
    final safeBytes = await sanitizeAvatarBytes(bytes);
    if (safeBytes == null || safeBytes.isEmpty) {
      return null;
    }
    _cacheSafeAvatarBytes(normalizedPath, safeBytes);
    return safeBytes;
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
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.UserAvatarUpdatedEvent>((event) async {
        final bareJid = event.jid.toBare().toString();
        final myBareJid = _myJid?.toBare().toString();
        final isSelf = myBareJid != null && myBareJid == bareJid;
        _avatarLog.fine(
          'User avatar update received. isSelf=$isSelf '
          'metadataCount=${event.metadata.length}.',
        );
        if (event.metadata.isEmpty) {
          _unmarkPubSubAvatarPreferred(bareJid);
          _avatarLog.fine(
            'User avatar metadata empty; clearing avatar. isSelf=$isSelf.',
          );
          await _clearAvatarForJid(
            bareJid,
            reason: _avatarClearReasonMetadataEmpty,
          );
          return;
        }

        _markPubSubAvatarPreferred(bareJid);
        await _refreshAvatarForJid(bareJid, metadata: event.metadata);
      })
      ..registerHandler<ConversationIndexItemUpdatedEvent>((event) async {
        final peerJid = event.item.peerBare.toBare().toString();
        if (peerJid.isEmpty) return;
        if (peerJid == myJid) return;
        if (!await _shouldRefreshConversationAvatar(peerJid)) return;
        await _refreshConversationAvatars([peerJid]);
      })
      ..registerHandler<mox.VCardAvatarUpdatedEvent>((event) async {
        final bareJid = event.jid.toBare().toString();
        final myBareJid = _myJid?.toBare().toString();
        final isSelf = myBareJid != null && myBareJid == bareJid;
        _avatarLog.fine(
          'VCard avatar update received. isSelf=$isSelf '
          'hasHash=${event.hash.isNotEmpty}.',
        );
        if (event.hash.isEmpty) {
          if (isSelf) {
            _avatarLog.fine('VCard avatar hash empty; ignoring for self.');
            return;
          }
          if (_isPubSubAvatarPreferred(bareJid)) {
            _avatarLog.fine(
              'VCard avatar hash empty; keeping PubSub avatar. '
              'isSelf=$isSelf.',
            );
            return;
          }
          _avatarLog.fine(
            'VCard avatar hash empty; clearing avatar. isSelf=$isSelf.',
          );
          await _clearAvatarForJid(
            bareJid,
            reason: _avatarClearReasonVcardEmpty,
          );
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

        _avatarLog.fine(
          'Avatar pubsub retraction matched stored hash; clearing avatar.',
        );
        _unmarkPubSubAvatarPreferred(bareJid);
        await _clearAvatarForJid(
          bareJid,
          reason: _avatarClearReasonPubSubRetract,
        );
      })
      ..registerHandler<mox.PubSubNodeDeletedEvent>((event) async {
        final node = event.node;
        if (node != mox.userAvatarMetadataXmlns &&
            node != mox.userAvatarDataXmlns) {
          return;
        }

        final bareJid = _avatarSafeBareJid(event.from);
        if (bareJid == null) return;

        _avatarLog.fine('Avatar pubsub node deleted; clearing avatar.');
        _unmarkPubSubAvatarPreferred(bareJid);
        await _clearAvatarForJid(
          bareJid,
          reason: _avatarClearReasonPubSubNodeDeleted,
        );
      })
      ..registerHandler<mox.PubSubNodePurgedEvent>((event) async {
        final node = event.node;
        if (node != mox.userAvatarMetadataXmlns &&
            node != mox.userAvatarDataXmlns) {
          return;
        }

        final bareJid = _avatarSafeBareJid(event.from);
        if (bareJid == null) return;

        _avatarLog.fine('Avatar pubsub node purged; clearing avatar.');
        _unmarkPubSubAvatarPreferred(bareJid);
        await _clearAvatarForJid(
          bareJid,
          reason: _avatarClearReasonPubSubNodePurged,
        );
      });
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: 'AvatarService.refreshSelfAvatarOnNegotiations',
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.resumedNegotiation,
        },
        operationName: 'AvatarService.refreshSelfAvatarOnNegotiations',
        run: () async {
          _hasSelfAvatarNegotiatedStream = true;
          _emitSelfAvatarHydrating();
          await _bootstrapSelfAvatarIfReady();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _avatarRosterRefreshOperationName,
        priority: 1,
        lane: 'roster',
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _avatarRosterRefreshOperationName,
        run: () async {
          await _refreshRosterAvatarsFromCache();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _avatarConversationRefreshOperationName,
        priority: 1,
        lane: 'conversationIndex',
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _avatarConversationRefreshOperationName,
        run: () async {
          await _refreshConversationIndexAvatars();
        },
      ),
    );
  }

  Future<void> cacheSelfAvatarDraft(
    AvatarUploadPayload payload, {
    bool waitForPublish = true,
  }) async {
    final myBareJid = _myJid?.toBare().toString();
    if (myBareJid == null || myBareJid.isEmpty) return;
    final targetJid = _avatarSafeBareJid(payload.jid ?? myJid);
    if (targetJid == null || targetJid != myBareJid) return;
    if (!isStateStoreReady || avatarEncryptionKey == null) return;

    try {
      final path = await _writeAvatarFile(bytes: payload.bytes);
      await _persistOwnAvatar(path, payload.hash);
      await _persistPendingSelfAvatarPublish(
        path: path,
        payload: payload,
        public: true,
      );
      _setCachedSelfAvatar(Avatar(path: path, hash: payload.hash));
      if (waitForPublish) {
        if (_hasSelfAvatarNegotiatedStream) {
          _selfAvatarInitialSyncCompleted = false;
          _emitSelfAvatarHydrating();
        }
        await _bootstrapSelfAvatarIfReady();
      } else {
        fireAndForget(
          _bootstrapSelfAvatarIfReady,
          operationName: 'AvatarService.bootstrapSelfAvatarDraft',
        );
      }
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine(
        'Failed to cache pending self avatar for immediate display.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<Avatar?> getOwnAvatar() async {
    if (!isStateStoreReady) return null;
    try {
      final stored = await _dbOpReturning<XmppStateStore, Avatar?>(
        (ss) => _readStoredSelfAvatar(ss),
      );
      _setCachedSelfAvatar(stored);
      return _cachedSelfAvatar;
    } on XmppAbortedException {
      return null;
    }
  }

  Future<void> _initializeAvatarEncryption(String passphrase) async {
    try {
      final salt = await _loadOrCreateAvatarSalt();
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      _avatarEncryptionKey = await hkdf.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: salt,
        info: utf8.encode('axichat-avatar-v1'),
      );
    } catch (error, stackTrace) {
      _avatarLog.severe(
        'Failed to initialize avatar encryption key.',
        error,
        stackTrace,
      );
      _avatarEncryptionKey = null;
    }
  }

  Future<List<int>> _loadOrCreateAvatarSalt() async {
    if (_avatarEncryptionSalt case final cached?) {
      return cached;
    }
    try {
      final stored = await _dbOpReturning<XmppStateStore, String?>(
        (ss) => ss.read(key: avatarEncryptionSaltKey) as String?,
      );
      if (stored != null) {
        final decoded = base64Decode(stored);
        _avatarEncryptionSalt = decoded;
        return decoded;
      }
    } on XmppAbortedException {
      rethrow;
    } on FormatException catch (error, stackTrace) {
      _avatarLog.warning(
        'Stored avatar salt could not be decoded, regenerating.',
        error,
        stackTrace,
      );
    }
    final fresh = secureBytes(32);
    final encoded = base64Encode(fresh);
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(key: avatarEncryptionSaltKey, value: encoded),
      awaitDatabase: true,
    );
    _avatarEncryptionSalt = fresh;
    return fresh;
  }

  @override
  Future<void> _reset() async {
    _avatarRefreshInProgress.clear();
    _configuredAvatarNodes.clear();
    _avatarBytesCache.clear();
    _safeAvatarBytesCache.clear();
    _avatarLoadsInFlight.clear();
    _avatarFileOperations.clear();
    _avatarDirectory = null;
    _selfAvatarRepairLastAttempt = null;
    _selfAvatarRefreshLifecycleEpoch = null;
    _selfAvatarBootstrapFuture = null;
    _avatarEncryptionKey = null;
    _avatarEncryptionSalt = null;
    _cachedSelfAvatar = null;
    _clearSelfAvatarNegotiationState();
    await super._reset();
  }

  Future<void> _bootstrapSelfAvatarIfReady() async {
    if (!_hasSelfAvatarNegotiatedStream) return;
    if (_selfAvatarInitialSyncCompleted) return;
    if (avatarEncryptionKey == null) return;
    final inFlight = _selfAvatarBootstrapFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final next = _runSelfAvatarBootstrap();
    _selfAvatarBootstrapFuture = next;
    try {
      await next;
    } finally {
      if (identical(_selfAvatarBootstrapFuture, next)) {
        _selfAvatarBootstrapFuture = null;
      }
    }
  }

  Future<void> _runSelfAvatarBootstrap() async {
    final operationEpoch = lifecycleEpoch;
    try {
      await _notifyCachedSelfAvatarIfAvailable();
      await _publishPendingSelfAvatarIfAvailable();
      await refreshSelfAvatarIfNeeded();
    } finally {
      if (operationEpoch == lifecycleEpoch) {
        _selfAvatarInitialSyncCompleted = true;
        _emitSelfAvatarHydrating();
      }
    }
  }

  Future<void> scheduleAvatarRefresh(
    Iterable<String> jids, {
    bool force = false,
  }) async {
    final refreshes = jids.toList(growable: false);
    if (refreshes.isEmpty) return;
    const maxConcurrent = 6;
    for (var index = 0; index < refreshes.length; index += maxConcurrent) {
      final end = index + maxConcurrent;
      final batch = refreshes.sublist(
        index,
        end > refreshes.length ? refreshes.length : end,
      );
      await Future.wait(
        batch.map((jid) => _refreshAvatarForJid(jid, force: force)),
      );
    }
  }

  Future<void> _refreshConversationAvatars(Iterable<String> jids) async {
    if (jids.isEmpty) return;
    await scheduleAvatarRefresh(jids);
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

  Future<bool> refreshAvatarsForConversationIndex() async {
    final refreshed = await _refreshConversationIndexAvatars();
    await refreshSelfAvatarIfNeeded(force: true);
    return refreshed;
  }

  Future<bool> _refreshConversationIndexAvatars() async {
    List<Chat> chats;
    try {
      chats = await _dbOpReturning<XmppDatabase, List<Chat>>(
        (db) => db.getChats(
          start: _conversationAvatarChatStart,
          end: _conversationAvatarChatEnd,
        ),
      );
    } on XmppAbortedException {
      return false;
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
    return true;
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

  bool _isSameDomainAvatarJid(String bareJid) {
    final normalized = bareJid.trim();
    if (normalized.isEmpty) return false;
    final myBareJid = _myJid?.toBare().toString();
    if (myBareJid == null || myBareJid.isEmpty) return false;
    if (sameBareAddress(normalized, myBareJid)) return true;
    final targetJid = parseJid(normalized);
    final selfJid = parseJid(myBareJid);
    if (targetJid == null || selfJid == null) return false;
    return targetJid.domain == selfJid.domain;
  }

  Future<bool> _shouldSkipAvatarForBareJid(String bareJid) async {
    final normalized = bareJid.trim();
    if (normalized.isEmpty) return _avatarSkipDefault;
    if (!_isSameDomainAvatarJid(normalized)) return true;
    try {
      final chat = await _dbOpReturning<XmppDatabase, Chat?>(
        (db) => db.getChat(normalized),
      );
      return chat?.type == ChatType.groupChat;
    } on XmppAbortedException {
      return _avatarSkipDefault;
    }
  }

  Future<void> prefetchAvatarForJid(String jid) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;
    if (await _shouldSkipAvatarForBareJid(bareJid)) return;

    switch (await _loadMetadata(bareJid)) {
      case final _AvatarMetadataLoaded loaded:
        await _refreshAvatarForJid(bareJid, metadata: [loaded.metadata]);
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
      final stored = await _dbOpReturning<XmppStateStore, Avatar?>((ss) async {
        final path = ss.read(key: selfAvatarPathKey) as String?;
        final hash = ss.read(key: selfAvatarHashKey) as String?;
        final resolvedPath = path?.trim();
        if (resolvedPath == null || resolvedPath.isEmpty) return null;
        return Avatar(path: resolvedPath, hash: hash?.trim());
      });
      if (stored == null) return;
      final path = stored.path;
      if (!await _hasCachedAvatarFile(path)) return;

      _markPubSubAvatarPreferred(myBareJid);
      _setCachedSelfAvatar(Avatar(path: path, hash: stored.hash));
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
    if (await _shouldSkipAvatarForBareJid(normalizedJid)) {
      _avatarLog.fine('VCard request skipped; jid marked skippable.');
      return;
    }
    final myBareJid = _myJid?.toBare().toString();
    final isSelf = myBareJid != null && myBareJid == normalizedJid;
    Object? refreshToken;
    try {
      _avatarLog.fine('Refreshing vCard avatar. isSelf=$isSelf force=$force.');
      final manager = _connection.getManager<mox.VCardManager>();
      if (manager == null) {
        _avatarLog.fine('VCardManager unavailable; skipping refresh.');
        return;
      }
      final startedRefresh = _startAvatarRefresh(normalizedJid);
      if (startedRefresh == null) {
        _avatarLog.fine('VCard request already in progress; skipping.');
        return;
      }
      refreshToken = startedRefresh;
      if (isSelf) {
        _emitSelfAvatarHydrating();
      }

      final vcardResult = await _withAvatarRefreshTimeout(
        manager.requestVCard(mox.JID.fromString(normalizedJid)),
        operationName: 'Avatar vCard fetch',
      );
      if (vcardResult.isType<mox.VCardError>()) {
        _avatarLog.fine('VCard request failed; aborting refresh.');
        return;
      }
      final vcard = vcardResult.get<mox.VCard>();
      final rawEncoded = vcard.photo?.binval?.trim();
      if (rawEncoded == null || rawEncoded.isEmpty) {
        _avatarLog.fine('VCard photo missing; aborting refresh.');
        return;
      }
      if (rawEncoded.length > _maxAvatarBase64Length * 2) {
        _avatarLog.fine('VCard photo payload too large; aborting refresh.');
        return;
      }
      final encoded = rawEncoded.replaceAll(RegExp(r'\s+'), '');
      if (encoded.isEmpty) {
        _avatarLog.fine('VCard photo payload empty after normalization.');
        return;
      }
      if (encoded.length > _maxAvatarBase64Length) {
        _avatarLog.fine('VCard photo payload exceeds max length.');
        return;
      }

      Uint8List bytes;
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        _avatarLog.fine('VCard photo base64 decode failed.');
        return;
      }
      if (bytes.isEmpty) {
        _avatarLog.fine('VCard avatar bytes empty after decode.');
        return;
      }
      if (bytes.length > _maxAvatarBytes) {
        _avatarLog.fine('VCard avatar bytes exceed max size.');
        return;
      }
      if (!_isSupportedAvatarBytes(bytes)) {
        _avatarLog.fine('VCard avatar bytes not supported.');
        return;
      }

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

      if (!_ownsAvatarRefresh(normalizedJid, refreshToken)) {
        _avatarLog.fine('Dropping stale vCard avatar refresh before write.');
        return;
      }
      final path = await _writeAvatarFile(bytes: bytes);
      if (!_ownsAvatarRefresh(normalizedJid, refreshToken)) {
        _avatarLog.fine('Dropping stale vCard avatar refresh result.');
        return;
      }
      await _storeAvatar(jid: normalizedJid, path: path, hash: hash);
      _avatarLog.fine('VCard avatar stored successfully.');
    } catch (error, stackTrace) {
      _avatarLog.warning('Failed to refresh vCard avatar.', error, stackTrace);
    } finally {
      if (refreshToken != null) {
        _finishAvatarRefresh(normalizedJid, refreshToken);
        if (isSelf) {
          _emitSelfAvatarHydrating();
        }
      }
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
    _avatarLog.fine('Refreshing roster avatars from cache.');
    if (rosterJids.isEmpty) return;
    await scheduleAvatarRefresh(rosterJids);
  }

  Future<void> _refreshAvatarForJid(
    String jid, {
    bool force = false,
    List<mox.UserAvatarMetadata>? metadata,
  }) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;
    if (await _shouldSkipAvatarForBareJid(bareJid)) {
      _avatarLog.fine('Avatar refresh skipped; jid marked skippable.');
      return;
    }
    final myBareJid = _myJid?.toBare().toString();
    final isSelf = myBareJid != null && myBareJid == bareJid;
    Object? refreshToken;
    try {
      final manager = _connection.getManager<mox.UserAvatarManager>();
      _avatarLog.fine(
        'Refreshing avatar. isSelf=$isSelf force=$force '
        'metadataProvided=${metadata != null}.',
      );
      if (manager == null) {
        _avatarLog.fine('UserAvatarManager unavailable; skipping refresh.');
        return;
      }
      if (isSelf &&
          metadata == null &&
          !force &&
          _selfAvatarRefreshLifecycleEpoch == lifecycleEpoch) {
        _avatarLog.fine(
          'Self avatar refresh skipped; lifecycle already refreshed.',
        );
        return;
      }
      final startedRefresh = _startAvatarRefresh(bareJid);
      if (startedRefresh == null) {
        _avatarLog.fine('Avatar refresh already in progress; skipping.');
        return;
      }
      refreshToken = startedRefresh;
      if (isSelf) {
        _emitSelfAvatarHydrating();
      }
      if (isSelf && metadata == null && !force) {
        _selfAvatarRefreshLifecycleEpoch = lifecycleEpoch;
      }
      final existingHash = await _storedAvatarHash(bareJid);
      if (metadata != null && metadata.isEmpty) {
        _avatarLog.fine('Metadata empty during refresh; clearing avatar.');
        await _clearAvatarForJid(
          bareJid,
          reason: _avatarClearReasonMetadataEmpty,
        );
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
            if (!isSelf) {
              _unmarkPubSubAvatarPreferred(bareJid);
            }
            if (isSelf) {
              _avatarLog.fine(
                'Avatar metadata missing for self; attempting publish repair.',
              );
              await _maybeRepairSelfAvatar(bareJid);
              return;
            }
            _avatarLog.fine(
              'Avatar metadata missing; requesting vCard fallback.',
            );
            await _refreshAvatarFromVCardRequest(bareJid, force: true);
            return;
          case _AvatarMetadataLoadFailed():
            _avatarLog.fine(
              'Avatar metadata load failed; requesting vCard fallback.',
            );
            if (!isSelf) {
              await _refreshAvatarFromVCardRequest(bareJid, force: true);
            }
            return;
        }
      }
      if (selectedMetadata == null) {
        _avatarLog.fine('No usable avatar metadata selected; skipping.');
        return;
      }
      _markPubSubAvatarPreferred(bareJid);
      if (!force &&
          existingHash != null &&
          existingHash == selectedMetadata.id) {
        final existingPath = await _storedAvatarPath(bareJid);
        if (await _hasCachedAvatarFile(existingPath)) {
          return;
        }
      }

      final avatarDataResult = await _withAvatarRefreshTimeout(
        manager.getUserAvatarData(
          mox.JID.fromString(bareJid),
          selectedMetadata.id,
        ),
        operationName: 'Avatar data fetch',
      );
      if (avatarDataResult.isType<mox.AvatarError>()) {
        _avatarLog.fine('Avatar data fetch failed; aborting refresh.');
        return;
      }
      final avatarData = avatarDataResult.get<mox.UserAvatarData>();
      Uint8List bytes;
      try {
        final normalized = avatarData.base64.replaceAll(RegExp(r'\s+'), '');
        bytes = base64Decode(normalized);
      } on FormatException {
        _avatarLog.fine('Avatar data base64 decode failed.');
        return;
      }
      if (bytes.isEmpty) {
        _avatarLog.fine('Avatar data payload empty after decode.');
        return;
      }
      if (bytes.length > _maxAvatarBytes) {
        _avatarLog.fine('Avatar data payload exceeds max bytes.');
        return;
      }

      if (!_ownsAvatarRefresh(bareJid, refreshToken)) {
        _avatarLog.fine('Dropping stale avatar refresh before write.');
        return;
      }
      final path = await _writeAvatarFile(bytes: bytes);
      if (!_ownsAvatarRefresh(bareJid, refreshToken)) {
        _avatarLog.fine('Dropping stale avatar refresh result.');
        return;
      }
      await _storeAvatar(jid: bareJid, path: path, hash: avatarData.hash);
      _avatarLog.fine('Avatar refresh stored successfully.');
    } catch (error, stackTrace) {
      _avatarLog.warning('Failed to refresh avatar.', error, stackTrace);
    } finally {
      if (refreshToken != null) {
        _finishAvatarRefresh(bareJid, refreshToken);
        if (isSelf) {
          _emitSelfAvatarHydrating();
        }
      }
    }
  }

  Future<void> _refreshAvatarFromVCard(String jid, String hash) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;
    if (await _shouldSkipAvatarForBareJid(bareJid)) {
      _avatarLog.fine('VCard refresh skipped; jid marked skippable.');
      return;
    }
    if (hash.isEmpty) {
      if (_isPubSubAvatarPreferred(bareJid)) {
        _avatarLog.fine('VCard hash empty; keeping PubSub avatar.');
        return;
      }
      _avatarLog.fine('VCard hash empty; clearing avatar.');
      await _clearAvatarForJid(bareJid, reason: _avatarClearReasonVcardEmpty);
      return;
    }
    final myBareJid = _myJid?.toBare().toString();
    final isSelf = myBareJid != null && myBareJid == bareJid;
    Object? refreshToken;
    try {
      final existingHash = await _storedAvatarHash(bareJid);
      if (existingHash == hash) {
        final existingPath = await _storedAvatarPath(bareJid);
        if (await _hasCachedAvatarFile(existingPath)) {
          return;
        }
      }

      final manager = _connection.getManager<mox.VCardManager>();
      if (manager == null) {
        _avatarLog.fine('VCardManager unavailable; skipping refresh.');
        return;
      }
      final startedRefresh = _startAvatarRefresh(bareJid);
      if (startedRefresh == null) {
        _avatarLog.fine('VCard refresh already in progress; skipping.');
        return;
      }
      refreshToken = startedRefresh;
      if (isSelf) {
        _emitSelfAvatarHydrating();
      }

      final vcardResult = await _withAvatarRefreshTimeout(
        manager.requestVCard(mox.JID.fromString(bareJid)),
        operationName: 'Avatar vCard fetch',
      );
      if (vcardResult.isType<mox.VCardError>()) {
        _avatarLog.fine('VCard request failed; aborting refresh.');
        return;
      }
      final vcard = vcardResult.get<mox.VCard>();
      final rawEncoded = vcard.photo?.binval?.trim();
      if (rawEncoded == null || rawEncoded.isEmpty) {
        _avatarLog.fine('VCard photo missing; aborting refresh.');
        return;
      }
      if (rawEncoded.length > _maxAvatarBase64Length * 2) {
        _avatarLog.fine('VCard photo payload too large; aborting refresh.');
        return;
      }
      final encoded = rawEncoded.replaceAll(RegExp(r'\s+'), '');
      if (encoded.isEmpty) {
        _avatarLog.fine('VCard photo payload empty after normalization.');
        return;
      }
      if (encoded.length > _maxAvatarBase64Length) {
        _avatarLog.fine('VCard photo payload exceeds max length.');
        return;
      }

      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) {
        _avatarLog.fine('VCard avatar bytes empty after decode.');
        return;
      }
      if (bytes.length > _maxAvatarBytes) {
        _avatarLog.fine('VCard avatar bytes exceed max size.');
        return;
      }

      if (!_ownsAvatarRefresh(bareJid, refreshToken)) {
        _avatarLog.fine('Dropping stale vCard refresh before write.');
        return;
      }
      final path = await _writeAvatarFile(bytes: bytes);
      if (!_ownsAvatarRefresh(bareJid, refreshToken)) {
        _avatarLog.fine('Dropping stale vCard refresh result.');
        return;
      }
      await _storeAvatar(jid: bareJid, path: path, hash: hash);
      _avatarLog.fine('VCard avatar stored successfully.');
    } catch (error, stackTrace) {
      _avatarLog.warning('Failed to refresh vCard avatar.', error, stackTrace);
    } finally {
      if (refreshToken != null) {
        _finishAvatarRefresh(bareJid, refreshToken);
        if (isSelf) {
          _emitSelfAvatarHydrating();
        }
      }
    }
  }

  Future<_AvatarMetadataLoadResult> _loadMetadata(String jid) async {
    final pubsub = _connection.getManager<mox.PubSubManager>();
    if (pubsub == null) {
      _avatarLog.fine('PubSubManager unavailable; cannot load metadata.');
      return const _AvatarMetadataLoadFailed();
    }
    const maxMetadataItems = 1;
    const metadataInfoTag = 'info';

    Future<moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>> getItems(
      int? maxItems,
    ) async => pubsub.getItems(
      mox.JID.fromString(jid),
      mox.userAvatarMetadataXmlns,
      maxItems: maxItems,
    );

    var result = await _withAvatarRefreshTimeout(
      getItems(maxMetadataItems),
      operationName: 'Avatar metadata fetch',
    );
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final shouldRetry =
          error is mox.EjabberdMaxItemsError ||
          error is mox.MalformedResponseError ||
          error is mox.UnknownPubSubError;
      _avatarLog.fine(
        'Metadata fetch failed with ${error.runtimeType}; retry=$shouldRetry.',
      );
      if (shouldRetry) {
        result = await _withAvatarRefreshTimeout(
          getItems(null),
          operationName: 'Avatar metadata fetch retry',
        );
      }
    }

    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      if (error is mox.ItemNotFoundError || error is mox.NoItemReturnedError) {
        _avatarLog.fine('Metadata fetch returned no items.');
        return const _AvatarMetadataMissing();
      }
      _avatarLog.fine('Metadata fetch failed after retry.');
      return const _AvatarMetadataLoadFailed();
    }

    final items = result.get<List<mox.PubSubItem>>();
    if (items.isEmpty) {
      _avatarLog.fine('Metadata fetch returned empty payload list.');
      return const _AvatarMetadataMissing();
    }

    final filteredItems = _filterAvatarItemsByPublisher(
      items: items,
      ownerBare: jid,
    );
    if (filteredItems.isEmpty) {
      _avatarLog.fine('Metadata filtered out by publisher checks.');
      return const _AvatarMetadataMissing();
    }

    final payload = filteredItems.first.payload;
    if (payload == null) {
      _avatarLog.fine('Metadata payload missing.');
      return const _AvatarMetadataLoadFailed();
    }

    final metadata = payload
        .findTags(metadataInfoTag)
        .map(mox.UserAvatarMetadata.fromXML)
        .toList();
    if (metadata.isEmpty) {
      _avatarLog.fine('Metadata payload contains no usable entries.');
      return const _AvatarMetadataMissing();
    }

    final selected = _selectMetadata(metadata);
    if (selected == null) {
      _avatarLog.fine('Metadata selection failed; no valid entries.');
      return const _AvatarMetadataLoadFailed();
    }

    return _AvatarMetadataLoaded(selected);
  }

  mox.UserAvatarMetadata? _selectMetadata(
    List<mox.UserAvatarMetadata> metadata,
  ) {
    if (metadata.isEmpty) return null;
    mox.UserAvatarMetadata? selected;
    var selectedArea = 0;
    var selectedLength = 0;
    for (final item in metadata) {
      if (item.length <= 0 || item.length > _maxAvatarBytes) continue;
      final area = (item.width ?? 0) * (item.height ?? 0);
      if (selected == null ||
          area > selectedArea ||
          (area == selectedArea && item.length > selectedLength)) {
        selected = item;
        selectedArea = area;
        selectedLength = item.length;
      }
    }
    return selected;
  }

  Future<String?> _storedAvatarHash(String jid) async {
    try {
      final hash = await _dbOpReturning<XmppDatabase, String?>((db) async {
        final roster = await db.getRosterItem(jid);
        if (roster?.avatarHash != null) return roster!.avatarHash;
        final chat = await db.getChat(jid);
        return chat?.avatarHash ?? chat?.contactAvatarHash;
      });
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
      final path = await _dbOpReturning<XmppDatabase, String?>((db) async {
        final roster = await db.getRosterItem(jid);
        if (roster?.avatarPath != null) return roster!.avatarPath;
        final chat = await db.getChat(jid);
        return chat?.avatarPath ?? chat?.contactAvatarPath;
      });
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

  Future<T> _withAvatarRefreshTimeout<T>(
    Future<T> future, {
    required String operationName,
  }) async {
    try {
      return await future.timeout(_avatarRefreshTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _avatarLog.fine('$operationName timed out.', error, stackTrace);
      rethrow;
    }
  }

  Future<void> _clearAvatarForJid(String jid, {String? reason}) async {
    final bareJid = _avatarSafeBareJid(jid);
    if (bareJid == null) return;
    final existingPath = await _storedAvatarPath(bareJid);
    final myBareJid = _myJid?.toBare().toString();
    final isSelf = myBareJid != null && myBareJid == bareJid;
    _avatarLog.fine(
      'Clearing avatar. isSelf=$isSelf reason=$reason '
      'hasCachedFile=${existingPath?.trim().isNotEmpty == true}.',
    );

    await _dbOp<XmppDatabase>((db) async {
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
    }, awaitDatabase: true);

    if (myBareJid != null && myBareJid == bareJid && isStateStoreReady) {
      await _persistStoredSelfAvatar(null);
      _setCachedSelfAvatar(null);
    }

    if (existingPath != null && existingPath.isNotEmpty) {
      _evictCachedAvatarBytes(existingPath);
      final cacheDirectory = await _avatarCacheDirectory();
      if (!_isSafeAvatarCachePath(
        cacheDirectory: cacheDirectory,
        filePath: existingPath,
      )) {
        _avatarLog.warning(
          'Refusing to delete avatar outside cache directory.',
        );
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
    await _dbOp<XmppDatabase>((db) async {
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
        await db.updateChatAvatar(jid: jid, avatarPath: path, avatarHash: hash);
      }
    }, awaitDatabase: true);
    if (myBareJid != null && myBareJid == jid) {
      await _persistOwnAvatar(path, hash);
      _setCachedSelfAvatar(Avatar(path: path, hash: hash));
    }
  }

  Future<void> _persistOwnAvatar(String path, String hash) async {
    if (!isStateStoreReady) return;
    final myBareJid = _myJid?.toBare().toString();
    if (myBareJid != null && myBareJid.isNotEmpty) {
      _markPubSubAvatarPreferred(myBareJid);
    }
    try {
      await _persistStoredSelfAvatar(Avatar(path: path, hash: hash));
    } on XmppAbortedException {
      return;
    }
  }

  Future<AvatarUploadResult> publishAvatar(
    AvatarUploadPayload payload, {
    bool public = true,
  }) async {
    if (connectionState != ConnectionState.connected) {
      throw XmppAvatarException(XmppDisconnectedException());
    }
    final targetJid = _avatarSafeBareJid(payload.jid ?? myJid);
    if (targetJid == null) {
      throw XmppAvatarException();
    }
    final shouldEmitOperation = _isSelfAvatarTarget(targetJid);
    if (shouldEmitOperation) {
      emitXmppOperation(_selfAvatarPublishStartEvent);
    }
    _avatarLog.fine('Publishing avatar. public=$public.');
    var success = false;
    try {
      final result = await _publishAvatarOnce(
        payload: payload,
        targetJid: targetJid,
        public: public,
      );
      _markPubSubAvatarPreferred(targetJid);
      if (_isSelfAvatarTarget(targetJid)) {
        await _clearPendingSelfAvatarPublish();
      }
      _avatarLog.fine('Avatar publish completed.');
      success = true;
      return result;
    } on XmppAvatarException catch (error, stackTrace) {
      final cause = error.wrapped;
      if (cause is mox.AvatarError || cause is mox.PubSubError) {
        if (!public) {
          rethrow;
        }
        const retryPublic = false;
        try {
          final result = await _publishAvatarOnce(
            payload: payload,
            targetJid: targetJid,
            public: retryPublic,
          );
          _markPubSubAvatarPreferred(targetJid);
          if (_isSelfAvatarTarget(targetJid)) {
            await _clearPendingSelfAvatarPublish();
          }
          _avatarLog.fine('Avatar publish completed.');
          success = true;
          return result;
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
            'Failed to publish avatar',
            retryError,
            retryStackTrace,
          );
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
    } finally {
      if (shouldEmitOperation) {
        emitXmppOperation(
          success
              ? _selfAvatarPublishSuccessEvent
              : _selfAvatarPublishFailureEvent,
        );
      }
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
    final presenceBasedDelivery = public
        ? presenceBasedDeliveryDisabled
        : presenceBasedDeliveryEnabled;
    final pubsub = _connection.getManager<PubSubManager>();
    if (pubsub == null) {
      _avatarLog.warning('PubSub unavailable; cannot publish avatar.');
      throw XmppAvatarException('PubSub is unavailable');
    }
    _avatarLog.fine('Preparing avatar publish payloads. public=$public.');
    final host = mox.JID.fromString(targetJid);
    final accessModel = public ? openAccessModel : presenceAccessModel;
    final dataPublishOptions = mox.PubSubPublishOptions(
      accessModel: accessModel,
      maxItems: maxPublishedAvatarItems,
      persistItems: persistItemsEnabled,
      publishModel: publishModelPublishers,
      sendLastPublishedItem: null,
    );
    final metadataPublishOptions = mox.PubSubPublishOptions(
      accessModel: accessModel,
      maxItems: maxPublishedAvatarItems,
      persistItems: persistItemsEnabled,
      publishModel: publishModelPublishers,
      sendLastPublishedItem: null,
    );
    final createNodeAccessModel = public
        ? mox.AccessModel.open
        : mox.AccessModel.presence;
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
      sendLastPublishedItem: null,
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
      sendLastPublishedItem: null,
    );

    final encodedData = await compute(
      _base64EncodeAvatarPublishPayload,
      payload.bytes,
    );
    final dataPayload = (mox.XmlBuilder.withNamespace(
      'data',
      mox.userAvatarDataXmlns,
    )..text(encodedData)).build();
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
      if (_configuredAvatarNodes.contains(cacheKey)) {
        _avatarLog.fine('Avatar node config cached; skipping configure.');
        return;
      }

      final configured = await pubsub
          .configureNode(host, node, config)
          .timeout(_avatarPublishTimeout);
      if (!configured.isType<mox.PubSubError>()) {
        _avatarLog.fine('Avatar node configured successfully.');
        _configuredAvatarNodes.add(cacheKey);
        return;
      }
      var configuredError = configured.get<mox.PubSubError>();
      _avatarLog.fine(
        'Avatar node configure failed with ${configuredError.runtimeType}.',
      );
      final shouldCreateNode = configuredError.indicatesMissingNode;
      if (!shouldCreateNode) {
        return;
      }

      try {
        await pubsub
            .createNodeWithConfig(
              host,
              config.withoutSendLastPublishedItem().toNodeConfig(),
              nodeId: node,
            )
            .timeout(_avatarPublishTimeout);
        final confirmed = await pubsub
            .configureNode(host, node, config)
            .timeout(_avatarPublishTimeout);
        if (!confirmed.isType<mox.PubSubError>()) {
          _avatarLog.fine('Avatar node created and configured successfully.');
          _configuredAvatarNodes.add(cacheKey);
          return;
        }
      } on Exception {
        // ignore and retry below
      }

      try {
        await pubsub
            .createNode(host, nodeId: node)
            .timeout(_avatarPublishTimeout);
        final confirmed = await pubsub
            .configureNode(host, node, config)
            .timeout(_avatarPublishTimeout);
        if (!confirmed.isType<mox.PubSubError>()) {
          _avatarLog.fine('Avatar node configured after create.');
          _configuredAvatarNodes.add(cacheKey);
          return;
        }
      } on Exception {
        return;
      }
    }

    Future<void> publishData() async {
      _avatarLog.fine('Publishing avatar data payload.');
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
            createNodeConfig: dataNodeConfig
                .withoutSendLastPublishedItem()
                .toNodeConfig(),
          )
          .timeout(_avatarPublishTimeout);
      if (result.isType<mox.PubSubError>()) {
        _avatarLog.fine(
          'Avatar data publish failed with '
          '${result.get<mox.PubSubError>().runtimeType}.',
        );
        throw XmppAvatarException(result.get<mox.PubSubError>());
      }
      _avatarLog.fine('Avatar data publish succeeded.');
    }

    Future<void> publishMetadata() async {
      _avatarLog.fine('Publishing avatar metadata payload.');
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
            createNodeConfig: metadataNodeConfig
                .withoutSendLastPublishedItem()
                .toNodeConfig(),
          )
          .timeout(_avatarPublishTimeout);
      if (result.isType<mox.PubSubError>()) {
        _avatarLog.fine(
          'Avatar metadata publish failed with '
          '${result.get<mox.PubSubError>().runtimeType}.',
        );
        throw XmppAvatarException(result.get<mox.PubSubError>());
      }
      _avatarLog.fine('Avatar metadata publish succeeded.');
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
      for (
        var attempt = 0;
        attempt < _avatarPublishVerificationAttempts;
        attempt++
      ) {
        _avatarLog.fine(
          'Verifying avatar publish. node=$node attempt=${attempt + 1}.',
        );
        final result = await pubsub
            .getItem(host, node, payload.hash)
            .timeout(_avatarPublishVerificationTimeout);
        if (result.isType<mox.PubSubError>()) {
          final error = result.get<mox.PubSubError>();
          final shouldRetry =
              isRetriableVerificationError(error) &&
              attempt + 1 < _avatarPublishVerificationAttempts;
          _avatarLog.fine(
            'Avatar verify failed with ${error.runtimeType}; '
            'retry=$shouldRetry.',
          );
          if (!shouldRetry) {
            return false;
          }
          await Future<void>.delayed(_avatarPublishVerificationDelay);
          continue;
        }

        final item = result.get<mox.PubSubItem>();
        final storedPayload = item.payload;
        final isValid =
            storedPayload != null &&
            storedPayload.tag == expectedTag &&
            storedPayload.attributes['xmlns'] == node &&
            (storedPayload.innerText().trim().isNotEmpty ||
                storedPayload.findTags(avatarMetadataInfoTag).isNotEmpty);
        if (isValid) {
          _avatarLog.fine('Avatar verify succeeded.');
          return true;
        }
        if (attempt + 1 >= _avatarPublishVerificationAttempts) {
          _avatarLog.fine('Avatar verify failed: payload invalid.');
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

    final path = await _writeAvatarFile(bytes: payload.bytes);
    await _storeAvatar(jid: targetJid, path: path, hash: payload.hash);
    final vCardManager = _connection.getManager<mox.VCardManager>();
    vCardManager?.setLastHash(targetJid, payload.hash);
    _avatarLog.fine('Avatar publish stored locally.');

    return AvatarUploadResult(path: path, hash: payload.hash);
  }

  String _avatarConfigKey({
    required String node,
    required mox.AccessModel accessModel,
  }) => '$node$_avatarConfigKeySeparator${accessModel.value}';

  Future<void> _maybeRepairSelfAvatar(String bareJid) async {
    final lastAttempt = _selfAvatarRepairLastAttempt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < _selfAvatarRepairCooldown) {
      _avatarLog.fine('Skipping self avatar repair; cooldown active.');
      return;
    }
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
    _selfAvatarRepairLastAttempt = DateTime.now();
    try {
      await _publishAvatarOnce(
        payload: payload,
        targetJid: bareJid,
        public: true,
      );
      _markPubSubAvatarPreferred(bareJid);
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

    final replay = _avatarLoadsInFlight[normalizedPath];
    if (replay != null) {
      return replay;
    }

    final nextReplay = _loadAvatarBytesInternal(normalizedPath);
    _avatarLoadsInFlight[normalizedPath] = nextReplay;
    try {
      return await nextReplay;
    } finally {
      if (identical(_avatarLoadsInFlight[normalizedPath], nextReplay)) {
        _avatarLoadsInFlight.remove(normalizedPath);
      }
    }
  }

  Future<Uint8List?> _loadAvatarBytesInternal(String normalizedPath) async {
    if (normalizedPath.isEmpty) return null;

    return _runAvatarFileOperation(normalizedPath, () async {
      final cacheDirectory = await _avatarCacheDirectory();
      if (!_isSafeAvatarCachePath(
        cacheDirectory: cacheDirectory,
        filePath: normalizedPath,
      )) {
        _avatarLog.warning('Rejected avatar path outside cache directory.');
        await _invalidateCachedAvatarPath(normalizedPath, deleteFile: false);
        return null;
      }

      final cached = cachedAvatarBytes(normalizedPath);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      final file = File(normalizedPath);
      if (!await file.exists()) {
        _avatarLog.fine('Cached avatar file missing; clearing stale path.');
        await _invalidateCachedAvatarPath(normalizedPath, deleteFile: false);
        return null;
      }
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          _avatarLog.warning('Cached avatar file empty; clearing cache entry.');
          await _invalidateCachedAvatarPath(normalizedPath, deleteFile: true);
          return null;
        }
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
        if (decrypted.isEmpty) {
          _avatarLog.warning(
            'Cached avatar decrypted to an empty payload; clearing cache entry.',
          );
          await _invalidateCachedAvatarPath(normalizedPath, deleteFile: true);
          return null;
        }
        _cacheAvatarBytes(normalizedPath, decrypted);
        return decrypted;
      } on Exception catch (error, stackTrace) {
        _avatarLog.warning(
          'Failed to load cached avatar; deleting corrupted cache entry.',
          error,
          stackTrace,
        );
        await _invalidateCachedAvatarPath(normalizedPath, deleteFile: true);
        return null;
      }
    });
  }

  Future<T> _runAvatarFileOperation<T>(
    String path,
    Future<T> Function() operation,
  ) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return operation();
    }

    final previous = _avatarFileOperations[normalizedPath];
    final completer = Completer<void>();
    final next = completer.future;
    _avatarFileOperations[normalizedPath] = next;
    if (previous != null) {
      await previous;
    }

    try {
      return await operation();
    } finally {
      completer.complete();
      if (identical(_avatarFileOperations[normalizedPath], next)) {
        _avatarFileOperations.remove(normalizedPath);
      }
    }
  }

  Future<void> _invalidateCachedAvatarPath(
    String path, {
    required bool deleteFile,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return;

    _evictCachedAvatarBytes(normalizedPath);
    try {
      await _dbOp<XmppDatabase>(
        (db) => db.clearAvatarReferencesForPath(path: normalizedPath),
        awaitDatabase: true,
      );
    } on XmppAbortedException {
      return;
    }

    await _clearSelfAvatarReferenceIfPathMatches(normalizedPath);
    await _clearPendingSelfAvatarIfPathMatches(normalizedPath);

    if (!deleteFile) return;
    final file = File(normalizedPath);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine(
        'Failed to delete invalid cached avatar file.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _clearSelfAvatarReferenceIfPathMatches(String path) async {
    if (!isStateStoreReady) return;

    String? storedPath;
    try {
      storedPath = await _dbOpReturning<XmppStateStore, String?>(
        (ss) => ss.read(key: selfAvatarPathKey) as String?,
      );
    } on XmppAbortedException {
      return;
    }
    if (storedPath?.trim() != path) return;

    try {
      await _persistStoredSelfAvatar(null);
    } on XmppAbortedException {
      return;
    }

    _setCachedSelfAvatar(null);
  }

  Future<void> _clearPendingSelfAvatarIfPathMatches(String path) async {
    if (!isStateStoreReady) return;
    final pending = await _readPendingSelfAvatarPublish();
    if (pending?.path.trim() != path) return;
    await _clearPendingSelfAvatarPublish();
  }

  bool _isSelfAvatarTarget(String targetJid) =>
      _avatarSafeBareJid(targetJid) == _myJid?.toBare().toString();

  Future<void> _persistPendingSelfAvatarPublish({
    required String path,
    required AvatarUploadPayload payload,
    required bool public,
  }) async {
    if (!isStateStoreReady || avatarEncryptionKey == null) return;
    final pending = _PendingSelfAvatarPublish(
      path: path,
      hash: payload.hash,
      mimeType: payload.mimeType,
      width: payload.width,
      height: payload.height,
      public: public,
      jid: payload.jid,
    );
    try {
      await _dbOp<XmppStateStore>(
        (ss) => ss.write(
          key: selfAvatarPendingPublishKey,
          value: jsonEncode(pending.toJson()),
        ),
        awaitDatabase: true,
      );
    } on XmppAbortedException {
      return;
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine(
        'Failed to persist pending self avatar publish.',
        error,
        stackTrace,
      );
    }
  }

  Avatar? _readStoredSelfAvatar(XmppStateStore store) {
    final rawStored = store.read(key: _selfAvatarStateKey);
    final encoded = rawStored is Map
        ? Map<Object?, Object?>.from(rawStored)
        : null;
    if (encoded != null) {
      final path = encoded[_storedAvatarPathField] as String?;
      final hash = encoded[_storedAvatarHashField] as String?;
      return Avatar.tryParseOrNull(path: path, hash: hash);
    }
    final path = store.read(key: selfAvatarPathKey) as String?;
    final hash = store.read(key: selfAvatarHashKey) as String?;
    return Avatar.tryParseOrNull(path: path, hash: hash);
  }

  Future<void> _persistStoredSelfAvatar(Avatar? avatar) async {
    await _dbOp<XmppStateStore>((store) async {
      await store.writeAll(
        data: <RegisteredStateKey, Object?>{
          selfAvatarPathKey: avatar?.path,
          selfAvatarHashKey: avatar?.hash,
          _selfAvatarStateKey: avatar == null
              ? null
              : <String, String?>{
                  _storedAvatarPathField: avatar.path,
                  _storedAvatarHashField: avatar.hash,
                },
        },
      );
    }, awaitDatabase: true);
  }

  bool _storedAvatarsMatch(Avatar? left, Avatar? right) =>
      left?.path == right?.path && left?.hash == right?.hash;

  Future<_PendingSelfAvatarPublish?> _readPendingSelfAvatarPublish() async {
    if (!isStateStoreReady) return null;
    try {
      final raw = await _dbOpReturning<XmppStateStore, String?>(
        (ss) async => ss.read(key: selfAvatarPendingPublishKey) as String?,
      );
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return _PendingSelfAvatarPublish.fromJson(decoded);
    } on XmppAbortedException {
      return null;
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine(
        'Failed to read pending self avatar publish.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> _clearPendingSelfAvatarPublish() async {
    if (!isStateStoreReady) return;
    try {
      await _dbOp<XmppStateStore>(
        (ss) => ss.write(key: selfAvatarPendingPublishKey, value: null),
        awaitDatabase: true,
      );
    } on XmppAbortedException {
      return;
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine(
        'Failed to clear pending self avatar publish.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _publishPendingSelfAvatarIfAvailable() async {
    final pending = await _readPendingSelfAvatarPublish();
    if (pending == null) return;
    final myBareJid = _myJid?.toBare().toString();
    if (myBareJid == null || myBareJid.isEmpty) return;
    final targetJid = _avatarSafeBareJid(pending.jid ?? myBareJid);
    if (targetJid == null || targetJid != myBareJid) {
      await _clearPendingSelfAvatarPublish();
      return;
    }
    final bytes = await loadAvatarBytes(pending.path);
    if (bytes == null || bytes.isEmpty) {
      await _clearPendingSelfAvatarPublish();
      return;
    }
    final payload = AvatarUploadPayload(
      bytes: bytes,
      mimeType: pending.mimeType,
      width: pending.width,
      height: pending.height,
      hash: pending.hash,
      jid: pending.jid,
    );
    try {
      await publishAvatar(payload, public: pending.public);
    } on Exception catch (error, stackTrace) {
      _avatarLog.fine('Pending self avatar publish failed.', error, stackTrace);
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
      ..setRange(combinedLength - macBytes.length, combinedLength, macBytes);
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
    final cipherText = encrypted.sublist(
      nonceLength,
      encrypted.length - macLength,
    );
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final decrypted = await _avatarCipher.decrypt(box, secretKey: key);
    return Uint8List.fromList(decrypted);
  }

  Future<String> _writeAvatarFile({required List<int> bytes}) async {
    final directory = await _avatarCacheDirectory();
    final contentHash = sha256.convert(bytes).toString();
    final filename = '$contentHash.enc';
    final file = File(p.join(directory.path, filename));

    return _runAvatarFileOperation(file.path, () async {
      final encrypted = await _encryptAvatarBytes(bytes);
      final tempFile = File(
        '${file.path}.${DateTime.timestamp().microsecondsSinceEpoch}.tmp',
      );
      try {
        await tempFile.writeAsBytes(encrypted, flush: true);
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
      } on Exception {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } on Exception {
          // Ignore cleanup failures before surfacing the original error.
        }
        rethrow;
      }

      final rawBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      _cacheAvatarBytes(file.path, rawBytes);
      return file.path;
    });
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

  void _markPubSubAvatarPreferred(String bareJid) {
    final normalized = bareJid.trim();
    if (normalized.isEmpty) return;
    _pubSubAvatarJids.add(normalized);
  }

  void _unmarkPubSubAvatarPreferred(String bareJid) {
    final normalized = bareJid.trim();
    if (normalized.isEmpty) return;
    _pubSubAvatarJids.remove(normalized);
  }

  bool _isPubSubAvatarPreferred(String bareJid) {
    final normalized = bareJid.trim();
    if (normalized.isEmpty) return false;
    return _pubSubAvatarJids.contains(normalized);
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
