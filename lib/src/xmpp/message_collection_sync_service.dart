// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _messageCollectionSyncSourceKeyName =
    'message_collection_sync_source_id';
const String _messageCollectionSyncPendingPublishesKeyName =
    'message_collection_sync_pending_publishes';
const String _messageCollectionSyncFlushPendingOperationName =
    'MessageCollectionSyncService.flushPendingOnResume';
const String _messageCollectionSyncSnapshotBootstrapOperationName =
    'MessageCollectionSyncService.bootstrapSnapshotOnNegotiations';

final _messageCollectionSyncSourceKey = XmppStateStore.registerKey(
  _messageCollectionSyncSourceKeyName,
);
final _messageCollectionSyncPendingPublishesKey = XmppStateStore.registerKey(
  _messageCollectionSyncPendingPublishesKeyName,
);

enum _MessageCollectionSyncDecision { applyRemote, publishLocal, skip }

mixin MessageCollectionSyncService on XmppBase, BaseStreamService {
  bool _messageCollectionSnapshotInFlight = false;
  String? _messageCollectionSourceId;
  bool _pendingMessageCollectionSyncLoaded = false;
  final Set<String> _pendingMessageCollectionPublishes = {};

  MessageCollectionsPubSubManager? get _messageCollectionsManager =>
      _connection.getManager<MessageCollectionsPubSubManager>();

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (event.resumed) {
          fireAndForget(
            _flushPendingMessageCollectionSync,
            operationName: _messageCollectionSyncFlushPendingOperationName,
          );
          return;
        }
        fireAndForget(
          syncMessageCollectionsSnapshot,
          operationName: _messageCollectionSyncSnapshotBootstrapOperationName,
        );
      })
      ..registerHandler<MessageCollectionSyncUpdatedEvent>((event) async {
        await _applyMessageCollectionSyncUpdate(event.payload);
      });
  }

  @override
  Future<void> publishMessageCollectionSyncEntry(
    MessageCollectionMembershipEntry entry,
  ) async {
    await _publishMessageCollectionSyncEntry(entry);
  }

  Future<void> syncMessageCollectionsSnapshot() async {
    if (_messageCollectionSnapshotInFlight || !_hasUsableXmppStream) {
      return;
    }
    _messageCollectionSnapshotInFlight = true;
    try {
      await database;
      if (!_hasUsableXmppStream) {
        return;
      }
      await _ensurePendingMessageCollectionSyncLoaded();
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'message collection sync',
      );
      if (!decision.isAllowed) {
        return;
      }
      final manager = _messageCollectionsManager;
      if (manager == null) {
        return;
      }
      await manager.ensureNode();
      await manager.subscribe();
      await _flushPendingMessageCollectionSync();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return;
      }

      final localEntries = await _localMessageCollectionEntries(
        includeInactive: true,
      );
      final localByItemId = <String, MessageCollectionMembershipEntry>{
        for (final entry in localEntries)
          _messageCollectionSyncItemId(entry): entry,
      };

      for (final remote in snapshot.items) {
        final local = localByItemId.remove(remote.itemId);
        if (local == null) {
          await _applyMessageCollectionSyncUpdate(remote);
          continue;
        }
        switch (_resolveMessageCollectionSyncDecision(local, remote)) {
          case _MessageCollectionSyncDecision.applyRemote:
            await _applyMessageCollectionSyncUpdate(remote);
          case _MessageCollectionSyncDecision.publishLocal:
            await _publishMessageCollectionSyncEntry(local);
          case _MessageCollectionSyncDecision.skip:
            continue;
        }
      }

      for (final local in localByItemId.values) {
        await _publishMessageCollectionSyncEntry(local);
      }
      await _flushPendingMessageCollectionSync();
    } on XmppAbortedException {
      return;
    } finally {
      _messageCollectionSnapshotInFlight = false;
    }
  }

  Future<void> _publishMessageCollectionSyncEntry(
    MessageCollectionMembershipEntry entry,
  ) async {
    final itemId = _messageCollectionSyncItemId(entry);
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (!_hasUsableXmppStream) {
      await _queueMessageCollectionPublish(itemId);
      return;
    }
    final support = await refreshPubSubSupport();
    final decision = decidePubSubSupport(
      supported: support.canUsePepNodes,
      featureLabel: 'message collection sync',
    );
    if (!decision.isAllowed) {
      return;
    }
    final manager = _messageCollectionsManager;
    if (manager == null) {
      await _queueMessageCollectionPublish(itemId);
      return;
    }
    await manager.ensureNode();
    await manager.subscribe();
    final payload = await _buildMessageCollectionPayload(entry);
    final published = await manager.publishEntry(payload);
    if (published) {
      await _clearPendingMessageCollectionPublish(itemId);
      return;
    }
    await _queueMessageCollectionPublish(itemId);
  }

  Future<void> _applyMessageCollectionSyncUpdate(
    MessageCollectionSyncPayload payload,
  ) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.applyMessageCollectionMembershipMutation(
        collectionId: payload.collectionId,
        chatJid: payload.chatJid,
        messageReferenceId: payload.messageReferenceId,
        messageStanzaId: payload.messageStanzaId,
        messageOriginId: payload.messageOriginId,
        messageMucStanzaId: payload.messageMucStanzaId,
        deltaAccountId: payload.deltaMsgId == null
            ? null
            : payload.deltaAccountId,
        deltaMsgId: payload.deltaMsgId,
        addedAt: payload.updatedAt.toUtc(),
        active: payload.active,
      );
      await db.normalizeMessageCollectionMembershipAliases(
        collectionId: payload.collectionId,
        chatJid: payload.chatJid,
        canonicalMessageReferenceId: payload.messageReferenceId,
        aliases: payload.aliases,
        messageStanzaId: payload.messageStanzaId,
        messageOriginId: payload.messageOriginId,
        messageMucStanzaId: payload.messageMucStanzaId,
        deltaAccountId: payload.deltaMsgId == null
            ? null
            : payload.deltaAccountId,
        deltaMsgId: payload.deltaMsgId,
      );
    });
  }

  _MessageCollectionSyncDecision _resolveMessageCollectionSyncDecision(
    MessageCollectionMembershipEntry local,
    MessageCollectionSyncPayload remote,
  ) {
    final localUpdatedAt = local.addedAt.toUtc();
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return _MessageCollectionSyncDecision.applyRemote;
    }
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return _MessageCollectionSyncDecision.publishLocal;
    }
    if (local.active != remote.active) {
      return remote.active
          ? _MessageCollectionSyncDecision.publishLocal
          : _MessageCollectionSyncDecision.applyRemote;
    }
    final localAliasScore = _messageCollectionAliasScore(
      stanzaId: local.messageStanzaId,
      originId: local.messageOriginId,
      mucStanzaId: local.messageMucStanzaId,
      deltaAccountId: local.deltaAccountId,
      deltaMsgId: local.deltaMsgId,
    );
    final remoteAliasScore = _messageCollectionAliasScore(
      stanzaId: remote.messageStanzaId,
      originId: remote.messageOriginId,
      mucStanzaId: remote.messageMucStanzaId,
      deltaAccountId: remote.deltaAccountId,
      deltaMsgId: remote.deltaMsgId,
    );
    if (remoteAliasScore > localAliasScore) {
      return _MessageCollectionSyncDecision.applyRemote;
    }
    if (localAliasScore > remoteAliasScore) {
      return _MessageCollectionSyncDecision.publishLocal;
    }
    return _MessageCollectionSyncDecision.skip;
  }

  int _messageCollectionAliasScore({
    required String? stanzaId,
    required String? originId,
    required String? mucStanzaId,
    required int? deltaAccountId,
    required int? deltaMsgId,
  }) {
    var score = 0;
    if (stanzaId?.trim().isNotEmpty == true) {
      score += 1;
    }
    if (originId?.trim().isNotEmpty == true) {
      score += 1;
    }
    if (mucStanzaId?.trim().isNotEmpty == true) {
      score += 1;
    }
    if (deltaAccountId != null && deltaMsgId != null) {
      score += 1;
    }
    return score;
  }

  Future<MessageCollectionSyncPayload> _buildMessageCollectionPayload(
    MessageCollectionMembershipEntry entry,
  ) async {
    return MessageCollectionSyncPayload(
      collectionId: entry.collectionId,
      chatJid: entry.chatJid,
      messageReferenceId: entry.messageReferenceId,
      messageStanzaId: entry.messageStanzaId,
      messageOriginId: entry.messageOriginId,
      messageMucStanzaId: entry.messageMucStanzaId,
      deltaAccountId: entry.deltaMsgId == null ? null : entry.deltaAccountId,
      deltaMsgId: entry.deltaMsgId,
      updatedAt: entry.addedAt.toUtc(),
      active: entry.active,
      sourceId: await _ensureMessageCollectionSyncSourceId(),
    );
  }

  Future<List<MessageCollectionMembershipEntry>>
  _localMessageCollectionEntries({bool includeInactive = false}) async {
    return await _dbOpReturning<
      XmppDatabase,
      List<MessageCollectionMembershipEntry>
    >(
      (db) => db.getAllMessageCollectionMemberships(
        includeInactive: includeInactive,
      ),
    );
  }

  String _messageCollectionSyncItemId(MessageCollectionMembershipEntry entry) =>
      MessageCollectionSyncPayload.itemIdFor(
        collectionId: entry.collectionId,
        chatJid: entry.chatJid,
        messageReferenceId: entry.messageReferenceId,
      );

  Future<String> _ensureMessageCollectionSyncSourceId() async {
    final existing = _messageCollectionSourceId?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = const Uuid().v4();
    await _dbOp<XmppStateStore>(
      (ss) async =>
          ss.write(key: _messageCollectionSyncSourceKey, value: generated),
      awaitDatabase: true,
    );
    _messageCollectionSourceId = generated;
    return generated;
  }

  Future<void> _ensurePendingMessageCollectionSyncLoaded() async {
    if (_pendingMessageCollectionSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>((ss) async {
      final rawSource = ss.read(key: _messageCollectionSyncSourceKey);
      final rawPublishes =
          (ss.read(key: _messageCollectionSyncPendingPublishesKey) as List?)
              ?.cast<Object?>();
      _messageCollectionSourceId = rawSource?.toString().trim();
      _pendingMessageCollectionPublishes
        ..clear()
        ..addAll(_normalizePendingMessageCollectionIds(rawPublishes));
    }, awaitDatabase: true);
    _pendingMessageCollectionSyncLoaded = true;
  }

  Iterable<String> _normalizePendingMessageCollectionIds(
    List<Object?>? raw,
  ) sync* {
    if (raw == null || raw.isEmpty) {
      return;
    }
    for (final entry in raw) {
      final normalized = entry?.toString().trim();
      if (normalized == null || normalized.isEmpty) {
        continue;
      }
      yield normalized;
    }
  }

  Future<void> _persistPendingMessageCollectionSync() async {
    if (!_pendingMessageCollectionSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(
        key: _messageCollectionSyncPendingPublishesKey,
        value: _pendingMessageCollectionPublishes.toList(growable: false),
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueMessageCollectionPublish(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingMessageCollectionSyncLoaded();
    _pendingMessageCollectionPublishes.add(normalized);
    await _persistPendingMessageCollectionSync();
  }

  Future<void> _clearPendingMessageCollectionPublish(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingMessageCollectionSyncLoaded();
    final removed = _pendingMessageCollectionPublishes.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingMessageCollectionSync();
  }

  Future<void> _flushPendingMessageCollectionSync() async {
    await _ensurePendingMessageCollectionSyncLoaded();
    if (_pendingMessageCollectionPublishes.isEmpty || !_hasUsableXmppStream) {
      return;
    }
    final support = await refreshPubSubSupport();
    final decision = decidePubSubSupport(
      supported: support.canUsePepNodes,
      featureLabel: 'message collection sync',
    );
    if (!decision.isAllowed) {
      return;
    }
    final manager = _messageCollectionsManager;
    if (manager == null) {
      return;
    }
    await manager.ensureNode();
    await manager.subscribe();
    final localEntries = await _localMessageCollectionEntries(
      includeInactive: true,
    );
    final localByItemId = <String, MessageCollectionMembershipEntry>{
      for (final entry in localEntries)
        _messageCollectionSyncItemId(entry): entry,
    };
    final pendingPublishes = _pendingMessageCollectionPublishes.toList(
      growable: false,
    );
    for (final itemId in pendingPublishes) {
      final localEntry = localByItemId[itemId];
      if (localEntry == null) {
        _pendingMessageCollectionPublishes.remove(itemId);
        continue;
      }
      final published = await manager.publishEntry(
        await _buildMessageCollectionPayload(localEntry),
      );
      if (published) {
        _pendingMessageCollectionPublishes.remove(itemId);
      }
    }
    await _persistPendingMessageCollectionSync();
  }
}
