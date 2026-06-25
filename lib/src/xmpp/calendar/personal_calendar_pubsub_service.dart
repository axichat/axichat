// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _personalCalendarSnapshotSourceKeyName =
    'personal_calendar_snapshot_source_id';
const String _personalCalendarSnapshotMigrationKeyName =
    'personal_calendar_pubsub_migration_v1';
const String _personalCalendarSnapshotMigrationCompleteValue = 'complete';
const String _personalCalendarSnapshotBootstrapOperationName =
    'PersonalCalendarPubSubService.syncSnapshotOnNegotiations';

final _personalCalendarSnapshotSourceKey = XmppStateStore.registerKey(
  _personalCalendarSnapshotSourceKeyName,
);
final _personalCalendarSnapshotMigrationKey = XmppStateStore.registerKey(
  _personalCalendarSnapshotMigrationKeyName,
);

typedef PersonalCalendarModelReader = CalendarModel Function();
typedef PersonalCalendarModelApplier =
    Future<void> Function(CalendarModel model);
typedef PersonalCalendarSnapshotStatusHandler =
    Future<void> Function(CalendarSnapshotPublishStatus status);

enum PersonalCalendarSnapshotSyncSignalKind { bootstrap, refresh, publish }

final class PersonalCalendarSnapshotSyncSignal {
  PersonalCalendarSnapshotSyncSignal({
    required this.kind,
    Completer<CalendarSnapshotPublishStatus>? completer,
  }) : _completer = completer ?? Completer<CalendarSnapshotPublishStatus>();

  final PersonalCalendarSnapshotSyncSignalKind kind;
  final Completer<CalendarSnapshotPublishStatus> _completer;

  Future<CalendarSnapshotPublishStatus> get result => _completer.future;

  void complete(CalendarSnapshotPublishStatus status) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete(status);
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.completeError(error, stackTrace);
  }
}

final class _PersonalCalendarSnapshotSyncRequest {
  const _PersonalCalendarSnapshotSyncRequest({
    required this.readModel,
    required this.applyModel,
    required this.onSnapshotPublishStatusChanged,
  });

  final PersonalCalendarModelReader readModel;
  final PersonalCalendarModelApplier applyModel;
  final PersonalCalendarSnapshotStatusHandler? onSnapshotPublishStatusChanged;
}

final class _PersonalCalendarSnapshotSyncResult {
  const _PersonalCalendarSnapshotSyncResult({
    required this.status,
    required this.remoteSnapshotFound,
  });

  final CalendarSnapshotPublishStatus status;
  final bool remoteSnapshotFound;
}

