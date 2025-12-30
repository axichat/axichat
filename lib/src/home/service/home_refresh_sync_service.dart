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
  })  : _xmppService = xmppService,
        _emailService = emailService;

  static const Duration _connectionTimeout = Duration(seconds: 20);
  static const int _mamHistoryPageSize = 50;
  static const Duration _streamReadyTimeout = Duration(seconds: 5);
  static const Duration _emailUnreadFetchTimeout = Duration(seconds: 8);
  static const Duration _emailHistoryFetchTimeout = Duration(seconds: 25);

  final XmppService _xmppService;
  final EmailService? _emailService;
  final Logger _log = Logger('HomeRefreshSyncService');
  bool _syncInFlight = false;
  DateTime? _lastSyncAt;
  StreamSubscription<ConnectionState>? _xmppConnectivitySubscription;
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;
  ConnectionState? _lastXmppState;
  EmailSyncStatus? _lastEmailStatus;
  var _listenersStarted = false;

  void start() {
    if (_listenersStarted) return;
    _listenersStarted = true;
    _lastXmppState = _xmppService.connectionState;
    _xmppConnectivitySubscription =
        _xmppService.connectivityStream.listen(_handleXmppConnectivity);
    final emailService = _emailService;
    if (emailService != null) {
      _lastEmailStatus = emailService.syncState.status;
      _emailSyncSubscription =
          emailService.syncStateStream.listen(_handleEmailSyncState);
    }
  }

  Future<void> close() async {
    _listenersStarted = false;
    final xmppSub = _xmppConnectivitySubscription;
    _xmppConnectivitySubscription = null;
    await xmppSub?.cancel();
    final emailSub = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await emailSub?.cancel();
  }

  Future<void> syncOnLogin() async {
    try {
      await refreshUnreadOnly();
    } on Exception {
      _log.fine('Post-login sync failed.');
    }
  }

  Future<DateTime> refreshUnreadOnly() async {
    if (_syncInFlight) {
      return _lastSyncAt ?? DateTime.timestamp();
    }
    _syncInFlight = true;
    try {
      await _healTransports();
      await _pullUnreadFromNewContacts();
      _lastSyncAt = DateTime.timestamp();
      return _lastSyncAt!;
    } finally {
      _syncInFlight = false;
    }
  }

  Future<DateTime> refresh() async {
    if (_syncInFlight) {
      return _lastSyncAt ?? DateTime.timestamp();
    }
    _syncInFlight = true;
    try {
      await _healTransports();
      await _pullUnreadFromNewContacts();
      await _syncEmailContacts();
      await _refreshAntiAbuseLists();
      await _refreshConversationIndex();
      await _refreshMucBookmarks();
      await _refreshEmailHistory();
      await _rehydrateCalendar();
      await _refreshAvatars();
      await _refreshDrafts();

      _lastSyncAt = DateTime.timestamp();
      return _lastSyncAt!;
    } finally {
      _syncInFlight = false;
    }
  }

  void _handleXmppConnectivity(ConnectionState state) {
    final wasConnected = _lastXmppState == ConnectionState.connected;
    _lastXmppState = state;
    if (!wasConnected && state == ConnectionState.connected) {
      unawaited(_runReconnectSync());
      return;
    }
  }

  void _handleEmailSyncState(EmailSyncState state) {
    final wasReady = _lastEmailStatus == EmailSyncStatus.ready;
    _lastEmailStatus = state.status;
    if (!wasReady && state.status == EmailSyncStatus.ready) {
      unawaited(_runReconnectSync());
    }
  }

  Future<void> _runReconnectSync() async {
    if (_syncInFlight) {
      return;
    }
    try {
      await refreshUnreadOnly();
    } on Exception {
      _log.fine('Reconnect sync failed.');
    }
  }

  Future<void> _rehydrateCalendar() async {
    if (_xmppService.connectionState != ConnectionState.connected) return;
    try {
      await _xmppService.rehydrateCalendarFromMam();
    } on Exception {
      // Best-effort: calendar rehydration failures should not block refresh
    }
  }

  Future<void> _healTransports() async {
    await _ensureConnected();
    await _ensureEmailConnected();
  }

  Future<MamGlobalSyncOutcome> _pullUnreadFromNewContacts() async {
    final mamOutcome = await _refreshXmppUnread();
    await _refreshEmailUnread();
    return mamOutcome;
  }

  Future<MamGlobalSyncOutcome> _refreshXmppUnread() async {
    if (_xmppService.connectionState != ConnectionState.connected) {
      return MamGlobalSyncOutcome.failed;
    }
    final streamReady =
        await _xmppService.waitForStreamReady(_streamReadyTimeout);
    if (streamReady?.isResumed ?? false) {
      return MamGlobalSyncOutcome.skippedResumed;
    }
    return _xmppService.syncGlobalMamCatchUp(
      pageSize: _mamHistoryPageSize,
    );
  }

  Future<void> _refreshEmailUnread() async {
    final emailService = _emailService;
    if (emailService == null) return;
    try {
      await emailService.performBackgroundFetch(
        timeout: _emailUnreadFetchTimeout,
      );
      await emailService.refreshChatlistFromCore();
    } on Exception {
      _log.fine('Email unread sync failed.');
    }
  }

  Future<void> _ensureConnected() async {
    if (!_xmppService.hasConnectionSettings) return;
    if (_xmppService.connectionState == ConnectionState.connected) return;
    await _xmppService.requestReconnect(ReconnectTrigger.userAction);
    await _xmppService.connectivityStream
        .firstWhere((state) => state == ConnectionState.connected)
        .timeout(_connectionTimeout);
  }

  Future<void> _ensureEmailConnected() async {
    final emailService = _emailService;
    if (emailService == null) return;
    try {
      await emailService.ensureEventChannelActive();
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

  Future<void> _refreshEmailHistory() async {
    final emailService = _emailService;
    if (emailService == null) return;
    try {
      await emailService.performBackgroundFetch(
        timeout: _emailHistoryFetchTimeout,
      );
      await emailService.refreshChatlistFromCore();
    } on Exception {
      _log.fine('Email background sync failed.');
    }
  }

  Future<void> _syncEmailContacts() async {
    final emailService = _emailService;
    if (emailService == null) return;
    try {
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
}
