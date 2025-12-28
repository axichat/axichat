import 'dart:collection';

final class SyncRateLimit {
  const SyncRateLimit({
    required this.maxEvents,
    required this.window,
    required this.refreshCooldown,
  });

  final int maxEvents;
  final Duration window;
  final Duration refreshCooldown;
}

const Duration _syncRateWindow = Duration(minutes: 1);
const Duration _syncRefreshCooldown = Duration(seconds: 10);
const int _draftSyncMaxEventsPerWindow = 120;
const int _spamSyncMaxEventsPerWindow = 120;
const int _emailBlocklistSyncMaxEventsPerWindow = 120;
const int _conversationIndexSyncMaxEventsPerWindow = 240;
const int _pinSyncMaxEventsPerWindow = 240;

const SyncRateLimit draftSyncRateLimit = SyncRateLimit(
  maxEvents: _draftSyncMaxEventsPerWindow,
  window: _syncRateWindow,
  refreshCooldown: _syncRefreshCooldown,
);
const SyncRateLimit spamSyncRateLimit = SyncRateLimit(
  maxEvents: _spamSyncMaxEventsPerWindow,
  window: _syncRateWindow,
  refreshCooldown: _syncRefreshCooldown,
);
const SyncRateLimit emailBlocklistSyncRateLimit = SyncRateLimit(
  maxEvents: _emailBlocklistSyncMaxEventsPerWindow,
  window: _syncRateWindow,
  refreshCooldown: _syncRefreshCooldown,
);
const SyncRateLimit conversationIndexSyncRateLimit = SyncRateLimit(
  maxEvents: _conversationIndexSyncMaxEventsPerWindow,
  window: _syncRateWindow,
  refreshCooldown: _syncRefreshCooldown,
);
const SyncRateLimit pinSyncRateLimit = SyncRateLimit(
  maxEvents: _pinSyncMaxEventsPerWindow,
  window: _syncRateWindow,
  refreshCooldown: _syncRefreshCooldown,
);

final class SyncRateLimiter {
  SyncRateLimiter(this.limit);

  final SyncRateLimit limit;
  final Queue<int> _events = Queue<int>();
  int? _lastRefreshMs;

  bool allowEvent() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _prune(nowMs);
    if (_events.length >= limit.maxEvents) {
      return false;
    }
    _events.addLast(nowMs);
    return true;
  }

  bool shouldRefreshNow() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastRefresh = _lastRefreshMs;
    if (lastRefresh != null &&
        nowMs - lastRefresh < limit.refreshCooldown.inMilliseconds) {
      return false;
    }
    _lastRefreshMs = nowMs;
    return true;
  }

  void _prune(int nowMs) {
    final cutoff = nowMs - limit.window.inMilliseconds;
    while (_events.isNotEmpty && _events.first < cutoff) {
      _events.removeFirst();
    }
  }
}
