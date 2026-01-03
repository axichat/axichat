// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class OmemoActivityCubit extends Cubit<OmemoActivityState> {
  OmemoActivityCubit({
    required XmppBase xmppBase,
    Duration completedRetention = const Duration(seconds: 2),
    Duration failedRetention = const Duration(seconds: 6),
  })  : _xmppBase = xmppBase,
        _completedRetention = completedRetention,
        _failedRetention = failedRetention,
        super(const OmemoActivityState()) {
    _subscription = _xmppBase.omemoActivityStream.listen(
      _handleEvent,
      onError: (error, stackTrace) {
        _logger.warning(
          'Error while processing OMEMO activity stream.',
          error,
          stackTrace,
        );
      },
    );
  }

  final XmppBase _xmppBase;
  final Duration _completedRetention;
  final Duration _failedRetention;
  final Map<_OmemoActivityKey, List<String>> _activeOperations = {};
  final Map<String, Timer> _retentionTimers = {};
  final Map<String, _RatchetTracker> _ratchetTrackers = {};
  late final StreamSubscription<mox.OmemoActivityEvent> _subscription;

  static final _logger = Logger('OmemoActivityCubit');

  void _handleEvent(mox.OmemoActivityEvent event) {
    _logger.fine(
      'Activity: operation=${event.operation.name} stage=${event.stage.name} '
      'jid=${event.jid ?? '-'} device=${event.deviceId ?? '-'} '
      'error=${event.error}',
    );

    if (_handlePersistRatchetEvent(event)) {
      return;
    }
    if (_handleRatchetFetchEvent(event)) {
      return;
    }
    final descriptor = _descriptorForEvent(event);
    final operationType =
        descriptor?.type ?? _defaultTypeForOperation(event.operation);

    final key = _OmemoActivityKey(
      operation: event.operation,
      jid: event.jid,
      deviceId: event.deviceId,
    );
    final target = _formatTarget(event.jid);
    final labels = _labelsForOperation(event.operation, target, event.deviceId);

    if (event.isStart) {
      final operationId = _startOperation(
        type: operationType,
        jid: event.jid,
        displayName: target,
        messageOverride:
            descriptor?.startMessage(target, event.deviceId) ?? labels.start,
      );
      _activeOperations.putIfAbsent(key, () => <String>[]).add(operationId);
      return;
    }

    final ids = _activeOperations[key];
    if (ids == null || ids.isEmpty) {
      _logger.fine(
        'Received OMEMO activity end without recorded start: ${event.operation}.',
      );
      return;
    }

    final operationId = ids.removeLast();
    if (ids.isEmpty) {
      _activeOperations.remove(key);
    }

    if (event.error != null) {
      _failOperation(
        operationId,
        message: descriptor?.failureMessage(target, event.deviceId),
        error: event.error,
        target: target,
        deviceId: event.deviceId,
      );
      return;
    }

    _completeOperation(
      operationId,
      descriptor?.successMessage(target, event.deviceId) ?? labels.success,
    );
  }

  static const _pendingGrace = Duration(milliseconds: 200);

  bool _handlePersistRatchetEvent(mox.OmemoActivityEvent event) {
    if (event.operation != mox.OmemoActivityOperation.persistRatchets) {
      return false;
    }

    // Routine encrypt/decrypt operations emit persistRatchets events without a
    // concrete device identifier. These represent steady-state ratchet saves
    // and should not surface user-facing progress state.
    if (event.deviceId == null) {
      _logger.finest(
        'Ignoring persistRatchet with no device id for '
        '${event.jid ?? '(self)'}',
      );
      return true;
    }

    final key = _ratchetDeviceKey(event.jid, event.deviceId);
    final target = _formatTarget(event.jid ?? _xmppBase.myJid);
    final labels = _labelsForOperation(
      mox.OmemoActivityOperation.persistRatchets,
      target,
      event.deviceId,
    );

    if (event.stage == mox.OmemoActivityStage.start) {
      final tracker = _ensureRatchetTracker(
        key: key,
        createType: OmemoOperationType.buildingRatchet,
        jid: event.jid,
        target: target,
        message: labels.start,
      );
      tracker.cancelDeferredCompletion();
      tracker.sawPersistPhase = true;
      tracker.persistCount++;
      _updateOperation(
        tracker.operationId,
        status: OmemoOperationStatus.inProgress,
        messageOverride: labels.start,
      );
      return true;
    }

    if (event.stage != mox.OmemoActivityStage.end) {
      return true;
    }

    _logger.finest(
      'persistRatchet end: jid=${event.jid ?? '(self)'} '
      'device=${event.deviceId ?? 'n/a'}',
    );

    final tracker = _ratchetTrackers[key];
    if (tracker == null) {
      _logger.warning(
        'persistRatchet end without matching start: '
        'jid=${event.jid ?? '(self)'} device=${event.deviceId ?? 'n/a'}',
      );
      return false;
    }

    tracker.cancelDeferredCompletion();

    if (tracker.persistCount > 0) {
      tracker.persistCount--;
    }

    if (event.error != null) {
      _failOperation(
        tracker.operationId,
        error: event.error,
        target: target,
        deviceId: event.deviceId,
      );
      _ratchetTrackers.remove(key);
    } else {
      if (tracker.fetchCount == 0 && tracker.persistCount == 0) {
        _completeOperation(tracker.operationId, labels.success);
        _ratchetTrackers.remove(key);
      } else {
        _updateOperation(
          tracker.operationId,
          status: OmemoOperationStatus.inProgress,
          messageOverride: labels.start,
        );
      }
    }

    return true;
  }

  bool _handleRatchetFetchEvent(mox.OmemoActivityEvent event) {
    if (event.operation != mox.OmemoActivityOperation.fetchDeviceBundle) {
      return false;
    }
    final key = _ratchetDeviceKey(event.jid, event.deviceId);
    final target = _formatTarget(event.jid ?? _xmppBase.myJid);
    final fetchLabels = _labelsForOperation(
      event.operation,
      target,
      event.deviceId,
    );
    final persistLabels = _labelsForOperation(
      mox.OmemoActivityOperation.persistRatchets,
      target,
      event.deviceId,
    );

    if (event.stage == mox.OmemoActivityStage.start) {
      final tracker = _ensureRatchetTracker(
        key: key,
        createType: OmemoOperationType.buildingRatchet,
        jid: event.jid,
        target: target,
        message: fetchLabels.start,
      );
      tracker.cancelDeferredCompletion();
      tracker.fetchCount++;
      _updateOperation(
        tracker.operationId,
        status: OmemoOperationStatus.inProgress,
        messageOverride: fetchLabels.start,
      );
      return true;
    }

    if (event.stage != mox.OmemoActivityStage.end) {
      return true;
    }

    final tracker = _ratchetTrackers[key];
    if (tracker == null) {
      _logger.warning(
        'ratchet fetch end without matching start: '
        'jid=${event.jid ?? '(self)'} device=${event.deviceId ?? 'n/a'}',
      );
      return false;
    }

    tracker.cancelDeferredCompletion();

    if (tracker.fetchCount > 0) {
      tracker.fetchCount--;
    }

    if (event.error != null) {
      _failOperation(
        tracker.operationId,
        error: event.error,
        target: target,
        deviceId: event.deviceId,
      );
      _ratchetTrackers.remove(key);
    } else {
      if (!tracker.sawPersistPhase && tracker.fetchCount == 0) {
        tracker.deferredCompletion = Timer(_pendingGrace, () {
          if (!_ratchetTrackers.containsKey(key)) return;
          if (tracker.fetchCount == 0 && tracker.persistCount == 0) {
            _completeOperation(tracker.operationId, fetchLabels.success);
            _ratchetTrackers.remove(key);
          }
        });
      }
      _updateOperation(
        tracker.operationId,
        status: OmemoOperationStatus.inProgress,
        messageOverride: persistLabels.start,
      );
    }

    return true;
  }

  String _startOperation({
    required OmemoOperationType type,
    String? jid,
    String? displayName,
    String? messageOverride,
  }) {
    final id = '${type.name}-${DateTime.now().microsecondsSinceEpoch}';
    final operation = OmemoOperation(
      id: id,
      type: type,
      startedAt: DateTime.now(),
      jid: jid,
      displayName: displayName,
      messageOverride: messageOverride,
    );
    final updated = List<OmemoOperation>.of(state.operations)..add(operation);
    emit(state.copyWith(operations: List.unmodifiable(updated)));
    return id;
  }

  void _completeOperation(String id, String? messageOverride) {
    _updateOperation(
      id,
      status: OmemoOperationStatus.success,
      messageOverride: messageOverride,
    );
  }

  void _failOperation(
    String id, {
    String? message,
    Object? error,
    String? target,
    int? deviceId,
  }) {
    final rawError = error?.toString();
    final friendlyError = _friendlyErrorMessage(
      error,
      target: target,
      deviceId: deviceId,
    );
    final resolvedMessage =
        message ?? friendlyError ?? 'Operation failed${_forTarget(target)}';
    final detailError = (rawError != null && rawError != resolvedMessage)
        ? rawError.startsWith('Instance of ')
            ? null
            : rawError
        : null;
    _updateOperation(
      id,
      status: OmemoOperationStatus.failure,
      messageOverride: resolvedMessage,
      error: detailError ?? friendlyError,
    );
  }

  void _updateOperation(
    String id, {
    OmemoOperationStatus? status,
    String? messageOverride,
    String? error,
  }) {
    final operations = List<OmemoOperation>.of(state.operations);
    final index = operations.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final updated = operations[index].copyWith(
      status: status,
      messageOverride: messageOverride,
      error: error,
    );
    operations[index] = updated;
    _scheduleTeardown(updated);
    emit(state.copyWith(operations: List.unmodifiable(operations)));
  }

  String? get _selfBareJidOrNull {
    final jid = _xmppBase.myJid;
    if (jid == null || jid.isEmpty) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } catch (_) {
      return jid;
    }
  }

  static const _selfSentinel = '__self__';

  String _normalizedRatchetJid(String? jid) {
    final selfBare = _selfBareJidOrNull;
    if (jid == null) return _selfSentinel;
    try {
      final bare = mox.JID.fromString(jid).toBare().toString();
      if (selfBare != null && bare == selfBare) {
        return _selfSentinel;
      }
      return bare;
    } catch (_) {
      if (selfBare != null && jid == selfBare) {
        return _selfSentinel;
      }
      return jid;
    }
  }

  String _ratchetDeviceKey(String? jid, int? deviceId) =>
      '${_normalizedRatchetJid(jid)}:${deviceId ?? -1}';

  _RatchetTracker _ensureRatchetTracker({
    required String key,
    required OmemoOperationType createType,
    required String? jid,
    required String? target,
    required String? message,
  }) {
    final existing = _ratchetTrackers[key];
    if (existing != null) {
      return existing;
    }

    final id = _startOperation(
      type: createType,
      jid: jid ?? _selfBareJidOrNull,
      displayName: target,
      messageOverride: message,
    );
    final tracker = _RatchetTracker(operationId: id);
    _ratchetTrackers[key] = tracker;
    return tracker;
  }

  void _scheduleTeardown(OmemoOperation operation) {
    if (operation.status == OmemoOperationStatus.inProgress) {
      _cancelRetention(operation.id);
      return;
    }
    final retention = operation.status == OmemoOperationStatus.success
        ? _completedRetention
        : _failedRetention;
    _cancelRetention(operation.id);
    _retentionTimers[operation.id] = Timer(retention, () {
      final operations = List<OmemoOperation>.of(state.operations)
        ..removeWhere((item) => item.id == operation.id);
      emit(state.copyWith(operations: List.unmodifiable(operations)));
      _retentionTimers.remove(operation.id);
    });
  }

  void _cancelRetention(String id) {
    final timer = _retentionTimers.remove(id);
    timer?.cancel();
  }

  static _OmemoOperationDescriptor? _descriptorForEvent(
    mox.OmemoActivityEvent event,
  ) {
    switch (event.operation) {
      case mox.OmemoActivityOperation.initializeRuntime:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.initializing,
          successMessageBuilder: (_, __) => 'Encryption ready',
          failureMessageBuilder: (_, __) => 'Initialization failed',
        );
      case mox.OmemoActivityOperation.generateDevice:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.publishingDevice,
          startMessageBuilder: (_, __) => 'Generating encryption keys...',
          successMessageBuilder: (_, __) => 'Generated encryption keys',
          failureMessageBuilder: (_, __) => 'Key generation failed',
        );
      case mox.OmemoActivityOperation.publishDeviceBundle:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.publishingDevice,
          startMessageBuilder: (_, __) => 'Publishing encryption keys...',
          successMessageBuilder: (_, __) => 'Encryption keys published',
          failureMessageBuilder: (_, __) => 'Failed to publish encryption keys',
        );
      case mox.OmemoActivityOperation.regenerateDevice:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.publishingDevice,
          startMessageBuilder: (_, __) => 'Regenerating encryption device...',
          successMessageBuilder: (_, __) => 'Encryption device regenerated',
          failureMessageBuilder: (_, __) => 'Device regeneration failed',
        );
      case mox.OmemoActivityOperation.fetchDeviceList:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.refreshingDeviceList,
          startMessageBuilder: (target, __) =>
              'Fetching device list${_forTarget(target)}...',
          successMessageBuilder: (target, __) =>
              'Device list updated${_forTarget(target)}',
          failureMessageBuilder: (target, __) =>
              'Failed to fetch device list${_forTarget(target)}',
        );
      case mox.OmemoActivityOperation.fetchBundlesBatch:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.refreshingDeviceList,
          startMessageBuilder: (target, __) =>
              'Fetching device bundles${_forTarget(target)}...',
          successMessageBuilder: (target, __) =>
              'Device bundles refreshed${_forTarget(target)}',
          failureMessageBuilder: (target, __) =>
              'Failed to fetch device bundles${_forTarget(target)}',
        );
      case mox.OmemoActivityOperation.fetchDeviceBundle:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.refreshingDeviceList,
          startMessageBuilder: (target, device) =>
              'Fetching device bundle${_forDevice(target, device)}...',
          successMessageBuilder: (target, device) =>
              'Device bundle ready${_forDevice(target, device)}',
          failureMessageBuilder: (target, device) =>
              'Failed to fetch device bundle${_forDevice(target, device)}',
        );
      case mox.OmemoActivityOperation.retrieveAllBundles:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.refreshingDeviceList,
          startMessageBuilder: (_, __) => 'Loading cached device bundles...',
          successMessageBuilder: (_, __) => 'Device bundles loaded',
          failureMessageBuilder: (_, __) =>
              'Failed to load cached device bundles',
        );
      case mox.OmemoActivityOperation.persistRatchets:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.buildingRatchet,
          startMessageBuilder: (target, __) =>
              'Building ratchets${_forTarget(target)}...',
          successMessageBuilder: (target, __) =>
              'Ratchets ready${_forTarget(target)}',
          failureMessageBuilder: (target, __) =>
              'Failed to build ratchets${_forTarget(target)}',
        );
      case mox.OmemoActivityOperation.removeRatchets:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.buildingRatchet,
          startMessageBuilder: (target, __) =>
              'Removing secure session data${_forTarget(target)}...',
          successMessageBuilder: (target, __) =>
              'Secure session removed${_forTarget(target)}',
          failureMessageBuilder: (target, __) =>
              'Failed to remove secure session${_forTarget(target)}',
        );
      case mox.OmemoActivityOperation.resetSession:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.buildingRatchet,
          startMessageBuilder: (target, device) =>
              'Resetting secure session${_forDevice(target, device)}...',
          successMessageBuilder: (target, device) =>
              'Secure session reset${_forDevice(target, device)}',
          failureMessageBuilder: (target, device) =>
              'Failed to reset secure session${_forDevice(target, device)}',
        );
      case mox.OmemoActivityOperation.resetAllSessions:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.buildingRatchet,
          startMessageBuilder: (target, __) =>
              'Resetting secure sessions${_forTarget(target)}...',
          successMessageBuilder: (target, __) =>
              'Secure sessions reset${_forTarget(target)}',
          failureMessageBuilder: (target, __) =>
              'Failed to reset secure sessions${_forTarget(target)}',
        );
      case mox.OmemoActivityOperation.sendEmptyMessage:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.buildingRatchet,
          startMessageBuilder: (target, __) =>
              'Finalizing secure session${_forTarget(target)}...',
          successMessageBuilder: (target, __) =>
              'Secure session finalized${_forTarget(target)}',
          failureMessageBuilder: (target, __) =>
              'Failed to finalize secure session${_forTarget(target)}',
        );
      case mox.OmemoActivityOperation.rotatePreKeys:
        return _OmemoOperationDescriptor(
          type: OmemoOperationType.rotatingPreKeys,
          startMessageBuilder: (_, __) => 'Rotating pre-keys...',
          successMessageBuilder: (_, __) => 'Pre-keys rotated',
          failureMessageBuilder: (_, __) => 'Failed to rotate pre-keys',
        );
    }
  }

  static OmemoOperationType _defaultTypeForOperation(
    mox.OmemoActivityOperation operation,
  ) {
    return switch (operation) {
      mox.OmemoActivityOperation.initializeRuntime =>
        OmemoOperationType.initializing,
      mox.OmemoActivityOperation.rotatePreKeys =>
        OmemoOperationType.rotatingPreKeys,
      mox.OmemoActivityOperation.generateDevice ||
      mox.OmemoActivityOperation.publishDeviceBundle ||
      mox.OmemoActivityOperation.regenerateDevice =>
        OmemoOperationType.publishingDevice,
      mox.OmemoActivityOperation.fetchDeviceList ||
      mox.OmemoActivityOperation.fetchBundlesBatch ||
      mox.OmemoActivityOperation.fetchDeviceBundle ||
      mox.OmemoActivityOperation.retrieveAllBundles =>
        OmemoOperationType.refreshingDeviceList,
      _ => OmemoOperationType.buildingRatchet,
    };
  }

  static _OperationLabels _labelsForOperation(
    mox.OmemoActivityOperation operation,
    String? target,
    int? deviceId,
  ) {
    switch (operation) {
      case mox.OmemoActivityOperation.persistRatchets:
        return _OperationLabels(
          start:
              'Building ratchets${_forDevice(target, deviceId).isNotEmpty ? _forDevice(target, deviceId) : _forTarget(target)}...',
          success:
              'Ratchets ready${_forDevice(target, deviceId).isNotEmpty ? _forDevice(target, deviceId) : _forTarget(target)}',
        );
      default:
        final name = _humanizeOperation(operation);
        final context = _forDevice(target, deviceId).isNotEmpty
            ? _forDevice(target, deviceId)
            : _forTarget(target);
        return _OperationLabels(
          start: '$name$context...',
          success: '$name complete$context',
        );
    }
  }

  static String _humanizeOperation(mox.OmemoActivityOperation operation) {
    final raw = operation.name;
    final withSpaces = raw.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return withSpaces.trim().toLowerCase();
  }

  static String? _formatTarget(String? jid) {
    if (jid == null) return null;
    try {
      return mox.JID.fromString(jid).toBare().toString();
    } catch (_) {
      return jid;
    }
  }

  static String _forTarget(String? target) {
    if (target == null || target.isEmpty) return '';
    return ' for $target';
  }

  static String _forDevice(String? target, int? deviceId) {
    final label = switch ((target, deviceId)) {
      (_, null) => target,
      (null, final id?) => 'device #$id',
      (final contact?, final id?) => '$contact (device #$id)',
    };
    if (label == null || label.isEmpty) return '';
    return ' for $label';
  }

  String? _friendlyErrorMessage(
    Object? error, {
    String? target,
    int? deviceId,
  }) {
    if (error == null) return null;

    final suffix =
        deviceId != null ? _forDevice(target, deviceId) : _forTarget(target);

    switch (error) {
      case mox.UnknownOmemoError():
        return 'Encryption metadata was unavailable$suffix. Retrying shortly.';
      case mox.BundleFetchError(:final reason):
        return 'Could not fetch encryption bundle$suffix: $reason';
      case mox.PreKeyExhaustedError(:final deviceId):
        return 'Device #$deviceId is out of pre-keys. Wait a moment and try again.';
      case mox.DeviceNotFoundError(:final deviceId):
        return 'Device #$deviceId is no longer registered${_forTarget(target)}.';
      case mox.UnknownDeviceError(:final deviceId):
        return 'Device #$deviceId is no longer recognized${_forTarget(target)}.';
      case mox.SessionBrokenError(:final jid, :final deviceId):
        return 'Secure session needs to be rebuilt${_forDevice(jid, deviceId)}.';
      case mox.UnknownOnetimePrekeyReceivedError(:final jid, :final deviceId):
        return 'One-time key was stale${_forDevice(jid, deviceId)}. Re-establishing the session.';
      case mox.DeviceDeletionError(:final message):
        return 'Failed to remove device$suffix: $message';
      default:
        return error.toString();
    }
  }

  @override
  Future<void> close() async {
    for (final timer in _retentionTimers.values) {
      timer.cancel();
    }
    _retentionTimers.clear();
    await _subscription.cancel();
    return super.close();
  }
}

