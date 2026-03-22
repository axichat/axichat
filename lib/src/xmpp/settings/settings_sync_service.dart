// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _settingsSyncSourceKeyName = 'settings_sync_source_id';
const String _settingsSyncSnapshotPayloadKeyName =
    'settings_sync_snapshot_payload';
const String _settingsSyncSnapshotUpdatedAtKeyName =
    'settings_sync_snapshot_updated_at';
const String _settingsSyncSnapshotSourceIdKeyName =
    'settings_sync_snapshot_source_id';
const String _settingsSyncSnapshotBootstrapOperationName =
    'SettingsSyncService.syncSettingsSnapshotOnNegotiations';

final _settingsSyncSourceKey = XmppStateStore.registerKey(
  _settingsSyncSourceKeyName,
);
final _settingsSyncSnapshotPayloadKey = XmppStateStore.registerKey(
  _settingsSyncSnapshotPayloadKeyName,
);
final _settingsSyncSnapshotUpdatedAtKey = XmppStateStore.registerKey(
  _settingsSyncSnapshotUpdatedAtKeyName,
);
final _settingsSyncSnapshotSourceIdKey = XmppStateStore.registerKey(
  _settingsSyncSnapshotSourceIdKeyName,
);

enum _SettingsSyncDecision { applyRemote, publishLocal, skip }

