// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:logging/logging.dart';

part 'xmpp_activity_state.dart';

class XmppActivityCubit extends Cubit<XmppActivityState> {
  XmppActivityCubit({
    required XmppBase xmppBase,
    Duration completedRetention = const Duration(seconds: 1),
    Duration failedRetention = const Duration(seconds: 1),
  }) : _xmppBase = xmppBase,
       _completedRetention = completedRetention,
       _failedRetention = failedRetention,
       super(const XmppActivityState()) {
    _subscription = _xmppBase.xmppOperationStream.listen(_handleEvent);
    _staleOperationTimer = Timer.periodic(
      _staleOperationCheckInterval,
      (_) => _reconcileStaleOperations(),
    );
  }

  static const Duration _minimumInProgressDuration = Duration(
    milliseconds: 350,
  );
  static const Duration _idleCompletionDelay = Duration(milliseconds: 300);
  static const Duration _staleOperationCheckInterval = Duration(seconds: 1);
  static const Duration _defaultOperationTimeout = Duration(minutes: 2);
  static const Duration _mamMucSyncTimeout = Duration(minutes: 10);
  static const Duration _longMamSyncTimeout = Duration(minutes: 20);

  final XmppBase _xmppBase;
  final Duration _completedRetention;
  final Duration _failedRetention;
  final Map<_XmppOperationKey, _XmppOperationBatch> _activeOperations = {};
  final Map<String, Timer> _retentionTimers = {};
  final Map<String, Timer> _completionTimers = {};
  late final StreamSubscription<XmppOperationEvent> _subscription;
  late final Timer _staleOperationTimer;

  static final _logger = Logger('XmppActivityCubit');

  void _handleEvent(XmppOperationEvent event) {
    final key = _XmppOperationKey(kind: event.kind);
    final now = DateTime.now();

    if (event.stage.isStart) {
      final operationId = _startOperation(event.kind);
      final batch = _activeOperations[key];
      if (batch == null) {
        _activeOperations[key] = _XmppOperationBatch(
          operationId: operationId,
          pendingCount: 1,
          startedAt: now,
        );
        return;
      }
      _cancelCompletion(operationId);
      if (batch.pendingCount == 0) {
        batch
          ..hadFailure = false
          ..hadSuccess = false
          ..startedAt = now;
        _refreshOperationStartTime(operationId, startedAt: now);
      }
      batch
        ..operationId = operationId
        ..pendingCount += 1;
      return;
    }

    final batch = _activeOperations[key];
    if (batch == null) {
      _logger.fine(
        'Received XMPP activity end without recorded start: ${event.kind}.',
      );
      return;
    }

    if (batch.pendingCount <= 0) {
      _logger.fine(
        'Received XMPP activity end without active count: ${event.kind}.',
      );
      return;
    }

    batch
      ..pendingCount -= 1
      ..hadSuccess = batch.hadSuccess || event.isSuccess
      ..hadFailure = batch.hadFailure || !event.isSuccess;

    if (batch.pendingCount > 0) {
      return;
    }

    _scheduleCompletion(key: key, batch: batch);
  }

  String _startOperation(XmppOperationKind kind) {
    final operations = List<XmppOperation>.of(state.operations);
    final index = operations.lastIndexWhere(
      (item) =>
          item.kind == kind && item.status == XmppOperationStatus.inProgress,
    );
    if (index != -1) {
      final existing = operations[index];
      _cancelCompletion(existing.id);
      return existing.id;
    }

    final String operationId = generateRandomString(length: 10);
    final String id = '${kind.name}-$operationId';
    final XmppOperation operation = XmppOperation(
      id: id,
      kind: kind,
      startedAt: DateTime.now(),
    );
    final updated = operations..add(operation);
    emit(state.copyWith(operations: List.unmodifiable(updated)));
    return id;
  }

  void _completeOperation(String id) {
    _updateOperation(id, status: XmppOperationStatus.success);
  }

  void _failOperation(String id) {
    _updateOperation(id, status: XmppOperationStatus.failure);
  }

  void _scheduleCompletion({
    required _XmppOperationKey key,
    required _XmppOperationBatch batch,
  }) {
    final id = batch.operationId;
    _cancelCompletion(id);
    final elapsed = DateTime.now().difference(batch.startedAt);
    final remaining = _minimumInProgressDuration - elapsed;
    final delay = remaining > _idleCompletionDelay
        ? remaining
        : _idleCompletionDelay;
    final token = batch.bumpCompletionToken();
    _completionTimers[id] = Timer(delay, () {
      _completionTimers.remove(id);
      final current = _activeOperations[key];
      if (current == null ||
          current.operationId != id ||
          current.pendingCount > 0 ||
          current.completionToken != token) {
        return;
      }
      final isSuccess = current.hadSuccess || !current.hadFailure;
      _applyCompletion(key: key, id: id, isSuccess: isSuccess);
    });
  }

  void _applyCompletion({
    required _XmppOperationKey key,
    required String id,
    required bool isSuccess,
  }) {
    if (isSuccess) {
      _completeOperation(id);
    } else {
      _failOperation(id);
    }
    _activeOperations.remove(key);
  }

