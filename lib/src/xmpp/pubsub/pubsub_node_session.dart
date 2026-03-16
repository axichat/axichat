// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

final class PubSubNodeSession {
  DateTime? _lastEnsureAttempt;
  bool _ensureInFlight = false;
  bool _ensurePending = false;
  bool _nodeReady = false;
  bool _subscriptionReady = false;
  Completer<void>? _ensureCompleter;
  Completer<void>? _subscribeCompleter;

  bool get nodeReady => _nodeReady;
  bool get subscriptionReady => _subscriptionReady;
  bool get ensureInFlight => _ensureInFlight;
  Future<void>? get activeEnsure => _ensureCompleter?.future;
  Future<void>? get activeSubscribe => _subscribeCompleter?.future;

  bool shouldAttemptEnsure(Duration backoff) {
    if (_ensureInFlight || _nodeReady) {
      return false;
    }
    final lastAttempt = _lastEnsureAttempt;
    if (lastAttempt == null) {
      return true;
    }
    return DateTime.timestamp().difference(lastAttempt) >= backoff;
  }

  Completer<void> beginEnsure() {
    final completer = Completer<void>();
    _ensureCompleter = completer;
    _ensureInFlight = true;
    _lastEnsureAttempt = DateTime.timestamp();
    return completer;
  }

  void completeEnsure(Completer<void> completer) {
    _ensureInFlight = false;
    _ensureCompleter = null;
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  bool takePendingRetry() {
    final shouldRetry = _ensurePending && !_nodeReady;
    _ensurePending = false;
    return shouldRetry;
  }

  Completer<void> beginSubscribe() {
    final completer = Completer<void>();
    _subscribeCompleter = completer;
    return completer;
  }

  void finishSubscribe(Completer<void> completer) {
    _subscribeCompleter = null;
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void markNodeReady() {
    _nodeReady = true;
  }

  void markSubscriptionReady() {
    _subscriptionReady = true;
  }

  void markSubscriptionStale() {
    _subscriptionReady = false;
  }

  void resetForNodeRebuild() {
    _nodeReady = false;
    _subscriptionReady = false;
    _lastEnsureAttempt = null;
    _ensurePending = true;
  }
}
