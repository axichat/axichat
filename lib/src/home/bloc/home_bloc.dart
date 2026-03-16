// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/xmpp/pubsub/bookmarks_manager.dart';
import 'package:axichat/src/xmpp/pubsub/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'home_event.dart';
part 'home_refresh.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required XmppService xmppService,
    EmailService? emailService,
    required List<HomeTab> tabs,
    Map<HomeTab, SearchFilterId?> initialFilters = const {},
  }) : _xmppService = xmppService,
       _emailService = emailService,
       super(HomeState.initial(tabs: tabs, initialFilters: initialFilters)) {
    on<HomeActiveTabChanged>(_onActiveTabChanged);
    on<HomeSearchVisibilityChanged>(_onSearchVisibilityChanged);
    on<HomeSearchToggled>(_onSearchToggled);
    on<HomeSearchQueryChanged>(_onSearchQueryChanged);
    on<HomeSearchSortChanged>(_onSearchSortChanged);
    on<HomeSearchFilterChanged>(_onSearchFilterChanged);
    on<HomeRefreshRequested>(_onRefreshRequested);
    on<HomeRefreshStatusCleared>(_onRefreshStatusCleared);
    on<HomeEmailServiceChanged>(_onEmailServiceChanged);
    on<_HomeEmailUnreadRefreshRequested>(_onEmailUnreadRefreshRequested);
    _attachEmailSyncSubscription(emailService);
  }

  final XmppService _xmppService;
  final Logger _log = Logger('HomeBloc');
  EmailService? _emailService;
  StreamSubscription<void>? _emailSyncSubscription;
  Future<DateTime>? _syncTask;

  void _onActiveTabChanged(
    HomeActiveTabChanged event,
    Emitter<HomeState> emit,
  ) {
    if (state.activeTab == event.tab) {
      return;
    }
    if (event.tab != null && !state.tabs.contains(event.tab)) {
      return;
    }
    emit(state.copyWith(activeTab: event.tab));
  }

  void _onSearchVisibilityChanged(
    HomeSearchVisibilityChanged event,
    Emitter<HomeState> emit,
  ) {
    if (state.active == event.active) {
      return;
    }
    emit(state.copyWith(active: event.active));
  }

  void _onSearchToggled(HomeSearchToggled event, Emitter<HomeState> emit) {
    emit(state.copyWith(active: !state.active));
  }

  void _onSearchQueryChanged(
    HomeSearchQueryChanged event,
    Emitter<HomeState> emit,
  ) {
    final targetTab = event.tab ?? state.activeTab;
    if (targetTab == null) {
      return;
    }
    final current = state.stateFor(targetTab);
    _emitTabState(emit, targetTab, current.copyWith(query: event.value));
  }

  void _onSearchSortChanged(
    HomeSearchSortChanged event,
    Emitter<HomeState> emit,
  ) {
    final targetTab = event.tab ?? state.activeTab;
    if (targetTab == null) {
      return;
    }
    final current = state.stateFor(targetTab);
    _emitTabState(emit, targetTab, current.copyWith(sort: event.sort));
  }

  void _onSearchFilterChanged(
    HomeSearchFilterChanged event,
    Emitter<HomeState> emit,
  ) {
    final targetTab = event.tab ?? state.activeTab;
    if (targetTab == null) {
      return;
    }
    final current = state.stateFor(targetTab);
    _emitTabState(emit, targetTab, current.copyWith(filterId: event.filterId));
  }

  Future<void> _onRefreshRequested(
    HomeRefreshRequested event,
    Emitter<HomeState> emit,
  ) async {
    await _runSync(emit, _runRefreshSequence);
  }

  Future<void> _onEmailUnreadRefreshRequested(
    _HomeEmailUnreadRefreshRequested event,
    Emitter<HomeState> emit,
  ) async {
    await _runSync(emit, _runEmailUnreadRefreshSequence);
  }

  Future<void> _runSync(
    Emitter<HomeState> emit,
    Future<DateTime> Function() action,
  ) async {
    final pending = _syncTask;
    if (pending != null) {
      await pending;
      return;
    }

    emit(state.copyWith(refreshStatus: RequestStatus.loading));

    final task = action();
    _syncTask = task;

    try {
      final syncedAt = await task;
      emit(
        state.copyWith(
          refreshStatus: RequestStatus.success,
          lastSyncedAt: syncedAt,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.fine('Home refresh failed.', error, stackTrace);
      emit(state.copyWith(refreshStatus: RequestStatus.failure));
    } finally {
      if (identical(_syncTask, task)) {
        _syncTask = null;
      }
    }
  }

  void _onRefreshStatusCleared(
    HomeRefreshStatusCleared event,
    Emitter<HomeState> emit,
  ) {
    if (state.refreshStatus.isNone) {
      return;
    }
    emit(state.copyWith(refreshStatus: RequestStatus.none));
  }

  Future<void> _onEmailServiceChanged(
    HomeEmailServiceChanged event,
    Emitter<HomeState> emit,
  ) async {
    if (identical(event.emailService, _emailService)) {
      return;
    }
    _emailService = event.emailService;
    await _attachEmailSyncSubscription(event.emailService);
  }

  void _emitTabState(
    Emitter<HomeState> emit,
    HomeTab tab,
    TabSearchState tabState,
  ) {
    final mutable = Map<HomeTab, TabSearchState>.from(state.tabStates)
      ..[tab] = tabState;
    emit(
      state.copyWith(
        tabStates: Map<HomeTab, TabSearchState>.unmodifiable(mutable),
      ),
    );
  }

  @override
  Future<void> close() async {
    _syncTask = null;
    final emailSubscription = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await emailSubscription?.cancel();
    return super.close();
  }
}
