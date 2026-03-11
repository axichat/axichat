// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/xmpp/bookmarks_manager.dart';
import 'package:axichat/src/xmpp/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:logging/logging.dart';

class HomeRefreshSyncService {
  HomeRefreshSyncService({
    required XmppService xmppService,
    EmailService? emailService,
  }) : _xmppService = xmppService,
       _emailService = emailService;

  final XmppService _xmppService;
  EmailService? _emailService;
  final Logger _log = Logger('HomeRefreshSyncService');
  final StreamController<HomeRefreshSyncUpdate> _syncUpdates =
      StreamController<HomeRefreshSyncUpdate>.broadcast();
  Future<DateTime>? _syncTask;
  DateTime? _lastSyncAt;
  StreamSubscription<ConnectionState>? _xmppConnectivitySubscription;
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;
  ConnectionState? _lastXmppState;
  EmailSyncStatus? _lastEmailStatus;
  int _lifecycleEpoch = 0;

  Stream<HomeRefreshSyncUpdate> get syncUpdates => _syncUpdates.stream;

  void start() {
    if (_xmppConnectivitySubscription != null) return;
    _lastXmppState = _xmppService.connectionState;
    _xmppConnectivitySubscription = _xmppService.connectivityStream.listen(
      _handleXmppConnectivity,
    );
    final emailService = _emailService;
    if (emailService != null) {
      _lastEmailStatus = emailService.syncState.status;
      _emailSyncSubscription = emailService.syncStateStream.listen(
        _handleEmailSyncState,
      );
    }
  }

  Future<void> updateEmailService(EmailService? emailService) async {
    if (identical(emailService, _emailService)) {
      return;
    }
    final emailSub = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await emailSub?.cancel();
    _emailService = emailService;
    if (emailService != null) {
      _lastEmailStatus = emailService.syncState.status;
      _emailSyncSubscription = emailService.syncStateStream.listen(
        _handleEmailSyncState,
      );
    } else {
      _lastEmailStatus = null;
    }
  }

  Future<void> close() async {
    _lifecycleEpoch += 1;
    final pendingSync = _syncTask;
    final xmppSub = _xmppConnectivitySubscription;
    _xmppConnectivitySubscription = null;
    await xmppSub?.cancel();
    final emailSub = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await emailSub?.cancel();
    if (pendingSync != null) {
      await pendingSync;
    }
    _lastSyncAt = null;
    _lastXmppState = null;
    _lastEmailStatus = null;
  }

  Future<void> syncOnLogin() async {
    final epoch = _lifecycleEpoch;
    if (_lastSyncAt == null) {
      await refresh(epoch: epoch);
      return;
    }
    await refreshUnreadOnly(epoch: epoch);
  }

  Future<DateTime> refreshUnreadOnly({int? epoch}) async {
    final currentEpoch = epoch ?? _lifecycleEpoch;
    return _enqueueSync(() async {
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _healTransports(epoch: currentEpoch);
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _pullUnreadFromNewContacts(epoch: currentEpoch);
      _throwIfLifecycleEpochChanged(currentEpoch);
      _lastSyncAt = DateTime.timestamp();
      return _lastSyncAt!;
    });
  }

  Future<DateTime> refresh({int? epoch}) async {
    final currentEpoch = epoch ?? _lifecycleEpoch;
    return _enqueueSync(() async {
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _healTransports(epoch: currentEpoch);
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _refreshXmppUnread(epoch: currentEpoch);
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _syncEmailContacts(epoch: currentEpoch);
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _refreshAntiAbuseLists();
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _refreshConversationIndex();
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _refreshMucBookmarks();
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _refreshEmailHistory(epoch: currentEpoch);
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _rehydrateCalendar();
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _refreshAvatars();
      _throwIfLifecycleEpochChanged(currentEpoch);
      await _refreshDrafts();
      _throwIfLifecycleEpochChanged(currentEpoch);

      _lastSyncAt = DateTime.timestamp();
      return _lastSyncAt!;
    });
  }