mixin SettingsSyncService on XmppBase, BaseStreamService {
  String? _settingsDeviceSourceId;
  String? _settingsSnapshotJson;
  DateTime? _settingsSnapshotUpdatedAt;
  String? _settingsSnapshotSourceId;
  String? _storedSettingsSnapshotJson;
  DateTime? _storedSettingsSnapshotUpdatedAt;
  String? _storedSettingsSnapshotSourceId;
  bool _settingsSyncStateLoaded = false;
  bool _settingsSnapshotInFlight = false;

  StreamController<Map<String, dynamic>> _settingsSyncUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  SettingsPubSubManager? get _settingsManager =>
      _connection.getManager<SettingsPubSubManager>();

  @override
  Stream<Map<String, dynamic>> get settingsSyncUpdateStream =>
      _settingsSyncUpdateController.stream;

  @override
  Future<void> seedSettingsSyncSnapshot(Map<String, dynamic> settings) async {
    final encoded = SettingsSyncPayload.encodeSettingsData(settings);
    if (encoded == null) {
      return;
    }
    _settingsSnapshotJson = encoded;
    await _ensureSettingsSyncStateLoaded();
  }

  @override
  Future<void> updateSettingsSyncSnapshot(Map<String, dynamic> settings) async {
    final encoded = SettingsSyncPayload.encodeSettingsData(settings);
    if (encoded == null) {
      return;
    }
    _settingsSnapshotJson = encoded;
    _settingsSnapshotUpdatedAt = DateTime.timestamp().toUtc();
    _settingsSnapshotSourceId = await _ensureSettingsDeviceSourceId();
    await _persistSettingsSyncStateIfAvailable();
    if (!_hasInitializedConnection || !_connection.hasConnectionSettings) {
      return;
    }
    await _publishCurrentSettingsSnapshot();
  }

  Future<bool> syncSettingsSnapshot() async {
    if (_settingsSnapshotInFlight) {
      return true;
    }
    _settingsSnapshotInFlight = true;
    try {
      await _ensureSettingsSyncStateLoaded();
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'settings sync',
      );
      if (!decision.isAllowed) {
        return true;
      }
      final manager = _settingsManager;
      if (manager == null) {
        return true;
      }
      await manager.ensureNode();
      await manager.subscribe();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return false;
      }
      final remote = snapshot.items.isEmpty ? null : snapshot.items.last;
      if (remote == null) {
        if (_settingsSnapshotJson == null) {
          return true;
        }
        return await _publishCurrentSettingsSnapshot(managerOverride: manager);
      }
      return await _reconcileIncomingSettingsSync(
        remote,
        managerOverride: manager,
      );
    } on XmppAbortedException {
      return false;
    } finally {
      _settingsSnapshotInFlight = false;
    }
  }

  Future<bool> _reconcileIncomingSettingsSync(
    SettingsSyncPayload remote, {
    SettingsPubSubManager? managerOverride,
  }) async {
    switch (_resolveIncomingSettingsSyncDecision(remote)) {
      case _SettingsSyncDecision.applyRemote:
        await _applyRemoteSettingsSync(remote);
        return true;
      case _SettingsSyncDecision.publishLocal:
        return await _publishCurrentSettingsSnapshot(
          managerOverride: managerOverride,
        );
      case _SettingsSyncDecision.skip:
        return true;
    }
  }

  Future<void> _applyRemoteSettingsSync(SettingsSyncPayload payload) async {
    final encoded = SettingsSyncPayload.encodeSettingsData(payload.settings);
    if (encoded == null) {
      return;
    }
    _settingsSnapshotJson = encoded;
    _settingsSnapshotUpdatedAt = payload.updatedAt.toUtc();
    _settingsSnapshotSourceId = payload.sourceId.trim();
    await _persistSettingsSyncStateIfAvailable();
    if (_settingsSyncUpdateController.isClosed) {
      return;
    }
    final decoded = SettingsSyncPayload.decodeSettingsData(encoded);
    if (decoded == null) {
      return;
    }
    _settingsSyncUpdateController.add(decoded);
  }

  _SettingsSyncDecision _resolveIncomingSettingsSyncDecision(
    SettingsSyncPayload remote,
  ) {
    final localSnapshotJson = _settingsSnapshotJson;
    final localUpdatedAt = _settingsSnapshotUpdatedAt;
    final localSourceId = _settingsSnapshotSourceId?.trim();
    if (localSnapshotJson != null &&
        localUpdatedAt != null &&
        localSourceId != null &&
        localSourceId.isNotEmpty) {
      return _resolveSettingsSyncDecision(
        localUpdatedAt: localUpdatedAt,
        localSourceId: localSourceId,
        remote: remote,
      );
    }
    return _resolveStoredSettingsSyncDecision(remote);
  }

  _SettingsSyncDecision _resolveStoredSettingsSyncDecision(
    SettingsSyncPayload remote,
  ) {
    final localSnapshotJson = _settingsSnapshotJson;
    if (localSnapshotJson == null) {
      return _SettingsSyncDecision.applyRemote;
    }
    final storedSnapshotJson = _storedSettingsSnapshotJson;
    if (storedSnapshotJson == null) {
      return _SettingsSyncDecision.applyRemote;
    }
    final storedUpdatedAt = _storedSettingsSnapshotUpdatedAt;
    final storedSourceId = _storedSettingsSnapshotSourceId?.trim();
    if (localSnapshotJson == storedSnapshotJson) {
      if (storedUpdatedAt == null ||
          storedSourceId == null ||
          storedSourceId.isEmpty) {
        return _SettingsSyncDecision.applyRemote;
      }
      return _resolveSettingsSyncDecision(
        localUpdatedAt: storedUpdatedAt,
        localSourceId: storedSourceId,
        remote: remote,
      );
    }

    final remoteSnapshotJson = SettingsSyncPayload.encodeSettingsData(
      remote.settings,
    );
    if (remoteSnapshotJson == storedSnapshotJson) {
      return _SettingsSyncDecision.publishLocal;
    }
    if (storedUpdatedAt == null ||
        storedSourceId == null ||
        storedSourceId.isEmpty) {
      return _SettingsSyncDecision.applyRemote;
    }
    final decision = _resolveSettingsSyncDecision(
      localUpdatedAt: storedUpdatedAt,
      localSourceId: storedSourceId,
      remote: remote,
    );
    return decision == _SettingsSyncDecision.skip
        ? _SettingsSyncDecision.applyRemote
        : decision;
  }

  Future<void> _handleSettingsSyncRetraction(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isNotEmpty &&
        normalized != SettingsSyncPayload.currentItemId) {
      return;
    }
    if (_settingsSnapshotJson == null ||
        !_hasInitializedConnection ||
        !_connection.hasConnectionSettings) {
      return;
    }
    await _publishCurrentSettingsSnapshot();
  }

  _SettingsSyncDecision _resolveSettingsSyncDecision({
    required DateTime localUpdatedAt,
    required String localSourceId,
    required SettingsSyncPayload remote,
  }) {
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    final normalizedLocalSourceId = localSourceId.trim();
    final normalizedRemoteSourceId = remote.sourceId.trim();
    if (remoteUpdatedAt.isAfter(localUpdatedAt.toUtc())) {
      return _SettingsSyncDecision.applyRemote;
    }
    if (remoteUpdatedAt.isBefore(localUpdatedAt.toUtc())) {
      return _SettingsSyncDecision.publishLocal;
    }
    if (normalizedRemoteSourceId == normalizedLocalSourceId) {
      return _SettingsSyncDecision.skip;
    }
    if (normalizedRemoteSourceId.compareTo(normalizedLocalSourceId) > 0) {
      return _SettingsSyncDecision.applyRemote;
    }
    return _SettingsSyncDecision.publishLocal;
  }

  Future<bool> _publishCurrentSettingsSnapshot({
    SettingsPubSubManager? managerOverride,
  }) async {
    final snapshotJson = _settingsSnapshotJson;
    if (snapshotJson == null) {
      return true;
    }
    final decoded = SettingsSyncPayload.decodeSettingsData(snapshotJson);
    if (decoded == null) {
      return false;
    }
    var updatedAt = _settingsSnapshotUpdatedAt;
    var sourceId = _settingsSnapshotSourceId?.trim();
    if (updatedAt == null || sourceId == null || sourceId.isEmpty) {
      updatedAt = DateTime.timestamp().toUtc();
      sourceId = await _ensureSettingsDeviceSourceId();
      _settingsSnapshotUpdatedAt = updatedAt;
      _settingsSnapshotSourceId = sourceId;
      await _persistSettingsSyncStateIfAvailable();
    }
    final manager = managerOverride ?? _settingsManager;
    if (manager == null) {
      return false;
    }
    await manager.ensureNode();
    return await manager.publishSettings(
      SettingsSyncPayload(
        settings: decoded,
        updatedAt: updatedAt,
        sourceId: sourceId,
      ),
    );
  }

  Future<String> _ensureSettingsDeviceSourceId() async {
    await _ensureSettingsSyncStateLoaded();
    final existing = _settingsDeviceSourceId?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = const Uuid().v4();
    _settingsDeviceSourceId = generated;
    await _persistSettingsSyncStateIfAvailable();
    return generated;
  }

  Future<void> _ensureSettingsSyncStateLoaded() async {
    if (_settingsSyncStateLoaded || !_canAccessSettingsSyncStateStore) {
      return;
    }
    ({
      Object? deviceSourceId,
      Object? snapshotPayload,
      Object? snapshotUpdatedAt,
      Object? snapshotSourceId,
    })?
    state;
    try {
      state =
          await _dbOpReturning<
            XmppStateStore,
            ({
              Object? deviceSourceId,
              Object? snapshotPayload,
              Object? snapshotUpdatedAt,
              Object? snapshotSourceId,
            })
          >(
            (ss) => (
              deviceSourceId: ss.read(key: _settingsSyncSourceKey),
              snapshotPayload: ss.read(key: _settingsSyncSnapshotPayloadKey),
              snapshotUpdatedAt: ss.read(
                key: _settingsSyncSnapshotUpdatedAtKey,
              ),
              snapshotSourceId: ss.read(key: _settingsSyncSnapshotSourceIdKey),
            ),
          );
    } on XmppAbortedException {
      return;
    }
    final loadedDeviceSourceId = _normalizeSettingsSourceId(
      state.deviceSourceId,
    );
    if (_settingsDeviceSourceId == null &&
        loadedDeviceSourceId != null &&
        loadedDeviceSourceId.isNotEmpty) {
      _settingsDeviceSourceId = loadedDeviceSourceId;
    }

    final loadedSnapshotJson = _normalizeSettingsSnapshotJson(
      state.snapshotPayload,
    );
    final loadedSnapshotUpdatedAt = _parseSettingsSnapshotAt(
      state.snapshotUpdatedAt,
    );
    final loadedSnapshotSourceId = _normalizeSettingsSourceId(
      state.snapshotSourceId,
    );
    _storedSettingsSnapshotJson = loadedSnapshotJson;
    _storedSettingsSnapshotUpdatedAt = loadedSnapshotUpdatedAt;
    _storedSettingsSnapshotSourceId = loadedSnapshotSourceId;
    _restoreCurrentSettingsSnapshotFromStoredState(
      snapshotJson: loadedSnapshotJson,
      snapshotUpdatedAt: loadedSnapshotUpdatedAt,
      snapshotSourceId: loadedSnapshotSourceId,
    );
    _settingsSyncStateLoaded = true;
  }

  void _restoreCurrentSettingsSnapshotFromStoredState({
    required String? snapshotJson,
    required DateTime? snapshotUpdatedAt,
    required String? snapshotSourceId,
  }) {
    final currentSnapshotJson = _settingsSnapshotJson;
    final currentSnapshotUpdatedAt = _settingsSnapshotUpdatedAt;
    final currentSnapshotSourceId = _settingsSnapshotSourceId?.trim();
    if (currentSnapshotJson == null) {
      _settingsSnapshotJson = snapshotJson;
      _settingsSnapshotUpdatedAt = snapshotUpdatedAt;
      _settingsSnapshotSourceId = snapshotSourceId;
      return;
    }
    if (snapshotJson == currentSnapshotJson) {
      _settingsSnapshotUpdatedAt ??= snapshotUpdatedAt;
      if ((_settingsSnapshotSourceId == null ||
              _settingsSnapshotSourceId!.trim().isEmpty) &&
          snapshotSourceId != null &&
          snapshotSourceId.isNotEmpty) {
        _settingsSnapshotSourceId = snapshotSourceId;
      }
      return;
    }
    if (currentSnapshotUpdatedAt != null &&
        currentSnapshotSourceId != null &&
        currentSnapshotSourceId.isNotEmpty) {
      _settingsSnapshotUpdatedAt = currentSnapshotUpdatedAt.toUtc();
      _settingsSnapshotSourceId = currentSnapshotSourceId;
      return;
    }
    _settingsSnapshotUpdatedAt = null;
    _settingsSnapshotSourceId = null;
  }

  bool get _canAccessSettingsSyncStateStore =>
      isStateStoreReady && _myJid != null;

  Future<void> _persistSettingsSyncStateIfAvailable() async {
    if (!_canAccessSettingsSyncStateStore) {
      return;
    }
    final deviceSourceId = _settingsDeviceSourceId?.trim();
    final snapshotJson = _settingsSnapshotJson;
    final snapshotUpdatedAt = _settingsSnapshotUpdatedAt;
    final snapshotSourceId = _settingsSnapshotSourceId?.trim();
    try {
      await _dbOp<XmppStateStore>((ss) async {
        if (deviceSourceId != null && deviceSourceId.isNotEmpty) {
          await ss.write(key: _settingsSyncSourceKey, value: deviceSourceId);
        }
        if (snapshotJson != null) {
          await ss.write(
            key: _settingsSyncSnapshotPayloadKey,
            value: snapshotJson,
          );
        }
        if (snapshotUpdatedAt != null) {
          await ss.write(
            key: _settingsSyncSnapshotUpdatedAtKey,
            value: snapshotUpdatedAt.toIso8601String(),
          );
        }
        if (snapshotSourceId != null && snapshotSourceId.isNotEmpty) {
          await ss.write(
            key: _settingsSyncSnapshotSourceIdKey,
            value: snapshotSourceId,
          );
        }
      });
    } on XmppAbortedException {
      return;
    }
    if (snapshotJson != null) {
      _storedSettingsSnapshotJson = snapshotJson;
    }
    if (snapshotUpdatedAt != null) {
      _storedSettingsSnapshotUpdatedAt = snapshotUpdatedAt.toUtc();
    }
    if (snapshotSourceId != null && snapshotSourceId.isNotEmpty) {
      _storedSettingsSnapshotSourceId = snapshotSourceId;
    }
    _settingsSyncStateLoaded = true;
  }

  DateTime? _parseSettingsSnapshotAt(Object? raw) {
    final normalized = raw?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return DateTime.tryParse(normalized)?.toUtc();
  }

  String? _normalizeSettingsSnapshotJson(Object? raw) {
    final normalized = raw?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return SettingsSyncPayload.decodeSettingsData(normalized) == null
        ? null
        : normalized;
  }

  String? _normalizeSettingsSourceId(Object? raw) {
    final normalized = raw?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return clampUtf8Value(normalized, maxBytes: settingsSyncSourceIdMaxBytes);
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _settingsSyncSnapshotBootstrapOperationName,
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.resumedNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _settingsSyncSnapshotBootstrapOperationName,
        run: () async {
          await syncSettingsSnapshot();
        },
      ),
    );
    manager
      ..registerHandler<SettingsSyncUpdatedEvent>((event) async {
        await _reconcileIncomingSettingsSync(event.payload);
      })
      ..registerHandler<SettingsSyncRetractedEvent>((event) async {
        await _handleSettingsSyncRetraction(event.itemId);
      });
  }

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    SettingsPubSubManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    settingsNotifyFeature,
  ];

  @override
  Future<void> _reset() async {
    _settingsDeviceSourceId = null;
    _settingsSnapshotUpdatedAt = null;
    _settingsSnapshotSourceId = null;
    _storedSettingsSnapshotJson = null;
    _storedSettingsSnapshotUpdatedAt = null;
    _storedSettingsSnapshotSourceId = null;
    _settingsSyncStateLoaded = false;
    await super._reset();
  }
}
