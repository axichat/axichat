part of 'home_bloc.dart';

enum HomeTab { chats, contacts, invites, blocked, drafts, folders }

enum HomeSearchSlot {
  chats,
  contacts,
  invites,
  blocked,
  drafts,
  foldersImportant,
  foldersSpam;

  static HomeSearchSlot? forTab(HomeTab? tab) => switch (tab) {
    HomeTab.chats => HomeSearchSlot.chats,
    HomeTab.contacts => HomeSearchSlot.contacts,
    HomeTab.invites => HomeSearchSlot.invites,
    HomeTab.blocked => HomeSearchSlot.blocked,
    HomeTab.drafts => HomeSearchSlot.drafts,
    HomeTab.folders || null => null,
  };
}

class HomeSearchFilter extends Equatable {
  const HomeSearchFilter({required this.id, required this.label});

  final SearchFilterId id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

List<HomeSearchFilter> chatsSearchFilters(AppLocalizations l10n) => [
  HomeSearchFilter(id: SearchFilterId.all, label: l10n.chatsFilterAll),
  HomeSearchFilter(
    id: SearchFilterId.contacts,
    label: l10n.chatsFilterContacts,
  ),
  HomeSearchFilter(
    id: SearchFilterId.nonContacts,
    label: l10n.chatsFilterNonContacts,
  ),
  HomeSearchFilter(id: SearchFilterId.xmpp, label: l10n.chatsFilterXmppOnly),
  HomeSearchFilter(id: SearchFilterId.email, label: l10n.chatsFilterEmailOnly),
  HomeSearchFilter(id: SearchFilterId.hidden, label: l10n.chatsFilterHidden),
];

List<HomeSearchFilter> spamSearchFilters(AppLocalizations l10n) => [
  HomeSearchFilter(id: SearchFilterId.all, label: l10n.spamFilterAll),
  HomeSearchFilter(id: SearchFilterId.email, label: l10n.spamFilterEmail),
  HomeSearchFilter(id: SearchFilterId.xmpp, label: l10n.spamFilterXmpp),
];

class TabSearchState extends Equatable {
  const TabSearchState({
    this.query = '',
    this.sort = SearchSortOrder.newestFirst,
    this.filterId,
  });

  final String query;
  final SearchSortOrder sort;
  final SearchFilterId? filterId;

  TabSearchState copyWith({
    String? query,
    SearchSortOrder? sort,
    Object? filterId = _homeStateUnset,
  }) {
    return TabSearchState(
      query: query ?? this.query,
      sort: sort ?? this.sort,
      filterId: filterId == _homeStateUnset
          ? this.filterId
          : filterId as SearchFilterId?,
    );
  }

  @override
  List<Object?> get props => [query, sort, filterId];
}

class HomeState extends Equatable {
  const HomeState({
    required this.tabs,
    required this.active,
    required this.activeTab,
    required this.searchStates,
    required this.refreshStatus,
    required this.badgeSeenMarkers,
    required this.badgeSeenMarkersLoaded,
    this.lastSyncedAt,
  });

  factory HomeState.initial({
    required List<HomeTab> tabs,
    required Map<HomeTab, SearchFilterId?> initialFilters,
  }) {
    final searchStates = <HomeSearchSlot, TabSearchState>{};
    for (final tab in tabs) {
      final slot = HomeSearchSlot.forTab(tab);
      if (slot != null) {
        searchStates[slot] = TabSearchState(filterId: initialFilters[tab]);
        continue;
      }
      if (tab == HomeTab.folders) {
        searchStates[HomeSearchSlot.foldersImportant] = const TabSearchState();
        searchStates[HomeSearchSlot.foldersSpam] = const TabSearchState(
          filterId: SearchFilterId.all,
        );
      }
    }
    return HomeState(
      tabs: List<HomeTab>.unmodifiable(tabs),
      active: false,
      activeTab: tabs.isEmpty ? null : tabs.first,
      searchStates: Map<HomeSearchSlot, TabSearchState>.unmodifiable(
        searchStates,
      ),
      refreshStatus: RequestStatus.none,
      badgeSeenMarkers: const <HomeBadgeBucket, DateTime>{},
      badgeSeenMarkersLoaded: false,
    );
  }

  final List<HomeTab> tabs;
  final bool active;
  final HomeTab? activeTab;
  final Map<HomeSearchSlot, TabSearchState> searchStates;
  final RequestStatus refreshStatus;
  final DateTime? lastSyncedAt;
  final Map<HomeBadgeBucket, DateTime> badgeSeenMarkers;
  final bool badgeSeenMarkersLoaded;

  TabSearchState? get currentTabState =>
      activeTab == null ? null : stateFor(activeTab!);

  TabSearchState stateFor(HomeTab tab) =>
      stateForSlot(HomeSearchSlot.forTab(tab));

  TabSearchState stateForSlot(HomeSearchSlot? slot) => slot == null
      ? const TabSearchState()
      : searchStates[slot] ?? const TabSearchState();

  HomeState copyWith({
    List<HomeTab>? tabs,
    bool? active,
    Object? activeTab = _homeStateUnset,
    Map<HomeSearchSlot, TabSearchState>? searchStates,
    RequestStatus? refreshStatus,
    Object? lastSyncedAt = _homeStateUnset,
    Map<HomeBadgeBucket, DateTime>? badgeSeenMarkers,
    bool? badgeSeenMarkersLoaded,
  }) {
    return HomeState(
      tabs: tabs ?? this.tabs,
      active: active ?? this.active,
      activeTab: activeTab == _homeStateUnset
          ? this.activeTab
          : activeTab as HomeTab?,
      searchStates: searchStates ?? this.searchStates,
      refreshStatus: refreshStatus ?? this.refreshStatus,
      lastSyncedAt: lastSyncedAt == _homeStateUnset
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      badgeSeenMarkers: badgeSeenMarkers ?? this.badgeSeenMarkers,
      badgeSeenMarkersLoaded:
          badgeSeenMarkersLoaded ?? this.badgeSeenMarkersLoaded,
    );
  }

  @override
  List<Object?> get props => [
    tabs,
    active,
    activeTab,
    searchStates,
    refreshStatus,
    lastSyncedAt,
    badgeSeenMarkers,
    badgeSeenMarkersLoaded,
  ];
}

const Object _homeStateUnset = Object();
