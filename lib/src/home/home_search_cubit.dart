// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';

import 'package:axichat/src/common/search/search_models.dart';

enum HomeTab { chats, contacts, invites, important, blocked, spam, drafts }

class HomeSearchFilter {
  const HomeSearchFilter({required this.id, required this.label});

  final SearchFilterId id;
  final String label;
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

class HomeTabEntry {
  const HomeTabEntry({
    required this.id,
    required this.label,
    required this.body,
    this.fab,
    this.searchFilters = const [],
  });

  final HomeTab id;
  final String label;
  final Widget body;
  final Widget? fab;
  final List<HomeSearchFilter> searchFilters;
}

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
    SearchFilterId? filterId,
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
    Map<HomeTab, SearchFilterId?> initialFilters = const {},
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

  void updateFilter(SearchFilterId? filterId, {HomeTab? tab}) {
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
