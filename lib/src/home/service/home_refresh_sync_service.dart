import 'dart:async';

import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/xmpp/bookmarks_manager.dart';
import 'package:axichat/src/xmpp/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:logging/logging.dart';

final class HomeRefreshSyncService {
  HomeRefreshSyncService({
    required XmppService xmppService,
    EmailService? emailService,
  })  : _xmppService = xmppService,
        _emailService = emailService;

  static const Duration _connectionTimeout = Duration(seconds: 20);
  static const int _mamHistoryPageSize = 50;

  final XmppService _xmppService;
  final EmailService? _emailService;
  final Logger _log = Logger('HomeRefreshSyncService');
  bool _syncInFlight = false;
  DateTime? _lastSyncAt;

  Future<void> syncOnLogin() async {
    try {
      await refresh();
    } on Exception {
      _log.fine('Post-login sync failed.');
    }
  }

  Future<DateTime> refresh() async {
    if (_syncInFlight) {
      return _lastSyncAt ?? DateTime.timestamp();
    }
    _syncInFlight = true;
    try {
      await _healTransports();

      await _refreshMucBookmarks();
      await _refreshConversationIndex();
      await _refreshEmailHistory();

      await _refreshXmppHistory();
      await _rehydrateCalendar();
      await _refreshAvatars();

      _lastSyncAt = DateTime.timestamp();
      return _lastSyncAt!;
    } finally {
      _syncInFlight = false;
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

  Future<void> _ensureConnected() async {
    if (_xmppService.connectionState == ConnectionState.connected) return;
    await _xmppService.triggerImmediateReconnect();
    await _xmppService.connectivityStream
        .firstWhere((state) => state == ConnectionState.connected)
        .timeout(_connectionTimeout);
  }

  Future<void> _ensureEmailConnected() async {
    final emailService = _emailService;
    if (emailService == null) return;
    try {
      if (!emailService.isRunning) {
        await emailService.start();
      }
      await emailService.handleNetworkAvailable();
    } on Exception {
      _log.fine('Email transport recovery failed.');
    }
  }

  Future<List<MucBookmark>> _refreshMucBookmarks() async {
    if (_xmppService.connectionState != ConnectionState.connected) {
      return const [];
    }
    final support = await _xmppService.refreshPubSubSupport();
    if (!support.canUseBookmarks2) {
      return const [];
    }
    final manager = _xmppService.bookmarksManager;
    if (manager == null) return const [];
    await manager.ensureNode();
    await manager.subscribe();
    final bookmarks = await manager.getBookmarks();
    await _xmppService.applyMucBookmarks(bookmarks);
    return bookmarks;
  }

  Future<List<ConvItem>> _refreshConversationIndex() async {
    if (_xmppService.connectionState != ConnectionState.connected) {
      return const [];
    }
    final support = await _xmppService.refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      return const [];
    }
    final manager = _xmppService.conversationIndexManager;
    if (manager == null) return const [];
    await manager.ensureNode();
    await manager.subscribe();
    final items = await manager.fetchAll();
    await _xmppService.applyConversationIndexItems(items);
    return items;
  }

  Future<void> _refreshEmailHistory() async {
    final emailService = _emailService;
    if (emailService == null) return;
    try {
      await emailService.performBackgroundFetch();
    } on Exception {
      _log.fine('Email background sync failed.');
    }
  }

  Future<void> _refreshXmppHistory() async {
    if (_xmppService.connectionState != ConnectionState.connected) return;
    final outcome = await _xmppService.syncGlobalMamCatchUp(
      pageSize: _mamHistoryPageSize,
    );
    final includeDirect = outcome.shouldFallbackToPerChat;
    await _xmppService.syncMessageArchiveOnLogin(
      includeDirect: includeDirect,
      includeMuc: true,
    );
  }

  Future<void> _refreshAvatars() async {
    if (_xmppService.connectionState != ConnectionState.connected) return;
    await _xmppService.refreshAvatarsForConversationIndex();
  }
}
