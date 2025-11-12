import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:axichat/src/common/search/search_models.dart';

enum HomeTab {
  chats,
  contacts,
  invites,
  blocked,
  drafts;
}

class TabSearchState extends Equatable {
  const TabSearchState({
    this.query = '',
    this.sort = SearchSortOrder.newestFirst,
    this.filterId,
  });

  final String query;
  final SearchSortOrder sort;
  final String? filterId;

  TabSearchState copyWith({
    String? query,
    SearchSortOrder? sort,
    String? filterId,
  }) {
    return TabSearchState(
      query: query ?? this.query,
      sort: sort ?? this.sort,
      filterId: filterId ?? this.filterId,
    );
  }

  @override
  List<Object?> get props => [query, sort, filterId];
}

class HomeSearchState extends Equatable {
  const HomeSearchState({
    required this.tabs,
    required this.active,
    required this.activeTab,
    required this.tabStates,
  });

  final List<HomeTab> tabs;
  final bool active;
  final HomeTab? activeTab;
  final Map<HomeTab, TabSearchState> tabStates;

  TabSearchState? get currentTabState =>
      activeTab == null ? null : tabStates[activeTab];

  TabSearchState stateFor(HomeTab tab) =>
      tabStates[tab] ?? const TabSearchState();

  @override
  List<Object?> get props => [tabs, active, activeTab, tabStates];
}

class HomeSearchCubit extends Cubit<HomeSearchState> {
  HomeSearchCubit({
    required List<HomeTab> tabs,
    Map<HomeTab, String?> initialFilters = const {},
  }) : super(
          HomeSearchState(
            tabs: List.unmodifiable(tabs),
            active: false,
            activeTab: tabs.isEmpty ? null : tabs.first,
            tabStates: Map<HomeTab, TabSearchState>.unmodifiable({
              for (final tab in tabs)
                tab: TabSearchState(filterId: initialFilters[tab]),
            }),
          ),
        );

  void setActiveTab(HomeTab? tab) {
    if (state.activeTab == tab) return;
    if (tab != null && !state.tabs.contains(tab)) return;
    emit(
      HomeSearchState(
        tabs: state.tabs,
        active: state.active,
        activeTab: tab,
        tabStates: state.tabStates,
      ),
    );
  }

  void setSearchActive(bool active) {
    if (state.active == active) return;
    emit(
      HomeSearchState(
        tabs: state.tabs,
        active: active,
        activeTab: state.activeTab,
        tabStates: state.tabStates,
      ),
    );
  }

  void toggleSearch() => setSearchActive(!state.active);

  void updateQuery(String value, {HomeTab? tab}) {
    final targetTab = tab ?? state.activeTab;
    if (targetTab == null) return;
    final current = state.stateFor(targetTab);
    _updateTabState(
      targetTab,
      TabSearchState(
        query: value,
        sort: current.sort,
        filterId: current.filterId,
      ),
    );
  }

  void updateSort(SearchSortOrder sort, {HomeTab? tab}) {
    final targetTab = tab ?? state.activeTab;
    if (targetTab == null) return;
    final current = state.stateFor(targetTab);
    _updateTabState(
      targetTab,
      TabSearchState(
        query: current.query,
        sort: sort,
        filterId: current.filterId,
      ),
    );
  }

  void updateFilter(String? filterId, {HomeTab? tab}) {
    final targetTab = tab ?? state.activeTab;
    if (targetTab == null) return;
    final current = state.stateFor(targetTab);
    _updateTabState(
      targetTab,
      TabSearchState(
        query: current.query,
        sort: current.sort,
        filterId: filterId,
      ),
    );
  }

  void clearQuery({HomeTab? tab}) => updateQuery('', tab: tab);

  void _updateTabState(HomeTab tab, TabSearchState tabState) {
    final mutable = Map<HomeTab, TabSearchState>.from(state.tabStates)
      ..[tab] = tabState;
    emit(
      HomeSearchState(
        tabs: state.tabs,
        active: state.active,
        activeTab: state.activeTab,
        tabStates: Map<HomeTab, TabSearchState>.unmodifiable(mutable),
      ),
    );
  }
}
