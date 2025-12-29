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

final class WindowRateLimit {
  const WindowRateLimit({
    required this.maxEvents,
    required this.window,
  });

  final int maxEvents;
  final Duration window;
}

final class WindowRateLimiter {
  WindowRateLimiter(this.limit);

  final WindowRateLimit limit;
  final Queue<int> _events = Queue<int>();

  bool allowEvent({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _prune(now);
    if (_events.length >= limit.maxEvents) {
      return false;
    }
    _events.addLast(now);
    return true;
  }

  int prune({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _prune(now);
    return _events.length;
  }

  void reset() => _events.clear();

  void _prune(int nowMs) {
    final cutoff = nowMs - limit.window.inMilliseconds;
    while (_events.isNotEmpty && _events.first < cutoff) {
      _events.removeFirst();
    }
  }
}

final class KeyedWindowRateLimiter {
  KeyedWindowRateLimiter({
    required this.limit,
    required this.cleanupInterval,
  });

  final WindowRateLimit limit;
  final Duration cleanupInterval;
  final Map<String, WindowRateLimiter> _limiters = {};
  int? _lastCleanupMs;

  bool allowEvent(String key, {int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final limiter = _limiters.putIfAbsent(
      key,
      () => WindowRateLimiter(limit),
    );
    final allowed = limiter.allowEvent(nowMs: now);
    _cleanup(now);
    return allowed;
  }

  void reset() {
    _limiters.clear();
    _lastCleanupMs = null;
  }

  void _cleanup(int nowMs) {
    final lastCleanup = _lastCleanupMs;
    if (lastCleanup != null &&
        nowMs - lastCleanup < cleanupInterval.inMilliseconds) {
      return;
    }
    _lastCleanupMs = nowMs;
    _limiters.removeWhere(
      (_, limiter) => limiter.prune(nowMs: nowMs) == 0,
    );
  }
}