  void _updateOperation(String id, {XmppOperationStatus? status}) {
    final operations = List<XmppOperation>.of(state.operations);
    final index = operations.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _cancelCompletion(id);
    final updated = operations[index].copyWith(status: status);
    operations[index] = updated;
    _scheduleTeardown(updated);
    emit(state.copyWith(operations: List.unmodifiable(operations)));
  }

  void _scheduleTeardown(XmppOperation operation) {
    if (operation.status == XmppOperationStatus.inProgress) {
      _cancelRetention(operation.id);
      return;
    }
    final retention = operation.status == XmppOperationStatus.success
        ? _completedRetention
        : _failedRetention;
    _cancelRetention(operation.id);
    _retentionTimers[operation.id] = Timer(retention, () {
      final operations = List<XmppOperation>.of(state.operations)
        ..removeWhere((item) => item.id == operation.id);
      emit(state.copyWith(operations: List.unmodifiable(operations)));
      _retentionTimers.remove(operation.id);
    });
  }

  void _cancelRetention(String id) {
    final timer = _retentionTimers.remove(id);
    timer?.cancel();
  }

  void _cancelCompletion(String id) {
    final timer = _completionTimers.remove(id);
    timer?.cancel();
  }

  void _refreshOperationStartTime(String id, {required DateTime startedAt}) {
    final operations = List<XmppOperation>.of(state.operations);
    final index = operations.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    final operation = operations[index];
    if (operation.startedAt == startedAt) {
      return;
    }
    operations[index] = operation.copyWith(startedAt: startedAt);
    emit(state.copyWith(operations: List.unmodifiable(operations)));
  }

  DateTime _startedAtForOperation(XmppOperation operation) {
    final key = _XmppOperationKey(kind: operation.kind);
    final activeBatch = _activeOperations[key];
    if (activeBatch == null || activeBatch.operationId != operation.id) {
      return operation.startedAt;
    }
    return activeBatch.startedAt;
  }

  Duration _maxDurationForOperationKind(XmppOperationKind kind) {
    return switch (kind) {
      XmppOperationKind.mamLoginSync ||
      XmppOperationKind.mamGlobalSync => _longMamSyncTimeout,
      XmppOperationKind.mamMucSync => _mamMucSyncTimeout,
      _ => _defaultOperationTimeout,
    };
  }

  void _reconcileStaleOperations() {
    final operations = state.operations;
    if (operations.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final List<String> staleIds = <String>[];
    final Map<String, XmppOperation> staleById = <String, XmppOperation>{};
    for (final operation in operations) {
      if (operation.status != XmppOperationStatus.inProgress) {
        continue;
      }
      final timeout = _maxDurationForOperationKind(operation.kind);
      final elapsed = now.difference(_startedAtForOperation(operation));
      if (elapsed <= timeout) {
        continue;
      }
      staleIds.add(operation.id);
      staleById[operation.id] = operation;
    }
    if (staleIds.isEmpty) {
      return;
    }

    for (final id in staleIds) {
      _cancelCompletion(id);
      _cancelRetention(id);
      _removeFromActiveOperationsIfCurrent(staleById[id]);
    }

    final updatedOperations = List<XmppOperation>.of(operations);
    var hasUpdates = false;
    for (var index = 0; index < updatedOperations.length; index += 1) {
      final operation = updatedOperations[index];
      if (!staleById.containsKey(operation.id)) {
        continue;
      }
      final failed = operation.copyWith(status: XmppOperationStatus.failure);
      updatedOperations[index] = failed;
      _scheduleTeardown(failed);
      hasUpdates = true;
    }
    if (hasUpdates) {
      _logger.warning(
        'Marking stale XMPP operations as failed: ${staleIds.join(', ')}.',
      );
      emit(state.copyWith(operations: List.unmodifiable(updatedOperations)));
    }
  }

  void _removeFromActiveOperationsIfCurrent(XmppOperation? operation) {
    if (operation == null) {
      return;
    }
    final key = _XmppOperationKey(kind: operation.kind);
    final current = _activeOperations[key];
    if (current == null || current.operationId != operation.id) {
      return;
    }
    _activeOperations.remove(key);
  }

  @override
  Future<void> close() async {
    _staleOperationTimer.cancel();
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    for (final timer in _retentionTimers.values) {
      timer.cancel();
    }
    _retentionTimers.clear();
    await _subscription.cancel();
    return super.close();
  }
}

class _XmppOperationKey {
  const _XmppOperationKey({required this.kind});

  final XmppOperationKind kind;

  @override
  bool operator ==(Object other) {
    return other is _XmppOperationKey && other.kind == kind;
  }

  @override
  int get hashCode => kind.hashCode;
}

class _XmppOperationBatch {
  _XmppOperationBatch({
    required this.operationId,
    required this.pendingCount,
    required this.startedAt,
  }) : hadFailure = false,
       hadSuccess = false,
       completionToken = 0;

  String operationId;
  int pendingCount;
  bool hadFailure;
  bool hadSuccess;
  DateTime startedAt;
  int completionToken;

  int bumpCompletionToken() {
    completionToken += 1;
    return completionToken;
  }
}
