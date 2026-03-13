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
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;
  EmailSyncStatus? _lastEmailStatus;
  bool _acceptsNewSyncRequests = true;
  bool _started = false;
  int _syncEpoch = 0;

  Stream<HomeRefreshSyncUpdate> get syncUpdates => _syncUpdates.stream;

  void start() {
    _acceptsNewSyncRequests = true;
    _started = true;
    if (_emailSyncSubscription != null) return;
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
    if (_started && emailService != null) {
      _lastEmailStatus = emailService.syncState.status;
      _emailSyncSubscription = emailService.syncStateStream.listen(
        _handleEmailSyncState,
      );
    } else {
      _lastEmailStatus = null;
    }
  }

  Future<void> close({bool abortPendingSync = false}) async {
    _acceptsNewSyncRequests = false;
    _started = false;
    final pending = _syncTask;
    if (abortPendingSync) {
      _syncEpoch += 1;
      _syncTask = null;
    }
    final emailSub = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await emailSub?.cancel();
    if (!abortPendingSync) {
      await pending;
    }
    _lastSyncAt = null;
    _lastEmailStatus = null;
  }

  Future<DateTime> refreshUnreadOnly() {
    return _enqueueSync((epoch) async {
      _throwIfSyncAborted(epoch);
      await _healTransports(epoch);
      _throwIfSyncAborted(epoch);
      await _pullUnreadFromNewContacts(epoch);
      _throwIfSyncAborted(epoch);
      _lastSyncAt = DateTime.timestamp();
      return _lastSyncAt!;
    });
  }

  Future<DateTime> refresh() {
    return _enqueueSync((epoch) async {
      _throwIfSyncAborted(epoch);
      await _healTransports(epoch);
      _throwIfSyncAborted(epoch);
      await _refreshXmppUnread(epoch);
      _throwIfSyncAborted(epoch);
      await _syncEmailContacts(epoch);
      _throwIfSyncAborted(epoch);
      await _refreshAntiAbuseLists(epoch);
      _throwIfSyncAborted(epoch);
      await _refreshConversationIndex(epoch);
      _throwIfSyncAborted(epoch);
      await _refreshMucBookmarks(epoch);
      _throwIfSyncAborted(epoch);
      await _refreshEmailHistory(epoch);
      _throwIfSyncAborted(epoch);
      await _rehydrateCalendar(epoch);
      _throwIfSyncAborted(epoch);
      await _refreshAvatars(epoch);
      _throwIfSyncAborted(epoch);
      await _refreshDrafts(epoch);
      _throwIfSyncAborted(epoch);
      _lastSyncAt = DateTime.timestamp();
      return _lastSyncAt!;
    });
  }

  Future<DateTime> _enqueueSync(Future<DateTime> Function(int epoch) action) {
    if (!_acceptsNewSyncRequests) {
      return Future<DateTime>.value(_lastSyncAt ?? DateTime.timestamp());
    }
    final pending = _syncTask;
    if (pending != null) {
      return pending;
    }
    final epoch = _syncEpoch;
    _syncUpdates.add(
      const HomeRefreshSyncUpdate(phase: HomeRefreshSyncPhase.running),
    );
    final task = () async {
      try {
        final syncedAt = await action(epoch);
        _throwIfSyncAborted(epoch);
        _syncUpdates.add(
          HomeRefreshSyncUpdate(
            phase: HomeRefreshSyncPhase.success,
            syncedAt: syncedAt,
          ),
        );
        return syncedAt;
      } on _HomeRefreshSyncAbortedException {
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

  Future<void> _handleEmailSyncState(EmailSyncState state) async {
    if (!_acceptsNewSyncRequests) {
      return;
    }
    final wasReady = _lastEmailStatus == EmailSyncStatus.ready;
    _lastEmailStatus = state.status;
    if (!wasReady && state.status == EmailSyncStatus.ready) {
      await _runEmailReconnectSync();
    }
  }

  Future<void> _runEmailReconnectSync() async {
    if (!_acceptsNewSyncRequests) {
      return;
    }
    if (_emailSyncSubscription == null) {
      return;
    }
    if (_syncTask != null) {
      return;
    }
    await _enqueueSync((epoch) async {
      _throwIfSyncAborted(epoch);
      await _refreshEmailUnread(epoch);
      _throwIfSyncAborted(epoch);
      _lastSyncAt = DateTime.timestamp();
      return _lastSyncAt!;
    });
  }

  Future<void> _rehydrateCalendar(int epoch) async {
    _throwIfSyncAborted(epoch);
    if (_xmppService.connectionState != ConnectionState.connected) return;
    try {
      await _xmppService.rehydrateCalendarFromMam();
      _throwIfSyncAborted(epoch);
    } on Exception {
      // Best-effort: calendar rehydration failures should not block refresh
    }
  }

  Future<void> _healTransports(int epoch) async {
    _throwIfSyncAborted(epoch);
    await _ensureConnected(epoch);
    _throwIfSyncAborted(epoch);
    await _ensureEmailConnected(epoch);
    _throwIfSyncAborted(epoch);
  }

  Future<MamGlobalSyncOutcome> _pullUnreadFromNewContacts(int epoch) async {
    _throwIfSyncAborted(epoch);
    final mamOutcome = await _refreshXmppUnread(epoch);
    _throwIfSyncAborted(epoch);
    await _refreshEmailUnread(epoch);
    _throwIfSyncAborted(epoch);
    return mamOutcome;
  }

  Future<MamGlobalSyncOutcome> _refreshXmppUnread(int epoch) async {
    _throwIfSyncAborted(epoch);
    if (_xmppService.connectionState != ConnectionState.connected) {
      return MamGlobalSyncOutcome.failed;
    }
    final streamReady = _xmppService.lastStreamReady;
    if (streamReady == null) {
      return MamGlobalSyncOutcome.failed;
    }
    if (streamReady.isResumed) {
      return MamGlobalSyncOutcome.skippedResumed;
    }
    const mamHistoryPageSize = 50;
    return _xmppService.syncGlobalMamCatchUp(pageSize: mamHistoryPageSize);
  }

  Future<void> _refreshEmailUnread(int epoch) async {
    _throwIfSyncAborted(epoch);
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
      _throwIfSyncAborted(epoch);
      await emailService.refreshChatlistFromCore();
      _throwIfSyncAborted(epoch);
    } on Exception {
      _log.fine('Email unread sync failed.');
    }
  }

  Future<void> _ensureConnected(int epoch) async {
    _throwIfSyncAborted(epoch);
    if (!_xmppService.hasConnectionSettings) return;
    if (_xmppService.connectionState == ConnectionState.connected) return;
    await _xmppService.requestReconnect(ReconnectTrigger.userAction);
    _throwIfSyncAborted(epoch);
    const connectionTimeout = Duration(seconds: 20);
    await _xmppService.connectivityStream
        .firstWhere((state) => state == ConnectionState.connected)
        .timeout(connectionTimeout);
    _throwIfSyncAborted(epoch);
  }

  Future<void> _ensureEmailConnected(int epoch) async {
    _throwIfSyncAborted(epoch);
    final emailService = _emailService;
    if (emailService == null) return;
    if (!await emailService.canReconnectConfiguredSession()) return;
    _throwIfSyncAborted(epoch);
    try {
      await emailService.ensureEventChannelActive();
      _throwIfSyncAborted(epoch);
      await emailService.handleNetworkAvailable();
      _throwIfSyncAborted(epoch);
    } on Exception {
      _log.fine('Email transport recovery failed.');
    }
  }

  Future<List<MucBookmark>> _refreshMucBookmarks(int epoch) async {
    _throwIfSyncAborted(epoch);
    if (_xmppService.connectionState != ConnectionState.connected) {
      return const [];
    }
    final bookmarks = await _xmppService.syncMucBookmarksSnapshot();
    _throwIfSyncAborted(epoch);
    return bookmarks;
  }

  Future<List<ConvItem>> _refreshConversationIndex(int epoch) async {
    _throwIfSyncAborted(epoch);
    if (_xmppService.connectionState != ConnectionState.connected) {
      return const [];
    }
    final items = await _xmppService.syncConversationIndexSnapshot();
    _throwIfSyncAborted(epoch);
    return items;
  }

  Future<void> _refreshEmailHistory(int epoch) async {
    _throwIfSyncAborted(epoch);
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
      _throwIfSyncAborted(epoch);
      await emailService.refreshChatlistFromCore();
      _throwIfSyncAborted(epoch);
    } on Exception {
      _log.fine('Email background sync failed.');
    }
  }

  Future<void> _syncEmailContacts(int epoch) async {
    _throwIfSyncAborted(epoch);
    final emailService = _emailService;
    if (emailService == null) return;
    if (!emailService.hasActiveSession) {
      return;
    }
    try {
      await emailService.syncContactsFromCore();
      _throwIfSyncAborted(epoch);
    } on Exception {
      _log.fine('Email contact sync failed.');
    }
  }

  Future<void> _refreshAntiAbuseLists(int epoch) async {
    _throwIfSyncAborted(epoch);
    if (_xmppService.connectionState != ConnectionState.connected) return;
    await _xmppService.syncSpamSnapshot();
    _throwIfSyncAborted(epoch);
    await _xmppService.syncEmailBlocklistSnapshot();
    _throwIfSyncAborted(epoch);
  }

  Future<void> _refreshAvatars(int epoch) async {
    _throwIfSyncAborted(epoch);
    if (_xmppService.connectionState != ConnectionState.connected) return;
    await _xmppService.refreshAvatarsForConversationIndex();
    _throwIfSyncAborted(epoch);
  }

  Future<void> _refreshDrafts(int epoch) async {
    _throwIfSyncAborted(epoch);
    if (_xmppService.connectionState != ConnectionState.connected) return;
    await _xmppService.syncDraftsSnapshot();
    _throwIfSyncAborted(epoch);
  }

  void _throwIfSyncAborted(int epoch) {
    if (epoch != _syncEpoch) {
      throw const _HomeRefreshSyncAbortedException();
    }
  }
}

final class _HomeRefreshSyncAbortedException implements Exception {
  const _HomeRefreshSyncAbortedException();
}

enum HomeRefreshSyncPhase { idle, running, success, failure }

class HomeRefreshSyncUpdate {
  const HomeRefreshSyncUpdate({required this.phase, this.syncedAt});

  final HomeRefreshSyncPhase phase;
  final DateTime? syncedAt;
}
