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
      Duration(milliseconds: 100);
  static const Duration _idleCompletionDelay = Duration(milliseconds: 300);

  final XmppBase _xmppBase;
  final Duration _completedRetention;
  final Duration _failedRetention;
  final Map<XmppOperationKind, List<_XmppOperationHandle>> _activeOperations =
      {};
  final Map<String, Timer> _startTimers = {};
  final Map<String, Timer> _retentionTimers = {};
  final Map<String, Timer> _completionTimers = {};
  late final StreamSubscription<XmppOperationEvent> _subscription;

  static final _logger = Logger('XmppActivityCubit');

  void _handleEvent(XmppOperationEvent event) {
    final now = DateTime.now();

    if (event.stage.isStart) {
      final handle = _createHandle(event.kind, now);
      final queue = _activeOperations.putIfAbsent(
        event.kind,
        () => <_XmppOperationHandle>[],
      );
      queue.add(handle);
      _scheduleStart(handle);
      return;
    }

    final queue = _activeOperations[event.kind];
    if (queue == null || queue.isEmpty) {
      _logger.fine(
        'Received XMPP activity end without recorded start: ${event.kind}.',
      );
      return;
    }

    final handle = queue.removeAt(0);
    if (queue.isEmpty) {
      _activeOperations.remove(event.kind);
    }
    if (_cancelPendingStartIfNeeded(handle)) {
      return;
    }
    _scheduleCompletion(handle: handle, isSuccess: event.isSuccess);
  }

  _XmppOperationHandle _createHandle(
    XmppOperationKind kind,
    DateTime startedAt,
  ) {
    final String operationId = generateRandomString(length: 10);
    final String id = '${kind.name}-$operationId';
    return _XmppOperationHandle(id: id, kind: kind, startedAt: startedAt);
  }

  void _scheduleStart(_XmppOperationHandle handle) {
    _cancelStart(handle.id);
    if (_minimumInProgressDuration == Duration.zero) {
      _showOperation(handle);
      return;
    }
    _startTimers[handle.id] = Timer(_minimumInProgressDuration, () {
      _startTimers.remove(handle.id);
      _showOperation(handle);
    });
  }

  bool _cancelPendingStartIfNeeded(_XmppOperationHandle handle) {
    final Timer? timer = _startTimers.remove(handle.id);
    if (timer == null) {
      return false;
    }
    timer.cancel();
    final elapsed = DateTime.now().difference(handle.startedAt);
    if (elapsed < _minimumInProgressDuration) {
      return true;
    }
    _showOperation(handle);
    return false;
  }

  void _showOperation(_XmppOperationHandle handle) {
    final operations = List<XmppOperation>.of(state.operations);
    if (operations.any((item) => item.id == handle.id)) {
      return;
    }
    final XmppOperation operation = XmppOperation(
      id: handle.id,
      kind: handle.kind,
      startedAt: handle.startedAt,
    );
    final updated = operations..add(operation);
    emit(state.copyWith(operations: List.unmodifiable(updated)));
  }

  void _completeOperation(String id) {
    _updateOperation(id, status: XmppOperationStatus.success);
  }

  void _failOperation(String id) {
    _updateOperation(id, status: XmppOperationStatus.failure);
  }

  void _scheduleCompletion({
    required _XmppOperationHandle handle,
    required bool isSuccess,
  }) {
    final id = handle.id;
    _cancelCompletion(id);
    final elapsed = DateTime.now().difference(handle.startedAt);
    final remaining = _minimumInProgressDuration - elapsed;
    final delay =
        remaining > _idleCompletionDelay ? remaining : _idleCompletionDelay;
    _completionTimers[id] = Timer(delay, () {
      _completionTimers.remove(id);
      _applyCompletion(id: id, isSuccess: isSuccess);
    });
  }

  void _applyCompletion({required String id, required bool isSuccess}) {
    if (isSuccess) {
      _completeOperation(id);
    } else {
      _failOperation(id);
    }
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

  void _cancelStart(String id) {
    final timer = _startTimers.remove(id);
    timer?.cancel();
  }

  @override
  Future<void> close() async {
    for (final timer in _startTimers.values) {
      timer.cancel();
    }
    _startTimers.clear();
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

class _XmppOperationHandle {
  _XmppOperationHandle({
    required this.id,
    required this.kind,
    required this.startedAt,
  });

  final String id;
  final XmppOperationKind kind;
  final DateTime startedAt;
}
