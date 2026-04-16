// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _homeBadgeSyncSnapshotKeyName = 'home_badge_sync_snapshot';
const String _homeBadgeSyncSnapshotBootstrapOperationName =
    'HomeBadgeMarkerSyncService.syncHomeBadgeSnapshotOnNegotiations';

final _homeBadgeSyncSnapshotKey = XmppStateStore.registerKey(
  _homeBadgeSyncSnapshotKeyName,
);

mixin HomeBadgeMarkerSyncService on XmppBase, BaseStreamService {
  bool _homeBadgeSyncStateLoaded = false;
  bool _homeBadgeSnapshotInFlight = false;
  final Map<HomeBadgeBucket, DateTime> _homeBadgeMarkers =
      <HomeBadgeBucket, DateTime>{};
  final StreamController<Map<HomeBadgeBucket, DateTime>>
  _homeBadgeSeenMarkersController =
      StreamController<Map<HomeBadgeBucket, DateTime>>.broadcast();

  HomeBadgeMarkersPubSubManager? get _homeBadgeMarkersManager =>
      _connection.getManager<HomeBadgeMarkersPubSubManager>();

  @override
  Map<HomeBadgeBucket, DateTime> get homeBadgeSeenMarkers =>
      Map<HomeBadgeBucket, DateTime>.unmodifiable(_homeBadgeMarkers);

  @override
  Stream<Map<HomeBadgeBucket, DateTime>> get homeBadgeSeenMarkersStream async* {
    await _ensureHomeBadgeSyncStateLoaded();
    yield homeBadgeSeenMarkers;
    yield* _homeBadgeSeenMarkersController.stream;
  }

  @override
  Future<void> markHomeBadgeBucketSeen({
    required HomeBadgeBucket bucket,
    required DateTime seenAt,
  }) async {
    await _ensureHomeBadgeSyncStateLoaded();
    final normalizedSeenAt = seenAt.toUtc();
    final current = _homeBadgeMarkers[bucket]?.toUtc();
    if (current != null && !normalizedSeenAt.isAfter(current)) {
      return;
    }
    _homeBadgeMarkers[bucket] = normalizedSeenAt;
    await _persistHomeBadgeSyncStateIfAvailable();
    _emitHomeBadgeSeenMarkers();
    if (!_hasInitializedConnection || !_connection.hasConnectionSettings) {
      return;
    }
    await _publishHomeBadgeMarker(bucket: bucket, seenAt: normalizedSeenAt);
  }

  Future<bool> syncHomeBadgeMarkersSnapshot() async {
    if (_homeBadgeSnapshotInFlight) {
      return true;
    }
    _homeBadgeSnapshotInFlight = true;
    try {
      await _ensureHomeBadgeSyncStateLoaded();
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'home badge marker sync',
      );
      if (!decision.isAllowed) {
        return true;
      }
      final manager = _homeBadgeMarkersManager;
      if (manager == null) {
        return true;
      }
      await manager.ensureNode();
      await manager.subscribe();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return false;
      }

      final remoteByBucket = <HomeBadgeBucket, HomeBadgeMarkerPayload>{
        for (final item in snapshot.items) item.bucket: item,
      };

      for (final remote in remoteByBucket.values) {
        final local = _homeBadgeMarkers[remote.bucket]?.toUtc();
        if (local == null) {
          await _applyRemoteHomeBadgeMarker(remote);
          continue;
        }
        final remoteSeenAt = remote.seenAt.toUtc();
        if (remoteSeenAt.isAfter(local)) {
          await _applyRemoteHomeBadgeMarker(remote);
          continue;
        }
        if (local.isAfter(remoteSeenAt)) {
          await _publishHomeBadgeMarker(
            bucket: remote.bucket,
            seenAt: local,
            managerOverride: manager,
          );
        }
      }

      for (final entry in _homeBadgeMarkers.entries) {
        if (remoteByBucket.containsKey(entry.key)) {
          continue;
        }
        await _publishHomeBadgeMarker(
          bucket: entry.key,
          seenAt: entry.value.toUtc(),
          managerOverride: manager,
        );
      }
      return true;
    } on XmppAbortedException {
      return false;
    } finally {
      _homeBadgeSnapshotInFlight = false;
    }
  }

  Future<void> _reconcileIncomingHomeBadgeMarker(
    HomeBadgeMarkerPayload remote,
  ) async {
    await _ensureHomeBadgeSyncStateLoaded();
    final local = _homeBadgeMarkers[remote.bucket]?.toUtc();
    if (local == null) {
      await _applyRemoteHomeBadgeMarker(remote);
      return;
    }
    final remoteSeenAt = remote.seenAt.toUtc();
    if (remoteSeenAt.isAfter(local)) {
      await _applyRemoteHomeBadgeMarker(remote);
      return;
    }
    if (local.isAfter(remoteSeenAt)) {
      await _publishHomeBadgeMarker(bucket: remote.bucket, seenAt: local);
    }
  }

  Future<void> _handleHomeBadgeMarkerRetraction(HomeBadgeBucket bucket) async {
    await _ensureHomeBadgeSyncStateLoaded();
    final local = _homeBadgeMarkers[bucket];
    if (local == null ||
        !_hasInitializedConnection ||
        !_connection.hasConnectionSettings) {
      return;
    }
    await _publishHomeBadgeMarker(bucket: bucket, seenAt: local.toUtc());
  }

  Future<void> _applyRemoteHomeBadgeMarker(
    HomeBadgeMarkerPayload payload,
  ) async {
    final nextSeenAt = payload.seenAt.toUtc();
    final previous = _homeBadgeMarkers[payload.bucket]?.toUtc();
    if (previous != null && !nextSeenAt.isAfter(previous)) {
      return;
    }
    _homeBadgeMarkers[payload.bucket] = nextSeenAt;
    await _persistHomeBadgeSyncStateIfAvailable();
    _emitHomeBadgeSeenMarkers();
  }

  Future<bool> _publishHomeBadgeMarker({
    required HomeBadgeBucket bucket,
    required DateTime seenAt,
    HomeBadgeMarkersPubSubManager? managerOverride,
  }) async {
    final manager = managerOverride ?? _homeBadgeMarkersManager;
    if (manager == null) {
      return false;
    }
    await manager.ensureNode();
    return manager.publishHomeBadgeMarker(
      HomeBadgeMarkerPayload(bucket: bucket, seenAt: seenAt.toUtc()),
    );
  }

  void _emitHomeBadgeSeenMarkers() {
    if (_homeBadgeSeenMarkersController.isClosed) {
      return;
    }
    _homeBadgeSeenMarkersController.add(homeBadgeSeenMarkers);
  }

  Future<void> _ensureHomeBadgeSyncStateLoaded() async {
    if (_homeBadgeSyncStateLoaded || !_canAccessHomeBadgeSyncStateStore) {
      return;
    }
    Object? snapshot;
    try {
      snapshot = await _dbOpReturning<XmppStateStore, Object?>(
        (ss) => ss.read(key: _homeBadgeSyncSnapshotKey),
      );
    } on XmppAbortedException {
      return;
    }
    _homeBadgeMarkers
      ..clear()
      ..addAll(_decodeStoredHomeBadgeSnapshot(snapshot));
    _homeBadgeSyncStateLoaded = true;
  }

  Map<HomeBadgeBucket, DateTime> _decodeStoredHomeBadgeSnapshot(Object? raw) {
    Object? decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        return const <HomeBadgeBucket, DateTime>{};
      }
    }
    if (decoded is! Map) {
      return const <HomeBadgeBucket, DateTime>{};
    }
    final snapshot = <HomeBadgeBucket, DateTime>{};
    for (final entry in decoded.entries) {
      final bucket = HomeBadgeBucket.fromItemId(entry.key.toString());
      final value = entry.value;
      if (bucket == null) {
        continue;
      }
      final seenAt = value is Map
          ? _parseStoredHomeBadgeTimestamp(value['seen_at'])
          : _parseStoredHomeBadgeTimestamp(value);
      if (seenAt == null) {
        continue;
      }
      snapshot[bucket] = seenAt;
    }
    return snapshot;
  }

  DateTime? _parseStoredHomeBadgeTimestamp(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  bool get _canAccessHomeBadgeSyncStateStore =>
      isStateStoreReady && _myJid != null;

  Future<void> _persistHomeBadgeSyncStateIfAvailable() async {
    if (!_canAccessHomeBadgeSyncStateStore) {
      return;
    }
    final snapshotJson = jsonEncode(<String, String>{
      for (final entry in _homeBadgeMarkers.entries)
        entry.key.itemId: entry.value.toUtc().toIso8601String(),
    });
    try {
      await _dbOp<XmppStateStore>((ss) async {
        await ss.write(key: _homeBadgeSyncSnapshotKey, value: snapshotJson);
      });
    } on XmppAbortedException {
      return;
    }
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _homeBadgeSyncSnapshotBootstrapOperationName,
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.resumedNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _homeBadgeSyncSnapshotBootstrapOperationName,
        run: () async {
          await syncHomeBadgeMarkersSnapshot();
        },
      ),
    );
    manager
      ..registerHandler<HomeBadgeMarkerSyncUpdatedEvent>((event) async {
        await _reconcileIncomingHomeBadgeMarker(event.payload);
      })
      ..registerHandler<HomeBadgeMarkerSyncRetractedEvent>((event) async {
        await _handleHomeBadgeMarkerRetraction(event.bucket);
      });
  }

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    HomeBadgeMarkersPubSubManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    homeBadgeMarkersNotifyFeature,
  ];

  @override
  Future<void> _reset() async {
    _homeBadgeMarkers.clear();
    _homeBadgeSyncStateLoaded = false;
    _homeBadgeSnapshotInFlight = false;
    _emitHomeBadgeSeenMarkers();
    await super._reset();
  }
}
