// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:logging/logging.dart';

const Duration _defaultCompletedRetention = Duration(seconds: 1);
const Duration _defaultFailedRetention = Duration(seconds: 1);
const Duration _minimumInProgressDuration = Duration(milliseconds: 100);
const Duration _idleCompletionDelay = Duration(milliseconds: 300);
const int _operationIdLength = 10;
const String _operationIdSeparator = '-';

const String _pubSubBookmarksStartMessage = 'Syncing bookmarks (PubSub)...';
const String _pubSubBookmarksSuccessMessage = 'Bookmarks synced';
const String _pubSubBookmarksFailureMessage = 'Bookmarks PubSub sync failed';

const String _pubSubConversationsStartMessage =
    'Syncing conversation index (PubSub)...';
const String _pubSubConversationsSuccessMessage = 'Conversation index synced';
const String _pubSubConversationsFailureMessage =
    'Conversation index PubSub sync failed';

const String _pubSubDraftsStartMessage = 'Syncing drafts (PubSub)...';
const String _pubSubDraftsSuccessMessage = 'Drafts synced';
const String _pubSubDraftsFailureMessage = 'Drafts PubSub sync failed';

const String _pubSubSpamStartMessage = 'Syncing spam list (PubSub)...';
const String _pubSubSpamSuccessMessage = 'Spam list synced';
const String _pubSubSpamFailureMessage = 'Spam list PubSub sync failed';

const String _pubSubEmailBlocklistStartMessage =
    'Syncing email blocklist (PubSub)...';
const String _pubSubEmailBlocklistSuccessMessage = 'Email blocklist synced';
const String _pubSubEmailBlocklistFailureMessage =
    'Email blocklist PubSub sync failed';
const String _pubSubAvatarMetadataStartMessage =
    'Syncing avatar metadata (PubSub)...';
const String _pubSubAvatarMetadataSuccessMessage = 'Avatar metadata synced';
const String _pubSubAvatarMetadataFailureMessage =
    'Avatar metadata PubSub sync failed';
const String _pubSubFetchStartMessage = 'Syncing PubSub service data...';
const String _pubSubFetchSuccessMessage = 'PubSub service data synced';
const String _pubSubFetchFailureMessage = 'PubSub service sync failed';

const String _mamLoginStartMessage = 'Syncing messages...';
const String _mamLoginSuccessMessage = 'Messages synced';
const String _mamLoginFailureMessage = 'Message sync failed';

const String _mamGlobalStartMessage = 'Syncing full history...';
const String _mamGlobalSuccessMessage = 'History synced';
const String _mamGlobalFailureMessage = 'History sync failed';

const String _mamMucStartMessage = 'Syncing room history...';
const String _mamMucSuccessMessage = 'Room history synced';
const String _mamMucFailureMessage = 'Room history sync failed';
const String _mamFetchStartMessage = 'Fetching archived messages...';
const String _mamFetchSuccessMessage = 'Archive fetched';
const String _mamFetchFailureMessage = 'Archive fetch failed';
const String _mucJoinStartMessage = 'Joining room...';
const String _mucJoinSuccessMessage = 'Room joined';
const String _mucJoinFailureMessage = 'Room join failed';

class XmppActivityCubit extends Cubit<XmppActivityState> {
  XmppActivityCubit({
    required XmppBase xmppBase,
    Duration completedRetention = _defaultCompletedRetention,
    Duration failedRetention = _defaultFailedRetention,
  })  : _xmppBase = xmppBase,
        _completedRetention = completedRetention,
        _failedRetention = failedRetention,
        super(const XmppActivityState()) {
    _subscription = _xmppBase.xmppOperationStream.listen(
      _handleEvent,
      onError: (error, stackTrace) {
        _logger.warning(
          'Error while processing XMPP activity stream.',
          error,
          stackTrace,
        );
      },
    );
  }

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
    final String operationId = generateRandomString(length: _operationIdLength);
    final String id = '${kind.name}$_operationIdSeparator$operationId';
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

class XmppActivityState {
  const XmppActivityState({this.operations = const []});

  final List<XmppOperation> operations;

  XmppActivityState copyWith({List<XmppOperation>? operations}) =>
      XmppActivityState(operations: operations ?? this.operations);
}

class XmppOperation {
  XmppOperation({
    required this.id,
    required this.kind,
    required this.startedAt,
    this.status = XmppOperationStatus.inProgress,
  });

