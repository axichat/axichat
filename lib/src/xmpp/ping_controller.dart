// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

enum XmppPingExpectation {
  none,
  responseExpected;

  bool get expectsResponse => this == XmppPingExpectation.responseExpected;
}

final class XmppKeepAliveManager extends mox.XmppManagerBase {
  XmppKeepAliveManager() : super(managerId);

  static const String managerId = 'axi.keepalive';

  @override
  Future<bool> isSupported() async => true;

  XmppPingExpectation sendPing() {
    final attrs = getAttributes();
    final socket = attrs.getSocket();

    if (socket.managesKeepalives()) {
      logger.finest('Not sending ping as the socket manages it.');
      return XmppPingExpectation.none;
    }

    final stream = attrs.getManagerById<mox.StreamManagementManager>(
      mox.smManager,
    );
    if (stream != null && stream.isStreamManagementEnabled()) {
      logger.finest('Sending an ack ping as Stream Management is enabled');
      stream.sendAckRequestPing();
      return XmppPingExpectation.responseExpected;
    }

    if (socket.whitespacePingAllowed()) {
      logger.finest(
        'Sending a whitespace ping as Stream Management is not enabled',
      );
      attrs.getConnection().sendWhitespacePing();
      return XmppPingExpectation.none;
    }

    logger.warning(
      'Cannot send keepalives as SM is not available, the socket disallows whitespace pings and does not manage its own keepalives. Cannot guarantee that the connection survives.',
    );
    return XmppPingExpectation.none;
  }
}

final class XmppPingController {
  XmppPingController({required XmppService owner}) : _owner = owner;

  static const Duration _idlePingInterval = Duration(minutes: 2);
  static const Duration _minIdleDelay = Duration(seconds: 10);
  static const Duration _pingTimeout = Duration(seconds: 20);

  final XmppService _owner;

  Timer? _idleTimer;
  Timer? _pingTimeoutTimer;
  DateTime? _lastPingSentAt;

  void handleConnectionState(ConnectionState state) {
    if (state == ConnectionState.connected) {
      _scheduleIdleCheck();
      return;
    }
    stop();
  }

  void stop() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _pingTimeoutTimer?.cancel();
    _pingTimeoutTimer = null;
    _lastPingSentAt = null;
  }

  XmppTrafficTracker? _trafficTracker() {
    final wrapper = _owner._connection.socketWrapper;
    if (wrapper case final XmppTrafficTracker tracker) {
      return tracker;
    }
    return null;
  }

  void _scheduleIdleCheck() {
    _idleTimer?.cancel();
    if (_owner.connectionState != ConnectionState.connected) {
      return;
    }
    final delay = _nextIdleDelay();
    if (delay == Duration.zero) {
      _handleIdleCheck();
      return;
    }
    _idleTimer = Timer(delay, _handleIdleCheck);
  }

  Duration _nextIdleDelay() {
    final now = DateTime.timestamp();
    final tracker = _trafficTracker();
    final lastTraffic = _latestTraffic(
      tracker?.lastIncomingAt,
      tracker?.lastOutgoingAt,
      _lastPingSentAt,
    );
    if (lastTraffic == null) {
      return _idlePingInterval;
    }
    final elapsed = now.difference(lastTraffic);
    final remaining = _idlePingInterval - elapsed;
    if (remaining <= Duration.zero) {
      return Duration.zero;
    }
    if (remaining < _minIdleDelay) {
      return _minIdleDelay;
    }
    return remaining;
  }

  DateTime? _latestTraffic(
    DateTime? incoming,
    DateTime? outgoing,
    DateTime? pingSentAt,
  ) {
    if (incoming == null) {
      if (outgoing == null) {
        return pingSentAt;
      }
      if (pingSentAt == null) {
        return outgoing;
      }
      return outgoing.isAfter(pingSentAt) ? outgoing : pingSentAt;
    }
    if (outgoing == null) {
      if (pingSentAt == null) {
        return incoming;
      }
      return incoming.isAfter(pingSentAt) ? incoming : pingSentAt;
    }
    final candidate = incoming.isAfter(outgoing) ? incoming : outgoing;
    if (pingSentAt == null) {
      return candidate;
    }
    return candidate.isAfter(pingSentAt) ? candidate : pingSentAt;
  }

  void _handleIdleCheck() {
    _idleTimer = null;
    if (_owner.connectionState != ConnectionState.connected) {
      return;
    }
    final now = DateTime.timestamp();
    final tracker = _trafficTracker();
    final lastTraffic = _latestTraffic(
      tracker?.lastIncomingAt,
      tracker?.lastOutgoingAt,
      _lastPingSentAt,
    );
    if (lastTraffic != null &&
        now.difference(lastTraffic) < _idlePingInterval) {
      _scheduleIdleCheck();
      return;
    }
    _sendPing();
  }

  void _sendPing() {
    final manager = _owner._connection.getManager<XmppKeepAliveManager>();
    if (manager == null) {
      _scheduleIdleCheck();
      return;
    }
    final expectation = manager.sendPing();
    _lastPingSentAt = DateTime.timestamp();
    if (expectation.expectsResponse) {
      _schedulePingTimeout();
    } else {
      _pingTimeoutTimer?.cancel();
      _pingTimeoutTimer = null;
    }
    _scheduleIdleCheck();
  }

  void _schedulePingTimeout() {
    _pingTimeoutTimer?.cancel();
    final sentAt = _lastPingSentAt;
    if (sentAt == null) {
      return;
    }
    _pingTimeoutTimer = Timer(_pingTimeout, () {
      _pingTimeoutTimer = null;
      if (_owner.connectionState != ConnectionState.connected) {
        return;
      }
      final tracker = _trafficTracker();
      final lastIncoming = tracker?.lastIncomingAt;
      if (lastIncoming != null && lastIncoming.isAfter(sentAt)) {
        return;
      }
      fireAndForget(
        () => _owner.requestReconnect(ReconnectTrigger.autoFailure),
        operationName: 'XmppService.pingTimeoutReconnect',
      );
    });
  }
}
