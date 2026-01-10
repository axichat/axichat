// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

class ImpatientCompleter<T> {
  ImpatientCompleter(this.completer);

  final Completer<T> completer;
  bool _hasListener = false;
  bool _hasValue = false;
  bool _hasPendingError = false;
  Object? _pendingError;
  StackTrace? _pendingStackTrace;

  Future<T> get future {
    _hasListener = true;
    _flushPendingError();
    return completer.future;
  }

  bool get isCompleted => completer.isCompleted;

  T? get value => _hasValue ? _value : null;
  late final T _value;

  void complete(T value) {
    if (isCompleted) return;
    _clearPendingError();
    completer.complete(value);
    _value = value;
    _hasValue = true;
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (isCompleted) return;
    if (!_hasListener) {
      _pendingError = error;
      _pendingStackTrace = stackTrace;
      _hasPendingError = true;
      return;
    }
    completer.completeError(error, stackTrace);
  }

  void _flushPendingError() {
    if (!_hasPendingError || isCompleted) return;
    final error = _pendingError;
    if (error == null) return;
    _clearPendingError();
    completer.completeError(error, _pendingStackTrace);
  }

  void _clearPendingError() {
    _pendingError = null;
    _pendingStackTrace = null;
    _hasPendingError = false;
  }
}
