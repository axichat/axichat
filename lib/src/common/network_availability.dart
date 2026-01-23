// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

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

  static final NetworkAvailabilityService instance =
      NetworkAvailabilityService._();

  final Connectivity _connectivity;
  final StreamController<NetworkAvailability> _controller =
      StreamController<NetworkAvailability>.broadcast();

  StreamSubscription<Object?>? _subscription;
  NetworkAvailability _current = NetworkAvailability.unknown;

  NetworkAvailability get current => _current;

  Stream<NetworkAvailability> get stream => _controller.stream;

  Future<void> start() async {
    if (_subscription != null) return;
    _updateAvailability(
      await _resolveAvailability(await _connectivity.checkConnectivity()),
    );
    _subscription = _connectivity.onConnectivityChanged
        .cast<Object?>()
        .listen(_handleConnectivityChange);
  }

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> waitForAvailable({Duration? timeout}) async {
    if (_current.isAvailable) return;
    final waitFuture =
        stream.firstWhere((availability) => availability.isAvailable);
    if (timeout == null) {
      await waitFuture;
      return;
    }
    await waitFuture.timeout(timeout, onTimeout: () => _current);
  }

  Future<void> _handleConnectivityChange(Object? result) async {
    _updateAvailability(await _resolveAvailability(result));
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
