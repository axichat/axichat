// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _blockingXmlns = 'urn:xmpp:blocking';
const String _reportingXmlns = 'urn:xmpp:reporting:1';
const String _reportingFeature = _reportingXmlns;
const String _reportingSpamReason = 'urn:xmpp:reporting:spam';
const String _reportingAbuseReason = 'urn:xmpp:reporting:abuse';
const String _stanzaIdXmlns = 'urn:xmpp:sid:0';
const String _blockTag = 'block';
const String _blockItemTag = 'item';
const String _blockingJidAttr = 'jid';
const String _reportTag = 'report';
const String _reportReasonAttr = 'reason';
const String _reportTextTag = 'text';
const String _stanzaIdTag = 'stanza-id';
const String _stanzaIdByAttr = 'by';
const String _stanzaIdIdAttr = 'id';
const String _blockingIqTypeSet = 'set';
const String _blockingIqTypeResult = 'result';
const String _blockingPresenceUpdateFailureLog =
    'Failed to update presence for newly blocked contacts.';
const String _spamSyncSourceKeyName = 'spam_sync_source_id';
const String _spamSyncPendingPublishesKeyName = 'spam_sync_pending_publishes';
const String _spamSyncPendingRetractionsKeyName =
    'spam_sync_pending_retractions';
const String _spamSyncSnapshotAtKeyName = 'spam_sync_last_snapshot_at';
const String _spamSyncSnapshotIdsKeyName = 'spam_sync_last_snapshot_ids';
const String _blocklistFetchOnLoginOperationName =
    'BlockingService.requestBlocklistOnLogin';
const String _spamSyncFlushPendingOperationName =
    'BlockingService.flushPendingSpamSyncOnResume';
const String _spamSyncSnapshotBootstrapOperationName =
    'BlockingService.bootstrapSpamSnapshotOnNegotiations';
const String _addressBlockSyncSourceKeyName = 'address_block_sync_source_id';
const String _addressBlockPendingPublishesKeyName =
    'address_block_sync_pending_publishes';
const String _addressBlockPendingRetractionsKeyName =
    'address_block_sync_pending_retractions';
const String _addressBlockSnapshotAtKeyName =
    'address_block_sync_last_snapshot_at';
const String _addressBlockSnapshotIdsKeyName =
    'address_block_sync_last_snapshot_ids';
const String _addressBlockFlushPendingOperationName =
    'BlockingService.flushPendingAddressBlockSyncOnResume';
const String _addressBlockSnapshotBootstrapOperationName =
    'BlockingService.bootstrapAddressBlockSnapshotOnNegotiations';

final _spamSyncSourceKey = XmppStateStore.registerKey(_spamSyncSourceKeyName);
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
final _addressBlockSyncSourceKey = XmppStateStore.registerKey(
  _addressBlockSyncSourceKeyName,
);
final _addressBlockPendingPublishesKey = XmppStateStore.registerKey(
  _addressBlockPendingPublishesKeyName,
);
final _addressBlockPendingRetractionsKey = XmppStateStore.registerKey(
  _addressBlockPendingRetractionsKeyName,
);
final _addressBlockSnapshotAtKey = XmppStateStore.registerKey(
  _addressBlockSnapshotAtKeyName,
);
final _addressBlockSnapshotIdsKey = XmppStateStore.registerKey(
  _addressBlockSnapshotIdsKeyName,
);

enum SpamReportReason { spam, abuse }

enum _SpamSyncDecision { applyRemote, publishLocal, skip }

enum _AddressBlockSyncDecision { applyRemote, publishLocal, skip }

extension SpamReportReasonExtension on SpamReportReason {
  String get urn => switch (this) {
    SpamReportReason.spam => _reportingSpamReason,
    SpamReportReason.abuse => _reportingAbuseReason,
  };
}

final class SpamReportStanzaId {
  const SpamReportStanzaId({required this.by, required this.id});

  final String by;
  final String id;

  mox.XMLNode toXml() => mox.XMLNode.xmlns(
    tag: _stanzaIdTag,
    xmlns: _stanzaIdXmlns,
    attributes: {_stanzaIdByAttr: by, _stanzaIdIdAttr: id},
  );
}