class _OperationLabels {
  const _OperationLabels({required this.start, required this.success});

  final String start;
  final String success;
}

class OmemoActivityState {
  const OmemoActivityState({this.operations = const []});

  final List<OmemoOperation> operations;

  OmemoActivityState copyWith({List<OmemoOperation>? operations}) =>
      OmemoActivityState(operations: operations ?? this.operations);
}

class OmemoOperation {
  OmemoOperation({
    required this.id,
    required this.type,
    required this.startedAt,
    this.jid,
    this.displayName,
    this.status = OmemoOperationStatus.inProgress,
    this.messageOverride,
    this.error,
  });

  final String id;
  final OmemoOperationType type;
  final DateTime startedAt;
  final String? jid;
  final String? displayName;
  final OmemoOperationStatus status;
  final String? messageOverride;
  final String? error;

  static final OmemoOperation empty = OmemoOperation._empty();

  OmemoOperation._empty()
      : this(
          id: '__empty__',
          type: OmemoOperationType.initializing,
          startedAt: DateTime.fromMillisecondsSinceEpoch(0),
        );

  bool get isEmpty => identical(this, empty);

  OmemoOperation copyWith({
    OmemoOperationStatus? status,
    String? messageOverride,
    String? error,
  }) =>
      OmemoOperation(
        id: id,
        type: type,
        startedAt: startedAt,
        jid: jid,
        displayName: displayName,
        status: status ?? this.status,
        messageOverride: messageOverride ?? this.messageOverride,
        error: error ?? this.error,
      );