mixin PersonalCalendarPubSubService
    on XmppBase, BaseStreamService, MessageService {
  String? _personalCalendarSnapshotSourceId;
  bool _personalCalendarSnapshotSourceLoaded = false;
  bool _personalCalendarSnapshotPublishRequested = false;
  bool _personalCalendarSnapshotRefreshRequested = false;
  Future<_PersonalCalendarSnapshotSyncResult>? _personalCalendarSnapshotTask;
  _PersonalCalendarSnapshotSyncRequest? _personalCalendarSnapshotRequest;
  final Queue<PersonalCalendarSnapshotSyncSignal>
  _pendingPersonalCalendarSnapshotSignals =
      Queue<PersonalCalendarSnapshotSyncSignal>();

  StreamController<PersonalCalendarSnapshotSyncSignal>?
  _personalCalendarSnapshotController;

  StreamController<PersonalCalendarSnapshotSyncSignal>
  get _personalCalendarSnapshotSignalController =>
      _personalCalendarSnapshotController ??=
          StreamController<PersonalCalendarSnapshotSyncSignal>.broadcast(
            onListen: _flushPendingPersonalCalendarSnapshotSignals,
          );

  CalendarSnapshotPubSubManager? get _personalCalendarSnapshotManager =>
      _connection.getManager<CalendarSnapshotPubSubManager>();

  @override
  Stream<PersonalCalendarSnapshotSyncSignal>
  get personalCalendarSnapshotStream =>
      _personalCalendarSnapshotSignalController.stream;

  @override
  Future<CalendarSnapshotPublishStatus> publishPersonalCalendarSnapshot({
    required PersonalCalendarModelReader readModel,
    required PersonalCalendarModelApplier applyModel,
    PersonalCalendarSnapshotStatusHandler? onSnapshotPublishStatusChanged,
  }) async {
    final result = await _schedulePersonalCalendarSnapshotSync(
      readModel: readModel,
      applyModel: applyModel,
      publishIfChanged: true,
      onSnapshotPublishStatusChanged: onSnapshotPublishStatusChanged,
    );
    return result.status;
  }

  @override
  Future<CalendarSnapshotPublishStatus> syncPersonalCalendarSnapshot({
    required PersonalCalendarModelReader readModel,
    required PersonalCalendarModelApplier applyModel,
    bool publishIfChanged = false,
    PersonalCalendarSnapshotStatusHandler? onSnapshotPublishStatusChanged,
  }) async {
    final result = await _schedulePersonalCalendarSnapshotSync(
      readModel: readModel,
      applyModel: applyModel,
      publishIfChanged: publishIfChanged,
      onSnapshotPublishStatusChanged: onSnapshotPublishStatusChanged,
    );
    return result.status;
  }

  @override
  Future<CalendarSnapshotPublishStatus> bootstrapPersonalCalendarSnapshot({
    required PersonalCalendarModelReader readModel,
    required PersonalCalendarModelApplier applyModel,
    PersonalCalendarSnapshotStatusHandler? onSnapshotPublishStatusChanged,
  }) async {
    if (await _isPersonalCalendarPubSubMigrationComplete()) {
      return syncPersonalCalendarSnapshot(
        readModel: readModel,
        applyModel: applyModel,
        publishIfChanged: true,
        onSnapshotPublishStatusChanged: onSnapshotPublishStatusChanged,
      );
    }

    final initial = await _schedulePersonalCalendarSnapshotSync(
      readModel: readModel,
      applyModel: applyModel,
      publishIfChanged: false,
      onSnapshotPublishStatusChanged: onSnapshotPublishStatusChanged,
    );
    if (initial.status != CalendarSnapshotPublishStatus.idle) {
      final mamOutcome = await rehydrateCalendarFromMam();
      if (!_canSeedPersonalCalendarPubSubAfterMam(mamOutcome)) {
        return initial.status;
      }
      final published = await _schedulePersonalCalendarSnapshotSync(
        readModel: readModel,
        applyModel: applyModel,
        publishIfChanged: true,
        onSnapshotPublishStatusChanged: onSnapshotPublishStatusChanged,
      );
      if (published.status == CalendarSnapshotPublishStatus.idle) {
        await _markPersonalCalendarPubSubMigrationComplete();
      }
      return published.status;
    }

    if (initial.remoteSnapshotFound) {
      final published = await _schedulePersonalCalendarSnapshotSync(
        readModel: readModel,
        applyModel: applyModel,
        publishIfChanged: true,
        onSnapshotPublishStatusChanged: onSnapshotPublishStatusChanged,
      );
      if (published.status == CalendarSnapshotPublishStatus.idle) {
        await _markPersonalCalendarPubSubMigrationComplete();
      }
      return published.status;
    }

    final mamOutcome = await rehydrateCalendarFromMam();
    if (!_canSeedPersonalCalendarPubSubAfterMam(mamOutcome)) {
      return CalendarSnapshotPublishStatus.pending;
    }
    final published = await _schedulePersonalCalendarSnapshotSync(
      readModel: readModel,
      applyModel: applyModel,
      publishIfChanged: true,
      onSnapshotPublishStatusChanged: onSnapshotPublishStatusChanged,
    );
    if (published.status == CalendarSnapshotPublishStatus.idle) {
      await _markPersonalCalendarPubSubMigrationComplete();
    }
    return published.status;
  }

  Future<_PersonalCalendarSnapshotSyncResult>
  _schedulePersonalCalendarSnapshotSync({
    required PersonalCalendarModelReader readModel,
    required PersonalCalendarModelApplier applyModel,
    required bool publishIfChanged,
    required PersonalCalendarSnapshotStatusHandler?
    onSnapshotPublishStatusChanged,
  }) {
    _personalCalendarSnapshotRequest = _PersonalCalendarSnapshotSyncRequest(
      readModel: readModel,
      applyModel: applyModel,
      onSnapshotPublishStatusChanged: onSnapshotPublishStatusChanged,
    );
    if (publishIfChanged) {
      _personalCalendarSnapshotPublishRequested = true;
    } else {
      _personalCalendarSnapshotRefreshRequested = true;
    }
    final activeTask = _personalCalendarSnapshotTask;
    if (activeTask != null) {
      return activeTask.then((result) async {
        if (_personalCalendarSnapshotPublishRequested ||
            _personalCalendarSnapshotRefreshRequested) {
          return _startPersonalCalendarSnapshotSyncTask();
        }
        return result;
      });
    }
    return _startPersonalCalendarSnapshotSyncTask();
  }

  Future<_PersonalCalendarSnapshotSyncResult>
  _startPersonalCalendarSnapshotSyncTask() {
    final task = _drainPersonalCalendarSnapshotSync();
    _personalCalendarSnapshotTask = task;
    task.whenComplete(() {
      if (_personalCalendarSnapshotTask == task) {
        _personalCalendarSnapshotTask = null;
      }
    });
    return task;
  }

  Future<_PersonalCalendarSnapshotSyncResult>
  _drainPersonalCalendarSnapshotSync() async {
    var result = const _PersonalCalendarSnapshotSyncResult(
      status: CalendarSnapshotPublishStatus.idle,
      remoteSnapshotFound: false,
    );
    while (_personalCalendarSnapshotPublishRequested ||
        _personalCalendarSnapshotRefreshRequested) {
      final publishIfChanged = _personalCalendarSnapshotPublishRequested;
      _personalCalendarSnapshotPublishRequested = false;
      _personalCalendarSnapshotRefreshRequested = false;
      final request = _personalCalendarSnapshotRequest;
      if (request == null) {
        return result;
      }
      result = await _syncPersonalCalendarSnapshotPass(
        request,
        publishIfChanged: publishIfChanged,
      );
    }
    return result;
  }

  Future<_PersonalCalendarSnapshotSyncResult> _syncPersonalCalendarSnapshotPass(
    _PersonalCalendarSnapshotSyncRequest request, {
    required bool publishIfChanged,
  }) async {
    try {
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'personal calendar sync',
      );
      if (!decision.isAllowed) {
        await _notifyPersonalCalendarSnapshotStatus(
          request,
          CalendarSnapshotPublishStatus.pending,
        );
        return const _PersonalCalendarSnapshotSyncResult(
          status: CalendarSnapshotPublishStatus.pending,
          remoteSnapshotFound: false,
        );
      }
      final manager = _personalCalendarSnapshotManager;
      if (manager == null) {
        await _notifyPersonalCalendarSnapshotStatus(
          request,
          CalendarSnapshotPublishStatus.pending,
        );
        return const _PersonalCalendarSnapshotSyncResult(
          status: CalendarSnapshotPublishStatus.pending,
          remoteSnapshotFound: false,
        );
      }
      await manager.ensureNode();
      await manager.subscribe();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        await _notifyPersonalCalendarSnapshotStatus(
          request,
          CalendarSnapshotPublishStatus.pending,
        );
        return const _PersonalCalendarSnapshotSyncResult(
          status: CalendarSnapshotPublishStatus.pending,
          remoteSnapshotFound: false,
        );
      }
      final remote = snapshot.items.isEmpty ? null : snapshot.items.last;
      final remoteSnapshotFound = remote != null;
      final localModel = normalizeCalendarModelForSync(request.readModel());
      final CalendarModel mergedModel;
      if (remote == null || remote.checksum == localModel.checksum) {
        mergedModel = localModel;
      } else {
        mergedModel = normalizeCalendarModelForSync(
          localModel.mergeWith(remote.model),
        );
      }
      if (mergedModel.checksum != localModel.checksum) {
        await request.applyModel(mergedModel);
      }
      final shouldPublish =
          publishIfChanged &&
          (remote == null || remote.checksum != mergedModel.checksum);
      if (!shouldPublish) {
        await _notifyPersonalCalendarSnapshotStatus(
          request,
          CalendarSnapshotPublishStatus.idle,
        );
        return _PersonalCalendarSnapshotSyncResult(
          status: CalendarSnapshotPublishStatus.idle,
          remoteSnapshotFound: remoteSnapshotFound,
        );
      }
      final payload = await PersonalCalendarSnapshotPubSubPayload.create(
        model: mergedModel,
        updatedAt: DateTime.timestamp().toUtc(),
        sourceId: await _ensurePersonalCalendarSnapshotSourceId(),
      );
      if (payload == null) {
        await _notifyPersonalCalendarSnapshotStatus(
          request,
          CalendarSnapshotPublishStatus.blocked,
        );
        return _PersonalCalendarSnapshotSyncResult(
          status: CalendarSnapshotPublishStatus.blocked,
          remoteSnapshotFound: remoteSnapshotFound,
        );
      }
      if (!await manager.publishSnapshot(payload)) {
        await _notifyPersonalCalendarSnapshotStatus(
          request,
          CalendarSnapshotPublishStatus.pending,
        );
        return _PersonalCalendarSnapshotSyncResult(
          status: CalendarSnapshotPublishStatus.pending,
          remoteSnapshotFound: remoteSnapshotFound,
        );
      }
      await _notifyPersonalCalendarSnapshotStatus(
        request,
        CalendarSnapshotPublishStatus.idle,
      );
      return _PersonalCalendarSnapshotSyncResult(
        status: CalendarSnapshotPublishStatus.idle,
        remoteSnapshotFound: remoteSnapshotFound,
      );
    } on CalendarSnapshotTooLargeException {
      await _notifyPersonalCalendarSnapshotStatus(
        request,
        CalendarSnapshotPublishStatus.blocked,
      );
      return const _PersonalCalendarSnapshotSyncResult(
        status: CalendarSnapshotPublishStatus.blocked,
        remoteSnapshotFound: false,
      );
    } on XmppAbortedException {
      await _notifyPersonalCalendarSnapshotStatus(
        request,
        CalendarSnapshotPublishStatus.pending,
      );
      return const _PersonalCalendarSnapshotSyncResult(
        status: CalendarSnapshotPublishStatus.pending,
        remoteSnapshotFound: false,
      );
    }
  }

  Future<void> _syncPersonalCalendarSnapshotOnBootstrap() async {
    await _requestPersonalCalendarSnapshotSyncFromBloc(
      PersonalCalendarSnapshotSyncSignalKind.bootstrap,
    );
  }

  bool _canSeedPersonalCalendarPubSubAfterMam(CalendarMamOutcome outcome) {
    return switch (outcome) {
      CalendarMamOutcome.completed ||
      CalendarMamOutcome.skippedCoveredByGlobal ||
      CalendarMamOutcome.skippedUnsupported => true,
      CalendarMamOutcome.skippedUnauthorized ||
      CalendarMamOutcome.skippedInFlight ||
      CalendarMamOutcome.incomplete ||
      CalendarMamOutcome.failed => false,
    };
  }

  Future<void> _notifyPersonalCalendarSnapshotStatus(
    _PersonalCalendarSnapshotSyncRequest request,
    CalendarSnapshotPublishStatus status,
  ) async {
    final notify = request.onSnapshotPublishStatusChanged;
    if (notify != null) {
      await notify(status);
    }
  }

  Future<void> _handlePersonalCalendarSnapshotUpdate(
    PersonalCalendarSnapshotPubSubPayload payload,
  ) async {
    await _ensurePersonalCalendarSnapshotSourceLoaded();
    final sourceId = _normalizePersonalCalendarSnapshotSourceId(
      payload.sourceId,
    );
    if (sourceId != null && sourceId == _personalCalendarSnapshotSourceId) {
      return;
    }
    await _requestPersonalCalendarSnapshotSyncFromBloc(
      PersonalCalendarSnapshotSyncSignalKind.refresh,
    );
  }

  Future<void> _handlePersonalCalendarSnapshotRetraction(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isNotEmpty &&
        normalized != PersonalCalendarSnapshotPubSubPayload.currentItemId) {
      return;
    }
    await _requestPersonalCalendarSnapshotSyncFromBloc(
      PersonalCalendarSnapshotSyncSignalKind.publish,
    );
  }

  Future<CalendarSnapshotPublishStatus>
  _requestPersonalCalendarSnapshotSyncFromBloc(
    PersonalCalendarSnapshotSyncSignalKind kind,
  ) async {
    final signal = PersonalCalendarSnapshotSyncSignal(kind: kind);
    final controller = _personalCalendarSnapshotSignalController;
    if (!controller.hasListener) {
      _pendingPersonalCalendarSnapshotSignals.add(signal);
      return CalendarSnapshotPublishStatus.pending;
    }
    controller.add(signal);
    return signal.result.timeout(
      const Duration(seconds: 30),
      onTimeout: () => CalendarSnapshotPublishStatus.pending,
    );
  }

  void _flushPendingPersonalCalendarSnapshotSignals() {
    final controller = _personalCalendarSnapshotSignalController;
    while (controller.hasListener &&
        _pendingPersonalCalendarSnapshotSignals.isNotEmpty) {
      controller.add(_pendingPersonalCalendarSnapshotSignals.removeFirst());
    }
  }

  Future<String> _ensurePersonalCalendarSnapshotSourceId() async {
    await _ensurePersonalCalendarSnapshotSourceLoaded();
    final existing = _personalCalendarSnapshotSourceId?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = const Uuid().v4();
    _personalCalendarSnapshotSourceId = generated;
    await _persistPersonalCalendarSnapshotSourceId();
    return generated;
  }

  Future<void> _ensurePersonalCalendarSnapshotSourceLoaded() async {
    if (_personalCalendarSnapshotSourceLoaded ||
        !_canAccessPersonalCalendarSnapshotStateStore) {
      return;
    }
    try {
      final loaded = await _dbOpReturning<XmppStateStore, Object?>(
        (ss) => ss.read(key: _personalCalendarSnapshotSourceKey),
      );
      final normalized = _normalizePersonalCalendarSnapshotSourceId(loaded);
      if (normalized != null) {
        _personalCalendarSnapshotSourceId = normalized;
      }
      _personalCalendarSnapshotSourceLoaded = true;
    } on XmppAbortedException {
      return;
    }
  }

  bool get _canAccessPersonalCalendarSnapshotStateStore => _myJid != null;

  Future<bool> _isPersonalCalendarPubSubMigrationComplete() async {
    if (!_canAccessPersonalCalendarSnapshotStateStore) {
      return false;
    }
    try {
      final loaded = await _dbOpReturning<XmppStateStore, Object?>(
        (ss) => ss.read(key: _personalCalendarSnapshotMigrationKey),
      );
      return loaded?.toString().trim() ==
          _personalCalendarSnapshotMigrationCompleteValue;
    } on XmppAbortedException {
      return false;
    }
  }

  Future<void> _markPersonalCalendarPubSubMigrationComplete() async {
    if (!_canAccessPersonalCalendarSnapshotStateStore) {
      return;
    }
    try {
      await _dbOp<XmppStateStore>((ss) async {
        await ss.write(
          key: _personalCalendarSnapshotMigrationKey,
          value: _personalCalendarSnapshotMigrationCompleteValue,
        );
      }, awaitDatabase: true);
    } on XmppAbortedException {
      return;
    }
  }

  Future<void> _persistPersonalCalendarSnapshotSourceId() async {
    if (!_canAccessPersonalCalendarSnapshotStateStore) {
      return;
    }
    final sourceId = _personalCalendarSnapshotSourceId?.trim();
    if (sourceId == null || sourceId.isEmpty) {
      return;
    }
    try {
      await _dbOp<XmppStateStore>((ss) async {
        await ss.write(
          key: _personalCalendarSnapshotSourceKey,
          value: sourceId,
        );
      }, awaitDatabase: true);
      _personalCalendarSnapshotSourceLoaded = true;
    } on XmppAbortedException {
      return;
    }
  }

  String? _normalizePersonalCalendarSnapshotSourceId(Object? raw) {
    final normalized = raw?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return clampUtf8Value(
      normalized,
      maxBytes: calendarSnapshotPubSubSourceIdMaxBytes,
    );
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _personalCalendarSnapshotBootstrapOperationName,
        priority: 2,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.resumedNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _personalCalendarSnapshotBootstrapOperationName,
        run: () async {
          await _syncPersonalCalendarSnapshotOnBootstrap();
        },
      ),
    );
    manager
      ..registerHandler<PersonalCalendarSnapshotPubSubUpdatedEvent>((
        event,
      ) async {
        await _handlePersonalCalendarSnapshotUpdate(event.payload);
      })
      ..registerHandler<PersonalCalendarSnapshotPubSubRetractedEvent>((
        event,
      ) async {
        await _handlePersonalCalendarSnapshotRetraction(event.itemId);
      });
  }

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    CalendarSnapshotPubSubManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    calendarSnapshotNotifyFeature,
  ];

  @override
  Future<void> _reset() async {
    _personalCalendarSnapshotSourceId = null;
    _personalCalendarSnapshotSourceLoaded = false;
    _personalCalendarSnapshotPublishRequested = false;
    _personalCalendarSnapshotRefreshRequested = false;
    _personalCalendarSnapshotRequest = null;
    _personalCalendarSnapshotTask = null;
    _pendingPersonalCalendarSnapshotSignals.clear();
    await super._reset();
  }
}
