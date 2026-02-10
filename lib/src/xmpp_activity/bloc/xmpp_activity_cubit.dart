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
  })  : _xmppBase = xmppBase,
        _completedRetention = completedRetention,
        _failedRetention = failedRetention,
        super(const XmppActivityState()) {
    _subscription = _xmppBase.xmppOperationStream.listen(_handleEvent);
  }

  static const Duration _minimumInProgressDuration =
      Duration(milliseconds: 350);
  static const Duration _idleCompletionDelay = Duration(milliseconds: 300);

  final XmppBase _xmppBase;
  final Duration _completedRetention;
  final Duration _failedRetention;
  final Map<_XmppOperationKey, _XmppOperationBatch> _activeOperations = {};
  final Map<String, Timer> _retentionTimers = {};
  final Map<String, Timer> _completionTimers = {};
  late final StreamSubscription<XmppOperationEvent> _subscription;

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
          ..hadSuccess = false;
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
    final delay =
        remaining > _idleCompletionDelay ? remaining : _idleCompletionDelay;
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
    final updated = operations[index].copyWith(
      status: status,
    );
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

  @override
  Future<void> close() async {
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
  })  : hadFailure = false,
        hadSuccess = false,
        completionToken = 0;

  String operationId;
  int pendingCount;
  bool hadFailure;
  bool hadSuccess;
  final DateTime startedAt;
  int completionToken;

  int bumpCompletionToken() {
    completionToken += 1;
    return completionToken;
  }
}