  String get description =>
      messageOverride ??
      switch (type) {
        OmemoOperationType.initializing =>
          'Initializing encryption services...',
        OmemoOperationType.publishingDevice =>
          'Updating encryption keys${_targetSuffix()}...',
        OmemoOperationType.refreshingDeviceList =>
          'Refreshing encryption keys${_targetSuffix()}...',
        OmemoOperationType.buildingRatchet =>
          'Building ratchets${_targetSuffix()}...',
        OmemoOperationType.rotatingPreKeys =>
          'Rotating pre-keys${_targetSuffix()}...',
      };

  String statusLabel() => switch (status) {
        OmemoOperationStatus.inProgress => description,
        OmemoOperationStatus.success =>
          messageOverride ?? 'Done${_targetSuffix(includeOn: false)}',
        OmemoOperationStatus.failure =>
          messageOverride ?? 'Failed${_targetSuffix(includeOn: false)}',
      };

  String _targetSuffix({bool includeOn = true}) {
    final target = displayName ?? jid;
    if (target == null || target.isEmpty) return '';
    return includeOn ? ' for $target' : ' for $target';
  }
}

enum OmemoOperationType {
  initializing,
  publishingDevice,
  refreshingDeviceList,
  buildingRatchet,
  rotatingPreKeys,
}

