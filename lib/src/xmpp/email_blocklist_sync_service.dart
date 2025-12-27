part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _emailBlocklistSyncSourceKeyName =
    'email_blocklist_sync_source_id';
const String _emailBlocklistPendingPublishesKeyName =
    'email_blocklist_sync_pending_publishes';
const String _emailBlocklistPendingRetractionsKeyName =
    'email_blocklist_sync_pending_retractions';
const String _emailBlocklistSnapshotAtKeyName =
    'email_blocklist_sync_last_snapshot_at';
const String _emailBlocklistSnapshotIdsKeyName =
    'email_blocklist_sync_last_snapshot_ids';

final _emailBlocklistSyncSourceKey = XmppStateStore.registerKey(
  _emailBlocklistSyncSourceKeyName,
);
final _emailBlocklistPendingPublishesKey = XmppStateStore.registerKey(
  _emailBlocklistPendingPublishesKeyName,
);
final _emailBlocklistPendingRetractionsKey = XmppStateStore.registerKey(
  _emailBlocklistPendingRetractionsKeyName,
);
final _emailBlocklistSnapshotAtKey = XmppStateStore.registerKey(
  _emailBlocklistSnapshotAtKeyName,
);
final _emailBlocklistSnapshotIdsKey = XmppStateStore.registerKey(
  _emailBlocklistSnapshotIdsKeyName,
);

enum _EmailBlocklistSyncDecision {
  applyRemote,
  publishLocal,
  skip,
}

