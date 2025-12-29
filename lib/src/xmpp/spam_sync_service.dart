part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _spamSyncSourceKeyName = 'spam_sync_source_id';
const String _spamSyncPendingPublishesKeyName = 'spam_sync_pending_publishes';
const String _spamSyncPendingRetractionsKeyName =
    'spam_sync_pending_retractions';
const String _spamSyncSnapshotAtKeyName = 'spam_sync_last_snapshot_at';
const String _spamSyncSnapshotIdsKeyName = 'spam_sync_last_snapshot_ids';

final _spamSyncSourceKey = XmppStateStore.registerKey(
  _spamSyncSourceKeyName,
);
final _spamSyncPendingPublishesKey = XmppStateStore.registerKey(
  _spamSyncPendingPublishesKeyName,
);
final _spamSyncPendingRetractionsKey = XmppStateStore.registerKey(
  _spamSyncPendingRetractionsKeyName,
);
final _spamSyncSnapshotAtKey = XmppStateStore.registerKey(
  _spamSyncSnapshotAtKeyName,
);
final _spamSyncSnapshotIdsKey = XmppStateStore.registerKey(
  _spamSyncSnapshotIdsKeyName,
);

enum _SpamSyncDecision {
  applyRemote,
  publishLocal,
  skip,
}

