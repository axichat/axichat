// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'chats_cubit.dart';

@Freezed(toJson: false, fromJson: false)
class ChatsState with _$ChatsState {
  const factory ChatsState({
    required String? openJid,
    @Default(<String>[]) List<String> openStack,
    @Default(<String>[]) List<String> forwardStack,
    required bool openCalendar,
    @Default(false) bool openChatCalendar,
    @Default(ChatRouteIndex.main) ChatRouteIndex openChatRoute,
    required List<Chat>? items,
    required RequestStatus creationStatus,
    @Default(RequestStatus.none) RequestStatus refreshStatus,
    DateTime? lastSyncedAt,
    @Default(<String>{}) Set<String> selectedJids,
    @Default('') String searchQuery,
    @Default(false) bool searchActive,
    SearchFilterId? searchFilter,
    @Default(SearchSortOrder.newestFirst) SearchSortOrder searchSortOrder,
    @Default('') String spamSearchQuery,
    @Default(false) bool spamSearchActive,
    SearchFilterId? spamSearchFilter,
    @Default(SearchSortOrder.newestFirst) SearchSortOrder spamSearchSortOrder,
    @Default(<String>{}) Set<String> rosterContacts,
    @Default(<Chat>[]) List<Chat> visibleItems,
    @Default(<Chat>[]) List<Chat> archivedItems,
    @Default(<Chat>[]) List<Chat> selectedChats,
    @Default(<Chat>[]) List<Chat> spamVisibleItems,
    @Default(<String>{}) Set<String> spamUpdatingJids,
    @Default(<String>[]) List<String> recipientAddressSuggestions,
    @Default(0) int demoResetRevision,
  }) = _ChatsState;
}
