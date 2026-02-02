// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/service/home_refresh_sync_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chats_cubit.freezed.dart';

part 'chats_state.dart';

enum ChatRouteIndex {
  main,
  search,
  details,
  settings,
  gallery,
  calendar;

  bool get isMain => this == ChatRouteIndex.main;

  bool get isSearch => this == ChatRouteIndex.search;

  bool get isDetails => this == ChatRouteIndex.details;

  bool get isSettings => this == ChatRouteIndex.settings;

  bool get isGallery => this == ChatRouteIndex.gallery;

  bool get isCalendar => this == ChatRouteIndex.calendar;

  bool get allowsChatInteraction => isMain || isSearch;
}

class _ChatViewResults {
  const _ChatViewResults({
    required this.visibleItems,
    required this.archivedItems,
    required this.selectedChats,
  });

  final List<Chat> visibleItems;
  final List<Chat> archivedItems;
  final List<Chat> selectedChats;
}

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({
    required XmppService xmppService,
    required HomeRefreshSyncService homeRefreshSyncService,
    EmailService? emailService,
  })  : _chatsService = xmppService,
        _xmppService = xmppService,
        _homeRefreshSyncService = homeRefreshSyncService,
        _emailService = emailService,
        super(
          _seedInitialState(xmppService.cachedChatList),
        ) {
    _chatsSubscription = _chatsService.chatsStream().listen(
          (items) => _updateChats(items),
        );
    _homeRefreshSyncSubscription =
        _homeRefreshSyncService.syncUpdates.listen(_handleHomeRefreshUpdate);
  }

  static ChatsState _seedInitialState(List<Chat>? cached) {
    final items = cached ?? const <Chat>[];
    final derived = _deriveChatViews(
      items: items,
      rosterContacts: const <String>{},
      searchQuery: '',
      searchActive: false,
      searchFilter: SearchFilterId.all,
      searchSortOrder: SearchSortOrder.newestFirst,
      selectedJids: const <String>{},
    );
    final spamVisibleItems = _deriveSpamItems(
      items: items,
      searchQuery: '',
      searchActive: false,
      searchFilter: SearchFilterId.all,
      searchSortOrder: SearchSortOrder.newestFirst,
    );
    return ChatsState(
      openJid: null,
      openStack: const <String>[],
      forwardStack: const <String>[],
      openCalendar: false,
      openChatCalendar: false,
      openChatRoute: ChatRouteIndex.main,
      items: items,
      creationStatus: RequestStatus.none,
      searchQuery: '',
      searchActive: false,
      searchFilter: SearchFilterId.all,
      searchSortOrder: SearchSortOrder.newestFirst,
      spamSearchQuery: '',
      spamSearchActive: false,
      spamSearchFilter: SearchFilterId.all,
      spamSearchSortOrder: SearchSortOrder.newestFirst,
      rosterContacts: const <String>{},
      visibleItems: derived.visibleItems,
      archivedItems: derived.archivedItems,
      selectedChats: derived.selectedChats,
      spamVisibleItems: spamVisibleItems,
    );
  }

  final ChatsService _chatsService;
  final XmppService _xmppService;
  final HomeRefreshSyncService _homeRefreshSyncService;
  EmailService? _emailService;

  late final StreamSubscription<List<Chat>> _chatsSubscription;
  late final StreamSubscription<HomeRefreshSyncUpdate>
      _homeRefreshSyncSubscription;
  final List<Timer> _exportCleanupTimers = [];

  void updateEmailService(EmailService? emailService) {
    _emailService = emailService;
  }

  @override
  Future<void> close() async {
    for (final timer in _exportCleanupTimers) {
      timer.cancel();
    }
    _exportCleanupTimers.clear();
    await _homeRefreshSyncSubscription.cancel();
    await _chatsSubscription.cancel();
    return super.close();
  }

  Stream<void> get demoResetStream => _xmppService.demoResetStream;

  void startDemoInteractivePhase() {
    _xmppService.startDemoInteractivePhase();
  }

  void _handleHomeRefreshUpdate(HomeRefreshSyncUpdate update) {
    final nextStatus = switch (update.phase) {
      HomeRefreshSyncPhase.running => RequestStatus.loading,
      HomeRefreshSyncPhase.success => RequestStatus.success,
      HomeRefreshSyncPhase.failure => RequestStatus.failure,
      HomeRefreshSyncPhase.idle => RequestStatus.none,
    };
    if (state.refreshStatus == nextStatus &&
        (update.syncedAt == null || state.lastSyncedAt == update.syncedAt)) {
      return;
    }
    emit(
      state.copyWith(
        refreshStatus: nextStatus,
        lastSyncedAt: update.syncedAt ?? state.lastSyncedAt,
      ),
    );
  }

  void scheduleExportCleanup(File file) {
    if (file.path.trim().isEmpty) return;
    const cleanupDelay = Duration(hours: 1);
    late final Timer timer;
    timer = Timer(cleanupDelay, () async {
      await ChatHistoryExporter.cleanupExportFile(file);
      _exportCleanupTimers.remove(timer);
    });
    _exportCleanupTimers.add(timer);
  }

  void updateSearchSnapshot({
    required bool active,
    required String query,
    required SearchFilterId? filterId,
    required SearchSortOrder sortOrder,
  }) {
    final normalizedQuery = active ? query.trim() : '';
    if (state.searchActive == active &&
        state.searchQuery == normalizedQuery &&
        state.searchFilter == filterId &&
        state.searchSortOrder == sortOrder) {
      return;
    }
    final derived = _deriveChatViews(
      items: state.items ?? const <Chat>[],
      rosterContacts: state.rosterContacts,
      searchQuery: normalizedQuery,
      searchActive: active,
      searchFilter: filterId,
      searchSortOrder: sortOrder,
      selectedJids: state.selectedJids,
    );
    emit(
      state.copyWith(
        searchActive: active,
        searchQuery: normalizedQuery,
        searchFilter: filterId,
        searchSortOrder: sortOrder,
        visibleItems: derived.visibleItems,
        archivedItems: derived.archivedItems,
        selectedChats: derived.selectedChats,
      ),
    );
  }

  void updateSpamSearchSnapshot({
    required bool active,
    required String query,
    required SearchFilterId? filterId,
    required SearchSortOrder sortOrder,
  }) {
    final normalizedQuery = active ? query.trim() : '';
    if (state.spamSearchActive == active &&
        state.spamSearchQuery == normalizedQuery &&
        state.spamSearchFilter == filterId &&
        state.spamSearchSortOrder == sortOrder) {
      return;
    }
    final spamVisibleItems = _deriveSpamItems(
      items: state.items ?? const <Chat>[],
      searchQuery: normalizedQuery,
      searchActive: active,
      searchFilter: filterId,
      searchSortOrder: sortOrder,
    );
    emit(
      state.copyWith(
        spamSearchActive: active,
        spamSearchQuery: normalizedQuery,
        spamSearchFilter: filterId,
        spamSearchSortOrder: sortOrder,
        spamVisibleItems: spamVisibleItems,
      ),
    );
  }

  void updateRosterContacts(Set<String> contacts) {
    if (setEquals(state.rosterContacts, contacts)) {
      return;
    }
    final derived = _deriveChatViews(
      items: state.items ?? const <Chat>[],
      rosterContacts: contacts,
      searchQuery: state.searchQuery,
      searchActive: state.searchActive,
      searchFilter: state.searchFilter,
      searchSortOrder: state.searchSortOrder,
      selectedJids: state.selectedJids,
    );
    emit(
      state.copyWith(
        rosterContacts: contacts,
        visibleItems: derived.visibleItems,
        archivedItems: derived.archivedItems,
        selectedChats: derived.selectedChats,
      ),
    );
  }

  static _ChatViewResults _deriveChatViews({
    required List<Chat> items,
    required Set<String> rosterContacts,
    required String searchQuery,
    required bool searchActive,
    required SearchFilterId? searchFilter,
    required SearchSortOrder searchSortOrder,
    required Set<String> selectedJids,
  }) {
    final normalizedQuery =
        searchActive ? searchQuery.trim().toLowerCase() : '';
    bool matchesFilter(Chat chat) {
      return switch (searchFilter ?? SearchFilterId.all) {
        SearchFilterId.contacts =>
          !chat.hidden && rosterContacts.contains(chat.jid),
        SearchFilterId.nonContacts =>
          !chat.hidden && !rosterContacts.contains(chat.jid),
        SearchFilterId.xmpp => !chat.hidden && chat.transport.isXmpp,
        SearchFilterId.email => !chat.hidden && chat.transport.isEmail,
        SearchFilterId.hidden => chat.hidden,
        SearchFilterId.all => !chat.hidden,
        SearchFilterId.attachments => !chat.hidden,
      };
    }

    bool matchesQuery(Chat chat) {
      if (normalizedQuery.isEmpty) return true;
      final alias = chat.contactDisplayName?.toLowerCase() ?? '';
      return chat.title.toLowerCase().contains(normalizedQuery) ||
          alias.contains(normalizedQuery) ||
          chat.jid.toLowerCase().contains(normalizedQuery) ||
          (chat.lastMessage?.toLowerCase().contains(normalizedQuery) ??
              false) ||
          (chat.alert?.toLowerCase().contains(normalizedQuery) ?? false);
    }

    final visibleItems = items
        .where((chat) => !chat.archived && !chat.spam)
        .where(matchesFilter)
        .where(matchesQuery)
        .toList(growable: false)
      ..sort(
        (a, b) => searchSortOrder.isNewestFirst
            ? b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp)
            : a.lastChangeTimestamp.compareTo(b.lastChangeTimestamp),
      );

    final archivedItems =
        items.where((chat) => chat.archived).toList(growable: false);
    final selectedChats = selectedJids.isEmpty
        ? const <Chat>[]
        : items
            .where((chat) => selectedJids.contains(chat.jid))
            .toList(growable: false);
    return _ChatViewResults(
      visibleItems: visibleItems,
      archivedItems: archivedItems,
      selectedChats: selectedChats,
    );
  }

  static List<Chat> _deriveSpamItems({
    required List<Chat> items,
    required String searchQuery,
    required bool searchActive,
    required SearchFilterId? searchFilter,
    required SearchSortOrder searchSortOrder,
  }) {
    final normalizedQuery =
        searchActive ? searchQuery.trim().toLowerCase() : '';
    bool matchesFilter(Chat chat) {
      return switch (searchFilter ?? SearchFilterId.all) {
        SearchFilterId.email => chat.transport.isEmail,
        SearchFilterId.xmpp => chat.transport.isXmpp,
        _ => true,
      };
    }

    bool matchesQuery(Chat chat) {
      if (normalizedQuery.isEmpty) return true;
      return chat.title.toLowerCase().contains(normalizedQuery) ||
          chat.jid.toLowerCase().contains(normalizedQuery);
    }

    final visibleItems = items
        .where((chat) => chat.spam)
        .where(matchesFilter)
        .where(matchesQuery)
        .toList(growable: false)
      ..sort(
        (a, b) {
          final aTimestamp = a.spamUpdatedAt ?? a.lastChangeTimestamp;
          final bTimestamp = b.spamUpdatedAt ?? b.lastChangeTimestamp;
          return searchSortOrder.isNewestFirst
              ? bTimestamp.compareTo(aTimestamp)
              : aTimestamp.compareTo(bTimestamp);
        },
      );
    return visibleItems;
  }

  void _updateChats(List<Chat> items) {
    final availableJids = items.map((chat) => chat.jid).toSet();
    final retainedSelection =
        state.selectedJids.where((jid) => availableJids.contains(jid)).toSet();
    final retainedStack = state.openStack
        .where((jid) => availableJids.contains(jid))
        .toList(growable: false);
    final retainedForward = state.forwardStack
        .where((jid) => availableJids.contains(jid))
        .toList(growable: false);
    final fallbackOpen =
        items.where((chat) => chat.open).firstOrNull?.jid ?? state.openJid;
    final seededStack = retainedStack.isNotEmpty
        ? retainedStack
        : [
            if (fallbackOpen != null && availableJids.contains(fallbackOpen))
              fallbackOpen,
          ];
    final shouldKeepChatCalendar =
        state.openChatCalendar && seededStack.isNotEmpty;
    final nextChatRoute = seededStack.isEmpty
        ? ChatRouteIndex.main
        : shouldKeepChatCalendar
            ? ChatRouteIndex.calendar
            : state.openChatRoute.isCalendar
                ? ChatRouteIndex.main
                : state.openChatRoute;
    final derived = _deriveChatViews(
      items: items,
      rosterContacts: state.rosterContacts,
      searchQuery: state.searchQuery,
      searchActive: state.searchActive,
      searchFilter: state.searchFilter,
      searchSortOrder: state.searchSortOrder,
      selectedJids: retainedSelection,
    );
    final spamVisibleItems = _deriveSpamItems(
      items: items,
      searchQuery: state.spamSearchQuery,
      searchActive: state.spamSearchActive,
      searchFilter: state.spamSearchFilter,
      searchSortOrder: state.spamSearchSortOrder,
    );
    emit(
      state.copyWith(
        openStack: seededStack,
        forwardStack: retainedForward,
        openJid: seededStack.isEmpty ? null : seededStack.last,
        items: items,
        selectedJids: retainedSelection,
        openChatCalendar: shouldKeepChatCalendar,
        openChatRoute: nextChatRoute,
        visibleItems: derived.visibleItems,
        archivedItems: derived.archivedItems,
        selectedChats: derived.selectedChats,
        spamVisibleItems: spamVisibleItems,
      ),
    );
  }

  Chat? _chatFor(String jid) {
    for (final chat in state.items ?? const <Chat>[]) {
      if (chat.jid == jid) return chat;
    }
    return null;
  }

  Future<void> openChat({required String jid}) async {
    emit(
      state.copyWith(
        openStack: <String>[jid],
        forwardStack: const <String>[],
        openJid: jid,
        openChatCalendar: false,
        openChatRoute: ChatRouteIndex.main,
      ),
    );
    await _chatsService.openChat(jid);
  }

  Future<void> toggleChat({required String jid}) async {
    if (jid == state.openJid) {
      await closeAllChats();
      return;
    }
    // Close calendar when opening chat
    if (state.openCalendar) {
      emit(state.copyWith(openCalendar: false, openChatCalendar: false));
    }
    await openChat(jid: jid);
  }

  Future<void> pushChat({required String jid}) async {
    final chat = _chatFor(jid);
    if (chat == null || !chat.defaultTransport.isEmail) {
      await openChat(jid: jid);
      return;
    }
    final filtered =
        state.openStack.where((entry) => entry != jid).toList(growable: false);
    final nextStack = [...filtered, jid];
    emit(
      state.copyWith(
        openStack: nextStack,
        forwardStack: const <String>[],
        openJid: jid,
        openChatCalendar: false,
        openChatRoute: ChatRouteIndex.main,
      ),
    );
    await _chatsService.openChat(jid);
  }

  Future<void> popChat() async {
    if (state.openStack.isEmpty) return;
    final popped = state.openStack.last;
    final nextStack = List<String>.of(state.openStack)..removeLast();
    final nextForward = List<String>.of(state.forwardStack)..add(popped);
    final nextOpen = nextStack.isEmpty ? null : nextStack.last;
    emit(
      state.copyWith(
        openStack: nextStack,
        forwardStack: nextForward,
        openJid: nextOpen,
        openChatCalendar: false,
        openChatRoute: ChatRouteIndex.main,
      ),
    );
    if (nextOpen == null) {
      await _chatsService.closeChat();
    } else {
      await _chatsService.openChat(nextOpen);
    }
  }

  Future<void> restoreChat() async {
    if (state.forwardStack.isEmpty) return;
    final restored = state.forwardStack.last;
    final nextForward = List<String>.of(state.forwardStack)..removeLast();
    final filteredStack =
        state.openStack.where((entry) => entry != restored).toList();
    filteredStack.add(restored);
    emit(
      state.copyWith(
        forwardStack: nextForward,
        openStack: filteredStack,
        openJid: restored,
        openChatCalendar: false,
        openChatRoute: ChatRouteIndex.main,
      ),
    );
    await _chatsService.openChat(restored);
  }

  Future<void> closeAllChats() async {
    if (state.openStack.isEmpty && state.forwardStack.isEmpty) return;
    emit(
      state.copyWith(
        openStack: const <String>[],
        forwardStack: const <String>[],
        openJid: null,
        openChatCalendar: false,
        openChatRoute: ChatRouteIndex.main,
      ),
    );
    await _chatsService.closeChat();
  }

  void toggleCalendar() {
    if (state.openCalendar) {
      emit(state.copyWith(openCalendar: false, openChatCalendar: false));
    } else {
      emit(state.copyWith(openCalendar: true, openChatCalendar: false));
    }
  }

  void setOpenChatRoute({required ChatRouteIndex route}) {
    if (state.openChatRoute == route) {
      return;
    }
    emit(
      state.copyWith(
        openChatRoute: route,
        openChatCalendar: route.isCalendar,
        openCalendar: route.isCalendar ? false : state.openCalendar,
      ),
    );
  }

  void setChatCalendarOpen({required bool open}) {
    if (state.openChatCalendar == open) {
      return;
    }
    emit(
      state.copyWith(
        openChatCalendar: open,
        openCalendar: open ? false : state.openCalendar,
        openChatRoute: open
            ? ChatRouteIndex.calendar
            : state.openChatRoute.isCalendar
                ? ChatRouteIndex.main
                : state.openChatRoute,
      ),
    );
  }

  Future<void> toggleFavorited({
    required String jid,
    required bool favorited,
  }) async {
    await _chatsService.toggleChatFavorited(jid: jid, favorited: favorited);
  }

  Future<void> toggleAttachmentAutoDownload({
    required String jid,
    required bool enabled,
  }) async {
    await _chatsService.toggleChatAttachmentAutoDownload(
      jid: jid,
      enabled: enabled,
    );
  }

  Future<void> toggleArchived({
    required String jid,
    required bool archived,
  }) async {
    if (archived && state.openJid == jid) {
      await _chatsService.closeChat();
    }
    await _chatsService.toggleChatArchived(jid: jid, archived: archived);
  }

  Future<void> toggleHidden({required String jid, required bool hidden}) async {
    if (hidden && state.openJid == jid) {
      await _chatsService.closeChat();
    }
    await _chatsService.toggleChatHidden(jid: jid, hidden: hidden);
  }

  Future<bool?> moveSpamToInbox({required Chat chat}) async {
    final jid = chat.jid;
    if (state.spamUpdatingJids.contains(jid)) {
      return null;
    }
    emit(
      state.copyWith(
        spamUpdatingJids: {...state.spamUpdatingJids, jid},
      ),
    );
    bool success = false;
    try {
      await _xmppService.setSpamStatus(jid: jid, spam: false);
      success = true;
    } on XmppException {
      success = false;
    } finally {
      emit(
        state.copyWith(
          spamUpdatingJids: {...state.spamUpdatingJids}..remove(jid),
        ),
      );
    }
    return success;
  }

  Future<List<Message>> loadChatHistory(String jid) {
    return _chatsService.loadCompleteChatHistory(jid: jid);
  }

  Future<void> createChatRoom({
    required String title,
    String? nickname,
    AvatarUploadPayload? avatar,
  }) async {
    emit(state.copyWith(creationStatus: RequestStatus.loading));
    final mucService = _chatsService as MucService;
    try {
      final roomJid = await mucService.createRoom(
        name: title,
        nickname: nickname,
        avatar: avatar,
      );
      await openChat(jid: roomJid);
      emit(state.copyWith(creationStatus: RequestStatus.success));
    } on Exception {
      emit(state.copyWith(creationStatus: RequestStatus.failure));
    }
  }

  void clearCreationStatus() {
    if (state.creationStatus.isNone) return;
    emit(state.copyWith(creationStatus: RequestStatus.none));
  }

  Future<void> refreshHomeSync() {
    if (!state.refreshStatus.isLoading) {
      emit(state.copyWith(refreshStatus: RequestStatus.loading));
    }
    return _homeRefreshSyncService.refresh().then((_) {});
  }

  void clearRefreshStatus() {
    if (state.refreshStatus.isNone) return;
    emit(state.copyWith(refreshStatus: RequestStatus.none));
  }

  Future<void> deleteChat({required String jid}) async {
    await _chatsService.deleteChat(jid: jid);
  }

  Future<void> deleteChatMessages({required String jid}) async {
    final chat = await _resolveChat(jid);
    final emailService = _emailService;
    if (chat != null && chat.defaultTransport.isEmail && emailService != null) {
      try {
        await _deleteEmailMessagesForChat(
          chat: chat,
          emailService: emailService,
        );
      } on Exception {
        // Best-effort: core delete should not block local cleanup.
      }
    }
    await _chatsService.deleteChatMessages(jid: jid);
  }

  Future<void> _deleteEmailMessagesForChat({
    required Chat chat,
    required EmailService emailService,
  }) async {
    final db = await _loadDatabase();
    final messages = await db.getAllMessagesForChat(chat.jid);
    if (messages.isEmpty) return;
    await emailService.deleteMessages(messages);
  }

  Future<Chat?> _resolveChat(String jid) async {
    final fromState = _chatFor(jid);
    if (fromState != null) return fromState;
    final db = await _loadDatabase();
    return db.getChat(jid);
  }

  Future<XmppDatabase> _loadDatabase() async {
    final xmppBase = _chatsService as XmppBase;
    return xmppBase.database;
  }

  Future<void> renameContact({
    required String jid,
    required String displayName,
  }) {
    return _chatsService.renameChatContact(jid: jid, displayName: displayName);
  }

  void ensureChatSelected(String jid) {
    if (state.selectedJids.contains(jid)) return;
    final updated = Set<String>.of(state.selectedJids)..add(jid);
    _emitSelectionUpdate(updated);
  }

  void toggleChatSelection(String jid) {
    final updated = Set<String>.of(state.selectedJids);
    if (!updated.remove(jid)) {
      updated.add(jid);
    }
    _emitSelectionUpdate(updated);
  }

  void clearSelection() {
    if (state.selectedJids.isEmpty) return;
    _emitSelectionUpdate(const <String>{});
  }

  void _emitSelectionUpdate(Set<String> selectedJids) {
    final derived = _deriveChatViews(
      items: state.items ?? const <Chat>[],
      rosterContacts: state.rosterContacts,
      searchQuery: state.searchQuery,
      searchActive: state.searchActive,
      searchFilter: state.searchFilter,
      searchSortOrder: state.searchSortOrder,
      selectedJids: selectedJids,
    );
    emit(
      state.copyWith(
        selectedJids: selectedJids,
        visibleItems: derived.visibleItems,
        archivedItems: derived.archivedItems,
        selectedChats: derived.selectedChats,
      ),
    );
  }

  Future<void> bulkToggleFavorited({required bool favorited}) async {
    final targets = state.selectedJids.toList();
    if (targets.isEmpty) return;
    await Future.wait(
      targets.map(
        (jid) =>
            _chatsService.toggleChatFavorited(jid: jid, favorited: favorited),
      ),
    );
    clearSelection();
  }

  Future<void> bulkToggleArchived({required bool archived}) async {
    final targets = state.selectedJids.toList();
    if (targets.isEmpty) return;
    if (archived && targets.contains(state.openJid)) {
      await _chatsService.closeChat();
    }
    await Future.wait(
      targets.map(
        (jid) => _chatsService.toggleChatArchived(jid: jid, archived: archived),
      ),
    );
    clearSelection();
  }

  Future<void> bulkToggleHidden({required bool hidden}) async {
    final targets = state.selectedJids.toList();
    if (targets.isEmpty) return;
    if (hidden && targets.contains(state.openJid)) {
      await _chatsService.closeChat();
    }
    await Future.wait(
      targets.map(
        (jid) => _chatsService.toggleChatHidden(jid: jid, hidden: hidden),
      ),
    );
    clearSelection();
  }

  Future<void> bulkDeleteSelectedChats() async {
    final targets = state.selectedJids.toList();
    if (targets.isEmpty) return;
    if (targets.contains(state.openJid)) {
      await _chatsService.closeChat();
    }
    await Future.wait(
      targets.map((jid) => _chatsService.deleteChat(jid: jid)),
    );
    clearSelection();
  }

  Future<int> countChatHistoryMessages(String jid) async {
    final db = await _loadDatabase();
    return db.countChatMessages(jid);
  }

  Future<List<Message>> loadChatHistoryPage({
    required String jid,
    required int offset,
    required int limit,
  }) async {
    final db = await _loadDatabase();
    return db.getChatMessages(jid, start: offset, end: limit);
  }

  Stream<List<String>> recipientAddressSuggestionsStream() =>
      _chatsService.recipientAddressSuggestionsStream();

  String? get selfJid => _xmppService.myJid;
}
