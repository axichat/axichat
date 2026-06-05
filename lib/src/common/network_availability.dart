// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NetworkAvailability {
  unknown,
  available,
  unavailable;

  bool get isAvailable => this == NetworkAvailability.available;

  bool get isUnavailable => this == NetworkAvailability.unavailable;
}

class NetworkAvailabilityService {
  NetworkAvailabilityService._({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  @visibleForTesting
  NetworkAvailabilityService.forTesting({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  static final NetworkAvailabilityService instance =
      NetworkAvailabilityService._();

  final Connectivity _connectivity;
  final StreamController<NetworkAvailability> _controller =
      StreamController<NetworkAvailability>.broadcast();

  StreamSubscription<Object?>? _subscription;
  NetworkAvailability _current = NetworkAvailability.unknown;
  Future<void>? _startFuture;
  int _startRequests = 0;
  bool _connectivityPluginAvailable = true;

  NetworkAvailability get current => _current;

  Stream<NetworkAvailability> get stream => _controller.stream;

  Future<NetworkAvailability> refresh() async {
    Object? result;
    try {
      result = await _connectivity.checkConnectivity();
      _connectivityPluginAvailable = true;
    } on MissingPluginException {
      _connectivityPluginAvailable = false;
      _updateAvailability(NetworkAvailability.unknown);
      return _current;
    }
    final availability = await _resolveAvailability(result);
    _updateAvailability(availability);
    return availability;
  }

  Future<void> start() async {
    _startRequests += 1;
    if (_subscription != null) return;
    final existingStart = _startFuture;
    if (existingStart != null) {
      try {
        await existingStart;
      } on Exception {
        _releaseStartRequest();
        rethrow;
      }
      return;
    }
    late final Future<void> startFuture;
    startFuture = _startListener().whenComplete(() {
      if (identical(_startFuture, startFuture)) {
        _startFuture = null;
      }
    });
    _startFuture = startFuture;
    try {
      await startFuture;
    } on Exception {
      _releaseStartRequest();
      rethrow;
    }
  }

  Future<void> stop() async {
    _releaseStartRequest();
    if (_startRequests > 0) return;
    final startFuture = _startFuture;
    if (startFuture != null) {
      try {
        await startFuture;
      } on Exception {
        // The matching start caller reports the failure.
      }
      if (_startRequests > 0) return;
    }
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> waitForAvailable({Duration? timeout}) async {
    if (_current.isAvailable) return;
    final waitFuture = stream.firstWhere(
      (availability) => availability.isAvailable,
    );
    if (timeout == null) {
      await waitFuture;
      return;
    }
    await waitFuture.timeout(timeout, onTimeout: () => _current);
  }

  Future<void> _handleConnectivityChange(Object? result) async {
    _updateAvailability(await _resolveAvailability(result));
  }

  Future<void> _startListener() async {
    await refresh();
    if (!_connectivityPluginAvailable ||
        _startRequests <= 0 ||
        _subscription != null) {
      return;
    }
    _subscription = _connectivity.onConnectivityChanged.cast<Object?>().listen(
      _handleConnectivityChange,
      onError: _handleConnectivityError,
    );
  }

  void _handleConnectivityError(Object error, StackTrace stackTrace) {
    if (error is MissingPluginException) {
      _connectivityPluginAvailable = false;
      _updateAvailability(NetworkAvailability.unknown);
      return;
    }
    Zone.current.handleUncaughtError(error, stackTrace);
  }

  void _releaseStartRequest() {
    if (_startRequests > 0) {
      _startRequests -= 1;
    }
  }

  void _updateAvailability(NetworkAvailability availability) {
    if (_current == availability) return;
    _current = availability;
    if (_controller.isClosed) return;
    _controller.add(availability);
  }

  Future<NetworkAvailability> _resolveAvailability(Object? result) async {
    if (result is List<ConnectivityResult>) {
      if (result.isEmpty || result.contains(ConnectivityResult.none)) {
        return NetworkAvailability.unavailable;
      }
      return NetworkAvailability.available;
    }
    if (result is ConnectivityResult) {
      return result == ConnectivityResult.none
          ? NetworkAvailability.unavailable
          : NetworkAvailability.available;
    }
    return NetworkAvailability.unknown;
  }
}
