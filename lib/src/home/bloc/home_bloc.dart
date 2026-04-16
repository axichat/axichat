// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'home_event.dart';
part 'home_state.dart';

enum _HomeRefreshOutcome {
  success,
  failure;

  bool get isSuccess => this == success;

  bool get isFailure => this == failure;
}

enum _HomeRefreshTargetOutcome {
  success,
  failure,
  skipped;

  bool get isFailure => this == failure;

  bool get isSuccess => this == success;

  bool get isSkipped => this == skipped;
}

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
  EmailService? _emailSyncSubscriptionService;
  Future<void>? _emailSyncSubscriptionTask;
  Future<_HomeRefreshOutcome>? _syncTask;

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
    final targetSlot = _resolveSearchSlot(tab: event.tab, slot: event.slot);
    if (targetSlot == null) {
      return;
    }
    final current = state.stateForSlot(targetSlot);
    _emitSearchState(emit, targetSlot, current.copyWith(query: event.value));
  }

  void _onSearchSortChanged(
    HomeSearchSortChanged event,
    Emitter<HomeState> emit,
  ) {
    final targetSlot = _resolveSearchSlot(tab: event.tab, slot: event.slot);
    if (targetSlot == null) {
      return;
    }
    final current = state.stateForSlot(targetSlot);
    _emitSearchState(emit, targetSlot, current.copyWith(sort: event.sort));
  }

  void _onSearchFilterChanged(
    HomeSearchFilterChanged event,
    Emitter<HomeState> emit,
  ) {
    final targetSlot = _resolveSearchSlot(tab: event.tab, slot: event.slot);
    if (targetSlot == null) {
      return;
    }
    final current = state.stateForSlot(targetSlot);
    _emitSearchState(
      emit,
      targetSlot,
      current.copyWith(filterId: event.filterId),
    );
  }

  Future<void> _onRefreshRequested(
    HomeRefreshRequested event,
    Emitter<HomeState> emit,
  ) async {
    await _runSync(emit, _runRefreshGesture);
  }

  Future<void> _onEmailUnreadRefreshRequested(
    _HomeEmailUnreadRefreshRequested event,
    Emitter<HomeState> emit,
  ) async {
    await _runSync(emit, _runEmailUnreadRefreshGesture);
  }

  Future<void> _runSync(
    Emitter<HomeState> emit,
    Future<_HomeRefreshOutcome> Function() action,
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
      final outcome = await task;
      if (outcome.isFailure) {
        emit(state.copyWith(refreshStatus: RequestStatus.failure));
        return;
      }
      emit(
        state.copyWith(
          refreshStatus: RequestStatus.success,
          lastSyncedAt: DateTime.timestamp(),
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

  HomeSearchSlot? _resolveSearchSlot({HomeTab? tab, HomeSearchSlot? slot}) {
    if (slot != null) {
      return slot;
    }
    final targetTab = tab ?? state.activeTab;
    return HomeSearchSlot.forTab(targetTab);
  }

  void _emitSearchState(
    Emitter<HomeState> emit,
    HomeSearchSlot slot,
    TabSearchState searchState,
  ) {
    final mutable = Map<HomeSearchSlot, TabSearchState>.from(state.searchStates)
      ..[slot] = searchState;
    emit(
      state.copyWith(
        searchStates: Map<HomeSearchSlot, TabSearchState>.unmodifiable(mutable),
      ),
    );
  }

  @override
  Future<void> close() async {
    _emailService = null;
    await _reconcileEmailSyncSubscription();
    return super.close();
  }

  Future<void> _attachEmailSyncSubscription(EmailService? emailService) async {
    _emailService = emailService;
    await _reconcileEmailSyncSubscription();
  }

  Future<void> _reconcileEmailSyncSubscription() async {
    while (true) {
      final activeTask = _emailSyncSubscriptionTask;
      if (activeTask != null) {
        await activeTask;
        if (identical(_emailSyncSubscriptionService, _emailService)) {
          return;
        }
        continue;
      }

      final task = _runEmailSyncSubscriptionReconcile();
      _emailSyncSubscriptionTask = task;
      try {
        await task;
      } finally {
        if (identical(_emailSyncSubscriptionTask, task)) {
          _emailSyncSubscriptionTask = null;
        }
      }
      if (identical(_emailSyncSubscriptionService, _emailService)) {
        return;
      }
    }
  }

  Future<void> _runEmailSyncSubscriptionReconcile() async {
    final existingSubscription = _emailSyncSubscription;
    _emailSyncSubscription = null;
    _emailSyncSubscriptionService = null;
    await existingSubscription?.cancel();

    final emailService = _emailService;
    if (emailService == null) {
      return;
    }

    final subscription = emailService.readyTransitionStream.listen((_) {
      if (!identical(_emailSyncSubscriptionService, emailService)) {
        return;
      }
      _runEmailReconnectSync();
    });
    if (!identical(_emailService, emailService)) {
      await subscription.cancel();
      return;
    }

    _emailSyncSubscription = subscription;
    _emailSyncSubscriptionService = emailService;

    if (identical(_emailService, emailService) &&
        identical(_emailSyncSubscriptionService, emailService) &&
        emailService.syncState.status == EmailSyncStatus.ready) {
      await _runEmailReconnectSync();
    }
  }

  Future<void> _runEmailReconnectSync() async {
    if (_syncTask != null) {
      return;
    }
    add(const _HomeEmailUnreadRefreshRequested());
  }

  Future<_HomeRefreshOutcome> _runRefreshGesture() async {
    final emailOutcome = await _runEmailSessionSync();
    final xmppOutcome = await _runXmppSessionSync();

    if (xmppOutcome.isFailure) {
      return _HomeRefreshOutcome.failure;
    }
    if (emailOutcome.isFailure && xmppOutcome.isSkipped) {
      return _HomeRefreshOutcome.failure;
    }
    return _HomeRefreshOutcome.success;
  }

  Future<_HomeRefreshTargetOutcome> _runEmailSessionSync() async {
    final emailService = _emailService;
    if (emailService == null) {
      return _HomeRefreshTargetOutcome.skipped;
    }
    final didSync = await emailService.syncSessionState();
    return didSync
        ? _HomeRefreshTargetOutcome.success
        : _HomeRefreshTargetOutcome.failure;
  }

  Future<_HomeRefreshTargetOutcome> _runXmppSessionSync() async {
    if (!_xmppService.hasConnectionSettings) {
      return _HomeRefreshTargetOutcome.skipped;
    }
    final didSync = await _xmppService.syncSessionState();
    return didSync
        ? _HomeRefreshTargetOutcome.success
        : _HomeRefreshTargetOutcome.failure;
  }

  Future<_HomeRefreshOutcome> _runEmailUnreadRefreshGesture() async {
    final emailService = _emailService;
    if (emailService == null) {
      return _HomeRefreshOutcome.success;
    }
    final didRefresh = await emailService.refreshUnreadForHomeRefresh();
    return didRefresh
        ? _HomeRefreshOutcome.success
        : _HomeRefreshOutcome.failure;
  }
}