mixin SpamSyncService on XmppBase, BaseStreamService {
  bool _spamSnapshotInFlight = false;
  String? _spamSourceId;
  bool _pendingSpamSyncLoaded = false;
  final Set<String> _pendingSpamPublishes = {};
  final Set<String> _pendingSpamRetractions = {};
  bool _spamSnapshotMetaLoaded = false;
  DateTime? _spamLastSnapshotAt;
  final Set<String> _spamLastSnapshotIds = {};

  SpamPubSubManager? get _spamManager =>
      _connection.getManager<SpamPubSubManager>();

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (connectionState != ConnectionState.connected) return;
        if (event.resumed) {
          unawaited(_flushPendingSpamSync());
          return;
        }
        unawaited(syncSpamSnapshot());
      })
      ..registerHandler<SpamSyncUpdatedEvent>((event) async {
        await _applySpamSyncUpdate(event.payload);
      })
      ..registerHandler<SpamSyncRetractedEvent>((event) async {
        await _applySpamSyncRetraction(event.jid);
      });
  }

  Stream<List<EmailSpamEntry>> spamlistStream() =>
      createPaginatedStream<EmailSpamEntry, XmppDatabase>(
        watchFunction: (db) async => db.watchEmailSpamlist(),
        getFunction: (db) => db.getEmailSpamlist(),
      );

  Future<void> syncSpamSnapshot() async {
    if (_spamSnapshotInFlight) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    _spamSnapshotInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) {
        return;
      }
      await _ensurePendingSpamSyncLoaded();
      final support = await refreshPubSubSupport();
      if (!support.canUsePepNodes) {
        return;
      }
      final manager = _spamManager;
      if (manager == null) {
        return;
      }
      await manager.ensureNode();
      await manager.subscribe();
      await _flushPendingSpamSync();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return;
      }
      await _ensureSpamSnapshotMetaLoaded();
      final snapshotTimestamp = DateTime.timestamp().toUtc();
      final isSnapshotComplete = snapshot.isComplete;

      final remoteItems = snapshot.items;
      final remoteByJid = <String, SpamSyncPayload>{};
      for (final item in remoteItems) {
        final normalized = item.jid.trim().toLowerCase();
        if (normalized.isEmpty) {
          continue;
        }
        remoteByJid[normalized] = item;
      }
      final remoteIds = remoteByJid.keys.toSet();

      final localItems =
          await _dbOpReturning<XmppDatabase, List<EmailSpamEntry>>(
        (db) => db.getEmailSpamlist(),
      );
      final localByJid = <String, EmailSpamEntry>{};
      for (final item in localItems) {
        final normalized = item.address.trim().toLowerCase();
        if (normalized.isEmpty) {
          continue;
        }
        localByJid[normalized] = item;
      }
      final localSourceId = await _ensureSpamSourceId();
      final previousSnapshotAt = _spamLastSnapshotAt;
      final previousSnapshotIds = Set<String>.of(_spamLastSnapshotIds);

      for (final entry in remoteByJid.entries) {
        final remoteJid = entry.key;
        final remote = entry.value;
        if (_pendingSpamRetractions.contains(remoteJid)) {
          await retractSpamSync(remoteJid);
          continue;
        }
        final local = localByJid[remoteJid];
        if (local == null) {
          await _applySpamStatus(
            jid: remoteJid,
            spam: true,
            updatedAt: remote.updatedAt,
            sourceId: remote.sourceId,
            origin: anti_abuse.SyncOrigin.remote,
          );
          continue;
        }
        final decision = _resolveSpamSyncDecision(
          local: local,
          remote: remote,
          localSourceId: localSourceId,
        );
        switch (decision) {
          case _SpamSyncDecision.applyRemote:
            await _applySpamStatus(
              jid: remoteJid,
              spam: true,
              updatedAt: remote.updatedAt,
              sourceId: remote.sourceId,
              origin: anti_abuse.SyncOrigin.remote,
            );
          case _SpamSyncDecision.publishLocal:
            await publishSpamSync(local);
          case _SpamSyncDecision.skip:
            continue;
        }
      }

      for (final entry in localByJid.entries) {
        final jid = entry.key;
        final local = entry.value;
        if (remoteByJid.containsKey(jid)) {
          continue;
        }
        if (_shouldApplyMissingSpamDeletion(
          jid: jid,
          localUpdatedAt: local.flaggedAt,
          entrySourceId: local.sourceId,
          localSourceId: localSourceId,
          lastSnapshotAt: previousSnapshotAt,
          previousSnapshotIds: previousSnapshotIds,
          isSnapshotComplete: isSnapshotComplete,
        )) {
          await _applySpamStatus(
            jid: jid,
            spam: false,
            updatedAt: snapshotTimestamp,
            sourceId: await _ensureSpamSourceId(),
            origin: anti_abuse.SyncOrigin.remote,
          );
          continue;
        }
        await publishSpamSync(local);
      }
      if (isSnapshotComplete) {
        await _persistSpamSnapshotMeta(
          snapshotAt: snapshotTimestamp,
          remoteIds: remoteIds,
        );
      }
    } on XmppAbortedException {
      return;
    } finally {
      _spamSnapshotInFlight = false;
    }
  }

  Future<void> setSpamStatus({
    required String jid,
    required bool spam,
  }) async {
    final normalized = jid.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final updatedAt = DateTime.timestamp().toUtc();
    final sourceId = await _ensureSpamSourceId();
    await _applySpamStatus(
      jid: normalized,
      spam: spam,
      updatedAt: updatedAt,
      sourceId: sourceId,
      origin: anti_abuse.SyncOrigin.local,
    );
    if (spam) {
      await publishSpamSync(
        EmailSpamEntry(
          address: normalized,
          flaggedAt: updatedAt,
          sourceId: sourceId,
        ),
      );
      return;
    }
    await retractSpamSync(normalized);
  }

  Future<void> publishSpamSync(EmailSpamEntry entry) async {
    final normalized = entry.address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      await _queueSpamPublish(normalized);
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      await _queueSpamPublish(normalized);
      return;
    }
    final manager = _spamManager;
    if (manager == null) {
      await _queueSpamPublish(normalized);
      return;
    }
    await manager.ensureNode();
    final payload = SpamSyncPayload(
      jid: normalized,
      updatedAt: entry.flaggedAt.toUtc(),
      sourceId: _normalizeSpamSourceId(entry.sourceId),
    );
    final published = await manager.publishSpam(payload);
    if (published) {
      await _clearPendingSpamPublish(normalized);
    } else {
      await _queueSpamPublish(normalized);
    }
  }

  Future<void> retractSpamSync(String jid) async {
    final normalized = jid.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      await _queueSpamRetraction(normalized);
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      await _queueSpamRetraction(normalized);
      return;
    }
    final manager = _spamManager;
    if (manager == null) {
      await _queueSpamRetraction(normalized);
      return;
    }
    final retracted = await manager.retractSpam(normalized);
    if (retracted) {
      await _clearPendingSpamRetraction(normalized);
    } else {
      await _queueSpamRetraction(normalized);
    }
  }

  Future<void> _applySpamSyncUpdate(SpamSyncPayload payload) async {
    await _ensurePendingSpamSyncLoaded();
    if (_pendingSpamRetractions.contains(payload.jid)) {
      await retractSpamSync(payload.jid);
      return;
    }

    final localEntry = await _dbOpReturning<XmppDatabase, EmailSpamEntry?>(
      (db) => db.getEmailSpamEntry(payload.jid),
    );
    if (localEntry != null) {
      final decision = _resolveSpamSyncDecision(
        local: localEntry,
        remote: payload,
        localSourceId: await _ensureSpamSourceId(),
      );
      switch (decision) {
        case _SpamSyncDecision.applyRemote:
          await _applySpamStatus(
            jid: payload.jid,
            spam: true,
            updatedAt: payload.updatedAt,
            sourceId: payload.sourceId,
            origin: anti_abuse.SyncOrigin.remote,
          );
        case _SpamSyncDecision.publishLocal:
          await publishSpamSync(localEntry);
        case _SpamSyncDecision.skip:
          return;
      }
      return;
    }

    await _applySpamStatus(
      jid: payload.jid,
      spam: true,
      updatedAt: payload.updatedAt,
      sourceId: payload.sourceId,
      origin: anti_abuse.SyncOrigin.remote,
    );
    await _clearPendingSpamPublish(payload.jid);
  }

  Future<void> _applySpamSyncRetraction(String jid) async {
    await _ensurePendingSpamSyncLoaded();
    final normalized = jid.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (_pendingSpamPublishes.contains(normalized)) {
      return;
    }
    await _applySpamStatus(
      jid: normalized,
      spam: false,
      updatedAt: DateTime.timestamp().toUtc(),
      sourceId: await _ensureSpamSourceId(),
      origin: anti_abuse.SyncOrigin.remote,
    );
    await _clearPendingSpamRetraction(normalized);
  }

  _SpamSyncDecision _resolveSpamSyncDecision({
    required EmailSpamEntry local,
    required SpamSyncPayload remote,
    required String localSourceId,
  }) {
    final localUpdatedAt = local.flaggedAt.toUtc();
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    if (localUpdatedAt.isBefore(remoteUpdatedAt)) {
      return _SpamSyncDecision.applyRemote;
    }
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return _SpamSyncDecision.publishLocal;
    }
    final localSource = _normalizeSpamSourceId(local.sourceId);
    if (localSource == remote.sourceId) {
      return _SpamSyncDecision.skip;
    }
    if (localSourceId == localSource) {
      return _SpamSyncDecision.publishLocal;
    }
    return _SpamSyncDecision.applyRemote;
  }

  Future<void> _applySpamStatus({
    required String jid,
    required bool spam,
    required DateTime updatedAt,
    required String sourceId,
    required anti_abuse.SyncOrigin origin,
  }) async {
    final normalized = jid.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _dbOp<XmppDatabase>(
      (db) async {
        if (spam) {
          await db.addEmailSpam(
            normalized,
            flaggedAt: updatedAt,
            sourceId: sourceId,
          );
        } else {
          await db.removeEmailSpam(normalized);
        }
        await db.markChatSpam(
          jid: normalized,
          spam: spam,
          spamUpdatedAt: spam ? updatedAt : null,
        );
      },
    );
    final callback = emailSpamSyncCallback;
    if (callback != null) {
      await callback(
        anti_abuse.SpamSyncUpdate(
          address: normalized,
          isSpam: spam,
          updatedAt: updatedAt,
          sourceId: sourceId,
          origin: origin,
        ),
      );
    }
  }

  String _normalizeSpamSourceId(String? sourceId) {
    final normalized = sourceId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return anti_abuse.syncLegacySourceId;
    }
    return normalized;
  }

  Future<String> _ensureSpamSourceId() async {
    final cached = _spamSourceId;
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }
    final stored = await _dbOpReturning<XmppStateStore, String?>(
      (ss) async => ss.read(key: _spamSyncSourceKey) as String?,
    );
    final trimmed = stored?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      _spamSourceId = trimmed;
      return trimmed;
    }
    final generated = uuid.v4();
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(
        key: _spamSyncSourceKey,
        value: generated,
      ),
    );
    _spamSourceId = generated;
    return generated;
  }

  Future<void> _ensurePendingSpamSyncLoaded() async {
    if (_pendingSpamSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async {
        final rawPublishes =
            (ss.read(key: _spamSyncPendingPublishesKey) as List?)
                ?.cast<Object?>();
        final rawRetractions =
            (ss.read(key: _spamSyncPendingRetractionsKey) as List?)
                ?.cast<Object?>();
        _pendingSpamPublishes
          ..clear()
          ..addAll(_normalizeSpamSyncIds(rawPublishes));
        _pendingSpamRetractions
          ..clear()
          ..addAll(_normalizeSpamSyncIds(rawRetractions));
      },
      awaitDatabase: true,
    );
    _pendingSpamSyncLoaded = true;
  }

  Future<void> _ensureSpamSnapshotMetaLoaded() async {
    if (_spamSnapshotMetaLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async {
        final rawTimestamp = ss.read(key: _spamSyncSnapshotAtKey);
        final rawIds =
            (ss.read(key: _spamSyncSnapshotIdsKey) as List?)?.cast<Object?>();
        _spamLastSnapshotAt = _parseSpamSnapshotAt(rawTimestamp);
        _spamLastSnapshotIds
          ..clear()
          ..addAll(_normalizeSpamSyncIds(rawIds));
      },
      awaitDatabase: true,
    );
    _spamSnapshotMetaLoaded = true;
  }

  DateTime? _parseSpamSnapshotAt(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Iterable<String> _normalizeSpamSyncIds(List<Object?>? raw) sync* {
    if (raw == null || raw.isEmpty) {
      return;
    }
    for (final entry in raw) {
      final normalized = entry?.toString().trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) {
        continue;
      }
      yield normalized;
    }
  }

  Future<void> _persistSpamSnapshotMeta({
    required DateTime snapshotAt,
    required Set<String> remoteIds,
  }) async {
    _spamLastSnapshotAt = snapshotAt;
    _spamLastSnapshotIds
      ..clear()
      ..addAll(remoteIds);
    await _dbOp<XmppStateStore>(
      (ss) async => ss.writeAll(
        data: {
          _spamSyncSnapshotAtKey: snapshotAt.toIso8601String(),
          _spamSyncSnapshotIdsKey: remoteIds.toList(growable: false),
        },
      ),
      awaitDatabase: true,
    );
  }

  bool _shouldApplyMissingSpamDeletion({
    required String jid,
    required DateTime localUpdatedAt,
    required String? entrySourceId,
    required String localSourceId,
    required DateTime? lastSnapshotAt,
    required Set<String> previousSnapshotIds,
    required bool isSnapshotComplete,
  }) {
    if (!isSnapshotComplete) {
      return false;
    }
    if (!previousSnapshotIds.contains(jid)) {
      return false;
    }
    if (_pendingSpamPublishes.contains(jid)) {
      return false;
    }
    final normalizedSource = _normalizeSpamSourceId(entrySourceId);
    if (normalizedSource != localSourceId) {
      return true;
    }
    if (lastSnapshotAt == null) {
      return false;
    }
    return !localUpdatedAt.toUtc().isAfter(lastSnapshotAt);
  }

  Future<void> _persistPendingSpamSync() async {
    if (!_pendingSpamSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async => ss.writeAll(
        data: {
          _spamSyncPendingPublishesKey:
              _pendingSpamPublishes.toList(growable: false),
          _spamSyncPendingRetractionsKey:
              _pendingSpamRetractions.toList(growable: false),
        },
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueSpamPublish(String jid) async {
    final normalized = jid.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingSpamSyncLoaded();
    _pendingSpamRetractions.remove(normalized);
    _pendingSpamPublishes.add(normalized);
    await _persistPendingSpamSync();
  }

  Future<void> _queueSpamRetraction(String jid) async {
    final normalized = jid.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingSpamSyncLoaded();
    _pendingSpamPublishes.remove(normalized);
    _pendingSpamRetractions.add(normalized);
    await _persistPendingSpamSync();
  }

  Future<void> _clearPendingSpamPublish(String jid) async {
    final normalized = jid.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingSpamSyncLoaded();
    final removed = _pendingSpamPublishes.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingSpamSync();
  }

  Future<void> _clearPendingSpamRetraction(String jid) async {
    final normalized = jid.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingSpamSyncLoaded();
    final removed = _pendingSpamRetractions.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingSpamSync();
  }

  Future<void> _flushPendingSpamSync() async {
    await _ensurePendingSpamSyncLoaded();
    if (_pendingSpamPublishes.isEmpty && _pendingSpamRetractions.isEmpty) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      return;
    }
    final manager = _spamManager;
    if (manager == null) {
      return;
    }
    await manager.ensureNode();

    final pendingRetractions = _pendingSpamRetractions.toList(growable: false);
    for (final jid in pendingRetractions) {
      final retracted = await manager.retractSpam(jid);
      if (retracted) {
        _pendingSpamRetractions.remove(jid);
      }
    }

    final pendingPublishes = _pendingSpamPublishes.toList(growable: false);
    for (final jid in pendingPublishes) {
      final localEntry = await _dbOpReturning<XmppDatabase, EmailSpamEntry?>(
        (db) => db.getEmailSpamEntry(jid),
      );
      if (localEntry == null) {
        _pendingSpamPublishes.remove(jid);
        continue;
      }
      final published = await manager.publishSpam(
        SpamSyncPayload(
          jid: localEntry.address,
          updatedAt: localEntry.flaggedAt.toUtc(),
          sourceId: _normalizeSpamSourceId(localEntry.sourceId),
        ),
      );
      if (published) {
        _pendingSpamPublishes.remove(jid);
      }
    }

    await _persistPendingSpamSync();
  }
}