mixin EmailBlocklistSyncService on XmppBase, BaseStreamService {
  bool _emailBlocklistSnapshotInFlight = false;
  String? _emailBlocklistSourceId;
  bool _pendingEmailBlocklistSyncLoaded = false;
  final Set<String> _pendingEmailBlocklistPublishes = {};
  final Set<String> _pendingEmailBlocklistRetractions = {};
  bool _emailBlocklistSnapshotMetaLoaded = false;
  DateTime? _emailBlocklistLastSnapshotAt;
  final Set<String> _emailBlocklistLastSnapshotIds = {};

  EmailBlocklistPubSubManager? get _emailBlocklistManager =>
      _connection.getManager<EmailBlocklistPubSubManager>();

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (connectionState != ConnectionState.connected) return;
        if (event.resumed) {
          unawaited(_flushPendingEmailBlocklistSync());
          return;
        }
        unawaited(syncEmailBlocklistSnapshot());
      })
      ..registerHandler<EmailBlocklistSyncUpdatedEvent>((event) async {
        await _applyEmailBlocklistSyncUpdate(event.payload);
      })
      ..registerHandler<EmailBlocklistSyncRetractedEvent>((event) async {
        await _applyEmailBlocklistSyncRetraction(event.address);
      });
  }

  Stream<List<EmailBlocklistEntry>> emailBlocklistStream() =>
      createPaginatedStream<EmailBlocklistEntry, XmppDatabase>(
        watchFunction: (db) async => db.watchEmailBlocklist(),
        getFunction: (db) => db.getEmailBlocklist(),
      );

  Future<void> syncEmailBlocklistSnapshot() async {
    if (_emailBlocklistSnapshotInFlight) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    _emailBlocklistSnapshotInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) {
        return;
      }
      await _ensurePendingEmailBlocklistSyncLoaded();
      final support = await refreshPubSubSupport();
      if (!support.canUsePepNodes) {
        return;
      }
      final manager = _emailBlocklistManager;
      if (manager == null) {
        return;
      }
      await manager.ensureNode();
      await manager.subscribe();
      await _flushPendingEmailBlocklistSync();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return;
      }
      await _ensureEmailBlocklistSnapshotMetaLoaded();
      final snapshotTimestamp = DateTime.timestamp().toUtc();
      final isSnapshotComplete = snapshot.isComplete;

      final remoteItems = snapshot.items;
      final remoteByAddress = <String, EmailBlocklistSyncPayload>{};
      for (final item in remoteItems) {
        final normalized = item.address.trim().toLowerCase();
        if (normalized.isEmpty) {
          continue;
        }
        remoteByAddress[normalized] = item;
      }
      final remoteIds = remoteByAddress.keys.toSet();

      final localItems =
          await _dbOpReturning<XmppDatabase, List<EmailBlocklistEntry>>(
        (db) => db.getEmailBlocklist(),
      );
      final localByAddress = <String, EmailBlocklistEntry>{};
      for (final item in localItems) {
        final normalized = item.address.trim().toLowerCase();
        if (normalized.isEmpty) {
          continue;
        }
        localByAddress[normalized] = item;
      }
      final localSourceId = await _ensureEmailBlocklistSourceId();
      final previousSnapshotAt = _emailBlocklistLastSnapshotAt;
      final previousSnapshotIds =
          Set<String>.of(_emailBlocklistLastSnapshotIds);

      for (final entry in remoteByAddress.entries) {
        final remoteAddress = entry.key;
        final remote = entry.value;
        if (_pendingEmailBlocklistRetractions.contains(remoteAddress)) {
          await retractEmailBlockSync(remoteAddress);
          continue;
        }
        final local = localByAddress[remoteAddress];
        if (local == null) {
          await _applyEmailBlockStatus(
            address: remoteAddress,
            blocked: true,
            updatedAt: remote.updatedAt,
            sourceId: remote.sourceId,
            origin: anti_abuse.SyncOrigin.remote,
          );
          continue;
        }
        final decision = _resolveEmailBlocklistSyncDecision(
          local: local,
          remote: remote,
          localSourceId: localSourceId,
        );
        switch (decision) {
          case _EmailBlocklistSyncDecision.applyRemote:
            await _applyEmailBlockStatus(
              address: remoteAddress,
              blocked: true,
              updatedAt: remote.updatedAt,
              sourceId: remote.sourceId,
              origin: anti_abuse.SyncOrigin.remote,
            );
          case _EmailBlocklistSyncDecision.publishLocal:
            await publishEmailBlockSync(local);
          case _EmailBlocklistSyncDecision.skip:
            continue;
        }
      }

      for (final entry in localByAddress.entries) {
        final address = entry.key;
        final local = entry.value;
        if (remoteByAddress.containsKey(address)) {
          continue;
        }
        if (_shouldApplyMissingEmailBlocklistDeletion(
          address: address,
          localUpdatedAt: local.blockedAt,
          entrySourceId: local.sourceId,
          localSourceId: localSourceId,
          lastSnapshotAt: previousSnapshotAt,
          previousSnapshotIds: previousSnapshotIds,
          isSnapshotComplete: isSnapshotComplete,
        )) {
          await _applyEmailBlockStatus(
            address: address,
            blocked: false,
            updatedAt: snapshotTimestamp,
            sourceId: await _ensureEmailBlocklistSourceId(),
            origin: anti_abuse.SyncOrigin.remote,
          );
          continue;
        }
        await publishEmailBlockSync(local);
      }
      if (isSnapshotComplete) {
        await _persistEmailBlocklistSnapshotMeta(
          snapshotAt: snapshotTimestamp,
          remoteIds: remoteIds,
        );
      }
    } on XmppAbortedException {
      return;
    } finally {
      _emailBlocklistSnapshotInFlight = false;
    }
  }

  Future<void> setEmailBlockStatus({
    required String address,
    required bool blocked,
  }) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final updatedAt = DateTime.timestamp().toUtc();
    final sourceId = await _ensureEmailBlocklistSourceId();
    await _applyEmailBlockStatus(
      address: normalized,
      blocked: blocked,
      updatedAt: updatedAt,
      sourceId: sourceId,
      origin: anti_abuse.SyncOrigin.local,
    );
    if (blocked) {
      await publishEmailBlockSync(
        EmailBlocklistEntry(
          address: normalized,
          blockedAt: updatedAt,
          sourceId: sourceId,
        ),
      );
      return;
    }
    await retractEmailBlockSync(normalized);
  }

  Future<void> clearEmailBlocklist() async {
    final items = await _dbOpReturning<XmppDatabase, List<EmailBlocklistEntry>>(
      (db) => db.getEmailBlocklist(),
    );
    for (final entry in items) {
      await setEmailBlockStatus(address: entry.address, blocked: false);
    }
  }

  Future<void> publishEmailBlockSync(EmailBlocklistEntry entry) async {
    final normalized = entry.address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      await _queueEmailBlocklistPublish(normalized);
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      await _queueEmailBlocklistPublish(normalized);
      return;
    }
    final manager = _emailBlocklistManager;
    if (manager == null) {
      await _queueEmailBlocklistPublish(normalized);
      return;
    }
    await manager.ensureNode();
    final payload = EmailBlocklistSyncPayload(
      address: normalized,
      updatedAt: entry.blockedAt.toUtc(),
      sourceId: _normalizeEmailBlocklistSourceId(entry.sourceId),
    );
    final published = await manager.publishBlock(payload);
    if (published) {
      await _clearPendingEmailBlocklistPublish(normalized);
    } else {
      await _queueEmailBlocklistPublish(normalized);
    }
  }

  Future<void> retractEmailBlockSync(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      await _queueEmailBlocklistRetraction(normalized);
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      await _queueEmailBlocklistRetraction(normalized);
      return;
    }
    final manager = _emailBlocklistManager;
    if (manager == null) {
      await _queueEmailBlocklistRetraction(normalized);
      return;
    }
    final retracted = await manager.retractBlock(normalized);
    if (retracted) {
      await _clearPendingEmailBlocklistRetraction(normalized);
    } else {
      await _queueEmailBlocklistRetraction(normalized);
    }
  }

  Future<void> _applyEmailBlocklistSyncUpdate(
    EmailBlocklistSyncPayload payload,
  ) async {
    await _ensurePendingEmailBlocklistSyncLoaded();
    if (_pendingEmailBlocklistRetractions.contains(payload.address)) {
      await retractEmailBlockSync(payload.address);
      return;
    }

    final localEntry = await _dbOpReturning<XmppDatabase, EmailBlocklistEntry?>(
      (db) => db.getEmailBlocklistEntry(payload.address),
    );
    if (localEntry != null) {
      final decision = _resolveEmailBlocklistSyncDecision(
        local: localEntry,
        remote: payload,
        localSourceId: await _ensureEmailBlocklistSourceId(),
      );
      switch (decision) {
        case _EmailBlocklistSyncDecision.applyRemote:
          await _applyEmailBlockStatus(
            address: payload.address,
            blocked: true,
            updatedAt: payload.updatedAt,
            sourceId: payload.sourceId,
            origin: anti_abuse.SyncOrigin.remote,
          );
        case _EmailBlocklistSyncDecision.publishLocal:
          await publishEmailBlockSync(localEntry);
        case _EmailBlocklistSyncDecision.skip:
          return;
      }
      return;
    }

    await _applyEmailBlockStatus(
      address: payload.address,
      blocked: true,
      updatedAt: payload.updatedAt,
      sourceId: payload.sourceId,
      origin: anti_abuse.SyncOrigin.remote,
    );
    await _clearPendingEmailBlocklistPublish(payload.address);
  }

  Future<void> _applyEmailBlocklistSyncRetraction(String address) async {
    await _ensurePendingEmailBlocklistSyncLoaded();
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (_pendingEmailBlocklistPublishes.contains(normalized)) {
      return;
    }
    await _applyEmailBlockStatus(
      address: normalized,
      blocked: false,
      updatedAt: DateTime.timestamp().toUtc(),
      sourceId: await _ensureEmailBlocklistSourceId(),
      origin: anti_abuse.SyncOrigin.remote,
    );
    await _clearPendingEmailBlocklistRetraction(normalized);
  }

  _EmailBlocklistSyncDecision _resolveEmailBlocklistSyncDecision({
    required EmailBlocklistEntry local,
    required EmailBlocklistSyncPayload remote,
    required String localSourceId,
  }) {
    final localUpdatedAt = local.blockedAt.toUtc();
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    if (localUpdatedAt.isBefore(remoteUpdatedAt)) {
      return _EmailBlocklistSyncDecision.applyRemote;
    }
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return _EmailBlocklistSyncDecision.publishLocal;
    }
    final localSource = _normalizeEmailBlocklistSourceId(local.sourceId);
    if (localSource == remote.sourceId) {
      return _EmailBlocklistSyncDecision.skip;
    }
    if (localSourceId == localSource) {
      return _EmailBlocklistSyncDecision.publishLocal;
    }
    return _EmailBlocklistSyncDecision.applyRemote;
  }

  Future<void> _applyEmailBlockStatus({
    required String address,
    required bool blocked,
    required DateTime updatedAt,
    required String sourceId,
    required anti_abuse.SyncOrigin origin,
  }) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _dbOp<XmppDatabase>(
      (db) async {
        if (blocked) {
          await db.addEmailBlock(
            normalized,
            blockedAt: updatedAt,
            sourceId: sourceId,
          );
        } else {
          await db.removeEmailBlock(normalized);
        }
      },
    );
    final callback = emailBlocklistSyncCallback;
    if (callback != null) {
      await callback(
        anti_abuse.EmailBlocklistSyncUpdate(
          address: normalized,
          blocked: blocked,
          updatedAt: updatedAt,
          sourceId: sourceId,
          origin: origin,
        ),
      );
    }
  }

  String _normalizeEmailBlocklistSourceId(String? sourceId) {
    final normalized = sourceId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return anti_abuse.syncLegacySourceId;
    }
    return normalized;
  }

  Future<String> _ensureEmailBlocklistSourceId() async {
    final cached = _emailBlocklistSourceId;
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }
    final stored = await _dbOpReturning<XmppStateStore, String?>(
      (ss) async => ss.read(key: _emailBlocklistSyncSourceKey) as String?,
    );
    final trimmed = stored?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      _emailBlocklistSourceId = trimmed;
      return trimmed;
    }
    final generated = uuid.v4();
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(
        key: _emailBlocklistSyncSourceKey,
        value: generated,
      ),
    );
    _emailBlocklistSourceId = generated;
    return generated;
  }

  Future<void> _ensurePendingEmailBlocklistSyncLoaded() async {
    if (_pendingEmailBlocklistSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async {
        final rawPublishes =
            (ss.read(key: _emailBlocklistPendingPublishesKey) as List?)
                ?.cast<Object?>();
        final rawRetractions =
            (ss.read(key: _emailBlocklistPendingRetractionsKey) as List?)
                ?.cast<Object?>();
        _pendingEmailBlocklistPublishes
          ..clear()
          ..addAll(_normalizeEmailBlocklistSyncIds(rawPublishes));
        _pendingEmailBlocklistRetractions
          ..clear()
          ..addAll(_normalizeEmailBlocklistSyncIds(rawRetractions));
      },
      awaitDatabase: true,
    );
    _pendingEmailBlocklistSyncLoaded = true;
  }

  Future<void> _ensureEmailBlocklistSnapshotMetaLoaded() async {
    if (_emailBlocklistSnapshotMetaLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async {
        final rawTimestamp = ss.read(key: _emailBlocklistSnapshotAtKey);
        final rawIds = (ss.read(key: _emailBlocklistSnapshotIdsKey) as List?)
            ?.cast<Object?>();
        _emailBlocklistLastSnapshotAt =
            _parseEmailBlocklistSnapshotAt(rawTimestamp);
        _emailBlocklistLastSnapshotIds
          ..clear()
          ..addAll(_normalizeEmailBlocklistSyncIds(rawIds));
      },
      awaitDatabase: true,
    );
    _emailBlocklistSnapshotMetaLoaded = true;
  }

  DateTime? _parseEmailBlocklistSnapshotAt(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Iterable<String> _normalizeEmailBlocklistSyncIds(List<Object?>? raw) sync* {
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

  Future<void> _persistEmailBlocklistSnapshotMeta({
    required DateTime snapshotAt,
    required Set<String> remoteIds,
  }) async {
    _emailBlocklistLastSnapshotAt = snapshotAt;
    _emailBlocklistLastSnapshotIds
      ..clear()
      ..addAll(remoteIds);
    await _dbOp<XmppStateStore>(
      (ss) async => ss.writeAll(
        data: {
          _emailBlocklistSnapshotAtKey: snapshotAt.toIso8601String(),
          _emailBlocklistSnapshotIdsKey: remoteIds.toList(growable: false),
        },
      ),
      awaitDatabase: true,
    );
  }

  bool _shouldApplyMissingEmailBlocklistDeletion({
    required String address,
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
    if (!previousSnapshotIds.contains(address)) {
      return false;
    }
    if (_pendingEmailBlocklistPublishes.contains(address)) {
      return false;
    }
    final normalizedSource = _normalizeEmailBlocklistSourceId(entrySourceId);
    if (normalizedSource != localSourceId) {
      return true;
    }
    if (lastSnapshotAt == null) {
      return false;
    }
    return !localUpdatedAt.toUtc().isAfter(lastSnapshotAt);
  }

  Future<void> _persistPendingEmailBlocklistSync() async {
    if (!_pendingEmailBlocklistSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async => ss.writeAll(
        data: {
          _emailBlocklistPendingPublishesKey:
              _pendingEmailBlocklistPublishes.toList(growable: false),
          _emailBlocklistPendingRetractionsKey:
              _pendingEmailBlocklistRetractions.toList(growable: false),
        },
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueEmailBlocklistPublish(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingEmailBlocklistSyncLoaded();
    _pendingEmailBlocklistRetractions.remove(normalized);
    _pendingEmailBlocklistPublishes.add(normalized);
    await _persistPendingEmailBlocklistSync();
  }

  Future<void> _queueEmailBlocklistRetraction(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingEmailBlocklistSyncLoaded();
    _pendingEmailBlocklistPublishes.remove(normalized);
    _pendingEmailBlocklistRetractions.add(normalized);
    await _persistPendingEmailBlocklistSync();
  }

  Future<void> _clearPendingEmailBlocklistPublish(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingEmailBlocklistSyncLoaded();
    final removed = _pendingEmailBlocklistPublishes.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingEmailBlocklistSync();
  }

  Future<void> _clearPendingEmailBlocklistRetraction(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingEmailBlocklistSyncLoaded();
    final removed = _pendingEmailBlocklistRetractions.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingEmailBlocklistSync();
  }

  Future<void> _flushPendingEmailBlocklistSync() async {
    await _ensurePendingEmailBlocklistSyncLoaded();
    if (_pendingEmailBlocklistPublishes.isEmpty &&
        _pendingEmailBlocklistRetractions.isEmpty) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      return;
    }
    final manager = _emailBlocklistManager;
    if (manager == null) {
      return;
    }
    await manager.ensureNode();

    final pendingRetractions =
        _pendingEmailBlocklistRetractions.toList(growable: false);
    for (final address in pendingRetractions) {
      final retracted = await manager.retractBlock(address);
      if (retracted) {
        _pendingEmailBlocklistRetractions.remove(address);
      }
    }

    final pendingPublishes =
        _pendingEmailBlocklistPublishes.toList(growable: false);
    for (final address in pendingPublishes) {
      final localEntry =
          await _dbOpReturning<XmppDatabase, EmailBlocklistEntry?>(
        (db) => db.getEmailBlocklistEntry(address),
      );
      if (localEntry == null) {
        _pendingEmailBlocklistPublishes.remove(address);
        continue;
      }
      final published = await manager.publishBlock(
        EmailBlocklistSyncPayload(
          address: localEntry.address,
          updatedAt: localEntry.blockedAt.toUtc(),
          sourceId: _normalizeEmailBlocklistSourceId(localEntry.sourceId),
        ),
      );
      if (published) {
        _pendingEmailBlocklistPublishes.remove(address);
      }
    }

    await _persistPendingEmailBlocklistSync();
  }
}
