// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/service/home_refresh_sync_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
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
  important,
  gallery,
  calendar;

  bool get isMain => this == ChatRouteIndex.main;

  bool get isSearch => this == ChatRouteIndex.search;

  bool get isDetails => this == ChatRouteIndex.details;

  bool get isSettings => this == ChatRouteIndex.settings;

  bool get isImportant => this == ChatRouteIndex.important;

  bool get isGallery => this == ChatRouteIndex.gallery;

  bool get isCalendar => this == ChatRouteIndex.calendar;

  bool get allowsChatInteraction => isMain || isSearch;
}

ChatRouteIndex resolveStoredChatRoute({
  required ChatRouteIndex route,
  required bool hasChat,
  required bool hasFocusedMessage,
}) {
  if (route.isDetails && !hasFocusedMessage) {
    return ChatRouteIndex.main;
  }
  if ((route.isSettings ||
          route.isImportant ||
          route.isGallery ||
          route.isCalendar) &&
      !hasChat) {
    return ChatRouteIndex.main;
  }
  return route;
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

int _compareVisibleChats(
  Chat a,
  Chat b, {
  required SearchSortOrder searchSortOrder,
}) {
  if (a.favorited != b.favorited) {
    return a.favorited ? -1 : 1;
  }
  return searchSortOrder.isNewestFirst
      ? b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp)
      : a.lastChangeTimestamp.compareTo(b.lastChangeTimestamp);
}

enum ChatsCreateRoomFailure {
  alreadyExists,
  unknown;

  String resolve(AppLocalizations l10n) => switch (this) {
    ChatsCreateRoomFailure.alreadyExists => l10n.chatsCreateGroupAlreadyExists,
    ChatsCreateRoomFailure.unknown => l10n.chatsCreateGroupFailure,
  };
}

class ChatsCubit extends Cubit<ChatsState> {
  ChatsCubit({
    required XmppService xmppService,
    required HomeRefreshSyncService homeRefreshSyncService,
    EmailService? emailService,
  }) : _chatsService = xmppService,
       _xmppService = xmppService,
       _homeRefreshSyncService = homeRefreshSyncService,
       _emailService = emailService,
       super(_seedInitialState(xmppService.cachedChatList)) {
    _chatsSubscription = _chatsService.chatsStream().listen(
      (items) => _updateChats(items),
    );
    _recipientAddressSuggestionsSubscription = _chatsService
        .recipientAddressSuggestionsStream()
        .listen(_updateRecipientAddressSuggestions);
    _homeRefreshSyncSubscription = _homeRefreshSyncService.syncUpdates.listen(
      _handleHomeRefreshUpdate,
    );
    _demoResetSubscription = _xmppService.demoResetStream.listen(
      (_) => _handleDemoReset(),
    );
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
  late final StreamSubscription<List<String>>
  _recipientAddressSuggestionsSubscription;
  late final StreamSubscription<void> _demoResetSubscription;
  final List<Timer> _exportCleanupTimers = [];
  String? _pendingDefaultOpenRouteJid;

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
    await _recipientAddressSuggestionsSubscription.cancel();
    await _demoResetSubscription.cancel();
    return super.close();
  }

  void startDemoInteractivePhase() {
    _xmppService.startDemoInteractivePhase();
  }