  Future<DateTime> _enqueueSync(Future<DateTime> Function() action) {
    final pending = _syncTask;
    if (pending != null) {
      return pending;
    }
    _syncUpdates.add(
      const HomeRefreshSyncUpdate(phase: HomeRefreshSyncPhase.running),
    );
    final task = () async {
      try {
        final syncedAt = await action();
        _syncUpdates.add(
          HomeRefreshSyncUpdate(
            phase: HomeRefreshSyncPhase.success,
            syncedAt: syncedAt,
          ),
        );
        return syncedAt;
      } on _HomeRefreshSyncCancelled {
        return _lastSyncAt ?? DateTime.timestamp();
      } on Exception catch (error, stackTrace) {
        _log.fine('Home refresh failed.', error, stackTrace);
        _syncUpdates.add(
          const HomeRefreshSyncUpdate(phase: HomeRefreshSyncPhase.failure),
        );
        return _lastSyncAt ?? DateTime.timestamp();
      }
    }();
    _syncTask = task;
    return task.whenComplete(() {
      if (_syncTask == task) {
        _syncTask = null;
      }
    });
  }

  Future<void> _handleXmppConnectivity(ConnectionState state) async {
    final wasConnected = _lastXmppState == ConnectionState.connected;
    _lastXmppState = state;
    if (!wasConnected && state == ConnectionState.connected) {
      _runReconnectSync();
      return;
    }
  }

  Future<void> _handleEmailSyncState(EmailSyncState state) async {
    final wasReady = _lastEmailStatus == EmailSyncStatus.ready;
    _lastEmailStatus = state.status;
    if (!wasReady && state.status == EmailSyncStatus.ready) {
      _runReconnectSync();
    }
  }

  void _runReconnectSync() {
    if (_xmppConnectivitySubscription == null &&
        _emailSyncSubscription == null) {
      return;
    }
    if (_syncTask != null) {
      return;
    }
    unawaited(refreshUnreadOnly());
  }

  Future<void> _rehydrateCalendar() async {
    if (_xmppService.connectionState != ConnectionState.connected) return;
    try {
      await _xmppService.rehydrateCalendarFromMam();
    } on Exception {
      // Best-effort: calendar rehydration failures should not block refresh
    }
  }

  Future<void> _healTransports({required int epoch}) async {
    _throwIfLifecycleEpochChanged(epoch);
    await _ensureConnected();
    _throwIfLifecycleEpochChanged(epoch);
    await _ensureEmailConnected(epoch: epoch);
  }

  Future<MamGlobalSyncOutcome> _pullUnreadFromNewContacts({
    required int epoch,
  }) async {
    final mamOutcome = await _refreshXmppUnread(epoch: epoch);
    _throwIfLifecycleEpochChanged(epoch);
    await _refreshEmailUnread(epoch: epoch);
    return mamOutcome;
  }

  Future<MamGlobalSyncOutcome> _refreshXmppUnread({required int epoch}) async {
    if (_xmppService.connectionState != ConnectionState.connected) {
      return MamGlobalSyncOutcome.failed;
    }
    const streamReadyTimeout = Duration(seconds: 5);
    final streamReady = await _xmppService.waitForStreamReady(
      streamReadyTimeout,
    );
    _throwIfLifecycleEpochChanged(epoch);
    if (streamReady?.isResumed ?? false) {
      return MamGlobalSyncOutcome.skippedResumed;
    }
    const mamHistoryPageSize = 50;
    return _xmppService.syncGlobalMamCatchUp(pageSize: mamHistoryPageSize);
  }