mixin BlockingService on XmppBase, BaseStreamService {
  StreamController<anti_abuse.SpamSyncUpdate> _spamSyncUpdateController =
      StreamController<anti_abuse.SpamSyncUpdate>.broadcast();
  bool _spamSnapshotInFlight = false;
  String? _spamSourceId;
  bool _pendingSpamSyncLoaded = false;
  final Set<String> _pendingSpamPublishes = <String>{};
  final Set<String> _pendingSpamRetractions = <String>{};
  bool _spamSnapshotMetaLoaded = false;
  DateTime? _spamLastSnapshotAt;
  final Set<String> _spamLastSnapshotIds = <String>{};
  StreamController<anti_abuse.AddressBlockSyncUpdate>
  _addressBlockSyncUpdateController =
      StreamController<anti_abuse.AddressBlockSyncUpdate>.broadcast();
  bool _addressBlockSnapshotInFlight = false;
  String? _addressBlockSourceId;
  bool _pendingAddressBlockSyncLoaded = false;
  final Set<String> _pendingAddressBlockPublishes = <String>{};
  final Set<String> _pendingAddressBlockRetractions = <String>{};
  bool _addressBlockSnapshotMetaLoaded = false;
  DateTime? _addressBlockLastSnapshotAt;
  final Set<String> _addressBlockLastSnapshotIds = <String>{};

  Stream<anti_abuse.SpamSyncUpdate> get spamSyncUpdateStream =>
      _spamSyncUpdateController.stream;

  Stream<anti_abuse.AddressBlockSyncUpdate> get addressBlockSyncUpdateStream =>
      _addressBlockSyncUpdateController.stream;

  void emitSpamSyncUpdate(anti_abuse.SpamSyncUpdate update) {
    if (_spamSyncUpdateController.isClosed) return;
    _spamSyncUpdateController.add(update);
  }

  void emitAddressBlockSyncUpdate(anti_abuse.AddressBlockSyncUpdate update) {
    if (_addressBlockSyncUpdateController.isClosed) return;
    _addressBlockSyncUpdateController.add(update);
  }

  Stream<List<SpamEntry>> spamlistStream() =>
      createPaginatedStream<SpamEntry, XmppDatabase>(
        watchFunction: (db) async => db.watchSpamlist(),
        getFunction: (db) => db.getSpamlist(),
      );

  Stream<List<AddressBlockEntry>> addressBlocklistStream() =>
      createPaginatedStream<AddressBlockEntry, XmppDatabase>(
        watchFunction: (db) async => db.watchAddressBlocks(),
        getFunction: (db) => db.getAddressBlocks(),
      );

  Future<bool> syncSpamSnapshot() async {
    if (_spamSnapshotInFlight) {
      return true;
    }
    _spamSnapshotInFlight = true;
    try {
      await database;
      await _ensurePendingSpamSyncLoaded();
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'spam sync',
      );
      if (!decision.isAllowed) {
        return true;
      }
      final manager = _spamManager;
      if (manager == null) {
        return true;
      }
      await manager.ensureNode();
      await manager.subscribe();
      await _flushPendingSpamSync();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return false;
      }
      await _ensureSpamSnapshotMetaLoaded();
      final snapshotTimestamp = DateTime.timestamp().toUtc();
      final isSnapshotComplete = snapshot.isComplete;

      final remoteItems = snapshot.items;
      final remoteByJid = <String, SpamSyncPayload>{};
      for (final item in remoteItems) {
        final normalized = _normalizeSpamJid(item.jid);
        if (normalized == null || normalized.isEmpty) {
          continue;
        }
        remoteByJid[normalized] = item;
      }
      final remoteIds = remoteByJid.keys.toSet();

      final localItems = await _dbOpReturning<XmppDatabase, List<SpamEntry>>(
        (db) => db.getSpamlist(),
      );
      final localByJid = <String, SpamEntry>{};
      for (final item in localItems) {
        final normalized = _normalizeSpamJid(item.address);
        if (normalized == null || normalized.isEmpty) {
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
      return true;
    } on XmppAbortedException {
      return false;
    } finally {
      _spamSnapshotInFlight = false;
    }
  }

  Future<bool> syncAddressBlockSnapshot() async {
    if (_addressBlockSnapshotInFlight) {
      return true;
    }
    _addressBlockSnapshotInFlight = true;
    try {
      await database;
      await _ensurePendingAddressBlockSyncLoaded();
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'address block sync',
      );
      if (!decision.isAllowed) {
        return true;
      }
      final manager = _addressBlockManager;
      if (manager == null) {
        return true;
      }
      await manager.ensureNode();
      await manager.subscribe();
      await _flushPendingAddressBlockSync();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return false;
      }
      await _ensureAddressBlockSnapshotMetaLoaded();
      final snapshotTimestamp = DateTime.timestamp().toUtc();
      final isSnapshotComplete = snapshot.isComplete;

      final remoteItems = snapshot.items;
      final remoteByAddress = <String, AddressBlockSyncPayload>{};
      for (final item in remoteItems) {
        final normalized = _normalizeAddressBlockAddress(item.address);
        if (normalized == null || normalized.isEmpty) {
          continue;
        }
        remoteByAddress[normalized] = item;
      }
      final remoteIds = remoteByAddress.keys.toSet();

      final localItems =
          await _dbOpReturning<XmppDatabase, List<AddressBlockEntry>>(
            (db) => db.getAddressBlocks(),
          );
      final localByAddress = <String, AddressBlockEntry>{};
      for (final item in localItems) {
        final normalized = _normalizeAddressBlockAddress(item.address);
        if (normalized == null || normalized.isEmpty) {
          continue;
        }
        localByAddress[normalized] = item;
      }
      final localSourceId = await _ensureAddressBlockSourceId();
      final previousSnapshotAt = _addressBlockLastSnapshotAt;
      final previousSnapshotIds = Set<String>.of(_addressBlockLastSnapshotIds);

      for (final entry in remoteByAddress.entries) {
        final remoteAddress = entry.key;
        final remote = entry.value;
        if (_pendingAddressBlockRetractions.contains(remoteAddress)) {
          await retractAddressBlockSync(remoteAddress);
          continue;
        }
        final local = localByAddress[remoteAddress];
        if (local == null) {
          await _applyAddressBlockStatus(
            address: remoteAddress,
            blocked: true,
            updatedAt: remote.updatedAt,
            sourceId: remote.sourceId,
            origin: anti_abuse.SyncOrigin.remote,
          );
          continue;
        }
        final decision = _resolveAddressBlockSyncDecision(
          local: local,
          remote: remote,
          localSourceId: localSourceId,
        );
        switch (decision) {
          case _AddressBlockSyncDecision.applyRemote:
            await _applyAddressBlockStatus(
              address: remoteAddress,
              blocked: true,
              updatedAt: remote.updatedAt,
              sourceId: remote.sourceId,
              origin: anti_abuse.SyncOrigin.remote,
            );
          case _AddressBlockSyncDecision.publishLocal:
            await publishAddressBlockSync(local);
          case _AddressBlockSyncDecision.skip:
            continue;
        }
      }

      for (final entry in localByAddress.entries) {
        final address = entry.key;
        final local = entry.value;
        if (remoteByAddress.containsKey(address)) {
          continue;
        }
        if (_shouldApplyMissingAddressBlockDeletion(
          address: address,
          localUpdatedAt: local.blockedAt,
          entrySourceId: local.sourceId,
          localSourceId: localSourceId,
          lastSnapshotAt: previousSnapshotAt,
          previousSnapshotIds: previousSnapshotIds,
          isSnapshotComplete: isSnapshotComplete,
        )) {
          await _applyAddressBlockStatus(
            address: address,
            blocked: false,
            updatedAt: snapshotTimestamp,
            sourceId: await _ensureAddressBlockSourceId(),
            origin: anti_abuse.SyncOrigin.remote,
          );
          continue;
        }
        await publishAddressBlockSync(local);
      }
      if (isSnapshotComplete) {
        await _persistAddressBlockSnapshotMeta(
          snapshotAt: snapshotTimestamp,
          remoteIds: remoteIds,
        );
      }
      return true;
    } on XmppAbortedException {
      return false;
    } finally {
      _addressBlockSnapshotInFlight = false;
    }
  }

  Future<void> setSpamStatus({required String jid, required bool spam}) async {
    final normalized = _normalizeSpamJid(jid);
    if (normalized == null || normalized.isEmpty) {
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
        SpamEntry(
          address: normalized,
          flaggedAt: updatedAt,
          sourceId: sourceId,
        ),
      );
      return;
    }
    await retractSpamSync(normalized);
  }

  Future<void> setAddressBlockStatus({
    required String address,
    required bool blocked,
  }) async {
    final normalized = _normalizeAddressBlockAddress(address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    final updatedAt = DateTime.timestamp().toUtc();
    final sourceId = await _ensureAddressBlockSourceId();
    await _applyAddressBlockStatus(
      address: normalized,
      blocked: blocked,
      updatedAt: updatedAt,
      sourceId: sourceId,
      origin: anti_abuse.SyncOrigin.local,
    );
    if (blocked) {
      await publishAddressBlockSync(
        AddressBlockEntry(
          address: normalized,
          blockedAt: updatedAt,
          sourceId: sourceId,
        ),
      );
      return;
    }
    await retractAddressBlockSync(normalized);
  }

  Future<void> clearAddressBlocks() async {
    final items = await _dbOpReturning<XmppDatabase, List<AddressBlockEntry>>(
      (db) => db.getAddressBlocks(),
    );
    for (final entry in items) {
      await setAddressBlockStatus(address: entry.address, blocked: false);
    }
  }

  Stream<List<BlocklistData>> blocklistStream({
    int start = 0,
    int end = basePageItemLimit,
  }) => createPaginatedStream<BlocklistData, XmppDatabase>(
    watchFunction: (db) async => db.watchBlocklist(start: start, end: end),
    getFunction: (db) => db.getBlocklist(start: start, end: end),
  );

  final Logger _blockingLogger = Logger('BlockingService');
  final Set<String> _blockedJids = <String>{};
  StreamSubscription<List<BlocklistData>>? _blocklistSubscription;
  bool _blocklistCacheReady = false;
  bool _spamReportingSupportResolved = false;
  bool _spamReportingSupported = false;

  SpamPubSubManager? get _spamManager =>
      _connection.getManager<SpamPubSubManager>();
  AddressBlockPubSubManager? get _addressBlockManager =>
      _connection.getManager<AddressBlockPubSubManager>();

  String? _normalizeSpamJid(String? jid) => normalizedAddressValue(jid);
  String? _normalizeAddressBlockAddress(String? address) =>
      normalizedAddressValue(address);

  void _startBlocklistCache() {
    if (_blocklistSubscription != null) {
      return;
    }
    _blocklistSubscription = blocklistStream().listen(_updateBlocklistCache);
  }

  Future<void> _updateBlocklistCache(List<BlocklistData> items) async {
    final previous = Set<String>.from(_blockedJids);
    final next = <String>{
      for (final entry in items) ?normalizedBareAddressValue(entry.jid),
    };
    _blockedJids
      ..clear()
      ..addAll(next);
    _blocklistCacheReady = true;
    final newlyBlocked = next.difference(previous);
    if (newlyBlocked.isEmpty) {
      return;
    }
    try {
      await _dbOp<XmppDatabase>((db) async {
        for (final jid in newlyBlocked) {
          await db.updatePresence(
            jid: jid,
            presence: Presence.unavailable,
            status: null,
          );
        }
      });
    } catch (error, stackTrace) {
      _blockingLogger.warning(
        _blockingPresenceUpdateFailureLog,
        error,
        stackTrace,
      );
    }
  }

  Future<bool> isJidBlocked(String jid) async {
    final normalized = normalizedBareAddressValue(jid);
    if (normalized == null) {
      return false;
    }
    if (_blockedJids.contains(normalized)) {
      return true;
    }
    if (_blocklistCacheReady) {
      return false;
    }
    final db = await database;
    final blocked = await db.isJidBlocked(normalized);
    if (blocked) {
      _blockedJids.add(normalized);
    }
    return blocked;
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    _startBlocklistCache();
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _blocklistFetchOnLoginOperationName,
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.resumedNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _blocklistFetchOnLoginOperationName,
        run: () async {
          _blockingLogger.info('Fetching blocklist...');
          await requestBlocklist();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _spamSyncSnapshotBootstrapOperationName,
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _spamSyncSnapshotBootstrapOperationName,
        run: () async {
          await syncSpamSnapshot();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _spamSyncFlushPendingOperationName,
        priority: 2,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.resumedNegotiation,
        },
        operationName: _spamSyncFlushPendingOperationName,
        run: () async {
          await _flushPendingSpamSync();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _addressBlockSnapshotBootstrapOperationName,
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _addressBlockSnapshotBootstrapOperationName,
        run: () async {
          await syncAddressBlockSnapshot();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _addressBlockFlushPendingOperationName,
        priority: 2,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.resumedNegotiation,
        },
        operationName: _addressBlockFlushPendingOperationName,
        run: () async {
          await _flushPendingAddressBlockSync();
        },
      ),
    );
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((_) async {
        _spamReportingSupportResolved = false;
      })
      ..registerHandler<SpamSyncUpdatedEvent>((event) async {
        await _applySpamSyncUpdate(event.payload);
      })
      ..registerHandler<SpamSyncRetractedEvent>((event) async {
        await _applySpamSyncRetraction(event.jid);
      })
      ..registerHandler<AddressBlockSyncUpdatedEvent>((event) async {
        await _applyAddressBlockSyncUpdate(event.payload);
      })
      ..registerHandler<AddressBlockSyncRetractedEvent>((event) async {
        await _applyAddressBlockSyncRetraction(event.address);
      })
      ..registerHandler<mox.BlocklistBlockPushEvent>((event) async {
        await _dbOp<XmppDatabase>((db) => db.blockJids(event.items));
      })
      ..registerHandler<mox.BlocklistUnblockPushEvent>((event) async {
        await _dbOp<XmppDatabase>((db) => db.unblockJids(event.items));
      })
      ..registerHandler<mox.BlocklistUnblockAllPushEvent>((_) async {
        await _dbOp<XmppDatabase>((db) => db.deleteBlocklist());
      });
  }

  @override
  Future<void> _reset() async {
    await _blocklistSubscription?.cancel();
    _blocklistSubscription = null;
    _blockedJids.clear();
    _blocklistCacheReady = false;
    await super._reset();
  }

  @override
  List<mox.XmppManagerBase> get featureManagers => <mox.XmppManagerBase>[
    ...super.featureManagers,
    mox.BlockingManager(),
  ];

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    SpamPubSubManager(),
    AddressBlockPubSubManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    spamNotifyFeature,
    addressBlockNotifyFeature,
  ];

  Future<void> publishSpamSync(SpamEntry entry) async {
    final normalized = _normalizeSpamJid(entry.address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    try {
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'spam sync',
      );
      if (!decision.isAllowed) {
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
    } on Exception {
      await _queueSpamPublish(normalized);
    }
  }

  Future<void> retractSpamSync(String jid) async {
    final normalized = _normalizeSpamJid(jid);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    try {
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'spam sync',
      );
      if (!decision.isAllowed) {
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
    } on Exception {
      await _queueSpamRetraction(normalized);
    }
  }

  Future<void> _applySpamSyncUpdate(SpamSyncPayload payload) async {
    await _ensurePendingSpamSyncLoaded();
    if (_pendingSpamRetractions.contains(payload.jid)) {
      await retractSpamSync(payload.jid);
      return;
    }

    final localEntry = await _dbOpReturning<XmppDatabase, SpamEntry?>(
      (db) => db.getSpamEntry(payload.jid),
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
    final normalized = _normalizeSpamJid(jid);
    if (normalized == null || normalized.isEmpty) {
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
    required SpamEntry local,
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
    final normalized = _normalizeSpamJid(jid);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    await _dbOp<XmppDatabase>((db) async {
      if (spam) {
        await db.addSpam(normalized, flaggedAt: updatedAt, sourceId: sourceId);
      } else {
        await db.removeSpam(normalized);
      }
      await db.markChatSpam(
        jid: normalized,
        spam: spam,
        spamUpdatedAt: spam ? updatedAt : null,
      );
      await db.markEmailChatsSpam(
        address: normalized,
        spam: spam,
        spamUpdatedAt: spam ? updatedAt : null,
      );
    });
    emitSpamSyncUpdate(
      anti_abuse.SpamSyncUpdate(
        address: normalized,
        isSpam: spam,
        updatedAt: updatedAt,
        sourceId: sourceId,
        origin: origin,
      ),
    );
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
      (ss) async => ss.write(key: _spamSyncSourceKey, value: generated),
    );
    _spamSourceId = generated;
    return generated;
  }

  Future<void> _ensurePendingSpamSyncLoaded() async {
    if (_pendingSpamSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>((ss) async {
      final rawPublishes = (ss.read(key: _spamSyncPendingPublishesKey) as List?)
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
    }, awaitDatabase: true);
    _pendingSpamSyncLoaded = true;
  }

  Future<void> _ensureSpamSnapshotMetaLoaded() async {
    if (_spamSnapshotMetaLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>((ss) async {
      final rawTimestamp = ss.read(key: _spamSyncSnapshotAtKey);
      final rawIds = (ss.read(key: _spamSyncSnapshotIdsKey) as List?)
          ?.cast<Object?>();
      _spamLastSnapshotAt = _parseSpamSnapshotAt(rawTimestamp);
      _spamLastSnapshotIds
        ..clear()
        ..addAll(_normalizeSpamSyncIds(rawIds));
    }, awaitDatabase: true);
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
      final normalized = _normalizeSpamJid(entry?.toString());
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
          _spamSyncPendingPublishesKey: _pendingSpamPublishes.toList(
            growable: false,
          ),
          _spamSyncPendingRetractionsKey: _pendingSpamRetractions.toList(
            growable: false,
          ),
        },
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueSpamPublish(String jid) async {
    final normalized = _normalizeSpamJid(jid);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    await _ensurePendingSpamSyncLoaded();
    _pendingSpamRetractions.remove(normalized);
    _pendingSpamPublishes.add(normalized);
    await _persistPendingSpamSync();
  }

  Future<void> _queueSpamRetraction(String jid) async {
    final normalized = _normalizeSpamJid(jid);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    await _ensurePendingSpamSyncLoaded();
    _pendingSpamPublishes.remove(normalized);
    _pendingSpamRetractions.add(normalized);
    await _persistPendingSpamSync();
  }

  Future<void> _clearPendingSpamPublish(String jid) async {
    final normalized = _normalizeSpamJid(jid);
    if (normalized == null || normalized.isEmpty) {
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
    final normalized = _normalizeSpamJid(jid);
    if (normalized == null || normalized.isEmpty) {
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
    final support = await refreshPubSubSupport();
    final decision = decidePubSubSupport(
      supported: support.canUsePepNodes,
      featureLabel: 'spam sync',
    );
    if (!decision.isAllowed) {
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
      final localEntry = await _dbOpReturning<XmppDatabase, SpamEntry?>(
        (db) => db.getSpamEntry(jid),
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

  Future<void> publishAddressBlockSync(AddressBlockEntry entry) async {
    final normalized = _normalizeAddressBlockAddress(entry.address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    try {
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'address block sync',
      );
      if (!decision.isAllowed) {
        return;
      }
      final manager = _addressBlockManager;
      if (manager == null) {
        await _queueAddressBlockPublish(normalized);
        return;
      }
      await manager.ensureNode();
      final payload = AddressBlockSyncPayload(
        address: normalized,
        updatedAt: entry.blockedAt.toUtc(),
        sourceId: _normalizeAddressBlockSourceId(entry.sourceId),
      );
      final published = await manager.publishBlock(payload);
      if (published) {
        await _clearPendingAddressBlockPublish(normalized);
      } else {
        await _queueAddressBlockPublish(normalized);
      }
    } on Exception {
      await _queueAddressBlockPublish(normalized);
    }
  }

  Future<void> retractAddressBlockSync(String address) async {
    final normalized = _normalizeAddressBlockAddress(address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    try {
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'address block sync',
      );
      if (!decision.isAllowed) {
        return;
      }
      final manager = _addressBlockManager;
      if (manager == null) {
        await _queueAddressBlockRetraction(normalized);
        return;
      }
      final retracted = await manager.retractBlock(normalized);
      if (retracted) {
        await _clearPendingAddressBlockRetraction(normalized);
      } else {
        await _queueAddressBlockRetraction(normalized);
      }
    } on Exception {
      await _queueAddressBlockRetraction(normalized);
    }
  }

  Future<void> _applyAddressBlockSyncUpdate(
    AddressBlockSyncPayload payload,
  ) async {
    await _ensurePendingAddressBlockSyncLoaded();
    if (_pendingAddressBlockRetractions.contains(payload.address)) {
      await retractAddressBlockSync(payload.address);
      return;
    }

    final localEntry = await _dbOpReturning<XmppDatabase, AddressBlockEntry?>(
      (db) => db.getAddressBlockEntry(payload.address),
    );
    if (localEntry != null) {
      final decision = _resolveAddressBlockSyncDecision(
        local: localEntry,
        remote: payload,
        localSourceId: await _ensureAddressBlockSourceId(),
      );
      switch (decision) {
        case _AddressBlockSyncDecision.applyRemote:
          await _applyAddressBlockStatus(
            address: payload.address,
            blocked: true,
            updatedAt: payload.updatedAt,
            sourceId: payload.sourceId,
            origin: anti_abuse.SyncOrigin.remote,
          );
        case _AddressBlockSyncDecision.publishLocal:
          await publishAddressBlockSync(localEntry);
        case _AddressBlockSyncDecision.skip:
          return;
      }
      return;
    }

    await _applyAddressBlockStatus(
      address: payload.address,
      blocked: true,
      updatedAt: payload.updatedAt,
      sourceId: payload.sourceId,
      origin: anti_abuse.SyncOrigin.remote,
    );
    await _clearPendingAddressBlockPublish(payload.address);
  }

  Future<void> _applyAddressBlockSyncRetraction(String address) async {
    await _ensurePendingAddressBlockSyncLoaded();
    final normalized = _normalizeAddressBlockAddress(address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    if (_pendingAddressBlockPublishes.contains(normalized)) {
      return;
    }
    await _applyAddressBlockStatus(
      address: normalized,
      blocked: false,
      updatedAt: DateTime.timestamp().toUtc(),
      sourceId: await _ensureAddressBlockSourceId(),
      origin: anti_abuse.SyncOrigin.remote,
    );
    await _clearPendingAddressBlockRetraction(normalized);
  }

  _AddressBlockSyncDecision _resolveAddressBlockSyncDecision({
    required AddressBlockEntry local,
    required AddressBlockSyncPayload remote,
    required String localSourceId,
  }) {
    final localUpdatedAt = local.blockedAt.toUtc();
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    if (localUpdatedAt.isBefore(remoteUpdatedAt)) {
      return _AddressBlockSyncDecision.applyRemote;
    }
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return _AddressBlockSyncDecision.publishLocal;
    }
    final localSource = _normalizeAddressBlockSourceId(local.sourceId);
    if (localSource == remote.sourceId) {
      return _AddressBlockSyncDecision.skip;
    }
    if (localSourceId == localSource) {
      return _AddressBlockSyncDecision.publishLocal;
    }
    return _AddressBlockSyncDecision.applyRemote;
  }

  Future<void> _applyAddressBlockStatus({
    required String address,
    required bool blocked,
    required DateTime updatedAt,
    required String sourceId,
    required anti_abuse.SyncOrigin origin,
  }) async {
    final normalized = _normalizeAddressBlockAddress(address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    await _dbOp<XmppDatabase>((db) async {
      if (blocked) {
        await db.addAddressBlock(
          normalized,
          blockedAt: updatedAt,
          sourceId: sourceId,
        );
      } else {
        await db.removeAddressBlock(normalized);
      }
    });
    emitAddressBlockSyncUpdate(
      anti_abuse.AddressBlockSyncUpdate(
        address: normalized,
        blocked: blocked,
        updatedAt: updatedAt,
        sourceId: sourceId,
        origin: origin,
      ),
    );
  }

  String _normalizeAddressBlockSourceId(String? sourceId) {
    final normalized = sourceId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return anti_abuse.syncLegacySourceId;
    }
    return normalized;
  }

  Future<String> _ensureAddressBlockSourceId() async {
    final cached = _addressBlockSourceId;
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }
    final stored = await _dbOpReturning<XmppStateStore, String?>(
      (ss) async => ss.read(key: _addressBlockSyncSourceKey) as String?,
    );
    final trimmed = stored?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      _addressBlockSourceId = trimmed;
      return trimmed;
    }
    final generated = uuid.v4();
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(key: _addressBlockSyncSourceKey, value: generated),
    );
    _addressBlockSourceId = generated;
    return generated;
  }

  Future<void> _ensurePendingAddressBlockSyncLoaded() async {
    if (_pendingAddressBlockSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>((ss) async {
      final rawPublishes =
          (ss.read(key: _addressBlockPendingPublishesKey) as List?)
              ?.cast<Object?>();
      final rawRetractions =
          (ss.read(key: _addressBlockPendingRetractionsKey) as List?)
              ?.cast<Object?>();
      _pendingAddressBlockPublishes
        ..clear()
        ..addAll(_normalizeAddressBlockSyncIds(rawPublishes));
      _pendingAddressBlockRetractions
        ..clear()
        ..addAll(_normalizeAddressBlockSyncIds(rawRetractions));
    }, awaitDatabase: true);
    _pendingAddressBlockSyncLoaded = true;
  }

  Future<void> _ensureAddressBlockSnapshotMetaLoaded() async {
    if (_addressBlockSnapshotMetaLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>((ss) async {
      final rawTimestamp = ss.read(key: _addressBlockSnapshotAtKey);
      final rawIds = (ss.read(key: _addressBlockSnapshotIdsKey) as List?)
          ?.cast<Object?>();
      _addressBlockLastSnapshotAt = _parseAddressBlockSnapshotAt(rawTimestamp);
      _addressBlockLastSnapshotIds
        ..clear()
        ..addAll(_normalizeAddressBlockSyncIds(rawIds));
    }, awaitDatabase: true);
    _addressBlockSnapshotMetaLoaded = true;
  }

  DateTime? _parseAddressBlockSnapshotAt(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Iterable<String> _normalizeAddressBlockSyncIds(List<Object?>? raw) sync* {
    if (raw == null || raw.isEmpty) {
      return;
    }
    for (final entry in raw) {
      final normalized = _normalizeAddressBlockAddress(entry?.toString());
      if (normalized == null || normalized.isEmpty) {
        continue;
      }
      yield normalized;
    }
  }

  Future<void> _persistAddressBlockSnapshotMeta({
    required DateTime snapshotAt,
    required Set<String> remoteIds,
  }) async {
    _addressBlockLastSnapshotAt = snapshotAt;
    _addressBlockLastSnapshotIds
      ..clear()
      ..addAll(remoteIds);
    await _dbOp<XmppStateStore>(
      (ss) async => ss.writeAll(
        data: {
          _addressBlockSnapshotAtKey: snapshotAt.toIso8601String(),
          _addressBlockSnapshotIdsKey: remoteIds.toList(growable: false),
        },
      ),
      awaitDatabase: true,
    );
  }

  bool _shouldApplyMissingAddressBlockDeletion({
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
    if (_pendingAddressBlockPublishes.contains(address)) {
      return false;
    }
    final normalizedSource = _normalizeAddressBlockSourceId(entrySourceId);
    if (normalizedSource != localSourceId) {
      return true;
    }
    if (lastSnapshotAt == null) {
      return false;
    }
    return !localUpdatedAt.toUtc().isAfter(lastSnapshotAt);
  }

  Future<void> _persistPendingAddressBlockSync() async {
    if (!_pendingAddressBlockSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async => ss.writeAll(
        data: {
          _addressBlockPendingPublishesKey: _pendingAddressBlockPublishes
              .toList(growable: false),
          _addressBlockPendingRetractionsKey: _pendingAddressBlockRetractions
              .toList(growable: false),
        },
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueAddressBlockPublish(String address) async {
    final normalized = _normalizeAddressBlockAddress(address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    await _ensurePendingAddressBlockSyncLoaded();
    _pendingAddressBlockRetractions.remove(normalized);
    _pendingAddressBlockPublishes.add(normalized);
    await _persistPendingAddressBlockSync();
  }

  Future<void> _queueAddressBlockRetraction(String address) async {
    final normalized = _normalizeAddressBlockAddress(address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    await _ensurePendingAddressBlockSyncLoaded();
    _pendingAddressBlockPublishes.remove(normalized);
    _pendingAddressBlockRetractions.add(normalized);
    await _persistPendingAddressBlockSync();
  }

  Future<void> _clearPendingAddressBlockPublish(String address) async {
    final normalized = _normalizeAddressBlockAddress(address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    await _ensurePendingAddressBlockSyncLoaded();
    final removed = _pendingAddressBlockPublishes.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingAddressBlockSync();
  }

  Future<void> _clearPendingAddressBlockRetraction(String address) async {
    final normalized = _normalizeAddressBlockAddress(address);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    await _ensurePendingAddressBlockSyncLoaded();
    final removed = _pendingAddressBlockRetractions.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingAddressBlockSync();
  }

  Future<void> _flushPendingAddressBlockSync() async {
    await _ensurePendingAddressBlockSyncLoaded();
    if (_pendingAddressBlockPublishes.isEmpty &&
        _pendingAddressBlockRetractions.isEmpty) {
      return;
    }
    final support = await refreshPubSubSupport();
    final decision = decidePubSubSupport(
      supported: support.canUsePepNodes,
      featureLabel: 'address block sync',
    );
    if (!decision.isAllowed) {
      return;
    }
    final manager = _addressBlockManager;
    if (manager == null) {
      return;
    }
    await manager.ensureNode();

    final pendingRetractions = _pendingAddressBlockRetractions.toList(
      growable: false,
    );
    for (final address in pendingRetractions) {
      final retracted = await manager.retractBlock(address);
      if (retracted) {
        _pendingAddressBlockRetractions.remove(address);
      }
    }

    final pendingPublishes = _pendingAddressBlockPublishes.toList(
      growable: false,
    );
    for (final address in pendingPublishes) {
      final localEntry = await _dbOpReturning<XmppDatabase, AddressBlockEntry?>(
        (db) => db.getAddressBlockEntry(address),
      );
      if (localEntry == null) {
        _pendingAddressBlockPublishes.remove(address);
        continue;
      }
      final published = await manager.publishBlock(
        AddressBlockSyncPayload(
          address: localEntry.address,
          updatedAt: localEntry.blockedAt.toUtc(),
          sourceId: _normalizeAddressBlockSourceId(localEntry.sourceId),
        ),
      );
      if (published) {
        _pendingAddressBlockPublishes.remove(address);
      }
    }

    await _persistPendingAddressBlockSync();
  }

  Future<void> requestBlocklist() async {
    if (await _connection.requestBlocklist() case final blocked?) {
      await _dbOp<XmppDatabase>((db) => db.replaceBlocklist(blocked));
    }
  }

  Future<void> block({required String jid}) async {
    _blockingLogger.info('Requesting to block $jid...');
    await _connection.block(jid);
  }

  Future<void> blockAndReport({
    required String jid,
    required SpamReportReason reason,
    String? reportText,
    List<SpamReportStanzaId> stanzaIds = const <SpamReportStanzaId>[],
  }) async {
    final normalized = jid.trim();
    if (normalized.isEmpty) return;
    final manager = _connection.getManager<mox.BlockingManager>();
    if (manager == null) {
      throw XmppBlockUnsupportedException();
    }
    if (!await _ensureSpamReportingSupport()) {
      throw XmppSpamReportUnsupportedException();
    }
    final reportChildren = <mox.XMLNode>[
      for (final stanzaId in stanzaIds)
        if (stanzaId.by.trim().isNotEmpty && stanzaId.id.trim().isNotEmpty)
          stanzaId.toXml(),
      if (reportText != null && reportText.trim().isNotEmpty)
        mox.XMLNode(tag: _reportTextTag, text: reportText.trim()),
    ];
    final reportNode = mox.XMLNode.xmlns(
      tag: _reportTag,
      xmlns: _reportingXmlns,
      attributes: {_reportReasonAttr: reason.urn},
      children: reportChildren,
    );
    final blockNode = mox.XMLNode.xmlns(
      tag: _blockTag,
      xmlns: _blockingXmlns,
      children: [
        mox.XMLNode(
          tag: _blockItemTag,
          attributes: {_blockingJidAttr: normalized},
          children: [reportNode],
        ),
      ],
    );
    final result = await _connection.sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(type: _blockingIqTypeSet, children: [blockNode]),
        shouldEncrypt: false,
      ),
    );
    if (result == null ||
        result.attributes[_iqTypeAttr]?.toString() != _blockingIqTypeResult) {
      throw XmppSpamReportException();
    }
  }

  Future<void> unblock({required String jid}) async {
    _blockingLogger.info('Requesting to unblock $jid...');
    await _connection.unblock(jid);
  }

  Future<void> unblockAll() async {
    _blockingLogger.info('Requesting to unblock all...');
    await _connection.unblockAll();
  }

  Future<bool> _ensureSpamReportingSupport() async {
    if (_spamReportingSupportResolved) {
      return _spamReportingSupported;
    }
    _spamReportingSupportResolved = true;
    _spamReportingSupported = true;
    return true;
  }
}