  void _handleDemoReset() {
    emit(state.copyWith(demoResetRevision: state.demoResetRevision + 1));
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

  void _updateRecipientAddressSuggestions(List<String> suggestions) {
    if (listEquals(state.recipientAddressSuggestions, suggestions)) {
      return;
    }
    emit(state.copyWith(recipientAddressSuggestions: suggestions));
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
    final normalizedQuery = searchActive
        ? searchQuery.trim().toLowerCase()
        : '';
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

    final visibleItems =
        items
            .where((chat) => !chat.archived && !chat.spam)
            .where(matchesFilter)
            .where(matchesQuery)
            .toList(growable: false)
          ..sort(
            (a, b) =>
                _compareVisibleChats(a, b, searchSortOrder: searchSortOrder),
          );

    final archivedItems = items
        .where((chat) => chat.archived)
        .toList(growable: false);
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
    final normalizedQuery = searchActive
        ? searchQuery.trim().toLowerCase()
        : '';
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

    final visibleItems =
        items
            .where((chat) => chat.spam)
            .where(matchesFilter)
            .where(matchesQuery)
            .toList(growable: false)
          ..sort((a, b) {
            final aTimestamp = a.spamUpdatedAt ?? a.lastChangeTimestamp;
            final bTimestamp = b.spamUpdatedAt ?? b.lastChangeTimestamp;
            return searchSortOrder.isNewestFirst
                ? bTimestamp.compareTo(aTimestamp)
                : aTimestamp.compareTo(bTimestamp);
          });
    return visibleItems;
  }

  void _updateChats(List<Chat> items) {
    final availableJids = items.map((chat) => chat.jid).toSet();
    final retainedSelection = state.selectedJids
        .where((jid) => availableJids.contains(jid))
        .toSet();
    final seededStack = List<String>.of(state.openStack, growable: false);
    final retainedForward = List<String>.of(
      state.forwardStack,
      growable: false,
    );
    final nextOpenJid = seededStack.isEmpty ? null : seededStack.last;
    final shouldKeepChatCalendar =
        state.openChatCalendar && nextOpenJid != null;
    final shouldResolvePendingDefaultRoute =
        nextOpenJid != null &&
        _pendingDefaultOpenRouteJid == nextOpenJid &&
        _chatFor(nextOpenJid, items: items) != null;
    final nextChatRoute = nextOpenJid == null
        ? ChatRouteIndex.main
        : shouldKeepChatCalendar
        ? ChatRouteIndex.calendar
        : shouldResolvePendingDefaultRoute
        ? _defaultOpenRouteForChat(nextOpenJid, items: items)
        : state.openChatRoute.isCalendar
        ? ChatRouteIndex.main
        : state.openChatRoute;
    if (nextOpenJid != _pendingDefaultOpenRouteJid ||
        shouldResolvePendingDefaultRoute) {
      _pendingDefaultOpenRouteJid = null;
    }
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
        openJid: nextOpenJid,
        items: items,
        selectedJids: retainedSelection,
        openChatCalendar: nextChatRoute.isCalendar,
        openChatRoute: nextChatRoute,
        visibleItems: derived.visibleItems,
        archivedItems: derived.archivedItems,
        selectedChats: derived.selectedChats,
        spamVisibleItems: spamVisibleItems,
      ),
    );
  }

  Chat? _chatFor(String jid, {List<Chat>? items}) {
    for (final chat in items ?? state.items ?? const <Chat>[]) {
      if (chat.jid == jid) return chat;
    }
    return null;
  }

  ChatRouteIndex _defaultOpenRouteForChat(
    String jid, {
    ChatRouteIndex? route,
    List<Chat>? items,
  }) {
    if (route != null) {
      return route;
    }
    return _chatFor(jid, items: items)?.opensToCalendar == true
        ? ChatRouteIndex.calendar
        : ChatRouteIndex.main;
  }

  void _stageOpenChatUnreadBoundarySeed(String jid) {
    final unreadCount = _chatFor(jid)?.unreadCount ?? 0;
    _chatsService.stageOpenChatUnreadBoundarySeed(
      jid: jid,
      unreadCount: unreadCount,
    );
  }

  Future<void> openChat({required String jid, ChatRouteIndex? route}) async {
    _stageOpenChatUnreadBoundarySeed(jid);
    final openRoute = _defaultOpenRouteForChat(jid, route: route);
    _pendingDefaultOpenRouteJid = route == null && _chatFor(jid) == null
        ? jid
        : null;
    emit(
      state.copyWith(
        openStack: <String>[jid],
        forwardStack: const <String>[],
        openJid: jid,
        openChatCalendar: openRoute.isCalendar,
        openChatRoute: openRoute,
        pendingOpenMessageChatJid: null,
        pendingOpenMessageReferenceId: null,
      ),
    );
    await _chatsService.openChat(jid);
  }

  Future<void> openImportantMessage({
    required String jid,
    required String messageReferenceId,
  }) async {
    final normalizedMessageReferenceId = messageReferenceId.trim();
    if (normalizedMessageReferenceId.isEmpty) {
      await openChat(jid: jid, route: ChatRouteIndex.main);
      return;
    }
    await openChat(jid: jid, route: ChatRouteIndex.main);
    emit(
      state.copyWith(
        pendingOpenMessageChatJid: jid,
        pendingOpenMessageReferenceId: normalizedMessageReferenceId,
        pendingOpenMessageRequestId: state.pendingOpenMessageRequestId + 1,
      ),
    );
  }

  void clearPendingOpenMessageSelection({required int requestId}) {
    if (requestId != state.pendingOpenMessageRequestId) {
      return;
    }
    emit(
      state.copyWith(
        pendingOpenMessageChatJid: null,
        pendingOpenMessageReferenceId: null,
      ),
    );
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
    _pendingDefaultOpenRouteJid = null;
    _stageOpenChatUnreadBoundarySeed(jid);
    final filtered = state.openStack
        .where((entry) => entry != jid)
        .toList(growable: false);
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
    final openRoute = nextOpen == null
        ? ChatRouteIndex.main
        : _defaultOpenRouteForChat(nextOpen);
    _pendingDefaultOpenRouteJid = nextOpen != null && _chatFor(nextOpen) == null
        ? nextOpen
        : null;
    emit(
      state.copyWith(
        openStack: nextStack,
        forwardStack: nextForward,
        openJid: nextOpen,
        openChatCalendar: openRoute.isCalendar,
        openChatRoute: openRoute,
      ),
    );
    if (nextOpen == null) {
      await _chatsService.closeChat();
    } else {
      _stageOpenChatUnreadBoundarySeed(nextOpen);
      await _chatsService.openChat(nextOpen);
    }
  }

  Future<void> restoreChat() async {
    if (state.forwardStack.isEmpty) return;
    final restored = state.forwardStack.last;
    _stageOpenChatUnreadBoundarySeed(restored);
    final nextForward = List<String>.of(state.forwardStack)..removeLast();
    final filteredStack = state.openStack
        .where((entry) => entry != restored)
        .toList();
    filteredStack.add(restored);
    final openRoute = _defaultOpenRouteForChat(restored);
    _pendingDefaultOpenRouteJid = _chatFor(restored) == null ? restored : null;
    emit(
      state.copyWith(
        forwardStack: nextForward,
        openStack: filteredStack,
        openJid: restored,
        openChatCalendar: openRoute.isCalendar,
        openChatRoute: openRoute,
      ),
    );
    await _chatsService.openChat(restored);
  }

  Future<void> closeAllChats() async {
    if (state.openStack.isEmpty && state.forwardStack.isEmpty) return;
    _pendingDefaultOpenRouteJid = null;
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
    _pendingDefaultOpenRouteJid = null;
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
    _pendingDefaultOpenRouteJid = null;
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
    _pendingDefaultOpenRouteJid = null;
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
    final spamTargetJid = chat.antiAbuseTargetAddress;
    if (state.spamUpdatingJids.contains(jid)) {
      return null;
    }
    emit(state.copyWith(spamUpdatingJids: {...state.spamUpdatingJids, jid}));
    bool success = false;
    try {
      await _xmppService.setSpamStatus(jid: spamTargetJid, spam: false);
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
    ChatPrimaryView primaryView = ChatPrimaryView.chat,
  }) async {
    emit(
      state.copyWith(
        creationStatus: RequestStatus.loading,
        creationFailure: null,
      ),
    );
    final mucService = _chatsService as MucService;
    try {
      final roomJid = await mucService.createRoom(
        name: title,
        nickname: nickname,
        avatar: avatar,
        primaryView: primaryView,
      );
      emit(
        state.copyWith(
          creationStatus: RequestStatus.success,
          creationFailure: null,
        ),
      );
      fireAndForget(
        () => openChat(
          jid: roomJid,
          route: primaryView.isCalendar
              ? ChatRouteIndex.calendar
              : ChatRouteIndex.main,
        ),
        operationName: 'ChatsCubit.openCreatedRoom',
      );
    } on XmppMucCreateConflictException {
      emit(
        state.copyWith(
          creationStatus: RequestStatus.failure,
          creationFailure: ChatsCreateRoomFailure.alreadyExists,
        ),
      );
    } on Exception {
      emit(
        state.copyWith(
          creationStatus: RequestStatus.failure,
          creationFailure: ChatsCreateRoomFailure.unknown,
        ),
      );
    }
  }

  void clearCreationStatus() {
    if (state.creationStatus.isNone) return;
    emit(
      state.copyWith(creationStatus: RequestStatus.none, creationFailure: null),
    );
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
    await Future.wait(targets.map((jid) => _chatsService.deleteChat(jid: jid)));
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

  String? get selfJid => _xmppService.myJid;
}
