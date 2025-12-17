import 'dart:async';

import 'package:axichat/src/xmpp/bookmarks_manager.dart';
import 'package:axichat/src/xmpp/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

final class HomeRefreshSyncService {
  HomeRefreshSyncService({
    required XmppService xmppService,
  }) : _xmppService = xmppService;

  static const int _historySyncConversationLimit = 50;
  static const Duration _connectionTimeout = Duration(seconds: 20);
  static const Duration _historySyncTimeBudget = Duration(seconds: 25);
  static const int _mamHistoryPageSize = 50;

  final XmppService _xmppService;

  Future<DateTime> refresh() async {
    await _ensureConnected();

    final bookmarks = await _refreshMucBookmarks();
    final conversationItems = await _refreshConversationIndex();

    await _refreshRecentHistory(
      bookmarks: bookmarks,
      conversations: conversationItems,
    );

    return DateTime.timestamp();
  }

  Future<void> _ensureConnected() async {
    if (_xmppService.connectionState == ConnectionState.connected) return;
    await _xmppService.triggerImmediateReconnect();
    await _xmppService.connectivityStream
        .firstWhere((state) => state == ConnectionState.connected)
        .timeout(_connectionTimeout);
  }

  Future<List<MucBookmark>> _refreshMucBookmarks() async {
    final manager = _xmppService.bookmarksManager;
    if (manager == null) return const [];
    final bookmarks = await manager.getBookmarks();
    await _xmppService.applyMucBookmarks(bookmarks);
    return bookmarks;
  }

  Future<List<ConvItem>> _refreshConversationIndex() async {
    final manager = _xmppService.conversationIndexManager;
    if (manager == null) return const [];
    await manager.ensureNode();
    await manager.subscribe();
    final items = await manager.fetchAll();
    await _xmppService.applyConversationIndexItems(items);
    return items;
  }

  Future<void> _refreshRecentHistory({
    required List<MucBookmark> bookmarks,
    required List<ConvItem> conversations,
  }) async {
    final supportsMam = await _xmppService.resolveMamSupport();
    if (!supportsMam) return;

    final now = DateTime.timestamp();
    final cutoff = now.add(_historySyncTimeBudget);

    final rooms = bookmarks.map((bookmark) => bookmark.roomBare.toString());
    final peers = conversations.toList(growable: false)
      ..sort(
        (a, b) => b.lastTimestamp.compareTo(a.lastTimestamp),
      );

    final targets = <({String jid, bool isMuc})>[];
    for (final room in rooms) {
      if (targets.length >= _historySyncConversationLimit) break;
      targets.add((jid: room, isMuc: true));
    }
    for (final conv in peers) {
      if (targets.length >= _historySyncConversationLimit) break;
      targets.add((jid: conv.peerBare.toString(), isMuc: false));
    }

    for (final target in targets) {
      if (DateTime.timestamp().isAfter(cutoff)) return;
      if (_xmppService.connectionState != ConnectionState.connected) return;
      try {
        await _xmppService.fetchLatestFromArchive(
          jid: target.jid,
          pageSize: _mamHistoryPageSize,
          isMuc: target.isMuc,
        );
      } on XmppAbortedException {
        return;
      } on Exception {
        continue;
      }
    }
  }
}