enum OmemoOperationStatus {
  inProgress,
  success,
  failure,
}

typedef _MessageBuilder = String? Function(String? target, int? deviceId);

class _OmemoOperationDescriptor {
  const _OmemoOperationDescriptor({
    required this.type,
    this.startMessageBuilder,
    this.successMessageBuilder,
    this.failureMessageBuilder,
  });

  final OmemoOperationType type;
  final _MessageBuilder? startMessageBuilder;
  final _MessageBuilder? successMessageBuilder;
  final _MessageBuilder? failureMessageBuilder;

  String? startMessage(String? target, int? deviceId) =>
      startMessageBuilder?.call(target, deviceId);

  String? successMessage(String? target, int? deviceId) =>
      successMessageBuilder?.call(target, deviceId);

  String? failureMessage(String? target, int? deviceId) =>
      failureMessageBuilder?.call(target, deviceId);
}

class _OmemoActivityKey {
  const _OmemoActivityKey({
    required this.operation,
    required this.jid,
    required this.deviceId,
  });

  final mox.OmemoActivityOperation operation;
  final String? jid;
  final int? deviceId;

  @override
  bool operator ==(Object other) {
    return other is _OmemoActivityKey &&
        other.operation == operation &&
        other.jid == jid &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(operation, jid, deviceId);
}

class _RatchetTracker {
  _RatchetTracker({required this.operationId});

  final String operationId;
  int fetchCount = 0;
  int persistCount = 0;
  bool sawPersistPhase = false;
  Timer? deferredCompletion;

  void cancelDeferredCompletion() {
    deferredCompletion?.cancel();
    deferredCompletion = null;
  }
}