  Future<void> _refreshEmailUnread({required int epoch}) async {
    final emailService = _emailService;
    if (emailService == null) return;
    if (!emailService.hasActiveSession) {
      return;
    }
    try {
      const emailUnreadFetchTimeout = Duration(seconds: 8);
      await emailService.performBackgroundFetch(
        timeout: emailUnreadFetchTimeout,
      );
      _throwIfLifecycleEpochChanged(epoch);
      await emailService.refreshChatlistFromCore();
    } on Exception {
      _log.fine('Email unread sync failed.');
    }
  }

  Future<void> _ensureConnected() async {
    if (!_xmppService.hasConnectionSettings) return;
    if (_xmppService.connectionState == ConnectionState.connected) return;
    await _xmppService.requestReconnect(ReconnectTrigger.userAction);
    const connectionTimeout = Duration(seconds: 20);
    await _xmppService.connectivityStream
        .firstWhere((state) => state == ConnectionState.connected)
        .timeout(connectionTimeout);
  }

  Future<void> _ensureEmailConnected({required int epoch}) async {
    final emailService = _emailService;
    if (emailService == null) return;
    if (!await emailService.canReconnectConfiguredSession()) return;
    try {
      _throwIfLifecycleEpochChanged(epoch);
      await emailService.ensureEventChannelActive();
      _throwIfLifecycleEpochChanged(epoch);
      await emailService.handleNetworkAvailable();
    } on Exception {
      _log.fine('Email transport recovery failed.');
    }
  }

  Future<List<MucBookmark>> _refreshMucBookmarks() async {
    if (_xmppService.connectionState != ConnectionState.connected) {
      return const [];
    }
    return _xmppService.syncMucBookmarksSnapshot();
  }

  Future<List<ConvItem>> _refreshConversationIndex() async {
    if (_xmppService.connectionState != ConnectionState.connected) {
      return const [];
    }
    return _xmppService.syncConversationIndexSnapshot();
  }

  Future<void> _refreshEmailHistory({required int epoch}) async {
    final emailService = _emailService;
    if (emailService == null) return;
    if (!emailService.hasActiveSession) {
      return;
    }
    try {
      const emailHistoryFetchTimeout = Duration(seconds: 25);
      await emailService.performBackgroundFetch(
        timeout: emailHistoryFetchTimeout,
      );
      _throwIfLifecycleEpochChanged(epoch);
      await emailService.refreshChatlistFromCore();
    } on Exception {
      _log.fine('Email background sync failed.');
    }
  }

  Future<void> _syncEmailContacts({required int epoch}) async {
    final emailService = _emailService;
    if (emailService == null) return;
    if (!emailService.hasActiveSession) {
      return;
    }
    try {
      _throwIfLifecycleEpochChanged(epoch);
      await emailService.syncContactsFromCore();
    } on Exception {
      _log.fine('Email contact sync failed.');
    }
  }

  Future<void> _refreshAntiAbuseLists() async {
    if (_xmppService.connectionState != ConnectionState.connected) return;
    await _xmppService.syncSpamSnapshot();
    await _xmppService.syncEmailBlocklistSnapshot();
  }

  Future<void> _refreshAvatars() async {
    if (_xmppService.connectionState != ConnectionState.connected) return;
    await _xmppService.refreshAvatarsForConversationIndex();
  }

  Future<void> _refreshDrafts() async {
    if (_xmppService.connectionState != ConnectionState.connected) return;
    await _xmppService.syncDraftsSnapshot();
  }

  void _throwIfLifecycleEpochChanged(int epoch) {
    if (epoch != _lifecycleEpoch) {
      throw const _HomeRefreshSyncCancelled();
    }
  }
}

enum HomeRefreshSyncPhase { idle, running, success, failure }

class HomeRefreshSyncUpdate {
  const HomeRefreshSyncUpdate({required this.phase, this.syncedAt});

  final HomeRefreshSyncPhase phase;
  final DateTime? syncedAt;
}

final class _HomeRefreshSyncCancelled implements Exception {
  const _HomeRefreshSyncCancelled();
}