  final String id;
  final XmppOperationKind kind;
  final DateTime startedAt;
  final XmppOperationStatus status;

  XmppOperation copyWith({
    XmppOperationStatus? status,
    DateTime? startedAt,
  }) =>
      XmppOperation(
        id: id,
        kind: kind,
        startedAt: startedAt ?? this.startedAt,
        status: status ?? this.status,
      );

  String statusLabel() => switch (status) {
        XmppOperationStatus.inProgress => kind.startLabel(),
        XmppOperationStatus.success => kind.successLabel(),
        XmppOperationStatus.failure => kind.failureLabel(),
      };
}

enum XmppOperationStatus { inProgress, success, failure }

extension XmppOperationKindLabels on XmppOperationKind {
  String startLabel() => switch (this) {
        XmppOperationKind.pubSubBookmarks => _pubSubBookmarksStartMessage,
        XmppOperationKind.pubSubConversations =>
          _pubSubConversationsStartMessage,
        XmppOperationKind.pubSubDrafts => _pubSubDraftsStartMessage,
        XmppOperationKind.pubSubSpam => _pubSubSpamStartMessage,
        XmppOperationKind.pubSubEmailBlocklist =>
          _pubSubEmailBlocklistStartMessage,
        XmppOperationKind.pubSubAvatarMetadata =>
          _pubSubAvatarMetadataStartMessage,
        XmppOperationKind.pubSubFetch => _pubSubFetchStartMessage,
        XmppOperationKind.mamLoginSync => _mamLoginStartMessage,
        XmppOperationKind.mamGlobalSync => _mamGlobalStartMessage,
        XmppOperationKind.mamMucSync => _mamMucStartMessage,
        XmppOperationKind.mamFetch => _mamFetchStartMessage,
        XmppOperationKind.mucJoin => _mucJoinStartMessage,
      };

  String successLabel() => switch (this) {
        XmppOperationKind.pubSubBookmarks => _pubSubBookmarksSuccessMessage,
        XmppOperationKind.pubSubConversations =>
          _pubSubConversationsSuccessMessage,
        XmppOperationKind.pubSubDrafts => _pubSubDraftsSuccessMessage,
        XmppOperationKind.pubSubSpam => _pubSubSpamSuccessMessage,
        XmppOperationKind.pubSubEmailBlocklist =>
          _pubSubEmailBlocklistSuccessMessage,
        XmppOperationKind.pubSubAvatarMetadata =>
          _pubSubAvatarMetadataSuccessMessage,
        XmppOperationKind.pubSubFetch => _pubSubFetchSuccessMessage,
        XmppOperationKind.mamLoginSync => _mamLoginSuccessMessage,
        XmppOperationKind.mamGlobalSync => _mamGlobalSuccessMessage,
        XmppOperationKind.mamMucSync => _mamMucSuccessMessage,
        XmppOperationKind.mamFetch => _mamFetchSuccessMessage,
        XmppOperationKind.mucJoin => _mucJoinSuccessMessage,
      };

  String failureLabel() => switch (this) {
        XmppOperationKind.pubSubBookmarks => _pubSubBookmarksFailureMessage,
        XmppOperationKind.pubSubConversations =>
          _pubSubConversationsFailureMessage,
        XmppOperationKind.pubSubDrafts => _pubSubDraftsFailureMessage,
        XmppOperationKind.pubSubSpam => _pubSubSpamFailureMessage,
        XmppOperationKind.pubSubEmailBlocklist =>
          _pubSubEmailBlocklistFailureMessage,
        XmppOperationKind.pubSubAvatarMetadata =>
          _pubSubAvatarMetadataFailureMessage,
        XmppOperationKind.pubSubFetch => _pubSubFetchFailureMessage,
        XmppOperationKind.mamLoginSync => _mamLoginFailureMessage,
        XmppOperationKind.mamGlobalSync => _mamGlobalFailureMessage,
        XmppOperationKind.mamMucSync => _mamMucFailureMessage,
        XmppOperationKind.mamFetch => _mamFetchFailureMessage,
        XmppOperationKind.mucJoin => _mucJoinFailureMessage,
      };
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
