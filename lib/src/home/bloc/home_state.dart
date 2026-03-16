part of 'home_bloc.dart';

enum HomeTab { chats, contacts, invites, important, blocked, spam, drafts }

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
    required this.tabStates,
    required this.refreshStatus,
    this.lastSyncedAt,
  });

  factory HomeState.initial({
    required List<HomeTab> tabs,
    required Map<HomeTab, SearchFilterId?> initialFilters,
  }) {
    return HomeState(
      tabs: List<HomeTab>.unmodifiable(tabs),
      active: false,
      activeTab: tabs.isEmpty ? null : tabs.first,
      tabStates: Map<HomeTab, TabSearchState>.unmodifiable({
        for (final tab in tabs)
          tab: TabSearchState(filterId: initialFilters[tab]),
      }),
      refreshStatus: RequestStatus.none,
    );
  }

  final List<HomeTab> tabs;
  final bool active;
  final HomeTab? activeTab;
  final Map<HomeTab, TabSearchState> tabStates;
  final RequestStatus refreshStatus;
  final DateTime? lastSyncedAt;

  TabSearchState? get currentTabState =>
      activeTab == null ? null : tabStates[activeTab];

  TabSearchState stateFor(HomeTab tab) =>
      tabStates[tab] ?? const TabSearchState();

  HomeState copyWith({
    List<HomeTab>? tabs,
    bool? active,
    Object? activeTab = _homeStateUnset,
    Map<HomeTab, TabSearchState>? tabStates,
    RequestStatus? refreshStatus,
    Object? lastSyncedAt = _homeStateUnset,
  }) {
    return HomeState(
      tabs: tabs ?? this.tabs,
      active: active ?? this.active,
      activeTab: activeTab == _homeStateUnset
          ? this.activeTab
          : activeTab as HomeTab?,
      tabStates: tabStates ?? this.tabStates,
      refreshStatus: refreshStatus ?? this.refreshStatus,
      lastSyncedAt: lastSyncedAt == _homeStateUnset
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
    tabs,
    active,
    activeTab,
    tabStates,
    refreshStatus,
    lastSyncedAt,
  ];
}

const Object _homeStateUnset = Object();
