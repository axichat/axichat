part of 'home_bloc.dart';

extension on HomeBloc {
  Future<void> _attachEmailSyncSubscription(EmailService? emailService) async {
    final existingSubscription = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await existingSubscription?.cancel();

    if (emailService == null) {
      return;
    }

    _emailSyncSubscription = emailService.readyTransitionStream.listen(
      (_) => _runEmailReconnectSync(),
    );
  }

  Future<void> _runEmailReconnectSync() async {
    if (_syncTask != null) {
      return;
    }
    add(const _HomeEmailUnreadRefreshRequested());
  }

  Future<DateTime> _runRefreshSequence() async {
    await _healTransports();
    await _refreshXmppUnread();
    await _syncEmailContacts();
    await _refreshAntiAbuseLists();
    await _refreshConversationIndex();
    await _refreshMucBookmarks();
    await _refreshEmailHistory();
    await _rehydrateCalendar();
    await _refreshAvatars();
    await _refreshDrafts();
    return DateTime.timestamp();
  }

  Future<DateTime> _runEmailUnreadRefreshSequence() async {
    await _refreshEmailUnread();
    return DateTime.timestamp();
  }

  Future<void> _rehydrateCalendar() async {
    try {
      await _xmppService.rehydrateCalendarFromMam();
    } on Exception {
      // Best-effort: calendar rehydration failures should not block refresh.
    }
  }

  Future<void> _healTransports() async {
    await _ensureConnected();
    await _ensureEmailConnected();
  }

  Future<MamGlobalSyncOutcome> _refreshXmppUnread() async {
    const mamHistoryPageSize = 50;
    return _xmppService.syncGlobalMamCatchUpForRefresh(
      pageSize: mamHistoryPageSize,
    );
  }

  Future<void> _ensureConnected() async {
    const connectionTimeout = Duration(seconds: 20);
    await _xmppService.ensureConnected(
      trigger: ReconnectTrigger.userAction,
      timeout: connectionTimeout,
    );
  }

  Future<void> _ensureEmailConnected() async {
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    await emailService.recoverForHomeRefresh();
  }

  Future<void> _refreshEmailUnread() async {
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    await emailService.refreshUnreadForHomeRefresh();
  }

  Future<List<MucBookmark>> _refreshMucBookmarks() {
    return _xmppService.syncMucBookmarksSnapshot();
  }

  Future<List<ConvItem>> _refreshConversationIndex() {
    return _xmppService.syncConversationIndexSnapshot();
  }

  Future<void> _refreshEmailHistory() async {
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    await emailService.refreshHistoryForHomeRefresh();
  }

  Future<void> _syncEmailContacts() async {
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    await emailService.syncContactsForHomeRefresh();
  }

  Future<void> _refreshAntiAbuseLists() async {
    await _xmppService.syncSpamSnapshot();
    await _xmppService.syncAddressBlockSnapshot();
  }

  Future<void> _refreshAvatars() async {
    await _xmppService.refreshAvatarsForConversationIndex();
  }

  Future<void> _refreshDrafts() async {
    await _xmppService.syncDraftsSnapshot();
  }
}
